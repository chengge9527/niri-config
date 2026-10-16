

 // ==UserScript==
 // @name         抖音直播源监测器
 // @namespace    https://tampermonkey.net/
 // @version      1.0.0
 // @description  监测抖音直播页面的 FLV、M3U8 等媒体请求并提取 URL
 // @match        https://douyin.com/*
 // @match        https://*.douyin.com/*
 // @match        http://douyin.com/*
 // @match        http://*.douyin.com/*
 // @run-at       document-start
 // @grant        unsafeWindow
 // @grant        GM_setClipboard
 // ==/UserScript==

(function () {
    'use strict';

    const page = typeof unsafeWindow !== 'undefined'
        ? unsafeWindow
        : window;

    const MAX_ITEMS = 100;
    const MAX_DISPLAY = 40;
    const MAX_RESPONSE_LENGTH = 4 * 1024 * 1024;

    const records = new Map();

    let enabled = true;
    let ui = null;
    let listEl = null;
    let countEl = null;
    let statusEl = null;
    let toggleBtn = null;

    // Identify supported media URL extensions.
    function getMediaType(rawUrl) {
        try {
            const url = new URL(rawUrl, page.location.href);

            if (!['http:', 'https:'].includes(url.protocol)) {
                return null;
            }

            let path = url.pathname.toLowerCase();

            try {
                path = decodeURIComponent(path);
            } catch (_) {}

            const match = path.match(/\.(m3u8|flv|mpd|mp4)$/i);
            return match ? match[1].toLowerCase() : null;
        } catch (_) {
            return null;
        }
    }

    // Extract complete media URLs from text or serialized JSON.
    function scanText(text, source) {
        if (!enabled || typeof text !== 'string' || !text) {
            return;
        }

        // Normalize common JSON string escape sequences.
        const normalized = text
            .replace(/\\u0026/gi, '&')
            .replace(/\\u003d/gi, '=')
            .replace(/\\\//g, '/');

        const matches =
            normalized.match(/https?:\/\/[^\s"'<>]+/gi) || [];

        for (let candidate of matches) {
            candidate = candidate
                .trim()
                .replace(/[),;\]}]+$/g, '');

            addUrl(candidate, source);
        }
    }

    // Keep only real media URLs and deduplicate by their full URL.
    function addUrl(rawUrl, source) {
        if (!enabled || typeof rawUrl !== 'string') {
            return;
        }

        const url = rawUrl
            .replace(/\\u0026/gi, '&')
            .replace(/\\u003d/gi, '=')
            .replace(/\\\//g, '/')
            .trim();

        const type = getMediaType(url);

        if (!type) {
            return;
        }

        let hostname;

        try {
            hostname = new URL(url).hostname;
        } catch (_) {
            return;
        }

        if (records.has(url)) {
            records.delete(url);
        }

        records.set(url, {
            url,
            type,
            hostname,
            source,
            time: new Date().toLocaleTimeString()
        });

        // Bound memory consumption.
        while (records.size > MAX_ITEMS) {
            records.delete(records.keys().next().value);
        }

        render();
    }

    // Only inspect JSON-like responses from live-related endpoints.
    function isLiveApi(rawUrl) {
        try {
            const path = new URL(
                rawUrl,
                page.location.href
            ).pathname;

            return /webcast|room|live|stream|reflow/i.test(path);
        } catch (_) {
            return false;
        }
    }

    // --------------------------------------------------
    // 1. Monitor fetch requests and responses.
    // --------------------------------------------------
    try {
        const originalFetch = page.fetch;

        if (typeof originalFetch === 'function' &&
            !originalFetch.__douyinStreamMonitor) {

            const monitoredFetch = function (input, ...args) {
                let requestUrl = '';

                try {
                    requestUrl = typeof input === 'string'
                        ? input
                        : input.url;
                } catch (_) {}

                addUrl(requestUrl, 'fetch 请求');

                return originalFetch.apply(this, [input, ...args])
                    .then(response => {
                        addUrl(response.url, 'fetch 响应');

                        if (!enabled ||
                            !isLiveApi(requestUrl)) {
                            return response;
                        }

                        let contentType = '';
                        let contentLength = 0;

                        try {
                            contentType =
                                response.headers.get('content-type') || '';

                            contentLength = Number(
                                response.headers.get('content-length') || 0
                            );
                        } catch (_) {}

                        if (
                            !/json|text\/plain/i.test(contentType) ||
                            contentLength > MAX_RESPONSE_LENGTH
                        ) {
                            return response;
                        }

                        // Read a clone so the page's original body remains
                        // available to the site's player.
                        try {
                            response.clone().text().then(text => {
                                if (text.length <= MAX_RESPONSE_LENGTH) {
                                    scanText(text, 'fetch JSON 响应');
                                }
                            }).catch(() => {});
                        } catch (_) {}

                        return response;
                    });
            };

            Object.defineProperty(
                monitoredFetch,
                '__douyinStreamMonitor',
                { value: true }
            );

            page.fetch = monitoredFetch;
        }
    } catch (error) {
        console.warn('[直播源监测] fetch 监测初始化失败', error);
    }

    // --------------------------------------------------
    // 2. Monitor XMLHttpRequest requests and responses.
    // --------------------------------------------------
    try {
        const XHR = page.XMLHttpRequest;
        const proto = XHR && XHR.prototype;

        if (proto && !proto.__douyinStreamMonitor) {
            const originalOpen = proto.open;
            const originalSend = proto.send;

            proto.open = function (method, url, ...args) {
                try {
                    this.__dsMonitorUrl = String(url || '');
                    addUrl(this.__dsMonitorUrl, 'XHR 请求');
                } catch (_) {}

                return originalOpen.call(
                    this, method, url, ...args
                );
            };

            proto.send = function (...args) {
                const xhr = this;

                try {
                    const requestUrl = xhr.__dsMonitorUrl || '';

                    if (isLiveApi(requestUrl)) {
                        xhr.addEventListener('load', function () {
                            if (!enabled) {
                                return;
                            }

                            addUrl(xhr.responseURL, 'XHR 响应');

                            try {
                                let text = '';

                                if (xhr.responseType === 'json') {
                                    text = JSON.stringify(xhr.response);
                                } else if (
                                    xhr.responseType === '' ||
                                    xhr.responseType === 'text'
                                ) {
                                    text = xhr.responseText;
                                }

                                if (
                                    typeof text === 'string' &&
                                    text.length <= MAX_RESPONSE_LENGTH
                                ) {
                                    scanText(text, 'XHR JSON 响应');
                                }
                            } catch (_) {}
                        }, { once: true });
                    } else {
                        addUrl(requestUrl, 'XHR 请求');
                    }
                } catch (_) {}

                return originalSend.apply(xhr, args);
            };

            Object.defineProperty(
                proto,
                '__douyinStreamMonitor',
                { value: true }
            );
        }
    } catch (error) {
        console.warn('[直播源监测] XHR 监测初始化失败', error);
    }

    // --------------------------------------------------
    // 3. Monitor the browser's resource timing entries.
    // --------------------------------------------------
    function inspectResources(entries) {
        if (!enabled) {
            return;
        }

        for (const entry of entries) {
            addUrl(entry.name, '浏览器资源监测');
        }
    }

    try {
        // Include resources that were requested before the panel appeared.
        inspectResources(page.performance.getEntriesByType('resource'));

        const Observer = page.PerformanceObserver;

        if (Observer) {
            const observer = new Observer(list => {
                inspectResources(list.getEntries());
            });

            try {
                observer.observe({
                    type: 'resource',
                    buffered: true
                });
            } catch (_) {
                observer.observe({ entryTypes: ['resource'] });
            }
        }
    } catch (error) {
        console.warn('[直播源监测] 资源监测初始化失败', error);
    }

    // --------------------------------------------------
    // 4. Clipboard support.
    // --------------------------------------------------
    function copyText(text) {
        try {
            if (typeof GM_setClipboard === 'function') {
                GM_setClipboard(text, 'text');
                return Promise.resolve(true);
            }
        } catch (_) {}

        try {
            return page.navigator.clipboard
                .writeText(text)
                .then(() => true)
                .catch(() => false);
        } catch (_) {
            return Promise.resolve(false);
        }
    }

    // --------------------------------------------------
    // 5. Floating panel UI.
    // --------------------------------------------------
    function buildUI() {
        if (ui || !document.body) {
            return;
        }

        const host = document.createElement('div');

        host.id = 'douyin-stream-monitor-root';

        Object.assign(host.style, {
            position: 'fixed',
            top: '90px',
            right: '16px',
            zIndex: '2147483647'
        });

        const shadow = host.attachShadow({ mode: 'open' });

        shadow.innerHTML = `
            <style>
                * {
                    box-sizing: border-box;
                }

                .panel {
                    width: min(460px, calc(100vw - 32px));
                    max-height: min(75vh, 680px);
                    display: flex;
                    flex-direction: column;
                    color: #e5e7eb;
                    background: #18181b;
                    border: 1px solid #3f3f46;
                    border-radius: 12px;
                    box-shadow: 0 12px 40px #0008;
                    font: 13px/1.5 system-ui, sans-serif;
                    overflow: hidden;
                }

                .header, .toolbar {
                    display: flex;
                    align-items: center;
                    gap: 8px;
                    padding: 10px 12px;
                    border-bottom: 1px solid #3f3f46;
                }

                .header {
                    justify-content: space-between;
                }

                .title {
                    font-size: 14px;
                    font-weight: 700;
                }

                .status {
                    display: block;
                    color: #a1a1aa;
                    font-size: 11px;
                }

                button {
                    padding: 5px 9px;
                    border: 1px solid #52525b;
                    border-radius: 6px;
                    background: #27272a;
                    color: #f4f4f5;
                    cursor: pointer;
                    font: inherit;
                    white-space: nowrap;
                }

                button:hover {
                    background: #3f3f46;
                }

                .toolbar {
                    flex-wrap: wrap;
                    border-bottom: 0;
                    padding-bottom: 4px;
                }

                .count {
                    margin-left: auto;
                    color: #a1a1aa;
                }

                .hint {
                    padding: 0 12px 8px;
                    color: #a1a1aa;
                    font-size: 11px;
                }

                .list {
                    overflow-y: auto;
                    overscroll-behavior: contain;
                    padding: 0 8px 8px;
                }

                .item {
                    margin-top: 6px;
                    padding: 8px;
                    border: 1px solid #3f3f46;
                    border-radius: 8px;
                    background: #202024;
                }

                .item-head {
                    display: flex;
                    align-items: center;
                    gap: 8px;
                    margin-bottom: 4px;
                }

                .type {
                    color: #93c5fd;
                    font-weight: 700;
                }

                .meta {
                    min-width: 0;
                    color: #a1a1aa;
                    font-size: 11px;
                    overflow-wrap: anywhere;
                }

                .copy {
                    margin-left: auto;
                }

                .url {
                    display: block;
                    max-height: 56px;
                    overflow: auto;
                    color: #d4d4d8;
                    font: 11px/1.5 ui-monospace, monospace;
                    overflow-wrap: anywhere;
                    user-select: text;
                }

                .empty {
                    padding: 24px 10px;
                    color: #a1a1aa;
                    text-align: center;
                }

                .footer {
                    padding: 8px 12px;
                    color: #71717a;
                    border-top: 1px solid #3f3f46;
                    font-size: 11px;
                }
            </style>

            <section class="panel">
                <header class="header">
                    <div>
                        <div class="title">抖音直播源监测</div>
                        <span class="status" id="status">监测中</span>
                    </div>
                    <button id="toggle">暂停</button>
                </header>

                <div class="toolbar">
                    <button id="copyAll">复制全部</button>
                    <button id="clear">清空</button>
                    <span class="count" id="count">0 条</span>
                </div>

                <div class="hint">
                    打开直播并开始播放，捕获到的媒体地址会显示在下面。
                </div>

                <div class="list" id="list">
                    <div class="empty">等待发现直播源……</div>
                </div>

                <div class="footer">
                    URL 可能包含临时签名，失效后请重新抓取。
                </div>
            </section>
        `;

        document.body.appendChild(host);

        ui = host;
        listEl = shadow.getElementById('list');
        countEl = shadow.getElementById('count');
        statusEl = shadow.getElementById('status');
        toggleBtn = shadow.getElementById('toggle');

        toggleBtn.addEventListener('click', () => {
            enabled = !enabled;

            toggleBtn.textContent = enabled ? '暂停' : '继续';
            statusEl.textContent = enabled ? '监测中' : '已暂停';

            render();
        });

        shadow.getElementById('clear').addEventListener('click', () => {
            records.clear();
            render();
        });

        shadow.getElementById('copyAll').addEventListener(
            'click',
            async () => {
                const urls = [...records.keys()].join('\n');

                if (!urls) {
                    return;
                }

                const ok = await copyText(urls);
                shadow.getElementById('copyAll').textContent =
                    ok ? '已复制' : '复制失败';

                setTimeout(() => {
                    const btn = shadow.getElementById('copyAll');
                    if (btn) btn.textContent = '复制全部';
                }, 1200);
            }
        );

        render();
    }

    function render() {
        if (!listEl) {
            return;
        }

        countEl.textContent = `${records.size} 条`;

        listEl.replaceChildren();

        if (!records.size) {
            const empty = document.createElement('div');
            empty.className = 'empty';
            empty.textContent = enabled
                ? '等待发现直播源……'
                : '监测已暂停';
            listEl.appendChild(empty);
            return;
        }

        const items = [...records.values()]
            .reverse()
            .slice(0, MAX_DISPLAY);

        for (const item of items) {
            const row = document.createElement('article');
            row.className = 'item';

            const head = document.createElement('div');
            head.className = 'item-head';

            const type = document.createElement('span');
            type.className = 'type';
            type.textContent = item.type.toUpperCase();

            const meta = document.createElement('span');
            meta.className = 'meta';
            meta.textContent =
                `${item.hostname} · ${item.time} · ${item.source}`;

            const copy = document.createElement('button');
            copy.className = 'copy';
            copy.textContent = '复制';

            copy.addEventListener('click', async () => {
                const ok = await copyText(item.url);
                copy.textContent = ok ? '已复制' : '失败';

                setTimeout(() => {
                    copy.textContent = '复制';
                }, 1000);
            });

            const url = document.createElement('div');
            url.className = 'url';
            url.textContent = item.url;
            url.title = item.url;

            head.append(type, meta, copy);
            row.append(head, url);
            listEl.appendChild(row);
        }
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', buildUI, {
            once: true
        });
    } else {
        buildUI();
    }
})();
