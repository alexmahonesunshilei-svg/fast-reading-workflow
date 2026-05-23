# Google Gemini Gem 安装

> **标准体验** + Google Workspace 集成（自动存 Docs / Drive）。
> Gemini 的中文上下文窗口比 GPT 更宽松，适合超长论文（>200 页）。

---

## 5 分钟安装

### Step 1 · 创建 Gem

1. 打开 https://gemini.google.com/gems
2. 点 **+ New Gem**

### Step 2 · 填基础信息

**Gem name**: `학술 快速阅读教练 v4.6`

**Custom instructions**:
把 `dist/platform-gemini/instructions.md` 全文粘贴。

### Step 3 · 上传 Knowledge

把这些文件上传到 Gem 的 **Files** 区：

- ✅ `SKILL.md`（必上传）
- ✅ `模板/解读卡模板套件_v4.md`（必上传）
- ✅ `模板/术语词典.md`
- ✅ `config.template.json`
- ✅ `脚本/打分.sh`（Python 段可被 code_execution 复用）
- ✅ `CHANGELOG.md`

### Step 4 · 保存 + 测试

点 **Save**，然后开新对话测试：
- 上传一个 PDF
- 说 "按 v4.6 流程精读"
- 看 Gem 是否走完 5 步

---

## Google Workspace 集成（Gemini 独有优势）

Gemini 可以直接读写你的 Google Drive / Docs / Sheets。

### 让 Gem 自动把解读卡存到 Google Docs

在 instructions 末尾加：
```
输出完成后，主动询问：
"要把这张解读卡存到你的 Google Drive 吗？"
如果用户同意，用 google_workspace tool 创建 Google Docs：
- 标题: "解读卡 · {论文标题} · {日期}"
- 内容: 完整解读卡 markdown
- 位置: Drive 根目录的 「快速阅读/库/」文件夹
```

### 让 Gem 维护一份 Google Sheets 章节索引

让 Gem 在每次输出后追加到 sheets：
- A 列: 标题
- B 列: 章节挂载
- C 列: 三层定位
- D 列: 优先级
- E 列: 一句话定位

这相当于 `脚本/章节索引.sh` 的云端版。

---

## 触发口令（同 Claude/GPT 段）

| 你说 | Gem 做 |
|---|---|
| 上传 PDF + "精读" | 全流程 |
| "存到 Drive" | 自动写 Google Docs |
| "我读了什么" | 读 Sheets 章节索引 |
| "付费墙" | 自动降级到变体 G |
| "搜「福柯」" | 搜 Drive 里所有解读卡 |

---

## 局限性

| 能力 | 状态 |
|---|---|
| 本地 bash | ❌ 用 code_execution Python |
| MCP | ❌ 用 Google Workspace API |
| 音视频转写 | ✅ Gemini Vision 直接读音视频（无需 whisper）|
| docx 生成 | ✅ code_execution + python-docx，但更推荐 Google Docs |
| PDF 截图 | ✅ Gemini Vision 比 OpenAI 更精确 |
| 中文长上下文 | ✅✅ **Gemini 2.5 Pro 支持 1M token，对超长书最友好** |

---

## Gemini 独有玩法

### ① 直接给 Gem 一个 YouTube 链接

Gemini 能直接解析 YouTube 字幕：
- 给 Gem 一个导演访谈的 YouTube 链接
- Gem 自动抓字幕 → 走变体 F 采访模板
- 比 whisper 转写快 10 倍

### ② Vision + 文字双模态

给 Gem 一本带插图的书的 PDF：
- Gem 同时分析文字 + 图表
- §4 机制拆解里能直接引用图表（"图 3.2 显示..."）

### ③ Workspace 跨文件读

Gem 可以读你 Drive 里**所有**已读卡 → 真正的跨库分析：
```
"对比我读过的 5 张韩国电影解读卡，找共同的方法论模式"
```

---

## 故障排查

### Gem 不识别 SKILL.md 里的"v4.6 流程"

- 在 Custom Instructions 里**直接复制 SKILL.md 全文**而不是只引用
- Files 区上传也不能保证 Gem 优先读 SKILL.md

### code_execution 装不上 pyhwp / pypdf

- Gemini code_execution 沙箱有限——大部分 pypi 包都行，但版本可能旧
- 如果 pypdf 失败，用 `pip install pdfplumber` 代替

### 中文显示乱码

- Gemini Workspace 集成默认 UTF-8 没问题
- 如果 code_execution 输出乱码，加 `import sys; sys.stdout.reconfigure(encoding='utf-8')`

---

## 进阶 · 用 Gemini API 做批量处理

如果你要批量处理 50 篇论文，可以不通过 Gem，直接用 Gemini API：

```python
import google.generativeai as genai
genai.configure(api_key="...")

model = genai.GenerativeModel(
    'gemini-2.5-pro',
    system_instruction=open('SKILL.md').read()  # SKILL.md 当 system prompt
)

for pdf in pdf_files:
    response = model.generate_content([
        "按 v4.6 流程精读",
        genai.upload_file(pdf)
    ])
    # 解析 response.text → 落盘解读卡
```

成本：Gemini 2.5 Pro 输入 $1.25/MTok（最便宜），50 篇约 $5。

---

*Gemini 适配版 · v1 · 2026-05-23*
