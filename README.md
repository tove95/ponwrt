# PonWrt 6.18 for 兆能 ZN504XG-D & 烽火 HG5585F (Airoha AN7581)

简体中文 | [English](README_en.md)

[![GitHub Actions Build Status](https://img.shields.io/github/actions/workflow/status/wuziwei/ponwrt-ZN504-HG5585F/build-zn504.yml?branch=master&style=flat-square&logo=github)](https://github.com/wuziwei/ponwrt-ZN504-HG5585F/actions)
[![Latest Release](https://img.shields.io/github/v/release/wuziwei/ponwrt-ZN504-HG5585F?style=flat-square&logo=github)](https://github.com/wuziwei/ponwrt-ZN504-HG5585F/releases)
[![Target](https://img.shields.io/badge/SoC-Airoha%20AN7581-blue?style=flat-square)](https://github.com/wuziwei/ponwrt-ZN504-HG5585F)
[![Device](https://img.shields.io/badge/Device-ZN504%20%26%20HG5585F-green?style=flat-square)](https://github.com/wuziwei/ponwrt-ZN504-HG5585F)
[![Kernel](https://img.shields.io/badge/Kernel-Linux%206.18-informational?style=flat-square)](https://github.com/wuziwei/ponwrt-ZN504-HG5585F)
[![License](https://img.shields.io/badge/License-GPL--2.0-orange?style=flat-square)](LICENSE)

本项目基于上游 [PonWrt](https://github.com/pbs05/ponwrt)（ImmortalWrt / Linux `6.18`），针对采用 **达发 Airoha AN7581 (4核 Cortex-A53 @ 1.2GHz + 8核 RISC-V NPU)** 主控的双旗舰机型进行深度工程化定制、硬件驱动加速与内核网络栈增强：
* **兆能 ZN504XG-D (`znxt_zn504xg-d`)**：纯有线 2.5G 高性能光猫（EN8811H 2.5G 网口 + 3×千兆）；
* **烽火 HG5585F 电信版 (`fiberhome_hg5585f-ct`)**：带 Wi-Fi 6 光猫（Airoha AN7581 + MT7916D DBDC AX3000 + NPU WED 硬件加速，标准原生 USB 2.0 硬件配置）。

每次发布均**同时自动化编译并提供两款机型的固件包**！

---

## 🌟 核心特性与架构优化

### 1. 烽火 HG5585F MT7916 Wi-Fi 6 与 NPU WED 硬件加速全栈移植
- **MT7916D DBDC 双频无线**：集成 `kmod-mt7915e` 驱动与 `kmod-mt7916-firmware` 官方固件，支持 2.4G 2x2 + 5G 3x3 AX3000 Wi-Fi 6 并发。
- **Airoha NPU / WED 硬件直转加速**：预置 `en7581_MT7916_npu_rv32.bin` 与 `en7581_MT7916_npu_data.bin`，由达发 8 核 RISC-V NPU 直接接管无线 RX DMA 与 WED TX 数据通路，实现无线与有线之间零 CPU 占用线速转发。
- **工厂 EEPROM 校准自动提取**：内置 `/etc/hotplug.d/firmware/10-mt7916-an-eeprom` 与 `/etc/init.d/mt7916-an-eeprom`（在 `kmodloader` 加载驱动前于 `START=08` 执行），开机自动从 UBI `factory` 分区的 `0x1000` 偏移处提取 4KB 射频校准数据，校验 `0x7916` 硬件魔数并无缝提供给驱动。
- **独立 MAC 地址算号机制**：内置 `/lib/preinit/07_an7581_bsp_wifi_mac`，开机预初始化阶段自动从 `factory` 分区读取基准 MAC 并计算 2.4G (`base + 6`) 与 5G (`base + 7`) 独立合法硬件地址。
- **射频功率校准表**：预置 `SingleSKU` 与 `mt7916-sku.dat` / `mt7916-sku-bf.dat` 波束成形数据。
- **异步无线扫描防卡死机制**：集成 `rpcd` 异步信道扫描补丁（`133-rpcd-async-scan.patch`），将长耗时的 Wi-Fi 信道扫描任务从主事件循环解耦并放入子进程与延迟请求队列，彻底杜绝在 LuCI 界面点击扫描周围无线 AP 时造成的 Web 控制台无响应与 504 Gateway Timeout。

### 2. Airoha AN7581 原生 PON 光猫全栈驱动与局端兼容性增强
- 内置 `kmod-airoha-xpon`、`kmod-airoha-en7572` (BOSA)、`kmod-phy-airoha-en8811h` (2.5G PHY)、`airoha-en7581-npu-firmware` (NPU 硬件加速)。
- 内置 `airoha-pond`、`airoha-ponctl`、`luci-app-pon`。
- 支持 GPON / XG-PON / XGS-PON **O5 正常营运状态**注册认证，支持 Vendor ID（如 `FHTT`）、Equipment ID（如 `HS8145X6 (PON ONT)`）、PON SN、LOID、Password、MAC 克隆及 BOSA 校准卷管理。
- **达发 EN7572 激光冷启动防抖与闭锁保护**：集成 8 次连续硬件采样确认（140ms 稳定期），彻底修复光猫冷启动上电瞬间激光器未完全出光而偶发误报 `SYS_TX_READY` 导致被局端 OLT 秒踢下线的顽疾。
- **增强型特殊局端 OLT（华为/中兴）排查能力**：
  - **LOID 补零方向可调**：支持在 Web 界面自由选择 24 字节 LOID 的填充方向（左对齐 / 右对齐），完美解决部分省份局端 OLT 因 0x00 填充位置不同而报 `reason=0x01` 认证失败的问题；
  - **链路原始报文字节（Wire Bytes）可视化**：在 LuCI 状态页直接展示上报给局端光纤的 16 进制原始报文及 ASCII 字符（含 `CTC ONU SN (0xC7/0x0001)` 与实际发送的 `LOID`），免去抓包痛苦；
  - **Web 界面一键覆盖 PON MAC**：支持在页面直接克隆旧光猫的 PON MAC 地址，用于通过局端 MAC 绑定校验。
- **纯净网络配置生成**：修复并移除 `config_generate` 为 DHCP 网络自动生成冗余 `wan6` 客户端接口的逻辑，杜绝桥接与双栈网络下的 DHCPv6 广播风暴与接口路由冲突。
- 实时光功率（接收/发射）、供电电压、芯片温度检测与全链路遥测告警。

### 3. 核心路由与实时音视频零丢包优化（微信视频/VoIP保序）
- 默认关闭 Flowtable 流卸载（`flow_offloading='0'`，`flow_offloading_hw='0'`）：彻底根除 Linux 内核流表 `nf_flowtable_udp_timeout = 30s` 造成的微信视频/VoIP实时长连接周期性断流卡死与 UDP 乱序，Airoha AN7581 4 核 1.2GHz A53 强大算力由原生网络栈全速转发，千兆满速 CPU 占用低于 15%。
- 默认关闭多核 `packet_steering`：避免多核哈希导致实时 UDP/RTP 音视频数据包乱序到达。
- 网桥组播放行优化（`group_fwd_mask = 0x4000`）：原生放行链路层 LLDP 报文，彻底避免下挂 AP（如 WTA302）组播探针被网桥丢弃产生的 `rx_dropped` 误报警。
- 移植 QWRT 内存防碎片参数（`vm.percpu_pagelist_high_fraction = 128`）：深度优化单核 page 列表阈值，彻底杜绝 4 核并发高吞吐下的物理内存碎片与分配延迟。
- 局域网广播免连接跟踪（`NOTRACK`）：UPnP SSDP (`239.255.255.250:1900`) 与 Windows WSD (`3702`) 广播彻底绕过连接跟踪，避免广播污染 conntrack 表与交换芯片 CDM 队列。
- 预置 16MB 万兆 TCP 读写套接字大缓冲区 (`rmem_max` / `wmem_max = 16M`)，彻底消除高带宽长肥管道瓶颈，提升 4K 串流与并发吞吐。
- 解锁 AN7581 4 核 1.2GHz 动态满频算力（空闲 500MHz 极度省电清凉，重载秒升 1.2GHz）。

### 4. 内核级 Netfilter NFQUEUE 支持（原生支持 Sing-Box `auto-redirect`）
- 编译并集成 `kmod-nfnetlink-queue`、`kmod-nft-queue` 及 `kmod-ipt-nfqueue` 内核模块。
- 彻底解决 Sing-Box / Momo 在原版 PonWrt 上开启 `auto_redirect: true` 时因缺少内核 Netfilter 队列驱动而崩溃报错的问题：
  > `FATAL[0000] start nfqueue: could not unbind existing handlers: netlink receive: invalid argument (-EINVAL)`
- 实测支持 Sing-Box TUN 模式原生全自动流量重定向拦截（局域网透明网关），无需多余且脆弱的自定义 nftables 脚本。
- 预置 Momo 纯核心模式（`core_only='1'`），流量分流与直连旁路完全遵循用户 `sing-box` 订阅规则，并预设 `GOMEMLIMIT=128MiB` 健康堆内存上限。

### 5. 第一性原理纯净加解密流水线（移除 SafeXcel/EIP-93 异构负优化，回归 CPU 原生高通量）
- **根治异构 DMA 性能倒挂**：深入遵从第一性原理与 upstream ImmortalWrt 官方最新实践（commit `da63f7d`），**彻底剔除 `kmod-crypto-hw-eip93` 协处理器驱动与 `kmod-cryptodev`**。
- **为什么坚决移除 SafeXcel / EIP-93 协处理器？**
  - **总线与 DMA 严重拖累网络包性能**：网络数据包（MTU <= 1500 字节）单次加解密数据量极小。外部 DMA 协处理器每次必须经历 `dma_map_single` 刷脏缓存、构造总线描述符、触发硬中断（Hard IRQ）、上下文切换及软中断调度（SoftIRQ）。实测表明其单请求吞吐只有 CPU 原生处理的 1/3，整机 CPU 占用反而因海量中断激增！
  - **消除 Crypto API 优先级霸凌**：EIP-93 驱动默认把优先级定为 `1500`，强制霸占 Linux 内核 Crypto API 队列并造成严重的软中断锁争用与抖动。
  - **现代透明代理零受损**：Momo / Sing-box / Xray 均为 Go 语言编写的用户态程序，全部调用 Go-assembly 针对 ARMv8 `asimd`（NEON）高度优化的向量算法，**天然不经过内核 Crypto API**。
  - **WireGuard 满血释放**：WireGuard 强制使用 **ChaCha20-Poly1305**（EIP-93 硬件根本不支持），剔除 EIP-93 的中断抢占后，内核直接调用 AN7581 强大的 4 核心 1.2GHz NEON 向量单元（`chacha20-neon`），流水线零延迟，杜绝网络丢包与抖动。

### 6. 电信 4K/8K IPTV 双栈引擎
- **PON 层**：支持在光猫拨号/桥接时直接绑定电信 IPTV 业务 VLAN / 组播 VLAN。
- **应用层**：内置 `msd_lite`（默认监听 `4022` 端口，配置 8MB 环形大缓存 + 4 线程），搭配 8MB UDP 内核缓冲调优（`99-custom-net-optimization.conf`），杜绝 4K/8K 组播丢包。
- **智能播放列表**：内置广东深圳电信全分类 `/www/iptv.m3u`，并通过 `95-iptv-m3u-ip` 热插拔脚本自动随网关当前 LAN IP 动态替换播放列表中的 IP 地址。

### 7. 动态域名解析 (Cloudflare DDNS) 与全功能 DNS 引擎
- **Cloudflare DDNS**：内置 `ddns-scripts-cloudflare`，开箱即用支持双栈 IPv4 / IPv6 动态域名极速解析。
- **全功能 DNS 解析引擎 (`dnsmasq-full`)**：原生支持 `ipset`、`nftset` 与 DNSSEC，为 Sing-Box、Momo 及各类透明分流提供坚实底层。

### 8. 烽火 (FiberHome) PON 认证参数一键备份与自动防刷除保护
- 提供 `/usr/sbin/backup-fiberhome-pon.sh` 与 `/usr/sbin/restore-fiberhome-pon.sh` 脚本，一键提取并校验 `FHTT`、`HG5585FV1.0`、LOID、PON SN 及设备标识。
- 自动维护 `/etc/sysupgrade.conf`，将烽火认证数据及备忘档案永久纳入保护清单，彻底告别固件升级后需要重填认证信息的痛点。

### 9. 界面与审美调优
- **Vantage 控制台主题与网络监控看板**：修复纯有线与 Wi-Fi 混合模式下的端口拓扑流，呈现炫酷动态光流。
- **精细温控与 NPU 仪表盘**：集成 `temperature-rpc.uc` 与 `autocore`，连通 `/sbin/tempinfo` RPC，实时显示 SoC 与光模块温度。
- **网页终端 (`luci-app-ttyd`)**：随时随地免客户端一键进入 SSH 终端。

---

## 📦 固件下载 (Releases)

请前往 [GitHub Releases](https://github.com/wuziwei/ponwrt-ZN504-HG5585F/releases) 获取经过实机严格验收的固件包（每次精简输出纯净 **4 个固件**）：

| 适用设备 | 固件文件名 | 适用场景 |
| :--- | :--- | :--- |
| **兆能 ZN504XG-D** | `ponwrt-airoha-an7581-znxt_zn504xg-d-squashfs-sysupgrade.itb` | **系统平滑升级（推荐）**，保留全部配置 |
| **兆能 ZN504XG-D** | `ponwrt-airoha-an7581-znxt_zn504xg-d-initramfs-recovery.itb` | **U-Boot Web 恢复/救砖** |
| **烽火 HG5585F (CT 电信版)** | `ponwrt-airoha-an7581-fiberhome_hg5585f-ct-squashfs-sysupgrade.itb` | **系统平滑升级（推荐）**，标准 USB 2.0 硬件与 MT7916 Wi-Fi |
| **烽火 HG5585F (CT 电信版)** | `ponwrt-airoha-an7581-fiberhome_hg5585f-ct-initramfs-recovery.itb` | **U-Boot Web 恢复/救砖** |

---

## 🛠️ 刷机与升级指南

> [!IMPORTANT]
> **关于光猫认证参数保护（特别提醒）**：
> 接入运营商网络通常使用的是**克隆的原电信烽火（FiberHome / FHTT）光猫认证参数**（包含 `vendor_id='FHTT'`、`hardware_version='HG5585FV1.0'`、LOID 与 SN）。
> 升级前**切勿清空配置恢复出厂**，应直接使用保留配置升级，或在终端执行 `/usr/sbin/backup-fiberhome-pon.sh` 生成认证备份！

### 方式一：SSH 命令行保留配置安全升级（强烈推荐）

在已有系统的设备上升级，可完整保留光猫认证信息（SN、LOID、VLAN 41）与宽带账号密码：

```bash
# 1. 将 sysupgrade 固件上传至光猫的 /tmp 目录
scp -O <firmware-name>-squashfs-sysupgrade.itb root@192.168.1.1:/tmp/sysupgrade.bin

# 2. SSH 登录并校验固件完整性
ssh root@192.168.1.1 "sysupgrade -T /tmp/sysupgrade.bin"

# 3. 执行保留配置刷入（切勿使用 -n 参数，否则会清除所有参数）
ssh root@192.168.1.1 "sysupgrade -v -c /tmp/sysupgrade.bin"
```

等待设备自动刷写并重启（通常约 1~2 分钟），即可无缝恢复拨号并上线。

### 方式二：LuCI Web 升级

1. 登录 LuCI 管理后台（默认 `http://192.168.1.1`）；
2. 进入 **系统 (System) -> 备份/升级 (Backup / Flash Firmware)**；
3. 选择对应的 `squashfs-sysupgrade.itb` 镜像；
4. 勾选 **“保留配置 (Keep settings)”** 后点击上传并确认刷写。

### 方式三：U-Boot Web 恢复刷机

若因误操作导致系统无法启动：
1. 断开电源，按住机身背部 **Reset 键** 并重新插电；
2. 保持按住约 8~10 秒，待指示灯闪烁后松开；
3. 电脑网线直连 LAN 口，设置电脑静态 IP 为 `192.168.1.2` / `255.255.255.0`；
4. 浏览器访问 `http://192.168.1.1` 进入 U-Boot Web 界面；
5. 上传对应的 `initramfs-recovery.itb` 镜像刷入恢复。

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

### 3. 应用 AN7581 增强配置
```bash
./scripts/kconfig.pl + configs/an7581.config configs/release.config > .config
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

- **[OpenWrt Project](https://github.com/openwrt/openwrt)**：为全球网络设备提供坚实、可扩展的嵌入式 Linux 操作系统底座。
- **[ImmortalWrt](https://github.com/immortalwrt/immortalwrt)**：提供高度优化、特性丰富的中国本地化 OpenWrt 构建环境。
- **[pbs05/ponwrt](https://github.com/pbs05/ponwrt)**：达发 Airoha AN7581 / AN7583 PON 光猫开源架构与驱动的奠基之作，本项目核心源码基底。
- **QWRT 固件团队 / 开发者**：为达发芯片探索出 SafeXcel EIP-93 硬件密码协处理器驱动、PPE 硬件流表加速与 Wi-Fi WED 硬件直转的优秀实践范例。
- **[NNdroid](https://github.com/NNdroid)**：提供 EN7572 激光冷启动防抖确认补丁、LOID 填充方向调节及 CTC 原始报文分析回显工具链。
- **[Kahen/PonWrt-CI-UBI](https://github.com/Kahen/PonWrt-CI-UBI)**：提供 AN7581 SoC 精确温度遥测方案 (`temperature-rpc.uc` 与 LuCI RPC 联动)、MTD 读写保护 (`kmod-mtd-rw`)、自动化 CI 构建经验。
- **[LeoooChen/PonWRT-TYFZA1](https://github.com/LeoooChen/PonWRT-TYFZA1)**：提供 XG-PON 线路与 PPPoE 线速流量硬件卸载（4.5% 超低 CPU 占用）实践及 `rpcd` 异步无线扫描防卡死机制。
- **[oenhu](https://github.com/oenhu)**：贡献 PR #116 优化，避免 DHCP 网络冗余生成 `wan6` 接口引起的路由竞争。
- **[SagerNet/sing-box](https://github.com/SagerNet/sing-box)**：新一代高性能网络代理核心。
- **[nikkinikki-org/OpenWrt-momo](https://github.com/nikkinikki-org/OpenWrt-momo)**：极简高效的 OpenWrt sing-box 透明网关前端与控制面板。
- **[rchen14b/luci-app-airoha-npu](https://github.com/rchen14b/luci-app-airoha-npu)**：达发 AN7581 独立 8 核 RISC-V NPU / PPE 运行状态与硬件流表监控看板。
- **[rozhuk-im/msd_lite](https://github.com/rozhuk-im/msd_lite)**：超轻量、高通量 4K/8K IPTV 组播转单播 HTTP 代理服务器。
- **[VizzleTF/luci-theme-footstrap](https://github.com/VizzleTF/luci-theme-footstrap)**：专为 PonWrt 适配的清爽现代响应式主题。
