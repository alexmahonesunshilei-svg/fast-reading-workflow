#!/bin/bash
# ============================================================
# 联系作者邮件草稿生成 · 三语模板
# 用 config.json 的个人信息填充，避免硬编码
#
# 用法:
#   ./生成请求邮件.sh "<论文标题>" "<作者邮箱>" "[研究方向]"
# ============================================================

TITLE="$1"
EMAIL="$2"

if [ -z "$TITLE" ] || [ -z "$EMAIL" ]; then
  echo "用法: $0 \"<论文标题>\" \"<作者邮箱>\" \"[研究方向]\""
  echo "例:  $0 \"Chinese Road Movies\" \"prof@example.ac.kr\" \"新主流电影\""
  exit 1
fi

# 读 config.json
CONFIG=~/Desktop/快速阅读/config.json
if [ ! -f "$CONFIG" ]; then
  echo "❌ 配置文件不存在: $CONFIG"
  echo "   请先复制 config.template.json 为 config.json 并填写"
  exit 1
fi

NAME_EN=$(python3 -c "import json;print(json.load(open('$CONFIG'))['user'].get('name_en','?'))" 2>/dev/null)
NAME_ZH=$(python3 -c "import json;print(json.load(open('$CONFIG'))['user'].get('name_zh','?'))" 2>/dev/null)
NAME_NATIVE=$(python3 -c "import json;print(json.load(open('$CONFIG'))['user'].get('name_native','?'))" 2>/dev/null)
USER_EMAIL=$(python3 -c "import json;print(json.load(open('$CONFIG'))['user'].get('email','?'))" 2>/dev/null)
UNIV_EN=$(python3 -c "import json;print(json.load(open('$CONFIG'))['university'].get('name_en','?'))" 2>/dev/null)
UNIV_ZH=$(python3 -c "import json;print(json.load(open('$CONFIG'))['university'].get('name_zh','?'))" 2>/dev/null)
UNIV_NATIVE=$(python3 -c "import json;print(json.load(open('$CONFIG'))['university'].get('name_native','?'))" 2>/dev/null)
TOPIC_ZH=$(python3 -c "import json;print(json.load(open('$CONFIG'))['dissertation'].get('topic_zh','?'))" 2>/dev/null)
TOPIC_EN=$(python3 -c "import json;print(json.load(open('$CONFIG'))['dissertation'].get('topic_en','?'))" 2>/dev/null)

TOPIC="${3:-$TOPIC_ZH}"

cat << EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📧 联系作者邮件草稿（中英韩三语，按需选择）
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

────────── 英文版（最稳妥）──────────
TO: $EMAIL
SUBJECT: Request for full-text of "$TITLE"

Dear Professor,

I am a PhD candidate at $UNIV_EN, working on research about $TOPIC_EN.

I read the abstract of your paper "$TITLE" and I am very interested in
your methodology and findings. Unfortunately, I cannot access the full
text through my institution.

Would you be kind enough to share a copy via email? I would be happy to
acknowledge your work in my dissertation.

Thank you very much for your time and consideration.

Best regards,
$NAME_EN
PhD Candidate
$UNIV_EN
$USER_EMAIL

────────── 韩文版（如果作者是韩国学者）──────────
TO: $EMAIL
제목: 「$TITLE」 원문 요청

존경하는 교수님께,

저는 $UNIV_NATIVE 에서 박사과정을 밟고 있는 $NAME_NATIVE 입니다.
현재 $TOPIC 에 관한 연구를 진행 중입니다.

교수님께서 발표하신 「$TITLE」의 초록을 읽고 그 방법론과 연구 결과에
큰 관심을 가지게 되었습니다. 다만, 저의 기관을 통해서는 원문에 접근할
수 없는 상황입니다.

가능하시다면 이메일로 한 부 공유해 주실 수 있을지 정중히 여쭙고
싶습니다. 박사논문에서 귀하의 연구를 충실히 인용하도록 하겠습니다.

귀하의 시간과 배려에 깊이 감사드립니다.

$NAME_NATIVE 드림
$UNIV_NATIVE 박사과정
$USER_EMAIL

────────── 中文版（如果作者是中国学者）──────────
TO: $EMAIL
主题：「$TITLE」全文索取

尊敬的老师，

我是 $UNIV_ZH 博士研究生 $NAME_ZH，目前正在从事 $TOPIC 方向的研究。

拜读了您的论文「$TITLE」的摘要后，对您所采用的方法论和研究成果产生了
浓厚兴趣。但通过我所在的机构无法获取该论文的全文。

不知能否冒昧请您通过电子邮件分享一份全文给我？我会在博士论文中充分
引用并致谢您的研究。

非常感谢您的时间和关照。

$NAME_ZH 敬上
$UNIV_ZH 博士研究生
$USER_EMAIL

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ 请选择对应语言版本，复制到邮件客户端发送。
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
