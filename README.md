# PonWrt for 兆能 ZN504XG-D (Airoha AN7581)

English | [简体中文](README_zh.md)

[![GitHub Actions Build Status](https://img.shields.io/github/actions/workflow/status/wuziwei/ponwrt-ZN504/build-zn504.yml?branch=master&style=flat-square&logo=github)](https://github.com/wuziwei/ponwrt-ZN504/actions)
[![Latest Release](https://img.shields.io/github/v/release/wuziwei/ponwrt-ZN504?style=flat-square&logo=github)](https://github.com/wuziwei/ponwrt-ZN504/releases)
[![Target](https://img.shields.io/badge/SoC-Airoha%20AN7581-blue?style=flat-square)](https://github.com/wuziwei/ponwrt-ZN504)
[![Device](https://img.shields.io/badge/Device-ZNXT%20ZN504XG--D-green?style=flat-square)](https://github.com/wuziwei/ponwrt-ZN504)
[![License](https://img.shields.io/badge/License-GPL--2.0-orange?style=flat-square)](LICENSE)

This repository provides customized and enhanced [PonWrt](https://github.com/pbs05/ponwrt) (based on [ImmortalWrt](https://github.com/immortalwrt/immortalwrt)) firmware specifically tuned for the **ZNXT (兆能) ZN504XG-D** optical network terminal (ONT), powered by the Airoha AN7581 quad-core ARM64 SoC.

---

## 🌟 Key Features & Improvements

- 🚀 **Integrated Kernel NFQUEUE Drivers (Fixes Sing-Box `auto-redirect`)**:
  - Pre-compiled and integrated `kmod-nfnetlink-queue`, `kmod-nft-queue`, and `kmod-ipt-nfqueue`.
  - Fixes the crash when enabling `auto_redirect: true` in Sing-Box / Momo on stock PonWrt:
    > `FATAL[0000] start nfqueue: could not unbind existing handlers: netlink receive: invalid argument (-EINVAL)`
  - Enables zero-configuration transparent proxying via Sing-Box TUN mode without requiring fragile custom nftables scripting.
- 🌐 **Comprehensive PON Link & O5 Registration**:
  - Full LuCI diagnostics integration (`luci-app-pon` and `airoha-pon-debug`).
  - Web & CLI support for modifying Vendor ID (e.g., `FHTT`), Equipment ID (e.g., `HS8145X6 (PON ONT)`), PON SN, LOID, cloned MAC, and VLAN binding.
  - Verified stable **O5 operational state** on live XG-PON lines with real-time optical power, temperature, and voltage telemetry.
- ⚡ **Wire-Speed Line Rate Routing**:
  - Linux 6.18 kernel on ARM64 Cortex-A53 quad-core architecture with hardware offload for PPPoE, IPv4, and IPv6 traffic.
- 🔄 **Automated GitHub Actions CI/CD**:
  - Includes ready-to-run GitHub Actions workflows to compile and package custom firmware in the cloud.

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
```

---

## 🛠️ Flashing & Upgrade Guide

> [!IMPORTANT]
> Always backup your original flash partitions (especially `factory` / `reservearea` identity data) before flashing.

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
