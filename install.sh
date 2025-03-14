#!/bin/bash

# VLESS Router Web Installer - Веб-интерфейс для установки на OpenWrt
# Скрипт запускает локальный веб-сервер на компьютере и предоставляет
# веб-интерфейс для настройки роутера с OpenWrt

# Обработка прерывания и выхода
trap cleanup EXIT INT TERM

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Переменные для настройки
TEMP_DIR=$(mktemp -d)
WEB_PORT=8000
ROUTER_DEFAULT_IP="192.168.1.1"
ROUTER_DEFAULT_PORT="22"
ROUTER_DEFAULT_USER="root"

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

# Функция для вывода статуса
print_status() {
    echo -e "${PURPLE}[СТАТУС]${NC} $1"
}

# Функция очистки при выходе
cleanup() {
    print_message "Завершение работы установщика..."
    # Остановка локального веб-сервера
    if [ ! -z "$PHP_PID" ]; then
        kill $PHP_PID 2>/dev/null
        print_message "Веб-сервер остановлен"
    fi
    # Удаление временных файлов
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
        print_message "Временные файлы удалены"
    fi
}

# Функция для проверки наличия команды
check_command() {
    if ! command -v $1 &> /dev/null; then
        print_error "Команда '$1' не найдена. Пожалуйста, установите необходимые зависимости."
        case $1 in
            ssh|scp)
                if [[ -f /etc/debian_version ]]; then
                echo "Для установки выполните: sudo apt-get install openssh-client"
                elif [[ -f /etc/fedora-release ]]; then
                    echo "Для установки выполните: sudo dnf install openssh-clients"
                elif [[ -f /etc/arch-release ]]; then
                    echo "Для установки выполните: sudo pacman -S openssh"
                else
                    echo "Установите пакет SSH для вашего дистрибутива"
                fi
                return 1
                ;;
            php)
                if [[ -f /etc/debian_version ]]; then
                    echo "Для установки выполните: sudo apt-get install php-cli"
                elif [[ -f /etc/fedora-release ]]; then
                    echo "Для установки выполните: sudo dnf install php-cli"
                elif [[ -f /etc/arch-release ]]; then
                    echo "Для установки выполните: sudo pacman -S php"
                else
                    echo "Установите пакет PHP CLI для вашего дистрибутива"
                fi
                return 1
                ;;
            xdg-open)
                if [[ -f /etc/debian_version ]]; then
                echo "Для установки выполните: sudo apt-get install xdg-utils"
                elif [[ -f /etc/fedora-release ]]; then
                    echo "Для установки выполните: sudo dnf install xdg-utils"
                elif [[ -f /etc/arch-release ]]; then
                    echo "Для установки выполните: sudo pacman -S xdg-utils"
                else
                    echo "Установите пакет xdg-utils для вашего дистрибутива"
                fi
                return 1
                ;;
        esac
    fi
    return 0
}

# Функция для получения локального IP-адреса
get_local_ip() {
    # Получаем локальный IP-адрес
    if command -v ip &> /dev/null; then
        LOCAL_IP=$(ip route get 1 | awk '{print $7; exit}')
    elif command -v ifconfig &> /dev/null; then
        LOCAL_IP=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n 1)
    else
        LOCAL_IP="localhost"
        print_warning "Не удалось определить локальный IP-адрес"
    fi
    echo $LOCAL_IP
}

# Проверка наличия необходимых директорий
check_directories() {
    # Проверка наличия основных директорий
    local missing_dirs=()
    
    # Определение директории скрипта
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
    
    # Проверка конфиг директории
    if [ ! -d "$SCRIPT_DIR/config" ]; then
        missing_dirs+=("config")
    fi
    
    # Проверка директории скриптов
    if [ ! -d "$SCRIPT_DIR/scripts" ]; then
        missing_dirs+=("scripts")
    fi
    
    # Проверка веб-директории
    if [ ! -d "$SCRIPT_DIR/web" ]; then
        missing_dirs+=("web")
    fi
    
    # Если есть отсутствующие директории, выводим предупреждение
    if [ ${#missing_dirs[@]} -gt 0 ]; then
        print_warning "Следующие необходимые директории отсутствуют:"
        for dir in "${missing_dirs[@]}"; do
            echo "  - $dir"
        done
        print_warning "Установка может работать некорректно без этих директорий"
        return 1
    fi
    
    print_success "Все необходимые директории найдены"
    return 0
}

# Заголовок
clear
echo -e "${BLUE}"
echo "------------------------------------------------------"
echo "           VLESS Router - Веб-установщик             "
echo "------------------------------------------------------"
echo -e "${NC}"
echo "  Этот мастер поможет установить VLESS Router на ваш"
echo "  маршрутизатор с OpenWrt."
echo ""

# Проверка наличия необходимых команд
print_message "Проверка зависимостей..."
DEPENDENCIES_OK=true

for cmd in ssh scp php xdg-open; do
    if ! check_command $cmd; then
        DEPENDENCIES_OK=false
    fi
done

if [ "$DEPENDENCIES_OK" = false ]; then
    print_error "Отсутствуют необходимые зависимости. Установите их и запустите скрипт снова."
    exit 1
fi

# Проверка наличия необходимых директорий
print_message "Проверка структуры проекта..."
check_directories

# Создание API файла для веб-интерфейса
print_message "Создание временного API файла..."
mkdir -p "$TEMP_DIR/api"

cat > "$TEMP_DIR/api/api.php" << 'EOF'
<?php
// API для веб-установщика VLESS Router

// Заголовки для API ответов
header('Content-Type: application/json');

// Функция для проверки подключения к роутеру
function checkRouterConnection($ip, $port = 22) {
    $connection = @fsockopen($ip, $port, $errno, $errstr, 5);
    if (is_resource($connection)) {
        fclose($connection);
        return true;
    }
    return false;
}

// Функция для проверки SSH соединения
function checkSshConnection($ip, $port, $user, $password) {
    $command = "sshpass -p '" . escapeshellarg($password) . "' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -p $port $user@$ip 'echo connected'";
    exec($command, $output, $return_code);
    return $return_code === 0;
}

// Функция для проверки наличия директории исходников
function checkSourceDirectory() {
    $scriptDir = dirname(dirname(__FILE__));
    $requiredDirs = ['web', 'config', 'scripts'];
    $missing = [];
    
    foreach ($requiredDirs as $dir) {
        if (!is_dir("$scriptDir/$dir")) {
            $missing[] = $dir;
        }
    }
    
    return [
        'success' => count($missing) === 0,
        'missing' => $missing
    ];
}

// Функция для настройки WiFi на роутере
function setupWifi($ip, $port, $user, $password, $wifi_ssid, $wifi_password) {
    // Создаем скрипт для настройки WiFi
    $wifiSetupScript = '
    # Создание конфигурации WiFi клиента
    uci set wireless.sta=wifi-iface
    uci set wireless.sta.device="radio0"
    uci set wireless.sta.network="wwan"
    uci set wireless.sta.mode="sta"
    uci set wireless.sta.ssid="'.$wifi_ssid.'"
    uci set wireless.sta.encryption="psk2"
    uci set wireless.sta.key="'.$wifi_password.'"
    
    # Настройка сети wwan
    uci set network.wwan=interface
    uci set network.wwan.proto="dhcp"
    
    # Применение настроек
    uci commit wireless
    uci commit network
    
    # Перезапуск сетевых служб
    wifi
    /etc/init.d/network restart
    ';
    
    // Сохраняем скрипт во временный файл
    $tempFile = tempnam(sys_get_temp_dir(), 'wifi_setup');
    file_put_contents($tempFile, $wifiSetupScript);
    
    // Копируем на роутер и выполняем
    $uploadCommand = "sshpass -p '" . escapeshellarg($password) . "' scp -o StrictHostKeyChecking=no -P $port $tempFile $user@$ip:/tmp/wifi_setup.sh";
    exec($uploadCommand, $output, $upload_return);
    
    if ($upload_return !== 0) {
        unlink($tempFile);
        return [
            'success' => false,
            'message' => 'Не удалось загрузить скрипт на роутер'
        ];
    }
    
    // Выполнение скрипта на роутере
    $execCommand = "sshpass -p '" . escapeshellarg($password) . "' ssh -o StrictHostKeyChecking=no -p $port $user@$ip 'chmod +x /tmp/wifi_setup.sh && /tmp/wifi_setup.sh'";
    exec($execCommand, $output, $exec_return);
    
    unlink($tempFile);
    
    return [
        'success' => $exec_return === 0,
        'message' => $exec_return === 0 ? 'WiFi настроен успешно' : 'Ошибка при настройке WiFi'
    ];
}

// Функция для проверки интернет-соединения на роутере
function checkInternetConnection($ip, $port, $user, $password) {
    $command = "sshpass -p '" . escapeshellarg($password) . "' ssh -o StrictHostKeyChecking=no -p $port $user@$ip 'ping -c 2 8.8.8.8'";
    exec($command, $output, $return_code);
    return $return_code === 0;
}

// Обработка API запросов
$action = isset($_GET['action']) ? $_GET['action'] : '';

switch ($action) {
    case 'check_router':
        $ip = isset($_GET['ip']) ? $_GET['ip'] : '192.168.1.1';
        $port = isset($_GET['port']) ? (int)$_GET['port'] : 22;
        
        $result = [
            'success' => checkRouterConnection($ip, $port),
            'message' => checkRouterConnection($ip, $port) ? 'Роутер доступен' : 'Не удалось подключиться к роутеру'
        ];
        
        echo json_encode($result);
        break;
        
    case 'check_ssh':
        $data = json_decode(file_get_contents('php://input'), true);
        $ip = $data['ip'] ?? '192.168.1.1';
        $port = (int)($data['port'] ?? 22);
        $user = $data['user'] ?? 'root';
        $password = $data['password'] ?? '';
        
        $result = [
            'success' => checkSshConnection($ip, $port, $user, $password),
            'message' => checkSshConnection($ip, $port, $user, $password) ? 'SSH соединение успешно' : 'Не удалось подключиться по SSH'
        ];
        
        echo json_encode($result);
        break;
    
    case 'check_source':
        echo json_encode(checkSourceDirectory());
        break;
        
    case 'setup_wifi':
        $data = json_decode(file_get_contents('php://input'), true);
        $ip = $data['ip'] ?? '192.168.1.1';
        $port = (int)($data['port'] ?? 22);
        $user = $data['user'] ?? 'root';
        $password = $data['password'] ?? '';
        $wifi_ssid = $data['wifi_ssid'] ?? '';
        $wifi_password = $data['wifi_password'] ?? '';
        
        echo json_encode(setupWifi($ip, $port, $user, $password, $wifi_ssid, $wifi_password));
        break;
    
    case 'check_internet':
        $data = json_decode(file_get_contents('php://input'), true);
        $ip = $data['ip'] ?? '192.168.1.1';
        $port = (int)($data['port'] ?? 22);
        $user = $data['user'] ?? 'root';
        $password = $data['password'] ?? '';
        
        $result = [
            'success' => true,
            'connected' => checkInternetConnection($ip, $port, $user, $password),
            'message' => checkInternetConnection($ip, $port, $user, $password) ? 'Интернет-соединение установлено' : 'Нет доступа к интернету'
        ];
        
        echo json_encode($result);
        break;
    
    default:
        echo json_encode([
            'success' => false,
            'message' => 'Неизвестное действие API'
        ]);
}
EOF

print_message "Подготовка к запуску веб-сервера..."

# Получаем IP-адрес локальной машины
LOCAL_IP=$(get_local_ip)
if [ -z "$LOCAL_IP" ]; then
    LOCAL_IP="localhost"
fi

# Заменяем плейсхолдер с путем к скрипту в файле HTML
sed -i "s|SCRIPT_PATH_PLACEHOLDER|$SCRIPT_DIR|g" "$TEMP_DIR/index.html"

# Проверка наличия sshpass
if ! command -v sshpass &> /dev/null; then
    print_warning "Пакет sshpass не установлен. Он необходим для работы веб-установщика."
    read -p "Установить sshpass сейчас? (y/n): " install_sshpass
    if [[ $install_sshpass == "y" || $install_sshpass == "Y" ]]; then
        print_message "Установка sshpass..."
        sudo apt-get update && sudo apt-get install -y sshpass
        if [ $? -ne 0 ]; then
            print_error "Не удалось установить sshpass. Пожалуйста, установите его вручную."
            print_message "Для Debian/Ubuntu: sudo apt-get install sshpass"
            exit 1
        else
            print_success "sshpass успешно установлен."
        fi
    else
        print_error "sshpass необходим для работы веб-установщика. Пожалуйста, установите его вручную."
        print_message "Для Debian/Ubuntu: sudo apt-get install sshpass"
        exit 1
    fi
fi

# Запуск PHP-сервера в фоновом режиме
print_message "Запуск веб-сервера на порту 8000..."
cd "$TEMP_DIR" && php -S 0.0.0.0:8000 &
PHP_PID=$!

if [ $? -ne 0 ]; then
    print_error "Не удалось запустить PHP-сервер. Убедитесь, что порт 8000 не занят другим приложением."
    cleanup
    exit 1
fi

# Проверка, что сервер запустился
sleep 2
if ! kill -0 $PHP_PID 2>/dev/null; then
    print_error "PHP-сервер не запустился или преждевременно завершил работу."
    cleanup
    exit 1
fi

print_success "Веб-сервер успешно запущен на порту 8000!"
print_message "Открываем веб-интерфейс установщика..."

# URL для веб-интерфейса
WEB_URL="http://$LOCAL_IP:8000"

# Открытие веб-интерфейса в браузере
if ! xdg-open "$WEB_URL" &>/dev/null; then
    print_warning "Не удалось автоматически открыть браузер."
    print_message "Пожалуйста, откройте браузер и перейдите по адресу:"
    echo "$WEB_URL"
fi

print_message "Веб-интерфейс установщика доступен по адресу: $WEB_URL"
print_message "Для завершения работы установщика нажмите Ctrl+C"

# Ожидаем завершения пользователем
wait $PHP_PID 