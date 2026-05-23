#!/bin/bash
# ============================================================
# 全文可获取性诊断 + 自动抓取（5 级降级）
#
# 用法:
#   ./查全文.sh "<DOI 或 URL 或 论文标题>"
#
# 输入可以是：
#   - DOI: 10.1234/example
#   - URL: https://...
#   - 标题: "Chinese Road Movies in Post-2000"
# ============================================================

set -e

INPUT="$1"
if [ -z "$INPUT" ]; then
  echo "用法: $0 <DOI 或 URL 或 标题>"
  exit 1
fi

echo "════════════════════════════════════════════════════"
echo "🔍 全文获取诊断: $INPUT"
echo "════════════════════════════════════════════════════"
echo ""

# ============ 判断输入类型 ============
if [[ "$INPUT" =~ ^10\..+/ ]]; then
  DOI="$INPUT"
  echo "🔢 识别为 DOI: $DOI"
elif [[ "$INPUT" =~ ^https?:// ]]; then
  URL="$INPUT"
  echo "🌐 识别为 URL: $URL"
else
  TITLE="$INPUT"
  echo "📝 识别为标题（将搜索 DOI）: $TITLE"
fi

# ============ Try 1: OpenAlex API ============
echo ""
echo "━━━ Try 1: OpenAlex API (全球最大 OA 索引) ━━━"
if [ -n "$DOI" ]; then
  QUERY_URL="https://api.openalex.org/works/doi:$DOI"
elif [ -n "$TITLE" ]; then
  ESCAPED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$TITLE'))")
  QUERY_URL="https://api.openalex.org/works?search=$ESCAPED&per_page=5"
else
  QUERY_URL=""
fi

if [ -n "$QUERY_URL" ]; then
  RESULT=$(curl -s "$QUERY_URL" 2>/dev/null || echo "")
  if [ -n "$RESULT" ]; then
    # 用 python 解析
    python3 << PYEOF
import json
try:
    r = json.loads('''$RESULT''')
    if 'results' in r:
        # 是搜索结果列表
        for i, w in enumerate(r['results'][:5]):
            oa = w.get('open_access', {})
            pdf = (w.get('best_oa_location') or {}).get('pdf_url') or oa.get('oa_url')
            print(f"  [{i+1}] {w.get('title','?')[:80]}")
            print(f"      年份: {w.get('publication_year')} | 引用: {w.get('cited_by_count',0)}")
            print(f"      OA: {'🟢' if oa.get('is_oa') else '🔴'} | PDF: {pdf or '(无)'}")
    else:
        # 是单条结果
        w = r
        oa = w.get('open_access', {})
        pdf = (w.get('best_oa_location') or {}).get('pdf_url') or oa.get('oa_url')
        print(f"  标题: {w.get('title','?')[:80]}")
        print(f"  作者: {', '.join([a['author']['display_name'] for a in w.get('authorships',[])[:3]])}")
        print(f"  OA 状态: {'🟢 公开' if oa.get('is_oa') else '🔴 不公开'}")
        print(f"  PDF 直链: {pdf or '(无 OA 直链)'}")
        if pdf:
            print(f"\n  💡 可直接尝试下载: curl -L -o paper.pdf '{pdf}'")
except Exception as e:
    print(f"  ⚠️  OpenAlex 解析失败: {e}")
PYEOF
  else
    echo "  ⚠️  OpenAlex 无响应"
  fi
fi

# ============ Try 2: CrossRef API (DOI/许可) ============
if [ -n "$DOI" ]; then
  echo ""
  echo "━━━ Try 2: CrossRef API (DOI 许可信息) ━━━"
  curl -s "https://api.crossref.org/works/$DOI" 2>/dev/null | python3 -c "
import json, sys
try:
    r = json.load(sys.stdin)['message']
    print(f\"  标题: {' '.join(r.get('title',['?'])[0:1])[:80]}\")
    print(f\"  许可: {[l['URL'] for l in r.get('license',[])] or '(无)'}\")
    print(f\"  PDF 链接候选: {[l['URL'] for l in r.get('link',[])][:3] or '(无)'}\")
except:
    print('  ⚠️  CrossRef 无响应或解析失败')
"
fi

# ============ Try 3: arXiv 探测 ============
if [ -n "$TITLE" ]; then
  echo ""
  echo "━━━ Try 3: arXiv (预印本) ━━━"
  ESCAPED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$TITLE'))")
  curl -s "http://export.arxiv.org/api/query?search_query=ti:$ESCAPED&max_results=3" 2>/dev/null | \
    python3 -c "
import sys, re
data = sys.stdin.read()
ids = re.findall(r'<id>(http://arxiv\\.org/abs/[^<]+)</id>', data)
for url in ids[:3]:
    print(f'  📄 {url} → PDF: {url.replace(\"/abs/\", \"/pdf/\")}.pdf')
if not ids:
    print('  (arXiv 无命中)')
"
fi

# ============ Try 4: Google Scholar 提示 ============
echo ""
echo "━━━ Try 4: Google Scholar / ResearchGate (手动) ━━━"
if [ -n "$TITLE" ]; then
  ESCAPED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$TITLE filetype:pdf'))")
  echo "  在浏览器打开:"
  echo "    https://scholar.google.com/scholar?q=$ESCAPED"
  echo "    https://www.google.com/search?q=$ESCAPED"
  echo "    https://www.researchgate.net/search/publication?q=$ESCAPED"
fi

# ============ Try 5: 联系作者邮件草稿 ============
echo ""
echo "━━━ Try 5: 联系作者邮件草稿 (兜底) ━━━"
echo "  如果以上都拿不到，运行:"
echo "    ~/Desktop/快速阅读/脚本/生成请求邮件.sh \"<论文标题>\" \"<作者邮箱>\""

echo ""
echo "════════════════════════════════════════════════════"
echo "✅ 诊断完毕。请根据上面给出的链接尝试抓取。"
echo "════════════════════════════════════════════════════"
