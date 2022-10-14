local attachEntity   = L("attachEntity", nil)
local collider  = L("collider", nil)
local bm             = Blockman.Instance()
local lfs_attributes = lfs.attributes
local lfs_mkdir = lfs.mkdir
local io_open = io.open
local math_abs = math.abs
local math_rad = math.rad
local math_sin = math.sin
local math_cos = math.cos
local Lib_toJson = Lib.toJson
local Lib_read_json_file = Lib.read_json_file
local Lib_getPosDistanceSqr = Lib.getPosDistanceSqr
local Lib_copy = Lib.copy
local Lib_v3add = Lib.v3add
local Lib_v3sub = Lib.v3cut

local edit_mod = "edit_volume"
local tempMod = nil
local tipUI = nil

local ISOPEN = false

local editRedoStack = {}

local bmGameSettings = bm.gameSettings
local editFovCount = 0
local STATIC_FOV_IMC = 0.1
local DEFAULT_OFFSET = {x = 0, y = 0, z = 0}
local kCollideDeviation = 0.01
local VOLUME_TYPE = {
    BOX = "Box",
    VERTICALBOX = "VerticalBox",
    CAPSULE = "Capsule",
    BALL = "Ball",
    COMPOUND = "Compound",
    COMPOSITE = "Composite",
    NONE = "None"
}
local EDIT_TYPE = {
    BOX = "Box",
    SPHERE = "Sphere",
    CAPSULE = "Capsule",
    CYLINDER = "Cylinder",
    CONVEXHULL = "ConvexHull",
    COMPOUND = "Compound",
    EMPTY = "Empty"
}

local DefaultCollider = {}
DefaultCollider[EDIT_TYPE.BOX] = function(offset, extent)
    return {
        type = EDIT_TYPE.BOX,
        extent = extent or {x = 1, y = 1, z = 1},
        offset = offset or Lib_copy(DEFAULT_OFFSET)
    }
end
DefaultCollider[EDIT_TYPE.SPHERE] = function(offset, radius)
    return {
        type = EDIT_TYPE.SPHERE,
        radius = radius or 1,
        offset = offset or Lib_copy(DEFAULT_OFFSET)
    }
end
DefaultCollider[EDIT_TYPE.CAPSULE] = function(offset, radius, height)
    return {
        type = EDIT_TYPE.CAPSULE,
        radius = radius or 1,
        height = height or 2,
        offset = offset or Lib_copy(DEFAULT_OFFSET)
    }
end
DefaultCollider[EDIT_TYPE.CYLINDER] = function(offset, radius, height)
    return {
        type = EDIT_TYPE.CYLINDER,
        radius = radius or 1,
        height = height or 2,
        offset = offset or Lib_copy(DEFAULT_OFFSET)
    }
end
DefaultCollider[EDIT_TYPE.CONVEXHULL] = function(offset, vertices)
    return {
        type = EDIT_TYPE.CONVEXHULL,
        vertices = vertices or {
            {x = 0, y = 1, z = 0},
            {x = 2, y = 1, z = 0},
            {x = 1, y = 1, z = 1},
            {x = 1, y = 2, z = 1},
        },
        offset = offset or Lib_copy(DEFAULT_OFFSET)
    }
end

local editVolumeBuff = Me:cfg().editVolumeBuff or {}

local STATIC_GAME_PATH = Root.Instance():getGamePath()
local STATIC_SAVETOMAP_MOD = "map001"
local saveToMapMod = nil
local lastSaveToMapMod = nil
local canSaveCollisionBoxToMap = false
local hadSaveToMap = false

local isGlobalCDing = false
local globalCDTime = 40
local cdTimer = function()
    isGlobalCDing =  false
end
local function checkGlobalCD()
    return isGlobalCDing
end
local function startGlobalCD()
    isGlobalCDing = true
    World.Timer(globalCDTime, cdTimer)
end

local function changeCanSaveCollisionBoxToMap(self, status)
    canSaveCollisionBoxToMap = status
    if self.btnSaveToMap then
        self.btnSaveToMap:SetEnabled(not not status)
    end
end

local function checkCanSaveCollisionBoxToMap()
    return canSaveCollisionBoxToMap
end

local function changeHadSaveToMap(self, status, saveMod)
    lastSaveToMapMod = saveMod
    hadSaveToMap = status
    if self.btnSaveToMapUndo then
        self.btnSaveToMapUndo:SetEnabled(not not status)
    end
end

local function checkHadSaveToMap()
    return hadSaveToMap and lastSaveToMapMod or false
end

local function checkPathIsExist(path)
    return lfs_attributes(path, "mode")
end

local isDragMode = false
local needUpdateEditPoint = true
local defaultEditParams = {
    point = Vector3.new(),
    typ = EDIT_TYPE.BOX,
    index = -1,
    exData = {}
}
local editParams = Lib_copy(defaultEditParams)
local originalLockBodyRotation = false
local originalLockSlideScreen = false

local Volume2Collider = {}
Volume2Collider[VOLUME_TYPE.BOX] = function(params)
    if #params == 3 then
        return DefaultCollider[EDIT_TYPE.BOX]({x = 0, y = params[2], z = 0}, {x = params[1], y = params[2], z = params[3]})
    elseif #params == 6 then
        return DefaultCollider[EDIT_TYPE.BOX]({x = (params[4] + params[1])/2, y = math.min(params[5], params[2]), z = (params[6] + params[3])/2},
                {x = math_abs(params[4] - params[1]), y = math_abs(params[5] - params[2]), z = math_abs(params[6] - params[3])})
    end
end
Volume2Collider[VOLUME_TYPE.VERTICALBOX] = function(params)
    return Volume2Collider[VOLUME_TYPE.BOX](params)
end
Volume2Collider[VOLUME_TYPE.CAPSULE] = function(params)
    if #params >= 5 then
        return DefaultCollider[EDIT_TYPE.CAPSULE]({x = params[1], y = params[2], z = params[3]}, params[4], params[5])
    end
end
Volume2Collider[VOLUME_TYPE.BALL] = function(params)
    if #params >= 4 then
        return DefaultCollider[EDIT_TYPE.SPHERE]({x = params[1], y = params[2] - params[4], z = params[3]}, params[4])
    end
end
Volume2Collider[VOLUME_TYPE.COMPOUND] = function(params)
    return Volume2Collider[VOLUME_TYPE.COMPOSITE](params)
end
Volume2Collider[VOLUME_TYPE.COMPOSITE] = function(params)
    local tempChild = {}
    for _, child in pairs(params) do
        local temp = Volume2Collider[child.type](child.params)
        if #temp == 0 then
            tempChild[#tempChild+1] = temp
        else
            for _, c in pairs(temp) do
                tempChild[#tempChild+1] = c
            end
        end
    end
    return tempChild
end
Volume2Collider[VOLUME_TYPE.NONE] = function(volumeParams)
    -- nothing todo
end
local function boundingVolume2Collider(boundingVolume)
    if not next(boundingVolume) then
        return {}
    end
    local typ = boundingVolume.type
    local ret = Volume2Collider[typ](boundingVolume.params)
    if typ == VOLUME_TYPE.COMPOSITE or typ == VOLUME_TYPE.COMPOUND then
        return {type = EDIT_TYPE.COMPOUND, child = ret}
    end
    return ret
end
local function getEntityCollider(entity)
    local cfg = entity:cfg()
    local ret
    if cfg.collider then
        ret = Lib_copy(cfg.collider)
    elseif cfg.boundingVolume then
        ret = boundingVolume2Collider(cfg.boundingVolume)
    end
    if not ret then
        ret = {}
    end
    return ret
end

local function enterDragMode()
    if isDragMode then
        return
    end
    isDragMode = true
    needUpdateEditPoint = false
    originalLockBodyRotation = bmGameSettings:isLockBodyRotation()
    originalLockSlideScreen = bmGameSettings:isLockSlideScreen()
    bmGameSettings:setLockBodyRotation(true)
    bmGameSettings:setLockSlideScreen(true)
end

local function leaveDragMode()
    if not isDragMode then
        return
    end
    isDragMode = false
    needUpdateEditPoint = true
    bmGameSettings:setLockBodyRotation(originalLockBodyRotation)
    bmGameSettings:setLockSlideScreen(originalLockSlideScreen)
end

local function getHitBoxPointWithBox(hitPos, min, max)
    local ret = Lib_copy(DEFAULT_OFFSET)
    if math_abs(min.x - hitPos.x) < math_abs(max.x - hitPos.x) then
        ret.x = min.x
    else
        ret.x = max.x
    end
    if math_abs(min.y - hitPos.y) < math_abs(max.y - hitPos.y) then
        ret.y = min.y
    else
        ret.y = max.y
    end
    if math_abs(min.z - hitPos.z) < math_abs(max.z - hitPos.z) then
        ret.z = min.z
    else
        ret.z = max.z
    end
    return ret
end

local function isPosInBox(box, pos)
	local min, max = box.min, box.max
	return  pos.x >= min.x and pos.x <= max.x and 
			pos.y >= min.y and pos.y <= max.y and 
			pos.z >= min.z and pos.z <= max.z
end

local function getHitBoxPointWithParams(boxParams, exOffset, hitPos, entityPos, forceGet)
    local extent = boxParams.extent
    local offset = boxParams.offset
    local min = {
        x = entityPos.x + offset.x - extent.x / 2 + exOffset.x,
        y = entityPos.y + offset.y + exOffset.y,
        z = entityPos.z + offset.z - extent.z / 2 + exOffset.z
    }
    local max = {
        x = entityPos.x + offset.x + extent.x / 2 + exOffset.x,
        y = entityPos.y + offset.y + extent.y + exOffset.y,
        z = entityPos.z + offset.z + extent.z / 2 + exOffset.z
    }
    if forceGet then
        return getHitBoxPointWithBox(hitPos, min, max)
    else
        return isPosInBox({min = min, max = max}, hitPos) and getHitBoxPointWithBox(hitPos, min, max) or false
    end
end

local function getHitCapsulePointWithParams(capsuleParams, exOffset, hitPos, entityPos, forceGet)
    local radius = capsuleParams.radius
    local height = capsuleParams.height
    local offset = capsuleParams.offset
    local ret = {x = entityPos.x + offset.x + exOffset.x, y = entityPos.y + offset.y + exOffset.y + height/2, z = entityPos.z + offset.z + exOffset.z}
    if forceGet then
        return ret
    else
        local min = 
        {
            x = entityPos.x + offset.x + exOffset.x - radius, 
            y = entityPos.y + offset.y + exOffset.y, 
            z = entityPos.z + offset.z + exOffset.z - radius
        }
        local max = 
        {
            x = entityPos.x + offset.x + exOffset.x + radius, 
            y = entityPos.y + offset.y + exOffset.y + height, 
            z = entityPos.z + offset.z + exOffset.z + radius
        }
        return isPosInBox({min = min, max = max}, hitPos) and ret or false
    end
end

local function getHitConvexHullPointWithParams(capsuleParams, exOffset, hitPos, entityPos)
    local offset = capsuleParams.offset
    local imcV3 = {
        x = entityPos.x + offset.x + exOffset.x,
        y = entityPos.y + offset.y + exOffset.y,
        z = entityPos.z + offset.z + exOffset.z
    }
    local ret = Lib_v3add(capsuleParams.vertices[1], imcV3)
    local index = 1
    for idx, ver in pairs(capsuleParams.vertices) do
        local temp = Lib_v3add(ver, imcV3)
        if Lib_getPosDistanceSqr(temp, hitPos) < Lib_getPosDistanceSqr(ret, hitPos) then
            ret = temp
            index = idx
        end
    end
    return ret, index
end

local GetEditParamsWithCompoundFunc = {}
GetEditParamsWithCompoundFunc[EDIT_TYPE.BOX] = function(boxParams, idx, colliderTyp, exOffset, hitPos, entityPos, updateParamsMap)
    local tempPoint = getHitBoxPointWithParams(boxParams, exOffset, hitPos, entityPos)
    if tempPoint and (Lib_getPosDistanceSqr(tempPoint, hitPos) < Lib_getPosDistanceSqr(updateParamsMap.edit_point, hitPos)) then
        updateParamsMap.edit_point, updateParamsMap.edit_typ, updateParamsMap.edit_index, updateParamsMap.is_break = tempPoint, colliderTyp, idx, true
        editParams.exData = {}
    end
end
GetEditParamsWithCompoundFunc[EDIT_TYPE.SPHERE] = function(sphereParams, idx, colliderTyp, exOffset, hitPos, entityPos, updateParamsMap)
    local sphereCenter = {x = entityPos.x + sphereParams.offset.x + exOffset.x, y = entityPos.y + sphereParams.offset.y + exOffset.y + sphereParams.radius , z = entityPos.z + sphereParams.offset.z + exOffset.z}
    if Lib_getPosDistanceSqr(sphereCenter, hitPos) <= (sphereParams.radius*sphereParams.radius + kCollideDeviation) then
        updateParamsMap.edit_point, updateParamsMap.edit_typ, updateParamsMap.edit_index, updateParamsMap.is_break = sphereCenter, colliderTyp, idx, true
        editParams.exData = {}
    end
end
GetEditParamsWithCompoundFunc[EDIT_TYPE.CAPSULE] = function(capsuleParams, idx, colliderTyp, exOffset, hitPos, entityPos, updateParamsMap)
    local tempPoint = getHitCapsulePointWithParams(capsuleParams, exOffset, hitPos, entityPos)
    if tempPoint then
        updateParamsMap.edit_point, updateParamsMap.edit_typ, updateParamsMap.edit_index, updateParamsMap.is_break = tempPoint, colliderTyp, idx, true
        editParams.exData = {}
    end
end
GetEditParamsWithCompoundFunc[EDIT_TYPE.CYLINDER] = function(cylinderParams, idx, colliderTyp, exOffset, hitPos, entityPos, updateParamsMap) -- cylinder the same as capsule
    GetEditParamsWithCompoundFunc[EDIT_TYPE.CAPSULE](cylinderParams, idx, colliderTyp, exOffset, hitPos, entityPos, updateParamsMap)
end
GetEditParamsWithCompoundFunc[EDIT_TYPE.CONVEXHULL] = function(convexHullParams, idx, colliderTyp, exOffset, hitPos, entityPos, updateParamsMap)
    local tempPoint, convexHullIndex = getHitConvexHullPointWithParams(convexHullParams, exOffset, hitPos, entityPos)
    if (Lib_getPosDistanceSqr(tempPoint, hitPos) < Lib_getPosDistanceSqr(updateParamsMap.edit_point, hitPos)) then
        updateParamsMap.edit_point, updateParamsMap.edit_typ, updateParamsMap.edit_index, updateParamsMap.is_break = tempPoint, colliderTyp, idx, true
        editParams.exData.convexHullIndex = convexHullIndex
    end
end
GetEditParamsWithCompoundFunc[EDIT_TYPE.EMPTY] = function(cylinderParams, idx, colliderTyp, exOffset, hitPos, entityPos, updateParamsMap) -- cylinder the same as capsule
    -- nothing todo
end

local function getEditParamsCompound(colliderArr, exOffset, hitPos, entityPos)
    local updateParamsMap = {
        edit_point = editParams.point,
        edit_typ = editParams.typ,
        edit_index = editParams.index,
        is_break = false
    }
    for idx, colliderParams in pairs(colliderArr) do
        GetEditParamsWithCompoundFunc[colliderParams.type](colliderParams, idx, colliderParams.type, exOffset, hitPos, entityPos, updateParamsMap)
        if updateParamsMap.is_break then
            break
        end
    end
    return updateParamsMap.edit_point, updateParamsMap.edit_typ, updateParamsMap.edit_index
end

local EditParamsFunc = {}
EditParamsFunc[EDIT_TYPE.COMPOUND] = function(colliderParams, colliderType, hitPos, entityPos)
    return getEditParamsCompound(colliderParams.child, colliderParams.offset or DEFAULT_OFFSET, hitPos, entityPos)
end
EditParamsFunc[EDIT_TYPE.BOX] = function(colliderParams, colliderType, hitPos, entityPos)
    return getHitBoxPointWithParams(colliderParams, DEFAULT_OFFSET, hitPos, entityPos, true), colliderType, -1
end
EditParamsFunc[EDIT_TYPE.SPHERE] = function(colliderParams, colliderType, hitPos, entityPos)
    return {x = entityPos.x + colliderParams.offset.x, y = entityPos.y + colliderParams.offset.y + colliderParams.radius, z = entityPos.z + colliderParams.offset.z}, colliderType, -1
end
EditParamsFunc[EDIT_TYPE.CAPSULE] = function(colliderParams, colliderType, hitPos, entityPos)
    return getHitCapsulePointWithParams(capsuleParams, DEFAULT_OFFSET, hitPos, entityPos, true), colliderType, -1
end
EditParamsFunc[EDIT_TYPE.CYLINDER] = function(cylinderParams, colliderType, hitPos, entityPos) -- cylinder the same as capsule
    return getHitCapsulePointWithParams(cylinderParams, DEFAULT_OFFSET, hitPos, entityPos, true), colliderType, -1
end
EditParamsFunc[EDIT_TYPE.CONVEXHULL] = function(convexHullParams, colliderType, hitPos, entityPos)
    local tempPoint, convexHullIndex = getHitConvexHullPointWithParams(convexHullParams, DEFAULT_OFFSET, hitPos, entityPos)
    editParams.exData.convexHullIndex = convexHullIndex
    return tempPoint, colliderType, -1
end

local function updateEditParams()
    if not needUpdateEditPoint then
        return
    end
    local hitInfo = bm:getHitInfo()
    if not hitInfo.entity then
        return
    end
    if not collider or not next(collider) then return end
    local colliderType = collider.type
    editParams.point, editParams.typ, editParams.index = EditParamsFunc[colliderType](collider, colliderType, hitInfo.worldPos, hitInfo.entity:getPosition())
end

local Tip = {}
local globalTip = " == 任何时候鼠标右键挪动 + a + d，删除当前选中位置对应的碰撞盒(可以重做回来)。 =="
local boxTip = "\n  Box：" ..
"\n      鼠标右键移动： 当前编辑点左右移动" .. 
"\n          + ctrl：当前编辑点对应的Box碰撞盒整个移动" ..
"\n          + shift：当前编辑点上下移动"
local sphereTip = "\n  Sphere：" ..
"\n      鼠标右键：" ..
"\n         + 数字键1(非小键盘)：X轴移动" ..
"\n         + 数字键2(非小键盘)：Y轴移动" ..
"\n         + 数字键3(非小键盘)：Z轴移动" ..
"\n         + 数字键4(非小键盘)：半径"
local capsuleTip = 
"\n  Capsule：" ..
"\n     鼠标右键：" ..
"\n         + 数字键1(非小键盘)：X轴移动" ..
"\n         + 数字键2(非小键盘)：Y轴移动" ..
"\n         + 数字键3(非小键盘)：Z轴移动" ..
"\n         + 数字键4(非小键盘)：半径" ..
"\n         + 数字键4(非小键盘) + ctrl：高度"
local cylinderTip = 
"\n  Cylinder：" ..
"\n     鼠标右键：" ..
"\n         + 数字键1(非小键盘)：X轴移动" ..
"\n         + 数字键2(非小键盘)：Y轴移动" ..
"\n         + 数字键3(非小键盘)：Z轴移动" ..
"\n         + 数字键4(非小键盘)：半径" ..
"\n         + 数字键4(非小键盘) + ctrl：高度"
local convexHullTip = 
"\n  ConvexHull：" ..
"\n     鼠标右键：" ..
"\n         + 数字键1(非小键盘)：X轴移动" ..
"\n         + 数字键2(非小键盘)：Y轴移动" ..
"\n         + 数字键3(非小键盘)：Z轴移动" ..
"\n         + ctrl：删除当前点" ..
"\n         + shift：在当前点的上面一格添加一个点"

Tip[EDIT_TYPE.BOX] = function()
    return globalTip..boxTip
end
Tip[EDIT_TYPE.SPHERE] = function()
    return globalTip..sphereTip
end
Tip[EDIT_TYPE.CAPSULE] = function()
    return globalTip..capsuleTip
end
Tip[EDIT_TYPE.CYLINDER] = function()
    return globalTip..cylinderTip
end
Tip[EDIT_TYPE.CONVEXHULL] = function()
    return globalTip..convexHullTip
end

local function showTip()
    if not tipUI then
        return
    end
    local func = Tip[editParams.typ]
    tipUI:SetText(func and func() or "== 当前啥也没选中！！！==")
end

local drawRender = DrawRender.instance
drawRender:setLineWidth(3)

local DrawTip = {}
local tipColor = 0xFFFFD700
DrawTip[EDIT_TYPE.BOX] = function(colliderParams, exOffset)
    local offset = Lib_v3add(colliderParams.offset or DEFAULT_OFFSET, exOffset)
    local extent = colliderParams.extent or DEFAULT_OFFSET
    local min, max = Lib_v3sub(offset, {x = extent.x / 2, y = 0, z = extent.z / 2}),Lib_v3add(offset, {x = extent.x / 2, y = extent.y, z = extent.z / 2})
    drawRender:drawAABB(min, max, tipColor)
end
DrawTip[EDIT_TYPE.SPHERE] = function(colliderParams, exOffset)
    local offset = Lib_v3add(colliderParams.offset or DEFAULT_OFFSET, exOffset)
    offset.y = offset.y + colliderParams.radius
    drawRender:drawSphere(offset, colliderParams.radius, tipColor)
end
DrawTip[EDIT_TYPE.CAPSULE] = function(colliderParams, exOffset)
    local offset = Lib_v3add(colliderParams.offset or DEFAULT_OFFSET, exOffset)
    local radius = colliderParams.radius
    local height = colliderParams.height - radius*2
    offset.y = offset.y + radius
    drawRender:drawSphere(offset, radius, tipColor) -- low sphere
    if height > 0 then
        local min = {x = offset.x - radius, y = offset.y, z = offset.z - radius}
        local max = {x = offset.x + radius, y = offset.y + height, z = offset.z + radius}
        drawRender:drawAABB(min, max, tipColor)
        offset.y = offset.y + height
        drawRender:drawSphere(offset, radius, tipColor) -- height sphere
    end
end
DrawTip[EDIT_TYPE.CYLINDER] = function(colliderParams, exOffset)
    local offset = Lib_v3add(colliderParams.offset or DEFAULT_OFFSET, exOffset)
    local radius = colliderParams.radius
    local height = colliderParams.height
    drawRender:drawCircle(offset, radius, Vector3.new(0, 1, 0), tipColor) -- low sphere
    if height > 0 then
        local min = {x = offset.x - radius*0.75, y = offset.y, z = offset.z - radius*0.75}
        local max = {x = offset.x + radius*0.75, y = offset.y + height, z = offset.z + radius*0.75}
        drawRender:drawAABB(min, max, tipColor)
        offset.y = offset.y + height
        drawRender:drawCircle(offset, radius, Vector3.new(0, 1, 0), tipColor) -- height sphere
    end
end
local function sameV3(v31, v32)
    return (v31.x == v32.x) and (v31.y == v32.y) and (v31.z == v32.z)
end
DrawTip[EDIT_TYPE.CONVEXHULL] = function(colliderParams, exOffset)
    local editParams_point = editParams.point
    drawRender:drawCircle(editParams_point, 0.25, Vector3.new(0, 1, 0), tipColor)
    drawRender:drawCircle(editParams_point, 0.5, Vector3.new(0, 1, 0), tipColor)
    drawRender:drawCircle(editParams_point, 0.75, Vector3.new(0, 1, 0), tipColor)
end
DrawTip[EDIT_TYPE.COMPOUND] = function(colliderParams, exOffset)
    local child = colliderParams.child[editParams.index]
    if not child or not child.type then
        return
    end
    DrawTip[child.type](child, Lib_v3add(colliderParams.offset or DEFAULT_OFFSET, exOffset))
end

local function showDrawTip()
    if not attachEntity or not editParams.point or not editParams.typ or not collider or not next(collider) then return end
    local entity_pos = attachEntity:getPosition()

    local tempPoint = Lib_v3add(editParams.point, {x = 0, y = 0.2, z = 0})
    drawRender:drawTriangle(tempPoint, Lib_v3add(tempPoint, {x = 0.4, y = 0.4, z = 0}), Lib_v3add(tempPoint, {x = -0.4, y = 0.4, z = 0}), tipColor)
    drawRender:drawLine(tempPoint, Lib_v3add(tempPoint, {x = 0, y = 2, z = 0}), tipColor)
    drawRender:drawCircle(editParams.point, 0.1, Vector3.new(0, 1, 0), tipColor)

    if editParams.index < 0 then
        local func = DrawTip[editParams.typ]
        if func then
            func(collider, entity_pos)
        end
    else
        DrawTip[EDIT_TYPE.COMPOUND](collider, entity_pos)
    end
end

DebugDraw.addEntry("editVolumeBox", function()
    updateEditParams()
    showTip()
    showDrawTip()
end)

local function redo()
    if not attachEntity then 
        return
    end
    collider.child[#collider.child + 1] = editRedoStack[#editRedoStack]
    editRedoStack[#editRedoStack] = nil
    attachEntity:setBoundingVolume({collider = collider})
end

local function undo()
    if not attachEntity then 
        return
    end
    editRedoStack[#editRedoStack + 1] = collider.child[#collider.child]
    collider.child[#collider.child] = nil
    attachEntity:setBoundingVolume({collider = collider})
end



function M:init()
    WinBase.init(self, "EditVolumeBox.json", true)
    tipUI = self:child("EditVolumeBox-edit_tip")
    self.btnSave = self:child("EditVolumeBox-save")
    self.saveInput = self:child("EditVolumeBox-save_input")
    self.saveInput:SetProperty("MaxTextLength", 200)
    self.btnUndo = self:child("EditVolumeBox-undo")
    self.btnRedo = self:child("EditVolumeBox-redo")

    self.btnBigFov = self:child("EditVolumeBox-bigFov")
    self.btnSmallFov = self:child("EditVolumeBox-smallFov")
    self.btnDownPos = self:child("EditVolumeBox-downPos")
    self.btnUpPos = self:child("EditVolumeBox-upPos")

    self.btnSaveToMap = self:child("EditVolumeBox-save_to_map")
    self.saveToMapInput = self:child("EditVolumeBox-save_to_map_input")
    self.saveToMapInput:SetProperty("MaxTextLength", 200)
    self.btnSaveToMapUndo = self:child("EditVolumeBox-save_to_map_undo")

    local function volume(typ)
        changeCanSaveCollisionBoxToMap(self, true)
        editRedoStack = {}
        self:addVolume(typ)
    end
    self:subscribe(self:child("EditVolumeBox-add-box"), UIEvent.EventButtonClick, function()
        volume(EDIT_TYPE.BOX)
    end)
    self:subscribe(self:child("EditVolumeBox-add-sphere"), UIEvent.EventButtonClick, function()
        volume(EDIT_TYPE.SPHERE)
    end)
    self:subscribe(self:child("EditVolumeBox-add-capsule"), UIEvent.EventButtonClick, function()
        volume(EDIT_TYPE.CAPSULE)
    end)
    self:subscribe(self:child("EditVolumeBox-add-cylinder"), UIEvent.EventButtonClick, function()
        volume(EDIT_TYPE.CYLINDER)
    end)
    self:subscribe(self:child("EditVolumeBox-add-convexHull"), UIEvent.EventButtonClick, function()
        volume(EDIT_TYPE.CONVEXHULL)
    end)
    self:subscribe(self.btnSave, UIEvent.EventButtonClick, function()
        self:saveVolumeBox(tempMod or edit_mod)
    end)
    self:subscribe(self.saveInput, UIEvent.EventEditTextInput, function()
        local modText = self.saveInput:GetPropertyString("Text","")
        if not modText or modText == "" then
            return
        end
        self.saveInput:SetProperty("Text", modText)
        tempMod = modText
    end)

    self:subscribe(self.btnUndo, UIEvent.EventButtonClick, function()
        changeCanSaveCollisionBoxToMap(self, true)
        undo()
    end)
    self:subscribe(self.btnRedo, UIEvent.EventButtonClick, function()
        changeCanSaveCollisionBoxToMap(self, true)
        redo()
    end)

    self:subscribe(self.btnBigFov, UIEvent.EventButtonClick, function()
        editFovCount = editFovCount + 1
        bmGameSettings:setFovSetting(bmGameSettings:getFovSetting() + STATIC_FOV_IMC)
    end)
    self:subscribe(self.btnSmallFov, UIEvent.EventButtonClick, function()
        editFovCount = editFovCount - 1
        bmGameSettings:setFovSetting(bmGameSettings:getFovSetting() - STATIC_FOV_IMC)
    end)

    self:subscribe(self.btnDownPos, UIEvent.EventButtonClick, function()
        Me:setPosition(Lib.v3add(Me:getPosition(),{x = 0, y = -1, z = 0}))
    end)

    self:subscribe(self.btnUpPos, UIEvent.EventButtonClick, function()
        Me:setPosition(Lib.v3add(Me:getPosition(),{x = 0, y = 1, z = 0}))
    end)

    self.container = {}
    self.containerCloser = {}

    Lib.subscribeEvent(Event.EVENT_SCENE_TOUCH_MOVE, function(x, y, preX, preY)
        M:resizeVolumeBox(x - preX, y - preY)
    end)
    
    Lib.subscribeEvent(Event.EVENT_SCENE_TOUCH_END, function()
        leaveDragMode()
    end)

    Lib.subscribeEvent(Event.EVENT_SCENE_TOUCH_CANCEL, function()
        leaveDragMode()
    end)

    self:subscribe(self.btnSaveToMap, UIEvent.EventButtonClick, function()
        self:saveStaticCollisionBoxToMap(saveToMapMod or STATIC_SAVETOMAP_MOD)
    end)
    self:subscribe(self.saveToMapInput, UIEvent.EventEditTextInput, function()
        local modText = self.saveToMapInput:GetPropertyString("Text","")
        if not modText or modText == "" or saveToMapMod == modText then
            return
        end
        self.saveToMapInput:SetProperty("Text", modText)
        saveToMapMod = modText
        changeCanSaveCollisionBoxToMap(self, true)
    end)
    self:subscribe(self.btnSaveToMapUndo, UIEvent.EventButtonClick, function()
        self:saveStaticCollisionBoxToMap_undo()
    end)
end

local function createEditEntity(pos)
    local worldCfg = World.cfg
    local params = {
        cfgName = "myplugin/" .. edit_mod,
        name = "编辑包围盒",
        pos = pos or Me:getFrontPos(3, true)
    }
    attachEntity = EntityClient.CreateClientEntity(params)
    collider = getEntityCollider(attachEntity)
end


function M:addVolume(typ)
    if not attachEntity then 
        createEditEntity()
    end
    local newVolume = DefaultCollider[typ](Lib.v3cut(Me:getPosition(), attachEntity:getPosition()))
    if collider.type ~= EDIT_TYPE.COMPOUND then 
        local subVolume = collider
        collider = {}
        collider.type = EDIT_TYPE.COMPOUND
        collider.child = {}
        if next(subVolume) then
            collider.child[1] = subVolume
        end
    end
    collider.child[#collider.child + 1] = newVolume
    attachEntity:setBoundingVolume({collider = collider})
end

function M:reset()
    if attachEntity then 
        attachEntity:setBoundingVolume(attachEntity:cfg())
    end
end

function M:saveVolumeBox(mod)
    if not collider or not mod then return end 
    
    local cfg = Lib_read_json_file(STATIC_GAME_PATH.."plugin/myplugin/entity/"..mod.."/setting.json")
    if not cfg then
		local path = STATIC_GAME_PATH.."plugin/myplugin/entity/"..mod
        -- path = string.gsub(path, "/", "\\\\")
        -- os.execute("mkdir "..path)
        lfs_mkdir(path)
        local f = io_open(STATIC_GAME_PATH.."plugin/myplugin/entity/"..mod.."/setting.json", "w+")
        f:write(Lib_toJson({}))
        f:close()
        cfg = Lib_read_json_file(STATIC_GAME_PATH.."plugin/myplugin/entity/"..edit_mod.."/setting.json")
    end
    cfg.collider = collider
    cfg.collision = true

    local file = io_open(STATIC_GAME_PATH.."plugin/myplugin/entity/"..mod.."/setting.json", "w+")
    file:write(Lib_toJson(cfg))
    file:close()
end

function M:saveStaticCollisionBoxToMap(mod)
    if not checkCanSaveCollisionBoxToMap() or not attachEntity then
        return
    end
    if not collider or not mod then
        perror("not collider or not mod, in editVolumeBox:saveStaticCollisionBoxToMap.")
        return
    end
    local mapDir = STATIC_GAME_PATH .. "/map/" .. mod
    local settingPath = mapDir .. "/setting.json"
    if not checkPathIsExist(mapDir) or not checkPathIsExist(settingPath) then
        perror("map/map*setting does not exist, in editVolumeBox:saveStaticCollisionBoxToMap, map name ->", mod)
        return
    end
    local cfg = Lib_read_json_file(settingPath)
    if not cfg then
        print("map will create new empty setting! in editVolumeBox:saveStaticCollisionBoxToMap, map name ->", mod)
        cfg = {staticCollisionBox = {}}
        local file = io_open(settingPath, "w+")
        file:write(Lib_toJson({}))
        file:close()
    end
    local staticCollisionBox = cfg.staticCollisionBox
    if not staticCollisionBox then
        staticCollisionBox = {}
        cfg.staticCollisionBox = staticCollisionBox
    end

    staticCollisionBox[#staticCollisionBox + 1] = {
        collider = collider, 
        position = attachEntity:getPosition()
    }

    local file = io_open(settingPath, "w+")
    file:write(Lib_toJson(cfg))
    file:close()
    changeCanSaveCollisionBoxToMap(self, false)
    changeHadSaveToMap(self, true, mod)
end

function M:saveStaticCollisionBoxToMap_undo()
    if not checkHadSaveToMap() then
        return
    end
    local path = STATIC_GAME_PATH .. "/map/" .. lastSaveToMapMod .. "/setting.json"
    local cfg = Lib_read_json_file(path)
    local staticCollisionBox = cfg.staticCollisionBox
    staticCollisionBox[#staticCollisionBox] = nil
    local file = io_open(path, "w+")
    file:write(Lib_toJson(cfg))
    file:close()
    changeCanSaveCollisionBoxToMap(self, true)
    changeHadSaveToMap(self, false)
end

local function resetLocalProp(self)
    editRedoStack = {}
    editFovCount = 0
    tempMod = nil
    saveToMapMod = nil
    lastSaveToMapMod = nil
    changeCanSaveCollisionBoxToMap(self, true)
    changeHadSaveToMap(self, false)
    self.saveInput:SetProperty("Text", edit_mod)
    self.saveToMapInput:SetProperty("Text", Me.map.name or STATIC_SAVETOMAP_MOD)
end

function M:onOpen()
    self.oldDisableGetMouseOver = World.CurWorld.disableGetMouseOver or false
    World.CurWorld.disableGetMouseOver = false

    if not attachEntity then
        createEditEntity()
    end
    ISOPEN = true
    for _, buffCfg in pairs(editVolumeBuff) do
        Me:addClientBuff(buffCfg)
    end
    resetLocalProp(self)
end

function M:onClose()
    if attachEntity then
        attachEntity:destroy()
        attachEntity = nil
        collider = nil
    end
    ISOPEN = false
    for _, buffCfg in pairs(editVolumeBuff) do
        local tempBuff = Me:getTypeBuff("fullName", buffCfg)
        if tempBuff then
            Me:removeClientBuff(tempBuff)
        end
    end
    bmGameSettings:setFovSetting(bmGameSettings:getFovSetting() - editFovCount * STATIC_FOV_IMC)
    resetLocalProp(self)
    World.CurWorld.disableGetMouseOver = self.oldDisableGetMouseOver
end

local function isSame(v1, v2)
    return math_abs(v1 - v2) < kCollideDeviation
end

local ColliderEdit = {}
ColliderEdit[EDIT_TYPE.BOX] = function(bm, uiDX, uiDY, entity, editCollider, entity_pos, editParams_point)
    local yaw = bm:getViewerYaw()
    local dX, dY, dZ
    if bm:isKeyPressing("key.sneak") then 
        dY = -uiDY / 100
        dX, dZ = 0, 0
    else
        local sinYaw = math_sin(-math_rad(yaw))
        local cosYaw = math_cos(-math_rad(yaw))
        dY = 0
        dZ = -(uiDY*cosYaw - uiDX*sinYaw) / 100
        dX = -(uiDY*sinYaw + uiDX*cosYaw) / 100

        if math_abs(dZ) > 5*math_abs(dX) then --忽略微小的斜向变化
            dX = 0
        elseif math_abs(dX) > 5*math_abs(dZ) then 
            dZ = 0
        end
    end

    if bm:isKeyPressing("key.pull") then -- 移动包围盒
        local offset = editCollider.offset
        offset.x = offset.x + dX/2
        offset.y = offset.y + dY
        offset.z = offset.z + dZ/2
    else
        local extent = editCollider.extent
        local offset = editCollider.offset
        local min = { x = entity_pos.x - extent.x/2 + offset.x, y = entity_pos.y + offset.y, z = entity_pos.z - extent.z/2 + offset.z } 
        local max = { x = entity_pos.x + extent.x/2 + offset.x, y = entity_pos.y + extent.y + offset.y, z = entity_pos.z + extent.z/2 + offset.z } 
        --UI位置->碰撞盒的xz变化分量
        if isSame(editParams_point.y, min.y) then 
            extent.y = extent.y - dY
        else--if isSame(editParams_point.y, max.y) then 
            extent.y = extent.y + dY
        end
        if isSame(editParams_point.x, min.x) then 
            extent.x = extent.x - dX
        else--if isSame(editParams_point.x, max.x) then 
            extent.x = extent.x + dX
        end
        if isSame(editParams_point.z, min.z) then 
            extent.z = extent.z - dZ
        else--if isSame(editParams_point.z, max.z) then 
            extent.z = extent.z + dZ
        end
    end
    editParams_point.x = editParams_point.x + dX/2
    editParams_point.y = editParams_point.y + dY
    editParams_point.z = editParams_point.z + dZ/2
    --改变包围盒
    entity:setBoundingVolume({collider = collider})
end
local function getDXYZWithPressing123(bm, uiDX, uiDY)
    local dX, dY, dZ = 0,0,0
    local yaw = bm:getViewerYaw()
    local sinYaw = math_sin(-math_rad(yaw))
    local cosYaw = math_cos(-math_rad(yaw))
    if bm:isKeyPressing("key.num1") then
        dX = -(uiDY*sinYaw + uiDX*cosYaw) / 100
    end
    if bm:isKeyPressing("key.num2") then
        dY = -uiDY / 100
    end
    if bm:isKeyPressing("key.num3") then
        dZ = -(uiDY*cosYaw - uiDX*sinYaw) / 100
    end
    return dX, dY, dZ
end
ColliderEdit[EDIT_TYPE.SPHERE] = function(bm, uiDX, uiDY, entity, editCollider, entity_pos, editParams_point)
    local dX, dY, dZ = getDXYZWithPressing123(bm, uiDX, uiDY)
    local imcRadius = 0
    if bm:isKeyPressing("key.num4") then
        imcRadius = -uiDY / 100
    end
    editParams_point.x = editParams_point.x + dX
    editParams_point.y = editParams_point.y + imcRadius + dY
    editParams_point.z = editParams_point.z + dZ
    local offset = editCollider.offset
    offset.x, offset.y, offset.z, editCollider.radius = offset.x + dX, offset.y + dY, offset.z + dZ, editCollider.radius + imcRadius
    entity:setBoundingVolume({collider = collider})
end
ColliderEdit[EDIT_TYPE.CAPSULE] = function(bm, uiDX, uiDY, entity, editCollider, entity_pos, editParams_point)
    local dX, dY, dZ = getDXYZWithPressing123(bm, uiDX, uiDY)
    local imcRadius,imcHeight = 0,0
    if bm:isKeyPressing("key.num4") then
        if bm:isKeyPressing("key.pull") then
            imcHeight = -uiDY / 100
        else
            imcRadius = -uiDY / 100
        end
    end
    editParams_point.x = editParams_point.x + dX
    editParams_point.y = editParams_point.y + imcHeight/2 + dY
    editParams_point.z = editParams_point.z + dZ
    local offset = editCollider.offset
    offset.x, offset.y, offset.z, editCollider.radius, editCollider.height = 
        offset.x + dX, offset.y + dY, offset.z + dZ, editCollider.radius + imcRadius, editCollider.height + imcHeight
    entity:setBoundingVolume({collider = collider})
end
ColliderEdit[EDIT_TYPE.CYLINDER] = function(bm, uiDX, uiDY, entity, editCollider, entity_pos, editParams_point) -- cylinder the same as capsule
    ColliderEdit[EDIT_TYPE.CAPSULE](bm, uiDX, uiDY, entity, editCollider, entity_pos, editParams_point)
end
ColliderEdit[EDIT_TYPE.CONVEXHULL] = function(bm, uiDX, uiDY, entity, editCollider, entity_pos, editParams_point)
    local dX, dY, dZ = getDXYZWithPressing123(bm, uiDX, uiDY)
    local editCollider_vertices = editCollider.vertices
    local convexHullIndex = editParams.exData.convexHullIndex
    if bm:isKeyPressing("key.pull") then -- ctrl
        if not checkGlobalCD() then
            startGlobalCD()
            editCollider_vertices[convexHullIndex], editCollider_vertices[#editCollider_vertices] = editCollider_vertices[#editCollider_vertices], editCollider_vertices[convexHullIndex]
            editCollider_vertices[#editCollider_vertices] = nil
            editParams.exData.convexHullIndex = 1
            editParams.point = Lib_copy(editCollider_vertices[1])
        end
    elseif bm:isKeyPressing("key.sneak") then -- shift
        if not checkGlobalCD() then
            startGlobalCD()
            local imc = {x = 0, y = 1, z = 0}
            editCollider_vertices[#editCollider_vertices + 1] = Lib_v3add(editCollider_vertices[convexHullIndex], imc)
            editParams.exData.convexHullIndex = #editCollider_vertices
            editParams.point = Lib_v3add(editParams_point, imc)
        end
    else
        editParams.point = Lib_v3add(editParams_point, {x = dX, y = dY, z = dZ})
        editCollider_vertices[convexHullIndex] = Lib_v3add(editCollider_vertices[convexHullIndex], {x = dX, y = dY, z = dZ})
    end
    entity:setBoundingVolume({collider = collider})
end

function M:resizeVolumeBox(uiDX, uiDY)
    if checkGlobalCD() then
        return
    end
    if bm:isMouseBtnDown(1) ~= true then --右键按下
        leaveDragMode()
        return
    end
    enterDragMode()
    local entity = attachEntity
    if not entity then return end
    if not collider then 
        collider = getEntityCollider(attachEntity) -- Lib.copy(attachEntity:cfg().editCollider)
    end
    local entity_pos = entity:getPosition()
    local editParams_point = editParams.point
    local editCollider = (editParams.index == -1) and collider or collider.child[editParams.index]
    local editParams_typ = editParams.typ
    if not editParams_point or not editCollider or not editParams_typ then return end
    if bm:isKeyPressing("key.left") and bm:isKeyPressing("key.right") then -- a + d
        startGlobalCD()
        local collider_child = collider.child
        -- collider_child[editParams.index], collider_child[#collider_child] = collider_child[#collider_child], collider_child[editParams.index]
        local temp = collider_child[editParams.index] -- it must be can redo undo
        for i = editParams.index, #collider_child - 1 do
            collider_child[i] = collider_child[i+1]
        end
        collider_child[#collider_child] = temp
        undo()
        editParams = Lib_copy(defaultEditParams)
    else
        ColliderEdit[editParams_typ](bm, uiDX, uiDY, entity, editCollider, entity_pos, editParams_point)
    end
    changeCanSaveCollisionBoxToMap(self, true)
end

local function showBBox(flag)
    local debugDraw = DebugDraw.instance
    debugDraw:setEnabled(flag)
    debugDraw:setEditVolumeBoxEnabled(flag)
    debugDraw:setDrawColliderAABBEnabled(flag)
    debugDraw:setDrawColliderEnabled(flag)
    debugDraw:setDrawAuraEnabled(flag)
    debugDraw:setDrawRegionEnabled(flag)
end

---@param entity Entity
function M:clickEntity(entity)
    if not UI:isOpen("editVolumeBox") then
        createEditEntity(entity:getPosition())
        UI:openWnd("editVolumeBox")
        showBBox(true)
    end
end

return M