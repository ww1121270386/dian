#!/usr/bin/env bash
# 校验新 hap 是否真的装进了模拟器/真机
# 用法:
#   bash verify-install.sh           # 只尝试覆盖安装并校验（保留数据）
#   bash verify-install.sh --wipe    # 签名冲突时：备份数据 → 卸载 → 安装 → 启动 → 截图
set -u

DEVECO="D:/Program Files/DevEco Studio"
HDC="$DEVECO/sdk/default/openharmony/toolchains/hdc.exe"
BUNDLE="com.fuelmate.native"
HAP="dist/entry-default-signed.hap"
MODE="${1:-}"

export MSYS_NO_PATHCONV=1
cd "$(dirname "$0")"

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }

if [ ! -f "$HAP" ]; then
  echo "❌ 找不到 $HAP，先执行 bash sign-and-build.sh"; exit 1
fi

LOCAL_SHA=$(sha256sum "$HAP" | cut -d' ' -f1)
LOCAL_VER=$(unzip -p "$HAP" module.json | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{const j=JSON.parse(s);console.log(j.app.versionName+' ('+j.app.versionCode+')')})")
LOCAL_CODE=$(unzip -p "$HAP" module.json | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{console.log(JSON.parse(s).app.versionCode)})")
say "本地包：$LOCAL_VER   SHA256=${LOCAL_SHA:0:16}…"

TARGETS=$("$HDC" list targets 2>/dev/null | tr -d '\r')
if [ -z "$TARGETS" ] || echo "$TARGETS" | grep -q "Empty"; then
  echo "❌ 没有在线设备。先在 DevEco 的 Device Manager 启动模拟器，再运行本脚本。"; exit 2
fi
say "在线设备：$TARGETS"

installed_ver() {
  "$HDC" shell "bm dump -n $BUNDLE" 2>/dev/null \
    | grep -oE '"(versionName|versionCode)": *"?[^",]*"?' \
    | tr -d ' "' | paste -sd' ' -
}

say "① 安装前设备上的版本"
BEFORE=$(installed_ver)
echo "   ${BEFORE:-（未安装）}"

say "② 覆盖安装"
INSTALL_OUT=$("$HDC" install -r "$HAP" 2>&1 | tr -d '\r')
echo "$INSTALL_OUT" | tail -2

if echo "$INSTALL_OUT" | grep -q "9568332"; then
  echo
  echo "⚠️  签名冲突：设备上旧包证书与当前不同，无法覆盖安装。"
  echo "   解决：卸载旧包（会清空 App 内数据）"
  if [ "$MODE" != "--wipe" ]; then
    echo "   确认数据可丢后执行： bash verify-install.sh --wipe"
    exit 3
  fi

  say "③ 备份数据"
  PREF="/data/app/el2/100/base/$BUNDLE/haps/entry/preferences/fuelmate_native"
  if "$HDC" shell "cat $PREF" > dist/backup/fuelmate_native.json 2>/dev/null && [ -s dist/backup/fuelmate_native.json ]; then
    echo "   已备份到 dist/backup/fuelmate_native.json ($(wc -c < dist/backup/fuelmate_native.json) 字节)"
  else
    echo "   ⚠️ 备份失败（可能设备未授权文件访问），继续会丢数据"
    read -r -p "   仍要继续？(y/N) " ans
    [ "$ans" = "y" ] || exit 4
  fi

  say "④ 卸载旧包"
  "$HDC" uninstall "$BUNDLE" 2>&1 | tail -1

  say "⑤ 安装新包"
  "$HDC" install "$HAP" 2>&1 | tail -2
fi

say "⑥ 安装后设备上的版本（应与本地一致：$LOCAL_VER）"
AFTER=$(installed_ver)
echo "   ${AFTER:-（读取失败）}"
if echo "$AFTER" | grep -q "$LOCAL_CODE"; then
  echo "   ✅ 版本号匹配，确认是新包"
else
  echo "   ⚠️ 版本号未变，可能仍是旧包"
fi

say "⑦ 设备上 hap 文件指纹比对（与本地一致即完全确定）"
for f in entry.hap base.hap; do
  DEV_SHA=$("$HDC" shell "sha256sum /data/app/el2/100/base/$BUNDLE/haps/entry/$f" 2>/dev/null | tr -d '\r' | cut -d' ' -f1)
  if [ -n "${DEV_SHA:-}" ] && [ "${#DEV_SHA}" -eq 64 ]; then
    echo "   $f 设备指纹: ${DEV_SHA:0:16}…"
    [ "$DEV_SHA" = "$LOCAL_SHA" ] && echo "   ✅ 与本地包完全一致" || echo "   ❌ 不一致"
    break
  fi
done

say "⑧ 启动并截图"
"$HDC" shell "aa start -a EntryAbility -b $BUNDLE" 2>&1 | tail -1
sleep 3
"$HDC" shell snapshot_display -f /data/local/tmp/fm_verify.jpeg 2>&1 | tail -1
"$HDC" file recv /data/local/tmp/fm_verify.jpeg dist/verify.jpeg 2>/dev/null | tail -1
[ -f dist/verify.jpeg ] && echo "   截图：dist/verify.jpeg"

say "界面自查两点"
echo "   1) 首页保养提醒里，除了绿色「里程」条，应有蓝色「时间 ▓▓░ 18%」条"
echo "   2) 费用页 → ＋记录 → 类型选「保养」，底部应出现「同步保养提醒」开关"
