-- No License Customs - server script
-- Respray, wheels, calipers, interior, UK plate text, underglow, looks, easy tuning, showroom camera.
-- Everyone on the server sees everyone's build. Loaded automatically from csp_extra_options.ini.

local VERSION = '2.2'

-- Key that opens the customs menu (name from ui.KeyIndex: End, Home, Insert, F9, F10 ...). Rebindable in the Save tab.
local MENU_KEY = 'End'
local HINT_SECONDS = 30

------------------------------------------------------------------ car knowledge

-- material names per car in the No License pack. Any other car falls back to name patterns.
local CARS = {
  nolicense_bmw_m3_g80 = {
    body = { 'ext_Body_Paint' },
    rims = { 'ext_Wheel_paint1' },
    calipers = { 'ext_Wheel_brake_caliper' },
    leather = { 'int_leather_paint2', 'int_leather_paint1', 'INT_ALCANTARA', 'int_leather_paint3', 'st_wheel_leather', 'INT_LEATHER_2' },
    accent = { 'int_light_paint1', 'INT_RED' },
    plate = { material = 'licenseplate_US', sheet = true },
  },
  nolicense_c63_23 = {
    body = { 'ext_Body_Paint' },
    rims = { 'ext_Wheel_paint1' },
    calipers = { 'ext_Wheel_brake_caliper' },
    leather = { 'IntAlcnt', 'int_leather_paint1', 'int_leather_paint2' },
    accent = { 'IntPianoBlack', 'intPlasticRed', 'int_light_paint1' },
    plate = { material = 'EXT_LP_US', sheet = true },
  },
  nolicense_clk55_amgkitturbo = {
    body = { 'body' },
    rims = { 'Material #38BDF' },
    leather = { 'leather_2', 'leather' },
    plate = { material = 'Material #25ggre', aspect = 4.00 },
  },
  nolicense_g82_comp_coupe = {
    body = { 'ext_Body_Paint' },
    rims = { 'ext_Wheel_paint1' },
    calipers = { 'ext_Wheel_brake_caliper' },
    leather = { 'leathertop', 'int_leather_paint2', 'leatherseat1', 'int_leather_paint3', 'int_leather_paint1' },
    plate = { material = 'EXT_PLATE', aspect = 1.78 },
  },
  nolicense_mercedes_a45_brabus = {
    body = { 'car_paint' },
    rims = { 'T5R_2PC' },
    calipers = { 'brake_calipers' },
    leather = { 'leather_2' },
    plate = { material = 'PlateNM', aspect = 4.00 },
  },
  nolicense_realistic_bmw_m340i_g20_chris = {
    body = { 'EXT_CARPAINT' },
    rims = { 'EXT_RIM' },
    calipers = { 'Brake_Caliper' },
    leather = { 'dash_leather', 'red_leather' },
    accent = { 'INT_CENTER_CONSOLE_CARBON', 'INT_CENTER_CONSOLE_PLASTIC', 'INT_CENTER_CONSOLE_SILVER', 'INT_CENTER_CONSOLE_GLOSS_BLACK' },
    plate = { material = 'chris_plate', aspect = 2.00 },
  },
  nolicense_ford_mustang_gt350 = {
    body = { 'ext_Body_Paint' },
    rims = { 'ext_Wheel_paint1' },
    calipers = { 'ext_Wheel_brake_caliper' },
    leather = { 'INT_LEATHER', 'int_leather_paint2', 'INT_ALCANTARA', 'int_leather_paint3', 'INT_SW_LEATHER_COLOR', 'int_leather_paint1' },
    accent = { 'INT_red' },
    plate = { material = 'vehicle_genericmud_car', aspect = 1.78 },
  },
  nolicense_jeep_trackhawk = {
    body = { 'EXT_CARPAINT' },
    rims = { 'EXT_RIM' },
    calipers = { 'EXT_caliper' },
    leather = { 'INT_LEATHER_2', 'INT_LEATHER_PERFORATED', 'INT_LEATHER' },
    plate = { material = 'vehicle_genericmud_car', aspect = 4.00 },
  },
  nolicense_porsche_gt3rs = {
    body = { 'EXT_CARPAINT', '1EXT_CARPAINT2' },
    rims = { 'rim_gloss_black', 'rimblack', 'rimpaint' },
    calipers = { 'Brake_Caliper' },
    leather = { 'INT_LEATHER', 'INT_ALCNT', 'INT_LEATHER_COLORED' },
    plate = { material = 'EXT_PLATE_plastic', aspect = 4.00 },
  },
  nolicense_realistic_mercedes_e63_w213 = {
    body = { 'ext_Body_Paint' },
    rims = { 'ext_Wheel_paint1', 'ext_Wheel_paint2' },
    calipers = { 'ext_Wheel_brake_caliper' },
    leather = { 'INT_LEATHER_BLACK', 'int_leather_paint3', 'int_leather_paint6', 'int_leather_paint1', 'int_leather_paint2', 'int_leather_paint5' },
    accent = { 'INT_PLASTIC_RED', 'int_light_paint1' },
    plate = { material = 'EXT_LP_US', sheet = true },
  },
  nolicense_volkswagen_golf_r_mk8 = {
    body = { 'ext_Body_Paint' },
    rims = { 'ext_Wheel_paint1', 'EXT_Rim' },
    calipers = { 'ext_Wheel_brake_caliper' },
    leather = { 'int_leather_paint1', 'INT_BLUE_LEATHER', 'INT_LEATHER', 'INT_ALCNT', 'int_leather_paint2' },
    accent = { 'INT_PIANO_BLACK', 'INT_RED' },
    plate = { material = 'EXT_LP_US', aspect = 2.35 },
  },
  nolicense_tesla_model3_24 = {
    body = { 'ext_carpaint' },
    rims = { 'RIM_2', 'Rim' },
    calipers = { 'Caliper' },
    leather = { 'int_leather_2', 'int_leather_1', 'int_leather_3' },
    accent = { 'int_carpaint', 'int_plastic_red' },
    plate = { material = 'EXT_PLATE', aspect = 4.00 },
  },
  nolicense_rr_cullinan = {
    body = { 'carpaint', 'carpaint2' },
    rims = { 'rim_1', 'rim_2', 'rim_3' },
    calipers = { 'caliper' },
    leather = { 'int_leather1', 'int_leather2', 'seat_leather', 'int_leather3', 'suit_leather1' },
    accent = { 'int_dashinsert', 'int_plasticred' },
    plate = { material = 'plate', aspect = 4.00 },
  },
  nolicense_bmw_x5m_f95 = {
    body = { 'ext_Body_Paint' },
    rims = { 'ext_Wheel_paint1' },
    calipers = { 'ext_Wheel_brake_caliper' },
    leather = { 'int_leather_paint3', 'st_wheel_leather', 'alcnt', 'leather_2', 'leather_roof', 'int_leather_paint2', 'int_leather_paint1', 'leather_1' },
    accent = { 'int_light_paint1' },
    plate = { material = 'licenseplate_US_emission', sheet = true },
  },
}

local SHEET_RECTS = {
  { 455 / 2048, 80 / 2048, 1125 / 2048, 381 / 2048 },
  { 455 / 2048, 508 / 2048, 1125 / 2048, 479 / 2048 },
  { 455 / 2048, 1003 / 2048, 1131 / 2048, 478 / 2048 },
  { 461 / 2048, 1545 / 2048, 1125 / 2048, 380 / 2048 },
}

local GROUPS = {
  { id = 'body',     label = 'Body',      match = { 'body_paint', 'carpaint', 'car_paint', '^body$', 'paint' }, exclude = { 'black', '^int', 'underside', 'logo', 'wheel', 'rim', 'caliper', 'light' } },
  { id = 'rims',     label = 'Wheels',    match = { 'wheel_paint', 'rim' },                                     exclude = { 'logo', 'bolt', 'lug', 'tyre', 'tire', 'chrome', 'trim', 'decal', 'plastic' } },
  { id = 'calipers', label = 'Calipers',  match = { 'caliper', 'calper' },                                      exclude = { 'logo', 'frame', 'chrome', '_at$' } },
  { id = 'leather',  label = 'Leather',   match = { 'leather', 'alcant', 'alcnt', 'seat_' },                    exclude = { 'decal', 'belt', 'monitor' } },
  { id = 'accent',   label = 'Accents',   match = { 'int_light_paint', 'plastic_red', 'int_red', 'plasticred', 'int_carpaint', 'center_console', 'dashinsert', 'piano' }, exclude = {} },
}

local FINISHES = { 'Gloss', 'Matte', 'Satin', 'Chrome' }

------------------------------------------------------------------ state

local store = ac.storage { builds = '{}', shareBuild = true, showOthers = true, tunes = '{}' }

local function defaultBuild()
  return { v = 2, body = nil, rims = nil, calipers = nil, leather = nil, accent = nil, finish = 0, plate = '', platestyle = 0, glow = nil, rgbcycle = false, brakeflash = false, glowpower = 0.6 }
end

local status, statusTimer = '', 0
local menu = { open = false, close = false, hintT = 0 }
local menuButton = nil
local function dlog(s) ac.log('nl_customs: ' .. s) end
local function say(s) status = s; statusTimer = 6; dlog(s) end

local myCarID = ac.getCarID(0) or ''
local build = defaultBuild()
local dirty, dirtyTimer = false, 0
local pick = {
  body = rgbm(0.9, 0.1, 0.1, 1), rims = rgbm(0.08, 0.08, 0.08, 1), calipers = rgbm(1, 0.75, 0, 1),
  leather = rgbm(0.12, 0.12, 0.12, 1), accent = rgbm(0.0, 0.9, 0.35, 1), glow = rgbm(0.0, 0.9, 0.35, 1),
}
local enabled = { body = false, rims = false, calipers = false, leather = false, accent = false, glow = false }
local plateText = ''
local t = 0

local function toRgbTable(c) return { c.r, c.g, c.b } end

------------------------------------------------------------------ scene: find the meshes

local rootCache = {}
local function carRoot(index)
  if rootCache[index] then return rootCache[index] end
  local ok, ref = pcall(ac.findNodes, 'carRoot:' .. tostring(index))
  if ok and ref then
    local okn, n = pcall(function() return ref:size() end)
    if okn and n and n > 0 then rootCache[index] = ref; return ref end
  end
  return nil
end

local function anyMatch(name, patterns)
  local lower = name:lower()
  for _, p in ipairs(patterns) do if lower:find(p) then return true end end
  return false
end

local function materialsFor(index, groupId)
  local cfg = CARS[ac.getCarID(index) or '']
  if cfg and cfg[groupId] then return cfg[groupId] end
  local group = nil
  for _, g in ipairs(GROUPS) do if g.id == groupId then group = g end end
  local root = carRoot(index)
  if not group or not root then return {} end
  local names, picked = {}, {}
  pcall(function()
    local all = root:findMeshes('?')
    for i = 1, all:size() do
      local m = all:materialName(i)
      if m and anyMatch(m, group.match) and not anyMatch(m, group.exclude) then picked[m] = true end
    end
  end)
  for m in pairs(picked) do names[#names + 1] = m end
  return names
end

local function findByMaterial(root, name)
  for _, f in ipairs({ '{ material:' .. name:gsub(' ', '?') .. ' }', 'material:' .. name:gsub(' ', '?'), 'material:' .. name }) do
    local ok, r = pcall(function() return root:findMeshes(f) end)
    if ok and r then
      local okn, n = pcall(function() return r:size() end)
      if okn and n and n > 0 then return r, n end
    end
  end
  return nil, 0
end

local matCache = {}
local scanReport = {}
local function groupMeshes(index, groupId)
  local key = index .. ':' .. groupId
  if matCache[key] ~= nil then return matCache[key] end
  local root = carRoot(index)
  if not root then return {} end
  local refs, found, missing = {}, {}, {}
  for _, m in ipairs(materialsFor(index, groupId)) do
    local r, n = findByMaterial(root, m)
    if r then
      pcall(function() r:ensureUniqueMaterials() end)   -- so painting this car never paints other copies of the same model
      refs[#refs + 1] = r
      found[#found + 1] = m .. '(' .. n .. ')'
    else
      missing[#missing + 1] = m
    end
  end
  if index == 0 then scanReport[groupId] = string.format('%s: %s%s', groupId, #found > 0 and table.concat(found, ' ') or 'nothing found', #missing > 0 and ('  missing ' .. table.concat(missing, ' ')) or '') end
  matCache[key] = refs
  return refs
end

-- stock values so Reset really goes back to stock
local stock = {}
local PROPS = { 'ksSpecular', 'ksSpecularEXP', 'ksEmissive', 'ksAmbient', 'ksDiffuse', 'fresnelMaxLevel', 'fresnelC', 'fresnelEXP', 'detailUVMultiplier', 'useDetail' }
local function remember(index, groupId, refs)
  local key = index .. ':' .. groupId
  if stock[key] then return end
  local snap = {}
  for i, ref in ipairs(refs) do
    local vals = {}
    for _, p in ipairs(PROPS) do
      local ok, v = pcall(function() return ref:getMaterialPropertyValue(p) end)
      if ok and v ~= nil then vals[p] = v end
    end
    snap[i] = vals
  end
  stock[key] = snap
end

local painted = {}
local function restore(index, groupId)
  local key = index .. ':' .. groupId
  if not painted[key] then return end
  painted[key] = nil
  local refs = groupMeshes(index, groupId)
  local snap = stock[key]
  for i, ref in ipairs(refs) do
    pcall(function() ref:resetSkin() end)              -- original textures back
    if snap and snap[i] then
      for p, v in pairs(snap[i]) do pcall(function() ref:setMaterialProperty(p, v) end) end
    end
  end
end

-- the paint itself: a solid colour texture replaces the diffuse map (ksDiffuse is a brightness number in AC, not a colour)
local function paint(index, groupId, c, finish)
  local refs = groupMeshes(index, groupId)
  remember(index, groupId, refs)
  if #refs > 0 then painted[index .. ':' .. groupId] = true end
  for _, ref in ipairs(refs) do
    local ok, err = pcall(function()
      local col = rgbm(c[1], c[2], c[3], 1)
      if finish == 3 then col = rgbm(0.55 + c[1] * 0.3, 0.55 + c[2] * 0.3, 0.55 + c[3] * 0.3, 1) end
      ref:setMaterialTexture('txDiffuse', col)
      ref:setMaterialProperty('ksEmissive', rgb(0, 0, 0))
      -- wheels and calipers often multiply the paint by a tinted detail map, which turns blue into purple. flatten it.
      if groupId == 'rims' or groupId == 'calipers' or groupId == 'accent' then
        pcall(function() ref:setMaterialTexture('txDetail', rgbm(0.5, 0.5, 0.5, 1)) end)
        pcall(function() ref:setMaterialProperty('useDetail', 0) end)
      end
      if finish then
        if finish == 1 then            -- matte
          ref:setMaterialProperty('ksSpecular', 0.03); ref:setMaterialProperty('ksSpecularEXP', 8)
          pcall(function() ref:setMaterialProperty('fresnelMaxLevel', 0.05) end)
        elseif finish == 2 then        -- satin
          ref:setMaterialProperty('ksSpecular', 0.25); ref:setMaterialProperty('ksSpecularEXP', 30)
          pcall(function() ref:setMaterialProperty('fresnelMaxLevel', 0.25) end)
        elseif finish == 3 then        -- chrome: mirror reflections everywhere, tight highlight
          ref:setMaterialProperty('ksSpecular', 1.2); ref:setMaterialProperty('ksSpecularEXP', 220)
          ref:setMaterialProperty('ksAmbient', 0.25); ref:setMaterialProperty('ksDiffuse', 0.15)
          pcall(function() ref:setMaterialProperty('fresnelMaxLevel', 1.0); ref:setMaterialProperty('fresnelC', 0.95); ref:setMaterialProperty('fresnelEXP', 1.0) end)
          pcall(function() ref:setMaterialTexture('txMaps', rgbm(1, 1, 1, 1)) end)
        else                           -- gloss
          ref:setMaterialProperty('ksSpecular', 0.55); ref:setMaterialProperty('ksSpecularEXP', 90)
          pcall(function() ref:setMaterialProperty('fresnelMaxLevel', 0.45) end)
        end
      end
    end)
    if not ok then dlog('paint ' .. groupId .. ': ' .. tostring(err)) end
  end
end

------------------------------------------------------------------ plates

local PLATE_FONT = 'Arial;Weight=Bold'
local YELLOW = rgbm(0.99, 0.82, 0.09, 1)
local BLUE = rgbm(0.0, 0.2, 0.6, 1)
local INK = rgbm(0.07, 0.07, 0.07, 1)
local WHITE = rgbm(1, 1, 1, 1)
local PLATE_STYLES = { 'UK yellow', 'UK white', 'Show plate' }

local function drawUKPlate(x, y, w, h, text, bg, style)
  style = style or 0
  local ink = INK
  if style == 1 then bg = rgbm(0.96, 0.96, 0.96, 1) end
  if style == 2 then bg = rgbm(0.05, 0.05, 0.05, 1); ink = rgbm(0.95, 0.95, 0.95, 1) end
  ui.drawRectFilled(vec2(x, y), vec2(x + w, y + h), bg or YELLOW)
  local eh = math.min(h, w / 2.2)
  local bw = w * 0.125
  ui.drawRectFilled(vec2(x, y), vec2(x + bw, y + h), BLUE)
  local jw, jh = bw * 0.68, eh * 0.22
  local jx, jy = x + (bw - jw) / 2, y + h / 2 - eh * 0.36
  ui.drawRectFilled(vec2(jx, jy), vec2(jx + jw, jy + jh), rgbm(0.0, 0.14, 0.5, 1))
  ui.drawRectFilled(vec2(jx, jy + jh * 0.38), vec2(jx + jw, jy + jh * 0.62), WHITE)
  ui.drawRectFilled(vec2(jx + jw * 0.4, jy), vec2(jx + jw * 0.6, jy + jh), WHITE)
  ui.drawRectFilled(vec2(jx, jy + jh * 0.44), vec2(jx + jw, jy + jh * 0.56), rgbm(0.8, 0.06, 0.18, 1))
  ui.drawRectFilled(vec2(jx + jw * 0.45, jy), vec2(jx + jw * 0.55, jy + jh), rgbm(0.8, 0.06, 0.18, 1))
  local inset = eh * 0.055
  ui.drawRect(vec2(x + bw + inset, y + inset), vec2(x + w - inset, y + h - inset), ink, eh * 0.1, ui.CornerFlags.All, math.max(2, eh * 0.022))
  ui.pushDWriteFont(PLATE_FONT)
  local bs = math.min(eh * 0.26, bw * 0.42)
  local bsz = ui.measureDWriteText('UK', bs)
  ui.dwriteDrawText('UK', bs, vec2(x + (bw - bsz.x) / 2, y + h / 2 + eh * 0.02), WHITE)
  local mainX = x + bw + w * 0.035
  local mainW = w - bw - w * 0.07
  local reg = (text and text ~= '') and text or 'NO LICENSE'
  local size = eh * 0.62
  local tsz = ui.measureDWriteText(reg, size)
  while tsz.x > mainW * 0.92 and size > 8 do
    size = size * 0.92
    tsz = ui.measureDWriteText(reg, size)
  end
  ui.dwriteDrawText(reg, size, vec2(mainX + (mainW - tsz.x) / 2, y + h / 2 - tsz.y / 2 - eh * 0.04), ink)
  local ss = eh * 0.075
  local ssz = ui.measureDWriteText('N O   L I C E N S E', ss)
  ui.dwriteDrawText('N O   L I C E N S E', ss, vec2(mainX + (mainW - ssz.x) / 2, y + h - eh * 0.16), ink)
  ui.popDWriteFont()
end

local plateApplied = {}
local function applyPlate(index, text, force, style)
  text = text or ''
  style = style or 0
  local key = text .. '#' .. tostring(style)
  if not force and plateApplied[index] == key then return end
  local cfg = CARS[ac.getCarID(index) or '']
  local root = carRoot(index)
  if not root then return end
  local ref = nil
  if cfg and cfg.plate then ref = findByMaterial(root, cfg.plate.material) end
  if not ref then
    ref = findByMaterial(root, '?plate?') or findByMaterial(root, '?Plate?') or findByMaterial(root, '?PLATE?')
    if not ref then return end
    cfg = { plate = { aspect = 4.0 } }
  end
  local sheet = cfg.plate.sheet
  local size = sheet and vec2(2048, 2048) or vec2(1024, math.floor(1024 / (cfg.plate.aspect or 4.0)))
  local ok, err = pcall(function()
    ref:ensureUniqueMaterials()
    ref:setMaterialTexture('txDiffuse', {
      textureSize = size,
      background = rgbm(0, 0, 0, 1),
      callback = function()
        if sheet then
          for i, r in ipairs(SHEET_RECTS) do
            drawUKPlate(r[1] * size.x, r[2] * size.y, r[3] * size.x, r[4] * size.y, text, (i == 2 or i == 3) and YELLOW or rgbm(0.96, 0.96, 0.96, 1), style)
          end
        else
          drawUKPlate(0, 0, size.x, size.y, text, YELLOW, style)
        end
      end,
    })
  end)
  if ok then plateApplied[index] = key else dlog('plate: ' .. tostring(err)) end
end

local function resetPlate(index)
  if not plateApplied[index] then return end
  local cfg = CARS[ac.getCarID(index) or '']
  local root = carRoot(index)
  if not root then return end
  local ref = cfg and cfg.plate and findByMaterial(root, cfg.plate.material) or nil
  if ref then pcall(function() ref:resetSkin() end) end
  plateApplied[index] = nil
end

------------------------------------------------------------------ underglow

local glowLights = {}
local hueT = 0

local function setGlow(index, c, cycle, power, brakeflash)
  local entry = glowLights[index]
  if not c then
    if entry then
      for _, l in ipairs(entry.lights) do pcall(function() l:dispose() end) end
      glowLights[index] = nil
    end
    return
  end
  if not entry then
    entry = { lights = {} }
    for i = 1, 4 do
      local ok, l = pcall(function() return ac.LightSource(ac.LightType.Regular) end)
      if ok and l then
        pcall(function()
          l.range = 3.2; l.rangeGradientOffset = 0.15; l.specularMultiplier = 0; l.fadeAt = 300; l.fadeSmooth = 50
        end)
        entry.lights[#entry.lights + 1] = l
      end
    end
    glowLights[index] = entry
  end
  entry.colour = c
  entry.cycle = cycle == true
  entry.power = (power or 0.6) * 5
  entry.brakeflash = brakeflash == true
  for _, l in ipairs(entry.lights) do pcall(function() l.color = rgb(c[1], c[2], c[3]) * entry.power end) end
end

local function hsv(h)
  local r, g, b
  local i = math.floor(h * 6) % 6
  local f = h * 6 - math.floor(h * 6)
  local q, tt = 1 - f, f
  if i == 0 then r, g, b = 1, tt, 0 elseif i == 1 then r, g, b = q, 1, 0 elseif i == 2 then r, g, b = 0, 1, tt
  elseif i == 3 then r, g, b = 0, q, 1 elseif i == 4 then r, g, b = tt, 0, 1 else r, g, b = 1, 0, q end
  return r, g, b
end

local function updateGlow(dt)
  hueT = hueT + dt * 0.12
  for index, entry in pairs(glowLights) do
    local car = ac.getCar(index)
    if car and #entry.lights == 4 then
      local p, f, s, up = car.position, car.look, car.side, car.up
      local offs = { { 0.6, 1.3 }, { -0.6, 1.3 }, { 0.6, -1.3 }, { -0.6, -1.3 } }
      local col = nil
      if entry.cycle then
        local r, g, b = hsv((hueT + index * 0.13) % 1)
        col = rgb(r, g, b) * entry.power
      end
      if entry.brakeflash and car.brake > 0.15 then
        col = rgb(1, 0.02, 0.02) * (entry.power * 1.4 * (0.7 + 0.3 * math.sin(hueT * 60)))
      elseif entry.brakeflash and not entry.cycle then
        col = rgb(entry.colour[1], entry.colour[2], entry.colour[3]) * entry.power
      end
      for i, l in ipairs(entry.lights) do
        l.position = p + f * offs[i][2] + s * offs[i][1] + up * 0.12
        if col then l.color = col end
      end
    end
  end
end

------------------------------------------------------------------ whole builds

local function applyBuild(index, b)
  if not b then return end
  for _, g in ipairs(GROUPS) do
    local c = b[g.id]
    if c then paint(index, g.id, c, g.id == 'body' and (b.finish or 0) or nil) else restore(index, g.id) end
  end
  if (b.plate or '') ~= '' or (b.platestyle or 0) ~= 0 then applyPlate(index, b.plate or '', false, b.platestyle or 0) else resetPlate(index) end
  setGlow(index, b.glow, b.rgbcycle, b.glowpower, b.brakeflash)
end

local function resetCar(index)
  for _, g in ipairs(GROUPS) do restore(index, g.id) end
  resetPlate(index)
  setGlow(index, nil)
end

local function loadSaved()
  local ok, all = pcall(function() return JSON.parse(store.builds) end)
  if not ok or type(all) ~= 'table' then all = {} end
  return all
end

local function saveBuild()
  local all = loadSaved()
  all[myCarID] = build
  store.builds = JSON.stringify(all)
  say('Saved. It comes back every time you drive this car.')
end

local function syncEditorFromBuild()
  for _, g in ipairs(GROUPS) do
    local c = build[g.id]
    enabled[g.id] = c ~= nil
    if c then pick[g.id] = rgbm(c[1], c[2], c[3], 1) end
  end
  enabled.glow = build.glow ~= nil
  if build.glow then pick.glow = rgbm(build.glow[1], build.glow[2], build.glow[3], 1) end
  plateText = build.plate or ''
end

------------------------------------------------------------------ sync

local FLAG = { body = 1, rims = 2, calipers = 4, leather = 8, accent = 16, glow = 32, rgbcycle = 128, brakeflash = 256 }
local syncEvent = nil
local remoteBuilds = {}

local function onPacket(sender, data)
  if sender == nil or sender.index == 0 then return end
  local b = defaultBuild()
  local flags = data.flags
  local function has(bit) return math.floor(flags / bit) % 2 == 1 end
  if has(FLAG.body) then b.body = { data.body.r, data.body.g, data.body.b } end
  if has(FLAG.rims) then b.rims = { data.rims.r, data.rims.g, data.rims.b } end
  if has(FLAG.calipers) then b.calipers = { data.calipers.r, data.calipers.g, data.calipers.b } end
  if has(FLAG.leather) then b.leather = { data.leather.r, data.leather.g, data.leather.b } end
  if has(FLAG.accent) then b.accent = { data.accent.r, data.accent.g, data.accent.b } end
  if has(FLAG.glow) then b.glow = { data.glow.r, data.glow.g, data.glow.b } end
  b.rgbcycle = has(FLAG.rgbcycle)
  b.brakeflash = has(FLAG.brakeflash)
  b.finish = data.finish or 0
  b.platestyle = data.style or 0
  b.glowpower = (data.power or 150) / 255
  b.plate = data.plate or ''
  remoteBuilds[sender.index] = b
  if store.showOthers then
    if flags == 0 and b.plate == '' and b.platestyle == 0 then resetCar(sender.index) else applyBuild(sender.index, b) end
  end
end

pcall(function()
  syncEvent = ac.OnlineEvent({
    ac.StructItem.key('NLCustomsSrv2'),
    flags = ac.StructItem.int32(),
    body = ac.StructItem.rgb(), rims = ac.StructItem.rgb(), calipers = ac.StructItem.rgb(),
    leather = ac.StructItem.rgb(), accent = ac.StructItem.rgb(), glow = ac.StructItem.rgb(),
    plate = ac.StructItem.string(12),
    style = ac.StructItem.byte(), power = ac.StructItem.byte(), finish = ac.StructItem.byte(),
  }, onPacket)
end)

local function broadcast()
  if not syncEvent then return end
  local b = store.shareBuild and build or defaultBuild()
  local flags = 0
  for k, bit in pairs(FLAG) do
    if (k == 'rgbcycle' or k == 'brakeflash') then if b[k] then flags = flags + bit end
    elseif b[k] then flags = flags + bit end
  end
  local function rgbOf(c) return c and rgb(c[1], c[2], c[3]) or rgb(0, 0, 0) end
  pcall(function()
    syncEvent({
      flags = flags,
      body = rgbOf(b.body), rims = rgbOf(b.rims), calipers = rgbOf(b.calipers),
      leather = rgbOf(b.leather), accent = rgbOf(b.accent), glow = rgbOf(b.glow),
      plate = b.plate or '', style = b.platestyle or 0, finish = b.finish or 0,
      power = math.floor(math.max(0, math.min(1, b.glowpower or 0.6)) * 255),
    }, true)
  end)
end

------------------------------------------------------------------ editor -> build

local function pushEditor()
  for _, g in ipairs(GROUPS) do build[g.id] = enabled[g.id] and toRgbTable(pick[g.id]) or nil end
  build.glow = enabled.glow and toRgbTable(pick.glow) or nil
  build.plate = plateText
  applyBuild(0, build)
  dirty = true
  dirtyTimer = 0.6
end

local function resetAll()
  build = defaultBuild()
  syncEditorFromBuild()
  resetCar(0)
  local all = loadSaved()
  all[myCarID] = nil
  store.builds = JSON.stringify(all)
  dirty = true
  dirtyTimer = 0.4
  say('Back to stock')
end

local function exportCode()
  pcall(function() ac.setClipboardText('NLB2:' .. JSON.stringify(build)) end)
  say('Build code copied. Paste it in Discord, friends import it with one click.')
end

local function importCode()
  local ok, txt = pcall(ui.getClipboardText)
  if not ok or type(txt) ~= 'string' or (txt:sub(1, 5) ~= 'NLB2:' and txt:sub(1, 5) ~= 'NLB1:') then say('No build code in the clipboard') return end
  local ok2, b = pcall(function() return JSON.parse(txt:sub(6)) end)
  if not ok2 or type(b) ~= 'table' then say('That code is broken') return end
  local nb = defaultBuild()
  for k, v in pairs(b) do nb[k] = v end
  if nb.matte then nb.finish = 1 end
  build = nb
  syncEditorFromBuild()
  applyBuild(0, build)
  dirty = true
  dirtyTimer = 0.4
  say('Build imported')
end

local LOOKS = {
  { name = 'No License', body = { 0.04, 0.04, 0.045 }, finish = 1, rims = { 0.03, 0.03, 0.03 }, calipers = { 0.0, 0.94, 0.35 }, accent = { 0.0, 0.94, 0.35 }, glow = { 0.0, 0.94, 0.35 }, platestyle = 2 },
  { name = 'Stealth', body = { 0.08, 0.08, 0.09 }, finish = 1, rims = { 0.05, 0.05, 0.05 }, calipers = { 0.08, 0.08, 0.08 }, leather = { 0.08, 0.08, 0.08 }, platestyle = 2 },
  { name = 'Midnight', body = { 0.2, 0.05, 0.4 }, finish = 0, rims = { 0.03, 0.03, 0.03 }, calipers = { 0.8, 0.1, 0.9 }, glow = { 0.6, 0.1, 1.0 }, platestyle = 0 },
  { name = 'Candy', body = { 0.72, 0.02, 0.05 }, finish = 0, rims = { 0.85, 0.65, 0.15 }, calipers = { 0.85, 0.65, 0.15 }, leather = { 0.5, 0.05, 0.05 }, platestyle = 1 },
  { name = 'Frozen', body = { 0.52, 0.53, 0.55 }, finish = 1, rims = { 0.08, 0.08, 0.08 }, calipers = { 1.0, 0.75, 0.0 }, glow = { 1.0, 1.0, 1.0 }, platestyle = 1 },
  { name = 'Miami', body = { 0.0, 0.62, 0.8 }, finish = 0, rims = { 0.95, 0.95, 0.93 }, calipers = { 0.98, 0.3, 0.6 }, glow = { 0.98, 0.3, 0.7 }, platestyle = 1 },
  { name = 'Chrome', body = { 0.8, 0.82, 0.85 }, finish = 3, rims = { 0.05, 0.05, 0.05 }, calipers = { 0.9, 0.1, 0.1 }, platestyle = 2 },
  { name = 'Satin gold', body = { 0.78, 0.6, 0.18 }, finish = 2, rims = { 0.05, 0.05, 0.05 }, calipers = { 0.05, 0.05, 0.05 }, leather = { 0.1, 0.08, 0.05 }, platestyle = 2 },
}

local function applyLook(L)
  for _, g in ipairs(GROUPS) do build[g.id] = L[g.id] and { L[g.id][1], L[g.id][2], L[g.id][3] } or nil end
  build.finish = L.finish or 0
  build.glow = L.glow and { L.glow[1], L.glow[2], L.glow[3] } or nil
  build.rgbcycle = false
  build.platestyle = L.platestyle or 0
  syncEditorFromBuild()
  applyBuild(0, build)
  dirty = true
  dirtyTimer = 0.5
  say(L.name .. ' applied')
end

------------------------------------------------------------------ showroom camera

local showroom = { cam = nil, angle = 0, speed = 0.35, dist = 6.5, height = 1.3, fov = 38, auto = true }

local function showroomStart()
  if showroom.cam then return end
  local ok, cam = pcall(ac.grabCamera, 'No License Customs')
  if ok and cam then showroom.cam = cam; say('Showroom on. F8 for a screenshot. Stop gives the camera back.') else say('Camera is busy right now') end
end

local function showroomStop()
  if showroom.cam then pcall(function() showroom.cam:dispose() end); showroom.cam = nil; say('Camera back') end
end

local function showroomUpdate(dt)
  local cam = showroom.cam
  if not cam then return end
  local car = ac.getCar(0)
  if not car then return end
  if showroom.auto then showroom.angle = showroom.angle + dt * showroom.speed end
  local a = showroom.angle
  local centre = car.position + car.up * 0.6
  local pos = centre + (car.look * math.cos(a) + car.side * math.sin(a)) * showroom.dist + car.up * (showroom.height - 0.6)
  pcall(function()
    cam.transform = mat4x4.look(pos, centre - pos, vec3(0, 1, 0))
    cam.fov = showroom.fov
    cam.ownShare = 1
  end)
end

------------------------------------------------------------------ tuning

local tune = { spinners = nil, scanTimer = 0, pending = {}, simple = { balance = 0.5, stiff = 0.5, diff = 0.5, bias = 0.5, pressure = 0.5, height = 0.5 }, presetName = '', saveName = 'my tune', files = nil }
local simpleDirty, simpleTimer = false, 0

local KEYMAP = {
  pressure_f = { '^PRESSURE_[LR]F$' }, pressure_r = { '^PRESSURE_[LR]R$' },
  camber_f = { '^CAMBER_[LR]F$' }, camber_r = { '^CAMBER_[LR]R$' },
  toe_f = { '^TOE_OUT_[LR]F$' }, toe_r = { '^TOE_OUT_[LR]R$' },
  arb_f = { '^ARB_FRONT$' }, arb_r = { '^ARB_REAR$' },
  spring_f = { '^SPRING_RATE_[LR]F$' }, spring_r = { '^SPRING_RATE_[LR]R$' },
  damp_f = { '^DAMP_BUMP_[LR]F$', '^DAMP_REBOUND_[LR]F$', '^DAMP_FAST_BUMP_[LR]F$', '^DAMP_FAST_REBOUND_[LR]F$' },
  damp_r = { '^DAMP_BUMP_[LR]R$', '^DAMP_REBOUND_[LR]R$', '^DAMP_FAST_BUMP_[LR]R$', '^DAMP_FAST_REBOUND_[LR]R$' },
  height_f = { '^ROD_LENGTH_[LR]F$' }, height_r = { '^ROD_LENGTH_[LR]R$' },
  diff_power = { '^DIFF_POWER$' }, diff_coast = { '^DIFF_COAST$' }, diff_preload = { '^DIFF_PRELOAD$' },
  bias = { '^FRONT_BIAS$' }, brake_power = { '^BRAKE_POWER_MULT$' },
  wing = { '^WING_%d+$' },
}

local PRESETS = {
  { name = 'Drift', blurb = 'Diff locked, front toe-out, soft rear, lots of caster feel. Initiates easily and holds angle.',
    v = { camber_f = 0.30, camber_r = 0.85, toe_f = 0.15, toe_r = 0.50, arb_f = 0.80, arb_r = 0.15, spring_f = 0.70, spring_r = 0.30, damp_f = 0.55, damp_r = 0.35, height_f = 0.45, height_r = 0.55, diff_power = 1.0, diff_coast = 1.0, diff_preload = 1.0, bias = 0.85, brake_power = 0.9, pressure_f = 0.45, pressure_r = 0.80, wing = 0.0 },
    simple = { balance = 0.15, stiff = 0.5, diff = 1.0, bias = 0.85, pressure = 0.65, height = 0.5 } },
  { name = 'Street', blurb = 'Planted at speed, quick on direction changes, forgiving under braking. The traffic setup.',
    v = { camber_f = 0.40, camber_r = 0.55, toe_f = 0.50, toe_r = 0.65, arb_f = 0.55, arb_r = 0.45, spring_f = 0.55, spring_r = 0.50, damp_f = 0.55, damp_r = 0.50, height_f = 0.35, height_r = 0.40, diff_power = 0.50, diff_coast = 0.35, diff_preload = 0.40, bias = 0.64, brake_power = 0.9, pressure_f = 0.50, pressure_r = 0.50, wing = 0.35 },
    simple = { balance = 0.6, stiff = 0.55, diff = 0.45, bias = 0.64, pressure = 0.5, height = 0.38 } },
  { name = 'Grip', blurb = 'Track setup. Stiff, more negative camber, low, a bit of wing. Fastest through corners.',
    v = { camber_f = 0.20, camber_r = 0.40, toe_f = 0.42, toe_r = 0.62, arb_f = 0.65, arb_r = 0.50, spring_f = 0.75, spring_r = 0.70, damp_f = 0.65, damp_r = 0.62, height_f = 0.20, height_r = 0.25, diff_power = 0.45, diff_coast = 0.30, diff_preload = 0.35, bias = 0.62, brake_power = 1.0, pressure_f = 0.45, pressure_r = 0.45, wing = 0.7 },
    simple = { balance = 0.55, stiff = 0.72, diff = 0.4, bias = 0.62, pressure = 0.45, height = 0.22 } },
  { name = 'Cruise', blurb = 'Soft, comfortable, nothing bites. For long drives and traffic weaving at a chill pace.',
    v = { camber_f = 0.60, camber_r = 0.70, toe_f = 0.50, toe_r = 0.60, arb_f = 0.35, arb_r = 0.30, spring_f = 0.30, spring_r = 0.30, damp_f = 0.35, damp_r = 0.35, height_f = 0.55, height_r = 0.55, diff_power = 0.35, diff_coast = 0.30, diff_preload = 0.30, bias = 0.60, brake_power = 0.8, pressure_f = 0.50, pressure_r = 0.50, wing = 0.2 },
    simple = { balance = 0.6, stiff = 0.3, diff = 0.33, bias = 0.6, pressure = 0.5, height = 0.55 } },
  { name = 'Launch', blurb = 'Drag and rolls. Flat wheels for traction, soft rear for squat, diff locked on power.',
    v = { camber_f = 0.85, camber_r = 0.90, toe_f = 0.50, toe_r = 0.52, arb_f = 0.50, arb_r = 0.35, spring_f = 0.60, spring_r = 0.25, damp_f = 0.50, damp_r = 0.35, height_f = 0.50, height_r = 0.40, diff_power = 1.0, diff_coast = 0.5, diff_preload = 0.7, bias = 0.65, brake_power = 0.9, pressure_f = 0.60, pressure_r = 0.35, wing = 0.0 },
    simple = { balance = 0.55, stiff = 0.42, diff = 0.9, bias = 0.65, pressure = 0.48, height = 0.45 } },
  { name = 'Slammed', blurb = 'As low as the car allows, stiff so it does not bottom out. Looks the part, still drives.',
    v = { camber_f = 0.25, camber_r = 0.30, toe_f = 0.50, toe_r = 0.55, arb_f = 0.60, arb_r = 0.55, spring_f = 0.85, spring_r = 0.85, damp_f = 0.70, damp_r = 0.70, height_f = 0.0, height_r = 0.0, diff_power = 0.5, diff_coast = 0.4, diff_preload = 0.4, bias = 0.62, brake_power = 0.9, pressure_f = 0.5, pressure_r = 0.5, wing = 0.0 },
    simple = { balance = 0.55, stiff = 0.85, diff = 0.5, bias = 0.62, pressure = 0.5, height = 0.0 } },
  { name = 'Top speed', blurb = 'No wing, low drag camber, long legs. For the straights.',
    v = { camber_f = 0.55, camber_r = 0.60, toe_f = 0.50, toe_r = 0.55, arb_f = 0.50, arb_r = 0.45, spring_f = 0.55, spring_r = 0.55, damp_f = 0.5, damp_r = 0.5, height_f = 0.30, height_r = 0.30, diff_power = 0.4, diff_coast = 0.3, diff_preload = 0.3, bias = 0.62, brake_power = 0.9, pressure_f = 0.6, pressure_r = 0.6, wing = 0.0 },
    simple = { balance = 0.55, stiff = 0.55, diff = 0.38, bias = 0.62, pressure = 0.6, height = 0.3 } },
}

local function scanSpinners()
  local ok, s = pcall(ac.getSetupSpinners)
  if ok and type(s) == 'table' then tune.spinners = s else tune.spinners = tune.spinners or {} end
end

local function fractionToValue(s, f)
  if f < 0 then f = 0 elseif f > 1 then f = 1 end
  local step = (s.step and s.step > 0) and s.step or 1
  local v = s.min + (s.max - s.min) * f
  v = s.min + math.floor((v - s.min) / step + 0.5) * step
  if v < s.min then v = s.min elseif v > s.max then v = s.max end
  return math.floor(v + 0.5)
end

local function canEdit()
  local ok, v = pcall(ac.isSetupAvailableToEdit)
  return ok and v == true
end

local function flushPending()
  if next(tune.pending) == nil or not canEdit() then return end
  local n, failed = 0, 0
  for name, value in pairs(tune.pending) do
    local ok, res = pcall(ac.setSetupSpinnerValue, name, value)
    if ok and res then n = n + 1 else failed = failed + 1 end
  end
  tune.pending = {}
  scanSpinners()
  say(string.format('Tune applied: %d setting(s)%s', n, failed > 0 and (', ' .. failed .. ' locked on this car') or ''))
end

local function applyFractions(frac)
  if not tune.spinners or #tune.spinners == 0 then scanSpinners() end
  local count = 0
  for key, f in pairs(frac) do
    local pats = KEYMAP[key]
    if pats then
      for _, s in ipairs(tune.spinners or {}) do
        if not s.readOnly then
          local up = s.name:upper()
          for _, p in ipairs(pats) do
            if up:match(p) then tune.pending[s.name] = fractionToValue(s, f); count = count + 1; break end
          end
        end
      end
    end
  end
  if count == 0 then say('No setup items found yet. Open the setup screen in the pits once, then try again.') return end
  if canEdit() then flushPending() else say('Queued ' .. count .. ' setting(s). They apply the moment you are in the pits.') end
end

local function simpleToFractions(sm)
  local b, st, d = sm.balance, sm.stiff, sm.diff
  return {
    arb_f = 0.25 + 0.6 * b, arb_r = 0.85 - 0.6 * b, toe_r = 0.5 + 0.25 * b, toe_f = 0.5 - 0.1 * (b - 0.5),
    spring_f = st + 0.12 * (b - 0.5), spring_r = st - 0.12 * (b - 0.5), damp_f = st, damp_r = st,
    diff_power = d, diff_coast = 0.85 * d, diff_preload = 0.7 * d, bias = sm.bias,
    pressure_f = sm.pressure, pressure_r = sm.pressure, height_f = sm.height, height_r = sm.height,
  }
end

local function applyPreset(p)
  tune.presetName = p.name
  for k, v in pairs(p.simple) do tune.simple[k] = v end
  applyFractions(p.v)
end

local setupsDir = nil
pcall(function() setupsDir = ac.getFolder(ac.FolderID.UserSetups) .. '/' .. myCarID .. '/generic' end)

local function refreshFiles()
  tune.files = {}
  if not setupsDir then return end
  pcall(function()
    local list = io.scanDir(setupsDir, '*.ini')
    if type(list) == 'table' then for _, fn in ipairs(list) do tune.files[#tune.files + 1] = fn end end
  end)
  table.sort(tune.files)
end

local function safeName(s)
  s = (s or ''):gsub('[^%w%-_ ]', ''):gsub('^%s+', ''):gsub('%s+$', '')
  if s == '' then s = 'tune' end
  return s
end

local function saveTuneFile()
  local ok, res = pcall(ac.saveCurrentSetup, 'generic/NL ' .. safeName(tune.saveName) .. '.ini')
  if ok and res then say('Saved "NL ' .. safeName(tune.saveName) .. '". It is in your normal setups list too.'); refreshFiles() else say('Could not save (try from the pits)') end
end

local function loadTuneFile(fn)
  if not canEdit() then say('Go to the pits (setup screen) to load a tune') return end
  local ok, res = pcall(ac.loadSetup, 'generic/' .. fn)
  if ok and res then say('Loaded ' .. fn); scanSpinners() else say('Could not load ' .. fn) end
end

local function exportTune()
  local ok, txt = pcall(ac.stringifyCurrentSetup, true, false)
  if ok and type(txt) == 'string' and #txt > 0 then pcall(function() ac.setClipboardText('NLT1\n' .. txt) end); say('Tune copied. Paste it to a friend.') else say('Nothing to export yet') end
end

local function importTune()
  if not canEdit() then say('Go to the pits (setup screen) to import a tune') return end
  local ok, txt = pcall(ui.getClipboardText)
  if not ok or type(txt) ~= 'string' or #txt < 10 then say('Clipboard is empty') return end
  if txt:sub(1, 4) == 'NLT1' then txt = txt:sub(6) end
  if not txt:find('%[') then say('Clipboard does not look like a tune') return end
  local ok2, res = pcall(ac.loadSetup, txt)
  if ok2 and res then say('Tune imported'); scanSpinners() else say('Could not import that tune (wrong car?)') end
end

------------------------------------------------------------------ frame

local started, startTimer = false, 2.0
local connected = {}

local function startup()
  started = true
  dlog('v' .. VERSION .. ' started, car ' .. myCarID .. (CARS[myCarID] and ' (known)' or ' (name patterns)'))
  carRoot(0)
  for _, g in ipairs(GROUPS) do groupMeshes(0, g.id) end
  local all = loadSaved()
  if all[myCarID] then
    build = all[myCarID]
    if build.matte and not build.finish then build.finish = 1 end
    syncEditorFromBuild()
    applyBuild(0, build)
  end
  dirty = true
  dirtyTimer = 2
  scanSpinners()
  refreshFiles()
  menu.hintT = HINT_SECONDS
end

function script.update(dt)
  t = t + dt
  if not started then
    startTimer = startTimer - dt
    if startTimer <= 0 then pcall(startup) end
    return
  end
  if statusTimer > 0 then statusTimer = statusTimer - dt end
  if dirty then
    dirtyTimer = dirtyTimer - dt
    if dirtyTimer <= 0 then dirty = false; broadcast() end
  end
  if simpleDirty then
    simpleTimer = simpleTimer - dt
    if simpleTimer <= 0 then simpleDirty = false; applyFractions(simpleToFractions(tune.simple)) end
  end
  local sim = ac.getSim()
  for i = 1, sim.carsCount - 1 do
    local car = ac.getCar(i)
    local isOn = car and car.isConnected
    if isOn and not connected[i] then
      connected[i] = true
      for k in pairs(matCache) do if k:sub(1, #tostring(i) + 1) == i .. ':' then matCache[k] = nil end end
      rootCache[i] = nil
      plateApplied[i] = nil
      if remoteBuilds[i] and store.showOthers then applyBuild(i, remoteBuilds[i]) end
    elseif not isOn and connected[i] then
      connected[i] = false
      setGlow(i, nil)
      remoteBuilds[i] = nil
      plateApplied[i] = nil
    end
  end
  pcall(updateGlow, dt)
  pcall(showroomUpdate, dt)
  tune.scanTimer = tune.scanTimer + dt
  if tune.scanTimer > 2 then
    tune.scanTimer = 0
    if next(tune.pending) ~= nil then flushPending() end
  end
end

------------------------------------------------------------------ UI

local GREEN = rgbm(0, 0.94, 0.35, 1)
local GOLD = rgbm(1, 0.8, 0.2, 1)
local RED = rgbm(1, 0.25, 0.22, 1)
local DIM = rgbm(0.55, 0.57, 0.62, 1)
local WARN = rgbm(1, 0.75, 0.3, 1)
local F_BOLD = 'Bahnschrift;Weight=Bold'
local F_MED = 'Bahnschrift;Weight=SemiBold'
local menuUI = { tab = 1, tabX = 0, tabW = 0 }
local anim = {}

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
function withA(c, a) return rgbm(c.r, c.g, c.b, (c.mult or 1) * a) end
function lerpC(a, b, f) return rgbm(a.r + (b.r - a.r) * f, a.g + (b.g - a.g) * f, a.b + (b.b - a.b) * f, a.mult + (b.mult - a.mult) * f) end
function ease(id, target, speed)
  local dt = 0.016
  pcall(function() dt = math.min(0.1, ac.getSim().dt or 0.016) end)
  local v = anim[id]
  if v == nil then v = target end
  v = v + (target - v) * math.min(1, dt * (speed or 14))
  anim[id] = v
  return v
end

function nlButton(label, w, accent, h)
  h = h or 28
  local p = ui.getCursor()
  ui.invisibleButton('##b' .. label, vec2(w, h))
  local hov = ui.itemHovered()
  local clicked = ui.itemClicked(ui.MouseButton.Left)
  local f = ease('b' .. label, hov and 1 or 0)
  if accent then
    ui.drawRectFilled(p, p + vec2(w, h), withA(accent, 0.8 + 0.2 * f), 5)
    ui.drawRectFilled(vec2(p.x, p.y + h - 2), vec2(p.x + w, p.y + h), rgbm(0, 0, 0, 0.25), 1)
  else
    ui.drawRectFilled(p, p + vec2(w, h), rgbm(1, 1, 1, 0.07 + 0.1 * f), 5)
    ui.drawRect(p, p + vec2(w, h), rgbm(1, 1, 1, 0.08 + 0.3 * f), 5, ui.CornerFlags.All, 1)
  end
  local tw = textW(label, 11, F_BOLD)
  text(label, 11, vec2(p.x + (w - tw.x) / 2, p.y + (h - 13) / 2), accent and rgbm(0.04, 0.04, 0.05, 1) or rgbm(1, 1, 1, 0.85 + 0.15 * f), F_BOLD)
  return clicked
end

function nlToggle(label, on, w)
  local p = ui.getCursor()
  w = w or 200
  ui.invisibleButton('##t' .. label, vec2(w, 28))
  local hov = ui.itemHovered()
  local clicked = ui.itemClicked(ui.MouseButton.Left)
  local f = ease('tg' .. label, on and 1 or 0)
  local hf = ease('tgh' .. label, hov and 1 or 0)
  ui.drawRectFilled(p, p + vec2(w, 28), rgbm(1, 1, 1, 0.05 + 0.05 * hf), 5)
  ui.drawRectFilled(vec2(p.x + 8, p.y + 8), vec2(p.x + 34, p.y + 20), lerpC(rgbm(1, 1, 1, 0.15), GREEN, f), 6)
  ui.drawCircleFilled(vec2(p.x + 14 + 14 * f, p.y + 14), 5, lerpC(rgbm(0.8, 0.8, 0.85, 1), rgbm(0.04, 0.04, 0.05, 1), f), 12)
  text(label, 11, vec2(p.x + 44, p.y + 7), rgbm(1, 1, 1, 0.9), F_BOLD)
  return clicked
end

function section(label, col)
  local p = ui.getCursor()
  ui.dummy(vec2(10, 18))
  ui.drawRectFilled(vec2(p.x, p.y + 4), vec2(p.x + 3, p.y + 14), col or GREEN, 1)
  text(label:upper(), 9, vec2(p.x + 9, p.y + 3), rgbm(0.75, 0.77, 0.82, 1), F_BOLD)
end

function nlTabs(id, labels, state, w)
  local p = ui.getCursor()
  local h = 30
  ui.dummy(vec2(w, h + 6))
  ui.drawRectFilled(vec2(p.x, p.y + h), vec2(p.x + w, p.y + h + 1), rgbm(1, 1, 1, 0.08))
  local x = p.x
  local selX, selW = p.x, 40
  for i, label in ipairs(labels) do
    local tw = textW(label, 11, F_BOLD).x
    local bw = tw + 24
    ui.setCursor(vec2(x, p.y))
    ui.invisibleButton('##tab' .. id .. i, vec2(bw, h))
    local hov = ui.itemHovered()
    if ui.itemClicked(ui.MouseButton.Left) then state.tab = i end
    local sel = state.tab == i
    local f = ease('tab' .. id .. i, (sel and 1 or (hov and 0.5 or 0)))
    text(label, 11, vec2(x + 12, p.y + 9), lerpC(rgbm(0.6, 0.62, 0.68, 1), rgbm(1, 1, 1, 1), f), F_BOLD)
    if sel then selX, selW = x + 8, bw - 16 end
    x = x + bw
  end
  state.tabX = ease('tabx' .. id, selX, 18)
  state.tabW = ease('tabw' .. id, selW, 18)
  ui.drawRectFilled(vec2(state.tabX, p.y + h - 2), vec2(state.tabX + state.tabW, p.y + h + 1), GREEN, 1)
  ui.setCursor(vec2(p.x, p.y + h + 8))
end

local SWATCHES = {
  { 'Nardo', 0.52, 0.53, 0.55 }, { 'Frozen black', 0.05, 0.05, 0.06 }, { 'Alpine white', 0.95, 0.95, 0.93 }, { 'NL green', 0.0, 0.94, 0.35 },
  { 'Candy red', 0.72, 0.02, 0.05 }, { 'Midnight', 0.2, 0.05, 0.4 }, { 'Miami blue', 0.0, 0.62, 0.8 }, { 'Gold', 0.85, 0.65, 0.15 },
  { 'Baby pink', 0.98, 0.65, 0.78 }, { 'Orange', 0.95, 0.4, 0.05 }, { 'Lime', 0.6, 0.95, 0.1 }, { 'Ice blue', 0.6, 0.85, 1.0 },
  { 'Blood', 0.35, 0.0, 0.02 }, { 'Forest', 0.05, 0.3, 0.12 }, { 'Navy', 0.03, 0.08, 0.3 }, { 'Sand', 0.76, 0.68, 0.5 },
}

-- colour squares that grow on hover. click = paint
function swatchRow(id)
  local p = ui.getCursor()
  local sz, gap = 28, 6
  local n = #SWATCHES
  ui.invisibleButton('##sw' .. id, vec2(n * (sz + gap), sz + 6))
  local hov = ui.itemHovered()
  local clicked = ui.itemClicked(ui.MouseButton.Left)
  local mx = nil
  if hov or clicked then pcall(function() mx = ui.mouseLocalPos() end) end
  local hit = nil
  for i, sw in ipairs(SWATCHES) do
    local x = p.x + (i - 1) * (sz + gap)
    local over = mx and mx.x >= x and mx.x <= x + sz and mx.y >= p.y and mx.y <= p.y + sz + 6
    if over then hit = sw end
    local f = ease('sw' .. id .. i, over and 1 or 0, 18)
    local g = 3 * f
    local isSel = enabled[id] and math.abs(pick[id].r - sw[2]) < 0.01 and math.abs(pick[id].g - sw[3]) < 0.01 and math.abs(pick[id].b - sw[4]) < 0.01
    ui.drawRectFilled(vec2(x - g, p.y + 3 - g), vec2(x + sz + g, p.y + 3 + sz + g), rgbm(sw[2], sw[3], sw[4], 1), 5)
    if isSel then ui.drawRect(vec2(x - g - 1, p.y + 2 - g), vec2(x + sz + g + 1, p.y + 4 + sz + g), rgbm(1, 1, 1, 1), 5, ui.CornerFlags.All, 2) end
  end
  if hit and hov then ui.setTooltip(hit[1]) end
  if clicked and hit then
    pick[id] = rgbm(hit[2], hit[3], hit[4], 1)
    enabled[id] = true
    pushEditor()
  end
end

-- one paint group as a card: toggle + current colour chip + swatches + picker
function colourBlock(id, label, w)
  w = w or 580
  ui.pushID(id)
  local p = ui.getCursor()
  local open = enabled[id]
  local h = open and 262 or 44
  ui.dummy(vec2(w, h))
  ui.drawRectFilled(p, p + vec2(w, h), rgbm(1, 1, 1, 0.045), 7)
  if open then ui.drawRectFilled(p, vec2(p.x + 3, p.y + h), withA(pick[id], 1), 2) end
  ui.setCursor(vec2(p.x + 10, p.y + 8))
  if nlToggle(label, enabled[id], 200) then enabled[id] = not enabled[id]; pushEditor() end
  local chip = enabled[id] and pick[id] or rgbm(1, 1, 1, 0.1)
  ui.drawCircleFilled(vec2(p.x + w - 24, p.y + 22), 11, chip, 24)
  ui.drawCircle(vec2(p.x + w - 24, p.y + 22), 11, rgbm(1, 1, 1, 0.2), 24, 1)
  if not enabled[id] then text('off - stock colour', 9, vec2(p.x + 230, p.y + 15), DIM) end
  if open then
    ui.setCursor(vec2(p.x + 10, p.y + 44))
    swatchRow(id)
    ui.setCursor(vec2(p.x + 10, p.y + 84))
    ui.setNextItemWidth(200)
    if ui.colorPicker('##pk' .. id, pick[id], bit.bor(ui.ColorPickerFlags.NoAlpha, ui.ColorPickerFlags.PickerHueBar, ui.ColorPickerFlags.NoSidePreview)) then pushEditor() end
  end
  ui.setCursor(vec2(p.x, p.y + h + 8))
  ui.popID()
end

function finishButtons(w)
  local p = ui.getCursor()
  ui.dummy(vec2(w, 54))
  ui.drawRectFilled(p, p + vec2(w, 54), rgbm(1, 1, 1, 0.045), 7)
  text('FINISH', 9, vec2(p.x + 12, p.y + 8), rgbm(0.75, 0.77, 0.82, 1), F_BOLD)
  local x = p.x + 80
  for i, f in ipairs(FINISHES) do
    ui.setCursor(vec2(x, p.y + 13))
    local sel = (build.finish or 0) == i - 1
    if nlButton(f, 100, sel and GREEN or nil) then build.finish = i - 1; pushEditor() end
    -- little sphere preview
    local cx, cy = x + 100 - 14, p.y + 27
    local base = enabled.body and pick.body or rgbm(0.5, 0.5, 0.55, 1)
    ui.drawCircleFilled(vec2(cx, cy), 7, sel and rgbm(0.04, 0.04, 0.05, 1) or base, 16)
    if i ~= 2 then ui.drawCircleFilled(vec2(cx - 2, cy - 2), i == 4 and 3.5 or 2, rgbm(1, 1, 1, i == 4 and 1 or (i == 3 and 0.5 or 0.8)), 10) end
    x = x + 112
  end
  ui.setCursor(vec2(p.x, p.y + 62))
end

function tabPaint()
  ui.childWindow('##paint', vec2(600, 400), false, 0, function()
    colourBlock('body', 'Body paint')
    if enabled.body then finishButtons(580) end
    colourBlock('rims', 'Wheels')
    colourBlock('calipers', 'Calipers')
  end)
end

function tabInterior()
  ui.childWindow('##int', vec2(600, 400), false, 0, function()
    colourBlock('leather', 'Leather / alcantara')
    colourBlock('accent', 'Trim accents')
    text('Not every car has recolourable accents. Save tab shows what was found on this car.', 9, ui.getCursor() + vec2(4, 0), DIM)
    ui.dummy(vec2(1, 14))
  end)
end

function tabPlate()
  section('registration (up to 10 characters)')
  ui.setNextItemWidth(300)
  local v, changed = ui.inputText('##plate', plateText, ui.InputTextFlags.CharsUppercase)
  if changed then plateText = v:sub(1, 10); pushEditor() end
  ui.sameLine(0, 8)
  if nlButton('Stock plate', 110) then plateText = ''; build.platestyle = 0; pushEditor() end
  section('style')
  for i, st in ipairs(PLATE_STYLES) do
    if nlButton(st, 120, (build.platestyle or 0) == i - 1 and GREEN or nil) then build.platestyle = i - 1; pushEditor() end
    if i < #PLATE_STYLES then ui.sameLine(0, 6) end
  end
  section('preview')
  local p = ui.getCursor()
  ui.dummy(vec2(400, 100))
  pcall(function() drawUKPlate(p.x, p.y, 400, 100, plateText, YELLOW, build.platestyle or 0) end)
  ui.drawRect(p, p + vec2(400, 100), rgbm(1, 1, 1, 0.15), 3, ui.CornerFlags.All, 1)
  text('Shows on the front and rear plate. Everyone on the server sees it.', 9, ui.getCursor() + vec2(4, 2), DIM)
  ui.dummy(vec2(1, 14))
end

function tabGlow()
  ui.childWindow('##glow', vec2(600, 400), false, 0, function()
    local p = ui.getCursor()
    local open = enabled.glow
    local h = open and 320 or 44
    ui.dummy(vec2(580, h))
    ui.drawRectFilled(p, p + vec2(580, h), rgbm(1, 1, 1, 0.045), 7)
    ui.setCursor(vec2(p.x + 10, p.y + 8))
    if nlToggle('Underglow', enabled.glow, 200) then enabled.glow = not enabled.glow; pushEditor() end
    if open then
      -- preview strip: the colour (or the rainbow) glowing under a dark bar
      local gc = pick.glow
      if build.rgbcycle then local r, g, b = hsv(hueT % 1); gc = rgbm(r, g, b, 1) end
      pcall(function() ui.drawRectFilledMultiColor(vec2(p.x + 20, p.y + 44), vec2(p.x + 560, p.y + 64), withA(gc, 0.0), withA(gc, 0.0), withA(gc, 0.9 * (build.glowpower or 0.6)), withA(gc, 0.9 * (build.glowpower or 0.6))) end)
      ui.drawRectFilled(vec2(p.x + 60, p.y + 38), vec2(p.x + 520, p.y + 50), rgbm(0.08, 0.08, 0.1, 1), 4)
      ui.setCursor(vec2(p.x + 10, p.y + 76))
      swatchRow('glow')
      ui.setCursor(vec2(p.x + 10, p.y + 116))
      ui.setNextItemWidth(200)
      if ui.colorPicker('##pkglow', pick.glow, bit.bor(ui.ColorPickerFlags.NoAlpha, ui.ColorPickerFlags.PickerHueBar, ui.ColorPickerFlags.NoSidePreview)) then pushEditor() end
      ui.setCursor(vec2(p.x + 240, p.y + 120))
      ui.setNextItemWidth(300)
      local v, ch = ui.slider('##gp', build.glowpower or 0.6, 0.1, 1.0, 'Brightness: %.2f')
      if ch then build.glowpower = v; pushEditor() end
      ui.setCursor(vec2(p.x + 240, p.y + 156))
      if nlToggle('RGB cycle', build.rgbcycle == true, 150) then build.rgbcycle = not build.rgbcycle; pushEditor() end
      ui.setCursor(vec2(p.x + 240, p.y + 190))
      if nlToggle('Flash red on brake', build.brakeflash == true, 190) then build.brakeflash = not build.brakeflash; pushEditor() end
    end
    ui.setCursor(vec2(p.x, p.y + h + 8))
  end)
end

function tabLooks()
  section('one click builds. tweak after in paint.')
  ui.childWindow('##looks', vec2(600, 360), false, 0, function()
    for i, L in ipairs(LOOKS) do
      local p = ui.getCursor()
      ui.invisibleButton('##look' .. i, vec2(138, 64))
      local hov = ui.itemHovered()
      if ui.itemClicked(ui.MouseButton.Left) then applyLook(L) end
      local f = ease('look' .. i, hov and 1 or 0)
      ui.drawRectFilled(p, p + vec2(138, 64), rgbm(1, 1, 1, 0.05 + 0.08 * f), 7)
      ui.drawRect(p, p + vec2(138, 64), rgbm(1, 1, 1, 0.06 + 0.4 * f), 7, ui.CornerFlags.All, 1)
      ui.drawRectFilled(vec2(p.x + 8, p.y + 8), vec2(p.x + 52, p.y + 56), rgbm(L.body[1], L.body[2], L.body[3], 1), 5)
      if L.finish == 3 then ui.drawCircleFilled(vec2(p.x + 20, p.y + 20), 5, rgbm(1, 1, 1, 0.9), 10) elseif L.finish == 0 then ui.drawCircleFilled(vec2(p.x + 20, p.y + 20), 3, rgbm(1, 1, 1, 0.6), 10) end
      local cx = p.x + 60
      for _, key in ipairs({ 'rims', 'calipers', 'glow' }) do
        local c = L[key]
        ui.drawCircleFilled(vec2(cx + 6, p.y + 48), 6, c and rgbm(c[1], c[2], c[3], 1) or rgbm(1, 1, 1, 0.08), 12)
        cx = cx + 16
      end
      text(L.name, 12, vec2(p.x + 60, p.y + 10), rgbm(1, 1, 1, 1), F_BOLD)
      text(FINISHES[(L.finish or 0) + 1], 8, vec2(p.x + 60, p.y + 27), DIM)
      if i % 4 ~= 0 and i < #LOOKS then ui.sameLine(0, 8) else ui.dummy(vec2(1, 6)) end
    end
  end)
end

function simpleSlider(key, label, left, right)
  ui.setNextItemWidth(560)
  local v, changed = ui.slider('##' .. key, tune.simple[key], 0, 1, label .. ': %.2f')
  if changed then tune.simple[key] = v; tune.presetName = '' end
  local p = ui.getCursor()
  text(left, 8, vec2(p.x + 2, p.y - 2), DIM)
  local rw = textW(right, 8).x
  text(right, 8, vec2(p.x + 560 - rw - 2, p.y - 2), DIM)
  ui.dummy(vec2(1, 10))
  return changed
end

function tabTune()
  ui.childWindow('##tune', vec2(600, 400), false, 0, function()
    if canEdit() then text('IN THE PITS - changes apply straight away', 9, ui.getCursor(), GREEN, F_BOLD)
    else text('Changes queue up and apply when you are in the pits with the setup screen open', 9, ui.getCursor(), WARN, F_BOLD) end
    ui.dummy(vec2(1, 14))
    section('presets')
    for i, pr in ipairs(PRESETS) do
      local p = ui.getCursor()
      ui.invisibleButton('##pre' .. i, vec2(138, 56))
      local hov = ui.itemHovered()
      if ui.itemClicked(ui.MouseButton.Left) then applyPreset(pr) end
      local sel = tune.presetName == pr.name
      local f = ease('pre' .. i, hov and 1 or 0)
      ui.drawRectFilled(p, p + vec2(138, 56), sel and withA(GREEN, 0.18) or rgbm(1, 1, 1, 0.05 + 0.08 * f), 7)
      ui.drawRect(p, p + vec2(138, 56), sel and GREEN or rgbm(1, 1, 1, 0.06 + 0.4 * f), 7, ui.CornerFlags.All, 1)
      text(pr.name, 12, vec2(p.x + 10, p.y + 8), sel and GREEN or rgbm(1, 1, 1, 1), F_BOLD)
      -- mini bars: stiff / diff / height
      local sm = pr.simple
      local bx = p.x + 10
      for _, k in ipairs({ 'stiff', 'diff', 'height' }) do
        ui.drawRectFilled(vec2(bx, p.y + 40), vec2(bx + 36, p.y + 44), rgbm(1, 1, 1, 0.1), 2)
        ui.drawRectFilled(vec2(bx, p.y + 40), vec2(bx + 36 * sm[k], p.y + 44), sel and GREEN or rgbm(1, 1, 1, 0.5), 2)
        bx = bx + 42
      end
      text('stiff   diff   height', 6, vec2(p.x + 10, p.y + 28), DIM)
      if hov then ui.setTooltip(pr.blurb) end
      if i % 4 ~= 0 and i < #PRESETS then ui.sameLine(0, 8) else ui.dummy(vec2(1, 4)) end
    end
    section('feel')
    local ch = false
    ch = simpleSlider('balance', 'Balance', 'Oversteer / loose', 'Understeer / planted') or ch
    ch = simpleSlider('stiff', 'Stiffness', 'Soft, comfy', 'Stiff, sharp') or ch
    ch = simpleSlider('diff', 'Diff lock', 'Open', 'Locked (drift / launch)') or ch
    ch = simpleSlider('bias', 'Brake bias', 'Rear brakes', 'Front brakes') or ch
    ch = simpleSlider('pressure', 'Tyre pressure', 'Low, more grip', 'High, more slide') or ch
    ch = simpleSlider('height', 'Ride height', 'Slammed', 'Raised') or ch
    if ch then simpleDirty = true; simpleTimer = 0.6 end
    section('save and share')
    ui.setNextItemWidth(220)
    tune.saveName = ui.inputText('##tunename', tune.saveName)
    ui.sameLine(0, 6)
    if nlButton('Save tune', 100, GREEN) then saveTuneFile() end
    ui.sameLine(0, 6)
    if nlButton('Copy tune', 100) then exportTune() end
    ui.sameLine(0, 6)
    if nlButton('Import tune', 100) then importTune() end
    text('Copied tunes are text. Paste them in Discord, friends import them with one click.', 9, ui.getCursor() + vec2(2, 0), DIM)
    ui.dummy(vec2(1, 14))
    ui.treeNode('Saved tunes', function()
      if tune.files == nil or #tune.files == 0 then ui.textColored('No saved tunes for this car yet.', DIM)
      else for _, fn in ipairs(tune.files) do if nlButton(fn:gsub('%.ini$', ''), 540) then loadTuneFile(fn) end end end
      if nlButton('Refresh list', 120) then refreshFiles() end
    end)
    ui.treeNode('Advanced (every setting)', function()
      if tune.spinners == nil or #tune.spinners == 0 then
        ui.textColored('Nothing here until the setup screen has been opened once.', DIM)
        if nlButton('Scan now', 100) then scanSpinners() end
      else
        for _, sp in ipairs(tune.spinners) do
          if sp.visible ~= false then
            local label = (sp.label or sp.name) .. (sp.units and (' (' .. sp.units .. ')') or '')
            local pend = tune.pending[sp.name]
            ui.setNextItemWidth(480)
            local v, changed = ui.slider('##' .. sp.name, pend or sp.value, sp.min, sp.max, label .. ': %.0f', true)
            if changed then
              local step = (sp.step and sp.step > 0) and sp.step or 1
              tune.pending[sp.name] = math.floor(sp.min + math.floor((v - sp.min) / step + 0.5) * step + 0.5)
              tune.presetName = ''
              simpleDirty = true; simpleTimer = 0.3
            end
            if sp.readOnly then ui.sameLine(); ui.textColored('locked', DIM) end
          end
        end
      end
    end)
  end)
end

function tabShowroom()
  section('orbit camera for screenshots and clips')
  if showroom.cam then
    if nlButton('Stop', 110, GREEN) then showroomStop() end
    ui.sameLine(0, 6)
    if nlToggle('Auto orbit', showroom.auto, 130) then showroom.auto = not showroom.auto end
    ui.setNextItemWidth(400)
    showroom.angle = ui.slider('##ang', showroom.angle, 0, math.pi * 2, 'Angle: %.2f')
    ui.setNextItemWidth(400)
    showroom.speed = ui.slider('##spd', showroom.speed, 0.05, 1.5, 'Speed: %.2f')
    ui.setNextItemWidth(400)
    showroom.dist = ui.slider('##dst', showroom.dist, 3, 14, 'Distance: %.1f m')
    ui.setNextItemWidth(400)
    showroom.height = ui.slider('##hgt', showroom.height, 0.3, 4, 'Height: %.1f m')
    ui.setNextItemWidth(400)
    showroom.fov = ui.slider('##fov', showroom.fov, 20, 70, 'FOV: %.0f')
    text('F8 takes a screenshot. Close this menu to watch it orbit.', 9, ui.getCursor() + vec2(2, 0), DIM)
    ui.dummy(vec2(1, 14))
  else
    if nlButton('Start showroom', 150, GREEN) then showroomStart() end
  end
end

function tabSave()
  ui.childWindow('##save', vec2(600, 400), false, 0, function()
    section('this build')
    if nlButton('Save this build', 150, GREEN) then saveBuild() end
    ui.sameLine(0, 6)
    if nlButton('Reset to stock', 130) then resetAll() end
    ui.sameLine(0, 6)
    if nlButton('Copy build code', 140) then exportCode() end
    ui.sameLine(0, 6)
    if nlButton('Import build code', 140) then importCode() end
    text('Saved builds come back every time you drive this car. Build codes are text: paste them in Discord, friends import your exact look.', 9, ui.getCursor() + vec2(2, 0), DIM)
    ui.dummy(vec2(1, 14))
    section('sharing')
    if nlToggle('Show my build to others', store.shareBuild, 260) then store.shareBuild = not store.shareBuild; dirty = true; dirtyTimer = 0.2 end
    if nlToggle('Show other players\' builds', store.showOthers, 260) then
      store.showOthers = not store.showOthers
      for i, b in pairs(remoteBuilds) do if store.showOthers then applyBuild(i, b) else resetCar(i) end end
    end
    section('menu key')
    if menuButton then
      local okc = pcall(function() menuButton:control(vec2(160, 24)) end)
      if not okc then ui.text('current key: ' .. MENU_KEY) end
    else
      ui.text('current key: ' .. MENU_KEY)
    end
    section('found on this car')
    for _, g in ipairs(GROUPS) do if scanReport[g.id] then text(scanReport[g.id], 9, ui.getCursor() + vec2(2, 0), DIM); ui.dummy(vec2(1, 13)) end end
    if nlButton('Re-scan car', 110) then
      matCache = {}; rootCache = {}; stock = {}; plateApplied = {}; painted = {}
      for _, g in ipairs(GROUPS) do groupMeshes(0, g.id) end
      applyBuild(0, build)
      say('Re-scanned')
    end
  end)
end

function drawMenu()
    local W = 600
    local p = ui.getCursor()
    ui.dummy(vec2(W, 64))
    local bc = enabled.body and pick.body or GREEN
    pcall(function() ui.drawRectFilledMultiColor(p, p + vec2(W, 64), withA(bc, 0.22), rgbm(0, 0, 0, 0), rgbm(0, 0, 0, 0), withA(bc, 0.05)) end)
    ui.drawRectFilled(vec2(p.x, p.y + 63), vec2(p.x + W, p.y + 64), withA(bc, 0.6))
    text('NO LICENSE', 20, vec2(p.x + 14, p.y + 12), GREEN, F_BOLD)
    text('CUSTOMS', 20, vec2(p.x + 14 + textW('NO LICENSE ', 20, F_BOLD).x, p.y + 12), rgbm(1, 1, 1, 1), F_BOLD)
    text(myCarID, 9, vec2(p.x + 16, p.y + 40), DIM, F_BOLD)
    if statusTimer > 0 then
      local sw = textW(status, 9, F_BOLD).x
      ui.drawRectFilled(vec2(p.x + W - sw - 26, p.y + 20), vec2(p.x + W - 10, p.y + 38), withA(GREEN, 0.9), 4)
      text(status, 9, vec2(p.x + W - sw - 18, p.y + 24), rgbm(0.04, 0.04, 0.05, 1), F_BOLD)
    end
    ui.setCursor(vec2(p.x, p.y + 70))
    nlTabs('c', { 'Paint', 'Interior', 'Plate', 'Glow', 'Looks', 'Tune', 'Showroom', 'Save' }, menuUI, W)
    local tabs = { tabPaint, tabInterior, tabPlate, tabGlow, tabLooks, tabTune, tabShowroom, tabSave }
    if MENUTAB then menuUI.tab = MENUTAB end
    tabs[menuUI.tab]()
end

pcall(function()
  local icn = ui.Icons and (ui.Icons.Car or ui.Icons.Settings) or nil
  ui.registerOnlineExtra(icn, 'No License Customs', nil, drawMenu)
end)

pcall(function()
  menuButton = ac.ControlButton('NL_CUSTOMS_MENU', { keyboard = { key = ui.KeyIndex[MENU_KEY] or ui.KeyIndex.End } })
end)

local function menuKeyPressed()
  if menuButton then
    local ok, v = pcall(function() return menuButton:pressed() end)
    if ok then return v == true end
  end
  local ok, v = pcall(function() return ui.keyboardButtonPressed(ui.KeyIndex[MENU_KEY] or ui.KeyIndex.End) end)
  return ok and v == true
end

local function openMenu()
  if menu.open then return end
  menu.open = true
  menu.close = false
  local ok = pcall(function()
    ui.modalDialog('No License Customs', function()
      drawMenu()
      ui.dummy(vec2(1, 6))
      if nlButton('Close   ' .. MENU_KEY:upper(), 120) or menu.close then menu.open = false; menu.close = false; return true end
      return false
    end, false, function() menu.open = false end)
  end)
  if not ok then menu.open = false end
end

function script.drawUI(dt)
  if not started then return end
  if menuKeyPressed() then
    if menu.open then menu.close = true else openMenu() end
  end
  if menu.hintT > 0 then
    menu.hintT = menu.hintT - dt
    local a = math.min(1, menu.hintT / 2)
    local sim = ac.getSim()
    local sh = sim.windowHeight
    local x, y = 24, sh * 0.42 + 66
    local w, h = 250, 58
    ui.drawRectFilled(vec2(x, y), vec2(x + w, y + h), rgbm(0.04, 0.045, 0.055, 0.82 * a), 6)
    ui.drawRectFilled(vec2(x, y), vec2(x + 3, y + h), withA(GREEN, a), 2)
    text('NO LICENSE CUSTOMS', 10, vec2(x + 12, y + 8), withA(GREEN, a), F_BOLD)
    local key = MENU_KEY:upper()
    local kw = textW(key, 11, F_BOLD).x
    ui.drawRectFilled(vec2(x + 12, y + 26), vec2(x + 12 + kw + 12, y + 46), rgbm(1, 1, 1, 0.9 * a), 3)
    text(key, 11, vec2(x + 18, y + 30), rgbm(0.05, 0.05, 0.05, a), F_BOLD)
    text('paint, plate, glow, tune', 10, vec2(x + 12 + kw + 20, y + 30), rgbm(0.9, 0.9, 0.92, a))
  end
end
