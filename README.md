# 🚀 NetCheck — VPS / Network Checker

Многофункциональный bash-скрипт для проверки сетевых параметров сервера, IP-адреса и доступности популярных сервисов.

---

## 📦 Возможности

### 🌐 Сетевые данные
- Определение публичного IPv4
- Определение публичного IPv6
- ASN (провайдер)
- Страна (через несколько GEOIP сервисов)
- Проверка согласованности GEOIP (mismatch detection)
- Классификация IP:
  - Residential (домашний)
  - Mobile (мобильный)
  - Datacenter / Hosting
  - VPN / Proxy (при несовпадении GEO)

---

### 📺 Стриминговые сервисы
- Netflix (доступ + проверка Premium)
- HBO Max
- Hulu
- Prime Video
- Paramount+
- Apple TV+
- Crunchyroll

---

### ▶️ YouTube
- Проверка доступности
- Определение региона

---

### 🌍 Дополнительные сервисы
- Disney+
- OpenAI (проверка API доступности)
- Steam
- TikTok
- Telegram Web
- Reddit
- GitHub
- Cloudflare

---

### 🎧 Музыка
- Spotify (доступность)
- Spotify Premium (доступность)

---

### 🚫 Проверка IP
- Spamhaus (blacklist)
- SORBS (blacklist)

---

### ⚡ Скорость
- Speedtest (если установлен)
- Альтернативный тест загрузки (wget)

---

## ⚙️ Запуск

```bash
bash <(curl -sL https://raw.githubusercontent.com/00firefly00/vps-checker/main/vps_service_checker.sh)
```
