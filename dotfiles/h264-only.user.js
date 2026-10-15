 // ==UserScript==
 // @name         H.264 Only - Block AV1 / HEVC / VP9
 // @namespace    local.media.codec.filter
 // @version      1.0.0
 // @description  Prefer H.264 video and reject explicitly identified non-H.264 video codecs.
 // @match        *://*/*
 // @run-at       document-start
 // @sandbox      raw
 // @grant        none
 // ==/UserScript==

(() => {
    'use strict';

    const win = typeof window !== 'undefined' ? window : null;
    if (!win) return;

    const guardKey = Symbol.for('tm.h264-only.codec-filter.v1');
    if (win[guardKey]) return;

    try {
        Object.defineProperty(win, guardKey, {
            value: true,
            configurable: false,
            enumerable: false,
            writable: false
        });
    } catch (_) {
        // Continue if the page prevents setting the guard.
    }

    // Enable this only when debugging is needed.
    const DEBUG = false;

    const logBlocked = (api, value) => {
        if (DEBUG && win.console &&
            typeof win.console.debug === 'function') {
            win.console.debug(`[H.264 Only] blocked ${api}:`, value);
        }
    };

    // Known audio and auxiliary codecs are allowed.
    const AUDIO_OR_AUX_CODEC_RE =
        /^(?:mp4a|opus|vorbis|flac|alac|ac-3|ec-3|ac-4|mp3|samr|sawb|lpcm|ulaw|alaw|dtsc|dtse|dtsx|dtsh|mha1|mha2|mhm1|mhm2|iamf|wvtt|stpp|cea608|cea708)(?:[.\-]|$)/i;

    // H.264 / AVC codec identifiers.
    const H264_CODEC_RE = /^(?:avc1|avc3)(?:\.|$)/i;

    function asString(value) {
        try {
            return String(value);
        } catch (_) {
            return '';
        }
    }

    function parseMimeType(input) {
        const type = asString(input);
        const semicolon = type.indexOf(';');

        const mime = (
            semicolon === -1
                ? type
                : type.slice(0, semicolon)
        ).trim().toLowerCase();

        // Parse quoted or unquoted codecs parameters.
        const match =
            /(?:^|;)\s*codecs\s*=\s*(?:"([^"]*)"|'([^']*)'|([^;]*))/i
                .exec(type);

        if (!match) {
            return { mime, codecs: null };
        }

        const raw = match[1] ?? match[2] ?? match[3] ?? '';

        const codecs = raw
            .split(',')
            .map(codec =>
                codec.trim()
                    .replace(/^['"]|['"]$/g, '')
                    .toLowerCase()
            )
            .filter(Boolean);

        return { mime, codecs };
    }

    function isH264Codec(codec) {
        return H264_CODEC_RE.test(String(codec || '').trim());
    }

    function isAudioOrAuxCodec(codec) {
        return AUDIO_OR_AUX_CODEC_RE.test(
            String(codec || '').trim()
        );
    }

    /**
     * Reject explicitly identified non-H.264 video.
     *
     * Examples:
     *   video/mp4; codecs="avc1.640028, mp4a.40.2" -> allowed
     *   video/mp4; codecs="av01.0.08M.08"         -> blocked
     *   video/webm; codecs="vp09.00.10.08"        -> blocked
     *   video/mp4; codecs="hev1.1.6.L93.B0"       -> blocked
     *   video/mp4; codecs="hvc1.1.6.L93.B0"       -> blocked
     *
     * MIME types with no codecs parameter are left alone.
     */
    function shouldBlockMimeType(input) {
        const { mime, codecs } = parseMimeType(input);

        if (!codecs || codecs.length === 0) {
            return false;
        }

        if (mime.startsWith('video/')) {
            const hasH264 = codecs.some(isH264Codec);

            const hasOtherVideoOrUnknownCodec = codecs.some(
                codec =>
                    !isH264Codec(codec) &&
                    !isAudioOrAuxCodec(codec)
            );

            // A video MIME type must explicitly include H.264.
            // Mixed H.264 + non-H.264 video is also rejected.
            return !hasH264 || hasOtherVideoOrUnknownCodec;
        }

        // Preserve known audio/auxiliary types. Reject other codec
        // identifiers in non-video or multiplexed MIME types.
        return codecs.some(
            codec =>
                !isH264Codec(codec) &&
                !isAudioOrAuxCodec(codec)
        );
    }

    function makeNotSupportedError(message) {
        try {
            return new win.DOMException(
                message,
                'NotSupportedError'
            );
        } catch (_) {
            const error = new Error(message);
            error.name = 'NotSupportedError';
            return error;
        }
    }

    // Preserve the original method, descriptor and `this` binding.
    function patchMethod(owner, methodName, makeWrapper) {
        if (!owner) return false;

        const descriptor =
            Object.getOwnPropertyDescriptor(owner, methodName);

        if (!descriptor ||
            typeof descriptor.value !== 'function') {
            return false;
        }

        if (descriptor.value.__h264OnlyWrapped === true) {
            return true;
        }

        const original = descriptor.value;
        const wrapped = makeWrapper(original);

        try {
            Object.defineProperty(wrapped, '__h264OnlyWrapped', {
                value: true,
                configurable: false,
                enumerable: false,
                writable: false
            });

            Object.defineProperty(owner, methodName, {
                ...descriptor,
                value: wrapped
            });

            return true;
        } catch (_) {
            try {
                owner[methodName] = wrapped;
                return owner[methodName] === wrapped;
            } catch (_) {
                return false;
            }
        }
    }

    // 1. Native HTML media playback and source capability checks.
    if (win.HTMLMediaElement &&
        win.HTMLMediaElement.prototype) {
        patchMethod(
            win.HTMLMediaElement.prototype,
            'canPlayType',
            original => function (type) {
                if (shouldBlockMimeType(type)) {
                    logBlocked(
                        'HTMLMediaElement.canPlayType',
                        type
                    );
                    return '';
                }

                return Reflect.apply(original, this, arguments);
            }
        );
    }

    // 2. Media Source Extensions (MSE).
    const mediaSourceConstructors = [
        win.MediaSource,
        win.WebKitMediaSource,
        win.ManagedMediaSource
    ].filter(Boolean);

    const seenPrototypes = new Set();

    for (const MediaSourceCtor of mediaSourceConstructors) {
        patchMethod(
            MediaSourceCtor,
            'isTypeSupported',
            original => function (type) {
                if (shouldBlockMimeType(type)) {
                    logBlocked('MediaSource.isTypeSupported', type);
                    return false;
                }

                return Reflect.apply(original, this, arguments);
            }
        );

        const proto = MediaSourceCtor.prototype;

        if (!proto || seenPrototypes.has(proto)) {
            continue;
        }

        seenPrototypes.add(proto);

        // Last line of defense when a player ignores isTypeSupported().
        patchMethod(
            proto,
            'addSourceBuffer',
            original => function (type) {
                if (shouldBlockMimeType(type)) {
                    logBlocked('MediaSource.addSourceBuffer', type);

                    throw makeNotSupportedError(
                        'H.264 Only: non-H.264 video MIME type rejected.'
                    );
                }

                return Reflect.apply(original, this, arguments);
            }
        );
    }

    // Also reject later codec changes in an existing SourceBuffer.
    if (win.SourceBuffer && win.SourceBuffer.prototype) {
        patchMethod(
            win.SourceBuffer.prototype,
            'changeType',
            original => function (type) {
                if (shouldBlockMimeType(type)) {
                    logBlocked('SourceBuffer.changeType', type);

                    throw makeNotSupportedError(
                        'H.264 Only: non-H.264 video MIME type rejected.'
                    );
                }

                return Reflect.apply(original, this, arguments);
            }
        );
    }

    // 3. MediaCapabilities API.
    const mediaCapabilitiesPrototype =
        (win.MediaCapabilities &&
            win.MediaCapabilities.prototype) ||
        (win.navigator && win.navigator.mediaCapabilities
            ? Object.getPrototypeOf(
                win.navigator.mediaCapabilities
            )
            : null);

    patchMethod(
        mediaCapabilitiesPrototype,
        'decodingInfo',
        original => function (configuration) {
            const videoType =
                configuration &&
                configuration.video &&
                configuration.video.contentType;

            if (typeof videoType === 'string' &&
                shouldBlockMimeType(videoType)) {
                logBlocked(
                    'MediaCapabilities.decodingInfo',
                    videoType
                );

                return Promise.resolve({
                    supported: false,
                    smooth: false,
                    powerEfficient: false
                });
            }

            return Reflect.apply(original, this, arguments);
        }
    );

    // 4. WebCodecs fallback used by some custom video players.
    if (win.VideoDecoder) {
        patchMethod(
            win.VideoDecoder,
            'isConfigSupported',
            original => function (config) {
                if (
                    config &&
                    typeof config.codec === 'string' &&
                    !isH264Codec(config.codec)
                ) {
                    logBlocked(
                        'VideoDecoder.isConfigSupported',
                        config.codec
                    );

                    return Promise.resolve({
                        config: { ...config },
                        supported: false
                    });
                }

                return Reflect.apply(original, this, arguments);
            }
        );

        if (win.VideoDecoder.prototype) {
            patchMethod(
                win.VideoDecoder.prototype,
                'configure',
                original => function (config) {
                    if (
                        config &&
                        typeof config.codec === 'string' &&
                        !isH264Codec(config.codec)
                    ) {
                        logBlocked(
                            'VideoDecoder.configure',
                            config.codec
                        );

                        throw makeNotSupportedError(
                            'H.264 Only: non-H.264 VideoDecoder configuration rejected.'
                        );
                    }

                    return Reflect.apply(
                        original,
                        this,
                        arguments
                    );
                }
            );
        }
    }
})();
