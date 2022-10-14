---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by work.
--- DateTime: 2018/8/29 9:57
---

local PROGRESSBAR_MAX = 580
local PROGRESSBAR_MIN = 32
local PROGRESSBAR_OFF = 90

local function castSkill()
	local data = Me:data("fishing")
	if data.skillName then
		Skill.Cast(data.skillName)
	end
end

local function cancelSkill()
	local data = Me:data("fishing")
	if data.skillName then
		Skill.Cast(data.skillName, {method="cancel"})
	end
end

function M:init()
    WinBase.init(self, "Fishing.json")
	self:subscribe(self:child("Fishing-button_throw"), UIEvent.EventButtonClick, castSkill)
	self:subscribe(self:child("Fishing-button_pull"), UIEvent.EventButtonClick, castSkill)
	self:setProgress(-1)
	self.handClick = self:child("Fishing-button_pull"):GetChildByIndex(0)
	Lib.subscribeEvent(Event.EVENT_SHOW_FISHING_CATCH_GUIDE, function(isNeedGuide)
		self.handClick:SetVisible(isNeedGuide)
		self.needFishingCatchGuide = isNeedGuide
	end)
end

function M:onOpen()
    local function tick()
		local data = Me:data("fishing")
		if data.skillName then
			local skill = Skill.Cfg(data.skillName)
			self:child("Fishing-button_throw"):SetVisible(true)
			self:child("Fishing-button_pull"):SetVisible(data.state=="catch")
			local value = skill:getRunValue(Me)
			if value>100 then
				value = 100
				cancelSkill()
                Lib.emitEvent(Event.EVENT_CENTER_TIPS, 40, nil, nil, { "gui_fishrun_tip" })
			end
			self:setProgress(value)
			if self.needFishingCatchGuide then
				self:hand_click()
			end
		else
			self:child("Fishing-button_throw"):SetVisible(false)
			self:child("Fishing-button_pull"):SetVisible(false)
		end
        return true
	end
	
	tick()
    self.timer = World.Timer(1, tick)
end

local maxY = -80
local minY = -100
local moveY = -5
local curY = nil
function M:hand_click()
	local hand = self.handClick
	if not hand then
		return 
	end
	if not curY then
		curY = hand:GetYPosition()[2]
	end
	if curY <= minY or curY >= maxY then
		moveY =  -1 * moveY
	end
	curY = curY + moveY
	hand:SetYPosition({0, curY})
end

function M:onClose()
	if self.timer then
		self.timer()
		self.timer = nil
	end
	cancelSkill()
end

function M:setProgress(value)
	if value<0 then
		self:child("Fishing-ProgressBar"):SetVisible(false)
		return
	end

	local width = value / 100 * (PROGRESSBAR_MAX - PROGRESSBAR_MIN) + PROGRESSBAR_MIN

	self:child("Fishing-ProgressBar"):SetVisible(true)
	self:child("Fishing-ProgressBar-Bar"):SetWidth({0,width})
	self:child("Fishing-ProgressBar-Fish"):SetXPosition({0,-width+PROGRESSBAR_OFF})
end

return M