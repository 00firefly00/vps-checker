# VPS Service Checker

Универсальный Bash‑скрипт для диагностики доступности онлайн‑сервисов с вашего VPS, сервера или прокси‑узла.  
Определяет публичный IP, регион, ASN, а также проверяет стриминги, соцсети, игровые платформы и инфраструктурные сервисы.

---

## ✨ Возможности

- Определение:
  - Публичного IPv4
  - Публичного IPv6
  - ASN, страны, региона, провайдера
- Проверка доступности сервисов:
  - Netflix
  - YouTube Premium
  - Disney+
  - OpenAI / ChatGPT
  - Steam
  - TikTok
  - Telegram
  - Reddit
  - GitHub
  - Cloudflare Warp / Zero Trust
- Цветной, компактный вывод (🟢🟡🔴)
- Минимальные зависимости — только `curl`
- Поддержка большинства Linux‑дистрибутивов:
  - Ubuntu / Debian
  - CentOS / Rocky / AlmaLinux
  - Alpine
  - Arch
  - OpenWRT
  - Docker‑контейнеры

---

## 🚀 Быстрый запуск

### Однострочный запуск
```bash
bash <(curl -sL https://raw.githubusercontent.com/00firefly00/vps-checker/main/vps_service_checker.sh)
```
## 🧪 Проверяемые сервисы

| Категория        | Сервисы                                   |
|------------------|--------------------------------------------|
| **IP / Geo**     | IPv4, IPv6, ASN, страна, провайдер         |
| **Стриминги**    | Netflix, YouTube Premium, Disney+          |
| **AI‑сервисы**   | OpenAI / ChatGPT                           |
| **Игры**         | Steam                                      |
| **Соцсети**      | TikTok, Telegram, Reddit                   |
| **Инфраструктура** | GitHub, Cloudflare                       |

Статусы проверки:
- 🟢 доступно  
- 🟡 частично / регионально  
- 🔴 заблокировано  
- ⚪ невозможно определить  

---

## 📄 Пример вывода

= IP: 203.0.113.10 (AS12345 Example ISP, US)

- Netflix:         🟢 Full Access (US)
= YouTube Premium: 🟡 Region Locked
= OpenAI:          🟢 Available
= Steam:           🔴 Blocked
= TikTok:          🟢 Available
= Telegram:        🟢 Available


---

## 🛠 Требования

- bash или совместимая оболочка  
- curl  

---

## 📁 Структура скрипта

- Модульные функции для каждой проверки  
- Fallback‑механизмы API  
- Безопасный парсинг JSON через grep/sed/awk  
- Цветной ANSI‑вывод  
- Поддержка IPv4 и IPv6  

---



---

## 📜 Лицензия

MIT License.
