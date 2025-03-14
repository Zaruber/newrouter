# VLESS Router для OpenWrt

VLESS Router — это проект для упрощения настройки и управления VLESS прокси на роутерах с OpenWrt. Данное программное обеспечение позволяет легко создавать и управлять WiFi сетями с различными режимами работы (с прокси и без), а также управлять профилями подключения VLESS.

## Возможности

- **Простая установка** с компьютера на роутер через графический интерфейс
- **Полностью веб-интерфейс** для всех настроек, без необходимости использования командной строки
- **Мастер первоначальной настройки** для пошагового подключения роутера к интернету
- Создание **двух WiFi сетей**:
  - Прямая сеть (без прокси)
  - Прокси сеть (весь трафик через VLESS)
- Удобное **управление профилями VLESS**
- **Интуитивно понятный веб-интерфейс** для мониторинга и настройки

## Требования

- Роутер с установленной OpenWrt (рекомендуется версия 21.02 или новее)
- Не менее 4 МБ свободной памяти на роутере
- Компьютер с Windows для установки (или Linux/macOS для опытных пользователей)

## Установка

### Самый простой способ (для Windows)

1. **Скачайте** репозиторий:
   - Используйте кнопку "Code" → "Download ZIP" на GitHub
   - Или клонируйте репозиторий: `git clone https://github.com/Zaruber/newrouter.git`

2. **Запустите установщик** с графическим интерфейсом:
   - Откройте файл `vless-router-installer.ps1` (правой кнопкой мыши → "Запустить с помощью PowerShell")
   - Введите IP-адрес вашего роутера, логин и пароль
   - Нажмите "Установить"

3. **Следуйте инструкциям** в открывшемся веб-браузере:
   - Мастер настройки автоматически откроется и проведет вас через весь процесс
   - Укажите WiFi сеть для подключения к интернету
   - Настройте параметры VLESS и WiFi сетей

### Установка для Linux/macOS

```bash
# Клонируйте репозиторий
git clone https://github.com/Zaruber/newrouter.git
cd newrouter

# Запустите скрипт установки (добавьте параметры при необходимости)
chmod +x install_to_router.sh
./install_to_router.sh [IP роутера] [пользователь] [порт SSH]

# После установки откройте браузер и перейдите по адресу
# http://[IP роутера]:8080
```

### Ручная установка через SSH

Для опытных пользователей, которые предпочитают ручную установку:

```bash
# Подключитесь к роутеру по SSH
ssh root@192.168.1.1

# Создайте директорию для проекта
mkdir -p /root/vless-router

# Выйдите из SSH и скопируйте файлы на роутер
scp -r /path/to/newrouter/* root@192.168.1.1:/root/vless-router/

# Снова подключитесь к роутеру и запустите настройку
ssh root@192.168.1.1
cd /root/vless-router
chmod +x setup_webserver.sh
./setup_webserver.sh

# После этого откройте браузер и перейдите по адресу
# http://192.168.1.1:8080
```

## Использование

### Первоначальная настройка

После открытия веб-интерфейса вы увидите мастер настройки, который проведет вас через следующие шаги:

1. **Подключение к интернету**:
   - Сканирование доступных WiFi сетей
   - Подключение к вашей домашней WiFi сети

2. **Установка необходимых пакетов**:
   - Автоматическая установка Xray и других компонентов
   - Настройка сетевых параметров

3. **Настройка WiFi сетей**:
   - Создание прямой сети (без прокси)
   - Создание прокси сети (с VLESS)

4. **Настройка профиля VLESS**:
   - Добавление данных для подключения к серверу VLESS
   - Выбор режима работы прокси

### Управление системой

После завершения настройки вы получите доступ к основному интерфейсу с разделами:

- **Панель управления**: просмотр статуса системы, состояния соединений
- **Профили**: управление профилями VLESS
- **Сайты**: настройка проксирования для конкретных сайтов
- **WiFi**: настройка параметров WiFi сетей
- **Настройки**: общие настройки системы

### WiFi сети

После настройки на вашем роутере будут созданы две WiFi сети:

1. **VLESS_DIRECT** - сеть без проксирования трафика
2. **VLESS_PROXY** - сеть с проксированием всего трафика через VLESS

## Устранение неполадок

### Не удается подключиться к веб-интерфейсу

1. **Проверьте подключение к роутеру**:
   - Убедитесь, что ваш компьютер подключен к сети роутера
   - Убедитесь, что роутер включен и работает

2. **Проверьте IP-адрес роутера**:
   - Обычно это 192.168.1.1 или 192.168.0.1
   - Попробуйте перейти по адресу http://192.168.1.1:8080

3. **Перезапустите установку**:
   - Запустите установщик еще раз
   - Убедитесь, что все данные введены правильно

### Проблемы с подключением к интернету

1. **Проверьте настройки WiFi**:
   - Убедитесь, что данные домашней WiFi сети введены правильно
   - Проверьте доступность домашней WiFi сети

2. **Проверьте сигнал WiFi**:
   - Убедитесь, что роутер находится в зоне действия домашней WiFi сети
   - При необходимости переместите роутер ближе к источнику сигнала

## Часто задаваемые вопросы (FAQ)

### Как обновить VLESS Router до новой версии?

Просто запустите установщик заново с актуальной версией проекта. Ваши настройки будут сохранены.

### Можно ли использовать VLESS Router на первичном роутере?

Да, но рекомендуется использовать его на вторичном роутере для большей гибкости в настройке сетей.

### Как сменить пароль WiFi сетей после установки?

В веб-интерфейсе перейдите в раздел "WiFi" и измените настройки для соответствующей сети.

### Как добавить новый профиль VLESS?

В веб-интерфейсе перейдите в раздел "Профили" и нажмите кнопку "Добавить профиль".

## Вклад в проект

Если вы хотите внести свой вклад в проект, пожалуйста:

1. Сделайте форк репозитория
2. Создайте ветку для вашей функциональности (`git checkout -b feature/amazing-feature`)
3. Зафиксируйте ваши изменения (`git commit -m 'Add some amazing feature'`)
4. Отправьте изменения в ветку (`git push origin feature/amazing-feature`)
5. Откройте Pull Request

## Лицензия

Этот проект распространяется под лицензией MIT. См. файл `LICENSE` для получения дополнительной информации.

## Отказ от ответственности

Данное программное обеспечение предоставляется "как есть", без каких-либо гарантий. Авторы не несут ответственности за любой возможный ущерб, связанный с использованием данного ПО. Используйте на свой страх и риск.

---

© 2023 VLESS Router Project
