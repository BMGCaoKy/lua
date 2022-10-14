local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions
local DICTIONARY_MT = BehaviorTree.DICTIONARY_MT

require "world.world"
local setting = require "common.setting"

function Actions.ReadGameCsv(data, params, context)
	return params.path and Lib.readGameCsv(params.path) or {}
end

local function checkDictionary(tb)
	assert(getmetatable(tb) == DICTIONARY_MT, "dict must be a dictionary")
	return tb
end

local function checkDictKey(key)
	assert(type(key) == "number" or type(key) == "string", tostring(key))
	return key
end

function Actions.DictionaryDump(node, params, context)
	local tb = params.dict
	print(tb, Lib.v2s(checkDictionary(tb), params.deep))
end

function Actions.NewDictionary(node, params, context)
    local dict = setmetatable({}, DICTIONARY_MT)
    local table = params[1] or params.table or {}
    local data = {}
    local count = 0
    for k, v in pairs(table) do
        data[checkDictKey(k)] = v
        count = count + 1
    end
    dict.data = data
    dict.count = count
    return dict
end

function Actions.DictionaryGet(node, params, context)
	local tb = checkDictionary(params.dict)
	return tb.data[checkDictKey(params.key)]
end

function Actions.DictionarySet(node, params, context)
	local tb = checkDictionary(params.dict)
	local value = params.value
	local key = checkDictKey(params.key)
	local hasOld = tb.data[key] ~= nil
	local hasNew = value ~= nil
	tb.data[key] = value
	local change = 0
	if hasOld and (not hasNew) then
		change = -1
	elseif (not hasOld) and hasNew then
		change = 1
	end
	tb.count = tb.count + change
end

function Actions.DictionarySize(node, params, context)
	return checkDictionary(params.dict).count
end

function Actions.DictionaryRemove(node, params, context)
	local tb = checkDictionary(params.dict)
	local key = checkDictKey(params.key)
	local ret = tb.data[key]
	tb.data[key] = nil
	local hasOld = ret ~= nil
	if hasOld then
		tb.count = tb.count - 1
	end
	return ret
end

function Actions.DictionaryContains(node, params, context)
	local tb = checkDictionary(params.dict)
	if tb.data[checkDictKey(params.key)] == nil then
		return false
	end
	return true
end

function Actions.DictionaryToTable(node, params, context)
	local tb = checkDictionary(params.dict)
	return tb.data
end

function Actions.NewArray(node, params, context)
	local array, n = {}, 0
	for k, v in pairs(params) do
		assert(type(k) == "number", tostring(k))
		array[k] = v
		if k > n then
			n = k
		end
	end
	assert(n < 256, n)
	array.n = n
	return array
end

function Actions.NumberAbs(node,params,context)
	return math.abs(params.p1)
end

function Actions.FindStr(data,params,context)
    local str= params.str
    local index = string.find(str,params.where_)
    if params.back_ then
        return string.sub(str,index+1,#str)
    else
        return string.sub(str,1,index-1)
    end
end

function Actions.V3(node, params, context)
	return Lib.v3(table.unpack(params))
end

function Actions.V3ToBlockPos(node, params, context)
    return Lib.tov3(params.v3):blockPos()
end

function Actions.PosToV3(node, params, context)
    return Lib.tov3(params.pos)
end

function Actions.Copy(node, params, context)
	local ret = Lib.copy(params.value)
	return ret
end

function Actions.ArrayRandom(node, params, context)
    return Game.RandomTable(params.table, params.num, params.isrepeat)
end

function Actions.SetWeightArrayVar(data, params, context) -- key must be a num
	local table = params.array
	local key = params.key
	assert(type(key) == "number", key)
    table[key] = params.weight
    return table
end

function Actions.FetchWeightArrayVar(data, params, context)
    local table = params.array
    if not next(table) then
        return nil
    end
    local total = 0
    for key, weight in pairs(table) do
        total = total + weight
    end
    local result = nil
    local temp = math.random() * total
    local _, temp1 = next(table)
    for key, weight in pairs(table) do
        if temp > temp1 then
            temp1 = temp1 + weight
        else
            result = key
            break
        end
    end
    return result
end

function Actions.ToNumber(data, params, context)
	return tonumber(params[1])
end

function Actions.ToInteger(data, params, context)
	return math.tointeger(params[1])
end

function Actions.IsNumber(data, params, context)
	return type(params[1]) == "number"
end

function Actions.V3AngleXZ(data, params, context)
	return Lib.v3AngleXZ(params.vector)
end

function Actions.V3RotationYaw(data, params, context)
	return Lib.posAroundYaw(params.vector, params.yaw)
end

function Actions.FilterWord(data, params, context)
	local msg = params.msg
	local len = params.len or 1000
	if utf8.len(msg) > len then
		return nil
	end
	return World.CurWorld:filterWord(params.msg)
end

function Actions.IsContainSensitiveWord(data, params, context)
	return World.CurWorld:isContainSensitiveWord(params.msg)
end

function Actions.SortArrayByKey(data, params, context)
	local arr = params.array
	local key = params.key
	local isToNumberKey = params.isToNumberKey or false
	if not arr or not key then
		return
	end
	table.sort(arr, function(a, b)
		local aKey = a[key]
		local bKey = b[key]
		assert(aKey and bKey and type(aKey) == type(bKey), "Actions.SortArrayByKey : row[key] must be had value")
        return (isToNumberKey and tonumber(aKey) or aKey) < (isToNumberKey and tonumber(bKey) or bKey)
	end)
end

function Actions.SortNumberArray(data, params, context)
	if not params.array then
		return
	end
	local isDesc = params.isDesc or false
	table.sort(params.array, function(a, b)
		assert(type(a) == "number" and type(b) == "number", "Actions.SortNumberArray : array members must be number.")
		if isDesc then
			return tonumber(a) > tonumber(b)
		else
			return tonumber(a) < tonumber(b)
		end
	end)
end

function Actions.SetVector3Len(data, params, context)
	local v3 = params.v3
	local oldLen = math.sqrt((v3.x*v3.x) + (v3.y*v3.y) + (v3.z*v3.z))
	v3.x = v3.x * params.len / oldLen 
	v3.y = v3.y * params.len / oldLen 
	v3.z = v3.z * params.len / oldLen 
end

