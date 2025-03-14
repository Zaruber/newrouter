#!/bin/sh

# VLESS Router Setup Script for OpenWrt
# Автоматическая настройка VLESS прокси на роутере OpenWrt

echo "=== VLESS Router Setup ==="

# Создание директорий для конфигурации и веб-интерфейса
mkdir -p /etc/vless-router
mkdir -p /www/vless-router
mkdir -p /tmp/vless-router

# Копирование файлов веб-интерфейса
cp -r /root/vless-router/web/* /www/vless-router/

# Создание API-скрипта для первоначальной настройки
cat > /www/vless-router/setup_api.cgi << 'EOF'
#!/bin/sh
echo "Content-type: application/json"
echo ""

# Получаем данные из запроса
read POST_DATA

# Обработка запроса
case "$PATH_INFO" in
    /scan_wifi)
        # Сканирование доступных WiFi сетей
        SCAN_RESULT=$(iwinfo wlan0 scan | grep ESSID | sed 's/.*ESSID: "//g' | sed 's/".*//g')
        echo "{ \"networks\": [\"$(echo $SCAN_RESULT | sed 's/ /\", \"/g')\"] }"
        ;;
    /connect_wifi)
        # Подключение к WiFi сети
        SSID=$(echo $POST_DATA | grep -o '"ssid":"[^"]*"' | sed 's/"ssid":"//g' | sed 's/"//g')
        PASSWORD=$(echo $POST_DATA | grep -o '"password":"[^"]*"' | sed 's/"password":"//g' | sed 's/"//g')
        
        # Настройка WiFi соединения
        uci set wireless.wwan=wifi-iface
        uci set wireless.wwan.device=radio0
        uci set wireless.wwan.network=wwan
        uci set wireless.wwan.mode=sta
        uci set wireless.wwan.ssid="$SSID"
        uci set wireless.wwan.encryption=psk2
        uci set wireless.wwan.key="$PASSWORD"
        
        # Создание сетевого интерфейса wwan
        uci set network.wwan=interface
        uci set network.wwan.proto=dhcp
        uci set network.wwan.metric=10
        
        # Применение настроек
        uci commit wireless
        uci commit network
        wifi reload
        /etc/init.d/network restart
        
        sleep 5
        
        # Проверка подключения
        INTERNET_CHECK=$(ping -c 1 -W 3 8.8.8.8 > /dev/null 2>&1 && echo "ok" || echo "fail")
        
        if [ "$INTERNET_CHECK" = "ok" ]; then
            echo "{ \"status\": \"success\", \"message\": \"WiFi успешно подключен\" }"
        else
            echo "{ \"status\": \"error\", \"message\": \"Не удалось подключиться к WiFi\" }"
        fi
        ;;
    /install_packages)
        # Установка необходимых пакетов
        opkg update > /tmp/opkg_update.log 2>&1
        opkg install xray-core luci-app-xray curl wget uhttpd uhttpd-mod-ubus openvpn-openssl luci-app-openvpn > /tmp/opkg_install.log 2>&1
        
        if [ $? -eq 0 ]; then
            echo "{ \"status\": \"success\", \"message\": \"Пакеты успешно установлены\" }"
        else
            echo "{ \"status\": \"error\", \"message\": \"Ошибка установки пакетов\", \"log\": \"$(cat /tmp/opkg_install.log | sed 's/"/\\\"/g')\" }"
        fi
        ;;
    /configure_vless)
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
        
        echo "{ \"status\": \"success\", \"message\": \"VLESS настроен\" }"
        ;;
    /configure_web)
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
        
        echo "{ \"status\": \"success\", \"message\": \"Веб-сервер настроен\" }"
        ;;
    /start_vless)
        # Запуск сервиса
        /root/vless-router/scripts/vless-service.sh start
        
        echo "{ \"status\": \"success\", \"message\": \"VLESS запущен\" }"
        ;;
esac
EOF

chmod +x /www/vless-router/setup_api.cgi

echo "=== VLESS Router Setup Complete ==="
echo "Веб-интерфейс доступен по адресу: http://192.168.1.1:8080"
