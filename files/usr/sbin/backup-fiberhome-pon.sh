#!/bin/sh
# ==============================================================================
# 烽火 (FiberHome) PON 认证参数自动备份与保护脚本
# 适用于: 兆能 ZN504XG-D (克隆原电信烽火 HG5585F / FHTT 认证上线)
# ==============================================================================

PON_CONF="/etc/config/pon"
BACKUP_FILE="/etc/fiberhome_pon_backup.uci"
INFO_FILE="/etc/fiberhome_pon_info.txt"
SYSUPGRADE_CONF="/etc/sysupgrade.conf"

if [ ! -f "$PON_CONF" ]; then
    echo "[ERROR] 找不到 $PON_CONF，未检测到 PON 配置！" >&2
    exit 1
fi

# 提取关键烽火认证参数
VENDOR=$(uci -q get pon.line0_omci.vendor_id || grep vendor_id "$PON_CONF" | awk -F"'" '{print $2}')
HW_VER=$(uci -q get pon.line0_omci.hardware_version || grep hardware_version "$PON_CONF" | awk -F"'" '{print $2}')
EQ_ID=$(uci -q get pon.line0_omci.equipment_id || grep equipment_id "$PON_CONF" | awk -F"'" '{print $2}')
LOID=$(uci -q get pon.line0_omci.loid || grep loid "$PON_CONF" | awk -F"'" '{print $2}')
SN=$(uci -q get pon.line0.serial_number || grep serial_number "$PON_CONF" | awk -F"'" '{print $2}')
MODE=$(uci -q get pon.line0.mode || grep mode "$PON_CONF" | awk -F"'" '{print $2}')

echo "=================================================="
echo "  正在备份烽火 (FiberHome) PON 关键认证参数..."
echo "=================================================="
echo "  厂商代码 (Vendor ID)  : ${VENDOR:-FHTT}"
echo "  硬件型号 (HW Version) : ${HW_VER:-HG5585FV1.0}"
echo "  设备标识 (Equipment ID): ${EQ_ID:-HS8145X6}"
echo "  宽带 LOID             : ${LOID}"
echo "  PON 序列号 (SN)       : ${SN}"
echo "  链路制式 (PON Mode)   : ${MODE:-xgpon}"
echo "=================================================="

# 备份完整配置文件
cp -f "$PON_CONF" "$BACKUP_FILE"
chmod 600 "$BACKUP_FILE"

# 生成人类可读的认证档案备忘录
cat << INFO > "$INFO_FILE"
# 烽火 (FiberHome) PON 认证档案备忘录
# 导出时间: $(date '+%Y-%m-%d %H:%M:%S')
VENDOR_ID=${VENDOR}
HARDWARE_VERSION=${HW_VER}
EQUIPMENT_ID=${EQ_ID}
LOID=${LOID}
SERIAL_NUMBER=${SN}
PON_MODE=${MODE}
BACKUP_SHA256=$(sha256sum "$BACKUP_FILE" | awk '{print $1}')
INFO

# 将烽火配置文件写入 sysupgrade.conf，防止固件升级被刷除
for path in "$PON_CONF" "$BACKUP_FILE" "$INFO_FILE" "/usr/sbin/backup-fiberhome-pon.sh" "/usr/sbin/restore-fiberhome-pon.sh"; do
    if ! grep -q "^$path" "$SYSUPGRADE_CONF" 2>/dev/null; then
        echo "$path" >> "$SYSUPGRADE_CONF"
    fi
done

echo "[OK] 烽火认证参数备份成功："
echo "     - 配置文件备份: $BACKUP_FILE"
echo "     - 备忘明细记录: $INFO_FILE"
echo "     - 已加入 $SYSUPGRADE_CONF (固件升级不丢失)"
echo "=================================================="
exit 0
