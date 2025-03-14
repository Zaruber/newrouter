@echo off
REM VLESS Router - Простой установщик для Windows
REM Автоматизирует процесс подключения к роутеру и открытия веб-интерфейса

title VLESS Router - Установщик

echo ------------------------------------------------------
echo           VLESS Router - Установщик v1.0
echo ------------------------------------------------------
echo.
echo  Этот мастер поможет установить VLESS Router на ваш
echo  маршрутизатор с OpenWrt.
echo.

REM Проверка наличия SSH и SCP
WHERE ssh >nul 2>nul
IF %ERRORLEVEL% NEQ 0 (
    echo Ошибка: На вашем компьютере не найдены программы SSH и SCP.
    echo Пожалуйста, установите Git for Windows по адресу:
    echo https://gitforwindows.org/
    echo.
    echo После установки перезапустите этот установщик.
    pause
    start https://gitforwindows.org/
    exit /b 1
)

REM Запрос данных для подключения
set /p ROUTER_IP=Введите IP-адрес роутера (по умолчанию 192.168.1.1): 
set /p SSH_PORT=Введите порт SSH (по умолчанию 22): 
set /p SSH_USER=Введите имя пользователя (по умолчанию root): 
set /p SSH_PASSWORD=Введите пароль: 

REM Установка значений по умолчанию, если не указаны
if "%ROUTER_IP%"=="" set ROUTER_IP=192.168.1.1
if "%SSH_PORT%"=="" set SSH_PORT=22
if "%SSH_USER%"=="" set SSH_USER=root

echo.
echo Проверка соединения с роутером %ROUTER_IP%...

REM Проверка соединения с роутером
ping -n 2 %ROUTER_IP% >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Ошибка: Не удается подключиться к роутеру.
    echo - Убедитесь, что вы подключены к сети роутера
    echo - Проверьте правильность IP-адреса
    pause
    exit /b 1
)

echo Доступ к роутеру подтвержден.
echo.
echo Создание директории на роутере...

REM Создание директории на роутере
ssh -p %SSH_PORT% -o StrictHostKeyChecking=no %SSH_USER%@%ROUTER_IP% "mkdir -p /root/vless-router" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Ошибка: Не удалось подключиться к роутеру по SSH.
    echo - Проверьте правильность учетных данных
    echo - Убедитесь, что SSH включен на роутере
    pause
    exit /b 1
)

echo Копирование файлов на роутер...

REM Определяем список файлов для копирования
set FILES_TO_COPY=config scripts web setup_webserver.sh README.md

REM Копирование файлов на роутер
for %%F in (%FILES_TO_COPY%) do (
    echo Копирование %%F...
    scp -r -P %SSH_PORT% -o StrictHostKeyChecking=no "%~dp0%%F" %SSH_USER%@%ROUTER_IP%:/root/vless-router/ >nul 2>&1
    if %ERRORLEVEL% neq 0 (
        echo Ошибка: Не удалось скопировать файлы на роутер.
        echo - Проверьте правильность учетных данных
        echo - Убедитесь, что на роутере достаточно места
        pause
        exit /b 1
    )
)

echo Файлы успешно скопированы.
echo.
echo Настройка веб-сервера на роутере...

REM Выполнение setup_webserver.sh на роутере
ssh -p %SSH_PORT% -o StrictHostKeyChecking=no %SSH_USER%@%ROUTER_IP% "cd /root/vless-router && chmod +x ./setup_webserver.sh && ./setup_webserver.sh" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Ошибка: Не удалось настроить веб-сервер на роутере.
    echo - Проверьте наличие зависимостей на роутере
    echo - Убедитесь, что скрипт setup_webserver.sh имеет права на выполнение
    pause
    exit /b 1
)

echo Веб-сервер успешно настроен.
echo.
echo Установка завершена!
echo.
echo Теперь откройте веб-браузер и перейдите по адресу:
echo http://%ROUTER_IP%:8080
echo.

REM Автоматическое открытие браузера
start http://%ROUTER_IP%:8080

echo Нажмите любую клавишу для выхода...
pause > nul 