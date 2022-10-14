local setting = require "common.setting"

function M:init()
    WinBase.init(self, "randomTable.json", true)
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
    local base_plugin = Me:cfg().plugin
    local cfg = setting:fetch("ui_config", not string.find( cfgKey, base_plugin .. "/") and (base_plugin .. "/" .. cfgKey) or cfgKey)
	local array = cfg.data or {}
	for index, data in pairs(array) do
		local itemName = "randomTable-item" .. index
		local textName = "randomTable-desc_"..index
		local item = self:child(itemName)
		local text = self:child(textName)
		if item and text then
			item:SetBackgroundColor(getCfgColor(data.backColor))
			text:SetText(Lang:toText(data.name))
			text:SetFontSize(data.textSize or "HT12")
			if data.borderColor then
				text:SetTextBoader(getCfgColor(data.borderColor))
			end
		end
	end
end

return M


