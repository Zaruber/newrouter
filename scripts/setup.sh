#!/bin/sh

# VLESS Router Setup Script for OpenWrt
# Автоматическая настройка VLESS прокси на роутере OpenWrt

echo "=== Установка необходимых пакетов ==="
opkg update
opkg install xray-core luci-app-xray curl wget uhttpd uhttpd-mod-ubus openvpn-openssl luci-app-openvpn

# Создание директорий для конфигурации и веб-интерфейса
mkdir -p /etc/vless-router
mkdir -p /www/vless-router

# Копирование файлов веб-интерфейса
cp -r /root/vless-router/web/* /www/vless-router/

# Копирование профилей VLESS
cp /root/vless-router/config/profiles.json /etc/vless-router/
cp /root/vless-router/config/settings.json /etc/vless-router/

# Настройка Xray
cp /root/vless-router/config/xray.json /etc/xray/config.json

# Настройка firewall для проксирования
uci add firewall redirect
uci set firewall.@redirect[-1].src='lan'
uci set firewall.@redirect[-1].proto='tcp'
uci set firewall.@redirect[-1].src_dport='80,443'
uci set firewall.@redirect[-1].dest_port='12345'
uci set firewall.@redirect[-1].dest_ip='127.0.0.1'
uci set firewall.@redirect[-1].target='DNAT'
uci set firewall.@redirect[-1].name='VLESS_PROXY'
uci set firewall.@redirect[-1].enabled='1'
uci commit firewall
/etc/init.d/firewall restart

# Настройка веб-сервера для интерфейса управления
cat > /etc/config/uhttpd-vless << EOF
config uhttpd 'main'
    list listen_http '0.0.0.0:8080'
    option home '/www/vless-router'
    option rfc1918_filter '0'
    option max_requests '3'
    option max_connections '100'
    option script_timeout '60'
    option network_timeout '30'
    option http_keepalive '20'
    option tcp_keepalive '1'
    option index_page 'index.html'
    option error_page '/error.html'
EOF

# Запуск веб-сервера
/etc/init.d/uhttpd restart

# Настройка автозапуска
cat > /etc/init.d/vless-router << EOF
#!/bin/sh /etc/rc.common
START=99

start() {
    /root/vless-router/scripts/vless-service.sh start
}

stop() {
    /root/vless-router/scripts/vless-service.sh stop
}

restart() {
    stop
    start
}
EOF

chmod +x /etc/init.d/vless-router
/etc/init.d/vless-router enable

echo "=== Установка завершена ==="
echo "Веб-интерфейс доступен по адресу: http://192.168.1.1:8080"
echo "По умолчанию созданы 2 WIFI сети:"
echo "1. VLESS_DIRECT - без проксирования"
echo "2. VLESS_PROXY - весь трафик через VLESS"

# Запуск сервиса
/root/vless-router/scripts/vless-service.sh start
