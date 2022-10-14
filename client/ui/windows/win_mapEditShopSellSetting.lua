local itemSetting = require "editor.setting.item_setting"


function M:init()
	WinBase.init(self, "shopSellSetting.json")
	self:initUIName()
	self:initUI()
end

function M:initUIName()
	self.gridUI = self:child("shopSellSetting-gridview")
	self.currentyLayout = self:child("shopSellSetting-currency")
end

function M:initUI()
	self.gridUI:InitConfig(0, 35, 1)
	self.gridUI:SetMoveAble(false)
	self.gridUI:SetAutoColumnCount(false)
end

function M:fetch()
	self.gridUI:RemoveAllItems()
	self.currentyLayout:CleanupChildren()
	local params = self.params
	local limit = tonumber(params.limit)

	local function isBuffItem()
		local fullName = params.fullName
		if fullName == "/block" then
			return false
		end
		local cfg = itemSetting:getCfg(fullName)
		return (cfg.itembuff or cfg.attachBuff) and true or false
	end

	local limitSwitch = UILib.createSwitch({
		value = limit ~= -1 or false,
		index = 200
	}, function(value)
		-- self:setBasePropByPos(pos, value)
		self.params.limit = value == false and -1 or 1
		self:fetch()  
	end)
	limitSwitch:invoke("setPos", {0, 0})

	local num = params.num
	local numSlider = UILib.createSlider({value = num, index = 202}, function(value)
		self.params.num = value
	end)

	local price = params.price
	local priceSlider = UILib.createSlider({value = price, index = 203}, function(value)
		self.params.price = value
	end)

	local coinName = params.coinName
	local shopSell = UIMgr:new_widget("shopSell")
	shopSell:invoke("fillData", {
		coinName = coinName,
		backFunc = function(name)
			self.params.coinName = name
		end
	})
	self.currentyLayout:AddChildWindow(shopSell)
	self.currentyLayout:SetXPosition({0, 330})
	local isBuff = isBuffItem()
	if isBuff then
		self.params.limit = -1
		self.params.num = 1
	else
		self.gridUI:AddItem(limitSwitch)
		if limit ~= -1 then
			local limitSlider = UILib.createSlider({value = limit, index = 201}, function(value)
				self.params.limit = value
			end)
			self.gridUI:AddItem(limitSlider)
		end
		self.gridUI:AddItem(numSlider)
	end
	self.gridUI:AddItem(priceSlider)
	local itemCount = self.gridUI:GetItemCount()
	local item = self.gridUI:GetItem(itemCount - 1)
	self.currentyLayout:SetYPosition({0, item:GetYPosition()[2] + item:GetPixelSize().y + 50})
end

function M:onSave()
	local backFunc = self.params and self.params.backFunc
	if backFunc then
		self.params.backFunc = nil
		backFunc(Lib.copy(self.params))
	end
end

function M:onOpen(params)
	self.params = params
	self:fetch()
end

return M