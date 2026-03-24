#!/bin/bash

# =============================================================================
# OpenClaw 定时任务框架 v2.0
# =============================================================================
# 设计理念：框架只负责执行和发送，报告内容由脚本自己决定
# 
# 流程：
# 1. 到达预定时间
# 2. 框架调用定时任务执行
# 3. 执行成功 → 发送脚本输出
# 4. 执行失败 → 发送错误信息
# =============================================================================

# 环境变量（可通过同名环境变量覆盖）
export HOME="${HOME:-/home/zzm}"
export PATH="${PATH:-/usr/local/node-v24.14.0-linux-x64/bin:/home/zzm/.npm-global/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin}"

# 命令路径（可通过环境变量覆盖）
OPENCLAW_CMD="${OPENCLAW_CMD:-openclaw}"

# 渠道配置（可通过环境变量覆盖）
# 支持：feishu, telegram, discord, slack, signal, whatsapp 等
REPORT_CHANNEL="${REPORT_CHANNEL:-feishu}"
REPORT_TARGET="${REPORT_TARGET:-ou_xxx}"

# 目录配置（可通过环境变量覆盖）
CRON_DIR="${CRON_DIR:-/home/zzm/.openclaw/cron}"
FRAMEWORK_DIR="$CRON_DIR"
TASKS_DIR="$FRAMEWORK_DIR/tasks"
LOGS_DIR="$FRAMEWORK_DIR/logs"

# 创建必要目录
mkdir -p "$TASKS_DIR" "$LOGS_DIR"

# =============================================================================
# 核心函数
# =============================================================================

# 记录日志
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# 发送报告消息（支持任意渠道）
send_report() {
    local message="$1"
    $OPENCLAW_CMD message send --channel "$REPORT_CHANNEL" --target "$REPORT_TARGET" --message "$message" 2>/dev/null || {
        echo "$message" > /tmp/pending-task-report.txt
        log "⚠️  消息已写入 /tmp/pending-task-report.txt"
    }
}

# 执行任务
execute_task() {
    local task_name="$1"
    local task_script="$2"
    local task_desc="$3"
    
    log "▶️  开始执行任务：$task_name"
    
    # 记录开始时间
    local start_time=$(date +%s)
    local task_id=$(date +%Y%m%d_%H%M%S)
    local log_file="$LOGS_DIR/${task_name}_${task_id}.log"
    local stdout_file="$LOGS_DIR/${task_name}_${task_id}.stdout"
    
    # 执行任务：stdout 单独保存，stderr 写入日志
    {
        echo "=== 任务开始：$(date '+%Y-%m-%d %H:%M:%S') ==="
        echo "任务：$task_desc"
        echo "脚本：$task_script"
        echo ""
    } > "$log_file"
    
    # 执行脚本
    bash -c "$task_script" > "$stdout_file" 2>>"$log_file"
    local exit_code=$?
    
    # 追加任务结束信息到日志
    {
        echo ""
        echo "=== 任务结束：$(date '+%Y-%m-%d %H:%M:%S') ==="
        echo "退出码：$exit_code"
    } >> "$log_file"
    
    # 计算耗时
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log "✅ 任务完成：$task_name (耗时：${duration}秒)"
    
    # 发送报告
    if [ "$exit_code" = "0" ]; then
        # 执行成功：发送脚本输出
        local report=$(cat "$stdout_file")
        if [ -n "$report" ]; then
            send_report "$report"
            log "📤 报告已发送"
        else
            log "✓ 任务成功，无输出"
        fi
    else
        # 执行失败：发送错误信息
        local error_log=$(tail -50 "$log_file" | head -40)
        local report="## ❌ 定时任务：$task_desc 执行失败

**退出码**: $exit_code
**执行时间**: $(date '+%Y-%m-%d %H:%M')
**耗时**: ${duration} 秒

### 错误日志
\`\`\`
$error_log
\`\`\`"
        send_report "$report"
        log "📤 错误报告已发送"
    fi
    
    # 清理临时文件
    rm -f "$stdout_file"
    
    # 清理旧日志（保留 7 天）
    find "$LOGS_DIR" -name "*.log" -mtime +7 -delete 2>/dev/null
    
    return 0
}

# 加载任务
load_task() {
    local task_name="$1"
    local task_file="$TASKS_DIR/${task_name}.task"
    
    if [ ! -f "$task_file" ]; then
        log "❌ 任务不存在：$task_name"
        return 1
    fi
    
    # 读取任务配置
    source "$task_file"
    
    # 执行任务
    execute_task "$task_name" "$TASK_SCRIPT" "$TASK_DESC"
}

# 列出所有任务
list_tasks() {
    log "📋 已注册的任务："
    echo ""
    
    if [ ! -d "$TASKS_DIR" ] || [ -z "$(ls -A "$TASKS_DIR" 2>/dev/null)" ]; then
        echo "  (无任务)"
        return
    fi
    
    for task_file in "$TASKS_DIR"/*.task; do
        if [ -f "$task_file" ]; then
            source "$task_file"
            local task_name=$(basename "$task_file" .task)
            echo "  - $task_name: $TASK_DESC"
        fi
    done
}

# 执行所有任务
run_all() {
    log "🚀 开始执行所有任务"
    echo ""
    
    if [ ! -d "$TASKS_DIR" ] || [ -z "$(ls -A "$TASKS_DIR" 2>/dev/null)" ]; then
        log "⚠️  无任务可执行"
        return
    fi
    
    for task_file in "$TASKS_DIR"/*.task; do
        if [ -f "$task_file" ]; then
            local task_name=$(basename "$task_file" .task)
            load_task "$task_name"
            echo ""
            sleep 2  # 任务间隔
        fi
    done
    
    log "✅ 所有任务执行完成"
}

# 显示任务状态
show_status() {
    log "📊 任务执行状态"
    echo ""
    
    # 显示最近的日志
    local recent_logs=$(ls -t "$LOGS_DIR"/*.log 2>/dev/null | head -10)
    
    if [ -z "$recent_logs" ]; then
        echo "  (无执行记录)"
        return
    fi
    
    for log_file in $recent_logs; do
        local task_name=$(basename "$log_file" .log | cut -d'_' -f1)
        local exit_code=$(grep "退出码:" "$log_file" | tail -1 | awk '{print $2}')
        local status_icon="✅"
        [ "$exit_code" != "0" ] && status_icon="❌"
        
        echo "  $status_icon $task_name - $(basename "$log_file")"
    done
}

# 显示帮助
show_help() {
    cat <<EOF
OpenClaw 定时任务框架 v2.0

用法:
  $0 run <task_name>     # 执行单个任务
  $0 list                # 列出所有任务
  $0 status              # 查看任务状态
  $0 run-all             # 执行所有任务
  $0 help                # 显示帮助

任务定义:
  在 tasks/ 目录下创建 .task 文件

示例 .task 文件 (tasks/update-repos.task):
  TASK_DESC="仓库代码自动更新"
  TASK_SCRIPT="${CRON_DIR:-/home/zzm/.openclaw/cron}/update-all.sh"

当前配置:
  任务目录：$TASKS_DIR
  日志目录：$LOGS_DIR
EOF
}

# =============================================================================
# 主程序
# =============================================================================

case "${1:-}" in
    run)
        if [ -z "${2:-}" ]; then
            log "❌ 错误：请指定任务名称"
            show_help
            exit 1
        fi
        load_task "$2"
        ;;
    list)
        list_tasks
        ;;
    status)
        show_status
        ;;
    run-all)
        run_all
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        show_help
        exit 1
        ;;
esac
