# 学术快速阅读工作流 · v4.6

> **三平台兼容**：Claude / OpenAI GPT / Google Gemini
> **核心能力**：把任何材料走 7 变体三档精读，10 节结构化解读卡，自动挂载到博士论文章节。

[![version](https://img.shields.io/badge/version-4.6.0-blue)]() [![license](https://img.shields.io/badge/license-MIT-green)]() [![platforms](https://img.shields.io/badge/platforms-Claude%20%7C%20GPT%20%7C%20Gemini-orange)]() [![lang](https://img.shields.io/badge/lang-zh--CN%20%7C%20ko--KR%20%7C%20en--US-purple)]()

---

## 30 秒了解

这个工作流帮你解决 4 件事：

1. **读完就忘** → 强制 10 节结构（§10 论文挂载点必填），自动建反查表
2. **AI 编造引用** → 4 维真实性审查 + 6 维质量打分（满分 60）
3. **付费墙锁文** → 变体 G 公开信息卡（明确标限度，不放弃）
4. **跨语种处理** → 中 / 英 / 韩 / 日，韩文 KCI/DBpia 专链路

支持任何输入：PDF / EPUB / DOCX / HWP / URL / 音视频 / YouTube。

---

## 看这个

```
                 用户给一份材料
                       │
       ┌───────────────┴───────────────┐
       ▼                               ▼
   [LLM 平台]                       [本地脚本]
   Claude / GPT / Gemini            16 个 bash 脚本
       │                               │
       └───────────┬───────────────────┘
                   ▼
        类型识别 → 7 变体之一
        (A-F 三档卡 / G 公开信息卡)
                   │
                   ▼
        10 节结构化解读卡
        §1-§9 内容 + §10 论文挂载点
                   │
                   ▼
        4 维审查 + 6 维打分
                   │
                   ▼
        入库 + 章节挂载 + 长记 + Zotero
```

---

## 30 秒安装

### Claude（推荐 · 最完整）

```bash
git clone https://github.com/sunshilei/fast-reading-workflow.git ~/Desktop/快速阅读
cd ~/Desktop/快速阅读/dist
bash install.sh
open ~/Desktop/快速阅读/config.json   # 填个人信息
```

### GPT

打开 https://chatgpt.com/gpts/editor → 创建 GPT → 粘贴 `dist/platform-gpt/instructions.md` → 上传 knowledge files。

详见 [`dist/platform-gpt/README.md`](dist/platform-gpt/README.md)

### Gemini

打开 https://gemini.google.com/gems → 创建 Gem → 粘贴 `dist/platform-gemini/instructions.md` → 上传 files。

详见 [`dist/platform-gemini/README.md`](dist/platform-gemini/README.md)

---

## 三平台能力对比

| 能力 | Claude | GPT | Gemini |
|---|---|---|---|
| 7 变体精读 | ✅ | ✅ | ✅ |
| 10 节结构化卡 | ✅ | ✅ | ✅ |
| 4 维真实性审查 | ✅ | ✅ | ✅ |
| 6 维质量打分 | ✅ | ✅ | ✅ |
| 跨库搜索 | ✅ (bash) | ⚠️ (file_search) | ✅ (Drive) |
| Zotero 同步 | ✅ (MCP) | ⚠️ (Actions) | ⚠️ (Workspace) |
| 长期记忆 | ✅ (MCP) | ✅ (Memory) | ⚠️ |
| 音视频转写 | ✅ (whisper.cpp 本地) | ⚠️ (API 计费) | ✅ (Vision 内置) |
| YouTube 直读 | ❌ | ❌ | ✅ |
| Workspace 集成 | ❌ | ❌ | ✅ |
| 1M token 上下文 | ⚠️ (Sonnet 200K) | ⚠️ (GPT-4o 128K) | ✅ (Pro 1M) |
| 本地脚本工具链 | ✅ | ❌ | ❌ |

---

## 30 行试一试

打开任一平台，丢一个 PDF 进对话，说：

> 按 v4.6 流程精读

LLM 会自动：
1. 识别变体（学术论文/书/小说...）
2. 抓全文 → 10 节解读卡
3. §10 自动建议挂载点（基于你的博论方向）
4. 输出真实性审查报告
5. 给 6 维质量分

如果是付费墙论文 → 自动降级到变体 G，约 2000 字诚实卡。

---

## 文件清单

```
dist/                            ← 跨平台分发包
├── SKILL.md                     ← LLM 读的核心指令（三平台共用）
├── QUICKSTART.md                ← 5 分钟人类上手
├── INSTALL.md                   ← 三平台分别安装步骤
├── install.sh                   ← bash 一键安装
├── config.template.json         ← 配置模板
├── manifest.json                ← 完整文件清单
├── CHANGELOG.md                 ← 版本演进
├── LICENSE                      ← MIT
│
├── platform-claude/
│   └── README.md                ← Claude 专属说明
├── platform-gpt/
│   ├── README.md                ← GPT 创建步骤
│   └── instructions.md          ← 直接粘贴到 Custom GPT
└── platform-gemini/
    ├── README.md                ← Gemini 创建步骤
    └── instructions.md          ← 直接粘贴到 Gem

../                              ← 工作流主目录
├── 库/                          ← 阅读成果
├── 模板/                        ← 7 变体模板
└── 脚本/                        ← 16 个 bash 脚本
```

---

## 16 个脚本是什么

| 类别 | 脚本 | 干啥 |
|---|---|---|
| **检索** | 检索主题.sh | 多源 OA 检索 |
|  | 韩文学术源.sh | KCI/RISS/DBpia/Kyobo/earticle/KISS |
|  | 查全文.sh | 5 层降级取全文 |
|  | 抓取校验.sh | 核验真实性 |
|  | 生成请求邮件.sh | 三语模板向作者要 PDF |
| **抓取** | 通用提取.sh | 8 种输入类型 |
|  | 音视频转写.sh | whisper.cpp 本地 |
|  | pdf_截图.sh | PIL 美化版关键页 |
| **审查** | 审查解读.sh | 4 维真实性 |
|  | 打分.sh | 6 维质量分 + mermaid 雷达 |
| **入库** | 章节索引.sh | §10 反查表 |
|  | 生成概念图.sh | mermaid §11 |
|  | 搜库.sh | 跨库全文搜索 |
| **维护** | 整理文件夹.sh | dry-run + macOS 回收站 |
|  | 批量解读.sh | 并行处理 + token 估算 |
|  | init.sh | 41 项依赖检测 |

加 2 张 Agent 指令卡：`zotero_同步.md` / `agentmemory_存档.md`

---

## 7 变体解读卡

| 变体 | 何时用 | 字数 |
|---|---|---|
| A 学术论文 | 默认 · 有 DOI 和 references | 8000-15000 |
| B 书籍 | ISBN / 章节目录 / >100 页 | 12000-18000 |
| C 小说 | 第一人称 / 情节 / 无引用 | 10000-15000 |
| D 散文 | 思辨 / 个人观点 | 5000-10000 |
| E 报刊 | 时效性强 | 3000-6000 |
| F 采访 | Q&A / 长对谈 | 6000-12000 |
| **G 付费墙锁文** | 全文不可达，只有公开 abstract | 1500-3000 |

---

## 设计哲学（Karpathy 准则简版）

1. **不编造**：拿不到的就说拿不到
2. **不超界**：用户说 A 就回答 A
3. **不假设**：多个解读时列候选让用户选
4. **简单优先**：50 行能写完不写 200 行
5. **目标驱动**：先定义"成功是什么样"再做

破坏性操作（清理 / 批量）默认 **dry-run**，必须 `--apply` 才真跑。

---

## 真实案例

- ✅ 7 张韩文 KCI 电影符号学论文 · 5 个 Agent 并行 22 分钟
- ✅ 《明朝那些事》（140 万字 · 9 卷）· 变体 B 全书地图卡 23 KB
- ✅ KCI KakaoTalk 沟通研究（付费墙）· 变体 G 公开信息卡 · 91 分

---

## 贡献

发现 bug / 想加变体 / 跨语种扩展 → 提 issue 或直接改文档（MIT 协议）。

---

## License

MIT · See [LICENSE](LICENSE)

---

*v4.6.0 · 2026-05-23 · sunshilei*
