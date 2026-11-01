-- No License Ranks - server script
-- Loaded by every player automatically from csp_extra_options.ini. Nothing to install.
--
-- HUD: a small panel at the top middle. Hidden while nothing is happening, pops in when
-- you earn something, stays while you are in a run, fades out when you crash or stop.
-- Never covers the road.

local VERSION = '3.1'

------------------------------------------------------------------ CONFIG (edit these)

-- Where the rank badges live (rank_01.png .. rank_27.png).
local ICON_BASE = 'https://raw.githubusercontent.com/YbwSolo/NL/main/icons/'

-- Zones file. Edit zones.json on GitHub, everyone gets the new zones next time they join.
-- Easiest way to make it: in game, CSP online extras menu > "No License Ranks" > Zones,
-- drive to the spot, press "+ Police zone here" / "+ Race start here" / "Race finish here",
-- then "Copy zones.json" and paste the text into zones.json on GitHub.
local ZONES_URL = 'https://raw.githubusercontent.com/YbwSolo/NL/main/zones.json'

-- Optional backend for server-side progress (leave '' to keep progress on each player's PC).
local BACKEND = ''

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
  RANKS[i] = { name = n, xp = math.floor(300 * ((i - 1) ^ 2.1)), col = col, icon = string.format('%srank_%02d.png', ICON_BASE, i) }
end

local XP = {
  perKm = 12, fastKm = 10, veryFastKm = 15, cleanKm = 4,
  nearMiss = 25, overtake = 6, crash = -40, streakStep = 0.25, streakWindow = 6.0,
  escape = 600, escapePerUnit = 60, busted = -400,
  raceWin = 800, raceSecond = 500, raceThird = 300, raceFinish = 150, raceSolo = 100,
}
local NEAR, PASS, MIN_SPEED, MIN_REL = 2.9, 5.0, 60, 12

------------------------------------------------------------------ storage

------------------------------------------------------------------ storage

local store = ac.storage {
  xp = 0, km = 0, nearMisses = 0, overtakes = 0, crashes = 0, topSpeed = 0, bestStreak = 0, bestRun = 0,
  escapes = 0, busts = 0, races = 0, raceWins = 0, hudScale = 1.0, alwaysShow = false,
  localZones = '', useLocalZones = false, zoneR = 6, zoneName = '',
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
local prev = {}
local lastPos = nil
local rankIndex = 1
local speedMult = 1
local run = { score = 0, active = false, stopTimer = 0, lost = false, lostTimer = 0, time = 0 }
local lastClose = 0
local hud = { alpha = 0, lastEvent = -10, events = {} }
local levelAnim = { t = -1, rank = 1 }
local banner = { text = '', sub = '', col = rgbm(1, 1, 1, 1), t = -1, life = 3 }
local others = {}
local diag = {}
local lastErr = nil

local function dlog(s)
  diag[#diag + 1] = s
  if #diag > 30 then table.remove(diag, 1) end
  ac.log('nl_ranks: ' .. s)
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

local saveTimer = 0
local function addXP(n, why, colour, noRun)
  if n == 0 then return end
  n = math.floor(n + 0.5)
  local before = rankFor(store.xp)
  store.xp = math.max(0, store.xp + n)
  session.xp = session.xp + n
  if n > 0 and not noRun then
    run.score = run.score + n
    run.active = true
    run.lost = false
  end
  if why then event((n > 0 and '+' or '') .. n .. '  ' .. why, colour) end
  local after = rankFor(store.xp)
  if after > before then
    rankIndex = after
    levelAnim = { t = 0, rank = after }
    backendSave()
    dlog('rank up -> ' .. RANKS[after].name)
  elseif after < before then
    rankIndex = after
    event('DEMOTED  ' .. RANKS[after].name, rgbm(1, 0.3, 0.3, 1), true)
  end
end

local function endRun(crashed)
  if run.score > store.bestRun then store.bestRun = run.score end
  if crashed and run.score > 0 then
    run.lost = true
    run.lostTimer = 1.6
    hud.lastEvent = t
  end
  run.score = 0
  run.active = false
  run.time = 0
end

------------------------------------------------------------------ sync

local rankEvent = nil
local chaseActive = false
pcall(function()
  rankEvent = ac.OnlineEvent({
    ac.StructItem.key('NLRanksSrv3'),
    rank = ac.StructItem.byte(),
    xp = ac.StructItem.int32(),
    chase = ac.StructItem.byte(),
  }, function(sender, data)
    if sender == nil or sender.index == 0 then return end
    others[sender.index] = { rank = math.max(1, math.min(#RANKS, data.rank)), xp = data.xp, chase = data.chase == 1 }
  end)
end)

local function broadcastRank()
  if not rankEvent then return end
  pcall(function() rankEvent({ rank = rankIndex, xp = math.floor(store.xp), chase = chaseActive and 1 or 0 }, true) end)
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
    if sender == nil then return end
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
  if #ZONES.race == 0 then return end
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
      session.km = session.km + km
      cleanDist = cleanDist + km
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
    endRun(true)
    addXP(XP.crash, 'contact', rgbm(1, 0.4, 0.3, 1), true)
    chaseCrash(me)
  end

  if streak > 0 then
    streakTimer = streakTimer - dt
    if streakTimer <= 0 then streak = 0 end
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
                store.nearMisses = store.nearMisses + 1
                session.nearMisses = session.nearMisses + 1
                local close = (NEAR - alat) / NEAR
                lastClose = math.max(lastClose, close)
                local mult = math.min(3, 1 + XP.streakStep * (streak - 1))
                local pts = (XP.nearMiss + close * 40 + speed / 10) * mult * (1 + (speedMult - 1) * 0.15)
                local label = close > 0.65 and 'INSANE NEAR MISS' or (close > 0.35 and 'CLOSE NEAR MISS' or 'NEAR MISS')
                if streak > 1 then label = label .. '  x' .. streak end
                addXP(pts, label, close > 0.65 and rgbm(1, 0.85, 0.2, 1) or rgbm(0, 0.94, 0.35, 1))
              elseif alat < PASS then
                store.overtakes = store.overtakes + 1
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
      loadRemoteZones()
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

local COL_POLICE = rgbm(0.25, 0.55, 1.0, 1)
local COL_RACE = rgbm(1.0, 0.22, 0.22, 1)
local function withA(c, a) return rgbm(c.r, c.g, c.b, (c.mult or 1) * a) end

function script.draw3D()
  if not started then return end
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
  for _, z in ipairs(ZONES.chase) do
    if flatDist(me.position, z) < 500 then
      ring(z.x, z.y, z.z, z.r, COL_POLICE, pulse)
      label(z.x, z.y, z.z, 'POLICE', COL_POLICE)
    end
  end
  for _, z in ipairs(ZONES.race) do
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

local GREEN = rgbm(0, 0.96, 0.38, 1)
local RED = rgbm(1, 0.25, 0.22, 1)
local F_BOLD = 'Bahnschrift;Weight=Bold'
local F_MED = 'Bahnschrift;Weight=SemiBold'

local function fmt(n)
  n = math.floor(n)
  local s = tostring(n):reverse():gsub('(%d%d%d)', '%1,'):reverse()
  if s:sub(1, 1) == ',' then s = s:sub(2) end
  return s
end

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
    elseif la >= 0 then
      local flash = la < 0.25 and 1 or math.max(0, 1 - (la - 0.25) * 2)
      fill = mix(RANKS[levelAnim.rank].col, rgbm(1, 1, 1, 1), flash)
      if la < 1.3 then word = 'RANK UP' end
    elseif run.active and run.score > 0 then
      word = fmt(run.score) .. ' PTS'
      sub = R.name:upper()
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
      textC(sub, 8 * s, x0 + mainW / 2, y1 + 25 * s, withA(textCol, 0.7 * A), F_BOLD)
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
  if count and count > 0 then
    local n = math.ceil(count)
    local frac = count - math.floor(count)
    local size = (48 + 16 * frac) * s
    textC(tostring(n), size, cx, ly + 44 * s, rgbm(1, 1, 1, 0.4 + 0.6 * frac), F_BOLD)
  end
end

------------------------------------------------------------------ online extras menu entry (stats, zones placer)

local function addLocalZone(kind, me)
  local p = me.position
  local name = store.zoneName ~= '' and store.zoneName or (kind == 'chase' and ('Police ' .. (#ZONES.chase + 1)) or ('Race ' .. (#ZONES.race + 1)))
  local z = normZone({ name = name, x = p.x, y = p.y, z = p.z, r = store.zoneR }, kind == 'race')
  if kind == 'chase' then ZONES.chase[#ZONES.chase + 1] = z else ZONES.race[#ZONES.race + 1] = z end
  store.zoneName = ''
  saveLocalZones()
  dlog('placed ' .. kind .. ' zone ' .. name)
end

pcall(function()
  local icn = ui.Icons and (ui.Icons.Trophy or ui.Icons.Star or ui.Icons.Settings) or nil
  ui.registerOnlineExtra(icn, 'No License Ranks', nil, function()
    local R = RANKS[rankIndex]
    ui.image(R.icon, vec2(56, 56))
    ui.sameLine()
    ui.beginGroup()
    ui.textColored(R.name, R.col)
    ui.text(fmt(store.xp) .. ' XP   rank ' .. rankIndex .. ' of ' .. #RANKS .. (backendOK and '   (server saved)' or ''))
    ui.endGroup()
    ui.separator()
    ui.text(string.format('%s km   %d near misses   %d overtakes   %d contacts', fmt(store.km), store.nearMisses, store.overtakes, store.crashes))
    ui.text(string.format('top %d km/h   best streak x%d   best run %s', store.topSpeed, store.bestStreak, fmt(store.bestRun)))
    ui.text(string.format('police: %d escapes, %d busts   races: %d, %d wins', store.escapes, store.busts, store.races, store.raceWins))
    ui.separator()
    ui.text('Players')
    for idx, o in pairs(others) do
      local c = ac.getCar(idx)
      if c and c.isConnected then
        ui.image(RANKS[o.rank].icon, vec2(18, 18))
        ui.sameLine()
        ui.text((ac.getDriverName(idx) or ('car ' .. idx)) .. '   ')
        ui.sameLine()
        ui.textColored(RANKS[o.rank].name .. (o.chase and '  (in a chase)' or ''), RANKS[o.rank].col)
      end
    end
    ui.separator()
    store.hudScale = ui.slider('##hs', store.hudScale, 0.6, 1.8, 'HUD size: %.2f')
    if ui.checkbox('Always show the HUD', store.alwaysShow) then store.alwaysShow = not store.alwaysShow end
    ui.sameLine()
    if ui.button('Preview rank-up') then levelAnim = { t = 0, rank = math.min(#RANKS, rankIndex + 1) }; hud.lastEvent = t end
    if chase.state ~= 'idle' then
      ui.sameLine()
      if ui.button('Cancel chase') then chaseReset() end
    end

    ui.separator()
    ui.text('Zones   (' .. zonesSource .. ')')
    local me = ac.getCar(0)
    if me then
      store.zoneName = ui.inputText('Name for the next zone', store.zoneName)
      store.zoneR = ui.slider('##zr', store.zoneR, 3, 25, 'Ring size: %.0f m', true)
      if ui.button('+ Police zone here') then addLocalZone('chase', me) end
      ui.sameLine()
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
    if ui.button('Copy my position') then pcall(function() ac.setClipboardText(string.format('%.1f, %.1f, %.1f', me.position.x, me.position.y, me.position.z)) end) end
    ui.sameLine()
    if store.useLocalZones and ui.button('Back to server zones') then
      store.useLocalZones = false
      store.localZones = ''
      applyZones(DEFAULT_ZONES, 'built-in')
      loadRemoteZones()
    end
    ui.textColored('Place zones, Copy zones.json, paste it into zones.json on GitHub. Everyone gets them next join.', rgbm(0.5, 0.5, 0.55, 1))
    ui.separator()
    for i = #diag, math.max(1, #diag - 6), -1 do ui.textColored(diag[i], rgbm(0.5, 0.5, 0.55, 1)) end
  end)
end)
