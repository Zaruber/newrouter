#!/bin/bash

# VLESS Router Web Installer - Веб-интерфейс для установки на OpenWrt
# Скрипт запускает локальный веб-сервер на компьютере Ubuntu и предоставляет
# веб-интерфейс для настройки роутера с OpenWrt

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для вывода сообщений
print_message() {
    echo -e "${BLUE}[VLESS Router]${NC} $1"
}

# Функция для вывода ошибок
print_error() {
    echo -e "${RED}[ОШИБКА]${NC} $1"
}

# Функция для вывода успешных сообщений
print_success() {
    echo -e "${GREEN}[УСПЕШНО]${NC} $1"
}

# Функция для вывода предупреждений
print_warning() {
    echo -e "${YELLOW}[ВНИМАНИЕ]${NC} $1"
}

# Функция для проверки наличия команды
check_command() {
    if ! command -v $1 &> /dev/null; then
        print_error "Команда '$1' не найдена. Пожалуйста, установите необходимые зависимости."
        case $1 in
            ssh|scp)
                echo "Для установки выполните: sudo apt-get install openssh-client"
                ;;
            php)
                echo "Для установки выполните: sudo apt-get install php"
                ;;
            xdg-open)
                echo "Для установки выполните: sudo apt-get install xdg-utils"
                ;;
        esac
        exit 1
    fi
}

# Получение IP-адреса локальной машины
get_local_ip() {
    ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n 1
}

# Функция для остановки веб-сервера при выходе
cleanup() {
    print_message "Останавливаю веб-сервер..."
    if [ -n "$PHP_PID" ]; then
        kill $PHP_PID 2>/dev/null
    fi
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
    print_message "Выход из установщика."
    exit 0
}

# Перехват сигналов для корректного завершения
trap cleanup SIGINT SIGTERM EXIT

# Заголовок
echo -e "${BLUE}"
echo "------------------------------------------------------"
echo "    VLESS Router - Веб-установщик для Linux/Ubuntu    "
echo "------------------------------------------------------"
echo -e "${NC}"
echo "  Этот мастер поможет установить VLESS Router на ваш"
echo "  маршрутизатор с OpenWrt через веб-интерфейс."
echo ""

# Проверка наличия необходимых команд
print_message "Проверка зависимостей..."
check_command ssh
check_command scp
check_command php
check_command xdg-open

# Определение директории скрипта
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Создание временной директории для веб-сервера
TEMP_DIR=$(mktemp -d)
print_message "Создание временной директории для веб-сервера: $TEMP_DIR"

# Копирование файлов для веб-установщика
mkdir -p "$TEMP_DIR/web"
mkdir -p "$TEMP_DIR/cgi-bin"
mkdir -p "$TEMP_DIR/js"
mkdir -p "$TEMP_DIR/css"

# Созаем файл для API
cat > "$TEMP_DIR/cgi-bin/api.php" << 'EOF'
<?php
header('Content-Type: application/json');

function execute_command($command) {
    $output = array();
    $return_var = 0;
    exec($command . " 2>&1", $output, $return_var);
    return array(
        'output' => $output,
        'status' => $return_var
    );
}

// Проверка соединения с роутером
function check_router_connection($ip) {
    $result = execute_command("ping -c 1 -W 2 " . escapeshellarg($ip));
    return $result['status'] === 0;
}

// Проверка SSH соединения
function check_ssh_connection($ip, $port, $user, $password = "") {
    $command = "sshpass -p " . escapeshellarg($password) . " ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -p " . escapeshellarg($port) . " " . escapeshellarg($user) . "@" . escapeshellarg($ip) . " 'echo OK'";
    $result = execute_command($command);
    return $result['status'] === 0;
}

// Установка на роутер
function install_to_router($ip, $port, $user, $password, $files_path) {
    $results = array();
    
    // Создание директории на роутере
    $cmd_mkdir = "sshpass -p " . escapeshellarg($password) . " ssh -o StrictHostKeyChecking=no -p " . escapeshellarg($port) . " " . escapeshellarg($user) . "@" . escapeshellarg($ip) . " 'mkdir -p /root/vless-router'";
    $results['mkdir'] = execute_command($cmd_mkdir);
    
    if ($results['mkdir']['status'] !== 0) {
        return array('success' => false, 'step' => 'mkdir', 'message' => 'Не удалось создать директорию на роутере');
    }
    
    // Копирование файлов на роутер
    $files_to_copy = array('config', 'scripts', 'web', 'setup_webserver.sh', 'README.md');
    $results['copy'] = array();
    
    foreach ($files_to_copy as $file) {
        if (file_exists($files_path . '/' . $file)) {
            $cmd_scp = "sshpass -p " . escapeshellarg($password) . " scp -r -o StrictHostKeyChecking=no -P " . escapeshellarg($port) . " " . escapeshellarg($files_path . '/' . $file) . " " . escapeshellarg($user . "@" . $ip . ":/root/vless-router/");
            $result = execute_command($cmd_scp);
            $results['copy'][$file] = $result;
            
            if ($result['status'] !== 0) {
                return array('success' => false, 'step' => 'copy', 'file' => $file, 'message' => 'Не удалось скопировать файл ' . $file);
            }
        }
    }
    
    // Настройка веб-сервера на роутере
    $cmd_setup = "sshpass -p " . escapeshellarg($password) . " ssh -o StrictHostKeyChecking=no -p " . escapeshellarg($port) . " " . escapeshellarg($user) . "@" . escapeshellarg($ip) . " 'cd /root/vless-router && chmod +x ./setup_webserver.sh && ./setup_webserver.sh'";
    $results['setup'] = execute_command($cmd_setup);
    
    if ($results['setup']['status'] !== 0) {
        return array('success' => false, 'step' => 'setup', 'message' => 'Не удалось настроить веб-сервер на роутере');
    }
    
    return array('success' => true, 'results' => $results);
}

// Обработка запросов
$action = isset($_GET['action']) ? $_GET['action'] : '';
$response = array('success' => false, 'message' => 'Неизвестное действие');

switch ($action) {
    case 'check_router':
        $ip = isset($_GET['ip']) ? $_GET['ip'] : '';
        if (empty($ip)) {
            $response = array('success' => false, 'message' => 'IP-адрес не указан');
        } else {
            $connected = check_router_connection($ip);
            $response = array('success' => true, 'connected' => $connected);
        }
        break;
        
    case 'check_ssh':
        $data = json_decode(file_get_contents('php://input'), true);
        $ip = isset($data['ip']) ? $data['ip'] : '';
        $port = isset($data['port']) ? $data['port'] : '22';
        $user = isset($data['user']) ? $data['user'] : 'root';
        $password = isset($data['password']) ? $data['password'] : '';
        
        if (empty($ip)) {
            $response = array('success' => false, 'message' => 'IP-адрес не указан');
        } else {
            $connected = check_ssh_connection($ip, $port, $user, $password);
            $response = array('success' => true, 'connected' => $connected);
        }
        break;
        
    case 'install':
        $data = json_decode(file_get_contents('php://input'), true);
        $ip = isset($data['ip']) ? $data['ip'] : '';
        $port = isset($data['port']) ? $data['port'] : '22';
        $user = isset($data['user']) ? $data['user'] : 'root';
        $password = isset($data['password']) ? $data['password'] : '';
        $files_path = isset($data['files_path']) ? $data['files_path'] : dirname(dirname(__FILE__));
        
        if (empty($ip)) {
            $response = array('success' => false, 'message' => 'IP-адрес не указан');
        } else {
            $result = install_to_router($ip, $port, $user, $password, $files_path);
            $response = $result;
        }
        break;
}

echo json_encode($response);
EOF

# Создаем index.html для веб-интерфейса
cat > "$TEMP_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>VLESS Router - Веб-установщик</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.2.3/dist/css/bootstrap.min.css">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.3/font/bootstrap-icons.css">
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
        }
        .step-dot.active {
            background-color: #0d6efd;
        }
        pre.log {
            max-height: 200px;
            overflow-y: auto;
            background-color: #f8f9fa;
            padding: 10px;
            border-radius: 5px;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="row justify-content-center mt-4">
            <div class="col-md-8">
                <div class="card">
                    <div class="card-header d-flex justify-content-between align-items-center">
                        <h4 class="mb-0">VLESS Router - Веб-установщик</h4>
                        <span class="badge bg-primary" id="step-badge">1/3</span>
                    </div>
                    <div class="card-body">
                        <!-- Шаг 1: Приветствие -->
                        <div id="step-1" class="step active">
                            <div class="text-center mb-4">
                                <div class="welcome-icon">
                                    <i class="bi bi-router"></i>
                                </div>
                                <h3>Добро пожаловать в установщик VLESS Router!</h3>
                                <p class="lead">Этот мастер поможет вам установить VLESS Router на ваш OpenWrt роутер.</p>
                            </div>
                            <div class="alert alert-info">
                                <i class="bi bi-info-circle-fill"></i> Убедитесь, что ваш компьютер подключен к роутеру с OpenWrt.
                            </div>
                            <p>Процесс установки включает в себя следующие шаги:</p>
                            <ol>
                                <li>Подключение к роутеру по SSH</li>
                                <li>Копирование необходимых файлов</li>
                                <li>Настройка и запуск веб-интерфейса на роутере</li>
                            </ol>
                            <div class="d-grid gap-2 mt-4">
                                <button class="btn btn-primary" id="btn-start">
                                    Начать установку <i class="bi bi-arrow-right"></i>
                                </button>
                            </div>
                        </div>

                        <!-- Шаг 2: Подключение к роутеру -->
                        <div id="step-2" class="step">
                            <h5>Шаг 1: Подключение к роутеру</h5>
                            <div class="mb-3">
                                <label for="router-ip" class="form-label">IP-адрес роутера</label>
                                <input type="text" class="form-control" id="router-ip" value="192.168.1.1">
                            </div>
                            <div class="mb-3">
                                <label for="ssh-port" class="form-label">SSH порт</label>
                                <input type="text" class="form-control" id="ssh-port" value="22">
                            </div>
                            <div class="mb-3">
                                <label for="ssh-user" class="form-label">Имя пользователя</label>
                                <input type="text" class="form-control" id="ssh-user" value="root">
                            </div>
                            <div class="mb-3">
                                <label for="ssh-password" class="form-label">Пароль</label>
                                <input type="password" class="form-control" id="ssh-password">
                            </div>
                            <div class="d-flex justify-content-between mt-4">
                                <button class="btn btn-outline-secondary" id="btn-back-to-welcome">Назад</button>
                                <button class="btn btn-primary" id="btn-check-connection">
                                    Проверить подключение <i class="bi bi-arrow-right"></i>
                                </button>
                            </div>
                            <div id="connection-status" class="mt-3" style="display: none;"></div>
                        </div>

                        <!-- Шаг 3: Установка на роутер -->
                        <div id="step-3" class="step">
                            <h5>Шаг 2: Установка на роутер</h5>
                            <div class="alert alert-info mb-4">
                                <i class="bi bi-info-circle-fill"></i> Сейчас будет выполнена установка VLESS Router на ваш роутер.
                            </div>
                            <div class="progress mb-3">
                                <div class="progress-bar" role="progressbar" id="install-progress" style="width: 0%"></div>
                            </div>
                            <div id="install-status" class="alert alert-primary">
                                Готов к установке...
                            </div>
                            <pre class="log" id="install-log"></pre>
                            <div class="d-flex justify-content-between mt-4">
                                <button class="btn btn-outline-secondary" id="btn-back-to-connection">Назад</button>
                                <button class="btn btn-primary" id="btn-install">
                                    Установить <i class="bi bi-arrow-right"></i>
                                </button>
                            </div>
                        </div>

                        <!-- Шаг 4: Завершение -->
                        <div id="step-4" class="step">
                            <div class="text-center mb-4">
                                <div class="welcome-icon text-success">
                                    <i class="bi bi-check-circle-fill"></i>
                                </div>
                                <h3>Установка завершена!</h3>
                                <p class="lead">VLESS Router успешно установлен на ваш роутер.</p>
                            </div>
                            <div class="alert alert-success">
                                <i class="bi bi-info-circle-fill"></i> Веб-интерфейс VLESS Router доступен по адресу:
                                <div class="d-grid gap-2 mt-2">
                                    <a id="router-web-url" href="#" target="_blank" class="btn btn-outline-success">
                                        <i class="bi bi-box-arrow-up-right"></i> Открыть веб-интерфейс
                                    </a>
                                </div>
                            </div>
                            <div class="text-center mt-4">
                                <p>Теперь вы можете использовать веб-интерфейс для дальнейшей настройки VLESS Router.</p>
                                <button class="btn btn-primary" id="btn-finish">
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

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.2.3/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        document.addEventListener('DOMContentLoaded', function() {
            // Элементы навигации
            const stepDots = document.querySelectorAll('.step-dot');
            const stepBadge = document.getElementById('step-badge');
            
            // Шаги
            const step1 = document.getElementById('step-1');
            const step2 = document.getElementById('step-2');
            const step3 = document.getElementById('step-3');
            const step4 = document.getElementById('step-4');
            
            // Кнопки навигации
            const btnStart = document.getElementById('btn-start');
            const btnBackToWelcome = document.getElementById('btn-back-to-welcome');
            const btnCheckConnection = document.getElementById('btn-check-connection');
            const btnBackToConnection = document.getElementById('btn-back-to-connection');
            const btnInstall = document.getElementById('btn-install');
            const btnFinish = document.getElementById('btn-finish');
            
            // Поля формы
            const routerIpInput = document.getElementById('router-ip');
            const sshPortInput = document.getElementById('ssh-port');
            const sshUserInput = document.getElementById('ssh-user');
            const sshPasswordInput = document.getElementById('ssh-password');
            
            // Статусы
            const connectionStatus = document.getElementById('connection-status');
            const installStatus = document.getElementById('install-status');
            const installLog = document.getElementById('install-log');
            const installProgress = document.getElementById('install-progress');
            const routerWebUrl = document.getElementById('router-web-url');
            
            // Переключение между шагами
            function goToStep(step) {
                document.querySelectorAll('.step').forEach(s => s.classList.remove('active'));
                document.getElementById(`step-${step}`).classList.add('active');
                
                stepDots.forEach(dot => dot.classList.remove('active'));
                stepDots[step - 1].classList.add('active');
                
                stepBadge.textContent = `${step}/4`;
            }
            
            // Проверка соединения с роутером
            async function checkRouterConnection() {
                const ip = routerIpInput.value;
                if (!ip) {
                    showConnectionError('Введите IP-адрес роутера');
                    return false;
                }
                
                btnCheckConnection.disabled = true;
                btnCheckConnection.innerHTML = '<span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span> Проверка...';
                
                try {
                    const response = await fetch(`cgi-bin/api.php?action=check_router&ip=${encodeURIComponent(ip)}`);
                    const data = await response.json();
                    
                    if (data.success && data.connected) {
                        return true;
                    } else {
                        showConnectionError('Не удается подключиться к роутеру. Проверьте IP-адрес и соединение.');
                        return false;
                    }
                } catch (error) {
                    showConnectionError(`Ошибка при проверке соединения: ${error.message}`);
                    return false;
                } finally {
                    btnCheckConnection.disabled = false;
                    btnCheckConnection.innerHTML = 'Проверить подключение <i class="bi bi-arrow-right"></i>';
                }
            }
            
            // Проверка SSH соединения
            async function checkSSHConnection() {
                const ip = routerIpInput.value;
                const port = sshPortInput.value;
                const user = sshUserInput.value;
                const password = sshPasswordInput.value;
                
                if (!password) {
                    showConnectionError('Введите пароль для SSH-подключения');
                    return false;
                }
                
                btnCheckConnection.disabled = true;
                btnCheckConnection.innerHTML = '<span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span> Проверка SSH...';
                
                try {
                    const response = await fetch('cgi-bin/api.php?action=check_ssh', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                        },
                        body: JSON.stringify({ ip, port, user, password }),
                    });
                    const data = await response.json();
                    
                    if (data.success && data.connected) {
                        showConnectionSuccess('Успешное подключение к роутеру!');
                        return true;
                    } else {
                        showConnectionError('Не удается подключиться к роутеру по SSH. Проверьте учетные данные.');
                        return false;
                    }
                } catch (error) {
                    showConnectionError(`Ошибка при проверке SSH-соединения: ${error.message}`);
                    return false;
                } finally {
                    btnCheckConnection.disabled = false;
                    btnCheckConnection.innerHTML = 'Проверить подключение <i class="bi bi-arrow-right"></i>';
                }
            }
            
            // Показать ошибку подключения
            function showConnectionError(message) {
                connectionStatus.innerHTML = `
                    <div class="alert alert-danger">
                        <i class="bi bi-exclamation-triangle-fill"></i> ${message}
                    </div>
                `;
                connectionStatus.style.display = 'block';
            }
            
            // Показать успешное подключение
            function showConnectionSuccess(message) {
                connectionStatus.innerHTML = `
                    <div class="alert alert-success">
                        <i class="bi bi-check-circle-fill"></i> ${message}
                    </div>
                    <div class="d-grid gap-2 mt-2">
                        <button class="btn btn-success" id="btn-go-to-install">
                            Продолжить установку <i class="bi bi-arrow-right"></i>
                        </button>
                    </div>
                `;
                connectionStatus.style.display = 'block';
                
                document.getElementById('btn-go-to-install').addEventListener('click', function() {
                    goToStep(3);
                });
            }
            
            // Установка на роутер
            async function installToRouter() {
                const ip = routerIpInput.value;
                const port = sshPortInput.value;
                const user = sshUserInput.value;
                const password = sshPasswordInput.value;
                
                btnInstall.disabled = true;
                btnBackToConnection.disabled = true;
                btnInstall.innerHTML = '<span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span> Установка...';
                
                installStatus.className = 'alert alert-primary';
                installStatus.innerHTML = '<i class="bi bi-gear-fill"></i> Начало установки...';
                installProgress.style.width = '10%';
                installLog.textContent = '';
                
                try {
                    // Получение пути к файлам
                    const filesPath = window.filesPath || '';
                    
                    updateStatus('Подключение к роутеру...', 20);
                    appendLog('Подключение к роутеру...');
                    
                    const response = await fetch('cgi-bin/api.php?action=install', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                        },
                        body: JSON.stringify({ ip, port, user, password, files_path: filesPath }),
                    });
                    const data = await response.json();
                    
                    if (data.success) {
                        updateStatus('Создание директории на роутере...', 40);
                        appendLog('Директория успешно создана на роутере.');
                        
                        updateStatus('Копирование файлов на роутер...', 60);
                        appendLog('Копирование файлов:');
                        for (const file in data.results.copy) {
                            appendLog(`- ${file}: успешно`);
                        }
                        
                        updateStatus('Настройка веб-сервера на роутере...', 80);
                        appendLog('Настройка веб-сервера:');
                        appendLog(data.results.setup.output.join('\n'));
                        
                        updateStatus('Установка завершена успешно!', 100, 'success');
                        
                        // Установка URL для веб-интерфейса
                        const routerWebUrlElement = document.getElementById('router-web-url');
                        const webUrl = `http://${ip}:8080`;
                        routerWebUrlElement.href = webUrl;
                        routerWebUrlElement.textContent = webUrl;
                        
                        // Переход к завершающему шагу через 2 секунды
                        setTimeout(() => {
                            goToStep(4);
                        }, 2000);
                        
                        return true;
                    } else {
                        const errorStep = data.step || 'unknown';
                        const errorMessage = data.message || 'Неизвестная ошибка при установке';
                        
                        updateStatus(`Ошибка при установке: ${errorMessage}`, 0, 'danger');
                        appendLog(`ОШИБКА: ${errorMessage}`);
                        
                        if (errorStep === 'copy' && data.file) {
                            appendLog(`Не удалось скопировать файл: ${data.file}`);
                        }
                        
                        btnInstall.disabled = false;
                        btnBackToConnection.disabled = false;
                        btnInstall.innerHTML = 'Повторить установку <i class="bi bi-arrow-repeat"></i>';
                        
                        return false;
                    }
                } catch (error) {
                    updateStatus(`Ошибка при установке: ${error.message}`, 0, 'danger');
                    appendLog(`ОШИБКА: ${error.message}`);
                    
                    btnInstall.disabled = false;
                    btnBackToConnection.disabled = false;
                    btnInstall.innerHTML = 'Повторить установку <i class="bi bi-arrow-repeat"></i>';
                    
                    return false;
                }
            }
            
            // Обновление статуса установки
            function updateStatus(message, progress, type = 'primary') {
                installStatus.className = `alert alert-${type}`;
                installStatus.innerHTML = `<i class="bi bi-${type === 'success' ? 'check-circle-fill' : type === 'danger' ? 'exclamation-triangle-fill' : 'gear-fill'}"></i> ${message}`;
                installProgress.style.width = `${progress}%`;
                installProgress.className = `progress-bar bg-${type}`;
            }
            
            // Добавление сообщения в лог
            function appendLog(message) {
                installLog.textContent += message + '\n';
                installLog.scrollTop = installLog.scrollHeight;
            }
            
            // Обработчики событий
            btnStart.addEventListener('click', function() {
                goToStep(2);
            });
            
            btnBackToWelcome.addEventListener('click', function() {
                goToStep(1);
            });
            
            btnCheckConnection.addEventListener('click', async function() {
                const routerConnected = await checkRouterConnection();
                if (routerConnected) {
                    const sshConnected = await checkSSHConnection();
                }
            });
            
            btnBackToConnection.addEventListener('click', function() {
                goToStep(2);
            });
            
            btnInstall.addEventListener('click', async function() {
                await installToRouter();
            });
            
            btnFinish.addEventListener('click', function() {
                window.close();
            });
            
            // Сохраняем путь к файлам
            window.filesPath = 'SCRIPT_PATH_PLACEHOLDER';
        });
    </script>
</body>
</html>
EOF

# Создаем скрипт для запуска PHP-сервера
cat > "$TEMP_DIR/run_server.sh" << EOF
#!/bin/bash
cd "$TEMP_DIR"
php -S 0.0.0.0:8000 -t .
EOF

# Делаем скрипт исполняемым
chmod +x "$TEMP_DIR/run_server.sh"

# Получаем IP-адрес локальной машины
LOCAL_IP=$(get_local_ip)
if [ -z "$LOCAL_IP" ]; then
    LOCAL_IP="localhost"
fi

# Заменяем плейсхолдер с путем к скрипту в файле HTML
sed -i "s|SCRIPT_PATH_PLACEHOLDER|$SCRIPT_DIR|g" "$TEMP_DIR/index.html"

# Проверка наличия sshpass
if ! command -v sshpass &> /dev/null; then
    print_warning "Пакет sshpass не установлен. Он необходим для работы веб-установщика."
    read -p "Установить sshpass сейчас? (y/n): " install_sshpass
    if [[ $install_sshpass == "y" || $install_sshpass == "Y" ]]; then
        print_message "Установка sshpass..."
        sudo apt-get update && sudo apt-get install -y sshpass
        if [ $? -ne 0 ]; then
            print_error "Не удалось установить sshpass. Пожалуйста, установите его вручную."
            print_message "Для Debian/Ubuntu: sudo apt-get install sshpass"
            exit 1
        else
            print_success "sshpass успешно установлен."
        fi
    else
        print_error "sshpass необходим для работы веб-установщика. Пожалуйста, установите его вручную."
        print_message "Для Debian/Ubuntu: sudo apt-get install sshpass"
        exit 1
    fi
fi

# Запуск PHP-сервера в фоновом режиме
print_message "Запуск веб-сервера на порту 8000..."
cd "$TEMP_DIR" && php -S 0.0.0.0:8000 &
PHP_PID=$!

if [ $? -ne 0 ]; then
    print_error "Не удалось запустить PHP-сервер. Убедитесь, что порт 8000 не занят другим приложением."
    cleanup
    exit 1
fi

# Проверка, что сервер запустился
sleep 2
if ! kill -0 $PHP_PID 2>/dev/null; then
    print_error "PHP-сервер не запустился или преждевременно завершил работу."
    cleanup
    exit 1
fi

print_success "Веб-сервер успешно запущен на порту 8000!"
print_message "Открываем веб-интерфейс установщика..."

# URL для веб-интерфейса
WEB_URL="http://$LOCAL_IP:8000"

# Открытие веб-интерфейса в браузере
if ! xdg-open "$WEB_URL" &>/dev/null; then
    print_warning "Не удалось автоматически открыть браузер."
    print_message "Пожалуйста, откройте браузер и перейдите по адресу:"
    echo "$WEB_URL"
fi

print_message "Веб-интерфейс установщика доступен по адресу: $WEB_URL"
print_message "Для завершения работы установщика нажмите Ctrl+C"

# Ожидаем завершения пользователем
wait $PHP_PID 