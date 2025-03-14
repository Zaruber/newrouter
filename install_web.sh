#!/bin/bash

# VLESS Router Web Installer - Веб-интерфейс для установки
# Этот скрипт запускает веб-сервер и предоставляет графический интерфейс
# для установки VLESS Router на OpenWrt

# Определение цветов для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Определение директории скрипта
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
MAIN_INSTALLER="$SCRIPT_DIR/install.sh"

# Проверка наличия основного установщика
if [ ! -f "$MAIN_INSTALLER" ]; then
    echo -e "${RED}Ошибка: Не найден основной скрипт установки (install.sh)${NC}"
    exit 1
fi

# Создание временной директории
TEMP_DIR=$(mktemp -d)
WEB_PORT=8000

# Функция очистки при выходе
cleanup() {
    echo -e "\n${BLUE}Завершение работы веб-установщика...${NC}"
    if [ ! -z "$PHP_PID" ]; then
        kill $PHP_PID 2>/dev/null
    fi
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

trap cleanup EXIT INT TERM

# Функция для проверки наличия команды
check_command() {
    command -v "$1" &> /dev/null
}

# Проверка наличия PHP
if ! check_command php; then
    echo -e "${RED}Ошибка: PHP не установлен${NC}"
    echo -e "${YELLOW}Для установки PHP выполните:${NC}"
    if [ -f /etc/debian_version ]; then
        echo "sudo apt-get update && sudo apt-get install php-cli"
    elif [ -f /etc/redhat-release ]; then
        echo "sudo dnf install php-cli"
    elif [ -f /etc/arch-release ]; then
        echo "sudo pacman -S php"
    else
        echo "Установите PHP через ваш пакетный менеджер"
    fi
    exit 1
fi

# Создание структуры веб-сервера
echo -e "${BLUE}Подготовка веб-сервера...${NC}"
mkdir -p "$TEMP_DIR/web"

# Копирование веб-файлов
echo -e "${BLUE}Копирование файлов...${NC}"
if [ -d "$SCRIPT_DIR/web" ]; then
    cp -r "$SCRIPT_DIR/web/"* "$TEMP_DIR/web/" 2>/dev/null || true
fi

# Создание API прокси
cat > "$TEMP_DIR/web/api_proxy.php" << 'EOF'
<?php
// API прокси для взаимодействия с основным установщиком
header('Content-Type: application/json');

$action = $_GET['action'] ?? '';
$response = ['success' => false, 'message' => 'Unknown action'];

switch ($action) {
    case 'start_install':
        $data = json_decode(file_get_contents('php://input'), true);
        $ip = $data['ip'] ?? '192.168.1.1';
        $port = $data['port'] ?? '22';
        $user = $data['user'] ?? 'root';
        $password = $data['password'] ?? '';
        
        // Запуск основного установщика с параметрами
        $command = sprintf(
            'bash ../install.sh --ip="%s" --port="%s" --user="%s" --password="%s" 2>&1',
            escapeshellarg($ip),
            escapeshellarg($port),
            escapeshellarg($user),
            escapeshellarg($password)
        );
        
        exec($command, $output, $return_code);
        
        $response = [
            'success' => $return_code === 0,
            'output' => implode("\n", $output),
            'code' => $return_code
        ];
        break;
        
    case 'check_connection':
        $ip = $_GET['ip'] ?? '192.168.1.1';
        $connection = @fsockopen($ip, 22, $errno, $errstr, 5);
        
        if ($connection) {
            fclose($connection);
            $response = ['success' => true, 'message' => 'Connection successful'];
        } else {
            $response = ['success' => false, 'message' => 'Connection failed'];
        }
        break;
}

echo json_encode($response);
EOF

# Создание простого веб-интерфейса
cat > "$TEMP_DIR/web/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>VLESS Router - Веб-установщик</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.7.2/font/bootstrap-icons.css">
    <style>
        .step {
            display: none;
        }
        .step.active {
            display: block;
        }
        .welcome-icon {
            font-size: 64px;
            color: #0d6efd;
            margin-bottom: 20px;
        }
        .step-indicator {
            display: flex;
            justify-content: center;
            margin: 20px 0;
        }
        .step-dot {
            width: 12px;
            height: 12px;
            border-radius: 50%;
            background-color: #dee2e6;
            margin: 0 5px;
            transition: background-color 0.3s;
        }
        .step-dot.active {
            background-color: #0d6efd;
        }
        .terminal {
            background-color: #1e1e1e;
            color: #fff;
            padding: 15px;
            border-radius: 5px;
            font-family: monospace;
            max-height: 300px;
            overflow-y: auto;
        }
        .terminal .success {
            color: #28a745;
        }
        .terminal .error {
            color: #dc3545;
        }
        .terminal .warning {
            color: #ffc107;
        }
    </style>
</head>
<body>
    <div class="container mt-5">
        <div class="row justify-content-center">
            <div class="col-md-8">
                <div class="card">
                    <div class="card-header d-flex justify-content-between align-items-center">
                        <h4 class="mb-0">VLESS Router - Веб-установщик</h4>
                        <span class="badge bg-primary" id="step-badge">1/4</span>
                    </div>
                    <div class="card-body">
                        <!-- Шаг 1: Приветствие -->
                        <div id="step-1" class="step active">
                            <div class="text-center">
                                <div class="welcome-icon">
                                    <i class="bi bi-router"></i>
                                </div>
                                <h3>Добро пожаловать!</h3>
                                <p class="lead">Этот мастер поможет установить VLESS Router на ваш маршрутизатор с OpenWrt</p>
                            </div>
                            <div class="alert alert-info mt-4">
                                <h5><i class="bi bi-info-circle"></i> Перед началом убедитесь, что:</h5>
                                <ul class="mb-0">
                                    <li>Ваш компьютер подключен к роутеру</li>
                                    <li>На роутере установлен OpenWrt</li>
                                    <li>У вас есть доступ к SSH</li>
                                </ul>
                            </div>
                            <div class="d-grid gap-2 mt-4">
                                <button class="btn btn-primary" onclick="nextStep(2)">
                                    Начать установку <i class="bi bi-arrow-right"></i>
                                </button>
                            </div>
                        </div>

                        <!-- Шаг 2: Проверка системы -->
                        <div id="step-2" class="step">
                            <h5><i class="bi bi-check-circle"></i> Проверка системы</h5>
                            <div class="terminal mt-3" id="system-check-log">
                                Проверка необходимых компонентов...
                            </div>
                            <div class="mt-3" id="system-check-status"></div>
                            <div class="d-flex justify-content-between mt-4">
                                <button class="btn btn-outline-secondary" onclick="prevStep(1)">
                                    <i class="bi bi-arrow-left"></i> Назад
                                </button>
                                <button class="btn btn-primary" onclick="checkSystem()" id="check-system-btn">
                                    Проверить систему <i class="bi bi-arrow-right"></i>
                                </button>
                            </div>
                        </div>

                        <!-- Шаг 3: Настройка подключения -->
                        <div id="step-3" class="step">
                            <h5><i class="bi bi-gear"></i> Настройка подключения</h5>
                            <form id="connection-form" class="mt-4">
                                <div class="mb-3">
                                    <label for="routerIp" class="form-label">IP-адрес роутера</label>
                                    <div class="input-group">
                                        <input type="text" class="form-control" id="routerIp" value="192.168.1.1" required>
                                        <button class="btn btn-outline-secondary" type="button" onclick="detectRouter()">
                                            <i class="bi bi-search"></i> Найти
                                        </button>
                                    </div>
                                </div>
                                <div class="mb-3">
                                    <label for="sshPort" class="form-label">SSH порт</label>
                                    <input type="text" class="form-control" id="sshPort" value="22" required>
                                </div>
                                <div class="mb-3">
                                    <label for="sshUser" class="form-label">Имя пользователя</label>
                                    <input type="text" class="form-control" id="sshUser" value="root" required>
                                </div>
                                <div class="mb-3">
                                    <label for="sshPassword" class="form-label">Пароль</label>
                                    <div class="input-group">
                                        <input type="password" class="form-control" id="sshPassword" required>
                                        <button class="btn btn-outline-secondary" type="button" onclick="togglePassword()">
                                            <i class="bi bi-eye"></i>
                                        </button>
                                    </div>
                                </div>
                                <div id="connection-status" class="mt-3" style="display: none;"></div>
                                <div class="d-flex justify-content-between mt-4">
                                    <button type="button" class="btn btn-outline-secondary" onclick="prevStep(2)">
                                        <i class="bi bi-arrow-left"></i> Назад
                                    </button>
                                    <button type="submit" class="btn btn-primary">
                                        Подключиться <i class="bi bi-arrow-right"></i>
                                    </button>
                                </div>
                            </form>
                        </div>

                        <!-- Шаг 4: Установка -->
                        <div id="step-4" class="step">
                            <h5><i class="bi bi-cloud-download"></i> Установка VLESS Router</h5>
                            <div class="progress mt-4">
                                <div class="progress-bar progress-bar-striped progress-bar-animated" 
                                     role="progressbar" id="install-progress" style="width: 0%"></div>
                            </div>
                            <div class="terminal mt-3" id="install-log"></div>
                            <div id="install-status" class="mt-3"></div>
                            <div class="d-flex justify-content-between mt-4">
                                <button class="btn btn-outline-secondary" onclick="prevStep(3)" id="back-to-connection">
                                    <i class="bi bi-arrow-left"></i> Назад
                                </button>
                                <button class="btn btn-success" onclick="finishInstall()" id="finish-install" style="display: none;">
                                    Завершить <i class="bi bi-check-lg"></i>
                                </button>
                            </div>
                        </div>

                        <!-- Индикатор шагов -->
                        <div class="step-indicator">
                            <div class="step-dot active" data-step="1"></div>
                            <div class="step-dot" data-step="2"></div>
                            <div class="step-dot" data-step="3"></div>
                            <div class="step-dot" data-step="4"></div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script>
        // Глобальные переменные
        let currentStep = 1;
        let installationStarted = false;

        // Функции навигации
        function updateStepIndicator(step) {
            document.querySelectorAll('.step-dot').forEach(dot => {
                dot.classList.remove('active');
            });
            document.querySelector(`.step-dot[data-step="${step}"]`).classList.add('active');
            document.getElementById('step-badge').textContent = `${step}/4`;
        }

        function showStep(step) {
            document.querySelectorAll('.step').forEach(s => s.classList.remove('active'));
            document.getElementById(`step-${step}`).classList.add('active');
            updateStepIndicator(step);
            currentStep = step;
        }

        function nextStep(step) {
            showStep(step);
        }

        function prevStep(step) {
            if (!installationStarted) {
                showStep(step);
            }
        }

        // Функции для работы с системой
        async function checkSystem() {
            const btn = document.getElementById('check-system-btn');
            const log = document.getElementById('system-check-log');
            const status = document.getElementById('system-check-status');
            
            btn.disabled = true;
            log.innerHTML = 'Проверка необходимых компонентов...\n';
            
            try {
                const response = await fetch('api_proxy.php?action=check_system');
                const result = await response.json();
                
                if (result.success) {
                    log.innerHTML += '<span class="success">✓ Все необходимые компоненты найдены</span>\n';
                    status.innerHTML = '<div class="alert alert-success">Система готова к установке</div>';
                    setTimeout(() => nextStep(3), 1000);
                } else {
                    log.innerHTML += '<span class="error">✗ Обнаружены проблемы:</span>\n';
                    result.missing.forEach(item => {
                        log.innerHTML += `<span class="error">  - ${item}</span>\n`;
                    });
                    status.innerHTML = '<div class="alert alert-danger">Установите необходимые компоненты и повторите проверку</div>';
                }
            } catch (error) {
                log.innerHTML += `<span class="error">✗ Ошибка при проверке: ${error.message}</span>\n`;
                status.innerHTML = '<div class="alert alert-danger">Произошла ошибка при проверке системы</div>';
            } finally {
                btn.disabled = false;
            }
        }

        // Функции для работы с подключением
        function togglePassword() {
            const input = document.getElementById('sshPassword');
            const icon = document.querySelector('button[onclick="togglePassword()"] i');
            if (input.type === 'password') {
                input.type = 'text';
                icon.classList.replace('bi-eye', 'bi-eye-slash');
            } else {
                input.type = 'password';
                icon.classList.replace('bi-eye-slash', 'bi-eye');
            }
        }

        async function detectRouter() {
            const ipInput = document.getElementById('routerIp');
            const status = document.getElementById('connection-status');
            
            status.style.display = 'block';
            status.className = 'alert alert-info';
            status.innerHTML = '<div class="spinner-border spinner-border-sm me-2"></div> Поиск роутера...';
            
            try {
                const response = await fetch('api_proxy.php?action=detect_router');
                const result = await response.json();
                
                if (result.success && result.ip) {
                    ipInput.value = result.ip;
                    status.className = 'alert alert-success';
                    status.textContent = 'Роутер найден!';
                } else {
                    status.className = 'alert alert-warning';
                    status.textContent = 'Не удалось автоматически найти роутер';
                }
            } catch (error) {
                status.className = 'alert alert-danger';
                status.textContent = 'Ошибка при поиске роутера';
            }
            
            setTimeout(() => {
                status.style.display = 'none';
            }, 3000);
        }

        // Обработчик формы подключения
        document.getElementById('connection-form').addEventListener('submit', async (e) => {
            e.preventDefault();
            
            const status = document.getElementById('connection-status');
            const submitBtn = e.target.querySelector('button[type="submit"]');
            
            status.style.display = 'block';
            status.className = 'alert alert-info';
            status.innerHTML = '<div class="spinner-border spinner-border-sm me-2"></div> Проверка подключения...';
            submitBtn.disabled = true;
            
            const formData = {
                ip: document.getElementById('routerIp').value,
                port: document.getElementById('sshPort').value,
                user: document.getElementById('sshUser').value,
                password: document.getElementById('sshPassword').value
            };
            
            try {
                // Проверка подключения
                const checkResponse = await fetch('api_proxy.php?action=check_connection', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(formData)
                });
                const checkResult = await checkResponse.json();
                
                if (checkResult.success) {
                    status.className = 'alert alert-success';
                    status.textContent = 'Подключение успешно!';
                    setTimeout(() => {
                        nextStep(4);
                        startInstallation(formData);
                    }, 1000);
                } else {
                    status.className = 'alert alert-danger';
                    status.textContent = checkResult.message || 'Ошибка подключения';
                }
            } catch (error) {
                status.className = 'alert alert-danger';
                status.textContent = `Ошибка: ${error.message}`;
            } finally {
                submitBtn.disabled = false;
            }
        });

        // Функции для установки
        async function startInstallation(connectionData) {
            installationStarted = true;
            const log = document.getElementById('install-log');
            const progress = document.getElementById('install-progress');
            const status = document.getElementById('install-status');
            const backBtn = document.getElementById('back-to-connection');
            const finishBtn = document.getElementById('finish-install');
            
            backBtn.disabled = true;
            log.textContent = 'Начало установки...\n';
            progress.style.width = '10%';
            
            try {
                const response = await fetch('api_proxy.php?action=start_install', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(connectionData)
                });
                
                const reader = response.body.getReader();
                const decoder = new TextDecoder();
                
                while (true) {
                    const {value, done} = await reader.read();
                    if (done) break;
                    
                    const text = decoder.decode(value);
                    log.textContent += text;
                    log.scrollTop = log.scrollHeight;
                    
                    // Обновление прогресса на основе вывода
                    if (text.includes('Копирование файлов')) {
                        progress.style.width = '30%';
                    } else if (text.includes('Настройка веб-сервера')) {
                        progress.style.width = '60%';
                    } else if (text.includes('Установка завершена')) {
                        progress.style.width = '100%';
                        status.innerHTML = '<div class="alert alert-success">Установка успешно завершена!</div>';
                        finishBtn.style.display = 'block';
                    }
                }
            } catch (error) {
                log.textContent += `\nОшибка: ${error.message}`;
                status.innerHTML = '<div class="alert alert-danger">Произошла ошибка при установке</div>';
                backBtn.disabled = false;
            }
        }

        function finishInstall() {
            window.location.href = `http://${document.getElementById('routerIp').value}:8080`;
        }
    </script>
</body>
</html>
EOF

# Запуск PHP-сервера
echo -e "${BLUE}Запуск веб-сервера на порту ${PURPLE}$WEB_PORT${NC}..."
cd "$TEMP_DIR/web" && php -S "0.0.0.0:$WEB_PORT" &> /dev/null &
PHP_PID=$!

# Проверка запуска сервера
sleep 2
if ! kill -0 $PHP_PID 2>/dev/null; then
    echo -e "${RED}Ошибка: Не удалось запустить веб-сервер${NC}"
    exit 1
fi

# Определение URL для доступа
if check_command ip; then
    LOCAL_IP=$(ip route get 1 | awk '{print $7; exit}')
elif check_command ifconfig; then
    LOCAL_IP=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n 1)
else
    LOCAL_IP="localhost"
fi

echo -e "${GREEN}Веб-интерфейс доступен по адресу: ${PURPLE}http://$LOCAL_IP:$WEB_PORT${NC}"

# Попытка открыть браузер
if check_command xdg-open; then
    xdg-open "http://$LOCAL_IP:$WEB_PORT" &>/dev/null
elif check_command open; then
    open "http://$LOCAL_IP:$WEB_PORT" &>/dev/null
fi

echo -e "${YELLOW}Для завершения работы нажмите Ctrl+C${NC}"

# Ожидание завершения работы PHP-сервера
wait $PHP_PID 