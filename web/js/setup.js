// VLESS Router - Скрипт для мастера настройки

document.addEventListener('DOMContentLoaded', function() {
    let currentStep = 1;
    const totalSteps = 4;

    // Элементы навигации
    const btnPrevStep = document.getElementById('btn-prev-step');
    const btnNextStep = document.getElementById('btn-next-step');
    const stepBadge = document.getElementById('setup-step-badge');

    // Проверка подключения к интернету
    async function checkInternetConnection() {
        const statusDiv = document.getElementById('internet-check-status');
        const wifiSetupSection = document.getElementById('wifi-setup-section');

        try {
            const response = await fetch('/api.php?action=check_internet');
            const data = await response.json();

            if (data.connected) {
                statusDiv.className = 'alert alert-success';
                statusDiv.innerHTML = '<i class="bi bi-check-circle"></i> Подключение к интернету установлено';
                btnNextStep.style.display = 'block';
                wifiSetupSection.style.display = 'none';
            } else {
                statusDiv.className = 'alert alert-warning';
                statusDiv.innerHTML = '<i class="bi bi-exclamation-triangle"></i> Нет подключения к интернету';
                wifiSetupSection.style.display = 'block';
                btnNextStep.style.display = 'none';
            }
        } catch (error) {
            statusDiv.className = 'alert alert-danger';
            statusDiv.innerHTML = `<i class="bi bi-x-circle"></i> Ошибка проверки подключения: ${error.message}`;
            wifiSetupSection.style.display = 'block';
            btnNextStep.style.display = 'none';
        }
    }

    // Сканирование Wi-Fi сетей
    async function scanWifiNetworks() {
        const wifiNetworks = document.getElementById('wifi-networks');
        const btnScanWifi = document.getElementById('btn-scan-wifi');

        btnScanWifi.disabled = true;
        btnScanWifi.innerHTML = '<span class="spinner-border spinner-border-sm" role="status"></span> Сканирование...';

        try {
            const response = await fetch('/api.php?action=scan_wifi');
            const data = await response.json();

            wifiNetworks.innerHTML = '';
            if (data.networks && data.networks.length > 0) {
                data.networks.forEach(network => {
                    const networkItem = document.createElement('button');
                    networkItem.className = 'list-group-item list-group-item-action';
                    networkItem.innerHTML = `<i class="bi bi-wifi"></i> ${network}`;
                    networkItem.onclick = () => {
                        document.getElementById('wifi-ssid').value = network;
                    };
                    wifiNetworks.appendChild(networkItem);
                });
            } else {
                wifiNetworks.innerHTML = '<div class="alert alert-warning">Сети не найдены</div>';
            }
        } catch (error) {
            wifiNetworks.innerHTML = `<div class="alert alert-danger">Ошибка сканирования: ${error.message}</div>`;
        } finally {
            btnScanWifi.disabled = false;
            btnScanWifi.innerHTML = '<i class="bi bi-wifi"></i> Сканировать Wi-Fi сети';
        }
    }

    // Подключение к Wi-Fi
    async function connectToWifi() {
        const ssid = document.getElementById('wifi-ssid').value;
        const password = document.getElementById('wifi-password').value;
        const btnConnect = document.getElementById('btn-connect-wifi');
        const statusDiv = document.getElementById('internet-check-status');

        if (!ssid) {
            alert('Введите SSID сети');
            return;
        }

        btnConnect.disabled = true;
        btnConnect.innerHTML = '<span class="spinner-border spinner-border-sm" role="status"></span> Подключение...';
        statusDiv.className = 'alert alert-info';
        statusDiv.innerHTML = '<div class="spinner-border spinner-border-sm me-2" role="status"></div>Подключение к Wi-Fi...';

        try {
            const response = await fetch('/api.php?action=connect_wifi', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ ssid, password })
            });
            const data = await response.json();

            if (data.success) {
                statusDiv.className = 'alert alert-success';
                statusDiv.innerHTML = '<i class="bi bi-check-circle"></i> Успешно подключено к Wi-Fi';
                btnNextStep.style.display = 'block';
                setTimeout(checkInternetConnection, 5000);
            } else {
                statusDiv.className = 'alert alert-danger';
                statusDiv.innerHTML = `<i class="bi bi-x-circle"></i> Ошибка подключения: ${data.message}`;
            }
        } catch (error) {
            statusDiv.className = 'alert alert-danger';
            statusDiv.innerHTML = `<i class="bi bi-x-circle"></i> Ошибка: ${error.message}`;
        } finally {
            btnConnect.disabled = false;
            btnConnect.innerHTML = 'Подключиться';
        }
    }

    // Установка пакетов
    async function installPackages() {
        const progressBar = document.getElementById('install-progress');
        const statusDiv = document.getElementById('install-status');
        const logDiv = document.getElementById('install-log');
        btnNextStep.style.display = 'none';

        try {
            const response = await fetch('/api.php?action=install_packages');
            const reader = response.body.getReader();
            const decoder = new TextDecoder();

            while (true) {
                const {value, done} = await reader.read();
                if (done) break;

                const text = decoder.decode(value);
                const data = JSON.parse(text);

                progressBar.style.width = `${data.progress}%`;
                progressBar.setAttribute('aria-valuenow', data.progress);
                statusDiv.innerHTML = data.status;
                logDiv.innerHTML += data.log + '\n';
                logDiv.scrollTop = logDiv.scrollHeight;

                if (data.error) {
                    throw new Error(data.error);
                }

                if (data.progress === 100) {
                    btnNextStep.style.display = 'block';
                }
            }
        } catch (error) {
            statusDiv.className = 'alert alert-danger';
            statusDiv.innerHTML = `<i class="bi bi-x-circle"></i> Ошибка установки: ${error.message}`;
        }
    }

    // Сохранение настроек Wi-Fi
    async function saveWifiSettings() {
        const directSsid = document.getElementById('direct-ssid').value;
        const directPassword = document.getElementById('direct-password').value;
        const proxySsid = document.getElementById('proxy-ssid').value;
        const proxyPassword = document.getElementById('proxy-password').value;

        if (!directSsid || !directPassword || !proxySsid || !proxyPassword) {
            alert('Заполните все поля');
            return;
        }

        try {
            const response = await fetch('/api.php?action=save_wifi_settings', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    direct_ssid: directSsid,
                    direct_password: directPassword,
                    proxy_ssid: proxySsid,
                    proxy_password: proxyPassword
                })
            });
            const data = await response.json();

            if (data.success) {
                btnNextStep.style.display = 'block';
            } else {
                throw new Error(data.message);
            }
        } catch (error) {
            alert(`Ошибка сохранения настроек: ${error.message}`);
        }
    }

    // Обработчики событий
    document.getElementById('btn-scan-wifi').onclick = scanWifiNetworks;
    document.getElementById('btn-connect-wifi').onclick = connectToWifi;
    document.getElementById('btn-save-wifi').onclick = saveWifiSettings;
    document.getElementById('btn-finish-setup').onclick = () => {
        window.location.href = 'index.html';
    };

    // Навигация по шагам
    btnPrevStep.onclick = () => {
        if (currentStep > 1) {
            currentStep--;
            showStep(currentStep);
        }
    };

    btnNextStep.onclick = () => {
        if (currentStep < totalSteps) {
            currentStep++;
            showStep(currentStep);
        }
    };

    function showStep(step) {
        document.querySelectorAll('.setup-step').forEach(el => el.style.display = 'none');
        document.getElementById(`setup-step-${step}`).style.display = 'block';
        stepBadge.textContent = `${step}/${totalSteps}`;

        btnPrevStep.style.display = step > 1 ? 'block' : 'none';
        btnNextStep.style.display = step < totalSteps ? 'block' : 'none';

        if (step === 1) {
            checkInternetConnection();
        } else if (step === 2) {
            installPackages();
        }
    }

    // Запуск мастера настройки
    showStep(1);
});
