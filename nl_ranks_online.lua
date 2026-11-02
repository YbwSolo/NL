-- No License Ranks - server script
-- Loaded by every player automatically from csp_extra_options.ini. Nothing to install.
--
-- HUD: a small panel at the top middle. Hidden while nothing is happening, pops in when
-- you earn something, stays while you are in a run, fades out when you crash or stop.
-- Never covers the road.

local VERSION = '5.3'

------------------------------------------------------------------ CONFIG (edit these)

-- Where the rank badges live (rank_01.png .. rank_27.png).
local ICON_BASE = 'https://raw.githubusercontent.com/YbwSolo/NL/main/icons/'

-- UI icon sheet
local ICON_ATLAS = 'https://raw.githubusercontent.com/YbwSolo/NL/main/icons/ui_atlas.png'

-- Where the calling cards live (s_*.png, a_*.png, f_*.png).
local CARD_BASE = 'https://raw.githubusercontent.com/YbwSolo/NL/main/cards/'

-- Zones file for the police / race circles (only used when those are switched on below).
local ZONES_URL = 'https://raw.githubusercontent.com/YbwSolo/NL/main/zones.json'

-- Optional backend for server-side progress (leave '' to keep progress on each player's PC).
local BACKEND = ''

-- Features. true = on, false = off.
local ENABLE_POLICE = false        -- blue circles that start a police chase
local ENABLE_HEAT = true           -- crash a lot in a short time and the police come for you (no circles needed)
local COP_TOP_KMH = 175            -- police never go faster than this. get above it and you are gone
local COP_MAX_UNITS = 2            -- one unit to start, a second one at 3 stars (stars = crashes while they chase you)
local COP_SECOND_UNIT_STARS = 3
local HEAT_CRASHES = 4             -- this many contacts...
local HEAT_WINDOW = 45             -- ...within this many seconds = chase
local FLIP_TO_PITS = true          -- on your roof and not moving = sent back to the pits. during a chase that is a wreck, not a bust (no xp lost)
local FLIP_SECONDS = 4             -- how long you can sit flipped before it happens
local ENABLE_RACE_ZONES = false    -- red circles that start a race lobby
local ENABLE_FLASH_RACE = true     -- stop next to someone, both flash headlights twice = 60 s race
local ENABLE_DAILY = true          -- 3 daily challenges
local ENABLE_NAMEPLATES = true     -- calling card + rank badge + name floating over other players' cars
local ENABLE_WEEKLY = true         -- one big weekly challenge
local ENABLE_LOGIN_STREAK = true   -- xp for playing on consecutive days

-- XP boost hours (local time of each player's PC). 2x xp between 20:00 and 23:59 by default.
local XP_BOOST = { hours = { 20, 21, 22, 23 }, mult = 2 }

-- Key that opens the menu (name from ui.KeyIndex: Home, End, Insert, F9, F10, M, N ...). Players can rebind it in Settings.
local MENU_KEY = 'End'
local ADMIN_KEY = 'Home'           -- admin panel. press it, type the admin password once, done (F-keys are taken by AC itself)
-- Admin password, stored as a hash so the plain password is not sitting in a public file.
-- To change it: open the admin panel -> Security -> type a new password -> Copy hash -> paste it here.
local ADMIN_PASSWORD_HASH = '23695191-47201398'
local HINT_SECONDS = 30            -- how long the "press HOME" hint stays on the left of the screen after joining

local ENABLE_WANTED = true         -- top run on the server becomes WANTED: 1.5x xp for them, bounty xp for near-missing them
local ENABLE_DRAFT = true          -- xp for sitting in another player's slipstream
local ENABLE_PRESTIGE = true       -- at NO LICENSE: prestige, back to Rookie with a star and +5% xp per star
local ENABLE_EMOTES = true         -- numpad 1-6 puts a quick message over your car for everyone
local EMOTES = { 'GG', 'WP', 'RACE?', 'LOL', 'SORRY', 'GL' }

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
  -- the grind: rank 2 at 1,500 xp, rank 10 at ~450k, rank 20 at ~3.2M, NO LICENSE at ~7.2M
  RANKS[i] = { name = n, xp = math.floor(1500 * ((i - 1) ^ 2.6)), col = col, icon = string.format('%srank_%02d.png', ICON_BASE, i) }
end

local XP = {
  perKm = 5, fastKm = 4, veryFastKm = 8, cleanKm = 3,
  nearMiss = 12, overtake = 3, streakStep = 0.15, streakWindow = 6.0,
  crashFlat = 300, crashRunPct = 0.30,      -- a crash costs 300 xp plus 30% of the run you were on
  escape = 4000, escapePerUnit = 500, busted = -2500,
  raceWin = 3000, raceSecond = 1800, raceThird = 1000, raceFinish = 500, raceSolo = 300,
  duelWin = 2500, duelLose = 400, duelDraw = 1200,
  bounty = 600, draftPerSec = 3, copSpin = 800,
}
local NEAR, PASS, MIN_SPEED, MIN_REL = 2.9, 5.0, 60, 12

-- daily challenges: 3 picked per day from this list
local CHALLENGES = {
  { id = 'nm60', text = '60 near misses', key = 'dayNear', goal = 60, xp = 8000 },
  { id = 'nm150', text = '150 near misses', key = 'dayNear', goal = 150, xp = 20000 },
  { id = 'km60', text = 'drive 60 km', key = 'dayKm', goal = 60, xp = 7000 },
  { id = 'km200', text = 'drive 200 km', key = 'dayKm', goal = 200, xp = 22000 },
  { id = 'top260', text = 'hit 260 km/h', key = 'dayTop', goal = 260, xp = 5000 },
  { id = 'top310', text = 'hit 310 km/h', key = 'dayTop', goal = 310, xp = 12000 },
  { id = 'streak8', text = 'x8 combo', key = 'dayStreak', goal = 8, xp = 7000 },
  { id = 'streak15', text = 'x15 combo', key = 'dayStreak', goal = 15, xp = 20000 },
  { id = 'run10k', text = 'a 10,000 point run', key = 'dayRun', goal = 10000, xp = 10000 },
  { id = 'run25k', text = 'a 25,000 point run', key = 'dayRun', goal = 25000, xp = 28000 },
  { id = 'clean10', text = '10 km with no contact', key = 'dayClean', goal = 10, xp = 9000 },
  { id = 'ot40', text = '40 overtakes', key = 'dayOver', goal = 40, xp = 6000 },
  { id = 'duel2', text = 'win 2 flash races', key = 'dayDuelWins', goal = 2, xp = 10000 },
  { id = 'duel5', text = 'win 5 flash races', key = 'dayDuelWins', goal = 5, xp = 25000 },
}

-- weekly challenge: one per week, rotates
local WEEKLY = {
  { text = '800 near misses this week', key = 'weekNear', goal = 800, xp = 60000 },
  { text = '600 km this week', key = 'weekKm', goal = 600, xp = 60000 },
  { text = '20 flash race wins this week', key = 'weekWins', goal = 20, xp = 80000 },
  { text = '1,500 near misses this week', key = 'weekNear', goal = 1500, xp = 120000 },
}

-- lifetime milestones
local MILESTONES = {
  { id = 'km100', text = '100 km driven', key = 'km', goal = 100, xp = 5000 },
  { id = 'km500', text = '500 km driven', key = 'km', goal = 500, xp = 20000 },
  { id = 'km2000', text = '2,000 km driven', key = 'km', goal = 2000, xp = 60000 },
  { id = 'km10000', text = '10,000 km driven', key = 'km', goal = 10000, xp = 250000 },
  { id = 'nm500', text = '500 near misses', key = 'nearMisses', goal = 500, xp = 10000 },
  { id = 'nm2500', text = '2,500 near misses', key = 'nearMisses', goal = 2500, xp = 50000 },
  { id = 'nm10000', text = '10,000 near misses', key = 'nearMisses', goal = 10000, xp = 200000 },
  { id = 'nm30000', text = '30,000 near misses', key = 'nearMisses', goal = 30000, xp = 600000 },
  { id = 'dw25', text = '25 flash race wins', key = 'duelWins', goal = 25, xp = 40000 },
  { id = 'dw100', text = '100 flash race wins', key = 'duelWins', goal = 100, xp = 150000 },
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
  { id = 's_breach', name = 'Breach', kind = 's', unlock = 'km', goal = 150 },
  { id = 's_elite1', name = 'Midnight GT', kind = 's', unlock = 'km', goal = 600 },
  { id = 's_seasonpass', name = 'Data Breach', kind = 's', unlock = 'km', goal = 2500 },
  { id = 's_ben', name = 'Red Blade', kind = 's', unlock = 'nm', goal = 400 },
  { id = 's_mil', name = 'Pink Fade', kind = 's', unlock = 'nm', goal = 1000 },
  { id = 's_nuketown_2025', name = 'Cyan Edge', kind = 's', unlock = 'wins', goal = 3 },
  { id = 's_roxann_soldier', name = 'Silver Blade', kind = 's', unlock = 'wins', goal = 15 },
  { id = 's_massacre', name = 'Sunset Ridge', kind = 's', unlock = 'run', goal = 12000 },
  { id = 's_partyrock', name = 'Dark Bloom', kind = 's', unlock = 'run', goal = 30000 },
  { id = 's_ghost', name = 'Red Lambo', kind = 's', unlock = 'top', goal = 280 },
  { id = 's_dragonfire', name = 'Hellfire', kind = 's', unlock = 'combo', goal = 10 },
  { id = 's_pap', name = 'Hypno', kind = 's', unlock = 'combo', goal = 15 },
  { id = 's_graf', name = 'Blossom', kind = 's', unlock = 'daily', goal = 10 },
  { id = 's_zombies', name = 'Slayer', kind = 's', unlock = 'daily', goal = 30 },
  { id = 's_kawaii', name = 'Old Master', kind = 's', unlock = 'days', goal = 5 },
  { id = 's_zulu', name = 'Sakura', kind = 's', unlock = 'days', goal = 14 },
  { id = 'a_afterlife', name = 'Afterlife', kind = 'a', frames = 32, fps = 20, unlock = 'rank', goal = 10 },
  { id = 'a_fire', name = 'Inferno', kind = 'a', frames = 32, fps = 20, unlock = 'nm', goal = 2000 },
  { id = 'a_gameover', name = 'Game Over', kind = 'a', frames = 32, fps = 20, unlock = 'wins', goal = 30 },
  { id = 'a_goku', name = 'Ultra', kind = 'a', frames = 32, fps = 20, unlock = 'rank', goal = 18 },
  { id = 'a_kakashi', name = 'Sharingan', kind = 'a', frames = 32, fps = 8, unlock = 'run', goal = 60000 },
  { id = 'a_kaneki', name = 'Ghoul', kind = 'a', frames = 32, fps = 12.0, unlock = 'nm', goal = 4000 },
  { id = 'a_panda', name = 'Mad Panda', kind = 'a', frames = 32, fps = 20, unlock = 'days', goal = 30 },
  { id = 'a_magicball', name = 'Arcane', kind = 'a', frames = 32, fps = 20, unlock = 'combo', goal = 20 },
  { id = 'a_storm', name = 'Storm', kind = 'a', frames = 16, fps = 18.2, unlock = 'top', goal = 300 },
  { id = 'a_sunset', name = 'Horizon', kind = 'a', frames = 32, fps = 20, unlock = 'km', goal = 6000 },
  { id = 'a_tornado', name = 'Tornado', kind = 'a', frames = 32, fps = 20, unlock = 'wins', goal = 60 },
  { id = 'a_orb', name = 'Core', kind = 'a', frames = 32, fps = 20, unlock = 'rank', goal = 22 },
  { id = 'a_trippy', name = 'Trippy', kind = 'a', frames = 32, fps = 20, unlock = 'rank', goal = 27 },
  { id = 'a_v1_starlight', name = 'Starlight', kind = 'a', frames = 32, fps = 16, unlock = 'combo', goal = 15 },
  { id = 'a_v1_assassin', name = 'Assassin', kind = 'a', frames = 32, fps = 16, unlock = 'nm', goal = 8000 },
  { id = 'a_v1_vortex', name = 'Vortex', kind = 'a', frames = 32, fps = 16, unlock = 'daily', goal = 50 },
  { id = 'a_v1_pulse', name = 'Pulse', kind = 'a', frames = 32, fps = 16, unlock = 'top', goal = 320 },
  { id = 'a_v1_ascend', name = 'Ascend', kind = 'a', frames = 32, fps = 16, unlock = 'combo', goal = 30 },
  { id = 'a_v1_nightfall', name = 'Nightfall', kind = 'a', frames = 32, fps = 16, unlock = 'wins', goal = 120 },
  { id = 'a_v1_blade', name = 'Blade', kind = 'a', frames = 32, fps = 16, unlock = 'days', goal = 60 },
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
  prestige = 0, menuKey = '', frame = 0, adminKey = '',
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
  if n > 0 and adminBoostActive and adminBoostActive() then n = n * 2 end
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
    if run.score > store.bestRun and run.score > 2000 and not run.pb then
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
    frame = ac.StructItem.byte(),
  }, function(sender, data)
    if sender == nil or sender.index == 0 then return end
    local old = others[sender.index]
    local rank = math.max(1, math.min(#RANKS, data.rank))
    local tag = tostring(data.tag or '')
    if tag == '' then tag = driverName(sender.index) end
    others[sender.index] = { rank = rank, xp = data.xp, chase = data.chase == 1, card = data.card, best = data.best, tag = tag, seen = t,
      fire = data.fire == 1, prestige = data.prestige or 0, top = data.top or 0, frame = data.frame or 0 }
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
      fire = onFire and 1 or 0, prestige = store.prestige, top = math.floor(sessionTop), frame = store.frame }, true)
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

------------------------------------------------------------------ flash race (flash your lights at someone, they get an accept / decline popup)

local duel = { state = 'idle', opp = -1, timer = 0, time = 0, toast = nil, result = nil, oppResult = nil, falseStart = false,
  flipTimer = 0, resend = 0, resendLeft = 0, lastMsg = nil, ackd = false, hb = 0, oppSeen = 0, ahead = 0 }
local flash = { edges = {}, lastHigh = false, lastHead = false, sentAt = -10, sentTo = -1, pendingFrom = -1, pendingAt = -10, popup = false }
local duelEvent = nil

-- car indices differ from player to player, session IDs do not
local function sessionOf(i)
  local id = 255
  pcall(function() local c = ac.getCar(i); if c then id = c.sessionID end end)
  return id
end

-- kinds: 1 challenge, 2 accept, 3 cancel/decline, 4 verdict at the line, 5 flipped out, 6 heartbeat, 7 ack
local function duelSend(kind, oppIndex, value)
  if not duelEvent then return end
  pcall(function() duelEvent({ kind = kind, target = sessionOf(oppIndex), value = value or 0 }, false) end)
end

-- important messages are repeated until the other side acks them
local function duelSendReliable(kind, oppIndex, value)
  duelSend(kind, oppIndex, value)
  duel.lastMsg = { kind = kind, opp = oppIndex, value = value }
  duel.resendLeft = 6
  duel.resend = 0.5
  duel.ackd = false
end

local function duelReset()
  duel = { state = 'idle', opp = -1, timer = 0, time = 0, toast = nil, result = nil, oppResult = nil, falseStart = false,
    flipTimer = 0, resend = 0, resendLeft = 0, lastMsg = nil, ackd = false, hb = 0, oppSeen = 0, ahead = 0 }
end

local function duelCancel(byMe, quiet)
  if duel.state == 'idle' then return end
  local opp = duel.opp
  if byMe then duelSendReliable(3, opp, 0) end
  if not quiet then showBanner('RACE CANCELLED', byMe and '' or (driverName(opp) .. ' backed out'), rgbm(0.7, 0.72, 0.78, 1), 2.5) end
  local keep = duel.lastMsg
  duelReset()
  if byMe then duel.lastMsg = keep; duel.resendLeft = 4; duel.resend = 0.5 end
end

local function duelStart(opp)
  if duel.state ~= 'idle' then return end
  duel.state = 'ready'
  duel.opp = opp
  duel.timer = RACE_GET_READY
  duel.oppSeen = t
  flash.pendingFrom = -1
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

-- the accept / decline popup
local function showChallenge(idx)
  flash.pendingFrom = idx
  flash.pendingAt = t
  hud.lastEvent = t
  if flash.popup then return end
  flash.popup = true
  local ok = pcall(function()
    ui.modalPopup('Race challenge', driverName(idx) .. ' wants to race you.\n' .. RACE_GET_READY .. ' seconds to line up, then ' .. RACE_SECONDS .. ' seconds. Whoever is in front at the end wins.\nFlip your car and you lose.',
      'Accept', 'Decline', nil, nil, function(accepted)
        flash.popup = false
        if accepted and flash.pendingFrom == idx and duel.state == 'idle' then
          duelSendReliable(2, idx, 0)
          duelStart(idx)
        else
          duelSend(3, idx, 0)
          flash.pendingFrom = -1
        end
      end)
  end)
  if not ok then
    flash.popup = false
    event(driverName(idx) .. ' wants a race   flash twice to accept', COL_RACE, true)
  end
end

pcall(function()
  duelEvent = ac.OnlineEvent({
    ac.StructItem.key('NLFlashRace4'),
    kind = ac.StructItem.byte(), target = ac.StructItem.byte(), value = ac.StructItem.float(),
  }, function(sender, data)
    if sender == nil or sender.index == 0 or not ENABLE_FLASH_RACE then return end
    local idx = sender.index
    if data.target ~= sessionOf(0) then return end
    if data.kind == 7 then
      if duel.lastMsg and duel.lastMsg.opp == idx then duel.ackd = true; duel.resendLeft = 0 end
      return
    end
    if data.kind == 6 then
      if duel.opp == idx then duel.oppSeen = t end
      return
    end
    duelSend(7, idx, data.kind)   -- ack everything else
    if data.kind == 1 then                        -- they flashed at me: popup
      if duel.state == 'idle' then
        if flash.sentTo == idx and t - flash.sentAt < 10 then
          duelSendReliable(2, idx, 0)
          duelStart(idx)
        elseif flash.pendingFrom ~= idx then
          showChallenge(idx)
        end
      end
    elseif data.kind == 2 then                    -- they accepted
      if duel.state == 'idle' and flash.sentTo == idx then duelStart(idx) end
    elseif data.kind == 3 then                    -- they declined / cancelled
      if duel.state ~= 'idle' and duel.opp == idx then duelCancel(false)
      elseif flash.sentTo == idx and t - flash.sentAt < 20 then flash.sentTo = -1; event(driverName(idx) .. ' declined', rgbm(0.7, 0.72, 0.78, 1), true) end
    elseif data.kind == 4 then                    -- their verdict at the line
      if duel.state == 'racing' and duel.opp == idx then duel.oppResult = data.value end
    elseif data.kind == 5 then                    -- they flipped
      if duel.state == 'racing' and duel.opp == idx and duel.result == nil then
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

-- nearest player in front of or beside me within 30 m
local function carNearMe(me)
  local sim = ac.getSim()
  local best, bestD = nil, 1e9
  for i = 1, sim.carsCount - 1 do
    local c = ac.getCar(i)
    if c and c.isConnected then
      local rel = c.position - me.position
      local lon, lat = rel:dot(me.look), math.abs(rel:dot(me.side))
      if lon > -8 and lon < 30 and lat < 8 and math.abs(rel.y) < 5 then
        local d = math.abs(lon) + lat
        if d < bestD then best, bestD = i, d end
      end
    end
  end
  return best
end

local function isFlipped(car)
  local upY = 1
  pcall(function() upY = car.up.y end)
  return upY < 0.15
end

local function duelUpdate(dt, me)
  if not ENABLE_FLASH_RACE then return end
  local speed = me.speedKmh
  -- reliable resend
  if duel.resendLeft > 0 and duel.lastMsg and not duel.ackd then
    duel.resend = duel.resend - dt
    if duel.resend <= 0 then
      duel.resend = 0.6
      duel.resendLeft = duel.resendLeft - 1
      duelSend(duel.lastMsg.kind, duel.lastMsg.opp, duel.lastMsg.value)
    end
  end
  if flash.pendingFrom >= 0 and t - flash.pendingAt > 25 then flash.pendingFrom = -1 end

  if duel.state == 'idle' then
    if speed < 60 and detectFlash(me) then
      local opp = carNearMe(me)
      if opp then
        if flash.pendingFrom == opp then
          duelSendReliable(2, opp, 0)
          duelStart(opp)
        else
          flash.sentAt, flash.sentTo = t, opp
          duelSendReliable(1, opp, 0)
          showBanner('CHALLENGE SENT', 'waiting for ' .. driverName(opp), COL_RACE, 3)
        end
      else
        event('nobody close enough to challenge', rgbm(0.7, 0.72, 0.78, 1))
      end
    end
    return
  end

  hud.lastEvent = t
  local opp = ac.getCar(duel.opp)
  if not opp or not opp.isConnected then duelCancel(false, true); return end
  pcall(function() if ui.keyboardButtonPressed(ui.KeyIndex.Back) then duelCancel(true) end end)
  if duel.state == 'idle' then return end

  -- heartbeat so both sides know the other is still in it
  duel.hb = duel.hb + dt
  if duel.hb > 1 then duel.hb = 0; duelSend(6, duel.opp, 0) end
  if t - duel.oppSeen > 15 and duel.state ~= 'ready' then
    showBanner('RACE OVER', driverName(duel.opp) .. ' dropped out', rgbm(0.7, 0.72, 0.78, 1), 3)
    duelReset()
    return
  end

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
      showBanner('GO', RACE_SECONDS .. ' seconds. be in front when it ends. flip = loss', GREEN, 2)
    end
  elseif duel.state == 'racing' then
    duel.time = duel.time + dt
    -- live gap, shared direction so both cars judge it the same way
    local L = me.look + opp.look
    if L:length() < 0.01 then L = me.look end
    L = L:normalize()
    duel.ahead = (me.position - opp.position):dot(L)
    if duel.falseStart then duel.ahead = duel.ahead - 15 end
    -- flipping loses it
    if isFlipped(me) then duel.flipTimer = duel.flipTimer + dt else duel.flipTimer = 0 end
    if duel.flipTimer > 1.0 and duel.result == nil then
      duel.result = -1
      duelSendReliable(5, duel.opp, 0)
      showBanner('YOU LOST', 'you flipped it', RED, 3)
      addXP(XP.duelLose, 'raced', rgbm(0.7, 0.72, 0.78, 1))
      local keep = duel.lastMsg
      duelReset()
      duel.lastMsg = keep; duel.resendLeft = 5; duel.resend = 0.5
      return
    end
    if duel.time >= RACE_SECONDS and duel.result == nil then
      local mine = duel.ahead > 2 and 1 or (duel.ahead < -2 and -1 or 0)
      duel.result = mine
      duelSendReliable(4, duel.opp, mine)
      duel.timer = 3.0
    elseif duel.result ~= nil then
      duel.timer = duel.timer - dt
      if duel.oppResult ~= nil or duel.timer <= 0 then duelFinish(duel.result, duel.oppResult) end
    end
  end
end

-- crashing no longer ends a race; only a flip does. a crash during line-up cancels it.
local function duelCrash()
  if duel.state == 'ready' or duel.state == 'count' then duelCancel(true) end
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
  local bonus = math.min(5000, store.loginStreak * 500)
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

local chase = { state = 'idle', zone = nil, countdown = 0, time = 0, units = {}, trail = {}, trailTimer = 0, bustTimer = -1, farTimer = 0, lastSpawnT = 0, pinTimer = 0 }
local POLICE_MODEL = 'nolicense_volkswagen_golf_r_mk8/nolicense_volkswagen_golf_r_mk8.kn5'
local copModelOK = nil
local copPhysicsOK = nil
local lookIsModel = nil

-- model matrix for a pose. mat4x4.look is checked once; if it turns out to be a view matrix we build the rows ourselves
local function poseMatrix(pos, look)
  if lookIsModel == nil then
    lookIsModel = false
    pcall(function()
      local m = mat4x4.look(vec3(10, 2, 3), vec3(0, 0, 1), vec3(0, 1, 0))
      if m and m.position and (m.position - vec3(10, 2, 3)):length() < 0.01 then lookIsModel = true end
    end)
  end
  if lookIsModel then return mat4x4.look(pos, look, vec3(0, 1, 0)) end
  local l = vec3(look.x, 0, look.z):normalize()
  local side = vec3(l.z, 0, -l.x)
  return mat4x4(vec4(side.x, side.y, side.z, 0), vec4(0, 1, 0, 0), vec4(l.x, l.y, l.z, 0), vec4(pos.x, pos.y, pos.z, 1))
end

-- each unit is a little car of its own: position, heading, speed, with steering and acceleration limits,
-- plus a physics body so it can actually hit you
local function makeUnit(pos, look, role)
  local u = { pos = vec3(pos.x, pos.y, pos.z), look = vec3(look.x, 0, look.z):normalize(), spd = 15, role = role, lights = {}, node = nil, body = nil,
    flash = math.random() * 10, lastBump = -10, stuck = 0, lastPos = vec3(pos.x, pos.y, pos.z), backT = 0 }
  if copModelOK ~= false then
    local ok, err = pcall(function()
      local path = ac.getFolder(ac.FolderID.ContentCars) .. '/' .. POLICE_MODEL
      if not io.fileExists(path) then error('police model missing') end
      u.node = ac.findNodes('dynamicRoot:yes'):loadKN5(path)
      if not u.node or u.node:size() == 0 then error('model empty') end
      copModelOK = true
      pcall(function() u.node:findMeshes('{ material:ext_Body_Paint }'):ensureUniqueMaterials():setMaterialTexture('txDiffuse', rgbm(0.96, 0.96, 0.96, 1)) end)
    end)
    if not ok then copModelOK = false; u.node = nil; dlog('police model unavailable, lights only (' .. tostring(err) .. ')') end
  end
  if copPhysicsOK ~= false then
    local ok, err = pcall(function()
      u.body = physics.RigidBody({ physics.Collider.Box(vec3(1.85, 1.2, 4.4), vec3(0, 0.7, 0)) }, 1100, nil, true, true)
      u.body:setSemiDynamic(true, true)
      u.body:setTransformation(poseMatrix(u.pos, u.look), false)
      copPhysicsOK = true
    end)
    if not ok then copPhysicsOK = false; u.body = nil; dlog('police physics unavailable, visual only (' .. tostring(err) .. ')') end
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
  if u.body then pcall(function() u.body:dispose() end) end
end

function nlChaseState() return chase.state end
local function chaseReset()
  for _, u in ipairs(chase.units) do disposeUnit(u) end
  chase = { state = 'idle', zone = nil, countdown = 0, time = 0, units = {}, trail = {}, trailTimer = 0, bustTimer = -1, farTimer = 0, lastSpawnT = 0, pinTimer = 0 }
  chaseActive = false
  broadcastRank()
end

-- road height under a point: real raycast when CSP allows it, otherwise the nearest point of the player's trail
local function groundY(pos, fallback)
  local gy = nil
  pcall(function()
    local d = physics.raycastTrack(vec3(pos.x, pos.y + 3, pos.z), vec3(0, -1, 0), 14)
    if d and d > 0 then gy = pos.y + 3 - d end
  end)
  if gy then return gy end
  local tr = chase.trail
  local best, bestD = nil, 1e9
  for i = #tr, math.max(1, #tr - 400), -1 do
    local d = flatDist(tr[i].p, pos)
    if d < bestD then bestD, best = d, tr[i].p.y end
  end
  if best and bestD < 60 then return best end
  return fallback
end

local ROLES = { 'ram', 'pitL', 'pitR', 'ram', 'pitL' }
local function spawnUnit(me, extra)
  local n = #chase.units
  if n >= COP_MAX_UNITS then return end
  if n >= 1 and (chase.stars or 0) < COP_SECOND_UNIT_STARS then return end
  local behind = me.position - me.look * (40 + n * 10) - me.side * ((n % 2 == 0) and 1.5 or -1.5)
  behind.y = groundY(behind, me.position.y)
  local u = makeUnit(behind, me.look, ROLES[n + 1] or 'ram')
  u.spd = me.speedKmh / 3.6
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

-- point on the player's trail a bit further along than where the unit is now (keeps units on the road through corners)
local function trailAhead(pos, lookahead)
  local tr = chase.trail
  if #tr < 2 then return nil end
  local bestI, bestD = #tr, 1e9
  for i = #tr, 1, -1 do
    local d = flatDist(tr[i].p, pos)
    if d < bestD then bestD, bestI = d, i end
  end
  if bestD > 80 then return nil end     -- nowhere near the trail: go straight at the player
  local acc = 0
  for i = bestI, #tr - 1 do
    acc = acc + flatDist(tr[i].p, tr[i + 1].p)
    if acc >= lookahead then return tr[i + 1].p end
  end
  return nil
end

local heat = { crashes = {} }
local function heatCrash(me)
  if not ENABLE_HEAT or chase.state ~= 'idle' then return end
  heat.crashes[#heat.crashes + 1] = t
  while #heat.crashes > 0 and t - heat.crashes[1] > HEAT_WINDOW do table.remove(heat.crashes, 1) end
  local n = #heat.crashes
  if n >= HEAT_CRASHES then
    heat.crashes = {}
    chase.state = 'countdown'
    chase.zone = nil
    chase.countdown = 3.0
    chase.time = 0
    showBanner('HEAT', 'too much contact. police on you in 3. drive', rgbm(0.3, 0.5, 1, 1), 3)
  elseif n == HEAT_CRASHES - 1 then
    event('HEAT RISING   one more and the police come', rgbm(0.4, 0.6, 1, 1), true)
  end
end

-- drive one unit for one frame
local function driveUnit(i, u, dt, me)
  local pSpeed = me.speedKmh / 3.6
  local topSpd = COP_TOP_KMH / 3.6
  local gap = flatDist(u.pos, me.position)
  local rel = me.position - u.pos
  local behind = rel:dot(u.look) > 0          -- player is in front of the unit

  -- spun out: no steering, sliding and rotating until it settles
  if u.spin and u.spin > 0 then
    u.spin = u.spin - dt
    local c, sn = math.cos(2.4 * dt * u.spinDir), math.sin(2.4 * dt * u.spinDir)
    u.look = vec3(u.look.x * c - u.look.z * sn, 0, u.look.x * sn + u.look.z * c):normalize()
    u.spd = math.max(0, u.spd - 14 * dt)
    u.pos = u.pos + u.slideDir * (u.spd * dt)
    u.pos.y = u.pos.y + (groundY(u.pos, me.position.y) - u.pos.y) * math.min(1, dt * 10)
    if u.body then pcall(function() if u.body:isSemiDynamic() then u.body:setTransformation(poseMatrix(u.pos, u.look), true) end end) end
    if u.node then pcall(function() u.node:setPosition(u.pos); u.node:setOrientation(u.look, vec3(0, 1, 0)) end) end
    for li, l in ipairs(u.lights) do l.position = u.pos + vec3(0, 1.55, 0) + vec3(-u.look.z, 0, u.look.x) * (li == 1 and 0.45 or -0.45) end
    return gap
  end

  -- where it wants to go, and how fast. the unit is quick but it is not a rocket: it tops out at COP_TOP_KMH,
  -- it only closes at +8 m/s, and once it is right behind you it matches your speed and nudges, it does not slam
  local target, want
  if gap > 45 or not behind then
    target = trailAhead(u.pos, 22 + 4 * (i - 1))
    if not target or flatDist(target, u.pos) < 3 then target = me.position end
    want = math.min(pSpeed + 8, topSpd)
  elseif u.role == 'ram' then
    target = me.position + me.velocity * 0.3
    if gap > 14 then want = math.min(pSpeed + 6, topSpd)
    elseif pSpeed < 14 then want = math.min(pSpeed + 5, 16)      -- you are slow: it comes in and shoves
    else want = pSpeed + 1.0 end                                  -- you are moving: it sits on your bumper and leans
  else
    local side = (u.role == 'pitL') and -1 or 1
    local alongside = rel:dot(me.look)
    if alongside > 4 then
      target = me.position - me.look * 1.0 + me.side * side * 2.4
      want = math.min(pSpeed + 5, topSpd)
    else
      target = me.position - me.look * 1.2 + me.side * side * 0.6
      want = pSpeed + 1.0
    end
  end
  if pSpeed < 3 then want = math.max(want, 6) end
  want = math.max(4, math.min(want, topSpd))

  -- walls: three short rays ahead. something in the way -> steer to the clearer side and slow down
  local sideV = vec3(-u.look.z, 0, u.look.x)
  local function ray(dir, len)
    local d = nil
    pcall(function() d = physics.raycastTrack(vec3(u.pos.x, u.pos.y + 1.1, u.pos.z), dir, len) end)
    if d and d > 0 then return d end
    return nil
  end
  local fwd = ray(u.look, 9)
  local lft = ray((u.look + sideV * 0.7):normalize(), 7)
  local rgt = ray((u.look - sideV * 0.7):normalize(), 7)
  if fwd then
    local steer = ((lft or 99) >= (rgt or 99)) and 1 or -1
    target = u.pos + u.look * 4 + sideV * steer * 6
    want = math.min(want, 4 + fwd * 2.2)
    u.wallT = t
  elseif lft and lft < 3.5 then
    target = target - sideV * 2.5
  elseif rgt and rgt < 3.5 then
    target = target + sideV * 2.5
  end

  -- other cars: it cannot collide with them, so it drives around them instead
  local sim = ac.getSim()
  for ci = 0, sim.carsCount - 1 do
    if ci ~= me.index then
      local oc = ac.getCar(ci)
      if oc and oc.isConnected then
        local orel = oc.position - u.pos
        local ahead = orel:dot(u.look)
        if ahead > 0 and ahead < 22 then
          local lat = orel:dot(sideV)
          if math.abs(lat) < 2.6 then
            local k = 1 - ahead / 22
            target = target + sideV * ((lat > 0) and -1 or 1) * (3.5 * k + 1.5)
            if ahead < 7 then want = math.min(want, math.max(3, oc.speedKmh / 3.6 - 1)) end
          end
        end
      end
    end
  end

  -- steer with a turn rate limit. ask too much of it at speed and it loses the back end
  local d = target - u.pos
  local dl = vec3(d.x, 0, d.z)
  local dist = dl:length()
  if dist > 0.3 then
    local dir = dl / dist
    local cross = u.look.x * dir.z - u.look.z * dir.x
    local dot = math.max(-1, math.min(1, u.look:dot(dir)))
    local ang = math.acos(dot)
    if ang > 0.85 and u.spd > 17 and gap < 40 and t - (u.lastSpin or -10) > 8 and t - (u.wallT or -10) > 1.5 then
      -- you swerved and it could not follow: spin out for a few seconds
      u.spin = 2.6 + math.random() * 1.2
      u.spinDir = cross > 0 and 1 or -1
      u.slideDir = vec3(u.look.x, 0, u.look.z)
      u.lastSpin = t
      chase.lost = (chase.lost or 0) + 1
      event('POLICE SPUN OUT   +' .. XP.copSpin .. ' xp', rgbm(0.4, 0.8, 1, 1), true)
      addXP(XP.copSpin, 'made a cop spin out', rgbm(0.4, 0.8, 1, 1))
      hud.lastEvent = t
      return gap
    end
    local maxTurn = (2.2 - math.min(1.7, u.spd * 0.032)) * dt
    local turn = math.min(ang, maxTurn) * (cross > 0 and 1 or -1)
    local c, sn = math.cos(turn), math.sin(turn)
    u.look = vec3(u.look.x * c - u.look.z * sn, 0, u.look.x * sn + u.look.z * c):normalize()
    if ang > 0.5 then want = math.min(want, math.max(8, 30 - (ang - 0.5) * 18)) end
  end
  if dist < 2 and u.role ~= 'ram' then want = pSpeed end
  if u.spd < want then u.spd = math.min(want, u.spd + 8 * dt) else u.spd = math.max(want, u.spd - 14 * dt) end
  u.pos = u.pos + u.look * (u.spd * dt)
  u.pos.y = u.pos.y + (groundY(u.pos, (gap > 45 and target or me.position).y) - u.pos.y) * math.min(1, dt * 10)

  -- physics body: push our pose in while it is kinematic; if it got knocked, follow it for a moment
  if u.body then
    pcall(function()
      if u.body:isSemiDynamic() then
        u.body:setTransformation(poseMatrix(u.pos, u.look), true)
        u.backT = 0
      else
        local m = u.body:getTransformation()
        if m and m.position then
          u.pos = vec3(m.position.x, m.position.y, m.position.z)
          local lk = m.look
          if lk and (lk.x * lk.x + lk.z * lk.z) > 0.01 then u.look = vec3(lk.x, 0, lk.z):normalize() end
        end
        u.backT = u.backT + dt
        if u.backT > 1.2 then u.body:setSemiDynamic(true, true) end
      end
    end)
  end

  -- contact feedback
  if gap < 4.2 and t - u.lastBump > 2.0 then
    u.lastBump = t
    event(u.role == 'ram' and 'RAMMED' or 'PIT MANEUVER', rgbm(0.4, 0.6, 1, 1))
    hud.lastEvent = t
  end

  -- visuals
  u.flash = u.flash + dt * 9
  local blue = math.floor(u.flash) % 2 == 0
  for li, l in ipairs(u.lights) do
    local on = (li == 1) == blue
    l.position = u.pos + vec3(0, 1.55, 0) + u.look * 0.2 + vec3(-u.look.z, 0, u.look.x) * (li == 1 and 0.45 or -0.45)
    l.color = (li == 1 and rgb(0.1, 0.3, 3) or rgb(3, 0.1, 0.1)) * (on and 1 or 0.08)
  end
  if u.node then pcall(function() u.node:setPosition(u.pos); u.node:setOrientation(u.look, vec3(0, 1, 0)) end) end
  return gap
end

local function chaseUpdate(dt, me)
  if not (ENABLE_POLICE or ENABLE_HEAT) then return end
  local speed = me.speedKmh
  if chase.state == 'idle' then
    for _, z in ipairs(ENABLE_POLICE and ZONES.chase or {}) do
      if inZone(z, me.position) and speed > 15 then
        chase.state = 'countdown'
        chase.zone = z
        chase.countdown = 3.0
        chase.time = 0
        showBanner('POLICE', 'get moving. they are on you in 3', rgbm(0.3, 0.5, 1, 1), 3)
        break
      end
    end
    return
  end
  -- keep a trail even during the countdown so units have a road to follow
  chase.trailTimer = chase.trailTimer + dt
  if chase.trailTimer > 0.1 then
    chase.trailTimer = 0
    chase.trail[#chase.trail + 1] = { t = t, p = vec3(me.position.x, me.position.y, me.position.z) }
    if #chase.trail > 900 then table.remove(chase.trail, 1) end
  end
  if chase.state == 'countdown' then
    chase.countdown = chase.countdown - dt
    if chase.countdown <= 0 then
      chase.state = 'active'
      chaseActive = true
      broadcastRank()
      chase.stars = 1
      spawnUnit(me)
      showBanner('CHASE ON', 'one unit on you. outrun it or make it miss', rgbm(0.3, 0.5, 1, 1), 2.5)
    end
    return
  end
  chase.time = chase.time + dt
  hud.lastEvent = t
  -- sent back to the pits (server /pit, reset, teleport) while they are on you = caught
  local jumped = false
  pcall(function()
    if me.justJumped == true or me.isInPit == true then jumped = true end
    if chase.resetCount == nil then chase.resetCount = me.resetCounter end
    if me.resetCounter ~= nil and chase.resetCount ~= nil and me.resetCounter ~= chase.resetCount then jumped = true end
  end)
  if chase.lastPos and flatDist(me.position, chase.lastPos) > 60 then jumped = true end
  chase.lastPos = vec3(me.position.x, me.position.y, me.position.z)
  if jumped and chase.time > 1 then
    store.busts = store.busts + 1
    showBanner('BUSTED', 'back to the pits with them on you   ' .. XP.busted .. ' xp', rgbm(1, 0.3, 0.25, 1), 4)
    addXP(XP.busted, 'busted', rgbm(1, 0.3, 0.25, 1), true)
    endRun(true)
    chaseReset()
    return
  end
  local nearest = 1e9
  for i, u in ipairs(chase.units) do
    local ok, gap = pcall(driveUnit, i, u, dt, me)
    if ok and gap then nearest = math.min(nearest, gap) end
  end
  chase.nearest = nearest
  -- boxed in and slow = busted
  if nearest < 7 and speed < 30 then chase.pinTimer = (chase.pinTimer or 0) + dt else chase.pinTimer = 0 end
  if (chase.pinTimer or 0) > 4 then
    store.busts = store.busts + 1
    showBanner('BUSTED', 'pinned in   ' .. XP.busted .. ' xp', rgbm(1, 0.3, 0.25, 1), 4)
    addXP(XP.busted, 'busted', rgbm(1, 0.3, 0.25, 1), true)
    endRun(true)
    chaseReset()
    return
  end
  if nearest > 200 then chase.farTimer = chase.farTimer + dt else chase.farTimer = 0 end
  if chase.farTimer > 5 or chase.time > 300 then
    local bonus = XP.escape + XP.escapePerUnit * #chase.units + math.max(0, 120 - chase.time) + XP.copSpin * (chase.lost or 0)
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
      if nearest < 12 and speed < 50 then
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

-- flipped over: nobody wants to sit on their roof in the road, and it is not the police's win either
local flip = { timer = 0, cool = 0, shown = -1 }
local function flipUpdate(dt, me)
  if not FLIP_TO_PITS then return end
  if flip.cool > 0 then flip.cool = flip.cool - dt return end
  local over = false
  pcall(function() over = me.up ~= nil and me.up.y < 0.25 end)
  if not (over and me.speedKmh < 8) then flip.timer = 0 flip.shown = -1 return end
  flip.timer = flip.timer + dt
  if flip.timer < FLIP_SECONDS then
    local left = math.ceil(FLIP_SECONDS - flip.timer)
    if left ~= flip.shown then
      flip.shown = left
      showBanner('FLIPPED', 'back to the pits in ' .. left, rgbm(1, 0.6, 0.2, 1), 1.2)
    end
    return
  end
  flip.timer = 0
  flip.cool = 6
  if chase.state ~= 'idle' then
    showBanner('WRECKED', 'you flipped it. no bust, no xp lost. back to the pits', rgbm(1, 0.6, 0.2, 1), 4)
    chaseReset()
  else
    showBanner('FLIPPED', 'back to the pits', rgbm(1, 0.6, 0.2, 1), 3)
  end
  endRun(true)
  local ok = false
  pcall(function() ok = ac.tryToTeleportToPits() == true end)
  if not ok then event('could not teleport you. use the pause menu to go back to the pits', rgbm(1, 0.5, 0.4, 1)) end
end

local function chaseCrash(me)
  if chase.state ~= 'active' then return end
  chase.stars = math.min(5, (chase.stars or 1) + 1)
  if chase.stars >= COP_SECOND_UNIT_STARS and #chase.units < COP_MAX_UNITS and t - chase.lastSpawnT > 4 then
    chase.lastSpawnT = t
    spawnUnit(me)
    event('second unit joined', rgbm(0.4, 0.6, 1, 1))
  else
    event(chase.stars .. ' stars', rgbm(0.4, 0.6, 1, 1))
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
    heatCrash(me)
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
        draft.bank = draft.bank + dt * XP.draftPerSec * speedMult
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
                local mult = math.min(2.2, 1 + XP.streakStep * (streak - 1))
                local pts = (XP.nearMiss + close * 22 + speed / 20) * mult * (1 + (speedMult - 1) * 0.1)
                local label = close > 0.65 and 'INSANE NEAR MISS' or (close > 0.35 and 'CLOSE NEAR MISS' or 'NEAR MISS')
                if streak > 1 then label = label .. '  x' .. streak end
                addXP(pts, label, close > 0.65 and rgbm(1, 0.85, 0.2, 1) or rgbm(0, 0.94, 0.35, 1))
                if ENABLE_WANTED and i == wantedIndex then addXP(XP.bounty, 'BOUNTY HIT  ' .. driverName(i), GOLD) end
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

  flipUpdate(dt, me)
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
        elseif who > 0 then event(driverName(who) .. ' is WANTED   +' .. XP.bounty .. ' per near miss on them', RED, true) end
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

------------------------------------------------------------------ emotes

local emoteEvent = nil
pcall(function()
  emoteEvent = ac.OnlineEvent({ ac.StructItem.key('NLEmote4'), idx = ac.StructItem.byte() }, function(sender, data)
    if sender == nil or sender.index == 0 then return end
    local o = others[sender.index]
    if o then o.emote = EMOTES[data.idx] or '?'; o.emoteT = t end
  end)
end)
local myEmote = { text = nil, t = -10 }
local function sendEmote(i)
  if not emoteEvent or not EMOTES[i] then return end
  pcall(function() emoteEvent({ idx = i }, false) end)
  myEmote = { text = EMOTES[i], t = t }
  event(EMOTES[i], rgbm(1, 1, 1, 1), true)
end

------------------------------------------------------------------ start

local started, startTimer, syncTimer, startFails = false, 1.5, 0, 0
local promptsDue = -1

local function startup()
  rankIndex = rankFor(store.xp)
  backendLoad()
  if ENABLE_POLICE or ENABLE_RACE_ZONES then loadRemoteZones() end
  dailyRefresh()
  weeklyRefresh()
  if not store.cardsInit then cardCheck(true); store.cardsInit = true else cardCheck(true) end
  broadcastRank()
  promptsDue = t + 5        -- popups wait until the player is actually in the car
  started = true
  dlog('v' .. VERSION .. ' started, ' .. RANKS[rankIndex].name .. ' ' .. math.floor(store.xp) .. ' xp')
end

local function latePrompts()
  promptsDue = -1
  loginCheck()
  askName()
  menu.hintT = HINT_SECONDS
  if ENABLE_DAILY and #daily.list > 0 then
    local parts = {}
    for _, c in ipairs(daily.list) do parts[#parts + 1] = c.text .. (hasFlag(store.dailyDone, c.id) and ' (done)' or '') end
    showBanner('TODAY\'S CHALLENGES', table.concat(parts, '   |   '), GOLD, 8)
  end
  pcall(function() ui.toast(ui.Icons and ui.Icons.Trophy or 'fx:loading', 'No License Ranks v' .. VERSION .. ' loaded. Press ' .. MENU_KEY:upper() .. ' for the menu.') end)
end

function script.update(dt)
  t = t + dt
  if not started then
    startTimer = startTimer - dt
    if startTimer <= 0 then
      local ok, err = pcall(startup)
      if not ok then
        startFails = startFails + 1
        dlog('startup error (' .. startFails .. '): ' .. tostring(err))
        startTimer = 3
        if startFails >= 4 then started = true; promptsDue = t + 3 end
      end
    end
    return
  end
  if promptsDue >= 0 and t >= promptsDue then
    local paused = false
    pcall(function() local sim = ac.getSim(); paused = sim.isPaused or sim.isInMainMenu end)
    if not paused then
      local ok, err = pcall(latePrompts)
      if not ok then dlog('prompts error: ' .. tostring(err)); promptsDue = -1 end
    end
  end
  local ok, err = pcall(update, dt)
  if not ok and lastErr ~= tostring(err) then lastErr = tostring(err); dlog('error: ' .. lastErr) end
  if ENABLE_EMOTES then
    pcall(function()
      for i = 1, #EMOTES do
        if ui.keyboardButtonPressed(ui.KeyIndex['NumPad' .. i]) then sendEmote(i) end
      end
    end)
  end
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

function fmtK(n)
  n = math.floor(n)
  if n >= 100000 then return string.format('%dK', math.floor(n / 1000)) end
  if n >= 1000 then return string.format('%.1fK', n / 1000) end
  return tostring(n)
end

function text(txt, size, pos, col, font)
  ui.pushDWriteFont(font or F_MED)
  ui.dwriteDrawText(txt, size, pos, col)
  ui.popDWriteFont()
end

function textW(txt, size, font)
  ui.pushDWriteFont(font or F_MED)
  local w = ui.measureDWriteText(txt, size)
  ui.popDWriteFont()
  return w
end

function textC(txt, size, cx, y, col, font)
  local w = textW(txt, size, font)
  text(txt, size, vec2(cx - w.x / 2, y), col, font)
  return w
end

function easeOutBack(x)
  local c1, c3 = 1.70158, 2.70158
  return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

function mix(a, b, f) return rgbm(a.r + (b.r - a.r) * f, a.g + (b.g - a.g) * f, a.b + (b.b - a.b) * f, a.mult + (b.mult - a.mult) * f) end

-- small dark tile with a grey label and a white value
hudAnim = { pop = {}, last = {} }
-- value pop: when a tile's text changes it briefly scales up
function popFor(id, value)
  if hudAnim.last[id] ~= value then hudAnim.last[id] = value; hudAnim.pop[id] = 1 end
  local p = hudAnim.pop[id] or 0
  hudAnim.pop[id] = math.max(0, p - 0.08)
  return p
end

function tile(x, y, w, h, A, value, label, valCol, s, outline, id, accent)
  -- soft shadow + body + top accent line
  ui.drawRectFilled(vec2(x + 1 * s, y + 3 * s), vec2(x + w + 1 * s, y + h + 3 * s), rgbm(0, 0, 0, 0.35 * A), 6 * s)
  ui.drawRectFilled(vec2(x, y), vec2(x + w, y + h), rgbm(0.05, 0.055, 0.07, 0.86 * A), 6 * s)
  pcall(function() ui.drawRectFilledMultiColor(vec2(x, y), vec2(x + w, y + h * 0.5), rgbm(1, 1, 1, 0.06 * A), rgbm(1, 1, 1, 0.06 * A), rgbm(1, 1, 1, 0), rgbm(1, 1, 1, 0)) end)
  if accent then ui.drawRectFilled(vec2(x + 8 * s, y), vec2(x + w - 8 * s, y + 2 * s), withA(accent, 0.9 * A), 1 * s) end
  if outline then ui.drawRect(vec2(x, y), vec2(x + w, y + h), withA(outline, 0.9 * A), 6 * s, ui.CornerFlags.All, 1.5 * s) end
  local pop = id and popFor(id, value) or 0
  local k = 1 + 0.18 * pop
  if label then
    if pop > 0 and valCol then ui.drawCircleFilled(vec2(x + w / 2, y + 13 * s), 16 * s * pop, withA(valCol, 0.18 * pop * A), 20) end
    textC(value, 15 * s * k, x + w / 2, y + 5 * s - 2 * s * pop, valCol or rgbm(1, 1, 1, A), F_BOLD)
    textC(label, 8 * s, x + w / 2, y + 24 * s, rgbm(0.58, 0.6, 0.66, A))
  else
    textC(value, 17 * s * k, x + w / 2, y + (h - 20 * s) / 2 - 2 * s * pop, valCol or rgbm(1, 1, 1, A), F_BOLD)
  end
end

function drawCardImage(c, p1, p2, col)
  if not c then return end
  local uv1, uv2 = cardUV(c)
  if uv1 then ui.drawImage(cardSrc(c), p1, p2, col, uv1, uv2) else ui.drawImage(cardSrc(c), p1, p2, col) end
end

-- the plate: card as the background, badge on the left, name + rank over it. k = scale, a = alpha
function drawEmote(cx, y, k, txt, age)
  local a = math.min(1, age * 4) * math.min(1, (3.2 - age) * 2)
  if a <= 0 then return end
  local size = 13 * k
  local tw = textW(txt, size, F_BOLD).x
  local pw, ph = tw + 16 * k, size + 10 * k
  local rise = math.min(1, age * 3) * 6 * k
  local x0, y0 = cx - pw / 2, y - ph - 6 * k - rise
  ui.drawRectFilled(vec2(x0, y0), vec2(x0 + pw, y0 + ph), rgbm(1, 1, 1, 0.95 * a), ph / 2)
  text(txt, size, vec2(x0 + 8 * k, y0 + 5 * k), rgbm(0.05, 0.05, 0.06, a), F_BOLD)
end

function drawNameplate(cx, cy, k, a, name, R, card, isTop, prestige, wanted, fire, emote, emoteAge, frame)
  local W, H = 150 * k, 37.5 * k
  local x, y = cx - W / 2, cy - H - 10 * k
  if emote and emoteAge and emoteAge < 3.2 then drawEmote(cx, y - ((wanted or fire or isTop) and 14 * k or 0), k, emote, emoteAge) end
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
  ui.drawRect(vec2(x, y), vec2(x + W, y + H), withA(frameColour(frame, R), 0.9 * a), 3 * k, ui.CornerFlags.All, 1.2 * k)
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
    local y0 = sh * 0.03 + (1 - A) * -14 * s + math.sin(t * 1.3) * 1.5 * s

    -- row 1: proximity, speed, combo, pb, total multiplier
    local streakMult = math.min(2.2, 1 + XP.streakStep * math.max(0, streak - 1))
    local proxMult = 1 + lastClose * 2
    local total = speedMult * streakMult
    local sc = speedMult >= 8 and RED or (speedMult >= 5 and rgbm(1, 0.8, 0.2, A) or (speedMult >= 2 and withA(GREEN, A) or rgbm(1, 1, 1, A)))
    local cc = streak >= 5 and rgbm(1, 0.8, 0.2, A) or (streak >= 2 and withA(GREEN, A) or rgbm(1, 1, 1, A))
    tile(x0, y0, tw, th, A, string.format('%.1fX', proxMult), 'PROXIMITY', lastClose > 0.5 and rgbm(1, 0.8, 0.2, A) or nil, s, nil, 'prox', lastClose > 0.5 and GOLD or nil)
    tile(x0 + (tw + gap), y0, tw, th, A, string.format('%.1fX', speedMult), 'SPEED', withA(sc, A), s, nil, 'spd', speedMult >= 2 and sc or nil)
    tile(x0 + (tw + gap) * 2, y0, tw, th, A, 'x' .. streak, 'COMBO', cc, s, nil, 'cmb', streak >= 2 and cc or nil)
    tile(x0 + (tw + gap) * 3, y0, tw, th, A, fmtK(store.bestRun), 'PB', nil, s, nil, 'pb')
    local totCol = total >= 10 and GOLD or rgbm(1, 1, 1, 1)
    if total >= 5 then ui.drawCircleFilled(vec2(x0 + (tw + gap) * 4 + mw / 2, y0 + th / 2), (26 + 4 * math.sin(t * 6)) * s, withA(totCol, 0.1 * A), 24) end
    tile(x0 + (tw + gap) * 4, y0, mw, th, A, string.format('%.1fX', total), nil, withA(totCol, A), s, R.col, 'tot')

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
    ui.drawRectFilled(vec2(x0 + 1 * s, y1 + 4 * s), vec2(x0 + mainW + 1 * s, y1 + mh + 4 * s), rgbm(0, 0, 0, 0.4 * A), 6 * s)
    ui.drawRectFilled(vec2(x0, y1), vec2(x0 + mainW, y1 + mh), withA(fill, 0.95 * A), 6 * s)
    pcall(function() ui.drawRectFilledMultiColor(vec2(x0, y1), vec2(x0 + mainW, y1 + mh * 0.55), rgbm(1, 1, 1, 0.14 * A), rgbm(1, 1, 1, 0.14 * A), rgbm(1, 1, 1, 0), rgbm(1, 1, 1, 0)) end)
    if run.active and run.score > 0 and not run.lost then
      local sweep = (t * 0.6) % 1.4 - 0.2
      local sx = x0 + mainW * sweep
      pcall(function() ui.drawRectFilledMultiColor(vec2(sx - 40 * s, y1), vec2(sx + 40 * s, y1 + mh), rgbm(1, 1, 1, 0), rgbm(1, 1, 1, 0.12 * A), rgbm(1, 1, 1, 0.12 * A), rgbm(1, 1, 1, 0)) end)
    end
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
    local wpop = popFor('word', word)
    if sub then
      textC(word, 17 * s * (1 + 0.12 * wpop), x0 + mainW / 2, y1 + 5 * s - 2 * s * wpop, withA(textCol, A), F_BOLD)
      textC(sub, 8 * s, x0 + mainW / 2, y1 + 25 * s, (run.pb and not run.lost) and withA(GOLD, A) or withA(textCol, 0.7 * A), F_BOLD)
    else
      textC(word, 20 * s * (1 + 0.12 * wpop), x0 + mainW / 2, y1 + 8 * s - 2 * s * wpop, withA(textCol, A), F_BOLD)
    end
    -- run timer tile
    local rt = run.active and run.time or 0
    local tt = string.format('%02d:%02d', math.floor(rt / 60), math.floor(rt % 60))
    tile(x0 + mainW + gap, y1, mw, mh, A, tt, nil, run.lost and withA(RED, A) or rgbm(1, 1, 1, A), s, nil, nil, run.active and GREEN or nil)

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
    if boostActive() or adminBoostActive() then
      local bt = (adminBoostActive() and 2 or XP_BOOST.mult) .. 'X XP'
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
            drawNameplate(sp.x, sp.y, k, fade, o.tag or driverName(idx), RANKS[o.rank], CARDS[o.card or 0], o.best and topBest > 0 and o.best == topBest, o.prestige, idx == wantedIndex, o.fire, o.emote, o.emoteT and (t - o.emoteT) or nil, o.frame)
          end
        end
      end
    end
  end
end

------------------------------------------------------------------ menu (CSP online extras > No License Ranks)

function addLocalZone(kind, me)
  local p = me.position
  local name = store.zoneName ~= '' and store.zoneName or (kind == 'chase' and ('Police ' .. (#ZONES.chase + 1)) or ('Race ' .. (#ZONES.race + 1)))
  local z = normZone({ name = name, x = p.x, y = p.y, z = p.z, r = store.zoneR }, kind == 'race')
  if kind == 'chase' then ZONES.chase[#ZONES.chase + 1] = z else ZONES.race[#ZONES.race + 1] = z end
  store.zoneName = ''
  saveLocalZones()
  dlog('placed ' .. kind .. ' zone ' .. name)
end

------------------------------------------------------------------ UI kit (glass panels, pill tabs, icon atlas)

menuUI = { nameEdit = nil, tab = 1, search = '' }
DIM = rgbm(0.56, 0.58, 0.64, 1)
BLUE = rgbm(0, 0.47, 1, 1)
BORDER = rgbm(0.44, 0.44, 0.44, 1)
GLASS = rgbm(0.02, 0.02, 0.03, 0.78)
CARD = rgbm(0.06, 0.06, 0.075, 0.9)
anim = {}
ICONS = {
cards = {0, 0}, challenges = {1, 0}, leaderboard = {2, 0}, stats = {3, 0}, settings = {4, 0}, paint = {5, 0}, interior = {6, 0}, plate = {7, 0}, glow = {0, 1}, looks = {1, 1}, tune = {2, 1}, showroom = {3, 1}, save = {4, 1}, players = {5, 1}, weather = {6, 1}, server = {7, 1}, time = {0, 2}, police = {1, 2}, race = {2, 2}, lock = {3, 2}, check = {4, 2}, close = {5, 2}, star = {6, 2}, fire = {7, 2}, skull = {0, 3}, admin = {1, 3}, emote = {2, 3}, search = {3, 3}, chevron = {4, 3}, crown = {5, 3}, bolt = {6, 3}, rain = {7, 3}, snow = {0, 4}, sun = {1, 4}, moon = {2, 4}, ban = {3, 4}, kick = {4, 4}, pit = {5, 4}, warning = {6, 4}, key = {7, 4}, speed = {0, 5}, combo = {1, 5}, proximity = {2, 5}, medal = {3, 5}, wind = {4, 5}, car = {5, 5}, calendar = {6, 5}, gift = {7, 5}, copy = {0, 6}, paste = {1, 6}, reset = {2, 6}, wheel = {3, 6}, brake = {4, 6}, drop = {5, 6}, message = {6, 6}, eye = {7, 6}, eyeoff = {0, 7}, up = {1, 7}, info = {2, 7}, grip = {3, 7}, session = {4, 7}, xp = {5, 7}, target = {6, 7}, home = {7, 7}
}
ICON_COLS, ICON_ROWS = 8, 8


function ease(id, target, speed)
  local dt = 0.016
  pcall(function() dt = math.min(0.1, ac.getSim().dt or 0.016) end)
  local v = anim[id]
  if v == nil then v = target end
  v = v + (target - v) * math.min(1, dt * (speed or 14))
  anim[id] = v
  return v
end

function lerpC(a, b, f) return rgbm(a.r + (b.r - a.r) * f, a.g + (b.g - a.g) * f, a.b + (b.b - a.b) * f, a.mult + (b.mult - a.mult) * f) end

-- icon from the atlas
function icon(name, p, size, col)
  local c = ICONS[name]
  if not c then return end
  local u1 = vec2(c[1] / ICON_COLS, c[2] / ICON_ROWS)
  local u2 = vec2((c[1] + 1) / ICON_COLS, (c[2] + 1) / ICON_ROWS)
  pcall(function() ui.drawImage(ICON_ATLAS, p, p + vec2(size, size), col or rgbm(1, 1, 1, 1), u1, u2) end)
end

-- horizontal gradient fill (left colour -> right colour), falls back to flat
function hgrad(p1, p2, cl, cr, r)
  local ok = pcall(function() ui.drawRectFilledMultiColor(p1, p2, cl, cr, cr, cl) end)
  if not ok then ui.drawRectFilled(p1, p2, lerpC(cl, cr, 0.5), r or 0) end
end

-- glass box with the 1px dark border, as in the design
function glass(p1, p2, r, a)
  a = a or 1
  ui.drawRectFilled(p1 + vec2(1, 4), p2 + vec2(1, 4), rgbm(0, 0, 0, 0.2 * a), r)
  ui.drawRectFilled(p1, p2, withA(GLASS, a), r)
  ui.drawRect(p1, p2, rgbm(0.016, 0.012, 0.024, 0.72 * a), r, ui.CornerFlags.All, 1)
end

-- the blue pill (active) or dark pill (inactive), used for tabs and buttons
function pill(p, w, h, active, f, a)
  a = a or 1
  if active then
    ui.drawRectFilled(p, p + vec2(w, h), withA(BLUE, 0.21 * a), 12)
    hgrad(p, p + vec2(w, h), withA(BLUE, (0.85 + 0.15 * f) * a), withA(BLUE, 0.21 * a), 12)
    ui.drawRect(p, p + vec2(w, h), withA(BLUE, a), 12, ui.CornerFlags.All, 1)
  else
    ui.drawRectFilled(p, p + vec2(w, h), rgbm(0, 0, 0, (0.5 + 0.2 * f) * a), 12)
    ui.drawRect(p, p + vec2(w, h), lerpC(rgbm(0.016, 0.012, 0.024, 0.72), rgbm(0.5, 0.5, 0.52, 0.9), f), 12, ui.CornerFlags.All, 1)
  end
end

-- button. accent = any colour means "primary" (blue pill); nil = dark pill. optional icon name
function nlButton(label, w, accent, h, ic)
  h = h or 32
  local p = ui.getCursor()
  ui.invisibleButton('##b' .. label, vec2(w, h))
  local hov = ui.itemHovered()
  local clicked = ui.itemClicked(ui.MouseButton.Left)
  local f = ease('b' .. label, hov and 1 or 0)
  local shown = label:gsub('##.*$', '')
  if accent and accent ~= BLUE and accent ~= GOLD and accent ~= GREEN then
    -- custom colour pill (red for danger etc)
    ui.drawRectFilled(p, p + vec2(w, h), withA(accent, 0.18 + 0.1 * f), 12)
    ui.drawRect(p, p + vec2(w, h), withA(accent, 0.9), 12, ui.CornerFlags.All, 1)
  else
    pill(p, w, h, accent ~= nil, f)
  end
  local tw = textW(shown:upper(), 12, F_BOLD)
  local iw = ic and 18 or 0
  local x = p.x + (w - tw.x - iw) / 2
  if ic then icon(ic, vec2(x, p.y + (h - 14) / 2), 14, rgbm(1, 1, 1, 0.9)) end
  text(shown:upper(), 12, vec2(x + iw, p.y + (h - 14) / 2), rgbm(1, 1, 1, 0.85 + 0.15 * f), F_BOLD)
  return clicked
end

function nlToggle(label, on, w)
  local p = ui.getCursor()
  w = w or 260
  ui.invisibleButton('##t' .. label, vec2(w, 32))
  local hov = ui.itemHovered()
  local clicked = ui.itemClicked(ui.MouseButton.Left)
  local f = ease('tg' .. label, on and 1 or 0)
  local hf = ease('tgh' .. label, hov and 1 or 0)
  pill(p, w, 32, false, hf)
  ui.drawRectFilled(vec2(p.x + 10, p.y + 9), vec2(p.x + 38, p.y + 23), lerpC(rgbm(1, 1, 1, 0.12), BLUE, f), 7)
  ui.drawCircleFilled(vec2(p.x + 17 + 14 * f, p.y + 16), 5.5, rgbm(1, 1, 1, 0.95), 12)
  text(label:gsub('##.*$', ''):upper(), 11, vec2(p.x + 48, p.y + 9), rgbm(1, 1, 1, 0.85 + 0.15 * hf), F_BOLD)
  return clicked
end

function section(label, col, ic)
  local p = ui.getCursor()
  ui.dummy(vec2(10, 22))
  if ic then icon(ic, vec2(p.x, p.y + 2), 13, col or BLUE) end
  text(label:upper(), 10, vec2(p.x + (ic and 19 or 0), p.y + 3), rgbm(0.82, 0.84, 0.88, 1), F_BOLD)
  local tw = textW(label:upper(), 10, F_BOLD).x
  ui.drawRectFilled(vec2(p.x + (ic and 19 or 0) + tw + 10, p.y + 10), vec2(p.x + 560, p.y + 11), rgbm(1, 1, 1, 0.08))
end

TAB_ICONS = { admin = 'admin', cards = 'cards', challenges = 'challenges', leaderboard = 'leaderboard', stats = 'stats', settings = 'settings',
  paint = 'paint', interior = 'interior', plate = 'plate', glow = 'glow', looks = 'looks', tune = 'tune', showroom = 'showroom', save = 'save',
  players = 'players', ['time & weather'] = 'weather', server = 'server', camera = 'showroom' }

-- pill tabs with icons
function nlTabs(id, labels, state, w)
  local p = ui.getCursor()
  local h = 32
  -- measure, shrink padding until it fits on one row
  local pad = 26
  local total = 0
  local widths = {}
  repeat
    total = 0
    for i, label in ipairs(labels) do
      local ic = TAB_ICONS[label:lower()]
      widths[i] = textW(label:upper(), 11, F_BOLD).x + pad + (ic and 18 or 0)
      total = total + widths[i] + 6
    end
    if total > w then pad = pad - 2 end
  until total <= w or pad <= 12
  local x = p.x
  for i, label in ipairs(labels) do
    local ic = TAB_ICONS[label:lower()]
    local bw = widths[i]
    ui.setCursor(vec2(x, p.y))
    ui.invisibleButton('##tab' .. id .. i, vec2(bw, h))
    local hov = ui.itemHovered()
    if ui.itemClicked(ui.MouseButton.Left) then state.tab = i end
    local sel = state.tab == i
    local f = ease('tab' .. id .. i, hov and 1 or 0)
    pill(vec2(x, p.y), bw, h, sel, f)
    local tx = x + pad / 2
    if ic then icon(ic, vec2(tx, p.y + 9), 14, rgbm(1, 1, 1, sel and 1 or 0.7 + 0.3 * f)); tx = tx + 18 end
    text(label:upper(), 11, vec2(tx, p.y + 9), rgbm(1, 1, 1, sel and 1 or 0.7 + 0.3 * f), F_BOLD)
    x = x + bw + 6
  end
  ui.setCursor(vec2(p.x, p.y + h + 12))
end

function bar(frac, w, colr, id, h)
  h = h or 6
  local p = ui.getCursor()
  ui.dummy(vec2(w, h + 2))
  frac = math.max(0, math.min(1, frac))
  if id then frac = ease('bar' .. id, frac, 6) end
  ui.drawRectFilled(p, p + vec2(w, h), rgbm(1, 1, 1, 0.08), h / 2)
  if frac > 0 then hgrad(p, p + vec2(math.max(h, w * frac), h), withA(colr or BLUE, 1), withA(colr or BLUE, 0.45), h / 2) end
end

-- search box in the design style
function searchBox(id, value, w)
  local p = ui.getCursor()
  pill(p, w, 32, false, 0)
  icon('search', vec2(p.x + 12, p.y + 9), 14, rgbm(1, 1, 1, 0.5))
  ui.setCursor(vec2(p.x + 34, p.y + 5))
  ui.setNextItemWidth(w - 44)
  local v = value
  pcall(function() ui.pushStyleColor(ui.StyleColor.FrameBg, rgbm(0, 0, 0, 0)) end)
  v = ui.inputText('##' .. id, value)
  pcall(function() ui.popStyleColor() end)
  if value == '' and v == '' then text('SEARCH', 11, vec2(p.x + 34, p.y + 9), rgbm(1, 1, 1, 0.3), F_BOLD) end
  ui.setCursor(vec2(p.x, p.y + 40))
  return v
end

-- panel frame: 20px radius glass, 2px grey border, 64px header with its own bottom border
panelErr = {}
function drawPanel(id, title, subtitle, w, h, accent, fn, onClose, ic, keyName)
  local sim = ac.getSim()
  local f = ease('panel' .. id, 1, 10)
  local sc = 0.97 + 0.03 * f
  local pw, ph = w * sc, h * sc
  local px, py = (sim.windowWidth - pw) / 2, (sim.windowHeight - ph) / 2
  ui.transparentWindow('nl_' .. id, vec2(px - 24, py - 24), vec2(pw + 48, ph + 48), true, true, function()
    -- the list inside may be taller than the window, so ImGui happily scrolls the whole window on the mouse wheel.
    -- undo that: draw everything offset by the scroll (so nothing moves) and put the scroll back to zero
    local sy = 0
    pcall(function() sy = ui.getScrollY() or 0 end)
    if sy ~= 0 then pcall(function() ui.setScrollY(0, false, false) end) end
    local o = vec2(24, 24 + sy)
    ui.drawRectFilled(o + vec2(2, 8), o + vec2(pw + 2, ph + 8), rgbm(0, 0, 0, 0.35 * f), 20)
    ui.drawRectFilled(o, o + vec2(pw, ph), rgbm(0.016, 0.012, 0.024, 0.86 * f), 20)
    -- header
    hgrad(o, o + vec2(pw, 64), rgbm(0, 0, 0, 0.5 * f), rgbm(0.035, 0.035, 0.035, 0.16 * f), 20)
    ui.drawRectFilled(o + vec2(0, 62), o + vec2(pw, 64), withA(BORDER, 0.9 * f))
    ui.drawRect(o + vec2(1, 1), o + vec2(pw - 1, ph - 1), withA(BORDER, 0.9 * f), 20, ui.CornerFlags.All, 2)
    if ic then
      ui.drawRectFilled(o + vec2(18, 16), o + vec2(50, 48), withA(accent, 0.25 * f), 8)
      icon(ic, o + vec2(24, 22), 20, withA(accent, f))
    end
    text(title:upper(), 15, o + vec2(ic and 60 or 20, 17), rgbm(1, 1, 1, f), F_BOLD)
    if subtitle then text(subtitle:upper(), 8, o + vec2(ic and 60 or 20, 38), withA(DIM, f), F_BOLD) end
    -- key hint pill + close
    local kx = o.x + pw - 112
    if keyName then
      local kw = textW(keyName:upper(), 10, F_BOLD).x + 22
      kx = o.x + pw - 60 - kw
      pill(vec2(kx, o.y + 16), kw, 32, false, 0)
      text(keyName:upper(), 10, vec2(kx + 11, o.y + 26), rgbm(1, 1, 1, 0.75), F_BOLD)
    end
    ui.setCursor(o + vec2(pw - 50, 16))
    ui.invisibleButton('##close' .. id, vec2(32, 32))
    local hov = ui.itemHovered()
    local hf = ease('close' .. id, hov and 1 or 0)
    pill(o + vec2(pw - 50, 16), 32, 32, false, hf)
    icon('close', o + vec2(pw - 41, 25), 14, rgbm(1, 1, 1, 0.7 + 0.3 * hf))
    if ui.itemClicked(ui.MouseButton.Left) then onClose() end
    -- every new line starts at the content edge, not at the window edge
    ui.indent(o.x + 22)
    ui.setCursor(o + vec2(22, 80))
    -- if the content fails the panel still shows, with the reason on it, instead of silently vanishing
    local okf, errf = pcall(fn)
    if not okf then
      local e = tostring(errf)
      if panelErr[id] ~= e then panelErr[id] = e; dlog('panel ' .. id .. ' error: ' .. e) end
      text('THIS PANEL HIT AN ERROR', 12, o + vec2(22, 90), RED, F_BOLD)
      text(e:sub(1, 90), 9, o + vec2(22, 112), rgbm(1, 1, 1, 0.8))
      if #e > 90 then text(e:sub(91, 180), 9, o + vec2(22, 126), rgbm(1, 1, 1, 0.8)) end
      text('IT IS IN THE CSP LOG TOO (DOCUMENTS / ASSETTO CORSA / LOGS / CUSTOM_SHADERS_PATCH.LOG)', 7, o + vec2(22, 146), DIM, F_BOLD)
    end
    ui.unindent(o.x + 22)
  end)
end

-- style ImGui sliders / inputs to match
function pushKitStyle()
  pcall(function()
    ui.pushStyleColor(ui.StyleColor.FrameBg, rgbm(0, 0, 0, 0.5))
    ui.pushStyleColor(ui.StyleColor.FrameBgHovered, rgbm(0, 0, 0, 0.65))
    ui.pushStyleColor(ui.StyleColor.FrameBgActive, rgbm(0, 0, 0, 0.7))
    ui.pushStyleColor(ui.StyleColor.SliderGrab, BLUE)
    ui.pushStyleColor(ui.StyleColor.SliderGrabActive, withA(BLUE, 0.8))
    ui.pushStyleColor(ui.StyleColor.Header, withA(BLUE, 0.3))
    ui.pushStyleColor(ui.StyleColor.HeaderHovered, withA(BLUE, 0.45))
    ui.pushStyleColor(ui.StyleColor.Button, rgbm(0, 0, 0, 0.5))
    ui.pushStyleColor(ui.StyleColor.ButtonHovered, withA(BLUE, 0.5))
    ui.pushStyleVar(ui.StyleVar.FrameRounding, 10)
    ui.pushStyleVar(ui.StyleVar.GrabRounding, 10)
  end)
end
function popKitStyle()
  pcall(function() ui.popStyleColor(9); ui.popStyleVar(2) end)
end

-- scrollable area drawn in the same window (child windows draw at the wrong place in online scripts)
local scrolls = {}
function scrollArea(id, w, h, fn)
  local p = ui.getCursor()
  local st = scrolls[id] or { y = 0, content = h }
  scrolls[id] = st
  local hov = false
  pcall(function() hov = ui.rectHovered(p, p + vec2(w, h)) end)
  if hov then pcall(function() local wh = ui.mouseWheel(); if wh and wh ~= 0 then st.y = st.y - wh * 70 end end) end
  local maxY = math.max(0, st.content - h)
  st.y = math.max(0, math.min(st.y, maxY))
  st.vy = ease('scroll' .. id, st.y, 16)
  pcall(function() ui.pushClipRect(p, p + vec2(w, h), true) end)
  ui.setCursor(vec2(p.x, p.y - st.vy))
  fn()
  local endY = ui.getCursor().y + st.vy
  st.content = endY - p.y + 12
  pcall(function() ui.popClipRect() end)
  if st.content > h then
    local track = h - 8
    local th = math.max(24, track * h / st.content)
    local ty = p.y + 4 + (track - th) * (st.y / math.max(1, st.content - h))
    ui.drawRectFilled(vec2(p.x + w - 4, p.y + 4), vec2(p.x + w - 1, p.y + 4 + track), rgbm(1, 1, 1, 0.06), 2)
    ui.drawRectFilled(vec2(p.x + w - 4, ty), vec2(p.x + w - 1, ty + th), withA(BLUE, 0.7), 2)
  end
  ui.setCursor(vec2(p.x, p.y + h + 6))
end

function isTopRun()
  if sessionBest <= 0 then return false end
  for _, o in pairs(others) do if o.best and o.best > sessionBest then return false end end
  return true
end

-- calling card as a product card: picture, label, name, CHOOSE / EQUIPPED / LOCKED pill
function cardTile(i, c, w)
  local h = 118
  local p = ui.getCursor()
  ui.invisibleButton('##card' .. i, vec2(w, h))
  local hovered = ui.itemHovered()
  local clicked = ui.itemClicked(ui.MouseButton.Left)
  local unlocked = cardUnlocked(c)
  local selected = store.card == c.id
  local f = ease('card' .. i, hovered and 1 or 0)
  -- card body
  if selected then
    hgrad(p, p + vec2(w, h), withA(BLUE, 0.55), withA(BLUE, 0.12), 12)
    ui.drawRect(p, p + vec2(w, h), BLUE, 12, ui.CornerFlags.All, 1)
  else
    ui.drawRectFilled(p, p + vec2(w, h), rgbm(0, 0, 0, 0.5 + 0.15 * f), 12)
    ui.drawRect(p, p + vec2(w, h), lerpC(rgbm(0.016, 0.012, 0.024, 0.72), rgbm(0.5, 0.5, 0.52, 0.9), f), 12, ui.CornerFlags.All, 1)
  end
  -- picture
  local ix, iy, iw, ih = p.x + 8, p.y + 8, w - 16, (w - 16) / 4
  drawCardImage(c, vec2(ix, iy), vec2(ix + iw, iy + ih), unlocked and rgbm(1, 1, 1, 1) or rgbm(0.25, 0.25, 0.28, 1))
  ui.drawRect(vec2(ix, iy), vec2(ix + iw, iy + ih), rgbm(1, 1, 1, 0.08), 6, ui.CornerFlags.All, 1)
  if not unlocked then icon('lock', vec2(ix + iw / 2 - 8, iy + ih / 2 - 8), 16, rgbm(1, 1, 1, 0.8)) end
  if c.kind == 'a' then
    ui.drawRectFilled(vec2(ix + iw - 38, iy + 4), vec2(ix + iw - 4, iy + 16), rgbm(0, 0, 0, 0.7), 4)
    text('ANIM', 7, vec2(ix + iw - 33, iy + 6), rgbm(1, 1, 1, 0.9), F_BOLD)
  end
  if hasFlag(store.newCards, c.id) and not selected then
    ui.drawRectFilled(vec2(ix + 4, iy + 4), vec2(ix + 34, iy + 16), BLUE, 4)
    text('NEW', 7, vec2(ix + 9, iy + 6), rgbm(1, 1, 1, 1), F_BOLD)
  end
  -- label + name
  text(c.kind == 'a' and 'ANIMATED CARD' or 'CALLING CARD', 7, vec2(p.x + 10, iy + ih + 8), withA(DIM, 1), F_BOLD)
  text(c.name, 11, vec2(p.x + 10, iy + ih + 19), rgbm(1, 1, 1, 1), F_BOLD)
  -- pill at the bottom
  local by = p.y + h - 30
  local label, prim = 'CHOOSE', false
  if selected then label, prim = 'EQUIPPED', true
  elseif not unlocked then label = cardLockText(c) end
  if not unlocked then
    local pr = cardProgress(c)
    ui.drawRectFilled(vec2(p.x + 10, by), vec2(p.x + w - 10, by + 22), rgbm(0, 0, 0, 0.55), 11)
    if pr > 0 then hgrad(vec2(p.x + 10, by), vec2(p.x + 10 + (w - 20) * pr, by + 22), withA(BLUE, 0.6), withA(BLUE, 0.25), 11) end
    local lw = textW(label:upper(), 8, F_BOLD).x
    text(label:upper(), 8, vec2(p.x + w / 2 - lw / 2, by + 6), rgbm(1, 1, 1, 0.9), F_BOLD)
  else
    pill(vec2(p.x + 10, by), w - 20, 22, prim, f)
    local lw = textW(label, 9, F_BOLD).x
    text(label, 9, vec2(p.x + w / 2 - lw / 2, by + 5), rgbm(1, 1, 1, 1), F_BOLD)
  end
  if hovered and not unlocked then ui.setTooltip('Locked: ' .. cardLockText(c)) end
  return clicked and unlocked
end

function tabCards()
  local n, un = 0, 0
  for _, c in ipairs(CARDS) do n = n + 1; if cardUnlocked(c) then un = un + 1 end end
  local p = ui.getCursor()
  menuUI.search = searchBox('cardsearch', menuUI.search, 240)
  ui.setCursor(vec2(p.x + 256, p.y + 9))
  text(un .. ' / ' .. n .. ' UNLOCKED', 10, ui.getCursor(), DIM, F_BOLD)
  ui.setCursor(vec2(p.x + 256 + 110, p.y))
  if nlButton('Animated only', 150, menuUI.animOnly and BLUE or nil, 32, 'star') then menuUI.animOnly = not menuUI.animOnly end
  ui.setCursor(vec2(p.x, p.y + 44))
  local q = menuUI.search:lower()
  scrollArea('cards', 600, 400, function()
    local col = 0
    for i, c in ipairs(CARDS) do
      if (q == '' or c.name:lower():find(q, 1, true)) and (not menuUI.animOnly or c.kind == 'a') then
        if cardTile(i, c, 186) then selectCard(c) end
        col = col + 1
        if col < 3 then ui.sameLine(0, 10) else col = 0; ui.dummy(vec2(1, 10)) end
      end
    end
  end)
end

-- challenge / milestone row in the list style: icon, title, progress, reward pill
function goalRow(id, title, value, goal, xp, done, w, ic)
  local p = ui.getCursor()
  ui.invisibleButton('##goal' .. id, vec2(w, 52))
  local hov = ui.itemHovered()
  local f = ease('goalh' .. id, hov and 1 or 0)
  if done then
    hgrad(p, p + vec2(w, 52), withA(BLUE, 0.35 + 0.1 * f), withA(BLUE, 0.06), 12)
    ui.drawRect(p, p + vec2(w, 52), withA(BLUE, 0.8), 12, ui.CornerFlags.All, 1)
  else
    ui.drawRectFilled(p, p + vec2(w, 52), rgbm(0, 0, 0, 0.5 + 0.15 * f), 12)
    ui.drawRect(p, p + vec2(w, 52), lerpC(rgbm(0.016, 0.012, 0.024, 0.72), rgbm(0.5, 0.5, 0.52, 0.9), f), 12, ui.CornerFlags.All, 1)
  end
  ui.drawRectFilled(vec2(p.x + 10, p.y + 10), vec2(p.x + 42, p.y + 42), done and withA(BLUE, 0.35) or rgbm(1, 1, 1, 0.06), 8)
  icon(done and 'check' or (ic or 'target'), vec2(p.x + 18, p.y + 18), 16, done and rgbm(1, 1, 1, 1) or withA(BLUE, 1))
  text(title, 12, vec2(p.x + 52, p.y + 9), rgbm(1, 1, 1, 1), F_BOLD)
  local frac = math.min(1, value / goal)
  if done then
    text('COMPLETED', 8, vec2(p.x + 52, p.y + 30), withA(BLUE, 1), F_BOLD)
  else
    local fe = ease('goal' .. id, frac, 6)
    local bw = w - 52 - 150
    ui.drawRectFilled(vec2(p.x + 52, p.y + 33), vec2(p.x + 52 + bw, p.y + 38), rgbm(1, 1, 1, 0.08), 2.5)
    if fe > 0 then hgrad(vec2(p.x + 52, p.y + 33), vec2(p.x + 52 + math.max(5, bw * fe), p.y + 38), BLUE, withA(BLUE, 0.4), 2.5) end
    local pv = fmt(math.min(value, goal)) .. ' / ' .. fmt(goal)
    text(pv, 8, vec2(p.x + 52 + bw + 8, p.y + 31), DIM, F_BOLD)
  end
  -- reward pill
  local r = '+' .. fmt(xp) .. ' XP'
  local rw = textW(r, 10, F_BOLD).x + 24
  pill(vec2(p.x + w - rw - 10, p.y + 12), rw, 28, done, f)
  text(r, 10, vec2(p.x + w - rw + 2, p.y + 20), done and rgbm(1, 1, 1, 1) or GOLD, F_BOLD)
  ui.dummy(vec2(1, 4))
end

function tabChallenges()
  scrollArea('chal', 600, 440, function()
    local w = 576
    if ENABLE_DAILY then
      section('today', BLUE, 'calendar')
      for _, c in ipairs(daily.list) do goalRow(c.id, c.text, dailyProgress(c), c.goal, c.xp, hasFlag(store.dailyDone, c.id), w, 'target') end
      text((store.dailyCount .. ' DAILY CHALLENGES COMPLETED IN TOTAL'), 8, ui.getCursor() + vec2(2, 0), DIM, F_BOLD)
      ui.dummy(vec2(1, 14))
    end
    if ENABLE_WEEKLY and weekly.item then
      section('this week', BLUE, 'gift')
      local c = weekly.item
      goalRow('week', c.text, store[c.key] or 0, c.goal, c.xp, store.weeklyDone, w, 'gift')
    end
    if ENABLE_LOGIN_STREAK then
      section('login streak', BLUE, 'bolt')
      local p = ui.getCursor()
      ui.dummy(vec2(w, 52))
      ui.drawRectFilled(p, p + vec2(w, 52), rgbm(0, 0, 0, 0.5), 12)
      ui.drawRect(p, p + vec2(w, 52), rgbm(0.016, 0.012, 0.024, 0.72), 12, ui.CornerFlags.All, 1)
      for d = 1, 7 do
        local on = d <= ((store.loginStreak - 1) % 7) + 1
        local cx, cy = p.x + 28 + (d - 1) * 34, p.y + 26
        if on then ui.drawCircleFilled(vec2(cx, cy), 11, BLUE, 20) else ui.drawCircle(vec2(cx, cy), 11, rgbm(1, 1, 1, 0.15), 20, 1) end
        text(tostring(d), 9, vec2(cx - 3, cy - 6), on and rgbm(1, 1, 1, 1) or DIM, F_BOLD)
      end
      text('DAY ' .. store.loginStreak, 12, vec2(p.x + 280, p.y + 11), rgbm(1, 1, 1, 1), F_BOLD)
      text('+' .. fmt(math.min(5000, (store.loginStreak + 1) * 500)) .. ' XP TOMORROW', 8, vec2(p.x + 280, p.y + 30), DIM, F_BOLD)
    end
    section('milestones', BLUE, 'medal')
    for _, m in ipairs(MILESTONES) do goalRow(m.id, m.text, store[m.key] or 0, m.goal, m.xp, hasFlag(store.milestonesDone, m.id), w, 'medal') end
  end)
end

function tabLeaderboard()
  local rows = { { name = myTag(), rank = rankIndex, xp = store.xp, best = sessionBest, me = true, top = sessionTop, prestige = store.prestige, wanted = wantedIndex == 0 } }
  for idx, o in pairs(others) do
    local c = ac.getCar(idx)
    if c and c.isConnected then rows[#rows + 1] = { name = o.tag or driverName(idx), rank = o.rank, xp = o.xp or 0, best = o.best or 0, top = o.top or 0, prestige = o.prestige or 0, wanted = idx == wantedIndex } end
  end
  menuUI.lbTab = menuUI.lbTab or 1
  local keys = { 'best', 'top', 'xp' }
  local p = ui.getCursor()
  for i, lbl in ipairs({ 'Best runs', 'Top speed', 'Ranks' }) do
    if nlButton(lbl, 130, menuUI.lbTab == i and BLUE or nil, 32) then menuUI.lbTab = i end
    if i < 3 then ui.sameLine(0, 8) end
  end
  ui.dummy(vec2(1, 8))
  local key = keys[menuUI.lbTab]
  table.sort(rows, function(a, b) return a[key] > b[key] end)
  local maxv = math.max(1, rows[1][key])
  scrollArea('lb', 600, 390, function()
    for i, r in ipairs(rows) do
      local q = ui.getCursor()
      ui.invisibleButton('##lbr' .. i, vec2(576, 46))
      local f = ease('lbr' .. i, ui.itemHovered() and 1 or 0)
      if r.me then hgrad(q, q + vec2(576, 46), withA(BLUE, 0.4), withA(BLUE, 0.08), 12); ui.drawRect(q, q + vec2(576, 46), withA(BLUE, 0.8), 12, ui.CornerFlags.All, 1)
      else ui.drawRectFilled(q, q + vec2(576, 46), rgbm(0, 0, 0, 0.5 + 0.15 * f), 12); ui.drawRect(q, q + vec2(576, 46), rgbm(0.016, 0.012, 0.024, 0.72), 12, ui.CornerFlags.All, 1) end
      -- position
      if i <= 3 then ui.drawCircleFilled(vec2(q.x + 24, q.y + 23), 12, i == 1 and GOLD or (i == 2 and rgbm(0.75, 0.77, 0.82, 1) or rgbm(0.72, 0.45, 0.2, 1)), 20) end
      text(tostring(i), 11, vec2(q.x + (i >= 10 and 18 or 21), q.y + 16), i <= 3 and rgbm(0.05, 0.05, 0.05, 1) or DIM, F_BOLD)
      ui.drawImage(RANKS[r.rank].icon, vec2(q.x + 44, q.y + 7), vec2(q.x + 76, q.y + 39), rgbm(1, 1, 1, 1))
      text(r.name .. (r.prestige > 0 and ('  ' .. string.rep('*', math.min(5, r.prestige))) or ''), 12, vec2(q.x + 86, q.y + 8), rgbm(1, 1, 1, 1), F_BOLD)
      text(RANKS[r.rank].name:upper(), 8, vec2(q.x + 86, q.y + 28), RANKS[r.rank].col, F_BOLD)
      if r.wanted then
        ui.drawRectFilled(vec2(q.x + 250, q.y + 15), vec2(q.x + 306, q.y + 31), RED, 8)
        text('WANTED', 8, vec2(q.x + 258, q.y + 19), rgbm(1, 1, 1, 1), F_BOLD)
      end
      local v = key == 'xp' and (fmt(r.xp) .. ' XP') or (key == 'best' and (fmt(r.best) .. ' PTS') or (math.floor(r.top) .. ' KM/H'))
      local vw = textW(v, 12, F_BOLD).x
      text(v, 12, vec2(q.x + 562 - vw, q.y + 9), rgbm(1, 1, 1, 1), F_BOLD)
      local fr = r[key] / maxv
      ui.drawRectFilled(vec2(q.x + 380, q.y + 32), vec2(q.x + 562, q.y + 35), rgbm(1, 1, 1, 0.08), 1.5)
      hgrad(vec2(q.x + 380, q.y + 32), vec2(q.x + 380 + 182 * fr, q.y + 35), BLUE, withA(BLUE, 0.4), 1.5)
      ui.dummy(vec2(1, 4))
    end
  end)
end

function statTile(x, y, w, label, value, ic, col)
  ui.drawRectFilled(vec2(x, y), vec2(x + w, y + 64), rgbm(0, 0, 0, 0.5), 12)
  ui.drawRect(vec2(x, y), vec2(x + w, y + 64), rgbm(0.016, 0.012, 0.024, 0.72), 12, ui.CornerFlags.All, 1)
  ui.drawRectFilled(vec2(x + 10, y + 16), vec2(x + 42, y + 48), withA(col or BLUE, 0.2), 8)
  icon(ic, vec2(x + 18, y + 24), 16, col or BLUE)
  text(tostring(value), 15, vec2(x + 52, y + 13), rgbm(1, 1, 1, 1), F_BOLD)
  text(label:upper(), 7, vec2(x + 52, y + 36), DIM, F_BOLD)
end

function tabStats()
  scrollArea('stats', 600, 440, function()
    section('driving', BLUE, 'car')
    local p = ui.getCursor()
    ui.dummy(vec2(576, 64))
    statTile(p.x, p.y, 138, 'km driven', fmt(store.km), 'car')
    statTile(p.x + 146, p.y, 138, 'near misses', fmt(store.nearMisses), 'proximity', GREEN)
    statTile(p.x + 292, p.y, 138, 'overtakes', fmt(store.overtakes), 'chevron')
    statTile(p.x + 438, p.y, 138, 'contacts', fmt(store.crashes), 'warning', RED)
    ui.dummy(vec2(1, 8))
    p = ui.getCursor()
    ui.dummy(vec2(576, 64))
    statTile(p.x, p.y, 138, 'top speed', math.floor(store.topSpeed) .. ' km/h', 'speed')
    statTile(p.x + 146, p.y, 138, 'best run', fmt(store.bestRun), 'medal', GOLD)
    statTile(p.x + 292, p.y, 138, 'best combo', 'x' .. store.bestStreak, 'combo')
    statTile(p.x + 438, p.y, 138, 'race wins', store.duelWins .. ' / ' .. store.duels, 'race', GOLD)
    ui.dummy(vec2(1, 8))
    p = ui.getCursor()
    ui.dummy(vec2(576, 64))
    statTile(p.x, p.y, 138, 'escapes', store.escapes, 'police')
    statTile(p.x + 146, p.y, 138, 'busted', store.busts, 'skull', RED)
    local n, total = 0, 0
    for _, c in ipairs(CARDS) do total = total + 1; if cardUnlocked(c) then n = n + 1 end end
    statTile(p.x + 292, p.y, 138, 'cards', n .. ' / ' .. total, 'cards')
    statTile(p.x + 438, p.y, 138, 'dailies done', store.dailyCount, 'calendar')
    if ENABLE_PRESTIGE then
      section('prestige', BLUE, 'star')
      p = ui.getCursor()
      ui.dummy(vec2(576, 64))
      hgrad(p, p + vec2(576, 64), withA(GOLD, 0.25), withA(GOLD, 0.04), 12)
      ui.drawRect(p, p + vec2(576, 64), withA(GOLD, 0.6), 12, ui.CornerFlags.All, 1)
      if store.prestige > 0 then text(string.rep('*', math.min(10, store.prestige)) .. '  PRESTIGE ' .. store.prestige .. '   +' .. (store.prestige * 5) .. '% XP ON EVERYTHING', 12, vec2(p.x + 14, p.y + 12), GOLD, F_BOLD)
      else text('NO STARS YET', 12, vec2(p.x + 14, p.y + 12), rgbm(1, 1, 1, 1), F_BOLD) end
      if rankIndex >= #RANKS then
        text('Back to Rookie, a star on your card, +5% xp for good. Cards stay.', 9, vec2(p.x + 14, p.y + 36), DIM)
        ui.setCursor(vec2(p.x + 420, p.y + 16))
        if nlButton('Prestige now', 140, GOLD, 32, 'star') then
          store.prestige = store.prestige + 1
          store.xp = 0
          rankIndex = 1
          showBanner('PRESTIGE ' .. store.prestige, 'back to Rookie. +' .. (store.prestige * 5) .. '% xp forever', GOLD, 6)
          broadcastRank()
          backendSave()
        end
        ui.setCursor(vec2(p.x, p.y + 68))
      else
        text('Reach NO LICENSE (rank 27) to prestige.', 9, vec2(p.x + 14, p.y + 36), DIM)
      end
    end
    section('how xp works', BLUE, 'info')
    for _, line in ipairs({
      'Near misses are the main earner. Closer = more. Chain them for a combo, go faster for a speed multiplier.',
      'A crash costs ' .. XP.crashFlat .. ' xp plus 30% of the run you were on. You never lose a rank you have reached.',
      'Draft behind another player above 120 km/h for xp. x10 combo puts you ON FIRE for the whole server to see.',
      'Hold the best run of the night and you are WANTED: 1.5x xp, but everyone gets a bounty for near missing you.',
      'Crash ' .. HEAT_CRASHES .. ' times in ' .. HEAT_WINDOW .. ' s and the police come. Lose them for big xp, get pinned and lose some.',
      'XP boost ' .. XP_BOOST.mult .. 'x between ' .. XP_BOOST.hours[1] .. ':00 and ' .. (XP_BOOST.hours[#XP_BOOST.hours] + 1) .. ':00.',
    }) do text(line, 9, ui.getCursor() + vec2(4, 0), DIM); ui.dummy(vec2(1, 15)) end
  end)
end

FRAMES = { { 'Rank colour', nil }, { 'Blue', BLUE }, { 'Gold', GOLD }, { 'White', rgbm(1, 1, 1, 1) }, { 'Green', GREEN }, { 'Red', RED }, { 'Purple', rgbm(0.75, 0.35, 1, 1) }, { 'Ice', rgbm(0.6, 0.85, 1, 1) } }
function frameColour(i, R)
  local f = FRAMES[(i or 0) + 1]
  return (f and f[2]) or R.col
end

function tabSettings()
  scrollArea('set', 600, 440, function()
    pushKitStyle()
    section('name over your car', BLUE, 'cards')
    if menuUI.nameEdit == nil then menuUI.nameEdit = myTag() end
    local p = ui.getCursor()
    pill(p, 300, 32, false, 0)
    ui.setCursor(vec2(p.x + 12, p.y + 5))
    ui.setNextItemWidth(276)
    pcall(function() ui.pushStyleColor(ui.StyleColor.FrameBg, rgbm(0, 0, 0, 0)) end)
    menuUI.nameEdit = ui.inputText('##tag', menuUI.nameEdit)
    pcall(function() ui.popStyleColor() end)
    ui.setCursor(vec2(p.x + 310, p.y))
    if nlButton('Save name', 130, BLUE, 32, 'check') then
      local v = menuUI.nameEdit:gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 15)
      if v ~= '' then store.tag = v; broadcastRank() end
      menuUI.nameEdit = myTag()
    end
    section('card frame colour', BLUE, 'paint')
    for i, f in ipairs(FRAMES) do
      local col = f[2] or RANKS[rankIndex].col
      local q = ui.getCursor()
      ui.invisibleButton('##fr' .. i, vec2(32, 32))
      local hov = ui.itemHovered()
      if ui.itemClicked(ui.MouseButton.Left) then store.frame = i - 1; broadcastRank() end
      local hf = ease('fr' .. i, hov and 1 or 0)
      ui.drawCircleFilled(vec2(q.x + 16, q.y + 16), 11 + 2 * hf, col, 24)
      if store.frame == i - 1 then ui.drawCircle(vec2(q.x + 16, q.y + 16), 15, rgbm(1, 1, 1, 1), 24, 2) end
      if hov then ui.setTooltip(f[1]) end
      if i < #FRAMES then ui.sameLine(0, 10) end
    end
    section('menu key', BLUE, 'key')
    if menuButton then
      local okc = pcall(function() menuButton:control(vec2(180, 28)) end)
      if not okc then ui.text('current key: ' .. MENU_KEY) end
    else
      ui.text('current key: ' .. MENU_KEY)
    end
    section('display', BLUE, 'eye')
    if nlToggle('Show other players\' cards and names', store.showOthersCards, 340) then store.showOthersCards = not store.showOthersCards end
    ui.dummy(vec2(1, 4))
    if nlToggle('Always show the HUD', store.alwaysShow, 340) then store.alwaysShow = not store.alwaysShow end
    ui.dummy(vec2(1, 6))
    ui.setNextItemWidth(340)
    store.hudScale = ui.slider('##hs', store.hudScale, 0.6, 1.8, 'HUD size: %.2f')
    ui.setNextItemWidth(340)
    store.nameplateScale = ui.slider('##ns', store.nameplateScale, 0.6, 1.6, 'Card size over cars: %.2f')
    if ENABLE_EMOTES then
      section('emotes  (numpad 1 - ' .. #EMOTES .. ')', BLUE, 'emote')
      for i, e in ipairs(EMOTES) do
        if nlButton(i .. '  ' .. e, 88, nil, 32) then sendEmote(i) end
        if i < #EMOTES then ui.sameLine(0, 6) end
      end
    end
    if ENABLE_FLASH_RACE then
      section('flash race', BLUE, 'race')
      text('Flash your headlights twice at someone close by (under 60 km/h). They get an Accept / Decline popup. ' .. RACE_GET_READY .. ' s to line up, then ' .. RACE_SECONDS .. ' s. In front at the end wins. Flip = loss.', 9, ui.getCursor() + vec2(4, 0), DIM)
      ui.dummy(vec2(1, 18))
      if duel.state ~= 'idle' and nlButton('Cancel race', 140, RED, 32, 'close') then duelCancel(true) end
    end
    if chase.state ~= 'idle' and nlButton('Cancel chase', 140, RED, 32, 'close') then chaseReset() end
    section('admin', RED, 'admin')
    if admin.unlocked then
      text('UNLOCKED ON THIS PC.   SERVER LINK: ' .. (admin.simAdmin and 'YES' or (admin.chatAdmin and 'SENT' or 'NO')), 7, ui.getCursor() + vec2(2, 0), DIM, F_BOLD)
      ui.dummy(vec2(1, 12))
      if nlButton('Open admin panel', 190, RED, 32, 'admin') then admin.open = true; anim['paneladmin'] = 0; menu.open = false end
      ui.sameLine(0, 8)
      if nlButton('Lock', 90, nil, 32, 'lock') then adminLock() end
    else
      text('ADMINS ONLY. PRESS ' .. ADMIN_KEY:upper() .. ' OR THE BUTTON AND TYPE THE ADMIN PASSWORD ONCE.', 7, ui.getCursor() + vec2(2, 0), DIM, F_BOLD)
      ui.dummy(vec2(1, 12))
      if nlButton('Admin login', 150, RED, 32, 'key') then adminToggle() end
    end
    text('ADMIN KEY (CLICK TO REBIND):', 8, ui.getCursor() + vec2(4, 2), DIM, F_BOLD)
    ui.dummy(vec2(1, 16))
    if adminButton then
      local okc = pcall(function() adminButton:control(vec2(180, 28)) end)
      if not okc then ui.text('current key: ' .. ADMIN_KEY) end
    else
      ui.text('current key: ' .. ADMIN_KEY)
    end
    text('OR USE THE ADMIN TAB AT THE TOP OF THIS MENU.', 7, ui.getCursor() + vec2(4, 2), DIM, F_BOLD)
    ui.dummy(vec2(1, 14))
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
    popKitStyle()
  end)
end

function drawMenu()
    local R = RANKS[rankIndex]
    local nxt = RANKS[rankIndex + 1]
    local W = 600
    local p = ui.getCursor()
    -- profile strip: card preview + rank + xp bar + badges
    ui.dummy(vec2(W, 110))
    ui.drawRectFilled(p, p + vec2(W, 110), rgbm(0, 0, 0, 0.45), 12)
    ui.drawRect(p, p + vec2(W, 110), rgbm(0.016, 0.012, 0.024, 0.72), 12, ui.CornerFlags.All, 1)
    local k = 2.2
    local cw, ch = 150 * k, 37.5 * k
    drawNameplate(p.x + 14 + cw / 2, p.y + 12 + ch + 10 * k, k, 1, myTag(), R, myCard(), isTopRun(), store.prestige, wantedIndex == 0, onFire, myEmote.text, t - myEmote.t, store.frame)
    local tx = p.x + cw + 34
    text(R.name:upper(), 20, vec2(tx, p.y + 14), R.col, F_BOLD)
    text('RANK ' .. rankIndex .. ' / ' .. #RANKS .. (store.prestige > 0 and ('   PRESTIGE ' .. store.prestige) or '') .. '   ' .. fmt(store.xp) .. ' XP', 8, vec2(tx, p.y + 40), DIM, F_BOLD)
    if nxt then
      local f = ease('hdrbar', (store.xp - R.xp) / (nxt.xp - R.xp), 6)
      ui.drawRectFilled(vec2(tx, p.y + 58), vec2(tx + 220, p.y + 64), rgbm(1, 1, 1, 0.08), 3)
      hgrad(vec2(tx, p.y + 58), vec2(tx + 220 * math.max(0.02, math.min(1, f)), p.y + 64), R.col, withA(R.col, 0.4), 3)
      text(fmt(nxt.xp - store.xp) .. ' TO ' .. nxt.name:upper(), 8, vec2(tx, p.y + 70), DIM, F_BOLD)
    else
      text('MAX RANK', 8, vec2(tx, p.y + 70), GOLD, F_BOLD)
    end
    local badges = {}
    local newN = countNewCards()
    if newN > 0 then badges[#badges + 1] = { newN .. ' NEW CARD' .. (newN > 1 and 'S' or ''), BLUE } end
    if boostActive() then badges[#badges + 1] = { XP_BOOST.mult .. 'X XP', GOLD } end
    if adminBoostActive() then badges[#badges + 1] = { '2X XP EVENT', GOLD } end
    if wantedIndex == 0 then badges[#badges + 1] = { 'WANTED', RED } end
    if admin.unlocked then badges[#badges + 1] = { 'ADMIN  ' .. ADMIN_KEY:upper(), RED } end
    local bx = tx
    for _, b in ipairs(badges) do
      local bw = textW(b[1], 8, F_BOLD).x + 16
      if b[1]:sub(1, 5) == 'ADMIN' then
        ui.setCursor(vec2(bx, p.y + 86))
        ui.invisibleButton('##adminbadge', vec2(bw, 16))
        if ui.itemClicked(ui.MouseButton.Left) then admin.open = true; anim['paneladmin'] = 0; menu.open = false end
      end
      ui.drawRectFilled(vec2(bx, p.y + 86), vec2(bx + bw, p.y + 102), withA(b[2], 0.9), 8)
      text(b[1], 8, vec2(bx + 8, p.y + 90), b[2] == GOLD and rgbm(0.05, 0.05, 0.05, 1) or rgbm(1, 1, 1, 1), F_BOLD)
      bx = bx + bw + 6
    end
    ui.setCursor(vec2(p.x, p.y + 120))
    nlTabs('m', { 'Cards', 'Challenges', 'Leaderboard', 'Stats', 'Settings', 'Admin' }, menuUI, W)
    local okt, errt
    if menuUI.tab == 1 then okt, errt = pcall(tabCards)
    elseif menuUI.tab == 2 then okt, errt = pcall(tabChallenges)
    elseif menuUI.tab == 3 then okt, errt = pcall(tabLeaderboard)
    elseif menuUI.tab == 4 then okt, errt = pcall(tabStats)
    elseif menuUI.tab == 5 then okt, errt = pcall(tabSettings)
    else okt, errt = pcall(tabAdmin) end
    if not okt then text(('TAB ERROR: ' .. tostring(errt)):sub(1, 120), 8, ui.getCursor() + vec2(4, 4), RED, F_BOLD); dlog('tab error: ' .. tostring(errt)) end
end

pcall(function()
  local icn = ui.Icons and (ui.Icons.Trophy or ui.Icons.Star or ui.Icons.Settings) or nil
  ui.registerOnlineExtra(icn, 'No License Ranks', nil, drawMenu)
end)

-- hotkey (rebindable in Settings) opens the same menu as a dialog
pcall(function()
  menuButton = ac.ControlButton('NL_RANKS_MENU', { keyboard = { key = ui.KeyIndex[MENU_KEY] or ui.KeyIndex.End } })
end)

function menuKeyPressed()
  if menuButton then
    local ok, v = pcall(function() return menuButton:pressed() end)
    if ok then return v == true end
  end
  local ok, v = pcall(function() return ui.keyboardButtonPressed(ui.KeyIndex[MENU_KEY] or ui.KeyIndex.End) end)
  return ok and v == true
end

-- in-game window with its own frame (drawn with ui.transparentWindow so it works while driving)
local panelAnim = {}
function openMenu()
  menu.open = not menu.open
  if menu.open then anim['panelmain'] = 0 end
end

------------------------------------------------------------------ admin panel (only after /admin <password> in chat)

admin = { open = false, login = false, unlocked = false, tab = 1, tabX = 0, tabW = 0, say = '', time = 20, transition = 60, rain = 0, wet = 0, water = 0, grip = 1.0,
  checkT = 0, boostMin = 30, announce = '', restrict = 0, ballast = 0, giveXP = 5000, isAdmin = false, simAdmin = false, chatAdmin = false, sentAt = -1,
  pw = '', serverPw = '', newPw = '', newHash = '', wrong = 0, lockT = 0, shake = 0, spectating = -1, log = {} }
adminEvent = nil
adminBoost = { until_ = -1, mult = 1 }

WEATHERS = {
  { 'Clear', 15 }, { 'Few clouds', 16 }, { 'Scattered', 17 }, { 'Broken clouds', 18 }, { 'Overcast', 19 },
  { 'Fog', 20 }, { 'Mist', 21 }, { 'Haze', 23 }, { 'Windy', 31 },
  { 'Light drizzle', 3 }, { 'Drizzle', 4 }, { 'Light rain', 6 }, { 'Rain', 7 }, { 'Heavy rain', 8 },
  { 'Thunderstorm', 1 }, { 'Heavy storm', 2 }, { 'Light snow', 9 }, { 'Snow', 10 }, { 'Hail', 32 },
}
TIMES = { { 'Dawn', 5.5 }, { 'Sunrise', 6.5 }, { 'Morning', 9 }, { 'Noon', 12 }, { 'Afternoon', 15 }, { 'Golden', 17.5 }, { 'Sunset', 19 }, { 'Dusk', 20 }, { 'Night', 22 }, { 'Midnight', 0 } }

-- password hash: two rolling sums, nothing fancy, just so the plain password is not in a public file
function pwHash(s)
  local h1, h2 = 7, 11
  for i = 1, #s do
    local b = s:byte(i)
    h1 = (h1 * 31 + b) % 1000000007
    h2 = (h2 * 131 + b * 7 + i) % 998244353
  end
  return string.format('%d-%d', h1, h2)
end

function adminLog(s)
  admin.log[#admin.log + 1] = s
  if #admin.log > 8 then table.remove(admin.log, 1) end
end

function cmd(c)
  local ok, err = pcall(function() ac.sendChatMessage(c) end)
  adminLog((ok and '> ' or 'failed: ') .. c)
  if not ok then dlog('chat command failed: ' .. tostring(err)) end
end

-- remembered unlock: the stored hash has to match the one in this file, so changing the password locks everyone out again
if store.adminKey ~= '' and store.adminKey == ADMIN_PASSWORD_HASH then admin.unlocked = true end

function adminUnlock(pw)
  if admin.lockT > t then return false end
  if pwHash(pw) == ADMIN_PASSWORD_HASH then
    admin.unlocked = true
    admin.login = false
    admin.open = true
    admin.wrong = 0
    anim['paneladmin'] = 0
    store.adminKey = ADMIN_PASSWORD_HASH
    pcall(function() ui.toast(ui.Icons and ui.Icons.Confirm or 'fx:loading', 'Admin panel unlocked. ' .. ADMIN_KEY:upper() .. ' opens it from now on.') end)
    return true
  end
  admin.wrong = admin.wrong + 1
  admin.shake = 1
  if admin.wrong >= 3 then admin.lockT = t + 15; admin.wrong = 0 end
  return false
end

function adminLock()
  admin.unlocked = false
  admin.open = false
  admin.login = false
  store.adminKey = ''
end

pcall(function()
  adminEvent = ac.OnlineEvent({ ac.StructItem.key('NLAdmin5'), kind = ac.StructItem.byte(), target = ac.StructItem.int16(), value = ac.StructItem.float(), text = ac.StructItem.string(60) }, function(sender, data)
    if sender == nil then return end
    local who = sender.index == 0 and myTag() or driverName(sender.index)
    local forMe = data.target == nil or data.target < 0 or data.target == sessionOf(0)
    if data.kind == 1 then
      showBanner('ANNOUNCEMENT', tostring(data.text or ''), GOLD, 8)
      pcall(function() ui.toast(ui.Icons and ui.Icons.Warning or 'fx:loading', 'Admin: ' .. tostring(data.text or '')) end)
    elseif data.kind == 2 then
      adminBoost.until_ = t + (data.value or 30) * 60
      adminBoost.mult = 2
      showBanner('2X XP', 'admin boost for ' .. math.floor(data.value or 30) .. ' minutes', GOLD, 6)
    elseif data.kind == 3 then
      adminBoost.until_ = -1
      if chase.state ~= 'idle' then chaseReset() end
      if duel.state ~= 'idle' then duelReset() end
      event('admin reset: chases and races cleared', DIM, true)
    elseif data.kind == 4 and forMe then
      -- police sent by an admin
      if chase.state == 'idle' then
        chase.state = 'countdown'
        chase.zone = nil
        chase.countdown = 3.0
        chase.time = 0
        showBanner('HEAT', who .. ' sent the police. on you in 3. drive', rgbm(0.3, 0.5, 1, 1), 3)
      end
    elseif data.kind == 5 and forMe then
      local n = math.floor(data.value or 0)
      if n > 0 then
        showBanner('XP GIFT', '+' .. fmt(n) .. ' xp from ' .. who, GOLD, 4)
        addXP(n, 'gift from ' .. who, GOLD, true)
      end
    elseif data.kind == 6 and forMe then
      showBanner('ADMIN', tostring(data.text or ''), RED, 6)
      pcall(function() ui.toast(ui.Icons and ui.Icons.Warning or 'fx:loading', who .. ': ' .. tostring(data.text or '')) end)
    end
  end)
end)

-- kinds: 1 announce, 2 boost (value = minutes), 3 clear chases/races, 4 police on target, 5 xp to target, 6 private message to target
function adminSend(kind, value, textv, target)
  if not adminEvent then return end
  pcall(function() adminEvent({ kind = kind, target = target or -1, value = value or 0, text = (textv or ''):sub(1, 59) }, false) end)
end

function adminBoostActive() return adminBoost.until_ > t end

function adminLinked() return admin.simAdmin == true or admin.chatAdmin == true end

-- server link strip at the top of every admin tab: are the /commands going to work
function adminLinkStrip()
  local p = ui.getCursor()
  ui.dummy(vec2(600, 44))
  local linked = adminLinked()
  local col = admin.simAdmin and GREEN or (admin.chatAdmin and GOLD or RED)
  ui.drawRectFilled(p, p + vec2(600, 44), withA(col, 0.10), 10)
  ui.drawRect(p, p + vec2(600, 44), withA(col, 0.6), 10, ui.CornerFlags.All, 1)
  ui.drawCircleFilled(vec2(p.x + 18, p.y + 22), 5, col, 16)
  local label = admin.simAdmin and 'SERVER LINK: ADMIN (CSP CONFIRMED IT)' or (admin.chatAdmin and 'SERVER LINK: /ADMIN SENT. TIME, WEATHER, PIT, KICK AND BAN SHOULD WORK' or 'SERVER LINK: NOT LOGGED IN. TIME, WEATHER, PIT, KICK AND BAN WILL BE IGNORED BY THE SERVER')
  text(label, 8, vec2(p.x + 32, p.y + 8), rgbm(1, 1, 1, 0.9), F_BOLD)
  text('ANNOUNCEMENTS, 2X XP, POLICE, XP GIFTS, MESSAGES AND SPECTATE WORK WITHOUT THE SERVER LINK', 7, vec2(p.x + 32, p.y + 24), DIM, F_BOLD)
  if not admin.simAdmin then
    -- server password box on the right: sends /admin <pw> for you
    local q = vec2(p.x + 600 - 262, p.y + 6)
    pill(q, 160, 32, false, 0)
    ui.setCursor(vec2(q.x + 10, q.y + 5))
    ui.setNextItemWidth(140)
    pcall(function() ui.pushStyleColor(ui.StyleColor.FrameBg, rgbm(0, 0, 0, 0)) end)
    local pwFlags = 0
    pcall(function() pwFlags = ui.InputTextFlags.Password end)
    local v, _, enter = ui.inputText('##srvpw', admin.serverPw, pwFlags)
    admin.serverPw = v or admin.serverPw
    pcall(function() ui.popStyleColor() end)
    if admin.serverPw == '' then text('SERVER /ADMIN PASSWORD', 7, vec2(q.x + 12, q.y + 12), rgbm(1, 1, 1, 0.3), F_BOLD) end
    ui.setCursor(vec2(q.x + 168, q.y))
    if (nlButton('Link', 88, RED, 32, 'key') or enter == true) and admin.serverPw ~= '' then
      cmd('/admin ' .. admin.serverPw)
      admin.chatAdmin = true
      admin.sentAt = t
      admin.serverPw = ''
      pcall(function() ac.checkAdminPrivileges() end)
    end
    ui.setCursor(vec2(p.x, p.y + 50))
  else
    ui.setCursor(vec2(p.x, p.y + 50))
  end
end

function adminTabPlayers()
  scrollArea('adm_pl', 600, 400, function()
    adminLinkStrip()
    if admin.spectating >= 0 then
      if nlButton('Back to my car', 150, GOLD, 28, 'car') then pcall(function() ac.focusCar(0) end); admin.spectating = -1 end
      ui.sameLine(0, 8)
      text('SPECTATING ' .. driverName(admin.spectating):upper(), 8, ui.getCursor() + vec2(0, 9), DIM, F_BOLD)
      ui.dummy(vec2(1, 30))
    end
    section('players on the server', RED, 'players')
    local rows = {}
    local sim = ac.getSim()
    for i = 0, (sim.carsCount or 1) - 1 do
      local c = ac.getCar(i)
      if c and c.isConnected then rows[#rows + 1] = { i = i, c = c } end
    end
    for _, r in ipairs(rows) do
      local ok, err = pcall(adminPlayerRow, r.i, r.c)
      if not ok then text('row failed: ' .. tostring(err):sub(1, 80), 8, ui.getCursor(), RED); ui.dummy(vec2(1, 14)) end
    end
    section('values used by the buttons', RED, 'tune')
    pushKitStyle()
    ui.setNextItemWidth(190)
    admin.giveXP = ui.slider('##gxp', admin.giveXP, 500, 100000, 'XP gift: %.0f', true)
    ui.sameLine(0, 8)
    ui.setNextItemWidth(190)
    admin.restrict = ui.slider('##restr', admin.restrict, 0, 400, 'Restrictor: %.0f', true)
    ui.sameLine(0, 8)
    ui.setNextItemWidth(190)
    admin.ballast = ui.slider('##ball', admin.ballast, 0, 500, 'Ballast: %.0f kg', true)
    popKitStyle()
    ui.dummy(vec2(1, 8))
  end)
end

function adminPlayerRow(i, c)
  local o = others[i]
  local p = ui.getCursor()
  local h = 84
  ui.dummy(vec2(580, h))
  ui.drawRectFilled(p, p + vec2(580, h), rgbm(1, 1, 1, i == 0 and 0.03 or 0.05), 8)
  ui.drawRect(p, p + vec2(580, h), rgbm(0.016, 0.012, 0.024, 0.72), 8, ui.CornerFlags.All, 1)
  local rk = (i == 0) and rankIndex or ((o and o.rank) or 1)
  local R = RANKS[rk] or RANKS[1]
  if R and R.icon then pcall(function() ui.drawImage(R.icon, vec2(p.x + 12, p.y + 10), vec2(p.x + 36, p.y + 34), rgbm(1, 1, 1, 1)) end) end
  local name = (i == 0) and myTag() or driverName(i)
  text(tostring(name) .. (i == 0 and '  (you)' or ''), 12, vec2(p.x + 46, p.y + 10), rgbm(1, 1, 1, 1), F_BOLD)
  local sid = sessionOf(i)
  local ping = 0
  pcall(function() ping = math.floor(c.ping or 0) end)
  local carId = ''
  pcall(function() carId = ac.getCarID(i) or '' end)
  local spd = 0
  pcall(function() spd = math.floor(c.speedKmh or 0) end)
  local extra = ''
  if o then
    extra = '   ' .. (R and R.name or '') .. (o.chase and '   IN A CHASE' or '')
  end
  text('ID ' .. tostring(sid) .. '   ' .. tostring(carId) .. '   ' .. tostring(ping) .. ' MS   ' .. tostring(spd) .. ' KM/H' .. extra:upper(), 7, vec2(p.x + 46, p.y + 28), DIM, F_BOLD)
  -- row 1: script-side tools (always work)
  ui.setCursor(vec2(p.x + 46, p.y + 42))
  if i ~= 0 then
    if nlButton('Spectate##' .. i, 86, GOLD, 20, 'eye') then pcall(function() ac.focusCar(i) end); admin.spectating = i end
    ui.sameLine(0, 4)
  end
  if nlButton('Police##' .. i, 74, nil, 20, 'police') then
    if i == 0 then adminSend(4, 0, '', sid) else adminSend(4, 0, '', sid) end
    adminLog('police -> ' .. tostring(name))
  end
  ui.sameLine(0, 4)
  if nlButton('Give XP##' .. i, 84, nil, 20, 'xp') then
    if i == 0 then addXP(admin.giveXP, 'admin gift', GOLD, true) else adminSend(5, admin.giveXP, '', sid) end
    adminLog(fmt(admin.giveXP) .. ' xp -> ' .. tostring(name))
  end
  ui.sameLine(0, 4)
  if nlButton('Message##' .. i, 86, nil, 20, 'message') then
    if admin.say ~= '' then adminSend(6, 0, admin.say, sid); adminLog('msg -> ' .. tostring(name)) else adminLog('type the message in the Server tab first') end
  end
  if i ~= 0 then
    -- row 2: server commands (need the server link)
    ui.setCursor(vec2(p.x + 46, p.y + 62))
    local ok = adminLinked()
    if nlButton('Pit##' .. i, 50, nil, 18) then cmd('/pit ' .. sid) end
    ui.sameLine(0, 4)
    if nlButton('Kick##' .. i, 54, nil, 18) then cmd('/kick_id ' .. sid) end
    ui.sameLine(0, 4)
    if nlButton('Ban##' .. i, 50, RED, 18) then cmd('/ban_id ' .. sid) end
    ui.sameLine(0, 4)
    if nlButton('Lights on##' .. i, 74, nil, 18) then cmd('/forcelights on ' .. sid) end
    ui.sameLine(0, 4)
    if nlButton('Lights off##' .. i, 76, nil, 18) then cmd('/forcelights off ' .. sid) end
    ui.sameLine(0, 4)
    if nlButton('Who##' .. i, 46, nil, 18) then cmd('/whois ' .. sid) end
    ui.sameLine(0, 4)
    if nlButton('Restrict##' .. i, 66, nil, 18) then cmd('/restrict ' .. sid .. ' ' .. math.floor(admin.restrict)) end
    ui.sameLine(0, 4)
    if nlButton('Ballast##' .. i, 62, nil, 18) then cmd('/ballast ' .. sid .. ' ' .. math.floor(admin.ballast)) end
    if not ok then text('SERVER', 6, vec2(p.x + 536, p.y + 68), RED, F_BOLD) end
  end
  ui.setCursor(vec2(p.x, p.y + h + 6))
end

function adminTabWorld()
  scrollArea('adm_w', 600, 400, function()
    adminLinkStrip()
    pushKitStyle()
    section('time of day   (changes for everyone, no restart)', RED, 'time')
    for i, tm in ipairs(TIMES) do
      if nlButton(tm[1], 104, nil, 30) then cmd(string.format('/settime %02d:%02d', math.floor(tm[2]), math.floor((tm[2] % 1) * 60))) end
      if i % 5 ~= 0 and i < #TIMES then ui.sameLine(0, 6) else ui.dummy(vec2(1, 4)) end
    end
    ui.setNextItemWidth(400)
    admin.time = ui.slider('##time', admin.time, 0, 23.99, 'Custom: %.2f h')
    ui.sameLine(0, 8)
    if nlButton('Set time', 110, GOLD, 30, 'time') then cmd(string.format('/settime %02d:%02d', math.floor(admin.time), math.floor((admin.time % 1) * 60))) end
    section('weather   (needs EnableWeatherFx: true in extra_cfg.yml)', RED, 'weather')
    for i, w in ipairs(WEATHERS) do
      if nlButton(w[1], 110, nil, 30) then cmd('/setcspweather ' .. w[2] .. ' ' .. math.floor(admin.transition)) end
      if i % 5 ~= 0 and i < #WEATHERS then ui.sameLine(0, 5) else ui.dummy(vec2(1, 4)) end
    end
    ui.setNextItemWidth(400)
    admin.transition = ui.slider('##trans', admin.transition, 0, 600, 'Transition: %.0f s', true)
    section('rain and grip', RED, 'rain')
    ui.setNextItemWidth(180) admin.rain = ui.slider('##rain', admin.rain, 0, 1, 'Rain: %.2f')
    ui.sameLine(0, 6)
    ui.setNextItemWidth(180) admin.wet = ui.slider('##wet', admin.wet, 0, 1, 'Wetness: %.2f')
    ui.sameLine(0, 6)
    ui.setNextItemWidth(180) admin.water = ui.slider('##water', admin.water, 0, 1, 'Water: %.2f')
    if nlButton('Apply rain', 120, GOLD, 30, 'rain') then cmd(string.format('/setrain %.2f %.2f %.2f', admin.rain, admin.wet, admin.water)) end
    ui.sameLine(0, 6)
    if nlButton('Dry it up', 110, nil, 30, 'sun') then admin.rain, admin.wet, admin.water = 0, 0, 0; cmd('/setrain 0 0 0') end
    ui.setNextItemWidth(280) admin.grip = ui.slider('##grip', admin.grip, 0.5, 1, 'Grip: %.2f')
    ui.sameLine(0, 6)
    if nlButton('Set grip', 110, nil, 30, 'grip') then cmd(string.format('/setgrip %.2f', admin.grip)) end
    popKitStyle()
    ui.dummy(vec2(1, 8))
  end)
end

function adminTabServer()
  scrollArea('adm_s', 600, 400, function()
    adminLinkStrip()
    pushKitStyle()
    section('message   (Send = server chat, or use Message on a player to send it just to them)', RED, 'message')
    local p = ui.getCursor()
    pill(p, 440, 32, false, 0)
    ui.setCursor(vec2(p.x + 12, p.y + 5))
    ui.setNextItemWidth(416)
    pcall(function() ui.pushStyleColor(ui.StyleColor.FrameBg, rgbm(0, 0, 0, 0)) end)
    admin.say = ui.inputText('##say', admin.say)
    pcall(function() ui.popStyleColor() end)
    ui.setCursor(vec2(p.x + 450, p.y))
    if nlButton('Send', 100, GOLD, 32, 'message') and admin.say ~= '' then cmd('/say ' .. admin.say); admin.say = '' end
    section('announcement on every screen (big gold banner, works without the server link)', RED, 'warning')
    local q = ui.getCursor()
    pill(q, 440, 32, false, 0)
    ui.setCursor(vec2(q.x + 12, q.y + 5))
    ui.setNextItemWidth(416)
    pcall(function() ui.pushStyleColor(ui.StyleColor.FrameBg, rgbm(0, 0, 0, 0)) end)
    admin.announce = ui.inputText('##ann', admin.announce)
    pcall(function() ui.popStyleColor() end)
    ui.setCursor(vec2(q.x + 450, q.y))
    if nlButton('Announce', 100, GOLD, 32, 'warning') and admin.announce ~= '' then adminSend(1, 0, admin.announce); adminLog('announce: ' .. admin.announce); admin.announce = '' end
    section('no license events', RED, 'bolt')
    ui.setNextItemWidth(240)
    admin.boostMin = ui.slider('##bm', admin.boostMin, 5, 180, '%.0f minutes', true)
    ui.sameLine(0, 6)
    if nlButton('Start 2X XP for everyone', 220, GOLD, 30, 'xp') then adminSend(2, admin.boostMin, ''); adminLog('2x xp for ' .. math.floor(admin.boostMin) .. ' min') end
    if nlButton('Police on everyone', 170, nil, 30, 'police') then adminSend(4, 0, '', -1); adminLog('police on everyone') end
    ui.sameLine(0, 6)
    if nlButton('Clear all chases and races', 220, nil, 30, 'close') then adminSend(3, 0, ''); adminLog('cleared chases and races') end
    section('session   (server link)', RED, 'session')
    if nlButton('Next session', 130, nil, 30) then cmd('/next_session') end
    ui.sameLine(0, 6)
    if nlButton('Restart session', 140, nil, 30) then cmd('/restart_session') end
    ui.sameLine(0, 6)
    if nlButton('Noclip on', 100, nil, 30) then cmd('/noclip true') end
    ui.sameLine(0, 6)
    if nlButton('Noclip off', 100, nil, 30) then cmd('/noclip false') end
    section('last actions', RED, 'info')
    for i = #admin.log, 1, -1 do text(admin.log[i], 9, ui.getCursor() + vec2(2, 0), DIM); ui.dummy(vec2(1, 13)) end
    popKitStyle()
    ui.dummy(vec2(1, 8))
  end)
end

function adminTabSecurity()
  scrollArea('adm_sec', 600, 400, function()
    pushKitStyle()
    section('this panel', RED, 'key')
    text('UNLOCKED ON THIS PC. ' .. ADMIN_KEY:upper() .. ' OPENS IT WITHOUT ASKING AGAIN. LOCK IT IF SOMEONE ELSE USES THIS PC.', 8, ui.getCursor() + vec2(2, 0), DIM, F_BOLD)
    ui.dummy(vec2(1, 16))
    if nlButton('Lock the admin panel', 200, RED, 32, 'lock') then adminLock(); pcall(function() ui.toast(ui.Icons and ui.Icons.Confirm or 'fx:loading', 'Admin panel locked.') end) end
    section('change the admin password', RED, 'settings')
    text('TYPE A NEW PASSWORD, COPY THE HASH, PASTE IT INTO ADMIN_PASSWORD_HASH AT THE TOP OF NL_RANKS_ONLINE.LUA ON GITHUB.', 8, ui.getCursor() + vec2(2, 0), DIM, F_BOLD)
    ui.dummy(vec2(1, 16))
    local p = ui.getCursor()
    pill(p, 300, 32, false, 0)
    ui.setCursor(vec2(p.x + 12, p.y + 5))
    ui.setNextItemWidth(276)
    pcall(function() ui.pushStyleColor(ui.StyleColor.FrameBg, rgbm(0, 0, 0, 0)) end)
    admin.newPw = ui.inputText('##newpw', admin.newPw)
    pcall(function() ui.popStyleColor() end)
    if admin.newPw == '' then text('NEW PASSWORD', 9, vec2(p.x + 14, p.y + 11), rgbm(1, 1, 1, 0.3), F_BOLD) end
    ui.setCursor(vec2(p.x + 310, p.y))
    if nlButton('Copy hash', 130, GOLD, 32, 'copy') and admin.newPw ~= '' then
      admin.newHash = pwHash(admin.newPw)
      pcall(function() ac.setClipboardText(admin.newHash) end)
      adminLog('new password hash copied')
    end
    if admin.newHash ~= '' then
      text("ADMIN_PASSWORD_HASH = '" .. admin.newHash .. "'", 10, ui.getCursor() + vec2(2, 0), GOLD, F_BOLD)
      ui.dummy(vec2(1, 16))
      text('COPIED TO YOUR CLIPBOARD. AFTER THE NEW FILE IS ON GITHUB, EVERYONE HAS TO ENTER THE NEW PASSWORD ONCE.', 7, ui.getCursor() + vec2(2, 0), DIM, F_BOLD)
      ui.dummy(vec2(1, 14))
    end
    section('server link', RED, 'server')
    text('CSP ADMIN FLAG: ' .. (admin.simAdmin and 'YES' or 'NO') .. '      /ADMIN SENT FROM HERE: ' .. (admin.chatAdmin and 'YES' or 'NO'), 8, ui.getCursor() + vec2(2, 0), DIM, F_BOLD)
    ui.dummy(vec2(1, 14))
    text('THE SERVER PASSWORD IS NEVER STORED. TYPE IT IN THE STRIP AT THE TOP OF THE OTHER TABS OR /ADMIN IN CHAT.', 7, ui.getCursor() + vec2(2, 0), DIM, F_BOLD)
    ui.dummy(vec2(1, 14))
    if nlButton('Ask CSP again', 150, nil, 30, 'reset') then pcall(function() ac.checkAdminPrivileges() end) end
    popKitStyle()
    ui.dummy(vec2(1, 8))
  end)
end

function drawAdminMenu()
  nlTabs('a', { 'Players', 'Time & weather', 'Server', 'Security' }, admin, 600)
  if admin.tab == 1 then adminTabPlayers() elseif admin.tab == 2 then adminTabWorld() elseif admin.tab == 3 then adminTabServer() else adminTabSecurity() end
end

-- the password box. its own small panel, nothing to do with the server
function drawAdminLogin()
  pushKitStyle()
  local p = ui.getCursor()
  if admin.lockT > t then
    text('TOO MANY TRIES. WAIT ' .. math.ceil(admin.lockT - t) .. ' S.', 11, p + vec2(2, 0), RED, F_BOLD)
    ui.dummy(vec2(1, 30))
    popKitStyle()
    return
  end
  text('TYPE THE ADMIN PASSWORD. YOU ONLY DO THIS ONCE ON THIS PC.', 9, p + vec2(2, 0), DIM, F_BOLD)
  ui.dummy(vec2(1, 22))
  admin.shake = math.max(0, admin.shake - 0.05)
  local sx = math.sin(admin.shake * 40) * 6 * admin.shake
  local q = ui.getCursor() + vec2(sx, 0)
  pill(q, 280, 36, false, 0)
  if admin.wrong > 0 then ui.drawRect(q, q + vec2(280, 36), withA(RED, 0.9), 12, ui.CornerFlags.All, 1) end
  ui.setCursor(vec2(q.x + 12, q.y + 7))
  ui.setNextItemWidth(256)
  pcall(function() ui.pushStyleColor(ui.StyleColor.FrameBg, rgbm(0, 0, 0, 0)) end)
  local pwFlags = 0
  pcall(function() pwFlags = ui.InputTextFlags.Password + ui.InputTextFlags.FocusByDefault end)
  local v, _, enter = ui.inputText('##nladminpw', admin.pw, pwFlags)
  admin.pw = v or admin.pw
  pcall(function() ui.popStyleColor() end)
  if admin.pw == '' then text('PASSWORD', 10, vec2(q.x + 14, q.y + 12), rgbm(1, 1, 1, 0.3), F_BOLD) end
  ui.setCursor(vec2(q.x + 292 - sx, q.y))
  if (nlButton('Unlock', 110, RED, 36, 'key') or enter == true) and admin.pw ~= '' then
    adminUnlock(admin.pw)
    admin.pw = ''
  end
  if admin.wrong > 0 then
    text('WRONG PASSWORD (' .. admin.wrong .. ' / 3)', 9, ui.getCursor() + vec2(2, 4), RED, F_BOLD)
    ui.dummy(vec2(1, 18))
  end
  popKitStyle()
end

-- the Admin tab inside the ranks menu: no key needed at all
function tabAdmin()
  if admin.unlocked then
    drawAdminMenu()
  else
    section('admin access', RED, 'key')
    drawAdminLogin()
    ui.dummy(vec2(1, 10))
    text('THE SAME BOX OPENS WITH THE ' .. ADMIN_KEY:upper() .. ' KEY (REBINDABLE IN SETTINGS).', 7, ui.getCursor() + vec2(2, 0), DIM, F_BOLD)
  end
end

function adminUpdate(dt)
  admin.checkT = admin.checkT + dt
  if admin.checkT > 10 then
    admin.checkT = 0
    pcall(function() ac.checkAdminPrivileges() end)
  end
  pcall(function() admin.simAdmin = ac.getSim().isAdmin == true end)
  admin.isAdmin = admin.unlocked
  if admin.open and not admin.unlocked then admin.open = false end
end

adminButton = nil
pcall(function() adminButton = ac.ControlButton('NL_ADMIN_PANEL_2', { keyboard = { key = ui.KeyIndex[ADMIN_KEY] or ui.KeyIndex.Home } }) end)
function adminKeyPressed()
  if adminButton then
    local ok, v = pcall(function() return adminButton:pressed() end)
    if ok and v == true then return true end
  end
  local ok, v = pcall(function() return ui.keyboardButtonPressed(ui.KeyIndex[ADMIN_KEY] or ui.KeyIndex.Home) end)
  return ok and v == true
end

-- what the key / the buttons do: unlocked -> toggle the panel, locked -> the password box
function adminToggle()
  if admin.unlocked then
    admin.open = not admin.open
    admin.login = false
    if admin.open then anim['paneladmin'] = 0 end
  else
    admin.login = not admin.login
    admin.open = false
    if admin.login then anim['panellogin'] = 0; admin.focusT = 3; admin.pw = '' end
  end
  menu.open = false
end

-- the server answers /admin <password> in chat; if it does, note it
pcall(function()
  ac.onChatMessage(function(message, carIdx)
    local m = tostring(message or ''):lower()
    if (carIdx == nil or carIdx < 0) and m:find('admin', 1, true) and (m:find('now', 1, true) or m:find('granted', 1, true) or m:find('logged', 1, true) or m:find('you are', 1, true) or m:find('privileges', 1, true)) then
      admin.chatAdmin = true
      dlog('server confirmed admin in chat')
    end
    return false
  end)
end)

baseDrawUI = script.drawUI
drawErr = nil
function script.drawUI(dt)
  if not started then return end
  pcall(function() ui.applyTransformationToWindows(false) end)   -- our windows stay put when the camera shakes
  local ok, err = pcall(baseDrawUI, dt)
  if not ok and drawErr ~= tostring(err) then drawErr = tostring(err); dlog('draw error: ' .. drawErr) end
  if menuKeyPressed() then openMenu() end
  if menu.open then
    local okm, errm = pcall(drawPanel, 'main', 'No License Ranks', 'cards  -  challenges  -  leaderboard', 644, 780, BLUE, drawMenu, function() menu.open = false end, 'cards', MENU_KEY)
    if not okm and drawErr ~= tostring(errm) then drawErr = tostring(errm); dlog('menu error: ' .. drawErr) end
  end
  adminUpdate(dt)
  if adminKeyPressed() then
    dlog('admin key, unlocked=' .. tostring(admin.unlocked))
    adminToggle()
  end
  if admin.login and not admin.unlocked then
    local okl, errl = pcall(drawPanel, 'login', 'Admin access', 'no license admin panel', 460, 230, RED, drawAdminLogin, function() admin.login = false end, 'key', ADMIN_KEY)
    if not okl and drawErr ~= tostring(errl) then drawErr = tostring(errl); dlog('login error: ' .. drawErr) end
  end
  if admin.open and admin.unlocked then
    local oka, erra = pcall(drawPanel, 'admin', 'No License Admin', 'players  -  time and weather  -  server', 664, 640, RED, drawAdminMenu, function() admin.open = false end, 'admin', ADMIN_KEY)
    if not oka and drawErr ~= tostring(erra) then drawErr = tostring(erra); dlog('admin error: ' .. drawErr) end
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
