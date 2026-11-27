# 电耗管家 · Android（WebView 壳）

## 产物
| 文件 | 用途 |
|---|---|
| `dist/android/FuelMate-1.6.5-release.apk` | 201 KB，已用 `apps/signing/android-fueltmate.jks` 签名，可安装/分发 |
| `dist/android/FuelMate-1.6.5-debug.apk` | 226 KB，调试用 |

- 包名：`com.fuelmate.app`
- 版本：1.6.5 (versionCode 28)
- minSdk 24 / targetSdk 34
- 签名证书 SHA-256：`b937da70e56972ee5612b253ff8fa86bbc13e709ea982d61e9598d1265e8471c`

## 实现方式
`MainActivity` 用系统 `WebView` 加载 `assets/index.html`（`apps/web` 的全部静态资源已内嵌，444 KB），
开启 JS / DOM Storage（H5 的 localStorage 数据可用），锁定竖屏，返回键优先回退网页历史。

## 构建
```bash
export JAVA_HOME=/c/dev/tools/jdk-17.0.21.1+2
export ANDROID_HOME=C:/dev/tools/android-sdk
export PATH="$JAVA_HOME/bin:/c/dev/tools/gradle-8.7/bin:$PATH"
cd apps/android
gradle :app:assembleRelease --no-daemon
```

## 密钥（务必备份）
`apps/signing/android-fueltmate.jks`，alias `fuelmate`，密码 `FuelMate@2026`，RSA 2048，有效期 10000 天。
**丢失将无法对已上架应用做升级更新。**

## 上架 Google Play / 国内商店
- Google Play 自 2021 起要求 **AAB**（`gradle :app:bundleRelease`），不是 APK
- 国内商店（华为/小米/OPPO/vivo/应用宝）收 APK，但多数要求**软件著作权 + 备案**（与鸿蒙侧同口径）
- 建议后续补：Privacy Policy URL、自适应图标（`mipmap-anydpi-v26/ic_launcher.xml`）、启动页
