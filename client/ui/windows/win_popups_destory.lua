-- Ïú»Ùµ¯´°Ãæ°å
function M:init()
	self.objID = Me.objID
	WinBase.init(self, "CharacterPanelSurePopups.json",true)
	self.base= self:child("CharacterPanelSurePopups-Base")
	self.base:SetVisible(false)
	self:initBtns()
end

function M:setCurWndVisiable(isOpen)
	self.base:SetVisible(isOpen)
	self._root:SetVisible(isOpen)
end

function M:initBtns()
	local sureBtn = self:child("CharacterPanelSurePopups-Sure_Btn")
	local cancleBtn = self:child("CharacterPanelSurePopups-Cancle_Btn")
	sureBtn:SetText(Lang:toText("sure"))
	cancleBtn:SetText(Lang:toText("cancel"))
	self:child("CharacterPanelSurePopups-Tab_Text"):SetText(Lang:toText("sure_destroy_top_tip"))
	self:child("CharacterPanelSurePopups-Sure_Del_Text"):SetText(Lang:toText("sure_destroy_tip"))



	self:subscribe(sureBtn, UIEvent.EventButtonClick, function()
		local sloter = self.sloter
		if sloter then
			Me:sendPacket({ pid = "DeleteItem", objID = Me.objID,
							bag = sloter:tid(), slot = sloter:slot() })
		end
		self:setCurWndVisiable(false)
	end)

	self:subscribe(cancleBtn, UIEvent.EventButtonClick, function() self:setCurWndVisiable(false) end)
end

function M:openPopups(cell,sloter,backWnd,isClickOnBag)
	self.cell = cell
	self.sloter = sloter
	self.isClickOnBag = isClickOnBag

	local base = self.base
	backWnd:AddChildWindow(self._root)
	base:SetVisible(true)
	self:setCurWndVisiable(true)
	self._root:SetArea({ 0.5, -200 }, { 0, 40 }, { 0, 400 }, { 0, 312})
	base:SetHorizontalAlignment(0)
end

function M:resetSurePanel(flag)
	self.base:SetVisible(flag)
end

function M:onClose()
	self:setCurWndVisiable(false)
end

return M