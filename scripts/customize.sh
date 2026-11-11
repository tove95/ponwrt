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

# 6. 规避 Airoha 架构下非必要 feed 循环依赖 (如无用的 squeezelite 音频)
if [ -L "./package/feeds/packages/squeezelite" ]; then
    rm -f "./package/feeds/packages/squeezelite"
fi

echo "=== [PonWrt-ZN504] Build preparation complete ==="
