VPS Service Checker 🚀


Удобный bash-скрипт для быстрой проверки VPS/IP: доступность популярных сервисов, реальный регион, GeoIP, blacklist и тип IP.


🔍 Возможности






Проверка доступности сервисов:




Netflix


YouTube (включая Premium)


Disney+


TikTok


Spotify


ChatGPT


Meta (Facebook)


Microsoft








Определение региона:




Реальный регион (по сервисам)


GeoIP (несколько баз одновременно)








Анализ IP:




Тип IP (Datacenter / Residential / Mobile)


ASN (провайдер)


Проверка по blacklist (Spamhaus, SORBS)








Дополнительно:




Тест скорости (Speedtest)


Цветной вывод


Анимация во время проверки


Адаптация под экран смартфона









⚙️ Установка и запуск


Быстрый запуск (одной командой)


bash <(curl -Ls https://raw.githubusercontent.com/USERNAME/REPO/main/script.sh)




Ручная установка


git clone https://github.com/USERNAME/REPO.git
cd REPO
chmod +x script.sh
./script.sh




📊 Пример вывода


Сервис     Статус  Регион
------     ------  ------
Netflix    ✔       GB
YouTube+   ✔       GB
Spotify    ✔       GB
ChatGPT    ✔       GB
Meta       ✔       GB
Microsoft  -       GB

==== GEOIP ====
ipinfo ip-api ipapi ifcfg 2ip
GB     GB     GB     GB     GB

ФАКТИЧЕСКИЙ РЕГИОН: GB
Тип IP: Datacenter




⚠️ Примечания




Некоторые GeoIP-сервисы могут не отвечать или ограничивать запросы


Регион определяется по нескольким источникам, возможны расхождения


YouTube Premium определяется по доступности страницы





🧠 Для чего это нужно




Проверка качества VPS перед использованием


Подбор IP для стриминга (Netflix, YouTube и др.)


Проверка блокировок и гео-ограничений


Анализ IP для VPN / прокси





⭐ Планы




Определение Netflix Full/Partial Unlock


Проверка доступности в Китае / Иране


Более точный анализ «чистоты» IP





📄 Лицензия


MIT License

