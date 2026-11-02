-- No License Ranks - server script
-- Loaded by every player automatically from csp_extra_options.ini. Nothing to install.
--
-- HUD: a small panel at the top middle. Hidden while nothing is happening, pops in when
-- you earn something, stays while you are in a run, fades out when you crash or stop.
-- Never covers the road.

local VERSION = '4.1'

------------------------------------------------------------------ CONFIG (edit these)

-- Where the rank badges live (rank_01.png .. rank_27.png).
local ICON_BASE = 'https://raw.githubusercontent.com/YbwSolo/NL/main/icons/'

-- Where the calling cards live (s_*.png, a_*.png, f_*.png).
local CARD_BASE = 'https://raw.githubusercontent.com/YbwSolo/NL/main/cards/'

-- Zones file for the police / race circles (only used when those are switched on below).
local ZONES_URL = 'https://raw.githubusercontent.com/YbwSolo/NL/main/zones.json'

-- Optional backend for server-side progress (leave '' to keep progress on each player's PC).
local BACKEND = ''

-- Features. true = on, false = off.
local ENABLE_POLICE = false        -- blue circles that start a police chase
local ENABLE_RACE_ZONES = false    -- red circles that start a race lobby
local ENABLE_FLASH_RACE = true     -- stop next to someone, both flash headlights twice = 60 s race
local ENABLE_DAILY = true          -- 3 daily challenges
local ENABLE_NAMEPLATES = true     -- calling card + rank badge + name floating over other players' cars
local ENABLE_WEEKLY = true         -- one big weekly challenge
local ENABLE_LOGIN_STREAK = true   -- xp for playing on consecutive days

-- XP boost hours (local time of each player's PC). 2x xp between 20:00 and 23:59 by default.
local XP_BOOST = { hours = { 20, 21, 22, 23 }, mult = 2 }

-- Key that opens the menu (name from ui.KeyIndex: Home, End, Insert, F9, F10, M, N ...). Players can rebind it in Settings.
local MENU_KEY = 'Home'
local HINT_SECONDS = 30            -- how long the "press HOME" hint stays on the left of the screen after joining

local ENABLE_WANTED = true         -- top run on the server becomes WANTED: 1.5x xp for them, bounty xp for near-missing them
local ENABLE_DRAFT = true          -- xp for sitting in another player's slipstream
local ENABLE_PRESTIGE = true       -- at NO LICENSE: prestige, back to Rookie with a star and +5% xp per star

-- Flash race
local RACE_SECONDS = 60            -- whoever is in front when the clock hits zero wins
local RACE_GET_READY = 10          -- seconds to get in position after both flashed

-- Used only when zones.json cannot be loaded.
local DEFAULT_ZONES = {
  chase = {
    { name = 'Daikoku PA', x = 5830.0, y = 22.2, z = -4628.0, r = 6 },
  },
  race = {},
}

------------------------------------------------------------------ ranks

local NAMES = { 'Rookie', 'Learner', 'Street', 'Runner', 'Cutter', 'Hustler', 'Outlaw', 'Reckless', 'Wanted', 'Most Wanted',
  'Menace', 'Enforcer', 'Kingpin', 'Phantom', 'Reaper', 'Warlord', 'Shogun', 'Overlord', 'Immortal', 'Legend',
  'Icon', 'Untouchable', 'Apex', 'Ghost', 'Sovereign', 'Godspeed', 'NO LICENSE' }

local RANKS = {}
for i, n in ipairs(NAMES) do
  local f = (i - 1) / (#NAMES - 1)
  local col
  if f < 0.15 then col = rgbm(0.72, 0.74, 0.78, 1)
  elseif f < 0.35 then col = rgbm(0.35, 0.72, 1.0, 1)
  elseif f < 0.55 then col = rgbm(0.20, 0.95, 0.55, 1)
  elseif f < 0.72 then col = rgbm(1.0, 0.78, 0.22, 1)
  elseif f < 0.88 then col = rgbm(1.0, 0.35, 0.22, 1)
  elseif i < #NAMES then col = rgbm(0.80, 0.35, 1.0, 1)
  else col = rgbm(0.0, 0.96, 0.38, 1) end
  -- steeper curve than before: rank 27 is ~720,000 xp
  RANKS[i] = { name = n, xp = math.floor(400 * ((i - 1) ^ 2.3)), col = col, icon = string.format('%srank_%02d.png', ICON_BASE, i) }
end

local XP = {
  perKm = 8, fastKm = 6, veryFastKm = 10, cleanKm = 3,
  nearMiss = 20, overtake = 4, streakStep = 0.25, streakWindow = 6.0,
  crashFlat = 100, crashRunPct = 0.30,      -- a crash costs 100 xp plus 30% of the run you were on
  escape = 600, escapePerUnit = 60, busted = -400,
  raceWin = 800, raceSecond = 500, raceThird = 300, raceFinish = 150, raceSolo = 100,
  duelWin = 500, duelLose = 120, duelDraw = 250,
}
local NEAR, PASS, MIN_SPEED, MIN_REL = 2.9, 5.0, 60, 12

-- daily challenges: 3 picked per day from this list
local CHALLENGES = {
  { id = 'nm25', text = '25 near misses', key = 'dayNear', goal = 25, xp = 600 },
  { id = 'nm60', text = '60 near misses', key = 'dayNear', goal = 60, xp = 1500 },
  { id = 'km30', text = 'drive 30 km', key = 'dayKm', goal = 30, xp = 500 },
  { id = 'km100', text = 'drive 100 km', key = 'dayKm', goal = 100, xp = 1500 },
  { id = 'top250', text = 'hit 250 km/h', key = 'dayTop', goal = 250, xp = 400 },
  { id = 'top300', text = 'hit 300 km/h', key = 'dayTop', goal = 300, xp = 1000 },
  { id = 'streak5', text = 'x5 combo', key = 'dayStreak', goal = 5, xp = 500 },
  { id = 'streak10', text = 'x10 combo', key = 'dayStreak', goal = 10, xp = 1500 },
  { id = 'run3k', text = 'a 3,000 point run', key = 'dayRun', goal = 3000, xp = 800 },
  { id = 'run8k', text = 'an 8,000 point run', key = 'dayRun', goal = 8000, xp = 2000 },
  { id = 'clean5', text = '5 km with no contact', key = 'dayClean', goal = 5, xp = 600 },
  { id = 'ot20', text = '20 overtakes', key = 'dayOver', goal = 20, xp = 400 },
  { id = 'duel1', text = 'win a flash race', key = 'dayDuelWins', goal = 1, xp = 800 },
  { id = 'duel3', text = 'win 3 flash races', key = 'dayDuelWins', goal = 3, xp = 2000 },
}

-- weekly challenge: one per week, rotates
local WEEKLY = {
  { text = '300 near misses this week', key = 'weekNear', goal = 300, xp = 5000 },
  { text = '250 km this week', key = 'weekKm', goal = 250, xp = 5000 },
  { text = '10 flash race wins this week', key = 'weekWins', goal = 10, xp = 6000 },
  { text = '600 near misses this week', key = 'weekNear', goal = 600, xp = 9000 },
}

-- lifetime milestones
local MILESTONES = {
  { id = 'km50', text = '50 km driven', key = 'km', goal = 50, xp = 300 },
  { id = 'km250', text = '250 km driven', key = 'km', goal = 250, xp = 1000 },
  { id = 'km1000', text = '1,000 km driven', key = 'km', goal = 1000, xp = 3000 },
  { id = 'km5000', text = '5,000 km driven', key = 'km', goal = 5000, xp = 10000 },
  { id = 'nm100', text = '100 near misses', key = 'nearMisses', goal = 100, xp = 500 },
  { id = 'nm1000', text = '1,000 near misses', key = 'nearMisses', goal = 1000, xp = 3000 },
  { id = 'nm5000', text = '5,000 near misses', key = 'nearMisses', goal = 5000, xp = 10000 },
  { id = 'dw10', text = '10 flash race wins', key = 'duelWins', goal = 10, xp = 2500 },
  { id = 'dw50', text = '50 flash race wins', key = 'duelWins', goal = 50, xp = 8000 },
}

-- calling cards. kind: s = static, a = animated. unlock types: free, rank, km, nm (near misses),
-- wins (flash races), run (best run points), top (km/h), combo, daily (dailies completed), days (login streak).
local CARDS = {
  { id = 's_default', name = 'Volkz', kind = 's', unlock = 'free', goal = 0 },
  { id = 's_bacon', name = 'Static', kind = 's', unlock = 'free', goal = 0 },
  { id = 's_dayofdead', name = 'Squad', kind = 's', unlock = 'free', goal = 0 },
  { id = 's_aqua', name = 'Straw Hat', kind = 's', unlock = 'rank', goal = 3 },
  { id = 's_elite2', name = 'Nebula', kind = 's', unlock = 'rank', goal = 5 },
  { id = 's_dcoyote', name = 'Demon', kind = 's', unlock = 'rank', goal = 8 },
  { id = 's_nuketown_z', name = 'Serpent', kind = 's', unlock = 'rank', goal = 12 },
  { id = 's_snake', name = 'Ink', kind = 's', unlock = 'rank', goal = 15 },
  { id = 's_breach', name = 'Breach', kind = 's', unlock = 'km', goal = 50 },
  { id = 's_elite1', name = 'Midnight GT', kind = 's', unlock = 'km', goal = 250 },
  { id = 's_seasonpass', name = 'Data Breach', kind = 's', unlock = 'km', goal = 1000 },
  { id = 's_ben', name = 'Red Blade', kind = 's', unlock = 'nm', goal = 100 },
  { id = 's_mil', name = 'Pink Fade', kind = 's', unlock = 'nm', goal = 250 },
  { id = 's_nuketown_2025', name = 'Cyan Edge', kind = 's', unlock = 'wins', goal = 1 },
  { id = 's_roxann_soldier', name = 'Silver Blade', kind = 's', unlock = 'wins', goal = 5 },
  { id = 's_massacre', name = 'Sunset Ridge', kind = 's', unlock = 'run', goal = 3000 },
  { id = 's_partyrock', name = 'Dark Bloom', kind = 's', unlock = 'run', goal = 8000 },
  { id = 's_ghost', name = 'Red Lambo', kind = 's', unlock = 'top', goal = 280 },
  { id = 's_dragonfire', name = 'Hellfire', kind = 's', unlock = 'combo', goal = 8 },
  { id = 's_pap', name = 'Hypno', kind = 's', unlock = 'combo', goal = 12 },
  { id = 's_graf', name = 'Blossom', kind = 's', unlock = 'daily', goal = 3 },
  { id = 's_zombies', name = 'Slayer', kind = 's', unlock = 'daily', goal = 10 },
  { id = 's_kawaii', name = 'Old Master', kind = 's', unlock = 'days', goal = 3 },
  { id = 's_zulu', name = 'Sakura', kind = 's', unlock = 'days', goal = 7 },
  { id = 'a_afterlife', name = 'Afterlife', kind = 'a', frames = 32, fps = 20, unlock = 'rank', goal = 10 },
  { id = 'a_fire', name = 'Inferno', kind = 'a', frames = 32, fps = 20, unlock = 'nm', goal = 500 },
  { id = 'a_gameover', name = 'Game Over', kind = 'a', frames = 32, fps = 20, unlock = 'wins', goal = 10 },
  { id = 'a_goku', name = 'Ultra', kind = 'a', frames = 32, fps = 20, unlock = 'rank', goal = 18 },
  { id = 'a_kakashi', name = 'Sharingan', kind = 'a', frames = 32, fps = 8, unlock = 'run', goal = 15000 },
  { id = 'a_kaneki', name = 'Ghoul', kind = 'a', frames = 32, fps = 12.0, unlock = 'nm', goal = 1000 },
  { id = 'a_panda', name = 'Mad Panda', kind = 'a', frames = 32, fps = 20, unlock = 'days', goal = 14 },
  { id = 'a_magicball', name = 'Arcane', kind = 'a', frames = 32, fps = 20, unlock = 'combo', goal = 15 },
  { id = 'a_storm', name = 'Storm', kind = 'a', frames = 16, fps = 18.2, unlock = 'top', goal = 300 },
  { id = 'a_sunset', name = 'Horizon', kind = 'a', frames = 32, fps = 20, unlock = 'km', goal = 2500 },
  { id = 'a_tornado', name = 'Tornado', kind = 'a', frames = 32, fps = 20, unlock = 'wins', goal = 25 },
  { id = 'a_orb', name = 'Core', kind = 'a', frames = 32, fps = 20, unlock = 'rank', goal = 22 },
  { id = 'a_trippy', name = 'Trippy', kind = 'a', frames = 32, fps = 20, unlock = 'rank', goal = 27 },
  { id = 'a_v1_starlight', name = 'Starlight', kind = 'a', frames = 32, fps = 16, unlock = 'combo', goal = 10 },
  { id = 'a_v1_assassin', name = 'Assassin', kind = 'a', frames = 32, fps = 16, unlock = 'nm', goal = 2500 },
  { id = 'a_v1_vortex', name = 'Vortex', kind = 'a', frames = 32, fps = 16, unlock = 'daily', goal = 20 },
  { id = 'a_v1_pulse', name = 'Pulse', kind = 'a', frames = 32, fps = 16, unlock = 'top', goal = 320 },
  { id = 'a_v1_ascend', name = 'Ascend', kind = 'a', frames = 32, fps = 16, unlock = 'combo', goal = 20 },
  { id = 'a_v1_nightfall', name = 'Nightfall', kind = 'a', frames = 32, fps = 16, unlock = 'wins', goal = 50 },
  { id = 'a_v1_blade', name = 'Blade', kind = 'a', frames = 32, fps = 16, unlock = 'days', goal = 30 },
  { id = 'a_og_undead', name = 'Undead', kind = 'a', frames = 30, fps = 16, unlock = 'rank', goal = 2 },
  { id = 'a_og_anarchy', name = 'Anarchy', kind = 'a', frames = 20, fps = 10, unlock = 'rank', goal = 4 },
  { id = 'a_og_beast', name = 'Beast', kind = 'a', frames = 30, fps = 16, unlock = 'rank', goal = 6 },
  { id = 'a_og_circuit', name = 'Circuit', kind = 'a', frames = 12, fps = 10, unlock = 'rank', goal = 7 },
  { id = 'a_og_soldier', name = 'Soldier', kind = 'a', frames = 32, fps = 16, unlock = 'rank', goal = 9 },
  { id = 'a_og_deadhand', name = 'Dead Hand', kind = 'a', frames = 20, fps = 10, unlock = 'rank', goal = 11 },
  { id = 'a_og_dragoneye', name = 'Dragon Eye', kind = 'a', frames = 26, fps = 12, unlock = 'rank', goal = 13 },
  { id = 'a_og_chequered', name = 'Chequered', kind = 'a', frames = 20, fps = 10, unlock = 'rank', goal = 14 },
  { id = 'a_og_paladin', name = 'Paladin', kind = 'a', frames = 24, fps = 12, unlock = 'rank', goal = 16 },
  { id = 'a_og_outbreak', name = 'Outbreak', kind = 'a', frames = 20, fps = 10, unlock = 'rank', goal = 20 },
}
local CARD_INDEX = {}
for i, c in ipairs(CARDS) do CARD_INDEX[c.id] = i end

------------------------------------------------------------------ storage

local store = ac.storage {
  xp = 0, km = 0, nearMisses = 0, overtakes = 0, crashes = 0, topSpeed = 0, bestStreak = 0, bestRun = 0,
  escapes = 0, busts = 0, races = 0, raceWins = 0, duels = 0, duelWins = 0, hudScale = 1.0, alwaysShow = false,
  localZones = '', useLocalZones = false, zoneR = 6, zoneName = '',
  dailyKey = '', dailyDone = '', dayNear = 0, dayKm = 0, dayTop = 0, dayStreak = 0, dayRun = 0, dayClean = 0, dayOver = 0, dayDuelWins = 0,
  milestonesDone = '',
  tag = '', card = 's_default', showOthersCards = true, nameplateScale = 1.0, unlockedCards = '', newCards = '', cardsInit = false,
  loginStreak = 0, lastLoginKey = '', dailyCount = 0, bestCombo = 0,
  weekKey = '', weekNear = 0, weekKm = 0, weekWins = 0, weeklyDone = false,
  prestige = 0, menuKey = '',
}

------------------------------------------------------------------ zones (remote json, or placed in game)

local ZONES = { chase = {}, race = {} }
local zonesSource = 'built-in'

local function normZone(z, isRace)
  local o = { name = tostring(z.name or ''), x = tonumber(z.x) or 0, y = tonumber(z.y) or 0, z = tonumber(z.z) or 0, r = tonumber(z.r) or 6 }
  if isRace then
    o.fx, o.fy, o.fz = tonumber(z.fx) or o.x, tonumber(z.fy) or o.y, tonumber(z.fz) or o.z
    o.finishR = tonumber(z.finishR) or 10
    o.finishName = tostring(z.finishName or 'finish')
  end
  return o
end

local function applyZones(tbl, source)
  if type(tbl) ~= 'table' then return false end
  local c, r = {}, {}
  for _, z in ipairs(tbl.chase or {}) do c[#c + 1] = normZone(z, false) end
  for _, z in ipairs(tbl.race or {}) do r[#r + 1] = normZone(z, true) end
  ZONES.chase, ZONES.race = c, r
  zonesSource = source
  return true
end

local function zonesJSON()
  local function num(v) return string.format('%.1f', v) end
  local out = { '{', '  "chase": [' }
  for i, z in ipairs(ZONES.chase) do
    out[#out + 1] = string.format('    { "name": "%s", "x": %s, "y": %s, "z": %s, "r": %s }%s', z.name, num(z.x), num(z.y), num(z.z), num(z.r), i < #ZONES.chase and ',' or '')
  end
  out[#out + 1] = '  ],'
  out[#out + 1] = '  "race": ['
  for i, z in ipairs(ZONES.race) do
    out[#out + 1] = string.format('    { "name": "%s", "x": %s, "y": %s, "z": %s, "r": %s, "fx": %s, "fy": %s, "fz": %s, "finishR": %s, "finishName": "%s" }%s',
      z.name, num(z.x), num(z.y), num(z.z), num(z.r), num(z.fx), num(z.fy), num(z.fz), num(z.finishR), z.finishName, i < #ZONES.race and ',' or '')
  end
  out[#out + 1] = '  ]'
  out[#out + 1] = '}'
  return table.concat(out, '\n')
end

local function saveLocalZones()
  store.localZones = zonesJSON()
  store.useLocalZones = true
  zonesSource = 'placed in game'
end

local function loadLocalZones()
  if store.localZones == '' then return false end
  local ok, data = pcall(function() return JSON.parse(store.localZones) end)
  return ok and applyZones(data, 'placed in game')
end

local function loadRemoteZones()
  pcall(function()
    web.get(ZONES_URL, function(err, response)
      if err or not response or response.status ~= 200 then return end
      local ok, data = pcall(function() return JSON.parse(response.body) end)
      if ok and not (store.useLocalZones and store.localZones ~= '') then applyZones(data, 'zones.json') end
    end)
  end)
end

applyZones(DEFAULT_ZONES, 'built-in')
if store.useLocalZones then loadLocalZones() end

local steamID = ''
pcall(function() steamID = tostring(ac.getUserSteamID() or '') end)

local backendOK = false
local function backendLoad()
  if BACKEND == '' or steamID == '' then return end
  pcall(function()
    web.get(BACKEND .. '/get?id=' .. steamID, function(err, response)
      if err or not response or response.status ~= 200 then return end
      local ok, data = pcall(function() return JSON.parse(response.body) end)
      if ok and type(data) == 'table' and type(data.xp) == 'number' then
        if data.xp > store.xp then store.xp = data.xp end
        for _, k in ipairs({ 'km', 'nearMisses', 'overtakes', 'crashes', 'topSpeed', 'bestStreak', 'bestRun', 'escapes', 'busts', 'races', 'raceWins' }) do
          if type(data[k]) == 'number' and data[k] > store[k] then store[k] = data[k] end
        end
        backendOK = true
      end
    end)
  end)
end

local function backendSave()
  if BACKEND == '' or steamID == '' then return end
  local name = ''
  pcall(function() name = ac.getDriverName(0) or '' end)
  local payload = JSON.stringify({ id = steamID, name = name, xp = store.xp, km = store.km, nearMisses = store.nearMisses, overtakes = store.overtakes,
    crashes = store.crashes, topSpeed = store.topSpeed, bestStreak = store.bestStreak, bestRun = store.bestRun, escapes = store.escapes, busts = store.busts, races = store.races, raceWins = store.raceWins })
  pcall(function() web.post(BACKEND .. '/set', { ['Content-Type'] = 'application/json' }, payload, function() end) end)
end

------------------------------------------------------------------ state

local t = 0
local session = { xp = 0, km = 0, nearMisses = 0 }
local streak, streakTimer = 0, 0
local lastCrash = -10
local cleanDist = 0
local cleanRun = 0
local prev = {}
local lastPos = nil
local rankIndex = 1
local speedMult = 1
local run = { score = 0, active = false, stopTimer = 0, lost = false, lostTimer = 0, time = 0, pb = false, lostAmount = 0 }
local lastClose = 0
local hud = { alpha = 0, lastEvent = -10, events = {} }
local levelAnim = { t = -1, rank = 1 }
local banner = { text = '', sub = '', col = rgbm(1, 1, 1, 1), t = -1, life = 3 }
local others = {}
local lastErr = nil
local sessionBest = 0          -- my best run this session (for the server leaderboard)
local sessionTop = 0           -- my top speed this session
local leaderIndex = -1
local wantedIndex = -1         -- car index of the WANTED player (-1 none, 0 me)
local onFire = false
local draft = { timer = 0, bank = 0, tick = 0 }
local menu = { open = false, close = false, hintT = 0 }
local menuButton = nil
local broadcastRank            -- defined in the sync section

local GOLD = rgbm(1, 0.8, 0.2, 1)
local GREEN = rgbm(0, 0.96, 0.38, 1)
local RED = rgbm(1, 0.25, 0.22, 1)
local COL_POLICE = rgbm(0.25, 0.55, 1.0, 1)
local COL_RACE = rgbm(1.0, 0.22, 0.22, 1)
local function withA(c, a) return rgbm(c.r, c.g, c.b, (c.mult or 1) * a) end

local function dlog(s) ac.log('nl_ranks: ' .. s) end

local function driverName(i)
  local o = others[i]
  if o and o.tag and o.tag ~= '' then return o.tag end
  local n = nil
  pcall(function() n = ac.getDriverName(i) end)
  return n or ('car ' .. i)
end

local function rankFor(xp)
  local r = 1
  for i, R in ipairs(RANKS) do if xp >= R.xp then r = i end end
  return r
end

-- an "event" is what makes the HUD show up
local function event(text, col, big)
  hud.lastEvent = t
  hud.events[#hud.events + 1] = { text = text, col = col or rgbm(1, 1, 1, 1), t = 0, big = big == true }
  if #hud.events > 4 then table.remove(hud.events, 1) end
end

local function showBanner(text, sub, col, life)
  banner = { text = text, sub = sub or '', col = col or rgbm(1, 1, 1, 1), t = 0, life = life or 3 }
  hud.lastEvent = t
end

local function fmt(n)
  n = math.floor(n)
  local s = tostring(n):reverse():gsub('(%d%d%d)', '%1,'):reverse()
  if s:sub(1, 1) == ',' then s = s:sub(2) end
  return s
end

local function boostActive()
  local h = nil
  pcall(function() h = tonumber(os.date('%H')) end)
  if not h then return false end
  for _, bh in ipairs(XP_BOOST.hours) do if bh == h then return true end end
  return false
end

local saveTimer = 0
-- ranks are never lost: xp cannot drop under the rank you already reached
local function addXP(n, why, colour, noRun)
  if n == 0 then return end
  if n > 0 and boostActive() then n = n * XP_BOOST.mult end
  if n > 0 and store.prestige > 0 then n = n * (1 + 0.05 * store.prestige) end
  if n > 0 and not noRun and ENABLE_WANTED and wantedIndex == 0 then n = n * 1.5 end
  n = math.floor(n + 0.5)
  local before = rankFor(store.xp)
  if n < 0 then
    local floor = RANKS[before].xp
    n = math.max(n, floor - store.xp)
    if n == 0 then
      if why then event(why, colour) end
      return 0
    end
  end
  store.xp = store.xp + n
  session.xp = session.xp + n
  if n > 0 and not noRun then
    run.score = run.score + n
    run.active = true
    run.lost = false
    if run.score > store.bestRun and run.score > 400 and not run.pb then
      run.pb = true
      event('NEW PERSONAL BEST', GOLD, true)
    end
  end
  if why then event((n > 0 and '+' or '') .. fmt(n) .. '  ' .. why, colour) end
  local after = rankFor(store.xp)
  if after > before then
    rankIndex = after
    levelAnim = { t = 0, rank = after }
    backendSave()
    dlog('rank up -> ' .. RANKS[after].name)
  end
  return n
end

local function endRun(crashed)
  if run.score > store.bestRun then store.bestRun = run.score end
  if run.score > store.dayRun then store.dayRun = run.score end
  if run.score > sessionBest then
    sessionBest = run.score
    local top = 0
    for _, o in pairs(others) do if o.best and o.best > top then top = o.best end end
    if top > 0 and sessionBest > top and leaderIndex ~= 0 then
      leaderIndex = 0
      event('BEST RUN ON THE SERVER', GOLD, true)
    end
    broadcastRank()
  end
  if crashed and run.score > 0 then
    run.lost = true
    run.lostTimer = 1.8
    hud.lastEvent = t
  end
  run.score = 0
  run.active = false
  run.time = 0
  run.pb = false
end

------------------------------------------------------------------ sync

local rankEvent = nil
local chaseActive = false

local function myTag()
  if store.tag ~= '' then return store.tag end
  local n = nil
  pcall(function() n = ac.getDriverName(0) end)
  return n or 'driver'
end

pcall(function()
  rankEvent = ac.OnlineEvent({
    ac.StructItem.key('NLRanksSrv4'),
    rank = ac.StructItem.byte(),
    xp = ac.StructItem.int32(),
    chase = ac.StructItem.byte(),
    card = ac.StructItem.int16(),
    best = ac.StructItem.int32(),
    tag = ac.StructItem.string(16),
    fire = ac.StructItem.byte(),
    prestige = ac.StructItem.byte(),
    top = ac.StructItem.int16(),
  }, function(sender, data)
    if sender == nil or sender.index == 0 then return end
    local old = others[sender.index]
    local rank = math.max(1, math.min(#RANKS, data.rank))
    local tag = tostring(data.tag or '')
    if tag == '' then tag = driverName(sender.index) end
    others[sender.index] = { rank = rank, xp = data.xp, chase = data.chase == 1, card = data.card, best = data.best, tag = tag, seen = t,
      fire = data.fire == 1, prestige = data.prestige or 0, top = data.top or 0 }
    if old then
      if rank > old.rank and old.rank > 0 then event(tag .. ' ranked up to ' .. RANKS[rank].name:upper(), RANKS[rank].col, true) end
      if (data.prestige or 0) > (old.prestige or 0) then event(tag .. ' PRESTIGED', GOLD, true) end
      if data.fire == 1 and not old.fire then event(tag .. ' is ON FIRE', rgbm(1, 0.5, 0.1, 1), true) end
    end
  end)
end)

broadcastRank = function()
  if not rankEvent then return end
  pcall(function()
    rankEvent({ rank = rankIndex, xp = math.floor(store.xp), chase = chaseActive and 1 or 0,
      card = CARD_INDEX[store.card] or 1, best = math.floor(sessionBest), tag = myTag():sub(1, 15),
      fire = onFire and 1 or 0, prestige = store.prestige, top = math.floor(sessionTop) }, true)
  end)
end

------------------------------------------------------------------ helpers

local function inZone(z, pos, r)
  local dx, dz = pos.x - z.x, pos.z - z.z
  r = r or z.r
  return dx * dx + dz * dz <= r * r and math.abs(pos.y - z.y) < 12
end

local function flatDist(a, b)
  local dx, dz = a.x - b.x, a.z - b.z
  return math.sqrt(dx * dx + dz * dz)
end


------------------------------------------------------------------ daily challenges + milestones

local daily = { list = {}, key = '' }

local function hasFlag(str, id) return str:find('|' .. id .. '|', 1, true) ~= nil end
local function addFlag(str, id) if str == '' then str = '|' end return str .. id .. '|' end

local function dailyKeyNow()
  local k = nil
  pcall(function() k = os.date('%Y-%m-%d') end)
  return k or 'day'
end

local function dayNumber(key)
  local y, m, d = key:match('(%d+)-(%d+)-(%d+)')
  if not y then return 1 end
  return tonumber(y) * 372 + tonumber(m) * 31 + tonumber(d)
end

local function dailyRefresh()
  if not ENABLE_DAILY then return end
  local key = dailyKeyNow()
  if key ~= store.dailyKey then
    store.dailyKey = key
    store.dailyDone = ''
    store.dayNear, store.dayKm, store.dayTop, store.dayStreak, store.dayRun, store.dayClean, store.dayOver, store.dayDuelWins = 0, 0, 0, 0, 0, 0, 0, 0
  end
  if daily.key ~= key then
    daily.key = key
    daily.list = {}
    local n = #CHALLENGES
    local seed = dayNumber(key)
    local picked = {}
    local i = 0
    while #daily.list < 3 and i < 40 do
      local idx = ((seed * 7 + i * 11 + 3) % n) + 1
      if not picked[idx] then picked[idx] = true; daily.list[#daily.list + 1] = CHALLENGES[idx] end
      i = i + 1
    end
  end
end

local function dailyProgress(c)
  return math.min(c.goal, store[c.key] or 0)
end

local function dailyCheck()
  if not ENABLE_DAILY then return end
  for _, c in ipairs(daily.list) do
    if not hasFlag(store.dailyDone, c.id) and (store[c.key] or 0) >= c.goal then
      store.dailyDone = addFlag(store.dailyDone, c.id)
      store.dailyCount = store.dailyCount + 1
      showBanner('CHALLENGE DONE', c.text .. '   +' .. fmt(c.xp) .. ' xp', GOLD, 4)
      addXP(c.xp, 'daily: ' .. c.text, GOLD, true)
    end
  end
end

local function milestoneCheck()
  for _, m in ipairs(MILESTONES) do
    if not hasFlag(store.milestonesDone, m.id) and (store[m.key] or 0) >= m.goal then
      store.milestonesDone = addFlag(store.milestonesDone, m.id)
      showBanner('MILESTONE', m.text .. '   +' .. fmt(m.xp) .. ' xp', GOLD, 4)
      addXP(m.xp, 'milestone: ' .. m.text, GOLD, true)
    end
  end
end

------------------------------------------------------------------ flash race (stop next to someone, both flash twice)

local duel = { state = 'idle', opp = -1, timer = 0, time = 0, toast = nil, result = nil, oppResult = nil, start = nil, falseStart = false }
local flash = { edges = {}, lastHigh = false, lastHead = false, sentAt = -10, sentTo = -1, incoming = {} }
local duelEvent = nil

-- car indices differ from player to player, session IDs do not
local function sessionOf(i)
  local id = 255
  pcall(function() local c = ac.getCar(i); if c then id = c.sessionID end end)
  return id
end

local function duelSend(kind, oppIndex, value)
  if not duelEvent then return end
  pcall(function() duelEvent({ kind = kind, target = sessionOf(oppIndex), value = value or 0 }, false) end)
end

local function duelReset()
  if duel.toast then pcall(function() duel.toast = nil end) end
  duel = { state = 'idle', opp = -1, timer = 0, time = 0, toast = nil, result = nil, oppResult = nil, start = nil, falseStart = false }
end

local function duelCancel(byMe, quiet)
  if duel.state == 'idle' then return end
  if byMe then duelSend(3, duel.opp, 0) end
  if not quiet then showBanner('RACE CANCELLED', byMe and '' or (driverName(duel.opp) .. ' backed out'), rgbm(0.7, 0.72, 0.78, 1), 2.5) end
  duelReset()
end

local function duelStart(opp)
  if duel.state ~= 'idle' then return end
  duel.state = 'ready'
  duel.opp = opp
  duel.timer = RACE_GET_READY
  flash.incoming[opp] = nil
  store.duels = store.duels + 1
  showBanner('RACE', 'vs ' .. driverName(opp) .. '   get in position', COL_RACE, 3)
  hud.lastEvent = t
  pcall(function()
    local icn = ui.Icons and (ui.Icons.Warning or ui.Icons.LoadingSpinner) or 'fx:loading'
    duel.toast = ui.toast(icn, 'Race vs ' .. driverName(opp) .. ' starting. Click to cancel.', function() duelCancel(true) end)
  end)
end

local function duelFinish(mine, theirs)
  -- 1 = I was in front, -1 = they were, 0 = level
  local outcome = mine
  if theirs ~= nil and theirs == mine and mine ~= 0 then outcome = 0 end      -- both think they won: call it level
  if theirs ~= nil and theirs ~= 0 and mine == 0 then outcome = -theirs end
  local oppName = driverName(duel.opp)
  if outcome == 1 then
    store.duelWins = store.duelWins + 1
    store.dayDuelWins = store.dayDuelWins + 1
    store.weekWins = store.weekWins + 1
    showBanner('YOU WON', 'ahead of ' .. oppName .. ' at the line   +' .. XP.duelWin .. ' xp', GOLD, 4)
    addXP(XP.duelWin, 'won the race', GOLD)
  elseif outcome == -1 then
    showBanner('YOU LOST', oppName .. ' was ahead   +' .. XP.duelLose .. ' xp', rgbm(0.7, 0.72, 0.78, 1), 4)
    addXP(XP.duelLose, 'raced', rgbm(0.7, 0.72, 0.78, 1))
  else
    showBanner('DEAD HEAT', 'level with ' .. oppName .. '   +' .. XP.duelDraw .. ' xp', GOLD, 4)
    addXP(XP.duelDraw, 'raced', GOLD)
  end
  duelReset()
end

pcall(function()
  duelEvent = ac.OnlineEvent({
    ac.StructItem.key('NLFlashRace3'),
    kind = ac.StructItem.byte(), target = ac.StructItem.byte(), value = ac.StructItem.float(),
  }, function(sender, data)
    if sender == nil or sender.index == 0 or not ENABLE_FLASH_RACE then return end
    local idx = sender.index
    if data.target ~= sessionOf(0) then return end   -- not for me
    if data.kind == 1 then                        -- they flashed at me
      if duel.state == 'idle' then
        if flash.sentTo == idx and t - flash.sentAt < 8 then
          duelSend(2, idx, 0)
          duelStart(idx)
        else
          flash.incoming[idx] = t
          event(driverName(idx) .. ' wants a race   flash twice to accept', COL_RACE, true)
          hud.lastEvent = t
        end
      end
    elseif data.kind == 2 then                    -- they accepted my flash
      if duel.state == 'idle' and flash.sentTo == idx then duelStart(idx) end
    elseif data.kind == 3 then                    -- they cancelled
      if duel.state ~= 'idle' and duel.opp == idx then duelCancel(false) end
    elseif data.kind == 4 then                    -- their verdict at the line
      if duel.state == 'racing' and duel.opp == idx then duel.oppResult = data.value end
    elseif data.kind == 5 then                    -- they crashed out
      if duel.state == 'racing' and duel.opp == idx then
        duel.result = 1
        duelFinish(1, -1)
      end
    end
  end)
end)

-- a flash = high beams coming on (or lights toggled). two within 2 s = a double flash.
local function detectFlash(me)
  local high, head = false, false
  pcall(function() high = me.highBeams == true; head = me.headlightsActive == true end)
  local edge = (high and not flash.lastHigh) or (head and not flash.lastHead)
  flash.lastHigh, flash.lastHead = high, head
  if not edge then return false end
  flash.edges[#flash.edges + 1] = t
  while #flash.edges > 0 and t - flash.edges[1] > 2.0 do table.remove(flash.edges, 1) end
  if #flash.edges >= 2 then
    flash.edges = {}
    return true
  end
  return false
end

local function carBesideMe(me)
  local sim = ac.getSim()
  local best, bestD = nil, 1e9
  for i = 1, sim.carsCount - 1 do
    local c = ac.getCar(i)
    if c and c.isConnected and c.speedKmh < 8 then
      local rel = c.position - me.position
      local lon, lat = math.abs(rel:dot(me.look)), math.abs(rel:dot(me.side))
      if lon < 9 and lat < 7 and math.abs(rel.y) < 4 then
        local d = lon + lat
        if d < bestD then best, bestD = i, d end
      end
    end
  end
  return best
end

local function duelUpdate(dt, me)
  if not ENABLE_FLASH_RACE then return end
  local speed = me.speedKmh
  if duel.state == 'idle' then
    if speed < 8 and detectFlash(me) then
      local opp = carBesideMe(me)
      if opp then
        if flash.incoming[opp] and t - flash.incoming[opp] < 12 then
          duelSend(2, opp, 0)
          duelStart(opp)
        else
          flash.sentAt, flash.sentTo = t, opp
          duelSend(1, opp, 0)
          event('race offered to ' .. driverName(opp) .. '   waiting for their flash', COL_RACE, true)
        end
      end
    end
    return
  end
  hud.lastEvent = t
  local opp = ac.getCar(duel.opp)
  if not opp or not opp.isConnected then duelCancel(false, true); return end
  pcall(function() if ui.keyboardButtonPressed(ui.KeyIndex.Back) then duelCancel(true) end end)
  if duel.state == 'idle' then return end
  if duel.state == 'ready' then
    duel.timer = duel.timer - dt
    if duel.timer <= 0 then
      duel.state = 'count'
      duel.timer = 3
      duel.toast = nil
      duel.falseStart = false
    end
  elseif duel.state == 'count' then
    duel.timer = duel.timer - dt
    if speed > 5 and not duel.falseStart then
      duel.falseStart = true
      event('FALSE START', RED, true)
    end
    if duel.timer <= 0 then
      duel.state = 'racing'
      duel.time = 0
      duel.result, duel.oppResult = nil, nil
      showBanner('GO', RACE_SECONDS .. ' seconds. be in front when it ends', GREEN, 2)
    end
  elseif duel.state == 'racing' then
    duel.time = duel.time + dt
    if duel.time >= RACE_SECONDS and duel.result == nil then
      -- shared direction so both cars judge it the same way
      local L = me.look + opp.look
      if L:length() < 0.01 then L = me.look end
      L = L:normalize()
      local ahead = (me.position - opp.position):dot(L)
      if duel.falseStart then ahead = ahead - 15 end
      local mine = ahead > 2 and 1 or (ahead < -2 and -1 or 0)
      duel.result = mine
      duelSend(4, duel.opp, mine)
      duel.timer = 2.0
    elseif duel.result ~= nil then
      duel.timer = duel.timer - dt
      if duel.oppResult ~= nil or duel.timer <= 0 then duelFinish(duel.result, duel.oppResult) end
    end
  end
end

local function duelCrash()
  if duel.state == 'racing' and duel.result == nil then
    duelSend(5, duel.opp, 0)
    showBanner('YOU LOST', 'crashed during the race', RED, 3)
    addXP(XP.duelLose, 'raced', rgbm(0.7, 0.72, 0.78, 1))
    duelReset()
  elseif duel.state == 'ready' or duel.state == 'count' then
    duelCancel(true)
  end
end

------------------------------------------------------------------ calling cards, login streak, weekly

local function cardSrc(c) return CARD_BASE .. c.id .. '.png' end

local function cardUV(c)
  if c.kind ~= 'a' or not c.frames or c.frames < 2 then return nil, nil end
  local f = math.floor(t * (c.fps or 12)) % c.frames
  return vec2(0, f / c.frames), vec2(1, (f + 1) / c.frames)
end

local function cardUnlocked(c)
  return c.unlock == 'free' or hasFlag(store.unlockedCards, c.id)
end

local function cardMet(c)
  local u, g = c.unlock, c.goal
  if u == 'free' then return true
  elseif u == 'rank' then return rankIndex >= g
  elseif u == 'km' then return store.km >= g
  elseif u == 'nm' then return store.nearMisses >= g
  elseif u == 'wins' then return store.duelWins >= g
  elseif u == 'run' then return store.bestRun >= g
  elseif u == 'top' then return store.topSpeed >= g
  elseif u == 'combo' then return store.bestStreak >= g
  elseif u == 'daily' then return store.dailyCount >= g
  elseif u == 'days' then return store.loginStreak >= g end
  return false
end

local function cardLockText(c)
  local u, g = c.unlock, c.goal
  if u == 'rank' then return 'reach ' .. RANKS[math.min(#RANKS, g)].name
  elseif u == 'km' then return fmt(g) .. ' km driven'
  elseif u == 'nm' then return fmt(g) .. ' near misses'
  elseif u == 'wins' then return g .. ' flash race win' .. (g > 1 and 's' or '')
  elseif u == 'run' then return fmt(g) .. ' point run'
  elseif u == 'top' then return g .. ' km/h'
  elseif u == 'combo' then return 'x' .. g .. ' combo'
  elseif u == 'daily' then return g .. ' daily challenges done'
  elseif u == 'days' then return g .. ' day login streak' end
  return ''
end

local function cardProgress(c)
  local u, g = c.unlock, c.goal
  local v = 0
  if u == 'rank' then v = rankIndex elseif u == 'km' then v = store.km elseif u == 'nm' then v = store.nearMisses
  elseif u == 'wins' then v = store.duelWins elseif u == 'run' then v = store.bestRun elseif u == 'top' then v = store.topSpeed
  elseif u == 'combo' then v = store.bestStreak elseif u == 'daily' then v = store.dailyCount elseif u == 'days' then v = store.loginStreak end
  if g <= 0 then return 1 end
  return math.max(0, math.min(1, v / g))
end

local function cardCheck(quiet)
  for _, c in ipairs(CARDS) do
    if c.unlock ~= 'free' and not hasFlag(store.unlockedCards, c.id) and cardMet(c) then
      store.unlockedCards = addFlag(store.unlockedCards, c.id)
      if not quiet then
        store.newCards = addFlag(store.newCards, c.id)
        showBanner('CARD UNLOCKED', c.name .. (c.kind == 'a' and '   (animated)' or ''), GOLD, 4)
        event('new calling card: ' .. c.name, GOLD)
      end
    end
  end
end

local function myCard()
  return CARDS[CARD_INDEX[store.card] or CARD_INDEX['s_default']] or CARDS[1]
end

local function selectCard(c)
  store.card = c.id
  if hasFlag(store.newCards, c.id) then store.newCards = store.newCards:gsub('|' .. c.id .. '|', '|', 1) end
  broadcastRank()
end

local function countNewCards()
  local n = 0
  for _ in store.newCards:gmatch('|[^|]+') do n = n + 1 end
  return n
end

-- login streak
local function loginCheck()
  if not ENABLE_LOGIN_STREAK then return end
  local today, yesterday = dailyKeyNow(), nil
  pcall(function() yesterday = os.date('%Y-%m-%d', os.time() - 86400) end)
  if store.lastLoginKey == today then return end
  if store.lastLoginKey == yesterday then store.loginStreak = store.loginStreak + 1 else store.loginStreak = 1 end
  store.lastLoginKey = today
  local bonus = math.min(1000, store.loginStreak * 100)
  showBanner('DAY ' .. store.loginStreak .. ' STREAK', 'welcome back   +' .. fmt(bonus) .. ' xp', GOLD, 5)
  addXP(bonus, 'login streak', GOLD, true)
end

-- weekly
local weekly = { item = nil, key = '' }
local function weeklyRefresh()
  if not ENABLE_WEEKLY then return end
  local key = nil
  pcall(function() key = os.date('%Y-%W') end)
  key = key or 'week'
  if store.weekKey ~= key then
    store.weekKey = key
    store.weekNear, store.weekKm, store.weekWins, store.weeklyDone = 0, 0, 0, false
  end
  if weekly.key ~= key then
    weekly.key = key
    local y, w = key:match('(%d+)-(%d+)')
    local n = (tonumber(y) or 0) * 53 + (tonumber(w) or 0)
    weekly.item = WEEKLY[(n % #WEEKLY) + 1]
  end
end

local function weeklyCheck()
  if not ENABLE_WEEKLY or not weekly.item or store.weeklyDone then return end
  local c = weekly.item
  if (store[c.key] or 0) >= c.goal then
    store.weeklyDone = true
    showBanner('WEEKLY DONE', c.text .. '   +' .. fmt(c.xp) .. ' xp', GOLD, 5)
    addXP(c.xp, 'weekly: ' .. c.text, GOLD, true)
  end
end

-- first join: pick the name that shows over your car
local namePromptShown = false
local function askName()
  if namePromptShown or store.tag ~= '' then return end
  namePromptShown = true
  local def = ''
  pcall(function() def = ac.getDriverName(0) or '' end)
  local ok = pcall(function()
    ui.modalPrompt('Welcome to No License', 'Pick the name that shows over your car. You can change it later in the No License Ranks menu.', def, 'Set name', 'Later', nil, nil, function(value)
      if value and tostring(value) ~= '' then
        store.tag = tostring(value):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 15)
        broadcastRank()
      end
    end)
  end)
  if not ok then dlog('name prompt unavailable') end
end

------------------------------------------------------------------ police chase

local chase = { state = 'idle', zone = nil, countdown = 0, time = 0, units = {}, trail = {}, trailTimer = 0, bustTimer = -1, farTimer = 0, lastSpawnT = 0 }
local POLICE_MODEL = 'nolicense_volkswagen_golf_r_mk8/nolicense_volkswagen_golf_r_mk8.kn5'
local copModelOK = nil

local function makeUnit(pos, delay)
  local u = { delay = delay, pos = vec3(pos.x, pos.y, pos.z), look = vec3(0, 0, 1), lights = {}, node = nil, flash = math.random() * 10 }
  if copModelOK ~= false then
    local ok, err = pcall(function()
      local path = ac.getFolder(ac.FolderID.ContentCars) .. '/' .. POLICE_MODEL
      if not io.fileExists(path) then error('police model missing') end
      u.node = ac.findNodes('dynamicRoot:yes'):loadKN5(path)
      if not u.node or u.node:size() == 0 then error('model empty') end
      copModelOK = true
      pcall(function() u.node:findMeshes('{ material:ext_Body_Paint }'):setMaterialProperty('ksDiffuse', rgb(0.95, 0.95, 0.95)):setMaterialProperty('ksAmbient', rgb(0.9, 0.9, 0.9)) end)
    end)
    if not ok then
      copModelOK = false
      u.node = nil
      dlog('police model unavailable, lights only (' .. tostring(err) .. ')')
    end
  end
  for i = 1, 2 do
    local ok, l = pcall(function() return ac.LightSource(ac.LightType.Regular) end)
    if ok and l then
      pcall(function()
        l.range = 14; l.rangeGradientOffset = 0.1; l.fadeAt = 400; l.fadeSmooth = 60; l.specularMultiplier = 0.4
        l.color = i == 1 and rgb(0.1, 0.3, 3) or rgb(3, 0.1, 0.1)
      end)
      u.lights[#u.lights + 1] = l
    end
  end
  return u
end

local function disposeUnit(u)
  for _, l in ipairs(u.lights) do pcall(function() l:dispose() end) end
  if u.node then pcall(function() u.node:dispose() end) end
end

local function chaseReset()
  for _, u in ipairs(chase.units) do disposeUnit(u) end
  chase = { state = 'idle', zone = nil, countdown = 0, time = 0, units = {}, trail = {}, trailTimer = 0, bustTimer = -1, farTimer = 0, lastSpawnT = 0 }
  chaseActive = false
  broadcastRank()
end

local function spawnUnit(me, extra)
  local n = #chase.units
  if n >= 5 then return end
  local behind = me.position - me.look * (35 + n * 12) - me.side * ((n % 2 == 0) and 1.5 or -1.5)
  local u = makeUnit(behind, 3.0 + n * 1.2 + (extra or 0))
  u.look = vec3(me.look.x, me.look.y, me.look.z)
  chase.units[#chase.units + 1] = u
end

local function trailPointAt(ago)
  local tr = chase.trail
  if #tr == 0 then return nil end
  local target = t - ago
  for i = #tr, 1, -1 do
    if tr[i].t <= target then
      local a, b = tr[i], tr[i + 1]
      if b then
        local f = (target - a.t) / math.max(0.001, b.t - a.t)
        return a.p + (b.p - a.p) * f
      end
      return a.p
    end
  end
  return tr[1].p
end

local function chaseUpdate(dt, me)
  if not ENABLE_POLICE then return end
  local speed = me.speedKmh
  if chase.state == 'idle' then
    for _, z in ipairs(ZONES.chase) do
      if inZone(z, me.position) and speed > 15 then
        chase.state = 'countdown'
        chase.zone = z
        chase.countdown = 3.0
        chase.time = 0
        showBanner('POLICE', 'get moving. they are on you in 3', rgbm(0.3, 0.5, 1, 1), 3)
        dlog('chase countdown at ' .. (z.name or 'zone'))
        break
      end
    end
    return
  end
  if chase.state == 'countdown' then
    chase.countdown = chase.countdown - dt
    if chase.countdown <= 0 then
      chase.state = 'active'
      chaseActive = true
      broadcastRank()
      spawnUnit(me)
      spawnUnit(me, 1.5)
      showBanner('CHASE ON', 'lose them. crashing brings more units', rgbm(0.3, 0.5, 1, 1), 2.5)
    end
    return
  end
  chase.time = chase.time + dt
  hud.lastEvent = t
  chase.trailTimer = chase.trailTimer + dt
  if chase.trailTimer > 0.1 then
    chase.trailTimer = 0
    chase.trail[#chase.trail + 1] = { t = t, p = vec3(me.position.x, me.position.y, me.position.z) }
    if #chase.trail > 900 then table.remove(chase.trail, 1) end
  end
  local nearest = 1e9
  for i, u in ipairs(chase.units) do
    if speed > 170 then u.delay = u.delay + dt * 0.18
    elseif speed > 120 then u.delay = u.delay + dt * 0.03
    elseif speed > 70 then u.delay = math.max(0.9, u.delay - dt * 0.12)
    else u.delay = math.max(0.5, u.delay - dt * 0.35) end
    u.delay = math.min(u.delay, 25)
    local target = trailPointAt(u.delay + 0.3 * (i - 1))
    if target then
      local d = target - u.pos
      local dist = d:length()
      if dist > 0.05 then
        local step = math.min(dist, (speed / 3.6 + 12) * dt * 1.4)
        u.pos = u.pos + d * (step / dist)
        local dl = vec3(d.x, 0, d.z)
        if dl:length() > 0.2 then u.look = dl:normalize() end
      end
    end
    u.flash = u.flash + dt * 9
    local blue = math.floor(u.flash) % 2 == 0
    for li, l in ipairs(u.lights) do
      local on = (li == 1) == blue
      l.position = u.pos + vec3(0, 1.55, 0) + u.look * 0.2 + vec3(-u.look.z, 0, u.look.x) * (li == 1 and 0.45 or -0.45)
      l.color = (li == 1 and rgb(0.1, 0.3, 3) or rgb(3, 0.1, 0.1)) * (on and 1 or 0.08)
    end
    if u.node then pcall(function() u.node:setPosition(u.pos); u.node:setOrientation(u.look, vec3(0, 1, 0)) end) end
    nearest = math.min(nearest, flatDist(u.pos, me.position))
  end
  chase.nearest = nearest
  if nearest > 260 then chase.farTimer = chase.farTimer + dt else chase.farTimer = 0 end
  if chase.farTimer > 5 or chase.time > 300 then
    local bonus = XP.escape + XP.escapePerUnit * #chase.units + math.max(0, 120 - chase.time)
    store.escapes = store.escapes + 1
    showBanner('ESCAPED', 'lost ' .. #chase.units .. ' units   +' .. math.floor(bonus) .. ' xp', rgbm(0, 0.96, 0.38, 1), 4)
    addXP(bonus, 'escaped the police', rgbm(0, 0.96, 0.38, 1))
    chaseReset()
    return
  end
  if chase.bustTimer >= 0 then
    chase.bustTimer = chase.bustTimer - dt
    if chase.bustTimer <= 0 then
      chase.bustTimer = -1
      if nearest < 45 then
        store.busts = store.busts + 1
        showBanner('BUSTED', 'they had you   ' .. XP.busted .. ' xp', rgbm(1, 0.3, 0.25, 1), 4)
        addXP(XP.busted, 'busted', rgbm(1, 0.3, 0.25, 1), true)
        endRun(true)
        chaseReset()
      else
        event('got away from that one', rgbm(0.6, 0.8, 1, 1))
      end
    end
  end
end

local function chaseCrash(me)
  if chase.state ~= 'active' then return end
  if t - chase.lastSpawnT > 4 then
    chase.lastSpawnT = t
    spawnUnit(me, 2.5)
    event('another unit joined', rgbm(0.4, 0.6, 1, 1))
  end
  if chase.bustTimer < 0 then
    chase.bustTimer = 10
    showBanner('GET AWAY', '10 seconds to put distance on them', rgbm(1, 0.6, 0.2, 1), 2.5)
  end
end

------------------------------------------------------------------ race

local race = { state = 'idle', zone = nil, host = -1, countdown = 0, time = 0, joined = {}, finishers = {}, myFinish = nil, inZoneTimer = 0, lobbyTick = 0 }
local raceEvent = nil
pcall(function()
  raceEvent = ac.OnlineEvent({
    ac.StructItem.key('NLRaceSrv3'),
    kind = ac.StructItem.byte(), zone = ac.StructItem.byte(), value = ac.StructItem.float(),
  }, function(sender, data)
    if sender == nil or not ENABLE_RACE_ZONES then return end
    local idx = sender.index
    if data.kind == 1 and idx ~= 0 then
      if race.state == 'idle' or (race.state == 'lobby' and race.host ~= 0) then
        race.state = 'lobby'; race.host = idx; race.zone = ZONES.race[data.zone] or race.zone; race.countdown = data.value; race.joined[idx] = true
        hud.lastEvent = t
      end
    elseif data.kind == 2 then race.joined[idx] = true
    elseif data.kind == 3 and idx ~= 0 then if race.state == 'lobby' then race.countdown = 0 end
    elseif data.kind == 4 then race.finishers[#race.finishers + 1] = { index = idx, time = data.value } end
  end)
end)

local function raceSend(kind, zoneIdx, value)
  if not raceEvent then return end
  pcall(function() raceEvent({ kind = kind, zone = zoneIdx or 0, value = value or 0 }, false) end)
end

local function raceZoneIndex(z)
  for i, zz in ipairs(ZONES.race) do if zz == z then return i end end
  return 0
end

local function raceUpdate(dt, me)
  if not ENABLE_RACE_ZONES or #ZONES.race == 0 then return end
  if race.state == 'idle' then
    for _, z in ipairs(ZONES.race) do
      if inZone(z, me.position) then
        race.inZoneTimer = race.inZoneTimer + dt
        if race.inZoneTimer > 1 then
          race.state = 'lobby'; race.host = 0; race.zone = z; race.countdown = 20; race.joined = { [0] = true }; race.lobbyTick = 0
          raceSend(1, raceZoneIndex(z), race.countdown)
          showBanner('RACE LOBBY', 'stay in the circle. starts in 20', rgbm(1, 0.8, 0.2, 1), 3)
        end
        return
      end
    end
    race.inZoneTimer = 0
    return
  end
  hud.lastEvent = t
  if race.state == 'lobby' then
    race.countdown = race.countdown - dt
    local inside = inZone(race.zone, me.position)
    if inside and not race.joined[0] then race.joined[0] = true; raceSend(2, raceZoneIndex(race.zone), 0) end
    if race.host == 0 then
      race.lobbyTick = race.lobbyTick + dt
      if race.lobbyTick > 2 then race.lobbyTick = 0; raceSend(1, raceZoneIndex(race.zone), race.countdown) end
    end
    if race.countdown <= 0 then
      if race.host == 0 then raceSend(3, raceZoneIndex(race.zone), 0) end
      if inside or race.joined[0] then
        race.state = 'racing'; race.time = 0; race.finishers = {}; race.myFinish = nil
        showBanner('GO', 'first to ' .. (race.zone.finishName or 'the finish'), rgbm(0, 0.96, 0.38, 1), 2)
      else
        race.state = 'idle'; race.joined = {}
      end
    end
  elseif race.state == 'racing' then
    race.time = race.time + dt
    if not race.myFinish and inZone({ x = race.zone.fx, y = race.zone.fy, z = race.zone.fz }, me.position, race.zone.finishR or 25) then
      race.myFinish = race.time
      raceSend(4, raceZoneIndex(race.zone), race.time)
      race.finishers[#race.finishers + 1] = { index = 0, time = race.time }
      table.sort(race.finishers, function(a, b) return a.time < b.time end)
      local place = 1
      for i, f in ipairs(race.finishers) do if f.index == 0 then place = i end end
      local n = 0
      for _ in pairs(race.joined) do n = n + 1 end
      local reward = (n <= 1) and XP.raceSolo or (place == 1 and XP.raceWin or (place == 2 and XP.raceSecond or (place == 3 and XP.raceThird or XP.raceFinish)))
      store.races = store.races + 1
      if place == 1 and n > 1 then store.raceWins = store.raceWins + 1 end
      showBanner(n <= 1 and 'FINISHED' or ('P' .. place), string.format('%.1f s   +%d xp', race.time, reward), place == 1 and rgbm(1, 0.8, 0.2, 1) or rgbm(0.8, 0.85, 0.9, 1), 4)
      addXP(reward, 'race', rgbm(1, 0.8, 0.2, 1))
      race.state = 'finished'; race.countdown = 8
    elseif race.time > 600 then
      race.state = 'idle'; race.joined = {}
    end
  elseif race.state == 'finished' then
    race.countdown = race.countdown - dt
    if race.countdown <= 0 then race.state = 'idle'; race.joined = {}; race.finishers = {} end
  end
end

------------------------------------------------------------------ driving

local checkTimer = 0
local function update(dt)
  t = t + dt
  local me = ac.getCar(0)
  if not me then return end
  local speed = me.speedKmh
  speedMult = math.max(1, math.min(10, 1 + math.floor((speed - 105) / 15)))

  local p = me.position
  if lastPos then
    local d = p:distance(lastPos)
    if d < 50 and speed > 5 then
      local km = d / 1000
      store.km = store.km + km
      store.dayKm = store.dayKm + km
      store.weekKm = store.weekKm + km
      session.km = session.km + km
      cleanDist = cleanDist + km
      cleanRun = cleanRun + km
      if cleanRun > store.dayClean then store.dayClean = cleanRun end
      local gain = km * XP.perKm
      if speed > 220 then gain = gain + km * (XP.fastKm + XP.veryFastKm) elseif speed > 150 then gain = gain + km * XP.fastKm end
      addXP(gain * speedMult)
      if cleanDist >= 1 then
        cleanDist = cleanDist - 1
        addXP(XP.cleanKm * speedMult, 'clean km', rgbm(0.6, 1, 0.7, 1))
      end
    end
  end
  lastPos = vec3(p.x, p.y, p.z)
  if speed > store.topSpeed then store.topSpeed = speed end
  if speed > store.dayTop then store.dayTop = speed end
  if speed > sessionTop + 5 then
    local others_top = 0
    for _, o in pairs(others) do if o.top and o.top > others_top then others_top = o.top end end
    local was = sessionTop
    sessionTop = speed
    if others_top > 0 and was <= others_top and speed > others_top then event('FASTEST ON THE SERVER  ' .. math.floor(speed) .. ' km/h', GOLD, true) end
  end

  -- run ends quietly when you stop
  if speed < 8 then
    run.stopTimer = run.stopTimer + dt
    if run.stopTimer > 3 and run.active then endRun(false) end
  else
    run.stopTimer = 0
  end
  -- in a flow: fast and clean keeps the HUD up
  if run.active then run.time = run.time + dt end
  if run.active and speed > 60 then hud.lastEvent = t end
  lastClose = math.max(0, lastClose - dt * 0.35)

  local depth = me.collisionDepth or 0
  if depth > 0 and t - lastCrash > 1.5 then
    lastCrash = t
    store.crashes = store.crashes + 1
    streak = 0
    cleanDist = 0
    cleanRun = 0
    local loss = XP.crashFlat + run.score * XP.crashRunPct
    endRun(true)
    run.lostAmount = -(addXP(-loss, 'CRASHED', RED, true) or 0)
    chaseCrash(me)
    duelCrash()
  end

  if streak > 0 then
    streakTimer = streakTimer - dt
    if streakTimer <= 0 then streak = 0 end
  end
  if onFire and streak < 10 then onFire = false; broadcastRank() end

  -- slipstream: sit close behind another player at speed
  if ENABLE_DRAFT then
    local drafting = false
    if speed > 120 then
      local sim2 = ac.getSim()
      for i = 1, sim2.carsCount - 1 do
        local c = ac.getCar(i)
        if c and c.isConnected and c.speedKmh > 100 then
          local rel = c.position - p
          local lon, lat = rel:dot(me.look), rel:dot(me.side)
          if lon > 3 and lon < 18 and math.abs(lat) < 2.2 then drafting = true; break end
        end
      end
    end
    if drafting then
      draft.timer = draft.timer + dt
      if draft.timer > 2 then
        draft.bank = draft.bank + dt * 4 * speedMult
        draft.tick = draft.tick + dt
        if draft.tick > 2 then draft.tick = 0; addXP(draft.bank, 'DRAFTING', rgbm(0.6, 0.85, 1, 1)); draft.bank = 0 end
      end
    else
      draft.timer, draft.bank, draft.tick = 0, 0, 0
    end
  end

  if speed >= MIN_SPEED then
    local sim = ac.getSim()
    local look, side = me.look, me.side
    for i = 1, sim.carsCount - 1 do
      local c = ac.getCar(i)
      if c and c.isConnected then
        local rel = c.position - p
        local lon = rel:dot(look)
        local lat = rel:dot(side)
        local pr = prev[i]
        if math.abs(lon) < 40 and math.abs(lat) < 12 then
          if pr and ((pr.lon > 0 and lon <= 0) or (pr.lon < 0 and lon >= 0)) and t - pr.t < 1.0 then
            local relSpeed = (me.velocity - c.velocity):length() * 3.6
            local alat = math.min(math.abs(lat), math.abs(pr.lat))
            if relSpeed > MIN_REL and t - lastCrash > 1.5 then
              if alat < NEAR then
                streak = streak + 1
                streakTimer = XP.streakWindow
                if streak > store.bestStreak then store.bestStreak = streak end
                if streak > store.dayStreak then store.dayStreak = streak end
                store.nearMisses = store.nearMisses + 1
                store.dayNear = store.dayNear + 1
                store.weekNear = store.weekNear + 1
                session.nearMisses = session.nearMisses + 1
                local close = (NEAR - alat) / NEAR
                lastClose = math.max(lastClose, close)
                local mult = math.min(3, 1 + XP.streakStep * (streak - 1))
                local pts = (XP.nearMiss + close * 40 + speed / 10) * mult * (1 + (speedMult - 1) * 0.15)
                local label = close > 0.65 and 'INSANE NEAR MISS' or (close > 0.35 and 'CLOSE NEAR MISS' or 'NEAR MISS')
                if streak > 1 then label = label .. '  x' .. streak end
                addXP(pts, label, close > 0.65 and rgbm(1, 0.85, 0.2, 1) or rgbm(0, 0.94, 0.35, 1))
                if ENABLE_WANTED and i == wantedIndex then addXP(150, 'BOUNTY HIT  ' .. driverName(i), GOLD) end
                if streak >= 10 and not onFire then onFire = true; showBanner('ON FIRE', 'x' .. streak .. ' combo', rgbm(1, 0.5, 0.1, 1), 2.5); broadcastRank() end
              elseif alat < PASS then
                store.overtakes = store.overtakes + 1
                store.dayOver = store.dayOver + 1
                addXP(XP.overtake, 'OVERTAKE', rgbm(0.7, 0.9, 1, 1))
              end
            end
          end
          prev[i] = { lon = lon, lat = lat, t = t }
        else
          prev[i] = nil
        end
      else
        prev[i] = nil
      end
    end
  end

  chaseUpdate(dt, me)
  raceUpdate(dt, me)
  duelUpdate(dt, me)

  checkTimer = checkTimer + dt
  if checkTimer > 1 then
    checkTimer = 0
    dailyRefresh()
    dailyCheck()
    weeklyRefresh()
    weeklyCheck()
    milestoneCheck()
    cardCheck(false)
    if ENABLE_WANTED then
      local best, who, n = 0, -1, 1
      for idx, o in pairs(others) do
        local c = ac.getCar(idx)
        if c and c.isConnected then n = n + 1; if o.best and o.best > best then best, who = o.best, idx end end
      end
      if sessionBest > best then best, who = sessionBest, 0 end
      if n < 2 or best < 500 then who = -1 end
      if who ~= wantedIndex then
        wantedIndex = who
        if who == 0 then showBanner('YOU ARE WANTED', '1.5x xp while you hold the top run. everyone gets a bounty for near missing you', RED, 4)
        elseif who > 0 then event(driverName(who) .. ' is WANTED   +150 per near miss on them', RED, true) end
      end
    end
  end

  for i = #hud.events, 1, -1 do
    hud.events[i].t = hud.events[i].t + dt
    if hud.events[i].t > 2.4 then table.remove(hud.events, i) end
  end
  if run.lost then
    run.lostTimer = run.lostTimer - dt
    if run.lostTimer <= 0 then run.lost = false end
  end
  if levelAnim.t >= 0 then
    levelAnim.t = levelAnim.t + dt
    if levelAnim.t > 3 then levelAnim.t = -1 end
    hud.lastEvent = t
  end
  if banner.t >= 0 then
    banner.t = banner.t + dt
    if banner.t > banner.life then banner.t = -1 end
  end

  -- HUD visibility: show while something happened in the last 2.5 s (or a run is going)
  local want = (store.alwaysShow or t - hud.lastEvent < 2.5 or run.lost) and 1 or 0
  if want > hud.alpha then hud.alpha = math.min(1, hud.alpha + dt * 5) else hud.alpha = math.max(0, hud.alpha - dt * 1.4) end

  saveTimer = saveTimer + dt
  if saveTimer > 60 then saveTimer = 0; backendSave() end
end

local started, startTimer, syncTimer = false, 1.0, 0

function script.update(dt)
  if not started then
    startTimer = startTimer - dt
    if startTimer <= 0 then
      started = true
      rankIndex = rankFor(store.xp)
      backendLoad()
      if ENABLE_POLICE or ENABLE_RACE_ZONES then loadRemoteZones() end
      dailyRefresh()
      weeklyRefresh()
      if not store.cardsInit then cardCheck(true); store.cardsInit = true else cardCheck(true) end
      loginCheck()
      askName()
      menu.hintT = HINT_SECONDS
      if ENABLE_DAILY and #daily.list > 0 then
        local parts = {}
        for _, c in ipairs(daily.list) do parts[#parts + 1] = c.text .. (hasFlag(store.dailyDone, c.id) and ' (done)' or '') end
        showBanner('TODAY\'S CHALLENGES', table.concat(parts, '   |   '), GOLD, 8)
      end
      broadcastRank()
      dlog('v' .. VERSION .. ' started, ' .. RANKS[rankIndex].name .. ' ' .. math.floor(store.xp) .. ' xp')
    end
    return
  end
  local ok, err = pcall(update, dt)
  if not ok and lastErr ~= tostring(err) then lastErr = tostring(err); dlog('error: ' .. lastErr) end
  syncTimer = syncTimer + dt
  if syncTimer > 30 then syncTimer = 0; broadcastRank() end
end

------------------------------------------------------------------ 3D rings (blue = police, red = race)


function script.draw3D()
  if not started or not (ENABLE_POLICE or ENABLE_RACE_ZONES) then return end
  local me = ac.getCar(0)
  if not me then return end
  local function ring(cx, cy, cz, r, col, pulse)
    local segs, prevp = 40, nil
    local a1 = withA(col, 0.9 * pulse)
    local a2 = withA(col, 0.35 * pulse)
    for i = 0, segs do
      local a = i / segs * math.pi * 2
      local pnt = vec3(cx + math.cos(a) * r, cy + 0.1, cz + math.sin(a) * r)
      if prevp then
        render.debugLine(prevp, pnt, a1)
        render.debugLine(prevp + vec3(0, 0.5, 0), pnt + vec3(0, 0.5, 0), a2)
      end
      if i % 5 == 0 then render.debugLine(pnt, pnt + vec3(0, 1.2, 0), a2) end
      prevp = pnt
    end
  end
  local function label(x, y, z, txt, col)
    pcall(function() render.debugText(vec3(x, y + 1.6, z), txt, col, 1.2, render.FontAlign.Center) end)
  end
  local pulse = 0.7 + 0.3 * math.sin(t * 3)
  for _, z in ipairs(ENABLE_POLICE and ZONES.chase or {}) do
    if flatDist(me.position, z) < 500 then
      ring(z.x, z.y, z.z, z.r, COL_POLICE, pulse)
      label(z.x, z.y, z.z, 'POLICE', COL_POLICE)
    end
  end
  for _, z in ipairs(ENABLE_RACE_ZONES and ZONES.race or {}) do
    if flatDist(me.position, z) < 500 then
      ring(z.x, z.y, z.z, z.r, COL_RACE, pulse)
      label(z.x, z.y, z.z, 'RACE', COL_RACE)
    end
    if race.state == 'racing' or race.state == 'finished' or (store.useLocalZones and flatDist(me.position, { x = z.fx, z = z.fz }) < 500) then
      ring(z.fx, z.fy, z.fz, z.finishR, rgbm(1, 1, 1, 1), 1)
      label(z.fx, z.fy, z.fz, 'FINISH', rgbm(1, 1, 1, 1))
    end
  end
end

------------------------------------------------------------------ HUD

local F_BOLD = 'Bahnschrift;Weight=Bold'
local F_MED = 'Bahnschrift;Weight=SemiBold'

local function fmtK(n)
  n = math.floor(n)
  if n >= 100000 then return string.format('%dK', math.floor(n / 1000)) end
  if n >= 1000 then return string.format('%.1fK', n / 1000) end
  return tostring(n)
end

local function text(txt, size, pos, col, font)
  ui.pushDWriteFont(font or F_MED)
  ui.dwriteDrawText(txt, size, pos, col)
  ui.popDWriteFont()
end

local function textW(txt, size, font)
  ui.pushDWriteFont(font or F_MED)
  local w = ui.measureDWriteText(txt, size)
  ui.popDWriteFont()
  return w
end

local function textC(txt, size, cx, y, col, font)
  local w = textW(txt, size, font)
  text(txt, size, vec2(cx - w.x / 2, y), col, font)
  return w
end

local function easeOutBack(x)
  local c1, c3 = 1.70158, 2.70158
  return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

local function mix(a, b, f) return rgbm(a.r + (b.r - a.r) * f, a.g + (b.g - a.g) * f, a.b + (b.b - a.b) * f, a.mult + (b.mult - a.mult) * f) end

-- small dark tile with a grey label and a white value
local function tile(x, y, w, h, A, value, label, valCol, s, outline)
  ui.drawRectFilled(vec2(x, y), vec2(x + w, y + h), rgbm(0.04, 0.045, 0.055, 0.82 * A), 5 * s)
  if outline then ui.drawRect(vec2(x, y), vec2(x + w, y + h), withA(outline, 0.9 * A), 5 * s, ui.CornerFlags.All, 1.5 * s) end
  if label then
    textC(value, 15 * s, x + w / 2, y + 5 * s, valCol or rgbm(1, 1, 1, A), F_BOLD)
    textC(label, 8 * s, x + w / 2, y + 24 * s, rgbm(0.58, 0.6, 0.66, A))
  else
    textC(value, 17 * s, x + w / 2, y + (h - 20 * s) / 2, valCol or rgbm(1, 1, 1, A), F_BOLD)
  end
end

local function drawCardImage(c, p1, p2, col)
  if not c then return end
  local uv1, uv2 = cardUV(c)
  if uv1 then ui.drawImage(cardSrc(c), p1, p2, col, uv1, uv2) else ui.drawImage(cardSrc(c), p1, p2, col) end
end

-- the plate: card as the background, badge on the left, name + rank over it. k = scale, a = alpha
local function drawNameplate(cx, cy, k, a, name, R, card, isTop, prestige, wanted, fire)
  local W, H = 150 * k, 37.5 * k
  local x, y = cx - W / 2, cy - H - 10 * k
  if card then
    drawCardImage(card, vec2(x, y), vec2(x + W, y + H), rgbm(1, 1, 1, a))
  else
    ui.drawRectFilled(vec2(x, y), vec2(x + W, y + H), rgbm(0.06, 0.07, 0.09, 0.85 * a), 3 * k)
  end
  -- darken the left side so the text reads on any card
  local ok = pcall(function()
    ui.drawRectFilledMultiColor(vec2(x, y), vec2(x + W * 0.75, y + H), rgbm(0, 0, 0, 0.72 * a), rgbm(0, 0, 0, 0, 0), rgbm(0, 0, 0, 0), rgbm(0, 0, 0, 0.72 * a))
  end)
  if not ok then ui.drawRectFilled(vec2(x, y), vec2(x + W * 0.6, y + H), rgbm(0, 0, 0, 0.5 * a)) end
  ui.drawRect(vec2(x, y), vec2(x + W, y + H), withA(R.col, 0.9 * a), 3 * k, ui.CornerFlags.All, 1.2 * k)
  local ic = 26 * k
  local bx, by = x + 5 * k, y + (H - ic) / 2
  ui.drawCircleFilled(vec2(bx + ic / 2, by + ic / 2), ic * 0.58, rgbm(0, 0, 0, 0.45 * a), 20)
  ui.drawImage(R.icon, vec2(bx, by), vec2(bx + ic, by + ic), rgbm(1, 1, 1, a))
  local tx = bx + ic + 6 * k
  local nameSize = 11 * k
  text(name, nameSize, vec2(tx + 1, y + 6 * k + 1), rgbm(0, 0, 0, 0.8 * a), F_BOLD)
  text(name, nameSize, vec2(tx, y + 6 * k), rgbm(1, 1, 1, a), F_BOLD)
  local rn = R.name:upper()
  if prestige and prestige > 0 then rn = rn .. '   ' .. string.rep('*', math.min(5, prestige)) .. (prestige > 5 and (' ' .. prestige) or '') end
  text(rn, 7 * k, vec2(tx, y + 21 * k), withA(R.col, a), F_BOLD)
  local tag, tcol = nil, GOLD
  if wanted then tag, tcol = 'WANTED', RED elseif fire then tag, tcol = 'ON FIRE', rgbm(1, 0.5, 0.1, 1) elseif isTop then tag = 'TOP RUN' end
  if tag then
    local tw2 = textW(tag, 7 * k, F_BOLD).x
    ui.drawRectFilled(vec2(cx - tw2 / 2 - 5 * k, y - 13 * k), vec2(cx + tw2 / 2 + 5 * k, y - 2 * k), withA(tcol, 0.9 * a), 2 * k)
    text(tag, 7 * k, vec2(cx - tw2 / 2, y - 12 * k), wanted and rgbm(1, 1, 1, a) or rgbm(0.05, 0.05, 0.05, a), F_BOLD)
  end
end

function script.drawUI(dt)
  if not started then return end
  local sim = ac.getSim()
  local sw, sh = sim.windowWidth, sim.windowHeight
  local s = store.hudScale
  local cx = sw / 2
  local A = hud.alpha

  if A > 0.01 then
    local R = RANKS[rankIndex]
    local nxt = RANKS[rankIndex + 1]
    local prog = nxt and (store.xp - R.xp) / (nxt.xp - R.xp) or 1
    prog = math.max(0, math.min(1, prog))

    local gap = 4 * s
    local tw, th = 84 * s, 38 * s        -- small tiles
    local mw = 62 * s                    -- multiplier / timer tiles
    local W = tw * 4 + gap * 4 + mw
    local x0 = cx - W / 2
    local y0 = sh * 0.03 + (1 - A) * -10 * s

    -- row 1: proximity, speed, combo, pb, total multiplier
    local streakMult = math.min(3, 1 + XP.streakStep * math.max(0, streak - 1))
    local proxMult = 1 + lastClose * 2
    local total = speedMult * streakMult
    local sc = speedMult >= 8 and RED or (speedMult >= 5 and rgbm(1, 0.8, 0.2, A) or (speedMult >= 2 and withA(GREEN, A) or rgbm(1, 1, 1, A)))
    local cc = streak >= 5 and rgbm(1, 0.8, 0.2, A) or (streak >= 2 and withA(GREEN, A) or rgbm(1, 1, 1, A))
    tile(x0, y0, tw, th, A, string.format('%.1fX', proxMult), 'PROXIMITY', lastClose > 0.5 and rgbm(1, 0.8, 0.2, A) or nil, s)
    tile(x0 + (tw + gap), y0, tw, th, A, string.format('%.1fX', speedMult), 'SPEED', withA(sc, A), s)
    tile(x0 + (tw + gap) * 2, y0, tw, th, A, 'x' .. streak, 'COMBO', cc, s)
    tile(x0 + (tw + gap) * 3, y0, tw, th, A, fmtK(store.bestRun), 'PB', nil, s)
    tile(x0 + (tw + gap) * 4, y0, mw, th, A, string.format('%.1fX', total), nil, total >= 10 and rgbm(1, 0.8, 0.2, A) or rgbm(1, 1, 1, A), s, R.col)

    -- row 2: main tile in rank colour (crash = red, rank up = flash), run timer on the right
    local y1 = y0 + th + gap
    local mh = 44 * s
    local mainW = tw * 4 + gap * 3
    local fill, textCol = R.col, rgbm(0.03, 0.03, 0.04, 1)
    local word = R.name:upper()
    local sub = nil
    local la = levelAnim.t
    if run.lost then
      fill, textCol, word = RED, rgbm(1, 1, 1, 1), 'CRASHED'
      if run.lostAmount > 0 then sub = '-' .. fmt(run.lostAmount) .. ' XP' end
    elseif la >= 0 then
      local flash = la < 0.25 and 1 or math.max(0, 1 - (la - 0.25) * 2)
      fill = mix(RANKS[levelAnim.rank].col, rgbm(1, 1, 1, 1), flash)
      if la < 1.3 then word = 'RANK UP' end
    elseif run.active and run.score > 0 then
      word = fmt(run.score) .. ' PTS'
      sub = run.pb and 'NEW PB' or R.name:upper()
    end
    ui.drawRectFilled(vec2(x0, y1), vec2(x0 + mainW, y1 + mh), withA(fill, 0.95 * A), 5 * s)
    -- xp bar along the bottom edge of the main tile
    ui.drawRectFilled(vec2(x0 + 6 * s, y1 + mh - 5 * s), vec2(x0 + mainW - 6 * s, y1 + mh - 2.5 * s), rgbm(0, 0, 0, 0.28 * A), 1 * s)
    ui.drawRectFilled(vec2(x0 + 6 * s, y1 + mh - 5 * s), vec2(x0 + 6 * s + (mainW - 12 * s) * prog, y1 + mh - 2.5 * s), withA(textCol, 0.8 * A), 1 * s)
    -- badge
    local ic = 32 * s
    local pop = 1
    if la >= 0 and la < 0.8 then pop = 1 + 0.5 * (easeOutBack(la / 0.8) - (la / 0.8)) + 0.25 * (1 - la / 0.8) end
    local bix, biy = x0 + 8 * s + ic / 2, y1 + mh / 2 - 1.5 * s
    local bi = ic * pop
    ui.drawCircleFilled(vec2(bix, biy), bi * 0.6, rgbm(0, 0, 0, 0.22 * A), 24)
    ui.drawImage(R.icon, vec2(bix - bi / 2, biy - bi / 2), vec2(bix + bi / 2, biy + bi / 2), rgbm(1, 1, 1, A))
    -- level on the right
    local lvl = 'LVL ' .. rankIndex
    local lw = textW(lvl, 9 * s, F_BOLD)
    text(lvl, 9 * s, vec2(x0 + mainW - lw.x - 9 * s, y1 + 6 * s), withA(textCol, 0.75 * A), F_BOLD)
    local xt = nxt and (fmtK(store.xp) .. ' / ' .. fmtK(nxt.xp)) or 'MAX'
    local xw = textW(xt, 8 * s)
    text(xt, 8 * s, vec2(x0 + mainW - xw.x - 9 * s, y1 + 18 * s), withA(textCol, 0.6 * A))
    -- word
    if sub then
      textC(word, 17 * s, x0 + mainW / 2, y1 + 5 * s, withA(textCol, A), F_BOLD)
      textC(sub, 8 * s, x0 + mainW / 2, y1 + 25 * s, (run.pb and not run.lost) and withA(GOLD, A) or withA(textCol, 0.7 * A), F_BOLD)
    else
      textC(word, 20 * s, x0 + mainW / 2, y1 + 8 * s, withA(textCol, A), F_BOLD)
    end
    -- run timer tile
    local rt = run.active and run.time or 0
    local tt = string.format('%02d:%02d', math.floor(rt / 60), math.floor(rt % 60))
    tile(x0 + mainW + gap, y1, mw, mh, A, tt, nil, run.lost and withA(RED, A) or rgbm(1, 1, 1, A), s)

    -- rank-up rings around the badge (small, never covers the road)
    if la >= 0 and la < 1.6 then
      for i = 1, 2 do
        local rr = la - i * 0.15
        if rr > 0 and rr < 1.1 then ui.drawCircle(vec2(bix, biy), (18 + rr * 110) * s, withA(RANKS[levelAnim.rank].col, (1 - rr / 1.1) * 0.8 * A), 48, 2 * s) end
      end
      for i = 1, 14 do
        local ang = i / 14 * math.pi * 2
        local sp = (la - 0.1) * 120 * s
        if sp > 0 then ui.drawCircleFilled(vec2(bix + math.cos(ang) * sp, biy + math.sin(ang) * sp), 2.2 * s, withA(RANKS[levelAnim.rank].col, (1 - math.min(1, (la - 0.1) / 1.4)) * A), 6) end
      end
    end

    if ENABLE_WANTED and wantedIndex == 0 then
      local wt = 'WANTED  1.5X'
      local ww = textW(wt, 9 * s, F_BOLD).x
      ui.drawRectFilled(vec2(x0, y0 - 15 * s), vec2(x0 + ww + 10 * s, y0 - 3 * s), withA(RED, 0.9 * A), 2 * s)
      text(wt, 9 * s, vec2(x0 + 5 * s, y0 - 14 * s), rgbm(1, 1, 1, A), F_BOLD)
    end
    -- xp boost tag
    if boostActive() then
      local bt = XP_BOOST.mult .. 'X XP'
      local bw = textW(bt, 9 * s, F_BOLD).x
      ui.drawRectFilled(vec2(x0 + W - bw - 10 * s, y0 - 15 * s), vec2(x0 + W, y0 - 3 * s), withA(GOLD, 0.9 * A), 2 * s)
      text(bt, 9 * s, vec2(x0 + W - bw - 5 * s, y0 - 14 * s), rgbm(0.05, 0.05, 0.05, A), F_BOLD)
    end
    -- police status above the panel
    if chase.state == 'active' then
      local ct = 'POLICE  ' .. #chase.units .. (chase.bustTimer >= 0 and ('   ' .. math.ceil(chase.bustTimer) .. 's') or '')
      local col = math.floor(t * 4) % 2 == 0 and COL_POLICE or RED
      textC(ct, 11 * s, cx, y0 - 15 * s, withA(col, A), F_BOLD)
    end

    -- event lines under the panel
    local ey = y1 + mh + 8 * s
    for i = #hud.events, 1, -1 do
      local e = hud.events[i]
      local a = math.min(1, e.t * 6) * (1 - math.max(0, (e.t - 1.6) / 0.8)) * A
      local size = (e.big and 15 or 12) * s
      local rise = (1 - math.min(1, e.t * 5)) * 6 * s
      textC(e.text, size, cx, ey + rise, withA(e.col, a), F_BOLD)
      ey = ey + size + 4 * s
    end
  end

  ---------------------------------------------------------------- status line (chase / race), below the panel
  local ly = sh * 0.03 + 38 * s + 4 * s + 44 * s + 46 * s
  if banner.t >= 0 then
    local a = math.min(1, banner.t * 4) * math.min(1, (banner.life - banner.t) * 2)
    textC(banner.text, 26 * s, cx, ly, withA(banner.col, a), F_BOLD)
    textC(banner.sub, 11 * s, cx, ly + 28 * s, rgbm(0.9, 0.9, 0.92, a))
  elseif duel.state == 'ready' then
    textC('GET IN POSITION', 22 * s, cx, ly, COL_RACE, F_BOLD)
    textC(string.format('vs %s   %ds   click the cancel popup or press Backspace to cancel', driverName(duel.opp), math.ceil(duel.timer)), 11 * s, cx, ly + 26 * s, rgbm(0.9, 0.9, 0.92, 1))
  elseif duel.state == 'racing' then
    local me = ac.getCar(0)
    local opp = ac.getCar(duel.opp)
    local left = math.max(0, RACE_SECONDS - duel.time)
    local lead = ''
    local lc = rgbm(0.9, 0.9, 0.92, 1)
    if me and opp then
      local L = me.look + opp.look
      if L:length() > 0.01 then
        local ahead = (me.position - opp.position):dot(L:normalize())
        if ahead > 2 then lead = 'AHEAD'; lc = GREEN elseif ahead < -2 then lead = 'BEHIND'; lc = RED else lead = 'LEVEL'; lc = GOLD end
        lead = lead .. string.format('  %.0f m', math.abs(ahead))
      end
    end
    textC(string.format('%d:%02d', math.floor(left / 60), math.floor(left % 60)), 26 * s, cx, ly, left < 10 and RED or rgbm(1, 1, 1, 1), F_BOLD)
    textC(lead .. '   vs ' .. driverName(duel.opp), 12 * s, cx, ly + 30 * s, lc, F_BOLD)
  elseif race.state == 'lobby' then
    local n = 0
    for _ in pairs(race.joined) do n = n + 1 end
    textC(string.format('RACE LOBBY   %d in   %ds', n, math.ceil(race.countdown)), 14 * s, cx, ly, COL_RACE, F_BOLD)
  elseif race.state == 'racing' then
    local me = ac.getCar(0)
    local d = me and flatDist(me.position, { x = race.zone.fx, z = race.zone.fz }) or 0
    textC(string.format('%.1f s     %s  %d m', race.time, (race.zone.finishName or 'FINISH'):upper(), d), 14 * s, cx, ly, GREEN, F_BOLD)
    local y = ly + 20 * s
    for i, f in ipairs(race.finishers) do
      local nm = f.index == 0 and 'you' or (ac.getDriverName(f.index) or ('car ' .. f.index))
      textC(string.format('P%d  %s  %.1fs', i, nm, f.time), 11 * s, cx, y, rgbm(0.7, 0.72, 0.78, 1))
      y = y + 14 * s
    end
  end

  local count = nil
  if chase.state == 'countdown' then count = chase.countdown end
  if race.state == 'lobby' and race.countdown <= 5 then count = race.countdown end
  if duel.state == 'count' then count = duel.timer end
  if count and count > 0 then
    local n = math.ceil(count)
    local frac = count - math.floor(count)
    local size = (48 + 16 * frac) * s
    textC(tostring(n), size, cx, ly + 44 * s, rgbm(1, 1, 1, 0.4 + 0.6 * frac), F_BOLD)
  end

  ---------------------------------------------------------------- calling cards over other cars
  if ENABLE_NAMEPLATES and store.showOthersCards then
    local camPos, camLook = sim.cameraPosition, sim.cameraLook
    local topBest = sessionBest
    for _, o in pairs(others) do if o.best and o.best > topBest then topBest = o.best end end
    for idx, o in pairs(others) do
      local c = ac.getCar(idx)
      if c and c.isConnected and camPos and camLook then
        local wp = c.position + vec3(0, 1.85, 0)
        local rel = wp - camPos
        local d = rel:length()
        if d < 160 and rel:dot(camLook) > 0 then
          local ok, sp = pcall(function() return ui.projectPoint(wp) end)
          if ok and sp and sp.x and sp.x > -200 and sp.x < sw + 200 and sp.y > -100 and sp.y < sh + 100 then
            local fade = math.min(1, (160 - d) / 40)
            local k = math.max(0.5, 1 - d / 240) * store.nameplateScale
            drawNameplate(sp.x, sp.y, k, fade, o.tag or driverName(idx), RANKS[o.rank], CARDS[o.card or 0], o.best and topBest > 0 and o.best == topBest, o.prestige, idx == wantedIndex, o.fire)
          end
        end
      end
    end
  end
end

------------------------------------------------------------------ menu (CSP online extras > No License Ranks)

local function addLocalZone(kind, me)
  local p = me.position
  local name = store.zoneName ~= '' and store.zoneName or (kind == 'chase' and ('Police ' .. (#ZONES.chase + 1)) or ('Race ' .. (#ZONES.race + 1)))
  local z = normZone({ name = name, x = p.x, y = p.y, z = p.z, r = store.zoneR }, kind == 'race')
  if kind == 'chase' then ZONES.chase[#ZONES.chase + 1] = z else ZONES.race[#ZONES.race + 1] = z end
  store.zoneName = ''
  saveLocalZones()
  dlog('placed ' .. kind .. ' zone ' .. name)
end

local menuUI = { nameEdit = nil }
local function nlButton(label, w, accent, h)
  h = h or 26
  local p = ui.getCursor()
  ui.invisibleButton('##b' .. label, vec2(w, h))
  local hov = ui.itemHovered()
  local clicked = ui.itemClicked(ui.MouseButton.Left)
  ui.drawRectFilled(p, p + vec2(w, h), accent and withA(accent, hov and 1 or 0.85) or rgbm(1, 1, 1, hov and 0.16 or 0.08), 4)
  local tw = textW(label, 11, F_BOLD)
  text(label, 11, vec2(p.x + (w - tw.x) / 2, p.y + (h - 13) / 2), accent and rgbm(0.04, 0.04, 0.05, 1) or rgbm(1, 1, 1, 1), F_BOLD)
  return clicked
end
local DIM = rgbm(0.5, 0.5, 0.55, 1)
local PANEL = rgbm(0.07, 0.075, 0.09, 1)

local function isTopRun()
  if sessionBest <= 0 then return false end
  for _, o in pairs(others) do if o.best and o.best > sessionBest then return false end end
  return true
end

-- one card tile. returns true when clicked
local function cardTile(i, c, w, h, showName)
  local p = ui.getCursor()
  ui.invisibleButton('##card' .. i, vec2(w, h + (showName and 14 or 0)))
  local hovered = ui.itemHovered()
  local clicked = ui.itemClicked(ui.MouseButton.Left)
  local unlocked = cardUnlocked(c)
  local selected = store.card == c.id
  drawCardImage(c, p, p + vec2(w, h), unlocked and rgbm(1, 1, 1, 1) or rgbm(0.28, 0.28, 0.3, 1))
  if not unlocked then
    local lt = cardLockText(c)
    local lw = textW(lt, 9, F_BOLD).x
    text(lt, 9, vec2(p.x + (w - lw) / 2, p.y + h / 2 - 10), rgbm(0.9, 0.9, 0.92, 1), F_BOLD)
    local pr = cardProgress(c)
    ui.drawRectFilled(vec2(p.x + 10, p.y + h / 2 + 5), vec2(p.x + w - 10, p.y + h / 2 + 8), rgbm(1, 1, 1, 0.15), 1)
    ui.drawRectFilled(vec2(p.x + 10, p.y + h / 2 + 5), vec2(p.x + 10 + (w - 20) * pr, p.y + h / 2 + 8), GOLD, 1)
  end
  local border = selected and GOLD or (hovered and rgbm(1, 1, 1, 0.8) or rgbm(1, 1, 1, 0.12))
  ui.drawRect(p, p + vec2(w, h), border, 3, ui.CornerFlags.All, selected and 2 or 1)
  if c.kind == 'a' then
    ui.drawRectFilled(vec2(p.x + w - 34, p.y + 3), vec2(p.x + w - 3, p.y + 13), rgbm(0, 0, 0, 0.6), 2)
    text('ANIM', 7, vec2(p.x + w - 31, p.y + 4), rgbm(1, 1, 1, 0.9), F_BOLD)
  end
  if hasFlag(store.newCards, c.id) then
    ui.drawRectFilled(vec2(p.x + 3, p.y + 3), vec2(p.x + 30, p.y + 13), GOLD, 2)
    text('NEW', 7, vec2(p.x + 7, p.y + 4), rgbm(0.05, 0.05, 0.05, 1), F_BOLD)
  end
  if showName then
    text(c.name, 9, vec2(p.x + 2, p.y + h + 2), selected and GOLD or rgbm(0.8, 0.82, 0.86, 1), F_BOLD)
  end
  if hovered and not unlocked then ui.setTooltip('Locked: ' .. cardLockText(c)) end
  return clicked and unlocked
end

local function tabCards()
  ui.childWindow('##cards', vec2(560, 330), false, 0, function()
    local col, n = 0, 0
    for i, c in ipairs(CARDS) do
      if c.kind ~= 'f' then
        if cardTile(i, c, 176, 44, true) then selectCard(c) end
        n = n + 1
        col = col + 1
        if col < 3 then ui.sameLine(0, 8) else col = 0 end
      end
    end
  end)
end

local function bar(frac, w, colr)
  local p = ui.getCursor()
  ui.dummy(vec2(w, 6))
  ui.drawRectFilled(p, p + vec2(w, 4), rgbm(1, 1, 1, 0.12), 2)
  ui.drawRectFilled(p, p + vec2(w * math.max(0, math.min(1, frac)), 4), colr or GOLD, 2)
end

local function tabChallenges()
  if ENABLE_DAILY then
    ui.textColored('TODAY', GOLD)
    for _, c in ipairs(daily.list) do
      local done = hasFlag(store.dailyDone, c.id)
      local prog = dailyProgress(c)
      if done then ui.textColored('DONE   ' .. c.text .. '   +' .. fmt(c.xp) .. ' xp', GREEN)
      else
        ui.text(string.format('%s   %s / %s   +%s xp', c.text, fmt(prog), fmt(c.goal), fmt(c.xp)))
        bar(prog / c.goal, 420)
      end
    end
    ui.textColored(store.dailyCount .. ' daily challenges completed in total', DIM)
    ui.separator()
  end
  if ENABLE_WEEKLY and weekly.item then
    ui.textColored('THIS WEEK', GOLD)
    local c = weekly.item
    if store.weeklyDone then ui.textColored('DONE   ' .. c.text .. '   +' .. fmt(c.xp) .. ' xp', GREEN)
    else
      local v = store[c.key] or 0
      ui.text(string.format('%s   %s / %s   +%s xp', c.text, fmt(v), fmt(c.goal), fmt(c.xp)))
      bar(v / c.goal, 420)
    end
    ui.separator()
  end
  if ENABLE_LOGIN_STREAK then
    ui.textColored('LOGIN STREAK', GOLD)
    ui.text(string.format('day %d   (+%s xp every day you come back, up to 1,000)', store.loginStreak, fmt(math.min(1000, (store.loginStreak + 1) * 100))))
    ui.separator()
  end
  ui.textColored('MILESTONES', GOLD)
  for _, m in ipairs(MILESTONES) do
    local done = hasFlag(store.milestonesDone, m.id)
    local v = store[m.key] or 0
    if done then ui.textColored('DONE   ' .. m.text, GREEN)
    else ui.textColored(string.format('%s   %s / %s   +%s xp', m.text, fmt(math.min(v, m.goal)), fmt(m.goal), fmt(m.xp)), rgbm(0.8, 0.82, 0.86, 1)) end
  end
end

local function tabLeaderboard()
  local rows = { { name = myTag(), rank = rankIndex, xp = store.xp, best = sessionBest, me = true } }
  for idx, o in pairs(others) do
    local c = ac.getCar(idx)
    if c and c.isConnected then rows[#rows + 1] = { name = o.tag or driverName(idx), rank = o.rank, xp = o.xp or 0, best = o.best or 0, top = o.top or 0, prestige = o.prestige or 0 } end
  end
  rows[1].top = sessionTop
  rows[1].prestige = store.prestige
  ui.textColored('BEST RUNS TONIGHT', GOLD)
  table.sort(rows, function(a, b) return a.best > b.best end)
  for i, r in ipairs(rows) do
    ui.textColored(string.format('%d.  %s', i, r.name), r.me and GOLD or rgbm(1, 1, 1, 1))
    ui.sameLine(260)
    ui.text(fmt(r.best) .. ' pts')
    ui.sameLine(400)
    ui.textColored(math.floor(r.top) .. ' km/h', DIM)
  end
  ui.separator()
  ui.textColored('RANKS ON THE SERVER', GOLD)
  table.sort(rows, function(a, b) return a.xp > b.xp end)
  for i, r in ipairs(rows) do
    ui.image(RANKS[r.rank].icon, vec2(18, 18))
    ui.sameLine()
    ui.textColored(string.format('%d.  %s', i, r.name), r.me and GOLD or rgbm(1, 1, 1, 1))
    ui.sameLine(260)
    ui.textColored(RANKS[r.rank].name, RANKS[r.rank].col)
    ui.sameLine(400)
    ui.text(fmt(r.xp) .. ' xp')
  end
end

local function tabStats()
  ui.text(string.format('%s km   %d near misses   %d overtakes   %d contacts', fmt(store.km), store.nearMisses, store.overtakes, store.crashes))
  ui.text(string.format('top %d km/h   best combo x%d   best run %s', store.topSpeed, store.bestStreak, fmt(store.bestRun)))
  if ENABLE_FLASH_RACE then ui.text(string.format('flash races: %d, %d wins', store.duels, store.duelWins)) end
  if ENABLE_POLICE then ui.text(string.format('police: %d escapes, %d busts', store.escapes, store.busts)) end
  if ENABLE_RACE_ZONES then ui.text(string.format('zone races: %d, %d wins', store.races, store.raceWins)) end
  local n = 0
  for _, c in ipairs(CARDS) do if c.kind ~= 'f' and cardUnlocked(c) then n = n + 1 end end
  local total = 0
  for _, c in ipairs(CARDS) do if c.kind ~= 'f' then total = total + 1 end end
  ui.text(string.format('calling cards: %d of %d unlocked', n, total))
  if ENABLE_PRESTIGE then
    ui.separator()
    ui.textColored('PRESTIGE', GOLD)
    if store.prestige > 0 then ui.text('prestige ' .. store.prestige .. '   +' .. (store.prestige * 5) .. '% xp on everything, stars on your card') end
    if rankIndex >= #RANKS then
      ui.textColored('You are NO LICENSE. Prestige sends you back to Rookie with a star next to your rank and +5% xp for good. Cards stay.', DIM)
      if nlButton('PRESTIGE NOW', 160, GOLD) then
        store.prestige = store.prestige + 1
        store.xp = 0
        rankIndex = 1
        showBanner('PRESTIGE ' .. store.prestige, 'back to Rookie. +' .. (store.prestige * 5) .. '% xp forever', GOLD, 6)
        broadcastRank()
        backendSave()
      end
    else
      ui.textColored('Reach NO LICENSE to prestige.', DIM)
    end
  end
  ui.separator()
  ui.textColored('HOW XP WORKS', GOLD)
  ui.textColored('Near misses are the main earner. Closer = more. Chain them for a combo multiplier, go faster for a speed multiplier.', DIM)
  ui.textColored('A crash costs 100 xp plus 30% of the run you were on. You never lose a rank you have reached.', DIM)
  ui.textColored('XP boost ' .. XP_BOOST.mult .. 'x between ' .. XP_BOOST.hours[1] .. ':00 and ' .. (XP_BOOST.hours[#XP_BOOST.hours] + 1) .. ':00.', DIM)
end

local function tabSettings()
  ui.textColored('NAME OVER YOUR CAR', GOLD)
  if menuUI.nameEdit == nil then menuUI.nameEdit = myTag() end
  menuUI.nameEdit = ui.inputText('##tag', menuUI.nameEdit)
  ui.sameLine()
  if ui.button('Save name') then
    local v = menuUI.nameEdit:gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 15)
    if v ~= '' then store.tag = v; broadcastRank() end
    menuUI.nameEdit = myTag()
  end
  ui.separator()
  ui.textColored('MENU KEY', GOLD)
  if menuButton then
    local okc = pcall(function() menuButton:control(vec2(160, 24)) end)
    if not okc then ui.text('current key: ' .. MENU_KEY) end
  else
    ui.text('current key: ' .. MENU_KEY)
  end
  ui.separator()
  if ui.checkbox('Show other players\' calling cards and names', store.showOthersCards) then store.showOthersCards = not store.showOthersCards end
  if ui.checkbox('Always show the HUD', store.alwaysShow) then store.alwaysShow = not store.alwaysShow end
  store.hudScale = ui.slider('##hs', store.hudScale, 0.6, 1.8, 'HUD size: %.2f')
  store.nameplateScale = ui.slider('##ns', store.nameplateScale, 0.6, 1.6, 'Card size over cars: %.2f')
  if ENABLE_FLASH_RACE then
    ui.separator()
    ui.textColored('Flash race: stop next to someone, both flash your headlights twice. ' .. RACE_GET_READY .. ' s to line up, then ' .. RACE_SECONDS .. ' s. In front at the end wins. Crash = loss.', DIM)
    if duel.state ~= 'idle' and ui.button('Cancel race') then duelCancel(true) end
  end
  if chase.state ~= 'idle' and ui.button('Cancel chase') then chaseReset() end

  if ENABLE_POLICE or ENABLE_RACE_ZONES then
    ui.separator()
    ui.text('Zones   (' .. zonesSource .. ')')
    local me = ac.getCar(0)
    if me then
      store.zoneName = ui.inputText('Name for the next zone', store.zoneName)
      store.zoneR = ui.slider('##zr', store.zoneR, 3, 25, 'Ring size: %.0f m', true)
      if ENABLE_POLICE and ui.button('+ Police zone here') then addLocalZone('chase', me) end
      if ENABLE_RACE_ZONES then
        if ENABLE_POLICE then ui.sameLine() end
        if ui.button('+ Race start here') then addLocalZone('race', me) end
        ui.sameLine()
        if #ZONES.race > 0 and ui.button('Race finish here') then
          local z = ZONES.race[#ZONES.race]
          z.fx, z.fy, z.fz = me.position.x, me.position.y, me.position.z
          z.finishR = math.max(store.zoneR, 8)
          if store.zoneName ~= '' then z.finishName = store.zoneName; store.zoneName = '' end
          saveLocalZones()
        end
      end
    end
    for i, z in ipairs(ZONES.chase) do
      ui.textColored(string.format('POLICE  %s   %.0f, %.0f, %.0f   r%.0f', z.name, z.x, z.y, z.z, z.r), COL_POLICE)
      ui.sameLine()
      if ui.button('remove##c' .. i) then table.remove(ZONES.chase, i); saveLocalZones() end
    end
    for i, z in ipairs(ZONES.race) do
      ui.textColored(string.format('RACE  %s   %.0f, %.0f, %.0f   r%.0f   finish %s', z.name, z.x, z.y, z.z, z.r, z.finishName), COL_RACE)
      ui.sameLine()
      if ui.button('remove##r' .. i) then table.remove(ZONES.race, i); saveLocalZones() end
    end
    if ui.button('Copy zones.json') then pcall(function() ac.setClipboardText(zonesJSON()) end) end
    ui.sameLine()
    if me and ui.button('Copy my position') then pcall(function() ac.setClipboardText(string.format('%.1f, %.1f, %.1f', me.position.x, me.position.y, me.position.z)) end) end
    ui.sameLine()
    if store.useLocalZones and ui.button('Back to server zones') then
      store.useLocalZones = false
      store.localZones = ''
      applyZones(DEFAULT_ZONES, 'built-in')
      loadRemoteZones()
    end
    ui.textColored('Place zones, Copy zones.json, paste it into zones.json on GitHub. Everyone gets them next join.', DIM)
  end
end

local function drawMenu()
    local R = RANKS[rankIndex]
    local nxt = RANKS[rankIndex + 1]

    -- how everyone else sees you
    local p = ui.getCursor()
    local k = 2.4
    local W, H = 150 * k, 37.5 * k
    ui.dummy(vec2(W, H + 14 * k))
    drawNameplate(p.x + W / 2, p.y + H + 10 * k, k, 1, myTag(), R, myCard(), isTopRun(), store.prestige, wantedIndex == 0, onFire)
    ui.sameLine(W + 16)
    ui.beginGroup()
    ui.textColored(R.name:upper(), R.col)
    ui.text('rank ' .. rankIndex .. ' of ' .. #RANKS .. '   ' .. fmt(store.xp) .. ' xp' .. (backendOK and '   (server saved)' or ''))
    if nxt then
      ui.text(fmt(nxt.xp - store.xp) .. ' xp to ' .. nxt.name)
      bar((store.xp - R.xp) / (nxt.xp - R.xp), 200, R.col)
    end
    local newN = countNewCards()
    if newN > 0 then ui.textColored(newN .. ' new card' .. (newN > 1 and 's' or '') .. ' unlocked', GOLD) end
    if boostActive() then ui.textColored(XP_BOOST.mult .. 'X XP ACTIVE', GOLD) end
    ui.endGroup()
    ui.separator()

    ui.tabBar('##nltabs', function()
      ui.tabItem('Cards', tabCards)
      ui.tabItem('Challenges', tabChallenges)
      ui.tabItem('Leaderboard', tabLeaderboard)
      ui.tabItem('Stats', tabStats)
      ui.tabItem('Settings', tabSettings)
    end)
end

pcall(function()
  local icn = ui.Icons and (ui.Icons.Trophy or ui.Icons.Star or ui.Icons.Settings) or nil
  ui.registerOnlineExtra(icn, 'No License Ranks', nil, drawMenu)
end)

-- hotkey (rebindable in Settings) opens the same menu as a dialog
pcall(function()
  menuButton = ac.ControlButton('NL_RANKS_MENU', { keyboard = { key = ui.KeyIndex[MENU_KEY] or ui.KeyIndex.Home } })
end)

local function menuKeyPressed()
  if menuButton then
    local ok, v = pcall(function() return menuButton:pressed() end)
    if ok then return v == true end
  end
  local ok, v = pcall(function() return ui.keyboardButtonPressed(ui.KeyIndex[MENU_KEY] or ui.KeyIndex.Home) end)
  return ok and v == true
end

local function openMenu()
  if menu.open then return end
  menu.open = true
  menu.close = false
  local ok = pcall(function()
    ui.modalDialog('No License Ranks', function()
      drawMenu()
      ui.separator()
      if nlButton('Close', 100) or menu.close then menu.open = false; menu.close = false; return true end
      return false
    end, false, function() menu.open = false end)
  end)
  if not ok then menu.open = false end
end

local baseDrawUI = script.drawUI
function script.drawUI(dt)
  baseDrawUI(dt)
  if not started then return end
  if menuKeyPressed() then
    if menu.open then menu.close = true else openMenu() end
  end
  -- hint on the left after joining
  if menu.hintT > 0 then
    menu.hintT = menu.hintT - dt
    local a = math.min(1, menu.hintT / 2)
    local sim = ac.getSim()
    local sh = sim.windowHeight
    local s = store.hudScale
    local x, y = 24 * s, sh * 0.42
    local w, h = 250 * s, 58 * s
    ui.drawRectFilled(vec2(x, y), vec2(x + w, y + h), rgbm(0.04, 0.045, 0.055, 0.82 * a), 6 * s)
    ui.drawRectFilled(vec2(x, y), vec2(x + 3 * s, y + h), withA(GREEN, a), 2 * s)
    text('NO LICENSE RANKS', 10 * s, vec2(x + 12 * s, y + 8 * s), withA(GREEN, a), F_BOLD)
    local key = MENU_KEY:upper()
    local kw = textW(key, 11 * s, F_BOLD).x
    ui.drawRectFilled(vec2(x + 12 * s, y + 26 * s), vec2(x + 12 * s + kw + 12 * s, y + 46 * s), rgbm(1, 1, 1, 0.9 * a), 3 * s)
    text(key, 11 * s, vec2(x + 18 * s, y + 30 * s), rgbm(0.05, 0.05, 0.05, a), F_BOLD)
    text('ranks, cards, challenges', 10 * s, vec2(x + 12 * s + kw + 20 * s, y + 30 * s), rgbm(0.9, 0.9, 0.92, a))
  end
end
