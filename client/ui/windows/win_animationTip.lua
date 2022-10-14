local setting = require "common.setting"

function M:init()
	WinBase.init(self, "AnimationTip.json")

	Lib.subscribeEvent(Event.EVENT_SCENE_TOUCH_BEGIN, function()
		if self.clickStop then
			return
		end
		self.clickStop = World.Timer(5, function()
			self:stopAnimat()
		end)
	end)
	Lib.subscribeEvent(Event.EVENT_SCENE_TOUCH_MOVE, function()
		if self.clickStop then
			self.clickStop()
			self.clickStop = nil
		end
	end)
	self.actor = self:child("AnimationTip-Actor")
end

function M:onOpen(cfgKey, callback)
	self.callback = callback
    local base_plugin = Me:cfg().plugin
    local cfg = setting:fetch("ui_config", not string.find( cfgKey, base_plugin .. "/") and (base_plugin .. "/" .. cfgKey) or cfgKey)
	self.actor:UpdateSelf(1)
	self.actor:SetActor1(cfg.actor or "g2020_gift_open.actor",cfg.skill or "idle")
	local skins = EntityClient.resetSkin(cfg.skin or {})
	for k, v in pairs(skins or {}) do
		self.actor:UseBodyPart(k, v)
	end
	self.actor:SetActorScale(cfg.scale or 1)
	self.stopTimer = World.Timer(cfg.time or 50, function()
		self:stopAnimat()
	end)
end

function M:stopAnimat()
	if self.stopTimer then
		self.stopTimer()
		self.stopTimer = nil
	end
	if self.clickStop then
		self.clickStop()
		self.clickStop = nil
	end
	if self.callback then
		self.callback()
		self.callback = nil
	end
	self.actor:SetActor1("","")
	UI:closeWnd(self)
end

