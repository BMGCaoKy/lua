-- 对Action做容错用的辅助判断函数


-- 获取当前执行Action的函数名字
---@param level number 其他函数中调用getActionName时，debug.getlocal函数调用所在层次，下列容错辅助判断函数中 level = 5
---@param index number 包含Action名字参数index, 目前在 index = 1 处
---@param step number  若再封装辅助判断函数step层，则level需要加上step才能正确获取到Action的名字
-- 大多数情况下不需要再封装辅助判断函数，即step = 0
local function getActionName(level, index, step)
    level = level or 5
    index = index or 1
    step = step or 0
    local _, v = debug.getlocal(level + step, index)
    return v and v.type or "unknownAction"
end

local function showInfo(info, level)
    level = level or 4
    Lib.log(info, level)
end

-- 检查是否为一个无效实例
-- 检查action传入的实例时，不能精确判断是哪类实例或没有该类实例检查函数时可以考虑使用这个通用的判断函数
-- 但是要打印提示信息时建议传入实例名
---@param instance table 需检查的实例，自身必须包含isValid()接口
---@param instanceName string 用于log中显示的实例名
---@param closeLog boolean log开关，默认开启，使检测结果为无效实例时可用log打印提示信息
function ActionsLib.isInvalidInstance(instance, instanceName, closeLog)
    if not instance or not instance:isValid() then
        if not closeLog then
            local info = string.format("Actions.%s: the %s is invalid !", getActionName(), instanceName)
            showInfo(info)
        end
        return true
    end
    return false
end

function ActionsLib.isInvalidEntity(entity, entityName, closeLog)
    entityName = entityName or "Entity"
    if ActionsLib.isInvalidInstance(entity, nil, true) then
        if not closeLog then
            local info = string.format("Actions.%s: the %s is invalid !", getActionName(), entityName)
            showInfo(info)
        end
        return true
    end
    return false
end

function ActionsLib.isInvalidPart(part, partName, closeLog)
    partName = partName or "Part"
    if ActionsLib.isInvalidInstance(part, nil, true) then
        if not closeLog then
            local info = string.format("Actions.%s: the %s is invalid !", getActionName(), partName)
            showInfo(info)
        end
        return true
    end
    return false
end

function ActionsLib.isInvalidMap(map, mapName, closeLog)
    mapName = mapName or "Map"
    if type(map) == "string" then
		return false
	end
    if ActionsLib.isInvalidInstance(map, nil, true) then
        if not closeLog then
            local info = string.format("Actions.%s: the %s is invalid !", getActionName(), mapName)
            showInfo(info)
        end
        return true
    end
    return false
end

function ActionsLib.isInvalidPlayer(player, palyerName, closeLog)
    palyerName = palyerName or "Entity"
    if ActionsLib.isInvalidInstance(player, nil, true) or not player.isPlayer then
        if not closeLog then
            local info = string.format("Actions.%s: the %s is an invalid player !", getActionName(), palyerName)
            showInfo(info)
        end
        return true
    end
    return false
end

function ActionsLib.isEmptyString(str, stringName, closeLog)
    stringName = stringName or "Name"
    if not str or str == '' then
        if not closeLog then
            local info = string.format("Actions.%s: the %s is empty !", getActionName(), stringName)
            showInfo(info)
        end
        return true
    end
    return false
end

function ActionsLib.isInvalidRange(min, max, closeLog)
    if not min or not max or min > max then
        if not closeLog then
            local info = string.format("Actions.%s: the Range is invalid !", getActionName())
            showInfo(info)
        end
        return true
    end
    return false
end

function ActionsLib.isInvalidRegion(region, closeLog)
    if not region then return false end
    local min, max = region.min, region.max
    local ret = false
    if not min or not max or ActionsLib.isInvalidRange(min.x, max.x, true) then
        ret = true
    end
    if not ret and ActionsLib.isInvalidRange(min.y, max.y, true) or ActionsLib.isInvalidRange(min.z, max.z, true) then
        ret = true
    end
    if ret and not closeLog then
        local info = string.format("Actions.%s: the Region is invalid !", getActionName())
        showInfo(info)
    end
    return ret
end

function ActionsLib.isNil(var, varName, closeLog, step)
    varName = varName or "Var"
    local ret = var == nil
    if ret and not closeLog then
        local info = string.format("Actions.%s: the %s is invalid !", getActionName(nil, nil, step), varName)
        showInfo(info)
    end
    return ret
end

function ActionsLib.isInvalidArrayIndex(index, closeLog)
    local ret = type(index) ~= "number" or index <= 0
    if ret and not closeLog then
        local info = string.format("Actions.%s: the Index is invalid !", getActionName())
        showInfo(info)
    end
    return ret
end

function ActionsLib.getTeamById(teamId)
    if ActionsLib.isNil(teamId, "TeamId", false, 1) then
        return nil
    end
    local team = Game.GetTeam(teamId)
    if ActionsLib.isNil(team, "TeamId", false, 1) then
        return nil
    end
    return team
end

function ActionsLib.tipIfWillOccursEndlessLoop(from, to, step)
	if step == 0 and from >= to then
		local info = string.format("Actions.%s: An endless loop occurs. This may produce some errors !", getActionName())
		showInfo(info, 3)
	end
end
