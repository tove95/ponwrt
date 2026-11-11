# PonWrt 6.18 for 兆能 ZN504XG-D (Airoha AN7581)

English | [简体中文](README_zh.md)

[![GitHub Actions Build Status](https://img.shields.io/github/actions/workflow/status/wuziwei/ponwrt-ZN504/build-zn504.yml?branch=master&style=flat-square&logo=github)](https://github.com/wuziwei/ponwrt-ZN504/actions)
[![Latest Release](https://img.shields.io/github/v/release/wuziwei/ponwrt-ZN504?style=flat-square&logo=github)](https://github.com/wuziwei/ponwrt-ZN504/releases)
[![Target](https://img.shields.io/badge/SoC-Airoha%20AN7581-blue?style=flat-square)](https://github.com/wuziwei/ponwrt-ZN504)
[![Device](https://img.shields.io/badge/Device-ZNXT%20ZN504XG--D-green?style=flat-square)](https://github.com/wuziwei/ponwrt-ZN504)
[![Kernel](https://img.shields.io/badge/Kernel-Linux%206.18-informational?style=flat-square)](https://github.com/wuziwei/ponwrt-ZN504)
[![License](https://img.shields.io/badge/License-GPL--2.0-orange?style=flat-square)](LICENSE)

Customized and performance-enhanced [PonWrt](https://github.com/pbs05/ponwrt) (based on [ImmortalWrt](https://github.com/immortalwrt/immortalwrt) / Linux `6.18`) firmware specifically engineered for the **ZNXT (兆能) ZN504XG-D (`znxt_zn504xg-d`)** 10G PON optical modem / gateway, powered by the Airoha AN7581 quad-core ARM64 SoC.

---

## 🌟 Key Features & Architectural Enhancements

### 1. Full-Stack Airoha AN7581 Native PON Drivers
- Integrated `kmod-airoha-xpon`, `kmod-airoha-en7572` (BOSA), `kmod-phy-airoha-en8811h` (2.5G PHY), and `airoha-en7581-npu-firmware` (NPU hardware offload).
- Integrated `airoha-pond`, `airoha-ponctl`, and `luci-app-pon`.
- Supports GPON / XG-PON / XGS-PON **O5 operational state** registration and verification, with full configuration of Vendor ID (e.g., `FHTT`), Equipment ID (e.g., `HS8145X6 (PON ONT)`), PON SN, LOID, password, cloned MAC, and BOSA calibration volume preservation.
- Live telemetry for Rx/Tx optical power, operating voltage, and SoC temperature.

### 2. Kernel Netfilter NFQUEUE Integration (Native Sing-Box `auto-redirect`)
- Compiled and integrated `kmod-nfnetlink-queue`, `kmod-nft-queue`, and `kmod-ipt-nfqueue`.
- Completely solves the crash when enabling `auto_redirect: true` in Sing-Box / Momo on stock PonWrt:
  > `FATAL[0000] start nfqueue: could not unbind existing handlers: netlink receive: invalid argument (-EINVAL)`
- Enables native transparent proxy redirection via Sing-Box TUN mode without requiring complex custom nftables scripting.
- Optimized for Momo (`core_only='1'`), lifting the default 60MiB hard-coded memory restriction to `128MiB` with direct bypass routing for multicast `224.0.0.0/4` and `239.0.0.0/8`.

### 3. Hardware Crypto Coprocessor Acceleration (Inside Secure SafeXcel EIP-93)
- Resolves the performance bottleneck and thermal throttling caused by the lack of ARMv8 AES CPU extensions on the physical AN7581 cores.
- Driver-level activation of the on-chip **Inside Secure SafeXcel EIP-93 dedicated hardware cryptographic engine (`kmod-crypto-hw-eip93`)** at base address `0x1fb70000`.
- Integrated `kmod-cryptodev` to expose `/dev/crypto` to user-space.
- Fully wired into the OpenSSL engine subsystem (`libopenssl-devcrypto`) via `/etc/ssl/modules.cnf.d/devcrypto.cnf`, offloading AES (ECB/CBC/CTR), DES/3DES, and SHA/HMAC calculations directly to the hardware engine for wire-speed crypto and low CPU load.

### 4. Dual-Stack 4K Telecom IPTV Engine
- **PON Layer**: Built-in `luci-app-iptv` for binding IPTV service VLAN and multicast VLANs on dial-up or bridge mode.
- **Application Layer**: Integrated `msd_lite` (listening on port `4022`, configured with 8MB circular cache + 4 threads) and `udpxy` (backup), coupled with 8MB UDP socket kernel buffer optimization (`99-custom-net-optimization.conf`).
- **Dynamic Playlist**: Bundled with Guangdong Shenzhen Telecom categorized `/www/iptv.m3u`, automatically updated with the current LAN gateway IP via the `95-iptv-m3u-ip` hotplug hook.

### 5. Dynamic Frequency Scaling & Thermal Control (`cpufreq`)
- Integrated `kmod-cpufreq-dt` and `luci-app-cpufreq` using the `schedutil` governor.
- Automatically scales the 4x Cortex-A53 cores down to 600MHz at idle and ramps up to 1.0GHz / 1.2GHz under load, preventing overheating.

### 6. Flow Offloading & Maintenance Utilities
- Firewall4 software and hardware PPE flow offloading enabled by default (`flow_offloading='1'`, `flow_offloading_hw='1'`), verified stable over long-term high-throughput PPPoE-over-VLAN workloads on Linux 6.18.60, providing line-rate Fastpath packet processing via the Airoha 8-core NPU/PPE to significantly offload the 4-core Cortex-A53 CPU and reduce heat dissipation.
- Native dynamic IPv6 interface `wan_6` binding added to Firewall zone `wan` for comprehensive state tracking.
- QWRT per-CPU pagelist memory optimization (`vm.percpu_pagelist_high_fraction = 128`) preventing page allocation stalls and memory fragmentation under high-bandwidth multi-core concurrency.
- QWRT SSDP (`239.255.255.250:1900`) and WSD (`3702`) `NOTRACK` bypass to avoid connection tracking table bloat and switch CDM queue backpressure.
- 16MB high-throughput TCP socket buffer tuning (`rmem_max` / `wmem_max = 16M`) to eliminate bandwidth-delay product bottlenecks.
- AN7581 1.2GHz dynamic cpufreq governor unlock and disabled unused Samba4/wsdd2 services saving ~50MB physical RAM out of the box.
- Out-of-the-box support for `xupnpd` (DLNA IPTV streaming), `luci-app-arpbind` (static IP/MAC anti-drift binding), and `luci-app-autoreboot` (scheduled auto-restart).
- Pre-configured shell alias `alias iperf3='iperf3 -A 3'` pinning speedtests to Core 3, avoiding network interrupt starvation on other cores.

### 7. Dynamic DNS (DDNS-Go)
- Pre-installed `ddns-go` + `luci-app-ddns-go` + `luci-i18n-ddns-go-zh-cn` for IPv4 & IPv6 automated DNS record management.

### 8. System Ergonomics & Aesthetics
- **Vantage Console Theme & Dashboard** (pre-enabled by default; classical Argon theme also bundled).
- ZRAM `zstd` compressed swap (256MB swap + daily 04:30 defragmentation).
- `ttyd` terminal auto-login, `nlbwmon` bandwidth monitor, and `ramfree` memory reclamation.

---

## 📦 Firmware Downloads

Download release binaries from [GitHub Releases](https://github.com/wuziwei/ponwrt-ZN504/releases):

| Firmware Image | Use Case | Description |
| :--- | :--- | :--- |
| `ponwrt-airoha-an7581-znxt_zn504xg-d-squashfs-sysupgrade.itb` | **System Upgrade (Recommended)** | For upgrading existing OpenWrt/PonWrt systems. Preserves all PON identity parameters and broadband PPPoE credentials. |
| `ponwrt-airoha-an7581-znxt_zn504xg-d-initramfs-recovery.itb` | **U-Boot Web Recovery** | For unbricking or initial installation from U-Boot Web recovery mode. |
| `momo-bundle.tar.gz` | **Proxy Bundle (Optional)** | Statically compiled `sing-box` (Go ARM64) and `luci-app-momo` management interface. |

### Checksums (SHA-256)

```text
57d082b69d94b22adbe1d8c9650262617d38a4978bc64c6a80dabb847fbb3f64  ponwrt-airoha-an7581-znxt_zn504xg-d-squashfs-sysupgrade.itb
908e92b6ed13cdf7c36465f8a5ec5a98aa6af9a68218fff5313f229669eda5af  ponwrt-airoha-an7581-znxt_zn504xg-d-initramfs-recovery.itb
f90cd5bb3b03dc7274f72190b9fe07ad8afd0697d5cf124c70045cf64fb4f41a  momo-bundle.tar.gz
```

---

## 🛠️ Flashing & Upgrade Guide

> [!IMPORTANT]
> **FiberHome (FHTT) PON Credentials Safeguard**:
> This device operates using cloned **FiberHome (FHTT / HG5585FV1.0)** credentials to authenticate with the ISP OLT, rather than bare factory defaults.
> Never wipe the device with a clean flash without retaining configuration. Run `/usr/sbin/backup-fiberhome-pon.sh` before upgrading to ensure your cloned FiberHome PON parameters are securely backed up.

### Backup & Restore FiberHome PON Credentials

```bash
# Backup credentials to /etc/fiberhome_pon_backup.uci and protect in sysupgrade.conf
/usr/sbin/backup-fiberhome-pon.sh

# Restore credentials if settings are ever reset
/usr/sbin/restore-fiberhome-pon.sh
```

### Method 1: Non-Destructive SSH Upgrade (Recommended)

To preserve all current configurations (SN, LOID, VLAN 41, PPPoE credentials):

```bash
# 1. Upload sysupgrade image to /tmp on the optical modem
scp -O ponwrt-airoha-an7581-znxt_zn504xg-d-squashfs-sysupgrade.itb root@192.168.1.1:/tmp/sysupgrade.bin

# 2. Verify signature and image validity
ssh root@192.168.1.1 "sysupgrade -T /tmp/sysupgrade.bin"
# Expected response: "Signature check OK"

# 3. Flash while preserving configuration (DO NOT use -n)
ssh root@192.168.1.1 "sysupgrade -v -c /tmp/sysupgrade.bin"
```

The device will write the image and reboot in 1–2 minutes.

### Method 2: LuCI Web Interface

1. Open LuCI Web UI (`http://192.168.1.1`);
2. Navigate to **System -> Backup / Flash Firmware**;
3. Choose `ponwrt-airoha-an7581-znxt_zn504xg-d-squashfs-sysupgrade.itb`;
4. Check **Keep settings** and proceed with the flash.

### Method 3: U-Boot Web Recovery Mode

If the device fails to boot:
1. Power off the device, press and hold the **Reset** button on the back panel, then power on;
2. Hold Reset for 8–10 seconds until the indicator flashes, then release;
3. Connect a LAN cable from your PC to the router, set PC IP to `192.168.1.2 / 255.255.255.0`;
4. Open `http://192.168.1.1` in your browser to enter U-Boot Web interface;
5. Upload `ponwrt-airoha-an7581-znxt_zn504xg-d-initramfs-recovery.itb` to recover.

---

## 🚀 Sing-Box Native `auto-redirect` Configuration

With `nfnetlink_queue` compiled in, Sing-Box handles redirection natively:

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

When started:
```text
INFO[0000] inbound/tun[tun-in]: started at tun0
INFO[0001] inbound/tun[tun-in]: inbound redirect connection from 192.168.1.xxx:xxxxx
```

---

## 🏗️ Build from Source

```bash
# 1. Setup build dependencies
sudo bash -c 'bash <(curl -s https://build-scripts.immortalwrt.org/init_build_environment.sh)'

# 2. Clone repository & install feeds
git clone https://github.com/wuziwei/ponwrt-ZN504.git
cd ponwrt-ZN504
./scripts/feeds update -a
./scripts/feeds install -a

# 3. Configure for AN7581 with NFQUEUE modules
cp configs/an7581.config .config
echo "CONFIG_PACKAGE_kmod-nfnetlink-queue=y" >> .config
echo "CONFIG_PACKAGE_kmod-nft-queue=y" >> .config
echo "CONFIG_PACKAGE_kmod-ipt-nfqueue=y" >> .config
make defconfig

# 4. Compile
make download -j$(nproc)
make -j$(nproc) || make -j1 || make -j1 V=s
```

Outputs are located in `bin/targets/airoha/an7581/`.

---

## ⚠️ Disclaimer

1. This project is for personal learning, testing, and research only.
2. Flashing third-party firmware bears inherent risks. Always back up your calibration and configuration data.
3. Users are responsible for complying with local regulations and carrier policies.

---

## 🙏 Acknowledgments & Credits

This project builds upon the tremendous contributions of the open-source router and networking community. Special thanks and sincere appreciation to the following developers and projects:

### 1. Base System & Core Firmware Architecture
- **[OpenWrt Project](https://github.com/openwrt/openwrt)**: The foundational extensible Linux operating system for embedded devices.
- **[ImmortalWrt](https://github.com/immortalwrt/immortalwrt)**: The highly optimized, feature-rich OpenWrt distribution and ecosystem.
- **[pbs05/ponwrt](https://github.com/pbs05/ponwrt)**: The pioneering open-source PonWrt firmware base and drivers for Airoha AN7581/AN7583 10G PON ONTs.
- **[coolsnowwolf (Lean)](https://github.com/coolsnowwolf/lede)**: For immense contributions to the OpenWrt ecosystem and foundational components like `autocore`.

### 2. Hardware Acceleration & Engineering Benchmarks
- **QWRT Firmware Developers**: For pioneering the Inside Secure SafeXcel EIP-93 dedicated hardware cryptographic engine (`kmod-crypto-hw-eip93`), Airoha PPE flow acceleration, and hardware performance tuning.
- **[Kahen/PonWrt-CI-UBI](https://github.com/Kahen/PonWrt-CI-UBI)**: For the SoC thermal telemetry solution (`temperature-rpc.uc` LuCI RPC integration), MTD read-write partition protection (`kmod-mtd-rw`), and robust CI build engineering.
- **[LeoooChen/PonWRT-TYFZA1](https://github.com/LeoooChen/PonWRT-TYFZA1)**: For XG-PON PPPoE line-rate flow offloading (ultra-low 4.5% CPU usage at 1Gbps), 8MB high-throughput socket buffers, and network optimization.
- **[bingoguo93](https://github.com/bingoguo93)**: For OpenWRT-CI-XG-040G-MD experience and package manifest benchmarks.

### 3. Core Networking, Transparent Proxy & Applications
- **[SagerNet/sing-box](https://github.com/SagerNet/sing-box)**: The universal, high-performance proxy platform.
- **[nikkinikki-org/OpenWrt-momo](https://github.com/nikkinikki-org/OpenWrt-momo)**: The clean, streamlined LuCI transparent proxy management suite for sing-box.
- **[sirpdboy/luci-app-lucky](https://github.com/sirpdboy/luci-app-lucky)** & **[lucky (gdy666)](https://github.com/gdy666/lucky)**: All-in-one port forwarding, DDNS, STUN NAT1, and reverse proxy engine.
- **[rchen14b/luci-app-airoha-npu](https://github.com/rchen14b/luci-app-airoha-npu)**: Web dashboard monitoring AN7581 8-core RISC-V NPU and hardware PPE flow tables.
- **[VIKINGYFY/packages](https://github.com/VIKINGYFY/packages)**: For Gecoos AC controller (`luci-app-gecoosac`) and Wake-on-LAN Ultra (`luci-app-wolultra`).
- **[rozhuk-im/msd_lite](https://github.com/rozhuk-im/msd_lite)**: High-performance, lightweight multicast-to-HTTP proxy for 4K/8K IPTV streaming.

### 4. UI Themes & User Experience
- **[VizzleTF/luci-theme-footstrap](https://github.com/VizzleTF/luci-theme-footstrap)**: Clean and modern responsive theme adapted for PonWrt.
- **[jerrykuku/luci-theme-argon](https://github.com/jerrykuku/luci-theme-argon)**: The classic, elegant Argon theme.
