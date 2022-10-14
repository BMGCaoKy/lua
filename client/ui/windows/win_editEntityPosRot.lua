-- 编辑UI
M.NotDialogWnd = true

local STATIC_MODEL = "blank"
local STATIC_REPLACE_MODEL = "blank"
local PLUGIN = Me:cfg().plugin
local STATIC_IMC = {x = 1, y = 1, z = 1, ry = 30, rp = 30, rr = 30}

local IS_OPEN = false

local bm = Blockman.instance
local curWorld = World.CurWorld

local function getObj(objID)
    if not objID then
        return false
    end
    local object = curWorld:getObject(objID)
    if not object or not object:isValid() then
        return false
    end
    return object
end

local function resetChildProp(self)
    self.model = PLUGIN .. "/" .. STATIC_MODEL
    self.replaceModel = PLUGIN .. "/" .. STATIC_REPLACE_MODEL
    self.curEditObjectId = nil
    self.curEditObjectData = {x = 0, y = 0, z = 0, ry = 0, rp = 0, rr = 0}
end

local function toKeep2DecimalPlaces(num)
    return math.floor(num * 100) / 100
end

local function updateChildProp(self, objID)
    local object = getObj(objID)
    if not object then
        return
    end
    object.onGround = true
    local objPos = object:getPosition()
    self.curEditObjectId = objID
    self.curEditObjectData = {
        x = toKeep2DecimalPlaces(objPos.x),
        y = toKeep2DecimalPlaces(objPos.y),
        z = toKeep2DecimalPlaces(objPos.z),
        ry = object:getRotationYaw(),
        rp = object:getRotationPitch(),
        rr = object:getRotationRoll()
    }
end

function M:init()
    WinBase.init(self, "EditEntityPosRot.json", true)
    self.base = self._root

    self:initChild()
    self:initEvent()
end

function M:initChild()
    self.new = self:child("EditEntityPosRot-new")
    self.newInput = self:child("EditEntityPosRot-new_input")
    self.newInput:SetProperty("MaxTextLength", 200)
    self.newInput:SetProperty("Text", STATIC_MODEL)

    self.save = self:child("EditEntityPosRot-save")
    self.del = self:child("EditEntityPosRot-del")

    self.add_x = self:child("EditEntityPosRot-add_x")
    self.sub_x = self:child("EditEntityPosRot-sub_x")
    self.set_x = self:child("EditEntityPosRot-set_x")
    self.set_input_x = self:child("EditEntityPosRot-set_input_x")

    self.add_y = self:child("EditEntityPosRot-add_y")
    self.sub_y = self:child("EditEntityPosRot-sub_y")
    self.set_y = self:child("EditEntityPosRot-set_y")
    self.set_input_y = self:child("EditEntityPosRot-set_input_y")

    self.add_z = self:child("EditEntityPosRot-add_z")
    self.sub_z = self:child("EditEntityPosRot-sub_z")
    self.set_z = self:child("EditEntityPosRot-set_z")
    self.set_input_z = self:child("EditEntityPosRot-set_input_z")

    self.add_ry = self:child("EditEntityPosRot-add_ry")
    self.sub_ry = self:child("EditEntityPosRot-sub_ry")
    self.set_ry = self:child("EditEntityPosRot-set_ry")
    self.set_input_ry = self:child("EditEntityPosRot-set_input_ry")

    self.add_rp = self:child("EditEntityPosRot-add_rp")
    self.sub_rp = self:child("EditEntityPosRot-sub_rp")
    self.set_rp = self:child("EditEntityPosRot-set_rp")
    self.set_input_rp = self:child("EditEntityPosRot-set_input_rp")

    self.add_rr = self:child("EditEntityPosRot-add_rr")
    self.sub_rr = self:child("EditEntityPosRot-sub_rr")
    self.set_rr = self:child("EditEntityPosRot-set_rr")
    self.set_input_rr = self:child("EditEntityPosRot-set_input_rr")


    self.replace = self:child("EditEntityPosRot-replace")
    self.replaceInput = self:child("EditEntityPosRot-replace_input")
    self.replaceInput:SetProperty("MaxTextLength", 200)
    self.replaceInput:SetProperty("Text", STATIC_REPLACE_MODEL)

    self.redo = self:child("EditEntityPosRot-redo")
    self.undo = self:child("EditEntityPosRot-undo")
    self.close = self:child("EditEntityPosRot-close")

    self.tipTextBox = self:child("EditEntityPosRot-tip_text_box")

    self.curEditMsgText = self:child("EditEntityPosRot-cur_edit_msg_text")

    resetChildProp(self)

    self.allCellMap = {
        add_x = self.add_x,
        sub_x = self.sub_x,
        set_x = self.set_x,
        set_input_x = self.set_input_x,
        add_y = self.add_y,
        sub_y = self.sub_y,
        set_y = self.set_y,
        set_input_y = self.set_input_y,
        add_z = self.add_z,
        sub_z = self.sub_z,
        set_z = self.set_z,
        set_input_z = self.set_input_z,
        add_ry = self.add_ry,
        sub_ry = self.sub_ry,
        set_ry = self.set_ry,
        set_input_ry = self.set_input_ry,
        add_rp = self.add_rp,
        sub_rp = self.sub_rp,
        set_rp = self.set_rp,
        set_input_rp = self.set_input_rp,
        add_rr = self.add_rr,
        sub_rr = self.sub_rr,
        set_rr = self.set_rr,
        set_input_rr = self.set_input_rr
    }
    self.touchListenerContent = {}
end

local function createOrReplaceCallback(self, params)
    local callbackObjID = params.objID
    if not callbackObjID then
        return
    end
    if getObj(callbackObjID) then
        self:onReload(callbackObjID)
    else
        if self.createOrReplaceCallbackEvent then
            self.createOrReplaceCallbackEvent()
        end
        self.createOrReplaceCallbackEvent = Lib.subscribeEvent(Event.EVENT_ENTITY_SPAWN, function(objID)
            if callbackObjID ~= objID then
                return
            end
            self:onReload(callbackObjID)
        end)
    end
end

function M:newObject(fullName)
    Me:sendPacket({
        pid = "GM",
        typ = "GMCallEditEntity",
        params = {
            key = "NewEditObject",
            playerId = Me.objID,
            fullName = fullName
        }
    }, function(params)
        createOrReplaceCallback(self, params)
    end)
end

function M:replaceObject(fullName, targetObjId)
    local object = getObj(targetObjId)
    if not object then
        return
    end
    Me:sendPacket({
        pid = "GM",
        typ = "GMCallEditEntity",
        params = {
            key = "ReplaceEditObject",
            targetObjId = targetObjId,
            playerId = Me.objID,
            fullName = fullName
        }
    }, function(params)
        createOrReplaceCallback(self, params)
    end)
end

local function redoEdit()
    Me:sendPacket({
        pid = "GM",
        typ = "GMCallEditEntity",
        params = {
            key = "RedoEdit",
            playerId = Me.objID,
        }
    })
end

local function undoEdit()
    Me:sendPacket({
        pid = "GM",
        typ = "GMCallEditEntity",
        params = {
            key = "UndoEdit",
            playerId = Me.objID,
        }
    })
end

local function resetEditQueue()
    Me:sendPacket({
        pid = "GM",
        typ = "GMCallEditEntity",
        params = {
            key = "ResetEditQueue",
            playerId = Me.objID,
        }
    })
end

local function saveInMap(objID)
    local object = getObj(objID)
    if not object then
        return
    end
    Me:sendPacket({
        pid = "GM",
        typ = "GMCallEditEntity",
        params = {
            key = "SaveEditObject",
            objId = object.objID,
            playerId = Me.objID,
            params = {
                pos = object:getPosition(),
                yaw = object:getRotationYaw(),
                pitch = object:getRotationPitch(),
                roll = object:getRotationRoll()
            }
        }
    })
end

local function delInMap(objID)
    local object = getObj(objID)
    if not object then
        return
    end
    Me:sendPacket({
        pid = "GM",
        typ = "GMCallEditEntity",
        params = {
            key = "RemoveEditObject",
            playerId = Me.objID,
            objId = object.objID
        }
    })
end

local function syncObject(objID)
    local object = getObj(objID)
    if not object then
        return
    end
    Me:sendPacket({
        pid = "GM",
        typ = "GMCallEditEntity",
        params = {
            key = "SyncEditObject",
            objId = object.objID,
            playerId = Me.objID,
            params = {
                pos = object:getPosition(),
                yaw = object:getRotationYaw(),
                pitch = object:getRotationPitch(),
                roll = object:getRotationRoll()
            }
        }
    })
end
local updateBoxText
local function updateChildData(self, objID)
    local curEditObjectData = self.curEditObjectData
    self.newInput:SetProperty("Text", self.laseNewInput or STATIC_MODEL)
    self.model = PLUGIN .. "/" .. (self.laseNewInput or STATIC_MODEL)
    self.set_input_x:SetText(curEditObjectData.x)
    self.set_input_y:SetText(curEditObjectData.y)
    self.set_input_z:SetText(curEditObjectData.z)
    self.set_input_ry:SetText(curEditObjectData.ry)
    self.set_input_rp:SetText(curEditObjectData.rp)
    self.set_input_rr:SetText(curEditObjectData.rr)
    self.replaceInput:SetProperty("Text", self.laseReplaceInput or STATIC_REPLACE_MODEL)
    self.replaceModel = PLUGIN .. "/" .. (self.laseReplaceInput or STATIC_REPLACE_MODEL)

    updateBoxText(self, objID)
end

local function updateObjectData(self, objID)
    local object = getObj(objID)
    if not object then
        return
    end
    local curEditObjectData = self.curEditObjectData
    object:setPosition({x = curEditObjectData.x, y = curEditObjectData.y, z = curEditObjectData.z})
    object:setRotation(curEditObjectData.ry, curEditObjectData.rp, curEditObjectData.rr)
    object:setBodyYaw(curEditObjectData.ry)
end

updateBoxText = function(self, objID)
    local object = getObj(objID)
    if not object then
        return
    end
    local bbox = object:getBoundingBox() or {}
    local min = bbox[2] or {x = 0, y = 0, z = 0}
    local max = bbox[3] or {x = 0, y = 0, z = 0}
    self.tipTextBox:SetText(" min:{ x = " .. toKeep2DecimalPlaces(min.x)
            .. ", y = " .. toKeep2DecimalPlaces(min.y)
            .. ", z = " .. toKeep2DecimalPlaces(min.z)
            .."} \n max:{ x = " .. toKeep2DecimalPlaces(max.x)
            .. ", y = " .. toKeep2DecimalPlaces(max.y)
            .. ", z = " .. toKeep2DecimalPlaces(max.z) .."}")
            
    self.curEditMsgText:SetText(" fullName = " .. object:cfg().fullName
        .. "\n name = " .. object.name
        .. "\n objID = " .. objID
        )
end

function M:initEvent()
    self:subscribe(self.new, UIEvent.EventButtonClick, function() -- 新建
        self:newObject(self.model)
    end)
    self:subscribe(self.newInput, UIEvent.EventEditTextInput, function() -- 输入模板
        local modText = self.newInput:GetPropertyString("Text","")
        if not modText or modText == "" then
            return
        end
        self.newInput:SetProperty("Text", modText)
        self.laseNewInput = modText
        self.model = PLUGIN .. "/" .. modText
    end)

    self:subscribe(self.save, UIEvent.EventButtonClick, function() -- 保存进map
        saveInMap(self.curEditObjectId)
    end)
    self:subscribe(self.del, UIEvent.EventButtonClick, function() -- 从map删除
        delInMap(self.curEditObjectId)
    end)

    local allCellMap = self.allCellMap
    for plu, modify in pairs(STATIC_IMC) do
        local inputCell = allCellMap["set_input_" .. plu]
        self:subscribe(allCellMap["add_" .. plu], UIEvent.EventButtonClick, function() -- add
            self.curEditObjectData[plu] = self.curEditObjectData[plu] + modify
            inputCell:SetText(self.curEditObjectData[plu])
            updateObjectData(self, self.curEditObjectId)
            updateBoxText(self, self.curEditObjectId)
        end)
        self:subscribe(allCellMap["sub_" .. plu], UIEvent.EventButtonClick, function() -- sub
            self.curEditObjectData[plu] = self.curEditObjectData[plu] - modify
            inputCell:SetText(self.curEditObjectData[plu])
            updateObjectData(self, self.curEditObjectId)
            updateBoxText(self, self.curEditObjectId)
        end)
        self:subscribe(allCellMap["set_" .. plu], UIEvent.EventButtonClick, function() -- set
            self.curEditObjectData[plu] = tonumber(inputCell:GetPropertyString("Text",""))
            updateObjectData(self, self.curEditObjectId)
            updateBoxText(self, self.curEditObjectId)
        end)
        self:subscribe(inputCell, UIEvent.EventEditTextInput, function() -- set_input
            local modText = inputCell:GetPropertyString("Text","")
            if not modText or modText == "" then
                return
            end
            inputCell:SetProperty("Text", modText)
        end)
    end

    self:subscribe(self.replace, UIEvent.EventButtonClick, function() -- 替换
        if not self.curEditObjectId then
            return
        end
        self:replaceObject(self.replaceModel, self.curEditObjectId)
        self.curEditObjectId = nil
    end)
    self:subscribe(self.replaceInput, UIEvent.EventEditTextInput, function() -- 输入模板
        local modText = self.replaceInput:GetPropertyString("Text","")
        if not modText or modText == "" then
            return
        end
        self.replaceInput:SetProperty("Text", modText)
        self.laseReplaceInput = modText
        self.replaceModel = PLUGIN .. "/" .. modText
    end)

    self:subscribe(self.redo, UIEvent.EventButtonClick, function() -- redo
        redoEdit()
    end)
    self:subscribe(self.undo, UIEvent.EventButtonClick, function() -- undo
        undoEdit()
    end)
    self:subscribe(self.close, UIEvent.EventButtonClick, function() -- close
        UI:closeWnd(self)
        resetEditQueue()
    end)
end

local function showBBox(flag)
    local debugDraw = DebugDraw.instance
    debugDraw:setEnabled(flag)
    -- debugDraw:setEditVolumeBoxEnabled(flag)
    debugDraw:setDrawColliderAABBEnabled(flag)
    debugDraw:setDrawColliderEnabled(flag)
    debugDraw:setDrawAuraEnabled(flag)
    debugDraw:setDrawRegionEnabled(flag)
end

local function resetObjRenderBoxEnable(objID, enable)
    local object = getObj(objID)
    if not object then
        return
    end
    -- -- Test Code
    -- local buffCfg = Me:cfg().plugin .. "/isStatic_prop_buff"
    -- if enable then
    --     object:addClientBuff(buffCfg)
    -- else
    --     local buff = object:getTypeBuff("fullName", buffCfg)
    --     if buff then
    --         object:removeBuff(buff)
    --     end
    -- end

    Me:sendPacket({
        pid = "GM",
        typ = "GMCallEditEntity",
        params = {
            key = "UpdateEditObject",
            objId = object.objID,
            playerId = Me.objID,
            isEdit = enable
        }
    })

    -- bm:setRenderBoxEnable(enable)
    showBBox(enable)
    object:setRenderBox(enable)
end

local function stopTouchListener(self)
    local touchListenerContent = self.touchListenerContent
    for i, v in pairs(touchListenerContent or {}) do
        v()
    end
    self.touchListenerContent = {}
end

local function startTouchListener(self)
    stopTouchListener(self)
    local tlco = self.touchListenerContent
    local touchTick = 0
    tlco.beginTouchEventListener = Lib.subscribeEvent(Event.EVENT_SCENE_TOUCH_BEGIN, function(x, y)
        touchTick = curWorld:getTickCount()
    end)
    tlco.endTouchEventListener = Lib.subscribeEvent(Event.EVENT_SCENE_TOUCH_END, function(x, y)
        if IS_OPEN and bm:getHitInfo().type ~= "ENTITY" and curWorld:getTickCount() - touchTick <= 2 then
            -- UI:closeWnd(self)
            -- resetEditQueue()
        end
    end)
end

local function openEvent(self, objID)
    IS_OPEN = true
    resetObjRenderBoxEnable(objID, true)
    updateChildProp(self, objID)

    updateChildData(self, objID)
    startTouchListener(self)
end

function M:onOpen(objID)
    openEvent(self, objID)
end

local function reloadEvent(self, objID)
    if objID == self.curEditObjectId then
        return
    end
    saveInMap(self.curEditObjectId)
    syncObject(self.curEditObjectId)
    resetObjRenderBoxEnable(self.curEditObjectId, false)

    openEvent(self, objID)
end

function M:onReload(objID)
    reloadEvent(self, objID)
end

local function closeEvent(self)
    IS_OPEN = false
    saveInMap(self.curEditObjectId)
    syncObject(self.curEditObjectId)
    resetObjRenderBoxEnable(self.curEditObjectId, false)

    resetChildProp(self)
    stopTouchListener(self)
end

function M:onClose()
    closeEvent(self)
end