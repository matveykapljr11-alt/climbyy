// =============================================================
// CLIMBY — Supabase client + helpers
// Подключи этот файл в HTML перед основными скриптами:
// <script src="https://unpkg.com/@supabase/supabase-js@2"></script>
// <script src="supabase-client.js"></script>
// =============================================================

// ⚠️ ВСТАВЬ СВОИ КЛЮЧИ (Project Settings → API)
const SUPABASE_URL      = 'https://YOUR_PROJECT.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGc...'; // anon public key

const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  },
});

// =============================================================
// AUTH — состояние юзера
// =============================================================

const Auth = {
  async getUser() {
    const { data: { user } } = await supabase.auth.getUser();
    return user;
  },

  async getProfile() {
    const user = await this.getUser();
    if (!user) return null;
    const { data } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', user.id)
      .single();
    return data;
  },

  async signOut() {
    await supabase.auth.signOut();
    location.reload();
  },

  onChange(callback) {
    return supabase.auth.onAuthStateChange((event, session) => {
      callback(event, session?.user || null);
    });
  },

  // Логин через Telegram (если используешь TG-бота — обмен токеном)
  async signInWithTelegram(tgInitData) {
    // Реализуй через свой бэкенд / edge function, который проверит TG-подпись
    // и вернёт Supabase session token
    const res = await fetch('/api/auth/telegram', {
      method: 'POST',
      body: JSON.stringify({ initData: tgInitData }),
    });
    const { access_token, refresh_token } = await res.json();
    await supabase.auth.setSession({ access_token, refresh_token });
  },
};

// =============================================================
// TEAMS — команды
// =============================================================

const Teams = {
  async list(divisionId = 'd1') {
    const { data, error } = await supabase
      .from('teams')
      .select('*')
      .eq('division_id', divisionId)
      .order('points', { ascending: false });
    if (error) throw error;
    return data;
  },

  async getById(id) {
    const { data, error } = await supabase
      .from('teams')
      .select(`
        *,
        members:team_members(
          *,
          profile:profiles(*)
        )
      `)
      .eq('id', id)
      .single();
    if (error) throw error;
    return data;
  },

  async create({ name, tag, logoInitials, logoColor, bio }) {
    const user = await Auth.getUser();
    const { data, error } = await supabase
      .from('teams')
      .insert({
        name, tag,
        logo_initials: logoInitials,
        logo_color: logoColor,
        bio,
        created_by: user.id,
        season_id: await this._currentSeasonId(),
      })
      .select()
      .single();
    if (error) throw error;

    // Сразу добавляю создателя как капитана
    await supabase.from('team_members').insert({
      team_id: data.id,
      player_id: user.id,
      role: 'captain',
      is_captain: true,
    });

    return data;
  },

  async _currentSeasonId() {
    const { data } = await supabase
      .from('seasons')
      .select('id')
      .eq('is_active', true)
      .single();
    return data?.id;
  },

  async invite(teamId, inviteeId, role, message) {
    const user = await Auth.getUser();
    const { data, error } = await supabase
      .from('team_invites')
      .insert({
        team_id: teamId,
        inviter_id: user.id,
        invitee_id: inviteeId,
        role, message,
      })
      .select()
      .single();
    if (error) throw error;
    return data;
  },

  async leave(teamId) {
    const user = await Auth.getUser();
    const { error } = await supabase
      .from('team_members')
      .update({ left_at: new Date().toISOString() })
      .eq('team_id', teamId)
      .eq('player_id', user.id);
    if (error) throw error;
  },
};

// =============================================================
// MATCHES — матчи
// =============================================================

const Matches = {
  async upcoming(teamId) {
    const { data, error } = await supabase
      .from('matches')
      .select(`
        *,
        team_a:teams!matches_team_a_id_fkey(name, logo_initials, logo_color),
        team_b:teams!matches_team_b_id_fkey(name, logo_initials, logo_color)
      `)
      .or(`team_a_id.eq.${teamId},team_b_id.eq.${teamId}`)
      .in('status', ['scheduled', 'preparing'])
      .order('scheduled_at', { ascending: true });
    if (error) throw error;
    return data;
  },

  async getById(id) {
    const { data, error } = await supabase
      .from('matches')
      .select(`
        *,
        team_a:teams!matches_team_a_id_fkey(*, members:team_members(*, profile:profiles(*))),
        team_b:teams!matches_team_b_id_fkey(*, members:team_members(*, profile:profiles(*))),
        maps:match_maps(*),
        confirmations:match_confirmations(*)
      `)
      .eq('id', id)
      .single();
    if (error) throw error;
    return data;
  },

  async markReady(matchId, teamId) {
    // Логика Ready System — реализуй через edge function
    // или просто отмечай как готового в отдельной таблице match_ready_status
    return showToast('Ready System ✓');
  },

  async confirmResult(matchId, teamId) {
    const user = await Auth.getUser();
    const { error } = await supabase
      .from('match_confirmations')
      .upsert({
        match_id: matchId,
        team_id: teamId,
        captain_id: user.id,
        confirmed: true,
        confirmed_at: new Date().toISOString(),
      });
    if (error) throw error;
  },

  // Real-time подписка на изменения в матче (счёт, статус)
  subscribe(matchId, onChange) {
    return supabase
      .channel(`match-${matchId}`)
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'matches',
        filter: `id=eq.${matchId}`,
      }, onChange)
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'match_maps',
        filter: `match_id=eq.${matchId}`,
      }, onChange)
      .subscribe();
  },
};

// =============================================================
// NOTIFICATIONS — уведомления
// =============================================================

const Notifications = {
  async list() {
    const user = await Auth.getUser();
    if (!user) return [];
    const { data, error } = await supabase
      .from('notifications')
      .select('*')
      .eq('user_id', user.id)
      .order('created_at', { ascending: false })
      .limit(50);
    if (error) throw error;
    return data;
  },

  async unreadCount() {
    const user = await Auth.getUser();
    if (!user) return 0;
    const { count } = await supabase
      .from('notifications')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', user.id)
      .eq('is_read', false);
    return count || 0;
  },

  async markAsRead(id) {
    const { error } = await supabase
      .from('notifications')
      .update({ is_read: true })
      .eq('id', id);
    if (error) throw error;
  },

  async markAllAsRead() {
    const user = await Auth.getUser();
    const { error } = await supabase
      .from('notifications')
      .update({ is_read: true })
      .eq('user_id', user.id)
      .eq('is_read', false);
    if (error) throw error;
  },

  async clear() {
    const user = await Auth.getUser();
    const { error } = await supabase
      .from('notifications')
      .delete()
      .eq('user_id', user.id);
    if (error) throw error;
  },

  // Real-time: новое уведомление приходит сразу
  subscribe(onNew) {
    Auth.getUser().then(user => {
      if (!user) return;
      supabase
        .channel('notifs')
        .on('postgres_changes', {
          event: 'INSERT',
          schema: 'public',
          table: 'notifications',
          filter: `user_id=eq.${user.id}`,
        }, ({ new: notif }) => onNew(notif))
        .subscribe();
    });
  },
};

// =============================================================
// INVITES — приглашения в команду
// =============================================================

const Invites = {
  async list() {
    const user = await Auth.getUser();
    const { data, error } = await supabase
      .from('team_invites')
      .select(`
        *,
        team:teams(*),
        inviter:profiles!team_invites_inviter_id_fkey(nick, handle)
      `)
      .eq('invitee_id', user.id)
      .eq('status', 'pending')
      .order('created_at', { ascending: false });
    if (error) throw error;
    return data;
  },

  async accept(id) {
    const { data: inv } = await supabase.from('team_invites').select('*').eq('id', id).single();
    const user = await Auth.getUser();
    // Меняю статус
    await supabase.from('team_invites').update({
      status: 'accepted',
      responded_at: new Date().toISOString(),
    }).eq('id', id);
    // Добавляю в team_members
    await supabase.from('team_members').insert({
      team_id: inv.team_id,
      player_id: user.id,
      role: inv.role,
    });
  },

  async decline(id) {
    await supabase.from('team_invites').update({
      status: 'declined',
      responded_at: new Date().toISOString(),
    }).eq('id', id);
  },
};

// =============================================================
// NEWS — новости
// =============================================================

const News = {
  async list(category = null, limit = 20) {
    let query = supabase
      .from('news')
      .select('*')
      .order('published_at', { ascending: false })
      .limit(limit);
    if (category) query = query.eq('category', category);
    const { data, error } = await query;
    if (error) throw error;
    return data;
  },

  async getBySlug(slug) {
    const { data, error } = await supabase
      .from('news')
      .select('*')
      .eq('slug', slug)
      .single();
    if (error) throw error;
    // Инкрементируем счётчик прочтений
    await supabase.rpc('increment_news_views', { news_slug: slug });
    return data;
  },

  async featured() {
    const { data, error } = await supabase
      .from('news')
      .select('*')
      .eq('is_featured', true)
      .order('published_at', { ascending: false })
      .limit(1)
      .maybeSingle();
    if (error) throw error;
    return data;
  },

  async search(query, category = null) {
    let q = supabase
      .from('news')
      .select('*')
      .or(`title.ilike.%${query}%,preview.ilike.%${query}%,body.ilike.%${query}%`)
      .order('published_at', { ascending: false });
    if (category) q = q.eq('category', category);
    const { data, error } = await q;
    if (error) throw error;
    return data;
  },
};

// =============================================================
// REPORTS / TICKETS / APPEALS
// =============================================================

const Support = {
  async submitTicket({ topic, description, evidenceUrls = [] }) {
    const user = await Auth.getUser();
    const { error } = await supabase.from('tickets').insert({
      user_id: user.id, topic, description, evidence_urls: evidenceUrls,
    });
    if (error) throw error;
  },

  async submitReport({ targetNick, matchId, categories, description, evidenceUrls = [] }) {
    const user = await Auth.getUser();
    // Опционально ищем target_id по нику
    const { data: target } = await supabase
      .from('profiles').select('id').eq('nick', targetNick).maybeSingle();
    const { error } = await supabase.from('reports').insert({
      reporter_id: user.id,
      target_nick: targetNick,
      target_id: target?.id,
      match_id: matchId,
      categories, description, evidence_urls: evidenceUrls,
    });
    if (error) throw error;
  },

  async submitAppeal({ banType, banDate, description, evidenceUrls = [] }) {
    const user = await Auth.getUser();
    const { error } = await supabase.from('appeals').insert({
      user_id: user.id,
      ban_type: banType,
      ban_date: banDate,
      description, evidence_urls: evidenceUrls,
    });
    if (error) throw error;
  },
};

// =============================================================
// SEASON — текущий сезон
// =============================================================

const Season = {
  async current() {
    const { data, error } = await supabase
      .from('seasons')
      .select('*')
      .eq('is_active', true)
      .single();
    if (error) throw error;
    return data;
  },

  async leaderboard(seasonId, divisionId = 'd1', limit = 50) {
    const { data, error } = await supabase
      .from('teams')
      .select('*')
      .eq('season_id', seasonId)
      .eq('division_id', divisionId)
      .order('points', { ascending: false })
      .limit(limit);
    if (error) throw error;
    return data;
  },
};

// =============================================================
// Привязка к существующим UI-функциям прототипа
// =============================================================
//
// Пример: заменить хардкод состояния на реальные данные.
//
// Было (в прототипе):
//   const userHasTeam = true;
//   let isLoggedIn = true;
//
// Станет:
//   let isLoggedIn = false;
//   let userHasTeam = false;
//   let currentUser = null;
//   let currentTeam = null;
//
//   async function refreshState() {
//     currentUser = await Auth.getProfile();
//     isLoggedIn = !!currentUser;
//     if (isLoggedIn) {
//       const { data } = await supabase
//         .from('team_members')
//         .select('team_id, role, is_captain, teams(*)')
//         .eq('player_id', currentUser.id)
//         .is('left_at', null)
//         .maybeSingle();
//       currentTeam = data?.teams;
//       userHasTeam = !!currentTeam;
//     }
//     applyAuthState();
//     applyTeamState();
//   }
//
//   Auth.onChange(refreshState);
//   refreshState();
//
//   // Подписка на real-time уведомления
//   Notifications.subscribe(notif => {
//     showToast('🔔 ' + notif.title, 'important');
//     Sounds.notif();
//     refreshNotifBadge();
//   });
