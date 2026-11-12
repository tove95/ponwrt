#!/usr/bin/env bash
set -euo pipefail

# PonWrt-ZN504 Custom Package & Architecture Integration Script
# Integrates:
# - QWRT Recommended: Airoha PPE / EIP-93, CPUFreq, RAMFree, Diskman, TTYD, FileTransfer
# - QWRT Optional: Samba4, GecoosAC, WOL Ultra
# - Kahen Essence: Temperature RPC (/sbin/tempinfo), Footstrap Theme, Clean Feeds
# - LeoooChen Essence: Line-rate PPPoE / XG-PON offload & High Throughput Buffers
# - Momo & Sing-Box: OpenWrt-momo with Chinese Translation and 128MB Memory Limit

echo "=== [PonWrt-ZN504] Preparing build dependencies and custom packages ==="

# 1. 确保 luci-app-airoha-npu (NPU/PPE SoC 状态监控) 处于可用状态
if [ ! -d "./package/luci-app-airoha-npu" ]; then
    echo "--> Cloning luci-app-airoha-npu..."
    git clone --depth 1 https://github.com/rchen14b/luci-app-airoha-npu.git ./package/luci-app-airoha-npu
else
    echo "[OK] luci-app-airoha-npu is present"
fi

# 2. 确保 nikkinikki OpenWrt-momo (Momo + sing-box 核心) 处于可用状态
if [ ! -d "./package/luci-app-momo" ]; then
    echo "--> Cloning OpenWrt-momo..."
    git clone --depth 1 https://github.com/nikkinikki-org/OpenWrt-momo.git ./package/luci-app-momo
else
    echo "[OK] luci-app-momo is present"
fi

# 3. 集成 Kahen 精华：luci-theme-footstrap (轻量响应式主题)
if [ ! -d "./package/luci-theme-footstrap" ]; then
    echo "--> Importing luci-theme-footstrap..."
    tmp_theme="$(mktemp -d)"
    git clone --depth 1 https://github.com/VizzleTF/luci-theme-footstrap.git "$tmp_theme/footstrap"
    if [ -d "$tmp_theme/footstrap/luci-theme-footstrap" ]; then
        cp -a "$tmp_theme/footstrap/luci-theme-footstrap" ./package/luci-theme-footstrap
    elif [ -f "$tmp_theme/footstrap/Makefile" ]; then
        cp -a "$tmp_theme/footstrap" ./package/luci-theme-footstrap
    fi
    rm -rf "$tmp_theme"
fi

# 4. 集成 Kahen 精华：自动连接 autocore 温度检测至 LuCI 状态界面
if [ -f "./scripts/integrate-temperature.py" ]; then
    echo "--> Running temperature integration..."
    python3 ./scripts/integrate-temperature.py . || true
fi

# 5. 集成 NNdroid 关键优化：EN7572 激光冷启动防抖 & LOID 补零方向与原始报文字节展示
TOP_DIR="$(pwd)"
if [ -d "./feeds/pon_drivers" ] && [ -f "$TOP_DIR/patches/01-pon-drivers-epon-laser-recovery.patch" ]; then
    echo "--> Applying EN7572 burst laser latch recovery patch to pon_drivers..."
    (cd feeds/pon_drivers && git apply --check "$TOP_DIR/patches/01-pon-drivers-epon-laser-recovery.patch" 2>/dev/null && git apply "$TOP_DIR/patches/01-pon-drivers-epon-laser-recovery.patch") || true
    ./scripts/feeds install -p pon_drivers -f || true
fi

if [ -d "./feeds/pon_userspace" ] && [ -f "$TOP_DIR/patches/02-pon-userspace-loid-padding-wire-view.patch" ]; then
    echo "--> Applying LOID padding & wire byte preview patch to pon_userspace..."
    (cd feeds/pon_userspace && git apply --check "$TOP_DIR/patches/02-pon-userspace-loid-padding-wire-view.patch" 2>/dev/null && git apply "$TOP_DIR/patches/02-pon-userspace-loid-padding-wire-view.patch") || true
    ./scripts/feeds install -p pon_userspace -f || true
fi

# 6. 升级 sing-box 核心至 1.15.0-alpha.13（支持 endpoints[].on_demand 等 1.15+ 新版配置语法）
# OpenWrt APK v3 禁止 PKG_VERSION 包含 '-'，因此包版本使用 1.15.0_alpha13，源码与二进制版本号保留 1.15.0-alpha.13
SING_BOX_MK="./feeds/packages/net/sing-box/Makefile"
if [ -f "$SING_BOX_MK" ] && ! grep -q "PKG_UPSTREAM_VERSION:=1.15.0-alpha.13" "$SING_BOX_MK"; then
    echo "--> Updating sing-box to 1.15.0-alpha.13..."
    python3 - "$SING_BOX_MK" <<'PYEOF'
import re, sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    src = f.read()

target_pkg_ver = "1.15.0_alpha13"
target_upstream = "1.15.0-alpha.13"
target_hash = "29047987ed69ba790f2ae4eec62abf41bd1619d093af071f505b4ba081e06b44"

src, n1 = re.subn(
    r"^PKG_VERSION:=.*$",
    f"PKG_VERSION:={target_pkg_ver}\nPKG_UPSTREAM_VERSION:={target_upstream}",
    src, count=1, flags=re.M,
)
src, n2 = re.subn(r"^PKG_RELEASE:=.*$", "PKG_RELEASE:=1", src, count=1, flags=re.M)
src, n3 = re.subn(
    r"^PKG_SOURCE:=.*$",
    "PKG_SOURCE:=$(PKG_NAME)-$(PKG_UPSTREAM_VERSION).tar.gz",
    src, count=1, flags=re.M,
)
src, n4 = re.subn(
    r"^PKG_SOURCE_URL:=.*$",
    "PKG_SOURCE_URL:=https://codeload.github.com/SagerNet/sing-box/tar.gz/v$(PKG_UPSTREAM_VERSION)?",
    src, count=1, flags=re.M,
)
src, n5 = re.subn(
    r"^PKG_HASH:=.*$",
    f"PKG_HASH:={target_hash}\nPKG_BUILD_DIR:=$(BUILD_DIR)/$(if $(BUILD_VARIANT),$(PKG_NAME)-$(BUILD_VARIANT)/)$(PKG_NAME)-$(PKG_UPSTREAM_VERSION)",
    src, count=1, flags=re.M,
)
src = src.replace("constant.Version=$(PKG_VERSION)", "constant.Version=$(PKG_UPSTREAM_VERSION)")

assert all(n == 1 for n in (n1, n2, n3, n4, n5)), f"Unexpected sing-box Makefile layout: {(n1, n2, n3, n4, n5)}"
with open(path, "w", encoding="utf-8") as f:
    f.write(src)
PYEOF
    rm -f ./tmp/.packageinfo ./tmp/.config-package.in 2>/dev/null || true
fi

# 7. 规避 Airoha 架构下非必要 feed 循环依赖 (如无用的 squeezelite 音频)
if [ -L "./package/feeds/packages/squeezelite" ]; then
    rm -f "./package/feeds/packages/squeezelite"
fi

echo "=== [PonWrt-ZN504] Build preparation complete ==="
