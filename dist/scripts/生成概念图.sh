#!/bin/bash
# ============================================================
# 解读卡概念图生成 · 自动从 §3 / §4 / §10 抽关键节点
# 生成 mermaid 图，追加到解读卡末尾
#
# 用法: ./生成概念图.sh <解读卡_三档.md>
# ============================================================

set -e

CARD="$1"

if [ -z "$CARD" ] || [ ! -f "$CARD" ]; then
  cat << EOF
用法: $0 <解读卡_三档.md>

例: $0 ~/Desktop/快速阅读/库/02-书籍/dangnianmingyue_2009_mingdynastythings/解读卡_三档.md

功能:
  从解读卡的 §3 精髓 + §4 机器拆解 + §10 论文挂载点
  抽 5-8 个关键节点 → 生成 mermaid 概念图，追加到卡末尾
EOF
  exit 1
fi

TMP_PY="/tmp/mermaid_gen_$(date +%s).py"

cat > "$TMP_PY" << 'PYEOF'
import re, sys

card_path = sys.argv[1]
with open(card_path, encoding='utf-8') as f:
    text = f.read()

# 标题
m_title = re.search(r'\|\s*(?:中文)?标题\s*\|\s*([^|\n]+)', text)
title = m_title.group(1).strip().strip('《》"\' ') if m_title else "本文"
if len(title) > 20: title = title[:18] + "…"

# 精髓
m_essence = re.search(r'##\s*3\.[^\n]*\n([\s\S]*?)(?=\n##\s)', text)
essence = ""
if m_essence:
    body = m_essence.group(1)
    m = re.search(r'\*\*那一招\*\*[：:]\s*([^\n]+)', body) or \
        re.search(r'\*\*精髓\*\*[：:]\s*([^\n]+)', body)
    if m:
        essence = m.group(1).strip()
    else:
        lines = [l.strip() for l in body.split('\n') if l.strip() and not l.startswith('|')]
        essence = lines[0] if lines else ""
    essence = re.sub(r'[\*_`]', '', essence)[:30]

# 机制（§4 子标题）
m_sec4 = re.search(r'##\s*4\.[^\n]*\n([\s\S]*?)(?=\n##\s)', text)
mechanisms = []
if m_sec4:
    body = m_sec4.group(1)
    subs = re.findall(r'###\s+([^\n]+)', body)
    if not subs:
        subs = re.findall(r'\*\*([^\*\n]{3,20})\*\*', body)
    for s in subs[:4]:
        s = re.sub(r'[（(].*?[）)]', '', s).strip()
        if len(s) > 15: s = s[:13] + "…"
        if s: mechanisms.append(s)

# 论文挂载点
m_sec10 = re.search(r'##\s*10\.[^\n]*\n([\s\S]*?)(?=\n##\s|\Z)', text)
chapter = ""
level = ""
one_line = ""
if m_sec10:
    body = m_sec10.group(1)
    m_ch = re.search(r'\|\s*对接章节\s*\|\s*([^|\n]+)', body)
    m_lv = re.search(r'\|\s*三层定位\s*\|\s*([^|\n]+)', body)
    m_ol = re.search(r'\|\s*一句话定位\s*\|\s*([^|\n]+)', body)
    chapter = m_ch.group(1).strip() if m_ch else ""
    level = m_lv.group(1).strip() if m_lv else ""
    one_line = m_ol.group(1).strip() if m_ol else ""
    if len(one_line) > 25: one_line = one_line[:23] + "…"

# 生成 mermaid
lines = []
lines.append("---")
lines.append("")
lines.append("## 11. 概念地图（自动生成）")
lines.append("")
lines.append("```mermaid")
lines.append("graph TD")
lines.append('    A["' + title + '"] --> B["精髓: ' + (essence or "(空)") + '"]')

for i, mech in enumerate(mechanisms):
    node_id = chr(ord('C') + i)
    lines.append('    A --> ' + node_id + '["' + mech + '"]')

if chapter or level:
    lines.append('    A --> M["博论挂载: ' + chapter + ' · ' + level + '"]')
    if one_line:
        lines.append('    M --> N["' + one_line + '"]')

lines.append("    style A fill:#ffd700,stroke:#333,stroke-width:3px")
lines.append("    style B fill:#e1f5ff,stroke:#0288d1")
if chapter or level:
    lines.append("    style M fill:#c8e6c9,stroke:#388e3c")
lines.append("```")
lines.append("")
lines.append("*概念地图自动生成自 §3 精髓 + §4 机器拆解 + §10 挂载点*")

new_block = '\n'.join(lines)

if re.search(r'##\s*11\.[^\n]*概念地图', text):
    new_text = re.sub(
        r'(?:^---\s*\n\s*\n)?##\s*11\.[^\n]*概念地图[\s\S]*?(?=\n##\s|\Z)',
        new_block + '\n', text, count=1, flags=re.MULTILINE)
    action = "替换"
else:
    new_text = text.rstrip() + '\n\n' + new_block + '\n'
    action = "追加"

with open(card_path, 'w', encoding='utf-8') as f:
    f.write(new_text)

print("✅ 已 " + action + " §11 概念地图到: " + card_path)
print("")
print("  标题节点: " + title)
print("  精髓节点: " + (essence or "(空)"))
print("  机制节点: " + str(len(mechanisms)) + " 个 — " + str(mechanisms))
print("  挂载节点: " + chapter + " · " + level)
print("")
print("渲染建议:")
print("  - VSCode 装 'Markdown Preview Mermaid Support' 插件")
print("  - 或贴到 https://mermaid.live 在线渲染")
print("  - docx 输出: 用 validate_and_render_mermaid_diagram MCP 转 SVG 嵌入")
PYEOF

python3 "$TMP_PY" "$CARD"
rm -f "$TMP_PY"

echo ""
echo "════════════════════════════════════════════════════"
echo "📋 查看: open \"$CARD\""
echo "════════════════════════════════════════════════════"
