#!/bin/bash
# VLESS Router - Скрипт офлайн-установки на роутер для Linux

# Функция вывода сообщений
print_message() {
    echo -e "\e[1;34m[VLESS Router]\e[0m $1"
}

# Функция вывода ошибок
print_error() {
    echo -e "\e[1;31m[ОШИБКА]\e[0m $1"
}

# Функция вывода успешных сообщений
print_success() {
    echo -e "\e[1;32m[УСПЕХ]\e[0m $1"
}

# Функция вывода предупреждений
print_warning() {
    echo -e "\e[1;33m[ПРЕДУПРЕЖДЕНИЕ]\e[0m $1"
}

# Функция вывода подсказок/советов
print_tip() {
    echo -e "\e[1;33m[СОВЕТ]\e[0m $1"
}

# Функция диагностики подключения к роутеру
check_connection_problems() {
    local router_ip=$1
    local user=$2
    local port=$3
    
    print_message "Диагностика проблем подключения..."
    
    # Проверка связи с роутером через ping
    print_message "Проверка доступности роутера по IP $router_ip..."
    ping -c 2 $router_ip > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        print_error "Роутер недоступен по ping. Проверьте следующее:"
        print_tip "- Убедитесь, что вы подключены к сети Wi-Fi роутера или кабелем"
        print_tip "- Проверьте правильность IP-адреса роутера"
        print_tip "- Убедитесь, что роутер включен и работает"
        return 1
    else
        print_success "Роутер $router_ip доступен по ping."
    fi
    
    # Проверка доступности SSH порта
    print_message "Проверка доступности SSH порта $port на роутере..."
    nc -z -w 5 $router_ip $port > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        print_error "SSH порт $port на роутере $router_ip недоступен. Проверьте следующее:"
        print_tip "- Убедитесь, что на роутере включен и настроен SSH"
        print_tip "- Проверьте правильность порта SSH (обычно 22)"
        print_tip "- Возможно, в роутере блокируются SSH соединения (проверьте настройки брандмауэра)"
        return 1
    else
        print_success "SSH порт $port на роутере $router_ip доступен."
    fi
    
    return 0
}

# Функция проверки наличия необходимых утилит
check_required_tools() {
    local missing_tools=0
    
    print_message "Проверка наличия необходимых утилит..."
    
    # Проверка наличия SSH
    if ! command -v ssh &> /dev/null; then
        print_error "Утилита SSH не найдена. Установите SSH:"
        print_tip "- Для Debian/Ubuntu: sudo apt-get install openssh-client"
        print_tip "- Для CentOS/RHEL: sudo yum install openssh-clients"
        print_tip "- Для Arch Linux: sudo pacman -S openssh"
        missing_tools=1
    fi
    
    # Проверка наличия SCP
    if ! command -v scp &> /dev/null; then
        print_error "Утилита SCP не найдена. Установите SCP (обычно поставляется с SSH):"
        print_tip "- Для Debian/Ubuntu: sudo apt-get install openssh-client"
        print_tip "- Для CentOS/RHEL: sudo yum install openssh-clients"
        print_tip "- Для Arch Linux: sudo pacman -S openssh"
        missing_tools=1
    fi
    
    # Проверка наличия nc (netcat) для диагностики
    if ! command -v nc &> /dev/null; then
        print_error "Утилита netcat (nc) не найдена. Установите netcat для расширенной диагностики:"
        print_tip "- Для Debian/Ubuntu: sudo apt-get install netcat"
        print_tip "- Для CentOS/RHEL: sudo yum install nc"
        print_tip "- Для Arch Linux: sudo pacman -S openbsd-netcat"
        missing_tools=1
    fi
    
    if [ $missing_tools -eq 1 ]; then
        return 1
    else
        print_success "Все необходимые утилиты найдены."
        return 0
    fi
}

# Функция проверки роутера на совместимость с OpenWrt
check_openwrt_compatibility() {
    local router_ip=$1
    local user=$2
    local port=$3
    local password=$4
    local ssh_cmd=""
    
    if [ -n "$password" ]; then
        ssh_cmd="sshpass -p '$password' ssh -p '$port' -o ConnectTimeout=5 -o StrictHostKeyChecking=no '$user@$router_ip'"
    else
        ssh_cmd="ssh -p '$port' -o ConnectTimeout=5 -o StrictHostKeyChecking=no '$user@$router_ip'"
    fi
    
    print_message "Проверка совместимости роутера с OpenWrt..."
    
    # Проверяем наличие файла /etc/openwrt_release
    if [ -n "$password" ]; then
        sshpass -p "$password" ssh -p "$port" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$user@$router_ip" "ls /etc/openwrt_release" > /dev/null 2>&1
    else
        ssh -p "$port" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$user@$router_ip" "ls /etc/openwrt_release" > /dev/null 2>&1
    fi
    
    if [ $? -ne 0 ]; then
        print_error "Не обнаружена система OpenWrt на роутере."
        print_tip "VLESS Router требует роутер с установленной системой OpenWrt."
        print_tip "Если у вас установлен OpenWrt, проверьте учетные данные SSH."
        return 1
    else
        # Проверяем версию OpenWrt
        if [ -n "$password" ]; then
            OPENWRT_VERSION=$(sshpass -p "$password" ssh -p "$port" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$user@$router_ip" "cat /etc/openwrt_release | grep DISTRIB_RELEASE | cut -d \"'\" -f 2")
        else
            OPENWRT_VERSION=$(ssh -p "$port" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$user@$router_ip" "cat /etc/openwrt_release | grep DISTRIB_RELEASE | cut -d \"'\" -f 2")
        fi
        
        print_success "Обнаружена система OpenWrt версии $OPENWRT_VERSION."
        return 0
    fi
}

# Функция для создания пакетов для офлайн-установки
create_offline_packages() {
    local router_ip=$1
    local user=$2
    local port=$3
    local password=$4
    local ssh_cmd=""
    local scp_cmd=""
    
    if [ -n "$password" ]; then
        ssh_cmd="sshpass -p '$password' ssh -p '$port' -o ConnectTimeout=5 -o StrictHostKeyChecking=no '$user@$router_ip'"
        scp_cmd="sshpass -p '$password' scp -P '$port' -o ConnectTimeout=5 -o StrictHostKeyChecking=no"
    else
        ssh_cmd="ssh -p '$port' -o ConnectTimeout=5 -o StrictHostKeyChecking=no '$user@$router_ip'"
        scp_cmd="scp -P '$port' -o ConnectTimeout=5 -o StrictHostKeyChecking=no"
    fi
    
    print_message "Подготовка пакетов для офлайн-установки..."
    
    # Создаем временную директорию для пакетов
    mkdir -p ./offline_packages
    
    # Список необходимых пакетов
    local packages=("curl" "uhttpd" "uhttpd-mod-ubus" "iptables" "ip6tables" "xray-core" "luci-app-xray")
    
    # Проверяем наличие интернета на локальной машине
    ping -c 1 8.8.8.8 > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        print_error "Нет подключения к интернету на локальной машине."
        print_tip "Для создания офлайн-пакетов требуется интернет-соединение на локальной машине."
        return 1
    fi
    
    # Получаем архитектуру роутера
    local arch=$(eval "$ssh_cmd \"uname -m\"")
    print_message "Архитектура роутера: $arch"
    
    # Получаем версию OpenWrt
    local version=$(eval "$ssh_cmd \"cat /etc/openwrt_release | grep DISTRIB_RELEASE | cut -d \\\"'\\\" -f 2\"")
    print_message "Версия OpenWrt: $version"
    
    # Создаем скрипт для установки пакетов на роутере
    cat > ./offline_packages/install_packages.sh << EOF
#!/bin/sh

# Скрипт установки офлайн-пакетов
echo "Установка офлайн-пакетов..."

# Создаем директорию для пакетов
mkdir -p /tmp/offline_packages

# Устанавливаем пакеты
cd /tmp/offline_packages
for pkg in *.ipk; do
    echo "Установка $pkg..."
    opkg install $pkg
done

echo "Установка пакетов завершена."
EOF
    
    # Скачиваем пакеты
    print_message "Скачивание пакетов для архитектуры $arch..."
    
    # Создаем временный скрипт для скачивания пакетов
    cat > ./download_packages.sh << EOF
#!/bin/bash

# Скрипт для скачивания пакетов OpenWrt
PACKAGES="${packages[*]}"
ARCH="$arch"
VERSION="$version"

# Репозитории OpenWrt
REPOS=(
    "http://downloads.openwrt.org/releases/$VERSION/packages/$ARCH/base"
    "http://downloads.openwrt.org/releases/$VERSION/packages/$ARCH/packages"
    "http://downloads.openwrt.org/releases/$VERSION/packages/$ARCH/luci"
    "http://downloads.openwrt.org/releases/$VERSION/packages/$ARCH/routing"
    "http://downloads.openwrt.org/releases/$VERSION/packages/$ARCH/telephony"
)

for pkg in $PACKAGES; do
    found=0
    for repo in "${REPOS[@]}"; do
        echo "Поиск $pkg в $repo..."
        pkg_file=$(curl -s $repo/Packages | grep -A 10 "Package: $pkg" | grep "Filename:" | head -1 | awk '{print $2}')
        if [ -n "$pkg_file" ]; then
            echo "Найден пакет $pkg: $pkg_file"
            wget -q -O "./offline_packages/$(basename $pkg_file)" "$repo/$pkg_file"
            if [ $? -eq 0 ]; then
                echo "Скачан пакет $pkg"
                found=1
                break
            fi
        fi
    done
    
    if [ $found -eq 0 ]; then
        echo "Не удалось найти пакет $pkg"
    fi
done
EOF
    
    # Делаем скрипт исполняемым
    chmod +x ./download_packages.sh
    
    # Запускаем скрипт скачивания
    ./download_packages.sh
    
    # Удаляем временный скрипт
    rm ./download_packages.sh
    
    # Проверяем, что пакеты скачаны
    local pkg_count=$(ls -1 ./offline_packages/*.ipk 2>/dev/null | wc -l)
    if [ "$pkg_count" -eq 0 ]; then
        print_error "Не удалось скачать пакеты для офлайн-установки."
        return 1
    fi
    
    print_success "Скачано $pkg_count пакетов для офлайн-установки."
    return 0
}

# Функция для настройки Wi-Fi клиента
setup_wifi_client() {
    local router_ip=$1
    local user=$2
    local port=$3
    local password=$4
    local ssh_cmd=""
    
    if [ -n "$passwor