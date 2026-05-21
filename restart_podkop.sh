#!/bin/sh
# Скрипт очистки кэша DNS и безопасного перезапуска Подкопа

C_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'
C_CYAN='\033[1;36m'
C_NONE='\033[0m'

echo -e "${C_CYAN}[+] Запущен процесс сброса сети и перезапуска служб...${C_NONE}"

# 1. Сброс кэша dnsmasq
echo -e "  -> Очистка системного кэша DNS (dnsmasq)..."
/etc/init.d/dnsmasq restart >/dev/null 2>&1

# 2. Перезапуск сетевого брандмауэра (сброс nftables)
echo -e "  -> Перезапуск брандмауэра для очистки правил nftables..."
/etc/init.d/firewall restart >/dev/null 2>&1

# 3. Чистый перезапуск Подкопа
echo -e "  -> Перезапуск службы Podkop (sing-box)..."
/etc/init.d/podkop restart >/dev/null 2>&1

echo -e "${C_GREEN}[+] Готово! Кэш DNS очищен, Подкоп успешно перезапущен.${C_NONE}\n"