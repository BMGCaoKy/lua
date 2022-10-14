function M:init()
    WinBase.init(self, "savePanel_edit.json")
    self.mask = self:child("Save-Mask")
    self.tipsText = self:child("Entity-Tool-Tip-text")
	self:setTipText("Edit_SavePanel_text")
end

function M:setTipText(msg)
	if msg then
		msg = Lang:toText(msg)
		local width = self.tipsText:GetFont():GetTextExtent(msg,1.0) +  30
		self.tipsText:SetWidth({0 , width })
		self.tipsText:SetText(msg)
	end
end

function M:onOpen(isOpendMask, text)
    self.mask:SetVisible(isOpendMask)
	self:setTipText(text)
end

function M:onReload(reloadArg)
   
end

return M