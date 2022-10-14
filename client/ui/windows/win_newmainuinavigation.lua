M.NotDialogWnd = true


function M:init()
    self.objID = Me.objID
	WinBase.init(self, "NewMainAdditionalList.json")
	self.base = self:child("NewMainAdditionalList-Base")
    self.base:SetVisible(true)

    self.collapsibleTop = self:child("NewMainAdditionalList-Top-Collapsible")
    self.collapsibleTopBtn = self:child("NewMainAdditionalList-Top-Collapsible-Btn")
    self:subscribe(self.collapsibleTopBtn, UIEvent.EventWindowClick, function()
        self:topCollapsible(self.collapsibleTopBool)
    end)
    self.collapsibleTop:SetVisible(false)
    self.collapsibleTop:SetHeight({ 0, 0 })
    self.collapsibleView = UIMgr:new_widget("grid_view")
    self.collapsibleView:invoke("AREA", { 0, 0 }, { 0, 15 })
    self.collapsibleView:invoke("MOVE_ABLE", false)
    self.collapsibleView:invoke("AUTO_COLUMN", false)
    self.collapsibleView:invoke("ITEM_ALIGNMENT", 1)
    self.collapsibleView:invoke("INIT_CONFIG", 15, 15, 2)
    self.collapsibleTop:AddChildWindow(self.collapsibleView)

    self.collapsibleRight = self:child("NewMainAdditionalList-Right-Collapsible")
    self.rightContainer = self:child('NewMainAdditionalList-Right-Container')
    self.collapsibleRight:SetVisible(false)
    self.collapsibleRightBtn = self:child("NewMainAdditionalList-Right-Collapsible-Btn")
    self:subscribe(self.collapsibleRightBtn, UIEvent.EventWindowClick, function()
        self:rightCollapsible(self.collapsibleRightBool)
    end)

    self.baseArea = self:getBaseArea()
    self.uiNavOffset = World.cfg.uiNavOffset
    self.navs = World.cfg.uiNavigation
    self.flagInt = 85
    self.flagInt2 = 70
    self.topItem = 0
    self.toolbarItem = 0
    self.RightItem = self.minimap and 0 or 1
    self.topItem2 = 0
    self.collapsibleNum = 0
    self.collapsibleTopBool = true
    self.collapsibleRightBool = true
    self.lastHeight = 0
    self.lastWidth = 0
    self.navList = {}

    local num = 0
	repeat
		num = num + 1
		local tipName = "gui.shop.chat"..num
	until tipName == Lang:toText(tipName)
    self.langChatNum = num - 1
    self.isOpenShopChat = true

	self:initWnd()
    Lib.subscribeEvent(Event.NAV_COLLAPSIBLE_CHANGE, function(type, colBool)
        if type == "right" then
            self:rightCollapsible(not colBool)
        else
            self:topCollapsible(not colBool)
        end
    end)
    Lib.subscribeEvent(Event.EVENT_SYNC_PAUSE_STATE, function(state)
        if state ~= World.CurWorld:isGamePause() then 
            Blockman.Instance():setVerticalSlide(0)
            Blockman.Instance():setHorizonSlide(0)
            self:setPauseImg(state)
        end
    end)
    Lib.subscribeEvent(Event.EVENT_PAUSE_BY_CLIENT, function()
        Blockman.Instance():setVerticalSlide(0)
        Blockman.Instance():setHorizonSlide(0)
        local state = World.CurWorld:isGamePause()
        self:setPauseImg(state)
        if World.cfg.allowPause then 
            Game.Pause(not state)
        end
    end)

    Lib.subscribeEvent(Event.EVENT_MAP_RELOAD, function ()
        self:refreshNavArea()
    end)

    Lib.subscribeEvent(Event.EVENT_MAP_CLOSE, function ()
        self:refreshNavArea()
    end)

    Lib.subscribeEvent(Event.EVENT_CHANGE_NAV_OFFSET, function(offset)
        self.uiNavOffset = offset
        self:refreshNavArea()
    end)
end

function M:getBaseArea()
    local minimap = UI:getWnd("minimap", true)
    return self.uiNavOffset or (minimap and minimap._root:GetPixelSize() or self.base:GetPixelSize())
end

function M:initWnd()
    self:initNav()

    Lib.subscribeEvent(Event.EVENT_SHOW_NAV, function(name, show)
        self:updateNav(name, show)
    end)

    Lib.subscribeEvent(Event.EVENT_ADD_RIGHT_COLLAPSIBLE, function(window)
        self:addRightCollapsible(window)
    end)
end

function M:updateCollapsible(cell)
    local height = cell:GetPixelSize().y + 20
    if self.collapsibleNum == 0 then
        self.collapsibleTop:SetVisible(true)
        self.collapsibleTopBtn:SetRotate(self.collapsibleTopBool and 0 or 180)
    end
    self.collapsibleNum = self.collapsibleNum + 1
    self.collapsibleTop:SetHeight({ 0, height * (math.floor(self.collapsibleNum / 7)) + height })
    self.collapsibleView:invoke("ITEM_ALIGNMENT", self.collapsibleNum > 6 and 0 or 1)
    self.collapsibleView:invoke("INIT_CONFIG", 15, 15, self.collapsibleNum > 6 and 6 or self.collapsibleNum)
    self.collapsibleView:invoke("ITEM", cell)
end

function M:topCollapsible(collapsibleBool)
    self.collapsibleTopBool = not collapsibleBool
    self.collapsibleTop:SetHeight({ 0, self.collapsibleTopBool and 110 or 0 })
    self.collapsibleTopBtn:SetRotate(self.collapsibleTopBool and 0 or 180)
end

local function clearWnd(window)
    while window:GetChildCount() ~= 0 do
        local wnd = window:GetChildByIndex(0)
        window:RemoveChildWindow1(wnd)
    end
end

function M:addRightCollapsible(window)
    --todo 增加右导航页面信息可收缩展示框
    clearWnd(self.rightContainer)
    self.collapsibleRight:SetVisible(false)
    local height, width = 0, 0
    if window then
        self.collapsibleRight:SetVisible(true)
        local area = window:GetPixelSize()
        height = area.y
        width = area.x
        self.rightContainer:AddChildWindow(window)
        self.collapsibleRightBtn:SetRotate(self.collapsibleRightBool and 0 or 180)
    end
    self.collapsibleRight:SetHeight({ 0, height })
    self.collapsibleRight:SetWidth({ 0, width })
    self.lastWidth = width
end

function M:rightCollapsible(collapsibleBool)
    self.collapsibleRightBool = not collapsibleBool
    self.collapsibleRight:SetWidth({ 0, self.collapsibleRightBool and self.lastWidth or 0 })
    self.collapsibleRightBtn:SetRotate(self.collapsibleRightBool and 0 or 180)
end

function M:setPauseImg(state)
    if self.pause and self.pause.show then 
        if state then 
            self.pause.btn:SetNormalImage("set:pause.json image:pause.png")
        else
            self.pause.btn:SetNormalImage("set:pause.json image:continue.png")
        end
    end
end

local function fetchUiCell()
    return GUIWindowManager.instance:LoadWindowFromJSON("NewMainAdditionalCell.json")
end

local function updateCellArea(self,nav,cell)
    local area = cell:GetPixelSize()
    local x,y = self.baseArea.x,self.baseArea.y
    if nav.show then
        local list = nav.list
        if list == 1 or list == "top" then
            self.topItem = self.topItem + 1
            cell:SetArea({0,-x-self.topItem * self.flagInt},{0,0},{0,nav.size or area.x},{0,nav.size or area.y})
        elseif list == 2 then
            self.topItem2 = self.topItem2 + 1
            cell:SetArea({0,-x-self.topItem2 * self.flagInt},{0,80},{0,nav.size or area.x},{0,nav.size or area.y})
        elseif list == "right" then
            cell:SetArea({0,-self.flagInt},{0,y+self.RightItem * self.flagInt2},{0,nav.size or area.x},{0,nav.size or area.y})
            self.RightItem = self.RightItem + 1
        elseif list == "collapsible" then
            cell:SetArea({ 0, 0 }, { 0, 0 }, { 0, nav.size or area.x }, { 0, nav.size or area.y })
            self:updateCollapsible(cell)
            return
        elseif list == "toolbar" then
            self.toolbarItem = self.toolbarItem + 1
            cell:SetArea({0,-self.toolbarItem*(nav.size or area.x)},{0,nav.iconYOffset or 0},{0,nav.size or area.x},{0,nav.size or area.y})
            Lib.emitEvent(Event.EVENT_ADD_IN_NAVIGATION, cell)
            return
        end
    end
    self.base:AddChildWindow(cell)
end

local function updateUiEvent(self,navs)
    local composite = navs["composite"]
    local welfare = navs["welfare"]
    local shop = navs["shop"]
    local task = navs["task"]
    local rank = navs["rank"]
    local parkuShop = navs["parkuShop"]
    self.pause = navs["pause"]
    local newbieGuide = navs["newbieGuide"]

    if composite then
        composite.text:SetText(Lang:toText("additionalcell.composite_icon.text"))
        self:unsubscribe(composite.btn)
        self:subscribe(composite.btn, UIEvent.EventButtonClick, function()
            Lib.emitEvent(Event.SHOW_COMPOSITION, "myplugin/smithy", true)
        end)
    end

    if welfare then
        welfare.text:SetText(Lang:toText("additionalcell.welfare_icon.text"))
        self:unsubscribe(welfare.btn)
        self:subscribe(welfare.btn, UIEvent.EventButtonClick, function()
            Lib.emitEvent(Event.EVENT_SHOW_SIGN_IN, "myplugin/textile", true)
        end)
    end

    if shop then
        shop.text:SetText(Lang:toText("gui.app.shop"))
        if World.cfg["openShopChat"] then
            self:updateShopChatTip(shop.cell)
        end
        self:unsubscribe(shop.btn)
        self:subscribe(shop.btn, UIEvent.EventButtonClick, function()
            Lib.emitEvent(Event.EVENT_OPEN_APPSHOP, true)
        end)

    end

    if task then
        task.text:SetText(Lang:toText("additionalcell.task_icon.text"))
        self:unsubscribe(task.btn)
        self:subscribe(task.btn, UIEvent.EventButtonClick, function()
            Lib.emitEvent(Event.EVENT_SHOW_TASK, true)
        end)
        Lib.subscribeEvent(Event.TASK_STATUS_CHANGE, function(hint)
            task.tip:SetVisible(hint)
        end)
    end

    if rank then
        rank.text:SetText(Lang:toText(rank.langText or ""))
        self:unsubscribe(rank.btn)
        local rankType = rank.params[1]
        local uiName = rank.params[2]
        self:subscribe(rank.btn, UIEvent.EventButtonClick, function(rankType, uiName)
            Lib.emitEvent(Event.EVENT_SHOW_RANK, rankType, uiName)
        end, rankType, uiName)
    end

    if parkuShop then
        parkuShop.text:SetText(Lang:toText(parkuShop.langText or ""))
        self:unsubscribe(parkuShop.btn)
        self:subscribe(parkuShop.btn, UIEvent.EventButtonClick, function()
            Lib.emitEvent(Event.EVENT_SHOW_PARKU_SHOP, true)
        end)
    end

    if self.pause then
        self.pause.text:SetText(Lang:toText(self.pause.langText or ""))
        self:unsubscribe(self.pause.btn)
        self:subscribe(self.pause.btn, UIEvent.EventButtonClick, function()
            Lib.emitEvent(Event.EVENT_PAUSE_BY_CLIENT)
        end)
    end

    if newbieGuide then
        newbieGuide.text:SetText(Lang:toText(newbieGuide.langText or ""))
        self:unsubscribe(newbieGuide.btn)
        self:subscribe(newbieGuide.btn, UIEvent.EventButtonClick, function()
          Lib.emitEvent(Event.EVENT_PLAYER_SHOWNOVICEGUIDE, newbieGuide.params)
        end)
    end

    local i = 1
    while navs["event" .. i] do
        local event = navs["event" .. i]
        local text = event.text
        text:SetText(Lang:toText(event.langText or "additionalcell.event.text"))
        text:SetProperty("Font", event.font)
        text:SetYPosition({0, event.yOffset})
        self:unsubscribe(event.btn)
        self:subscribe(event.btn, UIEvent.EventButtonClick, function()
            Me:doCallBack("uiNavigation", "key", self.regId, {key = event.eventKey})
        end)
        i = i + 1
    end
end

function M:updateShopChatTip(cell)
	local num,str = self.langChatNum
	local time = self.isOpenShopChat and 100 or 6000

	if num < 1 then
		str = "Please call  Developer"
	else
		local chatNum = math.random(1,num)
		str = "gui.shop.chat"..chatNum
    end

    local m_shopTalk = cell:child("NewMainAdditionalCell-Show_Task")
    local m_shopTalkTxt = cell:child("NewMainAdditionalCell-Task_Text")

	m_shopTalk:SetVisible(self.isOpenShopChat)
    m_shopTalkTxt:SetText(Lang:toText(str))

	self.isOpenShopChat = not self.isOpenShopChat

	World.Timer(time, self.updateShopChatTip,self,cell)
end

function M:initNav()
    if not self.navs then
        return
    end

    for i, nav in ipairs(self.navs) do
        local cell = fetchUiCell()
        nav.show = nav.show == nil and true or nav.show
        updateCellArea(self,nav,cell)
        local image = cell:child("NewMainAdditionalCell-Icon")
        image:SetImage(nav.iconPath)
        if nav.effect then
            image:PlayEffect1(nav.effect)
        end
        local text = cell:child("NewMainAdditionalCell-Text")
        local btn = cell:child("NewMainAdditionalCell-Btn")
        if nav.eventKey then
		    btn:SetName("NewMainAdditionalCell-Btn-"..nav.eventKey)
        end
        local tip = cell:child("NewMainAdditionalCell-Tip_Icon")

        local _tb = {
            cell = cell,
            show = nav.show,
            name = nav.name or i,
            eventKey = nav.eventKey,
            langText = nav.text,
            params = nav.params,
            image = image,
            text = text,
            btn = btn,
            tip = tip,
            list = nav.list,
            font = nav.font or "HT18",
            iconYOffset = nav.iconYOffset,
            size = nav.size,
            yOffset = nav.yOffset or 0
        }

        self.navList[_tb.name] = _tb
        cell:SetVisible(_tb.show)
    end

    updateUiEvent(self,self.navList)

end

function M:updateNav(name, show)
    local navs = self.navList
    if name then
        local nav = navs[name]
        if nav then
            nav.cell:SetVisible(show)
            nav.show = show

            self.topItem = 0
            self.toolbarItem = 0
            self.RightItem = self.minimap and 0 or 1
            self.topItem2 = 0
            for i,nav in ipairs(self.navs or {}) do
                local n = navs[nav.name]
                updateCellArea(self,n,n.cell)
            end
            updateUiEvent(self,navs)
        end
    end
end

function M:refreshNavArea()
    if not self.navs then
        return
    end
    self.baseArea = self:getBaseArea()
    self.topItem = 0
    self.toolbarItem = 0
    self.RightItem = self.minimap and 0 or 1
    self.topItem2 = 0
    for _, nav in ipairs(self.navs) do
        local n = self.navList[nav.name]
        if n then
            updateCellArea(self, n, n.cell)
        end
    end
end

function M:onOpen(regId)
    if not self.regId then
        self.regId = regId
    end
end

function M:onClose()

end

return M