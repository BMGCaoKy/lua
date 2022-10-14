local guiMgr = L("guiMgr", GUIManager:Instance())

print("begin init ui_schedule")
local mouseState = {NONE = 0, SHOW = 1, HIDE = 2}
local enumPlatformId = {PC = 1, ELSE = 2}
local platformId = CGame.instance:getPlatformId()

local guiMgr = L("guiMgr", GUIManager:Instance())
local Recorder = T(Lib, "Recorder")

---@class UI
local UI = UI

local misc = require "misc"
local now_nanoseconds = misc.now_nanoseconds
local function getTime()
    return now_nanoseconds() / 1000000
end

function UI:init()
    self._desktop = GUISystem.instance:GetRootWindow()
	self._desktop:CleanupChildren()
	self._windows = {}
	self._moreWindowsCntList = {}
	self._remoterData = {}
	self._preCreateWndList = {
		"setting",
		"chat",
		"appMainRole",
	}
    self._baseMainWndListWatcher = {
        "followInterface",
    }

    self._windowsOpenTime = {}
end

function UI:recordWindowOpenTime(name)
    if World.Now ~= nil then
        self._windowsOpenTime[name] = World.Now()
    end
end

function UI:getWindowOpenTime(name)
    if self._windowsOpenTime[name] ~= nil then
        return self._windowsOpenTime[name]
    end
    return 0
end

function UI:getPreCreateWndList()
    return self._preCreateWndList
end

local function removeBaseUi(baseMainWndListNormal, uiName)
    local idx = false
    for i,v in pairs(baseMainWndListNormal) do
        if v == uiName then
            idx = i
            break
        end
    end
    if idx then
        table.remove(baseMainWndListNormal,idx)
    end
end

local function checkEngineDefUIEnable(baseMainWndListNormal)
    local engineDefUIEnable = World.cfg.engineDefUIEnable
    if not engineDefUIEnable then
        return
    end

    for uiName, enable in pairs(engineDefUIEnable) do
        if not enable then
            removeBaseUi(baseMainWndListNormal, uiName)
        end
    end
end

function UI:getBaseMainWndListNormal()
    local baseMainWndListNormal
    
    if GUIManager:Instance():isEnabled() then
        baseMainWndListNormal = {
            "actionControl",
            "toolbar",
            "skills",
            "topteamInfo",
            "playerList",
            "playerinfo",
            "reload"
        }
    else
        baseMainWndListNormal = {
            "actionControl",
            "toolbar",
            "main",
            "skills",
            "topteamInfo",
            "interactionContainer",
            "playerList",
            "playerinfo",
            "reload"
        }
    end

    if World.cfg.baseMainWndListNormal then
        baseMainWndListNormal = Lib.copy(World.cfg.baseMainWndListNormal)
    end
    if GUIManager:Instance():isEnabled() then
        local exBaseMainWndList =
        {
            "shortcutBar",
            "appMainRole"
        }
        for _, ui in pairs(exBaseMainWndList) do
            baseMainWndListNormal[#baseMainWndListNormal + 1] = ui
        end
    end

    if World.cfg.chatSetting then
        removeBaseUi(baseMainWndListNormal, "newmainchat")
        local idx = false
        for i,v in pairs(baseMainWndListNormal) do
            if v == "newmainchat" then
                idx = i
                break
            end
        end
        if idx then
            table.remove(baseMainWndListNormal,idx)
        end

    end
    checkEngineDefUIEnable(baseMainWndListNormal)
    return baseMainWndListNormal
end

function UI:getBaseMainWndListWatcher()
    return self._baseMainWndListWatcher
end

function UI:getCustomMainWndList()
    local baseCustomMainWndList
    if GUIManager:Instance():isEnabled() then
        baseCustomMainWndList = {
            "frontsight",
        }
    else
        baseCustomMainWndList = {
            "frontsight",
            "editContainer",
        }
    end
    
    if World.cfg.baseCustomMainWndList then
        baseCustomMainWndList = World.cfg.baseCustomMainWndList
    end
    local names = Lib.copy(baseCustomMainWndList)

    if World.cfg.needShowTargetInfo then
        names[#names + 1] = "newmaintargetinfo"
    end
    --if World.CurMap.cfg.miniMap then
    --    names[#names + 1] = "minimap"
    --end
    for _, name  in ipairs (World.cfg.mainUiList or {}) do
        names[#names + 1] = name
    end
    checkEngineDefUIEnable(names)
    return names
end

-- only works for old ui
if not guiMgr:isEnabled() then
    function UI:SetWindowHide(name, hide)
        local wnd = UI._windows[name]
        if hide then
            wnd:hide()
        else
            wnd:show()
        end
    end

    function UI:SetWindowsAlphaToZero(names, setZero)
        for name in pairs(names) do
            local wnd = UI._windows[name]
            if setZero then
                wnd:root():SetAlpha(0)
            else
                wnd:root():SetAlpha(1)
            end
        end
    end

    function UI:HideAllWindowsExcept(whiteList, wndAsKey)
        self:RestoreAllWindows()

        local excepts = {}
        if wndAsKey then
            for wnd in pairs(whiteList) do
                table.insert(excepts, wnd:GetName())
            end
        else
            for name in pairs(whiteList) do
                table.insert(excepts, name)
            end
        end
        self.restoreHideWindowsFunc = self:hideOpenedWnd(excepts)
    end

    function UI:RestoreAllWindows()
        if not self.restoreHideWindowsFunc then
            return
        end
        self.restoreHideWindowsFunc()
        self.restoreHideWindowsFunc = nil
    end

    function UI:GetAllWindowNames()
        local ret = {}
        for name in pairs(self._windows) do
            table.insert(ret, name)
        end
        return ret
    end
end

function UI:AddWndInstance(wnd)
    self._desktop:AddChildWindow(wnd)
end

function UI:RemoveWndInstance(wnd)
    self._desktop:RemoveChildWindow1(wnd)
end

---@return WinBase
function UI:getWnd(name, dont_create, wndName)
	if GUIManager:Instance():isEnabled() then
		local ok, ret = pcall(UI.getWindow, UI, name, dont_create, wndName)
		if not ok then
			Lib.logWarning(string.format("try get new ui[%s]", name), ret)
			return
		end
		return ret
	end

    local window = self._windows[wndName or name]
--[[    if not window then
        Lib.logError("UI getWnd not window", tostring(wndName or name))
    end]]
    if not window and not dont_create then
        window = assert(UIMgr:new_wnd(name))
        self._windows[wndName or name] = window
    end
    return window
end

function UI:getMultiInstanceWnds(name)
    local wnds = {}
    for wndName, wnd in pairs(self._windows) do
        if string.find(wndName, name) and #wndName > #name then
            wnds[wndName] = wnd
        end
    end
    return wnds
end

local function openWnd(self, instanceName, name, ...)
	if GUIManager:Instance():isEnabled() then
		local ok, ret = pcall(UI.openSystemWindow, UI, name, instanceName, ...)
		if not ok then
			Lib.logError(string.format("try use new ui[%s]", name), ret, debug.traceback())
			return
		end
		return ret
	end

	local window = self:getWnd(name, nil, instanceName)
	if not window then
		return nil
	end

	local parent = window:root():GetParent()
	if parent and parent:getId() == self._desktop:getId() then	-- already opened
		return window
	end

    self._desktop:AddChildWindow(window:root(), instanceName)
    window:show()
    window:tryShowAnim()
    Lib.emitEvent(Event.EVENT_OPEN_WINDOW, name)
    window:onOpen(...)

    -- UI:checkWndState(platformId == enumPlatformId.PC and (not CGame.instance:isShowPlayerControlUi()), window:key(), true) --Check if  need to show the mouse
    -- if PlatformUtil.isPlatformWindows() and window:key() then
    if PlatformUtil.isPlatformWindows() then
        UI:processMouseState(true)
    end

    if self.checkPause then
        PlayerControl.CheckUIOpenPauseGame(name, true)
    end

    window:root():setTimerGoing(true)
    return window
end
local wndQueue = {}
function UI:openWndInQueue(wndName,param)
    local wnd = UI:getWnd(wndName)
    if not wnd then
        Lib.logError("openWndInQueue cant find wnd,name:",wndName)
        return
    end
    local curWnd = {
        wndName = wndName,
        param = param,
    }
    table.insert(wndQueue,curWnd)
    Lib.logDebugPrivate( "zhuyayi","wndQueue add:",Lib.v2s(wndQueue,3))
    if not wnd._allEvent then
        wnd._allEvent = {}
    end
    wnd._allEvent.queueCloseCall = function()
        local removeParam = table.remove(wndQueue,1)
        Lib.logDebugPrivate( "zhuyayi","wndQueueremove:",Lib.v2s(wndQueue,3))
        if #wndQueue>0 then
            if removeParam.wndName ==wndQueue[1].wndName then
                --相同界面空一帧调用
                World.LightTimer("",1,function()
                    UI:openWnd(wndQueue[1].wndName,wndQueue[1].param)
                end)
            else
                UI:openWnd(wndQueue[1].wndName,wndQueue[1].param)
            end
        else
            Lib.emitEvent(Event.EVENT_WND_QUEUE_EMPTY)
        end
    end
    if #wndQueue==1 then
        UI:openWnd(wndName,param)
    end
end
function UI:openNewWnd(name, ...)
    if GUIManager:Instance():isEnabled() then
        return
    end

    local window  = assert(UIMgr:new_wnd(name))
    self._windows[name] = window
	if not window then
		return nil
    end
    self:recordWindowOpenTime(name)

    self._desktop:AddChildWindow(window:root())
    window:show()
    window:onOpen(...)

    -- UI:checkWndState(platformId == enumPlatformId.PC and (not CGame.instance:isShowPlayerControlUi()), window:key(), true) --Check if  need to show the mouse
    -- if PlatformUtil.isPlatformWindows() and window:key() then
    if PlatformUtil.isPlatformWindows() then
        UI:processMouseState(true)
    end

    if self.checkPause then
        PlayerControl.CheckUIOpenPauseGame(name, true)
    end

    return window
end

function UI:openWnd(name, ...)
    if Recorder.CanUiShow and (not Recorder:CanUiShow(name)) then
        print("UI:openWindow blocked by Recorder", name, ...)
        return
    end

    self:recordWindowOpenTime(name) 
	return openWnd(self, false, name, ...)
end

function UI:openMultiInstanceWnd(name, ...)
    local index = 1
    while true do
        local winName = name .. "_multiple_" .. index
        local win = self._windows[winName]
        if not win then
            return openWnd(self, winName, name, ...)
        end
        local rootWin = win:root()
        local parent = rootWin:GetParent()
        if not parent or parent == 0 then
            return openWnd(self, winName, name, ...)
        end
        index = index + 1
    end
end

function UI:closeWnd(name, ...)
    if GUIManager:Instance():isEnabled() then
        UI:closeWindow(name, ...)
		return
	end

	local window
	if type(name) == "string" then
		window = self._windows[name]
	else
		assert(type(name) == "table" and name:root())
		window = name
	end

    if not window then
        return
    end

    window:root():setTimerGoing(false)
    Lib.emitEvent(Event.EVENT_CLOSE_WINDOW, name)
    window:hide()
    self._desktop:RemoveChildWindow1(window:root())
    window:onClose(...)


	-- UI:checkWndState(platformId == enumPlatformId.PC and (not CGame.instance:isShowPlayerControlUi()), window:key(), false) --Check if  need to hide the mouse
    -- if PlatformUtil.isPlatformWindows() and window:key() then
    if PlatformUtil.isPlatformWindows() then
        UI:processMouseState(false)
    end
end

function UI:reloadWnd(name)
	local window = UI:getWnd(name, true)
	if not window then
        return
    end
	local isOpen = false
	if UI:isOpen(name) then
		isOpen = true
	end
    window:hide()
	self._windows[name] = nil
    self._desktop:RemoveChildWindow1(window:root())
    window:onClose()
	--GUIWindowManager.instance:DestroyGUIWindow(window:root())
	if isOpen then
		UI:openWnd(name, table.unpack(window.openArgs or {}, 1, window.openArgs and window.openArgs.n))
	end
	UI:getWnd(name):onReload(window.reloadArg)
end

function UI:openSceneWnd(key, name, width, height, rotate, position, ...)
	if GUIManager:Instance():isEnabled() then
		return
	end

    local window = assert(UIMgr:new_wnd(name))
	if not window then
		return nil
	end

    assert(not self._windows[key], "already have the wnd by key: " .. key)

	self._windows[key] = window
    self:recordWindowOpenTime(key)

	if World.cfg.isUseWorldWindow then
		GUISystem.instance:CreateWorldWindow(key, window:root(), width, height, rotate, position, -1)
	else
		GUISystem.instance:CreateSceneWindow(key, window:root(), width, height, rotate, position, -1)
	end

    window:show()
    window:onOpen(...)
    return window
end

function UI:openEntitySceneWnd(key, name, width, height, rotate, position, objID, ...)
    if GUIManager:Instance():isEnabled() then
        local args = {
            width = width,
            height = height,
            rotation = rotate,
            position = position,
            objID = objID,
            flags = 4,
        }
        local window, instance = UI:openSystemSceneWindow(name, key, args, ...)
        self._windows[key] = instance
        self:recordWindowOpenTime(key)
		return
	end

    local window = assert(UIMgr:new_wnd(name))
	if not window then
		return nil
	end

    assert(not self._windows[key], "already have the wnd by key: " .. key)

	self._windows[key] = window
    self:recordWindowOpenTime(key)

	if World.cfg.isUseWorldWindow then
		GUISystem.instance:CreateWorldWindow(key, window:root(), width, height, rotate, position, objID)
	else
		GUISystem.instance:CreateSceneWindow(key, window:root(), width, height, rotate, position, objID)
	end

    window:show()
    window:onOpen(...)
    return window
end

function UI:closeSceneWnd(key)
	if GUIManager:Instance():isEnabled() then
		return
	end

	local window
	if type(key) == "string" then
		window = self._windows[key]
	end

    if not window then
        return
    end

	self._windows[key]:hide()
	self._windows[key]:onClose()
	self._windows[key] = nil
	if World.cfg.isUseWorldWindow then
		GUISystem.instance:RemoveWorldWindow(key)
	else
		GUISystem.instance:RemoveSceneWindow(key)
	end
end

function UI:openHeadWnd(objID, name, width, height, ...)
    if GUIManager:Instance():isEnabled() then
        -- local args = {
        --     objID = objID,
        --     width = width,
        --     height = height,
        -- }
        -- UI:openSystemSceneWindow(name, "", args, ...)
		return
	end
    if not GUISystem.instance:CanCreateHeadWindow() then
        return
    end
    local window = assert(UIMgr:new_wnd(name))
	if not window then
		return nil
	end
	local key = "*head_" .. objID
	local wnd = self._windows[key]
	if wnd then
		self:closeHeadWnd(objID)
	end

	self._windows[key] = window
    self:recordWindowOpenTime(key)

    local abbrArgs = table.pack(...)
    local headOffset = {x = 0, y = 0, z = 0}
    if abbrArgs and type(abbrArgs[1]) == "table" and abbrArgs[1].customHeadOffset then
        headOffset = abbrArgs[1].customHeadOffset
        table.remove(abbrArgs, 1)
    end
    local ret = true
	if World.cfg.isUseWorldWindow then
		GUISystem.instance:CreateHeadWorldWindow(key, objID, window:root(), width, height, headOffset)
	else
		ret = GUISystem.instance:CreateHeadWindow(objID, window:root(), width, height, headOffset)
	end

	if not ret then
        window:onClose()
        self._windows[key] = nil
        return
    end
    window:show()
    window:onOpen(table.unpack(abbrArgs))
    return window
end

---@param objID entityid
---@param width number
---@param height number
function UI:changeHeadWndSize(objID, width, height )
    if GUIManager:Instance():isEnabled() then
        return
    end

    local key = "*head_" .. objID
    local wnd = self._windows[key]
    if wnd then
		if World.cfg.isUseWorldWindow then
			GUISystem.instance:SetHeadWorldWindowSize(key, width, height)
		else
			GUISystem.instance:SetHeadWindowSize(objID, width, height)
		end
    end
end

---@param objID entityid
---@param offset Vector3
function UI:changeHeadWndOffset(objID, offset)
    if GUIManager:Instance():isEnabled() then
        return
    end

    local key = "*head_" .. objID
    local wnd = self._windows[key]
    if wnd then
		if World.cfg.isUseWorldWindow then
			GUISystem.instance:SetHeadWorldWindowOffset(key, offset)
		else
			GUISystem.instance:SetHeadWindowOffset(objID, offset)
		end
    end
end

function UI:closeHeadWnd(objID)
	local key = "*head_" .. objID

	local window
	if type(key) == "string" then
		window = self._windows[key]
	end

    if not window then
        return
    end

	self._windows[key]:hide()
	self._windows[key]:onClose()
	self._windows[key] = nil

	if World.cfg.isUseWorldWindow then
		GUISystem.instance:RemoveHeadWorldWindow(key)
	else
		GUISystem.instance:RemoveHeadWindow(objID)
	end
end

function UI:openGUIFollowWnd(objID, window, width, height, minDistanceScale, maxDistanceScale, minDistance, maxDistance, disappearDistance, worldOffset, uiOffset,...)
    if GUIManager:Instance():isEnabled() then
		return
	end
	if not window then
		return nil
	end

    local ret = true

	ret = GUISystem.instance:CreateGUIFollowWindow(objID, window, width, height, minDistanceScale, maxDistanceScale, minDistance, maxDistance, disappearDistance, worldOffset, uiOffset)

    return window, ret
end

function UI:closeGUIFollowWnd(objID)
    if GUIManager:Instance():isEnabled() then
		return
	end
	GUISystem.instance:RemoveGUIFollowWindow(objID)
end

function UI:changeGUIFollowWndSize(objID, width, height )
    if GUIManager:Instance():isEnabled() then
        return
    end

    GUISystem.instance:SetGUIFollowWindowSize(objID, width, height)
end

function UI:changeGUIFollowWndMinDistanceScale(objID, scale )
    if GUIManager:Instance():isEnabled() then
        return
    end

    GUISystem.instance:SetGUIFollowWindowMinScale(objID, scale)
end

function UI:changeGUIFollowWndMaxDistanceScale(objID, scale )
    if GUIManager:Instance():isEnabled() then
        return
    end

    GUISystem.instance:SetGUIFollowWindowMaxScale(objID, scale)
end

function UI:changeGUIFollowWndMinDistance(objID, distance )
    if GUIManager:Instance():isEnabled() then
        return
    end

    GUISystem.instance:SetGUIFollowWindowMinDistance(objID, distance)
end

function UI:changeGUIFollowWndMaxDistance(objID, distance )
    if GUIManager:Instance():isEnabled() then
        return
    end

    GUISystem.instance:SetGUIFollowWindowMaxDistance(objID, distance)
end

function UI:changeGUIFollowWndDisappearDistance(objID, distance )
    if GUIManager:Instance():isEnabled() then
        return
    end

    GUISystem.instance:SetGUIFollowWindowDisappearDistance(objID, distance)
end

function UI:changeGUIFollowWndWorldOffset(objID, offset )
    if GUIManager:Instance():isEnabled() then
        return
    end

    GUISystem.instance:SetGUIFollowWindowWorldOffset(objID, offset)
end

function UI:changeGUIFollowWndUIOffset(objID, offset )
    if GUIManager:Instance():isEnabled() then
        return
    end

    GUISystem.instance:SetGUIFollowWindowUIOffset(objID, offset)
end

function UI:isOpen(name)
	if GUIManager:Instance():isEnabled() then
		return UI:isOpenWindow(name)
	end

	local window
	if type(name) == "string" then
		window = self._windows[name]
	else
		assert(type(name) == "table" and name:root())
		window = name
	end

	if not window then
		return false
	end

	local parent = window:root():GetParent()
	if parent and parent:getId() == self._desktop:getId() then	-- already opened
		return true
	end

	return false
end

local function checkVisiable(self, node)
	assert(node)

	repeat
		if not node:IsVisible() then
			break
		end

		if node:getId() == self._desktop:getId() then
			return true
		end

		node = node:GetParent()
	until(not node)

	return false
end

function UI:findChild(path, index)
	local node = nil
	repeat
		assert(path and type(path) == "string")
		local win_name, child_name = string.match(path, "^([^/@]*)/?([^@]*)@?(.*)$")
		if #win_name == 0 then
			break
		end

        if not index then
            local root = self:getWnd(win_name, true)
            if #child_name == 0 then
                node = root and root:root()
                break
            end
            node = root and root:child(child_name)
        else
            local function findNodeWithIndex(root)
                local count = root:GetChildCount()
                for i = 1, count do
                    local child = root:GetChildByIndex(i-1)
                    if child:GetName() == child_name then
                        index = index - 1
                        if index < 0 then
                            return child
                        end
                    end
                    if child:GetChildCount() > 0 then
                        local findNode = findNodeWithIndex(child)
                        if findNode then
                            return findNode
                        end
                    end
                end
            end
            local root = self:getWnd(win_name, true)
            if root then
                root = root:root()
                node = findNodeWithIndex(root)
            end
        end
	until(true)

	if not node then
		return nil
	end

	return checkVisiable(self, node) and node or nil
end

-- 不建议使用，会破坏队列加载的优化
function UI:findQueueChild(path, index)
	local node = nil
	repeat
		assert(path and type(path) == "string")
		local win_name, child_name = string.match(path, "^([^/@]*)/?([^@]*)@?(.*)$")
		if #win_name == 0 then
			break
		end

        if not index then
            local root = UIMgr:getQueueWindow(win_name)
            if #child_name == 0 then
                node = root and root:root()
                break
            end
            node = root and root:child(child_name)
        else
            local function findNodeWithIndex(root)
                local count = root:GetChildCount()
                for i = 1, count do
                    local child = root:GetChildByIndex(i-1)
                    if child:GetName() == child_name then
                        index = index - 1
                        if index < 0 then
                            return child
                        end
                    end
                    if child:GetChildCount() > 0 then
                        local findNode = findNodeWithIndex(child)
                        if findNode then
                            return findNode
                        end
                    end
                end
            end
            local root = UIMgr:getQueueWindow(win_name)
            if root then
                root = root:root()
                node = findNodeWithIndex(root)
            end
        end
	until(true)

	if not node then
		return nil
	end

	return checkVisiable(self, node) and node or nil
end

-- function UI:getWinState()
--     if platformId ~= enumPlatformId.PC then
--         return false
--     end
-- 	for _, wnd in pairs(self._windows) do
-- 		if UI:isOpen(wnd) and wnd:key() then
-- 			return true
-- 		end
-- 	end
-- 	return false
-- end

function UI:hasOpenedModalWindow()
    local gui = GUISystem.instance
    local screenCenter = { x = gui:GetScreenWidth() / 2, y = gui:GetScreenHeight() / 2 }
    local logicCenter = GUISystem.instance:AdaptPosition(screenCenter)
    local window = GUISystem.instance:GetTargetGUIWindow(logicCenter)
    return window ~= nil
end

-- function UI:checkWndState(flag, affect, state)
-- 	if (not flag) or  (not affect) then    --flag=false, return
-- 		return
-- 	end
-- 	for _, wnd in pairs(self._windows) do
-- 		if UI:isOpen(wnd) and wnd:key() then
-- 			CGame.instance:showMouse()
-- 			return
-- 		end
-- 	end
-- 	if not state then
-- 		CGame.instance:hideMouse()
-- 	end
-- end

function UI:processMouseState(isWndOpen)
    if isWndOpen then
        CGame.instance:showMouse()
    else
        if 
            (not Clientsetting:isMouseShow())
            and (not UI:hasOpenedModalWindow()) 
            and (not (Player.CurPlayer and Player.CurPlayer.disableControl))
        then
            CGame.instance:hideMouse()
        end
    end  
end

function UI:setCheckPause(flag)
    self.checkPause = flag
end

local function getDelayOpenMainWndTimeMap()
    return World.cfg.delayOpenMainWndTimeMap or {}
end

local function setLevel(wnd, level)
    if not wnd then
        return
    end
    if guiMgr:isEnabled() then
        wnd:setLevel(level)
    else
        wnd:root():SetLevel(level)
    end
end
function UI:openMainWnd()
    Profiler:begin("UI:openMainWnd")
    local isWatcher = Me:isWatch()
    local baseList = isWatcher and self._baseMainWndListWatcher or self:getBaseMainWndListNormal()
    local customList = isWatcher and {} or self:getCustomMainWndList()
    local baseLevel = 49 + #baseList + #customList
    local delayOpenMainWndTimeMap = getDelayOpenMainWndTimeMap()
    local function openNewWnd(name)
        local curBaseLevel = baseLevel
        if not delayOpenMainWndTimeMap[name] then
            if guiMgr:isEnabled() and not World.cfg.asyncUICreation then
                local wnd = UI:openWnd(name)
                setLevel(wnd, curBaseLevel)
            else
                UIMgr:registerOpenWindow(name, function (window)
                    setLevel(window, curBaseLevel)
                end)
            end
        else
            World.LightTimer("openMainWnd delayOpen, wnd name : "..name, delayOpenMainWndTimeMap[name],function()
                local wnd = UI:getWnd(name, true)
				if not wnd then
					wnd = UI:openWnd(name)
                end
                setLevel(wnd, curBaseLevel)
            end)
        end
        baseLevel = baseLevel - 1
    end
    for _, name in ipairs(baseList) do
        openNewWnd(name)
    end
    for _, name in ipairs(customList) do
        openNewWnd(name)
    end
    if UI.onMainWindowOpen then
        UI:onMainWindowOpen()
    end
    Profiler:finish("UI:openMainWnd")
end

---@param excluded string or table
---@return function
function UI:hideOpenedWnd(excluded)
    if GUIManager:Instance():isEnabled() then
        return UI:hideAllWindow(excluded)
    end
    
    excluded = excluded or ""

    local excludedMap = {}
    if type(excluded) == "table" then
        for _, excludedName in pairs(excluded) do
            excludedMap[excludedName] = true
        end
    else
        excludedMap[excluded] = true
    end

    UIMgr:hideQueueWindow(excludedMap)

    local wnds = {}
    for name, wnd in pairs(UI._windows) do
        if not excludedMap[name] and wnd:isvisible() then
            wnd:hide()
            wnds[#wnds + 1] = name
        end
    end

    return function ()
        for _, name in ipairs(wnds) do
            local wnd = UI._windows[name]
            if wnd then
                wnd:show()
            end
        end
        UIMgr:showHideWindow()
        wnds = {}
    end
end

Lib.subscribeEvent(Event.EVENT_PLAYER_BEGIN, function()
	UI:openMainWnd()
    if Me:isWatch() or not World.cfg.enablePreCreateUI then
        return
    end
    --precreate wnd
    local preCreateWndList = {}
    for _, name in ipairs(UI._preCreateWndList or {}) do
        preCreateWndList[#preCreateWndList + 1] = name
    end
    for _, name  in ipairs(World.cfg.preCreateWndList or {}) do
        preCreateWndList[#preCreateWndList + 1] = name
    end
    local delayOpenMainWndTimeMap = getDelayOpenMainWndTimeMap()
    for _, name in ipairs(preCreateWndList) do
        if not delayOpenMainWndTimeMap[name] then
            UI:getWnd(name)
            Lib.logDebug("preCreateWnd : ", name)
        else
            World.LightTimer("preCreateWnd delayOpen, wnd name : "..name, delayOpenMainWndTimeMap[name],function()
                UI:getWnd(name)
                Lib.logDebug("preCreateWnd delayOpen : ", name)
            end)
        end
    end
    ----temp way to fix g2038 some ui cover chat ui,old chat pugins will del as soon
    --World.LightTimer("",3,function()
    --    if World.cfg.chatSetting then
    --        UI:getWnd("chat"):root():SetLevel(UI:getWnd("chat"):root():GetLevel())
    --    end
    --end)
    ----temp way over by zhuyayi
end)

Lib.subscribeEvent(Event.UPDATE_UI_NAVIGATION_REGCALLBACK_ID, function(regId)
    if not Me:isWatch() then
        UI:openWnd("newmainuinavigation", regId)
    end
end)

Lib.subscribeEvent(Event.EVENT_SCENEWND_OPERATION, function(show, uicfg)
	if show then
		UI:openSceneWnd(uicfg.key, uicfg.name, uicfg.width, uicfg.height, uicfg.rotate, uicfg.position , uicfg.args)
	else
		UI:closeSceneWnd(uicfg.key)
	end
end)

Lib.subscribeEvent(Event.EVENT_ENTITY_SCENEWND_OPERATION, function(show, uiCfg)
    if show then
        UI:openEntitySceneWnd(uiCfg.key, uiCfg.name, uiCfg.width, uiCfg.height, uiCfg.rotate, uiCfg.position, uiCfg.objID, uiCfg.args)
    else
        UI:closeSceneWnd(uiCfg.key)
    end
end)

Lib.subscribeEvent(Event.EVENT_RIDE, function(entity, mount)
    if not entity.isMainPlayer then
        return
    end
	if World.CurWorld.isEditor then
		return
	end
    if World.cfg.ignoreEngineEventRideOpenWnd then
        return
    end
    if mount and mount:isControl() and mount:cfg().carMove and mount:cfg().disableDriveControl ~= true then
        UI:openWnd("drive_control")
        UI:closeWnd("actionControl")
        for _, wnd in pairs(World.cfg.closeOnDrive or {}) do
            UI:closeWnd(wnd)
        end
    else
        UI:closeWnd("drive_control")
        UI:openWnd("actionControl")
        for _, wnd in pairs(World.cfg.closeOnDrive or {}) do
            UI:openWnd(wnd)
        end
    end
end)

Lib.subscribeEvent(Event.EVENT_PLAYER_SHOWNOVICEGUIDE, function()
	if Clientsetting.isKeyGuide("isOpenGuide") then
		UI:openWnd("newbie_guide")
		local retry = 1
		local network_mgr = require "network_mgr"
		World.Timer(5, function()
			local respone = network_mgr:set_client_cache("isOpenGuide", "1")
			if respone.ok or retry > 5 then
				if respone.ok then
					Clientsetting.setGuideInfo("isOpenGuide", false)
				end
				return false
			end
			retry = retry + 1
			return true
		end)
    end
end)

Lib.subscribeEvent(Event.EVENT_PLAYER_SHOWNOVICEGUIDE, function(fullName, close)
    if UI:isOpen("gameExplain") or close then
        UI:closeWnd("gameExplain")
    else
        UI:openWnd("gameExplain", fullName)
    end
end)

Lib.subscribeEvent(Event.EVENT_PLAYER_DEATH, function(time, func, ...)
    if GUIManager:Instance():isEnabled() then
        local wnd = UI:isOpenWindow("countdown")
        if not wnd then
            wnd = UI:openWindow("countdown", "countdown", "_layouts_")
        end
        local arg = table.pack(...)
        local showFunc = UI:hideAllWindow({"countdown", table.unpack(World.cfg.playerDeathShowUI or {})})
        local function callback()
            if func ~= nil then
                func(table.unpack(arg, 1, arg.n))
            end
            showFunc()
        end
        wnd:setTime(time, callback)
        return
    end 

    if UI:isOpen("countdown") then
        UI:getWnd("countdown"):forceCallBack()
    end
    local window = UI:openWnd("countdown")
    if not window then
        return
    end
    local arg = table.pack(...)
    local showFunc = UI:hideOpenedWnd({"countdown", table.unpack(World.cfg.playerDeathShowUI or {})})
    local function callback()
        if func ~= nil then
            func(table.unpack(arg, 1, arg.n))
        end
        showFunc()
    end

    window:_countdown(time, callback, World.cfg.playerDeathCanTouchMain)
end)

Lib.subscribeEvent(Event.EVENT_OPEN_PACK, function(...)
	if not UI:isOpen("mapEditMain") then
		return
	end
	if UI:isOpen("mapEditItemBag") then
		UI:closeWnd("mapEditItemBag")
	else
		UI:openWnd("mapEditItemBag", ...)
	end
end)

Lib.subscribeEvent(Event.EVENT_OPEN_REWARD_SETTING, function()
    UI:openWnd("mapEditRewardSetting")
end)

Lib.subscribeEvent(Event.EVENT_SHOW_PERSONALINFORMATIONS, function(objID)
    UI:openWnd("equipmentsystem", objID)
end)

Lib.subscribeEvent(Event.EVENT_SHOW_MAIN, function()
    UI:openWnd("editMain")
end)

Lib.subscribeEvent(Event.EVENT_OPEN_MAIN_TIPS, function()
	UI:openWnd("mapEditMainTip")
end)

Lib.subscribeEvent(Event.EVENT_MAP_EDIT_SETTING, function()
	UI:openWnd("mapEditSetting")
end)

Lib.subscribeEvent(Event.EVENT_MAP_DELETE, function(mapPath, win, mapName)
	UI:openWnd("mapEditTip", mapPath, win, mapName)
end)

Lib.subscribeEvent(Event.EVENT_CHAT_KEY_DOWN,function()
    if not UI:isOpen("main") then
		return
	end
    if UI:isOpen("chat") then
		Lib.emitEvent(Event.EVENT_OPEN_CHATBTN, false)
    else
		Lib.emitEvent(Event.EVENT_OPEN_CHATBTN, true)
	end
end)

Lib.subscribeEvent(Event.EVENT_SEND_ESPECIALLY_SHOP_UPDATE, function(close, menu)
    local wnd = UI:getWnd("upgrade")
    if wnd then
        wnd:updateList(menu)
    end
    if close then
        UI:closeWnd("upgrade")
    end
end)

Lib.subscribeEvent(Event.EVENT_COUNT_DOWN, function(time, func, ...)
    if GUIManager:Instance():isEnabled() then
        local wnd = UI:isOpenWindow("countdown")
        if not wnd then
            wnd = UI:openWindow("countdown")
        end
        local arg = table.pack(...)
        local showFunc = UI:hideAllWindow({"countdown", table.unpack(World.cfg.playerDeathShowUI or {})})
        local function callback()
            if func ~= nil then
                func(table.unpack(arg, 1, arg.n))
            end
            showFunc()
        end
        wnd:setTime(time, callback)
        return
    end 

    local window = UI:openWnd("countdown")
    if not window then
        return
    end
    local arg = table.pack(...)

    local function callback()
        if func ~= nil then
            func(table.unpack(arg, 1, arg.n))
        end
        UI:openMainWnd()
    end

    window:_countdown(time, callback, true)
end)

local function getUI(wndName)
    local window
    if UI:isOpen(wndName) then
        window = UI:getWnd(wndName)
    else
        window = UI:openWnd(wndName)
    end
    return window
end

Lib.subscribeEvent(Event.EVENT_TOP_TIPS, function(keepTime, vars, regId, textArgs)
    local window = getUI("promptNotice")
    if window then
        window:sendTopTips(keepTime, vars, regId, textArgs)
    end
end)

Lib.subscribeEvent(Event.EVENT_CENTER_TIPS, function(keepTime, vars, regId, textArgs)
    local window = getUI("promptNotice")
    if window then
        window:sendCenterTips(keepTime, vars, regId, textArgs)
    end
end)

Lib.subscribeEvent(Event.EVENT_BOTTOM_TIPS, function(keepTime, vars, regId, textArgs)
    local window = getUI("promptNotice")
    if window then
        window:sendBottomTips(keepTime, vars, regId, textArgs)
    end
end)

Lib.subscribeEvent(Event.EVENT_GAME_COUNTDOWN, function(keepTime, vars, regId, textArgs)
    local window = UI:getWnd("toolbar", true)
    if window then
        window:tipGameCountdown(keepTime, vars, regId, textArgs, true)
    end
end)

Lib.subscribeEvent(Event.EVENT_GAME_TOAST_TIPS, function(keepTime, vars, regId, textArgs)
    local window = getUI("promptNotice")
    if window then
        window:sendToastTips(keepTime, vars, regId, textArgs, true)
    end
end)

Lib.subscribeEvent(Event.EVENT_SEND_SETTLEMENT, function(result, isNextServer)
    if GUIManager:Instance():isEnabled() then
        UI:openWindow("finalsummary", nil, "_layouts_", result, isNextServer)
        return
    end
    local window = UI:openWnd("settlement")
    local showFunc = UI:hideOpenedWnd("settlement")
    if window then
        window:receiveFinalSummary(result, isNextServer, showFunc)
    end
end)

Lib.subscribeEvent(Event.EVENT_SHOW_GAMEQUALITY, function(show)
    if show then
        UI:openWnd("gameQuality")
    else
        UI:closeWnd("gameQuality")
    end
end)

Lib.subscribeEvent(Event.EVENT_SHOW_CHAPTERS, function(packet)
    if not packet.show then
        UI:closeWnd("stage")
        return
    end
    local win = UI:openWnd("stage")
    win:updateChapterInfo(packet)
end)

Lib.subscribeEvent(Event.EVENT_SHOW_GMBOARD, function(packet)
    if GUIManager:Instance():isEnabled() then
        local win = UI:isOpenWindow("gm_board")
        if not win then
            UI:openWnd("gm_board")
        elseif win:isOpen() then
            win:onClose()
        else
            win:onOpen()
        end
    else
        if UI:isOpen("gm_board") then
            UI:closeWnd("gm_board")
        else
            UI:openWnd("gm_board")
        end
    end
end)

Lib.subscribeEvent(Event.EVENT_CLOSE_GMBOARD, function(packet)
    if GUIManager:Instance():isEnabled() then
        local win = UI:isOpenWindow("gm_board")
        if win then
            win:onClose()
        end
    else
        UI:closeWnd("gm_board")
    end
end)

Lib.subscribeEvent(Event.EVENT_SHOW_STAGE_INFO, function(show, info)
    if show then
        UI:openWnd("stage_info", info)
    else
        UI:closeWnd("stage_info")
    end
end)

Lib.subscribeEvent(Event.EVENT_SHOW_STAGESETTLEMENT, function(packet)
    local winName = packet.winName
    if winName == "win_plumber_settlement" then
        UI:openWnd("plumber_settlement", packet)
    elseif winName == "win_stage_settlement" then
        UI:openWnd("stage_settlement", packet)
    end
end)

Lib.subscribeEvent(Event.EVENT_SEND_DEADSUMMARY,function (result, isNextServer, isWatcher, title)
    local showFunc = UI:hideOpenedWnd("deadSummary")
    UI:openWnd("deadSummary", result, isNextServer, isWatcher, title, showFunc)
end)

Lib.subscribeEvent(Event.EVENT_SEND_GAMEEND,function (result, title)
    Lib.emitEvent(Event.EVENT_CLOSE_ALL_WND)
    local function callback()
        UI:openMainWnd()
    end
    UI:openWnd("gameEnd", result, title, callback)
end)

Lib.subscribeEvent(Event.EVENT_CHECKED_MENU, function(check)
	local toolbar = UI:getWnd("toolbar", true)
    if GUIManager:Instance():isEnabled() then
        local settingWnd = UI:isOpenWindow("setting")
        if not settingWnd then
            --UI:openSystemWindowAsync(function(window) Lib.emitEvent(Event.EVENT_ONLINE_ROOM_SHOW, not window:isVisible()) end,
            --                            "setting")
            settingWnd = UI:openSystemWindow("setting")
        else
            settingWnd:setVisible(check)
        end

        if not settingWnd then
            return
        end
        Lib.emitEvent(Event.EVENT_ONLINE_ROOM_SHOW, not settingWnd:isVisible())
        return
    end
	if toolbar then
        toolbar:setChecked(check)
	end
    if check then
		UI:openWnd("setting")
    else
		UI:closeWnd("setting")
    end
end)

Lib.subscribeEvent(Event.EVENT_OPEN_EQUIPMENTSYSTEM, function()
	if not UI:isOpen("main") then
		return
	end
	if UI:isOpen("equipmentsystem") then
		UI:closeWnd("equipmentsystem")
	else
		UI:openWnd("equipmentsystem")
	end
end)

Lib.subscribeEvent(Event.EVENT_SHOW_KILLERINFO, function(info)
	if not info then
		UI:closeWnd("killerInfo")
	else
        local showFunc = UI:hideOpenedWnd("killerInfo")
		UI:openWnd("killerInfo", info, showFunc)
	end
end)

Lib.subscribeEvent(Event.EVENT_PLAYER_REBIRTH, function (objID)
    if Me.objID == objID then
        Lib.emitEvent(Event.RESET_SNIPE, objID)
    end
end)

Lib.subscribeEvent(Event.EVENT_SHOW_NOTICE, function(packet)
    local window = UI:openWnd("notice")
	if window then
		window:setArg(packet)
    end
end)

Lib.subscribeEvent(Event.EVENT_ADD_WAIT_DEAL_UI, function(packet)
    local window = UI:openWnd("waitDealList")
    if window then
        window:addWaitingList(packet)
    end
end)

Lib.subscribeEvent(Event.EVENT_SHOW_PERSONALINFORMATIONS, function(objID)
    UI:openWnd("equipmentsystem", objID)
end)

Lib.subscribeEvent(Event.EVENT_SHOW_REWARD_NOTICE, function(packet)
    local window = UI:openWnd("getiteminforam")
	if window then
		window:setArg(packet.tittletext, packet.tiptext, packet.cfg)
    end
end)

Lib.subscribeEvent(Event.EVENT_SHOW_REWARD_ROLL_TIP, function(packet)
    local window = UI:openWnd("reardui")
	if window then
		window:setRewardUi(packet.image, packet.text)
    end
end)


Lib.subscribeEvent(Event.EVENT_TOAST_TIP, function(text, time, delayCloseTime, originalText)
    local window = UI:isOpen("toast") and UI:getWnd("toast") or UI:openWnd("toast")
    if window then
        window:setToast(text, time, delayCloseTime, originalText)
    end
end)

Lib.subscribeEvent(Event.EVENT_SHOW_SELECT, function(packet)
    local window = UI:openWnd("select")
	if window then
		window:setOption(packet.options, packet.regId, packet.forcedChoice, packet.content, packet.tittle, packet.showMask)
    end
end)

Lib.subscribeEvent(Event.EVENT_MENU_EXIT, function()
    local window = UI:openWnd("gameTipDialog")
    local showFunc = UI:hideOpenedWnd("gameTipDialog")
	if window then
		window:refreshUi(showFunc)
	end
end)

Lib.subscribeEvent(Event.EVENT_KICKED_BY_SERVER, function(msg)
    Lib.emitEvent(Event.EVENT_CLOSE_ALL_WND)
    local window = UI:openWnd("mapLoadingPage")
    if window then
        window:showLoadingFailure(msg)
    end
end)

Lib.subscribeEvent(Event.EVENT_SEND_GAMEOVER, function(msg)
    Lib.emitEvent(Event.EVENT_CLOSE_ALL_WND)
    local window = UI:openWnd("mapLoadingPage")
    if window then
        window:showLoadingFailure(msg)
    end
end)

Lib.subscribeEvent(Event.EVENT_CLOSE_ALL_WND, function(msg)
    for _, wnd in pairs(UI._windows) do
        UI:closeWnd(wnd)
    end
end)

local function getAllOpenedDialogWindows(isBack)
    local isWatcher = Me:isWatch()
    local baseWnds = isWatcher and UI:getBaseMainWndListWatcher() or UI:getBaseMainWndListNormal()

    local customMainWnds = isWatcher and {} or UI:getCustomMainWndList()

    local ignoreWnds = {
        ["editVolumeBox"] = true
    }

    if isBack then
        local backIgnoreWnds = World.cfg.backIgnoreWnds or {}
        for _, name in pairs(backIgnoreWnds) do
            ignoreWnds[name] = true
        end
    end

    for _, name in ipairs(baseWnds) do
        ignoreWnds[name] = true
    end
    for _, name in ipairs(customMainWnds) do
        ignoreWnds[name] = true
    end

    local windows = {}
    for name, wnd in pairs(UI._windows) do
        -- NotDialogWnd: do not close when the return button is pressed
        if (not (ignoreWnds[name] or wnd.NotDialogWnd)) and (UI:isOpen(name)) then
            windows[#windows+1] = name
        end
    end
    return windows
end

Lib.subscribeEvent(Event.EVENT_CLOSE_ALL_DIALOG, function()
    local isWatcher = Me:isWatch()
    local baseWnds = isWatcher and UI:getBaseMainWndListWatcher() or UI:getBaseMainWndListNormal()
    local customMainWnds = isWatcher and {} or UI:getCustomMainWndList()
    local ignoreWnds = {
        ["editVolumeBox"] = true
    }
    for _, name in ipairs(baseWnds) do
        ignoreWnds[name] = true
    end
    for _, name in ipairs(customMainWnds) do
        ignoreWnds[name] = true
    end
    for name, wnd in pairs(UI._windows) do
        -- NotDialogWnd: do not close when the return button is pressed
        if not (ignoreWnds[name] or wnd.NotDialogWnd) then
            UI:closeWnd(wnd)
        end
    end
end)

function UI:openShopInstance(shopType, groupName)
    if not shopType then
        shopType = "singleShop"
    end
    if not groupName then
        groupName = "__" ..  shopType .."__"
    end
    local instanceName = shopType ..  "/" .. groupName
    --UI:openSystemWindowAsync(function(window) end,"shop", instanceName, shopType, groupName)
    UI:openSystemWindow("shop", instanceName, shopType, groupName)
end

Lib.subscribeEvent(Event.EVENT_OPEN_APPSHOP, function(isOpen, shopName, shopType)
    if GUIManager:Instance():isEnabled() then
        UI:openShopInstance(shopType or "shop", shopName)
        return
    end
    local window = UI:getWnd("toolbar", true)
    if window then
        if isOpen then
            UI:openWnd("appShop")
        else
            UI:closeWnd("appShop")
        end
    end
end)

Lib.subscribeEvent(Event.EVENT_OPEN_CONVERSATION, function(isOpen, ...)
    if isOpen then
        UI:openWnd("conversation", ...)
    else
        UI:closeWnd("conversation")
    end
end)

Lib.subscribeEvent(Event.EVENT_MAIN_ROLE, function(isOpen, ...)
    if isOpen then
	    if GUIManager:Instance():isEnabled() then
            local wnd = UI:getWnd("appMainRole")
            wnd:onOpen(...)
        else
            UI:openWnd("appMainRole", ...)
        end
    else
        UI:closeWnd("appMainRole")
    end
end)

Lib.subscribeEvent(Event.EVENT_OPEN_GENERIC_LIST_DISPLAY_BOX, function(isOpen, ...)
    if isOpen then
        UI:openWnd("genericListDisplayBox", ...)
    else
        UI:closeWnd("genericListDisplayBox")
    end
end)

Lib.subscribeEvent(Event.EVENT_OPEN_GENERIC_ACTOR_SHOW_STORE, function(isOpen, ...)
    if isOpen then
        UI:openWnd("genericActorShowStore", ...)
    else
        UI:closeWnd("genericActorShowStore")
    end
end)

Lib.subscribeEvent(Event.EVENT_SHOW_TITLE_BAR_PAGE, function(isOpen, ...)
    if isOpen then
        UI:openWnd("titleBarPage", ...)
    else
        UI:closeWnd("titleBarPage")
    end
end)

Lib.subscribeEvent(Event.EVENT_IMPRINT, function(isOpen, ...)
    if isOpen then
        UI:openWnd("imprint", ...)
    else
        UI:closeWnd("imprint")
    end
end)

Lib.subscribeEvent(Event.EVENT_BAG, function(isOpen, ...)
    if isOpen then
        UI:openWnd("bag", ...)
    else
        UI:closeWnd("bag")
    end
end)

Lib.subscribeEvent(Event.EVENT_OPEN_CHATBTN, function(isOpen)
    local window = UI:getWnd("toolbar", true)
    if window then
        if isOpen then
            if UI:getWnd("chatMain", true) then
                UI:openWnd(("chatMain"))
            else
                UI:openWnd("chat")
            end
        else
            if UI:getWnd("chatMain", true) then
                UI:closeWnd(("chatMain"))
            else
                UI:closeWnd("chat")
            end
        end
        if window.setChatOpened then
            window:setChatOpened(isOpen)
        end
    end
end)

Lib.subscribeEvent(Event.EVENT_SHOW_FINSHING, function(show)
    if show then
        UI:openWnd("fishing")
    else
        UI:closeWnd("fishing")
    end
end)

Lib.subscribeEvent(Event.EVENT_SHOW_RANK, function(rankType, uiName)
	uiName = uiName or "rank"
    if rankType then
		UI:openWnd(uiName, rankType)
    else
		UI:closeWnd(uiName)
	end
end)

Lib.subscribeEvent(Event.EVENT_SHOW_NEW_RANK, function(rankName, uiName)
    if rankName then
		UI:openWnd(uiName, rankName)
    else
		UI:closeWnd(uiName)
	end
end)

Lib.subscribeEvent(Event.EVENT_OPEN_MERCHANT, function(isOpen, showType, showTitle)
    if isOpen then
        if guiMgr:isEnabled() then
            UI:openShopInstance("commodity")
            return
        end
        UI:openWnd("merchantstores", showType, showTitle)
    else
        UI:closeWnd("merchantstores")
    end
end)

Lib.subscribeEvent(Event.EVENT_OPEN_UPGRADE_SHOP,function(isOpen)
    if isOpen then
        UI:openWnd("upgrade")
    else
        UI:closeWnd("upgrade")
    end
end)

Lib.subscribeEvent(Event.EVENT_SHOW_REVIVE, function(regId, coinId, coinCost, countDown, title, sure, cancel, msg, newReviveUI)
    UI:openWnd("tipDialog", 1, regId, coinId, coinCost, countDown, title, sure, cancel, msg, newReviveUI)
end)

Lib.subscribeEvent(Event.EVENT_SHOW_DIALOG_TIP, function(tipType,  ...)
    if tipType then
        UI:openWnd("tipDialog", tipType, ...)
    end
end)

Lib.subscribeEvent(Event.EVENT_BACK_KEY_DOWN,function()
    local quickExit = World.cfg.quickExit == nil and true or World.cfg.quickExit
	if not quickExit or UI:isOpen("mapLoadingPage") or UI:isOpen("loadingpage") then
		return
	end

    -- if UI:getWinState() then
	--     Lib.emitEvent(Event.EVENT_CLOSE_ALL_DIALOG)
	-- else
	-- 	if UI:isOpen("tipDialog") then
	-- 		UI:getWnd("tipDialog", true):onBtnClose()
	-- 	else
	-- 		Lib.emitEvent(Event.EVENT_CHECKED_MENU, true)
	-- 	end
	-- end

    -- close topmost dialog
    local dialogs = getAllOpenedDialogWindows(true)
    if dialogs and #dialogs > 0 then
        local lastOpenTime = 0
        local nameToClose = nil
        local timeT = 0

        for _, name in ipairs(dialogs) do
            timeT = UI:getWindowOpenTime(name)
            if timeT > lastOpenTime then
                lastOpenTime = timeT
                nameToClose = name
            end
        end

        if nameToClose ~= nil then
            UI:closeWnd(nameToClose)
            return
        end
    end

    -- close tips
    if UI:isOpen("tipDialog") then
        UI:getWnd("tipDialog", true):onBtnClose()
    end

    -- open setting window
	Lib.emitEvent(Event.EVENT_CHECKED_MENU, true)
end)

Lib.subscribeEvent(Event.EVENT_CHAT_KEY_DOWN,function()
	if not UI:isOpen("main") then
		return
	end
    if UI:isOpen("chat") then
		Lib.emitEvent(Event.EVENT_OPEN_CHATBTN, false)
    else
		Lib.emitEvent(Event.EVENT_OPEN_CHATBTN, true)
	end

end)

Lib.subscribeEvent(Event.EVENT_SHOW_ROUTINE, function (isOpen, content, data)
    if isOpen then
        UI:openWnd("routine", content, data)
    else
        UI:closeWnd("routine")
    end
end)

Lib.subscribeEvent(Event.EVENT_SHOW_TIP, function(guidePacket, cb, event)
	local window = UI:openWnd("tip")
    if guidePacket.clearCur then
        window:clearCur()
    end
	window:attach(guidePacket, cb, event)
end)

Lib.subscribeEvent(Event.EVENT_EDITOR_SHOW_TIP, function(node, text, dir, radius, curNode, cb, event)
	local window = UI:openWnd("mapEditGuideTip")
	window:attach(node, text, dir, radius, curNode, cb, event)
end)

Lib.subscribeEvent(Event.EVENT_HIDE_TIP, function(closeGuide)
	UI:closeWnd("tip")
    if closeGuide then
        UI:closeWnd("guide_mask")
    end
end)

Lib.subscribeEvent(Event.EVENT_EDITOR_HIDE_TIP, function()
	UI:closeWnd("mapEditGuideTip")
	UI:closeWnd("guide_mask")
end)

Lib.subscribeEvent(Event.EVENT_SHOW_CONTENTS_LIST, function(packet)
	local window = UI:openWnd("contents_list")
    if window then
        window:setContents(packet.contentsTittle, packet.contentsIcon,packet.contentsList)
    end
end)

Lib.subscribeEvent(Event.EVENT_LOADING_PAGE, function(showType, progress, fileSzie)
    if CGame.instance:getEditorType() == 2 then
        return
    end
    if guiMgr:isEnabled() then
        local window = UI:openSystemWindow("mapLoadingPage")
        if not rawget(window, "showLoadingPage") then
            window.close()
            window = UI:openSystemWindow("mapLoadingPage")
        end
        window:showLoadingPage(showType, progress, fileSzie)
        return
    end
    local window = UI:openWnd("mapLoadingPage")
    if window then 
        window:showLoadingPage(showType, progress, fileSzie)
    end
end)

Lib.subscribeEvent(Event.EVENT_OPEN_CHEST, function(isOpen, pos)
    if isOpen then
        UI:openWnd("chest", pos)
    else
        UI:closeWnd("chest")
    end
end)

Lib.subscribeEvent(Event.EVENT_OPEN_NPC_CHEST, function(isOpen, packet)
    if isOpen then
        UI:openWnd("npc_chest", packet.objID, packet.regId)
    else
        UI:closeWnd("npc_chest")
    end
end)

Lib.subscribeEvent(Event.EVENT_CHANGE_MOUSE_STATE, function(isMouseShow)
	if platformId ~= enumPlatformId.PC then --if not pc,then return
		return
	end
    if Player.CurPlayer and Player.CurPlayer.disableControl then
        return
    end

	-- if UI:getWinState() then
	-- 	CGame.instance:showMouse()
	-- 	return
	-- end

	-- local preMouseState =  CGame.instance:getMouseState()
	-- if(preMouseState == mouseState.SHOW) then
	-- 	CGame.instance:hideMouse()
	-- elseif(preMouseState == mouseState.HIDE) then
	-- 	CGame.instance:showMouse()
	-- else
	-- 	return		--todo,debug
	-- end

    if isMouseShow ~= nil then -- trigger by Clientsetting initialization
        if isMouseShow then
            CGame.instance:showMouse()
        else
            CGame.instance:hideMouse()
        end
    else -- trigger by key.mouse_state
        if Clientsetting:isMouseShow() then
            CGame.instance:hideMouse()
            Clientsetting:refreshMouseState(false)
        else
            CGame.instance:showMouse()
            Clientsetting:refreshMouseState(true)
        end
    end
end)

Lib.subscribeEvent(Event.EVENT_SHOW_TASK, function(isOpen, type, fullName, msg)
    if isOpen then
        local window = UI:openWnd("task")
        Lib.emitEvent(Event.EVENT_UPDATE_TASK_DATA, type or 0, fullName, msg)
    else
        UI:closeWnd("task")
    end
end)

Lib.subscribeEvent(Event.TASK_FINISH_HINT, function(fullName)
    local window = UI:openWnd("task")
    window:showTaskFinishHint(fullName)
end)

Lib.subscribeEvent(Event.EVENT_SHOW_FRIEND, function(isOpen)
    if isOpen then
        local window = UI:openWnd("friend")
    else
        UI:closeWnd("friend")
    end
end)

Lib.subscribeEvent(Event.SHOW_COMPOSITION, function (class, show)
    if show then
        UI:openWnd("composition", class)
    else
        UI:closeWnd("composition")
    end
end)

Lib.subscribeEvent(Event.SHOW_SUBMIT_RECIPE, function (class, recipeName, info, title, button)
    local window = UI:openWnd("composition")
    window:showSubmitRecipe(class, recipeName, info, title, button)
end)

Lib.subscribeEvent(Event.EVENT_SHOW_HOME, function(show, params)
    local window = UI:getWnd("home", true)
    if show then
        if window and UI:isOpen(window) then
            window:onOpen(params)
            return
        end
        UI:openWnd("home", params)
    else
        UI:closeWnd("home")
    end
end)

Lib.subscribeEvent(Event.SHOW_SNIPE, function (isOpen, snipeCfg, skill)
    if isOpen then
        UI:openWnd("snipe", snipeCfg, skill)
    else
        UI:closeWnd("snipe")
    end
end)


Lib.subscribeEvent(Event.EVENT_SHOW_SIGN_IN, function(isOpen)
    if isOpen then
        UI:openWnd("signIn")
    else
        UI:closeWnd("signIn")
    end
end)

Lib.subscribeEvent(Event.EVENT_SHOW_PARKU_SHOP, function(isOpen)
    if isOpen then
        UI:openWnd("parkuShop")
    else
        UI:closeWnd("parkuShop")
    end
end)

Lib.subscribeEvent(Event.EVENT_SHOW_CARDOPTIONS, function(packet)
    UI:openWnd("cardOptionsView", packet)
end)

Lib.subscribeEvent(Event.EVENT_SHOW_STORE, function(storeId, itemIndex)
    if storeId and itemIndex then
        UI:openWnd("store", storeId, itemIndex)
    end
end)

Lib.subscribeEvent(Event.EVENT_BACKPACK_DISPLAY, function(backpackKey, titleName, regId, relativeSize)
    UI:closeWnd("backpack_display")
    UI:openWnd("backpack_display", backpackKey, titleName, regId, relativeSize)
end)

Lib.subscribeEvent(Event.SHOW_TREASUREBOX, function(packet)
    local window = UI:openWnd("treasure_box")
	if window then
		window:initTreasureBox(packet)
	end
end)

Lib.subscribeEvent(Event.EVENT_SHOW_HIT_COUNT, function(start, finish, imageset)
	if start <= finish then
		UI:openWnd("hit_tip")
		Lib.emitEvent(Event.EVENT_UPDATE_HIT_COUNT, start, finish, imageset)
	else
		UI:closeWnd("hit_tip")
	end
end)

Lib.subscribeEvent(Event.EVENT_SHOW_PLAYER_KILL_COUNT, function(count)
	if count > 0 then
		UI:openWnd("kill_tip")
		if count > 1 then
			Lib.emitEvent(Event.EVENT_UPDATE_PLAYER_KILL_COUNT, count)
		end
	else
		UI:closeWnd("kill_tip")
	end
end)

Lib.subscribeEvent(Event.EVENT_GENERAL_OPTIONS, function(packet)
    if packet.close then
        UI:closeWnd("general_options")
    else
        local win = UI:openWnd("general_options")
        win:fillData(packet)
    end
end)

Lib.subscribeEvent(Event.EVENT_NEW_SHOP, function(params)
    local show = params.show
    local isOpen = show == nil and true or show
    if isOpen then
        UI:openWnd("newAppShop", params)
    else
        UI:closeWnd("newAppShop")
    end
end)

Lib.subscribeEvent(Event.EVENT_EQUIP_SKILL, function(skill)
    UI:openWnd("skillJack", skill)
end)

Lib.subscribeEvent(Event.EVENT_SHOW_GENERAL_OPTION_DERIVE, function(show, packet)
    if show ~= false then
        UI:openWnd("general_option_derive", packet)
    else
        UI:closeWnd("general_option_derive")
    end
end)

Lib.subscribeEvent(Event.EVNET_SHOW_INPUT_DIALOG, function(packet)
    local isClose = packet.contents and packet.contents.isClose
    if isClose then
        UI:closeWnd("inputDialog")
    else
        UI:openWnd("inputDialog", packet)
    end
end)

Lib.subscribeEvent(Event.EVENT_BROADCAST_PARTY_INVITE, function()
    local wnd = UI:getWnd("party_setting", true)
    if wnd then
        wnd:onClickBroadcastBtn()
    else
        Client.ShowTip(3, Lang:toText("tip.invite.need.in.party"), 40)
    end
end)

Lib.subscribeEvent(Event.EVENT_SHOW_PARTY_LIST, function(_, regId)
    UI:openWnd("party_list", regId)
end)

Lib.subscribeEvent(Event.EVENT_SHOW_PARTY_SETTING, function()
    UI:openWnd("party_setting")
end)

Lib.subscribeEvent(Event.EVENT_SHOW_PARTY_INNER_SETTING, function(show, packet)
    if show then
        UI:openWnd("party_inner_setting", packet)
    else
        UI:closeWnd("party_inner_setting")
    end
end)

Lib.subscribeEvent(Event.EVENT_SHOW_BGM_LIST, function(show)
	if show then
		UI:openWnd("bgm_list")
	else
		UI:closeWnd("bgm_list")
	end
end)

Lib.subscribeEvent(Event.EVENT_SHOW_EQUIP_UPGRADE, function(packet)
    UI:openWnd("equipUpgrade", packet)
end)

Lib.subscribeEvent(Event.EVENT_SHOW_PLAYERINFO_ON_HEAD, function(packet)
    UI:openEntityWnd(packet.objID, "head_playerinfo", 25, 15,packet)
end)

Lib.subscribeEvent(Event.EVENT_SHOW_GOLD_SHOP, function(show)
	if show then
		UI:openWnd("goldShop")
	else
		UI:closeWnd("goldShop")
	end
end)

Lib.subscribeEvent(Event.EVENT_SHOW_PRI_SHOP, function(show)
	if show then
		UI:openWnd("priShop")
	else
		UI:closeWnd("priShop")
	end
end)

Lib.subscribeEvent(Event.EVENT_SHOW_NEW_SIGIN_IN, function(show)
	if show then
		UI:openWnd("newSignIn")
	else
		UI:closeWnd("newSignIn")
	end
end)

Lib.subscribeEvent(Event.EVENT_SHOW_REWARD_EFFECT, function(type, fullName,count, time)
	local ui = UI:openWnd("rewardItemEffect")
	if ui then
		ui:addShowItem(type, fullName, count, time)
	end
end)

Lib.subscribeEvent(Event.EVENT_SHOW_ENTITY_HEADINFO, function(packet)
    UI:openHeadWnd(packet.objID, "entity_headinfo", 25, 15, packet)
end)

Lib.subscribeEvent(Event.EVENT_SHOW_SELL_SHOP, function(params)
    if params.show ~= false then
        UI:openWnd("sellShop", params)
    else
        UI:closeWnd("sellShop")
    end
end)

Lib.subscribeEvent(Event.SHOW_HEAD_COUNT_DOWN, function(packet)
	UI:openHeadWnd(packet.objID, "headCountDown",10, 10, packet.time)
end)

Lib.subscribeEvent(Event.EVENT_START_TRADE, function(show, tradeID, targetUid, tradeItem)
	local win = UI:openWnd("trade_platform")
	if show and win then
		win:openTrade(tradeID, targetUid, tradeItem)
	else
		UI:closeWnd("trade_platform")
	end
end)

Lib.subscribeEvent(Event.EVENT_REQUEST_TRADE, function(packet)
	local win = UI:openWnd("trade_platform")
	if win then
		win:showRequest(packet.playerName, packet.sessionId)
	end
end)

Lib.subscribeEvent(Event.EVENT_PROP_COLLECTION_COUNTDOWN, function(packet)
    local countDownWnd = UI:isOpenWindow("toolbar")
    if countDownWnd then
        countDownWnd:propCollectCountdown(packet.isCancel, packet.collectorsName, packet.CountdownTime, packet.autoCountDown, packet.fromPCGameOverCondition)
    end
end)

Lib.subscribeEvent(Event.EVENT_TRADE_NOTICE, function(msg)
	local win = UI:openWnd("trade_platform")
	if win then
		win:showMsg(msg, "Sure")
	end
end)

Lib.subscribeEvent(Event.EVENT_SHOW_TEAM_INFO, function(packet)
	local window = UI:openWnd("team_info")
	if window then
		window:showTeamInfo(packet)
    end
end)

Lib.subscribeEvent(Event.EVENT_SHOW_STAGE_EDIT_LIST, function(isOpen)
    if isOpen then
        UI:openWnd("stage_edit")
    else
        UI:closeWnd("stage_edit")
    end
end)

Lib.subscribeEvent(Event.EVENT_SHOW_TELEPORTER_TIP, function(isOpen, count, pairID, func, num)
    if isOpen then
        local win = UI:openWnd("teleporter_edit_tip")
        win:updateShowInfo(count, pairID, func, num)
    else
        UI:closeWnd("teleporter_edit_tip")
    end
end)

Lib.subscribeEvent(Event.EVENT_EDIT_MODE, function()
    --[[if CGame.instance:isEditorTool() then
        UI:openWnd("mapEditTestTool")
        CGame.instance:toggleDebugMessageShown(false)
    end
    UI:openWnd("mapEditToolbar")
    if UI:isOpen("mapEditMain") then
        UI:getWnd("mapEditMain"):onOpen()
        return
    end
    UI:openWnd("mapEditMain")

    UI:getWnd("mapEditItemBag")
    UI:getWnd("mapEditCompositeSetting"):initCellPool()
    require "MPeditor"]]--
end)

Lib.subscribeEvent(Event.EVENT_OPEN_EDIT_MAIN, function()
    UI:openWnd("mapEditToolbar")
	if UI:isOpen("mapEditMain") then
        UI:getWnd("mapEditMain"):onOpen()
        return
    end
	UI:openWnd("mapEditMain")
    UI:getWnd("mapEditCompositeSetting"):initCellPool()
end)

Lib.subscribeEvent(Event.EVENT_BLOCK_VECTOR, function(isOpen, ...)
    if isOpen then
        UI:openWnd("mapEditBlockVectorTip", ...)
    else
        UI:closeWnd("mapEditBlockVectorTip")
    end
end)

Lib.subscribeEvent(Event.EVENT_VECTOR_SET_VALUE, function(isOpen, ...)
    if isOpen then
        UI:openWnd("mapEditVector", ...)
    else
        UI:closeWnd("mapEditVector")
    end
end)

Lib.subscribeEvent(Event.EVENT_ENTITY_SETTING, function(id, pos, isClose)
	if isClose then
		UI:closeWnd("mapEditEntitySetting")
		return
	end
    if UI:isOpen("mapEditEntitySetting") then
        UI:closeWnd("mapEditEntitySetting")
    end
    UI:closeWnd("mapEditEntityPosUI")
	UI:openWnd("mapEditEntitySetting", id)
end)

Lib.subscribeEvent(Event.EVENT_ENTITY_SETTING_POINT, function(tb, isClose)
	if isClose then
		UI:closeWnd("mapEditEntityPosUI")
		return
	end
    if UI:isOpen("mapEditEntityPosUI") then
        UI:getWnd("mapEditEntityPosUI"):onOpen(tb)
        return
    end
    UI:closeWnd("mapEditEntitySetting")
	UI:openWnd("mapEditEntityPosUI", tb)
end)

Lib.subscribeEvent(Event.EVENT_ENTITY_SET_POS, function(id)
    UI:closeWnd("mapEditToolbar")
    if UI:isOpen("mapEditEntitySettingPos") then
        UI:getWnd("mapEditEntitySettingPos"):onOpen(id)
        return
    end
	UI:openWnd("mapEditEntitySettingPos", id)
end)

Lib.subscribeEvent(Event.EVENT_OPEN_ENTITY_TIPS, function(id, msg, state, isVisible,secondLevelText)
    if UI:isOpen("mapEditEntitySettingTip") then
        UI:getWnd("mapEditEntitySettingTip"):onOpen(id, msg, state)
        return
    end
	UI:openWnd("mapEditEntitySettingTip", id, msg, state,isVisible,secondLevelText)
end)

Lib.subscribeEvent(Event.EVENT_BUILDING_TOOLS, function(operationType, brush)
    if UI:isOpen("mapEditBuildingTools") then
        UI:getWnd("mapEditBuildingTools"):onOpen(operationType, brush)
        return
    end
	UI:openWnd("mapEditBuildingTools", operationType, brush)
end)

Lib.subscribeEvent(Event.EVENT_EDIT_TOOL_BAR, function()
	UI:openWnd("mapEditToolbar")
end)

Lib.subscribeEvent(Event.EVENT_EDIT_REPLACE, function()
	UI:openWnd("mapEditBuildingReplace")
end)

Lib.subscribeEvent(Event.EVENT_EDIT_MAP_MAKING, function()
    if platformId == enumPlatformId.PC then
        UI:openWnd("mapEditLoadingPage")
    else
         CGame.instance:showTipsInLoadingPage(Lang:toText("gui.message.res.loading"), false)
    end
end)

Lib.subscribeEvent(Event.EVENT_EDIT_ENTITY_DEL_TIP, function(entityId, uiType)
	if UI:isOpen("mapEditEntitySettingDelTip") then
        UI:getWnd("mapEditEntitySettingDelTip"):onOpen(entityId, uiType)
        return
    end
	UI:openWnd("mapEditEntitySettingDelTip", entityId, uiType)
end)

Lib.subscribeEvent(Event.EVENT_EDIT_OPEN_SHORTCUT, function(isOpen)
    if isOpen then
	    UI:openWnd("mapEditShortcut")
    else
        UI:closeWnd("mapEditShortcut")
    end
end)

Lib.subscribeEvent(Event.EVENT_EDIT_OPEN_GUIDE_WND, function(param)
    UI:openWnd("mapEditGuide", param)
end)

Lib.subscribeEvent(Event.EVENT_EDIT_OPEN_BACKGROUND, function(isOpen)
    if isOpen then
	    UI:openWnd("mapEditBackground")
    else
        UI:closeWnd("mapEditBackground")
    end
end)

Lib.subscribeEvent(Event.EVENT_OPEN_SAVEPANEL, function(isOpen, text)
    if isOpen then
		if UI:isOpen("savePanel") then
			UI:getWnd("savePanel"):onOpen(isOpen, text)
		end
	    UI:openWnd("savePanel", isOpen, text)
    else
        UI:closeWnd("savePanel")
    end
end)

Lib.subscribeEvent(Event.EVENT_EDIT_GLOBAL_SETTING, function(isOpen)
    if isOpen then
	    UI:openWnd("mapEditGlobalSetting")
    else
        UI:closeWnd("mapEditGlobalSetting")
    end
end)
Lib.subscribeEvent(Event.EVENT_SHOW_INVITE_TIP, function(packet)
    if UI:isOpen("invite_tip") then
        UI:closeWnd("invite_tip")
    end
    UI:openWnd("invite_tip", packet)
end)

Lib.subscribeEvent(Event.EVENT_SHOW_LONG_TEXT_TIP, function(packet)
    UI:openWnd("longTextTip", packet)
end)

Lib.subscribeEvent(Event.EVENT_SHOW_ANIMATION_TIP, function(key, dofunc)
    UI:openWnd("animationTip", key, dofunc)
end)

Lib.subscribeEvent(Event.EVENT_ADD_TASK_TRACE, function(fullName)
    local window = UI:openWnd("taskTracking", fullName)
    if not fullName then
        UI:closeWnd(window)
    end
    Lib.emitEvent(Event.EVENT_ADD_RIGHT_COLLAPSIBLE, fullName and window:root())
end)

Lib.subscribeEvent(Event.EVENT_CENTER_FRIEND_LOAD, function(friends)
    local window = UI:getWnd("invite_friends")
    window:onLoad(friends)
end)

Lib.subscribeEvent(Event.EVENT_SLIDING_PROMPT, function(data)
    local window = UI:openWnd("sliding_prompt")
    window:loadPrompt(data)
end)

Lib.subscribeEvent(Event.ENTITY_UPGLIDE_TIP, function(msg, keepTime)
    local wnd = UI:openWnd("upglide_tip")
    wnd:showTip(msg, keepTime)
end)

Lib.subscribeEvent(Event.EVENT_SHOW_ANIMOJI,function()
	local isOpen = UI:isOpen("Animoji")
    if not isOpen then
        UI:openWnd("Animoji")
    else
        UI:closeWnd("Animoji")
    end
end)

Lib.subscribeEvent(Event.EVENT_BE_ATTACKED,function(packet)
    local wnd = UI:openWnd("beAttackedFeedback")
    if not wnd then
        return
    end
    wnd:updateAttackerDirection(packet)
end)

Lib.subscribeEvent(Event.EVENT_GAME_RESULT, function (packet)
    local uiType = packet.result and packet.result.uiType or "Default"
    print("uiType", uiType)
    if GUIManager:Instance():isEnabled() then
        UI:openWindow("GameResultRank", nil, "_layouts_", packet, uiType)
    end
end)

Lib.subscribeEvent(Event.EVENT_GAME_SHOW_RESTART_BOX,function(packet)
    UI:openSystemWindow("GameRestartBox")
end)

if PlatformUtil.isPlatformWindows() then
    Lib.subscribeEvent(Event.EVENT_SCENE_TOUCH_BEGIN, function(x, y)
        UI:processMouseState(false)
    end)
    Lib.subscribeEvent(Event.EVENT_PC_GOTFOCUS, function()
        UI:processMouseState(false)
    end)
end