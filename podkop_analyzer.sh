#!/bin/sh
# RouteRich Ultimate Analyzer v23 (API Speed & Deep Troubleshooting Engine)

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
PODKOP_RUN=0; ZEROBLOCK_RUN=0

for srv in $SERVICES; do
    if [ -f "/etc/init.d/$srv" ]; then
        VER=$(get_ver "$srv")
        /etc/init.d/$srv enabled 2>/dev/null && ENAB="${C_GREEN}ВКЛ${C_NONE}" || ENAB="${C_RED}ВЫКЛ${C_NONE}"
        
        if /etc/init.d/$srv status 2>/dev/null | grep -q "running"; then
            [ "$srv" = "podkop" ] && PODKOP_RUN=1
            [ "$srv" = "zeroblock" ] && ZEROBLOCK_RUN=1
            
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
    echo -e "     ${C_CYAN}└ Что это значит:${C_NONE} Обе системы пытаются управлять ядром sing-box. Это ломает маршрутизацию."
    echo -e "     ${C_CYAN}🛠 Как исправить:${C_NONE} Выберите только одну программу. В меню 'Система' -> 'Загрузка' вторую отключите."
fi

# ====================================================================
# 2. АНАЛИЗ DNS И FAKEDNS
# ====================================================================
echo -e "\n${C_CYAN}= 2. ПРОВЕРКА DNS И FAKEDNS (ПЕРЕХВАТ ТРАФИКА):${C_NONE}"
DNSMASQ_PORT=$(uci -q get dhcp.@dnsmasq[0].port || echo "53")

if [ "$DNSMASQ_PORT" = "53" ] && netstat -tulpn 2>/dev/null | grep -q ":53 .*sing-box"; then
    echo -e "  ❌ ${C_RED}КРИТИЧЕСКИЙ КОНФЛИКТ: Конфликт системных DNS-портов!${C_NONE}"
    echo -e "     ${C_CYAN}└ Что это значит:${C_NONE} Стандартный DNS роутера (dnsmasq) и Podkop пытаются занять порт 53."
    echo -e "     ${C_CYAN}🛠 Как исправить:${C_NONE}"
    echo -e "       1. Перейдите в 'Сеть' -> 'DHCP и DNS' -> вкладка 'Расширенные настройки'."
    echo -e "       2. Найдите поле 'Порт DNS-сервера', сотрите 53 и впишите ${C_YELLOW}5353${C_NONE}."
    echo -e "       3. Нажмите 'Сохранить и применить'."
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
    echo -e "     ${C_CYAN}└ Что это значит:${C_NONE} Роутер не смог подменить IP заблокированного сайта. Перехват не сработал."
    echo -e "     ${C_CYAN}🛠 Как исправить (Проверьте по порядку):${C_NONE}"
    echo -e "       1. В браузере (Chrome/Edge/Yandex) выключите «Безопасный DNS» (DoH/DoT) в настройках."
    echo -e "       2. Выключите VPN-приложения и AdBlock-клиенты на ПК/Телефоне."
    echo -e "       3. Очистите кэш DNS на роутере."
else
    echo -e "  ⚠️  ${C_YELLOW}Таймаут DNS.${C_NONE} Роутер вообще не может определить IP-адрес сайта. Проверьте кабель провайдера."
fi

# ====================================================================
# 3. СЕКЦИИ, СКОРОСТЬ (API) И РАССЛЕДОВАНИЕ
# ====================================================================
echo -e "\n${C_CYAN}= 3. АНАЛИЗ СЕКЦИЙ, СПИСКОВ И СКОРОСТИ СЕРВЕРОВ:${C_NONE}"
> /tmp/analyzer_items.txt

print_loading "Проверка провайдера"
WAN_PING=$(ping -c 1 -W 2 8.8.8.8 2>/dev/null | awk -F '/' '/round-trip/{print $4}')
clear_loading
if [ -n "$WAN_PING" ]; then
    echo -e "  🌐 Прямой интернет (Провайдер) -> Отклик: ${C_GREEN}${WAN_PING} мс${C_NONE}"
else
    echo -e "  ❌ Прямой интернет -> ${C_RED}Нет связи${C_NONE} (Интернет отсутствует)"
fi
echo "  ---"

check_sections_and_speed() {
    local APP=$1
    if ! uci -q get $APP.settings >/dev/null; then return; fi
    
    echo -e "  🔰 Анализ конфигурации [${C_YELLOW}$APP${C_NONE}]:"
    SECTIONS=$(uci show $APP 2>/dev/null | grep "=section" | cut -d. -f2 | cut -d= -f1)
    
    for sec in $SECTIONS; do
        print_loading "Опрос секции $sec"
        
        # 1. ГАРАНТИРОВАННЫЙ СБОР СПИСКОВ
        L_RAW="$(uci -q get $APP.$sec.list)"
        D_RAW="$(uci -q get $APP.$sec.domain)"
        RULES=$(uci show $APP 2>/dev/null | grep "\.outbound='$sec'" | cut -d. -f2 | sort -u)
        for r in $RULES; do
            L_RAW="$L_RAW $(uci -q get $APP.$r.list)"
            D_RAW="$D_RAW $(uci -q get $APP.$r.domain)"
        done
        
        L_STR=$(echo "$L_RAW" | tr ' ' '\n' | grep -v '^$' | sort -u | tr '\n' ',' | sed 's/,$//; s/,/, /g')
        D_STR=$(echo "$D_RAW" | tr ' ' '\n' | grep -v '^$' | sort -u | tr '\n' ',' | sed 's/,$//; s/,/, /g')
        ALL_ITEMS=""
        [ -n "$L_STR" ] && ALL_ITEMS="Списки: $L_STR "
        [ -n "$D_STR" ] && ALL_ITEMS="${ALL_ITEMS}Домены: $D_STR"
        [ -z "$ALL_ITEMS" ] && ALL_ITEMS="пусто (трафик не назначен)"
        
        for i in $(echo "$L_RAW" | tr ' ' '\n' | grep -v '^$'); do echo "Список:$i:$APP->$sec" >> /tmp/analyzer_items.txt; done
        for d in $(echo "$D_RAW" | tr ' ' '\n' | grep -v '^$'); do echo "Домен:$d:$APP->$sec" >> /tmp/analyzer_items.txt; done

        # 2. ОПРЕДЕЛЕНИЕ ТЕГА ДЛЯ API
        OUTBOUND=$(uci -q get $APP.$sec.outbound || uci -q get $APP.$sec.proxy_config_type)
        [ -z "$OUTBOUND" ] && OUTBOUND="$sec"
        OUTBOUND=$(echo "$OUTBOUND" | tr -d '\n\r ')

        # 3. ТОЧНЫЙ ЗАМЕР ЗАДЕРЖКИ (SING-BOX API)
        DELAY=""
        API_PORT=$(uci -q get $APP.settings.api_port || echo "9090")
        API_URL="http://127.0.0.1:${API_PORT}/proxies/${OUTBOUND}/delay?url=http://cp.cloudflare.com/generate_204&timeout=3000"
        
        if command -v curl >/dev/null 2>&1; then
            API_RES=$(curl -s "$API_URL")
            DELAY=$(echo "$API_RES" | grep -o '"delay":[0-9]*' | cut -d: -f2)
        elif command -v wget >/dev/null 2>&1; then
            API_RES=$(wget -qO- "$API_URL" 2>/dev/null)
            DELAY=$(echo "$API_RES" | grep -o '"delay":[0-9]*' | cut -d: -f2)
        fi

        # Если API не ответил, но это интерфейс (awg10) - пробуем пинг системы
        if [ -z "$DELAY" ] && ip link show "$OUTBOUND" >/dev/null 2>&1; then
            RES=$(ping -I "$OUTBOUND" -c 1 -W 2 8.8.8.8 2>/dev/null | awk -F '/' '/round-trip/{print $4}')
            [ -n "$RES" ] && DELAY="$RES"
        fi

        clear_loading
        
        # 4. ВЫВОД И МОДУЛЬ РАССЛЕДОВАНИЯ
        if [ -n "$DELAY" ] && [ "$DELAY" != "0" ]; then
            echo -e "  ✅ [${C_CYAN}$sec${C_NONE}] -> Тег: ${C_YELLOW}$OUTBOUND${C_NONE} | Отклик: ${C_GREEN}${DELAY} мс${C_NONE}"
            echo -e "     └ Содержит: ${C_YELLOW}$ALL_ITEMS${C_NONE}"
        else
            echo -e "  ❌ [${C_CYAN}$sec${C_NONE}] -> ${C_RED}Таймаут / Не отвечает${C_NONE} (Туннель '$OUTBOUND' упал)"
            
            # --- START TROUBLESHOOTING ENGINE ---
            if ip link show "$OUTBOUND" >/dev/null 2>&1; then
                # Логика для WireGuard / AWG
                if command -v wg >/dev/null 2>&1; then
                    HS=$(wg show "$OUTBOUND" latest-handshakes 2>/dev/null | awk '{print $2}')
                    NOW=$(date +%s)
                    if [ -z "$HS" ] || [ "$HS" -eq 0 ]; then
                        echo -e "     ${C_CYAN}🔍 Расследование:${C_NONE} Нет 'рукопожатия' (Handshake) с сервером. Интерфейс поднят, но связи нет."
                        echo -e "     ${C_CYAN}🛠 Как исправить:${C_NONE} 1. Провайдер блокирует протокол (ТСПУ). 2. Неверные ключи. Попробуйте обновить конфигурацию."
                    elif [ $((NOW - HS)) -gt 180 ]; then
                        echo -e "     ${C_CYAN}🔍 Расследование:${C_NONE} Соединение было потеряно $((NOW - HS)) сек. назад."
                        echo -e "     ${C_CYAN}🛠 Как исправить:${C_NONE} Сервер VPN недоступен или выключен. Проверьте оплату VPS."
                    else
                        echo -e "     ${C_CYAN}🔍 Расследование:${C_NONE} Рукопожатие активно, но интернет через туннель не идет."
                        echo -e "     ${C_CYAN}🛠 Как исправить:${C_NONE} Возможна проблема с MTU (попробуйте 1280) или не работает NAT на стороне сервера."
                    fi
                fi
            else
                # Логика для VLESS / Shadowsocks / Прокси
                SRV_IP=$(uci -q get $APP.$sec.server || uci -q get $APP.$sec.address)
                if [ -n "$SRV_IP" ] && [ "$SRV_IP" != "127.0.0.1" ]; then
                    RES=$(ping -c 1 -W 2 "$SRV_IP" 2>/dev/null | awk -F '/' '/round-trip/{print $4}')
                    if [ -n "$RES" ]; then
                        echo -e "     ${C_CYAN}🔍 Расследование:${C_NONE} Сервер ($SRV_IP) пингуется (${RES} мс), но сам прокси не принимает соединения."
                        echo -e "     ${C_CYAN}🛠 Как исправить:${C_NONE} 1. Заблокирован порт прокси. 2. Ошибка в UUID или ключах. Обновите подписку."
                    else
                        echo -e "     ${C_CYAN}🔍 Расследование:${C_NONE} Сервер ($SRV_IP) полностью недоступен (не отвечает на ping)."
                        echo -e "     ${C_CYAN}🛠 Как исправить:${C_NONE} Сервер выключен, либо его IP забанен РКН. Замените сервер или IP."
                    fi
                else
                    echo -e "     ${C_CYAN}🔍 Расследование:${C_NONE} Ядро sing-box не смогло пустить трафик через узел '$OUTBOUND'."
                    echo -e "     ${C_CYAN}🛠 Как исправить:${C_NONE} Убедитесь, что сервер/подписка в секции $sec работает и оплачена."
                fi
            fi
            # --- END TROUBLESHOOTING ENGINE ---
            
            echo -e "     └ Содержит: ${C_YELLOW}$ALL_ITEMS${C_NONE}"
        fi
    done
}

check_sections_and_speed "podkop"
check_sections_and_speed "zeroblock"

echo "  ---"
DUPS=$(awk -F':' '{print $1":"$2}' /tmp/analyzer_items.txt | sort | uniq -d)
if [ -n "$DUPS" ]; then
    echo -e "  ❌ ${C_RED}КОНФЛИКТ В СПИСКАХ: Найдено дублирование сайтов/списков!${C_NONE}"
    for dup in $DUPS; do
        TYPE=$(echo "$dup" | cut -d: -f1)
        VAL=$(echo "$dup" | cut -d: -f2)
        IN_SECS=$(grep "^$dup:" /tmp/analyzer_items.txt | cut -d':' -f3 | sort -u | tr '\n' ' ' | sed 's/ $//')
        SEC_COUNT=$(echo "$IN_SECS" | wc -w)
        if [ "$SEC_COUNT" -gt 1 ]; then
            echo -e "       -> $TYPE ${C_RED}'$VAL'${C_NONE} добавлен сразу в: [ ${C_YELLOW}$IN_SECS${C_NONE} ]"
        fi
    done
    echo -e "     ${C_CYAN}└ Что это значит:${C_NONE} Ядро не понимает, в какой туннель отправлять трафик, т.к. сайт указан в двух местах."
    echo -e "     ${C_CYAN}🛠 Как исправить:${C_NONE} Удалите дубликаты. Один домен/список должен находиться строго в одной секции."
else
    echo -e "  ✅ ${C_GREEN}Пересечений нет:${C_NONE} Списки маршрутизации чисты и не конфликтуют."
fi

# ====================================================================
# 4. ПРОВЕРКА НАСТРОЕК AMNEZIA WG / ЗАЦИКЛИВАНИЯ
# ====================================================================
WG_IFACES=$(uci show network | grep -E "\.proto=" | grep -E "wireguard|amneziawg" | cut -d. -f2 | cut -d= -f1)
ENDPOINTS=""
LOOP_FOUND=0

if [ -n "$WG_IFACES" ]; then
    echo -e "\n${C_CYAN}= 4. ПРОВЕРКА АНОМАЛИЙ VPN (AMNEZIA WG / WIREGUARD):${C_NONE}"
    for IFACE in $WG_IFACES; do
        PEERS=$(uci show network | grep -E "=(wireguard|amneziawg)_$IFACE" | cut -d. -f2 | cut -d= -f1 | sort -u)
        for PEER in $PEERS; do
            ROUTE_ALLOWED=$(uci -q get network.$PEER.route_allowed_ips)
            ENDPOINT=$(uci -q get network.$PEER.endpoint_host)
            [ -n "$ENDPOINT" ] && ENDPOINTS="$ENDPOINTS $ENDPOINT"

            if [ "$ROUTE_ALLOWED" = "1" ] || [ -z "$ROUTE_ALLOWED" ]; then
                 echo -e "  ❌ ${C_RED}ПАРАЗИТНЫЙ МАРШРУТ на интерфейсе $IFACE!${C_NONE}"
                 echo -e "     ${C_CYAN}└ Что это значит:${C_NONE} Неправильная настройка VPN перехватывает весь трафик роутера мимо Подкопа."
                 echo -e "     ${C_CYAN}🛠 Как исправить:${C_NONE}"
                 echo -e "       1. Зайдите в 'Сеть' -> 'Интерфейсы'."
                 echo -e "       2. Нажмите 'Изменить' у интерфейса $IFACE."
                 echo -e "       3. Перейдите во вкладку 'Равноправные узлы' (Peers) -> Изменить."
                 echo -e "       4. Снимите галочку 'Маршрутизировать разрешённые IP' и сохраните."
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
            echo -e "  ❌ ${C_RED}ЗАЦИКЛИВАНИЕ ТРАФИКА! VPN-сервер ($IP) блокирует сам себя.${C_NONE}"
            echo -e "     ${C_CYAN}└ Что это значит:${C_NONE} Роутер пытается пустить шифрованный трафик внутрь самого себя. Интернет ляжет."
            echo -e "     ${C_CYAN}🛠 Как исправить:${C_NONE} Откройте меню Подкопа и добавьте IP ${C_YELLOW}$IP${C_NONE} в раздел 'Исключения' (Bypass)."
            LOOP_FOUND=1
        fi
    done
    [ "$LOOP_FOUND" -eq 0 ] && echo -e "  ✅ Зацикливаний трафика (Routing Loops) не обнаружено."
fi

# ====================================================================
# 5. ЧЕКЛИСТ КОНЕЧНОГО УСТРОЙСТВА
# ====================================================================
echo -e "\n${C_CYAN}= 5. ЧЕКЛИСТ КОНЕЧНОГО УСТРОЙСТВА (ПК / Смартфон):${C_NONE}"
echo -e "  💡 ${C_YELLOW}Если тесты роутера выше зеленые (✅), но сайты у вас не открываются, проверьте:${C_NONE}"
echo -e "     1. ${C_CYAN}Чужой VPN на устройстве:${C_NONE} Выключите все VPN-приложения (AdGuard VPN, Nord, Outline) на телефоне или ПК."
echo -e "        └ Они полностью перехватывают трафик до того, как он дойдет до роутера."
echo -e "     2. ${C_CYAN}Безопасный DNS (DoH/DoT):${C_NONE} В браузерах Chrome/Edge часто по умолчанию включен скрытый DNS."
echo -e "        └ Зайдите в настройки браузера -> Конфиденциальность -> Безопасный DNS -> ВЫКЛЮЧИТЬ."
echo -e "     3. ${C_CYAN}Кэш системы:${C_NONE} Нажмите Win+R, введите cmd и выполните команду: ipconfig /flushdns"

# ====================================================================
# 6. РАСХОД ТРАФИКА И НАГРУЗКА
# ====================================================================
echo -e "\n${C_CYAN}= 6. СИСТЕМА, НАГРУЗКА И ТРАФИК:${C_NONE}"

if command -v vnstat >/dev/null 2>&1; then
    WAN_DEV=$(ip route show default 2>/dev/null | grep -oE 'dev [a-zA-Z0-9_-]+' | head -n1 | awk '{print $2}')
    [ -z "$WAN_DEV" ] && WAN_DEV=$(uci -q get network.wan.device)
    if [ -n "$WAN_DEV" ]; then
        echo -e "  📊 Трафик на интерфейсе провайдера ($WAN_DEV):"
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

echo -e "  Время работы: $UPTIME | Процессор: $CPU_LOAD | Температура: $TEMP_C"
echo -e "  Оперативная память: $RAM_USED_PCT% | Внутренняя память: $NAND_INFO"

if command -v iwinfo >/dev/null 2>&1; then
    WIFI_IFACES=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2}')
    if [ -n "$WIFI_IFACES" ]; then
        echo -e "  ---"
        for wiface in $WIFI_IFACES; do
            if ip link show $wiface 2>/dev/null | grep -q "UP"; then
                SSID=$(iwinfo $wiface info 2>/dev/null | grep ESSID | cut -d'"' -f2)
                CLIENTS=$(iwinfo $wiface assoclist 2>/dev/null | grep -E "^[0-9A-F:]+" | wc -l)
                echo -e "  📡 Wi-Fi [${C_YELLOW}${SSID:-Скрытая}${C_NONE}]: ${C_CYAN}$CLIENTS${C_NONE} устройств подключено."
            fi
        done
    fi
fi

echo -e "\n${C_GREEN}--- ДИАГНОСТИКА ЗАВЕРШЕНА ---${C_NONE}\n"