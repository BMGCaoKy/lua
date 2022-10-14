local entity_obj = require "editor.entity_obj"

local cell_pool = {}

local function fetchCell()
	local ret = table.remove(cell_pool)
	if not ret then
		ret = UIMgr:new_widget("cell")
	end
	return ret
end

local function initCell(self, cell, newSize, fullName, idx, cfg, icon,type)
    cell:SetArea({ 0, 0 }, { 0, 0 }, { 0, newSize }, { 0, newSize})
    cell:setData("index", idx)
    cell:receiver()._img_frame:SetImage("set:map_edit_bag.json image:itembox1_bag.png")
    cell:receiver()._img_frame_select:SetImage("")
    cell:receiver()._img_frame_select:SetVisible(true)
    cell:setData("name", fullName)
    if not icon then
        cell:receiver()._img_locked:SetVisible(true)
        cell:receiver()._img_locked:SetArea({0,0},{0,0},{1,0},{1,0})
        cell:receiver()._img_locked:SetImage("set:map_edit_bag.json image:itembox2_empty_bag.png")
        return
    end
    cell:receiver()._img_item:SetImage(icon)
    cell:receiver()._img_item:SetVisible(true)
    
    self:subscribe(cell, UIEvent.EventWindowClick, function()
        local item = cell:data("item")
        if self._select_cell then
            self._select_cell:receiver():onClick(false, "")
        end
        self._select_cell = cell
        self._select_cell:receiver():onClick(true, "set:map_edit_bag.json image:itembox1_bag_select.png")
        self.selectBlockCfg = cfg
    end)
    
end

function M:init()
    WinBase.init(self, "dropItem_edit.json", true)
    self.titleLb = self:child("Item-Title")
    self.grid = self:child("Item-Grid")
    self.closeBtn = self:child("Item-closeBtn")
    self:subscribe(self:child("Item-OK"), UIEvent.EventButtonClick, function()
        entity_obj:Cmd("openUI", self.vectorEntityId)
        if self.selectBlockCfg then
            entity_obj:Cmd("changeStyle", self.vectorEntityId, self.selectBlockCfg)
        end
        UI:closeWnd("dropItem")
    end)
    self:subscribe(self.closeBtn, UIEvent.EventButtonClick, function()
        entity_obj:Cmd("openUI", self.vectorEntityId)
        UI:closeWnd("dropItem")
    end)
    self.grid:InitConfig(40, 0, 4)
    self.grid:SetAutoColumnCount(false)
    self.grid:SetArea({0,-40}, {0,0}, {1,0},{0,100})
    self:fetchStyleBlock()
end


function M:fetchStyleBlock()
    local items = Clientsetting.getBlockStyleList()
    local idx = 0
    for _, fullName in pairs(items or {}) do
        local cfg = Block.GetNameCfg(fullName)
        local icon = ResLoader:loadImage(cfg, cfg.icon)
        local cell = fetchCell()
        idx = idx + 1
        initCell(self, cell, 100, fullName, idx, cfg, icon, "block")
        self.grid:AddItem(cell)
    end
end

function M:initSelectCell(selectBlockCfg)
    if self._select_cell then
        self._select_cell:receiver():onClick(false, "")
        self._select_cell = nil
    end

    for i = 0, self.grid:GetItemCount() - 1 do
        local cell = self.grid:GetItem(i)
        if cell and  cell:data("name") == selectBlockCfg.fullName then
            cell:receiver():onClick(true, "set:map_edit_bag.json image:itembox1_bag_select.png")
            self._select_cell = cell
        end
    end
end

function M:onOpen(packet)
    self.pos = packet.pos
    self.selectBlockCfg = packet.cfg
    self.vectorEntityId = packet.vectorEntityId
    self:initSelectCell(self.selectBlockCfg)
    Lib.emitEvent(Event.EVENT_BLOCK_VECTOR, false)

end
