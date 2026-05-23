#!/bin/bash
# ============================================================
# PDF 关键页美化截图脚本 v2
#
# 用 PyMuPDF 渲染 + PIL 美化关键页:
#   ✓ 自动裁白边（智能边距保留）
#   ✓ 加柔和灰色边框
#   ✓ 角部柔和阴影（背景投影感）
#   ✓ 高 DPI 输出（180 DPI 默认）
#
# 用法: ./pdf_截图.sh <PDF 路径> <输出目录> [--style 默认|纯净|杂志]
# ============================================================

PDF="$1"
OUTDIR="$2"
STYLE="${3:-默认}"

if [ -z "$PDF" ] || [ ! -f "$PDF" ]; then
  echo "❌ PDF 不存在: $PDF"
  echo "用法: $0 <PDF> <输出目录> [--style 默认|纯净|杂志]"
  exit 1
fi

if [ -z "$OUTDIR" ]; then
  OUTDIR="$(dirname "$PDF")/pages"
fi

mkdir -p "$OUTDIR"
echo "🖼  PDF 美化截图: $(basename "$PDF") → $OUTDIR (风格: $STYLE)"

python3 << PYEOF
import fitz  # PyMuPDF
from PIL import Image, ImageOps, ImageDraw, ImageFilter, ImageChops
import os
import io

doc = fitz.open("$PDF")
n = len(doc)
out_dir = "$OUTDIR"
style = "$STYLE"

# 计算每页文本密度
densities = []
for i, page in enumerate(doc):
    text = page.get_text()
    densities.append((i, len(text)))

# 选择关键页
selected = set()
selected.add(0)                                          # 封面
if n > 1: selected.add(1)                                # 摘要/目录
for i, _ in sorted(densities, key=lambda x: -x[1])[:5]:  # 文本密度最高 3-5 页
    if i >= 2 and i < n - 2:
        selected.add(i)
    if len(selected) >= 7: break
if n >= 3: selected.add(n - 2)                            # 参考文献
if len(selected) < 5 and n >= 5:
    for i in [n // 4, n // 2, 3 * n // 4]:
        selected.add(i)

# ─── 美化函数 ───
def auto_crop_whitespace(img, padding=20):
    """智能裁掉白边，保留 padding 像素余白"""
    bg = Image.new(img.mode, img.size, (255, 255, 255))
    diff = ImageChops.difference(img, bg)
    bbox = diff.getbbox()
    if bbox:
        return img.crop((
            max(0, bbox[0] - padding),
            max(0, bbox[1] - padding),
            min(img.width, bbox[2] + padding),
            min(img.height, bbox[3] + padding)
        ))
    return img

def add_border(img, border=2, color='#CCCCCC'):
    """添加柔和细边框"""
    return ImageOps.expand(img, border=border, fill=color)

def add_soft_shadow(img, offset=8, blur=12, opacity=80):
    """添加柔和投影（卡片悬浮感）"""
    # 创建阴影层
    shadow = Image.new('RGBA', (img.width + offset*2, img.height + offset*2), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rectangle(
        [offset, offset, img.width + offset, img.height + offset],
        fill=(0, 0, 0, opacity)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))

    # 合成
    canvas = Image.new('RGBA', shadow.size, (255, 255, 255, 255))
    canvas.paste(shadow, (0, 0), shadow)
    img_rgba = img.convert('RGBA')
    canvas.paste(img_rgba, (offset // 2, offset // 2), img_rgba)
    return canvas.convert('RGB')

def beautify(img, style):
    """统一美化入口"""
    img = auto_crop_whitespace(img, padding=15)
    if style == '纯净':
        # 仅裁白边
        return img
    elif style == '杂志':
        # 裁边 + 细边框
        return add_border(img, border=1, color='#DDDDDD')
    else:  # 默认
        # 裁边 + 细灰边框 + 柔和投影
        img = add_border(img, border=2, color='#CCCCCC')
        img = add_soft_shadow(img, offset=6, blur=8, opacity=50)
        return img

# 渲染（180 DPI）
zoom = 180 / 72
mat = fitz.Matrix(zoom, zoom)

count = 0
for i in sorted(selected):
    page = doc[i]
    pix = page.get_pixmap(matrix=mat)

    # PyMuPDF → PIL
    img_data = pix.tobytes("png")
    img = Image.open(io.BytesIO(img_data))

    # 美化
    img = beautify(img, style)

    # 保存（PNG 优化压缩）
    out_path = os.path.join(out_dir, f"page_{i+1:03d}.png")
    img.save(out_path, optimize=True, compress_level=6)
    size_kb = os.path.getsize(out_path) // 1024
    print(f"  ✅ 第 {i+1:3d} 页 ({densities[i][1]:5d} 字符) → page_{i+1:03d}.png ({size_kb} KB · {img.width}×{img.height}px)")
    count += 1

doc.close()
print(f"\n  📊 共 {count} 张美化截图，风格: {style}")
PYEOF
