# OpenAI Custom GPT 安装

> **标准体验**——code_interpreter 替代 bash，browser 替代 WebSearch，knowledge 替代 templates。

---

## 5 分钟安装

### Step 1 · 创建 GPT

1. 打开 https://chatgpt.com/gpts/editor
2. 点 **+ Create**
3. 切到 **Configure** 标签

### Step 2 · 填基础信息

**Name**: `学术快速阅读教练 v4.6`

**Description**:
```
把任何材料（PDF/EPUB/URL/付费墙论文）走 7 变体三档精读，10 节结构化解读卡，
自动挂载到博论章节。防 AI 幻觉 + 6 维质量打分。
```

**Instructions**: 把 `dist/platform-gpt/instructions.md` 全文复制粘贴进来。

### Step 3 · 上传 Knowledge

把这些文件上传到 GPT 的 **Knowledge** 区：

- ✅ `SKILL.md`（核心指令 · 必上传）
- ✅ `模板/解读卡模板套件_v4.md`（必上传）
- ✅ `模板/术语词典.md`
- ✅ `config.template.json`（提示用户改填后再上传）
- ✅ `脚本/打分.sh`（Python 段可被 code_interpreter 复用）
- ✅ `脚本/审查解读.sh`（同上）
- ✅ `CHANGELOG.md`（让 GPT 知道版本演进）

### Step 4 · 启用 Capabilities

- ✅ **Web Browsing**（多源检索必需）
- ✅ **Code Interpreter**（替代 bash · 必需）
- ⚠️ **DALL·E**（可选，不依赖）
- ✅ **Actions**（如要接 Zotero Web API · 见下文）

### Step 5 · 设置 Conversation Starters

4 个建议：
```
精读这篇 PDF（请上传）
这是付费墙论文，能做什么
给我审一下这张解读卡
搜我读过的卡里提到「福柯」
```

### Step 6 · 发布

- **Only me** → 个人用
- **Anyone with the link** → 朋友间分享
- **Public** → 上 GPT Store（需通过审核）

---

## 上传 config.json 的两种方式

### 方式 A · 公开模板版（推荐）

把 `config.template.json` 直接传给 knowledge，让 GPT 第一次对话时引导用户填。

### 方式 B · 个人化版

复制 template，自己填好后上传 `config.json` 替换。**注意：knowledge 可能被其他用户看到**（如果 GPT 是 Public）——所以 Public GPT 不要传个人化 config。

---

## 触发口令（同 Claude 段）

| 你说 | GPT 做 |
|---|---|
| 上传 PDF + "精读" | 全流程 |
| "这是付费墙论文" | 自动降级到变体 G |
| "审一下" | 真实性核验 + 6 维打分 |
| "搜知识库 福柯" | file_search 跨 knowledge 检索 |

---

## 用 Custom Actions 接外部 API（可选）

如果想要"存进 Zotero"功能，需要配 Actions（OpenAPI schema）：

### Zotero Web API Action

在 GPT 编辑器的 **Actions** 区点 **+ Create new action**：

**Authentication**:
- Type: API Key
- Auth Type: Custom
- Custom Header Name: `Zotero-API-Key`
- API Key: 你的 Zotero key（https://www.zotero.org/settings/keys 申请）

**Schema** (OpenAPI 3.1):
```yaml
openapi: 3.1.0
info:
  title: Zotero Web API
  version: 3.0.0
servers:
  - url: https://api.zotero.org
paths:
  /users/{userID}/items:
    post:
      operationId: createItem
      summary: 创建新条目
      parameters:
        - name: userID
          in: path
          required: true
          schema: { type: string }
      requestBody:
        content:
          application/json:
            schema:
              type: array
              items:
                type: object
```

完整 schema 见 https://www.zotero.org/support/dev/web_api/v3/start

---

## 局限性 · 主动告知

| 能力 | 状态 |
|---|---|
| 本地 bash 脚本 | ❌ 改用 code_interpreter Python |
| 本地文件系统 | ❌ knowledge 是只读，库/ 维护在 Google Drive |
| MCP（Zotero/agentmemory）| ❌ 必须用 Custom Actions 替代 |
| 音视频转写 | ⚠️ 用 OpenAI Whisper API（额外计费） |
| docx 生成 | ✅ code_interpreter 可装 python-docx |
| PDF 截图 | ✅ code_interpreter PIL |
| 跨库搜索 | ⚠️ 受限于 knowledge 数量（GPT 上限 20 个文件） |

---

## 进阶建议

### 多人共享一个 GPT 但各自维护私有库

- GPT 设为 Public 或 Link
- 每个用户在自己 ChatGPT 账号下创建一个**Project**（ChatGPT 项目功能）
- Project 里上传**用户自己的** `config.json` 和已读卡片
- GPT 读 Project 的 files，不读其他用户的

### 与 ChatGPT Memory 联动

让 GPT 自动用 ChatGPT 的 memory 功能存"用户读过什么"——相当于 agentmemory 的 GPT 替代品。

---

## 故障排查

### GPT 说找不到 SKILL.md

- 重新上传到 Knowledge
- 在对话里直接说："你的 instructions 是 SKILL.md"，让 GPT 重新加载

### GPT 编了引用页码

- 在对话里说："按 SKILL.md 第 4 步走真实性审查"
- 启用 Web Browsing 让 GPT 实际去查 PDF 内容（如果 PDF 来自公开 URL）

### code_interpreter 无法访问外部文件

- 把 PDF 直接上传到对话里，GPT 能用 code_interpreter 处理
- 不能引用 `~/Desktop/...` 之类本地路径

---

*OpenAI GPT 适配版 · v1 · 2026-05-23*
