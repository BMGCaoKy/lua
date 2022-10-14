function M:init()
   WinBase.init(self, "AlternativeDialog.json", false)

   self.dialogPanel = self:child("AlternativeDialog-Panel")
   self.buttonPanel = self:child("AlternativeDialog-Panel-Btn-Bg")
   self.leftBtn = self:child("AlternativeDialog-LeftBtn")
   self.rightBtn = self:child("AlternativeDialog-RightBtn")
   self.messageText = self:child("AlternativeDialog-Content-Other-Message")
   self.closeBtn = self:child("AlternativeDialog-CloseBtn")
   self.titleText = self:child("AlternativeDialog-Title-Name")
   self.titleText:SetText(Lang:toText("ui_tip"))

   self.leftIconText = self:child("AlternativeDialog-Left-Icontext")
   self.rightIconText = self:child("AlternativeDialog-Right-Icontext")
   self.leftIcon = self:child("AlternativeDialog-Left-Icon")  
   self.rightIcon = self:child("AlternativeDialog-Right-Icon")
   self.leftCenterText = self:child("AlternativeDialog-left-centerText")
   self.rightCenterText = self:child("AlternativeDialog-Right-centerText")
   self.callBack = nil

   self:subscribe(self.closeBtn, UIEvent.EventButtonClick, function()
		UI:closeWnd(self)
   end)

   self:subscribe(self.leftBtn, UIEvent.EventButtonClick, function()
		UI:closeWnd(self)
		if self.callBack then
			self.callBack(true)
		end
   end)

   self:subscribe(self.rightBtn, UIEvent.EventButtonClick, function()
        UI:closeWnd(self)
		if self.callBack then
			self.callBack(false)
		end
   end)
end
--if have new showtype then set else use default
function M:onOpen(showArg, callBack)
	self.callBack = callBack
	if showArg.leftIcon then
		self.leftIcon:SetImage(showArg.leftIcon)
		self.leftIconText:SetText(Lang:toText(showArg.leftText))
		self.leftCenterText:SetText("")
	else
		self.leftIcon:SetImage("")
		self.leftIconText:SetText("")
		self.leftCenterText:SetText(Lang:toText(showArg.leftText))
	end
	if showArg.rightIcon then
		self.rightIcon:SetImage(showArg.rightIcon)
		self.rightIconText:SetText(Lang:toText(showArg.rightText))
		self.rightCenterText:SetText("")
	else
		self.rightIcon:SetImage("")
		self.rightIconText:SetText("")
		self.rightCenterText:SetText(Lang:toText(showArg.rightText))
	end
	self.titleText:SetText(Lang:toText(showArg.titleText or "ui_tip"))
	self.messageText:SetText(Lang:toText(showArg.msgText or ""))

	if not showArg.changUIstyle then
		return
	end
	self.leftBtn:SetPushedImage(showArg.leftBtnPushImage or "set:tip_dialog.json image:btn_big_blue")
	self.leftBtn:SetNormalImage(showArg.leftBtnNormalImage or "set:tip_dialog.json image:btn_big_blue")
	self.rightBtn:SetPushedImage(showArg.rightBtnPushImage or "set:tip_dialog.json image:btn_big_green")
	self.RightBtn:SetNormalImage(showArg.rightBtnNormalImage or "set:tip_dialog.json image:btn_big_green")
	self.closeBtn:SetPushedImage(showArg.closeBtnPushImage or "")
	self.closeBtn:SetNormalImage(showArg.closeBtnNormalImage or "")
	self.dialogPanel:SetBackImage(showArg.panelBg or "set:tip_dialog.json image:background")
	self.buttonPanel:SetBackImage(showArg.buttonPanelBg or "set:tip_dialog.json image:btn_background")

	self.messageText:SetTextColor(showArg.msgTextColor or {255/255, 255/255, 255/255})
	
	local panelArea = showArg.panelArea
	if panelArea and type(panelArea) == "table" then
		self.dialogPanel:SetArea(table.unpack(panelArea))
	else
		self.dialogPanel:SetArea({0, 0},{0, 0},{0, 618},{0, 332})
	end

	local buttonPanelArea = showArg.buttonPanelArea
	if buttonPanelArea and type(buttonPanelArea) == "table" then
		self.buttonPanel:SetArea(table.unpack(buttonPanelArea))
	else
		self.buttonPanel:SetArea({0, 0},{0, 0},{0.971, 0},{0.225, 0})
	end
end

return M