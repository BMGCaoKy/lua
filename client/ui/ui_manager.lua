---@class UIMgr
local UIMgr = UIMgr

function UIMgr:init()
    UI:init()
	UIMgr.uiFileList = {}
	loadingUiPage("loading_page", 6)
end

function UIMgr:reload(name)
	UI:reloadWnd(name)
end

---@return WinBase
function UIMgr:new_wnd(name, ...)
	local m = {}
	local tbEnv = setmetatable({ M = m }, { __index = _G })

	local path, chuck = loadLua(string.format("ui/windows/win_%s", name), Root.Instance():getGamePath():gsub("\\", "/") .. "modules/engine_overwrite/client/?.lua")
	if not path then
		path, chuck = loadLua(
				string.format("gui/win_%s", name), Root.Instance():getGamePath():gsub("\\", "/") .. "lua/?.lua",
				string.format("ui/windows/win_%s", name), package.path)
	end
	if not path then
		path, chuck = loadLua(string.format("ui/" .. name), package.path)
	end
	if not path then
		print("new_wnd error:",name)
	end
	local ret, errorMsg = load(chuck, "@"..path, "bt", tbEnv)
	assert(ret, errorMsg)()
	UIMgr.uiFileList[name] = {
		path = path,
		time = lfs.attributes(path, "modification")
	}
	local tm = Lib.derive(WinBase, m)
    local obj = Lib.derive(tm)
    obj:init(...)
	if obj:root() then obj:hide() end
    return obj
end

---@return WightRootWindow
function UIMgr:new_widget(name, ...)
	local path, chuck = loadLua(string.format("ui/widget/widget_%s", name),
			Root.Instance():getGamePath():gsub("\\", "/") .. "modules/engine_overwrite/client/?.lua")
	if path then
		local class = require("modules/engine_overwrite/client/ui/widget/widget_" ..  name)
		local obj = Lib.derive(class)
		obj:init(...)
		return assert(obj:root())
	else
		local luaName = string.format("gui/widget_%s", name)
		local path, chuck = loadLua(luaName, Root.Instance():getGamePath():gsub("\\", "/") .. "lua/?.lua")
		if not path then
			luaName = string.format("ui/" .. name)
			path, chuck = loadLua(luaName, package.path)
		end
		local class = nil
		if not path then
			class = require(string.format("%s.widget_%s", "ui.widget", name))
		else-- custom gui will shield the engine gui
			local m = {}
			local tbEnv = setmetatable({M = m}, {__index = _G})
			local ret, errorMsg = load(chuck, "@"..path, "bt", tbEnv)
			assert(ret, errorMsg)()
			UIMgr.uiFileList[name] = {
				path = path,
				time = lfs.attributes(path, "modification")
			}
			class = require(luaName)
		end
		local obj = Lib.derive(class)
		obj:init(...)

		return assert(obj:root())
	end
end

---@return adapter_base
function UIMgr:new_adapter(name, ...)
	local luaName = string.format("gui/adapter_%s", name)
	local path, chuck = loadLua(luaName, Root.Instance():getGamePath():gsub("\\", "/") .. "lua/?.lua")
	local class = nil
	if not path then
		class = require(string.format("%s.adapter_%s", "ui.adapter", name))
	else-- custom gui will shield the engine gui
		local m = {}
		local tbEnv = setmetatable({M = m}, {__index = _G})
		local ret, errorMsg = load(chuck, "@"..path, "bt", tbEnv)
		assert(ret, errorMsg)()
		UIMgr.uiFileList[name] = {
			path = path,
			time = lfs.attributes(path, "modification")
		}
		class = require(luaName)
	end
	local obj = Lib.derive(class)
	obj:init(...)
	return obj
end

---@param cloneWnd CGUIWindow
---@param nameSuffix string
---@return CGUIWindow
function UIMgr:clone_wnd(cloneWnd, nameSuffix)
	---@type CGUIWindow
	local newWnd = GUIWindowManager.instance:CreateGUIWindow1(cloneWnd:GetTypeString(), nameSuffix .. cloneWnd:GetName())
	newWnd:Clone(nameSuffix, cloneWnd)
	return newWnd
end

local events = {}
function UIMgr:event_id(widget, event)
	local key = string.format("%s:%s", widget:getId(), event)
	events[key] = events[key] or {}	-- 保证key 唯一，不和其它系统冲突
	return events[key]
end

function ui_event(event, sender, ...)
	if (World.cfg and World.cfg.enableGlobalForceGuide) and Me.guildingId and sender:getId() ~= Me.guildingId and (event == UIEvent.EventWindowTouchDown or event == UIEvent.EventWindowClick) then
		-- print("----------------pick  out---------------------",sender:getId())
		return
	end
	-- if event == UIEvent.EventWindowTouchDown or event == UIEvent.EventWindowClick then
	-- 	print("---------------Me.guildingId----------------------",Me.guildingId)
	-- 	print("---------------sender:getId()----------------------",sender:getId())
	-- end
	
	if event == UIEvent.EventWindowDestroy then 
		assert(sender)
		sender:onDestroy()
	else
		if (event==UIEvent.EventWindowClick or event==UIEvent.EventButtonClick) and AT.OnOldWndClick then
			AT.OnOldWndClick(sender)
		elseif event==UIEvent.EventEditTextInput and AT.OnOldWndEdit then
			AT.OnOldWndEdit(sender)
		end
		local eid = UIMgr:event_id(sender, event)
		Lib.emitEvent(eid, ...)
	end
end

function window_event(event, window, ...)
	UI:handleWindowEvent(window, event, ...)
end

function ui_global_event(event, ...)
	UI:handleGlobalEvent(event, ...)
end

function scene_ui_load_layout(layoutName, scene_ui_id)
	local uiID = math.tointeger(scene_ui_id) or 0
	if uiID > 0 then
		UI:openSceneUI(layoutName, uiID)
	end
end

function scene_ui_unload_layout(scene_ui_id)
	local uiID = math.tointeger(scene_ui_id) or 0
	if uiID > 0 then
		UI:closeSceneUI(uiID)
	end
end

function loadingPage(showType, progress, fileSize)
	--if CGame.instance:getPlatformId() ~= 1 then
	--	return
	--end
	Lib.emitEvent(Event.EVENT_LOADING_PAGE, showType, progress, fileSize)
end

function loadingUiPage(event, ...)
    local eid = string.format("EVENT_%s",string.upper(event))
    if Event[eid] then
        Lib.emitEvent(Event[eid], ...)
    end
end

local UITimerKey = {}
local LuaTimer = T(Lib, "LuaTimer") ---@type LuaTimer
function UIMgr:addUITimerKey(type, key)
	local keys = UITimerKey[type] or {}
	table.insert(keys, key)
	UITimerKey[type] = keys
end

function UIMgr:cancelUITimerKey(type)
	local keys = UITimerKey[type] or {}
	for _, key in pairs(keys) do
		LuaTimer:cancel(key)
	end
	UITimerKey[type] = nil
end
