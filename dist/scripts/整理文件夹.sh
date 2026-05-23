#!/bin/bash
# ============================================================
# 整理文件夹 · 安全清理脚本
#
# 扫描 5 类可清理的文件：
#   1. /tmp 下本工作流生成的临时文件
#   2. 收件箱/ 里已入库的 PDF 副本
#   3. 库/*/cover/cover_full.jpg（保留 cover.png 即可）
#   4. 模板/ 下的旧版（v1/v2/二档简版）→ 移到 _legacy/
#   5. 解读卡片/ 下的旧版重复卡
#
# 安全特性：
#   ✓ 默认 dry-run（只报告，不删）
#   ✓ 加 --apply 才真删
#   ✓ 用 mv 移到 macOS 回收站（可恢复），不用 rm
#   ✓ 最近 5 分钟修改的文件不删（保护正在编辑的）
#   ✓ 操作日志保存到 ~/Desktop/快速阅读/清理日志/
#
# 用法:
#   ./整理文件夹.sh             # 仅预览
#   ./整理文件夹.sh --apply      # 真删（移到回收站）
#   ./整理文件夹.sh --aggressive # 包含更激进的清理（旧模板等）
# ============================================================

set -e

APPLY="false"
AGGRESSIVE="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY="true"; shift;;
    --aggressive) AGGRESSIVE="true"; shift;;
    -h|--help)
      head -28 "$0" | tail -25; exit 0;;
    *) echo "未知参数: $1"; exit 1;;
  esac
done

PROJECT=~/Desktop/快速阅读
KCI=~/Desktop/kci小论文
LOG_DIR="$PROJECT/清理日志"
mkdir -p "$LOG_DIR"
LOGFILE="$LOG_DIR/$(date +%Y-%m-%d_%H%M%S).md"
TRASH=~/.Trash

echo "════════════════════════════════════════════════════"
if [ "$APPLY" = "true" ]; then
  echo "🧹 整理文件夹 · 真清理模式（移到 ~/.Trash）"
else
  echo "🔍 整理文件夹 · DRY-RUN（仅预览，不删任何文件）"
fi
echo "📋 日志: $LOGFILE"
echo "════════════════════════════════════════════════════"
echo ""

# ─── 日志头 ───
{
  echo "# 整理文件夹日志"
  echo ""
  echo "- 时间: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "- 模式: $([ "$APPLY" = "true" ] && echo '真清理（移到 ~/.Trash）' || echo 'DRY-RUN（仅预览）')"
  echo "- 激进: $AGGRESSIVE"
  echo ""
} > "$LOGFILE"

TOTAL_FILES=0
TOTAL_SIZE=0

# ─── 工具函数 ───
# 安全删除：移到回收站
safe_remove() {
  local f="$1"
  if [ "$APPLY" = "true" ]; then
    # 用时间戳避免回收站重名冲突
    local base=$(basename "$f")
    local ts=$(date +%s)
    mv "$f" "$TRASH/${ts}_${base}" 2>/dev/null && return 0 || return 1
  fi
  return 0  # dry-run 总是返回成功
}

# 计算文件大小（KB）
file_size_kb() {
  local f="$1"
  if [ -f "$f" ]; then
    stat -f%z "$f" 2>/dev/null | awk '{print int($1/1024)}'
  else
    echo 0
  fi
}

# 报告一条候选清理
report() {
  local category="$1"
  local f="$2"
  local size_kb=$(file_size_kb "$f")

  # 检查 mtime（最近 5 分钟编辑的不删）
  local now=$(date +%s)
  local mt=$(stat -f%m "$f" 2>/dev/null || echo $now)
  local age=$((now - mt))

  if [ "$age" -lt 300 ]; then
    echo "  ⏸  跳过（最近 5 分钟修改）: $f"
    echo "  - ⏸ 跳过（保护正在编辑）: \`$f\`" >> "$LOGFILE"
    return
  fi

  TOTAL_FILES=$((TOTAL_FILES + 1))
  TOTAL_SIZE=$((TOTAL_SIZE + size_kb))

  if [ "$APPLY" = "true" ]; then
    if safe_remove "$f"; then
      echo "  🗑  ${size_kb} KB → ~/.Trash: $f"
      echo "  - 🗑 ${size_kb} KB → Trash: \`$f\`" >> "$LOGFILE"
    else
      echo "  ⚠️  删除失败: $f"
    fi
  else
    echo "  → ${size_kb} KB | $f"
    echo "  - 候选 ${size_kb} KB: \`$f\`" >> "$LOGFILE"
  fi
}

# ============ 类别 1: /tmp 临时文件 ============
echo "── 类别 1: /tmp 下本工作流的临时残留 ──"
echo "" >> "$LOGFILE"
echo "## 类别 1: /tmp 临时残留" >> "$LOGFILE"
echo "" >> "$LOGFILE"

for pattern in "sonserae*" "kci_*" "material_*" "new_paper_*" "extract_*" "audit_*" "check_*" "审查报告_*" "douban_page*" "test_image*" "test_imgs*" "test_pdf*" "test_url*" "test_docx*"; do
  for f in /tmp/$pattern; do
    if [ -e "$f" ]; then
      report "tmp" "$f"
    fi
  done
done

echo ""

# ============ 类别 2: 收件箱里已入库的副本 ============
echo "── 类别 2: 收件箱/ 里已入库到 库/*/ 的副本 ──"
echo "" >> "$LOGFILE"
echo "## 类别 2: 收件箱里已入库的副本" >> "$LOGFILE"
echo "" >> "$LOGFILE"

if [ -d "$PROJECT/收件箱" ]; then
  for f in "$PROJECT/收件箱"/*; do
    if [ -f "$f" ]; then
      base=$(basename "$f")
      # 检查库 内是否已有同名 PDF
      if find "$PROJECT/库/" -name "원문.pdf" -o -name "$base" 2>/dev/null | head -1 | grep -q .; then
        report "inbox" "$f"
      fi
    fi
  done
fi

echo ""

# ============ 类别 3: 库 里的重复封面原图 ============
echo "── 类别 3: 库/*/cover/cover_full.jpg（已有美化版 cover.png）──"
echo "" >> "$LOGFILE"
echo "## 类别 3: 库重复封面原图" >> "$LOGFILE"
echo "" >> "$LOGFILE"

find "$PROJECT/库" -name "cover_full.jpg" 2>/dev/null | while read f; do
  dir=$(dirname "$f")
  if [ -f "$dir/cover.png" ]; then
    report "cover" "$f"
  fi
done

echo ""

# ============ 类别 4 (激进): 旧版模板 ============
if [ "$AGGRESSIVE" = "true" ]; then
  echo "── 类别 4: 旧版模板（v1/v2/二档简版 → 移到 _legacy/）──"
  echo "" >> "$LOGFILE"
  echo "## 类别 4: 旧版模板（aggressive）" >> "$LOGFILE"
  echo "" >> "$LOGFILE"

  LEGACY="$PROJECT/模板/_legacy"
  if [ "$APPLY" = "true" ]; then
    mkdir -p "$LEGACY"
  fi

  for old in "$PROJECT/模板/解读卡模板.md" "$PROJECT/模板/解读卡模板_v2.md" "$PROJECT/模板/解读卡模板_v3_二档简版.md"; do
    if [ -f "$old" ]; then
      size_kb=$(file_size_kb "$old")
      TOTAL_FILES=$((TOTAL_FILES + 1))
      TOTAL_SIZE=$((TOTAL_SIZE + size_kb))
      if [ "$APPLY" = "true" ]; then
        mv "$old" "$LEGACY/" && echo "  📦 ${size_kb} KB → _legacy/: $(basename $old)"
        echo "  - 📦 ${size_kb} KB → _legacy/: $(basename $old)" >> "$LOGFILE"
      else
        echo "  → ${size_kb} KB | $old"
        echo "  - 候选移到 _legacy/: \`$old\`" >> "$LOGFILE"
      fi
    fi
  done

  echo ""
fi

# ============ 类别 5: 解读卡片/ 里的旧重复卡 ============
echo "── 类别 5: 解读卡片/ 里没有对应库条目的孤立卡 ──"
echo "" >> "$LOGFILE"
echo "## 类别 5: 解读卡片/ 孤立卡" >> "$LOGFILE"
echo "" >> "$LOGFILE"

if [ -d "$PROJECT/解读卡片" ]; then
  for f in "$PROJECT/解读卡片"/*.md; do
    if [ -f "$f" ]; then
      base=$(basename "$f" .md)
      # 已入库的作者名清单（环境变量 KNOWN_AUTHORS 可覆盖，正则 OR 分隔）
      # 默认空 = 跳过这层启发式（避免误删）
      KNOWN_AUTHORS="${KNOWN_AUTHORS:-NEVER_MATCH_THIS_PLACEHOLDER}"
      if echo "$base" | grep -qE "$KNOWN_AUTHORS"; then
        # 已在 库/ 里有正版，删除这里的
        if find "$PROJECT/库" -name "解读卡_三档.md" 2>/dev/null | xargs grep -l "$(head -1 "$f" 2>/dev/null | head -c 30)" 2>/dev/null | head -1 | grep -q .; then
          report "orphan_card" "$f"
        fi
      fi
    fi
  done
fi

echo ""

# ============ 总结 ============
echo "════════════════════════════════════════════════════"
TOTAL_MB=$(awk "BEGIN {printf \"%.1f\", $TOTAL_SIZE / 1024}")
echo "📊 共发现 $TOTAL_FILES 个候选文件 · 总计 ${TOTAL_SIZE} KB (${TOTAL_MB} MB)"

{
  echo ""
  echo "---"
  echo ""
  echo "## 总结"
  echo ""
  echo "- 候选文件数: $TOTAL_FILES"
  echo "- 候选总大小: ${TOTAL_SIZE} KB (${TOTAL_MB} MB)"
} >> "$LOGFILE"

if [ "$APPLY" = "true" ]; then
  echo "✅ 已移动到 ~/.Trash（可在 Finder 清空回收站永久删除，或拖回还原）"
  echo "" >> "$LOGFILE"
  echo "**结果**: 已移动到 \`~/.Trash\`" >> "$LOGFILE"
else
  echo ""
  echo "⚠️  这是 DRY-RUN 预览。要真的清理，加 --apply 重跑："
  echo "    $0 --apply"
  if [ "$AGGRESSIVE" = "false" ]; then
    echo "    （加 --aggressive 还会归档旧版模板）"
  fi
  echo "" >> "$LOGFILE"
  echo "**结果**: 仅预览，未执行删除" >> "$LOGFILE"
fi
echo "════════════════════════════════════════════════════"
echo "📋 详细日志: $LOGFILE"
