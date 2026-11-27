#!/usr/bin/env bash
# 构建 hap 并校验签名状态（配合 DevEco 自动签名使用）
# 用法: bash sign-and-build.sh [debug|release]
set -e

DEVECO_POSIX="/d/Program Files/DevEco Studio"
DEVECO_WIN="D:////Program Files////DevEco Studio"
MODE="${1:-debug}"

export DEVECO_SDK_HOME="$DEVECO_WIN\\sdk"
export JAVA_HOME="$DEVECO_WIN\\jbr"
export PATH="$DEVECO_POSIX/jbr/bin:$DEVECO_POSIX/tools/node:$PATH"

cd "$(dirname "$0")"

echo "▶ 开始构建（$MODE）..."
"$DEVECO_POSIX/tools/hvigor/bin/hvigorw.bat" assembleHap \
  --mode module -p product=default -p buildMode="$MODE" --no-daemon | tail -6

OUT="entry/build/default/outputs/default"
SIGNED="$OUT/entry-default-signed.hap"
UNSIGNED="$OUT/entry-default-unsigned.hap"

echo "▶ 产物列表："
ls -lh "$OUT"/*.hap 2>/dev/null || true

if [ -f "$SIGNED" ]; then
  echo "▶ 校验签名..."
  "$DEVECO_POSIX/jbr/bin/java.exe" -jar \
    "$DEVECO_POSIX/sdk/default/openharmony/toolchains/lib/hap-sign-tool.jar" \
    verify-app -inFile "$SIGNED" -outCertChain "$OUT/verify-chain.cer" -outProfile "$OUT/verify-profile.p7b" || {
      echo "❌ 签名校验失败"; exit 1; }
  echo "✅ 已签名且校验通过：$SIGNED"
  echo "   安装: hdc install -r \"$(pwd)/$SIGNED\""
else
  echo "⚠️ 仍是未签名包（$UNSIGNED）"
  echo "   请先在 DevEco 完成：登录华为账号 → Project Structure → Signing Configs → ☑ Automatically generate signature"
  exit 2
fi
