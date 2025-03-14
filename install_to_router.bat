@echo off
REM VLESS Router - Скрипт установки на роутер для Windows

setlocal enabledelayedexpansion

REM Цвета для текста
set COLOR_BLUE=[94m
set COLOR_RED=[91m
set COLOR_GREEN=[92m
set COLOR_RESET=[0m

REM Функция вывода сообщений
:print_message
echo %COLOR_BLUE%[VLESS Router]%COLOR_RESET% %~1
exit /b 0

REM Функция вывода ошибок
:print_error
echo %COLOR_RED%[ОШИБКА]%COLOR_RESET% %~1
exit /b 0

REM Функция вывода успеха
:print_success
echo %COLOR_GREEN%[УСПЕХ]%COLOR_RESET% %~1
exit /b 0

REM Проверка наличия параметров
if "%~1"=="" (
    call :print_message "Использование: %~nx0 <IP-адрес роутера> [имя пользователя] [порт SSH]"
    call :print_message "Пример: %~nx0 192.168.1.1 root 22"
    exit /b 1
)

REM Параметры подключения
set ROUTER_IP=%~1
if "%~2"=="" (
    set ROUTER_USER=root
) else (
    set ROUTER_USER=%~2
)

if "%~3"=="" (
    set SSH_PORT=22
) else (
    set SSH_PORT=%~3
)

REM Проверка наличия утилиты ssh
where ssh >nul 2>&1
if %ERRORLEVEL% neq 0 (
    call :print_error "Команда SSH не найдена. Установите OpenSSH или Git Bash."
    call :print_message "Для Windows 10/11: Откройте Настройки -> Приложения -> Дополнительные компоненты -> Добавить компонент -> OpenSSH Клиент."
    pause
    exit /b 1
)

REM Проверка возможности подключения
call :print_message "Проверка подключения к роутеру %ROUTER_IP%..."

ssh -p "%SSH_PORT%" -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no "%ROUTER_USER%@%ROUTER_IP%" exit

if %ERRORLEVEL% neq 0 (
    call :print_error "Не удалось подключиться к роутеру. Проверьте подключение и учетные данные."
    pause
    exit /b 1
)

call :print_success "Подключение к роутеру успешно."

REM Копирование файлов проекта на роутер
call :print_message "Копирование файлов VLESS Router на роутер..."

REM Создание директории на роутере
ssh -p "%SSH_PORT%" "%ROUTER_USER%@%ROUTER_IP%" "mkdir -p /root/vless-router"

if %ERRORLEVEL% neq 0 (
    call :print_error "Не удалось создать директорию на роутере."
    pause
    exit /b 1
)

REM Копирование файлов
scp -P "%SSH_PORT%" -r .\vless-router\* "%ROUTER_USER%@%ROUTER_IP%:/root/vless-router/"

if %ERRORLEVEL% neq 0 (
    call :print_error "Не удалось скопировать файлы на роутер."
    pause
    exit /b 1
)

call :print_success "Файлы успешно скопированы на роутер."

REM Установка прав на исполнение скриптов
call :print_message "Настройка прав доступа..."

ssh -p "%SSH_PORT%" "%ROUTER_USER%@%ROUTER_IP%" "chmod +x /root/vless-router/scripts/*.sh && chmod +x /root/vless-router/web/*.cgi"

if %ERRORLEVEL% neq 0 (
    call :print_error "Не удалось установить права доступа на скрипты."
    pause
    exit /b 1
)

call :print_success "Права доступа установлены."

REM Запуск скрипта установки на роутере
call :print_message "Запуск скрипта установки на роутере..."
call :print_message "После завершения установки веб-интерфейс будет доступен по адресу: http://%ROUTER_IP%:8080"

ssh -p "%SSH_PORT%" "%ROUTER_USER%@%ROUTER_IP%" "/root/vless-router/scripts/setup.sh"

if %ERRORLEVEL% neq 0 (
    call :print_error "Произошла ошибка при выполнении скрипта установки."
    pause
    exit /b 1
)

call :print_success "Установка VLESS Router завершена успешно!"
call :print_message "Откройте веб-браузер и перейдите по адресу: http://%ROUTER_IP%:8080"
call :print_message "Следуйте инструкциям мастера настройки для завершения конфигурации."

echo.
echo Нажмите любую клавишу для выхода...
pause >nul
exit /b 0
