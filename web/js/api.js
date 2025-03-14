/**
 * API для взаимодействия с сервером VLESS Router
 */
class VlessRouterAPI {
    constructor() {
        this.baseUrl = '/api';
    }

    /**
     * Получение текущего статуса сервиса
     */
    async getStatus() {
        try {
            const response = await fetch(`${this.baseUrl}/status`);
            if (!response.ok) {
                throw new Error(`Ошибка API: ${response.status}`);
            }
            return await response.json();
        } catch (error) {
            console.error('Ошибка при получении статуса:', error);
            throw error;
        }
    }

    /**
     * Включение/выключение прокси
     */
    async toggleProxy(enabled) {
        try {
            const response = await fetch(`${this.baseUrl}/proxy/toggle`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ enabled }),
            });
            if (!response.ok) {
                throw new Error(`Ошибка API: ${response.status}`);
            }
            return await response.json();
        } catch (error) {
            console.error('Ошибка при переключении прокси:', error);
            throw error;
        }
    }

    /**
     * Перезапуск прокси
     */
    async restartProxy() {
        try {
            const response = await fetch(`${this.baseUrl}/proxy/restart`, {
                method: 'POST',
            });
            if (!response.ok) {
                throw new Error(`Ошибка API: ${response.status}`);
            }
            return await response.json();
        } catch (error) {
            console.error('Ошибка при перезапуске прокси:', error);
            throw error;
        }
    }

    /**
     * Получение списка профилей
     */
    async getProfiles() {
        try {
            const response = await fetch(`${this.baseUrl}/profiles`);
            if (!response.ok) {
                throw new Error(`Ошибка API: ${response.status}`);
            }
            return await response.json();
        } catch (error) {
            console.error('Ошибка при получении профилей:', error);
            throw error;
        }
    }

    /**
     * Добавление нового профиля
     */
    async addProfile(profile) {
        try {
            const response = await fetch(`${this.baseUrl}/profiles/add`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(profile),
            });
            if (!response.ok) {
                throw new Error(`Ошибка API: ${response.status}`);
            }
            return await response.json();
        } catch (error) {
            console.error('Ошибка при добавлении профиля:', error);
            throw error;
        }
    }

    /**
     * Удаление профиля
     */
    async deleteProfile(profileName) {
        try {
            const response = await fetch(`${this.baseUrl}/profiles/delete`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ name: profileName }),
            });
            if (!response.ok) {
                throw new Error(`Ошибка API: ${response.status}`);
            }
            return await response.json();
        } catch (error) {
            console.error('Ошибка при удалении профиля:', error);
            throw error;
        }
    }

    /**
     * Активация профиля
     */
    async activateProfile(profileName) {
        try {
            const response = await fetch(`${this.baseUrl}/profiles/activate`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ name: profileName }),
            });
            if (!response.ok) {
                throw new Error(`Ошибка API: ${response.status}`);
            }
            return await response.json();
        } catch (error) {
            console.error('Ошибка при активации профиля:', error);
            throw error;
        }
    }

    /**
     * Получение настроек WiFi
     */
    async getWifiSettings() {
        try {
            const response = await fetch(`${this.baseUrl}/wifi/settings`);
            if (!response.ok) {
                throw new Error(`Ошибка API: ${response.status}`);
            }
            return await response.json();
        } catch (error) {
            console.error('Ошибка при получении настроек WiFi:', error);
            throw error;
        }
    }

    /**
     * Сохранение настроек WiFi
     */
    async saveWifiSettings(settings) {
        try {
            const response = await fetch(`${this.baseUrl}/wifi/settings`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(settings),
            });
            if (!response.ok) {
                throw new Error(`Ошибка API: ${response.status}`);
            }
            return await response.json();
        } catch (error) {
            console.error('Ошибка при сохранении настроек WiFi:', error);
            throw error;
        }
    }

    /**
     * Перезапуск WiFi
     */
    async restartWifi() {
        try {
            const response = await fetch(`${this.baseUrl}/wifi/restart`, {
                method: 'POST',
            });
            if (!response.ok) {
                throw new Error(`Ошибка API: ${response.status}`);
            }
            return await response.json();
        } catch (error) {
            console.error('Ошибка при перезапуске WiFi:', error);
            throw error;
        }
    }

    /**
     * Получение белого списка
     */
    async getWhitelist() {
        try {
            const response = await fetch(`${this.baseUrl}/whitelist`);
            if (!response.ok) {
                throw new Error(`Ошибка API: ${response.status}`);
            }
            return await response.json();
        } catch (error) {
            console.error('Ошибка при получении белого списка:', error);
            throw error;
        }
    }

    /**
     * Добавление сайта в белый список
     */
    async addToWhitelist(domain) {
        try {
            const response = await fetch(`${this.baseUrl}/whitelist/add`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ domain }),
            });
            if (!response.ok) {
                throw new Error(`Ошибка API: ${response.status}`);
            }
            return await response.json();
        } catch (error) {
            console.error('Ошибка при добавлении в белый список:', error);
            throw error;
        }
    }

    /**
     * Удаление сайта из белого списка
     */
    async removeFromWhitelist(domain) {
        try {
            const response = await fetch(`${this.baseUrl}/whitelist/remove`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ domain }),
            });
            if (!response.ok) {
                throw new Error(`Ошибка API: ${response.status}`);
            }
            return await response.json();
        } catch (error) {
            console.error('Ошибка при удалении из белого списка:', error);
            throw error;
        }
    }

    /**
     * Включение/выключение белого списка
     */
    async toggleWhitelist(enabled) {
        try {
            const response = await fetch(`${this.baseUrl}/whitelist/toggle`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ enabled }),
            });
            if (!response.ok) {
                throw new Error(`Ошибка API: ${response.status}`);
            }
            return await response.json();
        } catch (error) {
            console.error('Ошибка при переключении белого списка:', error);
            throw error;
        }
    }

    /**
     * Получение черного списка
     */
    async getBlacklist() {
        try {
            const response = await fetch(`${this.baseUrl}/blacklist`);
            if (!response.ok) {
                throw new Error(`Ошибка API: ${response.status}`);
            }
            return await response.json();
        } catch (error) {
            console.error('Ошибка при получении черного списка:', error);
            throw error;
        }
    }

    /**
     * Добавление сайта в черный список
     */
    async addToBlacklist(domain) {
        try {
            const response = await fetch(`${this.baseUrl}/blacklist/add`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ domain }),
            });
            if (!response.ok) {
                throw new Error(`Ошибка API: ${response.status}`);
            }
            return await response.json();
        } catch (error) {
            console.error('Ошибка при добавлении в черный список:', error);
            throw error;
        }
    }

    /**
     * Удаление сайта из черного списка
     */
    async removeFromBlacklist(domain) {
        try {
            const response = await fetch(`${this.baseUrl}/blacklist/remove`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ domain }),
            });
            if (!response.ok) {
                throw new Error(`Ошибка API: ${response.status}`);
            }
            return await response.json();
        } catch (error) {
            console.error('Ошибка при удалении из черного списка:', error);
            throw error;
        }
    }

    /**
     * Включение/выключение черного списка
     */
    async toggleBlacklist(enabled) {
        try {
            const response = await fetch(`${this.baseUrl}/blacklist/toggle`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ enabled }),
            });
            if (!response.ok) {
                throw new Error(`Ошибка API: ${response.status}`);
            }
            return await response.json();
        } catch (error) {
            console.error('Ошибка при переключении черного списка:', error);
            throw error;
        }
    }

    /**
     * Сохранение режима проксирования
     */
    async saveProxyMode(mode) {
        try {
            const response = await fetch(`${this.baseUrl}/settings/proxy-mode`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ mode }),
            });
            if (!response.ok) {
                throw new Error(`Ошибка API: ${response.status}`);
            }
            return await response.json();
        } catch (error) {
            console.error('Ошибка при сохранении режима проксирования:', error);
            throw error;
        }
    }

    /**
     * Экспорт настроек
     */
    async exportSettings() {
        try {
            const response = await fetch(`${this.baseUrl}/settings/export`);
            if (!response.ok) {
                throw new Error(`Ошибка API: ${response.status}`);
            }
            return await response.json();
        } catch (error) {
            console.error('Ошибка при экспорте настроек:', error);
            throw error;
        }
    }

    /**
     * Импорт настроек
     */
    async importSettings(settings) {
        try {
            const response = await fetch(`${this.baseUrl}/settings/import`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(settings),
            });
            if (!response.ok) {
                throw new Error(`Ошибка API: ${response.status}`);
            }
            return await response.json();
        } catch (error) {
            console.error('Ошибка при импорте настроек:', error);
            throw error;
        }
    }

    /**
     * Перезагрузка роутера
     */
    async restartRouter() {
        try {
            const response = await fetch(`${this.baseUrl}/router/restart`, {
                method: 'POST',
            });
            if (!response.ok) {
                throw new Error(`Ошибка API: ${response.status}`);
            }
            return await response.json();
        } catch (error) {
            console.error('Ошибка при перезагрузке роутера:', error);
            throw error;
        }
    }
}

// Создаем и экспортируем экземпляр API
const api = new VlessRouterAPI();
