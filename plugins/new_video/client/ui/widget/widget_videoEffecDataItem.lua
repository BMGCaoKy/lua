local widget_base = require "ui.widget.widget_base"
---@class WidgetVideoEffecDataItem : widget_base
local WidgetVideoEffecDataItem = Lib.derive(widget_base)

function WidgetVideoEffecDataItem:init(callBack)
	widget_base.init(self, "videoEffecDataItem.json")
	self._allEvent = {}
	self.data = nil
	self.callBack = callBack
	self:initUI()
	self:initEvent()
end

function WidgetVideoEffecDataItem:initUI()
	self.imgVideoEffecDataItemIcon = self:child("videoEffecDataItem-icon")
	self.txtVideoEffecDataItemTitleDec = self:child("videoEffecDataItem-titleDec")
	self.imgVideoEffecDataItemIconSelected = self:child("videoEffecDataItem-iconSelected")
	self.imgVideoEffecDataItemIconSelected:SetVisible(false)
end

function WidgetVideoEffecDataItem:setData(data, isSelect)
	self.data = data
	self.imgVideoEffecDataItemIcon:SetImage(data.icon)
	self.txtVideoEffecDataItemTitleDec:SetText(Lang:toText(data.titleLang))
	self:setSelectState(isSelect)
end
--注册按钮点击事件，常驻事件监听也可在这里添加
function WidgetVideoEffecDataItem:initEvent()
	self:lightSubscribe("error: WidgetNavigationDataListItem event : EventWindowClick",self:root(), UIEvent.EventWindowClick, function()
		self:setSelectState(true)
		if self.callBack and self.data then
			self.callBack(self.data.sortIndex)
		end
	end)
end

function WidgetVideoEffecDataItem:setSelectState(isSelect)
	self.imgVideoEffecDataItemIconSelected:SetVisible(isSelect)
end

function WidgetVideoEffecDataItem:onDestroy()
	if self._allEvent then
		for k, fun in pairs(self._allEvent) do
			fun()
		end
	end
end

return WidgetVideoEffecDataItem
