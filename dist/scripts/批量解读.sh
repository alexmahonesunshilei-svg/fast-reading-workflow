#!/bin/bash
# ============================================================
# 批量解读 · 扫一个目录的所有 PDF/EPUB/DOCX，列清单 + 估算 token
#
# 默认 dry-run（只列清单和估算），加 --apply 才真跑。
# 真跑时输出一个 Agent prompt 文件，由用户在 Claude Code 里发给主对话
# （bash 不能直接调起并行 Agent，需要 Claude Code 主对话发起）
#
# 用法:
#   ./批量解读.sh <目录>                  # dry-run · 列清单
#   ./批量解读.sh <目录> --apply          # 生成 Agent prompt
#   ./批量解读.sh <目录> --apply -n 3     # 限并行数
# ============================================================

set -e

DIR="$1"
APPLY="false"
PARALLEL=5

shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY="true"; shift;;
    -n|--parallel) PARALLEL="$2"; shift 2;;
    *) shift;;
  esac
done

if [ -z "$DIR" ] || [ ! -d "$DIR" ]; then
  cat << EOF
用法: $0 <目录> [--apply] [-n 并行数]

例:
  $0 ~/Desktop/待读/         # 仅列清单（dry-run）
  $0 ~/Desktop/待读/ --apply # 生成 prompt 让 Claude Code 主对话并行跑

支持文件: .pdf / .epub / .docx / .hwp

输出（dry-run）:
  - 清单（标题 / 大小 / 估算字符数 / 预测 token）
  - 估算总 token 消耗
  - 估算总耗时

输出（--apply）:
  - 一个 Agent prompt 文件，复制粘贴到 Claude Code 主对话即可并行启动 N 个 Agent
EOF
  exit 1
fi

PROJECT=~/Desktop/快速阅读
TMP_PY="/tmp/batch_$(date +%s).py"

cat > "$TMP_PY" << 'PYEOF'
import os, sys, glob, json

dir_path = sys.argv[1]
apply_mode = sys.argv[2] == 'true'
parallel = int(sys.argv[3])

# 找所有支持的文件
patterns = ['*.pdf', '*.epub', '*.docx', '*.hwp']
files = []
for p in patterns:
    files.extend(glob.glob(os.path.join(dir_path, p)))
    files.extend(glob.glob(os.path.join(dir_path, '**', p), recursive=True))
files = sorted(set(files))

if not files:
    print("❌ 目录里没找到 PDF/EPUB/DOCX/HWP")
    sys.exit(1)

print("════════════════════════════════════════════════════")
print("📚 批量解读 · 扫描结果")
print("════════════════════════════════════════════════════")
print("  目录: " + dir_path)
print("  发现: " + str(len(files)) + " 个文件")
print("  模式: " + ("真跑（生成 Agent prompt）" if apply_mode else "DRY-RUN（仅清单）"))
print("")

total_size = 0
total_chars_est = 0
items = []

print("── 文件清单 ──")
for f in files:
    size = os.path.getsize(f)
    # 字符数估算: PDF ~1 字符/字节 * 0.3 系数 / DOCX ~0.4 / EPUB ~0.5
    ext = os.path.splitext(f)[1].lower()
    if ext == '.pdf': chars_est = int(size * 0.3)
    elif ext == '.docx': chars_est = int(size * 0.4)
    elif ext == '.epub': chars_est = int(size * 0.5)
    else: chars_est = int(size * 0.3)

    total_size += size
    total_chars_est += chars_est

    name = os.path.basename(f)
    if len(name) > 60: name = name[:57] + '...'
    print(f"  · {name}")
    print(f"    {size//1024} KB · 估 {chars_est} 字符")
    items.append({'path': f, 'name': name, 'chars_est': chars_est})

# 估算 token（中文 1 字符 ≈ 1.5 token）
total_tokens_input = int(total_chars_est * 1.5)
# 输出: 三档卡约 12000 字符 * 1.5 token = 18000 / 篇
total_tokens_output = len(files) * 18000
total_tokens = total_tokens_input + total_tokens_output

# Claude Sonnet 价格: input $3/MTok, output $15/MTok
cost_usd = (total_tokens_input / 1_000_000) * 3 + (total_tokens_output / 1_000_000) * 15

print("")
print("── 估算 ──")
print(f"  总大小:       {total_size//1024} KB ({total_size/1024/1024:.1f} MB)")
print(f"  总字符数:     {total_chars_est:,}")
print(f"  输入 token:   {total_tokens_input:,}")
print(f"  输出 token:   {total_tokens_output:,}")
print(f"  总 token:     {total_tokens:,}")
print(f"  Sonnet 费用:  ~${cost_usd:.2f}")
print(f"  预计耗时:     {len(files)*5//parallel}-{len(files)*8//parallel} 分钟（{parallel} 并行）")
print("")

if not apply_mode:
    print("⚠️  这是 DRY-RUN。要真跑，加 --apply 重跑:")
    print(f"    $0 {dir_path} --apply -n {parallel}")
    sys.exit(0)

# 真跑模式：生成 Agent prompt 文件
import datetime
prompt_path = f"/tmp/batch_prompt_{int(__import__('time').time())}.md"

# 拆分为 parallel 组
groups = [[] for _ in range(parallel)]
for i, it in enumerate(items):
    groups[i % parallel].append(it)

with open(prompt_path, 'w') as f:
    f.write("# 批量解读 · Agent 并行 prompt\n\n")
    f.write(f"生成时间: {datetime.datetime.now()}\n\n")
    f.write(f"共 {len(items)} 个文件，分 {parallel} 组并行处理。\n\n")
    f.write("---\n\n")
    f.write("## 操作步骤（在 Claude Code 主对话里跑）\n\n")
    f.write("把下面这段话直接粘贴给 Claude Code:\n\n")
    f.write("```\n")
    f.write(f"请并行起 {parallel} 个 general-purpose Agent，每个 Agent 处理下面一组文件，\n")
    f.write("完整跑 v4.5 三档精读流程（通用提取 → 解读卡 → 截图 → docx → 审查）：\n\n")
    for i, group in enumerate(groups, 1):
        if not group: continue
        f.write(f"Agent {i}:\n")
        for it in group:
            f.write(f"  - {it['path']}\n")
        f.write("\n")
    f.write("每个 Agent 在 ~/Desktop/快速阅读/库/ 下建拼音化目录，并在元数据 + 解读卡 + docx 都完成后跑审查脚本。\n")
    f.write("全部完成后，跑 章节索引.sh 更新章节素材索引。\n")
    f.write("```\n")

print(f"✅ Agent prompt 已生成: {prompt_path}")
print("")
print("下一步:")
print(f"  cat {prompt_path}")
print(f"  # 然后复制粘贴里面的代码块到 Claude Code 主对话")
PYEOF

python3 "$TMP_PY" "$DIR" "$APPLY" "$PARALLEL"
rm -f "$TMP_PY"
