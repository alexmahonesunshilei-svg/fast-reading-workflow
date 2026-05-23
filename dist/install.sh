#!/bin/bash
# ============================================================
# 快速阅读工作流 v4.6 · 一键安装脚本
#
# 把整个 dist/ 包安装到 ~/Desktop/快速阅读/
# 自动检测依赖、复制文件、建库目录、生成 config.json
#
# 用法:
#   bash install.sh                    # 安装到默认位置
#   bash install.sh /custom/path       # 安装到自定义路径
#   bash install.sh --dry-run          # 仅预览，不实际操作
# ============================================================

set -e

# ─── 参数解析 ───
INSTALL_DIR="$HOME/Desktop/快速阅读"
DRY_RUN="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN="true"; shift;;
    -h|--help)
      head -15 "$0" | tail -12
      exit 0;;
    *) INSTALL_DIR="$1"; shift;;
  esac
done

# 当前脚本所在目录（即 dist/）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_ROOT="$(dirname "$SCRIPT_DIR")"  # dist/ 的父目录 = 整个项目根

echo "════════════════════════════════════════════════════"
echo "📦 快速阅读工作流 v4.6 · 安装"
echo "════════════════════════════════════════════════════"
echo "  源:   $SRC_ROOT"
echo "  目标: $INSTALL_DIR"
echo "  模式: $([ "$DRY_RUN" = "true" ] && echo 'DRY-RUN（仅预览）' || echo '真安装')"
echo "════════════════════════════════════════════════════"
echo ""

run() {
  if [ "$DRY_RUN" = "true" ]; then
    echo "  [dry-run] $*"
  else
    eval "$*"
  fi
}

# ─── 1. 建目录 ───
echo "── ① 建目录结构 ──"
for d in 库/01-文献论文 库/02-书籍 库/03-小说散文 库/04-采访对谈 库/05-网文长文 \
         模板 脚本 收件箱 解读卡片 清理日志 dist; do
  if [ ! -d "$INSTALL_DIR/$d" ]; then
    run "mkdir -p \"$INSTALL_DIR/$d\""
    echo "  ✅ $d"
  else
    echo "  · $d (已存在)"
  fi
done
echo ""

# ─── 2. 复制脚本和模板 ───
echo "── ② 复制脚本 + 模板 ──"

# 脚本（如果用户是从 git 克隆，文件应该都在）
if [ -d "$SRC_ROOT/脚本" ]; then
  for f in "$SRC_ROOT/脚本"/*; do
    [ -e "$f" ] || continue
    name=$(basename "$f")
    if [ ! -f "$INSTALL_DIR/脚本/$name" ]; then
      run "cp \"$f\" \"$INSTALL_DIR/脚本/\""
      echo "  ✅ 脚本/$name"
    fi
  done
fi

# 模板
if [ -d "$SRC_ROOT/模板" ]; then
  for f in "$SRC_ROOT/模板"/*; do
    [ -e "$f" ] || continue
    name=$(basename "$f")
    if [ ! -e "$INSTALL_DIR/模板/$name" ]; then
      run "cp -r \"$f\" \"$INSTALL_DIR/模板/\""
      echo "  ✅ 模板/$name"
    fi
  done
fi

# README / Skills矩阵
for f in README.md Skills集成矩阵.md; do
  if [ -f "$SRC_ROOT/$f" ] && [ ! -f "$INSTALL_DIR/$f" ]; then
    run "cp \"$SRC_ROOT/$f\" \"$INSTALL_DIR/\""
    echo "  ✅ $f"
  fi
done

# dist 整个拷贝（含 SKILL.md / QUICKSTART / INSTALL / 平台适配）
if [ -d "$SCRIPT_DIR" ]; then
  for f in "$SCRIPT_DIR"/*; do
    [ -e "$f" ] || continue
    name=$(basename "$f")
    if [ ! -e "$INSTALL_DIR/dist/$name" ]; then
      run "cp -r \"$f\" \"$INSTALL_DIR/dist/\""
      echo "  ✅ dist/$name"
    fi
  done
fi
echo ""

# ─── 3. 生成 config.json（如不存在）───
echo "── ③ config.json ──"
if [ ! -f "$INSTALL_DIR/config.json" ]; then
  if [ -f "$SCRIPT_DIR/config.template.json" ]; then
    run "cp \"$SCRIPT_DIR/config.template.json\" \"$INSTALL_DIR/config.json\""
    echo "  ✅ config.json 已创建（基于 template）"
    echo "  ⚠️  请编辑填入你的个人信息: open \"$INSTALL_DIR/config.json\""
  else
    echo "  ⚠️  config.template.json 未找到，跳过"
  fi
else
  echo "  · config.json (已存在 · 未覆盖)"
fi
echo ""

# ─── 4. 给脚本加可执行权限 ───
echo "── ④ 加可执行权限 ──"
if [ "$DRY_RUN" = "false" ]; then
  chmod +x "$INSTALL_DIR/脚本"/*.sh 2>/dev/null
  echo "  ✅ 所有 .sh 已设为可执行"
else
  echo "  [dry-run] chmod +x \"$INSTALL_DIR/脚本/\"*.sh"
fi
echo ""

# ─── 5. 跑 init.sh ───
echo "── ⑤ 依赖检测 ──"
if [ "$DRY_RUN" = "false" ] && [ -f "$INSTALL_DIR/脚本/init.sh" ]; then
  echo ""
  bash "$INSTALL_DIR/脚本/init.sh" 2>&1 | tail -10
else
  echo "  [dry-run] bash \"$INSTALL_DIR/脚本/init.sh\""
fi
echo ""

# ─── 总结 ───
echo "════════════════════════════════════════════════════"
if [ "$DRY_RUN" = "true" ]; then
  echo "⚠️  这是 DRY-RUN，未实际安装。去掉 --dry-run 重跑即可真装。"
else
  echo "✅ 安装完成。下一步:"
  echo ""
  echo "  1. 编辑配置: open \"$INSTALL_DIR/config.json\""
  echo "  2. 装缺失依赖（看上面 init.sh 报告）"
  echo "  3. 开始第一次精读:"
  echo "     bash \"$INSTALL_DIR/脚本/通用提取.sh\" <你的 PDF>"
  echo "     # 然后跟 Claude/GPT/Gemini 说：'按 v4.6 流程精读'"
  echo ""
  echo "  📖 详细指南: \"$INSTALL_DIR/dist/QUICKSTART.md\""
fi
echo "════════════════════════════════════════════════════"
