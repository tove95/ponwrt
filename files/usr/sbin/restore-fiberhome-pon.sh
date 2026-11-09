#!/bin/sh
# ==============================================================================
# 烽火 (FiberHome) PON 认证参数一键恢复脚本
# ==============================================================================

PON_CONF="/etc/config/pon"
BACKUP_FILE="/etc/fiberhome_pon_backup.uci"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "[ERROR] 找不到备份文件 $BACKUP_FILE，无法执行恢复！" >&2
    exit 1
fi

echo "[INFO] 正在从 $BACKUP_FILE 恢复烽火认证参数..."
cp -f "$BACKUP_FILE" "$PON_CONF"
chmod 600 "$PON_CONF"

# 重载 PON 服务
if [ -x /etc/init.d/pon ]; then
    echo "[INFO] 正在重载 PON 服务使烽火认证生效..."
    /etc/init.d/pon restart
fi

echo "[OK] 烽火认证参数已恢复完成，设备正在重新握手 OLT！"
exit 0
