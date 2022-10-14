local globalSetting = require "editor.setting.global_setting"
local entitySetting = require "editor.setting.entity_setting"
local editorSetting = require "editor.setting"
local compositeSetting = require "editor.setting.composite_setting"

local openComposite
local compositeData
local recipesData
local indexMap = {}
local defaultName = "recipeNewName"
local cell_pool = {}
local recipe_pool = {} 
local recipPoolSize = 0
local cellPoolSize = 0

local function getRecipeWnd()
    local ret = table.remove(recipe_pool)
    if not ret then
        recipPoolSize = recipPoolSize + 1
        ret = GUIWindowManager.instance:LoadWindowFromJSON("recipeItem.json")
    end
    return ret
end

local function fetchCell()
    local ret  =  table.remove(cell_pool)
    if not ret then
        ret = UIMgr:new_widget("cell")
    end
    ret:child("widget_cell-img_item"):SetArea({0, -2},{0, -2},{1, -4}, {1,-4})
    return ret
end

local function getRecipeName(name)
    local splitRet = Lib.splitString(name, ".")
    if #splitRet > 0 and splitRet[1] == defaultName then
        return defaultName, splitRet[2]
    end
    return name
end

local function getItem(type, fullName, args)
    type = string.lower(type)
    local item = EditorModule:createItem(type, fullName, args)
    local cfg = item:cfg()
    return item, cfg
end

 local setPopFunc = function(self, cell, itemName, with, hei)
        local rpos = self:root():GetRenderArea()
        local pos = cell:GetRenderArea()
        local text = Lang:toText(itemName)
        local textWnd = self:child("popShowName")
        textWnd:SetText(text)
        local len = textWnd:GetFont():GetTextExtent(text, 1) + 40
        self.recipeNameWnd:SetWidth({0, len})
        self:child("recipeNameBg"):SetWidth({0, len})
        textWnd:SetWidth({0, len})
        textWnd:SetTextHorzAlign(1)
        local posx = {0, pos[1] - rpos[1] - len/2 + (with or 24)}
        local y = math.max(140, pos[2] - ( hei or 50)- rpos[2])
        local posy = {0, y}
        self.recipeNameWnd:SetXPosition(posx)
        self.recipeNameWnd:SetYPosition(posy)
        self:setPopWndEnabled(true)
    end

local function removeChildAllWin(win)
    if not win then
        return
    end
    while(true)
    do
        local childCount = win:GetChildCount()
        if childCount == 0 then
            return
        end
        local child = win:GetChildByIndex(0)
        win:RemoveChildWindow1(child)
    end
end

local function setCellDetails(self, wnd, data)
    if self.lastMaterialName and self.lastMaterialName == data.name then
        self.lastComposionCell = nil
        self.lastMaterialCell = nil
        self.lastMaterialName = nil
    end
    local materials = data.materials
    local composition = data.composition[1]
    local name, th = getRecipeName(data.name)
    local text = th and Lang:toText(name) .. th or Lang:toText(name)

    local itemContainer = wnd:child("itemContainer")
    removeChildAllWin(itemContainer)

    local recipeTitle = wnd:child("recipeName")
    local titleText = Lang:toText("win.edit.composion.materal.hit")
    recipeTitle:SetXPosition({0, 25})
    recipeTitle:SetText(titleText)
    recipeTitle:SetTextHorzAlign(0)
    local textTextent = recipeTitle:GetFont():GetTextExtent(titleText, 1) + 25
    wnd:child("recipeName2"):SetArea({0, 25 + textTextent},{0, 0},{0, 300},{0, 33})
    wnd:child("recipeName2"):SetText(text)

   
    local count = 0
    for i, material in pairs(materials or {}) do
        count = count + 1
    end
    itemContainer:SetWidth({0, count * 69})
    local materials = materials or {}
    local offsetx = 0
    for i = 1, 9 do
        local material = materials[i]
        material = material or materials[tostring(i)]
        if not material or not next(material) then
            goto continue
        end
        local cell = fetchCell()
        local item = getItem(material.type, material.name)
        cell:invoke("FRAME_IMAGE", nil, "set:map_edit_bag.json image:itembox1_bag.png")
        cell:invoke("FRAME_SELECT_IMAGE",nil,"set:map_edit_bag.json image:itembox1_bag_select.png")
        cell:SetArea({0, 0}, {0, 0}, {0, 48}, {0, 48})
        cell:invoke("ITEM_SLOTER",item)
        local itemName = item:getNameText()
        self:subscribe(cell, UIEvent.EventWindowTouchUp, function()
            cell:receiver():onClick(true)
            if self.lastMaterialCell and self.lastMaterialCell ~= cell then
                self.lastMaterialCell:SetArea({0, 0}, {0, 0}, {0, 48}, {0, 48})
                self.lastMaterialCell:receiver():onClick(false)
            end
            if self.lastComposionCell then
                self.lastComposionCell:child("recipeItem-selectedImg"):SetVisible(false)
                self.lastComposionCell = nil
            end
            if self.lastMaterialCell and self.lastMaterialCell == cell then
                cell:receiver():onClick(false)
                self.lastMaterialCell = nil
                return
            end
            cell:SetArea({0, 0}, {0, -1}, {0, 50}, {0, 50})
            self.lastMaterialName = data.name
            self.lastMaterialCell = cell
            setPopFunc(self, cell, itemName)
        end)
        local layout = GUIWindowManager.instance:CreateGUIWindow1("StaticImage")
        layout:SetArea({0,offsetx},{0,0},{0,50},{0,50})
        layout:AddChildWindow(cell)
        if count > 1 then
            local img = GUIWindowManager.instance:CreateGUIWindow1("StaticImage")
            img:SetImage("set:compositonEdit.json image:icon_add1.png")
            img:SetArea({0, 50 + 4}, {0, 18}, {0, 11}, {0, 11})
            img:SetWidth({0, 11})
            img:SetHeight({0, 11})
            layout:SetWidth({0, 50 + 11 + 4 * 2})
            layout:AddChildWindow(img)
        end
        offsetx = offsetx + 69.5
        count = count - 1
        itemContainer:AddChildWindow(layout)
        ::continue::
    end

    local imgIcon = wnd:child("recipeItem-compositionIcon")
    local compositionItem = getItem(composition.type, composition.name)
    imgIcon:SetImage(compositionItem and compositionItem:icon() or "")

    self:subscribe(wnd:child("recipeItem-compositionImg"), UIEvent.EventWindowTouchUp, function()
        if self.lastMaterialCell then
            self.lastMaterialCell:receiver():onClick(false)
            self.lastMaterialCell = nil
        end
        if self.lastComposionCell then
            self.lastComposionCell:child("recipeItem-selectedImg"):SetVisible(false)
        end
        self.lastMaterialName = data.name
        self.lastComposionCell = wnd
        wnd:child("recipeItem-selectedImg"):SetVisible(true)
        setPopFunc(self, imgIcon ,compositionItem:getNameText(), 34, 60)
    end)
end

function M:init()
    WinBase.init(self, "compositeEditor.json")
    self:child("composite_editor-addbtnText"):SetText(Lang:toText("composite.recipe"))
    self:child("composite_editor-recipeListText"):SetText(Lang:toText("composite.recipe.preview"))
    self:root():SetLevel(10)

    self.recipeGrid = self:child("composite_editor-recipe.List")
    self.recipeGrid:InitConfig(0, 10, 1)
    self.recipeGrid:SetAutoColumnCount(false)
    self.recipeGrid:SetMoveAble(true)
    
    local setEnableFunc = function(index)
        local count = self.recipeGrid:GetItemCount()
        for i=index, count do
            local item = self.recipeGrid:GetItem(i-1)
            item:SetEnabledRecursivly(status)
        end

    end

    local offOnWnd = UILib.createSwitch({
            index = 10001,
            value = openComposite
    }, function(status)
        openComposite = status
        if self.setEnableTimer then
            self.setEnableTimer()
        end
        local index = 1
        self.setEnableTimer = World.Timer(3, function()
            local count = self.recipeGrid:GetItemCount()
            local right = math.min(count, index+2)
            for i=index, right do
                local item = self.recipeGrid:GetItem(i-1)
                item:SetEnabledRecursivly(status)
            end
            index = right + 1
            return index <= count
        end)
        self.addbtn:SetEnabledRecursivly(status)
        globalSetting:saveCompositeEnable(status)
    end)
    self:child("openSwith"):AddChildWindow(offOnWnd)
    offOnWnd:SetYPosition({ 0, -5})
    self.offOnWnd = offOnWnd

    self:child("composite_editor-addText"):SetText(Lang:toText("win.edit.composion.add.rule"))
    self.addbtn = self:child("composite_editor-addRecipeBtn")
    self:subscribe(self.addbtn, UIEvent.EventButtonClick, function()
        CGame.instance:onEditorDataReport("click_global_setting_synthesis_system_add_rule", "")
        local nameMap = {}
        for _, recipe in pairs(recipesData) do
            nameMap[recipe.name] = true
        end
        UI:openWnd("mapEditCompositeRecipe", nil, function(data, enableComp)
            if not enableComp then
                 Lib.emitEvent(Event.EVENT_TOAST_TIP, Lang:toText("create.recipe.failure"), 20)
                 return
            end
            if not data or not data.composition or not data.materials then
                 Lib.emitEvent(Event.EVENT_TOAST_TIP, Lang:toText("create.recipe.failure"), 20)
                return
            end
            self:addRecipe(data)
        end, nameMap)
    end)

    self.recipeNameWnd = self:child("recipeNameWnd")
    self.popwnd = self:child("popwnd")
    self:setPopWndEnabled(false)
    self:subscribe(self.popwnd, UIEvent.EventWindowTouchUp, function()
        if self.lastMaterialCell then
            self.lastMaterialCell:receiver():onClick(false)
            self.lastMaterialCell = nil
        end
        if self.lastComposionCell then
            self.lastComposionCell:child("recipeItem-selectedImg"):SetVisible(false)
            self.lastComposionCell = nil
        end
        self:setPopWndEnabled(false)
    end)

    local sureBtn = self:child("composite-sureBtn")
    self:subscribe(sureBtn, UIEvent.EventButtonClick, function()
        self:saveData()
		UI:closeWnd(self)
	end)

    self:initData()
end

function M:initRecipes()
    indexMap = {}
    local size = #recipesData
    local mid = size - 5
    local count = math.floor(size / 15)
    count = count > 0 and count or 1
    local l = size + 1
    local r = size + 1
    openComposite = globalSetting:getCompositeEnable() or false
    self.addbtn:SetEnabledRecursivly(openComposite)
    self.offOnWnd:invoke("setUIValue", openComposite)

    local func = function()
        l = r - 1
        r = math.max(1, r - count)
        if l < 1 or r > l then
            self.canRemoveItem = true
            return false
        end
        for i= l, r, -1 do
            local recipe = recipesData[i]
            local item = self:createRecipeItem(recipe, i)
            if not openComposite then
                item:SetEnabledRecursivly(openComposite)
            end
            self.recipeGrid:AddItem(item)
        end
        self.canRemoveItem = not (r > 1)
        return r > 1
    end
    World.Timer(2, func)
end

function M:setPopWndEnabled(enable)
    self.popwnd:SetVisible(enable)
    self.recipeNameWnd:SetVisible(enable)
end

function M:addRecipe(data)
    if not data or not data.composition or not data.materials then
        return
    end
    local composition = data.composition[1]
    local materials = data.materials
    local name = data.name
    if not composition or not materials or not next(composition) or not next(materials) then
        return 
    end
    local index = #recipesData + 1
    recipesData[index] = data
    self:addRecipeItem(data, index)
end

function M:addRecipeItem(data, index)
    local item = self:createRecipeItem(data, index)
    self.recipeGrid:AddItem1(item, 0)
end

function M:modifyRecipe(index, data, wnd)
    recipesData[index] = data
    setCellDetails(self, wnd, data)
end

function M:removeRecipeItem(index, wnd)
    table.remove(recipesData, index)
    local count = self.recipeGrid:GetItemCount()
    local right = math.min(count, count - index)
    for i = 0, right do
        local cell = self.recipeGrid:GetItem(i)
        local curIndex = cell:data("index")
        curIndex = curIndex - 1
        cell:setData("index", curIndex)
    end
    self.recipeGrid:RemoveItem(wnd)
end

function M:createRecipeItem(data, index)
    local materials = data.materials
    local composition = data.composition[1]
    local name = data.name
    local wnd = getRecipeWnd()
    self.recipeGrid:AddItem(wnd)

    wnd:child("recipeItem-modifyBtnText"):SetText(Lang:toText("recipe.modify"))
    wnd:setData("index", index)
    self:subscribe(wnd:child("modifyBtn"), UIEvent.EventButtonClick, function()
        local nameMap = {}
        for _, recipe in pairs(recipesData) do
            nameMap[recipe.name] = true
        end
        nameMap[name] = nil
        local curIndex = wnd:data("index")
        UI:openWnd("mapEditCompositeRecipe", recipesData[curIndex], function(newData, enable)
            if not enable then
                Lib.emitEvent(Event.EVENT_TOAST_TIP, Lang:toText("modify.recipe.failure"), 20)
                return
            end
            if not newData or not newData.composition or not newData.materials then
                 Lib.emitEvent(Event.EVENT_TOAST_TIP, Lang:toText("modify.recipe.failure"), 20)
                 return
            end
            if not next(newData.composition) or not next(newData.materials) then
                 Lib.emitEvent(Event.EVENT_TOAST_TIP, Lang:toText("modify.recipe.failure"), 20)
                 return
            end
            self:modifyRecipe(curIndex, newData, wnd)
        end, nameMap)
    end)

    self:subscribe(wnd:child("delBtn"), UIEvent.EventButtonClick, function()
        if not self.canRemoveItem then
            return
        end
        local tip = UI:openWnd("mapEditTeamSettingTip", function()
            local curIndex = wnd:data("index")
            self:removeRecipeItem(curIndex, wnd)
        end, nil, Lang:toText("editor.ui.confirm.delect"))
        tip:switchBtnPosition()
    end)
    setCellDetails(self, wnd, data)
    return wnd
end

function M:initData()
    compositeData = compositeSetting:getMainComposite() or {}
    recipesData = compositeData.recipes
    if not recipesData then
        recipesData = {}
        compositeData.recipes = recipesData
    end
end

function M:setWndEnable(status)
    if self.lastEnable == nil or self.lastEnable ~= status then
        self.recipeGrid:SetEnabledRecursivly(status)
        local count = self.recipeGrid:GetItemCount()
        for i=1, count do
            local item = self.recipeGrid:GetItem(i-1)
            item:SetEnabledRecursivly(status)
        end
        self.addbtn:SetEnabledRecursivly(status)
        self.recipeNameWnd:SetEnabledRecursivly(status)
        self.offOnWnd:invoke("setUIValue", status)
        self.lastEnable = status and status or false
    end
end

local loadTime = 4
function M:initCellPool()
    if self.initCellTimer or self.isInitCell then
        return
    end
    self.isInitCell = true
    local composites = compositeSetting:getMainComposite() or {}
    local recipes = compositeData.recipes
    if not recipes then
        return
    end
    local count, i = 1, 1
    local len = #recipes
    local cellSize = len * 5
    self.initCellTimer = World.Timer(2, function()
        recipe_pool[i] =  GUIWindowManager.instance:LoadWindowFromJSON("recipeItem.json")
        recipPoolSize = recipPoolSize + 1
        for j=1, 5 do
            cell_pool[count] = UIMgr:new_widget("cell")
            count = count + 1
            cellPoolSize = cellPoolSize + 1
        end
        i = i + 1
        return i <= len and cellPoolSize <  cellSize and recipPoolSize < len
    end)
end

function M:doinitGridList()
     if not self.initGridList then
        self.initGridList = true
        self:initRecipes()
    end
end

function M:onOpen()
    self:doinitGridList()
end

function M:saveData()
    local composites = {compositeData}
    compositeSetting:saveComposites(composites)
    compositeSetting:save()
end

return M