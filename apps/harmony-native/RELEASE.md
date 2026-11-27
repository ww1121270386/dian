# 电耗管家 · 发布说明（HarmonyOS 1.6.5）

## 一、当前产物

| 项 | 值 |
|---|---|
| 包名 | `com.fuelmate.native` |
| 版本 | **1.6.5 (1000027)** |
| 构建模式 | `release`（`debug: false`，已关示例数据注入） |
| 文件 | `dist/release/FuelMate-1.6.5-1000027-release-signed.hap`（384 KB） |
| SHA-256 | `e3e5e81748e474fd346a28838d7bd8be25b28e39d65ef6774ac0cf76c46bfdc2` |
| 签名 | ✅ **发布证书 + release profile**（`profile type is: release`，验签通过） |
| 实机验证 | ✅ 模拟器安装、启动、四页签渲染正常 |

> **可直接上传 AGC 审核**：已用 AGC 下发的 Release Profile 与发布证书完成签名，`hap-sign-tool verify-app` 输出 `profile type is: release / Verify success`。

## 二、发布签名（已完成，可复现）

签名材料在 `apps/harmony-native/signing/release/`：

| 文件 | 来源 | 说明 |
|---|---|---|
| `电耗记录Release.p7b` | AGC Profile（Release 类型） | `bundle-name=com.fuelmate.native`、`type=release` |
| `dist-cert.pem` | 从 p7b 中提取的发布证书（CN=王中鑫…\,Release） | 公钥与 `signing/fuelmate.p12` 一致（SHA-256 `de2f5d9…`） |
| `release-chain.pem` | dist-cert + Developer Relations CA G2 + Root CA G2 | 签名工具要求完整链，缺中间证书会报 `cause in cert file` |

> ⚠️ 你之前下载的 `y电耗.cer` 其实是**华为根 CA**（CN=Huawei CBG Root CA G2，有效期到 2049），不能当应用证书用。真正的应用证书已在 Profile 里，已自动提取。

一键出包：

```bash
bash apps/harmony-native/build-release.sh
```

脚本会：编译 release → 用 p12 + release-chain + p7b 签名 → 验签（必须看到 `profile type is: release`）→ 打印 SHA-256。
若 `signing/release/` 缺材料，脚本自动退回调试签名并在文件名标记 `debugsigned`，**不会误当成上架包**。

## 三、上传与发布

1. AGC → 应用 → **版本信息** → 填写版本号 `1.6.5`、更新说明（见第五节）
2. **软件包管理** → 上传 `FuelMate-1.6.5-release.hap`
3. 补充应用信息：图标（`assets/icon-ring-1024.png`）、截图、隐私政策 URL
   - **隐私声明**：本应用不联网、无账号、无统计，全部数据存本机 → 隐私政策可极简，但必须提供可访问的 URL
4. 提交审核 → 通过后发布（可选分阶段放量）

## 四、iOS 侧（同一套功能）

```bash
git push   # 触发 .github/workflows/ios-native-unsigned.yml
```
- 产物：`FuelMate-native-unsigned.ipa`（Release 配置，未签名）
- 分发：Sideloadly + 免费 Apple ID（7 天有效），或加入 Apple Developer 后用 TestFlight
- 上架 App Store 需：付费开发者账号 + 真机归档（`xcodebuild archive` → `exportArchive`），Windows 无法完成，需 Mac 或 CI 上的 macOS runner 配证书

## 五、本版更新说明（可直接粘贴到 AGC）

```
1. 新增「提醒」模块：里程 / 时间双规则，到期与临近分级，进度条可视化
2. 提醒支持关联费用类型：记费用时自动带出提醒并更新基准里程/日期
3. 充电记录支持编辑；列表内显示每次充电电耗（kWh/km）
4. 费用支持编辑；费用项目可自定义（新增/删除，与提醒共用）
5. 首页指标、提醒条目、底部导航全面改用系统符号图标；新增 80/20 进度环应用图标
6. 单手操作优化：记录按钮置于右下拇指热区，带按压反馈
```

## 六、已知限制（发布前请确认可接受）

| 项 | 说明 |
|---|---|
| 数据存储 | 全部存本机 preferences，**无云同步、无备份导出**；卸载即丢 |
| 深色模式 | 未适配，固定浅色配色 |
| 平板/横屏 | 可运行，但布局按手机设计拉伸，未做分栏适配 |
| 示例数据 | 仅 debug 构建首次启动注入；release 构建不会注入（已用构建验证） |
| 上架签名 | 当前为调试签名，需按第二节换成发布证书 |

## 七、回归自测清单（发布前跑一遍）

- [ ] 首次安装 → 空状态引导（新建车辆弹层自动弹出）
- [ ] 新车 → 录 2 笔充电 → 首页电耗/里程/电费每公里出现数值
- [ ] 建提醒（双规则）→ 首页出现「里程 + 时间」两条进度条
- [ ] 记一笔同类费用 → 提醒基准被更新，Toast 显示「已保存，保养提醒已更新」
- [ ] 编辑充电 / 编辑费用 → 标题为「编辑…」，保存后条数不变
- [ ] 我的 → 费用项目：新增 `洗车`、删除一个 → 费用表单与提醒关联类型同步变化
- [ ] 卸载重装 → 数据为空、不注入示例数据（release 包）
