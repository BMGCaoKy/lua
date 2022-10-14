local globalSetting = require "editor.setting.global_setting"
local entitySetting = require "editor.setting.entity_setting"
local editorSetting = require "editor.setting"

local materialCells = {}
local recipeData
local materialCount = 0
local newName = 1
local defaultName = "recipeNewName"
local nameMap = {}
local enableComp = true
local uiNameList = {"block", "equip", "bagWeaponList", "dropItemList", "shopResourceList"}

local function getIndexMaterial(index)
    local materials = recipeData.materials
    if not materials then
        materials = {}
        recipeData.materials = materials
    end
    return materials[index] or materials[tostring(index)]
end

local function getRecipeName(name)
    local splitRet = Lib.splitString(name, ".")
    if #splitRet > 0 and splitRet[1] == defaultName then
        return defaultName, splitRet[2]
    end
    return name
end

local function CreateItem(type, fullName, args)
    type = string.lower(type)
    local item = EditorModule:createItem(type, fullName, args)
    local cfg = item:cfg()
    return item, cfg
end

local function getName(type, fullName)
    if not type or not fullName then
        return
    end
    local item = CreateItem(type, fullName)
    return item and item:getNameText()
end

local function fetchCell()
    --local ret = UIMgr:new_widget("cell","widgetSettingItem_edt.json")
    --ret:RemoveChildWindow(ret:child("widget_cell-cs_bottom"))
    local ret = GUIWindowManager.instance:LoadWindowFromJSON("compositonCell.json")
    ret:SetWidth({0, 100})
    ret:SetHeight({0, 100})
    return ret
end

local function getMateralCount()
    materialCount = 0
    for i, v in pairs(recipeData.materials or {}) do
        materialCount = materialCount + 1
    end
    return materialCount
end

local function getNameByFullName(fullName)
    assert(type(fullName) == "string", fullName)
    local splitRet = Lib.splitString(fullName, "/")
    local len = #splitRet
    local name = len > 0 and splitRet[len]
    return name
end

local function getIcon(type, fullName)
    local item = CreateItem(type, fullName)
    return item and item:icon()
end

function M:init()
    WinBase.init(self, "compositeRecipes.json")
    self.level = self:root():GetLevel()
    self:root():SetLevel(10)
    self.itemGrid = self:child("itemGrid")
    self.itemGrid:SetMoveAble(false)
    self.itemGrid:InitConfig(0, 0, 3)

    self:child("recipesName"):setTextAutolinefeed(Lang:toText("recipes.Title"))
    self:child("recipesName"):SetWordWrap(true)
    self:child("recipesName"):SetWidth({0, 160})
    self:child("recipehint"):SetText(Lang:toText("win.material.name"))
    self:child("compositeRecipes-hitComsite"):SetText(Lang:toText("player_openComposite"))

    self:child("surebutton"):SetText(Lang:toText("global.sure"))
    self:child("cancelbutton"):SetText(Lang:toText("global.cancel"))
    self:subscribe(self:child("surebutton"), UIEvent.EventButtonClick, function()
        if self.backFunc then
            self.backFunc(recipeData, enableComp)
        end
        UI:closeWnd(self)
    end)

    self:subscribe(self:child("cancelbutton"), UIEvent.EventButtonClick, function()
        local wnd = UI:openWnd("mapEditTeamSettingTip", function()
            UI:closeWnd(self)
        end, nil, Lang:toText("editor.ui.confirm.dontSave"))
        wnd:switchBtnPosition()
    end)

    local wndName = self:child("recipes-edit-name")
    local nameEdit = self:child("recipes-name-edit")
    self:subscribe(nameEdit, UIEvent.EventWindowTouchDown, function()
        nameEdit:SetTextWithNoTextChange(wndName:GetText())
    end)
    self:subscribe(nameEdit, UIEvent.EventWindowTextChanged, function()
        local text = nameEdit:GetPropertyString("Text","")
        if nameMap[text] then
            Lib.emitEvent(Event.EVENT_TOAST_TIP, Lang:toText("same.recipe.name"), 20)
            nameEdit:SetText("")
            return
        end
        if text ~= "" and not nameMap[text] then
            wndName:SetText(text)
            local width = wndName:GetFont():GetTextExtent(Lang:toText(text),1.0)
            nameEdit:SetText("")
            recipeData.name = text
        end
    end)

    self.addComBtn = self:child("addComposite")
    self:subscribe(self.addComBtn, UIEvent.EventButtonClick, function()
        if not enableComp then
            Lib.emitEvent(Event.EVENT_TOAST_TIP, Lang:toText("materials.letter"), 20)
            return
        end
        UI:openMultiInstanceWnd("mapEditItemBagSelect",{uiNameList = uiNameList, backFunc = function(item, isBuff)
            self:selectComposite(item, isBuff)
        end})
    end)
    self.delComBtn = self:child("delComposite")
    self.delComBtn:SetVisible(false)
    self:subscribe(self.delComBtn, UIEvent.EventButtonClick, function()
        self:selectCompItem()
        self:delectComposite()
    end)

    self:subscribe(self:child("compositeImage"), UIEvent.EventWindowClick, function()
        self:selectCompItem(true)
        self:selectedItemCell()
    end)

    self.recipeNameWnd = self:child("recipeNameWnd")
    self.recipeNameWnd:SetVisible(false)
end

function M:selectCompItem(status)
    self.delComBtn:SetVisible(status and true or false) 
    local img = status and "set:compositonEdit.json image:bg_compositon_act.png" or "set:compositonEdit.json image:bg_compositon_nor.png"
    self:child("compositebg"):SetBackImage(img)
end

function M:delectComposite()
    recipeData.composition = {}
    self:showComposite()
end

function M:selectComposite(item, isBuff)
    local composition = recipeData.composition
    if not composition then
        composition = { {} }
        recipeData.composition = composition
    end
    if not next(composition) then
        composition[1] = {}
    end
    local type = item:type()
    composition[1].type = string.upper(string.sub(type, 1, 1)) .. string.sub(type, 2)
    composition[1].name = item:cfg().fullName or item:full_name()
    self:checkCompEnable()
    self:showComposite()
end

function M:checkCompEnable()
    local materials = recipeData.materials or {}
    local count = 0
    for i=1, 9 do 
        if materials[i] and next(materials[i]) or materials[tostring(i)] then
            count = count + 1
        end
    end
    enableComp = count >= 2
    self:child("compositeAdd"):SetEnabledRecursivly(enableComp)
    self:child("addComposite"):SetEnabledRecursivly(true)
    if enableComp then
        self:child("addComposite"):SetNormalImage("set:compositonEdit.json image:icon_add_comp_nor.png")
        self:child("addComposite"):SetPushedImage("set:compositonEdit.json image:icon_add_comp_act.png")
    else
        self:child("addComposite"):SetNormalImage("set:compositonEdit.json image:icon_add_com_unable.png")
        self:child("addComposite"):SetPushedImage("set:compositonEdit.json image:icon_add_com_unable.png")
    end
end

function M:showComposite()
    local img = self:child("compositeImage")
    local composition = recipeData.composition and recipeData.composition[1] or {}

    self:child("compositename"):SetText(Lang:toText(getName(composition.type, composition.name) or ""))
    self.addComBtn:SetVisible(not composition.name)
    --self.delComBtn:SetVisible(composition.name and true or false)
    if composition.name then
        img:SetImage(getIcon(composition.type, composition.name))
    else
        img:SetImage("")
    end
end

function M:showRecipe()
    if not recipeData.name then
        recipeData.name = defaultName .. "." .. newName
        newName = newName + 1
    end
    local text, th = getRecipeName(recipeData.name)
    self:child("recipes-edit-name"):SetText(Lang:toText(text) .. (th and th or ""))

    self.itemGrid:RemoveAllItems()
    local index = 0
    local materials = recipeData.materials or {} 
    for i=1, 9 do 
        local data = materials[i] or materials[tostring(i)]
        local cell = self:createCell(i, data)
        self.itemGrid:AddItem(cell)
    end
    self:checkCompEnable()
end

function M:addMaterialItem(index, item, isBuff)
    local materials = recipeData.materials
    if not materials then
        materials = {}
        recipeData.materials = materials
    end
    local type = item:type()
    materials[tostring(index)] = {
        type = string.upper(string.sub(type, 1, 1)) .. string.sub(type, 2),
        name =  item:cfg().fullName or item:full_name(),
        count = 1
    }
    local cell = materialCells[index]
    self:setCell(cell, materials[tostring(index)])
    self:checkCompEnable()
end

function M:selectedItemCell(cell)
    if self.lastItemCell then
        self.lastItemCell:child("compositonCell-close"):SetVisible(false)
        self.lastItemCell:child("compositonCell-itemBg"):SetArea({0, 0}, {0, 0}, {1, -10}, {1, -10})
        self.lastItemCell:child("compositonCell-itemBg"):SetImage("set:compositonEdit.json image:materil_item_nor.png")
    end
    if cell then
        cell:child("compositonCell-close"):SetVisible(true)
        cell:child("compositonCell-itemBg"):SetArea({0, 0}, {0, 0}, {1, -2}, {1, -2})
        cell:child("compositonCell-itemBg"):SetImage("set:compositonEdit.json image:materil_item_act.png")
    end
    self.lastItemCell = cell
end

function M:setCell(cell, data)
    local delBtn = cell:child("compositonCell-close")
    local nameText = cell:child("compositonCell-itemName")
    local img = cell:child("compositonCell-itemIcon")
    local bg = cell:child("compositonCell-itemBg")
    bg:SetImage("set:compositonEdit.json image:materil_item_nor.png")
    
    if data then
        img:SetImage(getIcon(data.type, data.name))
        nameText:SetVisible(true)
        delBtn:SetVisible(false)
        local text = Lang:toText(getName(data.type, data.name))
        local len = string.len(text)
        local newText = text:sub(1,9) .. ( len >9 and "..." or "")
        nameText:SetText(newText)
    else
        nameText:SetVisible(false)
        delBtn:SetVisible(false)
        bg:SetImage("set:setting_global.json image:btn_add_player_actor_a.png")
    end
end

function M:createCell(index, data)
    local cell = fetchCell()
    self:setCell(cell, data)

    cell:setData("index", index)
    self:subscribe(cell, UIEvent.EventWindowClick, function()
        local material = getIndexMaterial(index)
        if material and next(material) then
            self:showMaterialName(material.type, material.name)
            self:selectedItemCell(cell)
            self:selectCompItem()
            return
        end
        UI:openMultiInstanceWnd("mapEditItemBagSelect",{uiNameList = uiNameList, backFunc = function(item, isBuff)
            self:addMaterialItem(index, item, isBuff)
        end})
    end)

    local delBtn = cell:child("compositonCell-close")
    self:subscribe(delBtn, UIEvent.EventButtonClick, function()
        local material = getIndexMaterial(index)
        if not material or not next(material) then
            return
        end
        recipeData.materials[index] = nil
        recipeData.materials[tostring(index)] = nil
        if self.lastItemCell and self.lastItemCell == cell then
            self.lastItemCell = nil
        end
        self.itemGrid:RemoveItem(cell)
        self:showRecipe()
    end)
    materialCells[index] = cell
    return cell
end

function M:showMaterialName(type, name)
    if not (type or name) then
        return
    end
    if self.showNameTimer then
        self.showNameTimer()
    end
    local itemName = getName(type, name)
    self.recipeNameWnd:SetVisible(true)
    local text = Lang:toText(itemName)
    local textWnd = self:child("showitemname")
    textWnd:SetText(text)
    local len = textWnd:GetFont():GetTextExtent(text, 1) + 50
    self.recipeNameWnd:SetWidth({0, len})
    self:child("recipenameBg"):SetWidth({0, len})
    textWnd:SetWidth({0, len})
    textWnd:SetTextHorzAlign(1)
    self.showNameTimer = World.Timer(20 * 5, function()
        self.recipeNameWnd:SetVisible(false)
    end)
end

function M:onOpen(data, backFunc, nameMapData)
    nameMap = nameMapData
    for k, v in pairs(nameMap or {}) do
        local name , th = getRecipeName(k)
        newName = math.max(newName, th and th + 1 or 1)
    end
    self.itemGrid:SetMoveAble(false)
    self.itemGrid:InitConfig(0, 0, 3)
    self.itemGrid:SetAutoColumnCount(false)
    self.delComBtn:SetVisible(false)
    self.lastItemCell = nil
    self.backFunc = backFunc
    recipeData = Lib.copy(data or {})
    self:showComposite()
    self:showRecipe()
end

return M