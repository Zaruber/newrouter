/**
 * Основной скрипт веб-интерфейса VLESS Router
 */

// Переменные для отслеживания состояния
let currentStatus = null;
let profiles = [];
let whitelist = [];
let blacklist = [];

// DOM элементы
const navItems = {
    dashboard: document.getElementById('nav-dashboard'),
    profiles: document.getElementById('nav-profiles'),
    sites: document.getElementById('nav-sites'),
    wifi: document.getElementById('nav-wifi'),
    settings: document.getElementById('nav-settings')
};

const sections = {
    dashboard: document.getElementById('dashboard-section'),
    profiles: document.getElementById('profiles-section'),
    sites: document.getElementById('sites-section'),
    wifi: document.getElementById('wifi-section'),
    settings: document.getElementById('settings-section')
};

// Элементы панели управления
const statusIndicator = document.getElementById('status-indicator');
const proxySwitch = document.getElementById('proxy-switch');
const activeProfileElement = document.getElementById('active-profile');
const proxyModeElement = document.getElementById('proxy-mode');
const directSsidElement = document.getElementById('direct-ssid');
const proxySsidElement = document.getElementById('proxy-ssid');

// Элементы для профилей
const profilesTableBody = document.getElementById('profiles-table-body');
const btnAddProfile = document.getElementById('btn-add-profile');
const btnSaveProfile = document.getElementById('btn-save-profile');
const profileNameInput = document.getElementById('profile-name');
const profileUrlInput = document.getElementById('profile-url');

// Элементы для сайтов
const whitelistSwitch = document.getElementById('whitelist-switch');
const blacklistSwitch = document.getElementById('blacklist-switch');
const whitelistInput = document.getElementById('whitelist-input');
const blacklistInput = document.getElementById('blacklist-input');
const btnAddWhitelist = document.getElementById('btn-add-whitelist');
const btnAddBlacklist = document.getElementById('btn-add-blacklist');
const whitelistItems = document.getElementById('whitelist-items');
const blacklistItems = document.getElementById('blacklist-items');

// Элементы для WiFi
const directSsidInput = document.getElementById('direct-ssid-input');
const directPasswordInput = document.getElementById('direct-password-input');
const proxySsidInput = document.getElementById('proxy-ssid-input');
const proxyPasswordInput = document.getElementById('proxy-password-input');
const btnSaveDirectWifi = document.getElementById('btn-save-direct-wifi');
const btnSaveProxyWifi = document.getElementById('btn-save-proxy-wifi');

// Элементы для настроек
const proxyModeAll = document.getElementById('proxy-mode-all');
const proxyModeSelective = document.getElementById('proxy-mode-selective');
const btnSaveProxyMode = document.getElementById('btn-save-proxy-mode');
const btnExportSettings = document.getElementById('btn-export-settings');
const btnImportSettings = document.getElementById('btn-import-settings');
const importSettingsFile = document.getElementById('import-settings');

// Кнопки быстрого доступа
const btnRestartProxy = document.getElementById('btn-restart-proxy');
const btnRestartWifi = document.getElementById('btn-restart-wifi');
const btnUpdateProfiles = document.getElementById('btn-update-profiles');
const btnRestartRouter = document.getElementById('btn-restart-router');

// Bootstrap модальное окно
const addProfileModal = new bootstrap.Modal(document.getElementById('addProfileModal'));

// Инициализация API
const api = new Api();

// Глобальные переменные
let currentView = 'dashboard';
let proxyActive = false;
let settings = {};
let firstRunModal = null;

/**
 * Инициализация веб-интерфейса
 */
async function initializeApp() {
    // Настройка обработчиков навигации
    setupNavigation();
    
    // Загрузка первоначальных данных
    try {
        await loadDashboardData();
        await loadProfiles();
        await loadSiteLists();
        await loadWifiSettings();
        await loadProxyMode();
    } catch (error) {
        showError('Ошибка при инициализации приложения: ' + error.message);
    }
    
    // Настройка обработчиков событий
    setupEventHandlers();
    
    // Проверка на первый запуск
    checkFirstRun();
}

/**
 * Настройка навигации между вкладками
 */
function setupNavigation() {
    // Обработчики для навигационных элементов
    navItems.dashboard.addEventListener('click', (e) => {
        e.preventDefault();
        showSection('dashboard');
    });
    
    navItems.profiles.addEventListener('click', (e) => {
        e.preventDefault();
        showSection('profiles');
    });
    
    navItems.sites.addEventListener('click', (e) => {
        e.preventDefault();
        showSection('sites');
    });
    
    navItems.wifi.addEventListener('click', (e) => {
        e.preventDefault();
        showSection('wifi');
    });
    
    navItems.settings.addEventListener('click', (e) => {
        e.preventDefault();
        showSection('settings');
    });
}

/**
 * Показывает выбранную секцию и скрывает остальные
 */
function showSection(sectionName) {
    // Скрываем все секции
    Object.values(sections).forEach(section => {
        section.style.display = 'none';
    });
    
    // Убираем активный класс со всех навигационных элементов
    Object.values(navItems).forEach(item => {
        item.classList.remove('active');
    });
    
    // Показываем выбранную секцию и активируем соответствующий элемент навигации
    sections[sectionName].style.display = 'block';
    navItems[sectionName].classList.add('active');
}

/**
 * Загружает данные для панели управления
 */
async function loadDashboardData() {
    try {
        currentStatus = await api.getStatus();
        
        // Обновление статуса
        if (currentStatus.proxy_running) {
            statusIndicator.classList.remove('alert-danger');
            statusIndicator.classList.add('alert-success');
            statusIndicator.textContent = 'VLESS Proxy активен ✅';
            proxySwitch.checked = true;
        } else {
            statusIndicator.classList.remove('alert-success');
            statusIndicator.classList.add('alert-danger');
            statusIndicator.textContent = 'VLESS Proxy остановлен ❌';
            proxySwitch.checked = false;
        }
        
        // Обновление активного профиля
        activeProfileElement.textContent = currentStatus.active_profile || 'Не выбран';
        
        // Обновление режима проксирования
        const modeText = {
            proxy_all: 'Весь трафик через прокси',
            selective: 'Выборочное проксирование'
        };
        proxyModeElement.textContent = modeText[currentStatus.proxy_mode] || currentStatus.proxy_mode;
        
        // Обновление информации о WiFi
        directSsidElement.textContent = currentStatus.wifi.direct_ssid || 'Не настроено';
        proxySsidElement.textContent = currentStatus.wifi.proxy_ssid || 'Не настроено';
    } catch (error) {
        showError('Ошибка при загрузке данных панели управления: ' + error.message);
    }
}

/**
 * Загружает список профилей
 */
async function loadProfiles() {
    try {
        const data = await api.getProfiles();
        profiles = data.profiles || [];
        
        // Очистка таблицы
        profilesTableBody.innerHTML = '';
        
        // Заполнение таблицы профилями
        profiles.forEach(profile => {
            const row = document.createElement('tr');
            
            // Извлечение сервера из URL
            let server = 'Неизвестный';
            try {
                const url = new URL(profile.url.split('#')[0]);
                server = url.hostname;
            } catch (e) {
                console.warn('Не удалось извлечь сервер из URL профиля:', e);
            }
            
            // Активный профиль
            const isActive = profile.name === currentStatus?.active_profile;
            
            row.innerHTML = `
                <td>${profile.name}</td>
                <td>${server}</td>
                <td>
                    <span class="badge ${isActive ? 'bg-success' : 'bg-secondary'}">
                        ${isActive ? 'Активный' : 'Неактивный'}
                    </span>
                </td>
                <td>
                    <div class="btn-group" role="group">
                        <button class="btn btn-sm btn-outline-primary btn-activate" ${isActive ? 'disabled' : ''}>Активировать</button>
                        <button class="btn btn-sm btn-outline-danger btn-delete">Удалить</button>
                    </div>
                </td>
            `;
            
            // Добавляем обработчики событий для кнопок
            const activateBtn = row.querySelector('.btn-activate');
            activateBtn.addEventListener('click', () => activateProfile(profile.name));
            
            const deleteBtn = row.querySelector('.btn-delete');
            deleteBtn.addEventListener('click', () => deleteProfile(profile.name));
            
            profilesTableBody.appendChild(row);
        });
    } catch (error) {
        showError('Ошибка при загрузке профилей: ' + error.message);
    }
}

/**
 * Загружает списки сайтов (белый и черный)
 */
async function loadSiteLists() {
    try {
        // Загрузка белого списка
        const whitelistData = await api.getWhitelist();
        whitelist = whitelistData.domains || [];
        whitelistSwitch.checked = currentStatus?.proxy_mode?.use_whitelist || false;
        
        // Очистка списка
        whitelistItems.innerHTML = '';
        
        // Заполнение белого списка
        whitelist.forEach(domain => {
            const listItem = document.createElement('li');
            listItem.className = 'list-group-item';
            listItem.innerHTML = `
                <span>${domain}</span>
                <button class="btn btn-sm btn-outline-danger btn-delete-whitelist">Удалить</button>
            `;
            
            // Добавляем обработчик события для кнопки удаления
            const deleteBtn = listItem.querySelector('.btn-delete-whitelist');
            deleteBtn.addEventListener('click', () => removeFromWhitelist(domain));
            
            whitelistItems.appendChild(listItem);
        });
        
        // Загрузка черного списка
        const blacklistData = await api.getBlacklist();
        blacklist = blacklistData.domains || [];
        blacklistSwitch.checked = currentStatus?.proxy_mode?.use_blacklist || false;
        
        // Очистка списка
        blacklistItems.innerHTML = '';
        
        // Заполнение черного списка
        blacklist.forEach(domain => {
            const listItem = document.createElement('li');
            listItem.className = 'list-group-item';
            listItem.innerHTML = `
                <span>${domain}</span>
                <button class="btn btn-sm btn-outline-danger btn-delete-blacklist">Удалить</button>
            `;
            
            // Добавляем обработчик события для кнопки удаления
            const deleteBtn = listItem.querySelector('.btn-delete-blacklist');
            deleteBtn.addEventListener('click', () => removeFromBlacklist(domain));
            
            blacklistItems.appendChild(listItem);
        });
    } catch (error) {
        showError('Ошибка при загрузке списков сайтов: ' + error.message);
    }
}

/**
 * Загружает настройки WiFi
 */
async function loadWifiSettings() {
    try {
        const wifiSettings = await api.getWifiSettings();
        
        // Заполнение полей формы
        directSsidInput.value = wifiSettings.direct_ssid || '';
        directPasswordInput.value = wifiSettings.direct_password || '';
        proxySsidInput.value = wifiSettings.proxy_ssid || '';
        proxyPasswordInput.value = wifiSettings.proxy_password || '';
    } catch (error) {
        showError('Ошибка при загрузке настроек WiFi: ' + error.message);
    }
}

/**
 * Загружает режим проксирования
 */
async function loadProxyMode() {
    try {
        const mode = currentStatus?.proxy_mode || 'proxy_all';
        
        // Установка соответствующего переключателя
        if (mode === 'proxy_all') {
            proxyModeAll.checked = true;
        } else if (mode === 'selective') {
            proxyModeSelective.checked = true;
        }
    } catch (error) {
        showError('Ошибка при загрузке режима проксирования: ' + error.message);
    }
}

/**
 * Настройка обработчиков событий
 */
function setupEventHandlers() {
    // Переключатель прокси
    proxySwitch.addEventListener('change', async () => {
        try {
            await api.toggleProxy(proxySwitch.checked);
            await loadDashboardData();
            showSuccess(proxySwitch.checked ? 'Прокси включен' : 'Прокси выключен');
        } catch (error) {
            showError('Ошибка при переключении прокси: ' + error.message);
        }
    });
    
    // Кнопка добавления профиля
    btnAddProfile.addEventListener('click', () => {
        // Сброс формы
        profileNameInput.value = '';
        profileUrlInput.value = '';
        addProfileModal.show();
    });
    
    // Кнопка сохранения профиля
    btnSaveProfile.addEventListener('click', async () => {
        const name = profileNameInput.value.trim();
        const url = profileUrlInput.value.trim();
        
        if (!name || !url) {
            showError('Необходимо заполнить все поля');
            return;
        }
        
        try {
            await api.addProfile({ name, url, enabled: true });
            addProfileModal.hide();
            await loadProfiles();
            showSuccess('Профиль успешно добавлен');
        } catch (error) {
            showError('Ошибка при добавлении профиля: ' + error.message);
        }
    });
    
    // Переключатели белого и черного списков
    whitelistSwitch.addEventListener('change', async () => {
        try {
            await api.toggleWhitelist(whitelistSwitch.checked);
            await loadDashboardData();
            showSuccess(whitelistSwitch.checked ? 'Белый список включен' : 'Белый список выключен');
        } catch (error) {
            showError('Ошибка при переключении белого списка: ' + error.message);
        }
    });
    
    blacklistSwitch.addEventListener('change', async () => {
        try {
            await api.toggleBlacklist(blacklistSwitch.checked);
            await loadDashboardData();
            showSuccess(blacklistSwitch.checked ? 'Черный список включен' : 'Черный список выключен');
        } catch (error) {
            showError('Ошибка при переключении черного списка: ' + error.message);
        }
    });
    
    // Кнопки добавления в списки
    btnAddWhitelist.addEventListener('click', async () => {
        const domain = whitelistInput.value.trim();
        if (!domain) {
            showError('Укажите домен для добавления');
            return;
        }
        
        try {
            await api.addToWhitelist(domain);
            whitelistInput.value = '';
            await loadSiteLists();
            showSuccess('Домен добавлен в белый список');
        } catch (error) {
            showError('Ошибка при добавлении в белый список: ' + error.message);
        }
    });
    
    btnAddBlacklist.addEventListener('click', async () => {
        const domain = blacklistInput.value.trim();
        if (!domain) {
            showError('Укажите домен для добавления');
            return;
        }
        
        try {
            await api.addToBlacklist(domain);
            blacklistInput.value = '';
            await loadSiteLists();
            showSuccess('Домен добавлен в черный список');
        } catch (error) {
            showError('Ошибка при добавлении в черный список: ' + error.message);
        }
    });
    
    // Кнопки сохранения WiFi настроек
    btnSaveDirectWifi.addEventListener('click', async () => {
        const ssid = directSsidInput.value.trim();
        const password = directPasswordInput.value.trim();
        
        if (!ssid || !password) {
            showError('Укажите SSID и пароль');
            return;
        }
        
        try {
            await api.saveWifiSettings({
                direct_ssid: ssid,
                direct_password: password,
                proxy_ssid: proxySsidInput.value.trim(),
                proxy_password: proxyPasswordInput.value.trim()
            });
            await loadDashboardData();
            showSuccess('Настройки сохранены');
        } catch (error) {
            showError('Ошибка при сохранении настроек WiFi: ' + error.message);
        }
    });
    
    btnSaveProxyWifi.addEventListener('click', async () => {
        const ssid = proxySsidInput.value.trim();
        const password = proxyPasswordInput.value.trim();
        
        if (!ssid || !password) {
            showError('Укажите SSID и пароль');
            return;
        }
        
        try {
            await api.saveWifiSettings({
                direct_ssid: directSsidInput.value.trim(),
                direct_password: directPasswordInput.value.trim(),
                proxy_ssid: ssid,
                proxy_password: password
            });
            await loadDashboardData();
            showSuccess('Настройки сохранены');
        } catch (error) {
            showError('Ошибка при сохранении настроек WiFi: ' + error.message);
        }
    });
    
    // Кнопка сохранения режима проксирования
    btnSaveProxyMode.addEventListener('click', async () => {
        const mode = proxyModeAll.checked ? 'proxy_all' : 'selective';
        
        try {
            await api.saveProxyMode(mode);
            await loadDashboardData();
            showSuccess('Режим проксирования изменен');
        } catch (error) {
            showError('Ошибка при изменении режима проксирования: ' + error.message);
        }
    });
    
    // Кнопки экспорта/импорта настроек
    btnExportSettings.addEventListener('click', async () => {
        try {
            const settings = await api.exportSettings();
            const blob = new Blob([JSON.stringify(settings, null, 2)], { type: 'application/json' });
            const url = URL.createObjectURL(blob);
            
            const a = document.createElement('a');
            a.href = url;
            a.download = 'vless_router_settings.json';
            a.click();
            
            URL.revokeObjectURL(url);
            showSuccess('Настройки экспортированы');
        } catch (error) {
            showError('Ошибка при экспорте настроек: ' + error.message);
        }
    });
    
    btnImportSettings.addEventListener('click', async () => {
        const file = importSettingsFile.files[0];
        if (!file) {
            showError('Выберите файл для импорта');
            return;
        }
        
        try {
            const reader = new FileReader();
            reader.onload = async (e) => {
                try {
                    const settings = JSON.parse(e.target.result);
                    await api.importSettings(settings);
                    await refreshAllData();
                    showSuccess('Настройки импортированы');
                } catch (parseError) {
                    showError('Ошибка при парсинге файла настроек: ' + parseError.message);
                }
            };
            reader.readAsText(file);
        } catch (error) {
            showError('Ошибка при импорте настроек: ' + error.message);
        }
    });
    
    // Кнопки быстрого доступа
    btnRestartProxy.addEventListener('click', async () => {
        try {
            await api.restartProxy();
            await loadDashboardData();
            showSuccess('Прокси перезапущен');
        } catch (error) {
            showError('Ошибка при перезапуске прокси: ' + error.message);
        }
    });
    
    btnRestartWifi.addEventListener('click', async () => {
        try {
            await api.restartWifi();
            showSuccess('WiFi перезапущен');
        } catch (error) {
            showError('Ошибка при перезапуске WiFi: ' + error.message);
        }
    });
    
    btnUpdateProfiles.addEventListener('click', async () => {
        try {
            // Обновление профилей (может потребоваться дополнительный метод API)
            await loadProfiles();
            showSuccess('Профили обновлены');
        } catch (error) {
            showError('Ошибка при обновлении профилей: ' + error.message);
        }
    });
    
    btnRestartRouter.addEventListener('click', async () => {
        if (confirm('Вы уверены, что хотите перезагрузить роутер?')) {
            try {
                await api.restartRouter();
                showSuccess('Роутер перезагружается...');
                
                // Показываем сообщение о необходимости подождать
                statusIndicator.classList.remove('alert-success', 'alert-danger');
                statusIndicator.classList.add('alert-warning');
                statusIndicator.innerHTML = 'Роутер перезагружается. Страница автоматически обновится через <span id="countdown">60</span> секунд...';
                
                // Запускаем таймер обратного отсчета
                let seconds = 60;
                const countdownElement = document.getElementById('countdown');
                const timer = setInterval(() => {
                    seconds--;
                    countdownElement.textContent = seconds;
                    
                    if (seconds <= 0) {
                        clearInterval(timer);
                        window.location.reload();
                    }
                }, 1000);
            } catch (error) {
                showError('Ошибка при перезагрузке роутера: ' + error.message);
            }
        }
    });
    
    // Обработчик для первичной настройки
    document.getElementById('btn-first-run-save').addEventListener('click', saveFirstRunSettings);
}

/**
 * Проверка на первый запуск и показ модального окна
 */
function checkFirstRun() {
    api.getSettings()
        .then(data => {
            settings = data;
            if (settings.first_run === true) {
                firstRunModal = new bootstrap.Modal(document.getElementById('firstRunModal'));
                firstRunModal.show();
            }
        })
        .catch(error => {
            console.error('Ошибка при проверке статуса первого запуска:', error);
        });
}

/**
 * Сохранение настроек первого запуска
 */
function saveFirstRunSettings() {
    const directSsid = document.getElementById('first-run-direct-ssid').value;
    const directPassword = document.getElementById('first-run-direct-password').value;
    const proxySsid = document.getElementById('first-run-proxy-ssid').value;
    const proxyPassword = document.getElementById('first-run-proxy-password').value;
    const proxyMode = document.querySelector('input[name="first-run-proxy-mode"]:checked').value;
    
    // Валидация
    if (!directSsid || !directPassword || !proxySsid || !proxyPassword) {
        alert('Пожалуйста, заполните все поля!');
        return;
    }
    
    if (directPassword.length < 8 || proxyPassword.length < 8) {
        alert('Пароль должен содержать минимум 8 символов!');
        return;
    }
    
    // Обновление настроек
    settings.wifi.direct_ssid = directSsid;
    settings.wifi.direct_password = directPassword;
    settings.wifi.proxy_ssid = proxySsid;
    settings.wifi.proxy_password = proxyPassword;
    settings.mode = proxyMode;
    settings.first_run = false;
    
    // Сохранение настроек и обновление WiFi сетей
    api.saveSettings(settings)
        .then(() => {
            return api.applyWifiSettings(settings.wifi);
        })
        .then(() => {
            // Закрытие модального окна
            firstRunModal.hide();
            
            // Обновление интерфейса
            loadWifiSettings();
            loadGeneralSettings();
            
            // Уведомление пользователя
            showAlert('Начальная настройка завершена. WiFi сети будут перезапущены с новыми настройками.', 'success');
        })
        .catch(error => {
            console.error('Ошибка при сохранении начальных настроек:', error);
            showAlert('Произошла ошибка при сохранении настроек: ' + error, 'danger');
        });
}

/**
 * Активация профиля
 */
async function activateProfile(profileName) {
    try {
        await api.activateProfile(profileName);
        await loadDashboardData();
        await loadProfiles();
        showSuccess(`Профиль "${profileName}" активирован`);
    } catch (error) {
        showError('Ошибка при активации профиля: ' + error.message);
    }
}

/**
 * Удаление профиля
 */
async function deleteProfile(profileName) {
    if (confirm(`Вы уверены, что хотите удалить профиль "${profileName}"?`)) {
        try {
            await api.deleteProfile(profileName);
            await loadProfiles();
            showSuccess(`Профиль "${profileName}" удален`);
        } catch (error) {
            showError('Ошибка при удалении профиля: ' + error.message);
        }
    }
}

/**
 * Удаление домена из белого списка
 */
async function removeFromWhitelist(domain) {
    try {
        await api.removeFromWhitelist(domain);
        await loadSiteLists();
        showSuccess(`Домен "${domain}" удален из белого списка`);
    } catch (error) {
        showError('Ошибка при удалении из белого списка: ' + error.message);
    }
}

/**
 * Удаление домена из черного списка
 */
async function removeFromBlacklist(domain) {
    try {
        await api.removeFromBlacklist(domain);
        await loadSiteLists();
        showSuccess(`Домен "${domain}" удален из черного списка`);
    } catch (error) {
        showError('Ошибка при удалении из черного списка: ' + error.message);
    }
}

/**
 * Обновление всех данных
 */
async function refreshAllData() {
    await loadDashboardData();
    await loadProfiles();
    await loadSiteLists();
    await loadWifiSettings();
    await loadProxyMode();
}

/**
 * Отображение сообщения об успехе
 */
function showSuccess(message) {
    // В качестве примера используем alert, но можно заменить на toast
    alert(message);
}

/**
 * Отображение сообщения об ошибке
 */
function showError(message) {
    // В качестве примера используем alert, но можно заменить на toast
    alert('Ошибка: ' + message);
}

// Инициализация приложения при загрузке страницы
document.addEventListener('DOMContentLoaded', initializeApp);
