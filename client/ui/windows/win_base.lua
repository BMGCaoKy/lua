local WinBase = WinBase ---@class WinBase
local LuaTimer = T(Lib, "LuaTimer") ---@type LuaTimer

-- function WinBase:init(path, key)
function WinBase:init(path)
	self._root = nil
	-- self._changeMouse = key   --window affect mouse state
	if path then
		---@type CGUIWindow
		self._root = GUIWindowManager.instance:LoadWindowFromJSON(path)
		self._root:connect(self)
		self._root:setData("jsonPath", path)
		-- todo: __index = root
		--print("GUIWindowManager.instance:LoadWindowFromJSON " .. path)
	end
end

-- function WinBase:key()
-- 	return self._changeMouse
-- end

---@return CGUIWindow
function WinBase:root()
	return self._root
end

---@return CGUIWindow
function WinBase:child(name)
	return self._root:child(name)
end

function WinBase:show()
	self._root:SetVisible(true)
end

function WinBase:hide()
	self._root:SetVisible(false)
end

function WinBase:isvisible()
	return self._root:IsVisible()
end

---@alias WindowEventHandler fun(window : CGUIWindow, dx : number, dy : number)
---@param widget widget_base
---@param event string UIEvent
---@param cb WindowEventHandler
function WinBase:subscribe(widget, event, cb, ...)
	return widget:subscribe(event, cb, ...)
end

---@param stack string
---@param widget CGUIWindow
---@param event string UIEvent
---@param cb WindowEventHandler
function WinBase:lightSubscribe(stack, widget, event, cb, ...)
	return widget:lightSubscribe(stack, event, cb, ...)
end

---@param widget CGUIWindow
---@param event string
function WinBase:unsubscribe(widget, event)
	widget:unsubscribe(event)
end

function WinBase:isShowAnim()
	return false
end

function WinBase:tryShowAnim()
	if not self:isShowAnim() then
		return
	end
	local color = self:root():GetBackgroundColor()
	if color[4] == 0 then
		return
	end
	---有半透明背景，算弹窗，增加背景子控件弹出动画
	local count = self:root():GetChildCount()
	for index = 1, count do
		local content = self:root():GetChildByIndex(index - 1)
		if content then
			local scale = 0.5
			content:SetScale(Lib.v3(scale, scale, scale))
			LuaTimer:scheduleTimer(function()
				if scale <= 1 then
					scale = scale + 0.1
				else
					scale = scale - 0.025
				end
				content:SetScale(Lib.v3(scale, scale, scale))
			end, 20, 10)
		end
	end
end

function WinBase:onOpen()

end

function WinBase:onClose()

end

function WinBase:onReload()

end
