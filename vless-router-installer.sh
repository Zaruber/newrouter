#!/bin/bash

# VLESS Router - Автоматический установщик для Linux
# Скрипт подключается к роутеру, копирует необходимые файлы и открывает веб-интерфейс

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
                ;;
        esac
        exit 1
    fi
}

# Заголовок
echo -e "${BLUE}"
echo "------------------------------------------------------"
echo "           VLESS Router - Установщик для Linux        "
echo "------------------------------------------------------"
echo -e "${NC}"
echo "  Этот мастер поможет установить VLESS Router на ваш"
echo "  маршрутизатор с OpenWrt."
echo ""

# Проверка наличия необходимых команд
print_message "Проверка зависимостей..."
check_command ssh
check_command scp
check_command xdg-open

# Получение параметров подключения
read -p "Введите IP-адрес роутера [192.168.1.1]: " ROUTER_IP
read -p "Введите порт SSH [22]: " SSH_PORT
read -p "Введите имя пользователя [root]: " SSH_USER
read -s -p "Введите пароль: " SSH_PASSWORD
echo ""

# Установка значений по умолчанию, если не указаны
ROUTER_IP=${ROUTER_IP:-"192.168.1.1"}
SSH_PORT=${SSH_PORT:-"22"}
SSH_USER=${SSH_USER:-"root"}

# Создание файла с настройками для SSH без запроса проверки ключа
SSH_CONFIG_FILE=$(mktemp)
cat > $SSH_CONFIG_FILE << EOF
Host router
    HostName $ROUTER_IP
    Port $SSH_PORT
    User $SSH_USER
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF

# Проверка соединения с роутером
print_message "Проверка соединения с роутером $ROUTER_IP..."
if ! ping -c 2 $ROUTER_IP &>/dev/null; then
    print_error "Не удается подключиться к роутеру."
    print_warning "- Убедитесь, что вы подключены к сети роутера"
    print_warning "- Проверьте правильность IP-адреса"
    rm $SSH_CONFIG_FILE
    exit 1
fi

print_success "Доступ к роутеру подтвержден."

# Создание директории на роутере
print_message "Создание директории на роутере..."
if ! ssh -F $SSH_CONFIG_FILE router "mkdir -p /root/vless-router" &>/dev/null; then
    print_error "Не удалось подключиться к роутеру по SSH."
    print_warning "- Проверьте правильность учетных данных"
    print_warning "- Убедитесь, что SSH включен на роутере"
    rm $SSH_CONFIG_FILE
    exit 1
fi

# Определение директории скрипта
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Копирование файлов на роутер
print_message "Копирование файлов на роутер..."

# Список файлов и директорий для копирования
FILES_TO_COPY=("config" "scripts" "web" "setup_webserver.sh" "README.md")

for file in "${FILES_TO_COPY[@]}"; do
    if [ -e "$SCRIPT_DIR/$file" ]; then
        print_message "Копирование $file..."
        if ! scp -r -F $SSH_CONFIG_FILE "$SCRIPT_DIR/$file" router:/root/vless-router/ &>/dev/null; then
            print_error "Не удалось скопировать $file на роутер."
            print_warning "- Проверьте права доступа"
            print_warning "- Убедитесь, что на роутере достаточно места"
            rm $SSH_CONFIG_FILE
            exit 1
        fi
    else
        print_warning "Файл/директория $file не найден(а) и будет пропущен(а)"
    fi
done

print_success "Файлы успешно скопированы."

# Настройка веб-сервера на роутере
print_message "Настройка веб-сервера на роутере..."
if ! ssh -F $SSH_CONFIG_FILE router "cd /root/vless-router && chmod +x ./setup_webserver.sh && ./setup_webserver.sh" &>/dev/null; then
    print_error "Не удалось настроить веб-сервер на роутере."
    print_warning "- Проверьте наличие зависимостей на роутере"
    print_warning "- Убедитесь, что скрипт setup_webserver.sh имеет права на выполнение"
    rm $SSH_CONFIG_FILE
    exit 1
fi

print_success "Веб-сервер успешно настроен!"

# Получение IP-адреса роутера в локальной сети
ROUTER_WEB_URL="http://$ROUTER_IP:8080"

# Удаление временного файла настроек SSH
rm $SSH_CONFIG_FILE

# Открытие веб-браузера
print_message "Установка завершена! Открываем веб-интерфейс для продолжения настройки..."
echo ""
echo "Веб-интерфейс доступен по адресу: $ROUTER_WEB_URL"
echo ""

# Открытие браузера с веб-интерфейсом
if ! xdg-open "$ROUTER_WEB_URL" &>/dev/null; then
    print_warning "Не удалось автоматически открыть браузер."
    print_message "Пожалуйста, откройте следующий URL в вашем браузере:"
    echo "$ROUTER_WEB_URL"
fi

print_success "Установка VLESS Router завершена успешно!"
print_message "Теперь вы можете продолжить настройку через веб-интерфейс." 