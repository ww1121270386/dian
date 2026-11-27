#!/usr/bin/env bash
# 一键构建并签名 release hap
#   - signing/release/ 下有 *.p7b + release-chain.pem → 用发布证书正式签名（可上架）
#   - 否则退回 DevEco 调试签名（仅可侧载测试）
set -e

DEVECO_POSIX="/d/Program Files/DevEco Studio"
DEVECO_WIN="D:\\\\Program Files\\\\DevEco Studio"
export DEVECO_SDK_HOME="$DEVECO_WIN\\\\sdk"
export JAVA_HOME="$DEVECO_WIN\\\\jbr"
export PATH="$DEVECO_POSIX/jbr/bin:$DEVECO_POSIX/tools/node:$PATH"

cd "$(dirname "$0")"
JAVA="$DEVECO_POSIX/jbr/bin/java.exe"
TOOL="$DEVECO_POSIX/sdk/default/openharmony/toolchains/lib/hap-sign-tool.jar"
OUT="entry/build/default/outputs/default"
UNSIGNED="$OUT/entry-default-unsigned.hap"
P12="signing/fuelmate.p12"
PASS="FuelMate@2026"
ALIAS="fuelmate"

echo "▶ 1/4 编译 release"
"$DEVECO_POSIX/tools/hvigor/bin/hvigorw.bat" assembleHap \
  --mode module -p product=default -p buildMode=release --no-daemon | tail -5

VER=$(unzip -p "$OUT/entry-default-signed.hap" module.json \
  | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{const a=JSON.parse(s).app;console.log(a.versionName+'-'+a.versionCode)})")
mkdir -p dist/release
TARGET="dist/release/FuelMate-${VER}-release-signed.hap"
P7B=$(ls signing/release/*.p7b 2>/dev/null | head -1 || true)
CHAIN="signing/release/release-chain.pem"

if [ -n "$P7B" ] && [ -f "$CHAIN" ] && [ -f "$P12" ]; then
  echo "▶ 2/4 用发布证书签名"
  "$JAVA" -jar "$TOOL" sign-app -keyAlias "$ALIAS" -signAlg "SHA256withECDSA" -mode "localSign" \
    -appCertFile "$CHAIN" -profileFile "$P7B" -inFile "$UNSIGNED" \
    -keystoreFile "$P12" -outFile "$TARGET" \
    -keyPwd "$PASS" -keystorePwd "$PASS" | tail -2
else
  echo "⚠️  2/4 缺少发布证书/Profile，退回调试签名（不可上架）"
  TARGET="dist/release/FuelMate-${VER}-release-debugsigned.hap"
  cp "$OUT/entry-default-signed.hap" "$TARGET"
fi

echo "▶ 3/4 校验"
"$JAVA" -jar "$TOOL" verify-app -inFile "$TARGET" \
  -outCertChain dist/release/verify-chain.cer -outProfile dist/release/verify-profile.p7b 2>&1 \
  | grep -E "profile type|Verify success|ERROR" || true

echo "▶ 4/4 产物"
ls -lh "$TARGET"
sha256sum "$TARGET"
