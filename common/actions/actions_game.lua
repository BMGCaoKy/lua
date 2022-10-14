local BehaviorTree = require("common.behaviortree")
local MapEffectMgr = require "server.world.map_effect_mgr"
local setting = require "common.setting"
local Actions = BehaviorTree.Actions
require "world.world"

local function startTimerRun(params)
    local obj = params.object
	-- todo:参数还原
    params.obj1 = obj
    Trigger.CheckTriggers(obj and obj:cfg(), params.event, params)
    return params.rep
end

function Actions.StartTimer(data, params, context)
    local time = params.time
    local action = params.action
    if action or data.children then
        local times = params.times
        local closer = World.Timer(
			time,
			function()
				local ok, ret = xpcall(Actions.Parallel, traceback, {
						type = "Parallel",
						children = action and {action} or data.children
					}, {}, context)
				if not ok then
					local msg = "Error call timer"
					local source, line, column = data.__source, data.__line, data.__column
					if source and line then
						msg = string.format("%s at %s:%d%s", msg, source, line, (column and " column "..column or ""))
					end
					perror(msg..":", ret)
					return
				end
				if time <= 0 then
					return true
				end
				times = times - 1
				if times > 0 then
					return true
				end
			end
        )
        return closer
    else
	    local obj = params.object
		if obj then
			return obj:timer(params.time, startTimerRun, params)
		else
			return World.Timer(params.time, startTimerRun, params)
		end
	end
end

function Actions.StopTimer(data,params,context)
    local timer = params.timer
    assert(timer)
    if type(timer) == "function" then
        timer()
    else
        for _, closer in pairs(timer or {}) do
            closer()
		end
	end
end

do
	local _closer = {}

	function Actions.StartTimer2(data, params, context)
        if ActionsLib.isNil(params.time, "Time") or ActionsLib.isNil(params.interval, "Interval") then
            return
        end
        params.times = params.time
        params.time = params.interval
        params.interval = nil

        local closer = Actions.StartTimer(data, params, context)

		local key = params.timer
		if key then
			_closer[key] = _closer[key] or {}
			table.insert(_closer[key], closer)
		end
	end

	function Actions.StopTimer2(data, params, context)
		local key = assert(params.timer)
        params.timer = _closer[key] or {}
        Actions.StopTimer(data, params, context)
		_closer[key] = nil
	end
end

function Actions.PlayerOneMoreGame(data, params, context)
    if World.isClient then 
        Lib.emitEvent(Event.EVENT_GAME_SHOW_RESTART_BOX, packet) 
    else
        local entity = params.entity
        if ActionsLib.isInvalidEntity(entity) then
            return
        end
        entity:sendPacket({
            pid = "ShowRestartBox"
        })
    end
end
