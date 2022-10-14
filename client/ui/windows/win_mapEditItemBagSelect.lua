local itemSetting = require "editor.setting.item_setting"

function M:init()
    WinBase.init(self, "setting_edit_tab.json")
    self.m_root = self:child("Global-root")
	self.m_sure = self:child("Global-Sure")
	self:child("Global-BackBtn"):SetVisible(false)
	self:child("Global-Bt-Label"):SetVisible(true)

    self.m_cancel = self:child("Global-Cancel")

    self.m_sure:SetText(Lang:toText("global.sure"))
    self.m_cancel:SetText(Lang:toText("global.cancel"))

	self:subscribe(self.m_cancel, UIEvent.EventButtonClick, function()
        UI:closeWnd(self)
    end)

	self:subscribe(self.m_sure, UIEvent.EventButtonClick, function()
		local func = self.backFunc or function(item)
		end
		local canCloseSelf = true
		if func and self.bagWin then
			local item, isBuff = self.bagWin:getSelectItem()
			local backFunc = function(flag)
				func(item)
			end
			if isBuff then
				-- todo open ui for item
				backFunc = function(flag)
					if flag then
						func(item, isBuff)
						UI:closeWnd(self)
					else
						itemSetting:delBuffItem(item:full_name())
					end
				end
				local cfg = item:cfg()
				canCloseSelf = false
				if cfg.settingUI then
					UI:openMultiInstanceWnd("mapEditTabSetting", {
						data = {
							fullName = item:full_name(),
							itemType = item:type(),
							item = item,
							cfg = cfg
						},
						labelName = cfg.settingUI.tabList,
						fullName = item:full_name(),
						backFunc = backFunc,
				})
				end
			else
				backFunc()
			end
		end
		if canCloseSelf then
			UI:closeWnd(self)
		end
    end)
	self:addBagWin()
end

function M:setSureBackFunc(func)
	self.backFunc = func
end

function M:addBagWin()
	self.bagWin = self.bagWin or UI:openMultiInstanceWnd("mapEditItemBag2")
	self.m_root:AddChildWindow(self.bagWin:root())
end

function M:onOpen(params)
	self:root():SetLevel(10)
	local backFunc = params and params.backFunc
	if backFunc then
		self:setSureBackFunc(backFunc)
	end
	if self.bagWin then
		self.bagWin:onOpen(params.setDropItem, params.uiNameList)
	end
end

function M:onClose()
	if self.bagWin then
		self.bagWin:onClose()
	end
end

return M