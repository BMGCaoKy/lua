--[[
	自动测试接口
]]

local misc = require "misc"
local cjson = require "cjson"
local http = require "socket.http"
local ltn12 = require "ltn12"

local useNewUI = GUIManager:Instance():isEnabled()
local guiMgr = L("guiMgr", GUIManager:Instance())
local inputSystem = InputSystem.instance
local bm = Blockman.Instance()

local AT = AT

AT.LOG_INFO = 1
AT.LOG_WARNING = 2
AT.LOG_ERROR = 3

AT.serverUrl = "http://localhost:8081/"

AT.timer = nil
AT.thread = nil
AT._oldUIWindowOpenEventHandlerIdnex = nil


local function assertWindow(wnd, name)
	if not wnd then
		error(string.format("自动测试失败：找不到窗口 %s", name))
	end
end

local function clientInfo()
	local client = misc.sys_info()
	client.game = World.GameName
	client.engineVersion = EngineVersionSetting.getEngineVersion()
	client.userId = CGame.instance:getPlatformUserId()
	return client
end

local function closeTimer()
	if AT.timer then
		AT.timer()
		AT.timer = nil
	end
end

local function _onTimeout()
	assert(AT.timer)
	assert(AT.thread)
	closeTimer()
	coroutine.resume(AT.thread, "timeout")
end

local function isWindowVisible(wnd)
	if useNewUI then
		return wnd:isVisible()
	else
		return wnd:IsVisible()
	end
end

local function regTimeout(time)
	assert(not AT.timer)
	assert(AT.thread)
	assert(AT.thread == coroutine.running())
	AT.timer = World.Timer(time, _onTimeout)
end

local function touchPos(pos, up)
	local input = {
		type = InputType.TouchScreen,
		subtype = TouchScreenInputSubType[up and "TouchUp" or "TouchDown"],
		touches = {
			{ id = -1, position = guiMgr.logicPosToScreenPos(pos) }
		}
	}
	inputSystem:handleInput(input)
end

local function workThread(func)
	AT.WaitTime(1)
	AT.Report(xpcall(func, debug.traceback))
	AT.Stop()
	if AT.jobData then
		AT.Begin()
	end
end

local function doBegin(code, name)
	AT.include = {}
	local func, msg = code, nil
	if type(func) ~= "function" then
		func, msg = load(misc.read_text(code), "@" .. name)
		if not func then
			AT.Report(false, "AT.Begin 解析错误: " .. msg)
			return
		end
	end

	if useNewUI then
		UI:subscribeGlobalEvent("Window/Shown", function(name, args)
			local window = UI:getWindowInstance(args.window)
			AT.OnWndOpen(window.__windowName, window, true)
		end)
	end
	local _, index = Lib.subscribeEvent(Event.EVENT_OPEN_WINDOW, function(name)
		local window = UI._desktop:GetChildByName(name)
		AT.OnWndOpen(name, window, false)
	end)
	AT._oldUIWindowOpenEventHandlerIdnex = index

	AT.thread = coroutine.create(function()
		local ok, msg = xpcall(workThread, traceback, func)
		if not ok then
			perror(msg)
		end
	end)
	coroutine.resume(AT.thread, func)
end

function AT.AssertWindowClosed(...)
	return AT.CheckWindowVisible(false, ...)
end

function AT.AssertWindowsClosed(...)
	return AT.CheckWindowsVisible(false, ...)
end

function AT.AssertWindowOpen(...)
	return AT.CheckWindowVisible(true, ...)
end

function AT.AssertWindowsOpen(...)
	return AT.CheckWindowsVisible(true, ...)
end

function AT.Begin()
	assert(not AT.thread)
	local data, code, body = AT.CallAPI("getjob", {client=clientInfo()})
	if not data then
		print("AT.Begin error:", AT.serverUrl, code, body)
		return
	end
	if not data.ok then
		print("job all done!")
		return
	end
	AT.jobData = data
	doBegin(data.code, data.name)
end

function AT.LocalBegin(name)
	assert(not AT.thread)
	local data = AT.CallAPI("getinc", {name=name,isMain=true})
	if not data or not data.ok then
		error("AT.LocalBegin error:" .. name)
		return
	end
	AT.jobData = nil
	doBegin(data.code, name)
end

function AT.TempBegin(func)
	AT.jobData = nil
	doBegin(func, "TEMP")
end

function AT.Stop()
	if not AT.thread then
		return
	end

	closeTimer()

	if useNewUI then
		UI:unsubscribeGlobalEvent("Window/Shown")
	end

	AT.waitWndName = nil
	AT.thread = nil

	if AT._oldUIWindowOpenEventHandlerIdnex ~= nil then
		Lib.unsubscribeEvent(Event.EVENT_OPEN_WINDOW, AT._oldUIWindowOpenEventHandlerIdnex)
		AT._oldUIWindowOpenEventHandlerIdnex = nil
	end
end

function AT.Log(typ, screen, ...)
	print("AT.Log", typ, screen, ...)
	if not AT.jobData then
		return
	end
	local tb = table.pack(...)
	for i = 1, tb.n do
		tb[i] = tostring(tb[i])
	end
	local pic = nil
	if screen then
		pic = misc.base64_encode(CGame.Instance():captureScreen(80))
	end
	AT.CallAPI("jobmsg", {type=typ, txt=table.concat(tb,"\t"), token=AT.jobData.token, pic=pic})
end

function AT.LogInfo(...)
	AT.Log(AT.LOG_INFO, false, ...)
end

function AT.LogWarning(...)
	AT.Log(AT.LOG_WARNING, true, ...)
end

function AT.LogError(...)
	local tb = table.pack(...)
	for i = 1, tb.n do
		tb[i] = tostring(tb[i])
	end
	AT.Log(AT.LOG_ERROR, true, debug.traceback(table.concat(tb,"\t"), 2))
end

function AT.Report(ok, msg)
	print("AT.Report", ok, msg or "")
	if not ok then
		AT.Log(AT.LOG_ERROR, true, msg)
	end
	if AT.jobData then
		AT.CallAPI("jobdone", {ok = ok, token = AT.jobData.token})
	end
end

local function addRecord(...)
	local code = string.format(...)
	AT.record[#AT.record + 1] = code
	print("AT.Record +=", code)
end

local function recordWndClick(names, text)
	if not AT.record then
		return
	end
	local wndName = names[1]
	if wndName~=AT.lastWndName then
		addRecord("")
		addRecord('AT.WaitWindow("%s", 100)', wndName)
		AT.lastWndName = wndName
	end
	local now = World.Now()
	if now~=AT.lastClickTime then
		addRecord('AT.WaitTime(10)')
		AT.lastClickTime = now
	end
	if text then
		addRecord('AT.CheckWindowText("%s","%s")', text, table.concat(names, '","'))
	end
	addRecord('AT.ClickWindow("%s")', table.concat(names, '","'))
end

local function recordWndEdit(names, text)
	if not AT.record then
		return
	end
	addRecord("")
	addRecord('AT.WaitTime(10)')
	addRecord('AT.SetWindowText("%s","%s")', text, table.concat(names, '","'))
end

local function _onNewWndClick(name, args)
	local text = nil
	local window = args.window
	if window:getType()=="WindowsLook/StaticText" then
		text = window:getProperty("Text")
	end
	local names = {}
	while window:getParent() do
		table.insert(names, 1, window:getName())
		window = window:getParent()
	end
	if names[2]=="gm_board" or names[2]=="GM" then
		return
	end
	recordWndClick(names, text)
end

local function _onNewWndEdit(name, args)
	local window = args.window
	if window:getType()~="WindowsLook/Editbox" then
		return
	end
	local names = {}
	while window:getParent() do
		table.insert(names, 1, window:getName())
		window = window:getParent()
	end
	recordWndEdit(names, window:getProperty("Text"))
end

local function recordKeyPressing(key, press)
	if press then
		addRecord("")
	else
		addRecord('AT.WaitTime(10)')
	end
	addRecord('AT.SetKeyPressing("%s",%s)', key, press)
end

local lastPressingKey = {}

local function _checkKey()
	if not AT.record then
		return
	end
	local newPressingKey = {}
	for _, key in ipairs(bm:getAllPressingKey()) do
		newPressingKey[key] = true
		if not lastPressingKey[key] then
			recordKeyPressing(key, true)
		end
	end
	for key in pairs(lastPressingKey) do
		if not newPressingKey[key] then
			recordKeyPressing(key, false)
		end
	end
	lastPressingKey = newPressingKey
	return true
end

function AT.RecordBegin()
	print("AT.RecordBegin")
	assert(not AT.thread)
	assert(not AT.record)
	AT.record = {}
	if useNewUI then
		UI:subscribeGlobalEvent("Window/MouseClick", _onNewWndClick)
		UI:subscribeGlobalEvent("Window/TextChanged", _onNewWndEdit)
	end
	World.Timer(1, _checkKey)
end

function AT.RecordEnd(giveup)
	print("AT.RecordEnd", giveup)
	assert(AT.record)
	if not giveup then
		local data = AT.CallAPI("createscript", {code=table.concat(AT.record, "\r\n"), client=clientInfo()})
		if data then
			print("AT.RecordEnd file:", data.name)
		end
	end
	AT.record = nil
	AT.lastClickTime = nil
	AT.lastWndName = nil
	if useNewUI then
		UI:unsubscribeGlobalEvent("Window/MouseClick")
		UI:unsubscribeGlobalEvent("Window/TextChanged")
	end
end

function AT.RecordPos()
	print("AT.RecordPos")
	assert(AT.record)
	local pos = Me:getPosition()
	addRecord("")
	addRecord('AT.GMMoveTo(%f,%f,%f)', pos.x, pos.y, pos.z)
end

function AT.WaitTime(time)
	regTimeout(time)
	assert(AT.thread == coroutine.running())
	coroutine.yield()
end

function AT.WaitWindow(name, timeout, try)
	-- local window = useNewUI and UI:isOpenWindow(name)
	-- if window and window:isVisible() then
	-- 	print("AT.WaitWindow OK:", name)
	-- 	return true
	-- end
	-- if UI._desktop and UI._desktop:GetChildByName(name) then
	-- 	print("AT.WaitWindow OK:", name)
	-- 	return true
	-- end
	local wnd = AT.GetWindow(name)
	if wnd and isWindowVisible(wnd) then
		print("AT.WaitWindow OK:", name)
		return true
	end

	regTimeout(timeout)
	AT.waitWndName = name
	assert(AT.thread == coroutine.running())
	local ret = coroutine.yield()

	if ret == "wndOpen" then
		print("AT.WaitWindow OK:", name)
		return true
	end

	-- check again when time is out, maybe the window had already shown.
	if not wnd then
		wnd = AT.GetWindow(name)
	end
	if wnd and isWindowVisible(wnd) then
		print("AT.WaitWindow OK:", name)
		return true
	end

	if try then
		print("AT.WaitWindow FAILED: %s", name)
		return false
	end

	error("AT.WaitWindow 超时: " .. name)
end

local function _checkWnd(name, window, isNewWnd)
	if not AT.thread or AT.waitWndName~=name then
		return
	end
	if isNewWnd and not window:isVisible() then
		return
	end
	closeTimer()
	AT.waitWndName = nil
	coroutine.resume(AT.thread, "wndOpen")
end

function AT.OnWndOpen(name, window, isNewWnd)
	if not AT.thread or AT.waitWndName ~= name then
		return
	end
	if isNewWnd and not window:isVisible() then
		return
	end
	World.Timer(1, _checkWnd, name, window, isNewWnd)
end

on_error_reg("AutoTest", function (typ, msg)
	if not AT.thread then
		return
	end
	if coroutine.running()==AT.thread then
		return
	end
	local msg = "测试中其它协程报错：\r\n" .. msg .. "\r\n" .. debug.traceback(AT.thread)
	AT.Report(false, msg)
	AT.Stop()
	AT.Begin()
end)

function AT.GetWindow(wndName, ...)
	local isNewWnd = useNewUI and UI.root:isChildName(wndName)
	local window
	if isNewWnd then
		window = UI.root
	else
		window = UI._desktop
	end
	local args = {wndName, ...}
	for i, name in ipairs(args) do
		if isNewWnd then
			if type(name)=="string" then
				window = window:isChildName(name) and UI:getWindowInstance(window:getChildByName(name))
			else
				window = (name>=0 and name<window:getChildCount()) and UI:getWindowInstance(window:getChildAtIdx(name))
			end
		else
			if type(name)=="string" then
				window = window:child(name)
			else
				window = (name>=0 and name<window:GetChildCount()) and window:GetChildByIndex(name)
			end
		end
		if not window then
			return nil, "AT.GetWindow 找不到窗口: " .. table.concat(args, ".", 1, i)
		end
	end
	return window, isNewWnd
end

function AT.ClickWindow(...)
	local window, isNewWnd = assert(AT.GetWindow(...))
	if isNewWnd then
		local pos = window:getPixelPosition()
		local size = window:getPixelSize()
		local centerPos = {
			x = pos.x + size.width/2,
			y = pos.y + size.height/2,
		}
		touchPos(centerPos, false)
		AT.WaitTime(2)
		touchPos(centerPos, true)
	else
		window:TouchDown({x = 1, y = 1})
		window:TouchUp({x = 1, y = 1})
	end
	print("AT.ClickWindow OK:", table.concat({...}, "."))
end

function AT.GetWindowText(...)
	local window, isNewWnd = assert(AT.GetWindow(...))
	return isNewWnd and window:getProperty("Text") or window:GetText()
end

function AT.SetWindowText(text, ...)
	local window, isNewWnd = assert(AT.GetWindow(...))
	if isNewWnd then
		window:setProperty("Text", text)
	else
		window:SetText(text)
	end
end

function AT.CheckWindowText(txt, ...)
	local text = AT.GetWindowText(...)
	local name = table.concat({...}, ".")
	if text == txt then
		print("AT.CheckWindowText OK:", name, txt)
		return
	end
	error(string.format("AT.CheckWindowText %s 失败: %s != %s", name, text, txt))
end

function AT.CheckWindowVisible(expected, ...)
	local wnd = AT.GetWindow(...)
	local name = table.concat({...}, ".")
	assertWindow(wnd, name)

	if isWindowVisible(wnd) == expected then
		print("AT.CheckWindowVisible OK:", name)
	else
		error(string.format( "AT.CheckWindowVisible %s 失败：窗口不可见", name))
	end
end

function AT.CheckWindowsVisible(expected, ...)
	if select("#", ...) < 1 then return end

	local arg = {...}
	for _, v in ipairs(arg) do
		if type(v) == "table" then
			AT.CheckWindowVisible(expected, table.unpack(v))
		else
			AT.CheckWindowVisible(expected, v)
		end
	end
end

function AT.OnOldWndClick(window)
	local parent = window
	local wnd = nil
	local rootId = UI._desktop:getId()
	while parent and parent:getId()~=rootId do
		wnd = parent
		parent = parent:GetParent()
	end
	if not wnd then
		return
	end
	local names = {wnd:GetName()}
	if window~=wnd then
		names[2] = window:GetName()
	end
	if names[1]=="GMBoard" or names[2]=="Main-GM" then
		return
	end
	local text = nil
	if window:GetTypeStr()=="StaticText" then
		text = window:GetText()
	end
	recordWndClick(names, text)
end

function AT.OnOldWndEdit(window)
	local parent = window
	local wnd = nil
	local rootId = UI._desktop:getId()
	while parent and parent:getId()~=rootId do
		wnd = parent
		parent = parent:GetParent()
	end
	if not wnd then
		return
	end
	local names = {wnd:GetName()}
	if window~=wnd then
		names[2] = window:GetName()
	end
	recordWndEdit(names, window:GetText())
end

function AT.SetKeyPressing(key, press)
	bm:setKeyPressing(key, press)
end

local function _setAxisKey(positiveKey, negativeKey, value, precision)
	if value>precision then
		AT.SetKeyPressing(positiveKey, true)
		AT.SetKeyPressing(negativeKey, false)
	elseif value<-precision then
		AT.SetKeyPressing(positiveKey, false)
		AT.SetKeyPressing(negativeKey, true)
	else
		AT.SetKeyPressing(positiveKey, false)
		AT.SetKeyPressing(negativeKey, false)
		return true
	end
	return false
end

local function _moveTimer(x, z, endTicks, precision)
	assert(AT.timer)
	assert(AT.thread)
	local nowPos = Me:getPosition()
	local dpos, retMsg
	if World.Now()>endTicks then
		dpos = Lib.v3(0,0,0)
		retMsg = "timeout"
	else
		dpos = Lib.posAroundYaw(Lib.v3(x-nowPos.x, 0, z-nowPos.z), -Blockman.instance:viewerRenderYaw())
		retMsg = "arrived"
	end
	local arrived = _setAxisKey("key.forward", "key.back", dpos.z, precision)
	arrived = _setAxisKey("key.left", "key.right", dpos.x, precision) and arrived
	if arrived then
		closeTimer()
		coroutine.resume(AT.thread, retMsg)
		return
	end
	return true
end

function AT.WaitMoveTo(x, z, timeout, precision, try)
	assert(not AT.timer)
	assert(AT.thread)
	assert(AT.thread == coroutine.running())
	timeout = timeout or 200
	precision = precision or 1
	AT.SetKeyPressing("key.forward", true)
	AT.timer = World.Timer(1, _moveTimer, x, z, timeout+World.Now(), precision)
	local ret = coroutine.yield()
	if ret=="arrived" then
		print("AT.WaitMoveTo OK:", x, z)
		return true
	end
	if try then
		return false
	end
	error("AT.WaitMoveTo 超时: " .. x .. ", " .. z)
end

function AT.CallAPI(api, param)
	local body = cjson.encode(param)
	print("AT.CallAPI request:", api, #body > 500 and body:sub(1,500).."..." or body)
	
	local data = {}

	local header = {
		["content-type"] = "application/json",
		["content-length"] = #body,
	}

	local obj = 
	{
		url = AT.serverUrl .. api,
		method = "POST",
		headers = header,
		sink = ltn12.sink.table(data),
		source = ltn12.source.string(body),
	}

	local res, code, response_headers = http.request(obj)
	print("AT.CallAPI response:", res, code, data[1])
	if code==200 then
		return cjson.decode(data[1])
	end
	return nil, code, data[1]
end

function AT.CallScript(name, ...)
	local func = AT.include[name]
	if func then
		return func(...)
	end
	local data = AT.CallAPI("getinc", {name=name})
	if not data or not data.ok then
		error("AT.CallScript error:" .. name)
		return
	end
	func = assert(load(misc.read_text(data.code), "@" .. name))
	AT.include[name] = func
	return func(...)
end

function AT.GMMoveTo(x, y, z)
	GM.input(Me, "玩家/当前位置", string.format("%f,%f,%f", x, y, z))
end

-- bridge to make calling AT.Xxx methods from poco easily

function AT.foo(name)
	return 'hello, ' .. name
end

local atAsyncMethods = {
	WaitTime = true,
	WaitMoveTo = true,
}
local atSyncMethods = {
	foo = true,
}

function AT.ServePoco(method, ...)
	if atSyncMethods[method] ~= nil then
		print('poco: call AT.' .. method .. ' directly')
		local ret = AT[method](...)
		if ret == nil then
			ret = true
		end
	end

	if atAsyncMethods ~= nil then
		local args = table.pack(...)
		return function (cbFinish)
			print('poco: call AT.' .. method .. ' asynchronously')
			AT.TempBegin(function ()
				local ret = AT[method](table.unpack(args))
				print('poco: AT.' .. method .. " return: '" .. tostring(ret) .. "'")
				if ret == nil then
					ret = true
				end
				cbFinish(ret)
			end)
		end
	end

	return "poco: Unknown method '" .. method "'"
end