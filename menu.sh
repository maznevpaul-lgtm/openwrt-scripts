#!/bin/sh
# Главное меню управления утилитами OpenWrt

C_CYAN='\033[1;36m'
C_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[1;31m'
C_NONE='\033[0m'

# !!! ОБЯЗАТЕЛЬНО УКАЖИ ЗДЕСЬ СВОЙ НИК И СВОЙ РЕПОЗИТОРИЙ (без слэша на конце) !!!
BASE_URL="https://raw.githubusercontent.com/ТВОЙ_НИК/ТВОЙ_РЕПОЗИТОРИЙ/main"

clear
echo -e "${C_CYAN}==================================================${C_NONE}"
echo -e "${C_GREEN}       УТИЛИТЫ ДЛЯ OPENWRT И ПОДКОПА (v1.1)       ${C_NONE}"
echo -e "${C_CYAN}==================================================${C_NONE}"
echo -e " 1) 🚀 Запустить Мега-Анализатор (Полная диагностика)"
echo -e " 2) 🧹 Очистить кэш DNS и перезапустить Подкоп"
echo -e " 3) 🔄 Обновить Подкоп (Официальный скрипт автора без сброса)"
echo -e " 0) ❌ Выход"
echo "--------------------------------------------------"
printf " Выбери действие (введи цифру и нажми Enter): "
read choice

case "$choice" in
    1)
        echo -e "\n${C_YELLOW}Запуск диагонстики всех туннелий и зацикливаний...${C_NONE}\n"
        sh <(wget -qO- "$BASE_URL/podkop_ultimate_analyzer.sh")
        ;;
    2)
        echo -e "\n${C_YELLOW}Очистка кэша DNS и перезапуск...${C_NONE}\n"
        sh <(wget -qO- "$BASE_URL/restart_podkop.sh")
        ;;
    3)
        echo -e "\n${C_YELLOW}Запуск официального обновления Подкопа от itdoginfo...${C_NONE}\n"
        # Вызов оригинального скрипта автора Подкопа
        sh <(wget -O - https://raw.githubusercontent.com/itdoginfo/podkop/refs/heads/main/install.sh)
        ;;
    4)
        echo -e "\n${C_YELLOW}Запуск диагностики от RouteRich...${C_NONE}\n"
        # Вызов оригинального скрипта автора Подкопа
        sh <(wget -qO- https://raw.githubusercontent.com/kkkkkCampbell/master/refs/heads/test_config_script/test_config_script_nightly)
        ;;
    0)
        echo -e "\nВыход. Удачи!\n"
        exit 0
        ;;
    *)
        echo -e "\n${C_RED}Ошибка: Неверный ввод!${C_NONE}\n"
        ;;
esac