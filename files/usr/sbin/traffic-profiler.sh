#!/bin/sh
# ==============================================================================
# PonWrt AN7581 Traffic Profiler & Circadian Thermal Governor
#
# 功能说明：
# 1. 可选高级特性，默认关闭，完全由用户按需选择开启或停止；
# 2. 开启后每小时整点记录网络吞吐、SoC温度与CPU频阶（自动区分工作日与周末）；
# 3. 提供终端直方图报告，并支持根据家庭真实作息一键应用工作日/周末分时调频。
# ==============================================================================

LOG_FILE="/etc/traffic_hourly.log"
TMP_STATE="/tmp/traffic_profiler.tmp"
CRON_TAB="/etc/crontabs/root"
CPUFREQ_MAX="/sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq"

get_net_bytes() {
    local dev="br-lan"
    if [ ! -d "/sys/class/net/$dev" ]; then
        for d in eth1 pon0 lan1; do
            [ -d "/sys/class/net/$d" ] && dev="$d" && break
        done
    fi
    local rx=$(cat "/sys/class/net/$dev/statistics/rx_bytes" 2>/dev/null || echo 0)
    local tx=$(cat "/sys/class/net/$dev/statistics/tx_bytes" 2>/dev/null || echo 0)
    echo "$rx $tx"
}

get_soc_temp() {
    local temp="N/A"
    if [ -f "/sbin/tempinfo" ]; then
        temp=$(/sbin/tempinfo 2>/dev/null | grep -i "SoC" | grep -Eo '[0-9]+(\.[0-9]+)?' | head -n1)
    fi
    if [ -z "$temp" ] && [ -f "/sys/class/thermal/thermal_zone0/temp" ]; then
        local raw=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
        [ -n "$raw" ] && temp=$((raw / 1000))
    fi
    echo "${temp:-0}"
}

# 1. 整点采样
record() {
    local cur_date=$(date +'%Y-%m-%d')
    local cur_hour=$(date +'%H')
    local cur_wday=$(date +'%u') # 1=周一, 7=周日
    local day_type="weekday"
    [ "$cur_wday" -ge 6 ] && day_type="weekend"

    local net_bytes=$(get_net_bytes)
    local cur_rx=$(echo "$net_bytes" | awk '{print $1}')
    local cur_tx=$(echo "$net_bytes" | awk '{print $2}')
    local cur_temp=$(get_soc_temp)
    local cur_maxfreq=$(cat "$CPUFREQ_MAX" 2>/dev/null || echo 0)

    if [ -f "$TMP_STATE" ]; then
        read -r last_rx last_tx last_time < "$TMP_STATE"
        if [ "$cur_rx" -ge "$last_rx" ] 2>/dev/null && [ "$cur_tx" -ge "$last_tx" ] 2>/dev/null; then
            local delta_rx=$(( (cur_rx - last_rx) / 1024 / 1024 ))
            local delta_tx=$(( (cur_tx - last_tx) / 1024 / 1024 ))
            local delta_total=$(( delta_rx + delta_tx ))

            echo "$cur_date $cur_hour:00 $cur_wday $day_type $delta_rx $delta_tx $delta_total $cur_temp $cur_maxfreq" >> "$LOG_FILE"

            # 滚动保留最近 14 天 (336 小时) 采样
            if [ $(wc -l < "$LOG_FILE" 2>/dev/null || echo 0) -gt 380 ]; then
                tail -n 336 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
            fi
        fi
    fi

    echo "$cur_rx $cur_tx $(date +%s)" > "$TMP_STATE"
}

# 2. 启用整点采样
enable() {
    mkdir -p /etc/crontabs
    touch "$CRON_TAB"
    if ! grep -q "traffic-profiler.sh record" "$CRON_TAB" 2>/dev/null; then
        echo "0 * * * * /usr/sbin/traffic-profiler.sh record >/dev/null 2>&1" >> "$CRON_TAB"
        /etc/init.d/cron restart 2>/dev/null || true
    fi
    # 立即建立首次基准
    record
    echo "✅ 已启用整点用量采样（每小时自动采样一次）。"
    echo "   建议运行 3~7 天后执行 'traffic-profiler.sh report' 查看分析画像。"
}

# 3. 停止采样并清理所有分时调频（恢复默认 1.2GHz 全速自适应）
disable() {
    if [ -f "$CRON_TAB" ]; then
        sed -i '/traffic-profiler/d' "$CRON_TAB"
        sed -i '/scaling_max_freq/d' "$CRON_TAB"
        /etc/init.d/cron restart 2>/dev/null || true
    fi
    echo 1200000 > "$CPUFREQ_MAX" 2>/dev/null || true
    echo "🛑 已停止采样并清除分时调频计划，CPU 已完全恢复默认 1.2GHz 动态满频自适应。"
}

# 4. 生成画像分析报告
report() {
    if [ ! -s "$LOG_FILE" ]; then
        echo "================================================================="
        echo " 暂无历史用量记录。"
        echo " 如需启用采样，请执行: traffic-profiler.sh enable"
        echo "================================================================="
        return
    fi

    echo "================================================================="
    echo "       PonWrt AN7581 日常用量与作息画像分析 (工作日 vs 周末)       "
    echo "================================================================="
    echo " 数据记录总条数: $(wc -l < "$LOG_FILE") 小时"
    echo ""

    render_profile() {
        local filter_type="$1"
        local title="$2"
        echo "---【$title】24小时流量分布与平均温度 ---"
        printf "%-5s | %-10s | %-8s | %-12s | %s\n" "时段" "平均流量" "平均温度" "建议等级" "分布直方图"
        echo "-----------------------------------------------------------------"

        awk -v type="$filter_type" '
        $4 == type {
            h = $2; sub(/:00/, "", h);
            tot[h] += $7;
            cnt[h]++;
            if ($8 > 0) { temp[h] += $8; tcnt[h]++; }
            if ($7 > max) max = $7;
        }
        END {
            for (i = 0; i < 24; i++) {
                h = sprintf("%02d", i);
                c = cnt[h] ? cnt[h] : 1;
                avg_mb = int(tot[h] / c);
                tc = tcnt[h] ? tcnt[h] : 1;
                avg_t = (temp[h] > 0) ? sprintf("%.1f°C", temp[h] / tc) : "N/A";

                if (avg_mb < 50) {
                    level = "🌙 深谷 (650M)";
                } else if (avg_mb < 300) {
                    level = "☀️ 平峰 (950M)";
                } else {
                    level = "🔥 盛峰 (1.2G)";
                }

                bar_len = (max > 0) ? int((avg_mb / (max + 1)) * 20) : 0;
                bar = "";
                for (b = 0; b < bar_len; b++) bar = bar "█";

                printf "%02d:00 | %6d MB  | %-8s | %-12s | %s\n", i, avg_mb, avg_t, level, bar;
            }
        }' "$LOG_FILE"
        echo ""
    }

    render_profile "weekday" "工作日 (周一至周五)"
    render_profile "weekend" "周末 (周六与周日)"
    echo "提示: 可运行 'traffic-profiler.sh apply' 应用工作日/周末分时调频降温计划。"
    echo "================================================================="
}

# 5. 应用工作日/周末分时调频计划
apply() {
    mkdir -p /etc/crontabs
    touch "$CRON_TAB"

    sed -i '/scaling_max_freq/d' "$CRON_TAB"
    sed -i '/traffic-profiler/d' "$CRON_TAB"

    echo "0 * * * * /usr/sbin/traffic-profiler.sh record >/dev/null 2>&1" >> "$CRON_TAB"

    # 工作日分时调频 (1-5)
    echo "# 工作日分时温控调频策略 (周一至周五)" >> "$CRON_TAB"
    echo "30 1 * * 1-5 echo 650000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq 2>/dev/null" >> "$CRON_TAB"
    echo "30 7 * * 1-5 echo 950000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq 2>/dev/null" >> "$CRON_TAB"
    echo "0 9 * * 1-5 echo 650000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq 2>/dev/null" >> "$CRON_TAB"
    echo "0 18 * * 1-5 echo 1200000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq 2>/dev/null" >> "$CRON_TAB"

    # 周末分时调频 (6,0)
    echo "# 周末分时温控调频策略 (周六与周日)" >> "$CRON_TAB"
    echo "30 2 * * 6,0 echo 650000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq 2>/dev/null" >> "$CRON_TAB"
    echo "30 8 * * 6,0 echo 950000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq 2>/dev/null" >> "$CRON_TAB"
    echo "0 13 * * 6,0 echo 1200000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq 2>/dev/null" >> "$CRON_TAB"

    /etc/init.d/cron restart 2>/dev/null || true
    echo "✅ 已启用工作日/周末分时调频与整点采样！"
    echo "   工作日 09:00~18:00 (离家) 与 01:30~07:30 (睡眠) 将自动锁定 650MHz 极冷休眠；"
    echo "   下班晚间与周末高负荷期将全速释放 1.2GHz 满血算力。"
}

# 6. 清理历史记录
clear_log() {
    rm -f "$LOG_FILE" "$TMP_STATE"
    echo "🧹 已清空历史流量与温度日志。"
}

# 7. 查看当前状态
status() {
    echo "=== PonWrt AN7581 用量画像与分时调频状态 ==="
    if grep -q "traffic-profiler.sh record" "$CRON_TAB" 2>/dev/null; then
        echo "整点流量采样: [已开启]"
    else
        echo "整点流量采样: [已关闭] (执行 'traffic-profiler.sh enable' 开启)"
    fi

    if grep -q "scaling_max_freq" "$CRON_TAB" 2>/dev/null; then
        echo "分时分级调频: [已启用]"
    else
        echo "分时分级调频: [未启用] (执行 'traffic-profiler.sh apply' 启用)"
    fi

    echo "当前最高频限制: $(cat "$CPUFREQ_MAX" 2>/dev/null || echo "N/A") Hz"
    echo "当前 SoC 核心温度: $(get_soc_temp)°C"
    echo "历史日志条数: $(wc -l < "$LOG_FILE" 2>/dev/null || echo 0) 小时"
    echo "============================================="
}

case "$1" in
    enable)  enable ;;
    disable) disable ;;
    record)  record ;;
    report)  report ;;
    apply)   apply ;;
    clear)   clear_log ;;
    status)  status ;;
    *)
        echo "用法: $0 {enable|disable|report|apply|status|clear}"
        echo "  enable  - 开启每小时整点流量/温度采样"
        echo "  disable - 停止采样并清除分时调频 (恢复 1.2GHz 全速)"
        echo "  report  - 打印工作日 vs 周末 24 小时流量画像直方图"
        echo "  apply   - 一键启用工作日/周末分时调频降温策略"
        echo "  status  - 查看当前运行状态与温度"
        echo "  clear   - 清空历史采样日志"
        ;;
esac
exit 0
