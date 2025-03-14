@echo off
REM VLESS Router - Скрипт установки на роутер для Windows

setlocal enabledelayedexpansion

REM Цвета для текста
set COLOR_BLUE=[94m
set COLOR_RED=[91m
set COLOR_GREEN=[92m
set COLOR_YELLOW=[93m
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

REM Функция вывода подсказок/советов
:print_tip
echo %COLOR_YELLOW%[СОВЕТ]%COLOR_RESET% %~1
exit /b 0

REM Функция проверки сетевого подключения
:check_network
set router_ip=%~1
call :print_message "Проверка сетевого подключения к %router_ip%..."
ping -n 2 %router_ip% >nul 2>&1
if %ERRORLEVEL% neq 0 (
    call :print_error "Роутер недоступен по ping. Проверьте следующее:"
    call :print_tip "- Убедитесь, что вы подключены к сети Wi-Fi роутера или кабелем"
    call :print_tip "- Проверьте правильность IP-адреса роутера"
    call :print_tip "- Убедитесь, что роутер включен и работает"
    exit /b 1
) else (
    call :print_success "Роутер %router_ip% доступен по ping."
    exit /b 0
)

REM Функция проверки SSH подключения
:check_ssh_port
set router_ip=%~1
set port=%~2
call :print_message "Проверка доступности SSH порта %port% на роутере..."

REM Используем PowerShell для проверки доступности порта
powershell -Command "$tcp = New-Object Net.Sockets.TcpClient; try { $tcp.Connect('%router_ip%', %port%); Write-Output 'Port is open' } catch { Write-Output 'Port is closed' } finally { $tcp.Close() }" | findstr "open" >nul 2>&1

if %ERRORLEVEL% neq 0 (
    call :print_error "SSH порт %port% на роутере %router_ip% недоступен. Проверьте следующее:"
    call :print_tip "- Убедитесь, что на роутере включен и настроен SSH"
    call :print_tip "- Проверьте правильность порта SSH (обычно 22)"
    call :print_tip "- Возможно, в роутере блокируются SSH соединения (проверьте настройки брандмауэра)"
    exit /b 1
) else (
    call :print_success "SSH порт %port% на роутере %router_ip% доступен."
    exit /b 0
)

REM Функция проверки OpenWrt на роутере
:check_openwrt
set router_ip=%~1
set user=%~2
set port=%~3

call :print_message "Проверка совместимости роутера с OpenWrt..."
ssh -p %port% -o ConnectTimeout=5 -o StrictHostKeyChecking=no %user%@%router_ip% "ls /etc/openwrt_release" >nul 2>&1

if %ERRORLEVEL% neq 0 (
    call :print_error "Не обнаружена система OpenWrt на роутере."
    call :print_tip "VLESS Router требует роутер с установленной системой OpenWrt."
    call :print_tip "Если у вас установлен OpenWrt, проверьте учетные данные SSH."
    exit /b 1
) else (
    for /f "tokens=*" %%i in ('ssh -p %port% -o ConnectTimeout=5 -o StrictHostKeyChecking=no %user%@%router_ip% "cat /etc/openwrt_release | grep DISTRIB_RELEASE | cut -d \"'\" -f 2"') do set version=%%i
    call :print_success "Обнаружена система OpenWrt версии !version!."
    exit /b 0
)

REM Функция проверки наличия необходимых пакетов на роутере
:check_packages
set router_ip=%~1
set user=%~2
set port=%~3
set missing=0

call :print_message "Проверка наличия необходимых пакетов на роутере..."

set packages=curl uhttpd uhttpd-mod-ubus iptables ip6tables

for %%p in (%packages%) do (
    call :print_message "Проверка пакета %%p..."
    ssh -p %port% -o ConnectTimeout=5 -o StrictHostKeyChecking=no %user%@%router_ip% "opkg list-installed | grep '^%%p '" >nul 2>&1
    if %ERRORLEVEL% neq 0 (
        call :print_error "Пакет %%p не установлен на роутере."
        set missing=1
    )
)

if !missing! equ 1 (
    call :print_message "Установка отсутствующих пакетов на роутер..."
    ssh -p %port% -o ConnectTimeout=10 -o StrictHostKeyChecking=no %user%@%router_ip% "opkg update && opkg install curl uhttpd uhttpd-mod-ubus iptables ip6tables"
    if %ERRORLEVEL% neq 0 (
        call :print_error "Не удалось установить необходимые пакеты на роутер."
        call :print_tip "Попробуйте установить пакеты вручную через SSH:"
        call :print_tip "  ssh %user%@%router_ip% -p %port%"
        call :print_tip "  opkg update && opkg install curl uhttpd uhttpd-mod-ubus iptables ip6tables"
        exit /b 1
    ) else (
        call :print_success "Необходимые пакеты установлены на роутер."
        exit /b 0
    )
) else (
    call :print_success "Все необходимые пакеты уже установлены на роутере."
    exit /b 0
)

REM Проверка наличия параметров
if "%~1"=="" (
    call :print_message "Использование: %~nx0 <IP-адрес роутера> [имя пользователя] [порт SSH] [пароль SSH]"
    call :print_message "Пример: %~nx0 192.168.1.1 root 22 mypassword"
    call :print_message "Если вы уже настроили SSH-ключ, пароль можно не указывать."
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

if "%~4"=="" (
    set SSH_PASSWORD=
) else (
    set SSH_PASSWORD=%~4
)

REM Мастер установки - начало
call :print_message "==============================================================="
call :print_message "              VLESS Router - Мастер установки                 "
call :print_message "==============================================================="
call :print_message "Данный мастер поможет вам установить VLESS Router на ваш OpenWrt роутер."
call :print_message "IP роутера: %ROUTER_IP%  Пользователь: %ROUTER_USER%  Порт SSH: %SSH_PORT%"

if not "%SSH_PASSWORD%"=="" (
    call :print_message "Для подключения будет использован пароль."
) else (
    call :print_message "Для подключения будет использован SSH-ключ (без пароля)."
)

call :print_message "==============================================================="

REM Проверка наличия утилиты ssh
where ssh >nul 2>&1
if %ERRORLEVEL% neq 0 (
    call :print_error "Команда SSH не найдена. Установите OpenSSH или Git Bash."
    call :print_message "Для Windows 10/11: Откройте Настройки -> Приложения -> Дополнительные компоненты -> Добавить компонент -> OpenSSH Клиент."
    call :print_tip "Также вы можете установить Git для Windows, который включает в себя SSH: https://git-scm.com/download/win"
    pause
    exit /b 1
)

REM Проверка наличия утилиты scp
where scp >nul 2>&1
if %ERRORLEVEL% neq 0 (
    call :print_error "Команда SCP не найдена. Установите OpenSSH или Git Bash."
    call :print_message "Для Windows 10/11: Откройте Настройки -> Приложения -> Дополнительные компоненты -> Добавить компонент -> OpenSSH Клиент."
    call :print_tip "Также вы можете установить Git для Windows, который включает в себя SCP: https://git-scm.com/download/win"
    pause
    exit /b 1
)

REM Проверка наличия sshpass, если указан пароль
if not "%SSH_PASSWORD%"=="" (
    where sshpass >nul 2>&1
    if %ERRORLEVEL% neq 0 (
        call :print_error "Для использования пароля требуется программа 'sshpass', но она не найдена."
        call :print_tip "Скачайте sshpass для Windows и добавьте его в PATH."
        call :print_tip "Альтернативно, настройте SSH-ключи для авторизации без пароля:"
        call :print_tip "  1. Сгенерируйте ключи: ssh-keygen"
        call :print_tip "  2. Скопируйте ключ: ssh-copy-id %ROUTER_USER%@%ROUTER_IP%"
        call :print_tip "  3. Запустите скрипт установки без указания пароля."
        pause
        exit /b 1
    )
)

REM Проверка сетевого подключения
call :check_network %ROUTER_IP%
if %ERRORLEVEL% neq 0 (
    call :print_error "Проблемы с сетевым подключением к роутеру."
    pause
    exit /b 1
)

REM Проверка SSH порта
call :check_ssh_port %ROUTER_IP% %SSH_PORT%
if %ERRORLEVEL% neq 0 (
    call :print_error "Проблемы с доступом к SSH порту на роутере."
    pause
    exit /b 1
)

REM Проверка возможности подключения
call :print_message "Проверка подключения к роутеру %ROUTER_IP%..."

if not "%SSH_PASSWORD%"=="" (
    sshpass -p "%SSH_PASSWORD%" ssh -p "%SSH_PORT%" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "%ROUTER_USER%@%ROUTER_IP%" exit
) else (
    ssh -p "%SSH_PORT%" -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no "%ROUTER_USER%@%ROUTER_IP%" exit
)

if %ERRORLEVEL% neq 0 (
    call :print_error "Не удалось подключиться к роутеру. Проверьте подключение и учетные данные."
    call :print_tip "Если вы используете пароль, убедитесь, что он правильный."
    call :print_tip "Проверьте, что на роутере включен SSH (Система -> Администрирование -> Настройки SSH)."
    call :print_tip "Можно также попробовать подключиться вручную: ssh %ROUTER_USER%@%ROUTER_IP% -p %SSH_PORT%"
    pause
    exit /b 1
)

call :print_success "Подключение к роутеру успешно."

REM Проверка OpenWrt на роутере
call :check_openwrt %ROUTER_IP% %ROUTER_USER% %SSH_PORT%
if %ERRORLEVEL% neq 0 (
    call :print_error "Роутер не совместим с VLESS Router."
    pause
    exit /b 1
)

REM Проверка наличия необходимых пакетов на роутере
call :check_packages %ROUTER_IP% %ROUTER_USER% %SSH_PORT%
if %ERRORLEVEL% neq 0 (
    call :print_error "Не все необходимые пакеты установлены на роутере."
    call :print_tip "Убедитесь, что роутер имеет доступ к интернету для установки пакетов."
    pause
    exit /b 1
)

REM Копирование файлов проекта на роутер
call :print_message "Копирование файлов VLESS Router на роутер..."

REM Создание директории на роутере
if not "%SSH_PASSWORD%"=="" (
    sshpass -p "%SSH_PASSWORD%" ssh -p "%SSH_PORT%" "%ROUTER_USER%@%ROUTER_IP%" "mkdir -p /root/vless-router"
) else (
    ssh -p "%SSH_PORT%" "%ROUTER_USER%@%ROUTER_IP%" "mkdir -p /root/vless-router"
)

if %ERRORLEVEL% neq 0 (
    call :print_error "Не удалось создать директорию на роутере."
    call :print_tip "Проверьте права доступа и свободное место на роутере."
    pause
    exit /b 1
)

REM Копирование файлов
set current_dir=%~dp0
if not "%SSH_PASSWORD%"=="" (
    sshpass -p "%SSH_PASSWORD%" scp -P "%SSH_PORT%" -r "%current_dir%*" "%ROUTER_USER%@%ROUTER_IP%:/root/vless-router/"
) else (
    scp -P "%SSH_PORT%" -r "%current_dir%*" "%ROUTER_USER%@%ROUTER_IP%:/root/vless-router/"
)

if %ERRORLEVEL% neq 0 (
    call :print_error "Не удалось скопировать файлы на роутер."
    call :print_tip "Проверьте права доступа и свободное место на роутере."
    call :print_tip "Убедитесь, что вы находитесь в правильной директории проекта."
    pause
    exit /b 1
)

call :print_success "Файлы успешно скопированы на роутер."

REM Установка прав на исполнение скриптов
call :print_message "Настройка прав доступа..."

if not "%SSH_PASSWORD%"=="" (
    sshpass -p "%SSH_PASSWORD%" ssh -p "%SSH_PORT%" "%ROUTER_USER%@%ROUTER_IP%" "chmod +x /root/vless-router/scripts/*.sh && chmod +x /root/vless-router/web/*.cgi"
) else (
    ssh -p "%SSH_PORT%" "%ROUTER_USER%@%ROUTER_IP%" "chmod +x /root/vless-router/scripts/*.sh && chmod +x /root/vless-router/web/*.cgi"
)

if %ERRORLEVEL% neq 0 (
    call :print_error "Не удалось установить права доступа на скрипты."
    call :print_tip "Проверьте права доступа и структуру директорий на роутере."
    pause
    exit /b 1
)

call :print_success "Права доступа установлены."

REM Запуск скрипта установки на роутере
call :print_message "Запуск скрипта установки на роутере..."
call :print_message "После завершения установки веб-интерфейс будет доступен по адресу: http://%ROUTER_IP%:8080"

if not "%SSH_PASSWORD%"=="" (
    sshpass -p "%SSH_PASSWORD%" ssh -p "%SSH_PORT%" "%ROUTER_USER%@%ROUTER_IP%" "/root/vless-router/scripts/setup.sh"
) else (
    ssh -p "%SSH_PORT%" "%ROUTER_USER%@%ROUTER_IP%" "/root/vless-router/scripts/setup.sh"
)

if %ERRORLEVEL% neq 0 (
    call :print_error "Произошла ошибка при выполнении скрипта установки."
    call :print_tip "Проверьте логи на роутере: /root/vless-router/logs/install.log"
    call :print_tip "Также можно попробовать выполнить установку вручную:"
    call :print_tip "  ssh %ROUTER_USER%@%ROUTER_IP% -p %SSH_PORT%"
    call :print_tip "  cd /root/vless-router && ./scripts/setup.sh"
    pause
    exit /b 1
)

call :print_success "Установка VLESS Router завершена успешно!"
call :print_message "Откройте веб-браузер и перейдите по адресу: http://%ROUTER_IP%:8080"
call :print_message "Следуйте инструкциям мастера настройки для завершения конфигурации."

REM Проверка доступности веб-интерфейса
call :print_message "Проверка доступности веб-интерфейса..."
timeout /t 2 /nobreak >nul

where curl >nul 2>&1
if %ERRORLEVEL% equ 0 (
    curl -s --connect-timeout 5 http://%ROUTER_IP%:8080 >nul 2>&1
    if %ERRORLEVEL% equ 0 (
        call :print_success "Веб-интерфейс VLESS Router доступен по адресу: http://%ROUTER_IP%:8080"
    ) else (
        call :print_error "Веб-интерфейс не отвечает. Возможно, потребуется дополнительная настройка."
        call :print_tip "Убедитесь, что порт 8080 не блокируется брандмауэром."
        call :print_tip "Проверьте, что веб-сервер запущен на роутере."
    )
) else (
    powershell -Command "(New-Object System.Net.WebClient).DownloadString('http://%ROUTER_IP%:8080')" >nul 2>&1
    if %ERRORLEVEL% equ 0 (
        call :print_success "Веб-интерфейс VLESS Router доступен по адресу: http://%ROUTER_IP%:8080"
    ) else (
        call :print_error "Веб-интерфейс не отвечает. Возможно, потребуется дополнительная настройка."
        call :print_tip "Убедитесь, что порт 8080 не блокируется брандмауэром."
        call :print_tip "Проверьте, что веб-сервер запущен на роутере."
    )
)

echo.
echo Нажмите любую клавишу для выхода...
pause >nul
exit /b 0
