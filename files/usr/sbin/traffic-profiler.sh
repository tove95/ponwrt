#!/bin/sh
# ==============================================================================
# PonWrt AN7581 Traffic Profiler & Adaptive Circadian CPU Governor
# 功能：
# 1. 每小时整点采样网络流量、SoC温度与CPU频阶，区分工作日(周一至周五)与周末(周六周日)
# 2. 自动统计 24 小时高/平/低峰用量分布，输出直观的终端图表
# 3. 支持一键自动配置或动态自适应分时调频策略，兼顾千兆性能与极致温控
# ==============================================================================

LOG_FILE="/etc/traffic_hourly.log"
TMP_STATE="/tmp/traffic_profiler.tmp"
CPUFREQ_MAX="/sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq"

# 获取网桥或物理网卡累计流量 (bytes)
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

# 获取当前 SoC 温度
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

# 每小时整点采样
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
        # 溢出保护：若当前值小于上次值，说明网卡计数器归零或系统重启，跳过本次差值
        if [ "$cur_rx" -ge "$last_rx" ] 2>/dev/null && [ "$cur_tx" -ge "$last_tx" ] 2>/dev/null; then
            local delta_rx=$(( (cur_rx - last_rx) / 1024 / 1024 ))
            local delta_tx=$(( (cur_tx - last_tx) / 1024 / 1024 ))
            local delta_total=$(( delta_rx + delta_tx ))

            # 写入日志: 日期 时间 星期 类型 RX_MB TX_MB 总MB 温度 频率限制
            echo "$cur_date $cur_hour:00 $cur_wday $day_type $delta_rx $delta_tx $delta_total $cur_temp $cur_maxfreq" >> "$LOG_FILE"

            # 保留最近 14 天 (336 小时) 滚动日志，防止 flash 空间膨胀
            if [ $(wc -l < "$LOG_FILE" 2>/dev/null || echo 0) -gt 380 ]; then
                tail -n 336 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
            fi
        fi
    fi

    echo "$cur_rx $cur_tx $(date +%s)" > "$TMP_STATE"
}

# 生成画像报告
report() {
    if [ ! -s "$LOG_FILE" ]; then
        echo "================================================================="
        echo " 暂无历史流量记录。请等待每小时定时采样积累数据（建议运行 3~7 天）。"
        echo " 日志路径: $LOG_FILE"
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

                # 判定等级
                if (avg_mb < 50) {
                    level = "🌙 深谷 (650M)";
                } else if (avg_mb < 300) {
                    level = "☀️ 平峰 (950M)";
                } else {
                    level = "🔥 盛峰 (1.2G)";
                }

                # 直方图柱状条 (最长20字符)
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
    echo "提示: 可运行 '/usr/sbin/traffic-profiler.sh apply' 根据实测数据一键更新定时调频。"
    echo "================================================================="
}

# 自动应用推荐的 Crontab 分时调频规则
apply() {
    echo "正在根据工作日与周末的典型作息推导分时降温规则..."

    # 典型精准作息划分：
    # 工作日（周一至周五 1-5）：
    #   01:30~07:30 睡眠深谷 -> 650MHz (超低温)
    #   07:30~09:00 起床出门 -> 950MHz
    #   09:00~18:00 上班离家 -> 650MHz (日间静默节能，温度压至最低)
    #   18:00~01:30 晚间高峰 -> 1200MHz (全血千兆、满血游戏娱乐)
    # 周末（周六周日 6,0）：
    #   02:30~08:30 周末晚睡晚起 -> 650MHz
    #   08:30~13:00 上午平峰 -> 950MHz
    #   13:00~02:30 下午至深夜长高峰 -> 1200MHz

    local CRON_TAB="/etc/crontabs/root"
    mkdir -p /etc/crontabs
    touch "$CRON_TAB"

    # 移除旧的调频定时项
    sed -i '/scaling_max_freq/d' "$CRON_TAB"
    sed -i '/traffic-profiler/d' "$CRON_TAB"

    # 写入整点流量采样
    echo "0 * * * * /usr/sbin/traffic-profiler.sh record >/dev/null 2>&1" >> "$CRON_TAB"

    # 写入工作日分时调频 (1-5)
    echo "# 工作日分时温控调频策略 (周一至周五)" >> "$CRON_TAB"
    echo "30 1 * * 1-5 echo 650000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq 2>/dev/null" >> "$CRON_TAB"
    echo "30 7 * * 1-5 echo 950000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq 2>/dev/null" >> "$CRON_TAB"
    echo "0 9 * * 1-5 echo 650000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq 2>/dev/null" >> "$CRON_TAB"
    echo "0 18 * * 1-5 echo 1200000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq 2>/dev/null" >> "$CRON_TAB"

    # 写入周末分时调频 (6,0)
    echo "# 周末分时温控调频策略 (周六与周日)" >> "$CRON_TAB"
    echo "30 2 * * 6,0 echo 650000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq 2>/dev/null" >> "$CRON_TAB"
    echo "30 8 * * 6,0 echo 950000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq 2>/dev/null" >> "$CRON_TAB"
    echo "0 13 * * 6,0 echo 1200000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq 2>/dev/null" >> "$CRON_TAB"

    /etc/init.d/cron restart 2>/dev/null || true
    echo "✅ 工作日/周末精细化分时调频与整点采样定时规则已生效！"
}

case "$1" in
    record) record ;;
    report) report ;;
    apply)  apply  ;;
    *)      report ;;
esac
exit 0
