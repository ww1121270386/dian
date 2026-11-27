# 电耗管家 · 移动端工程

三种形态，按需取用：

| 形态 | 目录 | 说明 |
|---|---|---|
| 壳工程（加载 NAS） | `apps/harmony`、`apps/ios` | WebView 打开 NAS 上的 H5，数据仍在 NAS |
| **原生离线版** | `apps/harmony-native`、`apps/ios-native` | 完全重写，数据存手机本地，断网可用 |
| 算法基准 | `apps/native-spec` | JS 实现 + 单测，两端同一口径 |

- 原生版说明与构建：[`apps/NATIVE.md`](apps/NATIVE.md)
- 壳工程说明与构建：[`apps/README.md`](apps/README.md)
- 云构建流水线：`.github/workflows/ios-native-unsigned.yml`（原生）、`ios-unsigned.yml`（壳）
