local MAJOR_VERSION = "LibGetFrame-1.1"
local MINOR_VERSION = 3
if not LibStub then
  error(MAJOR_VERSION .. " requires LibStub.")
end
local lib = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION)
if not lib then
  return
end

lib.callbacks = lib.callbacks or LibStub("CallbackHandler-1.0"):New(lib)
local callbacks = lib.callbacks

local GetPlayerInfoByGUID, UnitExists, IsAddOnLoaded, C_Timer, UnitIsUnit, SecureButton_GetUnit =
  GetPlayerInfoByGUID, UnitExists, IsAddOnLoaded, C_Timer, UnitIsUnit, SecureButton_GetUnit
local tinsert, CopyTable, wipe = tinsert, CopyTable, wipe

local maxDepth = 50

local defaultFramePriorities = {
  -- raid frames
  "^Vd1", -- vuhdo
  "^Vd2", -- vuhdo
  "^Vd3", -- vuhdo
  "^Vd4", -- vuhdo
  "^Vd5", -- vuhdo
  "^Vd", -- vuhdo
  "^HealBot", -- healbot
  "^GridLayout", -- grid
  "^Grid2Layout", -- grid2
  "^NugRaid%d+UnitButton%d+", -- Aptechka
  "^PlexusLayout", -- plexus
  "^ElvUF_Raid%d*Group", -- elv
  "^oUF_bdGrid", -- bdgrid
  "^oUF_.-Raid", -- generic oUF
  "^LimeGroup", -- lime
  "^InvenRaidFrames3Group%dUnitButton", -- InvenRaidFrames3
  "^SUFHeaderraid", -- suf
  "^LUFHeaderraid", -- luf
  "^AshToAshUnit%d+Unit%d+", -- AshToAsh
  "^Cell", -- Cell
  -- party frames
  "^AleaUI_GroupHeader", -- Alea
  "^SUFHeaderparty", --suf
  "^LUFHeaderparty", --luf
  "^ElvUF_PartyGroup", -- elv
  "^oUF_.-Party", -- generic oUF
  "^PitBull4_Groups_Party", -- pitbull4
  "^CompactRaid", -- blizz
  "^CompactParty", -- blizz
  -- player frame
  "^InvenUnitFrames_Player",
  "^SUFUnitplayer",
  "^LUFUnitplayer",
  "^PitBull4_Frames_Player",
  "^ElvUF_Player",
  "^oUF_.-Player",
  "^PlayerFrame",
}

local defaultPlayerFrames = {
  "^InvenUnitFrames_Player",
  "SUFUnitplayer",
  "LUFUnitplayer",
  "PitBull4_Frames_Player",
  "ElvUF_Player",
  "oUF_.-Player",
  "oUF_PlayerPlate",
  "PlayerFrame",
}
local defaultTargetFrames = {
  "^InvenUnitFrames_Target",
  "SUFUnittarget",
  "LUFUnittarget",
  "PitBull4_Frames_Target",
  "ElvUF_Target",
  "oUF_.-Target",
  "TargetFrame",
}
local defaultTargettargetFrames = {
  "^InvenUnitFrames_TargetTarget",
  "SUFUnittargetarget",
  "LUFUnittargetarget",
  "PitBull4_Frames_Target's target",
  "ElvUF_TargetTarget",
  "oUF_.-TargetTarget",
  "oUF_ToT",
  "TargetTargetFrame",
}
local defaultPartyFrames = {
  "^InvenUnitFrames_Party%d",
  "^AleaUI_GroupHeader",
  "^SUFHeaderparty",
  "^LUFHeaderparty",
  "^ElvUF_PartyGroup",
  "^oUF_.-Party",
  "^PitBull4_Groups_Party",
  "^CompactParty",
}
local defaultPartyTargetFrames = {
  "SUFChildpartytarget%d",
}
local defaultFocusFrames = {
  "^InvenUnitFrames_Focus",
  "ElvUF_FocusTarget",
  "LUFUnitfocus",
  "FocusFrame",
}
local defaultRaidFrames = {
  "^Vd",
  "^HealBot",
  "^GridLayout",
  "^Grid2Layout",
  "^PlexusLayout",
  "^InvenRaidFrames3Group%dUnitButton",
  "^ElvUF_Raid%d*Group",
  "^oUF_.-Raid",
  "^AshToAsh",
  "^Cell",
  "^LimeGroup",
  "^SUFHeaderraid",
  "^LUFHeaderraid",
  "^CompactRaid",
}

local GetFramesCache = {}
local FrameToUnitFresh = {}
local FrameToUnit = {}
local UpdatedFrames = {}

local function ScanFrames(depth, frame, ...)
  if not frame then
    return
  end
  if depth < maxDepth and frame.IsForbidden and not frame:IsForbidden() then
    local frameType = frame:GetObjectType()
    if frameType == "Frame" or frameType == "Button" then
      ScanFrames(depth + 1, frame:GetChildren())
    end
    if frameType == "Button" then
      local unit = SecureButton_GetUnit(frame)
      local name = frame:GetName()
      if unit and frame:IsVisible() and name then
        GetFramesCache[frame] = name
        if unit ~= FrameToUnit[frame] then
          FrameToUnit[frame] = unit
          UpdatedFrames[frame] = unit
        end
        FrameToUnitFresh[frame] = unit
      end
    end
  end
  ScanFrames(depth, ...)
end

local wait = false

local function doScanForUnitFrames()
  wait = false
  wipe(UpdatedFrames)
  wipe(GetFramesCache)
  wipe(FrameToUnitFresh)
  ScanFrames(0, UIParent)
  callbacks:Fire("GETFRAME_REFRESH")
  for frame, unit in pairs(UpdatedFrames) do
    callbacks:Fire("FRAME_UNIT_UPDATE", frame, unit)
  end
  for frame, unit in pairs(FrameToUnit) do
    if FrameToUnitFresh[frame] ~= unit then
      callbacks:Fire("FRAME_UNIT_REMOVED", frame, unit)
      FrameToUnit[frame] = nil
    end
  end
end

local function ScanForUnitFrames(noDelay)
  if noDelay then
    doScanForUnitFrames()
  elseif not wait then
    wait = true
    C_Timer.After(1, function()
      doScanForUnitFrames()
    end)
  end
end

function lib.ScanForUnitFrames()
  ScanForUnitFrames(true)
end

local function isFrameFiltered(name, ignoredFrames)
  for _, filter in pairs(ignoredFrames) do
    if name:find(filter) then
      return true
    end
  end
  return false
end

local function GetUnitFrames(target, ignoredFrames)
  if not UnitExists(target) then
    if type(target) ~= "string" then
      return
    end
    if target:find("Player") then
      target = select(6, GetPlayerInfoByGUID(target))
    else
      target = target:gsub(" .*", "")
    end
    if not UnitExists(target) then
      return
    end
  end

  local frames
  for frame, frameName in pairs(GetFramesCache) do
    local unit = SecureButton_GetUnit(frame)
    if unit and UnitIsUnit(unit, target) and not isFrameFiltered(frameName, ignoredFrames) then
      frames = frames or {}
      frames[frame] = frameName
    end
  end
  return frames
end

local function ElvuiWorkaround(frame)
  if IsAddOnLoaded("ElvUI") and frame and frame:GetName():find("^ElvUF_") and frame.Health then
    return frame.Health
  else
    return frame
  end
end

local defaultOptions = {
  framePriorities = defaultFramePriorities,
  ignorePlayerFrame = true,
  ignoreTargetFrame = true,
  ignoreTargettargetFrame = true,
  ignorePartyFrame = false,
  ignorePartyTargetFrame = true,
  ignoreFocusFrame = true,
  ignoreRaidFrame = false,
  playerFrames = defaultPlayerFrames,
  targetFrames = defaultTargetFrames,
  targettargetFrames = defaultTargettargetFrames,
  partyFrames = defaultPartyFrames,
  partyTargetFrames = defaultPartyTargetFrames,
  focusFrames = defaultFocusFrames,
  raidFrames = defaultRaidFrames,
  ignoreFrames = {
    "PitBull4_Frames_Target's target's target",
    "ElvUF_PartyGroup%dUnitButton%dTarget",
    "RavenOverlay",
    "AshToAshUnit%d+ShadowGroupHeaderUnitButton%d+",
    "InvenUnitFrames_TargetTargetTarget",
  },
  returnAll = false,
}

local IterateGroupMembers = function(reversed, forceParty)
  local unit = (not forceParty and IsInRaid()) and 'raid' or 'party'
  local numGroupMembers = unit == 'party' and GetNumSubgroupMembers() or GetNumGroupMembers()
  local i = reversed and numGroupMembers or (unit == 'party' and 0 or 1)
  return function()
    local ret
    if i == 0 and unit == 'party' then
      ret = 'player'
    elseif i <= numGroupMembers and i > 0 then
      ret = unit .. i
    end
    i = i + (reversed and -1 or 1)
    return ret
  end
end

local unitPetState = {} -- track if unit's pet exists

local GetFramesCacheListener
local function Init(noDelay)
  if not GetFramesCacheListener then
    GetFramesCacheListener = CreateFrame("Frame")
    GetFramesCacheListener:RegisterEvent("PLAYER_REGEN_DISABLED")
    GetFramesCacheListener:RegisterEvent("PLAYER_REGEN_ENABLED")
    GetFramesCacheListener:RegisterEvent("PLAYER_ENTERING_WORLD")
    GetFramesCacheListener:RegisterEvent("GROUP_ROSTER_UPDATE")
    GetFramesCacheListener:RegisterEvent("UNIT_PET")
    GetFramesCacheListener:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
    GetFramesCacheListener:SetScript("OnEvent", function(event, unit)
      if event == "GROUP_ROSTER_UPDATE" then
        wipe(unitPetState)
        for member in IterateGroupMembers() do
          unitPetState[member] = UnitExists(member .. "pet") and true or nil
        end
      end
      if event == "UNIT_PET" then
        if not (UnitIsUnit("player", unit) or UnitInParty(unit) or UnitInRaid(unit)) then
          return
        end
        -- skip if unit's pet existance has not changed
        local exists = UnitExists(unit .. "pet") and true or nil
        if unitPetState[unit] == exists then
          return
        else
          unitPetState[unit] = exists
        end
      end
      ScanForUnitFrames(false)
    end)
  end
  ScanForUnitFrames(noDelay)
end

function lib.Init()
  Init(true)
end

--[[
local trackingPets = false
-- TrackPets register UNIT_PET, can be useful for tracking pets changes while in encounter, but it can have a bad impact on FPS
function lib.TrackPets(test)
  if type(GetFramesCacheListener) ~= "table" then
    Init(true)
  end
  if test and not trackingPets then
    GetFramesCacheListener:RegisterEvent("UNIT_PET")
    trackingPets = true
  elseif not test and trackingPets then
    GetFramesCacheListener:UnregisterEvent("UNIT_PET")
    trackingPets = false
  end
end
]]

function lib.GetUnitFrame(target, opt)
  if type(GetFramesCacheListener) ~= "table" then
    Init(true)
  end
  opt = opt or {}
  setmetatable(opt, { __index = defaultOptions })

  if not target then
    return
  end

  local ignoredFrames = CopyTable(opt.ignoreFrames)
  if opt.ignorePlayerFrame then
    for _, v in pairs(opt.playerFrames) do
      tinsert(ignoredFrames, v)
    end
  end
  if opt.ignoreTargetFrame then
    for _, v in pairs(opt.targetFrames) do
      tinsert(ignoredFrames, v)
    end
  end
  if opt.ignoreTargettargetFrame then
    for _, v in pairs(opt.targettargetFrames) do
      tinsert(ignoredFrames, v)
    end
  end
  if opt.ignorePartyFrame then
    for _, v in pairs(opt.partyFrames) do
      tinsert(ignoredFrames, v)
    end
  end
  if opt.ignorePartyTargetFrame then
    for _, v in pairs(opt.partyTargetFrames) do
      tinsert(ignoredFrames, v)
    end
  end
  if opt.ignoreFocusFrame then
    for _, v in pairs(opt.focusFrames) do
      tinsert(ignoredFrames, v)
    end
  end
  if opt.ignoreRaidFrame then
    for _, v in pairs(opt.raidFrames) do
      tinsert(ignoredFrames, v)
    end
  end

  local frames = GetUnitFrames(target, ignoredFrames)
  if not frames then
    return
  end

  if not opt.returnAll then
    for i = 1, #opt.framePriorities do
      for frame, frameName in pairs(frames) do
        if frameName:find(opt.framePriorities[i]) then
          return ElvuiWorkaround(frame)
        end
      end
    end
    local next = next
    return ElvuiWorkaround(next(frames))
  else
    for frame in pairs(frames) do
      frames[frame] = ElvuiWorkaround(frame)
    end
    return frames
  end
end
lib.GetFrame = lib.GetUnitFrame -- compatibility

-- nameplates
function lib.GetUnitNameplate(unit)
  if not unit then
    return
  end
  local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
  if nameplate then
    -- credit to Exality for https://wago.io/explosiveorbs
    if nameplate.unitFrame and nameplate.unitFrame.Health then
      -- elvui
      return nameplate.unitFrame.Health
    elseif nameplate.unitFramePlater and nameplate.unitFramePlater.healthBar then
      -- plater
      return nameplate.unitFramePlater.healthBar
    elseif nameplate.kui and nameplate.kui.HealthBar then
      -- kui
      return nameplate.kui.HealthBar
    elseif nameplate.extended and nameplate.extended.visual and nameplate.extended.visual.healthbar then
      -- tidyplates
      return nameplate.extended.visual.healthbar
    elseif nameplate.TPFrame and nameplate.TPFrame.visual and nameplate.TPFrame.visual.healthbar then
      -- tidyplates: threat plates
      return nameplate.TPFrame.visual.healthbar
    elseif nameplate.unitFrame and nameplate.unitFrame.Health then
      -- bdui nameplates
      return nameplate.unitFrame.Health
    elseif nameplate.ouf and nameplate.ouf.Health then
      -- bdNameplates
      return nameplate.ouf.Health
    elseif nameplate.UnitFrame and nameplate.UnitFrame.healthBar then
      -- default
      return nameplate.UnitFrame.healthBar
    else
      return nameplate
    end
  end
end
