local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions
local DICTIONARY_MT = BehaviorTree.DICTIONARY_MT

require "world.world"
local setting = require "common.setting"

function Actions.Test(data, params, context)
	if params then
		Lib.pv(params, params.level or 3, "ActionTest!!!!!!!!!!!")
	end
end

function Actions.IsNil(data, params, context)
	return params.data == nil
end

function Actions.ComputeV3(data, params, context)
	local op = params.op
    if op=="add" then
        return Lib.v3add(params.p1,params.p2)
    end
    if op=="sub" then
        return Lib.v3cut(params.p1,params.p2)
    end
end

function Actions.Random(data, params, context)
	local min, max = params.min, params.max
	if ActionsLib.isInvalidRange(min, max) then
		return math.random()
	end
	return math.random(min, max)
end

function Actions.ArrayAppend(node, params, context)
	local array = params.array
	array[#array + 1] = params.value
end

function Actions.ArrayInsert(node, params, context)
	local index = math.tointeger(params.index)
	if ActionsLib.isInvalidArrayIndex(index) then
		return
	end
	table.insert(params.array, index, params.value)
end

function Actions.ArrayGet(node, params, context)
	local index = math.tointeger(params.index)
	if ActionsLib.isInvalidArrayIndex(index) then
		return
	end
	return params.array[index]
end

function Actions.ArraySet(node, params, context)
	local index = math.tointeger(params.index)
	if ActionsLib.isInvalidArrayIndex(index) then
		return
	end
	params.array[index] = params.value
end

function Actions.ArrayRemove(node, params, context)	-- 返回元素
	local index = math.tointeger(params.index)
	if ActionsLib.isInvalidArrayIndex(index) then
		return
	end
	return table.remove(params.array, index)
end

function Actions.ArraySize(node, params, context)
	if not params.array then
		return 
	end
	return #params.array
end

function Actions.ArrayFind(node, params, context)
	local v = params.value
	for index, value in ipairs(params.array) do
		if value == v or (type(v) == "table" and type(value) == "table" and Lib.isSameTable(v, value)) then
			return index
		end
	end
	return nil
end

function Actions.IsValueInArray(node, params, context)
	return not not Actions.ArrayFind(node, params, context)
end

function Actions.Concat(node,params,context)
    local str = ""
	for i = 1, 10 do
		local p = params["p"..i]
		if not p then
			break
		end
		str = str .. p
	end
	return str
end

function Actions.NumberFloor(node,params,context)
	return math.floor(params.p1)
end

function Actions.NumberCeil(node,params,context)
	return math.ceil(params.p1)
end

function Actions.GetPosDistance(data, params, context)
    return Lib.getPosDistance(params.pos1, params.pos2)
end

function Actions.GetPosDistanceSqr(data, params, context)
    return Lib.getPosDistanceSqr(params.pos1, params.pos2)
end

function Actions.ToString(data, params, context)
	return tostring(params[1])
end

local function checkTrigonometricFuncParams(params, errorMsgPre)
	if not params[1] then
		Lib.logWarning(errorMsgPre .. " error, not params.")
		return false
	end
	if type(params[1]) ~= "number" then
		Lib.logWarning(errorMsgPre .. " error, params isn't a number. ", params[1])
		return false
	end
	return true
end

function Actions.Sin(data, params, context)
	if not checkTrigonometricFuncParams(params, "Sin") then
		return
	end
	return math.sin(math.rad(params[1]))
end

function Actions.Cos(data, params, context)
	if not checkTrigonometricFuncParams(params, "Cos") then
		return
	end
	return math.cos(math.rad(params[1]))
end

function Actions.Tan(data, params, context)
	if not checkTrigonometricFuncParams(params, "Tan") then
		return
	end
	if params[1] == 90 then
		Lib.logWarning("Tan error, params is 90. ")
		return
	end
	return math.tan(math.rad(params[1]))
end

function Actions.SendToServer(data, params, context)
	if not World.isClient then
		return
	end
	local packet = params
	packet.pid = "BtsMsg"
	Me:sendPacket(packet)
end

function Actions.SendToClient(data, params, context)
	if World.isClient then
		return
	end

	local player = params.player
	if(not player or not player.isPlayer) then
		print("cannot send to client: ", player)
		return
	end
	local packet = params
	packet.player = nil
	packet.pid = "BtsMsg"
	player:sendPacket(packet)
end

function Actions.TableGet(node, params, context)
	local key = params.key
	local table = params.table
	if not type(table) == "table" then
		return
	end
	return params.table[key]
end
