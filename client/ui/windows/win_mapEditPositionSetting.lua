local state = require "editor.state"
local data_state = require "editor.dataState"
local entity_obj = require "editor.entity_obj"
local global_setting = require "editor.setting.global_setting"
local stageSetting = require "editor.stage_setting"
local utils = require "editor.utils"

local player_pos = nil
local player_yaw = nil
local player_pitch = nil
local bm = Blockman.Instance()
local bodyTrunSpeed

local eumOp = {
    birthPoint          = 1,
    rebirthPoint        = 2,
    teamBirthPoint      = 3,
    teamRebirthPoint    = 4,
    teamBedPoint        = 5,
    teamEggPoint        = 6,
    waitPoint           = 7,
    endPoint            = 8,
}

local enumText = {
    "win.map.global.setting.team.born.point",
    "win.map.global.setting.team.rebirth.point",
    "win.map.global.setting.team.born.point",
    "win.map.global.setting.team.rebirth.point",
    "win.map.global.setting.team.add.bedoregg.point",
    "win.map.global.setting.team.add.bedoregg.point",
    "win.map.global.setting.team.add.waiting.point",
    "win.map.global.setting.add.endPoint"
}
local teamIcons = {
    ["BLUE"] = "image/icon/team_blue.png",
    ["RED"] = "image/icon/team_red.png",
    ["YELLOW"] = "image/icon/team_yellow.png",
    ["GREEN"] = "image/icon/team_green.png",
}

local enumActor = {
    "myplugin/door_entity_setPos_birth",
    "myplugin/door_entity_setPos_rebirth",
    "myplugin/door_entity_setPos_birth",
    "myplugin/door_entity_setPos_rebirth",
    "myplugin/bed",
    "myplugin/egg",
    "myplugin/door_entity_wait_point",
    "myplugin/endPoint",
}

local function getTeamColor(teamId)
    if teamId then
        local teamMsg = global_setting:getTeamMsg()
        local data = teamMsg[teamId]
        return data and data.color or nil
    end
end

local function delEntity(self)
    if self.entity then
        local id = entity_obj:getIdByEntity(self.entity)
        entity_obj:delEntity(id)
        self.entity = nil
    end
end

function M:showEntityHeadPic(opType, color)
    if not color or not self.entity or opType == 5 or opType == 6 then
        return
    end
    color = string.upper(color)
    local picPath = teamIcons[color] or "image/icon/bubbling.png"
    self.entity:showHeadPic(picPath)
end

function M:changeCamera()
	local bm = Blockman.instance
	local cameraInfo = bm:getCameraInfo(4)
	local saveCameraData = {
		viewCfg = cameraInfo.viewCfg,
	}
	local viewCfg = {
		lockBodyRotation = false
	}
	if viewCfg then
		bm:changeCameraCfg(viewCfg, 4)
	end

	return function()
		local personView = bm:getCurrPersonView()
		bm:changeCameraCfg(saveCameraData.viewCfg, personView)
	end
end


local function rePlace(self)
    self.recoCamera = self:changeCamera()
    if self.entityId then
        local entity = entity_obj:getEntityById(self.entityId)
        if entity then
            bodyTrunSpeed = entity:getBodyTurnSpeed()
            entity:setBodyTurnSpeed(0)
        end
    end
    local function place(self)
        self:setPanel(true)
        self:controlUi(self.opType, self.txt, true)
        self:showUi(true)
        --self.entity:setRenderBox(false)
        Lib.emitEvent(Event.EVENT_OPEN_INVENTORY, false)
        UI:closeWnd("mapEditToolbar")
        Lib.emitEvent(Event.EVENT_ENTITY_CONTROL, self.entity)
    end
    place(self)
end

local idx = 1
local entityModel = {"myplugin/egg", "myplugin/bed"}

local function changeModel(self)
    if self.isShowPanel then
        return
    end
    self.entity = entity_obj:getEntityByDeriveType(5, 1, self.data.teamId)
    local pos = self.entity:getPosition()
    delEntity(self)
    local data = self.data or {}
    if string.find(data.entity, "_") then
        data.entity = string.sub(data.entity, 0, string.find(data.entity, "_") - 1)
    end
    if data.entity == entityModel[1] then
        self.data.entity = entityModel[2]
    else
        self.data.entity = entityModel[1]
    end

    local winType = self.opType
    if self.opType == 6 then
        winType = 5
    end
    local teamColor = self.data.color or getTeamColor(self.data.teamId)
    local color = "_" .. string.lower(teamColor)
    local tb = {cfg = self.data.entity .. color, derive = 
            {pointEntity = {idx = self.data.idx, teamId = self.data.teamId or 0, type = "pointEntity", entity = self.data.entity, typePoint = winType, color = teamColor}}}
    local id  = entity_obj:addEntity(pos, tb)
    self.entity = entity_obj:getEntityById(id)
    Lib.emitEvent(Event.EVENT_SETTING_ENTITY_MODEL, self.data.entity)
    self:openControlWnd(self.entity.objID, self.opType)
end

local function openGlobal(self)
    UI:closeWnd(self)
    Lib.emitEvent(Event.EVENT_HIDE_GLOBAL_SETTING, false, self.opType, self.data.teamId)
end

local function del(self)
    UI:closeWnd(self)
    Lib.emitEvent(Event.EVENT_HIDE_GLOBAL_SETTING, false, self.opType, self.data.teamId)
    Lib.emitEvent(Event.EVENT_POINT_DEL, self.opType, self.data.idx)
end

local uiShowList = 
            {
			    {
				    uiName = "setPosition", 
				    backFunc = rePlace
			    },
			    {
				    uiName = "changMonsterModle", 
				    backFunc = openGlobal --换模型暂时去页面
			    },			
                {
				    uiName = "setting", 
				    backFunc = openGlobal
			    },			
                {
				    uiName = "delete", 
				    backFunc = del
			    }
		    }

local function setPlayerStage(map)
    if not map then
        return
    end
    local index = stageSetting:getStageIndexByMap(map)
    local curIndex = stageSetting.curStage
    if index and index ~= curIndex then
        CGame.instance:onEditorDataReport("view_point_stage_jump", "")
        stageSetting:switchStage(index)
    end
end

local function setPlayerPos(entity, pos, yaw, pitch)
    setPlayerStage(pos.map)
    entity:setPosition(pos)
    entity:getRotationYaw(yaw)
    entity:getRotationPitch(pitch)
end

local function backToEditor(self, dontBack)
    local mainPlayer = bm:getEditorPlayer()
    Player.CurPlayer = mainPlayer
    bm:setMainPlayer(mainPlayer)
	if not dontBack then
		setPlayerPos(Player.CurPlayer, player_pos, player_yaw, player_pitch)
	else
		setPlayerPos(Player.CurPlayer, self.data.pos or player_pos, self.data.ry or 0, self.data.ry or 0)
	end
   
end

local function entityRotation(self, angle)
    self.entity:setRotationYaw(self.entity:getRotationYaw() + angle)
    self.entity:setBodyYaw(self.entity:getBodyYaw() + angle)
end

function M:init()
    WinBase.init(self, "teamPos_edit.json")
    self.close= self:child("Pos-Close")
    self.confirmWnd = self:child("Pos-confirm")
    self.rtRotateWnd = self:child("Pos-Right")
    self.ltRotateWnd = self:child("Pos-Left")
    self.m_msg = self:child("Pos-MsgBg-Msg")
    self.m_msgBg = self:child("Pos-MsgBg")

    self:subscribe(self.close, UIEvent.EventButtonClick, function()
        if not self.isShowPanel then
            self:controlPanelWnd(not self.isShowPanel)
            backToEditor(self, true)
            handle_mp_editor_command("esc")
            state:set_focus(nil)
            Lib.emitEvent(Event.EVENT_OPEN_EDIT_MAIN)
            if not next(self.data.pos or {}) then
                setPlayerPos(self.entity, player_pos, player_yaw, player_pitch)
            else
                setPlayerPos(self.entity, self.data.pos, self.data.ry, self.data.ry)
            end
            EditorModule:emitEvent("leaveEntityPosSetting")
        else
            UI:closeWnd(self)
            delEntity(self)
            Lib.emitEvent(Event.EVENT_HIDE_GLOBAL_SETTING, false, self.opType, self.data.teamId)
        end
    end)

    self:subscribe(self.confirmWnd, UIEvent.EventButtonClick, function()
        local player = Player.CurPlayer
        local position = player:getPosition()
        local hasBlock = false
        local pos = {y = math.floor(position.y)}
		for x= math.floor(position.x - 0.4), math.floor(position.x + 0.4) do
			for z = math.floor(position.z - 0.4), math.floor(position.z + 0.4) do
                for i = 0, 1 do
                    pos.x = x
                    pos.z = z
                    pos.y = math.floor(position.y) + i
                    local block = World.CurMap:getBlock(pos)
                    hasBlock = hasBlock or block.fullName ~= "/air"
                end
            end
        end
       if not hasBlock or self.opType == eumOp.teamBedPoint or self.opType == eumOp.teamEggPoint then
            self:savePos()
            if not self.isShowPanel then
                self:controlPanelWnd(not self.isShowPanel)
                backToEditor(self)
                handle_mp_editor_command("esc")
                state:set_focus(nil)
                Lib.emitEvent(Event.EVENT_OPEN_EDIT_MAIN)
                if self.dontSaveData then
                    Lib.emitEvent(Event.EVENT_HIDE_GLOBAL_SETTING, false, self.opType, self.data.teamId)
                end
                EditorModule:emitEvent("leaveEntityPosSetting")
            else
                UI:closeWnd(self)
                Lib.emitEvent(Event.EVENT_HIDE_GLOBAL_SETTING, false, self.opType, self.data.teamId)
            end
        else
            Lib.emitEvent(Event.EVENT_TOAST_TIP, Lang:toText("cant_place_block"), 20)
        end
    end)

    self:subscribe(self.rtRotateWnd, UIEvent.EventButtonClick, function()
        entityRotation(self, 90)
        local id = entity_obj:getIdByEntity(self.entity)
        entity_obj:Cmd("setRotation", id)
    end)

    self:subscribe(self.ltRotateWnd, UIEvent.EventButtonClick, function()
        entityRotation(self, -90)
        local id = entity_obj:getIdByEntity(self.entity)
        entity_obj:Cmd("setRotation", id)
    end)

end

function M:saveData(pos, ry)
    if self.opType == eumOp.birthPoint then
        local tmpPos = global_setting:getStartPos()
        tmpPos[self.data.idx] = pos
        tmpPos[self.data.idx].map = data_state.now_map_name
        global_setting:saveStartPos(tmpPos, true)
    elseif self.opType == eumOp.rebirthPoint then
        local tmpPos = global_setting:getRevivePos()
        tmpPos[self.data.idx] = pos
        tmpPos[self.data.idx].map = data_state.now_map_name
        global_setting:saveRevivePos(tmpPos, true)
    elseif self.opType == eumOp.teamBirthPoint then
        local teamData = global_setting:getTeamMsg()
        local teamId = self.data.teamId
        teamData[teamId].startPos = teamData[teamId].startPos or {}
        teamData[teamId].startPos[1] = pos
        teamData[teamId].startPos[1].map = data_state.now_map_name
        global_setting:saveEditTeamMsg(teamData, true)
    elseif self.opType == eumOp.teamRebirthPoint then
        local teamData = global_setting:getTeamMsg()
        local teamId = self.data.teamId
        teamData[teamId].rebirthPos = teamData[teamId].rebirthPos or {}
        teamData[teamId].rebirthPos[1] = pos
        teamData[teamId].rebirthPos[1].map = data_state.now_map_name
        global_setting:saveEditTeamMsg(teamData, true)
    elseif self.opType == eumOp.teamBedPoint or self.opType == eumOp.teamEggPoint then
        local teamData = global_setting:getTeamMsg()
        local teamId = self.data.teamId
        teamData[teamId].bed.pos = pos
        teamData[teamId].bed.ry = ry
        teamData[teamId].bed.pos.map = data_state.now_map_name
        global_setting:saveEditTeamMsg(teamData, true)
    elseif self.opType == eumOp.waitPoint then
        local initPos = global_setting:getInitPos()
        initPos = pos
        initPos.map = data_state.now_map_name
        global_setting:saveInitPos(initPos, true)
    elseif self.opType == eumOp.endPoint then
        utils:setEndPointPos(pos)
    end
end

function M:controlPanelWnd(isShow)
    self:setPanel(not isShow)
    self:controlUi(self.opType, self.txt, isShow)
    self:showUi(not isShow)
    --self.entity:setRenderBox(isShow)
    if isShow then
        self:openControlWnd(self.entity.objID, self.opType)
    else
        UI:closeWnd("mapEditEntityPosUI")
    end
    
end

function M:openControlWnd(objID, winType)
    local planelShowList = Lib.copy(uiShowList)
    if winType ~= 5 and winType ~= 6 then
        table.remove(planelShowList, 2)
    end
    World.Timer(2, function()
        Lib.emitEvent(Event.EVENT_ENTITY_SETTING_POINT, { 
		objID = objID, 
		uiShowList = planelShowList,
        argc = self
	})
        return false
    end)
    
end

local emitFuncList = {
    rePlace = rePlace,
    changeModel = openGlobal,--换模型暂时去页面
    openGlobal = openGlobal,
    del = del
}
function M:emitEvent(event, entityDerive)
    local funct = emitFuncList[event]
    local pointEntity = entityDerive.pointEntity
    self.entity = entity_obj:getEntityByDeriveType(pointEntity.typePoint, pointEntity.idx, pointEntity.teamId)
    local entityId = entity_obj:getIdByEntity(self.entity)
    self.entityId = entityId
	local pos = entity_obj:getPosById(entityId)
    self.data = {idx = pointEntity.idx, teamId = pointEntity.teamId, pos = pos, entity = pointEntity.entity, color = pointEntity.color}
    if funct then
        funct(self)
    end
end

function M:controlUi(op, text, isShowPanel) --op==1个人出生点,op==2复活点, op==3队伍出生点,op==4队伍复活点,op==5龙蛋、床
    if text == "" then
        return
    end
    local width =  self.m_msg:GetFont():GetTextExtent(text or "", 1.0)
    if width > 500 then
        self.m_msgBg:SetWidth({0 , 500 + 114 })
        self.m_msg:SetWidth({0 , 500})
   else
        self.m_msgBg:SetWidth({0 , width + 114 })
        self.m_msg:SetWidth({0 , width})
   end
   self.m_msg:setTextAutolinefeed(text or "")
end

function M:showUi(isShow)
    self.close:SetVisible(isShow)
    self.confirmWnd:SetVisible(isShow)
    local show = isShow and (self.opType == 5 or self.opType == 6)
    self.rtRotateWnd:SetVisible(show)
    self.ltRotateWnd:SetVisible(show)
    self.m_msgBg:SetVisible(isShow)
    data_state.is_can_place = not isShow
end

function M:savePos()
    local player = Player.CurPlayer
    local pos = player:getPosition()
    local ry = player:getBodyYaw()
    local id = entity_obj:getIdByEntity(self.entity)
    entity_obj:setPosById(id, {pos = pos, ry = ry})
	self.data.pos = pos
	self.data.ry = ry
    Lib.emitEvent(Event.EVENT_SAVE_POS, {entity = self.data.entity, pos = pos, ry = ry, data = self.data and self.data.idx, isShowPanel = self.isShowPanel}, self.opType)
    --if not self.isShowPanel then
    if not self.dontSaveData then
        self:saveData(pos, ry)
    end
    --end
end

local function checkIsEndPoint(self)
    local fullName = "myplugin/endPoint"
    local entity
    if utils:isPlaceEndPoint() and self.opType == 8 then
        entity = entity_obj:getEntityByFullName(fullName)
    end
    return entity
end

function M:createEntity(opType, data, isShowPanel)
    
    data = data and Lib.copy(data) or {}
    local pos = data.pos
    local ry = data.ry or 0
    if not next(data.pos or {}) then
        pos = Player.CurPlayer:getPosition()
    end
    local winType = opType
    if opType == 6 then
        winType = 5
    end
    self.entity = entity_obj:getEntityByDeriveType(winType, data.idx, data.teamId) or checkIsEndPoint(self)
    if self.entity then
        local fullName = string.gsub(self.entity:cfg().fullName, "_.*", "")
        local entityFullName = data.entity
        if data.color then
            entityFullName = entityFullName .. "_" .. string.lower(data.color)
        end
        if entityFullName ~= fullName then
            delEntity(self)
        end
    end
    if not self.entity then
        local color = data.color and string.lower(data.color) or nil
        color = color and ("_" .. color) or ""
        local entity
        if opType == 5 then
            entity = data.entity .. color
        else
            entity = enumActor[opType] .. color
        end
        local tb = {cfg = entity, entity = data.entity, derive = 
              {pointEntity = {idx = data.idx, teamId = data.teamId or 0, type = "pointEntity", typePoint = winType, color = data.color}}}
        if pos.map and pos.map ~= World.CurMap.name then
            setPlayerStage(pos.map)
        end

        if opType == 8 then
            tb.derive = {}
        end

        local createPos = Lib.copy(pos)
        createPos.ry = ry
        local id
        if opType == 8 then
            id = entity_obj:rulerArithmeticAdd(entity, pos)
        else
            id = entity_obj:addEntity(createPos, tb)
        end
        self.entity = entity_obj:getEntityById(id)
    end
    self:showEntityHeadPic(opType, data.tempColor)
    local entityId = entity_obj:getIdByEntity(self.entity)
    self.entityId = entityId
    if isShowPanel then
        setPlayerPos(self.entity, pos, data.ry or 0, data.ry or 0)
        rePlace(self)
    else
        if opType == 8 then
            return
        end
        self:controlPanelWnd(not isShowPanel)
    end
end

function M:setPlayerYPos(yIncrement)
	local player = Player.CurPlayer
	local pos = player:getPosition()
	pos.y = pos.y + (yIncrement)
	player:setPosition(pos)
end

function M:setPanel(isShowPanel)
    Blockman.instance.gameSettings.cameraYaw = Blockman.instance:viewerRenderYaw()
    Blockman.instance.gameSettings.cameraPitch = Blockman.instance:viewerRenderPitch() + Blockman.instance.gameSettings.cameraPitchCompensate
    local viewMode = EditorModule:getMoveControl():isThirdView() and 3 or 0
    Blockman.instance:setPersonView(viewMode)
    player_pos = Player.CurPlayer:getPosition()
    player_yaw = Player.CurPlayer:getRotationYaw()
    player_pitch = Player.CurPlayer:getRotationPitch() 
    if isShowPanel then
        EditorModule:emitEvent("enterEntityPosSetting")
        Blockman.Instance():saveMainPlayer(Player.CurPlayer)
	    --self:setPlayerYPos(-6)
    end  
end

function M:setPoint()
    local player = Player.CurPlayer
	if self.entity then
		local pos = self.entity:getPosition()
		local yaw = self.entity:getRotationYaw()
		local pitch = self.entity:getRotationPitch() 
		pos.map = self.entity.map.name
		setPlayerPos(player, pos, yaw, pitch)
	end
   
end

function M:onOpen(winType, data, isShowPanel, dontCreat, dontSaveData)
    self:setPanel(isShowPanel)

    self.opType = winType
    self.isShowPanel = isShowPanel
    self.dontSaveData = dontSaveData
    self.txt = Lang:toText(enumText[winType])
    self:controlUi(winType, "", isShowPanel)
    self:showUi(isShowPanel)
    if not dontCreat then
        self:createEntity(winType, data, isShowPanel)
        if not isShowPanel then
            self:setPoint()
        end
    end
    self.data = data
end

function M:onClose()
    if bodyTrunSpeed and self.entityId then
        local entity = entity_obj:getEntityById(self.entityId)
        if entity then
            entity:setBodyTurnSpeed(bodyTrunSpeed)
        end
    end
    bodyTrunSpeed = nil
    self.entityId = nil
    Blockman.instance:setPersonView(World.cfg.editrovViewMode or World.cfg.viewMode)
    data_state.is_can_place = true
    data_state.is_can_move = false
    Lib.emitEvent(Event.EVENT_OPEN_EDIT_MAIN)
    state:set_focus(nil)
    if self.isShowPanel then
        backToEditor(self)
        --self:setPlayerYPos(6)
    else
        setPlayerPos(Player.CurPlayer, player_pos, player_yaw, player_pitch)
    end
    if self.entity then
        --self.entity:setRenderBox(false)
    end
    if self.recoCamera then
        self.recoCamera()
        self.recoCamera = nil
    end
    handle_mp_editor_command("esc")
    EditorModule:emitEvent("leaveEntityPosSetting")
    --UI:closeWnd("mapEditEntityPosUI")
end

function M:onReload(reloadArg)

end

return M