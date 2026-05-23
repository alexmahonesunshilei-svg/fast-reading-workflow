# Fast Reading Workflow · 学术快速阅读工作流

> **三平台兼容（Claude / GPT / Gemini）的 AI 文献精读 Skill**
> 把每篇文献都吃透，自动挂载到博论章节，永不编造引用。

[🇨🇳 中文](#中文) · [🇬🇧 English](#english) · [🇰🇷 한국어](#한국어)

---

## 🇨🇳 中文

### 这是什么

一个**给研究生 / 博士生 / 学者**用的 AI 阅读工作流——把任何材料（PDF / EPUB / 网页 / 音视频 / 付费墙锁文）走 5 步流程，产出**10 节结构化解读卡**，并**自动挂载到博士论文章节**。

```
材料 → 类型识别 → 抓取 → 7 变体精读 → 真实性审查 → 入库挂载
```

### 解决的 3 个真痛点

| 痛点 | 现状 | 这个工作流的解法 |
|---|---|---|
| **读完就忘** | 解读卡散落，写论文时找不到 | 强制 10 节结构 + §10 论文挂载点必填 + 自动反查表 |
| **AI 编造引用** | LLM 经常伪造页码 / 金句 / 学者名 | 4 维真实性自检 + 6 维质量打分（满分 60 + 雷达图）|
| **付费墙锁文** | 韩文 KCI / DBpia 论文拿不到全文 → 工作流卡住 | 变体 G **公开信息卡**（明确标限度，不放弃）|

### 4 大核心特性

#### 1️⃣ **7 变体差异化处理**（不是一个模板套所有材料）

A 学术论文 · B 书籍 · C 小说 · D 散文 · E 报刊 · F 采访 · **G 付费墙锁文**

每个变体有自己的字数指标、§4 机制拆解维度、§7 精读方式。

#### 2️⃣ **10 节结构化解读卡**

```
§1 元信息  · §2 真问题  · §3 精髓 + 那一招  · §4 机制拆解
§5 深层原理 · §6 边界    · §7 逐章精读      · §8 金句汇编
§9 答辩追问 · §10 论文挂载点（必填）← v4.5 创新
```

§10 让"读了就忘"变成"读了就挂"——直接喂博士论文章节。

#### 3️⃣ **3 维防 AI 幻觉**

- **真实性审查**（4 维）：页码 / 引用句 / 学者名 / 年份必须在原文里
- **质量打分**（6 维 × 10 分）：元信息 / §10 / 字数 / §4 结构 / 引用真实 / 博论关联
- **诚实交代表**（变体 G 强制）：每条信息标来源 + 可信度

#### 4️⃣ **跨语言 + 多平台**

- 中 / 英 / 韩 / 日（韩文 KCI / RISS / DBpia / Kyobo / earticle / KISS 多源检索）
- **三平台一份指令**（Claude SKILL.md / GPT Custom Instructions / Gemini Gem）
- 16 个 bash 脚本（Claude Code 原生支持）

### 30 秒上手

```bash
# Claude Code（最完整体验）
git clone https://github.com/sunshilei/fast-reading-workflow.git ~/Desktop/快速阅读
cd ~/Desktop/快速阅读/dist && bash install.sh
open ~/Desktop/快速阅读/config.json   # 填个人信息

# OpenAI Custom GPT
# 访问 chatgpt.com/gpts/editor → 创建 GPT → 粘贴 dist/platform-gpt/instructions.md

# Google Gemini Gem
# 访问 gemini.google.com/gems → 创建 Gem → 粘贴 dist/platform-gemini/instructions.md
```

### 真实使用案例

| 材料 | 变体 | 产出 | 用时 |
|---|---|---|---|
| 7 篇韩文 KCI 电影符号学论文 | A | 7 张三档卡 + 7 个 docx | 22 分钟（5 Agent 并行）|
| 《明朝那些事》（140 万字 · 9 卷）| B | 12000 字全书地图卡 | 8 分钟 |
| KCI KakaoTalk 沟通研究（付费墙）| G | 3000 字诚实卡（91 分）| 2 分钟 |

### 三平台能力对比

| 能力 | Claude | GPT | Gemini |
|---|---|---|---|
| 7 变体精读 + 10 节卡 + 6 维打分 | ✅ | ✅ | ✅ |
| 本地 bash 脚本 | ✅ | ❌ | ❌ |
| Zotero 自动同步 | ✅ MCP | ⚠️ Actions | ⚠️ Workspace |
| YouTube 直接解析 | ❌ | ❌ | ✅ |
| 1M token 上下文 | ⚠️ 200K | ⚠️ 128K | ✅ Gemini 2.5 Pro |
| 中文长文支持 | ✅✅ | ✅ | ✅ |

### 设计哲学

遵循 **Karpathy 准则**（来自 Andrej Karpathy 对 LLM 错误模式的观察）：

1. **不编造** · 拿不到就说拿不到
2. **不超界** · 用户说 A 就回答 A
3. **不假设** · 多个解读时列候选让用户选
4. **简单优先** · 50 行能写完不写 200 行
5. **目标驱动** · 先定义"成功是什么样"

破坏性操作（清理 / 批量）默认 `--dry-run`，必须 `--apply` 才真跑。

### License & 贡献

**MIT 协议** · 自由使用 / 修改 / 分发。

发现 bug / 想加变体 / 想跨语种扩展 → 提 Issue 或 PR。

---

## 🇬🇧 English

### What is this

An AI reading workflow for **graduate students / PhD candidates / scholars**. Take any material (PDF / EPUB / web / audio-video / paywalled paper) through a 5-step process to produce **10-section structured reading cards** that **auto-mount to your dissertation chapters**.

```
Material → Type detection → Extraction → 7-variant deep reading → Reality audit → Library + Chapter mounting
```

### 3 Real Pain Points Solved

| Pain | Status quo | Our solution |
|---|---|---|
| **Read & forget** | Cards scattered, can't find when writing | Enforced §10 "Dissertation Mount Point" + auto reverse lookup |
| **AI hallucinated citations** | LLMs fake page numbers / quotes / scholar names | 4-dim reality audit + 6-dim quality score (out of 60 + radar chart) |
| **Paywalled papers** | Korean KCI / DBpia full-text inaccessible → workflow stalls | **Variant G "Public Info Card"** (honest limit-marking, don't give up) |

### 4 Core Features

1. **7-variant differentiated processing** — A Paper · B Book · C Novel · D Essay · E News · F Interview · **G Paywalled**
2. **10-section structured card** with §10 dissertation mount point (mandatory)
3. **3-layer anti-hallucination**: reality audit + quality score + honest disclosure table
4. **Cross-lingual + multi-platform**: zh / en / ko / ja + Claude / GPT / Gemini

### 30-second Setup

See QUICKSTART.md.

### Design Philosophy

Follows **Karpathy Guidelines** (from his observations on LLM failure modes):
1. **Don't fabricate** · 2. **Stay in lane** · 3. **Don't assume** · 4. **Simplicity first** · 5. **Goal-driven**

### License

MIT.

---

## 🇰🇷 한국어

### 무엇인가요

**대학원생 / 박사과정 / 연구자**를 위한 AI 독해 워크플로우. 어떤 자료든(PDF / EPUB / 웹 / 음성 / 페이월 논문) 5단계 프로세스를 거쳐 **10절 구조화 해독카드**를 산출하고, **박사논문 챕터에 자동 매핑**.

### 핵심 특징

1. **7가지 변형** — 학술논문 / 도서 / 소설 / 에세이 / 신문 / 인터뷰 / **페이월 잠금**
2. **10절 구조 해독카드** — §10 논문 매핑 포인트 필수
3. **3중 환각 방지** — 진실성 검사 + 품질 점수 + 솔직한 출처 표시
4. **다언어 + 다플랫폼** — 한 / 중 / 일 / 영 + Claude / GPT / Gemini

### 한국어 학술 자료 특화 지원

- KCI / RISS / DBpia / Kyobo Scholar / earticle / KISS 다중 검색
- 한국어 PDF / HWP 직접 처리
- 페이월 논문 시 변형 G로 자동 다운그레이드

### 라이센스

MIT.

---

## 🔗 Links

- 📖 [QUICKSTART.md](./QUICKSTART.md) · 5 분 시작
- 🛠️ [INSTALL.md](./INSTALL.md) · 三平台详细安装
- 🤖 [SKILL.md](./SKILL.md) · LLM 核心指令（共用）
- 📋 [CHANGELOG.md](./CHANGELOG.md) · 版本演进
- ⚖️ [LICENSE](./LICENSE) · MIT

---

## 🏷️ Tags

`#academic-reading` `#phd-tools` `#llm-workflow` `#claude-skill` `#custom-gpt` `#gemini-gem`
`#cross-platform` `#anti-hallucination` `#korean-academic` `#dissertation-helper` `#mit-license`

---

*v4.6.0 · 2026-05-23*
