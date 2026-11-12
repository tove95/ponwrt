#!/bin/sh
# 精确匹配内核线程 comm，将 mt76-tx 与 6 个 napi/phy0-0 线程打散到 4 个核心
idx=0
for pid in $(ls /proc | grep '^[0-9]*$' | sort -n); do
    [ -r "/proc/$pid/comm" ] || continue
    read -r cname < "/proc/$pid/comm" 2>/dev/null || continue
    case "$cname" in
        mt76-tx*)
            taskset -p 8 "$pid" >/dev/null 2>&1
            ;;
        napi/phy0-0)
            case $((idx % 6)) in
                0|1|2) mask=1 ;;
                3)     mask=2 ;;
                4|5)   mask=4 ;;
            esac
            taskset -p "$mask" "$pid" >/dev/null 2>&1
            idx=$((idx + 1))
            ;;
    esac
done
