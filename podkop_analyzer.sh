#!/bin/sh
# RouteRich Ultimate Analyzer v16 (Deep Scan & Conflict Resolution)

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
    [ -n "$ver" ] && echo "v$ver" || echo "Версия неизвестна"
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

# Сложный анализ конфликтов
if [ "$PODKOP_RUN" -eq 1 ] && [ "$ZEROBLOCK_RUN" -eq 1 ]; then
    echo -e "  ❌ ${C_RED}КРИТИЧЕСКИЙ КОНФЛИКТ: Запущены Podkop и Zeroblock одновременно!${C_NONE}"
    echo -e "     ${C_CYAN}└ Проблема:${C_NONE} Обе системы пытаются управлять sing-box. Маршрутизация полностью сломана."
    echo -e "     ${C_CYAN}🛠 Решение:${C_NONE} Выберите только одну службу. Вторую нужно остановить и отключить автозапуск."
fi

if { [ "$PODKOP_RUN" -eq 1 ] || [ "$ZEROBLOCK_RUN" -eq 1 ]; } && [ "$ZAPRET_RUN" -eq 1 ]; then
    echo -e "  ⚠️  ${C_YELLOW}РИСК КОНФЛИКТА ФАЕРВОЛА: Совместная работа (Podkop/Zeroblock + Zapret)${C_NONE}"
    echo -e "     ${C_CYAN}└ Проблема:${C_NONE} Обе программы используют nftables для перехвата пакетов. Запрет может 'красть' трафик у Подкопа."
    echo -e "     ${C_CYAN}🛠 Решение:${C_NONE} Если интернет работает нестабильно, убедитесь, что в настройках Zapret"
    echo -e "       (в файле конфигурации) интерфейс туннелей добавлен в исключения, либо выключите Zapret."
fi

# ====================================================================
# 2. АНАЛИЗ OPERA-PROXY И ЕГО ИНТЕГРАЦИИ
# ====================================================================
if [ "$OPERA_RUN" -eq 1 ]; then
    echo -e "\n${C_CYAN}= 2. ИНТЕГРАЦИЯ OPERA-PROXY:${C_NONE}"
    OPERA_PORT=$(netstat -tulpn 2>/dev/null | grep -iE 'opera|18080' | awk '{print $4}' | awk -F: '{print $NF}' | head -n 1)
    [ -z "$OPERA_PORT" ] && OPERA_PORT="18080"
    
    CONF_PATH=$(uci -q get podkop.settings.config_path || echo "/etc/sing-box/config.json")
    
    if grep -q "$OPERA_PORT" "$CONF_PATH" 2>/dev/null; then
        echo -e "  ✅ Подкоп знает об Opera-proxy (порт $OPERA_PORT интегрирован в конфиг)."
    else
        echo -e "  ❌ ${C_RED}Отсутствует интеграция:${C_NONE} Opera работает на порту $OPERA_PORT, но ядро sing-box туда ничего не отправляет."
        echo -e "     ${C_CYAN}🛠 Решение:${C_NONE} Проверьте настройки секции 'main' (или аналогичной) в Подкопе."
    fi
    
    if command -v curl >/dev/null 2>&1; then
        print_loading "Тест соединения через серверы Opera"
        HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}\n" -x http://127.0.0.1:$OPERA_PORT --connect-timeout 5 http://google.com)
        clear_loading
        if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
            echo -e "  ✅ Live Test: Серверы Opera успешно пропускают трафик (Код $HTTP_CODE)."
        else
            echo -e "  ⚠️  ${C_YELLOW}Live Test провален:${C_NONE} Opera-proxy не может достучаться до интернета. Серверы Opera могут лежать."
        fi
    fi
fi

# ====================================================================
# 3. АНАЛИЗ DNS И ПЕРЕХВАТА САЙТОВ
# ====================================================================
echo -e "\n${C_CYAN}= 3. ПРОВЕРКА DNS И FAKEDNS (ПЕРЕХВАТ ТРАФИКА):${C_NONE}"
DNSMASQ_PORT=$(uci -q get dhcp.@dnsmasq[0].port || echo "53")

if [ "$DNSMASQ_PORT" = "53" ] && netstat -tulpn 2>/dev/null | grep -q ":53 .*sing-box"; then
    echo -e "  ❌ ${C_RED}Критический конфликт DNS-портов!${C_NONE}"
    echo -e "     ${C_CYAN}🛠 Решение:${C_NONE} Перейдите в 'Сеть -> DHCP и DNS -> Расширенные настройки'."
    echo -e "       Измените 'Порт DNS-сервера' с 53 на 5353 и сохраните."
else
    echo -e "  ✅ Конфликтов системных DNS-портов не обнаружено."
fi

print_loading "Проверка подмены DNS (facebook.com)"
FB_IP=$(ping -c 1 facebook.com 2>/dev/null | awk -F '[()]' '/PING/{print $2}')
clear_loading

if echo "$FB_IP" | grep -qE "^198\.18\."; then
    echo -e "  ✅ ${C_GREEN}FakeDNS работает идеально!${C_NONE} Заблокированный сайт получил виртуальный IP ($FB_IP) и направлен в туннель."
elif [ -n "$FB_IP" ]; then
    echo -e "  ❌ ${C_RED}Сбой FakeDNS:${C_NONE} Сайт получил настоящий IP-адрес ($FB_IP). Трафик пойдет мимо обхода."
    echo -e "     ${C_CYAN}🛠 Возможные решения:${C_NONE}"
    echo -e "       1. В браузере включен «Безопасный DNS» (DoH/DoT) — отключите его."
    echo -e "       2. Сделайте сброс кэша DNS на роутере (пункт 2 в нашем меню)."
else
    echo -e "  ⚠️  ${C_YELLOW}Таймаут DNS.${C_NONE} Роутер вообще не может определить IP-адрес сайта."
fi

# ====================================================================
# 4. СЕКЦИИ, СПИСКИ И ДОСТУПНОСТЬ ТУННЕЛЕЙ
# ====================================================================
echo -e "\n${C_CYAN}= 4. КОНФИГУРАЦИЯ СЕКЦИЙ И РЕАЛЬНАЯ ДОСТУПНОСТЬ СЕРВЕРОВ:${C_NONE}"
> /tmp/analyzer_items.txt

print_loading "Проверка связи с провайдером"
WAN_PING=$(ping -c 1 -W 2 8.8.8.8 2>/dev/null | awk -F '/' '/round-trip/{print $4}')
clear_loading
if [ -n "$WAN_PING" ]; then
    echo -e "  🌐 Прямой интернет (Провайдер) -> Отклик: ${C_GREEN}${WAN_PING} мс${C_NONE}"
else
    echo -e "  ❌ Прямой интернет -> ${C_RED}Нет связи (Проверьте кабель/провайдера)${C_NONE}"
fi
echo "  ---"

CONF_PATH=$(uci -q get podkop.settings.config_path || echo "/etc/sing-box/config.json")

check_sections() {
    local APP=$1
    local SECTIONS=$(uci show $APP 2>/dev/null | grep "=section" | cut -d. -f2 | cut -d= -f1)
    
    for sec in $SECTIONS; do
        OUTBOUND=$(uci -q get $APP.$sec.outbound || uci -q get $APP.$sec.proxy_config_type)
        [ -z "$OUTBOUND" ] && OUTBOUND="$sec"
        
        LISTS=$(uci -q get $APP.$sec.list | tr ' ' ',')
        DOMS=$(uci -q get $APP.$sec.domain | tr ' ' ',')
        ALL_ITEMS=""
        [ -n "$LISTS" ] && ALL_ITEMS="${ALL_ITEMS}Списки: $LISTS "
        [ -n "$DOMS" ] && ALL_ITEMS="${ALL_ITEMS}Домены: $DOMS"
        [ -z "$ALL_ITEMS" ] && ALL_ITEMS="пусто"
        
        for item in $(uci -q get $APP.$sec.list 2>/dev/null); do echo "Список:$item:$APP->$sec" >> /tmp/analyzer_items.txt; done
        for item in $(uci -q get $APP.$sec.domain 2>/dev/null); do echo "Домен:$item:$APP->$sec" >> /tmp/analyzer_items.txt; done

        print_loading "Тестирование сервера $sec"
        PING_RES=""
        STATUS="📦"

        if ip link show "$OUTBOUND" >/dev/null 2>&1; then
            RES=$(ping -I "$OUTBOUND" -c 1 -W 2 8.8.8.8 2>/dev/null | awk -F '/' '/round-trip/{print $4}')
            if [ -n "$RES" ]; then
                STATUS="✅"; PING_RES="${C_GREEN}${RES} мс${C_NONE} [Интерфейс: $OUTBOUND]"
            else
                STATUS="❌"; PING_RES="${C_RED}Таймаут (Туннель упал!)${C_NONE} [Интерфейс: $OUTBOUND]"
            fi
        else
            SRV=$(grep -A 15 "\"tag\":\s*\"$OUTBOUND\"" "$CONF_PATH" 2>/dev/null | grep -m 1 "\"server\":" | awk -F'"' '{print $4}')
            [ -z "$SRV" ] && SRV=$(grep -A 15 "\"tag\":\s*\"$sec\"" "$CONF_PATH" 2>/dev/null | grep -m 1 "\"server\":" | awk -F'"' '{print $4}')
            
            if [ "$OUTBOUND" = "main" ] || [ "$sec" = "main" ]; then
                if netstat -tulpn 2>/dev/null | grep -q ":18080"; then
                    STATUS="✅"; PING_RES="${C_GREEN}Активен${C_NONE} [Локальный порт: 18080]"
                else
                    STATUS="❌"; PING_RES="${C_RED}Служба Opera-proxy недоступна${C_NONE}"
                fi
            elif [ -n "$SRV" ] && [ "$SRV" != "127.0.0.1" ]; then
                RES=$(ping -c 1 -W 2 "$SRV" 2>/dev/null | awk -F '/' '/round-trip/{print $4}')
                if [ -n "$RES" ]; then
                    STATUS="✅"; PING_RES="${C_GREEN}${RES} мс${C_NONE} [Сервер: $SRV]"
                else
                    STATUS="❌"; PING_RES="${C_RED}Сервер не отвечает!${C_NONE} (Заблокирован или не оплачен) [$SRV]"
                fi
            else
                STATUS="📦"; PING_RES="${C_YELLOW}Сложный/Внутренний прокси${C_NONE} [Тэг: $OUTBOUND]"
            fi
        fi

        clear_loading
        echo -e "  $STATUS [${C_CYAN}$sec${C_NONE}] -> Отклик: $PING_RES"
        echo -e "     └ Содержит: ${C_YELLOW}$ALL_ITEMS${C_NONE}"
    done
}

check_sections "podkop"
check_sections "zeroblock"

echo "  ---"
DUPS=$(awk -F':' '{print $1":"$2}' /tmp/analyzer_items.txt | sort | uniq -d)
if [ -n "$DUPS" ]; then
    echo -e "  ❌ ${C_RED}КОНФЛИКТ: Найдено дублирование сайтов/списков!${C_NONE}"
    for dup in $DUPS; do
        TYPE=$(echo "$dup" | cut -d: -f1)
        VAL=$(echo "$dup" | cut -d: -f2)
        IN_SECS=$(grep "^$dup:" /tmp/analyzer_items.txt | cut -d':' -f3 | sort -u | tr '\n' ' ' | sed 's/ $//')
        SEC_COUNT=$(echo "$IN_SECS" | wc -w)
        if [ "$SEC_COUNT" -gt 1 ]; then
            echo -e "       -> $TYPE ${C_RED}'$VAL'${C_NONE} добавлен сразу в: [ ${C_YELLOW}$IN_SECS${C_NONE} ]"
        fi
    done
    echo -e "     ${C_CYAN}🛠 Решение:${C_NONE} Один сайт должен лежать только в одной секции. Удалите лишнее в меню."
else
    echo -e "  ✅ ${C_GREEN}Пересечений нет:${C_NONE} Списки маршрутизации чисты."
fi

# ====================================================================
# 5. ПРОВЕРКА НАСТРОЕК AMNEZIA WG / ЗАЦИКЛИВАНИЯ
# ====================================================================
WG_IFACES=$(uci show network | grep -E "\.proto=" | grep -E "wireguard|amneziawg" | cut -d. -f2 | cut -d= -f1)
ENDPOINTS=""
LOOP_FOUND=0

if [ -n "$WG_IFACES" ]; then
    echo -e "\n${C_CYAN}= 5. ПРОВЕРКА АНОМАЛИЙ VPN (AMNEZIA WG / WIREGUARD):${C_NONE}"
    for IFACE in $WG_IFACES; do
        PEERS=$(uci show network | grep -E "=(wireguard|amneziawg)_$IFACE" | cut -d. -f2 | cut -d= -f1 | sort -u)
        for PEER in $PEERS; do
            ROUTE_ALLOWED=$(uci -q get network.$PEER.route_allowed_ips)
            ENDPOINT=$(uci -q get network.$PEER.endpoint_host)
            [ -n "$ENDPOINT" ] && ENDPOINTS="$ENDPOINTS $ENDPOINT"

            if [ "$ROUTE_ALLOWED" = "1" ] || [ -z "$ROUTE_ALLOWED" ]; then
                 echo -e "  ❌ ${C_RED}Паразитный маршрут на интерфейсе $IFACE!${C_NONE}"
                 echo -e "     ${C_CYAN}🛠 Решение:${C_NONE} Снимите галочку 'Маршрутизировать разрешённые IP' в настройках пира $IFACE."
            fi
        done
    done

    UNIQUE_IPS=$(echo "$ENDPOINTS" | tr ' ' '\n' | grep -v '^$' | sort -u)
    for IP in $UNIQUE_IPS; do
        print_loading "Проверка зацикливания маршрутов ($IP)"
        if ! echo "$IP" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
            RESOLVED=$(ping -c 1 "$IP" 2>/dev/null | awk -F '[()]' '/PING/{print $2}')
            [ -n "$RESOLVED" ] && IP="$RESOLVED"
        fi
        clear_loading
        
        [ -z "$IP" ] && continue

        ROUTE_DEV=$(ip route get "$IP" 2>/dev/null | head -n1 | grep -oE 'dev [a-zA-Z0-9_-]+' | awk '{print $2}')
        if echo "$ROUTE_DEV" | grep -qE "^(tun|wg|awg|sing|podkop|zeroblock)"; then
            echo -e "  ❌ ${C_RED}Зацикливание трафика! VPN-сервер ($IP) уходит сам в себя.${C_NONE}"
            echo -e "     ${C_CYAN}🛠 Решение:${C_NONE} Добавьте IP ${C_YELLOW}$IP${C_NONE} в раздел 'Исключения' (Bypass)."
            LOOP_FOUND=1
        fi
    done
    [ "$LOOP_FOUND" -eq 0 ] && echo -e "  ✅ Зацикливаний трафика (Routing Loops) не обнаружено."
fi

# ====================================================================
# 6. ВАЖНО: АНАЛИЗ ПРОБЛЕМ НА СТОРОНЕ ПК / КЛИЕНТА
# ====================================================================
echo -e "\n${C_CYAN}= 6. ЧЕКЛИСТ КОНЕЧНОГО УСТРОЙСТВА (ПК / Смартфон):${C_NONE}"
echo -e "  💡 ${C_YELLOW}Если тесты роутера выше зеленые (✅), но сайты у вас не открываются, проверьте:${C_NONE}"
echo -e "     1. ${C_CYAN}Чужой VPN на устройстве:${C_NONE} Выключите все VPN-приложения (AdGuard VPN, Nord, Outline) на телефоне или ПК."
echo -e "        └ Они полностью перехватывают трафик до того, как он дойдет до роутера и Подкопа."
echo -e "     2. ${C_CYAN}Безопасный DNS (DoH/DoT):${C_NONE} В браузерах Chrome/Edge часто по умолчанию включен скрытый DNS."
echo -e "        └ Зайдите в настройки браузера -> Конфиденциальность -> Безопасный DNS -> ВЫКЛЮЧИТЬ."
echo -e "     3. ${C_CYAN}Кэш системы:${C_NONE} Нажмите Win+R, введите cmd и выполните команду: ipconfig /flushdns"

# ====================================================================
# 7. РАСХОД ТРАФИКА ЗА МЕСЯЦ
# ====================================================================
if command -v vnstat >/dev/null 2>&1; then
    echo -e "\n${C_CYAN}= 7. СТАТИСТИКА РАСХОДА ИНТЕРНЕТА:${C_NONE}"
    WAN_DEV=$(ip route show default 2>/dev/null | grep -oE 'dev [a-zA-Z0-9_-]+' | head -n1 | awk '{print $2}')
    [ -z "$WAN_DEV" ] && WAN_DEV=$(uci -q get network.wan.device)
    if [ -n "$WAN_DEV" ]; then
        echo -e "  📊 Трафик на интерфейсе провайдера ($WAN_DEV):"
        vnstat -i "$WAN_DEV" -m 2>/dev/null | grep -E "(month|20[0-9]{2}-)" | tail -n 3 | sed 's/^/     /'
    fi
fi

# ====================================================================
# 8. НАГРУЗКА И WI-FI
# ====================================================================
echo -e "\n${C_CYAN}= 8. СИСТЕМА И НАГРУЗКА:${C_NONE}"
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