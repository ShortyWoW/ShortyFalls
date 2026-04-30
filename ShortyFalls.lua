local ADDON_NAME = ...
local SF = {}
_G.ShortyFalls = SF

print("|cff66ccffShortyFalls|r loaded.")

-- -------------------------------------------------------
-- UI state
-- -------------------------------------------------------
local frame
local cells = {}

-- -------------------------------------------------------
-- Config
-- -------------------------------------------------------
local TARGET_INSTANCE_MAP_ID = 2913

local CELL_SIZE = 44
local CELL_GAP  = 6
local PAD_X     = 12
local PAD_Y     = 12

-- Fallback raid icons only used if custom media is missing.
-- Cell order is: Circle, Diamond, Cross, Triangle, T
local ICON_ORDER = { 5, 3, 7, 4, nil }

local SYMBOL_NAMES = {
  [1] = "Circle",
  [2] = "Diamond",
  [3] = "Cross",
  [4] = "Triangle",
  [5] = "T",
}

local TEX_PATH = "Interface\\AddOns\\ShortyFalls\\media\\"

local TEXTURE_MAP = {
  [1] = TEX_PATH .. "sym_circle.tga",
  [2] = TEX_PATH .. "sym_diamond.tga",
  [3] = TEX_PATH .. "sym_cross.tga",
  [4] = TEX_PATH .. "sym_triangle.tga",
  [5] = TEX_PATH .. "sym_t.tga",
}

-- -------------------------------------------------------
-- SavedVariables
-- -------------------------------------------------------
local function DB()
  if not ShortyFallsDB then ShortyFallsDB = {} end
  if ShortyFallsDB.locked == nil then ShortyFallsDB.locked = true end
  if ShortyFallsDB.debugMode == nil then ShortyFallsDB.debugMode = false end
  if not ShortyFallsDB.assign then ShortyFallsDB.assign = {} end
  if not ShortyFallsDB.used then ShortyFallsDB.used = {} end
  if not ShortyFallsDB.sequence then ShortyFallsDB.sequence = {} end
  return ShortyFallsDB
end

-- -------------------------------------------------------
-- Raid visibility gate
-- -------------------------------------------------------
local function IsDebugForced()
  return ShortyFallsDB and ShortyFallsDB.debugMode == true
end

local function ShouldBeActive()
  if IsDebugForced() then
    return true
  end

  local _, instanceType, _, _, _, _, _, mapID = GetInstanceInfo()
  return instanceType == "raid" and mapID == TARGET_INSTANCE_MAP_ID
end

local function IsMythicRaid()
  local _, instanceType, difficultyID = GetInstanceInfo()
  return instanceType == "raid" and difficultyID == 16
end

local function UpdateVisibility()
  if not frame then return end

  if ShouldBeActive() then
    frame:Show()
  else
    frame:Hide()
  end
end

-- -------------------------------------------------------
-- Raid icons fallback
-- -------------------------------------------------------
local RAID_TEX = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local RAID_TEXCOORDS = {
  [1] = {0.00, 0.25, 0.00, 0.25},
  [2] = {0.25, 0.50, 0.00, 0.25},
  [3] = {0.50, 0.75, 0.00, 0.25},
  [4] = {0.75, 1.00, 0.00, 0.25},
  [5] = {0.00, 0.25, 0.25, 0.50},
  [6] = {0.25, 0.50, 0.25, 0.50},
  [7] = {0.50, 0.75, 0.25, 0.50},
  [8] = {0.75, 1.00, 0.25, 0.50},
}

local function ApplyRaidIcon(tex, iconIndex)
  local tc = RAID_TEXCOORDS[iconIndex]
  if not tc then return end
  tex:SetTexture(RAID_TEX)
  tex:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
end

local function SetSymbolTexture(tex, symbolIndex)
  if not tex or not symbolIndex then return end

  local ok = tex:SetTexture(TEXTURE_MAP[symbolIndex])
  if ok then
    tex:SetTexCoord(0, 1, 0, 1)
  else
    local fallback = ICON_ORDER[symbolIndex]
    if type(fallback) == "number" then
      ApplyRaidIcon(tex, fallback)
    else
      tex:Hide()
      print("|cff66ccffShortyFalls|r Missing media texture: " .. tostring(TEXTURE_MAP[symbolIndex]))
    end
  end
end

-- -------------------------------------------------------
-- Positioning / visuals
-- -------------------------------------------------------
local function GetCellPosition(index)
  local x = PAD_X + (index - 1) * (CELL_SIZE + CELL_GAP)
  local y = -PAD_Y - 22
  return x, y
end

local function PlaceCell(cell, positionIndex)
  local x, y = GetCellPosition(positionIndex)
  cell:ClearAllPoints()
  cell:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
end

local function RestoreOriginalCellOrder()
  for i = 1, #cells do
    PlaceCell(cells[i], i)
  end
end

local function SetCompleteVisual(complete)
  if not frame then return end

  if complete then
    frame:SetBackdropBorderColor(0.2, 1, 0.35, 0.95)
    frame:SetBackdropColor(0, 0.18, 0.06, 0.42)
  else
    frame:SetBackdropBorderColor(1, 1, 1, 0.25)
    frame:SetBackdropColor(0, 0, 0, 0.35)
  end
end

local function ClearCellExtras(cell)
  if not cell then return end
  if cell.num then cell.num:SetText("") end
  if cell.sequenceTex then cell.sequenceTex:Hide() end
  if cell.icon then cell.icon:SetAlpha(1) end
  cell:SetBackdropBorderColor(1, 1, 1, 0.25)
  if cell.bg then cell.bg:SetColorTexture(1, 1, 1, 0.10) end
end

local function UseBaseSymbolVisuals()
  for i = 1, #cells do
    ClearCellExtras(cells[i])
    if cells[i].icon then
      cells[i].icon:SetAlpha(1)
      SetSymbolTexture(cells[i].icon, i)
      cells[i].icon:Show()
    end
  end
end

local function ReorderByAssignedNumber()
  local db = DB()
  local ordered = {}

  for i = 1, #cells do
    local assignedNumber = db.assign[i]
    if assignedNumber then
      ordered[assignedNumber] = cells[i]
    end
  end

  for n = 1, 5 do
    if ordered[n] then
      PlaceCell(ordered[n], n)
    end
  end
end

local function GetSequenceCount()
  local db = DB()
  local count = 0

  for step = 1, 5 do
    if db.sequence[step] then
      count = step
    end
  end

  return count
end

local function IsSequenceComplete()
  return GetSequenceCount() == 5
end

local function RenderMythicEntryVisuals()
  RestoreOriginalCellOrder()
  UseBaseSymbolVisuals()

  local db = DB()
  local perSymbol = {}

  for step = 1, 5 do
    local symbolIndex = db.sequence[step]
    if symbolIndex then
      perSymbol[symbolIndex] = perSymbol[symbolIndex] and (perSymbol[symbolIndex] .. "," .. step) or tostring(step)
    end
  end

  for symbolIndex = 1, #cells do
    if cells[symbolIndex] and cells[symbolIndex].num then
      cells[symbolIndex].num:SetText(perSymbol[symbolIndex] or "")
    end
  end
end

local function RenderMythicSequenceVisuals()
  RestoreOriginalCellOrder()

  local db = DB()

  for slot = 1, #cells do
    local cell = cells[slot]
    local symbolIndex = db.sequence[slot]

    ClearCellExtras(cell)

    if symbolIndex then
      if cell.icon then cell.icon:SetAlpha(0) end
      if cell.sequenceTex then
        SetSymbolTexture(cell.sequenceTex, symbolIndex)
        cell.sequenceTex:Show()
      end
      if cell.num then cell.num:SetText(tostring(slot)) end
    end
  end
end

local function SavePosition()
  local db = DB()
  local point, _, relPoint, x, y = frame:GetPoint(1)
  db.pos = { point = point, relPoint = relPoint, x = x, y = y }
end

local function RestorePosition()
  local db = DB()
  frame:ClearAllPoints()

  if db.pos then
    frame:SetPoint(db.pos.point, UIParent, db.pos.relPoint, db.pos.x, db.pos.y)
  else
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
  end
end

local function ApplyLockState()
  local db = DB()

  if db.locked then
    frame:RegisterForDrag()
    frame:SetScript("OnDragStart", nil)
    frame:SetScript("OnDragStop", nil)
  else
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
      self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
      SavePosition()
    end)
  end
end

-- -------------------------------------------------------
-- Logic
-- -------------------------------------------------------
local function ResetAll()
  local db = DB()

  wipe(db.assign)
  wipe(db.used)
  wipe(db.sequence)

  RestoreOriginalCellOrder()
  UseBaseSymbolVisuals()
  SetCompleteVisual(false)
end

local function GetNextNumber()
  local db = DB()

  for n = 1, 5 do
    if not db.used[n] then
      return n
    end
  end
end

local function Assign(i)
  local db = DB()

  if IsMythicRaid() then
    local step = GetSequenceCount() + 1
    if step > 5 then return end

    -- Mythic sequence mode allows duplicates:
    -- T > Circle > Circle > Diamond > T, etc.
    db.sequence[step] = i

    if step == 5 then
      RenderMythicSequenceVisuals()
      SetCompleteVisual(true)
    else
      RenderMythicEntryVisuals()
      SetCompleteVisual(false)
    end

    return
  end

  -- Standard mode: one number per symbol.
  if db.assign[i] then return end

  local n = GetNextNumber()
  if not n then return end

  db.assign[i] = n
  db.used[n] = true

  cells[i].num:SetText(tostring(n))

  if n == 5 then
    ReorderByAssignedNumber()
    SetCompleteVisual(true)
  end
end

local function ApplyFromDB()
  if IsMythicRaid() then
    if IsSequenceComplete() then
      RenderMythicSequenceVisuals()
      SetCompleteVisual(true)
    else
      RenderMythicEntryVisuals()
      SetCompleteVisual(false)
    end
    return
  end

  local db = DB()
  local complete = true

  UseBaseSymbolVisuals()

  for i = 1, #cells do
    local n = db.assign[i]
    cells[i].num:SetText(n and tostring(n) or "")

    if not n then
      complete = false
    end
  end

  if complete then
    ReorderByAssignedNumber()
    SetCompleteVisual(true)
  else
    RestoreOriginalCellOrder()
    SetCompleteVisual(false)
  end
end

-- -------------------------------------------------------
-- Build UI
-- -------------------------------------------------------
local function BuildUI()
  if frame then return end
  DB()

  local totalW = PAD_X * 2 + CELL_SIZE * 5 + CELL_GAP * 4
  local totalH = PAD_Y * 2 + CELL_SIZE + 26

  frame = CreateFrame("Frame", "ShortyFallsFrame", UIParent, "BackdropTemplate")
  frame:SetSize(totalW, totalH)
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  frame:SetBackdropColor(0, 0, 0, 0.35)
  frame:SetBackdropBorderColor(1, 1, 1, 0.25)
  frame:SetClampedToScreen(true)

  frame:EnableMouse(true)
  frame:SetMovable(true)

  local fontPath = (GameFontNormal and select(1, GameFontNormal:GetFont()))
    or STANDARD_TEXT_FONT
    or "Fonts\\FRIZQT__.TTF"

  for i = 1, 5 do
    local cell = CreateFrame("Button", nil, frame, "BackdropTemplate")
    cell:SetSize(CELL_SIZE, CELL_SIZE)

    PlaceCell(cell, i)

    cell:SetBackdrop({
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
    })
    cell:SetBackdropBorderColor(1, 1, 1, 0.25)

    cell.bg = cell:CreateTexture(nil, "BACKGROUND")
    cell.bg:SetAllPoints(cell)
    cell.bg:SetColorTexture(1, 1, 1, 0.10)

    cell.icon = cell:CreateTexture(nil, "OVERLAY")
    cell.icon:SetPoint("CENTER", cell, "CENTER", 0, 0)
    cell.icon:SetSize(CELL_SIZE - 10, CELL_SIZE - 10)
    cell.icon:SetAlpha(1)
    SetSymbolTexture(cell.icon, i)

    cell.sequenceTex = cell:CreateTexture(nil, "OVERLAY")
    cell.sequenceTex:SetPoint("CENTER", cell, "CENTER", 0, 0)
    cell.sequenceTex:SetSize(CELL_SIZE - 10, CELL_SIZE - 10)
    cell.sequenceTex:Hide()

    cell.num = cell:CreateFontString(nil, "OVERLAY")
    cell.num:SetPoint("BOTTOM", cell, "TOP", 0, 6)
    cell.num:SetFont(fontPath, 28, "OUTLINE")
    cell.num:SetTextColor(1, 1, 1, 1)
    cell.num:SetShadowColor(0, 0, 0, 1)
    cell.num:SetShadowOffset(0, 0)
    cell.num:SetText("")

    cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    cell:SetScript("OnClick", function(_, btn)
      if btn == "RightButton" then
        ResetAll()
      else
        Assign(i)
      end
    end)

    cells[i] = cell
  end

  RestorePosition()
  ApplyLockState()
  ApplyFromDB()
  UpdateVisibility()
end

BuildUI()

-- -------------------------------------------------------
-- Eventless polling visibility
-- -------------------------------------------------------
C_Timer.NewTicker(1.0, function()
  UpdateVisibility()
end)

-- -------------------------------------------------------
-- Slash commands
-- -------------------------------------------------------
SLASH_SHORTYFALLS1 = "/sfalls"
SlashCmdList["SHORTYFALLS"] = function(msg)
  msg = (msg or ""):lower()

  if msg == "debug" then
    local db = DB()
    db.debugMode = not db.debugMode

    if db.debugMode then
      frame:Show()
      print("|cff66ccffShortyFalls|r debug mode |cff00ff00ON|r - frame forced visible.")
    else
      UpdateVisibility()
      print("|cff66ccffShortyFalls|r debug mode |cffff0000OFF|r - raid mapID 2913 gate restored.")
    end
    return
  end

  if msg == "show" then
    if ShouldBeActive() then
      frame:Show()
    else
      frame:Hide()
      print("|cff66ccffShortyFalls|r only shows inside raid mapID 2913. Use /sfalls debug to force it open.")
    end
    return
  end

  if msg == "hide" then
    frame:Hide()
    return
  end

  if msg == "lock" then
    DB().locked = true
    ApplyLockState()
    print("|cff66ccffShortyFalls|r locked.")
    return
  end

  if msg == "unlock" then
    DB().locked = false
    ApplyLockState()
    print("|cff66ccffShortyFalls|r unlocked.")
    return
  end

  if msg == "clear" or msg == "reset" then
    ResetAll()
    return
  end

  if msg == "where" then
    local name, instanceType, difficultyID, _, _, _, _, mapID = GetInstanceInfo()
    print("|cff66ccffShortyFalls|r Instance:", name or "nil", "Type:", instanceType or "nil", "MapID:", tostring(mapID))
    print("|cff66ccffShortyFalls|r DifficultyID:", tostring(difficultyID), "Mode:", IsMythicRaid() and "MYTHIC SEQUENCE" or "STANDARD UNIQUE")
    print("|cff66ccffShortyFalls|r Active:", ShouldBeActive() and "YES" or "NO")
    print("|cff66ccffShortyFalls|r Debug Mode:", DB().debugMode and "ON" or "OFF")
    return
  end

  print("|cff66ccffShortyFalls commands|r:")
  print("/sfalls debug")
  print("/sfalls show")
  print("/sfalls hide")
  print("/sfalls lock")
  print("/sfalls unlock")
  print("/sfalls clear")
  print("/sfalls where")
end