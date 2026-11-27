#!/usr/bin/env bash
# 用 DevEco Studio 自带工具链编译 hap（无需打开 IDE）
# 用法: bash build-hap.sh [debug|release]
set -e

DEVECO="D:/Program Files/DevEco Studio"
MODE="${1:-debug}"

export DEVECO_SDK_HOME="$DEVECO/sdk"
export JAVA_HOME="$DEVECO/jbr"
export PATH="$DEVECO/jbr/bin:$DEVECO/tools/node:$PATH"

cd "$(dirname "$0")"
"$DEVECO/tools/hvigor/bin/hvigorw.bat" assembleHap \
  --mode module -p product=default -p buildMode="$MODE" --no-daemon

echo "产物: entry/build/default/outputs/default/"
ls -lh entry/build/default/outputs/default/*.hap
