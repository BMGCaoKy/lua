local setting = require "common.setting"
local uiCfg = setting:fetch("ui_config", "myplugin/rewardItemEffect") or {}

function M:init()
	WinBase.init(self, "rewardItemEffet.json", true)
	self.itemImg = self:child("rewardItemEffet-itemImg")

	self:subscribe(self:child("rewardItemEffet-closeBtn"), UIEvent.EventButtonClick, function()
		UI:closeWnd(self)
	end)
	self.head = 1
	self.last = 0
	self.queue = {}
end

local SHOW_TYPE = {
	IMG = "Image",
	ITEM = "Item",
	BLOCK = "Block",
	COIN = "Coin",
	SKILL = "Skill",
}

function M:onOpen()
	
end

function M:addShowItem(type, ...)
	self.last = self.last + 1
	self.queue[self.last] = {
		type = type,
		args = table.pack(...)
	}
	if not self.showTimer then
		self:showItemUI()
	end
end

function M:showItemUI()-- key, count, time
	if self.head > self.last then
		return
	end
	local data = Lib.copy(self.queue[self.head])
	self.queue[self.head] = nil
	self.head = self.head + 1
	if not data then
		return
	end
	self:show()
	local type = data.type
	local args = data.args
	if type == SHOW_TYPE.IMG then
		self:showImg(table.unpack(args))
	elseif type == SHOW_TYPE.ITEM then
		self:showItem(table.unpack(args))
	elseif type == SHOW_TYPE.BLOCK then
		self:showBlock(table.unpack(args))
	elseif type == SHOW_TYPE.COIN then
		self:showIcon(table.unpack(args))
	elseif type == SHOW_TYPE.SKILL then
		self:showSkill(table.unpack(args))
	else
		self:showOther(type, table.unpack(args))
	end
end

function M:showUI(img, count, time, showImage)
	if string.find(img, "http:") == 1 or string.find(img, "https:") then
		self.itemImg:SetImage("")
		self.itemImg:SetImageUrl(img)
	else
		self.itemImg:SetImageUrl(" ")
		self.itemImg:SetImage(img)
	end
	self:child("rewardItemEffet-effect"):PlayEffect()
	self:child("rewardItemEffet-itemCount"):SetText("X"..(count or 1))
	if showImage then
		self:child("rewardItemEffet-level"):SetImage(showImage)
	else
		self:child("rewardItemEffet-level"):SetImage("")
	end
	if self.showTimer then
		self.showTimer()
	end
	self.showTimer = World.Timer(time or 50, function()
		self.showTimer()
		self.showTimer = nil
		if self.head <= self.last then
			self:hide()
			self.showTimer = World.Timer(uiCfg.interval or 30, function()
				self:showItemUI()
				return false
			end)
		else
			UI:closeWnd(self)
		end
		return false
	end)
end

function M:showImg(img, count, time)
	self:showUI(img, count, time)
end

function M:showItem(fullName, count ,time)
	local item = Item.CreateItem(fullName)
	local icon = item:icon()
	self:showUI(icon, count or 1, time or 20, item:cfg().showImage)
end

function M:showSkill(fullName, count ,time)
	local skill = Skill.Cfg(fullName)
	local icon = skill:getIcon()
	self:showUI(icon, count or 1, time or 20, nil)
end

function M:showOther(type, fullName, count, time)
	local cfg = setting:fetch(type, fullName)
	local icon = ResLoader:loadImage(cfg, cfg.icon)
	self:showUI(icon, count or 1, time or 20, nil)
end

function M:showBlock(fullName, count, time)
	 local item = Item.CreateItem("/block", 1, function(item)
            item:set_block(fullName)
        end)
     local icon = item:icon()
	 self:showUI(icon, count or 1, time or 20, item:cfg().showImage)
end

function M:showIcon(fullName, count, time)
	local icon = Coin:iconByCoinName(fullName)
	self:showUI(icon, count or 1, time)
end

return M
