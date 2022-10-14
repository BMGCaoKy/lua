cmd = require "editor.cmd"
local state = require "editor.state"
local duration = require "editor.edit_record.duration"
local data_state = require "editor.dataState"

local eventTracking = {
    lastStep = "click_last",
    nextStep = "click_next",
    empty = "click_space",
    del = "click_clean",
    fill = "click_select_fill",
    copy = "click_select_copy",
    move = "click_select_move",
    replace = "click_select_replace",
    chunk_del = "click_select_del",
    save = "click_save"
}

local btnImageMap = {
    save = {
        image = "set:mapEditToolbarImg.json image:click_save_tools"
    },
    lastStep = {
        image = "set:mapEditToolbarImg.json image:back_button_tools"
    },
    nextStep = {
        image = "set:mapEditToolbarImg.json image:redo_button_tools"
    },
    fill = {
        image = "set:mapEditToolbarImg.json image:icon_fill_nor"
    },
    copy = {
        image = "set:mapEditToolbarImg.json image:icon_copy_nor"
    },
    move = {
        image = "set:mapEditToolbarImg.json image:icon_move_nor"
    },
    replace = {
        image = "set:mapEditToolbarImg.json image:icon_replace_nor"
    },
    chunk_del ={
        image = "set:mapEditToolbarImg.json image:icon_delete_nor"
    },
    empty = {
        image = "set:mapEditToolbarImg.json image:click_button_tools",
        selectImage = "set:mapEditToolbarImg.json image:click_button_tools_select"
    },
    del = {
        image = "set:mapEditToolbarImg.json image:delete_button_tools",
        selectImage = "set:mapEditToolbarImg.json image:delete_button_tools_select",
    },
}

local function unifyProc(self, btn, proc)
    self:subscribe(btn, UIEvent.EventButtonClick, function()
        self:unsubscribe(btn)
        World.Timer(1, function()
            if not btn then
                return
            end
            unifyProc(self, btn, proc)
        end)
        if proc then
            proc()
        end
    end)
end

local function revocation(self)
    handle_mp_editor_command("undo")
end

local function del(self)
    data_state.is_del_state = true
	if state:brush_obj() then
		Lib.emitEvent(Event.EVENT_EMPTY_STATE)
	end
	handle_mp_editor_command("esc")
end

local function recovery(self)
    handle_mp_editor_command("redo")
end

local function empty(self)
    data_state.is_del_state = false
    handle_mp_editor_command("esc")
    Lib.emitEvent(Event.EVENT_EMPTY_STATE)
end

local function saveMap(self, saveMsg, saveSuccMsg)
	UI:openWnd("savePanel", true, saveMsg or "edit.saveing")
	World.Timer(1, function()
		handle_mp_editor_command("save_MpMap", {path = ""})

		if self.saveTimer then
			self.saveTimer()
			self.saveTimer = nil
		end
		Lib.emitEvent(Event.EVENT_OPEN_SAVEPANEL, true, saveSuccMsg or "Edit_SavePanel_text")
		self.saveTimer = World.Timer(8, function()
			UI:closeWnd("savePanel")
			return false
		end)
		return false
	end)
end

local function fill(self)
    self:enterBuildTools(1)
end

local function copy(self)
    self:enterBuildTools(3)
end

local function move(self)
    self:enterBuildTools(4)
end

local function replace(self)
    self:enterBuildTools(5)
end

local function chunk_del(self)
    self:enterBuildTools(2)
end

local operationFunc = {fill = fill, copy = copy, move = move, replace = replace, chunk_del = chunk_del,
                     lastStep = revocation, nextStep = recovery, del = del, empty = empty, save = saveMap}

function M:init()
    WinBase.init(self, "toolBar_edit.json")
    self.m_setting = self:child("ToolBar-Menu-Setting")
	self.m_test = self:child("ToolBar-Menu1-Test")  
	self.m_level = self:child("ToolBar-Menu1-Level") 
    self.m_global = self:child("ToolBar-Menu1-GlobalSetting")
    self.m_global:SetVisible(not not World.cfg.isShowGlobalSetting)

    self.flyActIcon = "set:map_edit_main_fly.json image:icon_fly_act.png"
    self.flyNorIcon = "set:map_edit_main_fly.json image:icon_fly_nor.png"

    self.isFly = true   --默认为飞行状态
    self:initFly(self.isFly)
    self:subscribe(self:child("ToolBar-Menu2-Fly"), UIEvent.EventButtonClick, function()
        local isThirdView = EditorModule:getMoveControl():isThirdView()
        if isThirdView then
            CGame.instance:onEditorDataReport("click_setting_third_person_perspective_fly", "")
            EditorModule:getMoveControl():switchThirdMoveWay(not self.isFly)
        else
            CGame.instance:onEditorDataReport("click_setting_first_person_perspective_fly", "")
            EditorModule:getMoveControl():switchFristMoveWay(not self.isFly)
        end
        self:initFly(EditorModule:getMoveControl():isEnableFly())
    end)

    Lib.subscribeEvent(Event.EVENT_SWITCH_STAGE, function ()
        self:initFly(true)
    end)

    Lib.subscribeEvent(Event.EVENT_CHANGE_MAIN_UI_STATE, function (cfg)
        if cfg.isFly ~= nil then
            self:initFly(cfg.isFly)
        end
    end)

    unifyProc(self, self.m_test, function()
        duration:clickTestWriteFile()
        CGame.instance:onEditorDataReport("click_test", "", 3)
        handle_mp_editor_command("esc")
        Lib.emitEvent(Event.EVENT_EDIT_MAP_MAKING)
        World.Timer(1, function()
            handle_mp_editor_command("save_MpMap", {path = ""})
            local gameRootPath = CGame.Instance():getGameRootDir()
            CGame.instance:restartGame(gameRootPath, World.GameName, 1, false)
        end)
    end)

    self:subscribe(self.m_level, UIEvent.EventButtonClick, function()
        CGame.instance:onEditorDataReport("click_stage", "", 3)
        Lib.emitEvent(Event.EVENT_SHOW_STAGE_EDIT_LIST, true)
        if Clientsetting.isKeyGuide("isGuideStage") then
            Lib.emitEvent(Event.EVENT_EDIT_OPEN_GUIDE_WND, 4)
        end
    end)

    unifyProc(self, self.m_global, function()
        Lib.emitEvent(Event.EVENT_EDIT_GLOBAL_SETTING, true)
    end)

    Lib.subscribeEvent(Event.EVENT_CHANGE_PERSONVIEW, function()
        self:updatePerspeceIcon()
    end)

    self:subscribe(self.m_setting, UIEvent.EventButtonClick, function()
        CGame.instance:onEditorDataReport("click_global_setting", "")
		Lib.emitEvent(Event.EVENT_MAP_EDIT_SETTING)
    end)

    self:initUI()
    Lib.subscribeEvent(Event.EVENT_ESC_CMD, function()
        self.m_empty:SetImage(btnImageMap.empty.image)
        self.m_del:SetImage(btnImageMap.del.image)

        if not state:brush_obj() then
            if data_state.is_del_state then
                self.m_del:SetImage(btnImageMap.del.selectImage)
            else
                self.m_empty:SetImage(btnImageMap.empty.selectImage)
            end
        end
    end)
     Lib.subscribeEvent(Event.EVENT_NOVICE_GUIDE, function(indexType, isFinish)
        if indexType == 7 then
            self.m_empty:SetName("ToobBarEmpty")
        end
    end)

    if World.CurWorld.isEditorEnvironment and World.cfg.autoSaveTime then
        self.autoSaveTimer = World.Timer(World.cfg.autoSaveTime, function()
            saveMap(self, "edit.auto.save", "edit.auto.save.succ")
            return true
        end)
    end
    
end

function M:initFly(flyState)
    self.isFly = flyState
    self:child("ToolBar-Menu2-Fly"):setBelongWhitelist(true)
    if flyState then
        self:child("ToolBar-Menu2-Fly"):SetNormalImage(self.flyActIcon)
        self:child("ToolBar-Menu2-Fly"):SetPushedImage(self.flyActIcon)
    else
        self:child("ToolBar-Menu2-Fly"):SetNormalImage(self.flyNorIcon)
        self:child("ToolBar-Menu2-Fly"):SetPushedImage(self.flyNorIcon)
    end
    Lib.emitEvent(Event.EVENT_CHANGE_MAIN_UI_STATE, {isFly = flyState})
end

function M:enterBuildTools(id)
    Lib.emitEvent(Event.EVENT_BUILDING_TOOLS, id, state:brush())
    UI:closeWnd(self)
end

function M:updatePerspeceIcon()
    local view = Blockman.instance:getCurrPersonView()
    local imageNor = "set:map_edit_main.json image:icon_view2_back_nor"
    local imageAct = "set:map_edit_main.json image:icon_view2_back_act"
    if view == 0 then
        imageNor = "set:map_edit_main.json image:icon_view3_aim_nor"
        imageAct = "set:map_edit_main.json image:icon_view3_aim_act"
    elseif view == 1 then
        imageNor = "set:map_edit_main.json image:icon_view2_back_nor"
        imageAct = "set:map_edit_main.json image:icon_view2_back_act"
    elseif view == 2 then
        imageNor = "set:map_edit_main.json image:icon_view1_font_nor"
        imageAct = "set:map_edit_main.json image:icon_view1_back_act"
    end

    if view==0 then
        Lib.emitEvent(Event.FRONTSIGHT_SHOW, 2)
    else
        Lib.emitEvent(Event.FRONTSIGHT_NOT_SHOW, 2)
    end
end

function M:onPerspeceChanged()
    Blockman.instance:switchPersonView()
    PlayerControl.UpdatePersonView()

    local view = Blockman.Instance():getCurrPersonView()
    if view==0 then
        Lib.emitEvent(Event.FRONTSIGHT_SHOW, 2)
    else
        Lib.emitEvent(Event.FRONTSIGHT_NOT_SHOW, 2)
    end
end

function M:onOpen(reloadArg)
    self.bodySelect = false
    self:initFly(true)
end

function M:onReload(reloadArg)

end

function M:fetchToolBar(grid, key, width, height, dir, interval)
    interval = interval or 0
    local button
    local offsetX = grid:GetChildCount() * (width + 30) + interval
    local offsetY = grid:GetChildCount() * (height + 25)
    local event
    if key ~= "empty" and key ~= "del" then
        button = GUIWindowManager.instance:CreateGUIWindow1("Button", "btn" .. key)
        button:SetNormalImage(btnImageMap[key].image)
        button:SetPushedImage(btnImageMap[key].image)
        event = UIEvent.EventButtonClick
    else
        button = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "btn" .. key)
        button:SetImage(btnImageMap[key].image)
        event = UIEvent.EventWindowClick
    end
    if dir and dir == "col" then
        button:SetArea({ 0, 0 }, { 0, offsetY }, { 0, width }, { 0, height})
    else
        button:SetArea({ 0, offsetX }, { 0, 0 }, { 0, width }, { 0, height})
    end

    self:subscribe(button, event, function()
        local function operation()
            handle_mp_editor_command("esc")
            Lib.emitEvent(Event.EVENT_EMPTY_STATE)
            if (key == "empty" or key == "del") and self.bodySelect then
                self.bodySelect = false
            end
            if operationFunc[key] then
                operationFunc[key](self)
            end
            CGame.instance:onEditorDataReport(eventTracking[key], "")
            if key == "empty" then
                if Clientsetting.isKeyGuide("isNewAcc") then
                   Lib.emitEvent(Event.EVENT_NOVICE_GUIDE,8) 
                end
            end
        end
        operation()
    end)
    grid:AddChildWindow(button)
    button:SetVerticalAlignment(2)
    return button
end

function M:initUI()
    local grid = self:child("ToolBar-Bg")
    self:fetchToolBar(grid, "save",         64, 64, nil, 20)
    self:fetchToolBar(grid, "lastStep",     64, 64, nil, 0)
    self:fetchToolBar(grid, "nextStep",     64, 64, nil, -5)
    self:fetchToolBar(grid, "fill",         64, 64, nil, 43)
    self:fetchToolBar(grid, "copy",         64, 64, nil, 43)
    self:fetchToolBar(grid, "move",         64, 64, nil, 43)
    self:fetchToolBar(grid, "replace",      64, 64, nil, 43)
    self:fetchToolBar(grid, "chunk_del",    64, 64, nil, 43)


    local leftGrid = GUIWindowManager.instance:CreateGUIWindow1("Layout", "leftGrid")
    leftGrid:SetArea({0, 20}, { 0, 70}, {0, 74}, {0, 183})
    self._root:AddChildWindow(leftGrid)
    self.m_del = self:fetchToolBar(leftGrid, "del", 74, 74, "col")
    self.m_empty = self:fetchToolBar(leftGrid, "empty", 74, 74, "col")

end
return M