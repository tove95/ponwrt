# PonWrt 6.18 for ZN504XG-D & HG5585F (Airoha AN7581)

[简体中文](README.md) | English

[![GitHub Actions Build Status](https://img.shields.io/github/actions/workflow/status/wuziwei/ponwrt-ZN504/build-zn504.yml?branch=master&style=flat-square&logo=github)](https://github.com/wuziwei/ponwrt-ZN504/actions)
[![Latest Release](https://img.shields.io/github/v/release/wuziwei/ponwrt-ZN504?style=flat-square&logo=github)](https://github.com/wuziwei/ponwrt-ZN504/releases)
[![Target](https://img.shields.io/badge/SoC-Airoha%20AN7581-blue?style=flat-square)](https://github.com/wuziwei/ponwrt-ZN504)
[![Device](https://img.shields.io/badge/Device-ZN504%20%26%20HG5585F-green?style=flat-square)](https://github.com/wuziwei/ponwrt-ZN504)
[![Kernel](https://img.shields.io/badge/Kernel-Linux%206.18-informational?style=flat-square)](https://github.com/wuziwei/ponwrt-ZN504)
[![License](https://img.shields.io/badge/License-GPL--2.0-orange?style=flat-square)](LICENSE)

Customized and performance-enhanced [PonWrt](https://github.com/pbs05/ponwrt) (based on [ImmortalWrt](https://github.com/immortalwrt/immortalwrt) / Linux `6.18`) firmware engineered for dual flagship Airoha AN7581 optical gateways:
* **ZN504XG-D (`znxt_zn504xg-d`)**: Pure wired 2.5G high-performance ONT (EN8811H 2.5G port + 3×GbE)
* **FiberHome HG5585F (`fiberhome_hg5585f-ct` / `fiberhome_hg5585f-cu`)**: Wi-Fi 6 ONT (Airoha AN7581 + MT7916D DBDC AX3000 + NPU WED hardware acceleration)

Every release automatically compiles and packages **both devices** into separate flashable images!

---

## 🌟 Key Features & Architectural Enhancements

### 1. FiberHome HG5585F MT7916 Wi-Fi 6 & NPU WED Offload Integration
- **MT7916D DBDC Dual-Band Wireless**: Integrated `kmod-mt7915e` driver and `kmod-mt7916-firmware`, delivering 2.4G 2x2 + 5G 3x3 AX3000 Wi-Fi 6 concurrency.
- **Airoha NPU / WED Hardware Offload**: Bundled `en7581_MT7916_npu_rv32.bin` and `en7581_MT7916_npu_data.bin`. The 8-core RISC-V NPU directly routes wireless RX DMA and WED TX frames for zero-CPU line-rate throughput.
- **Automated Factory EEPROM Extraction**: Integrated `/etc/hotplug.d/firmware/10-mt7916-an-eeprom` and `/etc/init.d/mt7916-an-eeprom` (executed at `START=08` prior to driver probing). Extracts the 4KB calibration block from UBI `factory` offset `0x1000` and validates the `0x7916` magic bytes.
- **Preinit Wireless MAC Calculation**: Embedded `/lib/preinit/07_an7581_bsp_wifi_mac` automatically reads the base MAC and assigns 2.4G (`base + 6`) and 5G (`base + 7`) hardware addresses.
- **RF Power Tables**: Integrated `SingleSKU` and `mt7916-sku.dat` beamforming data.
- **Async Wi-Fi Scan Protection**: Integrated `rpcd` async scanning patch (`133-rpcd-async-scan.patch`), decoupling wireless discovery from the main event loop to prevent LuCI Web UI stalls or 504 timeouts during channel surveys.

### 2. Full-Stack Airoha AN7581 Native PON Drivers & OLT Hardening
- Integrated `kmod-airoha-xpon`, `kmod-airoha-en7572` (BOSA), `kmod-phy-airoha-en8811h` (2.5G PHY), and `airoha-en7581-npu-firmware` (NPU hardware offload).
- Integrated `airoha-pond`, `airoha-ponctl`, and `luci-app-pon`.
- Supports GPON / XG-PON / XGS-PON **O5 operational state** registration and verification, with full configuration of Vendor ID (e.g., `FHTT`), Equipment ID (e.g., `HS8145X6 (PON ONT)`), PON SN, LOID, password, cloned MAC, and BOSA calibration volume preservation.
- **EN7572 Cold-Start Laser Latch Stabilization**: Integrated 8-consecutive-sample confirmation (140ms settling window) to prevent premature `SYS_TX_READY` reports before the laser stabilizes, eliminating cold-start registration drops.
- **Enhanced OLT (Huawei/ZTE) Troubleshooting & Compatibility**:
  - **Configurable LOID Padding Alignment**: Web UI support for Left vs Right 0x00 padding in the 24-byte LOID field, fixing `reason=0x01` authentication rejects on specific Huawei OLTs;
  - **Live Wire Bytes Inspection**: Real-time hex and printable ASCII display of raw frame attributes (`CTC ONU SN` and `LOID sent in authentication`) directly in LuCI Status;
  - **Web-based PON MAC Override**: Instant PON interface MAC cloning from the web management interface.
- **Clean Network Generation**: Prevents redundant `wan6` DHCPv6 interface creation on DHCP networks to avoid dual-stack route competition.
- Live telemetry for Rx/Tx optical power, operating voltage, and SoC temperature.

### 3. Airoha 8-Core NPU / PPE Hardware Flow Offloading (Fastpath)
- Hardware PPE flow offloading (`flow_offloading='1'`, `flow_offloading_hw='1'`) enabled by default. Full line-rate Gigabit and 2.5G throughput reduces quad-core A53 CPU utilization to ~**4.5%**.
- Backported QWRT memory anti-fragmentation optimization (`vm.percpu_pagelist_high_fraction = 128`), preventing high-concurrency page allocation stalls.
- LAN Multicast Bypass (`NOTRACK`): UPnP SSDP (`239.255.255.250:1900`) and Windows WSD (`3702`) bypass conntrack, preventing table exhaustion.
- 16MB TCP socket read/write buffers (`rmem_max` / `wmem_max = 16M`), eliminating long-fat network bottlenecks for 4K streaming.
- Dynamic 1.2GHz full-frequency scaling (500MHz idle efficiency, 1.2GHz instant boost).

### 4. Kernel Netfilter NFQUEUE Integration (Native Sing-Box `auto-redirect`)
- Compiled and integrated `kmod-nfnetlink-queue`, `kmod-nft-queue`, and `kmod-ipt-nfqueue`.
- Completely solves the crash when enabling `auto_redirect: true` in Sing-Box / Momo on stock PonWrt:
  > `FATAL[0000] start nfqueue: could not unbind existing handlers: netlink receive: invalid argument (-EINVAL)`
- Enables native transparent proxy redirection via Sing-Box TUN mode without requiring complex custom nftables scripting.
- Optimized for Momo (`core_only='1'`), lifting the default 60MiB hard-coded memory restriction to `128MiB` with direct bypass routing for multicast `224.0.0.0/4` and `239.0.0.0/8`.

### 5. SafeXcel EIP-93 Dedicated Hardware Crypto Acceleration
- Solves high CPU temperatures and cryptographic bottlenecks on ARM Cortex-A53 cores lacking native ARMv8 Crypto Extensions.
- Activates on-chip **Inside Secure SafeXcel EIP-93 hardware engine (`kmod-crypto-hw-eip93`)** at base `0x1fb70000`.
- Integrated `kmod-cryptodev` (`/dev/crypto`) and OpenSSL devcrypto engine (`libopenssl-devcrypto`), offloading AES, DES/3DES, and SHA/HMAC calculations to dedicated silicon.

### 6. Dual-Stack 4K/8K IPTV Multicast Engine
- **PON Layer**: Bind carrier IPTV and multicast VLANs directly during bridging or dial-up.
- **Application Layer**: Integrated `msd_lite` (port 4022, 8MB ring buffer + 4 threads) and 8MB UDP buffer tuning to eliminate 4K/8K multicast frame drops.
- **Dynamic Playlist**: Bundled with Guangdong Shenzhen Telecom `/www/iptv.m3u`, automatically updated with gateway IP via hotplug script.

### 7. Cloudflare DDNS & Full-Featured DNSMASQ
- **Cloudflare DDNS**: Integrated `ddns-scripts-cloudflare` for dual-stack IPv4/IPv6 automated dynamic DNS resolution.
- **Full-featured DNS (`dnsmasq-full`)**: Native support for `ipset`, `nftset`, and DNSSEC, providing a solid foundation for transparent routing.

### 8. FiberHome PON Protection & One-Click Backup
- Scripts `/usr/sbin/backup-fiberhome-pon.sh` and `/usr/sbin/restore-fiberhome-pon.sh` for one-click verification and backup of `FHTT`, `HG5585FV1.0`, LOID, and PON SN.
- Automatically maintains `/etc/sysupgrade.conf` so credentials survive across clean system flashes.

### 9. Modern Web Interface & Telemetry
- **Vantage Console Theme & Real-time Flow**: Visualizes wired and wireless ports with dynamic bezier particle flow.
- **Kahen SoC & BOSA Thermal Telemetry**: Live temperature readings via `temperature-rpc.uc` and `/sbin/tempinfo` RPC integration.
- **Web Terminal (`luci-app-ttyd`)**: Direct browser-based SSH access.

---

## 📦 Firmware Downloads (Releases)

Download production-tested images from [GitHub Releases](https://github.com/wuziwei/ponwrt-ZN504/releases):

| Target Device | Firmware Filename | Usage |
| :--- | :--- | :--- |
| **ZN504XG-D** | `ponwrt-airoha-an7581-znxt_zn504xg-d-squashfs-sysupgrade.itb` | **Standard Sysupgrade (Recommended)**, preserves settings |
| **ZN504XG-D** | `ponwrt-airoha-an7581-znxt_zn504xg-d-initramfs-recovery.itb` | **U-Boot Web Recovery / Unbrick** |
| **HG5585F (CT Telecom)** | `ponwrt-airoha-an7581-fiberhome_hg5585f-ct-squashfs-sysupgrade.itb` | **Standard Sysupgrade (Recommended)**, includes MT7916 Wi-Fi |
| **HG5585F (CT Telecom)** | `ponwrt-airoha-an7581-fiberhome_hg5585f-ct-initramfs-recovery.itb` | **U-Boot Web Recovery / Unbrick** |
| **HG5585F (CU Unicom)** | `ponwrt-airoha-an7581-fiberhome_hg5585f-cu-squashfs-sysupgrade.itb` | **Standard Sysupgrade (Recommended)**, includes MT7916 Wi-Fi |
| **HG5585F (CU Unicom)** | `ponwrt-airoha-an7581-fiberhome_hg5585f-cu-initramfs-recovery.itb` | **U-Boot Web Recovery / Unbrick** |

---

## 🛠️ Flashing & Upgrade Guide

> [!IMPORTANT]
> **Credential Preservation Warning**:
> Operating on carrier networks typically requires cloned FiberHome (`FHTT`) parameters.
> Always upgrade using configuration retention or run `/usr/sbin/backup-fiberhome-pon.sh` before upgrading!

### Method 1: SSH CLI Flashing (Recommended)

```bash
# 1. Upload the image to /tmp
scp -O <firmware-name>-squashfs-sysupgrade.itb root@192.168.1.1:/tmp/sysupgrade.bin

# 2. Verify signature and image integrity
ssh root@192.168.1.1 "sysupgrade -T /tmp/sysupgrade.bin"

# 3. Flash while preserving configuration (do NOT use -n)
ssh root@192.168.1.1 "sysupgrade -v -c /tmp/sysupgrade.bin"
```

The device will write the image and reboot in 1–2 minutes.

### Method 2: LuCI Web Upgrade

1. Navigate to `http://192.168.1.1` in your browser.
2. Go to **System -> Backup / Flash Firmware**.
3. Select your device's `squashfs-sysupgrade.itb` image.
4. Ensure **Keep settings** is checked, then upload and confirm.

### Method 3: U-Boot Web Recovery

If the device fails to boot:
1. Disconnect power, hold down the **Reset button**, and reconnect power.
2. Continue holding Reset for 8–10 seconds until LEDs flash, then release.
3. Connect your PC to a LAN port, configure static IP `192.168.1.2` / `255.255.255.0`.
4. Open `http://192.168.1.1` in your browser to access the recovery web UI.
5. Upload the corresponding `initramfs-recovery.itb` image to restore.

---

## 📖 ZN504XG-D PON Provisioning & OLT Registration Guide (Field Lessons)

Replacing stock carrier optical modems (e.g. Huawei HS8145X6, FiberHome HG5585F) with the **ZN504XG-D** (Airoha AN7581) to unlock 2.5G full-rate connectivity is a primary use case.

Many users encounter issues such as **cyclic O1–O5 state drops**, **instant OLT deactivations**, or **PPPoE PADI timeouts**. Below is the verified end-to-end registration procedure and hard-learned troubleshooting lessons.

### 1. Essential Parameters to Extract from Stock Modem

Before disconnecting your original optical modem, record the following credentials:

| Parameter | Description | Example (Telecom) |
| :--- | :--- | :--- |
| **PON SN** | 16-character PON Serial Number (first 4 characters are vendor ASCII, last 8 are hex) | `48575443XXXXXXXX` (`HWTC` Huawei) |
| **Broadband LOID** | Logic ID for telecom authentication | Phone number or `SZ10000XXXXXX` (leave password blank if none) |
| **Vendor & Model** | Vendor ID code and equipment hardware version | Vendor: `HWTC` or `FHTT`, Model: `HS8145X6` or `HG5585FV1.0` |
| **Internet VLAN ID** | 802.1q VLAN Tag bound to Internet service | Often `41`, `43`, or `46` (multicast/IPTV typically `45`) |
| **PPPoE Credentials** | Broadband dial-up username and password | `0755XXXXXXXX@163.gd` |

---

### 2. ZN504 Configuration Mapping

In LuCI (`http://192.168.1.1`), navigate to **Network -> PON Settings**:

#### ① Physical Link (Line 0)
- **Device**: `pon0`
- **Mode**: **`xgpon`** (standard for 10G PON Telecom connections; use `gpon` for Gigabit GPON, or `epon` for 10G-EPON)
- **Serial Number**: 16-character hex SN from original modem (e.g. `48575443XXXXXXXX`)

#### ② OMCI Protocol Identification (Line 0 OMCI)
- **Vendor ID**: **`FHTT`** (⚠️ See Lesson 1 below — recommended even if original modem was Huawei)
- **Equipment ID**: **`HS8145X6 (PON ONT)`** (⚠️ See Lesson 2 below — parentheses are mandatory)
- **Hardware Version**: `HG5585FV1.0`
- **Software Version**: `RP0100`
- **LOID**: Your broadband LOID (e.g. `SZXXXXXXXXX`)
- **Operator ID**: `CTC` (China Telecom)

#### Underlying Configuration (`/etc/config/pon`):
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

### 3. ⚠️ Critical Field Lessons & Common Pitfalls

#### 🛑 Pitfall 1: Never report `HWTC` when upstream OLT is Huawei!
* **Symptom**: The modem momentarily enters O5 state, but within **100 milliseconds** the upstream Huawei OLT issues a `Deactivate_ONU-ID` command (msg-id `0x05`), falling into an endless `O1 -> O2 -> O4 -> O5 -> O2` reconnect loop.
* **Root Cause**: When an ONU reports `HWTC` (Huawei vendor code), Huawei OLTs enforce proprietary Huawei-only handshakes (bombarding OMCI ME Class 350 firmware image checks and Class 373 hardware fingerprinting). Because open-source PonWrt lacks Huawei proprietary closed-source response handlers, the OLT classifies the device as an illegitimate clone and terminates it.
* **Solution**: Change `vendor_id` to **`FHTT` (FiberHome)**. Carrier OLTs are required to support third-party hardware. Reporting `FHTT` prompts the Huawei OLT to abandon proprietary checks and gracefully fall back to standard ITU-T G.988 / China Telecom CTC specifications, smoothly registering via LOID.

#### 🛑 Pitfall 2: Equipment ID must include `(PON ONT)` suffix
* **Symptom**: Link enters O5, but the OLT refuses to provision GEM Ports / data channels.
* **Solution**: The ITMS / OLT equipment database requires the full string: **`HS8145X6 (PON ONT)`** (including space and parentheses).

#### 🛑 Pitfall 3: PPPoE must bind to the VLAN interface (`pon0.41`)
* **Symptom**: O5 state is stable, but WAN PPPoE discovery fails with continuous PADI timeouts.
* **Root Cause**: Carrier broadband frames are encapsulated with 802.1q VLAN tags. Dialing directly on raw `pon0` discards or ignores these tags.
* **Solution**: In **Network -> Interfaces**, bind WAN to **`pon0.41`** (or create an 802.1q device for your local VLAN).

#### 🛑 Pitfall 4: Carrier Session Lockout (`check user-name in black list`)
* **Symptom**: PPPoE handshake succeeds, but authentication fails with:
  > `Remote message: 28103012: check user-name in black list. failed!`
* **Solution**: Disconnecting without logging out leaves an active session on the BRAS. Wait 3–5 minutes with the fiber disconnected to allow stale sessions to expire.

#### 🛑 Pitfall 5: Configuration Loss Across System Upgrades
* **Symptom**: Losing `/etc/config/pon` after a clean firmware flash leaves the device disconnected.
* **Solution**: Run `/usr/sbin/backup-fiberhome-pon.sh` once. It archives your credentials to `/etc/fiberhome_pon_backup.uci` and adds them to `/etc/sysupgrade.conf`. Use `/usr/sbin/restore-fiberhome-pon.sh` for one-click restoration if ever needed.

---

### 4. Verification & O5 Diagnostic Indicators

Run the following command to verify registration status:

```bash
pondctl status --line line0
```

**✅ Expected Output for Healthy Registration**:
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
* `authentication_meaning`: `"accepted"` confirms valid credential verification.
* `backend_state`: `"applied"` confirms provisioned GEM Port and T-CONT data paths.
* `vlan_ids`: Includes your local Internet (`41`) and IPTV (`45`) tags.

---

## 🚀 Sing-Box Native `auto-redirect` Configuration

With `nfnetlink_queue` compiled in, Sing-Box handles redirection natively:

### Inbound Configuration:

Per [Sing-Box documentation](https://deepwiki.com/SagerNet/sing-box), `auto_redirect` requires `auto_route: true`:

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

---

## 🏗️ Building From Source

```bash
# 1. Clone repository & update feeds
git clone https://github.com/wuziwei/ponwrt-ZN504.git
cd ponwrt-ZN504
./scripts/feeds update -a && ./scripts/feeds install -a

# 2. Apply AN7581 enhanced configuration
./scripts/kconfig.pl + configs/an7581.config configs/release.config > .config
make defconfig

# 3. Compile
make download -j$(nproc)
make -j$(nproc) || make -j1 || make -j1 V=s
```

Outputs are generated under `bin/targets/airoha/an7581/`.

---

## ⚠️ Disclaimer

1. This project is provided for technical exchange and networking research purposes.
2. Upgrading firmware carries inherent risks. Always backup your carrier credentials with `backup-fiberhome-pon.sh` before proceeding.
3. Observe all local telecommunication laws and regulations.

---

## 🙏 Acknowledgments & References

- **[OpenWrt Project](https://github.com/openwrt/openwrt)**: Foundation for embedded networking OS.
- **[ImmortalWrt](https://github.com/immortalwrt/immortalwrt)**: Highly optimized upstream distribution.
- **[pbs05/ponwrt](https://github.com/pbs05/ponwrt)**: Foundational Airoha AN7581/AN7583 PonWrt source tree.
- **QWRT Team**: Insights on SafeXcel EIP-93 crypto, PPE flow offloading, and NPU WED Wi-Fi acceleration.
- **[NNdroid](https://github.com/NNdroid)**: For EN7572 laser latch stabilization, LOID padding alignment, and CTC raw wire byte inspection tools.
- **[Kahen/PonWrt-CI-UBI](https://github.com/Kahen/PonWrt-CI-UBI)**: Precise SoC thermal telemetry (`temperature-rpc.uc`) and MTD read-write protection (`kmod-mtd-rw`).
- **[LeoooChen/PonWRT-TYFZA1](https://github.com/LeoooChen/PonWRT-TYFZA1)**: Line-rate PPPoE & XG-PON offload practices and `rpcd` async Wi-Fi scanning.
- **[oenhu](https://github.com/oenhu)**: For PR #116 preventing redundant DHCPv6 `wan6` interfaces on DHCP networks.
- **[SagerNet/sing-box](https://github.com/SagerNet/sing-box)**: Next-generation proxy engine.
- **[nikkinikki-org/OpenWrt-momo](https://github.com/nikkinikki-org/OpenWrt-momo)**: Streamlined sing-box WebUI and transparent gateway integration.
- **[rchen14b/luci-app-airoha-npu](https://github.com/rchen14b/luci-app-airoha-npu)**: Airoha AN7581 8-core NPU & PPE telemetry dashboard.
- **[rozhuk-im/msd_lite](https://github.com/rozhuk-im/msd_lite)**: Ultra-lightweight high-throughput IPTV proxy.
- **[VizzleTF/luci-theme-footstrap](https://github.com/VizzleTF/luci-theme-footstrap)**: Modern responsive theme for PonWrt.
