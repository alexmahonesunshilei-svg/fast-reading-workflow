#!/bin/bash
# ============================================================
# 多源主题检索 v2 · 12 源全覆盖
#
# 用法:
#   ./检索主题.sh <主题关键词> [--类型 通用|学术|书籍|新闻|博客|播客]
#
# 类型决定调用哪些源（不限定则跑全部 12 源）
# ============================================================

set -e

TOPIC=""
CATEGORY="通用"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --类型|--type) CATEGORY="$2"; shift 2;;
    -h|--help)
      head -10 "$0" | tail -8; exit 0;;
    *) TOPIC="$1"; shift;;
  esac
done

if [ -z "$TOPIC" ]; then
  echo "用法: $0 <主题关键词> [--类型 通用|学术|书籍|新闻|博客|播客]"
  exit 1
fi

OUTDIR=~/Desktop/快速阅读/检索
mkdir -p "$OUTDIR"
TIMESTAMP=$(date +%Y-%m-%d)
SAFE_TOPIC=$(echo "$TOPIC" | tr ' /\\' '___')
OUTFILE="$OUTDIR/${TIMESTAMP}_${SAFE_TOPIC}_${CATEGORY}.md"
ESCAPED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$TOPIC'))")

echo "════════════════════════════════════════════════════"
echo "🔍 多源检索 · 主题: $TOPIC · 类型: $CATEGORY"
echo "📁 输出: $OUTFILE"
echo "════════════════════════════════════════════════════"

# ─── 候选清单初始结构 ───
cat > "$OUTFILE" << EOF
# 多源检索：$TOPIC

> **检索时间**：$TIMESTAMP
> **类型范围**：$CATEGORY
> **关键词**：$TOPIC

---

## 关键词扩展（请人工补充）

| 查询组 | 词 |
|---|---|
| 核心词 | $TOPIC |
| 同义词 | （请补充）|
| 上位/下位 | （请补充）|
| 中英韩三语 | （请补充）|

---

EOF

# ─── A. 学术源（论文）─── 类型：通用 / 学术
if [[ "$CATEGORY" == "通用" || "$CATEGORY" == "学术" ]]; then
  echo "━━━ A. 学术源（4 个 API + 4 个手动）━━━"
  cat >> "$OUTFILE" << EOF
## A · 学术源

### A1 · OpenAlex API（自动 · 全球最大 OA 索引）

| ☐ | 标题 | 年 | 引用 | OA | PDF |
|---|---|---|---|---|---|
EOF
  curl -s "https://api.openalex.org/works?search=$ESCAPED&sort=cited_by_count:desc&per_page=10" 2>/dev/null | python3 -c "
import json, sys
try:
    r = json.load(sys.stdin)
    for w in r.get('results', [])[:10]:
        title = (w.get('title') or '?').replace('|', '/')[:70]
        year = w.get('publication_year', '?')
        cites = w.get('cited_by_count', 0)
        oa = w.get('open_access', {})
        is_oa = '🟢' if oa.get('is_oa') else '🔴'
        pdf = (w.get('best_oa_location') or {}).get('pdf_url') or oa.get('oa_url') or '—'
        if pdf != '—':
            pdf = f'[直链]({pdf})'
        print(f'| ☐ | {title} | {year} | {cites} | {is_oa} | {pdf} |')
except Exception as e:
    print(f'| | (API 失败: {e}) | | | | |')
" >> "$OUTFILE" 2>/dev/null || true

  cat >> "$OUTFILE" << EOF

### A2-A5 · 学术手动检索（浏览器打开）

- **RISS（韩国学术）**：https://www.riss.kr/search/Search.do?query=$ESCAPED
- **dCollection（韩国 OA 学位）**：https://www.dcollection.net/search?keyword=$ESCAPED
- **Google Scholar**：https://scholar.google.com/scholar?q=$ESCAPED
- **Semantic Scholar**：https://www.semanticscholar.org/search?q=$ESCAPED
- **CNKI（中文）**：https://kns.cnki.net/kns8s/defaultresult/index?korder=SU&kw=$ESCAPED
- **arXiv（预印本）**：https://arxiv.org/search/?query=$ESCAPED

EOF
fi

# ─── B. 图书源 ─── 类型：通用 / 书籍
if [[ "$CATEGORY" == "通用" || "$CATEGORY" == "书籍" ]]; then
  echo "━━━ B. 图书源（4 个手动）━━━"
  cat >> "$OUTFILE" << EOF
## B · 图书源

### B1-B4 · 图书手动检索

- **豆瓣读书**：https://search.douban.com/book/subject_search?search_text=$ESCAPED
- **Goodreads**：https://www.goodreads.com/search?q=$ESCAPED
- **Amazon 国际**：https://www.amazon.com/s?k=$ESCAPED
- **Amazon 中国**：https://www.amazon.cn/s?k=$ESCAPED
- **Library Genesis（OA 镜像）**：https://libgen.is/search.php?req=$ESCAPED
- **Z-Library**：https://z-lib.io/s/$ESCAPED
- **WorldCat（图书馆联网）**：https://www.worldcat.org/search?q=$ESCAPED

### 建议候选清单（请人工填）

| ☐ | 中文标题 | 原文标题 | 作者 | 出版社 | 年份 | ISBN | 推荐度 |
|---|---|---|---|---|---|---|---|
| ☐ | | | | | | | |

EOF
fi

# ─── C. 报刊/新闻源 ─── 类型：通用 / 新闻
if [[ "$CATEGORY" == "通用" || "$CATEGORY" == "新闻" ]]; then
  echo "━━━ C. 报刊新闻源（6 个手动）━━━"
  cat >> "$OUTFILE" << EOF
## C · 报刊新闻源

### C1-C6 · 新闻手动检索

#### 国际媒体
- **NYT**：https://www.nytimes.com/search?query=$ESCAPED
- **The Guardian**：https://www.theguardian.com/search?q=$ESCAPED
- **Reuters**：https://www.reuters.com/site-search/?query=$ESCAPED
- **BBC**：https://www.bbc.co.uk/search?q=$ESCAPED
- **南华早报（SCMP）**：https://www.scmp.com/search/$ESCAPED

#### 中文媒体
- **新华网**：https://so.news.cn/getNews?keyword=$ESCAPED
- **人民日报**：http://search.people.com.cn/s?keyword=$ESCAPED
- **澎湃新闻**：https://www.thepaper.cn/searchResult.html?inpsearch=$ESCAPED
- **财新**：https://search.caixin.com/search/search.jsp?keyword=$ESCAPED

#### 韩文媒体
- **NAVER 新闻**：https://search.naver.com/search.naver?where=news&query=$ESCAPED
- **DAUM 新闻**：https://search.daum.net/search?w=news&q=$ESCAPED
- **中央日报**：https://www.joongang.co.kr/search/news?keyword=$ESCAPED

### 建议候选清单

| ☐ | 标题 | 媒体 | 作者 | 日期 | URL | 时效 |
|---|---|---|---|---|---|---|
| ☐ | | | | | | |

EOF
fi

# ─── D. 博客/Newsletter ─── 类型：通用 / 博客
if [[ "$CATEGORY" == "通用" || "$CATEGORY" == "博客" ]]; then
  echo "━━━ D. 博客与 Newsletter（5 个手动）━━━"
  cat >> "$OUTFILE" << EOF
## D · 博客与 Newsletter

### D1-D5 · 博客手动检索

- **Substack**：https://substack.com/search/$ESCAPED
- **Medium**：https://medium.com/search?q=$ESCAPED
- **知乎专栏**：https://www.zhihu.com/search?type=content&q=$ESCAPED
- **微信公众号**（搜狗）：https://weixin.sogou.com/weixin?type=2&query=$ESCAPED
- **少数派**：https://sspai.com/search/page/1?keyword=$ESCAPED

### 建议候选清单

| ☐ | 标题 | 作者 | 平台 | 日期 | URL |
|---|---|---|---|---|---|
| ☐ | | | | | |

EOF
fi

# ─── E. 播客/视频 ─── 类型：通用 / 播客
if [[ "$CATEGORY" == "通用" || "$CATEGORY" == "播客" ]]; then
  echo "━━━ E. 播客与视频（6 个手动）━━━"
  cat >> "$OUTFILE" << EOF
## E · 播客与视频

### E1-E6 · 播客手动检索

- **Apple Podcasts**：https://podcasts.apple.com/search?term=$ESCAPED
- **Spotify**：https://open.spotify.com/search/$ESCAPED/podcasts
- **小宇宙**（中文播客）：https://www.xiaoyuzhoufm.com/search?q=$ESCAPED
- **Podchaser**：https://www.podchaser.com/search/podcasts?q=$ESCAPED
- **YouTube**：https://www.youtube.com/results?search_query=$ESCAPED
- **B 站**：https://search.bilibili.com/all?keyword=$ESCAPED

### 建议候选清单

| ☐ | 标题 | 主持/嘉宾 | 平台 | 时长 | 日期 | URL |
|---|---|---|---|---|---|---|
| ☐ | | | | | | |

EOF
fi

# ─── F. 维基百科与参考资料 ─── 类型：通用
if [[ "$CATEGORY" == "通用" ]]; then
  echo "━━━ F. 维基与参考工具 ━━━"
  cat >> "$OUTFILE" << EOF
## F · 维基与参考工具

- **English Wikipedia**：https://en.wikipedia.org/wiki/Special:Search?search=$ESCAPED
- **中文维基**：https://zh.wikipedia.org/wiki/Special:Search?search=$ESCAPED
- **한국어 위키**：https://ko.wikipedia.org/wiki/Special:Search?search=$ESCAPED
- **Stanford Encyclopedia of Philosophy**：https://plato.stanford.edu/search?q=$ESCAPED
- **JSTOR**：https://www.jstor.org/action/doBasicSearch?Query=$ESCAPED

EOF
fi

# ─── 通用尾部 ───
cat >> "$OUTFILE" << EOF
---

## 全文可获取性图例

- 🟢 直接公开 PDF
- 🟡 需要登录（RISS/部分期刊机构）
- 🔴 付费 / 不开放
- ⚪ 仅元数据 / 实体馆藏

---

## 引用网络发现（滚雪球后填）

- **高频作者**：
- **共享引用**：
- **顶级载体**：

---

## 检索盲点 / 我没找到的

- （坦白哪类资料没找到 / 哪个平台没覆盖到）

---

## 下一步

勾选完毕后说"**抓打勾的**"，我会用 \`通用提取.sh\` 处理任意类型（PDF/EPUB/HTML/URL...），然后送 Step 1 → 2 → 3。

无法获取的条目自动用 \`生成请求邮件.sh\` 出邮件模板。
EOF

echo ""
echo "✅ 候选清单已生成: $OUTFILE"
echo ""
echo "── 下一步 ──"
echo "1. 在 Claude Code 里说: '用 WebFetch 扫描候选源链接，填进 $OUTFILE'"
echo "2. 或自己在浏览器看链接、手动填表"
echo "3. 勾选完后说: '抓打勾的'"
