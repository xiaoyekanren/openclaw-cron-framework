#!/bin/bash

# 定时任务包装器（任务 A + B 整合）
# 用法：task-wrapper.sh "<任务脚本>" "<任务描述>"
# 功能：执行任务 + 发送报告（无论成功失败）

# 环境变量（可通过同名环境变量覆盖）
export HOME="${HOME:-/home/zzm}"
export PATH="${PATH:-/usr/local/node-v24.14.0-linux-x64/bin:/home/zzm/.npm-global/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin}"

# 命令路径（可通过环境变量覆盖）
OPENCLAW_CMD="${OPENCLAW_CMD:-openclaw}"

# 飞书用户 ID（可通过环境变量覆盖）
FEISHU_USER="${FEISHU_USER:-ou_xxx}"

# 目录配置（可通过环境变量覆盖）
CRON_DIR="${CRON_DIR:-/home/zzm/.openclaw/cron}"

# 日志目录
mkdir -p "$CRON_DIR/logs"

TASK_SCRIPT="$1"
TASK_DESC="$2"
TASK_ID=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$CRON_DIR/logs/${TASK_ID}.log"

# 记录开始时间（秒级时间戳）
START_TIME=$(date +%s)
START_DATETIME=$(date '+%Y-%m-%d %H:%M:%S')

echo "=== 任务开始 ==="
echo "任务：$TASK_DESC"
echo "时间：$START_DATETIME"
echo "日志：$LOG_FILE"
echo ""

# 执行主任务，捕获输出和退出码
{
    echo "=== 执行开始：$(date '+%Y-%m-%d %H:%M:%S') ==="
    bash -c "$TASK_SCRIPT"
    EXIT_CODE=$?
    echo "=== 执行结束：$(date '+%Y-%m-%d %H:%M:%S') ==="
    echo "退出码：$EXIT_CODE"
} > "$LOG_FILE" 2>&1

cat "$LOG_FILE"

echo ""
echo "退出码：$EXIT_CODE"
echo ""

# 计算执行耗时
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# ========== 生成报告并发送 ==========
echo "📤 生成报告并发送..."

if [[ "$TASK_DESC" == *"仓库"* ]]; then
    # 仓库更新任务 - 读取详细日志
    DETAIL_LOG="$CRON_DIR/logs/update-details-$(date +%Y%m%d).log"
    
    if [ "$EXIT_CODE" -eq 0 ] && [ -f "$DETAIL_LOG" ]; then
        HAS_UPDATES=$(grep -c "🔄" "$DETAIL_LOG" 2>/dev/null || echo "0")
        TOTAL_REPOS=$(wc -l < "$DETAIL_LOG" 2>/dev/null || echo "0")
        
        if [ "$HAS_UPDATES" -gt 0 ]; then
            # 有更新 - 详细列出
            UPDATED_LIST=$(grep "🔄" "$DETAIL_LOG" | sed 's/^🔄 /- 🔄 /')
            UPTODATE_LIST=$(grep "✅" "$DETAIL_LOG" | sed 's/^✅ /- ✅ /')
            
            REPORT=$(cat <<EOF
## 📦 仓库代码更新报告

**执行时间**: $(date '+%Y-%m-%d %H:%M')
**仓库总数**: $TOTAL_REPOS 个
**有更新**: $HAS_UPDATES 个
**无更新**: $((TOTAL_REPOS - HAS_UPDATES)) 个

### 🔄 有更新的仓库
$UPDATED_LIST

### ✅ 无更新的仓库
$UPTODATE_LIST

---
**本次执行耗时**: ${DURATION} 秒
EOF
)
        else
            # 无更新 - 简单列出
            UPTODATE_LIST=$(grep "✅" "$DETAIL_LOG" | sed 's/^✅ /- ✅ /')
            
            REPORT=$(cat <<EOF
## 📦 仓库代码更新报告

**执行时间**: $(date '+%Y-%m-%d %H:%M')
**状态**: ✅ 所有仓库无更新

### 仓库列表
$UPTODATE_LIST

---
**本次执行耗时**: ${DURATION} 秒
EOF
)
        fi
    else
        REPORT=$(cat <<EOF
## ❌ 仓库代码更新失败

**任务**: $TASK_DESC  
**退出码**: $EXIT_CODE  
**错误**: $(tail -10 "$LOG_FILE" | head -5)

---
**本次执行耗时**: ${DURATION} 秒
EOF
)
    fi
    
elif [[ "$TASK_DESC" == *"OpenClaw"* ]]; then
    # OpenClaw 更新检查
    if [ "$EXIT_CODE" -eq 0 ]; then
        VERSION=$(grep "已是最新版本" "$LOG_FILE" 2>/dev/null | grep -oP '\d{4}\.\d+\.\d+' | head -1)
        REPORT=$(cat <<EOF
## 🔧 OpenClaw 检查更新

**执行时间**: $(date '+%Y-%m-%d %H:%M')
**状态**: ✅ 已是最新版本
**当前版本**: $VERSION

---
**本次执行耗时**: ${DURATION} 秒
EOF
)
    else
        VERSION_INFO=$(grep -E "当前版本|最新版本|升级命令" "$LOG_FILE" 2>/dev/null)
        CURRENT_VER=$(echo "$VERSION_INFO" | grep "当前版本" | grep -oP '\d{4}\.\d+\.\d+' | head -1)
        LATEST_VER=$(echo "$VERSION_INFO" | grep "最新版本" | grep -oP '\d{4}\.\d+\.\d+' | head -1)
        if [ -n "$CURRENT_VER" ] && [ -n "$LATEST_VER" ]; then
            if [ "$CURRENT_VER" = "$LATEST_VER" ]; then
                # 版本相同，实际是最新的
                REPORT=$(cat <<EOF
## 🔧 OpenClaw 检查更新

**执行时间**: $(date '+%Y-%m-%d %H:%M')
**状态**: ✅ 已是最新版本
**当前版本**: $CURRENT_VER

---
**本次执行耗时**: ${DURATION} 秒
EOF
)
            else
                # 确实有更新
                REPORT=$(cat <<EOF
## 🔧 OpenClaw 检查更新

**执行时间**: $(date '+%Y-%m-%d %H:%M')
**状态**: 🔄 有更新可用
**当前版本**: $CURRENT_VER
**最新版本**: $LATEST_VER

**升级命令**: `npm install -g openclaw`

---
**本次执行耗时**: ${DURATION} 秒
EOF
)
            fi
        else
            REPORT=$(cat <<EOF
## ❌ OpenClaw 检查更新失败

**执行时间**: $(date '+%Y-%m-%d %H:%M')
**错误**: $(tail -5 "$LOG_FILE")

---
**本次执行耗时**: ${DURATION} 秒
EOF
)
        fi
    fi
else
    # 通用报告
    if [ "$EXIT_CODE" -ne 0 ]; then
        ERROR_LOG=$(tail -50 "$LOG_FILE" 2>/dev/null | head -40)
        REPORT=$(cat <<EOF
## ❌ 定时任务执行失败

**任务**: $TASK_DESC  
**退出码**: $EXIT_CODE  
**检查时间**: $(date '+%Y-%m-%d %H:%M:%S')  
**日志文件**: \`$LOG_FILE\`

### 错误日志
\`\`\`
$ERROR_LOG
\`\`\`

---
**本次执行耗时**: ${DURATION} 秒
EOF
)
    else
        REPORT=$(cat <<EOF
## ✅ 定时任务执行成功

**任务**: $TASK_DESC  
**状态**: 成功  
**检查时间**: $(date '+%Y-%m-%d %H:%M:%S')

---
**本次执行耗时**: ${DURATION} 秒
EOF
)
    fi
fi

# 发送消息
$OPENCLAW_CMD message send --channel feishu --target "$FEISHU_USER" --message "$REPORT" 2>/dev/null || {
    echo "$REPORT" > /tmp/pending-task-report.txt
    echo "⚠️  消息已写入 /tmp/pending-task-report.txt"
}

echo "✅ 报告已发送"

# 清理日志（保留 7 天）
find "$CRON_DIR/logs" -name "*.log" -mtime +7 -delete 2>/dev/null

echo ""
echo "✅ 任务执行完成（日志已保存，报告已发送）"
