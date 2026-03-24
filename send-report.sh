#!/bin/bash

# 发送定时任务失败报告
# 用法：send-report.sh "<任务描述>" "<退出码>" "<日志文件>"

# 环境变量（cron 环境必需）
export HOME="/home/zzm"
export PATH="/usr/local/node-v24.14.0-linux-x64/bin:/home/zzm/.npm-global/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# 绝对路径命令（仅非标准路径）
OPENCLAW_CMD="/home/zzm/.npm-global/bin/openclaw"

# 渠道配置（可通过环境变量覆盖）
# 支持：feishu, telegram, discord, slack, signal, whatsapp 等
REPORT_CHANNEL="${REPORT_CHANNEL:-feishu}"
REPORT_TARGET="${REPORT_TARGET:-ou_476c7862905aec59a12d19ebd8c7f6af}"

TASK_DESC="$1"
EXIT_CODE="$2"
LOG_FILE="$3"

# 读取错误日志（最后 50 行）
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
EOF
)

echo "$REPORT"

# 通过 openclaw 发送消息（支持任意渠道）
$OPENCLAW_CMD message send --channel "$REPORT_CHANNEL" --target "$REPORT_TARGET" --message "$REPORT" 2>/dev/null || {
    echo "$REPORT" > /tmp/pending-task-report.txt
}
