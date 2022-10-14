local setting = require "common.setting"

local CfgMod = setting:mod("skill")

-- 不同类型技能的定义（技能config的metatable、基类）
local SkillType = L("SkillType", {})

---@class SkillBase
local SkillBase = SkillType.Base
if not SkillBase then	-- 此对象会被client/server的定义覆盖，这里不可以热更新
	SkillBase = {}
	SkillBase.__index = SkillBase
	SkillType.Base = SkillBase

	--技能前后摇的一些默认设置,server,client都可以用
	--方便兼容以前的技能
	--SkillBase.enablePreSwing = false
	SkillBase.preSwingTime = 0  --单位为帧
	SkillBase.backSwingTime = 0 --单位为帧
	--SkillBase.enableBackSwing = false
	SkillBase.stopPreSwingFun = nil		--前摇结束执行的函数
	SkillBase.stopBackSwingFun = nil	--后摇结束执行的函数
	

	--前后摇对移动逻辑的影响和打断机制字段
	SkillBase.ignoreCastSkillPreS = false		--如果为true前摇是忽略技能释放,否则技能自由释放(但要打断当前的前摇)
	SkillBase.ignoreMovePreS = false			--如果为true前摇时忽略移动，否则可以自由移动
	SkillBase.ignoreJumpPreS = false			--如果为true前摇时忽略跳跃,否则可以自由跳跃
	SkillBase.enableMoveBrkPreS  = false		--如果为true前摇时任意移动可以打断，能不能移动之类参考上面的几个字段，若被忽略移动，则主动移动不能执行，所以也不会被打断，被动移动不受影响

	SkillBase.ignoreCastSkillBackS = false		--如果为true后摇是忽略技能释放,否则技能自由释放（但要打断当前的后摇）
	SkillBase.ignoreMoveBackS = false			--如果为true后摇时忽略移动，否则可以自由移动
	SkillBase.ignoreJumpBackS = false			--如果为true后摇时忽略跳跃,否则可以自由跳跃
	SkillBase.enableMoveBrkBackS  = false		--如果为true前摇时任意移动可以打断，能不能移动之类参考上面的几个字段，若被忽略移动，则主动移动不能执行，所以也不会被打断，被动移动不受影响



	-- 技能函数常见的参数为：
	--	(self)	一个技能配置（config）
	--	packet	一个技能协议包（一次技能释放的数据，包含技能目标等）
	--	from	技能释放者，可选
	--	...		其它
	function SkillBase:canCast(packet, from)	-- C/S通用的基本释放条件检查
		if from and from.isPlayer and from:isWatch() then
			return false
		end
		if from.curHp<=0 and not self.canCastOnDying then
			return false
		end
		if from:prop().disableSkillsStatus ~= 0 then
			if not self.isDecontrolSkill then
				return false
			end
		end
		return self:checkConsume(packet, from)
	end
	function SkillBase:getVpConsume()
		return self.consumeVp or 0
	end
	function SkillBase:checkConsume(packet, from) -- 检查技能消耗
        if self.cdTime and from:checkCD(self.cdKey,packet.ignoreNetDelay) then
            return false
        end
        if from.curVp < self:getVpConsume() then
            return false
        end
		if not self:extCheckConsume(packet, from) then
			return false
		end
		if self.container and not self:checkContainer(packet, from) then
			return false
		end
		return true
	end
	function SkillBase:checkContainer(packet, from)	-- 检查容器消耗
		local container = self.container
		if not next(container) then
			return true
		end
		local currentCapacity = self:getContainerVar(from, true)
		if not currentCapacity then
			return false
		end
		if from:data("reload").reloadTimer then
			return false
		end
		if (container.takeNum or 1) <= currentCapacity then
			return true
		end
		if from:isControl() then
			local autoReloadSkill = container.autoReloadSkill
			if not autoReloadSkill or ((autoReloadSkill ~= self.fullName) and not Skill.Cfg(autoReloadSkill):canCast(packet, from)) then
				if self.emptyClipSkill then
					Skill.Cast(self.emptyClipSkill, packet, from)
				end
			else
				Skill.DoCast(Skill.Cfg(container.autoReloadSkill), packet, from)
			end
		end
		return false
	end
    function SkillBase:extCheckConsume(packet, from) --扩充检查技能消耗,(clint/server 定义不同)
        return true
    end
	function SkillBase:doConsume(packet, from)	-- 执行技能消耗
        if self.cdKey then
            from:setCD(self.cdKey, packet.cdTime or self.cdTime, self)
        end
        if self.container then
            self:takeContainer(packet, from)
			local currentCapacity = self:getContainerVar(from, true)
			if not currentCapacity then
				return
			end
			--子弹用完，自动换弹夹
			if (self.container.takeNum or 1) > currentCapacity then
				if from:isControl() and self.container.autoReloadSkill then
					Skill.Cast(self.container.autoReloadSkill, packet, from)
				end
			end
        end
        self:extDoConsume(packet, from)
	end
    function SkillBase:extDoConsume(packet, from)   -- 扩充技能消耗,(clint/server 定义不同技能消耗方式)
    end
	function SkillBase:takeContainer(packet, from)	-- 消耗容器容量
	end
	function SkillBase:touchChange(packet, from)  -- 技能变化效果（仅touch技能有效）
	end
	function SkillBase:reTouchChange(packet, from)  -- 恢复技能变化效果（仅touch技能有效）
	end
	function SkillBase:extCast(packet, from)--扩充技能释放
	end
	function SkillBase:cast(packet, from)		-- 直接释放技能效果
		self:extCast(packet, from)
		if from and not packet.autoCast then
			self:doConsume(packet, from)
		end
	end
	function SkillBase:start(packet, from)		-- 开始技能动作（仅touch技能有效）
	end
	function SkillBase:sustain(packet, from)    -- 持续技能动作 (仅touch技能有效)
	end
	function SkillBase:stop(packet, from)		-- 中断技能动作（仅touch技能有效）
	end
	function SkillBase:getTouchTime(packet, from)	-- 获取touch时间（仅touch技能有效）
		if not self.isTouch then
			return nil
		end
		if not self:canCast(packet, from) then
			return nil
		end
		return self.touchTime
	end
	SkillBase.isTouch = false

	local function checkHandItem(self, sloter)
		if sloter then
			for _, skill in pairs(sloter:skill_list()) do
				if skill == self.fullName then
					return true
				end
			end
		end
		return false
	end

    function SkillBase:getContainerVar(from, needCheck)
        local sloter = from:getHandItem()
		local container = sloter and sloter:container()
		if not container or needCheck and not checkHandItem(self, sloter) then
			return
		end
		if not sloter:getValue("currentCapacity") then
			self:setCurrentCapacity(from, container.initCapacity or 0)
		end
		return sloter:getValue("currentCapacity"), container
	end

	function SkillBase:setCurrentCapacity(from, capacity)
		local sloter = from:getHandItem()
		if not checkHandItem(self, sloter) then
			return
		end
		sloter:setValue("currentCapacity", capacity)
    end

end

---@return SkillBase
function Skill.Cfg(name, from)
	local cfg = CfgMod:get(name)
	if not cfg then
		Lib.logError(from and string.format("not find skill: %s:%s:%s", name, from.name, from.platformUserId) or name)
	end
	return cfg
end

---@param typ string
function Skill.GetType(typ)
	local st = SkillType[typ]
	if not st then
		st = {}
		st.__index = st
		SkillType[typ] = setmetatable(st, SkillType.Base)
	end
	return st
end


local function init()
	--技能前后摇数据，主要是技能前后摇截止的时间，单位为帧数
	Skill.swingData = {}

	--技能的前后忽略行为数据
	Skill.ignoreSwingData = {}

	local systemSkill = World.cfg.systemSkill or {
		{
			fullName = "/attack",
			type = "MeleeAttack",
			priority = 1000
		}, {
			fullName = "/click",
			type = "Click",
			priority = -1
		}, {
			fullName = "/break",
			type = "BreakBlock",
			priority = 1001
		}, {
			fullName = "/place",
			type = "PlaceBlock",
			priority = 1002
		}, {
			fullName = "/place_test",
			type = "PlaceBlock",
			test = true,
			priority = 1003
		}, {
			fullName = "/build",
			type = "BuildSchematic",
			priority = 1005
		},
		{
			fullName = "/useitem",
			type = "UseItem",
			priority = 1004
		}, {
			fullName = "/empty",
			type = "Base",
			isClick = true,
			castActionTime = -1,
			castAction = "attack2",
			priority = 1007
		}, {
			fullName = "/jump_trigger",
			objTrigger = "ENTITY_JUMP",
			type = "Base",
			isJump = true,
			castAction = "",
			cdTime = 10,
			broadcast = false,
			priority = 1008
		}
	}
	for _, cfg in ipairs(systemSkill) do
		CfgMod:set(cfg)
		--print("############### cfg.fullName " .. cfg.fullName .. " cfg.id " .. cfg.id)
	end
end

function CfgMod:onLoad(cfg, reload)
	if cfg.cdTime then
		if cfg.cdType then
			cfg.cdKey = "type:" .. cfg.cdType
		else
			cfg.cdKey = "skill:" .. cfg.fullName
		end
	end
	setmetatable(cfg, Skill.GetType(cfg.type))
end

init()

RETURN()
