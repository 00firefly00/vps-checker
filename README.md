# VPS Service Checker 🚀

Лёгкий и удобный bash-скрипт для проверки VPS/IP: доступность сервисов, регион, GeoIP, blacklist и тип IP.

---

## 🔍 Возможности

**Проверка сервисов:**
- Netflix  
- YouTube (с определением Premium)  
- Disney+  
- TikTok  
- Spotify  
- ChatGPT  
- Meta (Facebook)  
- Microsoft  

**Определение региона:**
- Реальный регион (по сервисам)  
- GeoIP (несколько баз одновременно)  

**Анализ IP:**
- Тип IP (Datacenter / Residential / Mobile)  
- ASN (провайдер)  
- Проверка blacklist (Spamhaus, SORBS)  

**Дополнительно:**
- Тест скорости (Speedtest)  
- Цветной вывод  
- Анимация во время проверки  
- Удобный вывод для смартфона  

---

## ⚙️ Быстрый запуск

```bash
bash <(curl -Ls https://raw.githubusercontent.com/USERNAME/REPO/main/script.sh)
```
# ⚠️ Примечания

## 🛰️ GeoIP‑сервисы
- Некоторые GeoIP‑провайдеры могут **не отвечать** или **ограничивать количество запросов**.  
- Возможны **расхождения региона** между разными базами данных.

## ▶️ YouTube Premium
- Доступность YouTube Premium определяется **по возможности открыть страницу** `https://www.youtube.com/premium`.  
- Если страница недоступна или происходит редирект — Premium в регионе официально не поддерживается.
