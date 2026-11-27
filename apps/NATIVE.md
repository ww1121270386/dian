# 电耗管家 · 原生双端（鸿蒙 ArkTS / iOS SwiftUI）

完全重写的原生版本：**不依赖 NAS、不依赖 WebView**，数据存在手机本地，断网可用。
算法口径与 fpk 在线版一致（`apps/native-spec/calc.test.js` 已锁定基准，`CALC-SPEC-PASS`）。

```
apps/
├── harmony-native/       鸿蒙原生（ArkTS + ArkUI + preferences）
│   └── entry/src/main/ets/
│       ├── model/Calc.ets     数据模型 + 全部业务算法
│       ├── store/Repo.ets     本地存储（JSON 持久化）
│       └── pages/Index.ets    四个页签 + 四个录入弹层
├── ios-native/           iOS 原生（SwiftUI + Swift Charts）
│   ├── project.yml            XcodeGen 工程描述（无需手搓 pbxproj）
│   └── FuelMate/
│       ├── Models.swift / Calc.swift / Store.swift
│       └── Views/             Home / Charges / Expenses / Me / Forms
└── native-spec/          算法基准（JS 实现 + 单测，用于两端对齐）
```

## 功能对齐

| 功能 | fpk 在线版 | 鸿蒙原生 | iOS 原生 |
|---|---|---|---|
| 多车辆 / 切换 | ✅ | ✅ | ✅ |
| 充电记录（里程/kWh/单价/金额/SOC 前后） | ✅ | ✅ | ✅ |
| 电耗（相邻两次充电，kWh/km） | ✅ | ✅ | ✅ |
| 电费每公里 / 综合每公里 | ✅ | ✅ | ✅ |
| 保养提醒（里程/时间/两者先到 + 进度 + 下次到期） | ✅ | ✅ | ✅ |
| 年度里程倒计时（周期/剩余/日均） | ✅ | ✅ | ✅ |
| 持有成本（车价÷天数、÷里程） | ✅ | ✅ | ✅ |
| 估算续航（电池×SOC÷电耗） | ✅ | ✅ | ✅ |
| 电耗趋势图 / 费用构成图 | ✅ | ⬜ 未做 | ✅ 电耗柱状图 |
| CSV 导出 | ✅ | ⬜ 未做 | ⬜ 未做 |
| 多设备同步 | 同一 NAS | ❌ 本机 | ❌ 本机 |

> 原生版是**离线单机**：两台设备各自独立记账，不与 NAS 数据互通。要与 NAS 同步需另做云同步层。

## 一、鸿蒙构建（已验证可通过 CLI 编译）

本机已用 DevEco 自带 hvigor 完成编译，命令固化在 `apps/harmony-native/build-hap.sh`：

```bash
bash apps/harmony-native/build-hap.sh          # debug
bash apps/harmony-native/build-hap.sh release  # release
# 产物：entry/build/default/outputs/default/entry-default-unsigned.hap
```

**签名**：CLI 只能产出未签名包（真机/模拟器安装都要求签名）。在 DevEco 里点一次即可补上：
`打开 apps/harmony-native → 右上角登录华为账号 → Project Structure → Signing Configs → 勾选 Automatically generate signature → OK`，
之后 `bash build-hap.sh` 就会自动产出 `entry-default-signed.hap`（可直接 Run / 安装）。

### IDE 内构建

1. 安装 DevEco Studio 5.0+（Windows 可用），打开 `apps/harmony-native`
2. `Sync Now`（若提示 SDK 版本不符，把 `build-profile.json5` 的 `compatibleSdkVersion` 改成你本机 SDK，如 `5.0.0(12)`）
3. 登录华为账号 → `Project Structure → Signing Configs` 勾选自动签名
4. `Run` 真机调试，或 `Build → Build Hap(s)` 生成 `entry/build/default/outputs/default/entry-default-signed.hap`

权限说明：纯本地应用，`module.json5` **没有申请任何网络权限**。

## 二、iOS 构建

工程用 XcodeGen 描述（`project.yml`），因此不需要提交 `.xcodeproj`，也不用手工维护工程文件。

**云端出包（无需 Mac）**
1. 推仓库到 GitHub
2. `Actions → Build iOS native (unsigned ipa) → Run workflow`
3. 产物 `FuelMate-native-unsigned.ipa` → Windows 用 [Sideloadly](https://sideloadly.io/) + 免费 Apple ID 安装（7 天有效期，到期重签，数据在 App 内不受影响）

**本地（有 Mac 时）**
```bash
brew install xcodegen
cd apps/ios-native && xcodegen generate && open FuelMate.xcodeproj
```
Xcode 选团队后直接 Run。

## 三、数据与口径

- 存储：鸿蒙用 `preferences` 存 JSON；iOS 用 `Documents/fuelmate.json`。均无云、无账号、无埋点。
- 电耗：`本次充电量 ÷ 与上一条记录的里程差`（kWh/km，3 位小数），首条仅作起点
- 年度里程：自然年 `01-01~12-31`，年初基准取上一年最后一条记录里程，否则取当年首条
- 保养下次：`上次里程 + 间隔` / `上次日期 + 间隔天数`，取先到者，进度 ≥80% 标黄、到期标红
- 持有成本：`购车价 ÷ 已持有天数`（含首日）、`购车价 ÷ 总里程`

## 四、验证状态（务必知悉）

| 项 | 状态 |
|---|---|
| 业务算法（分段电耗/年度/保养/持有成本/续航） | ✅ JS 基准单测通过，两端按同一公式实现 |
| 鸿蒙工程配置（11 个 json5 + resources） | ✅ 全部 JSON 解析校验通过 |
| iOS 工程描述 project.yml / 两个 CI 工作流 | ✅ YAML 解析通过；Swift 源文件括号配平检查通过 |
| 鸿蒙编译（.hap） | ✅ **已用本机 DevEco 26 工具链编译通过**（`BUILD SUCCESSFUL`，产物 442KB，未签名） |
| iOS 编译（.ipa） | ⚠️ 本机无 macOS/Xcode，未实机编译 |

首次在你机器上编译时，若遇到 ArkTS 严格校验（如 `Array.filter` 回调类型、`common.UIAbilityContext` 导入路径）报错，把报错贴我，我按版本修。这是没在真 SDK 上跑过的必然代价，我不会假装已通过。
