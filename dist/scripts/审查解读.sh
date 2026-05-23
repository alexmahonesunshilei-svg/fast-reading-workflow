#!/bin/bash
# ============================================================
# 解读真实性审查脚本（防 AI 幻觉）
#
# 用法: ./审查解读.sh <解读卡.md> <PDF文本.txt>
# ============================================================

set -e

CARD="$1"
PDF_TXT="$2"

if [ -z "$CARD" ] || [ ! -f "$CARD" ]; then
  echo "❌ 解读卡不存在: $CARD"
  exit 1
fi

if [ -z "$PDF_TXT" ] || [ ! -f "$PDF_TXT" ]; then
  echo "❌ PDF 文本不存在: $PDF_TXT"
  exit 1
fi

echo "════════════════════════════════════════════════════"
echo "🔍 解读真实性审查"
echo "  解读卡: $CARD"
echo "  原文:   $PDF_TXT"
echo "════════════════════════════════════════════════════"
echo ""

REPORT="/tmp/审查报告_$(date +%s).md"
TMP_PY="/tmp/audit_$(date +%s).py"

cat > "$TMP_PY" << 'PYEOF'
import re
import sys
import os

card_path = sys.argv[1]
pdf_path = sys.argv[2]

with open(card_path, encoding='utf-8') as f:
    card = f.read()
with open(pdf_path, encoding='utf-8') as f:
    pdf = f.read()

page_marks = re.findall(r'=== PAGE (\d+)', pdf)
total_pages = max(int(p) for p in page_marks) if page_marks else 0

print(f"# 解读真实性审查报告")
print(f"")
print(f"- 解读卡: {card_path}")
print(f"- 原文: {pdf_path}")
print(f"- 原文总页数: {total_pages}")
print(f"- 解读卡字符数: {len(card)}")
print(f"")
print(f"---")
print(f"")

# ─── 1. 页码引用真实性 ───
print(f"## 1. 页码引用真实性")
print(f"")
page_refs = re.findall(r'p\.?\s*(\d+)(?:[-–](\d+))?', card)
invalid_pages = []
for ref in page_refs:
    start = int(ref[0])
    end = int(ref[1]) if ref[1] else start
    if start > total_pages or end > total_pages or start < 1:
        invalid_pages.append((start, end))

if invalid_pages:
    print(f"❌ 发现 {len(invalid_pages)} 处无效页码引用（论文只有 {total_pages} 页）:")
    print(f"")
    for s, e in invalid_pages[:20]:
        print(f"  - p.{s}" + (f"–{e}" if e != s else ""))
else:
    print(f"✅ 共 {len(page_refs)} 处页码引用，全部在 1-{total_pages} 范围内")
print(f"")

# ─── 2. 引用原句真实性 ───
print(f"## 2. 引用原句真实性（在 PDF 中查找）")
print(f"")

quotes_md = re.findall(r'^>\s*["「『](.+?)["」』]', card, re.MULTILINE)
quotes_inline = re.findall(r'["「『](.{20,200}?)["」』]', card)
all_quotes = list(set(quotes_md + quotes_inline))
candidate_quotes = [q for q in all_quotes if 20 <= len(q) <= 200]

def normalize(s):
    s = re.sub(r'[\*_`#]', '', s)
    s = re.sub(r'\s+', '', s)
    return s

pdf_norm = normalize(pdf)

verified = 0
unverified = []
for q in candidate_quotes:
    q_norm = normalize(q)
    if q_norm in pdf_norm or (len(q_norm) >= 30 and q_norm[:30] in pdf_norm):
        verified += 1
    else:
        unverified.append(q[:80])

total = len(candidate_quotes)
if total == 0:
    print(f"⚠️  解读卡里没有发现长引用句（≥20 字符）")
elif unverified:
    pct = 100 * verified // total if total else 0
    print(f"⚠️  共 {total} 条引用：{verified} 条在 PDF 找到（{pct}%），{len(unverified)} 条未找到")
    print(f"")
    for q in unverified[:10]:
        print(f"  - {q}...")
    if len(unverified) > 10:
        print(f"  ... 还有 {len(unverified)-10} 条")
else:
    print(f"✅ 共 {total} 条引用，全部在 PDF 中找到")
print(f"")

# ─── 3. 学者人名引用 ───
print(f"## 3. 学者人名引用核查")
print(f"")
scholar_refs = set()
scholar_refs.update(re.findall(r'([가-힯]{2,4})\s*\(', card))
scholar_refs.update(re.findall(r'([一-龿]{2,4})《', card))
scholar_refs.update(re.findall(r'引([一-龿]{2,4})', card))
scholar_refs = [s for s in scholar_refs if len(s) >= 2]

if scholar_refs:
    print(f"卡中提到的学者（抽样前 15）: {', '.join(list(scholar_refs)[:15])}")
    print(f"")
    not_in_pdf = [s for s in scholar_refs if s not in pdf]
    if not_in_pdf:
        print(f"⚠️  {len(not_in_pdf)} 个学者名未在 PDF 中出现:")
        print(f"")
        for s in not_in_pdf[:10]:
            print(f"  - {s}")
    else:
        print(f"✅ 所有学者名都在 PDF 中能找到")
else:
    print(f"（未检测到学者引用）")
print(f"")

# ─── 4. 年份核查 ───
print(f"## 4. 年份引用核查")
print(f"")
years_in_card = set(re.findall(r'\b(1[89]\d{2}|20[0-2]\d)\b', card))
years_in_pdf = set(re.findall(r'\b(1[89]\d{2}|20[0-2]\d)\b', pdf))
missing_years = years_in_card - years_in_pdf
if missing_years:
    print(f"⚠️  解读卡中有 {len(missing_years)} 个年份未在 PDF 出现: {sorted(missing_years)[:15]}")
    print(f"")
    print(f"（这可能是 Agent 添加的背景年份，需要人工判断是否合理）")
else:
    print(f"✅ 解读卡中的年份都能在 PDF 中找到")
print(f"")

# ─── 5. 总结 ───
print(f"---")
print(f"")
print(f"## 总结")
print(f"")
serious = len(invalid_pages) + (len(unverified) // 3 if total > 0 else 0)
if serious == 0:
    print(f"✅ **审查通过** — 没有明显幻觉迹象")
    exit_code = 0
elif serious < 3:
    print(f"⚠️  **审查警告** — 发现 {serious} 类小问题，建议人工抽查后再发布")
    exit_code = 0
else:
    print(f"❌ **审查不通过** — 发现 {serious} 类问题，建议修复后再发布")
    exit_code = 1

print(f"")
print(f"## 建议下一步")
print(f"")
print(f"1. 调用 **scholar-citation-verification** skill 对所有引用做最终核验")
print(f"2. 调用 **diss-citation-integrity** skill 做三角验证")
print(f"3. 如有韩中翻译，调用 **diss-bilingual-bridge** skill 核查术语")

sys.exit(exit_code)
PYEOF

set +e
python3 "$TMP_PY" "$CARD" "$PDF_TXT" > "$REPORT" 2>&1
EXIT=$?
set -e

echo "📋 报告已生成: $REPORT"
echo ""
cat "$REPORT"
echo ""

# ─── agentmemory 钩子（审查通过时提示）───
if [ "$EXIT" = "0" ]; then
  echo "════════════════════════════════════════════════════"
  echo "💾 [AGENTMEMORY-HOOK] 审查通过 · 建议存进长期记忆"
  echo "════════════════════════════════════════════════════"
  echo ""
  echo "  Agent 看到这行后，应该读"
  echo "    ~/Desktop/快速阅读/脚本/agentmemory_存档.md"
  echo "  按"4 类候选"问用户存哪些。"
  echo ""
  echo "  快速触发口令: \"存进长记\" / \"记住这个\""
  echo ""
fi

rm -f "$TMP_PY"
exit $EXIT
