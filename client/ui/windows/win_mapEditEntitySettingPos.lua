local engine = require "editor.engine"
local entity_obj = require "editor.entity_obj"
local data_state = require "editor.dataState"
local network_mgr = require "network_mgr"
local bm = Blockman.Instance()
local msg = nil
local bodyTrunSpeed = 0
local tipWin = nil
local playerPos = nil
local entityPos = nil

local function backToEditor()
    local pos = Player.CurPlayer:getPosition()
	local dx = Lib.v3cut(pos, entityPos)
	local pPos = Lib.v3add(playerPos, dx)
    local yaw = Player.CurPlayer:getRotationYaw()
    local pitch = Player.CurPlayer:getRotationPitch() 
    local mainPlayer = bm:getEditorPlayer()
    Player.CurPlayer = mainPlayer
    bm:setMainPlayer(mainPlayer)
    Player.CurPlayer:setPosition(pPos)
    --Player.CurPlayer:setRotationYaw(yaw)
    --Player.CurPlayer:setRotationPitch(pitch)
end

function M:entityRotation(angle)
	local entity = entity_obj:getEntityById(self._entityId)
    entity:setRotationYaw(entity:getRotationYaw() + angle)
	entity:setBodyYaw(entity:getBodyYaw() + angle)
end

function M:initTipMsg()
    self.text = self:child("Entity-Tool-text")
    self.textBG = self:child("Entity-Tool-Iconbg")
    self.text:SetText(Lang:toText("Win_AiControl_move_point_tips"))
    local width =  self.text:GetFont():GetTextExtent(Lang:toText("Win_AiControl_move_point_tips"),1.0)
    self.text:SetWidth({0 , width})
    self.textBG:SetWidth({0 , width + 150})
end

function M:init()
    WinBase.init(self, "entitySettingTools_edit.json")
   
    if Clientsetting.isKeyGuide("isRemind") then
        tipWin = GUIWindowManager.instance:LoadWindowFromJSON("entitySettingCrlTip_edit.json")

        local function CloseTipsWnd()
            if not Clientsetting.isKeyGuide("isRemind") then
                local retry = 1
                World.Timer(5, function() 
                    local respone = network_mgr:set_client_cache("isRemind", "1")
                    if respone.ok or retry > 2 then
						if respone.ok then
							Clientsetting.setGuideInfo("isRemind", false)
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
        local warning = tipWin:child("Entity-Ctr-Tips-Frame-Warning")
        local click = tipWin:child("Entity-Ctr-Tips-Frame-Click")

        warning:SetText(Lang:toText("EntitySetting_crl_tip_choiceText"))
        context:SetText(Lang:toText("EntitySetting_crl_tip_choice_context"))
        title:SetText(Lang:toText("composition.replenish.title"))
        if World.LangPrefix ~= "zh" then
            warning:SetArea({0.7, 0}, {0.857778, 0}, {0, 76}, {0, 24})
            click:SetArea({0.64, 0}, {0.83, 0}, {0, 270}, {0, 50})
        end
        local isRemind = false
        self:subscribe(click, UIEvent.EventWindowClick, function()
            local frameSelect = tipWin:child("Entity-Ctr-Tips-Frame-Select")
            if isRemind == false then
                frameSelect:SetChecked(true)
                isRemind = true
            else
                frameSelect:SetChecked(false)
                isRemind = false
            end
			Clientsetting.setlocalGuideInfo("isRemind", not isRemind)
        end)

        self:subscribe(tipWin:child("Entity-Ctr-Close"), UIEvent.EventButtonClick, function()
            CloseTipsWnd()
        end)

        self:subscribe(tipWin:child("Entity-Ctr-BG"), UIEvent.EventWindowClick, function()
            CloseTipsWnd()
        end)

        self:root():AddChildWindow(tipWin)
    end
    self:initTipMsg()
    self.tip = self:child("Entity-Tool-Tip")
    self:child("Entity-Tool-Tip-text"):SetText(Lang:toText("Edit_SavePanel_text"))
    self.tip:SetVisible(false)
	self:subscribe(self:child("Entity-Tool-Layout-Left"), UIEvent.EventButtonClick, function()
        self:entityRotation(-90)
        entity_obj:Cmd("setRotation", self._entityId)        
        engine:set_bModify(true)
    end)

	self:subscribe(self:child("Entity-Tool-Layout-Right"), UIEvent.EventButtonClick, function()
        self:entityRotation(90)
        entity_obj:Cmd("setRotation", self._entityId)                
        engine:set_bModify(true)
    end)

	self:subscribe(self:child("Entity-Tool-Layout-back"), UIEvent.EventButtonClick, function()
        Lib.emitEvent(Event.EVENT_OPEN_ENTITY_TIPS, self._entityId, Lang:toText("Edit_EntitySetting_tip_back_context"), 0, false, nil)
    end)

	self:subscribe(self:child("Entity-Tool-Layout-Exit"), UIEvent.EventButtonClick, function()
		Lib.emitEvent(Event.EVENT_OPEN_ENTITY_TIPS, self._entityId, Lang:toText("Edit_EntitySetting_tip_exit_context"), 1, true , Lang:toText("Edit_EntitySetting_tip_exit_secondLevelText"))
    end)

	self:subscribe(self:child("Entity-Tool-Layout-Save"), UIEvent.EventButtonClick, function()
        local count = 0
        UI:openWnd("savePanel" , false)
        World.Timer(1, function()
            if count > 0 then
                local entity = entity_obj:getEntityById(self._entityId)
				local data = {pos = entity:getPosition(), ry = entity:getBodyYaw()}
                entity_obj:setPosById(self._entityId, data)
                entity_obj:Cmd("setPos", self._entityId, data)
				local pos = entity_obj:getPosById(self._entityId)
				local deriveDate = entity_obj:getDataById(self._entityId)
				if deriveDate.aiData and deriveDate.aiData.route then
                    local aiData = deriveDate.aiData
                    local route = aiData.route
					if #route > 0 then
						route[1] = pos
						deriveDate.tmpAiData.route[1] = pos
						entity_obj:deriveSetData(self._entityId, "aiData", aiData)
						entity_obj:deriveSetData(self._entityId, "tmpAiData", deriveDate.tmpAiData)
					end
				end
                UI:closeWnd(self)
				UI:closeWnd("savePanel")
                Lib.emitEvent(Event.EVENT_ENTITY_SETTING, self._entityId, pos)
                return false
            end
            count = count + 1
            return true
        end)
    end)
end

function M:setPlayerYPos(yIncrement)
	local player = Player.CurPlayer
	local pos = player:getPosition()
	pos.y = pos.y + (yIncrement)
	player:setPosition(pos)
end

function M:onOpen(id)
    EditorModule:emitEvent("enterEntityPosSetting")
    EditorModule:getViewControl():changeViewCfg(-1, {
        lockBodyRotation = false
    })
	Blockman.instance.gameSettings.cameraYaw = Blockman.instance:viewerRenderYaw()
    Blockman.instance.gameSettings.cameraPitch = Blockman.instance:viewerRenderPitch() + Blockman.instance.gameSettings.cameraPitchCompensate
	Blockman.instance:setPersonView(World.cfg.viewMode)
	self:setPlayerYPos(-6)
	self._entityId = id
    self.entity = entity_obj:getEntityById(id)
	entityPos = self.entity:getPosition()
	playerPos = Player.CurPlayer:getPosition()
    bodyTrunSpeed = self.entity:getBodyTurnSpeed()
    self.entity:setBodyTurnSpeed(0)
    if Clientsetting.isKeyGuide("isRemind") and tipWin then
        self:root():AddChildWindow(tipWin)
    end
end

function M:onClose()
    data_state.is_can_place = true
    if self.entity then
        self.entity:setBodyTurnSpeed(bodyTrunSpeed)
		self.entity.isMoving = false
    end
    EditorModule:getViewControl():restore()
    backToEditor()
    Lib.emitEvent(Event.EVENT_OPEN_EDIT_MAIN)
	Blockman.instance:setPersonView(World.cfg.editrovViewMode or World.cfg.viewMode)
	self:setPlayerYPos(6)
	local pos = entity_obj:getPosById(self._entityId)
    Lib.emitEvent(Event.EVENT_ENTITY_SETTING, self._entityId, pos)
    EditorModule:emitEvent("leaveEntityPosSetting")
end

function M:onReload(reloadArg)

end

return M