# VLESS Router для OpenWrt

VLESS Router — это проект для упрощения настройки и управления VLESS прокси на роутерах с OpenWrt. Данное программное обеспечение позволяет легко создавать и управлять WiFi сетями с различными режимами работы (с прокси и без), а также управлять профилями подключения VLESS.

## Возможности

- Простая установка с компьютера на роутер
- Мастер первоначальной настройки
- Создание двух WiFi сетей:
  - Прямая сеть (без прокси)
  - Прокси сеть (весь трафик через VLESS)
- Управление профилями VLESS
- Простой веб-интерфейс для мониторинга и настройки

## Требования

- Роутер с установленной OpenWrt (рекомендуется версия 21.02 или новее)
- Не менее 4 МБ свободной памяти на роутере
- Компьютер с Windows, macOS или Linux для установки

## Установка

### 1. Клонирование репозитория

Склонируйте данный репозиторий на ваш компьютер:

```bash
git clone https://github.com/Zaruber/newrouter.git
cd vless-router
```

### 2. Установка на роутер

#### Для Linux/macOS:

```bash
chmod +x install_to_router.sh
./install_to_router.sh 192.168.1.1 [пользователь] [порт SSH]
```

#### Для Windows:

```bash
install_to_router.bat 192.168.1.1 [пользователь] [порт SSH]
```

Где:
- `192.168.1.1` - IP-адрес вашего роутера (замените на актуальный)
- `[пользователь]` - имя пользователя для SSH подключения (по умолчанию `root`)
- `[порт SSH]` - порт SSH на роутере (по умолчанию `22`)

### 3. Завершение установки через веб-интерфейс

После успешного копирования файлов на роутер, откройте браузер и перейдите по адресу:

```
http://IP-адрес-роутера:8080
```

Следуйте указаниям мастера настройки для завершения установки:

1. Подключение к WiFi сети для доступа в интернет
2. Установка необходимых пакетов
3. Настройка WiFi сетей
4. Создание профиля VLESS

## Использование

### Панель управления

После завершения установки вы можете использовать веб-интерфейс для управления VLESS Router:

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

1. Убедитесь, что вы подключены к сети роутера
2. Проверьте, что веб-сервер запущен: `ssh root@192.168.1.1 "ps | grep uhttpd"`
3. Перезапустите веб-сервер: `ssh root@192.168.1.1 "/etc/init.d/uhttpd restart"`

### Проблемы с WiFi

1. Перезапустите WiFi на роутере: `ssh root@192.168.1.1 "wifi reload"`
2. Проверьте настройки WiFi: `ssh root@192.168.1.1 "uci show wireless"`

### Проблемы с прокси

1. Перезапустите сервис VLESS: `ssh root@192.168.1.1 "/root/vless-router/scripts/vless-service.sh restart"`
2. Проверьте, что служба запущена: `ssh root@192.168.1.1 "ps | grep xray"`

## Часто задаваемые вопросы (FAQ)

### Ошибка "WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED" при установке

**Проблема:** При установке появляется ошибка вида:

```
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
IT IS POSSIBLE THAT SOMEONE IS DOING SOMETHING NASTY!
Someone could be eavesdropping on you right now (man-in-the-middle attack)!
It is also possible that a host key has just been changed.
```

Это означает, что SSH не может подтвердить аутентификацию по ключу, и подключение не удается.

**Причина:** Это может произойти, когда SSH обнаруживает изменение ключа хоста для того же IP-адреса.

**Решение:** Удалите старый ключ хоста из файла known_hosts командой:

```bash
ssh-keygen -f "~/.ssh/known_hosts" -R "Ваш_IP_роутера"
```

Например:
```bash
ssh-keygen -f ~/.ssh/known_hosts -R 192.168.1.1
```

После этого SSH автоматически добавит новый ключ хоста при следующем подключении.

### Ошибки при использовании sshpass и паролей с специальными символами

**Проблема:** Некоторые версии sshpass могут неправильно обрабатывать пароли, содержащие специальные символы ($, !, #, &, ", ', и т.д.).

**Решение:**
1. Используйте пароль без специальных символов.
2. При указании пароля в командной строке заключайте его в одинарные кавычки.
3. Настройте аутентификацию по ключу (рекомендуется):

```bash
# Создание ключа SSH (email не обязательен)
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"

# Копирование ключа на роутер
ssh-copy-id root@192.168.1.1
```

После этого можно использовать sshpass без указания пароля.

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
