---@class widget_base
local M = {}

function M:init(path, type, name)
	---@type CGUIWindow
	self._root = nil
	if path then
		self._root = GUIWindowManager.instance:LoadWindowFromJSON(path)
	else
		type = type or "Layout"
		name = name or ""
		self._root = GUIWindowManager.instance:CreateGUIWindow1(type, name)
	end
	self._root:connect(self)
	self:onLoad()
end

function M:onLoad()

end

---@return CGUIWindow
function M:root()
	return self._root
end

---@return CGUIWindow
function M:child(name)
	return self._root:child(name)
end

function M:setWidth(width)
	if not self._root then
		return
	end
	self._root:SetWidth(width)
end

function M:setHeight(height)
	if not self._root then
		return
	end
	self._root:SetHeight(height)
end

---@alias WindowEventHandler fun(window : CGUIWindow, dx : number, dy : number)
---@param widget CGUIWindow
---@param event string UIEvent
---@param cb WindowEventHandler
function M:subscribe(widget, event, cb, ...)
	return widget:subscribe(event, cb, ...)
end

---@param stack string
---@param widget GUIWindow
---@param event string UIEvent
---@param cb WindowEventHandler
function M:lightSubscribe(stack, widget, event, cb, ...)
	return widget:lightSubscribe(stack, event, cb, ...)
end

---@param widget CGUIWindow
---@param event string
function M:unsubscribe(widget, event)
	widget:unsubscribe(event)
end

function M:onDataChanged(data)

end

function M:destroy()
	UIMgr:cancelUITimerKey(self)
	self:onDestroy()
end

function M:onDestroy()

end

function M:onInvoke(key, ...)
	local fn = self[key]
	assert(type(fn) == "function", key)
	return fn(self, ...)
end

function M:SetMask(clickFunc)
	self._mask = GUIWindowManager.instance:CreateGUIWindow1("Layout", "")
	self._mask:SetLevel(100)
	self:root():AddChildWindow(self._mask)
	self._mask:SetArea({0, -1500}, {0, -1500},{0, 3000}, {0, 3000})
	self:subscribe(self._mask, UIEvent.EventWindowClick, function()
		if clickFunc then
			clickFunc()
		end
	end)
end

function M:isvisible()
	return self._root:IsVisible()
end

function M:get()
	return self
end

function M:addTimer(key)
	UIMgr:addUITimerKey(self, key)
end

return M
