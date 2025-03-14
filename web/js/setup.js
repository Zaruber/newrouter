/**
 * JavaScript для мастера установки VLESS Router
 */

document.addEventListener('DOMContentLoaded', function() {
    // Элементы навигации
    const welcomeSection = document.getElementById('setup-welcome');
    const step1Section = document.getElementById('setup-step-1');
    const stepBadge = document.getElementById('setup-step-badge');
    const stepDots = document.querySelectorAll('.step-dot');
    
    // Кнопки навигации
    const startSetupBtn = document.getElementById('start-setup');
    const backToWelcomeBtn = document.getElementById('back-to-welcome');
    const nextToStep2Btn = document.getElementById('next-to-step-2');
    
    // Элементы первого шага
    const internetCheckStatus = document.getElementById('internet-check-status');
    const wifiSetupSection = document.getElementById('wifi-setup-section');
    const btnScanWifi = document.getElementById('btn-scan-wifi');
    const wifiNetworksContainer = document.getElementById('wifi-networks');
    const wifiSsidInput = document.getElementById('wifi-ssid');
    const wifiPasswordInput = document.getElementById('wifi-password');
    const btnConnectWifi = document.getElementById('btn-connect-wifi');
    
    // API URL - исправляем путь для корректного обращения
    const API_URL = './cgi-bin/setup_api.cgi';
    
    // Начальная инициализация
    updateStepBadge('welcome');
    
    // Обработчики событий для навигации
    startSetupBtn.addEventListener('click', function() {
        switchToStep('1');
        checkInternetConnection();
    });
    
    backToWelcomeBtn.addEventListener('click', function() {
        switchToStep('welcome');
    });
    
    // Функции для проверки интернет-соединения
    function checkInternetConnection() {
        internetCheckStatus.innerHTML = `
            <div class="d-flex align-items-center">
                <div class="spinner-border spinner-border-sm me-2" role="status"></div>
                Проверка подключения к интернету...
            </div>
        `;
        
        fetch(`${API_URL}?action=check_internet`)
            .then(response => response.json())
            .then(data => {
                if (data.connected) {
                    internetCheckStatus.innerHTML = `
                        <div class="d-flex align-items-center">
                            <i class="bi bi-check-circle-fill text-success me-2"></i>
                            Подключение к интернету установлено!
                        </div>
                    `;
                    internetCheckStatus.className = 'alert alert-success';
                    nextToStep2Btn.disabled = false;
                } else {
                    internetCheckStatus.innerHTML = `
                        <div class="d-flex align-items-center">
                            <i class="bi bi-exclamation-triangle-fill text-warning me-2"></i>
                            Подключение к интернету отсутствует. Необходимо настроить WiFi подключение.
                        </div>
                    `;
                    internetCheckStatus.className = 'alert alert-warning';
                    wifiSetupSection.style.display = 'block';
                }
            })
            .catch(error => {
                console.error('Ошибка API:', error);
                internetCheckStatus.innerHTML = `
                    <div class="d-flex align-items-center">
                        <i class="bi bi-x-circle-fill text-danger me-2"></i>
                        Ошибка при проверке подключения к интернету: ${error.message}
                    </div>
                `;
                internetCheckStatus.className = 'alert alert-danger';
                wifiSetupSection.style.display = 'block';
            });
    }
    
    // Сканирование WiFi сетей
    btnScanWifi.addEventListener('click', scanWifiNetworks);
    
    function scanWifiNetworks() {
        btnScanWifi.disabled = true;
        btnScanWifi.innerHTML = '<div class="spinner-border spinner-border-sm me-2" role="status"></div> Сканирование...';
        
        wifiNetworksContainer.innerHTML = '';
        
        fetch(`${API_URL}?action=scan_wifi`)
            .then(response => response.json())
            .then(data => {
                btnScanWifi.disabled = false;
                btnScanWifi.innerHTML = '<i class="bi bi-wifi"></i> Сканировать Wi-Fi сети';
                
                if (data.success && data.networks && data.networks.length > 0) {
                    data.networks.forEach(network => {
                        const networkItem = document.createElement('button');
                        networkItem.type = 'button';
                        networkItem.className = 'list-group-item list-group-item-action d-flex justify-content-between align-items-center';
                        networkItem.innerHTML = `
                            <span><i class="bi bi-wifi"></i> ${network}</span>
                            <i class="bi bi-chevron-right"></i>
                        `;
                        networkItem.addEventListener('click', function() {
                            wifiSsidInput.value = network;
                        });
                        wifiNetworksContainer.appendChild(networkItem);
                    });
                } else {
                    wifiNetworksContainer.innerHTML = `
                        <div class="alert alert-info">
                            Не найдено доступных WiFi сетей. Убедитесь, что роутер находится в зоне действия беспроводных сетей.
                        </div>
                    `;
                }
            })
            .catch(error => {
                console.error('Ошибка сканирования WiFi:', error);
                btnScanWifi.disabled = false;
                btnScanWifi.innerHTML = '<i class="bi bi-wifi"></i> Сканировать Wi-Fi сети';
                
                wifiNetworksContainer.innerHTML = `
                    <div class="alert alert-danger">
                        Ошибка при сканировании сетей: ${error.message}
                    </div>
                `;
            });
    }
    
    // Подключение к WiFi
    btnConnectWifi.addEventListener('click', connectToWifi);
    
    function connectToWifi() {
        const ssid = wifiSsidInput.value.trim();
        const password = wifiPasswordInput.value;
        
        if (!ssid) {
            alert('Пожалуйста, введите имя WiFi сети (SSID)');
            return;
        }
        
        btnConnectWifi.disabled = true;
        btnConnectWifi.innerHTML = '<div class="spinner-border spinner-border-sm me-2" role="status"></div> Подключение...';
        
        const connectData = {
            ssid: ssid,
            password: password
        };
        
        fetch(`${API_URL}?action=connect_wifi`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(connectData),
        })
            .then(response => response.json())
            .then(data => {
                btnConnectWifi.disabled = false;
                btnConnectWifi.innerHTML = 'Подключиться';
                
                if (data.success) {
                    internetCheckStatus.innerHTML = `
                        <div class="d-flex align-items-center">
                            <i class="bi bi-check-circle-fill text-success me-2"></i>
                            Успешное подключение к WiFi сети "${ssid}". Проверка интернет-соединения...
                        </div>
                    `;
                    internetCheckStatus.className = 'alert alert-success';
                    
                    // Даем время на подключение
                    setTimeout(function() {
                        checkInternetConnection();
                        wifiSetupSection.style.display = 'none';
                        nextToStep2Btn.disabled = false;
                    }, 5000);
                } else {
                    internetCheckStatus.innerHTML = `
                        <div class="d-flex align-items-center">
                            <i class="bi bi-x-circle-fill text-danger me-2"></i>
                            Ошибка при подключении к WiFi: ${data.message || 'Неизвестная ошибка'}
                        </div>
                    `;
                    internetCheckStatus.className = 'alert alert-danger';
                }
            })
            .catch(error => {
                console.error('Ошибка подключения к WiFi:', error);
                btnConnectWifi.disabled = false;
                btnConnectWifi.innerHTML = 'Подключиться';
                
                internetCheckStatus.innerHTML = `
                    <div class="d-flex align-items-center">
                        <i class="bi bi-x-circle-fill text-danger me-2"></i>
                        Ошибка при подключении к WiFi: ${error.message}
                    </div>
                `;
                internetCheckStatus.className = 'alert alert-danger';
            });
    }
    
    // Функции навигации
    function switchToStep(step) {
        // Скрываем все секции
        document.querySelectorAll('.setup-step').forEach(section => {
            section.classList.remove('active');
        });
        
        // Показываем нужную секцию
        if (step === 'welcome') {
            welcomeSection.classList.add('active');
        } else {
            document.getElementById(`setup-step-${step}`).classList.add('active');
        }
        
        // Обновляем индикатор шага
        updateStepBadge(step);
    }
    
    function updateStepBadge(step) {
        // Обновляем бейдж с номером шага
        if (step === 'welcome') {
            stepBadge.textContent = 'Приветствие';
        } else {
            stepBadge.textContent = `${step}/4`;
        }
        
        // Обновляем точки шагов
        stepDots.forEach(dot => dot.classList.remove('active'));
        
        // Активируем текущую точку
        const dotIndex = step === 'welcome' ? 0 : parseInt(step);
        stepDots[dotIndex].classList.add('active');
    }
    
    // Остальные обработчики для последующих шагов
    // ... existing code ...
});
