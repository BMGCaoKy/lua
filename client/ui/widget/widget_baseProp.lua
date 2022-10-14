local widget_base = require "ui.widget.widget_base"
local M = Lib.derive(widget_base)

function M:init()
	WinBase.init(self, "item_base_prop_setting.json")
	self:initUIName()
	self:initUI()
	self:initData()
end

function M:initUIName()
	self.gridUI = self:child("base_prop_setting-propGrid")
	self.titleLangKeyUI = self:child("base_prop_setting-title")
	self.nameLangUI = self:child("base_prop_setting-name")

end

function M:initData()
	self.modifyData = {}
end

function M:initUI()
	self.gridUI:InitConfig(0, 30, 1)
end

function M:fillData(params)
	-- params = {
	-- 	title = "xxxxxx", -- if not nil has 名称
	-- 	dataUIList = {
	-- 		{
	-- 			type = "slider",
	-- 			index = xxxx, 
	--			value = value,
	-- 		}
	-- 	}
	-- }
	if params then
		self.title = params.title
		self.dataUIList = params.dataUIList 
	end
	if self.title then
		self:setTitle()
	else
		self:hiheTitle()
	end
	self:fetch()
end

function M:setTitle()
	self.titleLangKeyUI:SetText(Lang:toText("editor.ui.itemName"))
	self.nameLangUI:SetText(Lang:toText(self.title))
end

function M:fetch()
	self.gridUI:RemoveAllItems()
	if not self.title then
		local padui = GUIWindowManager.instance:CreateGUIWindow1("Layout", "")
		padui:SetHeight({0, 120})
		self.gridUI:AddItem(padui)
	end
	for index, propItem in pairs(self.dataUIList or {}) do
		local ui
		self.modifyData[index] = {
			value = propItem.value,
		}
		if propItem.type == "slider" then
			ui = UILib.createSlider({value = propItem.value or 9999999, 
			index = propItem.index or 1, 
			listenType = "onFinishTextChange"}, 
			function(value, isInfinity)
				self.modifyData[index] = {
					value = value,
					isInfinity = isInfinity,
				}
				if isInfinity then
					ui:child("Slider-Edit"):SetText("∞")
				end
			end)
		end
		if ui then
			self.gridUI:AddItem(ui)
		end
	end
end

function M:hiheTitle()
	self.titleLangKeyUI:SetVisible(false)
	self.nameLangUI:SetVisible(false)
	self.gridUI:SetYPosition({0, -66})
end

function M:getModify()
	return self.modifyData
end

return M