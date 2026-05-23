#!/bin/bash
# ============================================================
# 跨库全文搜索 · 一次搜遍所有解读卡 + 元数据 + 库索引
#
# 用法:
#   ./搜库.sh <关键词>                  # 搜全部
#   ./搜库.sh "福柯" --chapter 第3章本体  # 按章节过滤
#   ./搜库.sh "叙事" --priority 必引     # 按优先级过滤
#   ./搜库.sh "英雄" --type long         # 只看长文卡（>5000 字）
# ============================================================

set -e

KW="$1"
shift || true

CHAPTER=""
PRIORITY=""
CARD_TYPE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --chapter) CHAPTER="$2"; shift 2;;
    --priority) PRIORITY="$2"; shift 2;;
    --type) CARD_TYPE="$2"; shift 2;;
    *) shift;;
  esac
done

if [ -z "$KW" ]; then
  cat << EOF
用法: $0 <关键词> [选项]

例:
  $0 福柯
  $0 "叙事机器" --chapter 第3章本体
  $0 英雄 --priority 必引

选项:
  --chapter <章节>     只搜挂到该章的卡（绪论/理论框架/第3章本体...）
  --priority <级别>    只搜优先级（必引/可选/备用）
  --type <类型>        只搜类型（long=三档卡 / short=变体G公开信息卡 / all）

输出:
  按相关度排序 · 标题命中 > 摘要命中 > 正文命中
EOF
  exit 1
fi

PROJECT=~/Desktop/快速阅读
TMP_PY="/tmp/searchlib_$(date +%s).py"

cat > "$TMP_PY" << 'PYEOF'
import os, re, glob, sys, json
from collections import defaultdict

kw = sys.argv[1]
chapter_filter = sys.argv[2] if len(sys.argv) > 2 else ""
priority_filter = sys.argv[3] if len(sys.argv) > 3 else ""
type_filter = sys.argv[4] if len(sys.argv) > 4 else ""

project = os.path.expanduser("~/Desktop/快速阅读")

cards = sorted(
    glob.glob(project + "/库/**/解读卡_三档.md", recursive=True) +
    glob.glob(project + "/库/**/公开信息解读卡.md", recursive=True) +
    glob.glob(project + "/库/**/元数据.md", recursive=True)
)

results = []

for path in cards:
    try:
        with open(path, encoding='utf-8') as f:
            text = f.read()
    except: continue

    rel = os.path.relpath(path, project)
    is_short = '公开信息' in os.path.basename(path) or '元数据' in os.path.basename(path)
    chars = len(text)

    # 类型过滤
    if type_filter == 'long' and is_short: continue
    if type_filter == 'short' and not is_short: continue

    # 章节/优先级过滤（从 §10 抽）
    sec10 = re.search(r'##\s*10\.?\s*论文挂载点[\s\S]*?(?=\n##\s|\Z)', text)
    chapter_text = ""
    priority_text = ""
    if sec10:
        m1 = re.search(r'\|\s*对接章节\s*\|\s*([^|\n]+)', sec10.group(0))
        m2 = re.search(r'\|\s*优先级\s*\|\s*([^|\n]+)', sec10.group(0))
        chapter_text = m1.group(1).strip() if m1 else ""
        priority_text = m2.group(1).strip() if m2 else ""

    if chapter_filter and chapter_filter not in chapter_text: continue
    if priority_filter and priority_filter not in priority_text: continue

    # 搜
    kw_re = re.compile(re.escape(kw), re.IGNORECASE)
    matches = list(kw_re.finditer(text))
    if not matches: continue

    # 相关度评分
    # +10 标题命中, +5 §1-§2 命中, +2 其他命中, +1 normal
    score = 0
    contexts = []
    seen_pos = set()
    for m in matches:
        pos = m.start()
        # 找位置在哪一节
        prev_text = text[:pos]
        section = "正文"
        if "# " in prev_text:
            last_h1 = prev_text.rfind('\n# ')
            last_h2 = prev_text.rfind('\n## ')
            if last_h2 > last_h1:
                line_end = text.find('\n', last_h2 + 1)
                section = text[last_h2+4:line_end].strip()[:30]

        # 标题级别 = 第一行
        if pos < 200: score += 10
        elif '元信息' in section or '精髓' in section: score += 5
        elif '论文挂载点' in section: score += 5
        else: score += 2

        # 上下文
        ctx_start = max(0, pos - 40)
        ctx_end = min(len(text), pos + 80)
        ctx = text[ctx_start:ctx_end].replace('\n', ' ').strip()
        ctx = re.sub(re.escape(kw), '【' + kw + '】', ctx, flags=re.IGNORECASE)
        contexts.append((section, ctx))

    # 标题（§1 抓或第一行）
    m_t = re.search(r'\|\s*(?:中文)?标题\s*\|\s*([^|\n]+)', text)
    if m_t:
        title = m_t.group(1).strip().strip('《》"\' ')
    else:
        title = text.split('\n')[0].lstrip('# ').strip()[:40]

    results.append({
        'title': title, 'path': rel, 'chars': chars,
        'score': score, 'hits': len(matches),
        'chapter': chapter_text, 'priority': priority_text,
        'contexts': contexts[:3]  # 限 3 条
    })

# 排序
results.sort(key=lambda r: (-r['score'], -r['hits']))

# 输出
print("════════════════════════════════════════════════════")
print("🔍 搜库结果: 关键词 \"" + kw + "\"")
if chapter_filter: print("   过滤章节: " + chapter_filter)
if priority_filter: print("   过滤优先级: " + priority_filter)
print("   命中: " + str(len(results)) + " 张卡 (共扫 " + str(len(cards)) + " 张)")
print("════════════════════════════════════════════════════")
print("")

if not results:
    print("（无命中）")
    sys.exit(0)

for i, r in enumerate(results, 1):
    print(f"【{i}】 {r['title']}")
    print(f"     分数 {r['score']} · 命中 {r['hits']} 次 · {r['chars']} 字符")
    if r['chapter']: print(f"     章节: {r['chapter']}  |  优先级: {r['priority']}")
    print(f"     📁 {r['path']}")
    for section, ctx in r['contexts']:
        print(f"        [{section}] …{ctx}…")
    print()

print("提示: open <文件路径> 直接看卡")
PYEOF

python3 "$TMP_PY" "$KW" "$CHAPTER" "$PRIORITY" "$CARD_TYPE"
rm -f "$TMP_PY"
