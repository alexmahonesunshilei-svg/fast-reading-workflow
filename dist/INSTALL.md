# 安装指南 · 三平台分别说明

> 选你的平台，跳到对应章节。Claude 最完整、GPT 中等、Gemini 基础。
> 三平台都至少有"核心精读"能力——差异在工具链。

---

## ⚡ 一键脚本（仅 Claude Code · macOS/Linux）

```bash
curl -L https://example.com/fastread-skill/install.sh | bash
# 或先下到本地
bash install.sh
```

跑完后：
1. 编辑 `~/Desktop/快速阅读/config.json` 填个人信息
2. 跑 `bash ~/Desktop/快速阅读/脚本/init.sh` 检测依赖
3. 在 Claude Code 里说"按 v4.6 流程精读 <PDF 路径>"

---

## 🅰️ Claude / Claude Code（推荐 · 最完整体验）

### 安装

```bash
# ① 下载 skill 包
mkdir -p ~/Desktop/快速阅读
cd ~/Desktop/快速阅读

# ② 复制文件（手动 / git clone / 解压 zip）
cp -r /path/to/fastread-skill/dist/* ./

# ③ 一键安装依赖
bash 脚本/init.sh

# ④ 填配置
cp config.template.json config.json
# 用编辑器打开 config.json，把 ? 改成你的真实信息
```

### Claude Code 注册

如果你想让这个 skill 对所有项目自动可用：

```bash
mkdir -p ~/.claude/skills/fast-reading
cp SKILL.md ~/.claude/skills/fast-reading/
cp -r templates ~/.claude/skills/fast-reading/
# 之后任何 Claude Code 会话都能识别这个 skill
```

### 使用

直接对 Claude Code 说：
- **"按 v4.6 流程精读 ~/Desktop/某论文.pdf"** → 全流程跑
- **"搜库 福柯"** → 跨库搜索
- **"这张卡审一下"** → 真实性 + 打分
- **"存进 Zotero"** → MCP 调用 5 步
- **"存进长记"** → agentmemory 4 类候选

### 依赖

- macOS 12+ / Linux
- Python 3.9+
- Node.js 18+
- bash 3.2+
- 可选：whisper.cpp（音视频）、ffmpeg、yt-dlp

---

## 🅱️ OpenAI Custom GPT

### 创建 GPT

1. 打开 https://chatgpt.com/gpts/editor
2. 点 **Create**
3. **Configure** 标签下：

**Name**: 学术快速阅读教练（Fast Reading Coach）

**Description**: 把任何材料走 7 变体三档精读，10 节结构化解读卡，自动挂载到博论章节。

**Instructions**: 复制粘贴 `SKILL.md` 全文 + 加这段：

```
## 平台特有适配（OpenAI）

你现在运行在 OpenAI Custom GPT 平台。bash 脚本不可用，请：

1. 用 code_interpreter 跑 Python 替代 bash 脚本
2. 用 browser 抓 URL / 多源检索
3. 用 file_search 跨知识库搜索
4. 用 user 上传的 config.json 读个人信息

具体翻译：
- 通用提取.sh    → Python: pypdf / ebooklib / python-docx / trafilatura
- 韩文学术源.sh  → Python requests + KCI/DBpia 公开 API
- 审查解读.sh    → Python re 正则核验
- 打分.sh        → Python 6 维评分逻辑（详见 scripts/打分.sh 里的 Python 段）
- 章节索引.sh    → Python glob + re 解析 §10
```

**Conversation starters**:
- 精读这篇 PDF（请上传）
- 这是付费墙论文，能做什么
- 搜我读过的卡里提到的"福柯"
- 给我审一下这张卡

**Knowledge**（上传文件）:
- `SKILL.md`
- `templates/解读卡模板套件_v4.md`
- `templates/术语词典.md`
- `config.template.json`（建议用户自己上传填好的版本）
- `scripts/打分.sh`（Python 段可直接被 code_interpreter 复用）

**Capabilities**:
- ✅ Web Browsing（多源检索需要）
- ✅ Code Interpreter（替代 bash）
- ⚠️ DALL·E（可选 · 不依赖）
- ✅ Actions（如需接 Zotero Web API）

### 使用

新对话直接上传 PDF + 说 "精读"，GPT 会按 SKILL.md 走完 5 步。

### 局限

- ❌ 没有本地文件系统 → 库/_论文章节索引.md 只能维护在你单独的 Google Drive / Dropbox
- ❌ 没有 MCP → Zotero 同步必须用 Custom Actions（OpenAPI schema）
- ❌ 不能跑 whisper.cpp → 音视频要先用 OpenAI Whisper API 转写

---

## 🆑 Google Gemini Gem

### 创建 Gem

1. 打开 https://gemini.google.com/gems
2. 点 **+ New Gem**
3. **Custom instructions**: 复制粘贴 `SKILL.md` 全文 + 加这段：

```
## 平台特有适配（Gemini）

你现在运行在 Google Gemini Gem 平台。请：

1. 用 google_search 替代 WebSearch
2. 用 code_execution（Python）替代 bash 脚本
3. 用 google_drive 读写文件（库/ 目录可放在 Drive 里）
4. 用 user 上传的 config.json 读个人信息

具体翻译同 OpenAI 段（bash → Python）。
```

**Knowledge / Files**: 同 OpenAI 段（上传 SKILL.md + templates/* + config.template.json）

### 使用

跟 Gem 对话时直接上传 PDF + 说"精读"。

### 优势

- ✅ Google Workspace 集成 → 自动存解读卡到 Docs
- ✅ Drive 文件系统可用 → 库/ 维护比 OpenAI 容易
- ✅ Vision 强 → 处理论文里的图表更精确

### 局限

- ❌ 没有 MCP → 同 OpenAI 段
- ❌ 上下文窗口在中文上不如 Claude

---

## 🔧 跨平台通用问题

### Q1：填了 config.json 但 LLM 还是问我信息？

A：刷新对话或重新上传 config.json。LLM 不会自动重读已上传的文件。

### Q2：付费墙锁文怎么办？

A：所有平台都支持变体 G 公开信息卡。LLM 会自动降级，明确标注限度，**不编造**。

### Q3：能跨平台同步库吗？

A：可以——把 `~/Desktop/快速阅读/库/` 同步到 iCloud / Dropbox / Google Drive，三平台都从那里读。

### Q4：bash 脚本翻译成 Python 麻烦吗？

A：不麻烦。**所有 bash 脚本里的核心逻辑已经是 Python**（heredoc 形式）。摘出来即可用。

### Q5：我的学校付费墙不一样怎么办？

A：编辑 `config.json` 的 `university.sso_domain` 字段。

---

## 进阶工作流

### 批量解读（一次喂 10 篇 PDF）

```bash
# Claude Code
bash 脚本/批量解读.sh ~/Desktop/待读/

# GPT/Gemini: 上传一个 zip，让 LLM 逐个处理
```

### 跨库搜索

```bash
bash 脚本/搜库.sh "关键词"
# GPT/Gemini: 用 file_search 在 knowledge 里搜
```

### 自动概念图

```bash
bash 脚本/生成概念图.sh <解读卡.md>
# 生成 mermaid 图追加到卡末尾
```

### 音视频转写

```bash
bash 脚本/音视频转写.sh --install    # 首次
bash 脚本/音视频转写.sh ~/podcast.mp3
```

---

## 卸载

```bash
# Claude Code
rm -rf ~/Desktop/快速阅读
rm -rf ~/.claude/skills/fast-reading

# GPT / Gemini
# 在平台 UI 里删 GPT / Gem
```

> 库/ 目录是你的阅读成果——卸载前请先备份。

---

*INSTALL.md v1 · 2026-05-23*
