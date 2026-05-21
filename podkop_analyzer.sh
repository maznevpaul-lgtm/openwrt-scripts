#!/bin/sh
# Ultimate Podkop, AWG & Proxy Analyzer (Detailed Fixes & Zero-Trace)

# Умная очистка временных файлов при любом исходе
trap "rm -f /tmp/podkop_items.txt; exit" EXIT INT TERM

C_RED='\033[1;31m'
C_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'
C_CYAN='\033[1;36m'
C_NONE='\033[0m'

echo "----------------------------------------------------------"
echo -e "${C_CYAN}Анализ запущен: $(date +'%Y-%m-%d %H:%M:%S')${C_NONE}"
echo "----------------------------------------------------------"

# ====================================================================
# 1. СТАТУС СЛУЖБ И СОВМЕСТИМОСТЬ
# ====================================================================
echo -e "\n${C_CYAN}= СТАТУС СЛУЖБ И СОВМЕСТИМОСТЬ:${C_NONE}"
SERVICES="podkop sing-box zapret zapret2 opera-proxy youtubeUnblock"
PODKOP_RUN=0; ZAPRET_RUN=0; OPERA_RUN=0

for srv in $SERVICES; do
    if [ -f "/etc/init.d/$srv" ]; then
        /etc/init.d/$srv enabled 2>/dev/null && ENAB="${C_GREEN}РАЗРЕШЁН${C_NONE}" || ENAB="${C_RED}ОТКЛ${C_NONE}"
        
        if /etc/init.d/$srv status 2>/dev/null | grep -q "running"; then
            [ "$srv" = "podkop" ] && PODKOP_RUN=1
            [ "$srv" = "zapret" ] || [ "$srv" = "zapret2" ] && ZAPRET_RUN=1
            [ "$srv" = "opera-proxy" ] && OPERA_RUN=1
            
            if [ "$srv" = "sing-box" ] && [ "$PODKOP_RUN" -eq 1 ]; then
                echo -e "  $(printf '%-15s' $srv) | ${C_GREEN}RUNNING (MANAGED)${C_NONE} | $ENAB"
            else
                echo -e "  $(printf '%-15s' $srv) | ${C_GREEN}RUNNING${C_NONE}           | $ENAB"
            fi
        else
            echo -e "  $(printf '%-15s' $srv) | ${C_YELLOW}STOPPED${C_NONE}           | $ENAB"
        fi
    fi
done

if [ "$PODKOP_RUN" -eq 1 ] && [ "$ZAPRET_RUN" -eq 1 ]; then
    echo -e "  ⚠️  ${C_YELLOW}Внимание:${C_NONE} Podkop и Zapret работают одновременно! Возможен конфликт nftables."
fi

# ====================================================================
# 2. ПРОВЕРКА OPERA-PROXY И SING-BOX
# ====================================================================
echo -e "\n${C_CYAN}= ПРОВЕРКА ИНТЕГРАЦИИ И ВАЛИДАЦИЯ:${C_NONE}"
CONF_PATH=$(uci -q get podkop.settings.config_path)
[ -z "$CONF_PATH" ] && CONF_PATH="/etc/sing-box/config.json"

if [ -f "$CONF_PATH" ]; then
    if command -v sing-box >/dev/null 2>&1; then
        if sing-box check -c "$CONF_PATH" > /dev/null 2>&1; then
            echo -e "  ✅ ${C_GREEN}Конфиг валиден:${C_NONE} Ошибок в синтаксисе sing-box нет."
        else
            echo -e "  ❌ ${C_RED}КРИТИЧНО:${C_NONE} Файл конфига sing-box сломан или содержит ошибки!"
        fi
    fi
fi

if [ "$OPERA_RUN" -eq 1 ]; then
    OPERA_PORT=$(netstat -tulpn 2>/dev/null | grep -iE 'opera|18080' | awk '{print $4}' | awk -F: '{print $NF}' | head -n 1)
    [ -z "$OPERA_PORT" ] && OPERA_PORT="18080"
    if grep -q "$OPERA_PORT" "$CONF_PATH" 2>/dev/null; then
        echo -e "  ✅ ${C_GREEN}Opera-proxy:${C_NONE} Интегрирована в Подкоп (порт $OPERA_PORT)."
    else
        echo -e "  ⚠️  ${C_YELLOW}Opera-proxy:${C_NONE} Работает на порту $OPERA_PORT, но Подкоп про неё не знает."
    fi
fi

# ====================================================================
# 3. АНАЛИЗ СЕКЦИЙ И ПЕРЕСЕЧЕНИЙ
# ====================================================================
echo -e "\n${C_CYAN}= ПЕРЕСЕЧЕНИЯ ДОМЕНОВ, СПИСКОВ И IP В ПОДКОПЕ:${C_NONE}"
> /tmp/podkop_items.txt
if uci -q get podkop.settings >/dev/null; then
    SECTIONS=$(uci show podkop | grep "=section" | cut -d. -f2 | cut -d= -f1)
    
    for sec in $SECTIONS; do
        LISTS=$(uci -q get podkop.$sec.list | tr ' ' ',')
        DOMAINS=$(uci -q get podkop.$sec.domain | tr ' ' ',')
        IPS=$(uci -q get podkop.$sec.ip | tr ' ' ',')
        
        OUT_STR=""
        [ -n "$LISTS" ] && OUT_STR="${OUT_STR}Списки: $LISTS "
        [ -n "$DOMAINS" ] && OUT_STR="${OUT_STR}Домены: $DOMAINS "
        [ -n "$IPS" ] && OUT_STR="${OUT_STR}IP: $IPS"
        [ -z "$OUT_STR" ] && OUT_STR="пусто"
        
        echo -e "  podkop          ${C_CYAN}$sec${C_NONE}: $OUT_STR"
        
        for item in $(uci -q get podkop.$sec.list 2>/dev/null); do echo "СПИСОК:$item:$sec" >> /tmp/podkop_items.txt; done
        for item in $(uci -q get podkop.$sec.domain 2>/dev/null); do echo "ДОМЕН:$item:$sec" >> /tmp/podkop_items.txt; done
        for item in $(uci -q get podkop.$sec.ip 2>/dev/null); do echo "IP:$item:$sec" >> /tmp/podkop_items.txt; done
    done

    echo "  ---"
    DUPS=$(awk -F':' '{print $1":"$2}' /tmp/podkop_items.txt | sort | uniq -d)
    if [ -n "$DUPS" ]; then
        echo -e "  ❌ ${C_RED}НАЙДЕНЫ КОНФЛИКТЫ (УДАЛИТЕ ДУБЛИКАТЫ):${C_NONE}"
        for dup in $DUPS; do
            TYPE=$(echo "$dup" | cut -d: -f1)
            VAL=$(echo "$dup" | cut -d: -f2)
            
            IN_SECS=$(grep "^$dup:" /tmp/podkop_items.txt | cut -d':' -f3 | sort -u | tr '\n' ' ' | sed 's/ $//')
            SEC_COUNT=$(echo "$IN_SECS" | wc -w)
            
            if [ "$SEC_COUNT" -gt 1 ]; then
                echo -e "     -> ${TYPE} ${C_RED}'$VAL'${C_NONE} добавлен одновременно в: [ ${C_YELLOW}$IN_SECS${C_NONE} ]"
            fi
        done
    else
        echo -e "  ✅ ${C_GREEN}Пересечений нет:${C_NONE} Списки, домены и IP строго разделены."
    fi
else
    echo -e "  [-] Структура Подкопа не найдена."
fi

# ====================================================================
# 4. СКОРОСТЬ И ЗАДЕРЖКИ (PING)
# ====================================================================
echo -e "\n${C_CYAN}= ПРОВЕРКА ДОСТУПОВ/ИНТЕРФЕЙСОВ (LATENCY):${C_NONE}"
WG_IFACES=$(uci show network | grep -E "\.proto=" | grep -E "wireguard|amneziawg" | cut -d. -f2 | cut -d= -f1)

WAN_PING=$(ping -c 2 -W 2 8.8.8.8 2>/dev/null | tail -1 | awk -F '/' '{print $4}')
if [ -n "$WAN_PING" ]; then
    echo -e "  ✅ WAN (Direct)   -> 8.8.8.8 : ${C_GREEN}${WAN_PING} ms${C_NONE}"
else
    echo -e "  ❌ WAN (Direct)   -> 8.8.8.8 : ${C_RED}Таймаут (Нет интернета?)${C_NONE}"
fi

for IFACE in $WG_IFACES; do
    IFACE_PING=$(ping -I "$IFACE" -c 2 -W 2 8.8.8.8 2>/dev/null | tail -1 | awk -F '/' '{print $4}')
    if [ -n "$IFACE_PING" ]; then
        echo -e "  ✅ Туннель $IFACE -> 8.8.8.8 : ${C_GREEN}${IFACE_PING} ms${C_NONE}"
    else
        echo -e "  ⚠️  Туннель $IFACE -> 8.8.8.8 : ${C_YELLOW}Таймаут (Трафик не ходит)${C_NONE}"
    fi
done

# ====================================================================
# 5. КОНФИГУРАЦИЯ AWG И ROUTING LOOPS
# ====================================================================
echo -e "\n${C_CYAN}= ПРОВЕРКА АНОМАЛИЙ И ЗАЦИКЛИВАНИЙ:${C_NONE}"
ENDPOINTS=""
if [ -n "$WG_IFACES" ]; then
    for IFACE in $WG_IFACES; do
        PEERS=$(uci show network | grep -E "=(wireguard|amneziawg)_$IFACE" | cut -d. -f2 | cut -d= -f1 | sort -u)
        for PEER in $PEERS; do
            ROUTE_ALLOWED=$(uci -q get network.$PEER.route_allowed_ips)
            ENDPOINT=$(uci -q get network.$PEER.endpoint_host)
            [ -z "$ENDPOINT" ] && ENDPOINT="Неизвестный хост"

            if [ "$ROUTE_ALLOWED" = "1" ] || [ -z "$ROUTE_ALLOWED" ]; then
                 echo -e "  ❌ ${C_RED}Ошибка AWG:${C_NONE} У пира $ENDPOINT включена маршрутизация!"
                 echo -e "     ${C_CYAN}└ Решение:${C_NONE} Сеть -> Интерфейсы -> $IFACE -> Равноправные узлы -> Изменить."
                 echo -e "       Снимите галочку 'Маршрутизировать разрешённые IP-адреса' и сохраните."
            fi
            ENDPOINTS="$ENDPOINTS $ENDPOINT"
        done
        
        MTU=$(uci -q get network.$IFACE.mtu)
        if [ -z "$MTU" ] || [ "$MTU" -gt 1420 ]; then
            echo -e "  ⚠️  ${C_YELLOW}MTU Warning:${C_NONE} На $IFACE MTU = ${MTU:-1500}. Рекомендуется 1420 или 1280."
        fi
    done
fi

UNIQUE_IPS=$(echo "$ENDPOINTS" | tr ' ' '\n' | grep -v '^$' | sort -u)
for IP in $UNIQUE_IPS; do
    if ! echo "$IP" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        RESOLVED=$(ping -c 1 "$IP" 2>/dev/null | awk -F '[()]' '/PING/{print $2}')
        [ -n "$RESOLVED" ] && IP="$RESOLVED"
    fi
    [ -z "$IP" ] && continue

    ROUTE_DEV=$(ip route get "$IP" 2>/dev/null | head -n1 | grep -oE 'dev [a-zA-Z0-9_-]+' | awk '{print $2}')
    if echo "$ROUTE_DEV" | grep -qE "^(tun|wg|awg|sing|podkop)"; then
        echo -e "  ❌ ${C_RED}ЗАЦИКЛИВАНИЕ:${C_NONE} Сервер $IP заворачивается в туннель [ $ROUTE_DEV ]!"
        echo -e "     ${C_CYAN}└ Решение:${C_NONE} Добавьте этот IP в Исключения (Bypass) Подкопа, чтобы он шел напрямую."
    fi
done

if netstat -tulpn 2>/dev/null | grep -q ":53 .*sing-box"; then
    if netstat -tulpn 2>/dev/null | grep -q ":53 .*dnsmasq"; then
        echo -e "  ❌ ${C_RED}Конфликт DNS:${C_NONE} dnsmasq и sing-box дерутся за порт 53!"
        echo -e "     ${C_CYAN}└ Решение:${C_NONE} Сеть -> DHCP и DNS -> Расширенные настройки."
        echo -e "       Измените 'Порт DNS-сервера' с 53 на 5353 и сохраните."
    fi
fi

# ====================================================================
# 6. СИСТЕМНЫЕ РЕСУРСЫ
# ====================================================================
echo -e "\n${C_CYAN}= СИСТЕМНЫЕ РЕСУРСЫ:${C_NONE}"
LAN_IP=$(uci -q get network.lan.ipaddr)
UPTIME=$(awk '{print int($1/86400)"d "int(($1%86400)/3600)"h "int(($1%3600)/60)"m"}' /proc/uptime)

CPU_LOAD=$(uptime | awk -F'load average:' '{ print $2 }' | cut -d, -f1 | tr -d ' ')

TEMP_C="N/A"
if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
    TEMP_RAW=$(cat /sys/class/thermal/thermal_zone0/temp)
    TEMP_C="$((TEMP_RAW / 1000))°C"
fi

RAM_TOTAL=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
RAM_FREE=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
[ -n "$RAM_TOTAL" ] && RAM_USED_PCT=$(( 100 - (RAM_FREE * 100 / RAM_TOTAL) )) || RAM_USED_PCT="N/A"

NAND_INFO=$(df -h / | tail -n 1)
NAND_USED=$(echo "$NAND_INFO" | awk '{print $5}')

echo -e "  LAN IP: ${C_YELLOW}${LAN_IP:-192.168.1.1}${C_NONE} | Uptime: $UPTIME"
echo -e "  CPU Load: $CPU_LOAD | ${C_YELLOW}Temp: $TEMP_C${C_NONE} | RAM: $RAM_USED_PCT% | NAND: $NAND_USED"

echo -e "\n--- КОНЕЦ АНАЛИЗА ---\n"