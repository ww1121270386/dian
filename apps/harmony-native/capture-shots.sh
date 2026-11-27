#!/usr/bin/env bash
# 采集 AGC 上架截图：竖屏 3 张 → 输出 1080×2400 PNG
# 用法: bash capture-shots.sh
set -e
HDC="D:/Program Files/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe"
BUNDLE="com.fuelmate.native"
OUT="dist/screenshots"
export MSYS_NO_PATHCONV=1

cd "$(dirname "$0")"
mkdir -p "$OUT"

if "$HDC" list targets 2>/dev/null | grep -qE "^[0-9]"; then
  T=$("$HDC" list targets 2>/dev/null | head -1 | tr -d '\r')
else
  echo "❌ 没有在线设备，先在 DevEco 的 Device Manager 启动模拟器"; exit 1
fi
echo "▶ 设备: $T"

"$HDC" -t "$T" shell "aa force-stop $BUNDLE; aa start -a EntryAbility -b $BUNDLE" >/dev/null 2>&1
sleep 4

shot() { # $1=文件名 $2=点击x比例 $3=点击y比例（不传则不点）
  if [ -n "${2:-}" ]; then
    W=$("$HDC" -t "$T" shell "hidumper -s RenderService -a screen" 2>/dev/null | grep -oE "render resolution=[0-9]+x[0-9]+" | head -1 | grep -oE "[0-9]+x[0-9]+" | cut -dx -f1)
    H=$("$HDC" -t "$T" shell "hidumper -s RenderService -a screen" 2>/dev/null | grep -oE "render resolution=[0-9]+x[0-9]+" | head -1 | grep -oE "[0-9]+x[0-9]+" | cut -dx -f2)
    X=$(node -e "console.log(Math.round($W*$2))"); Y=$(node -e "console.log(Math.round($H*$3))")
    "$HDC" -t "$T" shell "uinput -T -c $X $Y" >/dev/null 2>&1; sleep 2
  fi
  "$HDC" -t "$T" shell snapshot_display -f /data/local/tmp/shot.jpeg >/dev/null 2>&1
  "$HDC" -t "$T" file recv /data/local/tmp/shot.jpeg "$OUT/raw-$1.jpeg" >/dev/null 2>&1
  echo "  抓取 $1"
}

shot home 0 0
shot charge 0.39 0.94
shot me 0.83 0.94

cd ../..
node -e "
const sharp=require('sharp');
const fs=require('fs');
(async()=>{
  const dir='apps/harmony-native/dist/screenshots';
  const map=[['raw-home.jpeg','01-首页'],['raw-charge.jpeg','02-充电'],['raw-me.jpeg','03-我的']];
  for (const [src,name] of map) {
    const p=dir+'/'+src; if(!fs.existsSync(p)) continue;
    await sharp(p).resize(1080,2400,{fit:'contain',background:'#F5F6F8'}).png()
      .toFile(dir+'/'+name+'.png');
    console.log('  '+name+'.png');
  }
  console.log('完成 → '+dir);
})();"