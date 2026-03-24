#!/bin/bash

# 检查 OpenClaw 自身更新
# 用法：check-openclaw-update.sh
# 返回：0=已是最新，1=有更新/失败

# 环境变量（可通过同名环境变量覆盖）
export HOME="${HOME:-/home/zzm}"
export PATH="${PATH:-/usr/local/node-v24.14.0-linux-x64/bin:/home/zzm/.npm-global/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin}"

# npm 代理配置（可通过环境变量覆盖）
export npm_config_proxy="${npm_config_proxy:-http://192.168.99.4:7890}"
export npm_config_https_proxy="${npm_config_https_proxy:-http://192.168.99.4:7890}"

# 命令路径（可通过环境变量覆盖）
OPENCLAW_CMD="${OPENCLAW_CMD:-openclaw}"
NPM_CMD="${NPM_CMD:-npm}"

CURRENT_VERSION=$($OPENCLAW_CMD --version 2>/dev/null | grep -oP '\d{4}\.\d+\.\d+' | head -1)

# 使用 curl 查询 npm registry（避免 npm 命令在 cron 环境中的网络问题）
LATEST_VERSION=$(curl -s "https://registry.npmjs.org/openclaw/latest" 2>/dev/null | grep -oP '"version"\s*:\s*"\K[^"]+' | head -1)

# 如果 curl 失败，回退到 npm 命令
if [ -z "$LATEST_VERSION" ]; then
    LATEST_VERSION=$($NPM_CMD view openclaw version 2>/dev/null)
fi

# 生成完整报告
if [ -z "$CURRENT_VERSION" ]; then
    cat <<EOF
## 🔧 OpenClaw 更新检查

**执行时间**: $(date '+%Y-%m-%d %H:%M')
**状态**: ❌ 无法获取当前版本

---
EOF
    exit 1
elif [ -z "$LATEST_VERSION" ]; then
    cat <<EOF
## 🔧 OpenClaw 更新检查

**执行时间**: $(date '+%Y-%m-%d %H:%M')
**状态**: ⚠️ 无法获取最新版本（网络问题）
**当前版本**: $CURRENT_VERSION

---
EOF
    exit 1
elif [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
    cat <<EOF
## 🔧 OpenClaw 更新检查

**执行时间**: $(date '+%Y-%m-%d %H:%M')
**状态**: ✅ 已是最新版本
**当前版本**: $CURRENT_VERSION

---
EOF
    exit 0
else
    cat <<EOF
## 🔧 OpenClaw 有新版本

**执行时间**: $(date '+%Y-%m-%d %H:%M')
**状态**: 🔄 有更新可用
**当前版本**: $CURRENT_VERSION
**最新版本**: $LATEST_VERSION

**升级命令**: \`npm install -g openclaw\`

---
EOF
    exit 0
fi
