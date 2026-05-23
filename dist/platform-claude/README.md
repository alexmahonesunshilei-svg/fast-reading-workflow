# Claude / Claude Code 安装

> **最完整体验**——bash 脚本全部可用 + 50+ MCP 集成（Zotero / agentmemory / Word / Gmail 等）。

---

## 5 分钟安装

```bash
# 1. 下载或克隆 skill
cd ~/Desktop
git clone https://github.com/sunshilei/fast-reading-workflow.git 快速阅读
# 或：解压 zip 到 ~/Desktop/快速阅读/

# 2. 一键安装
cd ~/Desktop/快速阅读/dist
bash install.sh

# 3. 填配置
open ~/Desktop/快速阅读/config.json
# 把所有 ? 改成你的真实信息

# 4. 检测依赖
bash ~/Desktop/快速阅读/脚本/init.sh
# 看报告，按提示 brew install / pip install 缺的

# 5. 开始第一次精读
bash ~/Desktop/快速阅读/脚本/通用提取.sh ~/Desktop/你的论文.pdf
# 然后在 Claude Code 里说：「按 v4.6 流程精读」
```

---

## 注册为全局 Skill（可选）

让所有 Claude Code 会话都能识别这个 skill：

```bash
mkdir -p ~/.claude/skills/fast-reading
cp ~/Desktop/快速阅读/dist/SKILL.md ~/.claude/skills/fast-reading/
cp -r ~/Desktop/快速阅读/模板 ~/.claude/skills/fast-reading/
```

之后任何 Claude Code 会话里说"按快速阅读流程"，Claude 都能识别。

---

## 推荐启用的 MCP

如果你想要完整体验，建议安装这些 MCP（按优先级）：

| MCP | 干啥 | 强烈推荐 |
|---|---|---|
| **zotero** | 自动同步解读卡到 Zotero 库 | ⭐⭐⭐ |
| **agentmemory** | 跨会话长期记忆 | ⭐⭐⭐ |
| **word** | 直接编辑 docx 而不是重新生成 | ⭐⭐ |
| **scholar-citation-verification** | 第三方核验引用 | ⭐⭐ |
| **mermaid** | 概念图渲染为 SVG | ⭐ |

安装方式见 https://docs.claude.com/en/docs/claude-code/mcp

---

## 触发口令速查

| 你说 | Claude 做 |
|---|---|
| "按 v4.6 流程精读 <PDF>" | 全流程 5 步 |
| "继续上次的精读" | 看 库/ 最新目录续做 |
| "搜库 福柯" | `bash 脚本/搜库.sh "福柯"` |
| "这张卡审一下" | 真实性 + 打分 |
| "存进 Zotero" | 5 步 MCP（需启用 zotero）|
| "存进长记" / "记住这个" | 4 类候选问你 |
| "全文找不到" | 自动降级到变体 G 公开信息卡 |
| "整理一下文件夹" | dry-run 列清单 |
| "并行跑这一批" | `bash 脚本/批量解读.sh <dir>` |
| "概念图" | 生成 mermaid §11 |

---

## 文件位置约定

```
~/Desktop/快速阅读/          ← 工作流根
├── config.json              ← 你的个人配置（必填）
├── README.md                ← 工作流自身的 README
├── 库/                      ← 阅读成果（按类型分子目录）
├── 模板/                    ← 7 变体模板
├── 脚本/                    ← 16 个 bash 脚本
├── 收件箱/                  ← 待处理文件暂存
├── 解读卡片/                ← 历史归档
├── 清理日志/                ← 整理脚本的日志
└── dist/                    ← 跨平台 skill 包（含 SKILL.md）

~/.claude/skills/fast-reading/   ← Claude Code 全局 skill 注册位置（可选）
~/.Trash/                        ← 整理文件夹 --apply 时移到这里（可恢复）
```

---

## 故障排查

### 跑 init.sh 报 "node:docx 未装"

```bash
npm install -g docx
```

### 跑通用提取.sh 报 "trafilatura 未装"

```bash
pip3 install --user trafilatura beautifulsoup4
```

### Claude 不识别"按 v4.6 流程精读"

- 在对话开头加："你是学术快速阅读教练（见 ~/Desktop/快速阅读/dist/SKILL.md）"
- 或者把 SKILL.md 文件拖进 Claude Code 让它读

### 整理文件夹.sh 误删了文件

```bash
# 文件在 ~/.Trash/ 里，按时间戳找
ls -lt ~/.Trash/ | head -20
# 拖回 Finder 即恢复
```

---

## 进阶玩法

### 跨项目复用 Skill

```bash
# 把这个 skill 挂到其他项目
ln -s ~/.claude/skills/fast-reading ~/your-other-project/.claude/skills/
```

### 自定义新变体

编辑 `模板/解读卡模板套件_v4.md`，加变体 H/I/J... 模板会被 Claude 自动识别。

### Hook 进 Claude Code 的 PreToolUse

在 `~/.claude/settings.json` 加：
```json
{
  "hooks": {
    "PreToolUse": {
      "Bash": "echo '⚠️ 删除前确认' && exit 1"
    }
  }
}
```

防止破坏性操作（已有 dry-run 保护，这是双保险）。

---

*Claude 适配版 · v1 · 2026-05-23*
