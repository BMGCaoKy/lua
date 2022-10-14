-- https://www.iana.org/assignments/telnet-options/telnet-options.xhtml

local lfs = require("lfs")
local misc = require("misc")
local cjson = require("cjson")
local ts = require("telnetserver")
---@type setting
local setting = require("common.setting")
local TelnetServer = ts.mt
local oldPrint = L("oldPrint", print)
local servers = L("servers", {})
local historyPath = L("historyPath")
local debugEnv = setmetatable({}, { __index = _G})
local reportData = L("reportData")
local reportTime = L("reportTime", 0)
local REPORT_SERVER = "47.243.80.43"
local curDir = L("curDir", lfs.currentdir())
local pathList = L("pathList", {})
local remotedebug = require "common.debug.remotedebug"
local attachedSessions = L("attachedSessions", {})

local M = L("M", {})

debugEnv.curServer = nil
debugEnv.w = World.CurWorld

function TelnetServer:writeline(...)
	local arg = table.pack(...)
	for i = 1, arg.n do
		arg[i] = tostring(arg[i]):gsub("\n", "\r\n")
	end
	self:write(table.concat(arg, "\t").."\r\n")
end

function TelnetServer:print(...)
	oldPrint("[DebugPort]", ...)
	self:writeline(...)
end

local function p(...)
	debugEnv.curServer:writeline(...)
end
debugEnv.p = p
function debugEnv.print(...)
	oldPrint(...)
	p(...)
end
function debugEnv.pv(value, maxLevel)
	p(Lib.v2s(value, maxLevel))
end
function debugEnv.o(id)
	return World.CurWorld:getObject(id)
end

function debugEnv.part(id)
	return Instance.getByRuntimeId(id)
end

local function readHistory()
	local file = io.open(historyPath)
	if not file then
		return {}
	end
	local lines = {}
	for line in file:lines() do
		lines[#lines+1] = line
	end
	file:close()
	return lines
end

local function addHistory(line)
	local file = io.open(historyPath, "a+")
	if file then
		file:write(line.."\n")
		file:close()
	end
end

local function dofunc(serverInfo, func, msg)
	local server = serverInfo.server
	if not func then
		server:print(msg)
		return
	end
	print = debugEnv.print
	local ok, msg = xpcall(func, traceback)
	print = oldPrint
	if not ok then
		server:print(msg)
	end
end

local cmds = {}

function cmds:d(value)
	dofunc(self, load(value, "@(DebugCmd)", nil, debugEnv))
end

function cmds:i(value)
	self.isREPLMode = true
	self.isMultilineStatement = false
	self.incompleteStatement = ''
end

function cmds:f(value)
	if not value then
		p("need filename!")
		return
	end
	dofunc(self, loadfile(value, nil, debugEnv))
end

function cmds:pf(value)
	if not value then
		p("Profiler is "..(Profiler.inited and "on" or "off"))
	elseif value == "dump" then
		p(Profiler:dumpString())
	elseif value == "on" then
		Profiler:init()
	elseif value == "off" then
		Profiler:reset()
	else
		p("useage: pf [dump|on|off]")
	end
end

local function printScene(scene)
	local root = scene:getRoot()
	local runtimeID = root:getRuntimeID()
	local class = root.className
	local name = root:getName()
	local id = root.id

	local runtimeIDLenMax = math.max(string.len("[RT-Id]"), tostring(runtimeID):len())
	local classLenMax = math.max(string.len("[Class]"), tostring(class):len())
	local parentIDLenMax = string.len("[Parent]")
	local nameLenMax = math.max(string.len("[Name]"), tostring(name):len())
	local idLenMax = math.max(string.len("[ID]"), tostring(id):len())

	local list = {{ runtimeID, class, 0, name, id }}
	for _, curPart in pairs(root:getDescendants()) do
		if not curPart:isValid() then
			goto continue
		end
		local runtimeID = curPart:getRuntimeID()
		local class = curPart.className
		local parent = curPart:getParent()
		local parentID = parent:getRuntimeID()
		local name = curPart:getName()
		local id = curPart.id
		runtimeIDLenMax = math.max(runtimeIDLenMax, tostring(runtimeID):len())
		classLenMax = math.max(classLenMax, tostring(class):len())
		parentIDLenMax = math.max(parentIDLenMax, tostring(parentID):len())
		nameLenMax = math.max(nameLenMax, tostring(name):len())
		idLenMax = math.max(idLenMax, tostring(id):len())
		list[#list + 1] = { runtimeID, class, parentID, name, id }
		::continue::
	end
	p(string.format("%"..tostring(runtimeIDLenMax).."s %-"..tostring(classLenMax).."s %-"..tostring(parentIDLenMax).."s %-"..tostring(nameLenMax).."s %-"..tostring(idLenMax).."s",
		"[RT-Id]", "[Class]", "[Parent]", "[Name]", "[ID]"))
	local fmt = "%"..tostring(runtimeIDLenMax).."d %-"..tostring(classLenMax).."s %-"..tostring(parentIDLenMax).."d %-"..tostring(nameLenMax).."s %-"..tostring(idLenMax).."d"
	for _, t in ipairs(list) do
		p(string.format(fmt, t[1], t[2], t[3], t[4], t[5]))
	end
end

function cmds:scene(value)
	local manager = World.CurWorld:getSceneManager()
	if value then
		local scene = manager:getScene(value)
		printScene(scene)
	else
		local scenes = manager:getAllScene()
		p(string.format("           [scene id]\t[class]"))
		for _, scene in ipairs(scenes) do 
			p(string.format(" %20d\t%-20s", scene:getID(), scene:getRoot().className))
		end
	end
end


local function show_pretty_info(infos)
	local keys = {}
	for k, _ in pairs(infos) do
		table.insert(keys, k)
	end
	table.sort(keys, function(x, y)
		return tostring(x) < tostring(y)
	 end)
	p("{")
	for _, key in pairs(keys) do
		p("  ["..'"' .. key ..'"' .."] = " .. '"' .. infos[key] .. '"')
	end
	p("}")
end

function cmds:part(value)
	if value then
		local curPart = Instance.getByRuntimeId(value)
		if not curPart then
			p("can not find part by RuntimeId: ", value)
			return
		end
		
		local infos = {}
		local includeAll = true
		curPart:getAllPropertiesAsTable(infos, includeAll)
		-- todo: 更换这里临时处理方案， 在cpp代码里id标脏处理
		if tonumber(infos["id"]) < 0 then -- 服务端instance属性集中id是未初始化的负值，为了方便调试这里重新get一下
			infos["id"] = tostring(curPart:getInstanceID());
		end
		infos.factoryKey = curPart:getScriptName()
		infos.runtimeID = curPart:getRuntimeID()
		show_pretty_info(infos)
	else
		local manager = World.CurWorld:getSceneManager()
		local scenes = manager:getAllScene()
		for _, scene in ipairs(scenes) do 
			printScene(scene)
		end
	end
end

local function openDebugDraw(debugDraw)
	if not debugDraw then
		return
	end
	if not debugDraw:isEnabled() then
		debugDraw:setEnabled(true)
	end
end

local function toBoolValue(value)
	if value == nil then
		return
	elseif value == "on" then
		return true
	elseif value == "off" then
		return false
	end
end

function cmds:da(value)
	local show_aabb = toBoolValue(value)
	if show_aabb == nil then
		p("args should be on or off")
		return
	end
	local debugDraw = DebugDraw.instance
	openDebugDraw(debugDraw)
    debugDraw:setDrawPartAABBEnabled(show_aabb)
end

function cmds:dc(value)
	local show_collision = toBoolValue(value)
	if show_collision == nil then
		p("args should be on or off")
		return
	end
	local debugDraw = DebugDraw.instance
	openDebugDraw(debugDraw)
	debugDraw:setDrawColliderEnabled(show_collision)
end


function cmds:o(value)
	for _, obj in ipairs(World.CurWorld:getAllObject()) do
		p(obj.objID, obj:getCfgName(), obj.map, obj.isEntity and obj.name or "", Lib.tov3(obj:getPosition() or {}), obj)
	end
end

function cmds:p(value)
	for _, entity in ipairs(World.CurWorld:getAllEntity()) do
		if entity.isPlayer then
			p(entity.objID, entity:getCfgName(), entity.map, entity.name or "", Lib.tov3(entity:getPosition() or {}), entity)
		end
	end
end

local function reload(hasChangeImage)
    local changed = {}
    for name, info in pairs(package.filelist) do
        local time = lfs.attributes(info.path, "modification")
        if time and time~=info.time then
            changed[#changed+1] = name
        end
    end
    print("changed lua file(s):", #changed)
    for _, name in ipairs(changed) do
        print("", name)
        package.loaded[name] = nil
        require(name)
    end
	local changed = setting:reload()
	if World.isClient then
		ResLoader:reload(changed, hasChangeImage)
	end
	if #changed>0 then
		Player.Reload()
		Coin.Reload()
		Shop.Reload()
        Commodity.Reload()
		if not World.isClient then 
			GM.updateAllPlayer()
		end
	end
	World.Reload(changed)
    print("changed config file(s):", #changed)
    for _, name in ipairs(changed) do
        print("", name)
    end

	if World.isClient then           --ui files
		local uiChanged = {}
		for uiName, uiInfo in pairs(UIMgr.uiFileList) do
			local uiTime = lfs.attributes(uiInfo.path, "modification")
			if uiTime and uiTime ~= uiInfo.time then
				uiChanged[#uiChanged + 1] = uiName
				UIMgr:reload(uiName)	
			end
		end
		print("changed ui window file(s):", #uiChanged)
	end

	for _, v in pairs(Config) do
		if type(v) == "table" then
			if v.reload then
				v:reload()
			end
		end
	end
end

function cmds:r(value)
	print = debugEnv.print
	reload(value)
	print = oldPrint
end

function cmds:R(value)
	print = debugEnv.print
	M.AutoReload()
	print = oldPrint
end

function cmds:bake(maxLightMode)
	print = debugEnv.print
	if World.isClient then 
		World.CurMap:bakeLightAndSave(maxLightMode, true)
	end
	print = oldPrint
end

function cmds:h(value)
	local lines = readHistory()
	local h = math.tointeger(value)
	if h and h>=1 and h<=#lines then
		local tb = self
		tb.text = lines[h]
		tb.cursor = #tb.text + 1
		tb.history = h
	else
		for i, line in ipairs(lines) do
			p(string.format("%d. %s", i, line))
		end
	end
end

local function AttachPlayer(tb, player)
	if tb.server then
		tb.server:writeline("attach player:", player)
	end
	local sessionId = 1
	while attachedSessions[sessionId] do
		sessionId = sessionId + 1
	end
	attachedSessions[sessionId] = true
	tb.player = player
	tb.attachedSessionId = sessionId
	player:AttachDebugPort(tb.attachedSessionId)
end

local function DetachPlayer(tb)
	if not tb.player then
		return
	end
	if tb.server then
		tb.server:writeline("detach player")
	end
	tb.player:DetachDebugPort(tb.attachedSessionId)
	attachedSessions[tb.attachedSessionId] = nil
	tb.attachedSessionId = nil
	tb.player = nil
end

function cmds:a(value)
	local server = self.server
	if World.isClient~=false then
		server:writeline("for server only!")
		return
	end
	if not value or value=="" then
		DetachPlayer(self)
		return
	end
	local obj = World.CurWorld:getObject(tonumber(value))
	if not obj or not obj.isPlayer then
		server:writeline("player not found:", value)
		return
	end
	AttachPlayer(self, obj)
end

function cmds:l(value)
	local server = self.server
	if not value or value=="" then
		curDir = lfs.currentdir()
		pathList = {
			Root.Instance():getRootPath(),
			Root.Instance():getGamePath(),
			Root.Instance():getWriteablePath(),
		}
		server:writeline(" curent:", curDir)
		server:writeline("1. root:", pathList[1])
		server:writeline("2. game:", pathList[2])
		server:writeline("3. conf:", pathList[3])
		return
	end
	if value=="." then
		value = curDir
	elseif value==".." then
		local i = curDir:find("[/\\][^/\\]+[/\\]?$")
		if i then
			value = curDir:sub(1, i-1)
		else
			value = curDir
		end
	elseif tonumber(value) then
		value = pathList[tonumber(value)] or value
	end
	if value:sub(1,1)~="/" and value:sub(2,2)~=":" then
		if curDir:sub(-1)~="/" and curDir:sub(-1)~="\\" then
			value = curDir .. "/" .. value
		else
			value = curDir .. value
		end
	end
	if value:sub(2)==":" then
		value = value .. "/"
	end
	local mode = lfs.attributes(value, "mode")
	if not mode then
		server:writeline("can't find path:", value)
		return
	end
	if mode=="file" then
		local file = io.open(value)
		if not file then
			server:writeline("can't open file:", value)
			return
		end
		server:writeline("show file:", value)
		server:writeline(file:read("a"))
		file:close()
		return
	end
	if mode~="directory" then
		server:writeline("unknown file type:", mode)
		return
	end
	server:writeline(" curent:", value)
	local list = {}
	for name in lfs.dir(value) do
		if name ~= "." and name ~= ".." then
			local attr = lfs.attributes(value .. "/" .. name)
			if attr then
				local index = #list + 1
				list[index] = name
				local text = string.format("%3d.  ", index) .. os.date("%Y-%m-%d %H:%M:%S ", attr.modification)
				if attr.mode=="directory" then
					server:writeline(text .. string.format("%10s [%s]", "-", name))
				else
					server:writeline(text .. string.format("%10d %s", attr.size, name))
				end
			end
		end
	end
	curDir = value
	pathList = list
end

function cmds:q(value)
	DetachPlayer(self)
	servers[self.server] = nil
	self.server:close()
	self.server = nil
end

function cmds:ce(value)
	local server = self.server
	if not value or value=="" then
		server:writeline("need the obj ID")
		return
	end
	local entity = World.CurWorld:getObject(tonumber(value))
	if not entity or not entity.isPlayer then
		server:writeline("player not found:", value)
		return
	end
	-- level / exp
	if entity:getValue("level") then
		entity:setValue("level",1)
	end
	if entity:getValue("exp") then
		entity:setValue("exp",0)
	end
	-- skill
	local studySkillMap = entity:data("skill").studySkillMap or {}
	local skillMap = studySkillMap["studySkills"]
	local equipSkills = studySkillMap["equipSkills"]
	for name,v in pairs(skillMap or {}) do
		local skill = Skill.Cfg(name)
		if skill.isActive then
			skillMap[name] = nil
		end
		if skill.isPassive then
			local buffCfg = skill.buffCfg
			skillMap[name] = nil
			local buff = entity:getTypeBuff("fullName",buffCfg)
			if buff then
				entity:removeBuff(buff)
			end
		end
	end
	studySkillMap["studySkills"] = {}
	studySkillMap["equipSkills"] = {}
	local vars = entity.vars
	if vars then
		vars.entitySkill = {}
		vars.entitySkill[1] = {}
		vars.entitySkill[2] = {}
	end
	entity:syncSkillMap()
	entity:syncStudySkillMap()
	-- tray bag
	--local trays = entity:tray():query_trays(Define.TRAY_TYPE.BAG)
	--for _, tray in pairs(trays or {}) do
	--	local slots = tray:query_items()
	--	for slot, item in pairs(slots) do
	--		tray:remove_item(slot)
	--	end
	--end
end

function cmds:se(value)
	local server = self.server
	if not value or value=="" then
		server:writeline("need the obj ID")
		return
	end
	local entity = World.CurWorld:getObject(tonumber(value))
	if not entity or not entity.isPlayer then
		server:writeline("player not found:", value)
		return
	end
	entity:saveDBData()
end

function cmds:m(value)
	local mri = require "common.util.MemoryReferenceInfo"
	mri.m_cConfig.m_bAllMemoryRefFileAddTime = false
	local args = Lib.split(value, " ")
	if #args == 0 or #args == 1 then
		local name = args[1] or "memory_snapshot"
		collectgarbage("collect")
		mri.m_cMethods.DumpMemorySnapshot("./", name, -1)
		return
	end
	if #args == 2 then
		mri.m_cMethods.DumpMemorySnapshotComparedFile("./", "Compared", -1,
				string.format("./LuaMemRefInfo-All-[%s].txt", args[1]),
				string.format("./LuaMemRefInfo-All-[%s].txt", args[2]))
	end
end

function cmds:poco_start()
	local poco = require("autotest.poco.poco_manager")
	poco:init_server(15004)
	p('[DebugPort] poco server started.')
end

function cmds:poco_stop()
	local poco = require("autotest.poco.poco_manager")
	poco:stop_server()
	p('[DebugPort] poco server stopped.')
end

function cmds:help(value)
	local server = self.server
	server:writeline()
	server:writeline("DebugPort usage:")
	server:writeline("  i       ,enter REPL mode. call 'exit()' to leave")
	server:writeline("  d str   ,do lua script.")
	server:writeline("  f file  ,do lua file.")
	server:writeline("  o       ,show all map object.")
	server:writeline("  p       ,show all players.")
	server:writeline("  r bool  ,reload all new file,has change image? 0 or 1,default=0.")
	server:writeline("  R       ,start/stop auto reload.")
	server:writeline("  bake bool ,rebake forceRecalculate map block light and save,maxLightMode=0?1")
	server:writeline("  a [id]  ,attach player.")
	server:writeline("  h [n]   ,command history.")
	server:writeline("  l path  ,list dir or show file.")
	server:writeline("  q       ,exit debug.")
	server:writeline("  ce [id] ,clear entity all active/passive skill ,level and tray.")
	server:writeline("  se [id] ,save the entity data(win).")
	server:writeline("  pf [dump|on|off] ,profiler operations.")
	server:writeline("  da [on|off] ,show aabb.")
	server:writeline("  dc [on|off] ,show collision.")
	server:writeline("  help    ,this message.")
	server:writeline("  m       ,lua memory snapshot dump.")
	server:writeline("  poco_start, start poco server for Airtest.")
	server:writeline("  poco_stop, stop poco server.")
end

local CC_Home = string.char(27, 91, 49, 126)
local CC_Del = string.char(27, 91, 51, 126)
local CC_End = string.char(27, 91, 52, 126)
local CC_Up = string.char(27, 91, 65)
local CC_Down = string.char(27, 91, 66)
local CC_Right = string.char(27, 91, 67)
local CC_Left = string.char(27, 91, 68)

local function addText(tb, text)
    local i = tb.cursor
    tb.text = tb.text:sub(1, i-1) .. text .. tb.text:sub(i)
    tb.cursor = i + #text
end

local ByteFunc = {
	[0] = function(tb)
		return 1, true
	end,
	[8] = function(tb)
		local c = tb.cursor - 1
		if c>=1 then
			tb.text = tb.text:sub(1, c-1) .. tb.text:sub(c+1)
			tb.cursor = c
		end
		return 1, false
	end,
	[10] = function(tb)
		local nb = tb.buff:byte(2)
		if nb==13 or nb==0 then
			return 2, true
		else
			return 1, true
		end
	end,
	[13] = function(tb, index)
		local nb = tb.buff:byte(2)
		if nb==10 or nb==0 then
			return 2, true
		else
			return 1, true
		end
	end,
	[27] = function(tb)
		if #tb.buff==1 then
			tb.text = ""
			tb.cursor = 1
			return 1, false
		end
		local cc3 = tb.buff:sub(1, 3)
		local cc4 = tb.buff:sub(1, 4)
		if cc3==CC_Left then
			local c = tb.cursor - 1
			if c>=1 then
				tb.cursor = c
			end
			return 3, false
		elseif cc3==CC_Right then
			local c = tb.cursor + 1
			if c<=#tb.text+1 then
				tb.cursor = c
			end
			return 3, false
		elseif cc3==CC_Up then
			local lines = readHistory()
			local h = tb.history or (#lines+1)
			if h>1 then
				h = h - 1
				tb.text = lines[h] or ""
				tb.cursor = #tb.text + 1
				tb.history = h
			end
			return 3, false
		elseif cc3==CC_Down then
			local h = tb.history
			if h then
				local lines = readHistory()
				if h>=#lines then
					h = nil
					tb.text = ""
					tb.cursor = 1
				else
					h = h + 1
					tb.text = lines[h]
					tb.cursor = #tb.text + 1
				end
				tb.history = h
			end
			return 3, false
		elseif cc4==CC_Del then
			local c = tb.cursor
			tb.text = tb.text:sub(1, c-1) .. tb.text:sub(c+1)
			return 4, false
		elseif cc4==CC_Home then
			tb.cursor = 1
			return 4, false
		elseif cc4==CC_End then
			tb.cursor = #tb.text + 1
			return 4, false
		end
		return #cc3, false
	end,
	[127] = function(tb)
		local c = tb.cursor
		tb.text = tb.text:sub(1, c-1) .. tb.text:sub(c+1)
		return 1, false
	end,
	[255] = function(tb)
		local buff = tb.buff
		if #buff<2 then
			return false
		end
		local b = buff:byte(2)
		if b==255 then
			addText(tb, string.char(255))
			return 2, false
		end
		if b~=250 then
			print("[DebugPort] unknown code:", b)
			return 2, false
		end
		local sub = ""
		local iac = false
		for i = 3, #buff do
			b = buff:byte(i)
			if iac then
				if b==255 then
					sub = sub .. string.char(b)
				elseif b==240 then
					return i, sub
				else
					print("[DebugPort] unknown sub code:", b)
					return i, false
				end
			elseif b==255 then
				iac = true
			else
				sub = sub .. string.char(b)
			end
		end
		return false
	end,
}

local function addBuffText(tb, index)
    if index<=1 then
        return false
    end
    addText(tb, tb.buff:sub(1, index-1))
    tb.buff = tb.buff:sub(index)
    return true
end

local function readline(tb)
	local buff, running = tb.server:readbuff()
	buff = buff or ''
	tb.buff = tb.buff .. buff
	if tb.buff == '' then
		return nil, running
	end
    local index = 1
	while index<=#tb.buff do
		local b = tb.buff:byte(index)
		local func = ByteFunc[b]
        if func then
			addBuffText(tb, index)
			local len, lok = func(tb, index)
			if not len then
				break
			end
			tb.buff = tb.buff:sub(len+1)
			if lok then
				return lok, running
			end
			index = 1
		else
			index = index + 1
		end
	end
    addBuffText(tb, index)
    return false, running
end

local function writeInput(tb)
	if not tb.server then
		return
	end
	local text = tb.text
	local sp = tb.inputLen - #text
	if sp<0 then
		sp = 0
	end
	local prompt = ""
	local player = tb.player
	if player then
		if player:isValid() then
			prompt = prompt .. string.format("[%d] ", player.objID)
		else
			tb.player = nil
		end
	end
	if tb.isREPLMode then
		prompt = prompt .. "i"
	end
	if tb.isMultilineStatement then
		prompt = prompt .. ">>> "
	else
		prompt = prompt .. "> "
	end


	tb.server:write(string.rep(CC_Up, tb.inputRow) .. string.char(13) .. prompt .. text .. string.rep(" ", sp+1) .. string.char(8))
	tb.inputLen = #text
	local cursor = tb.cursor + #prompt - 1
	tb.inputRow = math.floor(cursor / tb.screenWidth)
	tb.server:write(string.rep(CC_Up, math.floor((tb.inputLen+sp+#prompt) / tb.screenWidth) - tb.inputRow) .. string.char(13) .. string.rep(CC_Right, cursor % tb.screenWidth))
end

local function playerCmdRet(server, msg, isREPLMode_, isMultilineStatement_)
	local tb = servers[server]
	if not tb then
		return
	end
	tb.isREPLMode = isREPLMode_
	tb.isMultilineStatement = isMultilineStatement_
	server:print(msg)
	writeInput(tb)
end

local function evaluateLuaStatement(serverInfo, line)
	local server = serverInfo.server
	serverInfo.isMultilineStatement = false
	serverInfo.incompleteStatement = serverInfo.incompleteStatement .. line .. '\n'
	local func, msg = load('return ' .. serverInfo.incompleteStatement, "@(DebugCmd)", "t", debugEnv)
	if not func then
		if msg:sub(-#'<eof>') == '<eof>' then
			serverInfo.isMultilineStatement = true
			return
		end
		func, msg = load(serverInfo.incompleteStatement, "@(DebugCmd)", "t", debugEnv)
		if not func then
			if msg:sub(-#'<eof>') == '<eof>' then
				serverInfo.isMultilineStatement = true
				return
			else
				server:print(msg)
				serverInfo.incompleteStatement = ''
				return
			end
		end
	end
	print = debugEnv.print
	local oldExit = rawget(debugEnv, "exit")
	debugEnv.exit = function()
		serverInfo.isREPLMode = false
	end
	local results = { xpcall(func, traceback) }
	debugEnv.exit = oldExit
	print = oldPrint
	if not results[1] then
		server:print(results[2])
	else
		server:print(table.unpack(results, 2))
	end
	serverInfo.incompleteStatement = ''
end

local function docmd(serverInfo, line, needWriteInput)
	local server = serverInfo.server
	print("[DebugPort] docmd:", line)
	if serverInfo.isREPLMode then
		local player = serverInfo.player
		if player and player:isValid() then
			print("[DebugPort] doPlayerCmd:", player.objID, player.name, line)
			player:doClientCmd(line, serverInfo.attachedSessionId, playerCmdRet, server)
			return
		end
		evaluateLuaStatement(serverInfo, line)
	else
		local i = line:find(" ")
		local key, value
		if i then
			key = line:sub(1, i - 1)
			value = line:sub(i + 1)
		else
			key = line
		end
		local player = serverInfo.player
		if player and player:isValid() then
			if key~="a" and key~="q" and key~="h" then
				print("[DebugPort] doPlayerCmd:", player.objID, player.name, line)
				player:doClientCmd(line, serverInfo.attachedSessionId, playerCmdRet, server)
				return
			end
		end
		local func = cmds[key]
		if func then
			if not World.isClient and World.isClient~=nil and World.serverType~="gamecenter" then
				Me = M.serverPlayerPorts[M.port] or {}---@type EntityClientMainPlayer
			end
			debugEnv.curServer = server
			local ok, msg = xpcall(func, traceback, serverInfo, value)
			if not ok then
				server:print(msg)
			end
		elseif line ~= "" then
			server:writeline("unknown cmd: ", key)
		end
	end
	if needWriteInput then
		writeInput(serverInfo)
	end
end

local function dosub(tb, data)
	local code = data:byte(1)
	if code==31 then	-- Negotiate About Window Size
		local x1, x2 = data:byte(2, 3)
		tb.screenWidth = x1 * 256 + x2
		print("screenWidth", tb.screenWidth)
	else
		print("[DebugPort] unknown sub option:", code)
	end
end

local function _addr(addr)
	local i = assert(addr:find(":"), addr)
	return addr:sub(1, i-1), tonumber(addr:sub(i+1))
end

M.serverPlayerPorts = {}
function M:setServerPlayerPort(player, port)
	self.serverPlayerPorts[port] = player
end

function M.Tick()
	remotedebug.Tick()
	if M.filewatch then
		local changed = false
		for _, h in ipairs(M.filewatch) do
			while misc.win_filewatch_next(h) do
				changed = true
			end
		end
		if changed then
			reload()
		end
	end
	if not M.listen then
		return
	end
	local sock, addr = ts.accept(M.listen)
	if sock then
		print("[DebugPort] client connected:", addr, sock)
		local server = ts.newserver(sock)
		local serverInfo = {
			server = server,
			addr = addr,
			buff = "",
			text = "",
            cursor = 1,
			history = nil,
			inputLen = 0,
			inputRow = 0,
			screenWidth = 999,
		}
		servers[server] = serverInfo
		server:setoption(1, false, true)	-- echo
		server:setoption(3, false, true)	-- SUPPRESS-GO-AHEAD
		server:setoption(31, true, true)	-- Telnet Window Size
		server:setoption(34, true, false)	-- Linemode
		--server:setoption(24, true, true)	-- Terminal-Type
		--server:rawwrite(string.char(255,250,24,1,255,240))
		server:start()
		if World.isClient then
			local player = Player.CurPlayer
			if player then
				server:writeline(string.format("[port:%d] Client of %s[%d]", M.port, player.name, player.objID))
			else
				server:writeline(string.format("[port:%d] Client without player", M.port))
			end
		elseif World.isClient==nil then
			server:writeline(string.format("[port:%d] Tool", M.port))
		elseif World.serverType=="gamecenter" then
			server:writeline(string.format("[port:%d] Center", M.port))
		else
			local player = M.serverPlayerPorts[M.port] or {name = "unknown", objID = 0}
			server:writeline(string.format("[port:%d] Server of %s[%d]", M.port, player.name, player.objID))
		end
		server:writeline("dir:", lfs.currentdir())
		server:writeline("game:", World.GameName, M.engineVersion)
		docmd(serverInfo, "help", true)
	end
	for server, tb in pairs(servers) do
		for _ = 1, 10 do
			-- server might be closed in the last loop
			if tb.server == nil then
				break
			end
			local data, running = readline(tb)
			if data==true then
				local text = tb.text
				if text~="" then
					addHistory(text)
				end
				tb.cursor = #text + 1
				writeInput(tb)
				server:writeline()
				tb.text = ""
				tb.cursor = 1
				tb.inputLen = 0
				tb.inputRow = 0
				tb.history = nil
				docmd(tb, text, true)
			elseif data~=nil then
				if type(data)=="string" then
					dosub(tb, data)
				end
				writeInput(tb)
			elseif not running then
				print("[DebugPort] client closed:", tb.addr)
				DetachPlayer(tb)
				servers[server] = nil
				server:close()
				tb.server = nil
				break
			elseif not data then
				break
			end
		end
	end
	if not M.udp then
		return
	end
	local now = misc.now_microseconds()
	if now >= reportTime + 10*1000000 then
		ts.sendto(M.udp, "\0", REPORT_SERVER, 10086)
		reportTime = now
	end
	local buf, addr = ts.recvfrom(M.udp)
	if not buf then
		return
	end
	local packet = cjson.decode(buf)
	print("[DebugPort] udp cmd", addr)
	Lib.pv(packet)
	if packet.typ=="info" then
		ts.sendto(M.udp, cjson.encode(reportData), _addr(addr))
	elseif packet.typ=="debug" then
		local text = cjson.encode({typ="debug", port=remotedebug.Start()})
		ts.sendto(M.udp, text, _addr(addr))
	elseif packet.typ=="trans" then
		M.Transfer(packet.targetAddr, _addr(addr) .. ":" .. packet.serverPort)
	end
end

function M.Init(path, from, to)
	assert(not M.listen, "already inited!")
	historyPath = path
	to = to or from
	local listen = ts.create()
	for port = from, to do
		if ts.listen(listen, "127.0.0.1", port) then
			M.port = port
			print("[DebugPort] start listen:", port)
			break
		end
	end
	M.udp = ts.create(true)
	ts.noblock(M.udp, true)
	if not M.port then
		ts.close(listen)
		print("[DebugPort] start failed!", from, to)
		return false
	end
	ts.listen(M.udp, "0.0.0.0", M.port, true)
	ts.noblock(listen, true)
	M.listen = listen
	local engineVersion = EngineVersionSetting.getEngineVersion()
	M.engineVersion = engineVersion
	local isClient = World.isClient
	if isClient==false then
		M.gamePort = Server.CurServer:getServerPort()
	end
	local data = misc.sys_info()
	if isClient and not _WINDOWS then
--		local info = cjson.decode(CGame.instance:getShellInterface():getClientInfo())
--		data.sys = info.os_version
--		data.mfrs = info.manufacturer
--		data.device = info.device
	end
	data.port = M.port
	data.dir = lfs.currentdir()
	data.game = World.GameName
	data.gamePort = M.gamePort
	data.client = isClient
	data.engineVersion = engineVersion
	if isClient then
		data.userId = CGame.instance:getPlatformUserId()
	else
		data.serverType = World.serverType
	end
	ts.sendto(M.udp, misc.data_encode(data), REPORT_SERVER, 10086)
	reportData = data
	reportTime = misc.now_microseconds()

	local port = tonumber(os.getenv("DebugConnect"))
	if port then
		remotedebug.Connect(port)
	end

	return true
end

function M.Uninit()
	if M.listen then
		ts.close(M.listen)
		M.listen = nil
	end
	if M.udp then
		ts.close(M.udp)
		M.udp = nil
	end
end


function M.Transfer(addr1, addr2)
	local sock1 = ts.connect(_addr(addr1))
	local sock2 = ts.connect(_addr(addr2))
	print("begin transfer", addr1, "<=>", addr2)
	ts.transfer(sock1, sock2)
end

function M.Attach(sessionId)
	local fakeServer = { lines = {} }
	function fakeServer:writeline(...)
		local arg = table.pack(...)
		for i = 1, arg.n do
			arg[i] = tostring(arg[i]):gsub("\n", "\r\n")
		end
		self.lines[#self.lines + 1] = table.concat(arg, "\t") .. "\r\n"
	end
	function fakeServer:print(...)
		oldPrint("[DebugPort]", ...)
		self:writeline(...)
	end
	attachedSessions[sessionId] = {
		server = fakeServer,
		isREPLMode = false,
		isMultilineStatement = false,
		incompleteStatement = "",
	}
end

function M.Detach(sessionId)
	attachedSessions[sessionId] = nil
end

function M.DoCmd(sessionId, str)
	local session = attachedSessions[sessionId]
	local lines = {}
	session.server.lines = lines
	docmd(session, str, false)
	return table.concat(lines):sub(1, -3), session.isREPLMode, session.isMultilineStatement
end

function M.Reload(hasChangeImage)
	reload(hasChangeImage)
end

function M.AutoReload()
	if M.filewatch then
		for _, h in ipairs(M.filewatch) do
			misc.win_filewatch_stop(h)
		end
		M.filewatch = nil
		print("auto reload stoped.")
		return false
	end
	local dirs = {
		Root.Instance():getRootPath() .. "\\lua\\",
		Root.Instance():getGamePath() .. "\\",
	}
	M.filewatch = {}
	for i, dir in ipairs(dirs) do
		if dir:sub(2,2)~=":" then
			dir = curDir .. "\\" .. dir
		end
		dir = dir:gsub("/", "\\"):gsub("\\%.\\", "\\"):gsub("\\\\", "\\")
		M.filewatch[i] = misc.win_filewatch_start(dir)
		print("auto reload start", dir)
	end
	return true
end


RETURN(M)
