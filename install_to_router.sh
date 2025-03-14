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

# Проверка наличия параметров
if [ $# -lt 1 ]; then
    print_message "Использование: $0 <IP-адрес роутера> [имя пользователя] [порт SSH]"
    print_message "Пример: $0 192.168.1.1 root 22"
    exit 1
fi

# Параметры подключения
ROUTER_IP="$1"
ROUTER_USER="${2:-root}"  # По умолчанию root
SSH_PORT="${3:-22}"       # По умолчанию порт 22

# Проверка возможности подключения
print_message "Проверка подключения к роутеру $ROUTER_IP..."

# Убираем флаг BatchMode для возможности запроса пароля
ssh -p "$SSH_PORT" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$ROUTER_USER@$ROUTER_IP" exit 2>/dev/null

if [ $? -ne 0 ]; then
    print_error "Не удалось подключиться к роутеру. Проверьте подключение и учетные данные."
    exit 1
fi

print_success "Подключение к роутеру успешно."

# Копирование файлов проекта на роутер
print_message "Копирование файлов VLESS Router на роутер..."

# Создание директории на роутере
ssh -p "$SSH_PORT" "$ROUTER_USER@$ROUTER_IP" "mkdir -p /root/vless-router"

if [ $? -ne 0 ]; then
    print_error "Не удалось создать директорию на роутере."
    exit 1
fi

# Копирование файлов
scp -P "$SSH_PORT" -r ./vless-router/* "$ROUTER_USER@$ROUTER_IP:/root/vless-router/"

if [ $? -ne 0 ]; then
    print_error "Не удалось скопировать файлы на роутер."
    exit 1
fi

print_success "Файлы успешно скопированы на роутер."

# Установка прав на исполнение скриптов
print_message "Настройка прав доступа..."

ssh -p "$SSH_PORT" "$ROUTER_USER@$ROUTER_IP" "chmod +x /root/vless-router/scripts/*.sh && chmod +x /root/vless-router/web/*.cgi"

if [ $? -ne 0 ]; then
    print_error "Не удалось установить права доступа на скрипты."
    exit 1
fi

print_success "Права доступа установлены."

# Запуск скрипта установки на роутере
print_message "Запуск скрипта установки на роутере..."
print_message "После завершения установки веб-интерфейс будет доступен по адресу: http://$ROUTER_IP:8080"

ssh -p "$SSH_PORT" "$ROUTER_USER@$ROUTER_IP" "/root/vless-router/scripts/setup.sh"

if [ $? -ne 0 ]; then
    print_error "Произошла ошибка при выполнении скрипта установки."
    exit 1
fi

print_success "Установка VLESS Router завершена успешно!"
print_message "Откройте веб-браузер и перейдите по адресу: http://$ROUTER_IP:8080"
print_message "Следуйте инструкциям мастера настройки для завершения конфигурации."
