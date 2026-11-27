# 电耗管家 · iOS / HarmonyOS 双端壳工程

把一个已经在 NAS 上跑起来的电耗管家 H5（`http://<NAS-IP>:3280`），包成两个原生 App 入口。
**不重写业务代码**，App 只做一件事：用系统 WebView 打开你的服务，数据仍在你自己 NAS 上。

```
apps/
├── harmony/                 # 鸿蒙（ArkTS + ArkWeb）工程，DevEco Studio 直接打开
│   ├── AppScope/            # 应用级配置（包名 com.fuelmate.app、图标）
│   └── entry/               # 入口模块：Web 容器 + 服务器地址设置页（本地持久化）
├── ios/                     # iOS（Capacitor 6）工程
│   ├── capacitor.config.json
│   ├── www/index.html       # 启动页：填写/记住服务器地址后跳转
│   └── ios/App/App.xcodeproj# 已生成，含 ATS 例外与局域网权限、1024 图标
└── ../.github/workflows/ios-unsigned.yml   # 云端 mac 构建「未签名 ipa」
```

---

## 一、鸿蒙（Windows 可编译）

**前置**：安装 [DevEco Studio 5.0+](https://developer.huawei.com/consumer/cn/download/)（约 4GB）、注册华为开发者账号（免费，实名即可）。

1. DevEco Studio → `Open` → 选择 `apps/harmony` 目录
2. 首次打开会提示同步 hvigor 依赖，点 **Sync Now**
   - 若提示 SDK 版本不匹配：`File → Project Structure → SDK` 选本机已装版本，并把 `build-profile.json5` 里 `compatibleSdkVersion` 改成同版本（当前写的是 `5.0.0(12)`）
3. 登录华为账号：右上角头像 → `Sign In`，然后在 `Project Structure → Signing Configs` 勾选 **Automatically generate signature**
4. 真机/模拟器运行，或 `Build → Build Hap(s)` 产出 `entry/build/default/outputs/default/entry-default-signed.hap`

**App 行为**：首次启动弹出「服务器地址」，填 `http://192.168.1.x:3280` → 保存后直接进入；右下角 ⚙ 可随时改地址；连不上时显示「无法连接服务器 + 修改地址/重试」。

---

## 二、iOS（本机 Windows 出不了 ipa，走云构建）

`.ipa` 必须在 macOS 上编译并签名。你本机没有 Mac，所以用 GitHub Actions 的 macOS 跑一个**未签名 ipa**，再在 Windows 上用免费工具用自己的 Apple ID 签名安装。

### 1. 云端构建
1. 把本仓库推到 GitHub（私有库也行）
2. `Actions` → `Build unsigned iOS ipa` → `Run workflow`
3. 跑完在 Artifacts 下载 `FuelMate-unsigned-ipa`（内含 `FuelMate-unsigned.ipa`）

### 2. Windows 侧安装（免费 Apple ID 即可）
1. 下载 [Sideloadly](https://sideloadly.io/)（Windows 版）
2. iPhone 用数据线连电脑，Sideloadly 里选择设备 → 拖入 ipa → 填你的 Apple ID → `Start`
3. iPhone：`设置 → 通用 → VPN与设备管理` 里信任该开发者证书
4. 首次打开 App 输入 NAS 地址

> 免费签名有效期 **7 天**，到期重签一次即可（数据不丢，存在 NAS 上）。
> 有 Apple 开发者账号（$99/年）时可改为 Ad Hoc / TestFlight 分发，签名 1 年有效。

### 3. 有 Mac 的话更简单
```bash
cd apps/ios && npm install && npx cap sync ios && npx cap open ios
```
Xcode 里选自己的 Team，`Run` 即可。

---

## 三、可选：把 H5 打进 App（离线可用）

当前两端都是「加载 NAS 地址」，优点是零改造、换 IP 只改一个输入框。
若想 App 自身带 UI（只把数据请求打到 NAS），需要：

1. 把 `server/public` 拷进 `apps/ios/www/`（或鸿蒙 `entry/src/main/resources/rawfile/`）
2. 前端所有接口改为绝对地址：在 `app.js` 的 `api()` 里给 path 前拼 `window.FM_API_BASE`
3. 后端加 CORS（`Access-Control-Allow-Origin: *`），否则 WebView 跨域会被拦
4. 重新打包 fpk 升级 NAS 上的后端

需要的话我可以直接做这一版（改动量：前端 1 个函数 + 后端 1 行中间件）。

---

## 四、限制与注意

- **App Store 上架会被拒**：纯 WebView 壳触发审核条款 4.2（最低功能要求）。个人自用/内测分发没问题。
- **网络可达性**：App 只能访问能连到的地址。在家用局域网 IP；在外网需要 DDNS + 端口映射，或装 Tailscale 组网（iOS/鸿蒙都有客户端）。
- **HTTP 明文**：iOS 已在 `Info.plist` 开了 ATS 例外（`NSAllowsArbitraryLoads`）并声明局域网用途；鸿蒙 Web 组件已开 `mixedMode(All)`。正式上架建议换 HTTPS。
- **图标**：`assets/icon-1024.png` 生成的，换图标改 `assets/icon.svg` 后重新导出并替换两端资源。
