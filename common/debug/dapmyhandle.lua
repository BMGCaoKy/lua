local M = {}

local lfs = require("lfs")
local misc = require("misc")
local seri = require "seri"

local oldWinList = {}
local newWinList = {}

local typeDef = {}

M.TypeDef = typeDef


--[[
typeDef.["分页名"] = {
	-- item：树形结构中的一个节点，可以是table、string、userdata等任意形式，
	-- key：表达节点的字符串新式，用于协议传输

	GetRoot = function()	-- 获取根节点
		return {
			{item1, "显示名1"},
			{item2, "显示名2"},
			……
		}
	end,
	GetChild = function(item)	-- 获取子节点
		return {
			{item1, "显示名1"},
			{item2, "显示名2"},
			……
		}
	end,
	GetKey = function(item)	-- 根据节点获取key
		return key
	end,
	GetItem = function(key)	-- 根据key获取节点
		return item
	end,
	GetExpand = function(item)	-- 获取此节点是否可展开（既有子节点）
		return true or false
	end,
	GetImageIndex = function(item)	-- 获取节点图标，无此函数表示不支持
		return imageIndex	-- 要与ImageList索引（0起始）对应，-1表示无图标
	end,
	GetVisibility = function(item)	-- 获取此节点的隐藏情况（对应界面上树形节点旁边的勾选框），无此函数表示不支持
		-- -1、不支持隐藏
		-- 0、已隐藏
		-- 1、未隐藏
		return 1 or 0 or -1		-- （不是true、false）
	end,
	SetVisible = function(item, value)	-- 设置此节点的隐藏
		-- value: true or false	-- （不是1、0）
	end,
	GetRect = function(item)	-- 获取此节点的区域（用于显示框），无此函数表示不支持
		-- 特别的，当item=nil时：返回{left, top, right, bottom}表达总区域，返回nil表示不知道总区域
		return	{left, top, right, bottom}	-- 矩形框
					or
				{x, y, r}					-- 圆形框
					or
				nil							-- 不支持
	end,
	GetAttr = function(item)	-- 获取此节点的所有属性
		-- 显示值用于显示，纯string
		-- 编辑值用于编辑，纯string，省略时表示该字段只读
		--（编辑值与显示值不同是为了解决转义等问题，例如某字符串显示值“1\2”，编辑值为“1\\2”）
		return {
			{name1, "显示值1", "编辑值1"},
			{name2, "显示值2", "编辑值2"},
			……
		}
	end,
	SetAttr = function(item, key, value)	-- 设置此节点的一条属性（value为string）
		item[key] = value
	end,
	GetData = function(item)		-- 获取此节点的数据（较大的文本编辑框），无此函数表示不支持
		return "文本数据"
	end,
	SetData = function(item, value)	-- 设置此节点的数据
		item.data = value
	end,
	Order = 10,						-- 分页排序权重，小的靠左，大的靠右
	ImageList = {"icon1", "icon2"},	-- 图标列表，对应调试工具中已有的资源
}
]]


local function oldWinChildren(window, values)
	local last = window:GetChildCount() - 1
	for i = 0, last do
		local child = window:GetChildByIndex(i)
		local id = child:getId()
		oldWinList[id] = child
		values[#values+1] = {{child, false}, child:GetName()}
	end
end

local function newWinChildren(window, values)
	local last = window:getChildCount() - 1
	for i = 0, last do
		local child = window:getChildAtIdx(i)
		local id = child:getID()
		newWinList[id] = child
		values[#values+1] = {{child, true}, child:getName()}
	end
end

typeDef.UI = {
	GetRoot = function()
		local values = {}
		if not World.isClient then
			return values
		end
		if UI.root then
			newWinChildren(UI.root, values)
		end
		if UI._desktop then
			oldWinChildren(UI._desktop, values)
		end
		return values
	end,
	GetItem = function(key)
		local typ = key:sub(1, 4)
		local id = tonumber(key:sub(5))
		if typ=="old:" then
			return {oldWinList[id], false}
		end
		assert(typ=="new:", key)
		return {newWinList[id], true}
	end,
	GetChild = function(item)
		local values = {}
		if item[2] then
			newWinChildren(item[1], values)
		else
			oldWinChildren(item[1], values)
		end
		table.sort(values, function(a,b) return a[2]<b[2] end)
		return values
	end,
	GetKey = function(item)
		if item[2] then
			return "new:"..item[1]:getID()
		else
			return "old:"..item[1]:getId()
		end
	end,
	GetExpand = function(item)
		if item[2] then
			return item[1]:getChildCount() > 0
		else
			return item[1]:GetChildCount() > 0
		end
	end,
	GetVisibility = function(item)
		if item[2] then
			return item[1]:isVisible() and 1 or 0
		else
			return item[1]:IsVisible() and 1 or 0
		end
	end,
	SetVisible = function(item, value)
		if item[2] then
			item[1]:setVisible(value)
		else
			item[1]:SetVisible(value)
		end
	end,
	GetRect = function(item)
		if not item then
			return nil
		elseif item[2] then
			local rect = item[1]:getUnclippedOuterRect():get()
			return {rect.left, rect.top, rect.right, rect.bottom}
		else
			return item[1]:GetUnclippedOuterRect()
		end
	end,
	GetAttr = function(item)
		local values = {}
		if item[2] then
			for k, v in pairs(GUIManager:Instance():getWindowProperties(item[1].__window)) do
				values[#values+1] = {k, v, v}
			end
			values[#values+1] = {"_ID", "NW["..item[1]:getID().."]"}
		else
			for k, v in pairs(item[1]:GetAllProperties()) do
				values[#values+1] = {k, v, v}
			end
			values[#values+1] = {"_ID", "OW["..item[1]:getId().."]"}
		end
		table.sort(values, function(a,b) return a[1]<b[1] end)
		return values
	end,
	SetAttr = function(item, key, value)
		if item[2] then
			item[1]:setProperty(key, value)
		else
			item[1]:SetProperty(key, value)
		end
	end,
	Order = 10,
}


typeDef.Object = {
	GetRoot = function()
		return {
			{"f:npc", "Npc"},
			{"f:player", "玩家"},
			{"f:dropitem", "掉落物"},
			{"f:missile", "子弹"},
		}
	end,
	GetItem = function(key)
		if key:sub(1,2)=="f:" then
			return key
		else
			return World.CurWorld:getObject(tonumber(key))
		end
	end,
	GetChild = function(key)
		local values = {}
		if key=="f:npc" then
			for _, obj in ipairs(World.CurWorld:getAllEntity()) do
				if obj.platformUserId==0 then
					values[#values+1] = {obj, string.format("%s[entity:%s]", obj.name, obj:getCfgName())}
				end
			end
		elseif key=="f:player" then
			for _, obj in ipairs(World.CurWorld:getAllEntity()) do
				if obj.platformUserId~=0 then
					values[#values+1] = {obj, string.format("%s[entity:%s]", obj.name, obj:getCfgName())}
				end
			end
		elseif key=="f:dropitem" then
			for _, obj in ipairs(World.CurWorld:getAllObject()) do
				if obj.isDropItem then
					values[#values+1] = {obj, "item:" .. obj:item():cfg().fullName}
				end
			end
		elseif key=="f:missile" then
			for _, obj in ipairs(World.CurWorld:getAllObject()) do
				if obj.isMissile then
					values[#values+1] = {obj, "missile:" .. obj:getCfgName()}
				end
			end
		end
		return values
	end,
	GetKey = function(object)
		if type(object)=="string" then
			return object
		end
		return tostring(object.objID)
	end,
	GetExpand = function(object)
		return type(object)=="string"
	end,
	GetVisibility = function(object)
		if type(object)=="string" then
			return -1
		end
		if not object.getActorHide then
			return -1
		end
		return object:getActorHide() and 0 or 1
	end,
	SetVisible = function(object, value)
		if object.setActorHide then
			object:setActorHide(not value)
		end
	end,
	GetRect = function(object)
		if type(object)~="table" then
			return nil
		end
		local pos = object:getPosition()
		return {pos.x, pos.z, 0.5}
	end,
	GetAttr = function(object)
		if type(object)=="string" then
			return {}
		end
		local values = {
			{"objID", tostring(object.objID)},
			{"类型", object.__name },
			{"配置", object:getCfgName() },
		}
		if object.isEntity then
			values[#values+1] = {"名字", object.name}
		end
		if object.isDropItem then
			values[#values+1] = {"道具", object:item():cfg().fullName}
		end
		local v3 = object:getPosition()
		local str = string.format("%s,%s,%s", v3.x, v3.y, v3.z)
		values[#values+1] = {"坐标", str, str}
		return values
	end,
	SetAttr = function(object, key, value)
		if key=="坐标" then
			if object.setPos then
				object:setPos(Lib.strToV3(value))
			else
				object:setPosition(Lib.strToV3(value))
			end
		end
	end,
	Order = 20,
}


local function toPath(key)
	return key=="" and "./" or key
end

typeDef["文件"] = {
	ImageList = {"file", "folder"},
	GetRoot = function()
		local root = Root.Instance()
		return {
			{toPath(root:getRootPath()), "引擎目录"},
			{toPath(root:getGamePath()), "游戏目录"},
			{toPath(root:getWriteablePath()), "日志目录"},
		}
	end,
	GetItem = function(key)
		return key
	end,
	GetChild = function(path)
		local values = {}
		local files = {}
		if lfs.attributes(path, "mode") ~= "directory" then
			return values
		end
		local pp = path
		if pp:sub(-1)~="/" then
			pp = pp .. "/"
		end
		for name in lfs.dir(path) do
			if name ~= "." and name ~= ".." then
				local p = pp .. name
				if lfs.attributes(p, "mode") == "directory" then
					values[#values+1] = {p, name}
				else
					files[#files+1] = {p, name}
				end
			end
		end
		table.sort(values, function(a,b) return a[2]<b[2] end)
		table.sort(files, function(a,b) return a[2]<b[2] end)
		for _, file in ipairs(files) do
			values[#values+1] = file
		end
		return values
	end,
	GetKey = function(path)
		return path
	end,
	GetExpand = function(path)
		if lfs.attributes(path, "mode")~="directory" then
			return false
		end
		local func, data, it = lfs.dir(path)
		return func(data, it)~=nil
	end,
	GetImageIndex = function(path)
		return lfs.attributes(path, "mode") == "directory" and 1 or 0
	end,
	GetAttr = function(path)
		local attr = lfs.attributes(path)
		if not attr then
			return {{"错误路径", path }}
		end
		local values = {
			{"路径", path },
			{"类型", attr.mode },
			{"修改时间", os.date("%Y-%m-%d %H:%M:%S ", attr.modification) },
			{"创建时间", os.date("%Y-%m-%d %H:%M:%S ", attr.change) },
		}
		if attr.mode=="file" then
			values[#values+1] = {"容量", tostring(attr.size) }
		end
		return values
	end,
	GetData = function(path)
		local MAX_SIZE = 1024 * 200
		local attr = lfs.attributes(path)
		if not attr or attr.mode~="file" or (attr.size or 0)>MAX_SIZE then
			return nil
		end
		local file = io.open(path, "rb")
		if not file then
			return nil
		end
		local buf = file:read("a")
		file:close()
		if #buf>MAX_SIZE then
			return nil
		end
		return misc.read_text(buf)
	end,
	SetData = function(path, value)
		misc.write_utf8(path, value)
	end,
	Order = 40,
}

local tableList = {}
local tableId = {}

local function v2c(v)
	local t = type(v)
	if t=="number" or t=="boolean" or t=="nil" then
		return tostring(v)
	elseif t=="string" then
		return string.format("%q",v)
	else
		return nil, t
	end
end

local function c2v(c)
	return assert(load("return "..c))()
end

local function getLuaChild(tb)
	local values = {}
	for k, v in pairs(tb) do
		if type(v)=="table" then
			local id = tableId[v]
			if not id then
				id = #tableList + 1
				tableList[id] = v
				tableId[v] = id
			end
			values[#values+1] = {v, v2c(k) or tostring(k)}
		end
	end
	table.sort(values, function(a,b) return a[2]<b[2] end)
	return values
end

typeDef["全局变量"] = {
	GetRoot = function()
		return getLuaChild(_G)
	end,
	GetItem = function(key)
		return assert(tableList[tonumber(key)], key)
	end,
	GetChild = getLuaChild,
	GetKey = function(tb)
		return tostring(tableId[tb])
	end,
	GetExpand = function(tb)
		return next(tb)~=nil
	end,
	GetAttr = function(tb)
		local values = {}
		for k, v in pairs(tb) do
			if type(v)~="table" then
				local kc = v2c(k)
				values[#values+1] = {kc or tostring(k), tostring(v), kc and (v2c(v) or "")}
			end
		end
		table.sort(values, function(a,b) return a[1]<b[1] end)
		return values
	end,
	SetAttr = function(tb, key, value)
		local k = c2v(key)
		local v = c2v(value)
		tb[k] = v
	end,
	Order = 30,
}

local function dataEncode(value)
	return misc.base64_encode(seri.serialize_string(value))
end

local function dataDecode(txt)
	return seri.deseristring_string(misc.base64_decode(txt))
end

local function readDataFile()
	if World.isClient then
		return nil
	end
	local url = Server.CurServer:getDataServiceURL()
	if url:sub(1, 6)~="local:" then
		return nil
	end
	local file = io.open(url:sub(7), "rb")
	if not file then
		return {}
	end
	local data = {}
	local text = misc.read_text(file:read("a"))
	file:close()
	local line, pos
	while true do
		line, pos = misc.csv_decode(text, pos)
		if line then
			data[line[1]] = dataDecode(line[2])
		end
		if not pos then
			return data
		end
	end
end

local function saveDataFile(data)
	local lines = {}
	for k, v in pairs(data) do
		lines[#lines + 1] = misc.csv_encode({k, misc.base64_encode(seri.serialize_string(v))})
	end
	lines[#lines + 1] = ""
	local url = Server.CurServer:getDataServiceURL()
	misc.write_utf16(url:sub(7), table.concat(lines, "\r\n"))
end

local function toLua(value, sp)
	local txt, typ = v2c(value)
	if txt then
		return txt
	end
	if typ~="table" then
		return nil
	end
	local nsp = sp .. "  "
	local list = {"{\r\n"}
	for k, v in pairs(value) do
		local kt = v2c(k)
		local vt = toLua(v, nsp)
		if not kt or not vt then
			return nil
		end
		list[#list+1] = string.format("%s[%s] = %s,\r\n", nsp, kt, vt)
	end
	if not list[2] then
		return "{}"
	end
	list[#list+1] = sp .. "}"
	return table.concat(list)
end

typeDef["本地数据"] = {
	GetRoot = function()
		local data = readDataFile()
		if not data then
			return {}
		end
		local values = {}
		for k, v in pairs(data) do
			values[#values+1] = {{v, data, {k}, nil}, tostring(k)}
		end
		table.sort(values, function(a,b) return a[2]<b[2] end)
		return values
	end,
	GetItem = function(key)
		local tb = dataDecode(key)
		local fileData = readDataFile()
		local data = assert(fileData)
		local parent = nil
		for i, k in ipairs(tb) do
			parent = data
			data = data[k]
			local t = type(data)
			assert(t=="table", t)
		end
		return {data, fileData, tb, parent}
	end,
	GetChild = function(item)
		local tb = item[3]
		local index = #tb + 1
		local values = {}
		for k, v in pairs(item[1]) do
			if type(v)=="table" then
				tb[index] = k
				values[#values+1] = {{v, item[2], {table.unpack(tb, 1, index)}, nil}, tostring(k)}
			end
		end
		table.sort(values, function(a,b) return a[2]<b[2] end)
		return values
	end,
	GetKey = function(item)
		return dataEncode(item[3])
	end,
	GetExpand = function(item)
		return next(item[1])~=nil
	end,
	GetAttr = function(item)
		local values = {}
		for k, v in pairs(item[1]) do
			if type(v)~="table" then
				local kc = v2c(k)
				values[#values+1] = {kc or tostring(k), tostring(v), kc and (v2c(v) or "")}
			end
		end
		table.sort(values, function(a,b) return a[1]<b[1] end)
		return values
	end,
	SetAttr = function(item, key, value)
		local k = c2v(key)
		local v = c2v(value)
		item[1][k] = v
		saveDataFile(item[2])
	end,
	GetData = function(item)
		return toLua(item[1], "")
	end,
	SetData = function(item, value)
		local tb = item[3]
		item[4][tb[#tb]] = c2v(value)
		saveDataFile(item[2])
	end,
	Order = 50,
}

local sceneManager = World.CurWorld:getSceneManager()

typeDef.Node = {
	GetRoot = function()
		local values = {}
		for index, scene in ipairs(sceneManager:getAllScene()) do
			values[index] = {scene:getRoot(), string.format("Map[%d]%s", scene:getID(), scene:getRoot().className)}
		end
		return values
	end,
	GetChild = function(item)
		local values = {}
		for i, node in ipairs(item:getAllChild()) do
			values[i] = {node, string.format("%s[%d]%s", node.TypeName, node:getInstanceID(), node:getName())}
		end
		return values
	end,
	GetKey = function(item)
		return tostring(item:getInstanceID())
	end,
	GetItem = function(key)
		return Instance.getByInstanceId(tonumber(key))
	end,
	GetExpand = function(item)
		return item:getChildrenCount() > 0
	end,
	GetVisibility = function(item)
		local alpha = item.materialAlpha
		if not alpha then
			return -1
		end
		return alpha>0 and 1 or 0
	end,
	SetVisible = function(item, value)
		item.materialAlpha = value and 1 or 0
		item:setUseCollide(value)
	end,
	GetRect = function(item)
		if not item then
			return nil
		elseif not item:isA("MovableNode") then
			return nil
		end
		local pos = item:getPosition()
		local size = item:getSize()
		return {pos.x, pos.z, (size.x+size.z)/2}
	end,
	GetAttr = function(item)
		local props = {}
		item:getAllPropertiesAsTable(props, true)
		local values = {
			{"_TypeName", item.TypeName},
			{"_ScriptName", item:getScriptName()},
			{"_InstanceId", tostring(item:getInstanceID())},
			{"_RuntimeId", tostring(item:getRuntimeID())},
		}
		for k, v in pairs(props) do
			values[#values+1] = {k, v, v}
		end
		table.sort(values, function(a,b) return a[1]<b[1] end)
		return values
	end,
	SetAttr = function(item, key, value)
		item:setProperty(key, value)
	end,
	Order = 15,
}

if World.isClient then
	typeDef["本地数据"] = nil
else
	typeDef.UI = nil
end

function M:TypeInfo(req)
	local values = {}
	for k, v in pairs(typeDef) do
		values[#values+1] = {
			name = k,
			checkBox = v.GetVisibility~=nil,
			imageList = v.ImageList,
			rectView = v.GetRect~=nil,
			rect = v.GetRect and v.GetRect(nil),
			order = v.Order or 100,
		}
	end
	table.sort(values, function(a,b) return a.order<b.order end)
	return {values = values}
end

local function getItem(args)
	local typ = assert(typeDef[args.type], args.type)
	if args.key then
		return typ, typ.GetItem(args.key)
	end
	return typ, nil
end

local function children2nodes(typ, list)
	local values = {}
	for i, info in ipairs(list) do
		local item = info[1]
		values[i] = {
			typ.GetKey(item),
			info[2],
			typ.GetExpand(item),
			typ.GetImageIndex and typ.GetImageIndex(item) or -1,
			typ.GetVisibility and typ.GetVisibility(item) or -1,
			typ.GetRect and typ.GetRect(item),
		}
	end
	return values
end

function M:GetTree(req)
	local typ, item = getItem(req.arguments)
	local list
	if item then
		list = typ.GetChild(item)
	else
		list = typ.GetRoot()
	end
	return {values = children2nodes(typ, list)}
end

function M:GetTrees(req)
	local args = req.arguments
	local typ = assert(typeDef[args.type], args.type)
	local values = {}
	for i, key in ipairs(args.keys) do
		local item = typ.GetItem(key)
		local list = typ.GetChild(item)
		values[i] = children2nodes(typ, list)
	end
	return {values = values}
end

function M:GetAttr(req)
	local typ, item = getItem(req.arguments)
	local body = {values={}}
	if not item then
		return body
	end
	if typ.GetAttr then
		body.values = typ.GetAttr(item)
	end
	if typ.GetData then
		body.data = typ.GetData(item)
	end
	if typ.GetRect then
		body.rect = typ.GetRect(item)
	end
	if typ.GetVisibility then
		body.visibility = typ.GetVisibility(item) or -1
	end
	return body
end

function M:SetAttr(req)
	local args = req.arguments
	local typ, item = getItem(args)
	typ.SetAttr(item, args.attr, args.value)
end

function M:SetData(req)
	local args = req.arguments
	local typ, item = getItem(args)
	typ.SetData(item, args.value)
end

function M:SetVisible(req)
	local args = req.arguments
	local typ, item = getItem(args)
	typ.SetVisible(item, args.value)
end

function M:GetLog(req)
	local pos = req.arguments.pos
	local path = Root.Instance():getLogPath()
	local size = assert(lfs.attributes(path, "size"), path)
	if size<=pos then
		return {}
	end
	local file = io.open(path, "rb")
	if not file then
		return {}
	end
	if file:seek("set", 1)==0 then	-- 64位错位BUG，临时规避
		file:seek(nil, Bitwise64.Or(Bitwise64.Sl(pos, 32), 0))
	else
		file:seek("set", pos)
	end
	local txt = file:read(size-pos)
	file:close()
	return {pos=size, log=txt}
end

local debugEnv = setmetatable({}, { __index = _G})
debugEnv.w = World.CurWorld
debugEnv.p = print
debugEnv.pv = Lib.pv
function debugEnv.o(id)
	return World.CurWorld:getObject(id)
end
debugEnv.OW = oldWinList
debugEnv.NW = newWinList
debugEnv.V = tableList

function M:DoCmd(req)
	local cmd = req.arguments.cmd
	print("DoCmd:", cmd)
	return assert(load(cmd, "@(DebugCmd)", nil, debugEnv))()
end

function M:CapScreen(req)
	local quality = req.arguments and req.arguments.quality or 80
	local jpg = CGame.Instance():captureScreen(quality)
	return { value = misc.base64_encode(jpg) }
end

function M:GetFile(req)
	local file = io.open(req.arguments.path, "rb")
	if not file then
		return {}
	end
	local data = file:read("a")
	file:close()
	return { value = misc.base64_encode(data) }
end

function M:SetFile(req)
	local file = assert(io.open(req.arguments.path, "w+b"))
	file:write(misc.base64_decode(req.arguments.data))
	file:close()
end

function M:TransferTo(req)
	self:beginTransfer(req)
end

function M:TransferEnd(req)
	self:stopTransfer(req)
end


return M
