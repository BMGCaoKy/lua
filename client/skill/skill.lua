require "common.skill.skill"
require "skill.base"
require "skill.melee_attack"
require "skill.break_block"
require "skill.place_block"
require "skill.click"
require "skill.use_item"
require "skill.charge"
require "skill.reload"
require "skill.skill_dropItem"
require "skill.skill_missile"
require "skill.skill_float"
require "skill.fishing"
require "skill.buff"
require "skill.skill_ray"
require "skill.multistage"
require "skill.timeLine"
require "skill.skill_shoot"
require "skill.build_schematic"

local curTouchSkill = L("curTouchSkill")

local function getSkill(name)
	local player = Player.CurPlayer
	local cfg = Skill.Cfg(name)
	local from
	local tb = player:data("skill").skillMap and player:data("skill").skillMap[name] or {}
    local objID = tb and tb.objID
	if objID then
		from = World.CurWorld:getEntity(objID)
	else
		from = player
	end
	return cfg, from
end

local function checkTouchSkill(touchSkill, packet)
	local _packet = touchSkill.packet
	local cfg = touchSkill.cfg
	if cfg and cfg.fullName ~= "/break" then
		return true
	end
	if not packet or not packet.blockPos then
		Skill.TouchEnd()
		return true
	end
	if not _packet or not _packet.blockPos then
		return true
	end
	local oldBlockPos = _packet.blockPos
	local newBlockPos = packet.blockPos
	if oldBlockPos.x == newBlockPos.x and oldBlockPos.y == newBlockPos.y and oldBlockPos.z == newBlockPos.z then
		return true
	end
	Skill.TouchEnd()
	return true
end

local function getTouchProp(packet)
	local skillName = packet.name
	local cfg, from, touchTime
	if skillName then
		cfg, from = getSkill(skillName)
		touchTime = cfg:getTouchTime(packet, from)
		if not touchTime or touchTime < 0 then
			return
		end
	else
		local hadTouchSkill = false
		for _, name in ipairs(Player.CurPlayer:data("skill").clickList or {}) do
			cfg, from = getSkill(name)
			touchTime = cfg:getTouchTime(packet, from)
			if ((not packet.touchAtScene) or (not cfg.disableSceneTouch)) and touchTime and touchTime >= 0 then
				skillName = name
				hadTouchSkill = true
				break
			end
		end
		if not hadTouchSkill then
			return
		end
	end
	return cfg, from, touchTime
end

function Skill.TouchBegin(packet)
	if curTouchSkill and checkTouchSkill(curTouchSkill, packet) then
		return
	end
	local cfg, from, touchTime = getTouchProp(packet)
	if not touchTime then
		return
	end
	packet.touchTime = touchTime
    if not cfg:canCast(packet, from) then
        return
    end
	cfg:start(packet, from)
	local timer
	if cfg.touchEndCast then
		timer = World.Timer(touchTime, function()
			Player.CurPlayer:sendPacket({
				pid = "SustainSkill",
				name = cfg.fullName,
				fromID = from and from.objID
			})
			cfg:sustain(packet, from)
			curTouchSkill.sustainOK = true
		end)
	elseif cfg.type ~= "Charge" or cfg.releaseType == "Auto" then
		timer = World.Timer(touchTime, Skill.TouchOk)
	end
	curTouchSkill = {
		cfg = cfg,
		from = from,
		packet = packet,
		timer = timer
	}
	packet.pid = "StartSkill"
	packet.name = cfg.fullName
	packet.fromID = from and from.objID
	Player.CurPlayer:sendPacket(packet)
end

local function stop_timer()
	if not curTouchSkill then
		return
	end
	local tmp = curTouchSkill
	curTouchSkill = nil
	if tmp.timer then
		tmp.timer()
	end
	return tmp.cfg, tmp.from, tmp.packet, tmp.sustainOK
end

function Skill.CheckNeedTouchEnd(itemName)
	if curTouchSkill then
		local packet = curTouchSkill.packet
		if packet.itemName and packet.itemName ~= itemName then
			Skill.TouchEnd()
		end
	end
end

function Skill.TouchEnd()
	print("Skill.TouchEnd")
	local cfg, from, packet, sustainOK = stop_timer()
	if not cfg then
		return
	end
	if cfg.touchEndCast and sustainOK then
		curTouchSkill = {cfg = cfg, from = from, packet = packet} -- reset curTouchSkill 2 touch ok use
		Skill.TouchOk()
		return
	end
	cfg:stop(packet, from)
	packet.pid = "StopSkill"
	packet.name = cfg.fullName
	packet.fromID = from and from.objID
	Player.CurPlayer:sendPacket(packet)
end

function Skill.touchStop(name,from)
	local cfg = Skill.Cfg(name)
	if cfg then
		local packet = {isTouchStop = true}
		cfg:stop(packet, from)
		packet.pid = "StopSkill"
		packet.name = cfg.fullName
		packet.fromID = from and from.objID 
		Player.CurPlayer:sendPacket(packet)
	end
end

--[[  检查技能名是否符合要求 ]]-- start --
local filStr = { '-', '_', '/' }
local function filter(str, pos)
    for _, s in pairs(filStr) do
        if string.find(string.sub(str, 1, pos), s, pos, true) then
            return true
        end
    end
    return false
end

local function checkStr(str, pos)
	--local ret, _pos = string.find(str, '[^%w]', pos or 1)
	--暂时先尝试放开英文限制
	local ret, _pos = string.find(str, '[\\/]', pos or 1)
	if ret then
		if filter(str, _pos) then
			return checkStr(str, _pos + 1)
		else
			return false
		end
	end
	return true
end
local misc = require "misc"
-- end --

---@param cfg SkillBase
function Skill.DoCast(cfg, packet, from)
	print("Skill.DoCast")
	--[[
	if from and from.isPlayer and from:isWatch() then
		return
	end
	if cfg.debug then
		print("client Skill.DoCast -", from.name, cfg.fullName)
	end
	cfg:preCast(packet, from)
	--]]

	if Blockman.instance.singleGame then
		cfg:singleCast(packet, from)
	elseif packet.onlySelf then
		packet.name = cfg.fullName
		packet.fromID = from and from.objID
		Skill.CastByServer(packet)
	else
		print("Skill.DoCast send CastSkill packet")
		packet.pid = "CastSkill"
		packet.name = cfg.fullName
		packet.fromID = from and from.objID
		--检查输出 start
		assert(packet.name, "skill name is null")
		assert(cfg.fullName, "skill fullName is null")
		assert(packet.name == cfg.fullName, string.format("%s:%s", packet.name, cfg.fullName))
		assert(Skill.Cfg(packet.name) == cfg, "cfg !=")
		assert(checkStr(packet.name), string.format("Incorrect characters exist: %s", packet.name))
		local data = Player.CurPlayer:sendPacket(packet)
		local ok , _packet = pcall(misc.data_decode, data)
		if not ok then
			perror("handle_packets error!", self.name, _packet, #data, data:byte(1, 200))
		end
		-- assert(_packet.name == cfg.fullName, string.format("%s:%s", _packet.name, cfg.fullName))
	end
    if cfg.diffuseVal and cfg.diffuseVal>0 then
        FrontSight.Diffuse(cfg.diffuseVal, 1)
	end
end

function Skill.TouchOk()
	print("Skill.TouchOk")
	local cfg, from, packet = stop_timer()
	if not cfg then
		return
	end
    cfg:stop(packet, from)
	packet.isTouch = true
	--Skill.DoCast(cfg, packet, from)
	if Skill.CanIgnoreBySwing(from,"CastSkill") then
		print("Ignore skill by swing,skill ")
		return
	end
	Skill.DoBreakSwing(from,"CastSkill")
	cfg:preSwing(packet, from)
end

function Skill.ClickCast(packet)
	local player = Player.CurPlayer
	for _, name in ipairs(player:data("skill").clickList or {}) do
		local cfg, from = getSkill(name)
		--if cfg.isClick and cfg:canCast(packet, from) then
		--	Skill.DoCast(cfg, packet, from)
		if Skill.CanIgnoreBySwing(from,"CastSkill") then
			print("Ignore skill by swing,skill name: " .. name)
			return
		end
		Skill.DoBreakSwing(from,"CastSkill")
		if cfg.isClick and cfg:canCast(packet, from) then
			cfg:preSwing(packet, from)
			Lib.logDebug("Skill.ClickCast", name)
			print("Skill.ClickCast", name)
			break
		end
	end
end

--添加entity参数，兼容不是角色的技能释放情况（可能是宠物）
function Skill.Cast(skillName,packet,entity)
	print("Skill.Cast : " .. skillName) 
	local cfg, from = getSkill(skillName)
	from = entity or from
	
	packet = packet or {}
	if Skill.CanIgnoreBySwing(from,"CastSkill") then
		print("Ignore skill by swing,skill name: " .. skillName)
		return false
	end
	Skill.DoBreakSwing(from,"CastSkill")
	--if cfg:canCast(packet, from) then
	--	print("Skill.Cast cancast: " .. skillName) 
	--	cfg:preSwing(packet, from)
		--Skill.DoCast(cfg, packet, from)
		--Lib.logDebug("Skill.Cast " .. skillName)
		--print("################## Skill.Cast "  .. skillName)
	--end
	if cfg:canCast(packet,from) then
		cfg:preSwing(packet, from)
	else
		print("Skill.Cast  cfg:canCast false ")
		return false
	end
	return true
end

function Skill.StartByServer(packet)
	local cfg = Skill.Cfg(packet.name)
	local from = World.CurWorld:getEntity(packet.fromID)
	if not from then
		return
	end
	cfg:start(packet, from)
end

function Skill.SustainByServer(packet)
	local cfg = Skill.Cfg(packet.name)
	local from = World.CurWorld:getEntity(packet.fromID)
	if not from then
		return
	end
	cfg:sustain(packet, from)
end

function Skill.StopByServer(packet)
	local cfg = Skill.Cfg(packet.name)
	local from = World.CurWorld:getEntity(packet.fromID)
	if not from then
		return
	end
	cfg:stop(packet, from)
end

function Skill.CastByServer(packet)
	---@type SkillBase
	local cfg = Skill.Cfg(packet.name)
	local from = World.CurWorld:getEntity(packet.fromID)
	if not from then
		return
	end
	--兼容没有前摇的情况
	if packet.isCastBySever then
		if packet.needPre then 
			cfg:preCast(packet,from)
		end
	else 
		if not (from and from:isControl()) then 
			cfg:preCast(packet,from)
		end
	end
	if packet.castByAI and packet.preSwingTime then
		World.Timer(packet.preSwingTime, function()
			cfg:cast(packet, from)
			cfg:backSwing(packet, from)
		end)
	else 
		cfg:cast(packet, from)
		cfg:backSwing(packet, from)
	end
end

function Skill.StartPreSwingByServer(packet)
	print("Skill.StartPreSwingByServer fromID: " .. packet.fromID)
	local cfg = Skill.Cfg(packet.name)
	local from = World.CurWorld:getEntity(packet.fromID)
	if cfg.preSwingTime > 0 then
		if not (from and from:isControl()) or packet.needPre then
			cfg:preCast(packet, from)
		end
	end
end

function Skill.StopPreSwingByServer(packet)
	print("Skill.StopPreSwingByServer fromID: " .. packet.fromID)
	local cfg = Skill.Cfg(packet.name)
	local from = World.CurWorld:getEntity(packet.fromID)
	cfg:stopPreSwing(from)
end

function Skill.StartBackSwingByServer(packet)
	print("Skill.StartBackSwingByServer fromID: " .. packet.fromID)
	local cfg = Skill.Cfg(packet.name)
	local from = World.CurWorld:getEntity(packet.fromID)
end

function Skill.StopBackSwingByServer(packet)
	print("Skill.StopBackSwingByServer fromID: " .. packet.fromID)
	local cfg = Skill.Cfg(packet.name)
	local from = World.CurWorld:getEntity(packet.fromID)
	cfg:stopBackSwing(from)
end


function Skill.RecordIgnoreSwingData(from,cfg,isPre)
	if not Skill.ignoreSwingData[from.objID] then
		Skill.ignoreSwingData[from.objID] = {}
	end

	local ignoreSwingData = Skill.ignoreSwingData[from.objID]
	if isPre then
		ignoreSwingData.CastSkill = cfg.ignoreCastSkillPreS
		ignoreSwingData.Move = cfg.ignoreMovePreS
		ignoreSwingData.Jump = cfg.ignoreJumpPreS
	else
		ignoreSwingData.CastSkill = cfg.ignoreCastSkillBackS
		ignoreSwingData.Move = cfg.ignoreMoveBackS
		ignoreSwingData.Jump = cfg.ignoreJumpBackS
	end
end


function Skill.ClearIgnoreSwingData(from,cfg)
	if not Skill.ignoreSwingData[from.objID] then
		Skill.ignoreSwingData[from.objID] = {}
	end

	local ignoreSwingData = Skill.ignoreSwingData[from.objID]
	ignoreSwingData.CastSkill = false
	ignoreSwingData.Move = false
	ignoreSwingData.Jump = false
	
end

--action的类型为 Move,Jump,CastSkill
function Skill.CanIgnoreBySwing(from,action)
	if not Skill.ignoreSwingData[from.objID] then
		return false
	end

	local ignoreSwingData = Skill.ignoreSwingData[from.objID]
	return ignoreSwingData[action]
end


function Skill.RecordSwingData(from,cfg,isPreSwing)
	if not Skill.swingData[from.objID] then
		Skill.swingData[from.objID] = {}
	end

	local entitySwingData = Skill.swingData[from.objID]
	if not entitySwingData[cfg.fullName] then
		entitySwingData[cfg.fullName] = {}
	end

	local skillSwingData = entitySwingData[cfg.fullName]
	if isPreSwing then
		skillSwingData.stopPreSwingTick = World.CurWorld:getTickCount() + cfg.preSwingTime
		skillSwingData.stopBackSwingTick = 0
	else
		skillSwingData.stopPreSwingTick = 0
		skillSwingData.stopBackSwingTick = World.CurWorld:getTickCount() + cfg.backSwingTime
	end
end

function Skill.ClearSwingData(from,cfg)
	if not Skill.swingData[from.objID] then
		return
	end

	local entitySwingData = Skill.swingData[from.objID]
	if not entitySwingData[cfg.fullName] then
		return
	end

	local skillSwingData = entitySwingData[cfg.fullName]
	skillSwingData.stopPreSwingTick = 0
	skillSwingData.stopBackSwingTick = 0
end


function Skill.BreakSwingByMove(from,isPassiveMove)
	if not isPassiveMove then
		if Skill.CanIgnoreBySwing(from,"Move") then
			return
		end
	end

	Skill.DoBreakSwing(from,"Move")
end

--action的类型为 Move,CastSkill,Dead
function Skill.DoBreakSwing(from,action)
  if not Skill.swingData[from.objID] then
    return
  end

  local entitySwingData = Skill.swingData[from.objID]
  for skillName,skillSwingData in pairs(entitySwingData) do
    local cfg = Skill.Cfg(skillName)

	--Dead都会打断，暂时不判断
    local curTick = World.CurWorld:getTickCount()
    if curTick < skillSwingData.stopPreSwingTick then
		if cfg.ignoreCastSkillPreS and action == "CastSkill" then
			goto continue
		end
		if not cfg.enableMoveBrkPreS and (action == "Move" or action == "Jump") then
			goto continue
		end
		skillSwingData.stopPreSwingTick = 0
		print("Skill.DoBreakSwing break pre swing")
		cfg:stopPreSwing(from)
    end

    if curTick < skillSwingData.stopBackSwingTick then
		if cfg.ignoreCastSkillBackS and action == "CastSkill" then
			goto continue
		end
		if not cfg.enableMoveBrkBackS and (action == "Move" or action == "Jump") then
			goto continue
		end
		skillSwingData.stopBackSwingTick = 0
		print("Skill.DoBreakSwing break back swing")
		cfg:stopBackSwing(from)
    end
	::continue::
  end

  return
end
RETURN()
