local entity_obj = require "editor.entity_obj"
local blockVector_obj = require "editor.blockVector_obj"
local setting = require "common.setting"
local entity_obj_derive = require "editor.entity_obj_derive"


function M:init()
    WinBase.init(self, "mapBlockVectorTip_edit.json", true)
    self:initUiName()
    self:registerEvent()

end

local function get_id(pos)
    return string.format( "%d,%d,%d",pos.x, pos.y, pos.z)
end

function M:initUiName()
    self.count = self:child("Edit-Map-Tip-Block-Counts")
    self.icon = self:child("Edit-Map-Tip-Block-Icon")
    self.emptyBtn = self:child("Edit-Map-Tip-Droppings-No-Btn")
    self.thingBtn = self:child("Edit-Map-Tip-Droppings-Have-Btn")
    self.changeType = self:child("Edit-Map-Tip-Dlg-Change-Type")
    self.closeBtn = self:child("Edit-Map-Tip-Close")
    self.blockIcon = self:child("Edit-Map-Tip-Speicial-Block")
    self.changeBlockStypeBtn = self:child("Edit-Map-Tip-Dropper")
end


function M:getSetting(pos)
    return blockVector_obj:get_block_vector(pos)
end

function M:updataUi(params)
    if self.vectorSetting and self.vectorSetting.count then
        self.count:SetText(string.format( "%d",self.vectorSetting.count))
    else
        self.count:SetText("")
    end
end

local function CreateItem(type, fullName, args)
    local item = EditorModule:createItem(type, fullName, args)
    local cfg = item:cfg()
    return item, cfg
end

function M:showItemInfo(setting, blockCfg)
    if blockCfg then
        local img = ResLoader:loadImage(blockCfg, blockCfg.icon)
        self.blockIcon:SetImage(img)
        self.blockIcon:SetVisible(true)
    end

    if setting and setting.count and setting.count ~= 0 then
        local item, cfg = CreateItem(setting.type, setting.fullName)
        self.count:SetText(string.format( "%d",setting.count))
        self.emptyBtn:SetVisible(false)
        self.thingBtn:SetVisible(true)
        self.icon:SetImage(item and item:icon() or "")
    else
        self.emptyBtn:SetVisible(true)
        self.thingBtn:SetVisible(false)
        self.count:SetText("")
        self.icon:SetImage("")
    end
end


function M:registerEvent()
    self:subscribe(self.closeBtn, UIEvent.EventButtonClick, function()
        UI:closeWnd(self)
    end)

    self:subscribe(self.thingBtn, UIEvent.EventButtonClick, function()
        Lib.emitEvent(Event.EVENT_VECTOR_SET_VALUE, true, {
            vectorEntityId = self.vectorEntityId,
            pos = self.pos,
            blockVector = true
        })
    end)

    self:subscribe(self.emptyBtn, UIEvent.EventButtonClick, function()
        Lib.emitEvent(Event.EVENT_VECTOR_SET_VALUE, true, {
            vectorEntityId = self.vectorEntityId,
            pos = self.pos,
            blockVector = true
        })
    end)

    self:subscribe(self.changeBlockStypeBtn, UIEvent.EventButtonClick, function()
        UI:openWnd("dropItem", {
            vectorEntityId = self.vectorEntityId,
            cfg = self.blockCfg
        })
    end)

    Lib.subscribeEvent(Event.EVENT_CLOSE_POP_WIN, function()
        UI:closeWnd(self)
    end)

end

function M:onOpen(params)
    self.vectorEntityId = params.vectorEntityId
    if params.cfg then
        self.blockCfg = params.cfg
    end
    self.vectorSetting = entity_obj:getDataById(self.vectorEntityId) 
    self:showItemInfo(self.vectorSetting, params.cfg)

    Blockman.instance.gameSettings.isPopWindow = true

end

function M:onClose()
    Blockman.instance.gameSettings.isPopWindow = false  
end
