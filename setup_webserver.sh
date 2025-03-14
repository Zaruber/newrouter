#!/bin/sh
# Скрипт для быстрой настройки веб-сервера на роутере

# Остановка существующих веб-серверов
/etc/init.d/uhttpd stop >/dev/null 2>&1

# Создание директорий для веб-интерфейса
mkdir -p /www/vless-router
mkdir -p /etc/vless-router

# Копирование файлов веб-интерфейса
cp -r /root/vless-router/web/* /www/vless-router/

# Копирование конфигурационных файлов
mkdir -p /etc/vless-router
cp -r /root/vless-router/config/* /etc/vless-router/

# Предоставление прав на исполнение скриптам
chmod +x /root/vless-router/scripts/*.sh

# Настройка uhttpd для веб-интерфейса
cat > /etc/config/uhttpd << EOF
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

# Создание директории для CGI и API
mkdir -p /www/vless-router/cgi-bin

# Создание PHP API CGI скриптов
cat > /www/vless-router/cgi-bin/api.cgi << 'EOF'
#!/usr/bin/php-cgi
<?php
include('/www/vless-router/api.php');
?>
EOF

cat > /www/vless-router/cgi-bin/setup_api.cgi << 'EOF'
#!/usr/bin/php-cgi
<?php
include('/www/vless-router/setup_api.php');
?>
EOF

# Предоставление прав на исполнение API
chmod +x /www/vless-router/cgi-bin/*.cgi

# Проверка наличия PHP и установка при необходимости
if ! command -v php-cgi > /dev/null 2>&1; then
    echo "PHP не найден, устанавливаем..."
    opkg update
    opkg install php7-cgi
    if [ $? -ne 0 ]; then
        echo "Ошибка: Не удалось установить PHP. Пожалуйста, установите вручную."
        echo "Выполните команду: opkg install php7-cgi"
    fi
fi

# Создание симлинка на setup_api.php для обратной совместимости
ln -sf /www/vless-router/setup_api.php /www/vless-router/cgi-bin/setup_api.php

# Запуск веб-сервера
/etc/init.d/uhttpd start

# Создание симлинка для автозапуска
ln -sf /etc/init.d/uhttpd /etc/rc.d/S80uhttpd

echo "Веб-сервер успешно настроен и запущен на порту 8080"
echo "Доступ: http://$(uci get network.lan.ipaddr):8080" 