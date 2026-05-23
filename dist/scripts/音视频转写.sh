#!/bin/bash
# ============================================================
# 音视频转写 · 用 whisper.cpp 转写本地音视频 → 文本
#
# 输入: .mp3 / .mp4 / .m4a / .wav / .mov / YouTube URL
# 输出: 带时间码的 .txt（可直接走 通用提取.sh 后续）
#
# 用法:
#   ./音视频转写.sh <文件路径或 YouTube URL>
#   ./音视频转写.sh --install    # 自动装 whisper.cpp + 模型
# ============================================================

set -e

INPUT="$1"

WHISPER_DIR="$HOME/.whisper.cpp"
WHISPER_BIN="$WHISPER_DIR/build/bin/whisper-cli"
MODEL_PATH="$WHISPER_DIR/models/ggml-base.bin"  # 中等模型 142MB，速度/精度平衡

# ─── --install 模式 ───
if [ "$INPUT" = "--install" ]; then
  echo "════════════════════════════════════════════════════"
  echo "📦 安装 whisper.cpp（本地音视频转写）"
  echo "════════════════════════════════════════════════════"
  echo ""
  echo "依赖检查..."
  if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "  需要 ffmpeg（音频解码）→ brew install ffmpeg"
    echo ""
    read -p "  自动 brew install ffmpeg? [y/N] " yn
    if [ "$yn" = "y" ]; then brew install ffmpeg; else exit 1; fi
  else
    echo "  ✅ ffmpeg 已装"
  fi

  if [ ! -d "$WHISPER_DIR" ]; then
    echo "  克隆 whisper.cpp..."
    git clone https://github.com/ggerganov/whisper.cpp.git "$WHISPER_DIR"
  fi

  cd "$WHISPER_DIR"
  if [ ! -f "$WHISPER_BIN" ]; then
    echo "  编译 whisper.cpp（约 2 分钟）..."
    cmake -B build && cmake --build build --config Release -j
  fi

  if [ ! -f "$MODEL_PATH" ]; then
    echo "  下载模型 ggml-base.bin（142 MB）..."
    bash ./models/download-ggml-model.sh base
  fi

  echo ""
  echo "✅ whisper.cpp 安装完成"
  echo "   二进制: $WHISPER_BIN"
  echo "   模型:   $MODEL_PATH"
  echo ""
  echo "可选：装更强的模型 → bash $WHISPER_DIR/models/download-ggml-model.sh medium  # 1.5 GB，精度更高"
  exit 0
fi

if [ -z "$INPUT" ]; then
  cat << EOF
用法: $0 <音视频文件路径或 YouTube URL>

例:
  $0 ~/Desktop/导演访谈.mp4
  $0 ~/Desktop/podcast.mp3
  $0 "https://www.youtube.com/watch?v=xxx"

首次使用前先装:
  $0 --install

支持格式: mp3 / mp4 / m4a / wav / mov / aac / flac / YouTube URL
EOF
  exit 1
fi

# 检查 whisper 是否已装
if [ ! -f "$WHISPER_BIN" ]; then
  echo "❌ whisper.cpp 未安装。先跑: $0 --install"
  exit 1
fi

TIMESTAMP=$(date +%s)
WORKDIR="/tmp/audio_${TIMESTAMP}"
mkdir -p "$WORKDIR"

# ─── 判断输入类型 ───
AUDIO_FILE=""
if [[ "$INPUT" =~ ^https?:// ]]; then
  echo "── 下载 YouTube/在线音频 ──"
  if ! command -v yt-dlp >/dev/null 2>&1; then
    echo "❌ 需要 yt-dlp → brew install yt-dlp"
    exit 1
  fi
  cd "$WORKDIR"
  yt-dlp -x --audio-format mp3 -o "audio.%(ext)s" "$INPUT"
  AUDIO_FILE="$WORKDIR/audio.mp3"
else
  if [ ! -f "$INPUT" ]; then
    echo "❌ 文件不存在: $INPUT"
    exit 1
  fi
  AUDIO_FILE="$INPUT"
fi

# ─── ffmpeg 转 16kHz WAV（whisper 要求）───
echo "── ffmpeg 转码 16 kHz WAV ──"
WAV="$WORKDIR/input.wav"
ffmpeg -y -i "$AUDIO_FILE" -ar 16000 -ac 1 -c:a pcm_s16le "$WAV" 2>&1 | tail -5

# ─── 时长 ───
DUR=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$WAV" 2>/dev/null | awk '{printf "%d:%02d", int($1/60), int($1)%60}')
echo "  音频时长: $DUR"
echo ""

# ─── 跑 whisper ───
OUT_TXT="$WORKDIR/transcript.txt"
OUT_SRT="$WORKDIR/transcript.srt"

echo "── whisper.cpp 转写（语言自动检测）──"
echo "  这可能要 ${DUR%%:*} 分钟左右..."
echo ""

"$WHISPER_BIN" \
  -m "$MODEL_PATH" \
  -f "$WAV" \
  -l auto \
  -otxt \
  -osrt \
  -of "$WORKDIR/transcript" \
  --print-progress 2>&1 | tail -20

echo ""
CHARS=$(wc -m < "$OUT_TXT" 2>/dev/null || echo 0)

# ─── 整理产出（适配 通用提取.sh 的格式）───
FINAL="$WORKDIR/extracted.txt"
{
  echo "=== 类型: 音视频转写 ==="
  echo "=== 来源: $INPUT ==="
  echo "=== 音频时长: $DUR ==="
  echo "=== 转写字符数: $CHARS ==="
  echo "=== 模型: ggml-base ==="
  echo ""
  cat "$OUT_TXT"
} > "$FINAL"

echo "════════════════════════════════════════════════════"
echo "✅ 转写完成"
echo "════════════════════════════════════════════════════"
echo "  纯文本: $OUT_TXT"
echo "  字幕(带时间码): $OUT_SRT"
echo "  统一格式(给后续用): $FINAL"
echo ""
echo "下一步建议:"
echo "  → 这是采访/对谈 → 解读卡模板套件_v4.md 用变体 F"
echo "  → 这是讲座/课程 → 用变体 D（散文/随笔变体）"
echo "  → 这是纪录片 → 用变体 E（报刊/新闻变体）"
echo ""
echo "  跑解读:"
echo "    把 $FINAL 当作 通用提取.sh 的产物，进入 Step 3"
