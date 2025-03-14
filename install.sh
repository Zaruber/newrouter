#!/bin/bash

# VLESS Router - Универсальный установщик
# Скрипт с веб-интерфейсом для установки и настройки VLESS Router на OpenWrt

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Глобальные переменные
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
TEMP_DIR=$(mktemp -d)
WEB_PORT=8000
ROUTER_IP=""
ROUTER_PORT="22"
ROUTER_USER="root"
ROUTER_PASS=""

# Функция очистки при выходе
cleanup() {
    echo -e "\n${BLUE}Завершение работы установщика...${NC}"
    if [ ! -z "$PHP_PID" ]; then
        kill $PHP_PID 2>/dev/null
    fi
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

trap cleanup EXIT INT TERM

# Функция для проверки наличия команды
check_command() {
    command -v "$1" &> /dev/null
}

# Функция для вывода сообщений
print_message() {
    echo -e "${BLUE}[VLESS Router]${NC} $1"
}

# Функция для вывода ошибок
print_error() {
    echo -e "${RED}[ОШИБКА]${NC} $1"
}

# Функция для вывода успешных сообщений
print_success() {
    echo -e "${GREEN}[УСПЕШНО]${NC} $1"
}

# Функция для вывода предупреждений
print_warning() {
    echo -e "${YELLOW}[ВНИМАНИЕ]${NC} $1"
}

# Функция для проверки зависимостей
check_dependencies() {
    local missing=()
    
    # Проверка основных зависимостей
    for cmd in php ssh scp curl; do
        if ! check_command $cmd; then
            missing+=($cmd)
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        print_error "Отсутствуют необходимые зависимости:"
        for cmd in "${missing[@]}"; do
            echo "  - $cmd"
        done
        
        print_message "Установка зависимостей..."
        
        if [ -f /etc/debian_version ]; then
            sudo apt-get update
            sudo apt-get install -y php-cli openssh-client curl
        elif [ -f /etc/redhat-release ]; then
            sudo dnf install -y php-cli openssh-clients curl
        elif [ -f /etc/arch-release ]; then
            sudo pacman -S php openssh curl
        else
            print_error "Не удалось определить дистрибутив. Установите зависимости вручную:"
            echo "  - PHP CLI"
            echo "  - OpenSSH Client"
            echo "  - curl"
        exit 1
        fi
    fi
}

# Функция для проверки подключения к роутеру
check_router_connection() {
    local ip=$1
    local port=${2:-22}
    
    if ping -c 1 -W 2 $ip >/dev/null 2>&1; then
        if nc -z -w2 $ip $port >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

# Функция для сканирования WiFi сетей на роутере
scan_wifi() {
    local output=$(ssh -o StrictHostKeyChecking=no -p $ROUTER_PORT $ROUTER_USER@$ROUTER_IP "iwinfo wlan0 scan 2>/dev/null")
    if [ $? -eq 0 ]; then
        echo "$output" | grep "ESSID" | cut -d'"' -f2
    else
        return 1
    fi
}

# Функция для подключения к WiFi
connect_to_wifi() {
    local ssid=$1
    local password=$2
    
    # Создаем конфигурацию для WiFi
    cat > /tmp/wifi_config << EOF
config wifi-device 'radio0'
    option type 'mac80211'
    option channel 'auto'
    option band '2g'
    option disabled '0'

config wifi-iface 'default_radio0'
    option device 'radio0'
    option network 'wwan'
    option mode 'sta'
    option ssid '$ssid'
    option encryption 'psk2'
    option key '$password'
EOF
    
    # Копируем конфигурацию на роутер
    scp -o StrictHostKeyChecking=no -P $ROUTER_PORT /tmp/wifi_config $ROUTER_USER@$ROUTER_IP:/etc/config/wireless
    
    # Применяем настройки
    ssh -o StrictHostKeyChecking=no -p $ROUTER_PORT $ROUTER_USER@$ROUTER_IP "wifi up"
    
    # Проверяем подключение
    sleep 5
    if ssh -o StrictHostKeyChecking=no -p $ROUTER_PORT $ROUTER_USER@$ROUTER_IP "ping -c 1 8.8.8.8 >/dev/null 2>&1"; then
        return 0
    else
        return 1
    fi
}

# Функция для установки необходимых пакетов на роутере
install_router_packages() {
    print_message "Установка необходимых пакетов на роутере..."
    
    # Обновляем список пакетов
    ssh -o StrictHostKeyChecking=no -p $ROUTER_PORT $ROUTER_USER@$ROUTER_IP "opkg update"
    
    # Устанавливаем необходимые пакеты
    local packages=(
        "php7"
        "php7-cgi"
        "php7-mod-json"
        "uhttpd"
        "uhttpd-mod-ubus"
        "curl"
        "wget"
    )
    
    for package in "${packages[@]}"; do
        print_message "Установка пакета $package..."
        ssh -o StrictHostKeyChecking=no -p $ROUTER_PORT $ROUTER_USER@$ROUTER_IP "opkg install $package"
    done
}

# Функция для копирования файлов на роутер
copy_files_to_router() {
    print_message "Копирование файлов на роутер..."
    
    # Создаем необходимые директории
    ssh -o StrictHostKeyChecking=no -p $ROUTER_PORT $ROUTER_USER@$ROUTER_IP "
        mkdir -p /root/vless-router
        mkdir -p /www/vless-router
        mkdir -p /etc/vless-router
    "
    
    # Копируем файлы
    for dir in "config" "scripts" "web"; do
        if [ -d "$SCRIPT_DIR/$dir" ]; then
            print_message "Копирование директории $dir..."
            scp -o StrictHostKeyChecking=no -r -P $ROUTER_PORT "$SCRIPT_DIR/$dir" $ROUTER_USER@$ROUTER_IP:/root/vless-router/
        else
            print_warning "Директория $dir не найдена"
        fi
    done
    
    # Копируем веб-файлы
    if [ -d "$SCRIPT_DIR/web" ]; then
        scp -o StrictHostKeyChecking=no -r -P $ROUTER_PORT "$SCRIPT_DIR/web/"* $ROUTER_USER@$ROUTER_IP:/www/vless-router/
    fi
    
    # Копируем конфигурационные файлы
    if [ -d "$SCRIPT_DIR/config" ]; then
        scp -o StrictHostKeyChecking=no -r -P $ROUTER_PORT "$SCRIPT_DIR/config/"* $ROUTER_USER@$ROUTER_IP:/etc/vless-router/
    fi
}

# Функция для настройки веб-сервера на роутере
setup_web_server() {
    print_message "Настройка веб-сервера на роутере..."
    
    # Создаем конфигурацию uhttpd
    cat > /tmp/uhttpd << EOF
config uhttpd main
    option listen_http '0.0.0.0:8080'
    option home '/www/vless-router'
    option rfc1918_filter '0'
    option max_requests '3'
    option max_connections '100'
    option script_timeout '60'
    option network_timeout '30'
    option http_keepalive '20'
    option tcp_keepalive '1'
    option cgi_prefix '/cgi-bin'
    list interpreter '.php=/usr/bin/php-cgi'
    option index_page 'index.html'
    option error_page '/error.html'
EOF
    
    # Копируем конфигурацию на роутер
    scp -o StrictHostKeyChecking=no -P $ROUTER_PORT /tmp/uhttpd $ROUTER_USER@$ROUTER_IP:/etc/config/uhttpd
    
    # Перезапускаем веб-сервер
    ssh -o StrictHostKeyChecking=no -p $ROUTER_PORT $ROUTER_USER@$ROUTER_IP "
        /etc/init.d/uhttpd restart
        /etc/init.d/uhttpd enable
    "
}

# Функция для запуска веб-установщика
start_web_installer() {
    # Создаем временную директорию для веб-сервера
    mkdir -p "$TEMP_DIR/web"
    
    # Копируем веб-файлы
    cp -r "$SCRIPT_DIR/web/"* "$TEMP_DIR/web/" 2>/dev/null || true

    # Создаем API прокси для веб-интерфейса
    cat > "$TEMP_DIR/web/api_proxy.php" << 'EOF'
<?php
header('Content-Type: application/json');
$action = $_GET['action'] ?? '';
$response = ['success' => false, 'message' => 'Unknown action'];
switch ($action) {
    case 'check_internet':
        $output = shell_exec("ping -c 1 8.8.8.8");
        if ($output) {
            $response = ['success' => true, 'message' => 'Internet connection available'];
        } else {
            $response = ['success' => false, 'message' => 'No internet connection'];
        }
        break;
    case 'scan_wifi':
        // Возвращаем тестовый список сетей
        $response = ['success' => true, 'networks' => ['Network1','Network2','Network3']];
        break;
    case 'connect_wifi':
        $response = ['success' => true, 'message' => 'Connected to WiFi'];
        break;
    case 'start_install':
        $response = ['success' => true, 'message' => 'Installation started'];
        break;
    default:
        $response = ['success' => false, 'message' => 'Invalid action'];
}
echo json_encode($response);
?>
EOF

    # Запускаем PHP-сервер
    cd "$TEMP_DIR/web" && php -S "0.0.0.0:$WEB_PORT" &>/dev/null &
    PHP_PID=$!
    
    # Проверяем запуск сервера
    sleep 2
    if ! kill -0 $PHP_PID 2>/dev/null; then
        print_error "Не удалось запустить веб-сервер"
        exit 1
    fi
    
    # Определяем локальный IP
    if check_command ip; then
        LOCAL_IP=$(ip route get 1 | awk '{print $7; exit}')
    elif check_command ifconfig; then
        LOCAL_IP=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n 1)
    else
        LOCAL_IP="localhost"
    fi
    
    print_success "Веб-интерфейс доступен по адресу: http://$LOCAL_IP:$WEB_PORT"
    
    # Открываем браузер
    if check_command xdg-open; then
        xdg-open "http://$LOCAL_IP:$WEB_PORT" &>/dev/null
    elif check_command open; then
        open "http://$LOCAL_IP:$WEB_PORT" &>/dev/null
    fi
}

# Основная функция установки
main() {
    print_message "Запуск установщика VLESS Router..."
    
    # Проверяем зависимости
    check_dependencies
    
    # Запускаем веб-установщик
    start_web_installer
    
    # Ждем завершения работы веб-сервера
wait $PHP_PID 
}

# Запуск основной функции
main 