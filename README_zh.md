# PonWrt 6.18 for 兆能 ZN504XG-D (Airoha AN7581)

[English](README.md) | 简体中文

[![GitHub Actions Build Status](https://img.shields.io/github/actions/workflow/status/wuziwei/ponwrt-ZN504/build-zn504.yml?branch=master&style=flat-square&logo=github)](https://github.com/wuziwei/ponwrt-ZN504/actions)
[![Latest Release](https://img.shields.io/github/v/release/wuziwei/ponwrt-ZN504?style=flat-square&logo=github)](https://github.com/wuziwei/ponwrt-ZN504/releases)
[![Target](https://img.shields.io/badge/SoC-Airoha%20AN7581-blue?style=flat-square)](https://github.com/wuziwei/ponwrt-ZN504)
[![Device](https://img.shields.io/badge/Device-ZNXT%20ZN504XG--D-green?style=flat-square)](https://github.com/wuziwei/ponwrt-ZN504)
[![Kernel](https://img.shields.io/badge/Kernel-Linux%206.18-informational?style=flat-square)](https://github.com/wuziwei/ponwrt-ZN504)
[![License](https://img.shields.io/badge/License-GPL--2.0-orange?style=flat-square)](LICENSE)

本项目基于上游 [PonWrt](https://github.com/pbs05/ponwrt)（ImmortalWrt / Linux `6.18`），专为**兆能 ZN504XG-D (`znxt_zn504xg-d`)**（Airoha AN7581 10G PON ONT 光猫）进行工程化定制、硬件驱动加速与内核网络栈增强。

---

## 🌟 核心特性与架构优化

### 1. Airoha AN7581 原生 PON 光猫全栈驱动
- 内置 `kmod-airoha-xpon`、`kmod-airoha-en7572` (BOSA)、`kmod-phy-airoha-en8811h` (2.5G PHY)、`airoha-en7581-npu-firmware` (NPU 硬件加速)。
- 内置 `airoha-pond`、`airoha-ponctl`、`luci-app-pon`。
- 支持 GPON / XG-PON / XGS-PON **O5 正常营运状态**注册认证，支持 Vendor ID（如 `FHTT`）、Equipment ID（如 `HS8145X6 (PON ONT)`）、PON SN、LOID、Password、MAC 克隆及 BOSA 校准卷管理。
- 实时光功率（接收/发射）、供电电压、芯片温度检测与全链路遥测告警。

### 2. 内核级 Netfilter NFQUEUE 支持（原生支持 Sing-Box `auto-redirect`）
- 编译并集成 `kmod-nfnetlink-queue`、`kmod-nft-queue` 及 `kmod-ipt-nfqueue` 内核模块。
- 彻底解决 Sing-Box / Momo 在原版 PonWrt 上开启 `auto_redirect: true` 时因缺少内核 Netfilter 队列驱动而崩溃报错的问题：
  > `FATAL[0000] start nfqueue: could not unbind existing handlers: netlink receive: invalid argument (-EINVAL)`
- 实测支持 Sing-Box TUN 模式原生全自动流量重定向拦截（局域网透明网关），无需多余且脆弱的自定义 nftables 脚本。
- 适配 Momo（`core_only='1'`），解除默认 `60MiB` 硬编码内存限制并放宽至 `128MiB`，预设 `224.0.0.0/4`、`239.0.0.0/8` 组播流量直连绕行。

### 3. Airoha AN7581 硬件密码协处理器硬件加速 (Inside Secure SafeXcel EIP-93)
- 彻底解决 Airoha AN7581 物理 CPU 缺失 ARMv8 CPU AES 扩展指令集导致的软算性能瓶颈与高温积热。
- 驱动级激活片上基地址 `0x1fb70000` 的 **Inside Secure SafeXcel EIP-93 独立硬件密码协处理器 (`kmod-crypto-hw-eip93`)**。
- 内置 `kmod-cryptodev` 向用户空间暴露 `/dev/crypto` 硬件设备。
- 深度集成 OpenSSL 硬件加速引擎插件 (`libopenssl-devcrypto`) 与 `/etc/ssl/modules.cnf.d/devcrypto.cnf`，将 AES (ECB/CBC/CTR)、DES/3DES 及 SHA/HMAC 等加解密计算全量卸载至硬件协处理器执行，实现高吞吐、低延迟、超低 CPU 负载。

### 4. 电信 4K IPTV 双栈引擎
- **PON 层**：内置 `luci-app-iptv`，支持在光猫拨号/桥接时直接绑定电信 IPTV 业务 VLAN / 组播 VLAN。
- **应用层**：内置 `msd_lite`（默认监听 `4022` 端口，配置 8MB 环形大缓存 + 4 线程）与 `udpxy`（备用），搭配 8MB UDP 内核缓冲调优（`99-custom-net-optimization.conf`）。
- **智能播放列表**：内置广东深圳电信全分类 `/www/iptv.m3u`，并通过 `95-iptv-m3u-ip` 热插拔脚本自动随 ZN504 当前 LAN IP 动态替换播放列表中的 IP 地址。

### 5. CPU 动态按需调频与能耗温控 (`cpufreq`)
- 内置 `kmod-cpufreq-dt` 与 `luci-app-cpufreq`，默认启用 `schedutil` 动态按需调频策略。
- 待机与轻载时自动将 4 核 Cortex-A53 降频至 600MHz，高吞吐时阶梯跃升至 1.0GHz / 1.2GHz，彻底解决光猫 75°C+ 持续高温积热。

### 6. 硬件流卸载 (PPE Flow Offloading) 与局域网维护增强
- 开启 Firewall4 硬件流卸载（`flow_offloading='1'` 与 `flow_offloading_hw='1'`），打通 Airoha AN7581 专属 PPE 硬件直通加速。
- 开箱内置 `xupnpd`（DLNA IPTV 直播推流）、`luci-app-arpbind`（IP/MAC 静态防漂移绑定）、`luci-app-autoreboot`（计划定时健康自愈重启）。
- 环境变量注入 `alias iperf3='iperf3 -A 3'`，强制独占 4 核中的 Core 3 测速，彻底避开网卡与系统软中断。

### 7. 动态域名解析 DDNS-Go
- 内置 `ddns-go` + `luci-app-ddns-go` + `luci-i18n-ddns-go-zh-cn`，轻松实现公网 IPv4 / IPv6 动态域名绑定。

### 8. 系统与审美调优
- **Vantage 控制台主题与网络监控看板**（开箱默认启用；同时内置经典 Argon 离线主题作为备选）。
- ZRAM `zstd` 压缩（256MB 交换区 + 每日凌晨 04:30 自动碎片整理）。
- `ttyd` 自动免密登录、`nlbwmon` 带宽监控、`ramfree` 内存释放。

---

## 📦 固件下载 (Releases)

请前往 [GitHub Releases](https://github.com/wuziwei/ponwrt-ZN504/releases) 获取经过实机严格验收的固件包：

| 固件文件名 | 适用场景 | 说明 |
| :--- | :--- | :--- |
| `ponwrt-airoha-an7581-znxt_zn504xg-d-squashfs-sysupgrade.itb` | **系统平滑升级（推荐）** | 适用于已有 OpenWrt / PonWrt 系统升级，支持保留全部 PON 参数及拨号配置 |
| `ponwrt-airoha-an7581-znxt_zn504xg-d-initramfs-recovery.itb` | **U-Boot Web 恢复/救砖** | 适用于设备无法开机救砖或首次从原厂 U-Boot Web 刷入 |
| `momo-bundle.tar.gz` | **代理套件离线安装包** | 包含静态编译的 `sing-box` (Go ARM64) 以及 `luci-app-momo` 控制面板 |

### 校验和 (SHA-256)

```text
57d082b69d94b22adbe1d8c9650262617d38a4978bc64c6a80dabb847fbb3f64  ponwrt-airoha-an7581-znxt_zn504xg-d-squashfs-sysupgrade.itb
908e92b6ed13cdf7c36465f8a5ec5a98aa6af9a68218fff5313f229669eda5af  ponwrt-airoha-an7581-znxt_zn504xg-d-initramfs-recovery.itb
f90cd5bb3b03dc7274f72190b9fe07ad8afd0697d5cf124c70045cf64fb4f41a  momo-bundle.tar.gz
```

---

## 🛠️ 刷机与升级指南

> [!IMPORTANT]
> 升级前强烈建议导出当前设备的配置与分区备份（尤其是 `factory` / `reservearea` 原厂校准分区与身份数据）。

### 方式一：SSH 命令行保留配置安全升级（强烈推荐）

在已有 PonWrt 的 ZN504 上升级，可完整保留光猫认证信息（SN、LOID、VLAN 41）与宽带账号密码：

```bash
# 1. 将 sysupgrade 固件上传至光猫的 /tmp 目录
scp -O ponwrt-airoha-an7581-znxt_zn504xg-d-squashfs-sysupgrade.itb root@192.168.1.1:/tmp/sysupgrade.bin

# 2. SSH 登录并校验固件完整性与签名
ssh root@192.168.1.1 "sysupgrade -T /tmp/sysupgrade.bin"
# 若返回 "Signature check OK" 说明固件合法且完整

# 3. 执行保留配置刷入（切勿使用 -n 参数，否则会清除所有参数）
ssh root@192.168.1.1 "sysupgrade -v -c /tmp/sysupgrade.bin"
```

等待光猫自动刷写并重启（通常约 1~2 分钟），即可无缝恢复拨号并上线。

### 方式二：LuCI Web 升级

1. 登录 LuCI 管理后台（默认 `http://192.168.1.1`）；
2. 进入 **系统 (System) -> 备份/升级 (Backup / Flash Firmware)**；
3. 在“刷写新固件”处选择 `ponwrt-airoha-an7581-znxt_zn504xg-d-squashfs-sysupgrade.itb`；
4. 勾选 **“保留配置 (Keep settings)”** 后点击上传并确认刷写。

### 方式三：U-Boot Web 恢复刷机

若因误操作导致系统无法进入系统：
1. 断开光猫电源，按住机身背部的 **Reset 键** 不放并重新插电；
2. 保持按住 Reset 约 8~10 秒，待指示灯闪烁后松开；
3. 将电脑网线直连光猫 LAN 口，设置电脑静态 IP 为 `192.168.1.2` / `255.255.255.0`；
4. 浏览器访问 `http://192.168.1.1` 进入 U-Boot Web 界面；
5. 上传 `ponwrt-airoha-an7581-znxt_zn504xg-d-initramfs-recovery.itb` 刷入救砖。

---

## 🚀 Sing-Box 原生 `auto-redirect` 配置示例

固件内置的 `nfnetlink_queue` 驱动可直接支持 Sing-Box 的原生透明重定向。

### Inbound 配置规范：

依照 [Sing-Box 官方规范](https://deepwiki.com/SagerNet/sing-box)，`auto_redirect` 必须配合 `auto_route: true` 运行：

```json
{
  "inbounds": [
    {
      "type": "tun",
      "tag": "tun-in",
      "interface_name": "tun0",
      "address": [
        "172.19.0.1/30"
      ],
      "auto_route": true,
      "strict_route": false,
      "auto_redirect": true
    }
  ]
}
```

启动后执行 `sing-box run`，即可看到：
```text
INFO[0000] inbound/tun[tun-in]: started at tun0
INFO[0001] inbound/tun[tun-in]: inbound redirect connection from 192.168.1.xxx:xxxxx
```
流量无需额外配置复杂的 nftables 规则即可全自动完成分流与代理！

---

## 🏗️ 自行编译指南

### 1. 准备环境
推荐在 Ubuntu 22.04 / 24.04 LTS 环境下进行：
```bash
sudo bash -c 'bash <(curl -s https://build-scripts.immortalwrt.org/init_build_environment.sh)'
```

### 2. 克隆代码与更新 Feeds
```bash
git clone https://github.com/wuziwei/ponwrt-ZN504.git
cd ponwrt-ZN504

./scripts/feeds update -a
./scripts/feeds install -a
```

### 3. 应用 AN7581 配置并注入 NFQUEUE 支持
```bash
cp configs/an7581.config .config

# 注入 NFQUEUE 驱动支持
echo "CONFIG_PACKAGE_kmod-nfnetlink-queue=y" >> .config
echo "CONFIG_PACKAGE_kmod-nft-queue=y" >> .config
echo "CONFIG_PACKAGE_kmod-ipt-nfqueue=y" >> .config

make defconfig
```

### 4. 开始多线程编译
```bash
make download -j$(nproc)
make -j$(nproc) || make -j1 || make -j1 V=s
```

固件输出目录：`bin/targets/airoha/an7581/`

---

## ⚠️ 免责声明

1. 本项目为开源固件项目，旨在用于技术交流与网络设备功能研究。
2. 刷写第三方固件具有一定风险，操作前请务必备份好原厂分区数据与 LOID、宽带认证信息。
3. 请严格遵守当地电信运营商的相关管理规定，严禁用于任何非法网络活动。
