local selectLevel

function M:init()
    WinBase.init(self, "gameQuality.json", true)

    self.selectImg = self:child("gameQuality-selecte")
    self:child("gameQuality-title"):SetText(Lang:toText("game.quality.title"))
    self:child("gameQuality-normal-txt"):SetText(Lang:toText("game.quality.normal.desc"))
    self:child("gameQuality-better-txt"):SetText(Lang:toText("game.quality.better.desc"))
    self:child("gameQuality-best-txt"):SetText(Lang:toText("game.quality.best.desc"))
    self:child("gameQuality-ok"):SetText(Lang:toText("game.quality.ok"))

    self.normalMode = self:child("gameQuality-normal")
	self.betterMode = self:child("gameQuality-better")
	self.bestMode = self:child("gameQuality-best") 

    self:subscribe(self.normalMode, UIEvent.EventButtonClick, function()
    	self:onSelect(1)
    end)
    self:subscribe(self.betterMode, UIEvent.EventButtonClick, function()
    	self:onSelect(2)
    end)
    self:subscribe(self.bestMode, UIEvent.EventButtonClick, function()
    	self:onSelect(3)
    end)
    self:subscribe(self:child("gameQuality-ok"), UIEvent.EventButtonClick, function()
    	self:onClickOK()
    end)
end


function M:onOpen()
	self:onSelect(math.modf(Clientsetting.getGameQualityLeve()))
end

function M:onSelect(level)
	if level == selectLevel then 
		return 
	end

	selectLevel = level
	self.selectImg:SetVisible(true)
	local xpos, ypos
	if level == 1 then 
		xpos = self.normalMode:GetXPosition()
		ypos = self.normalMode:GetYPosition()
	elseif level == 2 then 
		xpos = self.betterMode:GetXPosition()
		ypos = self.betterMode:GetYPosition()
	elseif level == 3 then 
		xpos = self.bestMode:GetXPosition()
		ypos = self.bestMode:GetYPosition()
	else
		return
	end
	self.selectImg:SetXPosition(xpos)
	self.selectImg:SetYPosition(ypos)
end

function M:onClickOK()
	if selectLevel then 
		Lib.emitEvent(Event.EVENT_TOOLBAR_TO_SETTING_QUALITY, selectLevel)
	end
	UI:closeWnd(self)
end

return M