#!/bin/bash

# 每天自动拉取所有仓库最新代码
# 用法：update-all.sh [日志文件]

# 环境变量（可通过同名环境变量覆盖）
export HOME="${HOME:-/home/zzm}"
export PATH="${PATH:-/usr/local/node-v24.14.0-linux-x64/bin:/home/zzm/.npm-global/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin}"

# 目录配置（可通过环境变量覆盖）
CRON_DIR="${CRON_DIR:-/home/zzm/.openclaw/cron}"
REPO_DIR="${REPO_DIR:-/home/zzm/Srcs/repository}"

LOG_FILE="${1:-/tmp/git-update-$$.log}"
DETAIL_LOG="$CRON_DIR/logs/update-details-$(date +%Y%m%d).log"

echo "=== 更新开始：$(date '+%Y-%m-%d %H:%M:%S') ==="

# 清空详细日志
> "$DETAIL_LOG"

# 更新 repository 目录下的仓库
update_repos() {
    local base_dir="$1"
    
    if [ ! -d "$base_dir" ]; then
        return
    fi
    
    cd "$base_dir" || return
    
    for dir in */; do
        if [ -d "$dir/.git" ]; then
            cd "$dir" || continue
            
            REPO_NAME="${dir%/}"
            
            # 切换到 master 分支（如果存在）
            if git show-ref --verify --quiet refs/heads/master; then
                git checkout master >/dev/null 2>&1
                BRANCH="master"
            else
                BRANCH="$(git branch --show-current)"
            fi
            
            # 获取更新前 commit
            BEFORE_COMMIT=$(git rev-parse --short HEAD 2>/dev/null)
            
            # 拉取最新代码
            PULL_RESULT=$(git pull 2>&1)
            
            # 获取更新后 commit
            AFTER_COMMIT=$(git rev-parse --short HEAD 2>/dev/null)
            
            # 分析更新内容
            if echo "$PULL_RESULT" | grep -q "Already up to date"; then
                echo "✅ ${REPO_NAME} (${BRANCH}) - 已是最新" >> "$DETAIL_LOG"
            elif echo "$PULL_RESULT" | grep -qE "(Updating|Fast-forward)"; then
                # 获取变更统计
                CHANGES=$(echo "$PULL_RESULT" | grep -E "^\d+ files? changed" | head -1)
                
                # 获取详细变更（如果有）
                if [ -n "$BEFORE_COMMIT" ] && [ -n "$AFTER_COMMIT" ] && [ "$BEFORE_COMMIT" != "$AFTER_COMMIT" ]; then
                    COMMIT_LOG=$(git log --oneline ${BEFORE_COMMIT}..${AFTER_COMMIT} 2>/dev/null | head -5)
                    echo "🔄 ${REPO_NAME} (${BRANCH}) - 已更新" >> "$DETAIL_LOG"
                    echo "   版本：${BEFORE_COMMIT} → ${AFTER_COMMIT}" >> "$DETAIL_LOG"
                    if [ -n "$COMMIT_LOG" ]; then
                        echo "   提交记录:" >> "$DETAIL_LOG"
                        echo "$COMMIT_LOG" | sed 's/^/   - /' >> "$DETAIL_LOG"
                    fi
                else
                    echo "🔄 ${REPO_NAME} (${BRANCH}) - 已更新" >> "$DETAIL_LOG"
                fi
            else
                echo "⚠️ ${REPO_NAME} (${BRANCH}) - $PULL_RESULT" >> "$DETAIL_LOG"
            fi
            
            cd ..
        fi
    done
}

# 更新 repository 目录（skills 已移回此处）
update_repos "$REPO_DIR"

# 记录结束时间
END_TIME=$(date '+%Y-%m-%d %H:%M:%S')

# 统计更新情况
total_repos=$(grep -cE "^(✅|🔄)" "$DETAIL_LOG" 2>/dev/null | tr -d ' ' || echo "0")
has_updates=$(grep -c "🔄" "$DETAIL_LOG" 2>/dev/null | tr -d ' ' || echo "0")
uptodate=$(grep -c "✅" "$DETAIL_LOG" 2>/dev/null | tr -d ' ' || echo "0")

# 确保是数字
total_repos=${total_repos:-0}
has_updates=${has_updates:-0}
uptodate=${uptodate:-0}

# 生成完整报告
echo "## 📦 仓库代码更新"
echo ""
echo "**执行时间**: $(date '+%Y-%m-%d %H:%M')"
echo ""

# 有更新的仓库逐个汇报
if [ "$has_updates" -gt 0 ]; then
    grep "🔄" "$DETAIL_LOG" | while read -r line; do
        echo "- $line"
        echo ""
    done
    echo "**其他仓库**: 无更新"
    echo ""
else
    echo "**状态**: 无更新"
    echo ""
fi

echo "---"

# 始终返回 0
exit 0
t 0
