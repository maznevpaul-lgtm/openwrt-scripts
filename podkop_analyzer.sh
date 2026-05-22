#!/bin/sh
# RouteRich Ultimate Analyzer v36 (True Network-based Failsafe Detection)

trap "rm -f /tmp/analyzer_items.txt; exit" EXIT INT TERM

C_RED='\033[1;31m'
C_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'
C_CYAN='\033[1;36m'
C_NONE='\033[0m'

print_loading() { printf "  ⏳ ${C_YELLOW}%s...${C_NONE}" "$1"; }
clear_loading() { printf "\r\033[K"; }

get_ver() {
    local ver=$(opkg info "$1" 2>/dev/null | grep -m 1 Version | awk '{print $2}')
    [ -n "$ver" ] && echo "v$ver" || echo "Неизвестно"
}

FW_VER=$(cat /etc/openwrt_release 2>/dev/null | grep DISTRIB_RELEASE | cut -d\' -f2)
LAN_IP=$(uci -q get network.lan.ipaddr || echo "192.168.1.1")

clear
echo "----------------------------------------------------------"
echo -e "${C_CYAN}🛡️ Глубокая диагностика маршрутизации и обхода блокировок${C_NONE}"
echo -e "Время: $(date +'%Y-%m-%d %H:%M:%S')"
echo -e "Прошивка: ${C_YELLOW}${FW_VER:-Неизвестно}${C_NONE} | IP роутера: ${C_YELLOW}$LAN_IP${C_NONE}"
echo "----------------------------------------------------------"

# ====================================================================
# 1. ВЕРСИИ И СТАТУС ПРОГРАММ
# ====================================================================
echo -e "\n${C_CYAN}= 1. УСТАНОВЛЕННЫЕ ПАКЕТЫ И ИХ СТАТУС:${C_NONE}"
SERVICES="podkop zeroblock sing-box zapret zapret2 opera-proxy youtubeUnblock"
PODKOP_RUN=0; ZEROBLOCK_RUN=0; ZAPRET_RUN=0; OPERA_RUN=0

for srv in $SERVICES; do
    if [ -f "/etc/init.d/$srv" ]; then
        VER=$(get_ver "$srv")
        /etc/init.d/$srv enabled 2>/dev/null && ENAB="${C_GREEN}ВКЛ${C_NONE}" || ENAB="${C_RED}ВЫКЛ${C_NONE}"
        
        if /etc/init.d/$srv status 2>/dev/null | grep -q "running"; then
            [ "$srv" = "podkop" ] && PODKOP_RUN=1
            [ "$srv" = "zeroblock" ] && ZEROBLOCK_RUN=1
            [ "$srv" = "zapret" ] || [ "$srv" = "zapret2" ] && ZAPRET_RUN=1
            [ "$srv" = "opera-proxy" ] && OPERA_RUN=1
            
            if [ "$srv" = "sing-box" ] && { [ "$PODKOP_RUN" -eq 1 ] || [ "$ZEROBLOCK_RUN" -eq 1 ]; }; then
                echo -e "  ✅ $(printf '%-15s' $srv) | ${C_GREEN}РАБОТАЕТ (Управляется ядром)${C_NONE} | Авто: $ENAB | $VER"
            else
                echo -e "  ✅ $(printf '%-15s' $srv) | ${C_GREEN}РАБОТАЕТ${C_NONE}                     | Авто: $ENAB | $VER"
            fi
        else
            echo -e "  ⏸️  $(printf '%-15s' $srv) | ${C_YELLOW}ОСТАНОВЛЕНА${C_NONE}                  | Авто: $ENAB | $VER"
        fi
    fi
done

if [ "$PODKOP_RUN" -eq 1 ] && [ "$ZEROBLOCK_RUN" -eq 1 ]; then
    echo -e "  ❌ ${C_RED}КРИТИЧЕСКАЯ ОШИБКА: Запущены Podkop и Zeroblock одновременно!${C_NONE}"
    echo -e "     ${C_CYAN}└ Что это значит:${C_NONE} Обе системы ломают друг другу маршруты."
    echo -e "     ${C_YELLOW}⚡ Авто-решение (Оставить Подкоп):${C_NONE} /etc/init.d/zeroblock stop && /etc/init.d/zeroblock disable"
fi

if { [ "$PODKOP_RUN" -eq 1 ] || [ "$ZEROBLOCK_RUN" -eq 1 ]; } && [ "$ZAPRET_RUN" -eq 1 ]; then
    echo -e "  ⚠️  ${C_YELLOW}РИСК КОНФЛИКТА: Совместная работа (Podkop + Zapret)${C_NONE}"
    echo -e "     ${C_CYAN}🛠 Как исправить:${C_NONE} Добавьте VPN-интерфейсы Подкопа в исключения Zapret."
fi

# ====================================================================
# 2. АНАЛИЗ DNS И FAKEDNS
# ====================================================================
echo -e "\n${C_CYAN}= 2. ПРОВЕРКА DNS И FAKEDNS (ПЕРЕХВАТ ТРАФИКА):${C_NONE}"
DNSMASQ_PORT=$(uci -q get dhcp.@dnsmasq[0].port || echo "53")

# Умная проверка по РЕАЛЬНЫМ сетевым адресам (Игнорирует ложные конфликты)
if netstat -tulpn 2>/dev/null | grep -qE "127\.0\.0\.42:53\s+.*sing-box"; then
    echo -e "  ✅ ${C_GREEN}Архитектура RouteRich:${C_NONE} Ядро использует выделенный IP (127.0.0.42) для DNS. Конфликтов нет."
elif [ "$DNSMASQ_PORT" = "53" ] && netstat -tulpn 2>/dev/null | grep -qE "(0\.0\.0\.0|127\.0\.0\.1|${LAN_IP}):53\s+.*sing-box"; then
    echo -e "  ❌ ${C_RED}КРИТИЧЕСКИЙ КОНФЛИКТ: Конфликт системных DNS-портов!${C_NONE}"
    echo -e "     ${C_CYAN}└ Что это значит:${C_NONE} Служба dnsmasq и Podkop дерутся за стандартный порт 53."
    echo -e "     ${C_YELLOW}⚡ В один клик:${C_NONE} uci set dhcp.@dnsmasq[0].port='5353' && uci commit dhcp && /etc/init.d/dnsmasq restart"
else
    echo -e "  ✅ Конфликтов системных DNS-портов не обнаружено."
fi

print_loading "Проверка подмены DNS"
FB_IP=$(ping -c 1 facebook.com 2>/dev/null | awk -F '[()]' '/PING/{print $2}')
clear_loading

if echo "$FB_IP" | grep -qE "^198\.18\."; then
    echo -e "  ✅ ${C_GREEN}FakeDNS работает отлично!${C_NONE} Заблокированный сайт получил виртуальный IP ($FB_IP) и завернут в туннель."
elif [ -n "$FB_IP" ]; then
    echo -e "  ❌ ${C_RED}СБОЙ FAKEDNS:${C_NONE} Сайт получил настоящий IP-адрес ($FB_IP). Трафик пойдет мимо обхода."
    echo -e "     ${C_CYAN}🛠 Как исправить:${C_NONE} В браузере отключите «Безопасный DNS» (DoH). Выключите сторонние VPN. Очистите кэш DNS."
else
    echo -e "  ⚠️  ${C_YELLOW}Таймаут DNS.${C_NONE} Роутер вообще не может определить IP-адрес сайта. Проверьте провайдера."
fi

# ====================================================================
# 3. СЕКЦИИ И АДАПТИВНАЯ СКОРОСТЬ
# ====================================================================
echo -e "\n${C_CYAN}= 3. АНАЛИЗ МАРШРУТОВ И РЕАЛЬНОЙ СКОРОСТИ УЗЛОВ:${C_NONE}"
> /tmp/analyzer_items.txt

print_loading "Проверка провайдера"
WAN_PING=$(ping -c 1 -W 2 8.8.8.8 2>/dev/null | awk -F '/' '/round-trip/{print $4}')
clear_loading
if [ -n "$WAN_PING" ]; then
    echo -e "  🌐 Прямой интернет (Провайдер) -> Отклик: ${C_GREEN}${WAN_PING} мс${C_NONE}"
else
    echo -e "  ❌ Прямой интернет -> ${C_RED}Нет связи${C_NONE}"
fi
echo "  ---"

check_sections_and_speed() {
    local APP=$1
    if ! uci -q get $APP.settings >/dev/null; then return; fi
    
    echo -e "  🔰 Анализ базы конфигурации [${C_YELLOW}$APP${C_NONE}]:"
    SECTIONS=$(uci show $APP 2>/dev/null | grep "=section" | cut -d. -f2 | cut -d= -f1)
    
    API_ADDR=$(jsonfilter -i "/etc/sing-box/config.json" -e '@.experimental.clash_api.external_controller' 2>/dev/null)
    [ -z "$API_ADDR" ] && API_ADDR="${LAN_IP}:9090"
    
    for sec in $SECTIONS; do
        print_loading "Опрос секции $sec"
        
        CONN_TYPE=$(uci -q get $APP.$sec.connection_type || echo "proxy")
        
        # СБОР СПИСКОВ
        C_LISTS=$(uci -q get $APP.$sec.community_lists | tr ' ' ',')
        D_TEXT=$(uci -q get $APP.$sec.user_domains_text | tr '\n' ',' | sed 's/ //g; s/,,/,/g; s/^,//; s/,$//')
        S_TEXT=$(uci -q get $APP.$sec.user_subnets_text | tr '\n' ',' | sed 's/ //g; s/,,/,/g; s/^,//; s/,$//')
        F_IPS=$(uci -q get $APP.$sec.fully_routed_ips | tr ' ' ',')
        
        ALL_ITEMS=""
        [ -n "$C_LISTS" ] && ALL_ITEMS="Списки: $C_LISTS "
        [ -n "$D_TEXT" ] && ALL_ITEMS="${ALL_ITEMS}Домены: $D_TEXT "
        [ -n "$F_IPS" ] && ALL_ITEMS="${ALL_ITEMS}Полный роутинг: $F_IPS"
        [ -n "$S_TEXT" ] && ALL_ITEMS="${ALL_ITEMS}Подсети: $S_TEXT"
        [ -z "$ALL_ITEMS" ] && ALL_ITEMS="пусто (трафик не назначен)"
        
        for i in $(echo "$C_LISTS" | tr ',' '\n'); do [ -n "$i" ] && echo "Список:$i:$APP->$sec" >> /tmp/analyzer_items.txt; done
        for d in $(echo "$D_TEXT" | tr ',' '\n' | grep -v '^//'); do [ -n "$d" ] && echo "Домен:$d:$APP->$sec" >> /tmp/analyzer_items.txt; done

        # ТЕСТ СКОРОСТИ
        DELAY=""
        STATUS_MSG=""
        
        if [ "$CONN_TYPE" = "exclusion" ]; then
            DELAY="$WAN_PING"
            [ -n "$DELAY" ] && DELAY="${DELAY} мс"
            STATUS_MSG="(Исключение / Bypass)"
        elif [ "$CONN_TYPE" = "vpn" ]; then
            IFACE=$(uci -q get $APP.$sec.interface)
            if [ -n "$IFACE" ] && ip link show "$IFACE" >/dev/null 2>&1; then
                RES=$(ping -I "$IFACE" -c 1 -W 2 8.8.8.8 2>/dev/null | awk -F '/' '/round-trip/{print $4}')
                [ -n "$RES" ] && DELAY="${RES} мс"
                STATUS_MSG="(Туннель $IFACE)"
            fi
        else
            TARGET_TAG="${sec}-out"
            [ "$sec" = "main" ] && TARGET_TAG="main-out"
            URL="http://${API_ADDR}/proxies/${TARGET_TAG}/delay?url=http://www.gstatic.com/generate_204&timeout=2500"
            if command -v curl >/dev/null 2>&1; then
                API_RES=$(curl -s "$URL")
            else
                API_RES=$(wget -qO- "$URL" 2>/dev/null)
            fi
            if echo "$API_RES" | grep -q '"delay"'; then
                DELAY=$(echo "$API_RES" | grep -o '"delay":[0-9]*' | cut -d: -f2)
                [ -n "$DELAY" ] && [ "$DELAY" != "0" ] && DELAY="${DELAY} мс" || DELAY=""
                STATUS_MSG="(Узел $TARGET_TAG)"
            fi
        fi

        clear_loading
        
        # ВЫВОД И РАССЛЕДОВАНИЕ
        if [ -n "$DELAY" ] && [ "$DELAY" != "0" ]; then
            echo -e "  ✅ [${C_CYAN}$sec${C_NONE}] -> Отклик: ${C_GREEN}${DELAY}${C_NONE} $STATUS_MSG"
            echo -e "     └ Направлено: ${C_YELLOW}$ALL_ITEMS${C_NONE}"
        else
            echo -e "  ❌ [${C_CYAN}$sec${C_NONE}] -> ${C_RED}Не отвечает${C_NONE} $STATUS_MSG"
            if [ "$CONN_TYPE" = "vpn" ]; then
                echo -e "     ${C_CYAN}🛠 Как исправить:${C_NONE} Провайдер блокирует протокол, проблема с MTU или ключами."
            elif [ "$CONN_TYPE" != "exclusion" ]; then
                echo -e "     ${C_CYAN}🛠 Как исправить:${C_NONE} Проверьте оплату VPS, правильность UUID или блокировку порта."
            fi
            echo -e "     └ Направлено: ${C_YELLOW}$ALL_ITEMS${C_NONE}"
        fi
    done
}

check_sections_and_speed "podkop"
check_sections_and_speed "zeroblock"

echo "  ---"
DUPS=$(awk -F':' '{print $1":"$2}' /tmp/analyzer_items.txt | sort | uniq -d)
if [ -n "$DUPS" ]; then
    echo -e "  ❌ ${C_RED}КОНФЛИКТ В СПИСКАХ: Найдено дублирование сайтов/списков!${C_NONE}"
else
    echo -e "  ✅ ${C_GREEN}Пересечений нет:${C_NONE} Списки маршрутизации чисты."
fi

# ====================================================================
# 4. АНАЛИЗ ЖИВЫХ ЛОГОВ SING-BOX (LIVE LOG SCANNER)
# ====================================================================
echo -e "\n${C_CYAN}= 4. СКАНИРОВАНИЕ ЖИВЫХ ЛОГОВ (ОШИБКИ ТРАФИКА):${C_NONE}"
print_loading "Чтение системного журнала (logread)"
logread | grep "sing-box" | tail -n 100 > /tmp/singbox_logs.txt
clear_loading

ERR_REFUSED=$(grep "connection refused" /tmp/singbox_logs.txt | wc -l)
ERR_TIMEOUT=$(grep "i/o timeout" /tmp/singbox_logs.txt | wc -l)

if [ "$ERR_REFUSED" -eq 0 ] && [ "$ERR_TIMEOUT" -eq 0 ]; then
    echo -e "  ✅ ${C_GREEN}Ошибок трафика не обнаружено.${C_NONE} Пакеты идут стабильно."
else
    echo -e "  ⚠️  ${C_YELLOW}Обнаружены ошибки маршрутизации в реальном времени!${C_NONE}"
    
    if [ "$ERR_REFUSED" -gt 0 ]; then
        echo -e "  ❌ ${C_RED}Connection Refused ($ERR_REFUSED раз):${C_NONE}"
        echo -e "     ${C_CYAN}└ Что это значит:${C_NONE} Внутренний прокси-сервер (например, Opera-proxy) 'упал' или отклоняет подключения."
        echo -e "     ${C_CYAN}🛠 Как исправить:${C_NONE} Перезапустите службу в 'Система -> Загрузка'."
    fi
    
    if [ "$ERR_TIMEOUT" -gt 0 ]; then
        BAD_OUTS=$(grep "i/o timeout" /tmp/singbox_logs.txt | grep -o 'using outbound/[^:]*' | cut -d'[' -f2 | cut -d']' -f1 | sort | uniq)
        echo -e "  ❌ ${C_RED}I/O Timeout ($ERR_TIMEOUT раз):${C_NONE}"
        echo -e "     ${C_CYAN}└ Проблемные узлы:${C_NONE} ${C_YELLOW}$(echo $BAD_OUTS | tr '\n' ' ')${C_NONE}"
        echo -e "     ${C_CYAN}└ Что это значит:${C_NONE} Пакеты уходят в этот туннель, но теряются по пути. Сервер не отвечает."
        echo -e "     ${C_CYAN}🛠 Как исправить:${C_NONE} Для AWG2: снизьте MTU до 1280. Для Vless: блокировка провайдера (ТСПУ) или сервер недоступен."
    fi
fi
rm -f /tmp/singbox_logs.txt

# ====================================================================
# 5. ПРОВЕРКА НАСТРОЕК AMNEZIA WG / ЗАЦИКЛИВАНИЯ
# ====================================================================
echo -e "\n${C_CYAN}= 5. ПРОВЕРКА АНОМАЛИЙ VPN (AMNEZIA WG / WIREGUARD):${C_NONE}"
WG_IFACES=$(uci show network | grep -E "\.proto=" | grep -E "wireguard|amneziawg" | cut -d. -f2 | cut -d= -f1)

if [ -z "$WG_IFACES" ]; then
    echo -e "  ✅ ${C_GREEN}Интерфейсы WireGuard/AmneziaWG не настроены. Конфликтов нет.${C_NONE}"
else
    ENDPOINTS=""
    VPN_ERRORS=0

    for IFACE in $WG_IFACES; do
        PEERS=$(uci show network | grep -E "=(wireguard|amneziawg)_$IFACE" | cut -d. -f2 | cut -d= -f1 | sort -u)
        for PEER in $PEERS; do
            ROUTE_ALLOWED=$(uci -q get network.$PEER.route_allowed_ips)
            ENDPOINT=$(uci -q get network.$PEER.endpoint_host)
            [ -n "$ENDPOINT" ] && ENDPOINTS="$ENDPOINTS $ENDPOINT"

            if [ "$ROUTE_ALLOWED" = "1" ]; then
                 echo -e "  ❌ ${C_RED}ОБНАРУЖЕН ПАРАЗИТНЫЙ МАРШРУТ на интерфейсе $IFACE!${C_NONE}"
                 echo -e "     ${C_YELLOW}⚡ В один клик:${C_NONE} uci set network.$PEER.route_allowed_ips='0' && uci commit network && /etc/init.d/network restart"
                 VPN_ERRORS=1
            fi
        done
    done

    UNIQUE_IPS=$(echo "$ENDPOINTS" | tr ' ' '\n' | grep -v '^$' | sort -u)
    for IP in $UNIQUE_IPS; do
        print_loading "Проверка зацикливания ($IP)"
        if ! echo "$IP" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
            RESOLVED=$(ping -c 1 "$IP" 2>/dev/null | awk -F '[()]' '/PING/{print $2}')
            [ -n "$RESOLVED" ] && IP="$RESOLVED"
        fi
        clear_loading
        
        [ -z "$IP" ] && continue
        ROUTE_DEV=$(ip route get "$IP" 2>/dev/null | head -n1 | grep -oE 'dev [a-zA-Z0-9_-]+' | awk '{print $2}')
        if echo "$ROUTE_DEV" | grep -qE "^(tun|wg|awg|sing|podkop|zeroblock)"; then
            echo -e "  ❌ ${C_RED}КРИТИЧЕСКАЯ ОШИБКА: Зацикливание трафика (Routing Loop)!${C_NONE}"
            echo -e "     ${C_CYAN}🛠 Как исправить:${C_NONE} В настройках Подкопа добавьте IP: ${C_YELLOW}$IP${C_NONE} в раздел 'Исключения'."
            VPN_ERRORS=1
        fi
    done
    
    if [ "$VPN_ERRORS" -eq 0 ]; then
        echo -e "  ✅ ${C_GREEN}Зацикливаний и паразитных маршрутов не обнаружено.${C_NONE}"
    fi
fi

# ====================================================================
# 6. ЧЕКЛИСТ КОНЕЧНОГО УСТРОЙСТВА
# ====================================================================
echo -e "\n${C_CYAN}= 6. ЧЕКЛИСТ КОНЕЧНОГО УСТРОЙСТВА (ПК / Смартфон):${C_NONE}"
echo -e "  💡 ${C_YELLOW}Если все тесты зеленые (✅), но сайты не открываются:${C_NONE}"
echo -e "     1. ${C_CYAN}Чужой VPN:${C_NONE} Выключите все VPN (AdGuard, Outline) на телефоне/ПК."
echo -e "     2. ${C_CYAN}Безопасный DNS:${C_NONE} В браузере (Chrome/Edge) выключите 'Безопасный DNS' (DoH)."
echo -e "     3. ${C_CYAN}Кэш ПК:${C_NONE} На Windows нажмите Win+R -> cmd -> ${C_GREEN}ipconfig /flushdns${C_NONE}"

# ====================================================================
# 7. РАСХОД ТРАФИКА И НАГРУЗКА
# ====================================================================
echo -e "\n${C_CYAN}= 7. СИСТЕМА, НАГРУЗКА И ТРАФИК:${C_NONE}"

if command -v vnstat >/dev/null 2>&1; then
    WAN_DEV=$(ip route show default 2>/dev/null | grep -oE 'dev [a-zA-Z0-9_-]+' | head -n1 | awk '{print $2}')
    [ -z "$WAN_DEV" ] && WAN_DEV=$(uci -q get network.wan.device)
    if [ -n "$WAN_DEV" ]; then
        echo -e "  📊 Расход интернета на интерфейсе ($WAN_DEV):"
        vnstat -i "$WAN_DEV" -m 2>/dev/null | grep -E "(month|20[0-9]{2}-)" | tail -n 3 | sed 's/^/     /'
        echo "  ---"
    fi
fi

UPTIME=$(awk '{print int($1/86400)"д "int(($1%86400)/3600)"ч "int(($1%3600)/60)"м"}' /proc/uptime)
CPU_LOAD=$(uptime | awk -F'load average:' '{ print $2 }' | cut -d, -f1 | tr -d ' ')

TEMP_C="Нет датчика"
if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
    TEMP_C="$(( $(cat /sys/class/thermal/thermal_zone0/temp) / 1000 ))°C"
fi

RAM_TOTAL=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
RAM_FREE=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
if [ -n "$RAM_TOTAL" ] && [ "$RAM_TOTAL" -gt 0 ] 2>/dev/null; then
    RAM_USED_PCT=$(( 100 - (RAM_FREE * 100 / RAM_TOTAL) ))
else
    RAM_USED_PCT="N/A"
fi
NAND_INFO=$(df -h / | awk '$NF=="/"{printf "%s занято", $5}')

echo -e "  Время работы: $UPTIME | Нагрузка ЦП: $CPU_LOAD | Температура: $TEMP_C"
echo -e "  Оперативная память: $RAM_USED_PCT% | Внутренняя память (NAND): $NAND_INFO"

if command -v iwinfo >/dev/null 2>&1; then
    WIFI_IFACES=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2}')
    if [ -n "$WIFI_IFACES" ]; then
        echo -e "  ---"
        for wiface in $WIFI_IFACES; do
            if ip link show $wiface 2>/dev/null | grep -q "UP"; then
                SSID=$(iwinfo $wiface info 2>/dev/null | grep ESSID | cut -d'"' -f2)
                CLIENTS=$(iwinfo $wiface assoclist 2>/dev/null | grep -E "^[0-9A-F:]+" | wc -l)
                echo -e "  📡 Беспроводная сеть [${C_YELLOW}${SSID:-Скрытая}${C_NONE}]: подключено активных устройств: ${C_CYAN}$CLIENTS шт.${C_NONE}"
            fi
        done
    fi
fi

echo -e "\n${C_GREEN}--- ДИАГНОСТИКА ЗАВЕРШЕНА ---${C_NONE}\n"