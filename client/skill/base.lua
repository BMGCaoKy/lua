---@type SkillBase
local SkillBase = Skill.GetType("Base")
local CGInterface = CGame.instance:getShellInterface()

SkillBase.startAction = "attack2"
SkillBase.sustainAction = "aim2"
SkillBase.castAction = "attack2"
SkillBase.castActionTime = -1 --自动时间
SkillBase.isResetBaseAction = true
SkillBase.cycleTimer = {}
SkillBase.castEffectName = {}


local consume = {}

local function doConsume(from, consumeItem, check)
	local ret = true
	if type(consumeItem) == "table" then
		for _,i in pairs(consumeItem) do
			ret = consume:consumeItem(from, i)
			if not ret then
				return false
			end
		end
	else
		ret = consume:consumeItem(from, consumeItem)
	end
	return ret
end

local function playAction(from, action, time, isResetBaseAction)
    if not from or not from:isValid() then
        return
    end
	if from:data("reload").reloadTimer and action ~= "idle" and action ~= "" then
		return
	end
	if from.isEntity and action and action~="" then
		from:updateUpperAction(action, time, isResetBaseAction)
        --Lib.logDebug("playAction updateUpperAction", action)
	end
end

local function playEffect(from, cfg, effect)
    if not from or not from:isValid() then
        return
    end
	if effect and from.isEntity then
		local isEffectArr = false
		if not cfg.castEffectName[from.objID] then
			cfg.castEffectName[from.objID] = {}
		end

		for _, eff in ipairs(effect) do
			local name = from:showEffect(eff, cfg)
			table.insert(cfg.castEffectName[from.objID],name)
			isEffectArr = true
		end
		if not isEffectArr then
			local name = from:showEffect(effect, cfg)
			table.insert(cfg.castEffectName[from.objID],name)
		end
	end
end

local function stopPlayEffect(from, cfg, effect)
	if not cfg.castEffectName[from.objID] then
			return
	end
	for k,name in ipairs(cfg.castEffectName[from.objID]) do
		from:delEffect(name)
	end

	cfg.castEffectName[from.objID] = {}
end


local function playSound(from, self, cfg, sound)
    if not from or not from:isValid() then
        return
    end
	if sound then
		from:data("soundId")[self.fullName] = from:playSound(sound, cfg)
	end
end

local function stopSound(from, self)
	if from then
		local soundId = from:data("soundId")[self.fullName]
		if soundId then
			from:stopSound(soundId)
		end
	end
end

local function playFirstViewUIEffect(from, value, add)
    if not from or not from:isValid() then
        return
    end
    if from.isMainPlayer and value then
        Lib.emitEvent(Event.PLAYE_UI_EFFECT, value, add, value.time or 20)
    end
end

local function vibratorOnTime(from, vibratorTime)
    if not from or not from:isValid() then
        return
    end
	if not vibratorTime or type(vibratorTime) ~= "number" then
        return
    end
    CGInterface:vibratorOnTime(vibratorTime)
end

function SkillBase:getSoundCfg(packet,soundName,from)
	return self, self[soundName]
end

function SkillBase:start(packet, from)
	playAction(from, self.startAction, packet.touchActionTime or packet.touchTime)
	playEffect(from, self, self.startEffect)
    playSound(from, self, self:getSoundCfg(packet,"startSound",from))
    vibratorOnTime(from, self.startVibratorTime)
    playFirstViewUIEffect(from, self.startUIEffect, true)
end

function SkillBase:sustain(packet, from)
    local cycleTime = self.cycleSustainActionTime
    if cycleTime and cycleTime > 0 then
        playAction(from, self.sustainAction, cycleTime)
        local cycleTimer = self.cycleTimer[from.objID]
        if cycleTimer then
            cycleTimer()
        end
        cycleTimer = from:timer(cycleTime, function()
            --print("--------skill sustain timer", from.objID, packet.name)
            playAction(from, self.sustainAction, cycleTime)
            return true
        end)
        self.cycleTimer[from.objID] = cycleTimer
    else
		playAction(from, self.sustainAction, 10000) --todo 无持续播同一动作
    end
	playEffect(from, self, self.sustainEffect)
	playSound(from, self, self:getSoundCfg(packet,"sustainSound",from))
    vibratorOnTime(from, self.sustainVibratorTime)
    playFirstViewUIEffect(from, self.sustainUIEffect, true)
end

function SkillBase:stop(packet, from)
    local cycleTimer = self.cycleTimer[from.objID]
    if cycleTimer then
        cycleTimer()
        self.cycleTimer[from.objID] = nil
    end
	playAction(from, self.stopAction or "idle", 0)
	playEffect(from, self, self.stopEffect)
    playSound(from, self, self:getSoundCfg(packet,"stopSound",from))
	stopSound(from, self)
    vibratorOnTime(from, self.stopVibratorTime)
    playFirstViewUIEffect(from, self.preCastUIEffect, false)
    playFirstViewUIEffect(from, self.startUIEffect, false)
    playFirstViewUIEffect(from, self.sustainUIEffect, false)
    playFirstViewUIEffect(from, self.stopUIEffect, false)
end


--前摇
function SkillBase:preSwing(packet, from)
	print("SkillBase:preSwing " .. self.fullName)
	if from and from.isPlayer and from:isWatch() then
		return
	end

	self:preCast(packet, from)

	if self.preSwingTime <= 0 then
		print("SkillBase:preSwing " .. "not need preSwing")
		--if self:canCast(packet, from) then
			Lib.logDebug("Skill.Cast direct skill " .. self.fullName)
			print("Skill.Cast direct" .. self.fullName)
			self:setStartPos(packet,from)
			Skill.DoCast(self, packet, from)
		--end
		return
	end

	--都需要记前后摇数据，之前对释放技能的打断理解有误
	--if self.enableMoveBrkPreS then
		Skill.RecordSwingData(from,self,true)
	--end
	Skill.RecordIgnoreSwingData(from,self,true)

	Player.CurPlayer:sendPacket({
				pid = "StartPreSwing",
				name = self.fullName,
				fromID = from and from.objID
			})

	self.stopPreSwingFun = World.Timer(self.preSwingTime, function()
				Lib.logDebug("Skill.Cast " .. self.fullName)
				Skill.ClearSwingData(from,self)
				Skill.ClearIgnoreSwingData(from,self)
				self:setStartPos(packet,from)
				Skill.DoCast(self, packet, from)
				self.stopPreSwingFun = nil
		end)
end


function  SkillBase:stopPreSwing(from)
	print("SkillBase:stopPreSwing " .. self.fullName)
	if self.preSwingTime <= 0 then
		print("SkillBase:stopPreSwing " .. "not need stopPreSwing")
		return
	end

	if from:isControl() then
		print("SkillBase:stopPreSwing clear data")
		Skill.ClearIgnoreSwingData(from,self)
		Skill.ClearSwingData(from,self)
		Player.CurPlayer:sendPacket({
				pid = "StopPreSwing",
				name = self.fullName,
				fromID = from and from.objID
			})
		if self.stopPreSwingFun then
			self.stopPreSwingFun()
			self.stopPreSwingFun = nil
		end
	end
	--删除还有技能的动画特效音效行为
	print("SkillBase:stopPreSwing stop action")
	playAction(from,"idle",0,true)
	stopPlayEffect(from,self,self.castEffect)
	stopSound(from, self)

end


--后摇
function SkillBase:backSwing(packet, from)
	print("SkillBase:backSwing " .. self.fullName)
	
	--都需要记前后摇数据，之前对释放技能的打断理解有误
	--if self.enableMoveBrkBackS then
		Skill.RecordSwingData(from,self,false)
	--end
	Skill.RecordIgnoreSwingData(from,self,false)
	if self.backSwingTime > 0 then
		--处理后摇逻辑
		self.stopBackSwingFun = World.Timer(self.backSwingTime , function()
			--todo 
			Skill.ClearIgnoreSwingData(from,self)
			Skill.ClearSwingData(from,self)
			--backswing之后，技能就结束了，所以要把动画，特效，音效都结束
			playAction(from,"idle",0,true)
			stopPlayEffect(from,self,self.castEffect)
			stopSound(from, self)
			self.stopBackSwingFun = nil
			end)
		else
			--没有后摇的话，就清理数据，自然结束动作，音效特效
			Skill.ClearIgnoreSwingData(from,self)
			Skill.ClearSwingData(from,self)
		end
end

function  SkillBase:stopBackSwing(from)
	print("SkillBase:stopBackSwing " .. self.fullName)
	if self.backSwingTime <= 0 then
		print("SkillBase:stopBackSwing " .. "not need stopBackSwing")
		return
	end

	if from:isControl() then
		print("SkillBase:stopBackSwing clear data")
		Skill.ClearIgnoreSwingData(from,self)
		Skill.ClearSwingData(from,self)
		Player.CurPlayer:sendPacket({
				pid = "StopBackSwing",
				name = self.fullName,
				fromID = from and from.objID
			})
		if self.stopBackSwingFun then
			self.stopBackSwingFun()
			self.stopBackSwingFun = nil
		end
	end
	--删除还有技能的动画特效音效行为
	print("SkillBase:stopBackSwing stop action effect sound")
	playAction(from,"idle",0,true)
	stopPlayEffect(from,self,self.castEffect)
	stopSound(from, self)
end

--单独把某个获取开始位置的函数从cancast中拿出来
function SkillBase:setStartPos(packet, from)
end

-- 技能起手动作
function SkillBase:preCast(packet, from)
	if self.cdTime and from then
		from:setCD("net_delay", self.netDelay or 20)
	end
	playAction(from, self.castAction, self.castActionTime, self.isResetBaseAction)
	playEffect(from, self, self.castEffect)
    playSound(from, self, self:getSoundCfg(packet,"castSound",from))
    vibratorOnTime(from, self.castVibratorTime)
    playFirstViewUIEffect(from, self.preCastUIEffect, true)
end

local function castCameraZoom(skill, from)
    local cameraZoom = skill.cameraZoom
    if not from:isControl() or not cameraZoom then
        return
    end
    local scale = skill.cameraZoom.scale or 0.002
    local fov = Blockman.instance.gameSettings:getFovSetting()
    Blockman.instance.gameSettings:setFovSetting(fov - scale )
    World.Timer(cameraZoom.recoverTime or 2, function()
        Blockman.instance.gameSettings:setFovSetting(fov + scale)
    end)
end

local function castRecoil(skill, from)
    if not from:isControl() or not skill.recoil then
        return
    end
    local isTable = type(skill.recoil) == "table"
    local recoilValue = isTable and skill.recoil.recoil or skill.recoil
    if UI:isOpen("snipe") and UI:getWnd("snipe"):isSnipeOpen() and isTable and skill.recoil.recoilInSnipe then
        recoilValue = skill.recoil.recoilInSnipe
    end
    if recoilValue <= 0 then
        return
    end
    local oldPitch = from:getRotationPitch()
    if oldPitch <= -90 then
        return
    end
    local newPitch = oldPitch - recoilValue
    if newPitch < -90 then
        newPitch = -90
    end
    from:changeCameraView(nil, nil, newPitch, nil, 1)

    local autoRecoverRecoil = skill.autoRecoverRecoil or {}
    local recoverValue = isTable and skill.recoil.autoRecoverRecoil or autoRecoverRecoil.value or 0
    local recoverTime = isTable and skill.recoil.recoverInterval or autoRecoverRecoil.time or 2
    local time = recoverTime >= 2 and recoverTime or 2
    if recoverValue <= 0 then
        return
    end
    local offSet = newPitch - oldPitch
    local data = from:data("recoverRecoil")
    if data.timer then
        data.timer()
        data.timer = nil
    end
    if not data.recoil then
        data.recoil = 0
    end
    data.recoil = data.recoil + (-offSet)
    data.timer = World.Timer(time, function()
        local oldPitch = from:getRotationPitch()
        if oldPitch >= 90 then
            data.recoil = 0
            return false
        end
        if data.recoil <= 0 then
            return false
        end
        if data.recoil >= recoverValue then
            from:changeCameraView(nil, nil, oldPitch + recoverValue, nil, 1)
            data.recoil = data.recoil - recoverValue
            return true
        else
            from:changeCameraView(nil, nil, oldPitch + data.recoil, nil, 1)
            data.recoil = 0
            return false
        end
    end)
end

local function castVibrator(self, from, target)
    local castVibratorVariable = self.castVibratorVariable
    if not castVibratorVariable or type(castVibratorVariable) ~= "table" then
        return
    end
    if castVibratorVariable.targetVariableTime and target:isControl() then
        vibratorOnTime(target, castVibratorVariable.targetVariableTime)
    end

    if castVibratorVariable.fromVariableTime and from:isControl() then
        vibratorOnTime(from, castVibratorVariable.fromVariableTime)
    end
end

function SkillBase:extCast(packet, from)--扩充技能释放
    castRecoil(self, from)
    castCameraZoom(self, from)
    castVibrator(self, from, packet.targetID and World.CurWorld:getEntity(packet.targetID))
end

-- 单机模式下，直接释放技能
function SkillBase:singleCast(packet, from)
	self:cast(packet, from)
end

-- 技能图标的显示/隐藏
function SkillBase:showIcon(show, index)
	Lib.emitEvent(Event.EVENT_SHOW_SKILL, self, show, index)
end

function SkillBase:getIcon()
	if type(self.icon)~="string" then
		return nil
	end
	if not self.iconPath then
		self.iconPath = ResLoader:loadImage(self, self.icon)
	end
	return self.iconPath
end

function SkillBase:extCheckConsume(packet, from)
	local consumeItem = self.consumeItem
	if consumeItem then
		local ret = doConsume(from, consumeItem, true)
		if not ret then
			return false
		end
	end

	return true
end

function SkillBase:takeContainer(packet, from)
	if not Blockman.instance.singleGame then
		return
	end
	local container = self.container
	local currentCapacity = self:getContainerVar(from, true)
	if not currentCapacity then
		return
	end
	currentCapacity = currentCapacity - (container.takeNum or 1)
	self:setCurrentCapacity(from, packet.currentCapacity or currentCapacity)
end

function consume:consumeItem(from, consumeItem)
	local ifTable = type(consumeItem) == "table"
	local consumeName = ifTable and consumeItem.consumeName or consumeItem
	local consumeBlock = ifTable and consumeItem.consumeBlock
	local count = ifTable and consumeItem.count or 1
	local cash = from:tray():find_item_count(consumeName, consumeBlock)
	if cash < (count or 1) then
		return false
	end
	return true
end

