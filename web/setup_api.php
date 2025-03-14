<?php
/**
 * API для мастера установки VLESS Router
 */

header('Content-Type: application/json');
header('Cache-Control: no-cache');

// Функция для проверки подключения к интернету
function checkInternet() {
    exec('ping -c 1 -W 3 8.8.8.8 2>&1', $output, $returnCode);
    return $returnCode === 0;
}

// Функция для сканирования Wi-Fi сетей
function scanWifiNetworks() {
    exec('iwinfo | grep ESSID | cut -d\" -f2', $output, $returnCode);
    if ($returnCode === 0 && !empty($output)) {
        return ['success' => true, 'networks' => array_filter($output)];
    }
    return ['success' => false, 'message' => 'Не удалось найти Wi-Fi сети'];
}

// Функция для подключения к Wi-Fi
function connectToWifi($ssid, $password) {
    // Создание конфигурации Wi-Fi клиента
    $config = "uci batch << EOF\n";
    $config .= "set wireless.sta=wifi-iface\n";
    $config .= "set wireless.sta.device=radio0\n";
    $config .= "set wireless.sta.mode=sta\n";
    $config .= "set wireless.sta.network=wwan\n";
    $config .= "set wireless.sta.ssid='$ssid'\n";
    $config .= "set wireless.sta.encryption=psk2\n";
    $config .= "set wireless.sta.key='$password'\n";
    $config .= "set network.wwan=interface\n";
    $config .= "set network.wwan.proto=dhcp\n";
    $config .= "commit wireless\n";
    $config .= "commit network\nEOF\n";
    
    // Применение конфигурации
    file_put_contents('/tmp/wifi_config.sh', $config);
    exec('sh /tmp/wifi_config.sh 2>&1', $output, $returnCode);
    unlink('/tmp/wifi_config.sh');
    
    if ($returnCode === 0) {
        // Перезапуск сети
        exec('/etc/init.d/network restart 2>&1', $output, $returnCode);
        
        // Ожидание подключения
        sleep(10);
        
        // Проверка подключения
        if (checkInternet()) {
            return ['success' => true];
        }
    }
    
    return ['success' => false, 'message' => 'Не удалось подключиться к сети'];
}

// Функция для установки пакетов
function installPackages() {
    // Очистка кэша opkg
    exec('opkg update 2>&1', $output);
    $progress = 10;
    echo json_encode(['progress' => $progress, 'status' => 'Обновление списка пакетов...', 'log' => implode("\n", $output)]) . "\n";
    flush();
    
    // Список необходимых пакетов
    $packages = [
        'xray-core',
        'luci-app-xray',
        'curl',
        'wget',
        'uhttpd',
        'uhttpd-mod-ubus',
        'openvpn-openssl',
        'luci-app-openvpn'
    ];
    
    $total = count($packages);
    $current = 0;
    
    foreach ($packages as $package) {
        $current++;
        $progress = 10 + (80 * ($current / $total));
        
        exec("opkg install $package 2>&1", $output);
        echo json_encode([
            'progress' => $progress,
            'status' => "Установка пакета $package...",
            'log' => implode("\n", $output)
        ]) . "\n";
        flush();
    }
    
    // Финальная проверка
    $allInstalled = true;
    foreach ($packages as $package) {
        exec("opkg list-installed | grep $package", $output, $returnCode);
        if ($returnCode !== 0) {
            $allInstalled = false;
            break;
        }
    }
    
    if ($allInstalled) {
        echo json_encode([
            'progress' => 100,
            'status' => 'Установка завершена успешно',
            'log' => 'Все пакеты установлены'
        ]) . "\n";
    } else {
        echo json_encode([
            'progress' => 100,
            'status' => 'Ошибка установки',
            'error' => 'Не все пакеты были установлены'
        ]) . "\n";
    }
}

// Обработка запросов
$action = $_GET['action'] ?? '';
$postData = json_decode(file_get_contents('php://input'), true);

switch ($action) {
    case 'check_internet':
        echo json_encode(['connected' => checkInternet()]);
        break;
        
    case 'scan_wifi':
        echo json_encode(scanWifiNetworks());
        break;
        
    case 'connect_wifi':
        if (isset($postData['ssid']) && isset($postData['password'])) {
            echo json_encode(connectToWifi($postData['ssid'], $postData['password']));
        } else {
            echo json_encode(['success' => false, 'message' => 'Отсутствуют параметры SSID или пароль']);
        }
        break;
        
    case 'install_packages':
        installPackages();
        break;
        
    default:
        echo json_encode(['error' => 'Неизвестное действие']);
}