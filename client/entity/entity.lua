require "common.entity"
require "entity.entity_event"
local guide = require "guide.guide"

local ClientBuffId = L("ClientBuffId", 0)

---@type Entity
local Entity = Entity

function Entity.EntityProp:edge(value, add, buff)
	if add then
		self:setEdge(true, value.color or {1,1,1,1})
	else
		self:setEdge(false, value.color or {1,1,1,1})
	end
end

function Entity.EntityProp:effect(value, add, buff)
	local name = string.format("buff_%d_%d", self.objID, buff.id)
	if add then
		self:showEffect(value, buff.cfg, name)
	else
		self:delEffect(name, value.smoothRemove)
	end
end

function Entity.EntityProp:actionMap(value, add)
	if add then
		for src, dst in pairs(value) do
			self:setActionMapping(src, dst)
		end
	else
		for src, dst in pairs(value) do
			self:removeActionMapping(src)
		end
	end
end


function Entity.EntityProp:sound(value, add, buff)
	local ti = TdAudioEngine.Instance()
	if add then
		buff.soundId = self:playSound(value, buff.cfg)
		local soundId = buff.soundId
		local volume = tonumber(value.volume)
		if volume then
			ti:setSoundsVolume(soundId, volume)
		end
		local rollOffType = Sound3DRollOffType[value.rollOffType]
		if rollOffType then
			ti:set3DRollOffMode(soundId, rollOffType)
		end
		local distance = value.distance
		if distance then
			ti:set3DMinMaxDistance(soundId, distance[1], distance[2])
		end
	else
		ti:stopSound(buff.soundId)
	end
end

function Entity.EntityProp:headText(value, add, cfg, id)
	if add then
		Entity.setHeadText(self, value.x, value.y, value.txt)
		self:updateShowName()
	else
		Entity.setHeadText(self, value.x, value.y, nil)
		self:updateShowName()
	end
end
Entity.EntityProp.headText1 = Entity.EntityProp.headText

function Entity.EntityProp:hide(value, add, cfg, id)
	local prop = self:prop()
	local hide = prop.hide or 0
	local oldHide = hide > 0
	prop.hide = hide + (add and value or -value)
	local newHide = prop.hide > 0
	if oldHide==newHide then
		return
	end
	if not newHide then
		self:setAlpha(1, 10)
	elseif self.isMainPlayer then
		local hideDeep = self:cfg().hideDeep or 0.4
		self:setAlpha(hideDeep, self:cfg().hideTime)
	else
		local hideDeepOther = self:cfg().hideDeepOther or 0.1
		self:setAlpha(hideDeepOther, self:cfg().hideTime)
	end
	self:updateShowName()
	self:timer(2, function()  self:setActorPostionDirty(true)  end)
end

function Entity.EntityProp:actorFlashEffect(value, add, buff)
	local time = 0
	if add and not self.actorEffectTimer then
		self.actorEffectTimer = World.Timer(3, function()
			self:setAlpha(time % 2)
			time = time + 1
			return true
		end)
	else
		if self.actorEffectTimer then
			self.actorEffectTimer()
			self:setAlpha(1)
			self.actorEffectTimer = nil
		end
	end
end

function Entity.EntityProp:scale(value, add, buff)
	local data = Lib.v3(1, 1, 1)
	if add then
		data = Lib.v3(value.x, value.y, value.z)
	end
	self:setData("actorScale", data)
	self:setActorScale(data)
end

function Entity.EntityProp:interactionUiOffset(value, add, buff)
	self:setData("interactionUiOffset", add and value or {})
end

function Entity.EntityProp:refreshInteractionUI(value)
    local objID = self.objID
    Me:timer(1, function ()--it depends on the other prop, (may not be calculated)
        Me:updateObjectInteractionUI({recheck = true, objID = objID})
    end)
end

function Entity.EntityProp:headInfo(value, add, buff)
	Lib.emitEvent(Event.EVENT_HEADINFO_CHANGE, value)
end

function Entity.EntityProp:actionTimeScaleMap(value, add)
	for ac, ts in pairs(value) do
		if add then
			self:setActionTimeScale(ac, ts)
		else
			self:removeActionTimeScale(ac)
		end
	end
end

if Blockman.instance.singleGame then
	function Entity.EntityProp:skin(value, add, cfg, id)
		if add then
			self:applySkin(value)
		else
			local reset = {}
			for m, _ in pairs(value) do
				reset[m] = 0
			end
			self:applySkin(reset)
		end
	end
end

function Entity.ValueFunc:ownerId(value)
	self:updateCanAttack()
end

function Entity.ValueFunc:teamId(value)
	self:updateCanAttack()
end

function Entity.ValueFunc:guideStep(value)
	guide.SetStep(value)
end


local rule = {
	armor_chest = {},
	armor_foot = {},
	armor_head = {},
	armor_thigh = {},
	clothes_pants = {"armor_thigh"},
	clothes_tops = {"armor_chest"},
	custom_back = {},
	custom_classes = {},
	custom_crown = {},
	custom_decorate_hat = {},
	custom_face = {},
	custom_glasses = {},
	custom_hair = { "armor_head" },
	custom_hand = {},
	custom_hat = {},
	custom_offhand = {},
	custom_scarf = {"armor_chest"},
	custom_shoes = {"armor_foot"},
	custom_tops = {},
	custom_tail = {},
	custom_wing = {},
	custom_crown = {},
	custom_suits = {},
	gun = {}
}

for master, prior in pairs(rule) do
	for _, master_prior in ipairs (prior) do
		prior[master_prior] = true
	end
end

---@field updateUpperAction fun(self : EntityClient, action : string, ticks : number) : number
---@field getBaseAction fun(self : EntityClient) : string
---@field getUpperAction fun(self : EntityClient) : string
---@field setBaseAction fun(self : EntityClient, action : string) : void
---@field setUpperAction fun(self : EntityClient, action : string) : void
---@field getPrevBaseAction fun(self : EntityClient) : string
---@field getPrevUpperAction fun(self : EntityClient) : string
---@field setPreBaseAction fun(self : EntityClient, action : string) : void
---@field setPreUpperAction fun(self : EntityClient, action : string) : void
---@field refreshUpperAction fun(self : EntityClient) : void
---@field getActorName fun(self : EntityClient) : string
---@class EntityClient : Entity
local EntityClient = EntityClient

function EntityClient.processSkin(actorName, skins, fromScene, applyDefaultSkin)
	skins = skins or {}
	local result = {}

	local default = ActorManager:Instance():getActorDefaultBodyPart(actorName) or {}

	for master, priors in pairs(rule) do
		repeat
			if not skins[master] or skins[master] == ""  then
				result[master] = default[master] or ""
			end

			local conflict = false
			for prior in pairs(priors) do
				if skins[prior] and skins[prior] ~= "" then
					conflict = true
					break
				end
			end
			if not conflict then
				result[master] = result[master] or skins[master]
			else
				result[master] = ""
			end

			if (master == "custom_suits" or master == "skin_color") and result[master] == "" then
				result[master] =  {}
			end

		until(true)
	end

	local useNewFace = false
	for master, slave in pairs(skins) do
		if string.find(master, "merge_face") then 
			useNewFace = true
		end

		if not rule[master] then
			result[master] = slave
		end
	end

	if not fromScene then
		result = EntityClient.resetSkin(result)
	end

	if applyDefaultSkin then
		for master, slave in pairs(default) do
			if not result[master] or result[master] == "" then
				result[master] = slave
			end
		end
	end

	if useNewFace then
		local defaultSkin = SkinSetting.getDefaultFaceSkinForLua()
		for key, v in pairs(defaultSkin) do
			if not result[v[1]] then 
				result[v[1]] = v[2]
			end
		end
		result["custom_face"] = ""
	end
	return result
end

local function checkValue(skins, key)
	if skins[key] == "" then
		return true
	end
	return false
end

local function checkUseSuits(skins)
	assert(type(skins) == "table")
	if not skins["custom_suits"] then
		return false
	end

	if ((type(skins["custom_suits"]) == "string" and skins["custom_suits"] ~= "")
			or (type(skins["custom_suits"]) ~= "string" and next(skins["custom_suits"])))
			and checkValue(skins, "armor_foot")
			and checkValue(skins, "armor_thigh")
			and checkValue(skins, "armor_chest")
			and (skins["suits_head"] == 0 or checkValue(skins, "armor_head")) then
		return true
	end
	return false
end

function EntityClient.resetSkin(result)
	local newSkins = {}
	local useSuits = checkUseSuits(result)
	for master, slave in pairs(result or {}) do
		local skin = slave
		if useSuits then
			if master == "custom_suits" and type(slave) ~= "string" then
				for i, v in pairs(slave) do
					if i == 1 then
						skin = tostring(v)
					else
						skin = skin .. "-" .. tostring(v)
					end
				end
			end
			if (master == "custom_face" or master == "clothes_tops" or master == "custom_hair" or master == "clothes_pants" or master == "custom_shoes") and slave == 0 then
				skin = ""
			end
		else
			if master == "custom_suits" then
				skin = ""
			end
		end
		newSkins[master] = skin
	end
	--print("set skin : " .. Lib.v2s(newSkins))
	return newSkins
end

local function setSkin(self, skins)
	local selfSkins = self:data("skins")
	for master, slave in pairs(skins or {}) do
		selfSkins[master] = slave
	end

	local result = self.resetSkin(skins)
	local selfChildActors = self:data("child_actors")
	for master, _ in pairs(selfChildActors) do
		if type(result[master]) ~= "table" then
			---新装饰里面没报包含该子actor,卸载该子actor
			self:delChildActor(master)
			selfChildActors[master] = nil
			result[master] = nil
			selfSkins[master] = nil
		end
	end
	for master, slave in pairs(result or {}) do
		if master == "skin_color" then
			self:setActorCustomColor(slave)
		elseif master:find(".child") then
			if slave.replace then
				if selfChildActors[master] then
					self:delChildActor(master)
				end
				self:addChildActor(master, slave)
				slave.replace = nil
			else
				if not selfChildActors[master] then
					self:addChildActor(master, slave)
				end
			end
			selfChildActors[master] = slave
		else
			self:updateAttachModel(master, slave)
		end
	end
	Lib.emitEvent(Event.EVENT_ENTITY_SKIN_CHANGE, self)
end

function EntityClient:applySkinPart(skinPartData)

	if self.actorApplySkinPartTimer then
		self.actorApplySkinPartTimer()
		self.actorApplySkinPartTimer = nil
	end

	local skinPartQueue = self:data("skinPartQueue")
	if skinPartData and next(skinPartData) then
		table.insert(skinPartQueue, skinPartData)
	end

	local skinQueue = self:data("skinQuene")
	if self:getActorName() == "blank.actor" then
		return
	end
	if self:isActorPrepared() and skinQueue and not next(skinQueue) then
		if #skinPartQueue > 0  then
			for _, data in pairs(skinPartQueue) do
				local selfSkins = self:data("skins")
				for master, slave in pairs(data or {}) do
					selfSkins[master] = slave
				end
				self:applySkin(Lib.copy(selfSkins))
			end
			self:setData("skinPartQueue", {})
		else
			local selfSkins = self:data("skins")
			self:applySkin(Lib.copy(selfSkins))
		end
	else
		self.actorApplySkinPartTimer = self:lightTimer("EntityClient:applySkinPart", 1, self.applySkinPart, self)
	end
end

local function doAttachModel(self, skin)
	if self.removed then 
		return 
	end
	local result = EntityClient.processSkin(self:data("main").actorName or self:cfg().actorName, skin, true, self:cfg().applyDefaultSkin)
	setSkin(self, result)
end

function EntityClient:applySkin(skin)
	if World.cfg.disableApplySkin then
		return 
	end

	 if self.actorAttachModelTimer then
		 self.actorAttachModelTimer()
		 self.actorAttachModelTimer = nil
	 end
	 if self:getActorName() == "blank.actor" then
		return
	end
	 if self:isActorPrepared() then
		 local skinQuene = self:data("skinQuene")
		 if #skinQuene > 0 then
			 for _, s in ipairs(skinQuene) do
				 doAttachModel(self, s)
			 end
			 self:setData("skinQuene", {})
		 end
		 if skin then
			 doAttachModel(self, skin)
		 end
	 else
		 local skinQuene = self:data("skinQuene")
		 skinQuene[#skinQuene + 1] = Lib.copy(skin)
		 self.actorAttachModelTimer = self:lightTimer("EntityClient:applySkin", 1, self.applySkin, self)
	 end
end

function EntityClient:updateShowName()
    local cfg = self._cfg
	if cfg.hideSelfName and self == Me then
		self:setShowName("\n")
		return
	end
	if self:prop().hide == 1 and self ~= Me then
		self:setShowName("\n")
		return
	end
	if cfg.hideName or (self.map and self.map.cfg and self.map.cfg.hideName) then
		self:setShowName("\n")
		return
	end

	local headText = self:data("headText")
	local clientLines = headText.ary or {}
	local serverLines = headText.svrAry or {}
	local list = {}
	for y = -3, 1 do		-- line: top to buttom
		local cline = clientLines[y] or {}
		local sline = serverLines[y] or {}
		local line = {}
		for x = -2, 2 do	-- column: left to right
			local t = cline[x] or sline[x]
			if t then
				t = Lang:toText(t)
			elseif y == 0 and x == 0 then
				t = self.name
			end
			line[#line + 1]	= t
		end
		if #line > 0 then
			list[#list + 1] = table.concat(line)
		end
	end
	local cfg = self._cfg
	local name = table.concat(list, "\n")

	if cfg.nameBorder or World.cfg.nameBorder then
		name = "[B=1]" .. name
	end

	if not cfg.hideName then
		self:setShowName(name,cfg.headFont or World.cfg.headFont or "HT24")
	end

	if cfg.hideSelfName and self == Me then
		self:setShowName("\n",cfg.headFont or World.cfg.headFont or "HT24")
	end
end

function EntityClient:updateCanAttack()
	local player = Player.CurPlayer
	if player.objID==self.objID then
		for _, obj in ipairs(World.CurWorld:getAllObject()) do
			if obj.isEntity and obj.objID~=player.objID then
				obj:updateCanAttack()
			end
		end
	else
		local entityOwner = self:owner()
		local playerOwner = player:owner()
		local entityTeam = entityOwner:getValue("teamId")
		local playerTeam = playerOwner:getValue("teamId")
		if (playerTeam~=0 and playerTeam == entityTeam) or not player:canAttack(self) then
			self:setShowHpColor(0x00ff00)
		else
			self:setShowHpColor(-1)
		end
	end
end

local function getIconText(self, key)
	local map = self:prop(key)
	if not next(map) then
		return nil
	end
	local list = self:data("buff")
	local ary = {}
	for id, icon in pairs(map) do
		local path = ResLoader:loadImage(list[id].cfg, icon)
		ary[#ary+1] = "[P="..path.."]"
	end
	return table.concat(ary)
end

function EntityClient:updatePropShow(forceUpdate)
	local txt = getIconText(self, "prefixIcon")
	local changed = self:setHeadText(-2, 0, txt) or forceUpdate
	txt = getIconText(self, "suffixIcon")
	changed = self:setHeadText(2, 0, txt) or changed
	txt = getIconText(self, "designationIcon")
	changed = self:setHeadText(-2, -1, txt) or changed
	local star = self:prop("headStar")
	txt = nil
	if star>0 then
		local starText = World.cfg.starText or {}
		txt = string.rep(starText[1] or "\u{2605}", math.floor(star / 2)) ..
			string.rep(starText[2] or "\u{2606}", star % 2)
	end
	changed = self:setHeadText(0, -2, txt) or changed
	if changed then
		self:updateShowName()
	end
end

function Entity.EntityProp:voxelTest(value, add, buff)
	if add then
		Me.testTimer = Me:timer(1,function ()
			Me:setPosition(Me:getPosition() + Lib.v3(0, 0, 10))
			return true
		end)
	else
		Me.testTimer()
	end
end

function Entity.EntityProp:firstViewUIEffect(value, add, buff)
	if self.isMainPlayer then
		Lib.emitEvent(Event.PLAYE_UI_EFFECT, value, add)
	end
end

function EntityClient:calcBuff(buff, add, from)
	Entity.calcBuff(self, buff, add, from)
    if self.isMainPlayer then
        self:playGameBgm()
    end
	local cfg = buff.cfg
	if cfg.prefixIcon or cfg.suffixIcon or cfg.headStar or cfg.designationIcon then
		self:updatePropShow()
	end
    if cfg.flyModulus and self.isMainPlayer then
        Lib.emitEvent(Event.EVENT_UPDATE_FLY_STATE, self:prop()["flyModulus"] < 0)
    end
end
function EntityClient:stopGameBgm()
	local bgmsoundId = self:data("main").bgmsoundId
	if bgmsoundId ~= nil then
		TdAudioEngine.Instance():stopSound(bgmsoundId)
		self:data("main").bgmsoundId = nil
		self:data("main").lastbgmpath = nil
	end
end

function EntityClient:playGameBgm(bgm)
	if self.disableGameBgm then
		return nil
	end
	if bgm then
		if bgm.bgmSound then
			self._prop["bgmSound"] = bgm.bgmSound
		end
		if bgm.bgmVolume then
			self._prop["bgmVolume"] = bgm.bgmVolume
		end
	end
	local path = self:prop("bgmSound")
	--Lib.logDebug("EntityClient playGameBgm", path)
	local main = self:data("main")
	if path and path ~= "" then
		if path:sub(1,1)=="/" then
			path = "plugin/" .. self:cfg().plugin .."/".."bgm".. path
		elseif path:sub(1,1)=="@" then
			path = path:sub(2)
		else
			path = "plugin/" .. self:cfg().plugin .. "/" .. "bgm" .. "/" .. path
		end
	end
	local bgmsoundId = main.bgmsoundId
    local lastpath = main.lastbgmpath
    if bgmsoundId ~= nil and lastpath ~= path then
        TdAudioEngine.Instance():stopSound(bgmsoundId)
        main.bgmsoundId = nil
        main.lastbgmpath = nil
    end
    if path and path ~= "" and lastpath ~= path then
        main.bgmsoundId = TdAudioEngine.Instance():play2dSound(path,true)
        TdAudioEngine.Instance():setSoundsVolume(main.bgmsoundId, self:prop("bgmVolume") or 1)
    end
    main.lastbgmpath = path
	return main.bgmsoundId
end


function EntityClient:entityActorSquashed(scaleY)
	self:setActorScaleY(scaleY)
end

function EntityClient:getEffectName()
	local data = self:data("main")
	local effectId = (data.effectId or 0) + 1
	data.effectId = effectId
	return string.format("obj_%d_%d", self.objID, effectId)
end

function EntityClient:showEffect(effect, cfg, name)
	if not effect or not effect.effect then
		return nil
	elseif effect.selfOnly and not (self:owner():isControl())  and not self:cfg().enablebuffEffect then
		return nil
	end
	if not effect.path then
		cfg = cfg or self:cfg()
        effect.path = ResLoader:filePathJoint(cfg, effect.effect)
	end
	if not name then
		name = self:getEffectName()
	end
	local once = effect.once
	if once==nil then
		once = true
	end
	if effect.time then
		---@type LuaTimer
		local LuaTimer = T(Lib, "LuaTimer")
		LuaTimer:scheduleTimer(function()
			if self:isValid() then
				self:delEffect(name)
			end
		end, effect.time, 1)
	end
	if not effect.isFixedPosition then
		self:addEffect(name, effect.path, once, effect.pos, effect.yaw, effect.scale or {x = 1, y = 1, z = 1})
	else
		Blockman.instance:playEffectByPos(effect.effect, self:getPosition() + effect.pos, 360 - self:getBodyYaw() + effect.yaw, effect.time or 500, effect.scale or {x = 1, y = 1, z = 1})
	end
	return name
end

function EntityClient:updateMainPlayerRideOn()
    local player = Player.CurPlayer
    local target = World.CurWorld:getEntity(player.rideOnId)
    PlayerControl.UpdateControlInfo(target)
	Lib.emitEvent(Event.EVENT_RIDE, player, player:isCameraMode() and nil or target)
    PlayerControl.UpdatePersonView()
end

function EntityClient:rideOff(rideOffID)
	--assert(rideOffID == self.rideOnId)
	local old = self.world:getEntity(self.rideOnId)
	if old then
		local idx = self.rideOnIdx + 1
		if not self:isCameraMode() then
			local pos = old:cfg().ridePos[idx]
			local BoundingBox = old:getBoundingBox()
			if BoundingBox then
				self:setPosition({
					x = (BoundingBox[2].x + BoundingBox[3].x) / 2,
					y = (BoundingBox[2].y + BoundingBox[3].y) / 2,
					z = (BoundingBox[2].z + BoundingBox[3].z) / 2,
				})
			else
				self:setPosition(old:getPosition())
			end
			local debusPos = pos.out or pos.pos or {x = 0, y = 0, z = 0}
			debusPos = Lib.posAroundYaw(debusPos, old:getRotationYaw())
			self:debusFromRide(debusPos)
		end
		old:changePassenger(idx, nil)
		self:setAlwaysAction("")
	end
end

function EntityClient:rideOn(target, index)
	if not target and self.rideOnId == 0 then
		return
	end
    local world = self.world
	local rideOnId, rideOnIdx= self.rideOnId, self.rideOnIdx
    self.isMoving = false
    self.hitchingToId = 0
    if target then
    	local ridePos = target:cfg().ridePos
		local idx = index + 1
    	if not ridePos or not ridePos[idx] then
    		print("Invalid config of ridePos, entity:"..target:cfg().fullName..", index:"..idx)
    		return
    	end
        local pos = ridePos[idx]
        if pos.yaw then
			self:setRotationYaw(target:getBodyYaw() + pos.yaw)
        end
		self:setRideOn(target.objID, index)
		target:changePassenger(idx, self.objID)
		self:setAlwaysAction(pos.ride_Action or "")
		if target:cfg().autoDebusFromRide then
			local pos = target:seekRoundDroppablePos({x = 0, y = 0, z = 0}, 5)
			target:setPosition(pos)
		end
		rideOnId, rideOnIdx = self.rideOnId, self.rideOnIdx
    elseif self.rideOnId > 0 then
		self:setRideOn(0, 0)
    end
	self:changeActions()
    if self.isMainPlayer then
		self:updateMainPlayerRideOn()
	end
	self:setRideOnRenderPosQueueSize(self:cfg().rideOnRenderPosQueueSize or 0)
	Lib.emitEvent(target and Event.EVENT_ENTITY_RIDE_ON or Event.EVENT_ENTITY_RIDE_OFF, self.objID, rideOnId, rideOnIdx)
end

function EntityClient:checkCD(key,ignoreNetDelay)
	local rest = nil
	if not ignoreNetDelay then 
		rest = Entity.checkCD(self, "net_delay")
	end
	if rest then
		return 0
	end
	return Entity.checkCD(self, key)
end

function EntityClient:setCD(key, time, cfg)
	Entity.setCD(self, "net_delay", nil)
	Entity.setCD(self, key, time)
	if self.isMainPlayer and cfg and (cfg.enableCdMask or cfg.enableCdTip) and time then
		local now = World.Now()
		local skill = {
			name = cfg.fullName,
			cdMask = cfg.enableCdMask,
			beginTime = now,
			endTime = now + time,
			cdTip = cfg.enableCdTip
		}
		Lib.emitEvent(Event.EVENT_SHOW_CD_MASK, skill)
	end
end

---@return EntityClient
function EntityClient.CreateClientEntity(params)
	local cfg = Entity.GetCfg(params.cfgName)
	if cfg == nil then return end
	assert(cfg.id,params.cfgName)
	local world = World.CurWorld
	local entity = EntityClient.CreateEntity(cfg.id, world, world:nextLocalID(), "")
	entity:invokeCfgPropsCallback()
	if params.name then
		entity:setName(Lang:toText(params.name))
	end
	entity:setMap(World.CurMap)
	if params.pos then
		entity:setPosition(params.pos)
	end

	if params.ry then
		entity:setRotationYaw(params.ry)
		entity:setBodyYaw(params.ry)
	end

	entity:onCreate();
	entity:updateShowName()
	ExecUserScript.chunk(cfg , entity, "_clientScript")
	return entity
end

function EntityClient:addClientBuff(name, id, time, from)
	if not id then
		id = ClientBuffId - 1
		ClientBuffId = id
	end
    local buff = {
		cfg = Entity.BuffCfg(name),
		id = id,
		owner = self,
		time = time
	}
    self:data("buff")[id] = buff
    self:calcBuff(buff, true, from)
    if self.isMainPlayer then
        Lib.emitEvent(Event.DRAW_BUFFICON,buff)
		Lib.emitEvent(Event.FETCH_ENTITY_INFO,true) -- 更新buff后需要更新entity的属性视图
    end
	return buff
end

function EntityClient:removeClientBuff(buff)
    local id = assert(buff.id, "already removed?")
    self:data("buff")[id] = nil
    self:calcBuff(buff, false)
    if self.isMainPlayer then
        Lib.emitEvent(Event.CLEAR_BUFFICON, buff)
		Lib.emitEvent(Event.FETCH_ENTITY_INFO,true) -- 更新buff后需要更新entity的属性视图
    end
    buff.id = nil
end

function EntityClient:changeClientBuffTime(buff, time)
	buff.time = time
    if self.isMainPlayer then
        -- TODO：支持UI刷新buff时间
		--Lib.emitEvent(Event.DRAW_BUFFICON,buff)
    end
end

function EntityClient:removeClientTypeBuff(key, value)
	for id, buff in pairs(self:data("buff")) do
		if buff.cfg[key] == value then
			self:removeClientBuff(buff)
		end
	end
end

-- 同步方式为"other"或"none"的buff，是不会同步到自己客户端的，需要用下面函数在客户端自行添加。
-- 这样做的好处是可以让buff立即生效，无需等待服务器，无延迟。
function EntityClient:tryAddClientOnlyBuff(name, time)
	if not name or not self.isMainPlayer then
		return nil
	end
	local cfg = Entity.BuffCfg(name)
	local sync = cfg.sync or "all"
	if sync ~= "other" and sync ~= "none" then
		return nil
	end
    local buff
	--local buffBeginTime, buffEndTime
	if time then
		--buffBeginTime = World.Now()
		--buffEndTime = buffBeginTime + time
		self:timer(time, function()
			if buff.id then
				self:removeClientBuff(buff)
			end
		end)
	end
	buff = self:addClientBuff(name, nil, time)
	return buff
end

function EntityClient:updateHoldARGBStrength(item)
	self:setHoldModelARGBStrength(Lib.getItemEnchantColor(item))
end

function EntityClient:changeActor(actorName, clearSkin)
	assert(actorName, "need actor name")
	if not self:doChangeActor(actorName, clearSkin) then
		return
	end
	local effectHandler = Entity.EntityProp.effect
	for id, buff in pairs(self:data("buff")) do
		local cfg = buff.cfg
		local effect = cfg.effect
		if effect and not effect.once then
			effectHandler(self, effect, true, buff)
		end
	end
end

function EntityClient:saveHandItem(item)
	local old = self:data("main").handItem
	self:data("main").handItem = item
	self:updateHoldModel(item and item:model())
	self:updateHoldARGBStrength(item)
	local handItemBoneName = item and item:cfg().handItemBoneName or "s_hand_r"
	local firstPRVHandItemBoneName = item and item:cfg().firstPRVHandItemBoneName or ""
	self:setHandItemBoneName(handItemBoneName)
	self:setFirstPRVHandItemBoneName(firstPRVHandItemBoneName)

	if self:isControl() and old ~= item then
		Lib.emitEvent(Event.EVENT_HAND_ITEM_CHANGE, item)
		self:EmitEvent("OnHandItemChanged", item)
	end
end

function EntityClient:getHandItem()
	local item = self:data("main").handItem
	if item and item:null() then
		item = nil
	end

	return item
end

function EntityClient:moveStatusChange(newState, oldState)
	self:handleMoveStateSwitchBuffs(oldState, newState, function(self, fullName)
		local buffCfg = Entity.BuffCfg(fullName)
		if not buffCfg.buffTime then
			return self:addClientBuff(fullName)
		end
		--local tickCount = self.world:getTickCount()
		self:addClientBuff(fullName, nil, buffCfg.buffTime)
		return nil
	end, self.removeClientBuff)
end

function EntityClient:destroy()
	Lib.emitEvent(Event.EVENT_ENTITY_REMOVED, self.objID)
	Event:EmitEvent("OnEntityRemoved", self)
	local data = self:data("fishing")
    if data.hookID then
        local hook = World.CurWorld:getObject(data.hookID)
        if hook then
            hook:destroy()
        end
        data.hookID = nil
	end
	Blockman.instance:resetMouseOverInfo(self.objID)
	self:destroyBlockStop()
	self:clearRide()
	Object.destroy(self)
end

function EntityClient:showTargetInfo(targetInfo)
	Lib.emitEvent(Event.EVENT_SHOW_TARGET_INFO, targetInfo)
end

function EntityClient:SetEntityToBlock(data)
	self:fillBlock(data.xSize, data.ySize, data.zSize, data.blockId)
end

function EntityClient:setEntityActorFlashEffect(add)
	local func = self.EntityProp.actorFlashEffect
	if not func then
		return
	end
	func(self, nil, add, nil)
end

function EntityClient:changePassenger(idx, objID)
	local passengers = self:data("passengers")
	passengers[idx] = objID
	local passengersVar = {}
	for index, objId in pairs(passengers) do
		if objId ~= nil then
			table.insert(passengersVar, Bitwise64.Or(Bitwise64.Sl(index - 1, 32), objId))
		end
	end
	self:setData("passengers", passengers)
	self:setPassenger(passengersVar)
	self:changeActions()
end

function EntityClient:changeActions()
	local actions = {}
	local ignoreCheckSelfBaseActions = {}
	local passengers = self:data("passengers")
	local selfCfg = self:cfg()

	for index, _ in pairs(passengers) do
		local pos = selfCfg.ridePos[index]
		if pos.rideAction then
			actions = pos.rideAction
		end
	end

	if self.rideOnId > 0 and self.rideOnIdx >= 0 then
		local target = self.world:getEntity(self.rideOnId)
		if target then
			local pos = target:cfg().ridePos[self.rideOnIdx + 1]
			if pos.passengerAction then
				actions = pos.passengerAction
			end
		end
	end
	if selfCfg.ignoreCheckSelfBaseActions then
		ignoreCheckSelfBaseActions = selfCfg.ignoreCheckSelfBaseActions
	end

	self:setActions(actions)
	self:setIgnoreCheckSelfBaseActions(ignoreCheckSelfBaseActions)
end

function EntityClient:onCfgChanged()
	Object.onCfgChanged(self)
	--for master, slave in pairs(self:data("skins")) do
	--	self:updateAttachModel(master, slave)
	--end
	self:updateShowName()
	self:setProp("hideHp", self._cfg.hideHp or 1)
	self:setProp("textHeight", self._cfg.textHeight or 2.3)
	self:setProp("hpFaceCamera", self._cfg.hpFaceCamera or 0)
	setSkin(self, self:data("skins"))
end

function EntityClient:parserBubbleMsg(packet)
	local msg = {packet.textKey, table.unpack(packet.textArgs)}
    self:showHeadMessage(Lang:toText(msg))
end


local function checkCullingCriterion(entity, criterion)
	local mainPlayer = Player.CurPlayer
	local range = criterion.range or 20
	if mainPlayer:distance(entity) > range then
		return true
	end
	local amount = criterion.amount
	if amount and mainPlayer.displayAmount > amount then
		return true
	end
	return false
end

local function togetherCulling(entity, criterion)
	local mainPlayer = Player.CurPlayer
	if not entity or not criterion then
		return
	end
	local teamId = mainPlayer:getValue("teamId")
	local hideActor = entity:getActorHide()
	if criterion.toTeam and teamId ~= 0 and teamId == entity:getValue("teamId") and hideActor then
		entity:setActorHide(false)
		mainPlayer.displayAmount = mainPlayer.displayAmount + 1
		hideActor = false
	end
	if criterion.toPet then
		local allEntity = World.CurWorld:getAllEntity()
		for _, _entity in pairs(allEntity) do
			if _entity:getValue("ownerId") == entity.objID then
				_entity:setActorHide(hideActor)
			end
		end
	end
end

function EntityClient:checkDisposeCulling()
	--处理延迟剔除
	local mainPlayer = Player.CurPlayer
	local criterion = World.cfg.cullingCriterion
	if not criterion then
		return
	end

	local function doCheck()
		local hideActor = self:getActorHide()
		local isCulling = checkCullingCriterion(self, criterion)
		if isCulling and not hideActor then
			self:setActorHide(true)
			mainPlayer.displayAmount = mainPlayer.displayAmount - 1
		end
		if not mainPlayer.excludingDisplay and not isCulling and hideActor then
			self:setActorHide(false)
			mainPlayer.displayAmount = mainPlayer.displayAmount + 1
		end
		togetherCulling(self, criterion)
		mainPlayer.excludingDisplay = mainPlayer.displayAmount >= (criterion.amount or 20)
		return true
	end
	self:timer(60, doCheck)
end

function EntityClient:addYawOrPitch(yaw, pitch, interval)
	yaw = tonumber(yaw) or 0
	pitch = tonumber(pitch) or 0
	interval = tonumber(interval) or 1
	if yaw > 360 then
		yaw = yaw % 360
	end
	if yaw < -360 then
		yaw = yaw % 360 - 360
	end
	if pitch > 180 then
		pitch = 180
	end
	if pitch < -180 then
		pitch = -180
	end

	self:setRotationYaw(self:getRotationYaw() + yaw)
	self:setRotationPitch(self:getRotationPitch() + pitch)
	local pos = Blockman.instance:viewerRenderPos()
	Blockman.instance:changeCameraView(pos, self:getRotationYaw(), self:getRotationPitch(), 4, interval)
end

function EntityClient:showHeadPic(picPath, bg, isClose)
	local noShowHeadUi = self:cfg().noShowHeadUi
	if not (picPath or bg) or isClose or noShowHeadUi then
		SceneUIManager.RemoveEntityHeadUI(self.objID)
		return
	end
	local uiCfg = { name = "edit_headUI", width = 4, height = 4}
	local openParams = {picPath = picPath, bg = bg}
	SceneUIManager.AddEntityHeadUI(self.objID, {uiCfg = uiCfg, openParams = openParams})
end

function EntityClient:setEntityHide(hide)
	self:setActorHide(hide)
	self:setInvisible(hide)
end

function EntityClient:updateMiniMapIcon(iconTag)
	-- 没有小地图，没必要开启minimap,miniMap 有帧方法
	if not World.CurMap then
		return
	end
	local config = World.CurMap.cfg.miniMap
	if not config then
		return
	end

	local iconTag = iconTag or "miniMapIcon"
    if UI:isOpen("minimap") == false then
        UI:getWnd("minimap")
    end
	if self:isValid() and not self.isPlayer then
		local cfg = self:cfg()
		if cfg and cfg[iconTag] then
			Lib.emitEvent(Event.EVENT_MAP_SETICON, self.objID, cfg[iconTag], nil, {x=0,y=0,z=0}, nil, self.objID, true)
		end
	end
end

function EntityClient:turnHead()
	local objectRenderManager = ObjectRenderManager.Instance()
	if not objectRenderManager then
		return
	end

	local entityRender = objectRenderManager:getEntityRender()
	if not entityRender then
		return
	end

	entityRender:turnHead(self)

	Lib.logDebug("EntityClient turnHead")
end

function EntityClient:resetHead()
	local objectRenderManager = ObjectRenderManager.Instance()
	if not objectRenderManager then
		return
	end

	local entityRender = objectRenderManager:getEntityRender()
	if not entityRender then
		return
	end

	entityRender:resetHead(self)
end

function EntityClient:setEntityMode(mode, targetId)
	self:setMode(mode)
	self:setTargetId(targetId)
	if self.isMainPlayer then
		local target = World.CurWorld:getEntity(targetId)
		if mode == self:getObserverMode() and target then
			Blockman.instance:setViewEntity(target)
			Blockman.instance:control().enable = false
		elseif self:isWatch() then
			Blockman.instance:setViewEntity(Player.CurPlayer)
			Blockman.instance:control().enable = true
			if mode == self:getFreedomMode() then

			end
		end
		PlayerControl.UpdatePersonView()
		Lib.emitEvent(Event.EVENT_UPDATE_UI_DATA, "followInterface", mode)
	end
end

local SPHERE_MASK = Object:getTypeMask({"EntityClientMainPlayer"})

function EntityClient:createInteractionSphere()
	local interaction = self:cfg().interaction
	if not interaction then
		return
	end
	local radius, offset = interaction.radius, interaction.offset
	local range = math.floor(radius / 1)
	if range <= 0 then
		return
	end

	assert(not self.interactionRange)
	self.interactionRange = 9999	-- modify by liyuan (aura的range和interactionRange相同时，移除aura的Buff会把interaction创建的ObjectSphere一起移除)

	self:createObjectSphere(9999, range, math.min(range * 1.2, range + 1.5),SPHERE_MASK, offset or {x = 0, y = 0, z = 0})
end

function EntityClient:removeInteractionSphere()
	local range = self.interactionRange
	if not range then
		return
	end

	self.interactionRange = nil
	Me:onInInteractionRangesChanged(self.objID, false)
end

function EntityClient:setProp(key, value, sync)
	if not sync then
		self:doSetProp(key, value)
		return
	end

	local packet = {
		pid = "SetProp",
		key = key,
		value = value,
		isBigInteger = type(value) == "table" and value.IsBigInteger,
		objID = self.objID,
	}
    self:sendPacket(packet)
end

function EntityClient:onDead()
    local cfg = self:cfg()
    self:setForceMove()
    self:setDead(true)
    if cfg.deadSound then
        local time = math.min(cfg.deadSound.delayTime or 1, 20)
        World.Timer(time, function()
			if self and self:isValid() then
				self:playSound(cfg.deadSound, nil, cfg.deadSound.noFollow)
			else
			    Me:playSound(cfg.deadSound, nil, cfg.deadSound.noFollow)
            end
            return false
        end)
    end
	local brithActionTimer = self:data("main").brithActionTimer
	if brithActionTimer then
		brithActionTimer()
	end
    local deathEffect = cfg.deathEffect
	local entityPos = self:getPosition()
    if deathEffect then
        local time = math.min(deathEffect.delayTime or 1, 20)
        local targetPos = Lib.v3add(entityPos, deathEffect.pos or {x = 0, y = 0, z = 0})
        local effectPathName = ResLoader:filePathJoint(cfg, deathEffect.effect)
        local mainUI = UI:getWnd("appMainRole")
        mainUI.deathEffectTimer = World.Timer(time, function()
            local time = tonumber(deathEffect.time)
            time = time and time / 20 * 1000 or -1
            Blockman.instance:playEffectByPos(effectPathName, targetPos, 0, time)
        end)
        mainUI.deleteDeathEffect = function ()
            Blockman.instance:delEffect(effectPathName, targetPos)
        end
	end
	local randomPlayDeadActions = cfg.randomPlayDeadActions
	if randomPlayDeadActions then
		local deadAction = type(randomPlayDeadActions) == "string" and randomPlayDeadActions or randomPlayDeadActions[math.random(#randomPlayDeadActions)]
		local playDeadInfo = {}
		self:data("main").playDeadInfo = playDeadInfo
		playDeadInfo.oldCanTurnHeadProp = self:prop().canTurnHeadProp
		-- playDeadInfo.oldAction = self:getBaseAction()
		self:setBaseAction(deadAction)

		if self.isMainPlayer then
			local bm = Blockman.instance
			playDeadInfo.oldView = bm:getPersonView()
			playDeadInfo.oldIsLockBodyRotation = bm.gameSettings:isLockBodyRotation()
			-- playDeadInfo.oldIsLockSlideScreen = bm.gameSettings:isLockSlideScreen()

			bm:setPersonView(1) -- 0 first view, 1 thrid view
			bm.gameSettings:setLockBodyRotation(false)
			-- bm.gameSettings:setLockSlideScreen(true)
		end
		self:doSetProp("canTurnHeadProp", 0)
	end
end

function EntityClient:setProps(props)
	for prop, value in pairs(props or {}) do
		if type(value) == "table" and value.IsBigInteger then
			value = BigInteger.Recover(value)
		end
		self:setProp(prop, value)
	end
end

function EntityClient:changeCameraView(pos, yaw, pitch, distance, smooth)
	local bm = Blockman.instance
	pos = pos or bm:getViewerPos()
	yaw = yaw or bm:viewerRenderYaw()
	pitch = pitch or bm:viewerRenderPitch()
	distance = distance or bm:viewerRenderDistance()
	smooth = smooth or 1
	bm:changeCameraView(pos, yaw, pitch, distance, smooth or 1)
end

function EntityClient:getRenderPosFront(dis, isFoot, bCenter)
	dis = dis or 1
	local yaw = math.rad(self:getRotationYaw())
	local pos = isFoot and self:getRenderPosition() or self:getRenderEyePos()
	pos.x = pos.x - dis * math.sin(yaw)
	pos.z = pos.z + dis * math.cos(yaw)
	if bCenter then
		pos.x = math.floor(pos.x) + 0.5
		pos.z = math.floor(pos.z) + 0.5
	end
	return Lib.tov3(pos)
end

RETURN()
