function M:init()
	WinBase.init(self, "Online-Consume-Remind.json", true)
	self.title = self:child("Online-Consume-Remind-Title")
	self.txt = self:child("Online-Consume-Remind-Text")
	self.checkTxt = self:child("Online-Consume-Remind-CheckTxt")
	self.checkBox = self:child("Online-Consume-Remind-Check")
	self.yesBtn = self:child("Online-Consume-Remind-Yes")
	self.noBtn = self:child("Online-Consume-Remind-No")
	self.closeBtn = self:child("Online-Consume-Remind-Close")

	self.title:SetText(Lang:toText("win.main.online.consume.remind.title"))
	self.txt:SetText(string.format( Lang:toText("win.main.online.consume.remind.txt"), 1 ))
	self.checkTxt:SetText(Lang:toText("win.main.online.consume.remind.checktxt"))
	self.yesBtn:SetText(Lang:toText("global.sure"))
	self.noBtn:SetText(Lang:toText("global.cancel"))
	self.checkBox:SetChecked(true)

	self:subscribe(self.yesBtn, UIEvent.EventButtonClick, function()
		if self.callbackFunc then
			self.callbackFunc()
			self.callbackFunc = nil
		end
		if self.checkBox:GetChecked() then
			Clientsetting.refreshRemindConsume(0)
		else
			Clientsetting.refreshRemindConsume(1)
		end
		UI:closeWnd(self)
	end)
	self:subscribe(self.noBtn, UIEvent.EventButtonClick, function()
		self.callbackFunc = nil
		UI:closeWnd(self)
	end)
	self:subscribe(self.closeBtn, UIEvent.EventButtonClick, function()
		self.callbackFunc = nil
		UI:closeWnd(self)
	end)
end

function M:setPrice(price)
	self.txt:SetText(string.format( Lang:toText("win.main.online.consume.remind.txt"), price or 1 ))
end

function M:setCallBack(func)
	self.callbackFunc = func
end