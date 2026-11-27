# AGC 提交审核 · 一步步操作

> 适用：电耗管家 HarmonyOS 版 1.6.5（包名 `com.fuelmate.native`）
> 上架包：`apps/harmony-native/dist/release/FuelMate-1.6.5-release.app`（266 KB，已用发布证书签名）

---

## 0. 前置检查（都已具备）

| 项 | 状态 |
|---|---|
| 华为开发者账号 + 实名认证 | 已完成（能生成发布证书即代表已认证） |
| AGC 里的应用记录 | 已完成（Profile 绑定了 `com.fuelmate.native`） |
| 发布证书 + Release Profile | ✅ `signing/release/` |
| 上架软件包（`.app`，非 `.hap`） | ✅ `FuelMate-1.6.5-release.app` |
| 应用图标 | ✅ `assets/icon-square-1024.png`（1024×1024，**无圆角**，AGC 要求方形原图） |
| 隐私政策网址 | ❌ **必须自己准备**（见第 4 步） |
| 截图 | ⚠️ 需竖屏 3 张以上（见第 3 步） |

---

## 1. 进入上架页

1. 打开 <https://developer.huawei.com/consumer/cn/service/josp/agc/index.html> 登录
2. 顶部 **「我的应用」** → 找到「电耗管家」（没有就 **「我的项目」→ 添加应用 → HarmonyOS → 包名填 `com.fuelmate.native`**）
3. 左侧菜单 **「应用上架」→「版本信息」** → 点 **「新建发布」**

## 2. 上传软件包

1. 页面里 **「软件包管理」→「上传」**
2. 选 `FuelMate-1.6.5-release.app`（**不要传 .hap**，AGC 只认 .app）
3. 上传后系统自动做**合法性检测**（必选，几十秒）→ 通过后状态变「已上传」
4. 可选但强烈建议：该行「操作」→ **「启动自检」**（云端跑兼容性/稳定性/性能/功耗/UX/隐私，能提前发现被拒原因）

## 3. 填写版本与应用信息

**版本信息**
- 版本号：`1.6.5`
- 更新说明（直接粘）：
```
1. 新增提醒模块：里程/时间双规则，到期与临近分级，进度条可视化
2. 提醒可关联费用类型，记费用时自动更新基准里程/日期
3. 充电与费用记录支持编辑；充电列表显示单次电耗
4. 费用项目可自定义，与提醒共用同一份列表
5. 全面改用系统符号图标，新增 80/20 进度环应用图标
6. 单手握持优化：记录按钮置于右下拇指热区
```

**应用信息**
- 应用名称：`电耗管家`（系统会校验唯一性；若被占用需改名）
- 应用图标：上传 `assets/icon-square-1024.png`
  > 审核会比对「提交图标 = 安装后桌面图标 = 最近任务列表图标」，三处必须一致，否则驳回。我们 App 内用的是同一套图，OK。
- 应用分类：建议 `工具 > 效率`（或 `汽车 > 用车服务`，按 AGC 当前分类树选）
- 标签：最多 5 个，如 `电耗`、`充电记录`、`用车记账`、`里程管理`
- 简介/描述：≥20 字，例如
```
记录每次充电与用车开销，自动算出电耗（kWh/km）、每公里电费与年度里程进度，
并对保养、年检、保险等到期项做提醒。数据仅保存在本机，不联网、不上传。
```
- 截图：**至少 3 张，竖屏**，建议 1080×2400 或同比例
  > 现有模拟器截图是横屏/异形分辨率，不符合建议规格。正确做法：把模拟器切竖屏（或真机）后截 首页 / 充电 / 我的 三张。

## 4. 隐私与合规（最常被拒的一环）

1. **隐私政策网址**（必填）：需要一个公网可访问的网页，写清「收集什么、怎么用、怎么删」。
   本应用实际是**零收集**：不联网、无账号、无埋点、无第三方 SDK。最简文案：
   ```
   本应用不收集、不上传任何个人信息。
   所有车辆、充电、费用、提醒数据仅保存在您的设备本地；
   卸载应用即彻底删除，我们无法访问。
   如对本政策有疑问，请联系：<你的邮箱>
   ```
   托管方式：语雀/腾讯文档公开页、GitHub Pages、Notion 公开页均可（必须是 https 可访问）。
2. **隐私声明/数据安全表单**：「是否收集个人信息」选 **否**；权限使用说明留空（本应用未申请敏感权限）。
3. **AI 功能声明**：选 **不涉及**（无生成式 AI）。
4. **账号登录**：本应用无账号体系，无需接入华为账号登录（只有提供三方账号登录时才强制）。

## 5. 资质与备案

1. **APP 备案**：中国大陆上架通常需要工信部 APP 备案。
   **但本应用完全离线可用（断网后所有功能正常）→ 属于「单机 APP」，可免备案**：
   在「备案信息」处勾选 **「单机 APP」**。
   > 勾选需谨慎：审核会验证断网可用性。本应用无任何网络请求，符合条件。
   > 若后续加了云同步/联网统计，就必须走正式 APP 备案，否则会被驳回。
2. **版权信息**：可选。有《App 电子版权证书》可上传加分，没有也能提交。

## 6. 发布设置

- 发布国家和地区：**中国大陆**（需要海外就勾选对应地区，但海外无需备案）
- 付费情况：**免费**
- 上架时间：审核通过后立即发布（或指定时间）
- 分阶段发布：可选，建议首次 `10% → 50% → 100%`

## 7. 联系信息与提交

1. 填写审核联系邮箱/电话（审核人员可能联系你补充材料）
2. 通读「审核指南」自查一遍
3. 点 **「提交审核」**

## 8. 审核中与之后

| 事项 | 说明 |
|---|---|
| 审核时长 | 正式版 1–3 个工作日，多数 24 小时内 |
| 加急 | 后台可申请「审核加急」，需填理由，资源有限 |
| 被驳回 | 按审核意见逐条修改 → 重新提交，无需重新创建应用 |
| 上架后搜不到 | 检查：设备是否 HarmonyOS 5+、API 版本是否在适配范围、是否只发布了手机设备、上架时间是否未到 |

## 9. 高频驳回原因（针对本应用的风险点）

| 风险 | 说明 | 应对 |
|---|---|---|
| 图标不一致 | 提交图标 ≠ 桌面图标 | 用同一张 `icon-square-1024.png` 的视觉；桌面图标已同源 |
| 隐私政策缺失/打不开 | URL 404 或需登录 | 用公开可访问页面，提交前自己用无痕窗口打开验证 |
| 单机 APP 误勾 | 应用存在联网行为 | 本应用确实离线；如后续加联网要改备案 |
| 应用名称侵权/泛词 | 「电耗管家」较通用 | 若被要求改名，准备 2 个备选 |
| 截图不合规 | 横屏/含测试数据 | 用竖屏、清空测试数据后截 |
| 描述过短 | <20 字 | 用上面给的文案 |

---

## 附：重新出包命令

```bash
bash apps/harmony-native/build-release.sh              # 出 .hap（真机侧载）
```
上架用 `.app`：
```bash
cd apps/harmony-native
export DEVECO_SDK_HOME="D:\\Program Files\\DevEco Studio\\sdk"
export JAVA_HOME="D:\\Program Files\\DevEco Studio\\jbr"
export PATH="/d/Program Files/DevEco Studio/jbr/bin:/d/Program Files/DevEco Studio/tools/node:$PATH"
"/d/Program Files/DevEco Studio/tools/hvigor/bin/hvigorw.bat" assembleApp --mode project -p product=default -p buildMode=release --no-daemon
"D:/Program Files/DevEco Studio/jbr/bin/java.exe" -jar "D:/Program Files/DevEco Studio/sdk/default/openharmony/toolchains/lib/hap-sign-tool.jar" sign-app \
  -keyAlias fuelmate -signAlg SHA256withECDSA -mode localSign \
  -appCertFile signing/release/release-chain.pem \
  -profileFile "signing/release/电耗记录Release.p7b" \
  -inFile build/outputs/default/harmony-native-default-unsigned.app \
  -keystoreFile signing/fuelmate.p12 -outFile dist/release/FuelMate-1.6.5-release.app \
  -keyPwd "FuelMate@2026" -keystorePwd "FuelMate@2026"
```
