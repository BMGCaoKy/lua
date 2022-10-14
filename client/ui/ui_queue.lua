local misc = require( "misc")


UIMgr.WIN_QUEUE  = {}
UIMgr.WIN_CALLBACK_QUEUE  = {}
UIMgr.WIN_QUEUE_HIDE  = {}
UIMgr.WIN_QUEUE_NEED_SHOW  = {}


local function asyncUICreation()
	return not not World.cfg.asyncUICreation
end

function UIMgr:hideQueueWindow(excludedMap)
	-- 请注意，这里需要你默认队列的需要打开的 UI 全部为已经打开的状态
	UIMgr.WIN_QUEUE_HIDE = excludedMap
end

function UIMgr:showHideWindow()
	for _, name in pairs(UIMgr.WIN_QUEUE_NEED_SHOW) do
		local window = UI:getWnd(name, true)
		if window then
			window:show()
		end
	end
end

function UIMgr:registerWindowCallBack(name, callBack)
	for _, value in ipairs(UIMgr.WIN_QUEUE) do
		if value.args[2] == name then
			local call = self.WIN_CALLBACK_QUEUE[name]
			if not call then
				self.WIN_CALLBACK_QUEUE[name] = {}
			end
			table.insert(self.WIN_CALLBACK_QUEUE[name], callBack)
			return
		end
	end

	local window = UI:getWnd(name,  true)
	if window then
		callBack(window)
	end
end

function UIMgr:register(func,callBack, ...)
	table.insert(self.WIN_QUEUE, {fun = func, callBack = callBack, args =  table.pack(...)})
end

function UIMgr:checkAndRegister(name, func, callBack)
	local window = UI:getWnd(name,  asyncUICreation())
	if not window then
		self:register(func,callBack, UI, name)
		return nil
	end

	return window
end

-- 不建议使用，会破坏队列加载的优化
function UIMgr:findQueueChild(path, index)
	UI:findQueueChild(path, index)
end

function UIMgr:registerWindow(name, callBack)
	local window = self:checkAndRegister(name, UI.getWnd,callBack)
	if window and callBack then
		callBack(window)
	end
end

function UIMgr:registerOpenWindow(name, callBack)
	local window = self:checkAndRegister(name, UI.openWnd,callBack)

	if window then
		UI:openWnd(name)
	end
	if window and callBack then
		callBack(window)
	end
end

function UIMgr:registerOpenNewWindow(name, callBack)
	self:register(UI.openNewWnd,callBack, UI, name)
end

local function execute(item)
	if item.fun then
		local window = item.fun(table.unpack(item.args))
		if item.callBack then
			item.callBack(window)
		end

		if Lib.getTableSize(UIMgr.WIN_QUEUE_HIDE) ~= 0 then
			if not UIMgr.WIN_QUEUE_HIDE[item.args[2]] and window:isvisible() then
				window:hide()
				table.insert(UIMgr.WIN_QUEUE_NEED_SHOW, item.args[2])
			end
		end

		for _, call in pairs(UIMgr.WIN_CALLBACK_QUEUE[item.args[2]] or {}) do
			call(window)
		end
	end
end

function UIMgr:getQueueWindow(name)
	local window = UI:getWnd(name, true)
	if window then
		return window
	end

	local index = 0
	for i, value in ipairs(UIMgr.WIN_QUEUE) do
		if value.args[2] == name then
			execute(value)
			index = i
			break
		end
	end

	if index ~= 0 then
		table.remove(UIMgr.WIN_QUEUE, index)
	end

	return UI:getWnd(name, true)
end

local function getMilliseconds()
	return math.floor(misc.now_nanoseconds() / 1000000)
end

function UIMgr.Tick()
	if Lib.getTableSize(UIMgr.WIN_QUEUE) == 0 then
		return
	end

	local threshold = World.cfg.handleUIThreshold and World.cfg.handleUIThreshold or 100
	local startTime = getMilliseconds()
	while (getMilliseconds() - startTime < threshold) and (Lib.getTableSize(UIMgr.WIN_QUEUE) > 0) do
		execute(UIMgr.WIN_QUEUE[1])
		table.remove(UIMgr.WIN_QUEUE, 1 )
	end
end


