#!/bin/bash
CACHE_TIMEOUT=600  # 600秒 = 10分钟

# 获取当前时间加600秒
time=$(date +"%H:%M:%S" -d "+${CACHE_TIMEOUT} seconds")
echo $time
