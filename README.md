# OpenClaw 定时任务框架 v1.0

## 快速开始

### 1. 查看可用任务

```bash
${CRON_DIR:-${HOME:-~}/.openclaw/cron}/task-framework.sh list
```

### 2. 执行单个任务

```bash
${CRON_DIR:-${HOME:-~}/.openclaw/cron}/task-framework.sh run <task_name>
```

### 3. 执行所有任务

```bash
${CRON_DIR:-${HOME:-~}/.openclaw/cron}/task-framework.sh run-all
```

### 4. 查看任务状态

```bash
${CRON_DIR:-${HOME:-~}/.openclaw/cron}/task-framework.sh status
```

---

## 添加新任务

### 步骤 1: 创建任务脚本

在 `${CRON_DIR:-${HOME:-~}/.openclaw/cron}/` 目录下创建你的脚本，例如：

```bash
#!/bin/bash
# ${CRON_DIR:-${HOME:-~}/.openclaw/cron}/backup-database.sh

echo "开始备份数据库..."
# 你的备份逻辑
echo "备份完成"
```

### 步骤 2: 创建任务定义

在 `tasks/` 目录下创建 `.task` 文件：

```bash
# ${CRON_DIR:-${HOME:-~}/.openclaw/cron}/tasks/backup-db.task

TASK_DESC="数据库备份"
TASK_SCRIPT="${CRON_DIR:-${HOME:-~}/.openclaw/cron}/backup-database.sh"
```

### 步骤 3: 测试任务

```bash
${CRON_DIR:-${HOME:-~}/.openclaw/cron}/task-framework.sh run backup-db
```

### 步骤 4: 添加到 crontab

```bash
crontab -e

# 添加任务（每天凌晨 2 点执行）
0 2 * * * ${CRON_DIR:-${HOME:-~}/.openclaw/cron}/task-framework.sh run backup-db
```

---

## 目录结构

```
${CRON_DIR:-${HOME:-~}/.openclaw/cron}/
├── task-framework.sh          # 框架主脚本
├── tasks/                     # 任务定义目录
│   ├── update-repos.task      # 仓库更新任务
│   ├── check-openclaw.task    # OpenClaw 检查任务
│   └── your-task.task         # 你的任务
├── logs/                      # 日志目录
│   ├── update-repos_20260317_234220.log
│   └── check-openclaw_20260317_234221.log
├── reports/                   # 报告目录（可选）
├── update-all.sh              # 仓库更新脚本
├── check-openclaw-update.sh   # OpenClaw 检查脚本
└── README.md                  # 本文档
```

---

## 任务定义格式

`.task` 文件是简单的 bash 脚本，定义两个变量：

```bash
# 任务描述（用于报告）
TASK_DESC="任务描述"

# 任务脚本（绝对路径）
TASK_SCRIPT="/path/to/your/script.sh"
```

---

## 报告格式

框架会自动生成以下格式的报告：

### 仓库更新报告

```markdown
## 📦 仓库代码更新报告

执行时间：2026-03-17 23:42
仓库总数：11 个
有更新：1 个
无更新：10 个

### 🔄 有更新的仓库
- 🔄 iotdb (master) - 已更新
  版本：d8dfe1b917 → 67ddff930b

### ✅ 无更新的仓库
- ✅ file_download (master) - 已是最新

---
本次执行耗时：35 秒
```

### OpenClaw 检查报告

```markdown
## 🔧 OpenClaw 更新检查

执行时间：2026-03-17 23:42
状态：✅ 已是最新版本
当前版本：2026.3.13

---
本次执行耗时：3 秒
```

---

## Crontab 配置

使用提供的示例配置：

```bash
# 查看示例
cat ${CRON_DIR:-${HOME:-~}/.openclaw/cron}/crontab.example

# 应用到 crontab
cat ${CRON_DIR:-${HOME:-~}/.openclaw/cron}/crontab.example | crontab -
```

---

## 环境变量

框架已自动配置 cron 环境所需的环境变量：

```bash
export HOME="${HOME:-~}"
export PATH="/usr/local/node-v24.14.0-linux-x64/bin:${HOME:-~}/.npm-global/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
```

---

## 日志管理

- **日志位置**: `${CRON_DIR:-${HOME:-~}/.openclaw/cron}/logs/`
- **自动清理**: 保留 7 天，自动删除旧日志
- **查看详细日志**: `cat ${CRON_DIR:-${HOME:-~}/.openclaw/cron}/logs/<task_name>_<timestamp>.log`

---

## 故障排查

### 任务不执行

1. 检查 crontab: `crontab -l`
2. 检查 cron 服务：`systemctl status cron`
3. 检查 cron 日志：`sudo grep CRON /var/log/syslog | tail -20`
4. 手动测试：`${CRON_DIR:-${HOME:-~}/.openclaw/cron}/task-framework.sh run <task_name>`

### 报告未发送

1. 检查飞书授权
2. 查看 `/tmp/pending-task-report.txt`
3. 手动发送：`openclaw message send --channel feishu --target "ou_xxx" --message "测试"`

---

## 最佳实践

1. **任务命名**: 使用小写字母和连字符，如 `backup-db.task`
2. **日志输出**: 脚本应输出详细信息到 stdout/stderr
3. **退出码**: 成功返回 0，失败返回非 0
4. **幂等性**: 任务应可重复执行，无副作用
5. **超时控制**: 长时间任务应设置超时

---

## 扩展示例

### 示例 1: 添加系统监控任务

```bash
# 1. 创建脚本
cat > ${CRON_DIR:-${HOME:-~}/.openclaw/cron}/system-monitor.sh << 'EOF'
#!/bin/bash
echo "CPU 使用率：$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')%"
echo "内存使用率：$(free | grep Mem | awk '{printf("%.2f%%", $3/$2 * 100.0)}')"
echo "磁盘使用率：$(df -h / | tail -1 | awk '{print $5}')"
EOF
chmod +x ${CRON_DIR:-${HOME:-~}/.openclaw/cron}/system-monitor.sh

# 2. 创建任务定义
cat > ${CRON_DIR:-${HOME:-~}/.openclaw/cron}/tasks/system-monitor.task << 'EOF'
TASK_DESC="系统监控"
TASK_SCRIPT="${CRON_DIR:-${HOME:-~}/.openclaw/cron}/system-monitor.sh"
EOF

# 3. 测试
${CRON_DIR:-${HOME:-~}/.openclaw/cron}/task-framework.sh run system-monitor
```

### 示例 2: 添加数据库备份任务

```bash
# 1. 创建脚本
cat > ${CRON_DIR:-${HOME:-~}/.openclaw/cron}/backup-db.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="${HOME:-~}/backups"
mkdir -p "$BACKUP_DIR"
mysqldump -u root --all-databases > "$BACKUP_DIR/all-databases-$(date +%Y%m%d).sql"
echo "备份完成：$BACKUP_DIR/all-databases-$(date +%Y%m%d).sql"
EOF
chmod +x ${CRON_DIR:-${HOME:-~}/.openclaw/cron}/backup-db.sh

# 2. 创建任务定义
cat > ${CRON_DIR:-${HOME:-~}/.openclaw/cron}/tasks/backup-db.task << 'EOF'
TASK_DESC="数据库备份"
TASK_SCRIPT="${CRON_DIR:-${HOME:-~}/.openclaw/cron}/backup-db.sh"
EOF

# 3. 添加到 crontab（每天凌晨 2 点）
echo "0 2 * * * ${CRON_DIR:-${HOME:-~}/.openclaw/cron}/task-framework.sh run backup-db" | crontab -
```

---

## 版本历史

- **v1.0** (2026-03-17): 初始版本
  - 支持任务定义和执行
  - 自动生成飞书报告
  - 包含执行耗时
  - 自动清理日志

---

## 技术支持

遇到问题？检查以下文件：
- `${HOME:-~}/.openclaw/workspace/TOOLS.md` - 定时任务最佳实践
- `${HOME:-~}/.openclaw/workspace/memory/2026-03-17-cron-best-practices.md` - 详细指南
