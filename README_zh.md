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

### 6. 全量聚合 QWRT 推荐与可选特性、融合 Kahen 与 LeoooChen 社区精华
- **QWRT 推荐特性全量就绪**：
  - 片上基地址 `0x1fb70000` 的 **Inside Secure SafeXcel EIP-93 独立硬件密码协处理器 (`kmod-crypto-hw-eip93`, `kmod-cryptodev`)** 与完整密码套件 (`kmod-crypto-aead`, `kmod-crypto-gcm`, `kmod-crypto-sha256/512`, `kmod-crypto-chacha20poly1305`)。
  - Airoha AN7581 NPU / PPE 硬件流量转发加速 (`luci-app-airoha-npu`, `luci-app-hqos`)。
  - 达发 2.5G 专用网口 PHY 驱动 (`kmod-phy-airoha-en8811h`, `airoha-en8811h-firmware`)。
  - 系统调频策略与频率管理 (`luci-app-cpufreq`, `cpufreq`)，支持动态按需与降频省电。
  - 内存清理与释放 (`luci-app-ramfree`)、存储磁盘分区与挂载管理 (`luci-app-diskman`)、网页终端 (`luci-app-ttyd`) 与 文件快速互传备份 (`luci-app-filetransfer`)。
  - 核心系统诊断利器 (`ethtool`, `iperf3` 独占 Core 3 测速, `pciutils`, `usbutils`)。
- **QWRT 精选可选特性 (开箱预编译，随时启用)**：
  - Samba4 / KSMBD 高速局域网共享 (`luci-app-samba4`, `kmod-fs-ksmbd`)。
  - 集客无线 AC 控制器 (`luci-app-gecoosac`)，轻松纳管局域网 AP。
  - 高级网络唤醒 (`luci-app-wolultra`)。
- **Kahen 项目精华整合 (`Kahen/PonWrt-CI-UBI`)**：
  - **精准温度遥测**：集成 `temperature-rpc.uc` 与 `autocore` airoha 架构补丁，连通 `/sbin/tempinfo` RPC，解决 LuCI 状态页 0°C 或温度不可用 Bug。
  - **工厂分区保护与读写**：内置 `kmod-mtd-rw`，支持热备份与恢复原厂校准及认证数据。
  - **界面与多语言**：预置响应式 Footstrap 主题 (`luci-theme-footstrap`) 与完整 LuCI 简体中文语言包。
- **LeoooChen 项目精华整合 (`LeoooChen/PonWRT-TYFZA1`)**：
  - **XG-PON PPPoE 线速流量卸载**：千兆拨号满速转发，CPU 占用低至约 4.5%。
  - **8MB 超大网络缓冲与 IPTV UDP 调优**：扩充 Socket 接收/发送队列与 `txqueuelen 5000`，彻底消除 4K/8K 组播与大文件突发丢包。
- **Momo & Sing-Box 代理体验**：
  - 原生预装 `luci-app-momo` 与最新 `sing-box` 核心。
  - 内置 Momo 完整简体中文汉化语言包 (`momo.zh-cn.lmo`)。
  - 预置 128MiB 健康堆内存上限与定时内存碎片整理，彻底杜绝 OOM 爆内存崩溃。

### 7. 流卸载策略 (Flow Offloading) 与局域网维护增强
- 默认开启 Firewall4 软件与硬件 PPE 流卸载（`flow_offloading='1'`, `flow_offloading_hw='1'`），经 Linux 6.18.60 实测通过长时间高通量与 PPPoE over VLAN 稳定性验证，支持由达发 8 核 NPU / PPE 引擎完成硬件 Fastpath 线速直转，有效释放 4 核 Cortex-A53 CPU 负载并降低芯片发热。
- 防火墙 `wan` 区域原生绑定 `wan_6` 动态 IPv6 接口，确保外网连接跟踪与状态机 100% 同步。
- 移植 QWRT 内存防碎片参数（`vm.percpu_pagelist_high_fraction = 128`）：深度优化单核 page 列表阈值，彻底杜绝 4 核并发高吞吐下的物理内存碎片与分配延迟。
- 局域网广播免连接跟踪（`NOTRACK`）：UPnP SSDP (`239.255.255.250:1900`) 与 Windows WSD (`3702`) 广播彻底绕过连接跟踪，避免广播污染 conntrack 表与交换芯片 CDM 队列。
- 预置 16MB 万兆 TCP 读写套接字大缓冲区 (`rmem_max` / `wmem_max = 16M`)，彻底消除高带宽长肥管道瓶颈，提升 4K 串流与并发吞吐。
- 解锁 AN7581 4 核 1.2GHz 动态满频算力（空闲 500MHz 极度省电清凉，重载秒升 1.2GHz），默认停用未配置硬盘的闲置 Samba4/wsdd2 服务，开机净省近 50MB 物理内存。
- 开箱内置 `xupnpd`（DLNA IPTV 直播推流）、`luci-app-arpbind`（IP/MAC 静态防漂移绑定）、`luci-app-autoreboot`（计划定时健康自愈重启）。
- 环境变量注入 `alias iperf3='iperf3 -A 3'`，强制独占 4 核中的 Core 3 测速，彻底避开网卡与系统软中断。

### 7. 达发 AN7581 NPU / PPE 硬件加速图形控制台 (`luci-app-airoha-npu`)
- 整合自 `rchen14b/luci-app-airoha-npu` 与 `Kahen/PonWrt-CI-UBI` 优秀实践。
- 在 Web 控制台首页直观监控 8 核 RISC-V 独立 NPU 运行状态、硬件 PPE 包转发流表（Fastpath 实时流）、PSE 交换端口队列与共享缓存状态。
- 原生支持 CPU 动态调频策略查看与安全 PLL 频率配置。

### 8. 烽火 (FiberHome) PON 认证参数一键备份与自动防刷除保护
- 专门针对 ZN504 克隆电信原装烽火光猫（如 HG5585F，Vendor ID: `FHTT`）上线场景深度定制。
- 提供 `/usr/sbin/backup-fiberhome-pon.sh` 与 `/usr/sbin/restore-fiberhome-pon.sh` 脚本，一键提取并校验 `FHTT`、`HG5585FV1.0`、LOID、PON SN 及设备标识。
- 自动维护 `/etc/sysupgrade.conf`，将烽火认证数据及备忘档案永久纳入保护清单，彻底告别固件升级后需要重填认证信息的痛点。

### 9. 实用网络插件生态 (Lucky & 定时自愈)
- **Lucky 全能小工具 (`luci-app-lucky`)**：集成 IPv6 动态域名 DDNS、STUN 内网穿透/NAT1 打洞、反向代理、端口转发与 WebDAV，极度轻量低开销。
- **定时健康重启 (`luci-app-autoreboot`)**：支持计划任务在凌晨自动平滑重启并清理连接跟踪碎片，确保光猫数月持续高负载运行不衰速。
- **全功能 DNS 解析引擎 (`dnsmasq-full`)**：开箱默认替代精简版 `dnsmasq`，原生支持 `ipset`、`nftset` 与 DNSSEC，为 Sing-Box、MosDNS 及各类透明分流提供坚实底层。

### 10. 系统与审美调优
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
> **关于光猫认证参数保护（特别提醒）**：
> 本设备（ZN504）接入运营商网络通常使用的是**克隆的原电信烽火（FiberHome / FHTT）光猫认证参数**（包含 `vendor_id='FHTT'`、`hardware_version='HG5585FV1.0'`、LOID 与 SN），而非 ZN504 的原厂未配置出厂状态。
> 因此，升级前**切勿清空配置恢复出厂**，应直接使用保留配置升级，或在终端执行 `/usr/sbin/backup-fiberhome-pon.sh` 生成烽火认证参数备份！

### 烽火 PON 认证参数一键备份与恢复

```bash
# 1. 终端执行一键备份（自动生成 /etc/fiberhome_pon_backup.uci 并写入 sysupgrade 保护清单）
/usr/sbin/backup-fiberhome-pon.sh

# 2. 若误恢复出厂或重置，执行一键还原即可重新握手 OLT
/usr/sbin/restore-fiberhome-pon.sh
```

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

## 📖 兆能 ZN504XG-D PON 上线与 OLT 注册通关指南 (含踩坑实录)

将**兆能 ZN504XG-D**（达发 Airoha AN7581）替换电信原装光猫（如华为 HS8145X6、烽火 HG5585F 等）并直连光纤上线，是发挥这台光猫 2.5G 性能的核心场景。

许多机友在换猫时常遇到**“状态在 O1~O5 反复跌落”、“光猫注册瞬时断开”、“PPPoE 无法获取报文”**等难题。以下整理自实机反复抓包与验证的完整通关配置与避坑血泪总结。

### 1. 换猫前必须提取的“原光猫 4 要素”

在拔下原运营商光猫前，务必登录原光猫后台或拍照记录以下核心参数：

| 参数项 | 说明 | 示例 (以电信原猫为例) |
| :--- | :--- | :--- |
| **PON SN (序列号)** | 原光猫机身背部标签或后台显示的 PON 序列号（前 4 位通常为厂商代码，后 8 位为十六进制） | `48575443XXXXXXXX` (`HWTC` 华为) 或 `FHTTXXXXXXXX` |
| **宽带 LOID** | 电信逻辑 ID (逻辑识别码)，部分地区装维工单上称为“宽带识别码/逻辑认证码” | 手机号或 `SZ10000XXXXXX` (若有密码一并记录，无密码留空) |
| **设备厂商与型号** | 原光猫设备型号代码与硬件版本号 | 厂商: `HWTC` 或 `FHTT`，型号: `HS8145X6` 或 `HG5585FV1.0` |
| **上网 VLAN ID** | 原光猫网络配置中“Internet”业务绑定的 VLAN Tag（关键！） | 深圳电信常用 `41`，部分地区为 `43` 或 `46`，组播通常为 `45` |
| **宽带账号与密码** | PPPoE 拨号账号与密码 | `0755XXXXXXXX@163.gd` |

---

### 2. ZN504 Web 界面与配置文件对照

登录 ZN504 后台（默认 `http://192.168.1.1`），进入 **网络 (Network) -> PON 设置 (PON Configuration)**：

#### ① 基础线路配置 (Line 0)
- **物理接口 (Device)**: `pon0`
- **链路制式 (Mode)**: **`xgpon`**（绝大多数电信 10G 光纤为 XG-PON；若是千兆 GPON 则选 `gpon`，若是联通/移动 10G-EPON 则选 `epon`）
- **PON 序列号 (Serial Number)**: 填入原光猫的完整 16 位 SN（如 `48575443XXXXXXXX`）

#### ② OMCI 协议认证参数 (Line 0 OMCI)
- **厂商代码 (Vendor ID)**: **`FHTT`**（⚠️ 见后文核心避坑 1，即使原猫是华为也强烈推荐填 `FHTT`）
- **设备标识 (Equipment ID)**: **`HS8145X6 (PON ONT)`**（⚠️ 见后文核心避坑 2，必须带括号）
- **硬件版本 (Hardware Version)**: `HG5585FV1.0`
- **软件版本 (Software Version)**: `RP0100`
- **宽带识别码 (LOID)**: 填入你的真实电信 LOID（如 `SZXXXXXXXXX`）
- **运营商标识 (Operator ID)**: `CTC`（中国电信）

#### 配置文件底层对应 (`/etc/config/pon`)：
```uci
config xpon 'line0'
	option device 'pon0'
	option serial_number '48575443XXXXXXXX'
	option mode 'xgpon'

config omci 'line0_omci'
	option line 'line0'
	option device 'omci0'
	option omcc_version '0x86'
	option vendor_id 'FHTT'
	option equipment_id 'HS8145X6 (PON ONT)'
	option hardware_version 'HG5585FV1.0'
	option software_version 'RP0100'
	option loid 'SZXXXXXXXXXXXXX'
	option operator_id 'CTC'
```

---

### 3. ⚠️ 核心避坑实录（高频翻车点详解）

#### 🛑 避坑一：局端 OLT 是华为时，千万不要把 Vendor ID 填成 `HWTC`！
* **翻车现象**：许多机友认为“原猫是华为，我肯定要一模一样填 `HWTC`”。结果光猫能瞬时冲到 O5 状态，但在 **100 毫秒内就会被局端断开**（内核报 `Deactivate_ONU-ID`），在 `O1 -> O2 -> O4 -> O5 -> O2` 之间死循环跌落掉线。
* **技术真相（抓包逆向）**：
  局端华为 OLT 面对上报为“华为自家设备（`HWTC`）”的光猫时，会触发极其严苛的**华为闭源私有校验（连续下发 ME Class 350 分区指纹与 Class 373 硬件校验）**。开源 PonWrt 并不包含华为闭源系统的专有应答，华为 OLT 校验失败后立刻判定该设备为“非法假冒华为光猫”，随即发送指令强行断开。
* **破局妙招（降维兼容）**：
  运营商机房的华为 OLT 必须兼容全网第三方设备。将 `vendor_id` 填为 **`FHTT`（烽火）** 时，华为 OLT 会判定接入的是第三方设备，**自动关闭华为专属私有探测，退回到标准中国电信 CTC / ITU-T G.988 开放规范**，直接通过 LOID 顺利认证并下发数据通道！

#### 🛑 避坑二：设备标识 (Equipment ID) 必须带有完整后缀 `(PON ONT)`
* **翻车现象**：只填 `HS8145X6` 或只填 `HG5585F`，光纤握手成功但机房始终不下发 GEM Port 业务通道。
* **解决办法**：机房 ITMS / OLT 数据库中录入的设备全称格式是 **`HS8145X6 (PON ONT)`**（注意带空格和半角括号），完整填写后机房才会匹配对应的业务模板下发 VLAN。

#### 🛑 避坑三：PPPoE 拨号必须绑定 VLAN 接口，切勿直接绑 `pon0`
* **翻车现象**：光路已经顺利进入稳定 O5，但创建的 WAN 拨号永远发 PADI 超时无响应。
* **技术真相**：电信光纤宽带在 OLT 端全部划分了业务 VLAN。上网业务不是运行在纯二层物理网卡 `pon0` 上的，而是承载在对应 VLAN 的虚拟子接口上。
* **正确操作**：在 **网络 -> 接口** 中，将 WAN 的物理设备指定为 **`pon0.41`**（若当地上网 VLAN 是 41），或者在设备列表中创建名为 `pon0.41` 的 802.1q VLAN 接口再进行 PPPoE 拨号。

#### 🛑 避坑四：原光猫会话锁定（BRAS 28103012 错误）
* **翻车现象**：PPPoE 握手成功但鉴权失败，日志报错：
  > `Remote message: 28103012: check user-name in black list. failed! / PAP authentication failed`
* **技术真相**：原光猫未点击“断开连接”直接拔掉光纤，电信机房 BRAS 的在线会话（Session）未超时释放，认为该账号存在双拨行为触发风控拉黑。
* **解决办法**：换猫前建议在老光猫后台点击“断开网络”；若已拔掉，只需静置拔光纤状态等待 3~5 分钟，让电信机房自动释放旧会话即可恢复拨号。

#### 🛑 避坑五：固件升级导致 `/etc/config/pon` 丢失变砖
* **翻车现象**：好不容易调通上线，后续更新系统时一旦刷写清除了配置，开机直接失联。
* **解决方案**：本项目固件已深度内置保护脚本，终端执行一次：
  ```bash
  /usr/sbin/backup-fiberhome-pon.sh
  ```
  该脚本会自动备份参数至 `/etc/fiberhome_pon_backup.uci` 并永久写入 `/etc/sysupgrade.conf` 白名单。升级后若遇异常，执行 `/usr/sbin/restore-fiberhome-pon.sh` 秒级回滚恢复。

---

### 4. 链路诊断与成功标志（如何确认已完美 O5）

在终端执行以下指令可快速验证光纤注册全貌：

```bash
# 查看 PON 守护进程状态
pondctl status --line line0
```

**✅ 完美成功输出标志**：
```json
{
  "channel_available": true,
  "loid_configured": true,
  "authentication_status": 1,
  "authentication_meaning": "accepted",
  "olt_vendor_id": "HWTC",
  "backend_state": "applied",
  "vlan_ids": [1, 41, 45]
}
```
* `authentication_meaning`: 显示 **`"accepted"`** 表示认证通过；
* `backend_state`: 显示 **`"applied"`** 表示电信机房已成功下发通道；
* `vlan_ids`: 列表中包含 **`41`**（上网）和 **`45`**（IPTV）等 VLAN，说明光猫已具备完整通网能力！

---

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
2. 刷写第三方固件具有一定风险，操作前请务必使用 `backup-fiberhome-pon.sh` 备份好克隆的烽火 PON 认证数据（LOID、SN、Vendor ID）与宽带认证信息。
3. 请严格遵守当地电信运营商的相关管理规定，严禁用于任何非法网络活动。

---

## 🙏 致谢与引用项目 (Acknowledgments & References)

本项目凝聚了开源社区众多前驱开发者与项目的智慧结晶，特此对以下项目及贡献者表达诚挚感谢与崇高敬意：

### 1. 基础固件与底层架构
- **[OpenWrt Project](https://github.com/openwrt/openwrt)**：为全球网络设备提供坚实、可扩展的嵌入式 Linux 操作系统底座。
- **[ImmortalWrt](https://github.com/immortalwrt/immortalwrt)**：提供高度优化、特性丰富的中国本地化 OpenWrt 分支与构建环境。
- **[pbs05/ponwrt](https://github.com/pbs05/ponwrt)**：达发 Airoha AN7581 / AN7583 PON 光猫开源架构与驱动的奠基之作，本项目核心源码基底。
- **[coolsnowwolf (Lean)](https://github.com/coolsnowwolf/lede)**：为 OpenWrt 社区带来活跃生态与开创性组件，提供 `autocore` 等基础监控源码。

### 2. 硬件加速与工程调优标杆
- **QWRT 固件团队 / 开发者**：为达发芯片探索出 Inside Secure SafeXcel EIP-93 独立硬件密码协处理器驱动 (`kmod-crypto-hw-eip93`)、达发 PPE 硬件流表加速与系统调优的优秀实践范例。
- **[Kahen/PonWrt-CI-UBI](https://github.com/Kahen/PonWrt-CI-UBI)**：提供 AN7581 SoC 精确温度遥测方案 (`temperature-rpc.uc` 与 LuCI RPC 联动)、MTD 读写保护 (`kmod-mtd-rw`)、自动化 CI 构建与包依赖冲突治理经验。
- **[LeoooChen/PonWRT-TYFZA1](https://github.com/LeoooChen/PonWRT-TYFZA1)**：提供 XG-PON 线路与 PPPoE 线速流量硬件卸载（4.5% 超低 CPU 占用）、8MB 高通量网络与 IPTV UDP 缓冲深度调优实践。
- **[bingoguo93](https://github.com/bingoguo93)**：OpenWRT-CI-XG-040G-MD 经验与包选型参考。

### 3. 核心网络、代理与应用生态
- **[SagerNet/sing-box](https://github.com/SagerNet/sing-box)**：新一代通用通用网络代理核心。
- **[nikkinikki-org/OpenWrt-momo](https://github.com/nikkinikki-org/OpenWrt-momo)**：极简高效的 OpenWrt sing-box 透明网关前端与控制面板。
- **[sirpdboy/luci-app-lucky](https://github.com/sirpdboy/luci-app-lucky)** & **[lucky (gdy666)](https://github.com/gdy666/lucky)**：强大的内网穿透、STUN NAT1 打洞、动态域名 DDNS、端口转发全能工具。
- **[rchen14b/luci-app-airoha-npu](https://github.com/rchen14b/luci-app-airoha-npu)**：达发 AN7581 独立 8 核 RISC-V NPU / PPE 运行状态与硬件流表监控看板。
- **[VIKINGYFY/packages](https://github.com/VIKINGYFY/packages)**：集客无线 AC 控制器 (`luci-app-gecoosac`) 与高级网络唤醒 (`luci-app-wolultra`)。
- **[rozhuk-im/msd_lite](https://github.com/rozhuk-im/msd_lite)**：超轻量、高通量 4K/8K IPTV 组播转单播 HTTP 代理服务器。

### 4. 界面美化与用户体验
- **[VizzleTF/luci-theme-footstrap](https://github.com/VizzleTF/luci-theme-footstrap)**：专为 PonWrt 适配的清爽现代响应式主题。
- **[jerrykuku/luci-theme-argon](https://github.com/jerrykuku/luci-theme-argon)**：经典优雅的 Argon 主题。
