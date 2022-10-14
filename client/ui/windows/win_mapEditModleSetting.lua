local gridSize = 3
local itemSpace = 10
local titleImages = {
	"set:setting_modle.json image:title_icon_cn.png",
	"set:setting_modle.json image:title_icon_en.png"
}

function M:init()
	WinBase.init(self, "setting_modle_ui.json")
	self:initUIName()
	self:initUI()
	self:regEvent()
end

function M:initUIName()
	self.okBtn = self:child("setting_modle-ok")
	self.cancelBtn = self:child("setting_modle-cancel")
	self.actorUI = self:child("setting_modle-actorwnd")
	self.gridUI = self:child("setting_modle-actorGrid")

end

function M:initUI()
	self:child("setting_modle-tip_text"):SetText(Lang:toText("select_actor_model"))
	self.okBtn:SetText(Lang:toText("global.sure"))
    self.cancelBtn:SetText(Lang:toText("global.cancel"))
    local titleImage
	if World.Lang == "zh_CN" then
		titleImage = titleImages[1]
	else
		titleImage = titleImages[2]
	end
	self:child("setting_modle-title"):SetImage(titleImage)
	self.gridUI:InitConfig(itemSpace, itemSpace, gridSize)
	self.gridUI:SetAutoColumnCount(false)
    self.actorUI:SetActor1("")
end

function M:regEvent()
	self:subscribe(self.okBtn, UIEvent.EventButtonClick, function()
		local func = self.backFunc
		if func then
			func(self.selectData.actor)
		end
        UI:closeWnd(self)
    end)

	self:subscribe(self.cancelBtn, UIEvent.EventButtonClick, function()
        UI:closeWnd(self)
    end)
end

function M:newItemUI(itemData, index)
	local itemUI = GUIWindowManager.instance:LoadWindowFromJSON("modle_item.json")
	local nameUI = itemUI:child("modle_item-name")
	local btn = itemUI:child("modle_item-btn")
	local iconUI = itemUI:child("modle_item-icon")
	iconUI:SetImage(itemData.icon)
	iconUI:SetWidth({0, itemData.width or 60})
	iconUI:SetHeight({0, itemData.height or 150})
	nameUI:SetText(Lang:toText(itemData.name))
	self:subscribe(btn, UIEvent.EventRadioStateChanged, function()
		if btn:IsSelected() then
			self:selectItem(index)
		end
	end)
	return itemUI
end

function M:fetchAllActor()
	self.gridUI:RemoveAllItems()
	local actorList = Clientsetting.getData("selectActorList")
	for index, actorItem in ipairs(actorList) do
		local itemUI = self:newItemUI(actorItem, index)
		self.gridUI:AddItem(itemUI)
		self.itemUIs[index] = {
			ui = itemUI,
			data = actorItem
		}
	end
end

function M:selectItem(index, autoScroll)
	for k, itemData in pairs(self.itemUIs) do
		local itemUI = itemData.ui
		local data = itemData.data
		local nameUI = itemUI:child("modle_item-name")
		if k == index then
			nameUI:SetVisible(true)
			self.actorUI:SetActor1(data.actor, "idle")
			self.actorUI:SetActorScale(data.scale or 0.3)
			itemUI:child("modle_item-btn"):SetSelected(true)
		else
			itemUI:child("modle_item-btn"):SetSelected(false)
			nameUI:SetVisible(false)
		end
	end
	self.selectData = self.itemUIs[index].data
	if autoScroll then
		local contentHeight = self.gridUI:GetPixelSize().y
		local itemUI = self.itemUIs[index].ui
		local itemOriginY = itemUI:GetYPosition()[2]
		local itemHeight = itemUI:GetPixelSize().y
		local yOff = contentHeight - itemOriginY - itemHeight
		self.gridUI:SetOffset(0, yOff <= 0 and yOff or 0)
	end
end

function M:onOpen(params)
	self.itemUIs = {}
	self.backFunc = params and params.backFunc
	self:fetchAllActor()
	self:selectItem(1)
	if params.selectedActor then
		for k, itemData in pairs(self.itemUIs) do
			if itemData.data.actor == params.selectedActor then
				self:selectItem(k, true)
				break
			end
		end
	end
end

function M:onReload()

end

return M