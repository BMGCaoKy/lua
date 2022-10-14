-- 出售弹窗面板
function M:init()
	self.objID = Me.objID
	WinBase.init(self, "CharacterPaneSellPopups.json",true)
	self.base = self:child("CharacterPaneSellPopups-Base")
	self.base:SetVisible(false)
	self:initSellWnd()
end

local sellSloter = nil
local itemAllCount = 0
local sellCount = 1
local sellAmount = 0
local curItemCost = 0

function M:initSellWnd()
	local wndSell = self.base

	wndSell:child("CharacterPaneSellPopups-Tab_Text"):SetText(Lang:toText("bag_sell"))
	wndSell:child("CharacterPaneSellPopups-Sell_Number"):SetText(Lang:toText("allsell"))
	wndSell:child("CharacterPaneSellPopups-Sell_All_Money"):SetText(Lang:toText("allsellmoney"))

	self.textSellSure = wndSell:child("CharacterPaneSellPopups-Sure_Text"):SetText(Lang:toText("sure"))
	self.btnSellSure = wndSell:child("CharacterPaneSellPopups-Sure_Btn")

	self.textSellCancel = wndSell:child("CharacterPaneSellPopups-Cancle_Text"):SetText(Lang:toText("cancel"))
	self.btnSellCancel = wndSell:child("CharacterPaneSellPopups-Cancle_Btn")

	self.btnAdd = wndSell:child("CharacterPaneSellPopups-Add_Num_Btn")
	wndSell:child("CharacterPaneSellPopups-Add_Num_Text"):SetText(" + ")
	self.btnSub = wndSell:child("CharacterPaneSellPopups-Sub_Num_Btn")
	wndSell:child("CharacterPaneSellPopups-Sub_Num_Text"):SetText(" - ")
	self.textSellCount = wndSell:child("CharacterPaneSellPopups-Show_Sell_Number")
	self.textSellAmount = wndSell:child("CharacterPaneSellPopups-Show_All_Money")

	local function changeSellCount(addNumber)
		sellCount = sellCount + addNumber
        if sellCount < 1 then
			sellCount = itemAllCount
		elseif sellCount > itemAllCount then
			sellCount = 1
        end
		if 1 <= sellCount and sellCount <= itemAllCount then
			self.textSellCount:SetText(tostring(sellCount))
			sellAmount = curItemCost * sellCount
			self.textSellAmount:SetText(tostring(sellAmount))
		end
	end

	self:subscribe(self.btnAdd, UIEvent.EventButtonClick, function() changeSellCount(1) end)
	self:subscribe(self.btnSub, UIEvent.EventButtonClick, function() changeSellCount(-1) end)

	self:subscribe(self.btnSellSure, UIEvent.EventButtonClick, function()
		local sellSloter = self.sellSloter
		if sellSloter and sellCount > 0 then
			Me:sendPacket({ pid = "SellItem", objID = Me.objID, tid = sellSloter:tid(),
							slot = sellSloter:slot(), item_num = sellCount,  money = sellAmount })
		end
		self._root:SetVisible(false)
	end)

	self:subscribe(self.btnSellCancel, UIEvent.EventButtonClick, function() 
		self._root:SetVisible(false) 
	end)
end

function M:openPopups(cell,sloter,backWnd,isClickOnBag)
	self._root:SetVisible(true)
	self.cell = cell
	self.sellSloter = sloter
	self.isClickOnBag = isClickOnBag -- 判断是不是点的是装备中的装备

	sellCount = 1
	itemAllCount = sloter.stack_count and sloter:stack_count() or 0
	curItemCost = sloter:cfg().itemcost or 0
	self.textSellCount:SetText(tostring(sellCount))
	self.textSellAmount:SetText(tostring(curItemCost * sellCount))

	local base = self.base
	backWnd:AddChildWindow(self._root)
	base:SetVisible(true)
	self._root:SetArea({ 0.5, -200 }, { 0, 40 }, { 0, 400 }, { 0, 312})
	base:SetHorizontalAlignment(0)
end

function M:resetSellPanel(flag)
	self.base:SetVisible(flag)
end

function M:onClose()
	self.base:SetVisible(false)
	self._root:SetVisible(false)
end