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

# 2. 确保 lucky 与 luci-app-lucky 处于可用状态
if [ ! -d "./package/luci-app-lucky" ] || [ ! -d "./package/lucky" ]; then
    echo "--> Cloning luci-app-lucky & lucky..."
    rm -rf ./package/luci-app-lucky ./package/lucky
    git clone --depth 1 https://github.com/sirpdboy/luci-app-lucky.git ./package/luci-app-lucky
else
    echo "[OK] lucky and luci-app-lucky are present"
fi

# 3. 确保 nikkinikki OpenWrt-momo (Momo + sing-box 核心) 处于可用状态
if [ ! -d "./package/luci-app-momo" ]; then
    echo "--> Cloning OpenWrt-momo..."
    git clone --depth 1 https://github.com/nikkinikki-org/OpenWrt-momo.git ./package/luci-app-momo
else
    echo "[OK] luci-app-momo is present"
fi

# 4. 集成 Kahen 精华：luci-theme-footstrap (轻量响应式主题)
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

# 5. 集成 QWRT/Kahen 精选：GecoosAC (集客无线AC控制器) 与 WOL Ultra (高级网络唤醒)
if [ ! -d "./package/viking-packages" ]; then
    echo "--> Importing GecoosAC and WOL Ultra..."
    tmp_viking="$(mktemp -d)"
    git clone --depth 1 --filter=blob:none --sparse https://github.com/VIKINGYFY/packages.git "$tmp_viking/packages" 2>/dev/null || true
    if [ -d "$tmp_viking/packages" ]; then
        git -C "$tmp_viking/packages" sparse-checkout set gecoosac luci-app-gecoosac luci-app-wolultra 2>/dev/null || true
        mkdir -p ./package/viking-packages
        for pkg in gecoosac luci-app-gecoosac luci-app-wolultra; do
            [ -d "$tmp_viking/packages/$pkg" ] && cp -a "$tmp_viking/packages/$pkg" "./package/viking-packages/"
        done
    fi
    rm -rf "$tmp_viking"
fi

# 6. 集成 Kahen 精华：自动连接 autocore 温度检测至 LuCI 状态界面
if [ -f "./scripts/integrate-temperature.py" ]; then
    echo "--> Running temperature integration..."
    python3 ./scripts/integrate-temperature.py . || true
fi

# 7. 规避 Airoha 架构下非必要 feed 循环依赖 (如无用的 squeezelite 音频)
if [ -L "./package/feeds/packages/squeezelite" ]; then
    rm -f "./package/feeds/packages/squeezelite"
fi

echo "=== [PonWrt-ZN504] Build preparation complete ==="
