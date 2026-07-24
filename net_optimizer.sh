#!/bin/sh
# Скрипт оптимизации сети (TCP TW Reuse и Drop Invalid)

C_CYAN='\033[1;36m'
C_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[1;31m'
C_NONE='\033[0m'

echo -e "\n${C_CYAN}==================================================${C_NONE}"
echo -e "${C_YELLOW}⚙️  Настройка оптимизации сети (tcp_tw_reuse и drop_invalid)...${C_NONE}"

# Проверяем текущее состояние в фаерволе
STATE=$(uci -q get firewall.@defaults[0].drop_invalid)

if [ "$STATE" = "1" ]; then
    echo -e "  -> Текущий статус: ${C_GREEN}ВКЛЮЧЕНО${C_NONE}. Выполняем отключение (Откат)..."
    
    # 1. Отключаем TCP TW Reuse
    sed -i '/^net.ipv4.tcp_tw_reuse\s*=/d' /etc/sysctl.conf
    echo "net.ipv4.tcp_tw_reuse = 2" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1
    
    # 2. Отключаем Drop Invalid
    uci delete firewall.@defaults[0].drop_invalid
    uci commit firewall
    
    echo -e "  -> Перезапуск фаервола..."
    /etc/init.d/firewall reload >/dev/null 2>&1
    
    echo -e "${C_GREEN}[+] Готово! Оптимизация успешно отключена.${C_NONE}"
else
    echo -e "  -> Текущий статус: ${C_RED}ВЫКЛЮЧЕНО${C_NONE}. Выполняем включение (Применение)..."
    
    # 1. Включаем TCP TW Reuse
    sed -i '/^net.ipv4.tcp_tw_reuse\s*=/d' /etc/sysctl.conf
    echo "net.ipv4.tcp_tw_reuse = 1" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1
    
    # 2. Включаем Drop Invalid
    uci set firewall.@defaults[0].drop_invalid=1
    uci commit firewall
    
    echo -e "  -> Перезапуск фаервола..."
    /etc/init.d/firewall reload >/dev/null 2>&1
    
    echo -e "${C_GREEN}[+] Готово! Оптимизация успешно включена.${C_NONE}"
fi
echo -e "${C_CYAN}==================================================${C_NONE}\n"