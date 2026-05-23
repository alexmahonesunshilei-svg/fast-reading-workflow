#!/bin/bash
# ============================================================
# 通用材料提取脚本 v1
#
# 支持 6 种类型：
#   PDF       → pypdf 抽文本
#   EPUB      → ebooklib（电子书）
#   DOCX      → python-docx
#   HTML/URL  → trafilatura（智能正文提取）
#   TXT/MD    → 直接读
#   HWP       → pyhwp（韩国 Hangul 文档）
#
# 用法: ./通用提取.sh <文件路径或 URL> [输出 txt 路径]
# ============================================================

INPUT="$1"
OUT="${2:-}"

if [ -z "$INPUT" ]; then
  cat << EOF
用法: $0 <文件路径或 URL> [输出 txt 路径]

支持的输入类型:
  ✓ PDF              → pypdf
  ✓ EPUB             → ebooklib
  ✓ DOCX             → python-docx
  ✓ HWP（韩国）       → pyhwp
  ✓ HTML / URL        → trafilatura
  ✓ TXT / MD          → 直接读

输出: 统一文本 + 元信息（类型/页/字数等）
EOF
  exit 1
fi

# 默认输出路径
if [ -z "$OUT" ]; then
  TIMESTAMP=$(date +%s)
  OUT="/tmp/extract_${TIMESTAMP}.txt"
fi

# 识别类型
TYPE=""
if [[ "$INPUT" =~ ^https?:// ]]; then
  TYPE="url"
else
  if [ ! -f "$INPUT" ]; then
    echo "❌ 文件不存在: $INPUT"
    exit 1
  fi
  EXT="${INPUT##*.}"
  EXT_LOWER=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')
  case "$EXT_LOWER" in
    pdf) TYPE="pdf" ;;
    epub) TYPE="epub" ;;
    docx) TYPE="docx" ;;
    hwp) TYPE="hwp" ;;
    html|htm) TYPE="html" ;;
    md|markdown|txt) TYPE="text" ;;
    mp3|mp4|m4a|wav|mov|aac|flac|ogg|webm) TYPE="audio_video" ;;
    *) TYPE="unknown" ;;
  esac
fi

echo "════════════════════════════════════════════════════"
echo "📥 通用提取: $INPUT"
echo "   识别类型: $TYPE"
echo "   输出: $OUT"
echo "════════════════════════════════════════════════════"

case "$TYPE" in

  pdf)
    python3 << PYEOF
from pypdf import PdfReader
r = PdfReader("$INPUT")
total = 0
with open("$OUT", "w", encoding="utf-8") as f:
    f.write(f"=== 类型: PDF ===\n=== 来源: $INPUT ===\n=== 总页数: {len(r.pages)} ===\n\n")
    for i, p in enumerate(r.pages):
        t = p.extract_text() or ""
        total += len(t)
        f.write(f"=== PAGE {i+1} (chars: {len(t)}) ===\n{t}\n\n")
print(f"✅ {len(r.pages)} 页 / {total} 字符 → $OUT")
PYEOF
    ;;

  epub)
    python3 << PYEOF
from ebooklib import epub
from bs4 import BeautifulSoup
import warnings
warnings.filterwarnings("ignore")

book = epub.read_epub("$INPUT")
title = book.get_metadata('DC', 'title')
author = book.get_metadata('DC', 'creator')

with open("$OUT", "w", encoding="utf-8") as f:
    f.write(f"=== 类型: EPUB ===\n=== 来源: $INPUT ===\n")
    f.write(f"=== 标题: {title[0][0] if title else '?'} ===\n")
    f.write(f"=== 作者: {author[0][0] if author else '?'} ===\n\n")

    total_chars = 0
    chapter_count = 0
    for item in book.get_items():
        if item.get_type() == 9:  # ITEM_DOCUMENT
            soup = BeautifulSoup(item.get_content(), 'html.parser')
            for s in soup(['script', 'style']):
                s.decompose()
            text = soup.get_text()
            lines = [line.strip() for line in text.splitlines() if line.strip()]
            text = '\n'.join(lines)
            if len(text) > 100:
                chapter_count += 1
                total_chars += len(text)
                f.write(f"=== CHAPTER {chapter_count} (chars: {len(text)}) ===\n{text}\n\n")

print(f"✅ EPUB · {chapter_count} 章 / {total_chars} 字符 → $OUT")
PYEOF
    ;;

  docx)
    python3 << PYEOF
import docx
d = docx.Document("$INPUT")
total = 0
with open("$OUT", "w", encoding="utf-8") as f:
    f.write(f"=== 类型: DOCX ===\n=== 来源: $INPUT ===\n\n")
    for i, para in enumerate(d.paragraphs):
        t = para.text
        if t.strip():
            total += len(t)
            f.write(t + "\n")
    # 表格
    for ti, tbl in enumerate(d.tables):
        f.write(f"\n=== TABLE {ti+1} ===\n")
        for row in tbl.rows:
            f.write(" | ".join(c.text for c in row.cells) + "\n")
print(f"✅ DOCX · {total} 字符 / {len(d.paragraphs)} 段 / {len(d.tables)} 表 → $OUT")
PYEOF
    ;;

  hwp)
    # pyhwp 命令行
    HWP5TXT="$HOME/Library/Python/3.9/bin/hwp5txt"
    if [ ! -f "$HWP5TXT" ]; then
      pip3 install --user --quiet pyhwp 2>&1 | tail -2
    fi
    {
      echo "=== 类型: HWP ==="
      echo "=== 来源: $INPUT ==="
      echo ""
      "$HWP5TXT" "$INPUT" 2>/dev/null
    } > "$OUT"
    CHARS=$(wc -m < "$OUT")
    echo "✅ HWP · $CHARS 字符 → $OUT"
    ;;

  url)
    python3 << PYEOF
import warnings
warnings.filterwarnings("ignore")
import trafilatura
import requests

url = "$INPUT"
try:
    downloaded = trafilatura.fetch_url(url)
    if not downloaded:
        # 备用方案：requests
        r = requests.get(url, timeout=15, headers={'User-Agent': 'Mozilla/5.0'})
        downloaded = r.text
    text = trafilatura.extract(downloaded, include_links=False, include_tables=True,
                                 favor_precision=False, output_format='txt')
    meta = trafilatura.extract_metadata(downloaded)
    with open("$OUT", "w", encoding="utf-8") as f:
        f.write(f"=== 类型: URL ===\n=== 来源: $INPUT ===\n")
        if meta:
            f.write(f"=== 标题: {meta.title or '?'} ===\n")
            f.write(f"=== 作者: {meta.author or '?'} ===\n")
            f.write(f"=== 日期: {meta.date or '?'} ===\n")
            f.write(f"=== 出处: {meta.sitename or '?'} ===\n")
        f.write("\n")
        f.write(text or '(提取失败)')
    chars = len(text or '')
    print(f"✅ URL · {chars} 字符 → $OUT")
except Exception as e:
    print(f"❌ URL 提取失败: {e}")
PYEOF
    ;;

  html)
    python3 << PYEOF
import warnings
warnings.filterwarnings("ignore")
import trafilatura
with open("$INPUT", encoding="utf-8") as f:
    html = f.read()
text = trafilatura.extract(html, include_tables=True, favor_precision=False)
meta = trafilatura.extract_metadata(html)
with open("$OUT", "w", encoding="utf-8") as f:
    f.write(f"=== 类型: HTML ===\n=== 来源: $INPUT ===\n")
    if meta:
        f.write(f"=== 标题: {meta.title or '?'} ===\n")
    f.write("\n")
    f.write(text or '(提取失败)')
chars = len(text or '')
print(f"✅ HTML · {chars} 字符 → $OUT")
PYEOF
    ;;

  text)
    cp "$INPUT" "$OUT"
    CHARS=$(wc -m < "$OUT")
    echo "✅ 纯文本 · $CHARS 字符 → $OUT"
    ;;

  audio_video)
    echo "→ 检测到音视频文件，转发到 音视频转写.sh"
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    if [ ! -f "$SCRIPT_DIR/音视频转写.sh" ]; then
      echo "❌ 找不到 音视频转写.sh"
      exit 1
    fi
    bash "$SCRIPT_DIR/音视频转写.sh" "$INPUT"
    # 转写脚本会自己输出最终位置；如果想接到 $OUT，让用户手动 cp
    echo ""
    echo "提示：转写产物在上面的 'extracted.txt' 路径，如需重定向到 $OUT 请手动 cp"
    ;;

  *)
    echo "❌ 不支持的类型: $TYPE"
    exit 1
    ;;
esac

echo ""
echo "── 提取完成。可作为后续阅读/解读的输入 ──"
