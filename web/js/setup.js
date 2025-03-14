// VLESS Router - Скрипт для мастера настройки

document.addEventListener('DOMContentLoaded', function() {
    const setupWizard = document.getElementById('setup-wizard');
    const mainInterface = document.getElementById('main-interface');
    
    // Проверка первого запуска
    function checkFirstRun() {
        fetch('/api.php?action=check_first_run')
            .then(response => response.json())
            .then(data => {
                if (data.first_run) {
                    showSetupWizard();
                }
            })
            .catch(error => {
                console.error('Ошибка при проверке первого запуска:', error);
                // Если API недоступно, показываем мастер настройки по умолчанию
                showSetupWizard();
            });
    }
    
    // Показать мастер настройки
    function showSetupWizard() {
        setupWizard.style.display = 'block';
        mainInterface.style.display = 'none';
        showSetupStep(1);
    }
    
    // Показать основной интерфейс
    function showMainInterface() {
        setupWizard.style.display = 'none';
        mainInterface.style.display = 'block';
    }
    
    // Переключение между шагами мастера настройки
    function showSetupStep(stepNumber) {
        // Скрыть все шаги
        document.querySelectorAll('[id^="setup-step-"]').forEach(step => {
            if (step.id === `setup-step-${stepNumber}`) {
                step.style.display = 'block';
            } else {
                step.style.display = 'none';
            }
        });
        
        // Обновить заголовок и номер шага
        const stepTitle = document.getElementById('setup-step-title');
        const stepBadge = document.getElementById('setup-step-badge');
        
        switch (stepNumber) {
            case 1:
                stepTitle.textContent = 'Шаг 1: Подключение к WiFi';
                stepBadge.textContent = '1/4';
                break;
            case 2:
                stepTitle.textContent = 'Шаг 2: Установка пакетов';
                stepBadge.textContent = '2/4';
                break;
            case 3:
                stepTitle.textContent = 'Шаг 3: Настройка WiFi сетей';
                stepBadge.textContent = '3/4';
                break;
            case 4:
                stepTitle.textContent = 'Шаг 4: Завершение настройки';
                stepBadge.textContent = '4/4';
                break;
        }
    }
    
    // Шаг 1: Сканирование WiFi сетей
    document.getElementById('btn-scan-wifi').addEventListener('click', function() {
        const wifiNetworks = document.getElementById('wifi-networks');
        const wifiAlert = document.getElementById('wifi-alert');
        
        // Показать индикатор загрузки
        wifiAlert.innerHTML = `
            <div class="alert alert-info">
                <div class="spinner-border spinner-border-sm" role="status"></div>
                <span class="ms-2">Сканирование WiFi сетей...</span>
            </div>
        `;
        
        // Запрос к API для сканирования сетей
        fetch('/setup_api.cgi/scan_wifi')
            .then(response => response.json())
            .then(data => {
                if (data.networks && data.networks.length > 0) {
                    // Очистить и заполнить список сетей
                    wifiNetworks.innerHTML = '';
                    data.networks.forEach(network => {
                        const networkItem = document.createElement('button');
                        networkItem.className = 'list-group-item list-group-item-action';
                        networkItem.textContent = network;
                        networkItem.addEventListener('click', function() {
                            document.getElementById('wifi-ssid').value = network;
                        });
                        wifiNetworks.appendChild(networkItem);
                    });
                    
                    // Показать список сетей
                    wifiNetworks.style.display = 'block';
                    wifiAlert.innerHTML = `
                        <div class="alert alert-success">
                            <i class="bi bi-check-circle"></i>
                            <span class="ms-2">Найдено ${data.networks.length} WiFi сетей</span>
                        </div>
                    `;
                } else {
                    wifiAlert.innerHTML = `
                        <div class="alert alert-warning">
                            <i class="bi bi-exclamation-triangle"></i>
                            <span class="ms-2">WiFi сети не найдены. Проверьте, что WiFi адаптер включен и работает.</span>
                        </div>
                    `;
                }
            })
            .catch(error => {
                console.error('Ошибка при сканировании WiFi:', error);
                wifiAlert.innerHTML = `
                    <div class="alert alert-danger">
                        <i class="bi bi-x-circle"></i>
                        <span class="ms-2">Ошибка при сканировании WiFi сетей. Попробуйте еще раз.</span>
                    </div>
                `;
            });
    });
    
    // Шаг 1: Подключение к WiFi
    document.getElementById('btn-connect-wifi').addEventListener('click', function() {
        const ssid = document.getElementById('wifi-ssid').value;
        const password = document.getElementById('wifi-password').value;
        const wifiAlert = document.getElementById('wifi-alert');
        
        if (!ssid) {
            wifiAlert.innerHTML = `
                <div class="alert alert-danger">
                    <i class="bi bi-x-circle"></i>
                    <span class="ms-2">Введите имя WiFi сети.</span>
                </div>
            `;
            return;
        }
        
        // Показать индикатор загрузки
        wifiAlert.innerHTML = `
            <div class="alert alert-info">
                <div class="spinner-border spinner-border-sm" role="status"></div>
                <span class="ms-2">Подключение к WiFi сети...</span>
            </div>
        `;
        
        // Запрос к API для подключения к WiFi
        fetch('/setup_api.cgi/connect_wifi', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                ssid: ssid,
                password: password
            })
        })
        .then(response => response.json())
        .then(data => {
            if (data.status === 'success') {
                wifiAlert.innerHTML = `
                    <div class="alert alert-success">
                        <i class="bi bi-check-circle"></i>
                        <span class="ms-2">${data.message}</span>
                    </div>
                `;
                // Переход к следующему шагу
                setTimeout(() => {
                    showSetupStep(2);
                }, 1500);
            } else {
                wifiAlert.innerHTML = `
                    <div class="alert alert-danger">
                        <i class="bi bi-x-circle"></i>
                        <span class="ms-2">${data.message}</span>
                    </div>
                `;
            }
        })
        .catch(error => {
            console.error('Ошибка при подключении к WiFi:', error);
            wifiAlert.innerHTML = `
                <div class="alert alert-danger">
                    <i class="bi bi-x-circle"></i>
                    <span class="ms-2">Ошибка при подключении к WiFi. Попробуйте еще раз.</span>
                </div>
            `;
        });
    });
    
    // Шаг 2: Установка пакетов
    document.getElementById('btn-install-packages').addEventListener('click', function() {
        const packagesAlert = document.getElementById('packages-alert');
        const installProgress = document.getElementById('install-progress');
        const installLog = document.getElementById('install-log');
        const btnInstallPackages = document.getElementById('btn-install-packages');
        const btnBackToStep1 = document.getElementById('btn-back-to-step-1');
        const btnNextStep = document.getElementById('btn-packages-next');
        
        // Отключить кнопки
        btnInstallPackages.disabled = true;
        btnBackToStep1.disabled = true;
        
        // Показать индикатор загрузки
        packagesAlert.innerHTML = `
            <div class="alert alert-info">
                <div class="spinner-border spinner-border-sm" role="status"></div>
                <span class="ms-2">Установка пакетов. Это может занять несколько минут...</span>
            </div>
        `;
        
        // Показать лог установки
        installLog.style.display = 'block';
        installLog.innerHTML = 'Начало установки пакетов...\n';
        
        // Установка пакетов
        fetch('/setup_api.cgi/install_packages')
            .then(response => response.json())
            .then(data => {
                if (data.status === 'success') {
                    installProgress.style.width = '100%';
                    packagesAlert.innerHTML = `
                        <div class="alert alert-success">
                            <i class="bi bi-check-circle"></i>
                            <span class="ms-2">${data.message}</span>
                        </div>
                    `;
                    // Включить кнопку перехода к следующему шагу
                    btnNextStep.disabled = false;
                } else {
                    installProgress.style.width = '50%';
                    installProgress.classList.remove('bg-primary');
                    installProgress.classList.add('bg-danger');
                    packagesAlert.innerHTML = `
                        <div class="alert alert-danger">
                            <i class="bi bi-x-circle"></i>
                            <span class="ms-2">${data.message}</span>
                        </div>
                    `;
                    // Добавить лог ошибки
                    if (data.log) {
                        installLog.innerHTML += `\nОшибка: ${data.log}\n`;
                    }
                    // Включить кнопки назад
                    btnBackToStep1.disabled = false;
                    btnInstallPackages.disabled = false;
                }
            })
            .catch(error => {
                console.error('Ошибка при установке пакетов:', error);
                installProgress.style.width = '50%';
                installProgress.classList.remove('bg-primary');
                installProgress.classList.add('bg-danger');
                packagesAlert.innerHTML = `
                    <div class="alert alert-danger">
                        <i class="bi bi-x-circle"></i>
                        <span class="ms-2">Ошибка при установке пакетов. Попробуйте еще раз.</span>
                    </div>
                `;
                // Включить кнопки назад
                btnBackToStep1.disabled = false;
                btnInstallPackages.disabled = false;
            });
    });
    
    // Кнопка назад к шагу 1
    document.getElementById('btn-back-to-step-1').addEventListener('click', function() {
        showSetupStep(1);
    });
    
    // Кнопка перехода к шагу 3
    document.getElementById('btn-packages-next').addEventListener('click', function() {
        showSetupStep(3);
    });
    
    // Шаг 3: Настройка WiFi сетей
    document.getElementById('btn-create-wifi').addEventListener('click', function() {
        const directSsid = document.getElementById('direct-ssid').value;
        const directPassword = document.getElementById('direct-password').value;
        const proxySsid = document.getElementById('proxy-ssid').value;
        const proxyPassword = document.getElementById('proxy-password').value;
        const wifiSetupAlert = document.getElementById('wifi-setup-alert');
        
        if (!directSsid || !directPassword || !proxySsid || !proxyPassword) {
            wifiSetupAlert.innerHTML = `
                <div class="alert alert-danger">
                    <i class="bi bi-x-circle"></i>
                    <span class="ms-2">Заполните все поля для WiFi сетей.</span>
                </div>
            `;
            return;
        }
        
        // Показать индикатор загрузки
        wifiSetupAlert.innerHTML = `
            <div class="alert alert-info">
                <div class="spinner-border spinner-border-sm" role="status"></div>
                <span class="ms-2">Создание WiFi сетей...</span>
            </div>
        `;
        
        // Запрос к API для создания WiFi сетей
        fetch('/setup_api.cgi/create_wifi', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                direct_ssid: directSsid,
                direct_pass: directPassword,
                proxy_ssid: proxySsid,
                proxy_pass: proxyPassword
            })
        })
        .then(response => response.json())
        .then(data => {
            if (data.status === 'success') {
                wifiSetupAlert.innerHTML = `
                    <div class="alert alert-success">
                        <i class="bi bi-check-circle"></i>
                        <span class="ms-2">${data.message}</span>
                    </div>
                `;
                
                // Обновить значения на шаге 4
                document.getElementById('final-direct-ssid').textContent = directSsid;
                document.getElementById('final-direct-password').textContent = '***';
                document.getElementById('final-proxy-ssid').textContent = proxySsid;
                document.getElementById('final-proxy-password').textContent = '***';
                
                // Переход к следующему шагу
                setTimeout(() => {
                    showSetupStep(4);
                    // Настройка VLESS и запуск сервиса
                    setupVlessAndFinish();
                }, 1500);
            } else {
                wifiSetupAlert.innerHTML = `
                    <div class="alert alert-danger">
                        <i class="bi bi-x-circle"></i>
                        <span class="ms-2">${data.message}</span>
                    </div>
                `;
            }
        })
        .catch(error => {
            console.error('Ошибка при создании WiFi сетей:', error);
            wifiSetupAlert.innerHTML = `
                <div class="alert alert-danger">
                    <i class="bi bi-x-circle"></i>
                    <span class="ms-2">Ошибка при создании WiFi сетей. Попробуйте еще раз.</span>
                </div>
            `;
        });
    });
    
    // Кнопка назад к шагу 2
    document.getElementById('btn-back-to-step-2').addEventListener('click', function() {
        showSetupStep(2);
    });
    
    // Функция для настройки VLESS и завершения установки
    function setupVlessAndFinish() {
        // Настройка VLESS
        fetch('/setup_api.cgi/configure_vless')
            .then(response => response.json())
            .then(data => {
                if (data.status === 'success') {
                    console.log('VLESS настроен успешно');
                    
                    // Настройка веб-сервера
                    return fetch('/setup_api.cgi/configure_web');
                } else {
                    throw new Error('Ошибка при настройке VLESS');
                }
            })
            .then(response => response.json())
            .then(data => {
                if (data.status === 'success') {
                    console.log('Веб-сервер настроен успешно');
                    
                    // Запуск VLESS
                    return fetch('/setup_api.cgi/start_vless');
                } else {
                    throw new Error('Ошибка при настройке веб-сервера');
                }
            })
            .then(response => response.json())
            .then(data => {
                if (data.status === 'success') {
                    console.log('VLESS запущен успешно');
                } else {
                    throw new Error('Ошибка при запуске VLESS');
                }
            })
            .catch(error => {
                console.error('Ошибка при завершении настройки:', error);
            });
    }
    
    // Кнопка перехода в панель управления
    document.getElementById('btn-go-to-dashboard').addEventListener('click', function() {
        showMainInterface();
    });
    
    // Проверяем, нужно ли показывать мастер настройки
    checkFirstRun();
});
