local setting = require "common.setting"
local editorSetting = require "editor.setting"
local block2block = {}

local cell_pool = {}
local function fetchCell()
	local ret = table.remove(cell_pool)
	if not ret then
		ret = UIMgr:new_widget("cell")
	end
	return ret
end

function M:init()
    WinBase.init(self, "buildingReplace_edit.json")
    self.m_lt = self:child("Replace-Layout-Lt")
    self.m_rt = self:child("Replace-Layout-Rt")
    self.m_ltGrid = self:child("Replace-Layout-Lt-Grid")
    self.m_rtGrid = self:child("Replace-Layout-Rt-Grid")
    self.m_close = self:child("Replace-Close")
    self.m_sure = self:child("Replace-Layout-Sure")
    self:child("Replace-Layout-Rt-ClipLayout"):SetClipChild(true)
    self:child("Replace-Layout-Sure-Text"):SetText(Lang:toText("gui_menu_exit_game_sure_btn"))
    self:child("Replace-Layout-Lt-Title"):SetText(Lang:toText("win.map.building.replace.title"))

    self:subscribe(self.m_close, UIEvent.EventButtonClick, function()
        self:closeReplace()
    end)

    self:subscribe(self:child("Replace-BG"), UIEvent.EventWindowClick, function()
        self:closeReplace()
    end)

    self:subscribe(self.m_sure, UIEvent.EventButtonClick, function()
        UI:closeWnd(self)
        handle_mp_editor_command("req_replace2", {rule = block2block})
        Lib.emitEvent(Event.EVENT_EDIT_REPLACE_CLOSE, 2)
    end)

     Lib.subscribeEvent(Event.EVENT_EDIT_REPLACE_COUNT, function(ret)              
          self:initLtGrid(ret)
     end)

     Lib.subscribeEvent(Event.EVENT_EDIT_BLOCK_REPLACE, function(blockCell)
        assert(blockCell)
        assert(self.lt_select_cell)
        local blockId = blockCell:data("item"):block_id()
        local icon = blockCell:data("item"):icon()
        local cell = self.lt_select_cell:child("Cell-Layout-Img-Rt"):GetChildByIndex(0):receiver() 
        cell._img_item:SetImage(icon)
        cell:onClick(true, "set:map_edit_bag.json image:itembox1_bag_select.png")

        block2block[self.lt_select_cell:data("name")] = blockId

		self.lt_select_cell:setData("rtIndex", blockCell:data("index") - 1)  
     end)

    Lib.emitEvent(Event.EVENT_EDIT_REPLACE_INIT, self, self.m_rtGrid)
end

function M:initLtGrid(ret)
    self.m_ltGrid:RemoveAllItems()
    self.m_ltGrid:InitConfig(0, 10, 1)
    local high = self.m_ltGrid:GetPixelSize().y / 4 - 15
    for name, count in pairs(ret or {}) do
        local blockId = setting:name2id("block", name)
        local cell = GUIWindowManager.instance:LoadWindowFromJSON("buildingCell_edit.json")
        local ltIcon = ObjectPicture.Instance():buildBlockPicture(blockId)
        ltIcon = blockId == 0 and "set:map_edit_fill_replace.json image:air_block_40px" or ltIcon 
        local ltCell = fetchCell()
        local rtCell = fetchCell()
        cell:child("Cell-Layout-Img-Lt"):AddChildWindow(ltCell)
        cell:child("Cell-Layout-Img-Rt"):AddChildWindow(rtCell)
        self:initCell(ltCell, ltIcon)
        self:initCell(rtCell, "set:map_edit_fill_replace.json image:icon_un_replace_70")

        cell:setData("name", name)
		cell:setData("rtIndex", 0)
        block2block[name] = nil
        local tmpName
        local cfg
        if blockId == 0 then
            tmpName = Lang:formatText( "myplugin/air_itemname" )
        else
            cfg = setting:fetch("block", name )
            local rCfg = editorSetting:fetch("block", name) 
            tmpName = Lang:formatText( ( rCfg and rCfg.cfg.itemname ) or ( cfg and cfg._name ) )
        end 
        local blockName = string.format("%s\n%s:%d", tmpName,Lang:toText( "editor.ui.count" ), count)
        cell:child("Cell-Layout-Name"):SetText(blockName)
        if not cfg or cfg.enableEditorBuilding ~= false then
            self.m_ltGrid:AddItem(cell)
        end
        cell:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 0, high})
        self:subscribe(cell:child("Cell-Layout"), UIEvent.EventWindowTouchUp, function()
            if self.lt_select_cell then
                self.lt_select_cell:child("Cell-Frame"):SetVisible(false)
                self.lt_select_cell:child("Cell-Layout-Img-Rt"):GetChildByIndex(0):receiver():onClick(false, "")
            end
            self.lt_select_cell = cell
            self.lt_select_cell:child("Cell-Frame"):SetVisible(true)
			local rtcell = self.m_rtGrid:GetItem(self.lt_select_cell:data("rtIndex"))
			if not rtcell then
				return
			end
			if self._select_cell then
				self._select_cell:receiver():onClick(false)
			end
			self._select_cell = rtcell
			self._select_cell:receiver():onClick(true, "set:map_edit_bag.json image:itembox1_bag_select.png")
            --todo
        end)
    end
    if self.m_ltGrid:GetItemCount() > 0 then
        local ltCell = self.m_ltGrid:GetItem(0)
        if not ltCell then
            return
        end
        self.lt_select_cell = ltCell
        self.lt_select_cell:child("Cell-Frame"):SetVisible(true)
        self.lt_select_cell:child("Cell-Layout-Img-Rt"):GetChildByIndex(0):receiver():onClick(true, "set:map_edit_bag.json image:itembox1_bag_select.png")
    end
end


function M:initCell(cell, icon)
    cell:SetArea({ 0, 0 }, { 0, 0 }, { 1,  0}, { 1, 0})
    cell:receiver()._img_frame:SetImage("set:map_edit_bag.json image:itembox1_bag.png")
    cell:receiver()._img_frame_select:SetImage("")
    cell:receiver()._img_frame_select:SetVisible(true)
    cell:receiver()._img_item:SetImage(icon)
    --self._select_cell:receiver():onClick(true, "set:map_edit_bag.json image:itembox1_bag_select.png")
end

function M:closeReplace()
    UI:closeWnd(self)
    Lib.emitEvent(Event.EVENT_EDIT_REPLACE_CLOSE, 1)
end

function M:onOpen()
    self.m_ltGrid:ResetPos()
    block2block = {}
	if self.m_rtGrid:GetItemCount() > 0 then
        local cell = self.m_rtGrid:GetItem(0)
        if not cell then
            return
        end
		if self._select_cell then
            self._select_cell:receiver():onClick(false, "")
            self._select_cell:receiver():setCellTip("")
        end
        self._select_cell = cell
        self._select_cell:receiver():onClick(true, "set:map_edit_bag.json image:itembox1_bag_select.png")
    end
end

function M:onClose()
    
end

function M:onReload(reloadArg)

end

return M