local cmd = require "editor.cmd"
local setting = require "common.setting"
local state = require "editor.state"
local engine = require "editor.engine"
local def = require "editor.def"
local data_state = require "editor.dataState"
local network_mgr = require "network_mgr"

local currentOperationType = nil
local scopeText = nil
local brush_obj = nil
local startPoint = nil
local endPoint = nil

local tipWin = nil

local cell_pool = {}

local function fetchCell()
	local ret = table.remove(cell_pool)
	if not ret then
		ret = UIMgr:new_widget("cell")
	end
	return ret
end

local function getBlockName(cell)
    local blockId = cell:data("item"):block_id()
    local blockCfg = Block.GetNameCfg(setting:id2name("block", blockId))
    local blockName = blockCfg.itemname or blockCfg._name
    return blockName
end

local function initCell(self, cell, newSize, item, idx)
    cell:SetArea({ 0, 0 }, { 0, 0 }, { 0, newSize }, { 0, newSize})
    cell:setData("index", idx)
    cell:receiver()._img_frame:SetImage("set:map_edit_bag.json image:itembox1_bag.png")
    cell:receiver()._img_frame_select:SetImage("")
    cell:receiver()._img_frame_select:SetVisible(true)
    
    if not item then
        cell:receiver()._img_locked:SetVisible(true)
        cell:receiver()._img_locked:SetArea({0,0},{0,0},{1,0},{1,0})
        cell:receiver()._img_locked:SetImage("set:map_edit_bag.json image:itembox2_empty_bag.png")
        return
    end
    cell:setData("item", item)
	cell:receiver()._img_item:SetImage(item:icon())
    self:subscribe(cell, UIEvent.EventWindowClick, function()
        local item = cell:data("item")
        if self._select_cell then
            self._select_cell:receiver():onClick(false, "")
            self._select_cell:receiver():setCellTip("")
        end
        self._select_cell = cell
        self._select_cell:receiver():onClick(true, "set:map_edit_bag.json image:itembox1_bag_select.png")
        self._select_cell:receiver():setCellTip(getBlockName(cell))
        Lib.emitEvent(Event.EVENT_EDIT_BLOCK_REPLACE, cell)
    end)
    
end

local function fetchBuildInfo(self, bagGrid, flag)
    local idx = 1
    bagGrid:InitConfig(20, 20, 4)
    bagGrid:SetClipChild(false)
	local newSize = bagGrid:GetPixelSize().y / 4 - 15
    local blocks = Clientsetting.getBlockList()
    if flag then
       local tmp = Clientsetting.getSpecialBlockList()
       for i, v in ipairs(tmp or {}) do
           table.insert(blocks, i, v) 
       end
    end
    local maxIdx = #blocks
	local function fetch()
		if idx > maxIdx then
            return false
        end
        local item = Item.CreateItem("/block", 1, function(_item)
                    _item:set_block(blocks[idx])
              end)
        if idx == 1 and flag then
           function item:icon()
              return "set:map_edit_fill_replace.json image:icon_un_replace_70"  
           end
        end
        function item:isShowCount()
            return false
        end
        local cell = fetchCell()
        initCell(self, cell, newSize, item, idx)
        local cfg = Block.GetNameCfg(blocks[idx])
        if cfg.enableEditorBuilding ~= false then
            bagGrid:AddItem(cell)
        end
        idx = idx + 1
        return true
    end 
    fetch()
    World.Timer(1, fetch)
end

local function fill(self)
    self:controlUI(false, false, false, false, true)
end

local function del(self)
    self:controlUI(false, false, true, false, false)
end

local function copy(self)
    self:controlUI(true, false, false, true, false, Lang:toText("composition.replenish.msg.sure.point"))
    handle_mp_editor_command("frame_to_chunk", {})
    handle_mp_editor_command("copy", {})
    data_state.is_can_move = true
end 

local function move(self)
    self:controlUI(true, false, false, true, false, Lang:toText("composition.move.msg.sure.point"))
    handle_mp_editor_command("frame_to_chunk", {})
    handle_mp_editor_command("cut", {})
    data_state.is_can_move = true
end

local function replace(self)
    self:controlUI(false, false, false, false, false)
    handle_mp_editor_command("frame_to_chunk", {})
    Lib.emitEvent(Event.EVENT_EDIT_REPLACE)
    handle_mp_editor_command("req_count", {})
end

local operationFunc = {fill, del, copy, move, replace}

local function initDefaultSelect(self, bagGrid)
    if bagGrid:GetItemCount() > 0 and not self._select_cell then
        local cell = bagGrid:GetItem(0)
        if not cell then
            return
        end
        self._select_cell = cell
        self._select_cell:receiver():onClick(true, "set:map_edit_bag.json image:itembox1_bag_select.png")
        self._select_cell:receiver():setCellTip(getBlockName(cell))
    end
end

function M:init()
    WinBase.init(self, "buildingTools_edit.json")

    self.m_msg = self:child("Buildings-Msg")
    self.m_msgBG = self:child("Buildings-MsgBG")
    self.m_operation = self:child("Buildings-Operation")
    self.m_tips = self:child("Buildings-Tips")
    self.m_copy = self:child("Buildings-Copy")
    self.m_fill = self:child("Buildings-Fill")

    self.m_valueBG = self:child("Buildings-Operation-Value-Bg")
    self.m_value = self:child("Buildings-Operation-Value")
    self.m_back = self:child("Buildings-Operation-Back")
    self.m_sure = self:child("Buildings-Operation-Sure")
    self.m_return = self:child("Buildings-Operation-Return")
    self.m_confrim = self:child("Buildings-Operation-Confrim")
    self.m_close = self:child("Buildings-Operation-Close")

    self.m_fillClose = self:child("Buildings-Fill-Operation-Close")
    self.m_fillGridview = self:child("Buildings-Fill-Operation-GridView")
    self.m_fillCancel = self:child("Buildings-Fill-Operation-Cancel")
    self.m_fillFill = self:child("Buildings-Fill-Operation-Fill")

    self.m_delSure = self:child("Buildings-Tips-Sure")
    self.m_delCancel = self:child("Buildings-Tips-Cancel")

    self.m_copyLt = self:child("Buildings-Copy-Left")
    self.m_copyzRt = self:child("Buildings-Copy-Right")
    self.m_copyBack = self:child("Buildings-Copy-Back")
    self.m_copySure = self:child("Buildings-Copy-Sure")
    self.m_copyClose = self:child("Buildings-Copy-Close")

    self:child("Buildings-Fill-Operation-ClipLayout"):SetClipChild(true)

    --self.m_valueBG:SetVisible(false)
    --self.m_copyClose:SetVisible(false)
    self:child("Buildings-Fill-Operation-Cancel-Text"):SetText(Lang:toText("global.cancel"))
    self:child("Buildings-Fill-Operation-Fill-Text"):SetText(Lang:toText("global.sure"))
    self:child("Buildings-Tips-Sure"):SetText(Lang:toText("win.map.edit.entity.setting.fetch.delete"))
    self:child("Buildings-Tips-Cancel"):SetText(Lang:toText("composition.replenish.no.btn"))
    self:child("Buildings-Tips-Context"):SetText(Lang:toText("win.map.edit.building.tools.tips.context"))
    self:child("Buildings-Tips-Title"):SetText(Lang:toText("composition.replenish.title"))
    self:child("Buildings-Fill-Operation-Title"):SetText(Lang:toText("composition.replenish.titleTip"))

    self:subscribe(self.m_back, UIEvent.EventButtonClick, function()
        UI:closeWnd(self)
        Lib.emitEvent(Event.EVENT_EDIT_TOOL_BAR)
    end)

    self:subscribe(self.m_sure, UIEvent.EventButtonClick, function()
        initDefaultSelect(self, self.m_fillGridview)
		handle_mp_editor_command("focusmode", {mode = "frame_p"})
        local focusObj = state:focus_obj()
        startPoint = { 
            x = math.ceil(focusObj.min.x - 0.5),
            y = math.ceil(focusObj.min.y - 0.5),
            z = math.ceil(focusObj.min.z - 0.5)
        }
        Lib.emitEvent(Event.FRAME_POSITION, startPoint)
        self:controlUI(true, true, false, false, false, Lang:toText("win.buildings.msg.scope"))
        self:controlOperationUI(false)
        self.m_copyBack:SetVisible(true)
    end)

    self:subscribe(self.m_return, UIEvent.EventButtonClick, function()
        Lib.emitEvent(Event.EVENT_EDIT_BUILDINGS_BACK)
        self:controlUI(true, true, false, false, false, Lang:toText("win.buildings.msg.start.point"))
        self:controlOperationUI(true)
        data_state.is_can_update = true
    end)

    self:subscribe(self.m_confrim, UIEvent.EventButtonClick, function()
		local brushObj = state:brush_obj()
        endPoint = { 
            x = math.ceil(brushObj.min.x - 0.5),
            y = math.ceil(brushObj.min.y - 0.5),
            z = math.ceil(brushObj.min.z - 0.5)
        }
        Lib.emitEvent(Event.FRAME_POSITION, endPoint)
        Lib.emitEvent(Event.EVENT_EDIT_CONFRIM, state:focus_obj().min)
        local centerPos = Lib.v3add(endPoint, startPoint)
        centerPos = Lib.v3multip(centerPos, 0.5)
        local pos = Blockman.instance:getCameraPos()
        Player.CurPlayer:setPosition(pos)
        operationFunc[currentOperationType](self)
    end)

    self:subscribe(self.m_close, UIEvent.EventButtonClick, function()
        UI:closeWnd(self)
    end)

    self:subscribe(self.m_fillClose, UIEvent.EventButtonClick, function()
        self:backToSelectScope()
    end)

    self:subscribe(self:child("Buildings-Buildings-Fill-BG"), UIEvent.EventWindowClick, function()
        self:backToSelectScope()
    end)

    self:subscribe(self.m_fillCancel, UIEvent.EventButtonClick, function()
        self:backToSelectScope()
    end)

    self:subscribe(self.m_fillFill, UIEvent.EventButtonClick, function()
        local id = self._select_cell:data("item"):block_id()
        local minPoint = {
            x = math.min(startPoint.x, endPoint.x),
            y = math.min(startPoint.y, endPoint.y),
            z = math.min(startPoint.z, endPoint.z)
        }
        local maxPoint = {
            x = math.max(startPoint.x, endPoint.x),
            y = math.max(startPoint.y, endPoint.y),
            z = math.max(startPoint.z, endPoint.z)  
        }
        local blockRegion = {min = minPoint, max = maxPoint, id = id}
        cmd:block_fill(blockRegion)
        UI:closeWnd(self)
    end)

    self:subscribe(self.m_delCancel, UIEvent.EventButtonClick, function()
        self:backToSelectScope()
    end)

    self:subscribe(self:child("Buildings-Buildings-Tips-BG"), UIEvent.EventWindowClick, function()
        self:backToSelectScope()
    end)

    self:subscribe(self.m_delSure, UIEvent.EventButtonClick, function()
        handle_mp_editor_command("frame_to_chunk", {})
        handle_mp_editor_command("delete", {})
        UI:closeWnd(self)
    end)                      
    
    self:subscribe(self.m_copyLt, UIEvent.EventButtonClick, function()
        --rotate lt
        Lib.emitEvent(Event.EVENT_EDIT_ROTATE, 1)  ---rotate left
    end)                                 

    self:subscribe(self.m_copyzRt, UIEvent.EventButtonClick, function()
        ----rotate rt
        Lib.emitEvent(Event.EVENT_EDIT_ROTATE, 2)   --rotate right
    end)

    self:subscribe(self.m_copyBack, UIEvent.EventButtonClick, function()
        if currentOperationType == 4 then
            handle_mp_editor_command("undo")
        end
        Player.CurPlayer:setPosition(endPoint)
        self:backToSelectScope()
        data_state.is_can_move = false
    end)

    self:subscribe(self.m_copySure, UIEvent.EventButtonClick, function()
       
        Lib.emitEvent(Event.EVENT_EDIT_COPY_SURE)
        if currentOperationType == 4 then
            UI:closeWnd(self)
        end

        if currentOperationType == 3 then
            self:controlUI(true, false, false, true, false, Lang:toText("composition.replenish.msg.again"))
            self.m_copyBack:SetVisible(false)
        end
    end)

    self:subscribe(self.m_copyClose, UIEvent.EventButtonClick, function()
        if currentOperationType == 4 then
            handle_mp_editor_command("undo")
        end
        UI:closeWnd(self)
    end)

    Lib.subscribeEvent(Event.EVENT_CONFIRM_POINT, function()
        self:controlUI(true, true, false, false, false, Lang:toText("win.buildings.msg.start.point"))
        self:controlOperationUI(true)
        data_state.is_can_update = true
    end)      

    Lib.subscribeEvent(Event.EVENT_BOUND_SCOPE, function(scope)
        scopeText = string.format("(%s*%s*%s)", scope.x, scope.y, scope.z)
        self:controlUI(true, true, false, false, false, Lang:toText("win.buildings.msg.scope"))
        self:controlOperationUI(false, scopeText)
    end)
    self:controlUI(true, true, false, false, false, Lang:toText("win.buildings.msg.start.point"))

     Lib.subscribeEvent(Event.EVENT_EDIT_REPLACE_INIT, function(obj, gridView)            
        fetchBuildInfo(obj, gridView, true)
     end)

     Lib.subscribeEvent(Event.EVENT_EDIT_REPLACE_CLOSE, function(operationType)
        assert(operationType)
        if operationType == 1 then
            self:backToSelectScope()
        else
            UI:closeWnd(self)
        end
     end)
     fetchBuildInfo(self, self.m_fillGridview)
end

function M:backToSelectScope()
    self:controlUI(true, true, false, false, false, Lang:toText("win.buildings.msg.scope"))
    self:controlOperationUI(false, scopeText)
    Lib.emitEvent(Event.EVENT_EDITOR_STATE_BACK_BRUSH)
end

function M:controlUI(msg, op, tip, menu, fill, msgText)
   self.m_msg:SetText(msgText or "")
   self.m_msgBG:SetVisible(msg)
   local width =  self.m_msg:GetFont():GetTextExtent(msgText or "",1.0)
   if width > 500 then
        self.m_msgBG:SetWidth({0 , 500 + 114 })
        self.m_msg:SetWidth({0 , 500})
   else
        self.m_msgBG:SetWidth({0 , width + 114 })
        self.m_msg:SetWidth({0 , width})
   end
  
   self.m_operation:SetVisible(op)
   self.m_tips:SetVisible(tip)
   self.m_copy:SetVisible(menu)
   self.m_fill:SetVisible(fill)
end

function M:controlOperationUI(show, text) 
    self.m_back:SetVisible(show)
    self.m_sure:SetVisible(show)
    self.m_return:SetVisible(not show)
    self.m_confrim:SetVisible(not show)
    self.m_value:SetVisible(not show)
    self.m_close:SetVisible(not show)
    self.m_valueBG:SetVisible(not show)
    self.m_value:SetText(text or "")
end

function M:openPathRemind()
    if not tipWin then
            tipWin = GUIWindowManager.instance:LoadWindowFromJSON("entitySettingCrlTip_edit.json")

            
            local function CloseTipsWnd()
                if not Clientsetting.isKeyGuide("isAreaRemind") then
                        local retry = 1
                        World.Timer(5, function()
                            local respone = network_mgr:set_client_cache("isAreaRemind", "1")
                            if respone.ok or retry > 2 then
								if respone.ok then
									Clientsetting.setGuideInfo("isAreaRemind", false)
								end
                                return false
                            end
                            retry = retry + 1
                            return true
                        end)
                    end
                    self:root():RemoveChildWindow1(tipWin)
            end
            
            local title = tipWin:child("Entity-Ctr-Frame-Title")
            local context =  tipWin:child("Entity-Ctr-Frame-Context")
            local image = tipWin:child("Entity-Ctr-Tips-Frame-Demo")
            local warning = tipWin:child("Entity-Ctr-Tips-Frame-Warning")
            local click = tipWin:child("Entity-Ctr-Tips-Frame-Click")
           
            title:SetText(Lang:toText("composition.replenish.title"))
            context:SetFontSize("HT20")
            context:SetText(Lang:toText("win.building.control.remind.text"))
            context:SetYPosition({0.18 , 0})
            image:SetImage("set:map_edit_buildingAreaTips.json image:select_area_image")
            image:SetArea({0, 0}, {0.35, 0}, {0, 606}, {0, 205})
            warning:SetText(Lang:toText("EntitySetting_crl_tip_choiceText"))
            if World.LangPrefix ~= "zh" then
                warning:SetArea({0.7, 0}, {0.857778, 0}, {0, 76}, {0, 24})
                click:SetArea({0.64, 0}, {0.83, 0}, {0, 270}, {0, 50})
            end

            local isAreaRemind = false
            self:subscribe(click, UIEvent.EventWindowClick, function()
                if isAreaRemind == false then
                    tipWin:child("Entity-Ctr-Tips-Frame-Select"):SetChecked(true)
                    isAreaRemind = true
                else
                    tipWin:child("Entity-Ctr-Tips-Frame-Select"):SetChecked(false)
                    isAreaRemind = false
                end
				Clientsetting.setlocalGuideInfo("isAreaRemind", not isAreaRemind)
            end)

            self:subscribe(tipWin:child("Entity-Ctr-Close"), UIEvent.EventButtonClick, function()
                CloseTipsWnd()
            end)

            self:subscribe(tipWin:child("Entity-Ctr-BG"), UIEvent.EventWindowClick, function()
                CloseTipsWnd()
            end)
        end
        self:root():AddChildWindow(tipWin)
end

function M:onOpen(operationType, brush)
    Me.cantUseSkill = true
    self.recoCamera = self:changeCamera()
    EditorModule:emitEvent("openBuildingTools")
	data_state.is_can_place = false
    Lib.emitEvent(Event.EVENT_OPEN_INVENTORY, false)
    --self:backToClose(true)
    self:controlUI(true, true, false, false, false, Lang:toText("win.buildings.msg.start.point"))
    currentOperationType = operationType
    brush_obj = brush

    if Clientsetting.isKeyGuide("isAreaRemind") then
        self:openPathRemind()
    else
        tipWin = nil
    end
end

function M:changeCamera()
	local bm = Blockman.instance
	local cameraInfo = bm:getCameraInfo(4)
	local saveCameraData = {
		curInfo = cameraInfo.curInfo,
		viewCfg = cameraInfo.viewCfg,
	}
	local viewCfg = {
		enable = true,
		distance = 10,
		lockBodyRotation = false
	}
	bm:setPersonView(4)
	if viewCfg then
		bm:changeCameraCfg(viewCfg, 4)
	end

	return function()
		local personView = bm:getCurrPersonView()
		bm:changeCameraCfg(saveCameraData.viewCfg, personView)
		bm:setPersonView(saveCameraData.curInfo.curPersonView)
	end
end

function M:onClose()
    Me.cantUseSkill = nil
    self.recoCamera()
    EditorModule:emitEvent("closeBuildingTools")
    data_state.is_can_place = true
    data_state.is_can_move = false
    Lib.emitEvent(Event.EVENT_OPEN_EDIT_MAIN)
    if brush_obj then
        state:set_brush(brush_obj._table, brush_obj.class)
    else
        handle_mp_editor_command("esc")
        state:set_focus(nil)
    end
end

function M:onReload(reloadArg)

end

return M