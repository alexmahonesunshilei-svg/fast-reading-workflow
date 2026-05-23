#!/bin/bash
# ============================================================
# 快速阅读工作流 · 首次安装检测脚本
#
# 检测：Python 模块 + Node 包 + 命令行工具 + 配置文件
# 缺失项：提示安装命令（不擅自装）
#
# 用法: ./init.sh
# ============================================================

set +e  # 不要因单个检测失败而退出

PROJECT=~/Desktop/快速阅读
PASS=0
FAIL=0
WARN=0

check_pass() { PASS=$((PASS+1)); echo "  ✅ $1"; }
check_fail() { FAIL=$((FAIL+1)); echo "  ❌ $1"; echo "     → $2"; }
check_warn() { WARN=$((WARN+1)); echo "  ⚠️  $1"; echo "     → $2"; }

echo "════════════════════════════════════════════════════"
echo "🔍 快速阅读工作流 v4.6 · 依赖检测"
echo "════════════════════════════════════════════════════"
echo ""

# ─── 1. 命令行工具 ───
echo "── ① 命令行工具 ──"
for cmd in python3 node bash curl ffprobe; do
  if command -v "$cmd" >/dev/null 2>&1; then
    VER=$($cmd --version 2>&1 | head -1)
    check_pass "$cmd: $VER"
  else
    case "$cmd" in
      python3) check_fail "$cmd 未装" "brew install python@3.11";;
      node) check_fail "$cmd 未装" "brew install node";;
      ffprobe) check_warn "$cmd 未装（音视频需要）" "brew install ffmpeg";;
      *) check_fail "$cmd 未装" "brew install $cmd";;
    esac
  fi
done
echo ""

# ─── 2. Python 模块 ───
echo "── ② Python 模块 ──"
PYMOD=(pypdf ebooklib docx PIL trafilatura requests bs4)
for mod in "${PYMOD[@]}"; do
  if python3 -c "import $mod" 2>/dev/null; then
    check_pass "python: $mod"
  else
    case "$mod" in
      docx) check_fail "python: python-docx 未装" "pip3 install --user python-docx";;
      PIL) check_fail "python: Pillow 未装" "pip3 install --user Pillow";;
      bs4) check_fail "python: beautifulsoup4 未装" "pip3 install --user beautifulsoup4";;
      *) check_fail "python: $mod 未装" "pip3 install --user $mod";;
    esac
  fi
done

# pyhwp 单独检查
if [ -f "$HOME/Library/Python/3.9/bin/hwp5txt" ] || command -v hwp5txt >/dev/null 2>&1; then
  check_pass "python: pyhwp (hwp5txt)"
else
  check_warn "python: pyhwp 未装（韩文 HWP 需要）" "pip3 install --user pyhwp"
fi
echo ""

# ─── 3. Node 包 ───
echo "── ③ Node 包 ──"
if npm list -g docx 2>/dev/null | grep -q docx@; then
  DOCX_VER=$(npm list -g docx 2>/dev/null | grep docx@ | head -1 | sed 's/.*docx@//')
  check_pass "node: docx@$DOCX_VER"
else
  check_fail "node: docx 未装" "npm install -g docx"
fi
echo ""

# ─── 4. 可选 · whisper.cpp（音视频）───
echo "── ④ 可选 · 音视频转写 ──"
if [ -f "$HOME/.whisper.cpp/build/bin/whisper-cli" ]; then
  check_pass "whisper.cpp 已装"
  if [ -f "$HOME/.whisper.cpp/models/ggml-base.bin" ]; then
    check_pass "whisper 模型: ggml-base"
  else
    check_warn "whisper 模型未下" "bash 脚本/音视频转写.sh --install"
  fi
else
  check_warn "whisper.cpp 未装（音视频需要）" "bash 脚本/音视频转写.sh --install"
fi
echo ""

# ─── 5. 工作流文件 ───
echo "── ⑤ 工作流文件 ──"
REQUIRED_FILES=(
  "config.json"
  "README.md"
  "Skills集成矩阵.md"
  "模板/解读卡模板套件_v4.md"
  "模板/docx_template.js"
  "脚本/通用提取.sh"
  "脚本/审查解读.sh"
  "脚本/打分.sh"
  "脚本/章节索引.sh"
  "脚本/搜库.sh"
)
for f in "${REQUIRED_FILES[@]}"; do
  if [ -f "$PROJECT/$f" ]; then
    check_pass "$f"
  else
    check_fail "$f 缺失" "git 拉新版或手动重建"
  fi
done
echo ""

# ─── 6. 目录 ───
echo "── ⑥ 库目录 ──"
for d in "库" "库/01-文献论文" "库/02-书籍" "库/03-小说散文" "库/04-采访对谈" "库/05-网文长文" "模板" "脚本" "收件箱" "解读卡片" "清理日志"; do
  if [ -d "$PROJECT/$d" ]; then
    count=$(find "$PROJECT/$d" -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    check_pass "$d  ($((count-1)) 子项)"
  else
    check_warn "$d 不存在" "mkdir -p \"$PROJECT/$d\""
  fi
done
echo ""

# ─── 7. config.json 校验 ───
echo "── ⑦ config.json 校验 ──"
if [ -f "$PROJECT/config.json" ]; then
  if python3 -c "import json; json.load(open('$PROJECT/config.json'))" 2>/dev/null; then
    check_pass "config.json 合法 JSON"
    # 检查关键字段
    for key in "user.name_zh" "university.sso_domain" "advisor.name_zh" "dissertation.chapters"; do
      val=$(python3 -c "import json; d=json.load(open('$PROJECT/config.json')); k='$key'.split('.'); v=d; [v:=v[i] for i in k]; print(v)" 2>/dev/null)
      if [ -n "$val" ] && [ "$val" != "?" ]; then
        check_pass "config: $key"
      else
        check_warn "config: $key 未填" "编辑 $PROJECT/config.json"
      fi
    done
  else
    check_fail "config.json 不是合法 JSON" "重新生成或修复语法"
  fi
fi
echo ""

# ─── 总结 ───
echo "════════════════════════════════════════════════════"
TOTAL=$((PASS + FAIL + WARN))
echo "📊 检测完成: $TOTAL 项 · 通过 $PASS · 警告 $WARN · 失败 $FAIL"
echo ""

if [ "$FAIL" -eq 0 ] && [ "$WARN" -eq 0 ]; then
  echo "✅ 工作流就绪。开始你的下一次精读吧！"
  echo ""
  echo "下一步建议："
  echo "  bash 脚本/通用提取.sh <你的 PDF>"
  echo "  # 然后跟 Claude Code 说：'按 v4.6 流程精读'"
elif [ "$FAIL" -eq 0 ]; then
  echo "🟡 核心就绪。可选项缺失，但不影响主流程。"
else
  echo "🔴 核心依赖缺失。按上面的 → 提示装齐再用。"
fi
echo "════════════════════════════════════════════════════"
