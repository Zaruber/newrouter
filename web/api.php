<?php
/**
 * API для VLESS Router
 * 
 * Обрабатывает запросы от веб-интерфейса к бэкенду.
 */

// Константы путей к файлам
define('CONFIG_DIR', '../config');
define('SCRIPTS_DIR', '../scripts');
define('SETTINGS_FILE', CONFIG_DIR . '/settings.json');
define('PROFILES_FILE', CONFIG_DIR . '/profiles.json');
define('WHITELIST_FILE', CONFIG_DIR . '/whitelist.txt');
define('BLACKLIST_FILE', CONFIG_DIR . '/blacklist.txt');

// Включаем отображение всех ошибок для отладки
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Заголовки для CORS и JSON
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE');
header('Access-Control-Allow-Headers: Content-Type');

// Проверка наличия конфигурационных файлов и создание их при необходимости
if (!file_exists(SETTINGS_FILE)) {
    $settings = array(
        'active_profile' => '',
        'mode' => 'proxy_all',
        'wifi' => array(
            'direct_ssid' => 'VLESS_DIRECT',
            'direct_password' => 'direct12345',
            'proxy_ssid' => 'VLESS_PROXY',
            'proxy_password' => 'proxy12345'
        ),
        'proxy_mode' => array(
            'use_whitelist' => false,
            'use_blacklist' => true
        ),
        'first_run' => true
    );
    file_put_contents(SETTINGS_FILE, json_encode($settings, JSON_PRETTY_PRINT));
}

if (!file_exists(PROFILES_FILE)) {
    $profiles = array();
    file_put_contents(PROFILES_FILE, json_encode($profiles, JSON_PRETTY_PRINT));
}

if (!file_exists(WHITELIST_FILE)) {
    file_put_contents(WHITELIST_FILE, '');
}

if (!file_exists(BLACKLIST_FILE)) {
    file_put_contents(BLACKLIST_FILE, '');
}

// Получение HTTP метода и параметров
$method = $_SERVER['REQUEST_METHOD'];
$action = isset($_GET['action']) ? $_GET['action'] : '';

// Обработка запроса
switch ($method) {
    case 'GET':
        switch ($action) {
            case 'status':
                $response = getProxyStatus();
                break;
            case 'profiles':
                $response = getProfiles();
                break;
            case 'whitelist':
                $response = getWhitelist();
                break;
            case 'blacklist':
                $response = getBlacklist();
                break;
            case 'settings':
                $response = getSettings();
                break;
            default:
                $response = array('success' => false, 'message' => 'Недопустимый запрос');
        }
        break;
    case 'POST':
        switch ($action) {
            case 'start-proxy':
                $response = startProxy();
                break;
            case 'stop-proxy':
                $response = stopProxy();
                break;
            case 'save-settings':
                $response = saveSettings();
                break;
            case 'save-profiles':
                $response = saveProfiles();
                break;
            case 'save-whitelist':
                $response = saveWhitelist();
                break;
            case 'save-blacklist':
                $response = saveBlacklist();
                break;
            default:
                $response = array('success' => false, 'message' => 'Недопустимый запрос');
        }
        break;
    default:
        $response = array('success' => false, 'message' => 'Недопустимый метод');
}

sendResponse($response);

/**
 * Получение настроек сервиса
 */
function getSettings() {
    $settings = json_decode(file_get_contents(SETTINGS_FILE), true);
    return array('success' => true, 'data' => $settings);
}

/**
 * Сохранение настроек сервиса
 */
function saveSettings() {
    $data = json_decode(file_get_contents('php://input'), true);
    
    if (!$data) {
        return array('success' => false, 'message' => 'Недопустимые данные');
    }
    
    $settings = json_decode(file_get_contents(SETTINGS_FILE), true);
    
    // Обновление настроек
    if (isset($data['mode'])) {
        $settings['mode'] = $data['mode'];
    }
    
    if (isset($data['proxy_mode'])) {
        $settings['proxy_mode'] = $data['proxy_mode'];
    }
    
    if (isset($data['wifi'])) {
        $settings['wifi'] = $data['wifi'];
    }
    
    if (isset($data['active_profile'])) {
        $settings['active_profile'] = $data['active_profile'];
    }
    
    // Обработка параметра first_run
    if (isset($data['first_run'])) {
        $settings['first_run'] = $data['first_run'];
    }
    
    // Сохранение настроек
    file_put_contents(SETTINGS_FILE, json_encode($settings, JSON_PRETTY_PRINT));
    
    return array('success' => true, 'message' => 'Настройки сохранены');
}

/**
 * Применение настроек WiFi
 */
function applyWifiSettings() {
    // Применение настроек WiFi
    $settings = json_decode(file_get_contents(SETTINGS_FILE), true);
    $wifiSettings = $settings['wifi'];
    
    // Обновление настроек WiFi
    $command = "uci set wireless.@wifi-iface[0].ssid='{$wifiSettings['direct_ssid']}'\n" .
               "uci set wireless.@wifi-iface[0].key='{$wifiSettings['direct_password']}'\n" .
               "uci set wireless.@wifi-iface[1].ssid='{$wifiSettings['proxy_ssid']}'\n" .
               "uci set wireless.@wifi-iface[1].key='{$wifiSettings['proxy_password']}'\n" .
               "uci commit wireless\n" .
               "/etc/init.d/network restart";
    
    executeCommand($command);
    
    return array('success' => true, 'message' => 'Настройки WiFi применены');
}

/**
 * Получение списка профилей
 */
function getProfiles() {
    $profiles = json_decode(file_get_contents(PROFILES_FILE), true);
    return array('success' => true, 'data' => $profiles);
}

/**
 * Сохранение списка профилей
 */
function saveProfiles() {
    $data = json_decode(file_get_contents('php://input'), true);
    
    if (!$data) {
        return array('success' => false, 'message' => 'Недопустимые данные');
    }
    
    // Сохранение профилей
    file_put_contents(PROFILES_FILE, json_encode($data, JSON_PRETTY_PRINT));
    
    return array('success' => true, 'message' => 'Профили сохранены');
}

/**
 * Получение статуса прокси
 */
function getProxyStatus() {
    // Проверка статуса прокси
    $proxyRunning = (executeCommand('pgrep xray') !== '');
    
    return array('success' => true, 'data' => array('proxy_running' => $proxyRunning));
}

/**
 * Запуск прокси-сервиса
 */
function startProxy() {
    // Запуск прокси-сервиса
    executeCommand('/root/vless-router/scripts/vless-service.sh start');
    
    return array('success' => true, 'message' => 'Прокси-сервис запущен');
}

/**
 * Остановка прокси-сервиса
 */
function stopProxy() {
    // Остановка прокси-сервиса
    executeCommand('/root/vless-router/scripts/vless-service.sh stop');
    
    return array('success' => true, 'message' => 'Прокси-сервис остановлен');
}

/**
 * Получение списка сайтов для белого списка
 */
function getWhitelist() {
    $whitelist = file_get_contents(WHITELIST_FILE);
    $domains = array_filter(explode("\n", $whitelist), 'trim');
    
    return array('success' => true, 'data' => $domains);
}

/**
 * Получение списка сайтов для черного списка
 */
function getBlacklist() {
    $blacklist = file_get_contents(BLACKLIST_FILE);
    $domains = array_filter(explode("\n", $blacklist), 'trim');
    
    return array('success' => true, 'data' => $domains);
}

/**
 * Сохранение белого списка сайтов
 */
function saveWhitelist() {
    $data = json_decode(file_get_contents('php://input'), true);
    
    if (!$data) {
        return array('success' => false, 'message' => 'Недопустимые данные');
    }
    
    // Сохранение белого списка
    file_put_contents(WHITELIST_FILE, implode("\n", $data));
    
    return array('success' => true, 'message' => 'Белый список сохранен');
}

/**
 * Сохранение черного списка сайтов
 */
function saveBlacklist() {
    $data = json_decode(file_get_contents('php://input'), true);
    
    if (!$data) {
        return array('success' => false, 'message' => 'Недопустимые данные');
    }
    
    // Сохранение черного списка
    file_put_contents(BLACKLIST_FILE, implode("\n", $data));
    
    return array('success' => true, 'message' => 'Черный список сохранен');
}

/**
 * Выполнение shell команды и возврат результата
 */
function executeCommand($command) {
    return shell_exec($command . ' 2>&1');
}

/**
 * Отправка JSON-ответа
 */
function sendResponse($data) {
    header('Content-Type: application/json');
    echo json_encode($data);
    exit(0);
}
