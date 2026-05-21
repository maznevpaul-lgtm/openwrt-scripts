#!/bin/sh
# Ultimate Podkop & Zeroblock Analyzer (Smart, Clean & User-Friendly)

trap "rm -f /tmp/analyzer_items.txt; exit" EXIT INT TERM

C_RED='\033[1;31m'
C_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'
C_CYAN='\033[1;36m'
C_NONE='\033[0m'

FW_VER=$(cat /etc/openwrt_release 2>/dev/null | grep DISTRIB_RELEASE | cut -d\' -f2)
LAN_IP=$(uci -q get network.lan.ipaddr || echo "192.168.1.1")

clear
echo "----------------------------------------------------------"
echo -e "${C_CYAN}🚀 Диагностика роутера и систем обхода блокировок запущена${C_NONE}"
echo -e "Время: $(date +'%Y-%m-%d %H:%M:%S')"
echo -e "Версия прошивки: ${C_YELLOW}${FW_VER:-Неизвестно}${C_NONE} | Адрес роутера: ${C_YELLOW}$LAN_IP${C_NONE}"
echo "----------------------------------------------------------"

# ====================================================================
# СТАТУС ПРОГРАММ
# ====================================================================
echo -e "\n${C_CYAN}= СТАТУС СЛУЖБ НА РОУТЕРЕ:${C_NONE}"
SERVICES="podkop zeroblock sing-box zapret zapret2 opera-proxy youtubeUnblock"
PODKOP_RUN=0; ZEROBLOCK_RUN=0; ZAPRET_RUN=0

for srv in $SERVICES; do
    if [ -f "/etc/init.d/$srv" ]; then
        /etc/init.d/$srv enabled 2>/dev/null && ENAB="${C_GREEN}ВКЛЮЧЕНА${C_NONE}" || ENAB="${C_RED}ОТКЛЮЧЕНА${C_NONE}"
        if /etc/init.d/$srv status 2>/dev/null | grep -q "running"; then
            [ "$srv" = "podkop" ] && PODKOP_RUN=1
            [ "$srv" = "zeroblock" ] && ZEROBLOCK_RUN=1
            [ "$srv" = "zapret" ] || [ "$srv" = "zapret2" ] && ZAPRET_RUN=1
            
            if [ "$srv" = "sing-box" ] && { [ "$PODKOP_RUN" -eq 1 ] || [ "$ZEROBLOCK_RUN" -eq 1 ]; }; then
                echo -e "  ✅ $(printf '%-15s' $srv) | ${C_GREEN}РАБОТАЕТ (ПОД УПРАВЛЕНИЕМ)${C_NONE} | Автозапуск: $ENAB"
            else
                echo -e "  ✅ $(printf '%-15s' $srv) | ${C_GREEN}РАБОТАЕТ${C_NONE}           | Автозапуск: $ENAB"
            fi
        else
            echo -e "  ⏸️  $(printf '%-15s' $srv) | ${C_YELLOW}ОСТАНОВЛЕНА${C_NONE}         | Автозапуск: $ENAB"
        fi
    fi
done

# Проверка критического конфликта Подкоп + Zeroblock
if [ "$PODKOP_RUN" -eq 1 ] && [ "$ZEROBLOCK_RUN" -eq 1 ]; then
    echo -e "  ❌ ${C_RED}Критическая ошибка: Конфликт систем обхода!${C_NONE}"
    echo -e "     ${C_CYAN}└ Что это значит:${C_NONE} У вас одновременно запущены и Podkop, и Zeroblock."
    echo -e "       Они используют одно и то же ядро sing-box и ломают маршруты друг другу."
    echo -e "     ${C_CYAN}└ Как исправить:${C_NONE} Выключите одну из служб (оставьте либо Podkop, либо Zeroblock)."
fi

if { [ "$PODKOP_RUN" -eq 1 ] || [ "$ZEROBLOCK_RUN" -eq 1 ]; } && [ "$ZAPRET_RUN" -eq 1 ]; then
    echo -e "  ⚠️  ${C_YELLOW}Внимание: Одновременно работают разные системы обхода (sing-box + Zapret)!${C_NONE}"
    echo -e "     └ Они могут конфликтовать в фаерволе. Рекомендуется использовать что-то одно."
fi

# ====================================================================
# АНАЛИЗ DNS И ПЕРЕХВАТА САЙТОВ
# ====================================================================
echo -e "\n${C_CYAN}= ПРОВЕРКА DNS (ПЕРЕХВАТ ЗАБЛОКИРОВАННЫХ САЙТОВ):${C_NONE}"
DNSMASQ_PORT=$(uci -q get dhcp.@dnsmasq[0].port || echo "53")

if [ "$DNSMASQ_PORT" = "53" ] && netstat -tulpn 2>/dev/null | grep -q ":53 .*sing-box"; then
    echo -e "  ❌ ${C_RED}Критическая ошибка: Конфликт DNS-портов!${C_NONE}"
    echo -e "     ${C_CYAN}🛠 Как исправить:${C_NONE} В меню роутера откройте 'Сеть' -> 'DHCP и DNS' -> 'Расширенные настройки'."
    echo -e "       Найдите 'Порт DNS-сервера', измените цифру 53 на 5353 и нажмите 'Сохранить и применить'."
else
    echo -e "  ✅ Конфликтов DNS-портов не обнаружено."
fi

echo -e "  --- Проверка подмены IP (FakeDNS) ---"
FB_IP=$(ping -c 1 facebook.com 2>/dev/null | awk -F '[()]' '/PING/{print $2}')

if echo "$FB_IP" | grep -qE "^198\.18\."; then
    echo -e "  ✅ ${C_GREEN}Перехват сайтов (FakeDNS) работает отлично!${C_NONE} (Поддельный IP: $FB_IP)"
elif [ -n "$FB_IP" ]; then
    echo -e "  ❌ ${C_RED}Ошибка: Перехват сайтов (FakeDNS) не сработал!${C_NONE}"
    echo -e "     ${C_CYAN}└ Что это значит:${C_NONE} Сайты получают настоящие IP ($FB_IP) и идут мимо туннелей."
    echo -e "     ${C_CYAN}🛠 Как исправить:${C_NONE}"
    echo -e "       1. Полностью выключите функцию «Безопасный DNS» (DoH) в настройках вашего браузера."
    echo -e "       2. Очистите кэш DNS (пункт 2 в главном меню скриптов)."
else
    echo -e "  ⚠️  ${C_YELLOW}Не удалось проверить DNS.${C_NONE} Возможно, на роутере нет интернета."
fi

# ====================================================================
# ПРОВЕРКА СПИСКОВ И ТУННЕЛЕЙ (ПОДКОП + ZEROBLOCK)
# ====================================================================
echo -e "\n${C_CYAN}= ПРОВЕРКА НАПРАВЛЕНИЙ И СКОРОСТИ ОТКЛИКА:${C_NONE}"
> /tmp/analyzer_items.txt

WAN_PING=$(ping -c 1 -W 2 8.8.8.8 2>/dev/null | awk -F '/' '/round-trip/{print $4}')
if [ -n "$WAN_PING" ]; then
    echo -e "  🌐 Прямой интернет (Провайдер): Отклик ${C_GREEN}${WAN_PING} мс${C_NONE}"
else
    echo -e "  ❌ Прямой интернет: ${C_RED}Нет связи${C_NONE} (Проверьте кабель провайдера)"
fi
echo "  ---"

# Чтение секций Podkop
if uci -q get podkop.settings >/dev/null; then
    SECTIONS_P=$(uci show podkop | grep "=section" | cut -d. -f2 | cut -d= -f1)
    for sec in $SECTIONS_P; do
        OUTBOUND=$(uci -q get podkop.$sec.outbound || echo "неизвестно")
        if uci -q get network.$OUTBOUND >/dev/null; then
            IFACE_PING=$(ping -I "$OUTBOUND" -c 1 -W 2 8.8.8.8 2>/dev/null | awk -F '/' '/round-trip/{print $4}')
            [ -n "$IFACE_PING" ] && P_STR="${C_GREEN}${IFACE_PING} мс${C_NONE}" || P_STR="${C_RED}Таймаут (Туннель упал!)${C_NONE}"
            echo -e "  ✅ [Подкоп] Секция ${C_CYAN}$sec${C_NONE} -> Отклик: $P_STR"
        else
            echo -e "  📦 [Подкоп] Секция ${C_CYAN}$sec${C_NONE} -> ${C_YELLOW}Встроенный прокси ($OUTBOUND)${C_NONE}"
        fi
        for item in $(uci -q get podkop.$sec.list 2>/dev/null); do echo "Список:$item:Подкоп->$sec" >> /tmp/analyzer_items.txt; done
        for item in $(uci -q get podkop.$sec.domain 2>/dev/null); do echo "Домен:$item:Подкоп->$sec" >> /tmp/analyzer_items.txt; done
    done
fi

# Чтение секций Zeroblock
if uci -q get zeroblock.settings >/dev/null; then
    SECTIONS_Z=$(uci show zeroblock | grep "=section" | cut -d. -f2 | cut -d= -f1)
    for sec in $SECTIONS_Z; do
        OUTBOUND=$(uci -q get zeroblock.$sec.outbound || echo "неизвестно")
        if uci -q get network.$OUTBOUND >/dev/null; then
            IFACE_PING=$(ping -I "$OUTBOUND" -c 1 -W 2 8.8.8.8 2>/dev/null | awk -F '/' '/round-trip/{print $4}')
            [ -n "$IFACE_PING" ] && P_STR="${C_GREEN}${IFACE_PING} мс${C_NONE}" || P_STR="${C_RED}Таймаут (Туннель упал!)${C_NONE}"
            echo -e "  ✅ [Zeroblock] Секция ${C_CYAN}$sec${C_NONE} -> Отклик: $P_STR"
        else
            echo -e "  📦 [Zeroblock] Секция ${C_CYAN}$sec${C_NONE} -> ${C_YELLOW}Встроенный прокси ($OUTBOUND)${C_NONE}"
        fi
        for item in $(uci -q get zeroblock.$sec.list 2>/dev/null); do echo "Список:$item:Zeroblock->$sec" >> /tmp/analyzer_items.txt; done
        for item in $(uci -q get zeroblock.$sec.domain 2>/dev/null); do echo "Домен:$item:Zeroblock->$sec" >> /tmp/analyzer_items.txt; done
    done
fi

# Анализ дубликатов (внутри сервисов и между ними)
if [ -s /tmp/analyzer_items.txt ]; then
    echo "  ---"
    DUPS=$(awk -F':' '{print $1":"$2}' /tmp/analyzer_items.txt | sort | uniq -d)
    if [ -n "$DUPS" ]; then
        echo -e "  ❌ ${C_RED}Конфликт маршрутов! Найдено дублирование сайтов/списков:${C_NONE}"
        for dup in $DUPS; do
            TYPE=$(echo "$dup" | cut -d: -f1)
            VAL=$(echo "$dup" | cut -d: -f2)
            IN_SECS=$(grep "^$dup:" /tmp/analyzer_items.txt | cut -d':' -f3 | sort -u | tr '\n' ' ' | sed 's/ $//')
            SEC_COUNT=$(echo "$IN_SECS" | wc -w)
            if [ "$SEC_COUNT" -gt 1 ]; then
                echo -e "       -> $TYPE ${C_RED}'$VAL'${C_NONE} добавлен сразу в: [ ${C_YELLOW}$IN_SECS${C_NONE} ]"
            fi
        done
        echo -e "     ${C_CYAN}🛠 Как исправить:${C_NONE} Сайт или список должен находиться строго в одном месте, иначе система запутается."
    else
        echo -e "  ✅ Конфликтов в списках сайтов не обнаружено."
    fi
fi

# ====================================================================
# ПРОВЕРКА НАСТРОЕК AMNEZIA WG / WIREGUARD
# ====================================================================
WG_IFACES=$(uci show network | grep -E "\.proto=" | grep -E "wireguard|amneziawg" | cut -d. -f2 | cut -d= -f1)
ENDPOINTS=""
LOOP_FOUND=0

if [ -n "$WG_IFACES" ]; then
    echo -e "\n${C_CYAN}= ПРОВЕРКА VPN-ИНТЕРФЕЙСОВ (AMNEZIA WG / WIREGUARD):${C_NONE}"
    for IFACE in $WG_IFACES; do
        PEERS=$(uci show network | grep -E "=(wireguard|amneziawg)_$IFACE" | cut -d. -f2 | cut -d= -f1 | sort -u)
        for PEER in $PEERS; do
            ROUTE_ALLOWED=$(uci -q get network.$PEER.route_allowed_ips)
            ENDPOINT=$(uci -q get network.$PEER.endpoint_host)
            [ -n "$ENDPOINT" ] && ENDPOINTS="$ENDPOINTS $ENDPOINT"

            if [ "$ROUTE_ALLOWED" = "1" ] || [ -z "$ROUTE_ALLOWED" ]; then
                 echo -e "  ❌ ${C_RED}Ошибка в настройках интерфейса $IFACE!${C_NONE}"
                 echo -e "     ${C_CYAN}🛠 Как исправить:${C_NONE} В 'Сеть' -> 'Интерфейсы' -> '$IFACE' -> 'Равноправные узлы' -> Снимите галочку 'Маршрутизировать разрешённые IP'."
            fi
        done
    done

    UNIQUE_IPS=$(echo "$ENDPOINTS" | tr ' ' '\n' | grep -v '^$' | sort -u)
    for IP in $UNIQUE_IPS; do
        if ! echo "$IP" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
            RESOLVED=$(ping -c 1 "$IP" 2>/dev/null | awk -F '[()]' '/PING/{print $2}')
            [ -n "$RESOLVED" ] && IP="$RESOLVED"
        fi
        [ -z "$IP" ] && continue

        ROUTE_DEV=$(ip route get "$IP" 2>/dev/null | head -n1 | grep -oE 'dev [a-zA-Z0-9_-]+' | awk '{print $2}')
        if echo "$ROUTE_DEV" | grep -qE "^(tun|wg|awg|sing|podkop|zeroblock)"; then
            echo -e "  ❌ ${C_RED}Зацикливание трафика! Сервер VPN ($IP) блокирует сам себя.${C_NONE}"
            echo -e "     ${C_CYAN}🛠 Как исправить:${C_NONE} Добавьте IP ${C_YELLOW}$IP${C_NONE} в раздел 'Исключения' (Bypass) вашего Подкопа или Zeroblock."
            LOOP_FOUND=1
        fi
    done
    [ "$LOOP_FOUND" -eq 0 ] && echo -e "  ✅ Зацикливаний трафика не обнаружено."
fi

# ====================================================================
# РАСХОД ТРАФИКА ЗА МЕСЯЦ
# ====================================================================
if command -v vnstat >/dev/null 2>&1; then
    echo -e "\n${C_CYAN}= СТАТИСТИКА РАСХОДА ИНТЕРНЕТА:${C_NONE}"
    WAN_DEV=$(ip route show default 2>/dev/null | grep -oE 'dev [a-zA-Z0-9_-]+' | head -n1 | awk '{print $2}')
    [ -z "$WAN_DEV" ] && WAN_DEV=$(uci -q get network.wan.device)
    if [ -n "$WAN_DEV" ]; then
        echo -e "  📊 Трафик на интерфейсе провайдера ($WAN_DEV):"
        vnstat -i "$WAN_DEV" -m 2>/dev/null | grep -E "(month|20[0-9]{2}-)" | tail -n 3 | sed 's/^/     /'
    fi
fi

# ====================================================================
# СОСТОЯНИЕ WI-FI СЕТЕЙ
# ====================================================================
if command -v iw >/dev/null 2>&1 || command -v iwinfo >/dev/null 2>&1; then
    WIFI_IFACES=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2}')
    if [ -n "$WIFI_IFACES" ]; then
        echo -e "\n${C_CYAN}= СОСТОЯНИЕ WI-FI СЕТЕЙ:${C_NONE}"
        for wiface in $WIFI_IFACES; do
            SSID=$(iwinfo $wiface info 2>/dev/null | grep ESSID | cut -d'"' -f2)
            [ -z "$SSID" ] && SSID="Скрытая/Выключена"
            RATE=$(iwinfo $wiface info 2>/dev/null | grep "Bit Rate" | awk '{print $3" "$4}')
            CLIENTS=$(iwinfo $wiface assoclist 2>/dev/null | grep -E "^[0-9A-F:]+" | wc -l)
            
            if ip link show $wiface 2>/dev/null | grep -q "UP"; then
                echo -e "  📡 Сеть (SSID): ${C_YELLOW}$SSID${C_NONE} | ${C_GREEN}РАЗДАЕТСЯ${C_NONE}"
                echo -e "     ├ Подключено устройств: ${C_CYAN}$CLIENTS шт.${C_NONE}"
                echo -e "     └ Текущая скорость канала: ${C_CYAN}${RATE:-Неизвестно}${C_NONE}"
            fi
        done
    fi
fi

# ====================================================================
# НАГРУЗКА НА РОУТЕР
# ====================================================================
echo -e "\n${C_CYAN}= НАГРУЗКА НА РОУТЕР:${C_NONE}"
UPTIME=$(awk '{print int($1/86400)"д "int(($1%86400)/3600)"ч "int(($1%3600)/60)"m"}' /proc/uptime)
CPU_LOAD=$(uptime | awk -F'load average:' '{ print $2 }' | cut -d, -f1 | tr -d ' ')

TEMP_C="Нет датчика"
if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
    TEMP_C="$(( $(cat /sys/class/thermal/thermal_zone0/temp) / 1000 ))°C"
fi

RAM_TOTAL=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
RAM_FREE=$(awk '/MemAvailable/ {proc/meminfo || print $4}')
[ -n "$RAM_TOTAL" ] && [ "$RAM_TOTAL" -gt 0 ] && RAM_USED_PCT=$(( 100 - (RAM_FREE * 100 / RAM_TOTAL) )) || RAM_USED_PCT="N/A"
NAND_INFO=$(df -h / | awk '$NF=="/"{printf "%s занято", $5}')

echo -e "  Время работы: $UPTIME | Процессор: $CPU_LOAD | Температура: $TEMP_C"
echo -e "  Оперативная память: $RAM_USED_PCT% | Внутренняя память: $NAND_INFO"

echo -e "\n${C_GREEN}--- ДИАГНОСТИКА ЗАВЕРШЕНА ---${C_NONE}\n"