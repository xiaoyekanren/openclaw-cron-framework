---
name: openclaw-cron-framework
description: "OpenClaw 定时任务框架 v2.0。用于创建、管理、执行定时任务，自动发送报告。当以下情况时使用此 Skill：(1) 需要添加新的定时任务（晨间简报、系统监控、数据备份等）(2) 需要查看/执行/管理现有定时任务 (3) 需要配置 crontab 定时执行 (4) 用户提到定时任务、cron、自动执行、定时报告 (5) 需要任务执行后自动发送通知（支持飞书、Telegram、Discord 等）"
---

## ⚙️ 首次使用配置（必读！）

**克隆框架后，必须修改以下配置才能使用：**

### 1. 用户 ID 配置

搜索所有脚本中的 `ou_xxx` 或 `ou_你的用户ID`，替换为你的飞书用户 ID：
- `task-framework.sh`: `REPORT_TARGET`
- `send-report.sh`: `REPORT_TARGET`
- `task-wrapper.sh`: `FEISHU_USER`
- `morning-brief.sh`: `FEISHU_USER`

**获取你的飞书 ID**：飞书 → 点击头像 → 个人资料页查看（格式：`ou_xxx`）

### 2. 目录路径配置

搜索并替换 `${CRON_DIR:-${HOME:-/home/zzm}/.openclaw/cron}`，改为你的实际路径：
- 脚本中的 `CRON_DIR`、`FRAMEWORK_DIR`
- 任务文件 `tasks/*.task` 中的 `TASK_SCRIPT`

### 3. 环境变量快速配置

在 crontab 中设置环境变量即可覆盖默认值：
```bash
# 在 crontab 顶部添加
CRON_DIR="/你的/路径/.openclaw/cron"
REPO_DIR="/你的/仓库/目录"
REPORT_TARGET="ou_你的用户ID"
OPENCLAW_CMD="/usr/local/bin/openclaw"

# 然后执行任务
0 8 * * * /你的/路径/task-framework.sh run morning-brief
```

### 4. npm 代理（如需要）

`check-openclaw-update.sh` 中的代理配置：
```bash
export npm_config_proxy="http://你的代理:端口"
export npm_config_https_proxy="http://你的代理:端口"
```

---

# OpenClaw 定时任务框架 v2.0

## 🚨 核心架构（v2.0 重构后）

**设计原则**：执行 + 报告一体化

| 组件 | 职责 | 说明 |
|------|------|------|
| **task-framework.sh** | 执行 + 发送 | 只负责执行脚本和发送报告，不生成报告内容 |
| **任务脚本 (.sh)** | 业务逻辑 + 报告 | 脚本自己输出完整 Markdown 报告 |
| **任务定义 (.task)** | 元数据 | 定义任务描述和脚本路径 |

**执行流程**：
```
1. 到达预定时间
2. 框架执行脚本 → 捕获 stdout
3. 执行成功 → 发送脚本 stdout（完整报告）
4. 执行失败 → 发送错误日志
```

**关键变化**（vs v1.0）：
- ❌ 移除框架生成报告的逻辑（400+ 行 → 230 行）
- ✅ 脚本自己输出完整 Markdown 报告
- ✅ 框架极简，责任清晰，易于扩展
- ✅ **渠道无关**：支持飞书、Telegram、Discord、Slack 等任意 OpenClaw 渠道

### task-wrapper.sh - 环境变量包装器

**用途**：确保任务脚本在 cron 环境下有正确的环境变量（PATH、HOME 等）。

**何时使用**：
- 在 crontab 中直接调用任务脚本时
- 需要确保脚本能找到 node、npm、openclaw 等命令时

**用法**：
```bash
# 方式 1: 通过包装器执行任务脚本
${CRON_DIR:-${HOME:-/home/zzm}/.openclaw/cron}/task-wrapper.sh ${CRON_DIR:-${HOME:-/home/zzm}/.openclaw/cron}/your-task.sh

# 方式 2: 通过框架执行（框架内部已处理环境变量）
${CRON_DIR:-${HOME:-/home/zzm}/.openclaw/cron}/task-framework.sh run your-task
```

**包装器会自动设置**：
- `HOME=${HOME:-/home/zzm}`
- `PATH` 包含 node、npm、openclaw 等命令路径
- 日志输出重定向

## 🌐 渠道配置

**环境变量**（可选，默认使用当前渠道配置）：
```bash
export REPORT_CHANNEL="feishu"     # 渠道：feishu, telegram, discord, slack, signal, whatsapp
export REPORT_TARGET="ou_xxx"      # 目标用户/群组 ID（根据渠道而定）
```

**crontab 配置示例**：
```bash
# 使用默认渠道（当前配置）
0 8 * * * ${CRON_DIR:-${HOME:-/home/zzm}/.openclaw/cron}/task-framework.sh run morning-brief

# 指定 Telegram 渠道
0 8 * * * REPORT_CHANNEL=telegram REPORT_TARGET="-1001234567890" ${CRON_DIR:-${HOME:-/home/zzm}/.openclaw/cron}/task-framework.sh run morning-brief
```

---

## 📁 目录结构

```
${CRON_DIR:-${HOME:-/home/zzm}/.openclaw/cron}/
├── task-framework.sh          # 框架主脚本（v2.0）
├── task-wrapper.sh            # 包装器（cron 环境环境变量配置）
├── send-report.sh             # 报告发送脚本
├── tasks/                     # 任务定义目录
│   ├── check-openclaw.task    # OpenClaw 检查任务
│   ├── morning-brief.task     # 晨间简报
│   ├── update-repos.task      # 仓库更新
│   └── your-task.task         # 你的任务
├── logs/                      # 日志目录
│   ├── check-openclaw_20260320_080500.log
│   └── morning-brief_20260320_080000.log
├── reports/                   # 任务报告备份目录
├── morning-brief.sh           # 晨间简报脚本
├── check-openclaw-update.sh   # OpenClaw 检查脚本
├── update-all.sh              # 仓库更新脚本
└── README.md                  # 详细文档
```

---

## 🎯 命令详解

### task-framework.sh 用法

```bash
${CRON_DIR:-${HOME:-/home/zzm}/.openclaw/cron}/task-framework.sh <command> [options]
```

### 命令列表

| 命令 | 用法 | 说明 |
|------|------|------|
| `list` | `task-framework.sh list` | 列出所有已注册任务 |
| `run` | `task-framework.sh run <task_name>` | 执行单个任务 |
| `run-all` | `task-framework.sh run-all` | 依次执行所有任务（测试用） |
| `status` | `task-framework.sh status` | 查看最近执行状态 |

### 详细说明

#### list - 列出任务
```bash
$ ./task-framework.sh list
check-openclaw   - OpenClaw 版本检查
morning-brief    - 晨间简报
update-repos     - 仓库代码自动更新
```

#### run - 执行任务
```bash
# 执行单个任务
./task-framework.sh run morning-brief

# 可选：指定报告渠道
REPORT_CHANNEL=telegram REPORT_TARGET="-1001234567890" ./task-framework.sh run morning-brief
```

#### run-all - 批量执行
```bash
# 按注册顺序依次执行所有任务
./task-framework.sh run-all
```

#### status - 查看状态
```bash
$ ./task-framework.sh status
任务名            状态    执行时间
check-openclaw    ✅成功  2026-03-24 08:05
morning-brief     ✅成功  2026-03-24 08:00
update-repos      ✅成功  2026-03-24 08:00
```

---

## 🎯 快速索引：意图 → 命令

| 用户意图 | 命令 | 说明 |
|---------|------|------|
| 查看所有任务 | `task-framework.sh list` | 列出已注册任务 |
| 执行单个任务 | `task-framework.sh run <task_name>` | 手动执行测试 |
| 执行所有任务 | `task-framework.sh run-all` | 批量执行（测试用） |
| 查看任务状态 | `task-framework.sh status` | 查看最近执行状态 |
| 添加新任务 | 创建 .task 文件 | 见下方"添加任务" |
| 查看执行日志 | `cat logs/<task>_<timestamp>.log` | 查看详细输出 |

---

## 📝 添加新任务（4 步走）

### 步骤 1: 创建任务脚本

在 `${CRON_DIR:-${HOME:-/home/zzm}/.openclaw/cron}/` 目录下创建脚本：

```bash
#!/bin/bash
# ${CRON_DIR:-${HOME:-/home/zzm}/.openclaw/cron}/your-task.sh

# 你的业务逻辑
echo "## 📋 任务报告"
echo ""
echo "执行时间：$(date '+%Y-%m-%d %H:%M')"
echo ""
echo "### 执行结果"
echo "- ✅ 项目 1: 完成"
echo "- ✅ 项目 2: 完成"
echo ""
echo "---"
echo "本次执行耗时：$(date +%s) 秒"

exit 0  # 成功返回 0，失败返回非 0
```

**关键点**：
- ✅ 脚本必须输出完整 Markdown 报告（框架直接发送）
- ✅ 成功返回 `exit 0`，失败返回 `exit 1`
- ✅ 使用绝对路径或确保环境变量正确

### 步骤 2: 创建任务定义

在 `tasks/` 目录下创建 `.task` 文件：

```bash
# ${CRON_DIR:-${HOME:-/home/zzm}/.openclaw/cron}/tasks/your-task.task

TASK_DESC="你的任务描述"
TASK_SCRIPT="${CRON_DIR:-${HOME:-/home/zzm}/.openclaw/cron}/your-task.sh"
```

**格式要求**：
- `TASK_DESC`: 任务描述（用于日志和状态显示）
- `TASK_SCRIPT`: 脚本绝对路径

### 步骤 3: 测试任务

```bash
${CRON_DIR:-${HOME:-/home/zzm}/.openclaw/cron}/task-framework.sh run your-task
```

检查：
- ✅ 脚本执行成功
- ✅ 报告格式正确
- ✅ 飞书消息发送成功

### 步骤 4: 添加到 crontab

```bash
crontab -e

# 添加任务（每天早上 8 点执行）
0 8 * * * ${CRON_DIR:-${HOME:-/home/zzm}/.openclaw/cron}/task-framework.sh run your-task
```

**crontab 示例**：
```bash
# 晨间简报（每天 8:00）
0 8 * * * ${CRON_DIR:-${HOME:-/home/zzm}/.openclaw/cron}/task-framework.sh run morning-brief

# OpenClaw 检查（每天 8:05）
5 8 * * * ${CRON_DIR:-${HOME:-/home/zzm}/.openclaw/cron}/task-framework.sh run check-openclaw

# 仓库更新（每天 8:00）
0 8 * * * ${CRON_DIR:-${HOME:-/home/zzm}/.openclaw/cron}/task-framework.sh run update-repos
```

---

## 📋 现有任务列表

| 任务名 | 描述 | 脚本 | 执行时间 |
|--------|------|------|---------|
| `check-openclaw` | OpenClaw 版本检查 | check-openclaw-update.sh | 每天 08:05 |
| `morning-brief` | 晨间简报（新闻 + 任务 + 推荐） | morning-brief.sh | 每天 08:00 |
| `update-repos` | 仓库代码自动更新 | update-all.sh | 每天 08:00 |

---

## 📊 报告格式规范

**框架要求**：脚本必须输出完整 Markdown 报告，框架直接发送。

### 成功报告示例

```markdown
## 🔧 OpenClaw 更新检查

执行时间：2026-03-20 08:05
状态：✅ 已是最新版本
当前版本：2026.3.13

---
本次执行耗时：3 秒
```

### 失败报告示例（框架自动生成）

```markdown
## ❌ 任务执行失败

任务名称：your-task
执行时间：2026-03-20 08:00

### 错误日志
```
/path/to/script.sh: line 10: command not found
```

---
请检查脚本或联系管理员。
```

---

## 🔍 故障排查

### 问题 1: 任务不执行

**检查步骤**：
```bash
# 1. 检查 crontab
crontab -l

# 2. 检查 cron 服务
systemctl status cron

# 3. 检查 cron 日志
sudo grep CRON /var/log/syslog | tail -20

# 4. 手动测试
${CRON_DIR:-${HOME:-/home/zzm}/.openclaw/cron}/task-framework.sh run your-task
```

### 问题 2: 报告未发送

**检查步骤**：
```bash
# 1. 检查 pending 报告
cat /tmp/pending-task-report.txt

# 2. 检查渠道配置和授权
# 飞书
openclaw message send --channel feishu --target "ou_xxx" --message "测试"
# Telegram
openclaw message send --channel telegram --target "-1001234567890" --message "测试"
# Discord
openclaw message send --channel discord --target "channel_id" --message "测试"

# 3. 查看框架日志
cat ${CRON_DIR:-${HOME:-/home/zzm}/.openclaw/cron}/logs/your-task_*.log
```

### 问题 3: 渠道配置错误

**症状**：报告发送到错误的渠道或用户

**解决方案**：
```bash
# 检查环境变量
echo $REPORT_CHANNEL
echo $REPORT_TARGET

# 在 crontab 中明确指定
0 8 * * * REPORT_CHANNEL=feishu REPORT_TARGET="ou_xxx" ${CRON_DIR:-${HOME:-/home/zzm}/.openclaw/cron}/task-framework.sh run your-task
```

### 问题 3: 脚本执行失败

**常见原因**：
- ❌ 环境变量缺失（PATH、HOME）
- ❌ 脚本没有执行权限
- ❌ 命令路径不是绝对路径

**解决方案**：
```bash
# 1. 添加执行权限
chmod +x ${CRON_DIR:-${HOME:-/home/zzm}/.openclaw/cron}/your-task.sh

# 2. 脚本开头添加环境变量
#!/bin/bash
export HOME="${HOME:-/home/zzm}"
export PATH="${PATH:-/usr/local/...}/bin"

# 3. 使用绝对路径
OPENCLAW_CMD="${OPENCLAW_CMD:-openclaw}"
$OPENCLAW_CMD message send ...
```

---

## 🛠️ 最佳实践

### 1. 脚本规范

```bash
#!/bin/bash
set -e  # 遇到错误立即退出

# 环境变量（cron 环境必需）
export HOME="${HOME:-/home/zzm}"
export PATH="${PATH:-/usr/local/...}/bin"

# 使用绝对路径（如需要调用 openclaw 命令）
OPENCLAW_CMD="${OPENCLAW_CMD:-openclaw}"

# 业务逻辑
echo "## 📋 报告标题"
echo ""
echo "执行时间：$(date '+%Y-%m-%d %H:%M')"
echo ""
# ... 你的逻辑

exit 0
```

### 2. 渠道配置

**默认**：使用当前 OpenClaw 配置的渠道

**自定义渠道**（在 `.task` 文件中）：
```bash
# ${CRON_DIR:-${HOME:-/home/zzm}/.openclaw/cron}/tasks/your-task.task
TASK_DESC="你的任务"
TASK_SCRIPT="${CRON_DIR:-${HOME:-/home/zzm}/.openclaw/cron}/your-task.sh"

# 可选：指定渠道（覆盖默认配置）
export REPORT_CHANNEL="telegram"
export REPORT_TARGET="-1001234567890"
```

**或在 crontab 中指定**：
```bash
# 发送到 Telegram
0 8 * * * REPORT_CHANNEL=telegram REPORT_TARGET="-1001234567890" ${CRON_DIR:-${HOME:-/home/zzm}/.openclaw/cron}/task-framework.sh run your-task
```

### 3. 任务命名

- ✅ 使用小写字母和连字符：`backup-db.task`
- ❌ 避免大写字母和空格：`Backup DB.task`

### 4. 日志管理

- 框架自动保留 7 天日志
- 手动清理：`find logs/ -name "*.log" -mtime +7 -delete`

### 5. 幂等性

任务应可重复执行，无副作用：
```bash
# ✅ 好的做法
mkdir -p /path/to/dir  # 已存在也不报错

# ❌ 避免
mkdir /path/to/dir  # 已存在会报错
```

---

## 📚 扩展示例

### 示例 1: 系统监控任务

```bash
# 1. 创建脚本
cat > ${CRON_DIR:-${HOME:-/home/zzm}/.openclaw/cron}/system-monitor.sh << 'EOF'
#!/bin/bash
export HOME="${HOME:-/home/zzm}"
export PATH="${PATH:-/usr/local/...}/bin"

echo "## 🖥️ 系统监控报告"
echo ""
echo "执行时间：$(date '+%Y-%m-%d %H:%M')"
echo ""
echo "### CPU 使用率"
echo "- 使用率：$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')%"
echo ""
echo "### 内存使用率"
echo "- 使用率：$(free | grep Mem | awk '{printf("%.2f%%", $3/$2 * 100.0)}')"
echo ""
echo "### 磁盘使用率"
echo "- 根分区：$(df -h / | tail -1 | awk '{print $5}')"
echo ""
echo "---"
echo "监控完成"
EOF
chmod +x ${CRON_DIR:-${HOME:-/home/zzm}/.openclaw/cron}/system-monitor.sh

# 2. 创建任务定义
cat > ${CRON_DIR:-${HOME:-/home/zzm}/.openclaw/cron}/tasks/system-monitor.task << 'EOF'
TASK_DESC="系统监控"
TASK_SCRIPT="${CRON_DIR:-${HOME:-/home/zzm}/.openclaw/cron}/system-monitor.sh"
EOF

# 3. 测试
${CRON_DIR:-${HOME:-/home/zzm}/.openclaw/cron}/task-framework.sh run system-monitor

# 4. 添加到 crontab（每小时执行）
echo "0 * * * * ${CRON_DIR:-${HOME:-/home/zzm}/.openclaw/cron}/task-framework.sh run system-monitor" | crontab -
```

### 示例 2: 数据库备份任务

```bash
# 1. 创建脚本
cat > ${CRON_DIR:-${HOME:-/home/zzm}/.openclaw/cron}/backup-db.sh << 'EOF'
#!/bin/bash
export HOME="${HOME:-/home/zzm}"
export PATH="${PATH:-/usr/local/...}/bin"

BACKUP_DIR="${HOME:-/home/zzm}/backups"
mkdir -p "$BACKUP_DIR"

echo "## 💾 数据库备份报告"
echo ""
echo "执行时间：$(date '+%Y-%m-%d %H:%M')"
echo ""

# 备份逻辑
mysqldump -u root --all-databases > "$BACKUP_DIR/all-databases-$(date +%Y%m%d).sql"

if [ $? -eq 0 ]; then
    echo "### 备份结果"
    echo "- ✅ 备份成功"
    echo "- 文件：$BACKUP_DIR/all-databases-$(date +%Y%m%d).sql"
    echo "- 大小：$(du -h $BACKUP_DIR/all-databases-$(date +%Y%m%d).sql | cut -f1)"
else
    echo "### 备份结果"
    echo "- ❌ 备份失败"
    exit 1
fi

echo ""
echo "---"
echo "备份完成"
EOF
chmod +x ${CRON_DIR:-${HOME:-/home/zzm}/.openclaw/cron}/backup-db.sh

# 2. 创建任务定义
cat > ${CRON_DIR:-${HOME:-/home/zzm}/.openclaw/cron}/tasks/backup-db.task << 'EOF'
TASK_DESC="数据库备份"
TASK_SCRIPT="${CRON_DIR:-${HOME:-/home/zzm}/.openclaw/cron}/backup-db.sh"
EOF

# 3. 添加到 crontab（每天凌晨 2 点）
echo "0 2 * * * ${CRON_DIR:-${HOME:-/home/zzm}/.openclaw/cron}/task-framework.sh run backup-db" | crontab -
```

---

## 🔗 相关文档

- `${CRON_DIR:-${HOME:-/home/zzm}/.openclaw/cron}/README.md` - 框架详细说明
- `${HOME:-/home/zzm}/.openclaw/workspace/TOOLS.md` - 定时任务最佳实践
- `${HOME:-/home/zzm}/.openclaw/workspace/HEARTBEAT.md` - 心跳检查任务配置

---

## 版本历史

- **v2.0** (2026-03-20): 架构重构
  - 框架简化（400+ 行 → 230 行）
  - 脚本自己生成完整报告
  - 移除框架生成报告逻辑
  - 责任更清晰，易于扩展

- **v1.0** (2026-03-17): 初始版本
  - 支持任务定义和执行
  - 自动生成飞书报告
  - 自动清理日志
