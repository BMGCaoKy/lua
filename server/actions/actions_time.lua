local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions
require "world.world"
local setting = require "common.setting"

function Actions.GetTime(node, params, context)
	return os.time()
end

function Actions.GetYear(node, params, context)
    local time = params.time
    if not time then
        return false
    end
    return Lib.getYear(time)
end

function Actions.GetMonth(node, params, context)
    local time = params.time
    if not time then
        return false
    end
    return Lib.getMonth(time)
end

function Actions.GetDayOfMonth(node, params, context)
    local time = params.time
    if not time then
        return false
    end
    return Lib.getDayOfMonth(time)
end

function Actions.GetDayOfWeek(node, params, context)
    local time = params.time
    if not time then
        return false
    end
    return Lib.getDayOfWeek(time)
end

function Actions.GetDayOfWeekString(node, params, context)
    local time = params.time
    if not time then
        return false
    end
    return Lib.getDayOfWeekString(time)
end

function Actions.GetDayOfYear(node, params, context)
    local time = params.time
    if not time then
        return false
    end
    return Lib.getDayOfYear(time)
end

function Actions.GetYearDayStr(node, params, context)
    local time = params.time
    if not time then
        return false
    end

    return Lib.getYearDayStr(time)
end

function Actions.GetYearMonthStr(node, params, context)
    local time = params.time
    if not time then
        return false
    end
    return Lib.getYearMonthStr(time)
end

function Actions.GetYearWeekStr(node, params, context)
    local time = params.time
    if not time then
        return false
    end
    return Lib.getYearWeekStr(time)
end

function Actions.GetWeeksOfYear(node, params, context)
    local time = params.time
    if not time then
        return false
    end
    return Lib.getWeeksOfYear(time)
end

function Actions.IsTimeBefore(node, params, context)
    local time1, time2 = params.time1, params.time2
	if not (time1 and time2) then
		return false
	end
	return tonumber(time1) < tonumber(time2)
end

function Actions.IsTimeAfter(node, params, context)
    local time1, time2 = params.time1, params.time2
	if not (time1 and time2) then
		return false
	end
	return tonumber(time1) > tonumber(time2)
end

function Actions.GetTimeDiff(node, params, context)
    local time1, time2 = params.time1, params.time2
    if not (time1 and time2) then
        return false
    end
	return Lib.getTimeDiff(time1,time2)
end

function Actions.GetMonthStartTime(node, params, context)
    local time = params.time
    if not time then
        return false
    end
    return Lib.getMonthStartTime(time)
end

function Actions.GetWeekStartTime(node, params, context)
    local time = params.time
    if not time then
        return false
    end
    return Lib.getWeekStartTime(time)
end

function Actions.GetDayStartTime(node, params, context)
    local time = params.time
    if not time then
        return false
    end
    return Lib.getDayStartTime(time)
end


function Actions.GetMonthEndTime(node, params, context)
    local time = params.time
    if not time then
        return false
    end
    return Lib.getMonthEndTime(time)
end


function Actions.GetWeekEndTime(node, params, context)
    local time = params.time
    if not time then
        return false
    end
    return Lib.getWeekEndTime(time)
end


function Actions.GetDayEndTime(node, params, context)
    local time = params.time
    if not time then
        return false
    end
    return Lib.getDayEndTime(time)
end

function Actions.IsSameWeek(node, params, context)
    local time1, time2 = params.time1, params.time2
    if not (time1 and time2) then
        return false
    end
    return Lib.isSameWeek(time1, time2)
end

function Actions.IsSameDay(node, params, context)
    local time1, time2 = params.time1, params.time2
	if not (time1 and time2) then
		return false
	end
	return Lib.isSameDay(time1, time2)
end
