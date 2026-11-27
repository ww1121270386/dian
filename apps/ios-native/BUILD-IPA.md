# 出 IPA（Windows 上只能走 CI）

本机是 Windows，没有 `xcodebuild`，**无法本地编译 IPA**。仓库里已有 macOS 工作流：
`.github/workflows/ios-native-unsigned.yml`（`runs-on: macos-14` + XcodeGen + xcodebuild，产物为 unsigned ipa）。

## 一、首次推送（你在本地执行，2 条命令）

1. GitHub 新建一个仓库（Private 也可以），拿到地址，例如 `https://github.com/<你>/fuelmate.git`
2. 在项目根目录执行：

```bash
git init
git add .
git commit -m "feat: FuelMate 三端（web / harmony-native / ios-native / android）"
git branch -M main
git remote add origin https://github.com/<你>/fuelmate.git
git push -u origin main
```

> 推送时会要求输入账号密码 —— GitHub 已不支持密码，需用 **Personal Access Token**（Settings → Developer settings → Tokens (classic) → 勾 `repo`）当密码。
> 仓库里已 `.gitignore` 掉 `signing/*.p12`、`*.jks` 等密钥，不会被推上去（**这是对的，密钥不要进仓库**）。

## 二、CI 自动出包

推送后 GitHub 会因 `apps/ios-native/**` 变更自动触发；也可手动：
**Actions → Build iOS native (unsigned ipa) → Run workflow**

约 3–6 分钟完成后：
**Actions → 该次运行 → Artifacts → `FuelMate-native-unsigned-ipa`** 下载，解压得 `FuelMate-native-unsigned.ipa`。

## 三、IPA 能做什么 / 不能做什么

| 场景 | 说明 |
|---|---|
| 直接装 iPhone | ❌ 未签名装不上 |
| Sideloadly / AltStore + 免费 Apple ID | ✅ 可装，**7 天到期需重签** |
| 付费开发者账号（$99/年） | ✅ 可做 TestFlight 内测（90 天）、Ad Hoc 分发、上架 App Store |
| 上架 App Store | 需要 Mac 归档 + 证书 + 隐私清单，Windows 无法完成 |

## 四、如果要做正式 iOS 包

在 macOS 上（或 CI 上加签名步骤）：

```bash
cd apps/ios-native
xcodegen generate
xcodebuild -project FuelMate.xcodeproj -scheme FuelMate \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/FuelMate.xcarchive archive
xcodebuild -exportArchive -archivePath build/FuelMate.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath build/ipa
```
`ExportOptions.plist` 里填你的 Team ID 与分发方式（`app-store` / `ad-hoc` / `development`）。
