local setting = require "common.setting"

function M:init()
    WinBase.init(self, "randomTableView.json", true)
	self.gridContainer = self:child("randomTableView-gridview")
	self.titleDesc = self:child("randomTableView-titleName")
end

local function getCfgColor(cfg)
	local color = Lib.copy(cfg)
	for i, k in ipairs(color or {}) do
		local pr = tonumber(color[i])
		color[i] = pr < 1 and pr or pr / 255
	end
	return color
end

function M:onOpen(cfgKey)
	local gridView = self.gridView
    local base_plugin = Me:cfg().plugin
    local cfg = setting:fetch("ui_config", not string.find( cfgKey, base_plugin .. "/") and (base_plugin .. "/" .. cfgKey) or cfgKey)
	self.titleDesc:SetText(Lang:toText(cfg.titleText or "scene.shop.desc"))
	for index, data in pairs(cfg.data or {}) do
		local childName = "randomTableView-item"..index
		local item = self:child(childName)
		if not item then
			return
		end
		self:child("randomTableView-img"..index):SetImage(data.img)
		local itemDesc = self:child("randomTableView-desc_"..index)
		itemDesc:SetFontSize(data.textSize or "HT12")
		itemDesc:SetText(Lang:toText(data.name))
		itemDesc:SetBackgroundColor(getCfgColor(data.backColor))
		if data.borderColor then
			itemDesc:SetTextBoader(getCfgColor(data.borderColor))
		end
	end
end

return M