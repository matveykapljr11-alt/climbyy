-- =============================================================
-- CLIMBY — 50 тестовых команд в D1 Rookie
-- Запусти в SQL Editor после 01_schema.sql + 02_seed.sql
-- =============================================================
-- Создаёт 50 команд с разными именами, цветами, очками и рангами.
-- Все команды без members (нужны реальные profiles).
-- На фронте они отрисуются как обычные карточки команд.

-- Сначала получим season_id текущего активного сезона
do $$
declare
  s_id uuid;
begin
  select id into s_id from public.seasons where is_active = true limit 1;

  -- Удаляю старые тестовые команды если запускаю повторно
  delete from public.teams where name like 'Test_%' or created_by is null;

  -- 50 команд с разнообразными именами и характеристиками
  insert into public.teams (
    name, tag, logo_initials, logo_color, bio,
    division_id, season_id, region,
    points, wins, losses, wr, matches_played, rank,
    current_streak, is_recruiting, is_public_stats
  ) values
  -- ТОП-5
  ('Vortex Renegades', 'VRN', 'VR', 'var(--peach)',     'Кэжуальная команда, играем для души. D1 Rookie.', 'd1', s_id, 'RU', 39, 5, 3, 0.625, 8, 1, 2, false, true),
  ('Sparks',           'SPR', 'SP', 'var(--mint)',      'Молодая агрессивная тима.',                       'd1', s_id, 'RU', 38, 5, 2, 0.714, 7, 2, 3, false, true),
  ('9th Hour',         '9TH', '9H', 'var(--lemon)',     'Играем по ночам.',                                'd1', s_id, 'RU', 35, 5, 3, 0.625, 8, 3, 1, false, true),
  ('Shadow Ops',       'SHO', 'SH', 'var(--sky)',       'Тихие, чёткие, опасные.',                         'd1', s_id, 'RU', 28, 4, 4, 0.500, 8, 4, 0, false, true),
  ('Krypto',           'KRY', 'KR', 'var(--accent)',    'Криптовалютная тима.',                            'd1', s_id, 'RU', 22, 3, 5, 0.375, 8, 5, -1, true,  true),

  -- 6-15
  ('Pixel Riot',       'PXR', 'PX', 'var(--accent)',    'Игроки с пикселями в крови.',                     'd1', s_id, 'RU', 21, 3, 4, 0.428, 7, 6,  1, false, true),
  ('Foxy Crew',        'FXY', 'FY', 'var(--hot-pink)',  'Хитрые лисы с RUST.',                             'd1', s_id, 'RU', 20, 3, 5, 0.375, 8, 7,  0, true,  true),
  ('Rebels.',          'RBL', 'RB', '#b88a5f',          'Бунтари без причины.',                            'd1', s_id, 'KZ', 19, 3, 5, 0.375, 8, 8, -1, false, true),
  ('Nexus5',           'NX5', 'NX', '#d4d8e0',          'Команда из 5 ветеранов.',                         'd1', s_id, 'RU', 18, 2, 4, 0.333, 6, 9,  0, false, true),
  ('Kazbek',           'KZB', 'KZ', 'var(--sky)',       'С Кавказа с любовью.',                            'd1', s_id, 'GE', 17, 2, 5, 0.286, 7, 10, 0, false, true),
  ('No Mercy',         'NOM', 'NM', 'var(--hot-pink)',  'Без жалости, без вопросов.',                      'd1', s_id, 'RU', 16, 2, 5, 0.286, 7, 11,-3, false, true),
  ('Black Roses',      'BLR', 'BR', '#1a1a1a',          'Тёмная сторона лиги.',                            'd1', s_id, 'BY', 15, 2, 5, 0.286, 7, 12, 0, false, true),
  ('Cybernetix',       'CBN', 'CB', 'var(--accent-2)',  'Будущее уже здесь.',                              'd1', s_id, 'RU', 15, 2, 5, 0.286, 7, 13, 0, true,  true),
  ('Aurora Squad',     'AUR', 'AU', '#7ec8e3',          'Северное сияние на DUST.',                        'd1', s_id, 'RU', 14, 2, 6, 0.250, 8, 14, 0, false, true),
  ('Phoenix Rising',   'PHX', 'PX', '#ff6b35',          'Возрождаемся в каждом матче.',                    'd1', s_id, 'UA', 14, 2, 6, 0.250, 8, 15, 0, false, true),

  -- 16-30
  ('TerraFirm',        'TRF', 'TF', '#5a8c3f',          'Земля под ногами.',                               'd1', s_id, 'RU', 13, 2, 6, 0.250, 8, 16, -2, false, true),
  ('Iron Will',        'IRN', 'IW', '#4a4a4a',          'Железная воля к победе.',                         'd1', s_id, 'RU', 13, 2, 6, 0.250, 8, 17,  0, false, true),
  ('Astral Hunters',   'ASH', 'AH', '#a78bfa',          'Охотники между мирами.',                          'd1', s_id, 'KZ', 12, 1, 4, 0.200, 5, 18,  0, true,  true),
  ('NeonByte',         'NBT', 'NB', '#22d3ee',          'Неон и киберпанк.',                               'd1', s_id, 'RU', 12, 1, 5, 0.167, 6, 19,  0, false, false), -- закрытая стата
  ('Silent Punch',     'SLN', 'SP', '#6b6b6b',          'Тихий удар.',                                     'd1', s_id, 'BY', 12, 1, 5, 0.167, 6, 20,  0, false, true),
  ('Dragon Fire',      'DRF', 'DF', '#dc2626',          'Огонь дракона.',                                  'd1', s_id, 'UA', 11, 1, 5, 0.167, 6, 21,  0, false, true),
  ('Stealth Foxes',    'STF', 'SF', '#f97316',          'Хитрые скрытные лисы.',                           'd1', s_id, 'RU', 11, 1, 5, 0.167, 6, 22,  0, true,  true),
  ('Quantum',          'QTM', 'QT', '#8b5cf6',          'Квантовая запутанность.',                         'd1', s_id, 'RU', 10, 1, 6, 0.143, 7, 23,  0, false, true),
  ('Sentinel',         'SNT', 'SN', '#0ea5e9',          'Стражи лиги.',                                    'd1', s_id, 'RU', 10, 1, 6, 0.143, 7, 24,  0, false, true),
  ('Ravenswood',       'RVN', 'RW', '#3f3f46',          'Вороны на дереве.',                               'd1', s_id, 'KZ', 10, 1, 6, 0.143, 7, 25,  0, false, true),
  ('Wildcats',         'WDC', 'WC', '#eab308',          'Дикие кошки D1.',                                 'd1', s_id, 'RU',  9, 1, 6, 0.143, 7, 26,  0, false, true),
  ('Glitch Mob',       'GLT', 'GM', '#84cc16',          'Сбой в матрице — это мы.',                        'd1', s_id, 'BY',  9, 1, 6, 0.143, 7, 27,  0, false, false), -- закрытая стата
  ('Solar Flare',      'SLR', 'SL', '#f59e0b',          'Солнечная вспышка.',                              'd1', s_id, 'RU',  8, 1, 7, 0.125, 8, 28, -2, false, true),
  ('Echo',             'ECH', 'EC', '#06b6d4',          'Эхо на серверах.',                                'd1', s_id, 'UA',  8, 1, 7, 0.125, 8, 29,  0, false, true),
  ('Nightwalkers',     'NWK', 'NW', '#1e1b4b',          'Бродим ночью.',                                   'd1', s_id, 'RU',  8, 1, 7, 0.125, 8, 30,  0, true,  true),

  -- 31-50 (новички в опасной зоне)
  ('Crimson Tide',     'CRT', 'CT', '#991b1b',          'Багровая волна.',                                 'd1', s_id, 'RU',  7, 1, 7, 0.125, 8, 31,  0, false, true),
  ('Last Stand',       'LST', 'LS', '#525252',          'Последняя стойка.',                               'd1', s_id, 'KZ',  7, 1, 7, 0.125, 8, 32,  0, true,  true),
  ('Apex Wolves',      'APX', 'AW', '#737373',          'Альфа-волки D1.',                                 'd1', s_id, 'RU',  6, 0, 6, 0.000, 6, 33,  0, true,  true),
  ('Frostbite',        'FRB', 'FB', '#67e8f9',          'Обморожение от наших фрагов.',                    'd1', s_id, 'BY',  6, 0, 7, 0.000, 7, 34,  0, false, true),
  ('Hex Reapers',      'HEX', 'HR', '#4c1d95',          'Жнецы шестигранников.',                           'd1', s_id, 'RU',  5, 0, 7, 0.000, 7, 35,  0, false, true),
  ('Vandals',          'VND', 'VD', '#dc2626',          'Хулиганы D1.',                                    'd1', s_id, 'UA',  5, 0, 8, 0.000, 8, 36,  0, true,  true),
  ('Bleak Avenue',     'BLA', 'BA', '#404040',          'Мрачная улица.',                                  'd1', s_id, 'RU',  5, 0, 8, 0.000, 8, 37,  0, false, true),
  ('Static',           'STC', 'ST', '#a1a1aa',          'Помехи в эфире.',                                 'd1', s_id, 'RU',  4, 0, 8, 0.000, 8, 38,  0, false, true),
  ('Voidwalkers',      'VOI', 'VW', '#1e293b',          'Шагатели в пустоту.',                             'd1', s_id, 'KZ',  4, 0, 8, 0.000, 8, 39,  0, true,  true),
  ('Crusaders',        'CRU', 'CR', '#0891b2',          'Крестоносцы лиги.',                               'd1', s_id, 'RU',  4, 0, 8, 0.000, 8, 40,  0, false, true),
  ('Outliers',         'OUT', 'OL', '#9ca3af',          'Выпадают из статистики.',                         'd1', s_id, 'BY',  3, 0, 8, 0.000, 8, 41,  0, false, true),
  ('Mistral',          'MST', 'MS', '#a3e635',          'Холодный южный ветер.',                           'd1', s_id, 'UA',  3, 0, 8, 0.000, 8, 42,  0, true,  true),
  ('Volt',             'VLT', 'VL', '#fde047',          'Электричество.',                                  'd1', s_id, 'RU',  3, 0, 8, 0.000, 8, 43,  0, false, true),
  ('Ghost Protocol',   'GHP', 'GP', '#27272a',          'Никто не услышит.',                               'd1', s_id, 'RU',  2, 0, 8, 0.000, 8, 44,  0, false, false), -- закрытая стата
  ('Cinder',           'CDR', 'CD', '#9a3412',          'Угольки былой славы.',                            'd1', s_id, 'RU',  2, 0, 8, 0.000, 8, 45,  0, false, true),
  ('Hollow',           'HLW', 'HL', '#52525b',          'Пустые внутри.',                                  'd1', s_id, 'KZ',  2, 0, 8, 0.000, 8, 46,  0, true,  true),
  ('Mock5',            'MK5', 'M5', '#525252',          'Команда из мокапов.',                             'd1', s_id, 'RU',  1, 0, 8, 0.000, 8, 47,  0, false, true),
  ('Underdogs',        'UND', 'UD', '#92400e',          'Тёмные лошадки.',                                 'd1', s_id, 'UA',  1, 0, 8, 0.000, 8, 48,  0, true,  true),
  ('Plan B',           'PLB', 'PB', '#0369a1',          'Запасной план.',                                  'd1', s_id, 'BY',  0, 0, 8, 0.000, 8, 49,  0, true,  true),
  ('Last Place',       'LP1', 'LP', '#71717a',          'Дно турнирной таблицы (пока).',                   'd1', s_id, 'RU',  0, 0, 8, 0.000, 8, 50,  0, true,  true);

end $$;

-- Проверка
select count(*) as total_teams from public.teams where division_id = 'd1';
-- Ожидаемо: 50

select rank, name, tag, points, wins || '-' || losses as record, round(wr*100)::int || '%' as winrate
from public.teams
where division_id = 'd1'
order by rank
limit 10;
