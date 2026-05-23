#!/bin/bash
# ============================================================
# 韩文学术源 · 专门处理 RISS / KCI / DBpia / earticle 等
#
# 解决痛点：OpenAlex/CrossRef 对韩国学术期刊收录率 < 30%，
# 韩文 KCI 论文 5 层降级全失败时的最后救命链路。
#
# 用法:
#   ./韩文学术源.sh <DOI 或 RISS URL>
#
# 输出:
#   1. 元数据 + 章节大纲
#   2. KCI Open Access 检测
#   3. 三语邮件模板（韩-中-英）
#   4. 图书馆 SSO 跳转链接（最后退路）
# ============================================================

set -e

INPUT="$1"

if [ -z "$INPUT" ]; then
  cat << EOF
用法: $0 <DOI 或 RISS URL>

例:
  $0 10.14353/sjk.2021.29.4.03
  $0 "https://www.riss.kr/search/detail/DetailView.do?control_no=..."

输出:
  - 元数据卡（含章节大纲、作者邮箱）
  - KCI OA 检测结果
  - 三语邮件模板
EOF
  exit 1
fi

TIMESTAMP=$(date +%s)
OUTDIR="/tmp/kor_acad_${TIMESTAMP}"
mkdir -p "$OUTDIR"

echo "════════════════════════════════════════════════════"
echo "🇰🇷 韩文学术源专链路"
echo "  输入: $INPUT"
echo "  输出目录: $OUTDIR"
echo "════════════════════════════════════════════════════"
echo ""

# ─── 判断输入类型 ───
DOI=""
RISS_URL=""
if [[ "$INPUT" =~ ^10\. ]]; then
  DOI="$INPUT"
  echo "→ 识别为 DOI"
elif [[ "$INPUT" =~ riss\.kr ]]; then
  RISS_URL="$INPUT"
  echo "→ 识别为 RISS URL"
else
  echo "❌ 输入既不是 DOI 也不是 RISS URL"
  exit 1
fi

# ─── 1. CrossRef / OpenAlex 探测（韩文论文收录率低，但试一下）───
echo ""
echo "── ① CrossRef / OpenAlex 探测 ──"
TITLE=""
JOURNAL=""
YEAR=""
AUTHORS=""
if [ -n "$DOI" ]; then
  CR=$(curl -s "https://api.crossref.org/works/$DOI" 2>&1)
  if echo "$CR" | grep -q '"status":"ok"'; then
    echo "✅ CrossRef 收录"
    TITLE=$(echo "$CR" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['message'].get('title',['?'])[0])" 2>/dev/null)
    JOURNAL=$(echo "$CR" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['message'].get('container-title',['?'])[0])" 2>/dev/null)
    YEAR=$(echo "$CR" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['message'].get('issued',{}).get('date-parts',[['?']])[0][0])" 2>/dev/null)
    AUTHORS=$(echo "$CR" | python3 -c "
import sys,json
d=json.load(sys.stdin)['message']
authors=d.get('author',[])
parts=[]
for a in authors:
    g=a.get('given','?'); f=a.get('family','?')
    affs=', '.join(af.get('name','') for af in a.get('affiliation',[]))
    parts.append(f + ' ' + g + (' @ '+affs if affs else ''))
print(' | '.join(parts))
" 2>/dev/null)
    VOLUME=$(echo "$CR" | python3 -c "import sys,json;d=json.load(sys.stdin);print(f\"Vol.{d['message'].get('volume','?')} No.{d['message'].get('issue','?')} pp.{d['message'].get('page','?')}\")" 2>/dev/null)
    echo "  标题: $TITLE"
    echo "  期刊: $JOURNAL · $VOLUME"
    echo "  年份: $YEAR"
    echo "  作者: $AUTHORS"
    # 落盘元数据
    {
      echo "# 论文元数据（CrossRef）"
      echo ""
      echo "| 字段 | 值 |"
      echo "|---|---|"
      echo "| DOI | $DOI |"
      echo "| 标题 | $TITLE |"
      echo "| 期刊 | $JOURNAL |"
      echo "| 卷期 | $VOLUME |"
      echo "| 年份 | $YEAR |"
      echo "| 作者 | $AUTHORS |"
    } > "$OUTDIR/元数据.md"
  else
    echo "⚠️  CrossRef 未收录（韩文论文常见）"
  fi

  echo ""
  OA=$(curl -s "https://api.openalex.org/works/doi:$DOI" 2>&1)
  if echo "$OA" | grep -q '"is_oa":true'; then
    OA_URL=$(echo "$OA" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('open_access',{}).get('oa_url',''))" 2>/dev/null)
    echo "✅ OpenAlex: 是 OA"
    echo "  OA 链接: $OA_URL"
    if [ -n "$OA_URL" ]; then
      echo "  → 直接下载: curl -L \"$OA_URL\" -o paper.pdf"
    fi
  else
    echo "🔴 OpenAlex: 不是 OA"
  fi
fi

# ─── 2. KCI / DBpia / Kyobo Scholar / earticle / KISS 多源探测 ───
echo ""
echo "── ② 韩国本土学术库多源探测 ──"
if [ -n "$DOI" ]; then
  TITLE_PARAM=$(echo "$TITLE" | python3 -c "import sys,urllib.parse;print(urllib.parse.quote(sys.stdin.read().strip()))" 2>/dev/null)
  echo "  · KCI:           https://www.kci.go.kr/kciportal/po/search/poTotalSearList.kci?query=$DOI"
  echo "  · DBpia:         https://www.dbpia.co.kr/search/topSearch?searchOption=all&query=$DOI"
  echo "  · Kyobo Scholar: https://scholar.kyobobook.co.kr/total/search?query=$TITLE_PARAM"
  echo "  · earticle:      https://www.earticle.net/Search/Searchword?keyword=$DOI"
  echo "  · KISS:          https://kiss.kstudy.com/searchresult/searchresult.asp?key1=$DOI"
fi
echo ""
echo "  💡 实战经验:"
echo "     · DBpia / KCI 公开 abstract + 목차（章节大纲）"
echo "     · Kyobo Scholar 偶尔有完整韩文 abstract（比英文 abstract 长 5x）"
echo "     · earticle 部分论文是 OA"
echo "     · KISS 部分论文是 OA"
echo "     · 全文 PDF 几乎都需要 SSO 或付费"

# ─── 2b. 韩文 abstract 抓取（无需 SSO 的核心信息）───
if [ -n "$DOI" ]; then
  echo ""
  echo "── ②b 韩文 abstract 自动抓取 ──"
  python3 << PYEOF
import warnings; warnings.filterwarnings("ignore")
import urllib.request, re, json

doi = "$DOI"
abstract_kor = ""
sources_tried = []

# 尝试 1: OpenAlex（有时韩国期刊有 abstract_inverted_index）
try:
    req = urllib.request.Request(f"https://api.openalex.org/works/doi:{doi}",
                                  headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req, timeout=10) as r:
        d = json.loads(r.read())
        # FWCI / 引用
        fwci = d.get('fwci', None)
        cited = d.get('cited_by_count', 0)
        if fwci is not None:
            print(f"  📊 OpenAlex: FWCI={fwci:.2f} · 引用 {cited} 次")
        # abstract
        inv = d.get('abstract_inverted_index')
        if inv:
            words = sorted([(pos, w) for w, ps in inv.items() for pos in ps])
            abstract = ' '.join(w for _, w in words)
            if any(0xAC00 <= ord(c) <= 0xD7A3 for c in abstract):
                abstract_kor = abstract
            else:
                print(f"  · OpenAlex abstract: 英文版（{len(abstract)} 字符）")
                with open("$OUTDIR/abstract_en.txt", "w") as f:
                    f.write(abstract)
        sources_tried.append("OpenAlex")
except Exception as e:
    pass

if abstract_kor:
    with open("$OUTDIR/abstract_kor.txt", "w") as f:
        f.write(abstract_kor)
    print(f"  ✅ 抓到韩文 abstract ({len(abstract_kor)} 字符) → abstract_kor.txt")
else:
    print(f"  ⚠️ 韩文 abstract 自动抓取失败（已试 {', '.join(sources_tried)}）")
    print(f"     建议手动从 DBpia / Kyobo Scholar 复制（公开内容）")
PYEOF
fi

# ─── 3. RISS 详情页抓取（如果给的是 RISS URL）───
if [ -n "$RISS_URL" ]; then
  echo ""
  echo "── ③ RISS 详情页抓取 ──"
  python3 << PYEOF
import warnings; warnings.filterwarnings("ignore")
import trafilatura, re
url = "$RISS_URL"
try:
    html = trafilatura.fetch_url(url)
    text = trafilatura.extract(html or '', include_tables=True, favor_precision=False, output_format='txt') or ''

    # 抓 DOI
    m_doi = re.search(r'10\.\d{4,9}/[\w\.\-/]+', text)
    if m_doi:
        print(f"  DOI: {m_doi.group(0)}")

    # 抓作者
    m_author = re.search(r'(저자|작성자)[\s:：]+([가-힯·\s,]+)', text)
    if m_author:
        print(f"  作者: {m_author.group(2).strip()}")

    # 抓章节大纲（목차）
    m_toc = re.search(r'목차[\s\S]{0,2000}?(?=초록|발행|키워드|참고문헌|관련|$)', text)
    if m_toc:
        toc = m_toc.group(0)
        print(f"")
        print(f"  📚 章节大纲（목차）:")
        for line in toc.split('\n')[:30]:
            line = line.strip()
            if line and line != '목차':
                print(f"    {line}")

    with open("$OUTDIR/riss_raw.txt", "w") as f:
        f.write(text)
    print(f"")
    print(f"  ✅ 原文已存: $OUTDIR/riss_raw.txt")
except Exception as e:
    print(f"  ❌ RISS 抓取失败: {e}")
PYEOF
fi

# ─── 4. 学者邮箱推断 ───
echo ""
echo "── ④ 作者邮箱推断 ──"
echo "  韩国学者邮箱常规格式（推测，请到机构网站核实）:"
echo "    - 연세대 (Yonsei): firstname.lastname@yonsei.ac.kr"
echo "    - 서울대 (SNU):    id@snu.ac.kr"
echo "    - 고려대 (Korea):  id@korea.ac.kr"
echo "    - <你的学校>:      查 config.json 的 university.email_pattern"
echo "  → 推荐查 Google Scholar 作者主页或机构网站验证邮箱"

# ─── 5. 三语邮件模板 ───
echo ""
echo "── ⑤ 三语邮件模板 ──"
MAIL_FILE="$OUTDIR/邮件模板_三语.md"
cat > "$MAIL_FILE" << 'MAILEOF'
# 学者论文请求邮件 · 三语模板

> 用于韩国 KCI 论文全文无法通过 OA 渠道获取时，向作者本人请求。
> 韩国学者通常会在 2-3 天内回复（学界惯例较友好）。

---

## 韩文版（首选 · 显示尊重）

```
제목: [논문 PDF 요청] {논문 제목}

존경하는 {교수님 이름} 교수님께,

안녕하세요. 저는 {본인 소속}에서 박사과정을 밟고 있는 {본인 이름}입니다.

교수님께서 작성하신 다음 논문을 제 박사논문 연구에 참고하고자 하나,
저희 학교 도서관 SSO로 접근이 불가능합니다:

  · 제목: {논문 제목}
  · 저널: {저널명}, Vol.{호}, No.{권}, pp.{페이지}
  · DOI: {DOI}

가능하시다면 PDF 사본을 보내주실 수 있는지 부탁드립니다.
연구 목적 외에는 사용하지 않을 것을 약속드립니다.

바쁘신 와중에 부탁드려 죄송합니다.
감사합니다.

{본인 이름}
{본인 소속} 박사과정
{본인 이메일}
```

---

## 中文版（备注用，发送时不带）

```
标题: [论文 PDF 请求] {论文标题}

尊敬的 {教授姓名} 教授：

您好。我是 {本人单位} 的博士生 {本人姓名}。

我希望参考您撰写的以下论文用于我的博士论文研究，
但通过我校图书馆 SSO 无法访问：

  · 标题: {论文标题}
  · 期刊: {期刊名}, Vol.{卷}, No.{期}, pp.{页码}
  · DOI: {DOI}

如可能，恳请您能将 PDF 副本发送给我。我承诺仅用于研究目的。

冒昧请求，多有打扰，深表歉意。
感谢您。

{本人姓名}
{本人单位} 博士生
{本人邮箱}
```

---

## 英文版（学者英语好的话也可用）

```
Subject: [Paper PDF Request] {Paper title}

Dear Prof. {Last name},

I hope this email finds you well. I am {your name}, a PhD candidate at {your institution}.

I would like to cite your following paper in my doctoral dissertation,
but I cannot access it through my university library SSO:

  · Title: {Paper title}
  · Journal: {Journal name}, Vol.{vol}, No.{issue}, pp.{pages}
  · DOI: {DOI}

If possible, could you kindly send me a PDF copy? I assure you it will be used
solely for research purposes.

Apologies for the imposition. Thank you very much for your time.

Best regards,
{Your name}
PhD Candidate, {Your institution}
{Your email}
```

---

## 发送前 checklist

- [ ] {占位符} 全部替换
- [ ] 作者邮箱已通过机构网站核实（不是猜的）
- [ ] 用韩文版（最有礼貌，回复率最高）
- [ ] 邮件签名包含你的真实身份（学校+学号+导师）
- [ ] 抄送你的导师（提高可信度，可选）
MAILEOF

echo "  ✅ 模板已存: $MAIL_FILE"

# ─── 6. 图书馆 SSO 跳转 ───
echo ""
echo "── ⑥ 图书馆 SSO 退路 ──"
# 从 config 读 SSO 域名
CONFIG=~/Desktop/快速阅读/config.json
SSO_DOMAIN=""
if [ -f "$CONFIG" ]; then
  SSO_DOMAIN=$(python3 -c "import json;print(json.load(open('$CONFIG'))['university'].get('sso_domain',''))" 2>/dev/null)
fi
if [ -n "$SSO_DOMAIN" ] && [ "$SSO_DOMAIN" != "?" ]; then
  echo "  通过你的学校（$SSO_DOMAIN）图书馆代理:"
  if [ -n "$DOI" ]; then
    echo "  · DBpia 代理: https://www-dbpia-co-kr.${SSO_DOMAIN}/journal/articleDetail?doi=$DOI"
  fi
else
  echo "  ⚠️ config.json 未配置 university.sso_domain"
fi
echo "  · RISS 一般无需代理，但 PDF 下载需要登录学校账号"

# ─── 7. 总结 ───
echo ""
echo "════════════════════════════════════════════════════"
echo "📋 完成。输出文件:"
ls -la "$OUTDIR/" 2>&1 | tail -n +2
echo ""
echo "下一步:"
echo "  1. 看 $OUTDIR/riss_raw.txt 拿章节大纲"
echo "  2. 用 $MAIL_FILE 给作者发邮件"
echo "  3. 收到 PDF 后跑: 通用提取.sh paper.pdf"
echo "════════════════════════════════════════════════════"
