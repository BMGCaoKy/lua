local EFFECT_INTERVAL = 1
local EFFECT_TIME = 2 --时间越久速度越慢
local IgnoreCache = false

function M:init()
    self._defaultFlag = true
    WinBase.init(self, "AppMainRole.json", true)
    self:initUiName()
    self:initConfig()
    self:initTouch()
    self._entityInfoCache = {}
    self:child("main-windows_bg"):SetTouchPierce(true)
    -- self:child("main-childUi"):SetTouchPierce(true)
    self:subscribe(self.closeBtn, UIEvent.EventButtonClick, function()
        Lib.emitEvent(Event.EVENT_MAIN_ROLE, false)
    end)
    Lib.subscribeEvent(Event.FETCH_ENTITY_INFO, function(ignoreCache)
        if not self._curCfg then
            return
        end
        IgnoreCache = ignoreCache
        if self._curCfg.entityType then
            self:getInfoByID(self._objID, Define[self._curCfg.entityType], ignoreCache)
        end
    end)
end


function M:initTouch()
    self.leftTabLayout:SetTouchable(false)
    self.letTabList:SetTouchable(false)
    self:child("main-bgColor"):SetTouchable(false)
end

function M:subscribeEvent()
    self._allEvent[#self._allEvent + 1] = self:subscribe( self._root, UIEvent.EventWindowClick, function()
        UI:closeWnd("popups_property")
    end)

    self._allEvent[#self._allEvent + 1] = self:subscribe( self:child("main-bag_left_pannel"), UIEvent.EventWindowClick, function()
        UI:closeWnd("popups_property")
    end)

    self._allEvent[#self._allEvent + 1] = self:subscribe( self:child("main-bag_right_pannel"), UIEvent.EventWindowClick, function()
        UI:closeWnd("popups_property")
    end)

end

local function fiterCfg(cfg)
    local i = 1
    while i <= #cfg do
        if not cfg[i].lookOtherShow then
            table.remove(cfg, i)
        else
            if cfg[i].child then
                fiterCfg(cfg[i].child)
            end
            i = i + 1
        end
    end
end

function M:initConfig()
    self._tabCfg = World.cfg.bagMainUi or {
		{
            ["tabName"] = "gui_main_left_tab_name_role",
            ["lookOtherShow"] = true,
            ["titleName"] = "gui_main_title_name_role",
            ["openWindow"] = "character_panel",
            ["entityType"] = "ENTITY_INTO_TYPE_PLAYER"
        },
	}
    if not self._lookOther then
        return
    end
    fiterCfg(self._tabCfg)

end

function M:openWindow(windowName, cfg)
    local function openWin(info)
        local childUi = self:child("main-childUI")
        UI:closeWnd(windowName)
        local win = UI:openWnd(windowName, {
            isMe = not self._lookOther,
            entityType = cfg.entityType,
            info = info,
            objID = self._objID,
            parentUi = childUi
        })

        self._curOpenWindow = cfg.openWindow
        local root = win._root
        childUi:AddChildWindow(root)
        root:SetXPosition({0, 0})
        root:SetYPosition({0, 0})
        root:SetHeight({1, 0})

        self._curCfg = cfg
        if not self._lookOther then
            return
        end
        local childWidth = win._root:GetPixelSize().x
        local parentLayout = self:child("main-windows")
        parentLayout:SetWidth({0, childWidth + 229})
    end

    if cfg.entityType then
        openWin()
        self:getInfoByID(self._objID, Define[cfg.entityType],IgnoreCache)
    else
        openWin()
    end
end

function M:initUiName()
    self.leftTabLayout = self:child("main-windows"):child("main-left_tab")
    self.letTabList = self.leftTabLayout:child("main-tabList")
    self.title = self:child("main-windows"):child("main-win_titile")
    self.closeBtn = self:child("main-windows"):child("main-closeButton")
    self.childUI = self:child("main-childUI")
end

function M:selectTransColor(item)
    for _, _item in pairs(self._itemList) do
        _item:SetTextColor({255/255, 250/255, 174/255})
    end
    item:SetTextColor({42/255, 44/255, 31/255})
    self.letTabList:LayoutChild()

end

function M:selectItem(item, cfg)
    if item:IsSelected() then
        self._selectName = item:GetName()
        self:selectTransColor(item)
        self.title:SetText(Lang:toText(cfg.titleName))
        self:openWindow(cfg.openWindow, cfg)
    else
        UI:closeWnd(cfg.openWindow)
    end
end

function M:registerSelectEvent(item, cfg, parentIndex)
    if cfg.child then
        self:subscribe(item, UIEvent.EventButtonClick, function()
            self:openChild(cfg, parentIndex, not self._tabParentChild[parentIndex], item)
        end)
    else
        self:subscribe(item, UIEvent.EventRadioStateChanged, function()
            self:selectItem(item, cfg)
        end)
    end
end

function M:setItemParent(name, cfg, parentIndex)
    local item
    if not cfg.child then
        item = GUIWindowManager.instance:CreateGUIWindow1("RadioButton", name)
        item:SetPushedImage("set:skill_character_system.json image:left_tab_select_1.png")
        item:SetNormalImage("set:skill_character_system.json image:left_tab_1.png")

    else
        local icoItem = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "ico")
        icoItem:SetImage("set:skill_character_system.json image:left_tab_slippery.png")
        icoItem:SetArea({0, 175}, {0, 39}, {0, 20}, {0, 12})
        item = GUIWindowManager.instance:CreateGUIWindow1("Button", name)
        item:SetPushedImage("set:skill_character_system.json image:left_tab_1.png")
        item:SetNormalImage("set:skill_character_system.json image:left_tab_1.png")
        item:AddChildWindow(icoItem)
    end
    self:registerSelectEvent(item, cfg, parentIndex)
    item:SetTextColor({255/255, 250/255, 174/255})
    item:SetText(Lang:toText(cfg.tabName))
    item:SetWidth({0, 211})
    item:SetHeight({0, 86})
    item:SetHorizontalAlignment(1)
    item:SetProperty("Font", "HT16")

    return item
end

function M:setItemChild(name, cfg)
    local item = GUIWindowManager.instance:CreateGUIWindow1("RadioButton", name)
    item:SetPushedImage("set:skill_character_system.json image:left_tab_select_2.png")
    item:SetNormalImage("set:skill_character_system.json image:left_tab_2.png")
    self:registerSelectEvent(item, cfg)
    item:SetTextColor({255/255, 250/255, 174/255})
    item:SetText(Lang:toText(cfg.tabName))
    item:SetWidth({0, 199})
    item:SetHorizontalAlignment(2)
    item:SetProperty("Font", "HT16")

    --item:SetVisible(false)
    return item
end

function M:openChild(cfg, parentIndex, open, item)
    if open then
        self:createChild(cfg, parentIndex, item)
    else
        self:delChild(cfg, parentIndex, item)
    end
end

function M:findOperatorIndex(parentIndex)
    local OperatorIndex = parentIndex
    for i = 1, parentIndex - 1 do
        if self._tabParentChild[i] then
            OperatorIndex = OperatorIndex + #self._tabCfg[i].child
        end
    end
    return OperatorIndex
end

function M:delChild(cfg, parentIndex, parentItem)
    if not cfg.child then
        return
    end

    if not self._tabParentChild[parentIndex] then
        return
    end

    parentItem:child("ico"):SetImage("set:skill_character_system.json image:left_tab_slippery.png")

    local delIndex = self:findOperatorIndex(parentIndex)
    for i = 1, #cfg.child do
        local item = self._itemList[delIndex + 1]
        Lib.uiTween(item, {
            Hight = {0, 0},
            Alpha = 0
        }, EFFECT_TIME, function()
            table.remove(self._itemList, delIndex + 1)
            self.letTabList:DeleteItem(delIndex)
        end)
    end

    Lib.loop(1, EFFECT_TIME, function()
        self.letTabList:LayoutChild()
    end)

    self._tabParentChild[parentIndex] = false

end

function M:createChild(cfg, parentIndex, parentItem)
    if not cfg.child then
        return
    end

    parentItem:child("ico"):SetImage("set:skill_character_system.json image:left_tab_sliding.png")

    local insertIndex = self:findOperatorIndex(parentIndex)
    for childIndex, child in ipairs(cfg.child) do
        local childName = string.format( "parent-%d-child-tab-%d",parentIndex, childIndex)
        local item = self:setItemChild(childName, child)

        item:SetHeight({0, 86})
        item:SetAlpha(1)

        World.Timer(EFFECT_INTERVAL * (childIndex - 1), function()
            -- Lib.uiTween(item, {
            --     Hight = {0, 86},
            --     Alpha = 1
            -- }, EFFECT_TIME)
            return false
        end)
        self.letTabList:AddItem1(item, "", insertIndex)
        table.insert(self._itemList, insertIndex + 1, item)

        if childName == self._selectName then
            item:SetSelected(true)
        end
        
        if self._defaultFlag then
            self._defaultFlag = false
            item:SetSelected(true)
        end

        insertIndex = insertIndex + 1
    end

    Lib.loop(1, EFFECT_TIME + EFFECT_INTERVAL * #cfg.child * 2, function()
        self.letTabList:LayoutChild()
    end)

    self._tabParentChild[parentIndex] = true
end

function M:createLeftTab()
    local item
    self._tabParent = {}
    self._tabParentChild = {}
    self._itemList = {}
    self._selectName = "" 
    for parentIndex, parent in ipairs(self._tabCfg) do
        local parentName = string.format( "parent-tab-%d", parentIndex)
        item = self:setItemParent(parentName, parent, parentIndex)
        table.insert(self._itemList, item)
        self.letTabList:AddItem(item)
        self._tabParentChild[parentIndex] = false
    end
end

function M:openDefaultWin()
    if self._curOpenWindow then
        self._defaultFlag = false
        self:openWindow(self._curOpenWindow, self._curCfg)

        return
    end

    local cfg = self._tabCfg[1]
    local item = self._itemList[1]

    if cfg.child then
        if not self._tabParentChild[1] then

            self:openChild(cfg, 1, not self._tabParentChild[1], item)
        else
            
            self._defaultFlag = false
            self:selectItem(self._itemList[2], cfg.child[1])
        end
    else
        self._defaultFlag = false
        item:SetSelected(true)
        self:selectItem(item, cfg)
    end
end

function M:emitEvent()
    Lib.emitEvent()
end

function M:getInfoByID(objID, entityType, ignoreCache)
    -- local entityType = Define[self._curCfg.entityType]
    local function handleViewInfo(info, isCache)
        if type(info) == "table" then
            Lib.emitEvent(Event.PUSH_ENTITY_INFO, info)
            self._entityInfoCache[entityType] = info
            info.cache = isCache
        end
	end

    local cache = self._entityInfoCache[entityType]
	if not ignoreCache and cache then
		handleViewInfo(cache, true)
		return
    end
    IgnoreCache = false
	Me:sendPacket({
		pid = "QueryEntityViewInfo",
		objID = assert(objID),
		entityType = entityType,
	}, handleViewInfo)
end

function M:onOpen(objID)
    -- objID = Me.objID
    self._lookOther = objID and true or false
    self._objID = objID or Me.objID
    self._allEvent = {}
    self:initConfig(objID)
    
    if not self.notfirstOpen then
        self:createLeftTab()
        self.notfirstOpen = true
    end
    if self._lookOther then
        self._curOpenWindow = nil
        self._defaultFlag = true
        self._entityInfoCache = {}
        self.letTabList:ClearAllItem()
        self:createLeftTab()
    end

    --self._defaultFlag = true
    self:openDefaultWin()
    self:subscribeEvent()
end

function M:onClose()
    if self._curOpenWindow then
        UI:closeWnd(self._curOpenWindow)
    end

    if self._allEvent then
        for k, fun in pairs(self._allEvent) do
            fun()
        end
    end
    UI:closeWnd("popups_property")
end

