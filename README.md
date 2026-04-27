# BB-Project: Тестовое приложение с кеширующим слоем

## Архитектура

Приложение состоит из четырёх компонентов, развёрнутых на отдельных виртуальных машинах:

| ВМ | IP | Компонент | ОС |
|---|---|---|---|
| proxy | 192.168.1.141 | Flask cache-api (прокси) | CentOS 9 Stream |
| cache | 192.168.1.142 | Redis 7.2 | CentOS 9 Stream |
| backend | 192.168.1.143 | Go Backend API | Ubuntu 24.04 |
| db | 192.168.1.144 | PostgreSQL 15 | Ubuntu 24.04 |

### Логика работы

Пользователь
↓
proxy (cache-api.py, :5000)
↓              ↓
Redis (:6379)   Backend API (:8080)
↓
PostgreSQL (:5432)

Прокси принимает запрос → проверяет Redis → если данных нет, идёт к Backend → Backend читает из PostgreSQL → прокси сохраняет результат в Redis и возвращает клиенту.

---

## Сетевая топология

Правила настроены через `iptables`, скрипт `rules.sh` применяется на каждой ВМ с соответствующим флагом:

```bash
sudo bash rules.sh --proxy    # на ВМ proxy
sudo bash rules.sh --cache    # на ВМ cache
sudo bash rules.sh --backend  # на ВМ backend
sudo bash rules.sh --db       # на ВМ db
```

| Источник | Назначение | Порт | Доступ |
|---|---|---|---|
| Любой | proxy | 5000 | ✅ |
| proxy | cache (Redis) | 6379 | ✅ |
| proxy | backend | 8080 | ✅ |
| backend | db (PostgreSQL) | 5432 | ✅ |
| Все остальные | backend | 8080 | ❌ |
| Все остальные | cache | 6379 | ❌ |
| Все остальные | db | 5432 | ❌ |

---

## Структура репозитория

bb-project/
├── rules.sh                          # Скрипт настройки iptables для всех ВМ
├── control                           # Спецификация .deb пакета
├── cache-api.spec                    # Спецификация .rpm пакета
|
└── README.md

---

## Пакеты приложений

### Backend API (.deb, Ubuntu)
- Бинарник Go собран на ВМ backend
- Установлен через `dpkg -i backend-api.deb`
- Управляется через `systemctl`

### Cache API (.rpm, CentOS)
- Python Flask приложение
- Установлен через `rpm -i cache-api.rpm`
- Управляется через `systemctl`

---

## Проверка работы

### Статус сервисов

*[СКРИНШОТ 1 — sudo systemctl status backend-api на ВМ backend]*
<img width="976" height="330" alt="изображение" src="https://github.com/user-attachments/assets/1e4d54d3-eeda-4ba2-ad68-a221c1a18105" />

*[СКРИНШОТ 2 — sudo systemctl status cache-api на ВМ proxy]*
<img width="1096" height="505" alt="изображение" src="https://github.com/user-attachments/assets/369064fe-852c-4bb0-8602-f9d057a57c85" />

### Работа кэширования

Первый запрос — данные берутся из PostgreSQL через Backend:
```bash
curl http://192.168.1.141:5000/user?id=5
```
```json
{"cached":false,"user":{"age":35,"id":5,"name":"Charlie Davis"}}
```

Второй запрос — данные берутся из Redis:
```bash
curl http://192.168.1.141:5000/user?id=5
```
```json
{"cached":true,"user":{"age":35,"id":5,"name":"Charlie Davis"}}
```

*[СКРИНШОТ 3 — оба curl запроса к прокси, cached false и cached true]*
<img width="667" height="171" alt="изображение" src="https://github.com/user-attachments/assets/a3d1b954-0a7d-45ef-8390-447d87e4eb79" />

### Доступ разрешён — proxy обращается к backend напрямую

```bash
curl http://192.168.1.143:8080/user?id=5
```

*[СКРИНШОТ 4 — curl с proxy на backend, успешный ответ]*
<img width="603" height="75" alt="изображение" src="https://github.com/user-attachments/assets/5706126e-a4dd-4098-9b62-e2ee4fec8c60" />

### Доступ заблокирован — db не может обратиться к backend и Redis

```bash
curl --connect-timeout 5 http://192.168.1.143:8080/user?id=5
curl --connect-timeout 5 http://192.168.1.142:6379
```

*[СКРИНШОТ 5 — curl с db на backend и redis, оба timeout]*
<img width="927" height="123" alt="изображение" src="https://github.com/user-attachments/assets/914dd5cb-7350-4435-8154-4689b1fc9ccc" />

---

## База данных

PostgreSQL 15, БД `test`, таблица `users` (20 записей).

Пользователь приложения имеет только право `SELECT` на таблицу — принцип минимальных привилегий.
