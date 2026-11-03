-- No License - walk mode. Park up, press E, walk about with your mates. First person, WASD + mouse,
-- shift to run, E next to your car to get back in. Everyone else sees you as the No License character.
-- The character and its animations download once from the server's GitHub (nl_ped.zip).

local VERSION = '2.2'
local PED_URL = 'https://raw.githubusercontent.com/YbwSolo/NL/main/nl_ped6.zip'
local EMOTE_URL = 'https://raw.githubusercontent.com/YbwSolo/NL/main/nl_emotes2.zip'
local KEY_TOGGLE = 'E'          -- out of the car / back in (ui.KeyIndex names)
local KEY_VIEW = 'V'            -- first person <-> behind the character
local KEY_EMOTES = 'B'          -- emote menu (on foot only)
local KEY_FWD, KEY_BACK, KEY_LEFT, KEY_RIGHT = 'W', 'S', 'A', 'D'
local WALK_SPEED = 1.55         -- m/s, matches the walk cycle
local RUN_SPEED = 4.8
local EYE_HEIGHT = 1.62
local MOUSE_SENS = 0.0022
local MAX_EXIT_KMH = 4          -- car has to be (nearly) stopped to get out
local ENTER_RANGE = 3.5         -- how close to the car you need to be to get back in
local SPAWN_SIDE = 1.7          -- metres from the car centre to the door you step out of
local SEND_RATE = 0.1           -- seconds between position updates to other players
local ANIM = { idle = { file = 'idle.ksanim', len = 8.37 }, walk = { file = 'walk.ksanim', len = 1.067 }, run = { file = 'run.ksanim', len = 0.667 }, back = { file = 'back.ksanim', len = 1.267 } }
local STATES = { 'idle', 'walk', 'run', 'back' }
local STATE_ID = { idle = 1, walk = 2, run = 3, back = 4 }

-- emotes: id = file in nl_emotes.zip, len = seconds per loop, props = what to put in his hands
-- (prop files are baked for the hand they were placed in, in the blender file)
local EMOTE_GROUPS = { 'Picture poses', 'Members', 'Outside', 'Show the glock', 'Money', 'Cover face' }
local EMOTES = {
  { id = '100membersdrop1', label = '100 drop 1', group = 'Picture poses', len = 3.767 },
  { id = '100membersdrop2', label = '100 drop 2', group = 'Picture poses', len = 3.767 },
  { id = '100membersdrop3', label = '100 drop 3', group = 'Picture poses', len = 3.767 },
  { id = '100membersdrop4', label = '100 drop 4', group = 'Picture poses', len = 3.767 },
  { id = '150membersdrop1', label = '150 drop 1', group = 'Picture poses', len = 3.767 },
  { id = '150membersdrop2', label = '150 drop 2', group = 'Picture poses', len = 3.767 },
  { id = '150membersdrop3', label = '150 drop 3', group = 'Picture poses', len = 3.767 },
  { id = '150membersdrop4', label = '150 drop 4', group = 'Picture poses', len = 3.767 },
  { id = 'spose9', label = 'Pose 9', group = 'Picture poses', len = 3.733 },
  { id = 'fpose1', label = 'Pose 1', group = 'Picture poses', len = 3.733 },
  { id = 'ots', label = 'OTS', group = 'Picture poses', len = 3.733 },
  { id = 'onpoint', label = 'On point', group = 'Picture poses', len = 1.533 },
  { id = 'dogiclovertwo', label = 'Dogi clover 2', group = 'Picture poses', len = 3.733 },
  { id = 'dogicloverthree', label = 'Dogi clover 3', group = 'Picture poses', len = 3.733 },
  { id = 'smoke2', label = 'Smoke', group = 'Picture poses', len = 3.733, props = { 'joint' } },
  { id = 'snakechild', label = 'Snake child', group = 'Picture poses', len = 3.733 },
  { id = 'gunhand', label = 'Gun hand', group = 'Picture poses', len = 3.733 },
  { id = 'presidential', label = 'Presidential', group = 'Picture poses', len = 3.767 },
  { id = 'burner', label = 'Burner', group = 'Picture poses', len = 3.767, props = { 'lighter' } },
  { id = 'wildkard', label = 'Wildkard', group = 'Members', len = 3.767, props = { 'redarp' } },
  { id = 'leanin', label = 'Leanin', group = 'Members', len = 3.767, props = { 'g40' } },
  { id = 'druglove', label = 'Drug love', group = 'Outside', len = 3.767 },
  { id = 'simonsays', label = 'Simon says', group = 'Outside', len = 3.767 },
  { id = 'bloodonnastreets', label = 'Blood on the streets', group = 'Outside', len = 3.767 },
  { id = 'smith', label = 'Show the glock', group = 'Show the glock', len = 3.733, props = { 'glock' } },
  { id = 'responsibility', label = 'Sit money spread', group = 'Money', len = 3.767, props = { 'moneyspread_sit' } },
  { id = 'wickk', label = 'FMC money spread', group = 'Money', len = 3.033, props = { 'moneyspread_fmc' } },
  { id = 'demons', label = 'Cover face', group = 'Cover face', len = 3.767 },
}
local PROPS = {
  glock = { file = 'prop_glock.kn5', bone = 'mixamorig_RightHand' },
  joint = { file = 'prop_joint.kn5', bone = 'mixamorig_RightHand' },
  lighter = { file = 'prop_lighter.kn5', bone = 'mixamorig_LeftHand' },
  g40 = { file = 'prop_g40.kn5', bone = 'mixamorig_RightHand' },
  redarp = { file = 'prop_redarp.kn5', bone = 'mixamorig_RightHand' },
  moneyspread_sit = { file = 'prop_moneyspread_sit.kn5', bone = 'mixamorig_RightHand' },
  moneyspread_fmc = { file = 'prop_moneyspread_fmc.kn5', bone = 'mixamorig_RightHand' },
}
local EMOTE_STATE_BASE = 10     -- network state byte = 10 + emote index

local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local t = 0
local sim = nil
local function dlog(s) ac.log('nl_walk: ' .. s) end

-- camera pose matrix built by hand (mat4x4.look gives a view matrix)
local function cross(a, b) return vec3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x) end
local sideSign = nil
local function camMatrix(pos, look)
  local l = look:normalize()
  local up = vec3(0, 1, 0)
  local side = cross(up, l):normalize()
  if sideSign == nil then
    sideSign = 1
    pcall(function() local car = ac.getCar(0); if cross(car.up, car.look):dot(car.side) < 0 then sideSign = -1 end end)
  end
  side = side * sideSign
  local up2 = cross(l, side) * sideSign
  return mat4x4(vec4(side.x, side.y, side.z, 0), vec4(up2.x, up2.y, up2.z, 0), vec4(l.x, l.y, l.z, 0), vec4(pos.x, pos.y, pos.z, 1))
end

local function flat(a, b) local dx, dz = a.x - b.x, a.z - b.z; return math.sqrt(dx * dx + dz * dz) end
local function groundAt(pos, fallback)
  local d = nil
  pcall(function() d = physics.raycastTrack(vec3(pos.x, pos.y + 2.0, pos.z), vec3(0, -1, 0), 8) end)
  if d and d > 0 then return pos.y + 2.0 - d end
  return fallback
end
local function blocked(pos, dir, len)
  local d = nil
  pcall(function() d = physics.raycastTrack(vec3(pos.x, pos.y + 1.0, pos.z), dir, len) end)
  return d and d > 0
end
-- letters and digits are not in ui.KeyIndex, their virtual key code is the ASCII code
local function keyIndex(name)
  local v = ui.KeyIndex[name]
  if v then return v end
  if #name == 1 then return string.byte(name:upper()) end
  return nil
end
local function keyDown(name)
  local v = false
  local k = keyIndex(name)
  if not k then return false end
  pcall(function() v = ac.isKeyDown(k) == true end)
  return v
end
local pressedAt = {}
local function keyPressed(name)
  local v = false
  local k = keyIndex(name)
  if not k then return false end
  if ac.isKeyPressed then
    pcall(function() v = ac.isKeyPressed(k) == true end)
  else
    pcall(function() v = ui.keyboardButtonPressed(k) == true end)
  end
  if v and t - (pressedAt[k] or -10) < 0.35 then return false end
  if v then pressedAt[k] = t end
  return v
end

------------------------------------------------------------------ the character files

local ped = { folder = nil, err = nil, loading = false, tried = 0, modelErr = nil }
local function pedLoad()
  if ped.folder or ped.loading or ped.tried >= 3 then return end
  ped.loading = true
  ped.tried = ped.tried + 1
  local ok, e = pcall(function()
    web.loadRemoteAssets(PED_URL, function(err, folder)
      ped.loading = false
      if err or not folder then ped.err = tostring(err or 'no folder'); dlog('ped download failed: ' .. ped.err) return end
      ped.folder = folder
      dlog('ped assets in ' .. tostring(folder))
    end)
  end)
  if not ok then ped.loading = false; ped.err = tostring(e); dlog('loadRemoteAssets: ' .. ped.err) end
end
local function pedFile(name) return ped.folder .. '/' .. name end

local emo = { folder = nil, err = nil, loading = false, tried = 0 }
local function emoteLoad()
  if emo.folder or emo.loading or emo.tried >= 3 then return end
  emo.loading = true
  emo.tried = emo.tried + 1
  local ok, e = pcall(function()
    web.loadRemoteAssets(EMOTE_URL, function(err, folder)
      emo.loading = false
      if err or not folder then emo.err = tostring(err or 'no folder'); dlog('emote download failed: ' .. emo.err) return end
      emo.folder = folder
      dlog('emote assets in ' .. tostring(folder))
    end)
  end)
  if not ok then emo.loading = false; emo.err = tostring(e); dlog('loadRemoteAssets emotes: ' .. emo.err) end
end
local function emoteFile(name) return emo.folder .. '/' .. name end

------------------------------------------------------------------ a walker (mine or someone else's)

local function newWalker(idx)
  return { idx = idx, pos = vec3(0, 0, 0), tpos = vec3(0, 0, 0), yaw = 0, tyaw = 0, state = 'idle', emote = nil, animT = 0, node = nil, model = nil, lastT = -100, vel = vec3(0, 0, 0), visible = false, props = {}, propsShown = {} }
end

local function walkerModel(w)
  if w.model or not ped.folder then return w.model end
  local ok, err = pcall(function()
    w.node = ac.findNodes('dynamicRoot:yes'):loadKN5(pedFile('ped.kn5'))
    if not w.node or w.node:size() == 0 then error('loadKN5 returned nothing') end
    w.model = w.node
  end)
  if not ok then ped.modelErr = tostring(err); dlog('model load failed: ' .. tostring(err)); w.model = false end
  return w.model
end

-- props hang off the hand bone nodes inside the character, so they follow the animation for free
local function walkerProp(w, key)
  local ref = w.props[key]
  if ref ~= nil or not emo.folder then return ref end
  local pdef = PROPS[key]
  if not pdef then w.props[key] = false return false end
  local ok, err = pcall(function()
    local hand = w.node:findNodes(pdef.bone)
    if not hand or hand:size() == 0 then error('bone node ' .. pdef.bone .. ' not found') end
    local r = hand:loadKN5(emoteFile(pdef.file))
    if not r or r:size() == 0 then error('loadKN5 returned nothing') end
    w.props[key] = r
  end)
  if not ok then dlog('prop ' .. key .. ' failed: ' .. tostring(err)); w.props[key] = false end
  return w.props[key]
end

local function walkerShowProps(w, list)
  local want = {}
  for _, key in ipairs(list or {}) do want[key] = true end
  for key, ref in pairs(w.props) do
    if ref and not want[key] and w.propsShown[key] then pcall(function() ref:setVisible(false) end); w.propsShown[key] = false end
  end
  for key in pairs(want) do
    local ref = walkerProp(w, key)
    if ref and not w.propsShown[key] then pcall(function() ref:setVisible(true) end); w.propsShown[key] = true end
  end
end

local function walkerDraw(w, dt)
  local m = walkerModel(w)
  if not m then return end
  local look = vec3(math.sin(w.yaw), 0, math.cos(w.yaw))
  pcall(function()
    w.node:setPosition(w.pos)
    w.node:setOrientation(look, vec3(0, 1, 0))
    if not w.visible then w.node:setVisible(true); w.visible = true end
    local e = w.state == 'emote' and EMOTES[w.emote or 0] or nil
    if e and emo.folder then
      w.animT = (w.animT + dt / e.len) % 1
      m:setAnimation(emoteFile('emote_' .. e.id .. '.ksanim'), w.animT, true)
      walkerShowProps(w, e.props)
    else
      local a = ANIM[w.state] or ANIM.idle
      w.animT = (w.animT + dt / a.len) % 1
      m:setAnimation(pedFile(a.file), w.animT, true)
      walkerShowProps(w, nil)
    end
  end)
end

local function walkerHide(w)
  if w.node and w.visible then pcall(function() w.node:setVisible(false) end); w.visible = false end
  walkerShowProps(w, nil)
end

------------------------------------------------------------------ me

local me = { active = false, w = newWalker(0), pitch = 0, camYaw = 0, cam = nil, third = false, speed = 0, parked = nil, sendT = 0, bob = 0, hint = '', hintT = -10, stopSends = 0, lockT = 0, menu = false, menuAnim = 0 }

local walkEvent = nil
local others = {}
pcall(function()
  walkEvent = ac.OnlineEvent({ ac.StructItem.key('NLWalk1'), state = ac.StructItem.byte(), x = ac.StructItem.float(), y = ac.StructItem.float(), z = ac.StructItem.float(), yaw = ac.StructItem.float() }, function(sender, data)
    if sender == nil or sender.index == 0 then return end
    local idx = sender.index
    local w = others[idx]
    if data.state == 0 then
      if w then walkerHide(w); w.lastT = -100 end
      return
    end
    if not w then w = newWalker(idx); others[idx] = w; w.pos = vec3(data.x, data.y, data.z); w.yaw = data.yaw end
    local np = vec3(data.x, data.y, data.z)
    local gap = t - w.lastT
    if gap > 0.02 and gap < 2 then w.vel = (np - w.tpos) / gap else w.vel = vec3(0, 0, 0) end
    if flat(np, w.pos) > 25 then w.pos = np end
    w.tpos = np
    w.tyaw = data.yaw
    if data.state >= EMOTE_STATE_BASE and EMOTES[data.state - EMOTE_STATE_BASE] then
      if w.state ~= 'emote' or w.emote ~= data.state - EMOTE_STATE_BASE then w.animT = 0 end
      w.state = 'emote'
      w.emote = data.state - EMOTE_STATE_BASE
      emoteLoad()
    else
      w.state = STATES[data.state] or 'idle'
      w.emote = nil
    end
    w.lastT = t
    pedLoad()
  end)
end)

local function send(state)
  if not walkEvent then return end
  local w = me.w
  pcall(function() walkEvent({ state = state, x = w.pos.x, y = w.pos.y, z = w.pos.z, yaw = w.yaw }, false) end)
end

local function hint(s, life) me.hint = s; me.hintT = t + (life or 3) end

local function emoteStart(i)
  local e = EMOTES[i]
  if not e then return end
  if not emo.folder then emoteLoad(); hint('emotes still downloading, give it a second', 2) return end
  me.w.state = 'emote'
  me.w.emote = i
  me.w.animT = 0
  me.speed = 0
  me.third = true
  me.menu = false
  hint(e.label:upper() .. '   move to stop   ' .. KEY_EMOTES .. ' for the menu', 3)
end

local function emoteStop()
  if me.w.state == 'emote' then me.w.state = 'idle'; me.w.emote = nil; me.w.animT = 0 end
end

local function getOut(car)
  if me.active then return end
  if car.speedKmh > MAX_EXIT_KMH then hint('stop the car first', 2) return end
  local ok, cam = pcall(ac.grabCamera, 'No License walk')
  if not ok or not cam then
    local why = ''
    pcall(function() local _, e = ac.grabCamera('No License walk'); why = tostring(e or '') end)
    hint('camera is busy: ' .. why:sub(1, 60), 4)
    return
  end
  me.cam = cam
  me.active = true
  me.third = false
  local dir = car.isLeftHandDrive and -1 or 1
  local w = me.w
  w.pos = car.position + car.side * (SPAWN_SIDE * dir)
  w.pos.y = groundAt(w.pos, car.position.y)
  w.yaw = atan2(car.look.x, car.look.z)
  me.camYaw = w.yaw
  me.pitch = 0
  me.speed = 0
  w.state = 'idle'
  me.parked = vec3(car.position.x, car.position.y, car.position.z)
  pcall(function() physics.setCarNoInput(true) end)
  pedLoad()
  emoteLoad()
  hint('WASD walk   SHIFT run   mouse look   V view   B emotes   hold ALT to free the mouse   E back in the car', 6)
  dlog('out of the car')
end

local function getIn(reason)
  if not me.active then return end
  me.active = false
  me.menu = false
  emoteStop()
  if me.cam then pcall(function() me.cam:dispose() end); me.cam = nil end
  pcall(function() physics.setCarNoInput(false) end)
  pcall(function() physics.awakeCar(0) end)
  walkerHide(me.w)
  me.stopSends = 3
  if reason then hint(reason, 3) end
  dlog('back in the car')
end

local function updateMe(dt, car)
  local w = me.w
  -- toggles
  if keyPressed(KEY_TOGGLE) then
    if me.active then
      if flat(w.pos, car.position) <= ENTER_RANGE then getIn() else hint(string.format('your car is %d m away', math.floor(flat(w.pos, car.position))), 2) end
    else
      getOut(car)
    end
  end
  if not me.active then
    if me.stopSends > 0 then me.stopSends = me.stopSends - 1; send(0) end
    return
  end
  if keyPressed(KEY_VIEW) then me.third = not me.third end
  if keyPressed(KEY_EMOTES) then me.menu = not me.menu end
  if me.menu and keyPressed('Escape') then me.menu = false end
  -- the car moved a long way without you (admin teleport, pit reset): go with it
  if me.parked and flat(car.position, me.parked) > 40 then
    w.pos = car.position + car.side * SPAWN_SIDE
    w.pos.y = groundAt(w.pos, car.position.y)
    me.parked = vec3(car.position.x, car.position.y, car.position.z)
    hint('your car moved. you went with it', 3)
  end

  -- look. the mouse is only taken while the game is the active window and nothing is paused,
  -- and holding ALT frees it (so alt-tab and the pause menu behave)
  local md = nil
  local grabMouse = true
  pcall(function() grabMouse = sim.isWindowForeground ~= false and sim.isPaused ~= true and sim.isInMainMenu ~= true end)
  if keyDown('Menu') or me.menu then grabMouse = false end
  if grabMouse then
    pcall(function() md = ac.accessMouseDelta(true, true, true) end)
    pcall(function() ac.hideMouseCursor(true) end)
  end
  if md then
    me.camYaw = me.camYaw - md.x * MOUSE_SENS
    me.pitch = math.max(-1.35, math.min(1.35, me.pitch - md.y * MOUSE_SENS))
  end
  -- the camera has its own heading. in first person the body follows it; in third person the body
  -- turns to face wherever it is walking and the camera orbits around it
  local fwd = vec3(math.sin(me.camYaw), 0, math.cos(me.camYaw))
  local right = cross(fwd, vec3(0, 1, 0))

  -- move
  local mv = vec3(0, 0, 0)
  local f, b = keyDown(KEY_FWD), keyDown(KEY_BACK)
  if f then mv = mv + fwd end
  if b then mv = mv - fwd end
  if keyDown(KEY_LEFT) then mv = mv - right end
  if keyDown(KEY_RIGHT) then mv = mv + right end
  local moving = mv:length() > 0.1
  if me.menu then moving = false; mv = vec3(0, 0, 0) end
  if moving and me.w.state == 'emote' then emoteStop() end
  local running = moving and keyDown('Shift') and not b
  local want = moving and (running and RUN_SPEED or WALK_SPEED) or 0
  if b and not f then want = math.min(want, WALK_SPEED * 0.8) end
  me.speed = me.speed + (want - me.speed) * math.min(1, dt * (want > me.speed and 6 or 10))
  if moving then
    local dir = mv:normalize()
    local step = dir * (me.speed * dt)
    if not blocked(w.pos, dir, 0.55) then
      w.pos = w.pos + step
    else
      -- slide along it
      local sideDir = vec3(dir.z, 0, -dir.x)
      if not blocked(w.pos, sideDir, 0.55) and sideDir:dot(mv) >= 0 then w.pos = w.pos + sideDir * (me.speed * dt * 0.6)
      elseif not blocked(w.pos, -sideDir, 0.55) then w.pos = w.pos + (-sideDir) * (me.speed * dt * 0.6) end
    end
    local gy = groundAt(w.pos, w.pos.y)
    w.pos.y = w.pos.y + (gy - w.pos.y) * math.min(1, dt * 12)
  end
  -- animation state, and which way the body faces
  if w.state == 'emote' then
    -- hold the pose
  elseif not moving or me.speed < 0.15 then w.state = 'idle'
  elseif b and not f then w.state = 'back'
  elseif running then w.state = 'run'
  else w.state = 'walk' end
  local faceYaw = me.camYaw
  if me.third then
    faceYaw = w.yaw                              -- standing still: he holds his facing, the camera orbits round him
    if moving then
      local dir = mv:normalize()
      if b and not f then dir = -dir end        -- backpedalling: face away from the travel
      faceYaw = atan2(dir.x, dir.z)
    end
  end
  if w.state == 'emote' then
    -- the pose keeps its facing, the camera is free to orbit for the photo
  elseif me.third then
    local d = faceYaw - w.yaw
    while d > math.pi do d = d - 2 * math.pi end
    while d < -math.pi do d = d + 2 * math.pi end
    w.yaw = w.yaw + d * math.min(1, dt * 9)
  else
    w.yaw = me.camYaw
  end

  -- camera
  me.bob = me.bob + dt * (me.speed > 0.2 and (running and 11 or 7.5) or 0)
  local bobA = me.speed > 0.2 and (running and 0.045 or 0.025) or 0
  local look = vec3(math.sin(me.camYaw) * math.cos(me.pitch), math.sin(me.pitch), math.cos(me.camYaw) * math.cos(me.pitch))
  local eye
  if me.third then
    local head = w.pos + vec3(0, 1.45, 0)
    local back = -look
    local dist = 2.8
    local hit = nil
    pcall(function() hit = physics.raycastTrack(head, back, dist + 0.3) end)
    if hit and hit > 0 then dist = math.max(0.6, hit - 0.3) end
    eye = head + back * dist + right * 0.4
    local gy = groundAt(eye, eye.y - 1)
    if eye.y < gy + 0.35 then eye.y = gy + 0.35 end
    look = (w.pos + vec3(0, 1.3, 0) + fwd * 2.0 - eye):normalize()
    walkerDraw(w, dt)
  else
    eye = w.pos + vec3(0, EYE_HEIGHT + math.sin(me.bob) * bobA, 0) + right * (math.sin(me.bob * 0.5) * bobA * 0.6)
    walkerHide(w)
  end
  pcall(function()
    me.cam.transform = camMatrix(eye, look)
    me.cam.fov = me.third and 60 or 72
    me.cam.ownShare = 1
  end)

  -- tell everyone
  me.sendT = me.sendT + dt
  if me.sendT >= SEND_RATE then
    me.sendT = 0
    if w.state == 'emote' and w.emote then send(EMOTE_STATE_BASE + w.emote) else send(STATE_ID[w.state] or 1) end
  end
end

local function updateOthers(dt)
  for idx, w in pairs(others) do
    local c = ac.getCar(idx)
    if not c or not c.isConnected or t - w.lastT > 4 then
      walkerHide(w)
    else
      -- glide to the latest position, extrapolate a touch so it does not lag
      local target = w.tpos + w.vel * math.min(0.25, t - w.lastT)
      w.pos = w.pos + (target - w.pos) * math.min(1, dt * 9)
      local d = w.tyaw - w.yaw
      while d > math.pi do d = d - 2 * math.pi end
      while d < -math.pi do d = d + 2 * math.pi end
      w.yaw = w.yaw + d * math.min(1, dt * 10)
      walkerDraw(w, dt)
    end
  end
end

------------------------------------------------------------------ loop

local lastErr = nil
function script.update(dt)
  t = t + dt
  sim = ac.getSim()
  local car = ac.getCar(0)
  if not car then return end
  if t > 8 and not ped.folder then pedLoad() end   -- fetch the character in the background right after joining
  if t > 20 and not emo.folder then emoteLoad() end
  local ok, err = pcall(function()
    updateMe(dt, car)
    updateOthers(dt)
  end)
  if not ok and lastErr ~= tostring(err) then lastErr = tostring(err); dlog('error: ' .. lastErr) end
end

------------------------------------------------------------------ hud

local F_BOLD = 'Bahnschrift;Weight=Bold'
local function text(txt, size, pos, col)
  ui.pushDWriteFont(F_BOLD)
  ui.dwriteDrawText(txt, size, pos, col)
  ui.popDWriteFont()
end
local function textW(txt, size)
  ui.pushDWriteFont(F_BOLD)
  local w = ui.measureDWriteText(txt, size)
  ui.popDWriteFont()
  return w.x
end

-- the emote menu: a panel in the middle, one tile per emote, grouped
local hoverAnim = {}
local uiLastT = nil
local function drawEmoteMenu(sw, sh)
  local dt = math.min(0.1, uiLastT and (t - uiLastT) or 0.016)
  me.menuAnim = me.menuAnim + ((me.menu and 1 or 0) - me.menuAnim) * math.min(1, dt * 12)
  if me.menuAnim < 0.01 then return end
  local f = me.menuAnim
  local cols = 4
  local tileW, tileH, gap = 128, 44, 8
  local pw = cols * tileW + (cols - 1) * gap + 48
  -- height from the groups
  local rows = 0
  for _, g in ipairs(EMOTE_GROUPS) do
    local n = 0
    for _, e in ipairs(EMOTES) do if e.group == g then n = n + 1 end end
    if n > 0 then rows = rows + 1 + math.ceil(n / cols) end
  end
  local ph = 78 + rows * (tileH + gap) + 24 + 30
  local px, py = (sw - pw) / 2, (sh - ph) / 2 + (1 - f) * 20
  ui.transparentWindow('nl_emotes', vec2(px - 16, py - 16), vec2(pw + 32, ph + 32), true, true, function()
    pcall(function() if (ui.getScrollY() or 0) ~= 0 then ui.setScrollY(0, false, false) end end)
    local o = vec2(16, 16)
    local BLUE = rgbm(0, 0.47, 1, 1)
    ui.drawRectFilled(o + vec2(2, 8), o + vec2(pw + 2, ph + 8), rgbm(0, 0, 0, 0.35 * f), 16)
    ui.drawRectFilled(o, o + vec2(pw, ph), rgbm(0.016, 0.012, 0.024, 0.9 * f), 16)
    ui.drawRect(o + vec2(1, 1), o + vec2(pw - 1, ph - 1), rgbm(1, 1, 1, 0.08 * f), 16, ui.CornerFlags.All, 1.5)
    ui.drawRectFilled(o + vec2(0, 56), o + vec2(pw, 57), rgbm(1, 1, 1, 0.08 * f))
    text('EMOTES', 15, o + vec2(22, 16), rgbm(1, 1, 1, f))
    text('CLICK ONE TO STRIKE THE POSE. WALK TO STOP.  ' .. KEY_EMOTES:upper() .. ' OR ESC CLOSES THIS', 8, o + vec2(22, 38), rgbm(1, 1, 1, 0.45 * f))
    -- close + stop
    ui.setCursor(o + vec2(pw - 44, 14))
    ui.invisibleButton('##emclose', vec2(30, 30))
    local hv = ui.itemHovered()
    ui.drawRectFilled(o + vec2(pw - 44, 14), o + vec2(pw - 14, 44), rgbm(1, 1, 1, hv and 0.14 or 0.06), 8)
    text('X', 12, o + vec2(pw - 33, 20), rgbm(1, 1, 1, 0.85 * f))
    if ui.itemClicked(ui.MouseButton.Left) then me.menu = false end
    if me.w.state == 'emote' then
      ui.setCursor(o + vec2(pw - 130, 14))
      ui.invisibleButton('##emstop', vec2(78, 30))
      local hs = ui.itemHovered()
      ui.drawRectFilled(o + vec2(pw - 130, 14), o + vec2(pw - 52, 44), rgbm(1, 0.25, 0.22, hs and 0.9 or 0.7), 8)
      text('STOP', 11, o + vec2(pw - 130 + 22, 21), rgbm(1, 1, 1, f))
      if ui.itemClicked(ui.MouseButton.Left) then emoteStop() end
    end
    local y = 72
    for _, g in ipairs(EMOTE_GROUPS) do
      local items = {}
      for i, e in ipairs(EMOTES) do if e.group == g then items[#items + 1] = i end end
      if #items > 0 then
        text(g:upper(), 9, o + vec2(24, y + 6), rgbm(0, 0.47, 1, 0.9 * f))
        y = y + tileH + gap - 18
        for k, i in ipairs(items) do
          local e = EMOTES[i]
          local col = (k - 1) % cols
          local row = math.floor((k - 1) / cols)
          local tx, ty = 24 + col * (tileW + gap), y + row * (tileH + gap)
          ui.setCursor(o + vec2(tx, ty))
          ui.invisibleButton('##em' .. i, vec2(tileW, tileH))
          local hov = ui.itemHovered()
          hoverAnim[i] = (hoverAnim[i] or 0) + ((hov and 1 or 0) - (hoverAnim[i] or 0)) * math.min(1, dt * 14)
          local hf = hoverAnim[i]
          local active = me.w.state == 'emote' and me.w.emote == i
          local p1, p2 = o + vec2(tx, ty), o + vec2(tx + tileW, ty + tileH)
          ui.drawRectFilled(p1, p2, active and rgbm(0, 0.47, 1, 0.85 * f) or rgbm(1, 1, 1, (0.05 + 0.08 * hf) * f), 10)
          ui.drawRect(p1, p2, active and rgbm(0.5, 0.75, 1, f) or rgbm(1, 1, 1, (0.08 + 0.25 * hf) * f), 10, ui.CornerFlags.All, 1)
          text(e.label:upper(), 9, p1 + vec2(12, 10), rgbm(1, 1, 1, (0.85 + 0.15 * hf) * f))
          if e.props then text('WITH ' .. table.concat(e.props, ', '):upper(), 6, p1 + vec2(12, 27), rgbm(1, 1, 1, 0.45 * f)) end
          if ui.itemClicked(ui.MouseButton.Left) and me.menu then emoteStart(i) end
        end
        y = y + math.ceil(#items / cols) * (tileH + gap) + 10
      end
    end
    if emo.err then text('EMOTE PACK FAILED TO DOWNLOAD: ' .. emo.err:sub(1, 60), 8, o + vec2(24, ph - 24), rgbm(1, 0.3, 0.3, f))
    elseif not emo.folder then text('EMOTE PACK DOWNLOADING (10 MB, ONCE)...', 8, o + vec2(24, ph - 24), rgbm(1, 1, 1, 0.5 * f)) end
    pcall(function() ui.setMaxCursorY(ph + 20) end)
  end)
end

local uiErr = nil
function script.drawUI()
  if not sim then return end
  local sw, sh = sim.windowWidth, sim.windowHeight
  if me.active then
    local okm, errm = pcall(drawEmoteMenu, sw, sh)
    if not okm and uiErr ~= tostring(errm) then uiErr = tostring(errm); dlog('menu error: ' .. uiErr) end
  end
  uiLastT = t
  local ok, err = pcall(function()
    local car = ac.getCar(0)
    -- names over the other walkers
    for idx, w in pairs(others) do
      if w.visible then
        local sp = nil
        pcall(function() sp = ui.projectPoint(w.pos + vec3(0, 2.05, 0)) end)
        local d = flat(w.pos, sim.cameraPosition)
        if sp and sp.x and d < 80 and sp.x > -100 and sp.x < sw + 100 and sp.y > -50 and sp.y < sh + 50 then
          local name = ''
          pcall(function() name = ac.getDriverName(idx) or '' end)
          local k = math.max(0.6, 1 - d / 120)
          local size = 12 * k
          local tw = textW(name, size)
          ui.drawRectFilled(vec2(sp.x - tw / 2 - 8 * k, sp.y - 10 * k), vec2(sp.x + tw / 2 + 8 * k, sp.y + 10 * k), rgbm(0.03, 0.03, 0.04, 0.8), 6 * k)
          ui.drawRectFilled(vec2(sp.x - tw / 2 - 8 * k, sp.y - 10 * k), vec2(sp.x - tw / 2 - 5 * k, sp.y + 10 * k), rgbm(0, 0.47, 1, 1), 2 * k)
          text(name, size, vec2(sp.x - tw / 2, sp.y - size * 0.62), rgbm(1, 1, 1, 1))
        end
      end
    end
    if me.active and car then
      -- walking strip at the bottom
      local d = flat(me.w.pos, car.position)
      local near = d <= ENTER_RANGE
      local label = near and ('E   BACK IN THE CAR') or string.format('YOUR CAR   %d M', math.floor(d))
      local w, h = 300, 34
      local x, y = (sw - w) / 2, sh - 70
      ui.drawRectFilled(vec2(x, y), vec2(x + w, y + h), rgbm(0.03, 0.03, 0.04, 0.78), 8)
      ui.drawRectFilled(vec2(x, y), vec2(x + 4, y + h), near and rgbm(0, 0.96, 0.38, 1) or rgbm(0, 0.47, 1, 1), 8)
      text(label, 12, vec2(x + (w - textW(label, 12)) / 2, y + 9), rgbm(1, 1, 1, 1))
      -- direction to the car when it is out of sight
      if not near then
        local rel = car.position - me.w.pos
        local ang = atan2(rel.x, rel.z) - me.camYaw
        local cx, cy, r = x + w - 20, y + h / 2, 8
        local function pt(a, rr) return vec2(cx + math.sin(a) * rr, cy - math.cos(a) * rr) end
        pcall(function() ui.drawTriangleFilled(pt(ang, r), pt(ang + 2.5, r * 0.8), pt(ang - 2.5, r * 0.8), rgbm(1, 1, 1, 0.9)) end)
      end
      local st = me.w.state == 'emote' and ('EMOTE   ' .. (EMOTES[me.w.emote or 0] and EMOTES[me.w.emote].label:upper() or '')) or me.w.state:upper()
      text(st, 8, vec2(x + 10, y + h + 6), rgbm(1, 1, 1, 0.35))
      local bh = KEY_EMOTES:upper() .. '   EMOTES'
      text(bh, 8, vec2(x + w - 10 - textW(bh, 8), y + h + 6), rgbm(1, 1, 1, 0.35))
      if ped.err then text('CHARACTER DOWNLOAD FAILED: ' .. ped.err:sub(1, 60), 8, vec2(x, y - 16), rgbm(1, 0.3, 0.3, 1))
      elseif ped.modelErr then text('CHARACTER MODEL FAILED: ' .. ped.modelErr:sub(1, 60), 8, vec2(x, y - 16), rgbm(1, 0.3, 0.3, 1))
      elseif not ped.folder then text('CHARACTER DOWNLOADING...', 8, vec2(x, y - 16), rgbm(1, 1, 1, 0.5))
      elseif me.third and me.w.model == nil then text('CHARACTER NOT CREATED YET', 8, vec2(x, y - 16), rgbm(1, 1, 1, 0.5)) end
    end
    if t < me.hintT then
      local a = math.min(1, me.hintT - t)
      local size = 11
      local tw = textW(me.hint, size)
      local x, y = (sw - tw) / 2 - 14, sh - 118
      ui.drawRectFilled(vec2(x, y), vec2(x + tw + 28, y + 30), rgbm(0.03, 0.03, 0.04, 0.8 * a), 8)
      text(me.hint, size, vec2(x + 14, y + 8), rgbm(1, 1, 1, a))
    end
    if not me.active and car and car.speedKmh < MAX_EXIT_KMH and t > 5 then
      -- quiet reminder when stopped
      local s = KEY_TOGGLE .. '   GET OUT'
      local tw = textW(s, 9)
      text(s, 9, vec2(sw - tw - 24, sh - 28), rgbm(1, 1, 1, 0.28))
    end
  end)
  if not ok and uiErr ~= tostring(err) then uiErr = tostring(err); dlog('ui error: ' .. uiErr) end
end
