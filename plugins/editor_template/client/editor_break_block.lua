local SkillBase = Skill.GetType("Base")
local BreakBlock = Skill.GetType("BreakBlock")

local function check(f)
	return f > 1 and 1 or f
end

local function getBuffEff(player)
	return player and player:data("efficient").value or 0
end

local function getToolEff(tool, block)
	local effAll = tool:cfg().effAllBlock or 0
	local effType = tool:cfg().effTypeBlock or {}
	local efft = effType[block.blockType] or 0
	return effAll + efft
end

local function getBlockBreakTime(block, player)
	local breakTime = block.breakTime or 1
	if not player then
		return breakTime
	end
	local tool = player:getHandItem()
	local buffEff = check(getBuffEff(player))
	if not tool or tool:null() then
		return (1 - buffEff) * breakTime
	end
	local eff = check(getToolEff(tool, block) + buffEff)
	return (1 - eff) * breakTime
end

function BreakBlock:getTouchTime(packet, from)
	local blockPos = packet.blockPos
	if not blockPos then
		return nil
	end
	if from:data("reload").reloadTimer then
		return nil
	end
	if not self:canCast(packet, from) then
		return nil
	end
	local block = from.map:getBlock(blockPos)
	local clickDis = from:cfg().clickBlockDistance
	if clickDis and Lib.getPosDistance(from:getPosition(), blockPos) > clickDis then
		return false
	end
	local breakTime = getBlockBreakTime(block, from)
	return math.ceil(math.max(1, breakTime))
end
