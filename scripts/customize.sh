#!/usr/bin/env bash
set -euo pipefail

# PonWrt-ZN504 custom package build preparation script
echo "=== [PonWrt-ZN504] Preparing build dependencies and custom packages ==="

# 1. 确保 luci-app-airoha-npu 处于可用状态
if [ -d "./package/luci-app-airoha-npu" ]; then
    echo "[OK] luci-app-airoha-npu is present"
fi

# 2. 确保 lucky 与 luci-app-lucky 处于可用状态
if [ -d "./package/luci-app-lucky" ] && [ -d "./package/lucky" ]; then
    echo "[OK] lucky and luci-app-lucky are present"
fi

echo "=== [PonWrt-ZN504] Build preparation complete ==="
