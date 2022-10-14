local add_monster_setting = require "editor.setting.add_monster_setting"
local monsterSetData = {}
local lastLtBtn
local lastSelectedItem
local curPage = 1

function M:init()
    WinBase.init(self, "RuleSettingMonster.json")
    self:initRangeGrid()
    self.sureBtn = self:child("Monster-Setting-btn_ok")
    self.sureBtn:child("Monster-Setting-btn_ok-text"):SetText(Lang:toText("global.sure"))
    self.cancelBtn = self:child("Monster-Setting-btn_cencel")
    self.cancelBtn:child("Monster-Setting-btn_cancel-text"):SetText(Lang:toText("global.cancel"))
    self.setNameIcon = self:child("Monster-Setting-Title-show-icon")
    self.setNameEdit = self:child("Monster-Setting-Title-show-frame")
    self.setNameText = self:child("Monster-Setting-Title-show-text")
    self.setName = self:child("Monster-Setting-Title")
    self.monsterSpecies = self:child("Monster-Setting-Species")
    self.monsterRefreshInterval = self:child("Monster-Setting-Refresh-Interval")
    self.monsterEnvironment = self:child("Monster-Setting-Environment")
    self.monsterRange = self:child("Monster-Setting-Range")

    self.ltGrid = self:child("Monster-Setting-ltGrid")
    self.ltGrid:InitConfig(0,8,1)
    self.ltGrid:SetMoveAble(true)

    self.midGrid = self:child("Monster-Setting-midGrid")
    self.midGrid:InitConfig(0,20,1)
    self.midGrid:SetMoveAble(true)
    self.midGrid:SetAutoColumnCount(false)
    self.midGrid:AddItem(self.setName)
    self.midGrid:AddItem(self.monsterSpecies)
    self.midGrid:AddItem(self.monsterRefreshInterval)
    self.midGrid:AddItem(self.monsterEnvironment)
    self.midGrid:AddItem(self.monsterRange)
    self.monsterSpecies:setTextAutolinefeed(Lang:toText("rule.setting.monster.species"))
    self.monsterEnvironment:setTextAutolinefeed(Lang:toText("rule.setting.monster.environment"))
    self.monsterRange:setTextAutolinefeed(Lang:toText("rule.setting.monster.range"))
    self.delBtn = self:child("Monster-Setting-optBtn-delete")
    self:child("Monster-Setting-Title-Text"):setTextAutolinefeed(Lang:toText("editor.ui.itemName"))
    self:child("Monster-Setting-Range-All-Text"):setTextAutolinefeed(Lang:toText("rule.setting.monster.range.all"))
    self:child("Monster-Setting-Range-Set-Text"):setTextAutolinefeed(Lang:toText("rule.setting.monster.range.set"))
    self:child("Monster-Setting-Range-NoSet-Text"):setTextAutolinefeed(Lang:toText("rule.setting.monster.range.noset"))
    self:child("Monster-Setting-Show-Title"):setTextAutolinefeed(Lang:toText("rule.setting.random.monster"))

    self.monsterEnvironmentTable = {
        day = { btn = self:child("Monster-Setting-Day"), text = self:child("Monster-Setting-Day-Text") },
        night = { btn = self:child("Monster-Setting-Night"), text = self:child("Monster-Setting-Night-Text") },
        allday = { btn = self:child("Monster-Setting-Day-Night"), text = self:child("Monster-Setting-Day-Night-Text") }
    }

    self.monsterEnvironmentTable["day"].text:setTextAutolinefeed(Lang:toText("rule.setting.day.mode"))
    self.monsterEnvironmentTable["night"].text:setTextAutolinefeed(Lang:toText("rule.setting.night.mode"))
    self.monsterEnvironmentTable["allday"].text:setTextAutolinefeed(Lang:toText("rule.setting.monster.time.allday"))

    self.monsterRangeTable = {
        all = { btn = self:child("Monster-Setting-Range-All"), text = self:child("Monster-Setting-Range-All-Text") },
        set = { btn = self:child("Monster-Setting-Range-Set"), text = self:child("Monster-Setting-Range-Set-Text") },
        noset = { btn = self:child("Monster-Setting-Range-NoSet"), text = self:child("Monster-Setting-Range-NoSet-Text") }
    }
    self:initMonsterSetData()

    self:subscribe(self.monsterEnvironmentTable["day"].btn, UIEvent.EventWindowTouchUp, function()
        monsterSetData[curPage].monsterEnvironment = "day"
        self:refreshMonsterEnvironment("day")
    end)
    self:subscribe(self.monsterEnvironmentTable["night"].btn, UIEvent.EventWindowTouchUp, function()
        monsterSetData[curPage].monsterEnvironment = "night"
        self:refreshMonsterEnvironment("night")
    end)
    self:subscribe(self.monsterEnvironmentTable["allday"].btn, UIEvent.EventWindowTouchUp, function()
        monsterSetData[curPage].monsterEnvironment = "allday"
        self:refreshMonsterEnvironment("allday")
    end)

    self:subscribe(self.monsterRangeTable["all"].btn, UIEvent.EventWindowTouchUp, function()
        monsterSetData[curPage].monsterRange = "all"
        self:refreshMonsterRange()
    end)
    self:subscribe(self.monsterRangeTable["set"].btn, UIEvent.EventWindowTouchUp, function()
        monsterSetData[curPage].monsterRange = "set"
        self:refreshMonsterRange()
    end)
    self:subscribe(self.monsterRangeTable["noset"].btn, UIEvent.EventWindowTouchUp, function()
        monsterSetData[curPage].monsterRange = "noset"
        self:refreshMonsterRange()
    end)

    self:subscribe(self.delBtn, UIEvent.EventButtonClick, function()
        if not lastLtBtn then
            return
        end
        local tip = UI:openWnd("mapEditTeamSettingTip", function()
            local index = lastLtBtn:data("index")
            table.remove( monsterSetData, index )
            self:refreshLtGrid()
        end, nil, Lang:toText("editor.ui.confirm.delect"))
        tip:switchBtnPosition()
    end)
    
    self.speciesGrid = self:child("Monster-Setting-Species-Grid")
    self.speciesGrid:InitConfig(20,20,5)
    self.speciesGrid:SetMoveAble(false)
    self.speciesGrid:SetAutoColumnCount(false)

    self.monsterRangeSetGrid = self:child("Monster-Setting-Range-Set-Grid")
    self.monsterRangeSetGrid:InitConfig(20,20,5)
    self.monsterRangeSetGrid:SetMoveAble(false)
    self.monsterRangeSetGrid:SetAutoColumnCount(false)

    self.monsterRangeNoSetGrid = self:child("Monster-Setting-Range-NoSet-Grid")
    self.monsterRangeNoSetGrid:InitConfig(20,20,5)
    self.monsterRangeNoSetGrid:SetMoveAble(false)
    self.monsterRangeNoSetGrid:SetAutoColumnCount(false)

    local sliderValue = monsterSetData[curPage] and monsterSetData[curPage].refreshInterval or 10
    self.intervalSlider = UILib.createSlider({value = sliderValue, index = 5013}, function(value)
        monsterSetData[curPage].refreshInterval = value
    end)
    self.monsterRefreshInterval:AddChildWindow(self.intervalSlider)

    self:refreshLtGrid()

    self:subscribe(self.sureBtn, UIEvent.EventButtonClick, function()
        self:SaveData()
        UI:closeWnd(self)
    end)
    self:subscribe(self.cancelBtn, UIEvent.EventButtonClick, function()
        UI:closeWnd(self)
    end)

    self:subscribe(self.setNameEdit, UIEvent.EventWindowTouchUp, function()
        self.setNameEdit:SetTextWithNoTextChange(self.setNameText:GetText())
    end)

    self:subscribe(self.setNameEdit, UIEvent.EventWindowTextChanged, function()
        local text = self.setNameEdit:GetPropertyString("Text","")
        if text ~= "" then
            local ltBenText = text
            if Lib.getStringLen(ltBenText) > 10 then
                ltBenText = Lib.subString(ltBenText, 8) .. "..."
            end
            self:refreshName(text)
            monsterSetData[curPage].name = text
            lastLtBtn:child("name"):SetText(ltBenText)
            self.setNameEdit:SetText("")
        end
    end)
end

local function compatible(data)
    if data[1] then
        for j = 1, #data do
            for k, v in pairs(data[j]) do
                if k == "fullname" or k == "fullName" then
                    data[j].fullName = v
                end
            end
        end
    else
        for k, v in pairs(data) do
            data[k].fullName = v.fullname or v.fullName
        end
    end
end

function M:initMonsterSetData()
    local data = add_monster_setting:getAddMonsters()
    monsterSetData = data and data[1] or {}
    monsterSetData[curPage] = monsterSetData[curPage] or {}

    for i = 1, #monsterSetData do
        compatible(monsterSetData[i].monsterRangeNoSetTable or {})
        compatible(monsterSetData[i].monsterRangeSetTable or {})
        compatible(monsterSetData[i].monsterSpecies or {})
    end
end

function M:initRangeGrid()
    self.rangeMonsterGrid = {count = 1, gridList = {}}
    self.rangeSetGrid = {count = 1, gridList = {}}
    self.rangeNoSetGrid = {count = 1, gridList = {}}
end

function M:getMonsterSetAddBtn()
    local btn = GUIWindowManager.instance:CreateGUIWindow1("Button", "addBtn")
    btn:SetHeight({0, 42})
    btn:SetWidth({0, 190})
    btn:SetNormalImage("set:new_shop1.json image:shop_left_add_nor.png")
    btn:SetPushedImage("set:new_shop1.json image:shop_left_add_nor.png")
    self:subscribe(btn, UIEvent.EventButtonClick, function()
        local name = Lang:toText("rule.setting.type.name") .. (#monsterSetData + 1)
        table.insert(monsterSetData, 1, {name = name})
        self:refreshLtGrid()
    end)
    return btn
end

function M:refreshLtGrid()
    self.ltGrid:RemoveAllItems()
    local tabBtn
    local addBtn = self:getMonsterSetAddBtn()
    self.ltGrid:AddItem(addBtn)
    if #monsterSetData == 0 then
        self:showPage(curPage)
    end
    for i, data in pairs(monsterSetData) do 
        local typeBtn = self:createMonsterSetBtn(i, data.name or Lang:toText("rule.setting.type.name"))
        self.ltGrid:AddItem(typeBtn)
        tabBtn = tabBtn or typeBtn
    end
    self:selectLtBtn(tabBtn)
end

function M:createMonsterSetBtn(index, name)
    local btn = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "btn" .. tostring(index))
    btn:setData("index", index)
    btn:SetHeight({0, 42})
    btn:SetWidth({0, 190})
    btn:SetImage("set:setting_global.json image:icon_commoditytap_no.png")
    local textWnd = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "name")
    textWnd:SetHeight({1, 0})
    textWnd:SetWidth({1, 0})
    textWnd:SetTextVertAlign(1)
    textWnd:SetTextHorzAlign(1)
    name = Lang:toText(name)
    if Lib.getStringLen(name) > 10 then
        name = Lib.subString(name, 8) .. "..."
    end
    textWnd:SetText(name)
    btn:AddChildWindow(textWnd)
    self:subscribe(btn, UIEvent.EventWindowTouchUp, function()
        self:selectLtBtn(btn)
    end)
    return btn
end

function M:selectLtBtn(curLtBtn)
    if lastLtBtn then
        lastLtBtn:SetImage("set:setting_global.json image:icon_commoditytap_no.png")
    end
    if not curLtBtn then
        lastLtBtn = nil
        return
    end
    curLtBtn:SetImage("set:setting_global.json image:icon_commoditytap_ok.png")
    lastLtBtn = curLtBtn
    local index = lastLtBtn:data("index")
    self:initRangeGrid()
    self:showPage(index)
    lastSelectedItem = nil
end

function M:getAddMonsterItem()
    local addBtn = GUIWindowManager.instance:LoadWindowFromJSON("RuleSettingMonsterItem.json")
    addBtn:RemoveChildWindow("setting-item-bg1")
    addBtn:child("setting-item-text"):SetWordWrap(true)
    addBtn:child("setting-item-text"):setTextAutolinefeed(Lang:toText("rule.setting.monster.species.add"))
    self:subscribe(addBtn, UIEvent.EventWindowTouchUp, function()
        local index = lastLtBtn:data("index")
        UI:openMultiInstanceWnd("mapEditItemBagSelect", {uiNameList = {"monster"},backFunc = function(item, isBuff)
            if not monsterSetData[index] then
                return
            end
            local name =  item.getNameText and item:getNameText() or item:cfg().itemname 
            local fullName = item:full_name()
            monsterSetData[index].monsterSpecies = monsterSetData[index].monsterSpecies or {}
            for k,v in pairs(monsterSetData[index].monsterSpecies) do
                if v.fullName == fullName then
                    Lib.emitEvent(Event.EVENT_TOAST_TIP, Lang:toText("rule.setting.monster.added"), 20)
                    return
                end
            end
            table.insert( monsterSetData[index].monsterSpecies, 1, { type = item:type(), icon = item:icon(), name = name, fullName = fullName } )
            self:refreshSpeciesGrid()
            lastSelectedItem = nil
        end})
    end)
    return addBtn
end

function M:getAddRangeSetItem()
    local addBtn = GUIWindowManager.instance:LoadWindowFromJSON("RuleSettingMonsterItem.json")
    addBtn:RemoveChildWindow("setting-item-bg1")
    addBtn:child("setting-item-text"):SetWordWrap(true)
    addBtn:child("setting-item-text"):setTextAutolinefeed(Lang:toText("rule.setting.monster.range.add"))
    self:subscribe(addBtn, UIEvent.EventWindowTouchUp, function()
        local index = lastLtBtn:data("index")
        if not monsterSetData[index] then
            return
        end
        local wndMultiSelect = UI:openWnd("mapEditItemBagMultiSelect")
        local backFunc = function(data)
            monsterSetData[index].monsterRangeSetTable = data
            self:refreshRangeSetGrid()
            self:refreshMonsterRange()
            lastSelectedItem = nil
        end
        local data = {}
        for k,v in pairs(monsterSetData[index].monsterRangeSetTable or {}) do
            data[k] = v
        end
        wndMultiSelect:setMultiSelectData("block", data, backFunc)
    end)
    return addBtn
end

function M:getAddRangeNoSetItem()
    local addBtn = GUIWindowManager.instance:LoadWindowFromJSON("RuleSettingMonsterItem.json")
    addBtn:RemoveChildWindow("setting-item-bg1")
    addBtn:child("setting-item-text"):SetWordWrap(true)
    addBtn:child("setting-item-text"):setTextAutolinefeed(Lang:toText("rule.setting.monster.range.add"))
    self:subscribe(addBtn, UIEvent.EventWindowTouchUp, function()
        local index = lastLtBtn:data("index")
        if not monsterSetData[index] then
            return
        end
        local wndMultiSelect = UI:openWnd("mapEditItemBagMultiSelect")
        local backFunc = function(data)
            monsterSetData[index].monsterRangeNoSetTable = data
            self:refreshRangeNoSetGrid()
            self:refreshMonsterRange()
            lastSelectedItem = nil
        end
        local data = {}
        for k,v in pairs(monsterSetData[index].monsterRangeNoSetTable or {}) do
            data[k] = v
        end
        wndMultiSelect:setMultiSelectData("block", data, backFunc)
    end)
    return addBtn
end

function M:onSelectItem(clickItem)
    if lastSelectedItem then
        lastSelectedItem:child("setting-item-bg"):SetImage("set:new_shop1.json image:shop_icon_bg_nor.png")
        lastSelectedItem:child("setting-item-btn_close"):SetVisible(false)
    end
    if clickItem then
        lastSelectedItem = clickItem
        clickItem:child("setting-item-bg"):SetImage("set:new_shop1.json image:shop_icon_bg_act.png")
        clickItem:child("setting-item-btn_close"):SetVisible(true)
    else
        lastSelectedItem = nil
    end
end

function M:getMonsterSpeciesItem(data)
    local item = GUIWindowManager.instance:LoadWindowFromJSON("RuleSettingMonsterItem.json")
    item:child("setting-item-bg"):SetImage("set:new_shop1.json image:shop_icon_bg_nor.png")
    local blockItem = data.fullName and EditorModule:createItem("entity", data.fullName)
    item:child("setting-item-bg1"):SetImage(blockItem and blockItem:icon() or data.icon)
    item:child("setting-item-bg1"):SetArea({0, 5}, {0, 20}, {0, 80}, {0, 80})
    item:child("setting-item-text"):SetWordWrap(true)
    item:child("setting-item-text"):setTextAutolinefeed(Lang:toText(data.name))
    self:subscribe(item, UIEvent.EventWindowTouchUp, function()
        self:onSelectItem(item)
    end)
    self:subscribe(item:child("setting-item-btn_close"), UIEvent.EventButtonClick, function()
        self.speciesGrid:RemoveItem(item)
        local index = lastLtBtn:data("index")
        if monsterSetData[index] and monsterSetData[index].monsterSpecies then
            table.remove( monsterSetData[index].monsterSpecies, item:data("dataIndex") )
        end
        self:refreshSpeciesGrid()
    end)
    return item
end

function M:getMonsterRangeSetItem(data)
    local item = GUIWindowManager.instance:LoadWindowFromJSON("RuleSettingMonsterItem.json")
    item:child("setting-item-bg"):SetImage("set:new_shop1.json image:shop_icon_bg_nor.png")
    local blockItem = data.fullName and EditorModule:createItem("block", data.fullName)
    item:child("setting-item-bg1"):SetImage(blockItem and blockItem:icon() or data.icon)
    item:child("setting-item-bg1"):SetArea({0, 5}, {0, 20}, {0, 80}, {0, 80})
    item:child("setting-item-text"):SetWordWrap(true)
    item:child("setting-item-text"):setTextAutolinefeed(Lang:toText(data.name))
    self:subscribe(item, UIEvent.EventWindowTouchUp, function()
        self:onSelectItem(item)
    end)
    self:subscribe(item:child("setting-item-btn_close"), UIEvent.EventButtonClick, function()
        self.monsterRangeSetGrid:RemoveItem(item)
        local index = lastLtBtn:data("index")
        if monsterSetData[index] and monsterSetData[index].monsterRangeSetTable then
            monsterSetData[index].monsterRangeSetTable[data.fullName] = nil
        end
        self:refreshMonsterRange()
    end)
    return item
end

function M:getMonsterRangeNoSetItem(data)
    local item = GUIWindowManager.instance:LoadWindowFromJSON("RuleSettingMonsterItem.json")
    item:child("setting-item-bg"):SetImage("set:new_shop1.json image:shop_icon_bg_nor.png")
    local blockItem = data.fullName and EditorModule:createItem("block", data.fullName)
    item:child("setting-item-bg1"):SetImage(blockItem and blockItem:icon() or data.icon)
    item:child("setting-item-bg1"):SetArea({0, 5}, {0, 20}, {0, 80}, {0, 80})
    item:child("setting-item-text"):SetWordWrap(true)
    item:child("setting-item-text"):setTextAutolinefeed(Lang:toText(data.name))
    self:subscribe(item, UIEvent.EventWindowTouchUp, function()
        self:onSelectItem(item)
    end)
    self:subscribe(item:child("setting-item-btn_close"), UIEvent.EventButtonClick, function()
        self.monsterRangeNoSetGrid:RemoveItem(item)
        local index = lastLtBtn:data("index")
        if monsterSetData[index] and monsterSetData[index].monsterRangeNoSetTable then
            monsterSetData[index].monsterRangeNoSetTable[data.fullName] = nil
        end
        self:refreshMonsterRange()
    end)
    return item
end

function M:showPage(index)
    self.midGrid:ResetPos()
    local setData = monsterSetData[index]
    if not setData then
        self.midGrid:SetVisible(false)
        return
    end
    curPage = index
    self.midGrid:SetVisible(true)
    self:refreshName(setData.name or Lang:toText("rule.setting.type.name"))
    self.intervalSlider:invoke("setUIValue", setData.refreshInterval or 10 )
    self:refreshMonsterEnvironment(setData.monsterEnvironment)
    self:refreshMonsterRange()
    self:refreshSpeciesGrid()
end

function M:refreshMonsterRange()
    local index = lastLtBtn:data("index")
    local range = monsterSetData[index] and monsterSetData[index].monsterRange
    local normalColor = {174/255, 184/255, 183/255, 1}
    local selectedColor = {99/255, 100/255, 106/255, 1}
    range = range or "all"
    for k,v in pairs(self.monsterRangeTable or {}) do
        if k == range then
            v.btn:SetSelected(true)
            v.text:SetTextColor(selectedColor)
        else
            v.text:SetTextColor(normalColor)
        end
    end
    local lsatHeight1 = ( 1 + math.floor( ( self.rangeSetGrid.count - 1 ) / 5 ) ) * 155
    local lsatHeight2 = ( 1 + math.floor( ( self.rangeNoSetGrid.count - 1 ) / 5 ) ) * 155
    if range == "set" then
        self:refreshRangeSetGrid()
    elseif range == "noset" then
        self:refreshRangeNoSetGrid()
    end
    local height1 = ( 1 + math.floor( ( self.rangeSetGrid.count - 1 ) / 5 ) ) * 155
    local height2 = ( 1 + math.floor( ( self.rangeNoSetGrid.count - 1 ) / 5 ) ) * 155
    self.monsterRangeSetGrid:SetVisible(range == "set")
    self.monsterRangeNoSetGrid:SetVisible(range == "noset")
    self.monsterRangeNoSetGrid:SetYPosition({ 0 , 180 })
    self.monsterRangeTable["noset"].btn:SetYPosition({ 0 , range == "set" and 120 + height1 or 120 })
    self.monsterRange:SetHeight({ 0, range == "all" and 200 or 200 + ( range == "set" and height1 or height2 ) })
    if height1 < lsatHeight1 or height2 < lsatHeight2 then
        local lastOffset = self.midGrid:GetScrollOffset()
        self.midGrid:SetScrollOffset(lastOffset + 155)
    end
end

function M:refreshMonsterEnvironment(time)
    local normalColor = {174/255, 184/255, 183/255, 1}
    local selectedColor = {99/255, 100/255, 106/255, 1}
    time = time or "day"
    for k,v in pairs(self.monsterEnvironmentTable or {}) do
        if k == time then
            v.btn:SetSelected(true)
            v.text:SetTextColor(selectedColor)
        else
            v.text:SetTextColor(normalColor)
        end
    end
end

function M:refreshSpeciesGrid()
    self.rangeMonsterGrid = {count = 1, gridList = {}}
    self.speciesGrid:RemoveAllItems()
    self.speciesGrid:AddItem(self:getAddMonsterItem())
    local index = lastLtBtn:data("index")
    local data = monsterSetData[index] and monsterSetData[index].monsterSpecies or {}
    if next(data) == nil then
        self.monsterRefreshInterval:SetEnabledRecursivly(false)
        self.monsterEnvironment:SetEnabledRecursivly(false)
        self.monsterRange:SetEnabledRecursivly(false)
    else
        self.monsterRefreshInterval:SetEnabledRecursivly(true)
        self.monsterEnvironment:SetEnabledRecursivly(true)
        self.monsterRange:SetEnabledRecursivly(true)
    end
    for i = 1,#data do
        World.LightTimer("addItem", i, function()
            if self.rangeMonsterGrid.gridList[data[i].name] then
                return
            end
            local item = self:getMonsterSpeciesItem(data[i])
            item:setData("dataIndex", i)
            self.speciesGrid:AddItem(item)
            self.rangeMonsterGrid.gridList[data[i].name] = true
        end)
    end
    self.rangeMonsterGrid.count = #data > 0 and #data or 1
    local height = ( 1 + math.floor( ( self.rangeMonsterGrid.count ) / 5 ) ) * 155
    self.monsterSpecies:SetHeight( { 0, height } )
    self.speciesGrid:SetHeight( { 0, height } )
end

local function calcRangDataCount(data)
    local count = 1
    if not data then
        return count
    end
    for k, v in pairs(data) do
        count = count + 1
    end 
    return count
end

function M:refreshRangeSetGrid()
    self.rangeSetGrid = {count = 1, gridList = {}}
    self.lastScrollOffset = self.midGrid:GetScrollOffset()
    self.monsterRangeSetGrid:RemoveAllItems()
    self.monsterRangeSetGrid:AddItem(self:getAddRangeSetItem())
    local index = lastLtBtn:data("index")
    local data = monsterSetData[index] and monsterSetData[index].monsterRangeSetTable
    if not data then
        self.monsterRangeSetGrid:SetHeight( { 0, 155 } )
        return
    end
    local count = 1
    for k, v in pairs(data) do
        World.LightTimer("addItem", count, function()
            if self.rangeSetGrid.gridList[v.name] then
                return
            end
            local item = self:getMonsterRangeSetItem(v)
            self.monsterRangeSetGrid:AddItem(item)
            self.rangeSetGrid.gridList[v.name] = true
        end)
        count = count + 1
    end
    self.rangeSetGrid.count = calcRangDataCount(data)
    local height = ( 1 + math.floor( ( self.rangeSetGrid.count - 1 ) / 5 ) ) * 155
    self.monsterRangeSetGrid:SetHeight( { 0, height } )
end

function M:refreshRangeNoSetGrid()
    self.monsterRangeNoSetGrid:RemoveAllItems()
    self.monsterRangeNoSetGrid:AddItem(self:getAddRangeNoSetItem())
    local index = lastLtBtn:data("index")
    local data = monsterSetData[index] and monsterSetData[index].monsterRangeNoSetTable
    local lastNoSetDataCount = calcRangDataCount(data)
    if not data then
        self.monsterRangeNoSetGrid:SetHeight( { 0, 155 } )
        return
    end
    if self.lastScrollOffset and lastNoSetDataCount == self.rangeNoSetGrid.count then
         self.midGrid:SetScrollOffset(self.lastScrollOffset)
    end
    self.rangeNoSetGrid = {count = 1, gridList = {}}
    local count = 1
    for k, v in pairs(data) do
        World.LightTimer("addItem", count, function()
            if self.rangeNoSetGrid.gridList[v.name] then
                return
            end
            local item = self:getMonsterRangeNoSetItem(v)
            self.monsterRangeNoSetGrid:AddItem(item)
            self.rangeNoSetGrid.gridList[v.name] = true
        end)
        count = count + 1
    end
    self.rangeNoSetGrid.count = calcRangDataCount(data)
    local height = ( 1 + math.floor( ( self.rangeNoSetGrid.count - 1 ) / 5 ) ) * 155
    self.monsterRangeNoSetGrid:SetHeight( { 0, height } )
end

function M:refreshName(text)
    self.setNameText:SetText(text)
    local width = self.setNameText:GetFont():GetTextExtent(Lang:toText(text),1.0)
    self.setNameText:SetWidth({0, width})
    self.setNameIcon:SetXPosition({0, width + 10})
    self.setNameEdit:SetXPosition({0, width + 10})
end

function M:onOpen()
    self:showPage(curPage)
end

function M:onClose()
    self:initRangeGrid()
    lastSelectedItem = nil
end

function M:SaveData()
    add_monster_setting:saveAddMonsters( { monsterSetData } )
end

return M