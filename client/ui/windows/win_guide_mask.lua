local m_posx, m_posy, m_radius = 0,0,0
local checkPos = false

function M:init()
	WinBase.init(self, "GuiMask.json")
	self:root():setBelongWhitelist(true)
    self:root():SetAlwaysOnTop(true)
	self:root():SetLevel(1)
	self.mask = self:child("Mask-guideMask")
end

function M:setNoCheckPos()
	checkPos = true
end

function M:updateMask(posx, posy, radius, needForce)
	if m_posx == posx and m_posy == posy and m_radius == radius and not checkPos then
		return
	end
	m_posx, m_posy, m_radius = posx, posy, radius
	UI.guideMask = {x = tonumber(posx), y = tonumber(posy), r = tonumber(radius)}
	self.mask:setGuideMask(posx, posy, radius)
	self.mask:SetTouchable(needForce)
end

function M:updateMaskForce(posx, posy, radius, needForce)
	--if m_posx == posx and m_posy == posy and m_radius == radius then
	--	return
	--end
	m_posx, m_posy, m_radius = posx, posy, radius
	UI.guideMask = {x = tonumber(posx), y = tonumber(posy), r = tonumber(radius)}
	self.mask:setGuideMask(posx, posy, radius)
	self.mask:SetTouchable(needForce)
end

function M:setMask(area, needForce, posx, posy, radius)
	self.mask:setRectangleMask(area)
	self.mask:SetTouchable(needForce)
	UI.guideMask = {x = tonumber(posx), y = tonumber(posy), r = tonumber(radius)}
end

function M:setEffect(posx, posy, clickEffect)
	if self.clickEffect == clickEffect then
		return
	end
	self.clickEffect = clickEffect
	self.mask:RemoveChildWindow("show-effect")
	--self.mask:CleanupChildren()
	local showEffect = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "show-effect")
	showEffect:SetTouchable(false)
	showEffect:SetArea({ 0, posx }, { 0, posy }, { 0, 50 }, { 0, 50 })
	showEffect:PlayEffect1(clickEffect)
	showEffect:SetLevel(49)
	self.mask:AddChildWindow(showEffect)
end

function M:onClose()
	UI.guideMask = {}
	local count = self.mask:GetChildCount()
	for i = 1, count do
		local child = self.mask:GetChildByIndex(0)
		self.mask:RemoveChildWindow1(child)
	end
	self.clickEffect = nil
end

return M
