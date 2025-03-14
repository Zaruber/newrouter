#!/bin/bash
# VLESS Router - Скрипт установки на роутер для Linux/macOS

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
        print_tip "- Для macOS: обычно SSH уже установлен, иначе установите через Homebrew"
        missing_tools=1
    fi
    
    # Проверка наличия SCP
    if ! command -v scp &> /dev/null; then
        print_error "Утилита SCP не найдена. Установите SCP (обычно поставляется с SSH):"
        print_tip "- Для Debian/Ubuntu: sudo apt-get install openssh-client"
        print_tip "- Для CentOS/RHEL: sudo yum install openssh-clients"
        print_tip "- Для macOS: обычно SCP уже установлен, иначе установите через Homebrew"
        missing_tools=1
    fi
    
    # Проверка наличия nc (netcat) для диагностики
    if ! command -v nc &> /dev/null; then
        print_error "Утилита netcat (nc) не найдена. Установите netcat для расширенной диагностики:"
        print_tip "- Для Debian/Ubuntu: sudo apt-get install netcat"
        print_tip "- Для CentOS/RHEL: sudo yum install nc"
        print_tip "- Для macOS: brew install netcat"
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

# Функция проверки наличия необходимых пакетов на роутере
check_router_packages() {
    local router_ip=$1
    local user=$2
    local port=$3
    local password=$4
    local missing_pkgs=0
    
    print_message "Проверка наличия необходимых пакетов на роутере..."
    
    # Список необходимых пакетов
    local required_pkgs=("curl" "uhttpd" "uhttpd-mod-ubus" "iptables" "ip6tables")
    
    for pkg in "${required_pkgs[@]}"; do
        print_message "Проверка пакета $pkg..."
        
        if [ -n "$password" ]; then
            sshpass -p "$password" ssh -p "$port" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$user@$router_ip" "opkg list-installed | grep '^$pkg '" > /dev/null 2>&1
        else
            ssh -p "$port" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$user@$router_ip" "opkg list-installed | grep '^$pkg '" > /dev/null 2>&1
        fi
        
        if [ $? -ne 0 ]; then
            print_error "Пакет $pkg не установлен на роутере."
            missing_pkgs=1
        fi
    done
    
    if [ $missing_pkgs -eq 1 ]; then
        print_message "Установка отсутствующих пакетов на роутер..."
        
        if [ -n "$password" ]; then
            sshpass -p "$password" ssh -p "$port" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$user@$router_ip" "opkg update && opkg install curl uhttpd uhttpd-mod-ubus iptables ip6tables"
        else
            ssh -p "$port" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$user@$router_ip" "opkg update && opkg install curl uhttpd uhttpd-mod-ubus iptables ip6tables"
        fi
        
        if [ $? -ne 0 ]; then
            print_error "Не удалось установить необходимые пакеты на роутер."
            print_tip "Попробуйте установить пакеты вручную через SSH:"
            print_tip "  ssh $user@$router_ip -p $port"
            print_tip "  opkg update && opkg install curl uhttpd uhttpd-mod-ubus iptables ip6tables"
            return 1
        else
            print_success "Необходимые пакеты установлены на роутер."
            return 0
        fi
    else
        print_success "Все необходимые пакеты уже установлены на роутере."
        return 0
    fi
}

# Проверка наличия параметров
if [ $# -lt 1 ]; then
    print_message "Использование: $0 <IP-адрес роутера> [имя пользователя] [порт SSH] [пароль SSH]"
    print_message "Пример: $0 192.168.1.1 root 22 mypassword"
    print_message "Если вы уже настроили SSH-ключ, пароль можно не указывать."
    exit 1
fi

# Параметры подключения
ROUTER_IP="$1"
ROUTER_USER="${2:-root}"  # По умолчанию root
SSH_PORT="${3:-22}"       # По умолчанию порт 22
SSH_PASSWORD="$4"        # Пароль SSH (может быть пустым)

# Мастер установки - начало
print_message "==============================================================="
print_message "              VLESS Router - Мастер установки                 "
print_message "==============================================================="
print_message "Данный мастер поможет вам установить VLESS Router на ваш OpenWrt роутер."
print_message "IP роутера: $ROUTER_IP  Пользователь: $ROUTER_USER  Порт SSH: $SSH_PORT"
if [ -n "$SSH_PASSWORD" ]; then
    print_message "Для подключения будет использован пароль."
else
    print_message "Для подключения будет использован SSH-ключ (без пароля)."
fi
print_message "==============================================================="

# Проверка наличия базовых инструментов на локальной машине
check_required_tools
if [ $? -ne 0 ]; then
    print_error "Для продолжения установки необходимо установить недостающие утилиты."
    exit 1
fi

# Проверка наличия sshpass если указан пароль
if [ -n "$SSH_PASSWORD" ]; then
    if ! command -v sshpass &> /dev/null; then
        print_error "Для использования пароля требуется пакет 'sshpass'. Установите его:"
        print_message "  - Для Debian/Ubuntu: sudo apt-get install sshpass"
        print_message "  - Для CentOS/RHEL: sudo yum install sshpass"
        print_message "  - Для macOS: brew install hudochenkov/sshpass/sshpass"
        exit 1
    fi
    SSH_CMD="sshpass -p '$SSH_PASSWORD' ssh"
    SCP_CMD="sshpass -p '$SSH_PASSWORD' scp"
else
    SSH_CMD="ssh"
    SCP_CMD="scp"
fi

# Проверка возможности подключения к роутеру
print_message "Проверка подключения к роутеру $ROUTER_IP..."

# Включаем отладочный вывод SSH
print_message "Команда SSH будет выполнена в отладочном режиме для выявления проблемы..."
if [ -n "$SSH_PASSWORD" ]; then
    print_message "Используется аутентификация по паролю с sshpass"
    sshpass -v -p "$SSH_PASSWORD" ssh -vvv -p "$SSH_PORT" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$ROUTER_USER@$ROUTER_IP" "echo Тестовое подключение успешно" 2>&1 | tee /tmp/ssh_debug.log
    SSH_RESULT=$?
    print_message "Код возврата SSH: $SSH_RESULT"
    if [ -f /tmp/ssh_debug.log ]; then
        print_message "Последние 10 строк лога SSH:"
        tail -10 /tmp/ssh_debug.log
    fi
else
    print_message "Используется аутентификация по ключу"
    ssh -vvv -p "$SSH_PORT" -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=no "$ROUTER_USER@$ROUTER_IP" "echo Тестовое подключение успешно" 2>&1 | tee /tmp/ssh_debug.log
    SSH_RESULT=$?
    print_message "Код возврата SSH: $SSH_RESULT"
    if [ -f /tmp/ssh_debug.log ]; then
        print_message "Последние 10 строк лога SSH:"
        tail -10 /tmp/ssh_debug.log
    fi
fi

if [ $SSH_RESULT -ne 0 ]; then
    print_error "Не удалось подключиться к роутеру. Проверьте подключение и учетные данные."
    
    # Расширенная диагностика проблем подключения
    check_connection_problems "$ROUTER_IP" "$ROUTER_USER" "$SSH_PORT"
    print_tip "Если вы используете пароль, убедитесь, что он правильный."
    print_tip "Проверьте, что на роутере включен SSH (Система -> Администрирование -> Настройки SSH)."
    print_tip "Попробуйте ввести следующую команду вручную для проверки подключения:"
    print_tip "ssh -vvv $ROUTER_USER@$ROUTER_IP -p $SSH_PORT"
    print_tip "Если вы используете пароль и установили sshpass, попробуйте вручную:"
    print_tip "sshpass -p ВАШ_ПАРОЛЬ ssh $ROUTER_USER@$ROUTER_IP -p $SSH_PORT"
    
    # Проверка известных проблем с sshpass в зависимости от версии
    if [ -n "$SSH_PASSWORD" ]; then
        # Получение версии sshpass
        SSHPASS_VERSION=$(sshpass -V 2>&1 | head -1)
        print_message "Установленная версия sshpass: $SSHPASS_VERSION"
        print_tip "Некоторые версии sshpass могут иметь проблемы с паролями, содержащими специальные символы."
        print_tip "Попробуйте установить пароль без специальных символов или заменить пробелы на %20."
    fi
    
    exit 1
fi

print_success "Подключение к роутеру успешно."

# Проверка совместимости роутера с OpenWrt
check_openwrt_compatibility "$ROUTER_IP" "$ROUTER_USER" "$SSH_PORT" "$SSH_PASSWORD"
if [ $? -ne 0 ]; then
    print_error "Роутер не совместим с VLESS Router."
    exit 1
fi

# Проверка наличия необходимых пакетов на роутере
check_router_packages "$ROUTER_IP" "$ROUTER_USER" "$SSH_PORT" "$SSH_PASSWORD"
if [ $? -ne 0 ]; then
    print_error "Не все необходимые пакеты установлены на роутере."
    print_tip "Убедитесь, что роутер имеет доступ к интернету для установки пакетов."
    exit 1
fi

# Проверка подключения к интернету на роутере
print_message "Проверка наличия подключения к интернету на роутере..."
INTERNET_CHECK=$(ssh -p "$SSH_PORT" "$ROUTER_USER@$ROUTER_IP" "ping -c 1 8.8.8.8 > /dev/null 2>&1 && echo 1 || echo 0" 2>/dev/null)

if [ "$INTERNET_CHECK" -eq 1 ]; then
    print_success "Роутер имеет подключение к интернету."
else
    print_warning "Роутер не имеет подключения к интернету!"
    print_message "Для установки необходимых пакетов требуется интернет-соединение."
    print_message "Вы можете настроить подключение к интернету через:"
    print_tip "1. Веб-интерфейс OpenWrt (LuCI): http://$ROUTER_IP"
    print_tip "2. Подключением WAN-порта роутера к другому источнику интернета"
    print_tip "3. Настройкой Wi-Fi клиента для подключения к существующей сети"

    # Помощь в настройке Wi-Fi клиента, если роутер не подключен к интернету
    print_message "Хотите настроить подключение Wi-Fi клиента через этот скрипт? (y/n)"
    read -r setup_wifi

    if [ "$setup_wifi" = "y" ] || [ "$setup_wifi" = "Y" ]; then
        setup_wifi_client
    else
        print_message "Пожалуйста, настройте подключение к интернету на роутере и запустите скрипт повторно."
        print_tip "Для настройки через веб-интерфейс: откройте http://$ROUTER_IP в браузере и настройте подключение."
        print_message "После настройки подключения запустите скрипт повторно."
        exit 1
    fi

    # Повторная проверка подключения после настройки
    print_message "Проверка подключения к интернету после настройки..."
    INTERNET_CHECK=$(ssh -p "$SSH_PORT" "$ROUTER_USER@$ROUTER_IP" "ping -c 1 8.8.8.8 > /dev/null 2>&1 && echo 1 || echo 0" 2>/dev/null)

    if [ "$INTERNET_CHECK" -eq 1 ]; then
        print_success "Успешно! Роутер имеет подключение к интернету."
    else
        print_error "Не удалось настроить подключение к интернету. Пожалуйста, настройте соединение вручную и запустите скрипт повторно."
        exit 1
    fi
fi

# Копирование файлов проекта на роутер
print_message "Копирование файлов VLESS Router на роутер..."

# Создание директории на роутере
ssh -p "$SSH_PORT" "$ROUTER_USER@$ROUTER_IP" "mkdir -p /root/vless-router"

if [ $? -ne 0 ]; then
    print_error "Не удалось создать директорию на роутере."
    print_tip "Проверьте права доступа и свободное место на роутере."
    exit 1
fi

# Копирование файлов
current_dir=$(dirname "$0")
scp -P "$SSH_PORT" -r "$current_dir"/* "$ROUTER_USER@$ROUTER_IP:/root/vless-router/"

if [ $? -ne 0 ]; then
    print_error "Не удалось скопировать файлы на роутер."
    print_tip "Проверьте права доступа и свободное место на роутере."
    print_tip "Убедитесь, что вы находитесь в правильной директории проекта."
    exit 1
fi

print_success "Файлы успешно скопированы на роутер."

# Установка прав на исполнение скриптов
print_message "Настройка прав доступа..."

ssh -p "$SSH_PORT" "$ROUTER_USER@$ROUTER_IP" "chmod +x /root/vless-router/scripts/*.sh && chmod +x /root/vless-router/web/*.cgi"

if [ $? -ne 0 ]; then
    print_error "Не удалось установить права доступа на скрипты."
    print_tip "Проверьте права доступа и структуру директорий на роутере."
    exit 1
fi

print_success "Права доступа установлены."

# Запуск скрипта установки на роутере
print_message "Запуск скрипта установки на роутере..."
print_message "После завершения установки веб-интерфейс будет доступен по адресу: http://$ROUTER_IP:8080"

ssh -p "$SSH_PORT" "$ROUTER_USER@$ROUTER_IP" "/root/vless-router/scripts/setup.sh"

if [ $? -ne 0 ]; then
    print_error "Произошла ошибка при выполнении скрипта установки."
    print_tip "Проверьте логи на роутере: /root/vless-router/logs/install.log"
    print_tip "Также можно попробовать выполнить установку вручную:"
    print_tip "  ssh $ROUTER_USER@$ROUTER_IP -p $SSH_PORT"
    print_tip "  cd /root/vless-router && ./scripts/setup.sh"
    exit 1
fi

print_success "Установка VLESS Router завершена успешно!"
print_message "Откройте веб-браузер и перейдите по адресу: http://$ROUTER_IP:8080"
print_message "Следуйте инструкциям мастера настройки для завершения конфигурации."

# Проверка доступности веб-интерфейса
print_message "Проверка доступности веб-интерфейса..."
sleep 2
if command -v curl &> /dev/null; then
    curl -s --connect-timeout 5 http://$ROUTER_IP:8080 > /dev/null
    if [ $? -eq 0 ]; then
        print_success "Веб-интерфейс VLESS Router доступен по адресу: http://$ROUTER_IP:8080"
    else
        print_error "Веб-интерфейс не отвечает. Возможно, потребуется дополнительная настройка."
        print_tip "Убедитесь, что порт 8080 не блокируется брандмауэром."
        print_tip "Проверьте, что веб-сервер запущен на роутере."
    fi
fi

# Функция для настройки Wi-Fi клиента
setup_wifi_client() {
    print_message "===== Мастер настройки Wi-Fi клиента ====="
    print_message "Сканирование доступных Wi-Fi сетей..."
    
    # Сканирование и вывод списка доступных Wi-Fi сетей
    WIFI_LIST=$(ssh -p "$SSH_PORT" "$ROUTER_USER@$ROUTER_IP" "iwinfo | grep ESSID | cut -d\" -f2" 2>/dev/null)
    
    if [ -z "$WIFI_LIST" ]; then
        print_error "Не удалось получить список Wi-Fi сетей. Проверьте, включен ли Wi-Fi на роутере."
        print_tip "Вы можете настроить Wi-Fi через веб-интерфейс: http://$ROUTER_IP"
        return 1
    fi
    
    # Вывод списка сетей
    print_message "Доступные Wi-Fi сети:"
    i=1
    for network in $WIFI_LIST; do
        echo "$i. $network"
        i=$((i+1))
    done
    
    # Запрос SSID и пароля
    print_message "Введите SSID (имя) сети для подключения:"
    read -r wifi_ssid
    print_message "Введите пароль сети:"
    read -r wifi_password
    
    print_message "Настройка Wi-Fi клиента..."
    
    # Конфигурация Wi-Fi клиента на роутере
    ssh -p "$SSH_PORT" "$ROUTER_USER@$ROUTER_IP" "uci batch << EOF
    set wireless.sta=wifi-iface
    set wireless.sta.device=radio0
    set wireless.sta.mode=sta
    set wireless.sta.network=wwan
    set wireless.sta.ssid='$wifi_ssid'
    set wireless.sta.encryption=psk2
    set wireless.sta.key='$wifi_password'
    set network.wwan=interface
    set network.wwan.proto=dhcp
    commit wireless
    commit network
EOF

# Применение настроек
/etc/init.d/network restart
" 2>/dev/null
    
    print_message "Ожидание подключения Wi-Fi (это может занять до 30 секунд)..."
    sleep 30
    
    # Проверка успешного подключения
    WIFI_STATUS=$(ssh -p "$SSH_PORT" "$ROUTER_USER@$ROUTER_IP" "iwinfo | grep -A 5 $wifi_ssid | grep -c 'Status: Connected'" 2>/dev/null)
    
    if [ "$WIFI_STATUS" -ge 1 ]; then
        print_success "Wi-Fi успешно подключен к сети '$wifi_ssid'."
        return 0
    else
        print_error "Не удалось подключиться к Wi-Fi сети '$wifi_ssid'."
        print_tip "Проверьте правильность SSID и пароля."
        print_tip "Вы можете настроить Wi-Fi через веб-интерфейс: http://$ROUTER_IP"
        return 1
    fi
}
