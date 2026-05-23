#!/bin/bash
# ============================================================
# 解读卡质量打分 · 6 维 × 各 10 分 = 满分 60
#
# 6 维:
#   1. 元信息完整度
#   2. §10 论文挂载点填写度
#   3. 字数达标（按变体）
#   4. §4 机器拆解结构（子标题/表格）
#   5. 引用真实性（接 审查解读.sh 结果，如有 PDF）
#   6. 与博论关联清晰度
#
# 用法:
#   ./打分.sh <解读卡.md>
#   ./打分.sh <解读卡.md> <PDF文本.txt>  # 含引用真实性
# ============================================================

set -e

CARD="$1"
PDF_TXT="$2"

if [ -z "$CARD" ] || [ ! -f "$CARD" ]; then
  echo "用法: $0 <解读卡.md> [PDF文本.txt]"
  exit 1
fi

TMP_PY="/tmp/score_$(date +%s).py"

cat > "$TMP_PY" << 'PYEOF'
import os, re, sys, json

card_path = sys.argv[1]
pdf_path = sys.argv[2] if len(sys.argv) > 2 else ""

with open(card_path, encoding='utf-8') as f:
    text = f.read()

# 加载 config（如存在）
config = {}
try:
    with open(os.path.expanduser("~/Desktop/快速阅读/config.json")) as f:
        config = json.load(f)
except: pass

thresholds = config.get('quality_thresholds', {})
tier3_min = thresholds.get('tier3_min_chars', 8000)
tier3_max = thresholds.get('tier3_max_chars', 25000)
g_min = thresholds.get('variant_g_min_chars', 1500)
g_max = thresholds.get('variant_g_max_chars', 4000)
passing = thresholds.get('passing_score', 60)

# 判断变体
is_variant_g = '公开信息' in os.path.basename(card_path) or '基于公开信息' in text[:500]
variant = "G (公开信息卡)" if is_variant_g else "A-F (三档卡)"
chars = len(text)

scores = {}
reasons = {}

# ── 维度 1: 元信息完整度 ──
m_meta = re.search(r'##\s*1\.[^\n]*\n([\s\S]*?)(?=\n##\s)', text)
required_fields = ['标题', '作者', '年份', '期刊']
if is_variant_g: required_fields = ['DOI', '标题', '作者', '期刊']

if m_meta:
    filled = sum(1 for f in required_fields if re.search(r'\|\s*(?:中文)?' + f + r'\s*\|\s*[^|\n?]+\|', m_meta.group(0)) or re.search(r'\|\s*' + f + r'\s*\|\s*[^|\n?]+\|', m_meta.group(0)))
    s1 = int(10 * filled / len(required_fields))
    reasons['元信息完整度'] = f"{filled}/{len(required_fields)} 必填字段"
else:
    s1 = 0
    reasons['元信息完整度'] = "缺 §1"
scores['元信息完整度'] = s1

# ── 维度 2: §10 论文挂载点填写度 ──
m_sec10 = re.search(r'##\s*10\.?\s*论文挂载点[\s\S]*?(?=\n##\s|\Z)', text)
if m_sec10:
    body = m_sec10.group(0)
    mount_fields = ['三层定位', '对接章节', '用作', '一句话定位', '优先级']
    filled = 0
    for f in mount_fields:
        m = re.search(r'\|\s*' + f + r'\s*\|\s*([^|\n]+)', body)
        if m and m.group(1).strip() not in ['', '?', '-', '空', '无']:
            filled += 1
    s2 = int(10 * filled / len(mount_fields))
    reasons['§10 挂载度'] = f"{filled}/{len(mount_fields)} 字段填了"
else:
    s2 = 0
    reasons['§10 挂载度'] = "缺 §10"
scores['§10 挂载度'] = s2

# ── 维度 3: 字数达标 ──
if is_variant_g:
    if g_min <= chars <= g_max:
        s3 = 10; reasons['字数达标'] = f"{chars} 字符（变体 G 区间 {g_min}-{g_max} 内）"
    elif chars < g_min:
        s3 = max(0, int(10 * chars / g_min)); reasons['字数达标'] = f"{chars} 字符（短于 {g_min}）"
    else:
        s3 = max(5, 10 - (chars - g_max) // 500); reasons['字数达标'] = f"{chars} 字符（超 {g_max}，但变体 G 宜短）"
else:
    if tier3_min <= chars <= tier3_max:
        s3 = 10; reasons['字数达标'] = f"{chars} 字符（三档区间 {tier3_min}-{tier3_max} 内）"
    elif chars < tier3_min:
        s3 = max(0, int(10 * chars / tier3_min)); reasons['字数达标'] = f"{chars} 字符（短于 {tier3_min}，三档要求更长）"
    else:
        s3 = max(7, 10 - (chars - tier3_max) // 2000); reasons['字数达标'] = f"{chars} 字符（超出 {tier3_max}）"
scores['字数达标'] = s3

# ── 维度 4: §4 机器拆解结构 ──
if is_variant_g:
    # 变体 G 不要求 §4
    s4 = 10; reasons['§4 结构'] = "变体 G 免检"
else:
    m_sec4 = re.search(r'##\s*4\.[^\n]*\n([\s\S]*?)(?=\n##\s)', text)
    if m_sec4:
        body = m_sec4.group(1)
        subs = len(re.findall(r'^###\s+', body, re.MULTILINE))
        tables = body.count('|---')
        if subs >= 3 or tables >= 2:
            s4 = 10; reasons['§4 结构'] = f"{subs} 个子标题 · {tables} 张表"
        elif subs >= 1 or tables >= 1:
            s4 = 6; reasons['§4 结构'] = f"{subs} 个子标题 · {tables} 张表（建议 ≥3 子标题）"
        else:
            s4 = 3; reasons['§4 结构'] = "无子标题/无表，结构松散"
    else:
        s4 = 0; reasons['§4 结构'] = "缺 §4"
scores['§4 结构'] = s4

# ── 维度 5: 引用真实性 ──
if not pdf_path or not os.path.isfile(pdf_path):
    if is_variant_g:
        # 变体 G 不引原文，所以不扣
        s5 = 10; reasons['引用真实'] = "变体 G 不引原文，免检"
    else:
        s5 = 5; reasons['引用真实'] = "未提供 PDF 文本，无法核验（自动给 5/10）"
else:
    with open(pdf_path, encoding='utf-8') as f:
        pdf = f.read()
    # 用类似审查脚本的简化逻辑
    page_marks = re.findall(r'=== PAGE (\d+)', pdf)
    total_pages = max(int(p) for p in page_marks) if page_marks else 0
    page_refs = re.findall(r'p\.?\s*(\d+)', text)
    invalid = sum(1 for r in page_refs if int(r) > total_pages or int(r) < 1)
    pct_invalid = invalid / max(1, len(page_refs))
    s5 = int(10 * (1 - pct_invalid))
    reasons['引用真实'] = f"{len(page_refs)} 处页码引用，{invalid} 处越界"
scores['引用真实'] = s5

# ── 维度 6: 与博论关联清晰度 ──
m_one_line = re.search(r'\|\s*一句话定位\s*\|\s*([^|\n]+)', text)
m_level = re.search(r'\|\s*三层定位\s*\|\s*([^|\n]+)', text)
if m_one_line and m_one_line.group(1).strip() not in ['', '?', '-']:
    one_line = m_one_line.group(1).strip()
    level = m_level.group(1).strip() if m_level else ""
    if len(one_line) >= 30 and any(L in level for L in ['上位', '本位', '下位']):
        s6 = 10; reasons['博论关联'] = f"清晰（{len(one_line)} 字定位 + 层级明确）"
    elif len(one_line) >= 15:
        s6 = 7; reasons['博论关联'] = f"基本清晰（{len(one_line)} 字定位）"
    else:
        s6 = 4; reasons['博论关联'] = f"太短（仅 {len(one_line)} 字）"
elif '⚪' in (m_one_line.group(1) if m_one_line else "") or '仅记录' in text[-2000:]:
    s6 = 10; reasons['博论关联'] = "明确标记为 ⚪ 仅记录（也算清晰判断）"
else:
    s6 = 0; reasons['博论关联'] = "缺一句话定位"
scores['博论关联'] = s6

# ── 总分 ──
total = sum(scores.values())
percentage = int(total / 60 * 100)

# 等级
if total >= 55: grade = "🏆 优秀"
elif total >= passing: grade = "✅ 合格"
elif total >= 40: grade = "🟡 待补"
else: grade = "🔴 重做"

# 输出
print("════════════════════════════════════════════════════")
print(f"📊 解读卡质量打分")
print("════════════════════════════════════════════════════")
print(f"  文件: {os.path.basename(card_path)}")
print(f"  变体: {variant}")
print(f"  总字符: {chars}")
print("")
print(f"  📈 {total}/60 ({percentage}%) — {grade}")
print("")
print("── 6 维明细 ──")
print(f"  {'维度':<14} {'得分':<6} 详情")
print(f"  {'-'*50}")
for k, v in scores.items():
    bar = "█" * v + "░" * (10 - v)
    print(f"  {k:<12} {v:>2}/10 {bar}  {reasons[k]}")

print("")

# 改进建议
print("── 改进建议 ──")
suggestions = []
for k, v in scores.items():
    if v < 7:
        if k == '元信息完整度': suggestions.append(f"补 §1 缺失字段: {reasons[k]}")
        elif k == '§10 挂载度': suggestions.append("填 §10 论文挂载点（每张卡必填）")
        elif k == '字数达标': suggestions.append("调整字数到目标区间")
        elif k == '§4 结构': suggestions.append("§4 加 ≥3 个子标题或 ≥2 张表")
        elif k == '引用真实': suggestions.append("跑 审查解读.sh 核验引用 + 修正越界页码")
        elif k == '博论关联': suggestions.append("§10 一句话定位写满 30 字以上 + 明确上/本/下位")

if suggestions:
    for s in suggestions:
        print(f"  · {s}")
else:
    print(f"  ✅ 全维度合格，无需改进")

# 雷达图
print("")
print("── Mermaid 雷达图（可贴到 mermaid.live 渲染）──")
print("```mermaid")
print("xychart-beta")
print('    title "解读卡质量 6 维"')
print('    x-axis ["元信息", "§10挂载", "字数", "§4结构", "引用", "博论关联"]')
print('    y-axis "得分" 0 --> 10')
print('    bar [' + ','.join(str(v) for v in scores.values()) + ']')
print("```")

sys.exit(0 if total >= passing else 1)
PYEOF

python3 "$TMP_PY" "$CARD" "$PDF_TXT"
EXIT=$?
rm -f "$TMP_PY"
exit $EXIT
