#!/bin/bash
# ============================================================
# 抓取真实性校验脚本
#
# 校验抓到的 PDF 是不是真的论文：
#  ✓ 文件大小 > 50KB
#  ✓ 页数 ≥ 3
#  ✓ 可提取文本 ≥ 1000 字符
#  ✓ 不是登录页 / 错误页 / 摘要页
#  ✓ 语言检测（韩/中/英）
#  ✓ 含学术结构特征（摘要/参考文献/章节标题）
#
# 用法: ./抓取校验.sh <PDF 路径> [文本缓存路径]
# ============================================================

PDF="$1"
TXT="$2"

if [ -z "$PDF" ] || [ ! -f "$PDF" ]; then
  echo "❌ PDF 不存在: $PDF"
  exit 1
fi

# 如果没传文本缓存，临时抽
if [ -z "$TXT" ]; then
  TXT=$(mktemp /tmp/check_XXXXXX.txt)
  python3 -c "
from pypdf import PdfReader
r = PdfReader('$PDF')
with open('$TXT','w',encoding='utf-8') as f:
    for p in r.pages: f.write(p.extract_text()+'\n')
" 2>/dev/null
fi

echo "════════════════════════════════════════════════════"
echo "🔍 抓取真实性校验: $(basename "$PDF")"
echo "════════════════════════════════════════════════════"

PASS=0
FAIL=0
WARN=0

check() {
  local name="$1"
  local result="$2"
  local msg="$3"
  if [ "$result" = "pass" ]; then
    echo "  ✅ $name: $msg"
    PASS=$((PASS+1))
  elif [ "$result" = "warn" ]; then
    echo "  ⚠️  $name: $msg"
    WARN=$((WARN+1))
  else
    echo "  ❌ $name: $msg"
    FAIL=$((FAIL+1))
  fi
}

# ─── 1. 文件大小 ───
SIZE=$(stat -f%z "$PDF" 2>/dev/null || stat -c%s "$PDF" 2>/dev/null)
SIZE_KB=$((SIZE / 1024))
if [ "$SIZE_KB" -lt 50 ]; then
  check "文件大小" "fail" "${SIZE_KB} KB（< 50KB，可能是错误页或登录页）"
elif [ "$SIZE_KB" -lt 100 ]; then
  check "文件大小" "warn" "${SIZE_KB} KB（< 100KB，建议人工确认）"
else
  check "文件大小" "pass" "${SIZE_KB} KB"
fi

# ─── 2. 页数 ───
PAGES=$(python3 -c "from pypdf import PdfReader; print(len(PdfReader('$PDF').pages))" 2>/dev/null)
if [ -z "$PAGES" ] || [ "$PAGES" -lt 3 ]; then
  check "页数" "fail" "${PAGES:-0} 页（< 3 页，可疑）"
elif [ "$PAGES" -lt 5 ]; then
  check "页数" "warn" "${PAGES} 页（短篇论文/海报，建议人工确认）"
else
  check "页数" "pass" "${PAGES} 页"
fi

# ─── 3. 可提取文本量 ───
CHARS=$(wc -m < "$TXT" 2>/dev/null | tr -d ' ')
if [ -z "$CHARS" ] || [ "$CHARS" -lt 1000 ]; then
  check "文本提取" "fail" "${CHARS:-0} 字符（< 1000，可能是扫描件/图片 PDF/被加密）"
elif [ "$CHARS" -lt 5000 ]; then
  check "文本提取" "warn" "${CHARS} 字符（< 5000，建议人工确认）"
else
  check "文本提取" "pass" "${CHARS} 字符"
fi

# ─── 4. 登录页 / 错误页特征 ───
DANGER_PATTERNS=$(grep -ciE "login required|로그인|sign in|access denied|404|not found|forbidden|please log in|회원가입|구독|sign up|subscribe" "$TXT" 2>/dev/null | head -1 || echo 0)
DANGER_PATTERNS=${DANGER_PATTERNS:-0}
if [ "$DANGER_PATTERNS" -gt 10 ]; then
  check "登录/错误页特征" "fail" "命中 $DANGER_PATTERNS 次（很可能不是真论文）"
elif [ "$DANGER_PATTERNS" -gt 3 ]; then
  check "登录/错误页特征" "warn" "命中 $DANGER_PATTERNS 次（建议人工确认）"
else
  check "登录/错误页特征" "pass" "命中 $DANGER_PATTERNS 次（正常）"
fi

# ─── 5. 语言检测 ───
KO_CHARS=$(python3 -c "
import re
with open('$TXT', encoding='utf-8') as f:
    text = f.read()
ko = len(re.findall(r'[가-힯]', text))
print(ko)
" 2>/dev/null || echo 0)
CN_CHARS=$(python3 -c "
import re
with open('$TXT', encoding='utf-8') as f:
    text = f.read()
cn = len(re.findall(r'[一-鿿]', text))
print(cn)
" 2>/dev/null || echo 0)
EN_CHARS=$(python3 -c "
import re
with open('$TXT', encoding='utf-8') as f:
    text = f.read()
en = len(re.findall(r'[a-zA-Z]', text))
print(en)
" 2>/dev/null || echo 0)

LANG_TOTAL=$((KO_CHARS + CN_CHARS + EN_CHARS))
if [ "$LANG_TOTAL" -lt 500 ]; then
  check "语言检测" "fail" "韩 $KO_CHARS / 中 $CN_CHARS / 英 $EN_CHARS（实质文本太少）"
else
  MAIN=""
  if [ $KO_CHARS -gt $CN_CHARS ] && [ $KO_CHARS -gt $EN_CHARS ]; then MAIN="韩文"
  elif [ $CN_CHARS -gt $EN_CHARS ]; then MAIN="中文"
  else MAIN="英文"
  fi
  check "语言检测" "pass" "主语言: $MAIN（韩 $KO_CHARS / 中 $CN_CHARS / 英 $EN_CHARS）"
fi

# ─── 6. 学术结构特征 ───
ACADEMIC=$(grep -ciE "abstract|초록|摘要|references|참고문헌|参考文献|introduction|서론|绪论|conclusion|결론|结论|doi|논문|论文|article|연구" "$TXT" 2>/dev/null | head -1 || echo 0)
ACADEMIC=${ACADEMIC:-0}
if [ "$ACADEMIC" -lt 3 ]; then
  check "学术结构特征" "fail" "命中 $ACADEMIC 次（不像学术论文）"
elif [ "$ACADEMIC" -lt 8 ]; then
  check "学术结构特征" "warn" "命中 $ACADEMIC 次（可疑）"
else
  check "学术结构特征" "pass" "命中 $ACADEMIC 次"
fi

# ─── 总结 ───
echo ""
echo "──────────────────────────────────────"
echo "通过: $PASS  警告: $WARN  失败: $FAIL"
echo "──────────────────────────────────────"

if [ "$FAIL" -gt 0 ]; then
  echo "❌ 抓取校验未通过：$FAIL 项失败"
  echo "建议：检查 PDF 是否真实完整，或重新抓取"
  exit 1
elif [ "$WARN" -gt 2 ]; then
  echo "⚠️  抓取校验勉强通过：$WARN 项警告"
  echo "建议人工确认后再继续"
  exit 0
else
  echo "✅ 抓取校验通过"
  exit 0
fi
