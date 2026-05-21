#!/bin/sh
# RouteRich Ultimate Analyzer v23 (API Speed Fixed & Comprehensive Manual)

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
    echo -e "     ${C_CYAN}└ Что это значит:${C_NONE} Обе системы пытаются одновременно управлять одним и тем же ядром sing-box. Это полностью ломает логику маршрутов, интернет работать не будет."
    echo -e "     ${C_CYAN}🛠 Как исправить:${C_NONE} Перейдите в меню роутера: 'Система' -> 'Загрузка'. Выберите одну из программ, нажмите кнопку 'Стоп', а затем кнопку 'Отключить' (чтобы она не запускалась сама при перезагрузке)."
fi

# ====================================================================
# 2. АНАЛИЗ DNS И FAKEDNS
# ====================================================================
echo -e "\n${C_CYAN}= 2. ПРОВЕРКА DNS И FAKEDNS (ПЕРЕХВАТ ТРАФИКА):${C_NONE}"
DNSMASQ_PORT=$(uci -q get dhcp.@dnsmasq[0].port || echo "53")

if [ "$DNSMASQ_PORT" = "53" ] && netstat -tulpn 2>/dev/null | grep -q ":53 .*sing-box"; then
    echo -e "  ❌ ${C_RED}КРИТИЧЕСКИЙ КОНФЛИКТ: Конфликт системных DNS-портов!${C_NONE}"
    echo -e "     ${C_CYAN}└ Что это значит:${C_NONE} Стандартная служба DNS роутера (dnsmasq) и модуль Подкопа пытаются одновременно занять порт 53. Из-за этого перехват сайтов ломается."
    echo -e "     ${C_CYAN}🛠 Как исправить:${C_NONE}"
    echo -e "       1. Откройте веб-интерфейс роутера в браузере."
    echo -e "       2. Перейдите в верхнем меню: 'Сеть' -> 'DHCP и DNS'."
    echo -e "       3. Откройте вкладку 'Расширенные настройки'."
    echo -e "       4. Найдите строку 'Порт DNS-сервера', сотрите там цифру 53 и впишите ${C_YELLOW}5353${C_NONE}."
    echo -e "       5. В самом низу страницы нажмите кнопку 'Сохранить и применить'."
else
    echo -e "  ✅ Конфликтов системных DNS-портов не обнаружено."
fi

print_loading "Проверка подмены DNS (Тест FakeDNS)"
FB_IP=$(ping -c 1 facebook.com 2>/dev/null | awk -F '[()]' '/PING/{print $2}')
clear_loading

if echo "$FB_IP" | grep -qE "^198\.18\."; then
    echo -e "  ✅ ${C_GREEN}FakeDNS работает отлично!${C_NONE} Заблокированный сайт успешно получил виртуальный IP-адрес ($FB_IP) и направлен в туннель обхода."
elif [ -n "$FB_IP" ]; then
    echo -e "  ❌ ${C_RED}СБОЙ СИСТЕМЫ FAKEDNS:${C_NONE} Заблокированный сайт получил настоящий IP-адрес ($FB_IP). Трафик пойдет напрямую через провайдера и сайт не откроется."
    echo -e "     ${C_CYAN}└ Что это значит:${C_NONE} Роутер не смог подменить IP-адрес сайта. Скорее всего, запрос ушел мимо Подкопа."
    echo -e "     ${C_CYAN}🛠 Как исправить (Проверьте три фактора):${C_NONE}"
    echo -e "       1. В настройках вашего браузера (Chrome, Яндекс, Edge) зайдите в Безопасность и полностью ВЫКЛЮЧИТЕ функцию «Безопасный DNS» (DoH)."
    echo -e "       2. Выключите любые VPN-расширения или блокировщики рекламы на компьютере/телефоне (они крадут DNS-запросы у роутера)."
    echo -e "       3. Очистите кэш DNS (выберите пункт 2 в главном меню нашего скрипта на роутере)."
else
    echo -e "  ⚠️  ${C_YELLOW}Таймаут DNS.${C_NONE} Роутер вообще не смог определить IP-адрес сайта. Проверьте, есть ли базовый интернет от провайдера."
fi

# ====================================================================
# 3. СЕКЦИИ, СПИСКИ И АВТО-ОПРЕДЕЛЕНИЕ СКОРОСТИ
# ====================================================================
echo -e "\n${C_CYAN}= 3. АНАЛИЗ СЕКЦИЙ, СПИСКОВ И СКОРОСТИ СЕРВЕРОВ:${C_NONE}"
> /tmp/analyzer_items.txt

print_loading "Проверка связи с провайдером"
WAN_PING=$(ping -c 1 -W 2 8.8.8.8 2>/dev/null | awk -F '/' '/round-trip/{print $4}')
clear_loading
if [ -n "$WAN_PING" ]; then
    echo -e "  🌐 Прямой интернет (Провайдер) -> Отклик: ${C_GREEN}${WAN_PING} мс${C_NONE}"
else
    echo -e "  ❌ Прямой интернет -> ${C_RED}Нет связи${C_NONE} (Базовый интернет от провайдера отсутствует!)"
fi
echo "  ---"

check_sections_and_speed() {
    local APP=$1
    if ! uci -q get $APP.settings >/dev/null; then return; fi
    
    echo -e "  🔰 Считывание конфигурации [${C_YELLOW}$APP${C_NONE}]:"
    
    # 1. Получаем список всех активных технических ТЕГОВ из ядра sing-box
    API_PORT=$(uci -q get $APP.settings.api_port || echo "9090")
    API_PROXIES=$(curl -s "http://127.0.0.1:${API_PORT}/proxies")
    ALL_TAGS=$(echo "$API_PROXIES" | grep -oE '"name":"[^"]+"' | cut -d'"' -f4 | grep -vE '^(GLOBAL|COMPATIBLE)$' | sort -u)
    
    SECTIONS=$(uci show $APP 2>/dev/null | grep "=section" | cut -d. -f2 | cut -d= -f1)
    
    for sec in $SECTIONS; do
        print_loading "Тестирование секции $sec"
        
        # 2. ПОИСК АКТУАЛЬНОГО ТЕГА ДЛЯ ТЕКУЩЕЙ СЕКЦИИ (Умное сопоставление)
        TARGET_TAG=""
        for t in $ALL_TAGS; do
            t_low=$(echo "$t" | tr 'A-Z' 'a-z' | tr -d '0-9_-')
            sec_low=$(echo "$sec" | tr 'A-Z' 'a-z' | tr -d '0-9_-')
            
            if [ "$(echo "$sec" | tr 'A-Z' 'a-z')" = "main" ] && echo "$t" | grep -qE "http|main|proxy"; then
                TARGET_TAG="$t"
                break
            elif [ "$(echo "$sec" | tr 'A-Z' 'a-z')" != "main" ] && { echo "$t_low" | grep -q "$sec_low" || echo "$sec_low" | grep -q "$t_low"; }; then
                TARGET_TAG="$t"
                break
            fi
        done
        
        # Если совпадений нет, берем имя секции как запасной вариант
        [ -z "$TARGET_TAG" ] && TARGET_TAG="$sec"

        # 3. ПОЛНЫЙ И ГАРАНТИРОВАННЫЙ СБОР СПИСКОВ САЙТОВ
        L_RAW="$(uci -q get $APP.$sec.list)"
        D_RAW="$(uci -q get $APP.$sec.domain)"
        RULES=$(uci show $APP 2>/dev/null | grep -E "=rule|=policy" | cut -d. -f2 | cut -d= -f1)
        for r in $RULES; do
            R_OUT=$(uci -q get $APP.$r.outbound)
            if [ "$R_OUT" = "$sec" ] || [ "$R_OUT" = "$TARGET_TAG" ]; then
                L_RAW="$L_RAW $(uci -q get $APP.$r.list)"
                D_RAW="$D_RAW $(uci -q get $APP.$r.domain)"
            fi
        done
        
        L_STR=$(echo "$L_RAW" | tr ' ' '\n' | grep -v '^$' | sort -u | tr '\n' ',' | sed 's/,$//; s/,/, /g')
        D_STR=$(echo "$D_RAW" | tr ' ' '\n' | grep -v '^$' | sort -u | tr '\n' ',' | sed 's/,$//; s/,/, /g')
        ALL_ITEMS=""
        [ -n "$L_STR" ] && ALL_ITEMS="Списки: $L_STR "
        [ -n "$D_STR" ] && ALL_ITEMS="${ALL_ITEMS}Домены: $D_STR"
        [ -z "$ALL_ITEMS" ] && ALL_ITEMS="пусто (правила маршрутизации не заданы)"
        
        for i in $(echo "$L_RAW" | tr ' ' '\n' | grep -v '^$'); do echo "Список:$i:$APP->$sec" >> /tmp/analyzer_items.txt; done
        for d in $(echo "$D_RAW" | tr ' ' '\n' | grep -v '^$'); do echo "Домен:$d:$APP->$sec" >> /tmp/analyzer_items.txt; done

        # 4. ЗАМЕР ЗАДЕРЖКИ ЧЕРЕЗ API ПО ЧИСТОМУ HTTP (КАК НА ДАШБОРДЕ)
        DELAY=""
        API_URL="http://127.0.0.1:${API_PORT}/proxies/${TARGET_TAG}/delay?url=http://cp.cloudflare.com/generate_204&timeout=2500"
        
        API_RES=$(curl -s "$API_URL")
        [ -z "$API_RES" ] && API_RES=$(wget -qO- "$API_URL" 2>/dev/null)
        
        if echo "$API_RES" | grep -q '"delay"'; then
            DELAY=$(echo "$API_RES" | grep -o '"delay":[0-9]*' | cut -d: -f2)
        fi

        clear_loading
        
        # 5. ВЫВОД СКОРОСТИ И МОДУЛЬ РАССЛЕДОВАНИЯ ПРИЧИН
        if [ -n "$DELAY" ] && [ "$DELAY" != "0" ]; then
            echo -e "  ✅ [${C_CYAN}$sec${C_NONE}] -> Отклик: ${C_GREEN}${DELAY} мс${C_NONE} (Узел: $TARGET_TAG)"
            echo -e "     └ Направлено: ${C_YELLOW}$ALL_ITEMS${C_NONE}"
        else
            echo -e "  ❌ [${C_CYAN}$sec${C_NONE}] -> ${C_RED}Таймаут / Не отвечает${C_NONE} (Узел: $TARGET_TAG)"
            
            # --- СТАРТ МОДУЛЯ ГЛУБОКОГО РАССЛЕДОВАНИЯ ---
            if ip link show "$TARGET_TAG" >/dev/null 2>&1; then
                # Если узел является сетевым интерфейсом (AWG / WireGuard)
                if command -v wg >/dev/null 2>&1; then
                    HS=$(wg show "$TARGET_TAG" latest-handshakes 2>/dev/null | awk '{print $2}')
                    NOW=$(date +%s)
                    if [ -z "$HS" ] || [ "$HS" -eq 0 ]; then
                        echo -e "     ${C_CYAN}🔍 Расследование:${C_NONE} Интерфейс $TARGET_TAG поднят, но сетевой обмен (Handshake) отсутствует."
                        echo -e "     ${C_CYAN}🛠 Как исправить:${C_NONE} 1. Ваш провайдер заблокировал протокол WireGuard (работа ТСПУ/РКН). 2. Допущена ошибка в ключах (Private/Public Key). Проверьте настройки туннеля."
                    elif [ $((NOW - HS)) -gt 150 ]; then
                        echo -e "     ${C_CYAN}🔍 Расследование:${C_NONE} Сессия была активна, но потеряна $((NOW - HS)) сек. назад."
                        echo -e "     ${C_CYAN}🛠 Как исправить:${C_NONE} Сервер VPN перестал отвечать. Проверьте, оплачен ли ваш VPS, или попробуйте сменить порт в настройках."
                    else
                        echo -e "     ${C_CYAN}🔍 Расследование:${C_NONE} Связь с VPN-сервером есть (Handshake активен), но данные через него не идут."
                        echo -e "     ${C_CYAN}🛠 Как исправить:${C_NONE} Проблема с размером пакета. Перейдите в настройки интерфейса $TARGET_TAG и установите значение MTU на ${C_YELLOW}1280${C_NONE} или ${C_YELLOW}1420${C_NONE}."
                    fi
                fi
            else
                # Если узел — прокси-протокол (Vless, Shadowsocks, Mimo)
                SRV_IP=$(uci -q get $APP.$sec.server || uci -q get $APP.$sec.address)
                if [ -n "$SRV_IP" ] && [ "$SRV_IP" != "127.0.0.1" ]; then
                    RES=$(ping -c 1 -W 2 "$SRV_IP" 2>/dev/null | awk -F '/' '/round-trip/{print $4}')
                    if [ -n "$RES" ]; then
                        echo -e "     ${C_CYAN}🔍 Расследование:${C_NONE} Сам удаленный сервер ($SRV_IP) в сети и пингуется за ${RES} мс. Но ядро sing-box не может установить с ним прокси-соединение."
                        echo -e "     ${C_CYAN}🛠 Как исправить:${C_NONE} Допущена ошибка в личных ключах шифрования (UUID, Public Key, Short ID) или провайдер заблокировал конкретный порт прокси. Обновите конфигурацию ключей."
                    else
                        echo -e "     ${C_CYAN}🔍 Расследование:${C_NONE} Удаленный сервер ($SRV_IP) полностью недоступен по сети (не отвечает на ping)."
                        echo -e "     ${C_CYAN}🛠 Как исправить:${C_NONE} 1. IP-адрес вашего сервера заблокирован Роскомнадзором наглухо (по IP). 2. Ваш VPS-сервер выключен за неуплату. Проверьте личный кабинет хостинга."
                    fi
                else
                    echo -e "     ${C_CYAN}🔍 Расследование:${C_NONE} Ядро sing-box не смогло запустить тест для узла '$TARGET_TAG'."
                    echo -e "     ${C_CYAN}🛠 Как исправить:${C_NONE} Убедитесь, что служба Подкопа включена, а конфигурация внутри вкладки 'Секции' заполнена без пропусков."
                fi
            fi
            # --- КОНЕЦ МОДУЛЯ РАССЛЕДОВАНИЯ ---
            
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
    for dup in $DUPS; do
        TYPE=$(echo "$dup" | cut -d: -f1)
        VAL=$(echo "$dup" | cut -d: -f2)
        IN_SECS=$(grep "^$dup:" /tmp/analyzer_items.txt | cut -d':' -f3 | sort -u | tr '\n' ' ' | sed 's/ $//')
        SEC_COUNT=$(echo "$IN_SECS" | wc -w)
        if [ "$SEC_COUNT" -gt 1 ]; then
            echo -e "       -> $TYPE ${C_RED}'$VAL'${C_NONE} добавлен сразу в: [ ${C_YELLOW}$IN_SECS${C_NONE} ]"
        fi
    done
    echo -e "     ${C_CYAN}└ Что это значит:${C_NONE} Система не понимает, через какой именно туннель открывать сайт, так как он прописан в разных секциях."
    echo -e "     ${C_CYAN}🛠 Как исправить:${C_NONE} Удалите дубликаты. Один домен или список должен находиться строго в одной секции обхода."
else
    echo -e "  ✅ ${C_GREEN}Пересечений нет:${C_NONE} Списки маршрутизации чисты и не содержат перекрестных конфликтов."
fi

# ====================================================================
# 4. ПРОВЕРКА НАСТРОЕК AMNEZIA WG / WIREGUARD
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
                 echo -e "  ❌ ${C_RED}ОБНАРУЖЕН ПАРАЗИТНЫЙ МАРШРУТ на интерфейсе $IFACE!${C_NONE}"
                 echo -e "     ${C_CYAN}└ Что это значит:${C_NONE} Включенная системная галочка заставляет WireGuard перехватывать ВЕСЬ трафик роутера, ломая умную маршрутизацию Подкопа."
                 echo -e "     ${C_CYAN}🛠 Как исправить:${C_NONE}"
                 echo -e "       1. Перейдите в меню роутера: 'Сеть' -> 'Интерфейсы'."
                 echo -e "       2. Нажмите кнопку 'Изменить' напротив интерфейса $IFACE."
                 echo -e "       3. Откройте вкладку 'Равноправные узлы' (Peers) и нажмите 'Изменить' на вашем пире."
                 echo -e "       4. Снимите галочку с пункта 'Маршрутизировать разрешённые IP-адреса' (Route Allowed IPs)."
                 echo -e "       5. Сохраните настройки и нажмите 'Сохранить и применить'."
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
            echo -e "  ❌ ${C_RED}КРИТИЧЕСКАЯ ОШИБКА: Зацикливание трафика (Routing Loop)!${C_NONE}"
            echo -e "     ${C_CYAN}└ Что это значит:${C_NONE} Роутер пытается подключиться к вашему VPN-серверу ($IP) ЧЕРЕЗ сам этот же VPN-сервер. Происходит бесконечный цикл и интернет полностью падает."
            echo -e "     ${C_CYAN}🛠 Как исправить:${C_NONE} Откройте настройки Подкопа (или Zeroblock). Перейдите в раздел 'Исключения' (Bypass) и внесите туда IP-адрес вашего сервера: ${C_YELLOW}$IP${C_NONE}, чтобы роутер подключался к нему напрямую через провайдера."
            LOOP_FOUND=1
        fi
    done
    [ "$LOOP_FOUND" -eq 0 ] && echo -e "  ✅ Зацикливаний трафика (Routing Loops) не обнаружено."
fi

# ====================================================================
# 5. ЧЕКЛИСТ КОНЕЧНОГО УСТРОЙСТВА
# ====================================================================
echo -e "\n${C_CYAN}= 5. ЧЕКЛИСТ КОНЕЧНОГО УСТРОЙСТВА (ПК / Смартфон):${C_NONE}"
echo -e "  💡 ${C_YELLOW}Если все тесты роутера выше зеленые (✅), но сайты на ПК/телефоне всё равно не открываются:${C_NONE}"
echo -e "     1. ${C_CYAN}Включен сторонний VPN:${C_NONE} Полностью отключите любые VPN-приложения (AdGuard VPN, Nord, Outline, Browsec) на самом телефоне или компьютере."
echo -e "        └ Они полностью перехватывают сетевой поток внутри системы до того, как он успеет дойти до роутера и Подкопа."
echo -e "     2. ${C_CYAN}Безопасный DNS (DoH/DoT):${C_NONE} Браузеры часто отправляют DNS-запросы в шифрованном виде в обход роутера."
echo -e "        └ Зайдите в настройки браузера -> Конфиденциальность / Безопасность -> Найдите 'Безопасный DNS' -> Переключите в положение ВЫКЛЮЧИТЬ."
echo -e "     3. ${C_CYAN}Завис кэш компьютера:${C_NONE} Очистите локальную базу сетевых адресов. На Windows нажмите комбинацию кнопок Win+R, введите ${C_YELLOW}cmd${C_NONE}, нажмите Enter и выполните команду: ${C_GREEN}ipconfig /flushdns${C_NONE}"

# ====================================================================
# 6. РАСХОД ТРАФИКА И НАГРУЗКА
# ====================================================================
echo -e "\n${C_CYAN}= 6. СИСТЕМА, НАГРУЗКА И ТРАФИК:${C_NONE}"

if command -v vnstat >/dev/null 2>&1; then
    WAN_DEV=$(ip route show default 2>/dev/null | grep -oE 'dev [a-zA-Z0-9_-]+' | head -n1 | awk '{print $2}')
    [ -z "$WAN_DEV" ] && WAN_DEV=$(uci -q get network.wan.device)
    if [ -n "$WAN_DEV" ]; then
        echo -e "  📊 Расход интернета на главном интерфейсе ($WAN_DEV):"
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