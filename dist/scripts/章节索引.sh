#!/bin/bash
# ============================================================
# 章节素材索引 · 自动维护"已读材料 → 博论章节"反查表
#
# 扫描所有 库/**/解读卡_三档.md，提取 §10 论文挂载点，
# 生成反查表写入 库/_论文章节索引.md。
#
# 用法: ./章节索引.sh
# ============================================================

set -e

PROJECT=~/Desktop/快速阅读
INDEX="$PROJECT/库/_论文章节索引.md"
TMP_PY="/tmp/chapter_index_$(date +%s).py"

echo "════════════════════════════════════════════════════"
echo "📚 章节素材索引 · 扫描所有解读卡"
echo "════════════════════════════════════════════════════"

CARDS=$(find "$PROJECT/库" \( -name "解读卡_三档.md" -o -name "公开信息解读卡.md" \) 2>/dev/null | wc -l | tr -d ' ')
echo "  发现 $CARDS 张解读卡"
echo ""

if [ "$CARDS" -eq 0 ]; then
  echo "❌ 没找到任何解读卡_三档.md"
  exit 1
fi

cat > "$TMP_PY" << 'PYEOF'
import os, re, glob, datetime
from collections import defaultdict

project = os.path.expanduser("~/Desktop/快速阅读")
cards = sorted(
    glob.glob(project + "/库/**/解读卡_三档.md", recursive=True) +
    glob.glob(project + "/库/**/公开信息解读卡.md", recursive=True)
)

CHAPTERS = ["绪论", "理论框架", "第3章本体", "第4章案例", "第5章对比", "结论"]
LEVELS = ["上位", "本位", "下位"]

chapter_data = defaultdict(list)
level_count = defaultdict(int)
missing_section10 = []
all_entries = []

def extract_section10(text):
    m = re.search(r'##\s*10\.?\s*论文挂载点.*?\n([\s\S]*?)(?=\n##\s|\Z)', text)
    if not m: return None
    body = m.group(1)
    info = {}
    for line in body.split('\n'):
        line = line.strip()
        if not line.startswith('|') or '---' in line: continue
        parts = [p.strip() for p in line.split('|') if p.strip()]
        if len(parts) < 2: continue
        info[parts[0]] = parts[1]
    return info

def get_book_title(text, card_path):
    m = re.search(r'\|\s*(?:中文)?标题\s*\|\s*([^|\n]+)', text)
    if m: return m.group(1).strip().strip('《》"\' ')
    return os.path.basename(os.path.dirname(card_path))

for card_path in cards:
    with open(card_path, encoding='utf-8') as f:
        text = f.read()
    title = get_book_title(text, card_path)
    rel_path = os.path.relpath(card_path, project)
    info = extract_section10(text)
    if not info:
        missing_section10.append((title, rel_path))
        continue

    level = info.get('三层定位', '?')
    chapters = info.get('对接章节', '?')
    usage = info.get('用作', '?')
    one_line = info.get('一句话定位', '')
    priority = info.get('优先级', '🟢 备用')

    for L in LEVELS:
        if L in level:
            level_count[L] += 1

    for ch in CHAPTERS:
        if ch in chapters or ch.replace('第', '').replace('章', '') in chapters:
            chapter_data[ch].append({
                'title': title, 'level': level, 'usage': usage,
                'one_line': one_line, 'priority': priority, 'path': rel_path
            })

    all_entries.append({
        'title': title, 'level': level, 'chapters': chapters,
        'priority': priority, 'path': rel_path
    })

# Build markdown
out = []
out.append("# 博士论文章节素材索引")
out.append("")
now = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
out.append("> 自动维护表 · 最后生成: " + now)
out.append("> 扫描了 " + str(len(cards)) + " 张解读卡，" + str(len(all_entries)) + " 张已填 §10，" + str(len(missing_section10)) + " 张缺 §10")
out.append("")
out.append("---")
out.append("")
out.append("## 上中下位框架（提醒）")
out.append("")
out.append("- **上位**: 整体话语场（中国新主流的概念史/政策环境/批评史）")
out.append("- **本位**: 英雄美学的本体框架（你的核心论证）")
out.append("- **下位**: 具体案例分析（《长津湖》《战狼》《八佰》《志愿军》等）")
out.append("")
out.append("---")
out.append("")
out.append("## 章节素材分布")
out.append("")
out.append("| 章节 | 已挂 | 上位 | 本位 | 下位 | 缺口 |")
out.append("|---|---|---|---|---|---|")

for ch in CHAPTERS:
    entries = chapter_data[ch]
    n = len(entries)
    n_up = sum(1 for e in entries if '上位' in e['level'])
    n_mid = sum(1 for e in entries if '本位' in e['level'])
    n_down = sum(1 for e in entries if '下位' in e['level'])
    if n == 0:
        warn = "🔴 0 篇 · 该补"
    elif n < 3:
        warn = "🟡 少于 3 篇"
    else:
        warn = "✅ 充足"
    out.append("| " + ch + " | " + str(n) + " | " + str(n_up) + " | " + str(n_mid) + " | " + str(n_down) + " | " + warn + " |")

out.append("")
out.append("**层级总分布**: 上位 " + str(level_count['上位']) + " · 本位 " + str(level_count['本位']) + " · 下位 " + str(level_count['下位']))
out.append("")
out.append("---")
out.append("")
out.append("## 详细挂载")
out.append("")

for ch in CHAPTERS:
    entries = chapter_data[ch]
    if not entries: continue
    out.append("### " + ch)
    out.append("")
    out.append("| 标题 | 层级 | 用作 | 优先级 | 一句话定位 |")
    out.append("|---|---|---|---|---|")
    pri_rank = {'🔴': 0, '🟡': 1, '🟢': 2}
    entries.sort(key=lambda e: pri_rank.get(e['priority'][:1], 3))
    for e in entries:
        out.append("| " + e['title'] + " | " + e['level'] + " | " + e['usage'] + " | " + e['priority'] + " | " + e['one_line'] + " |")
    out.append("")

out.append("---")
out.append("")
out.append("## 缺口与补救（自动建议）")
out.append("")

gaps = []
for ch in CHAPTERS:
    n = len(chapter_data[ch])
    if n == 0:
        gaps.append("- 🔴 **" + ch + "** 没有任何已挂材料 → 该章是空的，需要专门检索")
    elif n < 3:
        gaps.append("- 🟡 **" + ch + "** 只有 " + str(n) + " 篇材料 → 建议再读 " + str(3-n) + " 篇")

if level_count['上位'] < 5:
    gaps.append("- 🟡 **上位**层只有 " + str(level_count['上位']) + " 篇 → 上位话语场需要更多支撑材料")
if level_count['本位'] < 5:
    gaps.append("- 🟡 **本位**层只有 " + str(level_count['本位']) + " 篇 → 本位框架需要更多理论文献")
if level_count['下位'] < 8:
    gaps.append("- 🟡 **下位**层只有 " + str(level_count['下位']) + " 篇 → 案例分析需要更多影片精读")

if not gaps:
    out.append("✅ 当前覆盖充足，继续保持。")
else:
    for g in gaps:
        out.append(g)

if missing_section10:
    out.append("")
    out.append("---")
    out.append("")
    out.append("## ⚠️ 缺 §10 论文挂载点的卡（需要补）")
    out.append("")
    for title, path in missing_section10:
        out.append("- " + title + " · `" + path + "`")

index_path = os.path.expanduser("~/Desktop/快速阅读/库/_论文章节索引.md")
with open(index_path, 'w', encoding='utf-8') as f:
    f.write('\n'.join(out))

print("")
print("📊 统计:")
print("   总卡数:      " + str(len(cards)))
print("   已填 §10:    " + str(len(all_entries)))
print("   缺 §10:      " + str(len(missing_section10)))
print("")
print("   上位:        " + str(level_count['上位']))
print("   本位:        " + str(level_count['本位']))
print("   下位:        " + str(level_count['下位']))
print("")
for ch in CHAPTERS:
    n = len(chapter_data[ch])
    marker = "🔴" if n == 0 else ("🟡" if n < 3 else "✅")
    print("   " + marker + " " + ch + ": " + str(n) + " 篇")
print("")
print("✅ 索引已更新: " + index_path)
PYEOF

python3 "$TMP_PY"
rm -f "$TMP_PY"

echo ""
echo "════════════════════════════════════════════════════"
echo "📋 查看索引: open $INDEX"
echo "════════════════════════════════════════════════════"
