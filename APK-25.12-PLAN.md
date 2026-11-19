# 25.12 / apk 包格式兼容规划

> 状态：规划文档（阶段 0 已就绪）。触发实施的时机：任一上游项目停止发布 24.10 `.ipk` 资产，或需要支持 ImmortalWrt/OpenWrt 25.12 系列设备时。

## 一、背景

- OpenWrt / ImmortalWrt 自 **25.12** 起默认包管理器由 `opkg`(.ipk) 切换为 `apk`(.apk)。
- 本仓库所有 `.run` 自解压包的内嵌 `install.sh` 均调用 `opkg install`，因此只能用于 24.10 及以前的 opkg 系系统。
- `shell/immortalwrt.sh` 已通过 `IMMORTALWRT_SERIES` 环境变量锁定 24.10 系列，25.12 的软件源索引/包格式均不兼容。

## 二、上游现状摸底（2026-11）

| 项目 | 24.10 ipk | 25.12 apk | 备注 |
|---|---|---|---|
| Passwall | ✓（`23.05-24.10_luci-app-*.ipk`） | ✓（`25.12+_*.apk`） | 两代资产并存 |
| Passwall2 | ✓（`packages_ipk_*.zip`） | ✓（`packages_apk_*.zip` + `*.apk`） | 依赖 zip 已按代分名 |
| nikki / momo | ✓（`*-openwrt-24.10.tar.gz`） | ✓（`*-openwrt-25.12.tar.gz`） | tar.gz 内为对应格式包 |
| mosdns / openlist2 (sbwml) | ✓ | ✓ | 同上 |
| dae / homeproxy / argon / dufs | ImmortalWrt 24.10 官方源 | 待确认 25.12 源 | 走 `IMMORTALWRT_SERIES=25.12` 即可切源 |
| AdGuardHome / OpenClash / SSRP | ✓（dl.openwrt.ai 等） | 待确认 | 需逐源验证 |
| iStore (luci-app-store) | ✓ | 待确认 | 关注官方适配进度 |

结论：**主流上游均已双轨发布**，ipk 资产短期内不会消失，迁移时间窗口充足。

## 三、分阶段实施方案

### 阶段 0（已完成）：版本追踪参数化

`shell/immortalwrt.sh` 支持 `IMMORTALWRT_RELEASE` / `IMMORTALWRT_SERIES` / `IMMORTALWRT_MIRROR` 环境变量，`IMMORTALWRT_SERIES=25.12` 即可解析 25.12.x 最新补丁版（仅索引层面，包格式处理见后续阶段）。

### 阶段 1（建议首选）：双模 install.sh —— 一份 .run 通吃两代系统

`.run` 内同时携带 `.ipk` 与 `.apk`，安装脚本运行时探测包管理器：

```sh
#!/bin/sh
if command -v apk >/dev/null 2>&1; then
  apk update || exit 1
  # apk 无本地签名源时必须 --allow-untrusted，安全权衡见下文
  apk add --allow-untrusted ./*.apk
else
  opkg update || exit 1
  opkg install ./*.ipk
fi
```

- 优点：发布通道不分叉，用户无需区分设备代际；`makeself` 外壳完全不受影响。
- 代价：包体积约翻倍（两套包）；`--allow-untrusted` 需在 README 注明风险与适用场景。
- 工作量：改 14 个 install.sh 生成模板 + 一次 x86_64 25.12 虚拟机实测，约 1–2 天。

### 阶段 2：分系列构建（.run-apk 变体）

若不想体积翻倍，则为每个 workflow 增加输入参数（如 `package_series`，默认 `24.10`），产物命名追加系列后缀：

- `passwall2-26.11.11-1_x86_64.run`（24.10，现状）
- `passwall2-26.11.11-1_x86_64_25.12.run`（apk 变体）

发布策略：tag 加 `-apk` 或 `@25.12` 后缀，或单独 release 分类。
工作量：14 个 workflow 各加一路下载 + 打包分支，约 2–3 天。

### 阶段 3（可选重构）：CI 矩阵化

将 14 份高度相似的 workflow 重构为可复用 composite action / matrix（`strategy.matrix: series: [24.10, 25.12]`），消除双倍 YAML 维护成本。重构时注意保留各 workflow 的 tag/命名兼容性。

## 四、风险与注意事项

1. **依赖命名差异**：apk 系的内核/防火墙依赖（如 `kmod-*`、`firewall4`）在 apk 源中的版本约束不同，需逐包验证 `apk add` 的可解析性。
2. **签名**：apk 默认校验签名；社区源多为无签名，`--allow-untrusted` 是必要参数，但意味着放弃了包级完整性校验（与 opkg 现状一致）。
3. **机型覆盖**：25.12 目前主要覆盖 x86_64 与主流 aarch64；老设备（armv7 等）仍停留在 opkg 系，双模方案天然兼容。
4. **实测优先**：阶段 1 落地前，先在 QEMU x86_64 上跑 ImmortalWrt 25.12 snapshot 验证 install.sh，再全面铺开。

## 五、决策建议

先做**阶段 1（双模 install.sh）**：改动小、用户体验无感、发布通道不分叉；待上游明确停发 ipk 或体积成为问题时再评估阶段 2/3。
