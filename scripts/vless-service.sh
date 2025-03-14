#!/bin/sh

# Скрипт для управления VLESS сервисом
XRAY_CONFIG="/etc/xray/config.json"
SETTINGS_FILE="/etc/vless-router/settings.json"
PROFILES_FILE="/etc/vless-router/profiles.json"
WHITELIST_FILE="/etc/vless-router/whitelist.txt"
BLACKLIST_FILE="/etc/vless-router/blacklist.txt"

# Функция для запуска Xray с нужной конфигурацией
start() {
    # Проверяем наличие основных файлов
    if [ ! -f "$SETTINGS_FILE" ]; then
        echo "Файл настроек не найден, создаем стандартный..."
        create_default_settings
    fi

    if [ ! -f "$PROFILES_FILE" ]; then
        echo "Файл профилей не найден, создаем стандартный..."
        create_default_profiles
    fi

    # Создание/обновление конфигурации Xray на основе текущих настроек
    generate_xray_config

    # Запуск Xray
    /etc/init.d/xray start

    # Настройка маршрутизации
    setup_routing

    echo "VLESS сервис запущен"
}

# Остановка сервиса
stop() {
    # Остановка Xray
    /etc/init.d/xray stop

    # Отмена маршрутизации
    cleanup_routing

    echo "VLESS сервис остановлен"
}

# Создание стандартных настроек при первом запуске
create_default_settings() {
    cat > "$SETTINGS_FILE" << EOF
{
    "active_profile": "default",
    "mode": "proxy_all",
    "wifi": {
        "direct_ssid": "VLESS_DIRECT",
        "direct_password": "direct12345",
        "proxy_ssid": "VLESS_PROXY",
        "proxy_password": "proxy12345"
    },
    "proxy_mode": {
        "use_whitelist": false,
        "use_blacklist": true
    }
}
EOF
}

# Создание файла профилей при первом запуске
create_default_profiles() {
    # Получаем профили из vless_profile.md
    grep -E "^vless://" /root/vless_profile.md > /tmp/vless_profiles.txt
    
    # Создаем базовый файл профилей
    cat > "$PROFILES_FILE" << EOF
{
    "profiles": [
EOF

    # Добавляем профили из файла
    FIRST=true
    while IFS= read -r line; do
        # Извлечение имени из профиля
        NAME=$(echo "$line" | grep -oE "#[^#]*$" | sed 's/#//')
        if [ -z "$NAME" ]; then
            NAME="Профиль $(date +%s)"
        fi
        
        # Если это не первый элемент, добавляем запятую
        if [ "$FIRST" = false ]; then
            echo "," >> "$PROFILES_FILE"
        else
            FIRST=false
        fi
        
        # Добавляем профиль в JSON
        cat >> "$PROFILES_FILE" << PROFILE
        {
            "name": "$NAME",
            "url": "$line",
            "enabled": true
        }
PROFILE
    done < /tmp/vless_profiles.txt
    
    # Закрываем JSON
    cat >> "$PROFILES_FILE" << EOF
    ]
}
EOF

    rm /tmp/vless_profiles.txt
}

# Генерация конфигурации Xray на основе настроек и активного профиля
generate_xray_config() {
    # Получение активного профиля
    ACTIVE_PROFILE=$(jsonfilter -i "$SETTINGS_FILE" -e '$.active_profile')
    
    # Получение URL активного профиля
    PROFILE_URL=$(jsonfilter -i "$PROFILES_FILE" -e "$.profiles[@.name='$ACTIVE_PROFILE'].url")
    
    # Если профиль не найден, используем первый в списке
    if [ -z "$PROFILE_URL" ]; then
        PROFILE_URL=$(jsonfilter -i "$PROFILES_FILE" -e "$.profiles[0].url")
    fi
    
    # Парсинг параметров VLESS профиля
    UUID=$(echo "$PROFILE_URL" | grep -oE "vless://[^@]*" | sed 's/vless:\/\///')
    SERVER=$(echo "$PROFILE_URL" | grep -oE "@[^:]*" | sed 's/@//')
    PORT=$(echo "$PROFILE_URL" | grep -oE ":[0-9]*" | sed 's/://')
    
    # Создание конфигурации Xray
    cat > "$XRAY_CONFIG" << EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 12345,
      "protocol": "dokodemo-door",
      "settings": {
        "network": "tcp,udp",
        "followRedirect": true
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      },
      "tag": "transparent"
    }
  ],
  "outbounds": [
    {
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "$SERVER",
            "port": $PORT,
            "users": [
              {
                "id": "$UUID",
                "encryption": "none"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "fingerprint": "chrome",
          "serverName": "nltimes.nl",
          "publicKey": "ObJP-vy-Qksvk30M-NDs_yVbubddLsmMuF0ZND2Kl1k"
        }
      },
      "tag": "proxy"
    },
    {
      "protocol": "freedom",
      "tag": "direct"
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "inboundTag": ["transparent"],
        "outboundTag": "proxy"
      }
    ]
  }
}
EOF
}

# Настройка маршрутизации
setup_routing() {
    # Включение перенаправления IP
    echo 1 > /proc/sys/net/ipv4/ip_forward
    
    # Настройка iptables для прозрачного проксирования
    iptables -t nat -N VLESS_PROXY 2>/dev/null
    iptables -t nat -F VLESS_PROXY
    
    # Читаем режим проксирования
    PROXY_MODE=$(jsonfilter -i "$SETTINGS_FILE" -e '$.mode')
    USE_WHITELIST=$(jsonfilter -i "$SETTINGS_FILE" -e '$.proxy_mode.use_whitelist')
    USE_BLACKLIST=$(jsonfilter -i "$SETTINGS_FILE" -e '$.proxy_mode.use_blacklist')
    
    # Настройка в зависимости от режима
    if [ "$PROXY_MODE" = "proxy_all" ]; then
        # Проксирование всего трафика
        iptables -t nat -A VLESS_PROXY -p tcp -j REDIRECT --to-port 12345
    elif [ "$PROXY_MODE" = "selective" ]; then
        # Выборочное проксирование
        if [ "$USE_WHITELIST" = "true" ] && [ -f "$WHITELIST_FILE" ]; then
            # Использование белого списка (только эти домены через прокси)
            while IFS= read -r domain; do
                [ -z "$domain" ] && continue
                iptables -t nat -A VLESS_PROXY -p tcp -d "$domain" -j REDIRECT --to-port 12345
            done < "$WHITELIST_FILE"
        elif [ "$USE_BLACKLIST" = "true" ] && [ -f "$BLACKLIST_FILE" ]; then
            # Использование черного списка (все кроме этих доменов через прокси)
            iptables -t nat -A VLESS_PROXY -p tcp -j REDIRECT --to-port 12345
            while IFS= read -r domain; do
                [ -z "$domain" ] && continue
                iptables -t nat -A VLESS_PROXY -p tcp -d "$domain" -j RETURN
            done < "$BLACKLIST_FILE"
        else
            # По умолчанию проксируем все
            iptables -t nat -A VLESS_PROXY -p tcp -j REDIRECT --to-port 12345
        fi
    fi
    
    # Добавление правила в цепочку PREROUTING
    iptables -t nat -A PREROUTING -j VLESS_PROXY
}

# Очистка маршрутизации
cleanup_routing() {
    # Удаление правил iptables
    iptables -t nat -D PREROUTING -j VLESS_PROXY 2>/dev/null
    iptables -t nat -F VLESS_PROXY 2>/dev/null
    iptables -t nat -X VLESS_PROXY 2>/dev/null
}

# Переключение профиля
switch_profile() {
    if [ -n "$1" ]; then
        # Проверка существования профиля
        PROFILE_EXISTS=$(jsonfilter -i "$PROFILES_FILE" -e "$.profiles[@.name='$1']")
        if [ -n "$PROFILE_EXISTS" ]; then
            # Обновление активного профиля
            sed -i "s/\"active_profile\": \"[^\"]*\"/\"active_profile\": \"$1\"/" "$SETTINGS_FILE"
            restart
            echo "Профиль переключен на: $1"
        else
            echo "Профиль не найден: $1"
        fi
    else
        echo "Необходимо указать имя профиля"
    fi
}

# Обработка команд
case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        start
        ;;
    switch_profile)
        switch_profile "$2"
        ;;
    *)
        echo "Использование: $0 {start|stop|restart|switch_profile имя_профиля}"
        exit 1
        ;;
esac

exit 0
