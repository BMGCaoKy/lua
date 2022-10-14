local queue = require "common.stl.queue"	--- 必须优先全局 class 函数初始化
require "common.util.logutil"
require "common.luatimer"
require "common.tools.timer"
local cjson = require "cjson"
local misc = require "misc"
local lfs = require "lfs"
local loadstring = rawget(_G, "loadstring") or load
require "common.math.math"
require "common.dateutil"
local xml2lua = require "common.xml2lua.xml2lua"
local handler = require "common.xml2lua.xmlhandler.tree"

local Stack = require "common.stack"
local Platform = require "common.platform"
local eventCalls = L("eventCalls", {})

local strsub = string.sub
local strfind = string.find

local math = math
local floor = math.floor
local mrand = math.random
local PI_DIV180 = math.pi / 180
local timePerTick = 50 --单位ms

local allGameConfigs
local isLoadGameConfigs = false

local function getConfig(path)
	if not isLoadGameConfigs and allGameConfigs == nil and not path:find("lang/") then
		allGameConfigs = Lib.load_lua_full_path(Root.Instance():getGamePath().. "all_configs.lbc")
		isLoadGameConfigs = true
	end
	return allGameConfigs and allGameConfigs[path] or nil
end

function Lib.derive(base, derive)
	assert(base)
	derive = derive or {}
	derive.__base = derive.__base or {}
	table.insert(derive.__base, base)

	return setmetatable(derive, {
			__index = function (_, key)
				for _, base in ipairs(derive.__base) do
					if base[key] then
						return base[key]
					end
				end
			end
		}
	)
end

function Lib.go(target)
	local GameObject = require "common.gameobject"
	return GameObject.extend(target)
end

function Lib.class(classname, super)
	local class = require "common.class"
	return class(classname, super)
end

function Lib.classof(obj)
	local _, classof = require "common.class"
	return classof(obj)
end

function Lib.clone(obj)
	local _, _, clone = require "common.class"
	return clone(obj)
end

---@param t table
---@param f function
function Lib.pairsByKeys(t, f)
	local arr = {}
	for k, _ in pairs(t) do
		arr[#arr + 1] = k
	end

	table.sort(arr, f)

	local i = 0
	return function()
		i = i + 1
		return arr[i], t[arr[i]]
	end
end

---@param t table
---@param f function
function Lib.pairsByValues(t, f)
	local arr = {}
	local tbKey = {}
	for k, v in pairs(t) do
		arr[#arr + 1] = v
		tbKey[v] = k
	end

	table.sort(arr, f)

	local i = 0
	return function()
		i = i + 1
		return tbKey[arr[i]], arr[i]
	end
end

---@param str string
---@return table
function Lib.stringToTable(str)
	if type(str) ~= "string" then
		return nil
	end

	local ok, ret = xpcall(loadstring("return "..str), debug.traceback)
	if not ok then
		Lib.logError("stringToTable not ok", str, ret)
		return nil
	end

	return type(ret) == "table" and ret or nil
end

---@param t table
---@param d any
function Lib.setDefault(t, d)
	if type(t) ~= "table" then
		return
	end

	setmetatable(t, { __index = function()
			return d
	end })
end

---@return table
function Lib.newWeakTable(tb, mode)
	tb = tb or {}
	mode = mode or "kv"
	setmetatable(tb, {__mode = mode})
	return tb
end

function Lib.getTableSize(tb)
	if not tb or type(tb) ~= "table" then
		return -1
	end

	local result = 0
	for _, _ in pairs(tb) do
		result = result + 1
	end
	return result
end

function Lib.toBool(value)
	if type(value) == "boolean" then
		return value
	elseif type(value) == "string" then
		return value == "true"
	end
	return false
end

---@param tick number
function Lib.tickToTime(tick)
	return tick * timePerTick
end

---@param time number 单位ms
function Lib.timeToTick(time)
	return math.ceil(time / timePerTick)
end

---@param name string
---@param initval any
function Lib.declare(name, initval)
	rawset(_G, name, initval or false)
end

---@param root any
---@param options table
---@return string
function Lib.inspect(root, options)
	local inspect = require "common.util.inspect"
	return inspect.inspect(root, options)
end

function Lib.read_file(path)
	local file, errmsg = io.open(path, "rb")
	if not file then
		--print("[Error]", errmsg)
		--print("--------------------------------------")
		--print(traceback())
		return nil
	end
	local content = file:read("a")
	file:close()

	-- remove BOM
	local c1, c2, c3 = string.byte(content, 1, 3)
	if (c1 == 0xEF and c2 == 0xBB and c3 == 0xBF) then	-- UTF-8
		content = string.sub(content, 4)
	elseif (c1 == 0xFF and c2 == 0xFE) then	-- UTF-16(LE)
		content = string.sub(content, 3)
	end

	return content
end

--function Lib.read_file(path)
--	local fileName = false
--	local find, q = strfind(path, Root.Instance():getGamePath(), 1, true)
--	if find then
--		fileName = strsub(path, q + 1)
--	else
--		fileName = path
--	end
--	local content = FileResourceManager.Instance():LuaReadFileAsText(path)
--	if (not content or content == '') then
--		content = FileResourceManager.Instance():OpenResourceAsStrInGame(fileName)
--	end
--	if (not content or content == '') then
--		return
--	end
--    -- remove BOM
--    local c1, c2, c3 = string.byte(content, 1, 3)
--    if (c1 == 0xEF and c2 == 0xBB and c3 == 0xBF) then	-- UTF-8
--        content = string.sub(content, 4)
--    elseif (c1 == 0xFF and c2 == 0xFE) then	-- UTF-16(LE)
--        content = string.sub(content, 3)
--    end
--    return content
--end

local function checkAssert(ok, path)
	if ok then
		return
	end

	if rawget(_G, "IS_EDITOR") then
		Lib.logError("wrong json format:", path)
	else
		assert(false, path)
	end
end

function Lib.read_lua_object(path, debug)
	local content = Lib.read_file(path, debug)
	if content and content ~= '' then
		local ok, ret = pcall(misc.data_decode, content)
		checkAssert(ok, path)
		return ok and ret
	end
end

function Lib.read_json_file(path, debug)
	local content = Lib.read_file(path, debug)
	if content and content ~= '' then
		content = content:gsub("&backslash", "\\")
		local ok, ret = pcall(cjson.decode, content)
		checkAssert(ok, path)
		return ok and ret
	else
		--Lib.logError("read_json_file failed!", path)
	end
end

function Lib.read_lang_file(path)
	local content, errmsg = Lib.read_file(path)
	if (not content or content == '') then
		return nil
	end
	local strs = Lib.splitString(content, "\n")
	local res = {}
	for _, i in pairs(strs) do
		if i:sub(-1) == "\r" then
			i = i:sub(1,-2)
		end
		local k, v = string.match(i,"^([^=%s]*)%s*=%s*(.*)$")
		if k and v then
			res[k] = v:gsub("\\n", "\n")
		end
	end
	return res
end

function Lib.table_is_empty(t)
	return _G.next(t) == nil
end

function Lib.readGameJson(path)
	local config = getConfig(path)
	if config then
		return Lib.copy(config)
	end
	return Lib.read_json_file(Root.Instance():getGamePath()..path)
end

function Lib.readGameLuaObject(path)
	local content = Lib.read_lua_object(Root.Instance():getGamePath()..path)
	return content
end

-- 根据 key 的降序序列化, 追加可自定义排序方式
function Lib.toJson(data, sortFunc)
	local strList = {}
	local tojson, array2json, obj2json
	local tabStr = "  "

	obj2json = function(data, level)
		--排序
		local keys = {}
		for k, _ in pairs(data) do
			if type(k) == "string" or type(k) == "number" then
				table.insert(keys, k)
			end
		end
		table.sort(keys, sortFunc)

		table.insert(strList, "{\n")
		level = level + 1
		for _, k in ipairs(keys) do
			table.insert(strList, string.rep(tabStr, level))
			table.insert(strList, '\"')
			table.insert(strList, k)
			table.insert(strList, '\"')
			table.insert(strList, ": ")
			tojson(data[k], level)
			table.insert(strList, ",\n")
		end
		strList[#strList] = "\n"
		level =  level - 1
		table.insert(strList, string.rep(tabStr, level))
		table.insert(strList, "}")
	end

	array2json = function(data, level)
		table.insert(strList, "[\n")
		level = level + 1
		for _, v in ipairs(data) do
			table.insert(strList, string.rep(tabStr, level))
			tojson(v, level)
			table.insert(strList, ",\n")
		end
		strList[#strList] = "\n"
		level =  level - 1
		table.insert(strList, string.rep(tabStr, level))
		table.insert(strList, "]")
	end

	tojson = function(data, level)
		if type(data) == "string" then
			data = data:gsub("\\", "\\\\")
			--data = data:gsub("/", "\\/")
			data = data:gsub("\n", "\\n")
			data = data:gsub("\"", "\\\"")
			table.insert(strList, '\"' .. data .. '\"')
		elseif type(data) == "number" then
			local num = math.ceil(data) --浮点型处理：x.0存盘为整型x
			if data == num then
				table.insert(strList, num)
			else
				table.insert(strList, data)
			end
		elseif type(data) == "nil" then
			table.insert(strList, "null")
		elseif type(data) == "boolean" then
			table.insert(strList, data and "true" or "false")
		elseif type(data) == "table" then
			level = level or 0
			if Lib.table_is_empty(data) then
				table.insert(strList, "[]")
			elseif #data > 0 then
				array2json(data, level)
			else
				obj2json(data, level)
			end
		end
	end

	tojson(data)

	return table.concat(strList)
end

function Lib.jsonToFormat(str)
    local result = {}
    local pos = 0
    local strLen = string.len(str)
    local indentStr = "\t"
    local newLine = "\n"
    local prevChar = ""
    local outOfQuotes = true

    for i = 0, strLen do
        local char = string.sub(str, i, i)
        if char == '"' and prevChar ~= "\\" then
            outOfQuotes = not outOfQuotes
        elseif (char == "}" or char == "]") and outOfQuotes then
			result[#result + 1] = newLine
            pos = pos - 1
            for j = 0, pos do
				result[#result + 1] = indentStr
            end
        end
		result[#result + 1] = char
        if (char == "," or char == "{" or char == "[") and outOfQuotes then
			result[#result + 1] = newLine
            if char == "{" or char == "[" then
                pos = pos + 1
            end
            for j = 0, pos do
				result[#result + 1] = indentStr
            end
        end
        prevChar = char
    end
    return table.concat(result)
end

function Lib.saveGameJson1(path, content, filePath)
    local ok
    ok, content = pcall(cjson.encode, content)
	path = (filePath or Root.Instance():getGamePath()) .. path
    local file, errmsg = io.open(path, "w")
	if not file then
		print(errmsg)
		return false
	end
	file:write(content)
	file:close()
end

function Lib.saveGameJson(path, content, filePath)
	local ok
	if World.isClient and CGame.instance:getPlatformId() == 1 then  --pc
		content = Lib.toJson(content)
	else
		ok, content = pcall(cjson.encode, content)
	end
	path = (filePath or Root.Instance():getGamePath()) .. path
	local file, errmsg = io.open(path, "w")
	if not file then
		print(errmsg)
		return false
	end
	file:write(content)
	file:close()
end

function Lib.load_lua_full_path(luaPath)
	local endPath, chuck = loadLua(luaPath)
	if endPath then
		local ret, _ = load(chuck, "@" .. endPath, "bt")
		if ret then
			return ret()
		end
	end
	return nil
end

function Lib.read_csv_file(path, ignore_line)
	if strfind(path, Root.Instance():getGamePath(), 1, true) then
		local newPath = path:gsub(Root.Instance():getGamePath(), "")
		local luaPath = path:gsub(".csv$", ".lbc")
		if lfs.attributes(luaPath, "mode") == "file" then
			local config = Lib.load_lua_full_path(luaPath)
			if config then return config end
		end
		local config = getConfig(newPath)
		if config then return config end
	end
	return misc.read_csv_file(path, ignore_line)
end

function Lib.read_gamepath_csv(path, cols, ignore_line, separator)
	ignore_line = ignore_line or 3
	separator = separator or "#"

	local config = Lib.read_csv_file(Root.Instance():getGamePath() .. path, ignore_line)
	local ret = {}
	for _, row in ipairs(config) do
		local newRow = {}
		for key, type in pairs(cols) do
			local value = row[key]
			if type == "n" then
				value = tonumber(value)
			elseif type == "#" then
				value = Lib.splitString(value, separator)
			elseif type == "#n" then
				value = Lib.splitString(value, separator, true)
			end
			newRow[key] = value
		end
		table.insert(ret, newRow)
	end
	return ret
end

function Lib.toXml(data,handle,level)
	return xml2lua.toXml(data, handle,level)
end

function Lib.XmltoTable(xml)
	local new_handler = handler:new()
	local parser = xml2lua.parser(new_handler)
	parser:parse(xml)
	return new_handler.root
end

function Lib.LoadXmltoTable(path)
	local xml = xml2lua.loadFile(path)
	return Lib.XmltoTable(xml)
end

---@param path string
function Lib.readGameCsv(path, ignore_line)
	if strfind(path, Root.Instance():getGamePath(), 1, true) then
		return Lib.read_csv_file(path, ignore_line)
	else
		return Lib.read_csv_file(Root.Instance():getGamePath()..path, ignore_line)
	end
end

local function v2s(value, sp, restLevel)
	local typ = type(value)
	if typ=="string" then
		return '\"' .. value .. '\"'
	elseif typ~="table" then
		return tostring(value)
	end
	restLevel = restLevel - 1
	if restLevel<0 then
		return "..."
	end
	local nsp = sp .. "  "
	local tb = {}
	local idxs = {}
	for k, v in ipairs(tb) do
		idxs[k] = true
		tb[#tb+1] = "[" .. k .. "] = " .. v2s(v, nsp, restLevel)
	end
	for k, v in pairs(value) do
		if not idxs[k] then
			k = (type(k)=="string") and ('\"'..k..'\"') or tostring(k)
			tb[#tb+1] = "[" .. k .. "] = " .. v2s(v, nsp, restLevel)
		end
	end
	if not tb[1] then
		return "{}"
	end
	nsp = "\n" .. nsp
	return "{"..nsp .. table.concat(tb, ","..nsp) .. "\n" .. sp .. "}";
end

function Lib.v2s(value, maxLevel)
	return v2s(value, "", maxLevel or 3)
end

function Lib.a2s(array)
	local result = "["
	for i, v in pairs(array) do
		if i == #array then
			result = result .. tostring(v)
		else
			result = result .. tostring(v) .. ","
		end
	end
	return result .. "]"
end

function Lib.pv(value, maxLevel, tips)
	print(
		tips, v2s(value, "", maxLevel or 3)
	)
end

function Lib.sendServerErrMsgToChat(obj, msg)
	-- sendErrToClient : none / target / all
	local sendErrToClient = World.sendErrToClient
	if not sendErrToClient or sendErrToClient == "none" then
		return
	end
	local sendToPlayers
	if sendErrToClient == "all" then
		sendToPlayers = Game.GetAllPlayers() or {}
	elseif sendErrToClient == "target" then
		sendToPlayers = {}
		for objId in pairs(World.sendErrToClientPlayerIds) do
			sendToPlayers[objId] = World.CurWorld:getObject(objId)
		end
	end
	if not sendToPlayers or not next(sendToPlayers) then
		return
	end
	local tempMsg = "error objID = " .. (obj and obj.objID or 0) .. ", " .. msg
	for _, player in pairs(sendToPlayers) do
		GM.serverError(player, tempMsg)
	end
end

function Lib.sendErrMsgToChat(obj, msg)
	if World.isClient then
		GM:sendErrMsgToChatBar(msg)
		return
	end
	Lib.sendServerErrMsgToChat(obj, msg)
end

function Lib.getEventCall(name)
	return Event:GetLibCalls(name)
end

local function emitCallEvent(name, ...)
	local bindableEvent = Event:GetExtraEvent(Define.EVENT_POOL.LIB, name, "Engine")
	if bindableEvent then
		bindableEvent:Emit(...)
	end
end

function Lib.checkAndPopEventData(name)
	if not DataCacheContainer.checkHasRegister(name) then
		return
	end
	for _, argsPack in ipairs(DataCacheContainer.popDataCache(name)) do
		emitCallEvent(name, table.unpack(argsPack))
	end
	DataCacheContainer.removeContainer(name)
end

function Lib.subscribeEvent(name, func, ...)
	if not name or not func then
		return
	end
	-- return Lib.lightSubscribeEvent(traceback_only("register event"), name, func, ...)
	return Lib.lightSubscribeEvent(Lib.getCallTag(), name, func, ...)
end

function Lib.lightSubscribeEvent(stack, name, func, ...)
	assert(stack, " Lib.lightSubscribeEvent need stack!")
	if not name or not func then
		return
	end

	local bindableEvent = Event:GetExtraEvent(Define.EVENT_POOL.LIB, name, "Engine")
	local bindHandler, bindID = bindableEvent:BindWithStack(func, stack, ...)

	return function()
		bindHandler:Destroy()
	end, bindID
end

function Lib.subscribeKeyDownEvent(key, func)
	return Lib.subscribeEvent(Event.EVENT_WIN_KEY_DOWN, function(name)
		if key == name then
			func()
		end
	end)
end

function Lib.subscribeKeyUpEvent(key, func)
	return Lib.subscribeEvent(Event.EVENT_WIN_KEY_UP, function(name)
		if key == name then
			func()
		end
	end)
end

function Lib.unsubscribeEvent(name, index)
	local bindableEvent = Event:GetExtraEvent(Define.EVENT_POOL.LIB, name, "Engine", true)
	if bindableEvent then
		bindableEvent:UnbindByID(index)
	end
end

function Lib.emitEvent(name, ...)
	emitCallEvent(name, ...)
end

function Lib.v3add(v1, v2)
	return {
		x = v1.x + v2.x,
		y = v1.y + v2.y,
		z = v1.z + v2.z
	}
end

function Lib.v3cut(v1,v2)
	return{
		x = v1.x - v2.x,
		y = v1.y - v2.y,
		z = v1.z - v2.z
	}
end

function Lib.v3multip(value1, value2)
	local v1 = value1
	local v2 = value2
	local function transV(num)
		return {
			x = num,
			y = num,
			z = num
		}
	end
	if type(value1) == "number" then
		v1 = transV(value1)
	end
	if type(value2) == "number" then
		v2 = transV(value2)
	end
	return {
		x = v1.x * v2.x,
		y = v1.y * v2.y,
		z = v1.z * v2.z,
	}
end

function Lib.v3normalize(v)
	local len =  math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
	return {
		x = v.x / len,
		y = v.y / len,
		z = v.z / len
	}
end

function Lib.v3AngleXZ(v)
	local r = math.atan(-v.x, v.z)
	return r >= 0 and (r / PI_DIV180) or (360 - math.abs(r) / PI_DIV180)
end

function Lib.getPosDistanceSqr(pos1, pos2)
	if not pos1 or not pos2 then
		return math.huge
	end
    local dx, dy, dz = pos1.x - pos2.x, pos1.y - pos2.y, pos1.z - pos2.z
    return dx * dx + dy * dy + dz * dz
end

function Lib.getPosDistance(pos1, pos2)
	if not pos1 or not pos2 then
		return math.huge
	end
    return math.sqrt(Lib.getPosDistanceSqr(pos1, pos2))
end

function Lib.getPosXZAbsoluteDistance(pos1, pos2)
	if not pos1 or not pos2 then
		return math.huge
	end
    return math.abs(pos1.x - pos2.x) + math.abs(pos1.z - pos2.z)
end

function Lib.getRegionCenter(region)
	local min, max = region.min, region.max
	return Lib.v3((min.x + max.x) / 2, (min.y + max.y) / 2, (min.z + max.z) / 2)
end

function Lib.randPosInRegion(region)
	local min, max = region.min, region.max
    return Lib.v3(mrand(min.x, max.x), mrand(min.y, max.y), mrand(min.z, max.z))
end

function Lib.isPosInRegion(region, pos)
	local min, max = region.min, region.max
	return math.floor(pos.x) >= min.x and math.floor(pos.x) <= max.x and
			math.floor(pos.y) >= min.y and math.floor(pos.y) <= max.y and
			math.floor(pos.z) >= min.z and math.floor(pos.z) <= max.z
end

function Lib.boxOne()
	local obj = {
		min = {
			x = 1,
			y = 1,
			z = 1
		},
		max = {
			x = 1,
			y = 1,
			z = 1
		}
	}
	return obj
end

function Lib.copy(value)
	if type(value)~="table" then
		return value
	end
	local ret = {}
	if value.clone then--if table has owner clone function than use it,just like big_integer.lua.--- note by zhuyayi 20200413
		ret = value:clone()
	else
		for k, v in pairs(value) do
			ret[k] = Lib.copy(v)
		end
	end

	return ret
end

function Lib.copyTable1(tb)
	local ret = {}
	for k, v in pairs(tb) do
		ret[k] = v
	end
	return ret
end

function Lib.fileExists(path)
	local time = lfs.attributes(path, "modification")
	return time ~= nil -- 存在最后一次修改时间则文件存在
end

function Lib.copyFile(existingFilePath, newFilePath)
	local file = io.open(existingFilePath, "rb")
	local data = file:read("*a")
	file:close()
	file = io.open(newFilePath, "wb")
	file:write(data)
	file:close()
end

function Lib.copyFiles(ofilePath, dfilePath)
	local mode = lfs.attributes(ofilePath, "mode", true)
	if mode == "directory" then
		if not Lib.fileExists(dfilePath) then
			lfs.mkdir(dfilePath)
		end
		for it in lfs.dir(ofilePath) do
			if it ~= '.' and it ~= ".." then
				local path = Lib.combinePath(ofilePath, it)
				Lib.copyFiles(path, Lib.combinePath(dfilePath, it))
			end
		end
	elseif mode == "file" then
		local file = io.open(ofilePath, "r")
		local data = file:read("*a")
		file:close()
		file = io.open(dfilePath, "w+")
		file:write(data)
		file:close()
	end
end

--完整地复制整个文件夹及里面的内容
function Lib.full_copy_folder(existing_path, new_path)
	Lib.mkPath(new_path)
	for it in lfs.dir(existing_path) do
		if it ~= '.' and it ~= ".." then
			local path = Lib.combinePath(existing_path, it)
			local mode = lfs.attributes(path, "mode")
			if mode == "directory" then
				Lib.full_copy_folder(path, Lib.combinePath(new_path, it))
			elseif mode == "file" then
				Lib.copyFile(path, Lib.combinePath(new_path, it))
			end
		end
	end
end

function Lib.copyFileToZip(existingFilePath, newFilePath)
	local data = Lib.read_file(existingFilePath)
	local fromEngine = false
	local fileName = false
	local find, q = strfind(newFilePath, Root.Instance():getGamePath(),1,true)
	if not find then
		find, q = strfind(newFilePath, Root.Instance():getGamePath(),1,true)
		if find then
			fromEngine = true
		end
	end
	if find then
		fileName = strsub(path, q + 1)
	else
		fileName = path
	end
	if fromEngine then
		FileResourceManager:instance():WriteTextToMediaZipFile(fileName,data)
	else
		FileResourceManager:instance():WriteTextToGameZipFile(fileName,data)
	end
end


function Lib.reconstructName(name, colorful)
	if name == nil then
		return ""
	end
    name = name:gsub("\n", " ")
	if string.find(name, "&$") and string.find(name, "$&") then
		return name
	end
    if type(colorful) == "string" and #colorful ~= 0 then
        local colors = Lib.splitString(colorful, "-")
        while #name + 1 < #colors do
            table.remove(colors)
        end
        colorful = table.concat(colors, "-")
        name = string.format("&$[%s]$%s$&", colorful, name)
    end
    return name
end

--清除字符串首尾的“空白\r\t\n”等字符
function Lib.stringTrim(str)
    return string.gsub(str, "^%s*(.-)%s*$", "%1")
end

--此方法切割的字符串自动过滤空字符串
function Lib.splitString(str, sep, to_number)
	local res = {}
	string.gsub(str, '[^' .. sep .. ']+', function(w)
		if to_number then
			w = tonumber(w)
		end
		table.insert(res, w)
	end)
	return res
end

---@param str string
---@param reps string
---@param keep_blank boolean
---@param to_number boolean
function Lib.split(str, reps, keep_blank, to_number)
	local result = {}
	if str == nil or reps == nil then
		return result
	end

	keep_blank = keep_blank or false
	if keep_blank then
		local startIndex = 1
		while true do
			local lastIndex = string.find(str, reps, startIndex)
			if not lastIndex then
				table.insert(result, string.sub(str, startIndex, string.len(str)))
				break
			end
			table.insert(result, string.sub(str, startIndex, lastIndex - 1))
			startIndex = lastIndex + string.len(reps)
		end
	else
		string.gsub(str, '[^' .. reps .. ']+', function(w)
			table.insert(result, w)
		end)
	end

	to_number = to_number or false
	if to_number then
		for i = 1, #result do
			result[i] = tonumber(result[i])
		end
	end

	return result
end

--此方法切割的字符串包含空字符串
function Lib.splitIncludeEmptyString(str, sep)
	local res = {}
	string.gsub(str, '[^' .. sep .. ']*', function(w)
		table.insert(res, w)
	end)
	return res
end
function Lib.toFileName(path)
	local pos = nil
	local init = 0
	repeat
		pos = string.find(path, "[/\\]", init+1)
		init = pos or init
	until pos == nil
	return string.sub(path, init+1)
end
function Lib.toFileDirName(path)
	local pos = nil
	local init = 0
	repeat
		pos = string.find(path, "[/\\]", init+1)
		init = pos or init
	until pos == nil

	if init == 0 then
		return "./"
	else
		return string.sub(path, 0, init)
	end
end

function Lib.toThousandthString(value)
	assert(tonumber(value), value)
	local str = tostring(math.floor(tonumber(value)))
	if str:len() < 4 then
		return str
	end
    if str:len() >= 4 then
        str = tostring(math.floor(tonumber(str)/1000).."k")
    end
	str = str:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if str:sub(1,1) == "," then
		str = str:sub(2)
	end
	return str
end

function Lib.assemblyString(_table, value)
	local txt = tostring(value)
	if not _table then
		return txt
	end
	local res = {}
	for t in string.gmatch(txt,"%d") do
		table.insert(res, _table[t] or t)
	end
	txt = table.concat(res)
	return txt
end

function Lib.s2v(str)
    if not str or type(str) ~= "string" then
        return
    end
    return loadstring("return " .. str)()
end

--间隔preTime循环执行指定函数count次数
function Lib.loop(preTime, count, func)
	local timeIndex = 0
	if not func then
		return
	end

	World.Timer(preTime, function()
		timeIndex = timeIndex + 1
		if timeIndex > count then
			return false
		end
		func()
		return true
	end)
end

--ui缓动函数
function Lib.uiTween(ui, PropertyObj, time, finishBackF)
	local timerList = {}
	local timeIndex = 0
	local function clearAllTimer()
		for k, timeF in pairs(timerList) do
			timerList[k]()
			timerList[k] = nil
		end
	end

	local function arrayToString(array)
		return "{" .. table.concat( array, ",") .. "}"
	end

	local function toDoSetValue(PropertyName, curValue, addValue)
		local setValueString
		local setValue = {}
		if type(curValue) == "table" then
			for k, v in pairs(curValue) do
				setValue[k] = curValue[k] + addValue[k] * timeIndex
			end
			setValueString = arrayToString(setValue)
		else
			setValue = curValue + addValue * timeIndex
			setValueString = tostring(setValue)
		end
		ui:SetProperty(PropertyName, setValueString)
		return true
	end

	local function timerToSetValue(PropertyName, curValue, targetValue)
		local addValue = {}

		if type(curValue) == "table" then
			for k, v in pairs(curValue) do
				addValue[k] = (targetValue[k] - v) / time
			end
		else
			addValue = (targetValue - curValue) / time
		end
		local timerF = World.Timer(1, toDoSetValue, PropertyName, curValue, addValue)
		table.insert(timerList, timerF)
	end

	for PropertyName, targetValue in pairs(PropertyObj) do
		local valueString = ui:GetPropertyString(PropertyName)
		local s2vF = loadstring("return "..valueString)

		local curValue
		if s2vF then
			curValue = s2vF()
		elseif tonumber(valueString) then
			curValue = tonumber(valueString)
		end
		timerToSetValue(PropertyName, curValue, targetValue)
	end

	World.Timer(1, function()
		timeIndex = timeIndex + 1
		if timeIndex > time then
			clearAllTimer()
			if finishBackF then
				finishBackF()
			end
			return false
		end
		return true
	end)
end

function Lib.switchNum(number, integer)
	assert(tonumber(number), number)
	local res = tonumber(number / 1000)
    if res >= 1 and res < 1000 then
        return string.format("%s%s", integer and floor(res) or res, integer and "K+" or "K")
    elseif res >= 1000 and res < 1000000 then
        return string.format("%s%s", integer and floor(res / 1000) or res / 1000, integer and "M+" or "M")
    elseif res >= 1000000 then
        return string.format("%s%s", integer and floor(res / 1000000) or res / 1000000, integer and "B+" or "B")
    end
	return tostring(number)
end

-- 6543210 -> 6.543.210 格式
function Lib.numberFormatString(number, delimiter)
    if not number then
        return "0"
    end
    local str = tostring(number)
    local result = ""
    while true do
        local count = #str
        if count > 3 then
            result = (delimiter or ".") .. string.sub(str, count - 2, count) .. result
            str = string.sub(str, 1, count - 3)
        else
            result = str .. result
            break
        end
    end
    return result
end

function Lib.combinePath(...)
	local tmp = {}
	for _, path in ipairs({...}) do
		if (path ~= "") then
			table.insert(tmp, path)
		end
	end

	return Lib.normalizePath(table.concat(tmp, "/"))
end

function Lib.normalizePath(path)
	path = string.gsub(string.gsub(path, "\\", "/"), "(/+)", "/")

	local head = string.sub(path, 1, 1) == "/"
	local tail = string.sub(path, -1) == "/"

	local names = {}
	for name in string.gmatch(path, "([^/]+)") do
		if name == ".." and names[#names] and names[#names] ~= ".." then
			--assert(#names > 0)

			table.remove(names)
		elseif name ~= "." or not next(names) then
			table.insert(names, name)
		end
	end

	local ret = table.concat(names, "/")
	if head then
		ret = "/" .. ret
	end

	if #names > 0 and tail then
		ret = ret .. "/"
	end

	return ret
end

function Lib.rmdir(path)
    if lfs.attributes(path, "mode") == "directory" then
        local function _rmdir(path)
			for entry in lfs.dir(path) do
				if entry ~= "." and entry ~= ".." then
					local curDir = path.. '/' .. entry
					local mode = lfs.attributes(curDir, "mode")
					if mode == "directory" then
						_rmdir(curDir.."/")
					elseif mode == "file" then
						os.remove(curDir)
					end
				end
			end
            lfs.rmdir(path)
        end
        _rmdir(path)
    end
end

function Lib.rootPrefix(path)
	if ( Root.platform() == Platform.WINDOWS ) then
		return ""
	else
		if path:find("/", 1, true) == 1 then
			return "/"
		end
		return ""
	end
end

function Lib.mkPath(path)
	path = string.gsub(string.gsub(path, "\\", "/"), "(/+)", "/")
	local curr_path = Lib.rootPrefix(path)
	for name in string.gmatch(path, "[^/]+") do
		curr_path = curr_path .. name .. "/"
		local mode = lfs.attributes(curr_path, "mode")
		if mode ~= "directory" then
			local ok, errcode = lfs.mkdir(curr_path)
			assert(ok, errcode)
		end
	end
end

function Lib.dir(dir, mode, isFullPath)
    local path = isFullPath and dir or Root.Instance():getGamePath() .. dir

    if lfs.attributes(path, "mode") == "directory" then
        local lnext, data = lfs.dir(path)
        local function mnext(data)
			--file 是文件名或者目录名
            local file = lnext(data)
            if not file then
                return nil
            end
            if file=="." or file==".." then
                return mnext(data)
            end
			--filePath 是绝对路径
            local filePath = path .. "/" .. file
            if mode and lfs.attributes(filePath, "mode") ~= mode then
                return mnext(data)
            end
            return file, filePath
        end
		return mnext, data
	else
		local find, q = strfind(path, Root.Instance():getGamePath(), 1, true)
		if not find then
			path = Root.Instance():getGamePath() .. dir
		end
		local dirName = Lib.getZipEntryName(path, true)
		--c++ zip的目录最后都带"/"
		if not Lib.stringEnds(dirName, "/") and dirName ~= "" then
			dirName = dirName .. "/"
		end
		local fileList = ZipResourceManager.Instance():getGameFilesInEntry(dirName)
		local count = #fileList
		local function archNext()
			if count == 0 then
				--print("No file or dir: ", dirName)
				return function()
				end, nil
			end
			local index = 0
			local function next()
				index = index + 1
				if index > count then
					--print("End dir!!!!!!!!!!!!!!!!!!!!!!!!!:" .. path)
					return nil
				end
				local file = fileList[index]
				local archive = ZipResourceManager.Instance():getArchByAbsPath(Lib.normalizePath(path.."/"..file))
				if not archive then
					print("no archive:" .. path.."/"..file, dirName)
					return nil
				end
				local filePath = dirName..file
				-- 模式是目录但是返回是文件或模式是文件返回不是文件的，都不符合要求
				if (mode == "directory" and archive:isFile(filePath)) or (mode == "file" and not archive:isFile(filePath)) then
					next()
				else
					-- 文件名或目录名和他们的绝对路径返回直接去掉最后的"/"
					if Lib.stringEnds(file, "/") then
						file = string.sub(file, 1, -2)
					end
					if Lib.stringEnds(filePath, "/") then
						filePath = string.sub(filePath, 1, -2)
					end
					return file, filePath
				end
			end
			return next
		end
		return archNext()
	end
end

function Lib.stringEnds(String,End)
    return String ~= nil and (End=='' or string.sub(String,-string.len(End))== End)
end

function Lib.dirExist(path)
	local mode = lfs.attributes(path, "mode")
	if mode and mode == "directory" then
		return true
	end
	return false
end

function Lib.getSubDirs(path, dir_list)
	local mode = lfs.attributes(path, "mode")
	if not mode or mode ~= "directory" then
		return
	end
	local function _getSubDirs(_path, _sub_dir)
		for file in lfs.dir(_path) do
			if file ~= "." and file ~= ".." and file ~= ".meta" then
				local sub_path = _path .. file .. '/'
				local mode = lfs.attributes(sub_path, "mode")
				if mode ~= nil and mode == "directory" then
					local sub_dir = _sub_dir .. file
					table.insert(dir_list, sub_dir)
					_getSubDirs(sub_path, sub_dir .. '/')
				end
			end
		end
	end
	_getSubDirs(path, "")
end

function Lib.showNumberUi(number, pos)
	-- body
	local wDh = 14 / 20
    local desktop = GUISystem.instance:GetRootWindow()
    local grid = GUIWindowManager.instance:CreateGUIWindow1("GridView", "123")
	grid:SetItemAlignment(1)
	local result = Blockman.instance:getScreenPos(pos)
	local parentWidth = 70 * 11 / result.c
    grid:SetArea({result.x, 0}, {result.y, 0}, {0, parentWidth}, {0, parentWidth / wDh})

	local numStr = tostring(number)
	local len = string.len(numStr)
	grid:InitConfig(1, 1, len)

	for i = 1, len do
		local num = numStr:sub(i, i)
		local item = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", string.format( "%d",i))
		item:SetImage("set:number_mla.json image:numStyle1_" .. num ..".png")
		grid:AddItem(item)
		local width = 0.9 / len
		-- local height = width / wDh
		item:SetWidth({width, 0})
		item:SetHeight({width, 0})
	end
	desktop:AddChildWindow(grid)
	return grid
end

function Lib.time2Seconds(hour, minute, second)
	return (hour or 0) * 3600 + (minute or 0) * 60 + (second or 0)
end

function Lib.timeFormatting(second)
	assert(tonumber(second), second)
    local timeHour = math.fmod(math.floor(second/3600), 24)
    local timeMinute = math.fmod(math.floor(second/60), 60)
    local timeSecond = math.fmod(second, 60)

    return timeHour, timeMinute, timeSecond
end

function Lib.sgn(number)
	number = assert(tonumber(number), tostring(number))
	if number > 0 then
		return 1
	elseif number < 0 then
		return -1
	else
		return 0
	end
end

function Lib.posAroundYaw(pos, rotationYaw)
	local yaw = math.rad(- rotationYaw)
	local c = math.cos(yaw)
	local s = math.sin(yaw)
	local x = pos.x * c + pos.z * s
	local z = pos.z * c - pos.x * s
	return Lib.v3(x,  pos.y, z)
end

function Lib.posAroundYawAndPitch(pos, rotationYaw, rotationPitch)
	local yaw = math.rad(- rotationYaw)
	local yc = math.cos(yaw)
	local ys = math.sin(yaw)
	local pitch = math.rad(- rotationPitch)
	local pt = math.tan(pitch)
	local x = pos.x * yc + pos.z * ys
	local z = pos.z * yc - pos.x * ys
	local y = pos.z * pt
	return Lib.v3(x, y, z)
end

local function find_in_dir(zp, srcDir, pat)
	for name in lfs.dir(srcDir, true) do
		if name ~= '.' and name ~= '..' then
			local fileattr = lfs.attributes(srcDir.."/"..name, "mode", true)
			--assert(type(fileattr) == "table")
			if fileattr == "directory" then
				find_in_dir(zp, srcDir.."/"..name, pat)
			else
				local dir_name = srcDir.."/"..name
				local path_name = string.gsub(dir_name, pat, "")
				misc.zip_add_file(zp, path_name, dir_name)
			end
		end
	end
end

function Lib.zip(filename, srcDir, desDir)
	local zp = misc.zip_open(desDir ..filename..".zip")

	find_in_dir(zp, srcDir .. filename, srcDir)
	misc.zip_close(zp)
end

function Lib.tbToCsvContent(tb)
	local header = tb.header
	local items = tb.items
	header = header or {}
	if #header == 0 then
		local keys = {}
		for _, item in ipairs(items) do
			for k in pairs(item) do
				keys[k] = true
			end
		end
		for k in pairs(keys) do
			table.insert(header, k)
		end
		table.sort(header)
	end

	local function to_array(item)
		local ret = {}
		for _, key in ipairs(header) do
			table.insert(ret, item[key] or "")
		end

		return ret
	end

	local out = misc.csv_encode(header) .. "\r\n"
	for i, v in ipairs(items) do
		local line = to_array(v)
		out = out .. misc.csv_encode(line) .. "\r\n"
	end
	return out
end

function Lib.write_csv(path, tb)
	local out = Lib.tbToCsvContent(tb)
	misc.write_utf8(path, out)
end

function Lib.getNextDayTime()
	local cur_timestamp = os.time()
	local one_hour_timestamp = 24*60*60
	local temp_time = cur_timestamp + one_hour_timestamp
	local temp_date = os.date("*t", temp_time)
	return os.time({year=temp_date.year, month=temp_date.month, day=temp_date.day, hour = 0})
end

function Lib.getItemBgImage(item)
	-- 道具背景图，具体实现可以由自定义脚本去覆盖这个方�
	return ""
end

function Lib.getItemEnchantColor(item)
	-- 道具附魔附加的光照值，具体实现可以由自定义脚本去覆盖这个方�
	return 1,1,1,1
end

function Lib.CreateStack()
	return Stack:Create()
end

function Lib.getRayTarget(len, random) -- just client use.
    local screenPos = {x=0, y=0}
    if random then
        screenPos = FrontSight.randomPointByRrange()
    end
	local ri = Root.Instance()
	screenPos.x = screenPos.x + ri:getRealWidth() / 2
	screenPos.y = screenPos.y + ri:getRealHeight() / 2
	local result = Blockman.instance:getRayTraceResult(screenPos,len or 150, false, true, true , {})
	return result.hitPos or result.farthest
end

function Lib.getTime()
	return misc.now_nanoseconds() / 1000000
end

local function random(n, m)
	math.randomseed(os.clock() * math.random(1000000,90000000) + math.random(1000000,90000000))
	return math.random(n, m)
end

function Lib.randomLetter(len)
	local rt = ""
	for i = 1, len do
		rt = rt .. string.char(random(97,122))
	end
	return rt
end

local function getByteCount(str, index)
    local curByte = string.byte(str, index)
    local byteCount = 1
    if curByte == nil then
        byteCount = 0
    elseif curByte > 0 and curByte <= 127 then
        byteCount = 1
    elseif curByte>=192 and curByte<=223 then
        byteCount = 2
    elseif curByte>=224 and curByte<=239 then
        byteCount = 3
    elseif curByte>=240 and curByte<=247 then
        byteCount = 4
    end
    return byteCount
end

function Lib.getStringLen(str)
    local len = 0
    local i = 1
    local lastCount = 1
    local byteList = {}
    repeat
        lastCount = getByteCount(str, i)
        i = i + lastCount
        if lastCount > 1 then
            len = len + 2
        else
            len = len + lastCount
        end
        table.insert(byteList, lastCount)
    until(lastCount == 0)
    return len, byteList
end

function Lib.subString(str, endIndex)
    local count = 0
    local index = 1
    local subStr = ""
    local subStrLen = 0
    local lastByte = 1
    while subStrLen <= endIndex and lastByte > 0 do
        lastByte = getByteCount(str, index)
        index = index + lastByte
        subStr = string.sub(str, 1, index - 1)
        subStrLen = Lib.getStringLen(subStr)
    end
    return string.sub(str, 1, index - lastByte - 1)
end

function Lib.rotate(pos, rotate)
	local pi = PI_DIV180
	local function rotateZ()
		local rz = rotate.z * PI_DIV180
		local resx = math.cos(rz) * pos.x + math.sin(rz) * pos.y
		local resy = math.cos(rz) * pos.y - math.sin(rz) * pos.x
		pos.x = resx
		pos.y = resy
	end
	local function rotateY()
		local ry = rotate.y * PI_DIV180
		local resx = math.cos(ry) * pos.x + math.sin(ry) * pos.z
		local resz = math.cos(ry) * pos.z - math.sin(ry) * pos.x
		pos.x = resx
		pos.z = resz
	end
	local function rotateX()
		local rx = rotate.x * PI_DIV180
		local resy = math.cos(rx) * pos.y + math.sin(rx) * pos.z
		local resz = math.cos(rx) * pos.z - math.sin(rx) * pos.y
		pos.y = resy
		pos.z = resz
	end
	local pos = Lib.tov3(pos)
	rotateZ()
	rotateX()
	rotateY()
end

--游戏初始化的时候初始化一个随机数种子，这里不再变�
function Lib.randomItemByWeight(num, pool, ifReduce)
	assert(type(num)=="number", "type num: " .. type(num))
	assert(type(pool)=="table", "type pool: " .. type(pool))
	assert(type(ifReduce)=="boolean", "type ifReduce: " .. type(ifReduce))
	if ifReduce then
		assert(Lib.getTableSize(pool) >= num, "random pool error")
	else
		assert(Lib.getTableSize(pool) >= 1, "random pool error")
	end
	local sumOfWeight = 0
	for _, v in pairs(pool) do
		sumOfWeight = sumOfWeight + v.weight
	end
	local result = {}

	local function randomItem()
		if ifReduce then
			sumOfWeight = 0
			for _, v in pairs(pool) do
				sumOfWeight = sumOfWeight + v.weight
			end
		end
		local rs = math.random(0, sumOfWeight)
		for index, item in pairs(pool) do
			--print(item.weight)
			rs = rs - item.weight
			local pItem = item
			if rs < 0 then
				return pItem, index
			end
		end
	end

	for i = 1, num do
		local item, index = randomItem()
		while item == nil do
			item, index = randomItem()
		end
		table.insert(result, item)
		if ifReduce then
			table.remove(pool, index)
		end
	end
	return result
end

---@param low number
---@param high number
function Lib.createArray(low, high)
	local result = {}
	for i = low, high do
		table.insert(result, i)
	end
	return result
end

---随机n个[low,high]范围的不重复的整�
---@param low number
---@param high number
---@param n number
function Lib.randomIntNoRepeat(low, high, n)
	local size = high - low + 1
	if n > size then
		return {}
	end

	local tb = Lib.createArray(low, high)

	local result = {}
	for i = 1, n do
		local index = math.random(#tb)
		tb[index], tb[#tb] = tb[#tb], tb[index]
		table.insert(result, tb[#tb])
		table.remove(tb)
	end
	return result
end

---判断tb表中是否包含值value
---@param tb table
---@param value any
function Lib.tableContain(tb, value)
	if type(tb) ~= "table" then
		return false
	end

	for _, v in pairs(tb) do
		if v == value then
			return true
		end
	end
	return false
end

function Lib.clampDegree(value)
	if math.abs(value) < 1 then
		return value
	end

	value = value % 360

	while(value > 360) do
		value = value - 360
	end

	while(value < 0) do
		value = value + 360
	end

	return value
end

function Lib.getNameByFullName(fullName)
	assert(type(fullName) == "string", fullName)
	local splitRet = Lib.splitString(fullName, "/")
	local len = #splitRet
	local name = len > 0 and splitRet[len]
	return name
end
---删除tb表中的某个值
---@param tb table
---@param value any
function Lib.tableRemove(tb, value)
	if type(tb) ~= "table" then
		return
	end
	for key, v in pairs(tb) do
		if v == value then
			if type(key) == "number" then
				table.remove(tb, key)
			else
				tb[key] = nil
			end
			break
		end
	end
end

function Lib.mergeArray(t1, t2, result)
	result = result or t1
	if result == t1 then
		for _, value in pairs(t2) do
			table.insert(t1, value)
		end
	else
		for _, value in pairs(t1) do
			table.insert(result, value)
		end
		for _, value in pairs(t2) do
			table.insert(result, value)
		end
	end
end

function Lib.mergeTable(t1, t2)
	for key, value in pairs(t2) do
		if type(value) == "table" then
			local _value = t1[key] or {}
			t1[key] = _value
			Lib.mergeTable(_value, value)
		else
			t1[key] = value
		end
	end
end

function Lib.getBoolProperty(key)
	return GlobalProperty.Instance():getBoolProperty(key)
end

function Lib.getIntProperty(key)
	return GlobalProperty.Instance():getIntProperty(key)
end

function Lib.getFloatProperty(key)
	return GlobalProperty.Instance():getFloatProperty(key)
end

function Lib.getStringProperty(key)
	return GlobalProperty.Instance():getStringProperty(key)
end

function Lib.setBoolProperty(key, value)
	GlobalProperty.Instance():setBoolProperty(key, value)
end

function Lib.setIntProperty(key, value)
	GlobalProperty.Instance():setIntProperty(key, value)
end

function Lib.setFloatProperty(key, value)
	GlobalProperty.Instance():setFloatProperty(key, value)
end

function Lib.setStringProperty(key, value)
	GlobalProperty.Instance():setStringProperty(key, value)
end

--from是主动触发的人/物，self是被动响应的物/区域等
function Lib.canMeetTheCondition(self, from, conditions)
	local compareFunc = {
		['=='] = function(a, b) return a == b end,
		['>='] = function(a, b) return a >= b end,
		['>'] = function(a, b) return a > b end,
		['<='] = function(a, b) return a <= b end,
		['<'] = function(a, b) return a < b end,
		['~='] = function(a, b) return a ~= b end,
		['!='] = function(a, b) return a ~= b end
	}

	local function tip(tip)
		if tip then
			if World.isClient then
				Client.ShowTip(3, tip, 40)
			elseif from.isPlayer then
				from:sendTip(3, tip, 40)
			end
		end
	end

	for _, condition in pairs(conditions or {}) do
		local obj = self
		local type = condition.type                 -- EntityValue, prop, func
		local value = condition.value               -- 具体的数值
		local objType = condition.objType           -- self, from
		local compareType = condition.compareType   -- 运算符
		local key = condition.key					-- 需要比较的属性key
		local args = condition.args	or {}			-- 自定义func的参数
		if objType and (objType == "other" or objType == "from") then
			obj = from
		end
		if not (type ~= nil and value ~= nil and compareType ~= nil and key ~= nil) then
			print("Lib.canMeetTheCondition config incorrect !!!")
			tip("config_error")
			return false
		end

		if type == "EntityValue" then
			if not compareFunc[compareType](obj:getValue(key), value) then
				tip(condition.tip)
				return false
			end
		end

		if type == "EntityProp" then
			if not compareFunc[compareType](obj:prop(key), value) then
				tip(condition.tip)
				return false
			end
		end
		if type == "func" then
			args = Lib.copy(args)
			if objType and (objType == "other" or objType == "from") then
				if self and self.objID then
					args[#args + 1] = self.objID
				end
			else
				if from and from.objID then
					args[#args + 1] = from.objID
				end
			end
			if not compareFunc[compareType](obj[key](obj, table.unpack(args)), value) then
				tip(condition.tip)
				return false
			end
		end
	end

	return true
end

function Lib.toPercentageColor(color)
	local pcolor = { r = 0, g = 0, b = 0, a = 0 }
	pcolor.r = color.r / 255.0
	pcolor.g = color.g / 255.0
	pcolor.b = color.b / 255.0
	pcolor.a = color.a / 255.0
	return pcolor
end

function Lib.toIntegerColor(color)
	local pcolor = { r = 0, g = 0, b = 0, a = 0 }
	pcolor.r = color.r * 255
	pcolor.g = color.g * 255
	pcolor.b = color.b * 255
	pcolor.a = color.a * 255
	return pcolor
end

function Lib.getZipEntryName(filePath,returnOriginalName)
	filePath = Lib.normalizePath(filePath)
	local relaPath = ZipResourceManager.Instance():getRelaPathByAbsPath(filePath)
	if relaPath ~= "" then
		return relaPath
	end
	local gamePath =  Lib.normalizePath(Root.Instance():getGamePath())
	local find, q = strfind(filePath, gamePath, 1, true)
	local entryName = false
	if find then
		entryName = strsub(filePath, q + 1)
	else
		if returnOriginalName then
			entryName = filePath
		else
			entryName = nil
		end
	end
	return entryName
end

---校验货币是否足够
---@param coinId number 货币Id，0=金魔方
---@param price number|BigInteger 价格
function Lib.checkMoney(player, coinId, price, disableRecharge)
	local currency = player:getCurrency(Coin:coinNameByCoinId(coinId), true)
	if currency.count >= price then
		return true
	end
	if World.isClient and not disableRecharge then
		if coinId <= 1 then
			Interface.onRecharge(1)
		else
			Lib.emitEvent(Event.EVENT_LACK_OF_CURRENCY, coinId, price - currency.count)
		end
	end
	return false
end

local PayLocks = {}
---支付货币接口
---@param player EntityServerPlayer 玩家对象
---@param uniqueId string|number 商品唯一ID 没有时不做 ExchangeItems 的数据上报
---消耗平台货币(魔方/金币)建议用number，消耗其他货币(绿钞..)建议用string，表示reason的意思
---@param coinId number 货币Id（0：金魔方 1：蓝魔方 2：金币 3~n:自定义coin.json）
---@param price number|BigInteger 价格
---@param callback function 支付接口回调，return false回滚订单，退钱
---CUBO埋点相关需求字段
---@param goodsNum number|string 购买商品数量 没有默认1
---@param reason number 货币变化的原因，枚举，游戏定义 默认 Define.ExchangeItemsReason.BuyShop
function Lib.payMoney(player, uniqueId, coinId, price, callback, goodsNum, reason)
	if World.isClient then
		return
	end
	local key = tostring(player.platformUserId) .. "-" .. uniqueId
	if PayLocks[key] then
		return
	end
	if price <= 0 or ((coinId==0) and (os.getenv("startFromWorldEditor") or (string.sub(World.GameName or "",-1) == "b"))) then
		callback(true)
		GameAnalytics.OnPlayerCostMoneyExchangeItems(player, uniqueId, coinId, price, goodsNum, reason)
		return
	end
	if not Lib.checkMoney(player, coinId, price) then
		callback(false)
		return
	end
	if coinId <= 2 then
		PayLocks[key] = true
		AsyncProcess.BuyGoods(player.platformUserId, tonumber(uniqueId) or 1, coinId, price, nil, function(_, ret, _)
			PayLocks[key] = nil
			local callbackResult = callback(ret)
			if ret then
				Lib.emitEvent(Event.EVENT_PAY_MONEY_SUCCESS, player, coinId, price)
				GameAnalytics.OnPlayerCostMoneyExchangeItems(player, uniqueId, coinId, price, goodsNum, reason)
			end
			return callbackResult
		end)
		return
	end
	local coinName = Coin:coinNameByCoinId(coinId)
	player:payCurrency(coinName, price, false, false, uniqueId)
	Lib.emitEvent(Event.EVENT_PAY_MONEY_SUCCESS, player, coinId, price)
	callback(true)
	GameAnalytics.OnPlayerCostMoneyExchangeItems(player, uniqueId, coinId, price, goodsNum, reason)
end

function Lib.printSubString(org)
	local string = require("string")
	local orgLen = string.len(org)
	local index = 0
	while(index < orgLen) do
		local cur = string.sub(org, index, index + 1024)
		index = index + 1025
		Lib.logError("print string", cur)
	end
end

function Lib.getCallTag()
	local debugInfo = debug.getinfo(3)
	local fileName = debugInfo.source or "UNKNOW_SOURCE"
	if debugInfo.source then
		fileName = debugInfo.source
	end
	local srcLine = debugInfo.currentline or "UNKNOW_LINE"
	return fileName .. ":" .. srcLine
end

--check if a number/value is nan
function Lib.checkNumberValueIsNan(value)
	if not value then
		return true
	end

	if type( value ) == "number" then
		if value ~= value then
			return true
		end
	else
		Lib.logWarning("warning:checkNumberValueIsNan need a number parameter!!",type( value ))
		return false
	end

	return false
end

function Lib.jointParts(partList)
	if not partList or #partList < 2 then
		Lib.logWarning("joint Parts must more than 2")
		return
	end
	local fristPart = partList[1]
	for i = 2, #partList do
		local fixedConstraint = Instance.Create("FixedConstraint")
		local part = partList[i]
		fixedConstraint:setProperty("slavePartID", tostring(part:getInstanceID()))
		fixedConstraint:setParent(fristPart)
	end
end

function Lib.XPcall(func, errorLog, ...)
	local ok, ret = xpcall(func, debug.traceback, ...)
	if not ok then
		ret = "Lib.XPcall error!!! " .. (errorLog or "") .. ".\n" .. ret
		Lib.logError(ret)
	end
	return ok, ret
end


function Lib.replaceStringUTF8(str, pos, replace)
	return Lib.subStringUTF8(str, 1, pos - 1) .. replace .. Lib.subStringUTF8(str, pos + 1)
end

--截取中英混合的UTF8字符串，endIndex可缺省
function Lib.subStringUTF8(str, startIndex, endIndex)
	if startIndex < 0 then
		startIndex = Lib.subStringGetTotalIndex(str) + startIndex + 1;
	end

	if endIndex ~= nil and endIndex < 0 then
		endIndex = Lib.subStringGetTotalIndex(str) + endIndex + 1;
	end

	if endIndex == nil then
		return string.sub(str, Lib.subStringGetTrueIndex(str, startIndex));
	else
		return string.sub(str, Lib.subStringGetTrueIndex(str, startIndex), Lib.subStringGetTrueIndex(str, endIndex + 1) - 1);
	end
end

--获取中英混合UTF8字符串的真实字符数量
function Lib.subStringGetTotalIndex(str)
	local curIndex = 0;
	local i = 1;
	local lastCount = 1;
	repeat
		lastCount = Lib.subStringGetByteCount(str, i)
		i = i + lastCount;
		curIndex = curIndex + 1;
	until(lastCount == 0);
	return curIndex - 1;
end

function Lib.subStringGetTrueIndex(str, index)
	local curIndex = 0;
	local i = 1;
	local lastCount = 1;
	repeat
		lastCount = Lib.subStringGetByteCount(str, i)
		i = i + lastCount;
		curIndex = curIndex + 1;
	until(curIndex >= index);
	return i - lastCount;
end

--返回当前字符实际占用的字符数
function Lib.subStringGetByteCount(str, index)
	local curByte = string.byte(str, index)
	local byteCount = 1;
	if curByte == nil then
		byteCount = 0
	elseif curByte > 0 and curByte <= 127 then
		byteCount = 1
	elseif curByte>=192 and curByte<=223 then
		byteCount = 2
	elseif curByte>=224 and curByte<=239 then
		byteCount = 3
	elseif curByte>=240 and curByte<=247 then
		byteCount = 4
	end
	return byteCount;
end


--[[--

输出格式化字符串

~~~ lua

printf("The value = %d", 100)

~~~

@param string fmt 输出格式
@param [mixed ...] 更多参数

]]
function Lib.printf(fmt, ...)
	print(string.format(tostring(fmt), ...))
end

--[[--

检查并尝试转换为数值，如果无法转换则返回 0

@param mixed value 要检查的值
@param [integer base] 进制，默认为十进制

@return number

]]
function Lib.checknumber(value, base)
	return tonumber(value, base) or 0
end

--[[--

检查并尝试转换为整数，如果无法转换则返回 0

@param mixed value 要检查的值

@return integer

]]
function Lib.checkint(value)
	return math.round(checknumber(value))
end

--[[--

检查并尝试转换为布尔值，除了 nil 和 false，其他任何值都会返回 true

@param mixed value 要检查的值

@return boolean

]]
function Lib.checkbool(value)
	return (value ~= nil and value ~= false)
end

--[[--

检查值是否是一个表格，如果不是则返回一个空表格

@param mixed value 要检查的值

@return table

]]
function Lib.checktable(value)
	if type(value) ~= "table" then value = {} end
	return value
end

--[[--

如果表格中指定 key 的值为 nil，或者输入值不是表格，返回 false，否则返回 true

@param table hashtable 要检查的表格
@param mixed key 要检查的键名

@return boolean

]]
function Lib.isset(hashtable, key)
	local t = type(hashtable)
	return (t == "table" or t == "userdata") and hashtable[key] ~= nil
end

function Lib.boxBound(v1, v2)
	return {
		x = math.min(v1.x, v2.x),
		y = math.min(v1.y, v2.y),
		z = math.min(v1.z, v2.z)
	},
	{
		x = math.max(v1.x, v2.x),
		y = math.max(v1.y, v2.y),
		z = math.max(v1.z, v2.z)
	}
end

function Lib.isSameTable(t1, t2) -- deep compare
	if t1 == t2 then
		return true
	end
	local t1Empty = not next(t1)
	local t2Empty = not next(t2)
	if t1Empty and t2Empty then
		return true
	end
	if t1Empty ~= t2Empty then
		return false
	end
	for i, v in pairs(t1) do
		local t2i = t2[i]
		if t2i == nil then
			return false
		end
		if type(v) ~= "table" then
			if t2i ~= v then
				return false
			end
		elseif not Lib.isSameTable(v, t2i) then
			return false
		end
	end
	return true
end

function Lib.parseUdimString(content)
    -- 用来解析"{{0,18},{0,70},{0,19},{0,80}}"格式的字符串
    local parse = "[^{*}$]+"
    local udims = {}
    content = content:gsub(" ", "")	--用于去掉字符串中的空格
    local result = content:match(parse)
    while true do
        if not result then
            return #udims > 0 and udims or result
        end
        udims[#udims + 1] = result
        local _, subEndIndex = content:find(parse)
        subEndIndex = subEndIndex + 3
        content = "{" .. content:sub(subEndIndex, #content)
		result = content:match(parse)
	end
end

function Lib.deserializerStrV3(str)
	if not str then
		return {x = 0, y = 0, z = 0}
	end
	if type(str)~="string" then
		Lib.logWarning(" Lib.deserializerStrV3 params must be string. Now is: ", Lib.v2s(str))
		return str
	end
	local x, y, z = string.match(str, "x:([-%d%.]+) y:([-%d%.]+) z:([-%d%.]+)")
	return { x = tonumber(x) or 0, y = tonumber(y) or 0, z = tonumber(z) or 0}
end

function Lib.deserializerStrQuaternion(str)
	if not str then
		return {w = 1, x = 0, y = 0, z = 0}
	end
	if type(str)~="string" then
		Lib.logWarning(" Lib.deserializerStrQuaternion params must be string. Now is: ", Lib.v2s(str))
		return str
	end
	local w, x, y, z = string.match(str, "w:([-%d%.]+) x:([-%d%.]+) y:([-%d%.]+) z:([-%d%.]+)")
	return { w = tonumber(w) or 0, x = tonumber(x) or 0, y = tonumber(y) or 0, z = tonumber(z) or 0}
end

--[[--

查找tbSortedArray排序数组中第一个大于val的元素下标，若无返回#tbSortedArray + 1

@param table tbSortedArray 要查找的数组
@param mixed val 要查找数值
@param mixed key 要检查的键名

@return integer

]]
function Lib.upper_bound(tbSortedArray, val, key)
	local right = #tbSortedArray
	local left = 1
	local mid = math.floor((left + right)/2)
	while (left < mid + 1) do
		if (tbSortedArray[mid][key] <= val) then
			left = mid+1
			mid = math.floor((left + right)/2)
		else
			if (left == right) then
				return left
			end
			right = mid
			mid = math.floor((left + right)/2)
		end
	end
	return mid + 1
end

--[[--

查找tbSortedArray排序数组中第一个不小于val的元素下标，若无返回#tbSortedArray + 1

@param table tbSortedArray 要查找的数组
@param mixed val 要查找数值
@param mixed key 要检查的键名

@return integer

]]
function Lib.lower_bound(tbSortedArray, val, key)
	local right = #tbSortedArray
	local left = 1
	local mid = math.floor((left + right)/2)
	while (left < mid + 1) do
		if (tbSortedArray[mid][key] < val) then
			left = mid+1
			mid = math.floor((left + right)/2)
		else
			if (left == right) then
				return left
			end
			right = mid
			mid = math.floor((left + right)/2)
		end
	end
	return mid + 1
end

-- {v1, v2, ...} -> {[v1] = 1, [v2] = 2, ...}
function Lib.Vector2Map(vector)
	local ret = {}
	for i, v in ipairs(vector) do
		ret[v] = i
	end
	return ret
end

RETURN()
