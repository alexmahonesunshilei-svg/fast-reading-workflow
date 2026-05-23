#!/bin/bash
# ============================================================
# 路径标准化工具（macOS bash 3.2 兼容版 · 用 Python 实现）
#
# 把中文/韩文/日文混合的目录名转为 ASCII 拼音目录，避免编码踩坑。
# 显示名（用户看到的）仍用原文，存在 元数据.md 里。
#
# 用法:
#   ./path_helper.sh normalize "<目录名>"
#   ./path_helper.sh display ~/path/to/paper_dir
#
# 自定义术语映射：
#   编辑下面的 KOREAN_MAP / CHINESE_MAP / JAPANESE_MAP
#   把你常遇到的人名/概念加进去
# ============================================================

CMD="${1:-help}"
INPUT="$2"

case "$CMD" in
  normalize)
    python3 << 'PYEOF'
import sys, re, unicodedata

# ─── 用户自定义术语映射（按需扩展）───
# 加进来的术语会被替换成 ASCII，避免目录名混编码
KOREAN_MAP = {
    # 概念示例
    "기호학": "semiotics",
    "서사구조": "narrative-structure",
    "성장통": "growing-pains",
    "로드무비": "road-movie",
    # 在这里加你常遇到的韩文术语 / 人名 → 拼音
    # "이름": "romanization",
}

CHINESE_MAP = {
    # 概念示例
    "符号学": "semiotics",
    "叙事": "narrative",
    "公路片": "road-movie",
    "新主流电影": "new-mainstream-film",
    # 在这里加你常遇到的中文术语 / 人名 → 拼音
    # "中文名": "pinyin",
}

JAPANESE_MAP = {
    # 在这里加你常遇到的日文术语
    # "用語": "term",
}

# 实际归一化逻辑
import os
raw = os.environ.get('INPUT_RAW', '')

# 应用映射
for d in (KOREAN_MAP, CHINESE_MAP, JAPANESE_MAP):
    for k, v in d.items():
        raw = raw.replace(k, v)

# 剩余非 ASCII 字符转 unicode normalize + ascii-fallback
def ascii_fold(s):
    # NFKD 分解，丢弃组合字符
    s = unicodedata.normalize('NFKD', s)
    s = ''.join(c for c in s if not unicodedata.combining(c))
    # 非 ASCII 转下划线
    s = re.sub(r'[^a-zA-Z0-9\-_.]', '_', s)
    # 合并多个下划线
    s = re.sub(r'_+', '_', s).strip('_').lower()
    return s

print(ascii_fold(raw))
PYEOF
    ;;

  display)
    if [ -d "$INPUT" ] && [ -f "$INPUT/元数据.md" ]; then
      head -1 "$INPUT/元数据.md" | sed 's/^#\s*//'
    else
      basename "$INPUT" 2>/dev/null || echo "?"
    fi
    ;;

  help|*)
    cat << EOF
用法:
  $0 normalize "<目录名>"   把中/韩/日混合目录名转为 ASCII
  $0 display <目录路径>     从元数据.md 读取显示名

自定义术语映射:
  编辑本脚本顶部的 KOREAN_MAP / CHINESE_MAP / JAPANESE_MAP
  加入你常遇到的术语 → 拼音/romanization 的对照
EOF
    ;;
esac

# 兼容 bash 调用方式: INPUT_RAW="$INPUT" 传给 python
export INPUT_RAW="$INPUT"
