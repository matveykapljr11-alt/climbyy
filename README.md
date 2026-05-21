# 🧗 Climby — кэжуальная Standoff 2 лига

Бета-платформа для casual-competitive Standoff 2 турниров в FACEIT-стиле.

**Концепт:**
- Сезоны по 1 месяцу
- 4 дивизиона: 🐣 D1 Rookie → ⚔️ D2 Challenger → 💎 D3 Elite → 👑 D4 Pro
- Команды 5/5 с ролями (Captain / Sniper / Entry / Support / Substitute)
- Точечный матчмейкинг ±7 PTS
- Ready System, Map Pick/Ban
- Промоушн/релегейшн между сезонами

---

## 📁 Структура

```
climby/
├── index.html                 ← Прототип (single-file SPA)
├── supabase/
│   ├── 01_schema.sql          ← Схема БД (таблицы, RLS, триггеры)
│   ├── 02_seed.sql            ← Стартовые данные (дивизионы, сезон, новости)
│   ├── 03_seed_teams.sql      ← 50 тестовых команд D1
│   └── client.js              ← JS-обёртка для работы с Supabase
├── .env.example               ← Шаблон переменных окружения
├── .gitignore
└── README.md
```

---

## 🚀 Запуск

### 1. Клонируй репо
```bash
git clone https://github.com/YOUR_USERNAME/climby.git
cd climby
```

### 2. Создай проект на Supabase
1. https://supabase.com → New project
2. Регион: Frankfurt (для RU аудитории)
3. Скопируй `Project URL` и `anon public key` из Settings → API

### 3. Залей схему БД
Открой Supabase Dashboard → SQL Editor → запусти по очереди:
1. `supabase/01_schema.sql`
2. `supabase/02_seed.sql`
3. `supabase/03_seed_teams.sql`

### 4. Включи Realtime
В SQL Editor:
```sql
alter publication supabase_realtime add table public.matches;
alter publication supabase_realtime add table public.match_maps;
alter publication supabase_realtime add table public.match_confirmations;
alter publication supabase_realtime add table public.notifications;
alter publication supabase_realtime add table public.team_invites;
```

### 5. Настрой переменные окружения
```bash
cp .env.example .env
# Открой .env и подмени значения
```

### 6. Открой index.html в браузере
Просто открой файл двойным кликом или подними локальный сервер:
```bash
python3 -m http.server 8000
# → http://localhost:8000
```

---

## 🛠 Технологии

- **Фронт:** ванильный HTML/CSS/JS (single-file SPA, ~12700 строк)
- **БД:** Supabase (PostgreSQL + Auth + Realtime + RLS)
- **Авторизация:** Telegram WebApp (через бота) / Email magic link
- **Хостинг:** Vercel / Netlify / любой статический

Никаких билдов, бандлеров и фреймворков. Один HTML-файл = весь сайт.

---

## 📋 Что работает в прототипе

- ✅ 12 страниц (home, matches, teams, team, players, player, match, news, notifications, help, settings, season, invites)
- ✅ 9 модалок (auth, verify, team, logout, support, apply, challenge, message, achievement, article, globalSearch)
- ✅ 3 фазы матча с симуляцией LIVE раундов
- ✅ Ready System, Map Pick/Ban, Reports, Appeals
- ✅ Гостевой и залогиненный режимы
- ✅ Тёмная/светлая темы
- ✅ Cmd+K глобальный поиск
- ✅ Звуки + конфетти + toast 4 типов
- ✅ Адаптив (мобильный, планшет, десктоп)

## 🔌 Что подключается через Supabase

| Прототип (хардкод) | Supabase (API) |
|---------------------|----------------|
| 50 команд на /teams | `Teams.list('d1')` |
| Матчи на /matches | `Matches.upcoming(teamId)` |
| Лента новостей | `News.list()` + `News.featured()` |
| Уведомления | `Notifications.list()` + real-time |
| Состав команды | `Teams.getById(id)` |
| Создание тимы | `Teams.create({ ... })` |
| Заявки | `Invites.list()` / `Invites.accept(id)` |
| Репорты / тикеты | `Support.submitReport(...)` |

---

## 🎯 Roadmap

### Альфа (готово)
- [x] Прототип всех экранов
- [x] Схема БД
- [x] RLS-политики
- [x] Realtime подписки

### Бета (текущая)
- [ ] Подключение фронта к Supabase
- [ ] TG-бот для верификации Standoff 2 ID
- [ ] Админка для модераторов матчей
- [ ] Реальная авторизация
- [ ] 50 команд → реальный сезон

### Сезон 2
- [ ] Открытие D2 Challenger
- [ ] Промоушн системы (топ-8 → D2)
- [ ] Платежи (опционально)
- [ ] EN / UA / KZ локализация

---

## 🤝 Контакты

- **Telegram:** [@climby_league](https://t.me/climby_league)
- **Discord:** скоро
- **Twitch:** twitch.tv/climby_league (для стримов финалов)

---

## 📄 License

MIT
