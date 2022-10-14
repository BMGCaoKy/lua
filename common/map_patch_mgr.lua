-- * MapPatchMgr ： map 补丁包 管理，用于生成本地补丁包文件，适用于下次开启游戏时重构(数据量小)
-- * ptr
local os_date = os.date
local os_time = os.time
local lfs_attributes = lfs.attributes
local lfs_mkdir = lfs.mkdir
local lfs_dir = lfs.dir
local io_open = io.open
local cjson = require "cjson"

local function saveJson(path, content)
    local ok
    ok, content = pcall(cjson.encode, content)
    if not ok then
        Lib.logError("json encode error", path)
        return
    end
    local file, errorMessgae = io.open(path, "w+")
    if not file then
        Lib.logError(errorMessgae)
        return
    end
    file:write(content)
    file:close()
end
local Lib_read_json_file = Lib.read_json_file
local Lib_copyFile = Lib.copyFile
local Lib_rmdir = Lib.rmdir
local curWorld = World.CurWorld

-- * static
local STATIC_MAX_SAVE_OPERAT_COUNT_INTERVAL = 200
local STATIC_SAVE_TIME_INTERVAL = 1200
local STATIC_PATCH_VERSION_TIME = 9999 -- day
local DEFAULT_TIMER_TIME = 20 * 60 * 20

local STATIC_GAME_PATH = Root.Instance():getGamePath()

-- * local
local createByMapEntityTable = {}
local createByMapDropItemTable = {}

-- * cfg
local enableMapPatch = World.cfg.enableMapPatch or false
local mapPatchProp = World.cfg.mapPatchProp or {}
--[[
    mapPatchProp = {
        saveOperatCountInterval : 20, -- 保存操作间隔：与下条互补，针对频繁操作后意外强退情况，在操作多次后强制save
        saveTimeInterval : 120,       -- 保存时间间隔：地图数据change过后多久就保存，在时间内如果再次change则重新计时
        savePatchVersionTime ：9999,  -- 游玩数据过期时间 day
        saveTimerTime : 20 * 60 * 20  -- 游戏的保存间隔(这个间隔是游戏每隔多久保存一次)
    }
]]
local maxSaveOperatCount = mapPatchProp.saveOperatCountInterval or STATIC_MAX_SAVE_OPERAT_COUNT_INTERVAL
local saveTimeInterval = mapPatchProp.saveTimeInterval or STATIC_SAVE_TIME_INTERVAL
local savePatchVersionTime = mapPatchProp.savePatchVersionTime or STATIC_PATCH_VERSION_TIME
local saveTimerTime = mapPatchProp.saveTimerTime or DEFAULT_TIMER_TIME

-- * save prop
local saveOperatCount = 0
local saveTimer = nil

-- * save table
local map_blockMgr = {}
--[[
    map_blockMgr = {mapName : [x: [y : [z : {blockBlockId : Id, blockBlockId : Id} ] ] ]}
        * when save -> if oldBlockId == newBlockId -> not save and cleanUp this filed, cause this pos not change.
]]

local map_entityMgr = {}
--[[
    map_entityMgr = {
        mapName : {
            objPatchKey : {createByMapIndex = xx, pos = xx, yaw = xx, pitch = xx, change = xx, objPatchKey= xxxx_xx, fullName = xxx, saveHp = xx, isStartAI},
        }
    }
]]

local map_dropItemMgr = {}
--[[
    map_dropItemMgr = {
        mapName : {
            objPatchKey : {createByMapIndex = xx, pos = xx, yaw = xx, pitch = xx, change = xx, objPatchKey= xxxx_xx,
                                            lifeTime = xxx, item_type = xx, item_fullName = xx, block_id = xx, item_count = xx,
                                            item_moveSpeed = xxx, item_moveTime = xxx}
        }
    }
]]

-- *********************************************** --
--[[
                       ** patch file format **
    {
        changeBlocks : { x : { y : {z : {oldBlockId : xx, newBlockId:xx} } } }, -- x y z is string
    }

    {
        changeEntitys : { objPatchKey : {createByMapIndex = xx, pos = xx, yaw = xx, pitch = xx, change = xx, saveHp = xx, isStartAI,
                                            objPatchKey= xxxx_xx, fullName = xxx} }
    }
    {
        changeDropItems : { objPatchKey : {createByMapIndex = xx, pos = xx, yaw = xx, pitch = xx, change = xx, objPatchKey= xxxx_xx,
                                            lifeTime = xxx, item_type = xx, item_fullName = xx, block_id = xx, item_count = xx},
                                            item_moveSpeed = xxx, item_moveTime = xxx }
    }
        -- createByMapIndex/createByMapIndex widght > objPatchKey widght
        -- if objTb has createByMapIndex, this tb's change must be destroy/update, it just can use createByMapIndex find the obj.
        -- if objTb hasn't createByMapIndex, this tb's change must be create/update, it must use createEntity.
        * change -> destroy/create/update,
        * objPatchKey -> today + time + _ + cur objID
]]
-- *********************************************** --

----------------------------------------------------- util method
local function resetSaveProp()
    if saveTimer then
        saveTimer()
    end
    saveTimer = nil
    saveOperatCount = 0
end

local function resetSaveTable()
    map_blockMgr = {}
    map_dropItemMgr = {}
    map_entityMgr = {}
end

local function getToday()
    return os_date("%Y%m%d",os_time())
end

local function getTime()
    return os_date("%H%M%S",os_time())
end

local function getWorldTime()
    return curWorld:getWorldTime()
end

local function setWorldTime(worldTime)
    return curWorld:setWorldTime(worldTime)
end

local function getMapName(map)
    return type(map) == "string" and map or map.name
end

local function getPatchFileName()
    return "mapPatch.json" -- "mapPatch_" .. getToday() .. ".json"
end

local function getAndCreateMapDir(mapName)
    local path = STATIC_GAME_PATH .. "map/" .. (mapName or "")
    if not lfs_attributes(path, "mode") then
        lfs_mkdir(path)
    end
    return path
end

local function getAndCreatePatchRootDir(mapRootDir, notCreate)
    local path = mapRootDir .. "patchDir"
    if not lfs_attributes(path, "mode") then
        if notCreate then
            return
        end
        lfs_mkdir(path)
    end
    return path
end
    
local function getAndCreatePatchDir(mapRootDir, mapName, notCreate)
    local path = getAndCreatePatchRootDir(mapRootDir, notCreate)
    if not path then
        return
    end
    path = path .. "/" .. mapName
    if not lfs_attributes(path, "mode") then
        if notCreate then
            return
        end
        lfs_mkdir(path)
    end
    return path
end

local function getMapPatchFilePathByMapName(mapName, modName)
    return getAndCreatePatchDir(getAndCreateMapDir(), mapName) .. "/" .. modName .. "_" .. getPatchFileName()
end

local function getMapSettingFilePathByMapName(mapName)
    return getAndCreateMapDir(mapName) .. "/setting.json"
end

local function checkOrCreatePatchFile(path)
    if not lfs_attributes(path, "mode") then
        saveJson(path, {})
	end
end

local enableMapPatchMgr = World.isEditorServer
Lib.logInfo(string.format("checkEnableMapPatchMgr, enableMapPatch: %s, enableMapPatchMgr: %s", enableMapPatch, enableMapPatchMgr))

local function checkEnableMapPatchMgr()
    return enableMapPatch and enableMapPatchMgr
end

local function checkEntityIsEnableAI(entity)
    for _, tb in pairs(entity:data("aiData") or {}) do
        return true
    end
    return false
end

local function tableSave2TableByFiled(targetTable, sourceTable)
    for filed, value in pairs(sourceTable) do
        if filed == "pos" then
            targetTable.pos = {x = value.x, y = value.y, z = value.z}
        else
            targetTable[filed] = value
        end
    end
    -- targetTable.createByMapIndex = sourceTable.createByMapIndex or targetTable.createByMapIndex
    -- targetTable.change = sourceTable.change or targetTable.change
    -- targetTable.pos = sourceTable.pos and {x = sourceTable.pos.x, y = sourceTable.pos.y, z = sourceTable.pos.z} or targetTable.pos
    -- targetTable.yaw = sourceTable.yaw or targetTable.yaw
    -- targetTable.pitch = sourceTable.pitch or targetTable.pitch
    -- targetTable.objPatchKey = sourceTable.objPatchKey or targetTable.objPatchKey
    -- targetTable.fullName = sourceTable.fullName or targetTable.fullName
    -- targetTable.lifeTime = sourceTable.lifeTime or targetTable.lifeTime
    -- targetTable.item_type = sourceTable.item_type or targetTable.item_type
    -- targetTable.item_fullName = sourceTable.item_fullName or targetTable.item_fullName
    -- targetTable.block_id = sourceTable.block_id or targetTable.block_id
    -- targetTable.item_count = sourceTable.item_count or targetTable.item_count
    -- targetTable.item_moveSpeed = sourceTable.item_moveSpeed or targetTable.item_moveSpeed
    -- targetTable.item_moveTime = sourceTable.item_moveTime or targetTable.item_moveTime
    -- targetTable.saveHp = sourceTable.saveHp or targetTable.saveHp
    -- targetTable.isStartAI = sourceTable.isStartAI or targetTable.isStartAI
end

local function getMapsNameList()
    local mapsNameList = {}
    local mapsDir = getAndCreateMapDir()
    for fileName in lfs_dir(mapsDir) do
        if fileName ~= "." and fileName ~= ".." then
            local filepath = mapsDir .. fileName
            local fileattr = lfs_attributes(filepath, "mode", true)
            if fileattr == "directory" then
                mapsNameList[#mapsNameList + 1] = fileName
            end
        end
    end
    return mapsNameList
end

local function checkFile(path)
    return lfs_attributes(path, "mode")
end

local function clearPatchFile(patchFile)
    if lfs_attributes(patchFile, "mode") then
        saveJson(patchFile, {})
    end
end

local function removeAllPatchDir()
    if not enableMapPatch then
        return
    end
    local patchDir = getAndCreateMapDir() .. "/" .. "patchDir"
    if lfs_attributes(patchDir, "mode") then
        Lib_rmdir(patchDir)
    end
end

local function checkPatchIsNeedOperating()
    if not enableMapPatch then
        return false
    end
    local patchDir = getAndCreateMapDir() .. "patchDir"
    if not lfs_attributes(patchDir, "mode") then
        return false
    end
    local lastEditTime = -1
    for fileName in lfs_dir(patchDir) do
        if fileName ~= "." and fileName ~= ".." then
            local time = lfs_attributes(patchDir .. "/" .. fileName, "modification")
            if time > lastEditTime then
                lastEditTime = time
            end
        end
    end
    if lastEditTime < 0 then
        removeAllPatchDir()
        return false
    end
    print("os_time() - lastEditTime", os_time(), lastEditTime)
    if (os_time() - lastEditTime) > savePatchVersionTime * 24 * 60 * 60 then
        removeAllPatchDir()
        return false
    end
    return true
end

local function checkAndRemoveAllFlagFile()
    local mapRootDir = getAndCreateMapDir()
    local mergeFilePath = mapRootDir .. "needMergePatch.flag"
    local removeFilePath = mapRootDir .. "needRemovePatch.flag"
    if checkFile(mergeFilePath) then
        os.remove(mergeFilePath)
    end
    if checkFile(removeFilePath) then
        os.remove(removeFilePath)
    end
end
-- *********************************************** --
----------------------------------------------------- save method
local function saveBlockChangeToPatchFile(posTable, path)
    checkOrCreatePatchFile(path)
    local cfg = assert(Lib_read_json_file(path), "map_patch_mgr:saveBlockChangeToPatchFile path error.path:" .. path)
    if not cfg.changeBlocks then
        cfg.changeBlocks = {}
    end
    local changeBlocks = cfg.changeBlocks
    for x, yzTable in pairs(posTable) do
        local changeBlocksX = changeBlocks[tostring(x)]
        if not changeBlocksX then
            changeBlocksX = {}
            changeBlocks[tostring(x)] = changeBlocksX
        end
        for y, zTable in pairs(yzTable) do
            local changeBlocksXY = changeBlocksX[tostring(y)]
            if not changeBlocksXY then
                changeBlocksXY = {}
                changeBlocksX[tostring(y)] = changeBlocksXY
            end
            for z, blockTable in pairs(zTable) do
                local changeBlockXYZ = changeBlocksXY[tostring(z)]
                if not changeBlockXYZ then
                    changeBlockXYZ = {}
                    changeBlocksXY[tostring(z)] = changeBlockXYZ
                end
                if not changeBlockXYZ.oldBlockId then
                    changeBlockXYZ.oldBlockId = blockTable.oldBlockId
                end
                changeBlockXYZ.newBlockId = blockTable.newBlockId
                if changeBlockXYZ.oldBlockId == changeBlockXYZ.newBlockId then
                    changeBlocksXY[tostring(z)] = nil
                end
            end
        end
    end
    saveJson(path, cfg)
end

local function saveObjectChangeToPatchFile(objectTable, path, params) -- params ->{isEntity, isDropItem}
    local changeFiled
    if params.isEntity then
        changeFiled = "changeEntitys"
    elseif params.isDropItem then
        changeFiled = "changeDropItems"
    end
    if not changeFiled then
        return
    end
    checkOrCreatePatchFile(path)
    local cfg = assert(Lib_read_json_file(path), "map_patch_mgr:saveObjectChangeToPatchFile path error.path:" .. path)
    if not cfg[changeFiled] then
        cfg[changeFiled] = {}
    end
    local changeTable = cfg[changeFiled]
    for objPatchKey, tb in pairs(objectTable) do
        if not tb.createByMapIndex and tb.change == "destroy" then
            changeTable[objPatchKey] = nil
        else
            local changeTable_objPatchKey = changeTable[objPatchKey]
            if not changeTable_objPatchKey then
                changeTable_objPatchKey = {}
                changeTable[objPatchKey] = changeTable_objPatchKey
            end
            -- changeTable[objPatchKey] = tb
            tableSave2TableByFiled(changeTable_objPatchKey, tb)
            -- ex
            if tb.objId then
                local obj = curWorld:getObject(tb.objId)
                if obj then
                    changeTable_objPatchKey.isStartAI = checkEntityIsEnableAI(obj)
                end
            end
        end
    end
    saveJson(path, cfg)
end

local function saveWorldTimeToPatchFile()
    local worldTimePatchFile = getAndCreatePatchRootDir(getAndCreateMapDir()) .. "/worldTime.json"
    checkOrCreatePatchFile(worldTimePatchFile)
    local cfg = assert(Lib_read_json_file(worldTimePatchFile), "map_patch_mgr:saveWorldTimeToPatchFile path error.path:" .. worldTimePatchFile)
    cfg.worldTime = getWorldTime()
    saveJson(worldTimePatchFile, cfg)
end

local function saveChangeToPatchFile()
    for mapName, posTable in pairs(map_blockMgr) do
        saveBlockChangeToPatchFile(posTable, getMapPatchFilePathByMapName(mapName, "block"))
    end

    for mapName, entityTable in pairs(map_entityMgr) do
        saveObjectChangeToPatchFile(entityTable, getMapPatchFilePathByMapName(mapName, "entity"), {isEntity = true})
    end

    for mapName, dropItemTable in pairs(map_dropItemMgr) do
        saveObjectChangeToPatchFile(dropItemTable, getMapPatchFilePathByMapName(mapName, "dropItem"), {isDropItem = true})
    end

    saveWorldTimeToPatchFile()

    resetSaveProp()
    resetSaveTable()
end

local function saveChange()
    if saveTimer then
        saveTimer()
    end
    saveOperatCount = saveOperatCount + 1
    if saveOperatCount >= maxSaveOperatCount then
        saveOperatCount = 0
        saveChangeToPatchFile()
        return
    end
    saveTimer = World.Timer(saveTimeInterval, saveChangeToPatchFile)
end

----------------------------------------------------- playing logic
function MapPatchMgr.BlockChange(map, params) -- params: pos, oldId, newId, notSave
    local pos = params.pos
    if not checkEnableMapPatchMgr() or not map or not pos then
        return false
    end

    local mapName = getMapName(map)
    local map_patch = map_blockMgr[mapName] -- mapName
    if not map_patch then
        map_patch = {}
        map_blockMgr[mapName] = map_patch
    end

    local xpatch = map_patch[pos.x] -- x
    if not xpatch then
        xpatch = {}
        map_patch[pos.x] = xpatch
    end

    local ypatch = xpatch[pos.y] -- y
    if not ypatch then
        ypatch = {}
        xpatch[pos.y] = ypatch
    end

    local zpatch = ypatch[pos.z] -- z
    if not zpatch then
        zpatch = {
            oldBlockId = params.oldId or 0
        }
        ypatch[pos.z] = zpatch
    end
    zpatch.newBlockId = params.newId or 0
    if zpatch.newBlockId == zpatch.oldBlockId then
        ypatch[pos.z] = nil
    end

    if not params.notSave then
        saveChange()
    end
end

function MapPatchMgr.ObjectChange(map, params) -- params : change -> destroy/create/update, objId, pos, yaw, pitch, createByMapIndex, objPatchKey,
                                                    -- notSave, notNeedSaveToPatch, isEntity/isDropItem, fullName(entity), saveHp(entity), isStartAI(entity),
                                                    -- lifeTime(dropItem), item_type(dropItem), item_fullName(dropItem), 
                                                    -- block_id(dropItem), item_count(dropItem), item_moveSpeed(dropItem), item_moveTime(dropItem)
    -- notNeedSaveToPatch : 配置中决定该entity是否需要存补丁(比如游戏启动时动态根据配置创建，并且不受补丁影响的比如 初始点)
    -- notSave ： 暂时不存，比如在退出游戏时，先全部数据存到mgr中，然后才调用接口整体存盘
    if not checkEnableMapPatchMgr() or not map or params.notNeedSaveToPatch then
        return false
    end
    
    if params.change == "create" and params.createByMapIndex then -- cause this is create by map, not need save
        return false
    end

    if not params.objPatchKey then
        return
    end

    local mgr = (params.isEntity and map_entityMgr) or (params.isDropItem and map_dropItemMgr)
    if not mgr then
        return
    end

    local mapName = getMapName(map)
    local map_patch = mgr[mapName]
    if not map_patch then
        map_patch = {}
        mgr[mapName] = map_patch
    end

    if params.change == "destroy" and not params.createByMapIndex and map_patch[params.objPatchKey] then
        map_patch[params.objPatchKey] = nil
    else
        local map_patch_objPatchKey = map_patch[params.objPatchKey]
        if not map_patch_objPatchKey then
            map_patch_objPatchKey = {}
            map_patch[params.objPatchKey] = map_patch_objPatchKey
        end
        tableSave2TableByFiled(map_patch_objPatchKey, params)
    end

    if not params.notSave then
        saveChange()
    end
end

function MapPatchMgr.ForceSaveAll()
    if not checkEnableMapPatchMgr() then
        return false
    end
    saveChangeToPatchFile()
end

function MapPatchMgr.ForceUpdateObjectChange()
    -- 更新保存全部的entity的数据(只需要entity，dropItem不会移动，block不会移动， 静态的不会动的entity不需要保存(即未启用ai的不需要保存)。)
    -- 更新保存 位置/角度/血量/ai
    if not checkEnableMapPatchMgr() then
        return false
    end
    local entitys = curWorld:getAllEntity()
    if not entitys then
        return
    end
    resetSaveProp()
    for _, entity in pairs(entitys) do
        if checkEntityIsEnableAI(entity) then
            local pos = entity:getPosition()
            MapPatchMgr.ObjectChange(entity.map, {
                pos = {x = pos.x, y = pos.y, z = pos.z}, yaw = entity:getRotationYaw(), pitch = entity:getRotationPitch(),saveHp = entity.curHp, 
                change = "update", objPatchKey = entity.objPatchKey, isEntity = true, notSave = true, createByMapIndex = entity.createByMapIndex,
                isStartAI = true
            })
        end
    end
    MapPatchMgr.ForceSaveAll()
end

local saveall_timer = nil
function MapPatchMgr.ForceUpdateObjectChangeTimer(time)
    if not checkEnableMapPatchMgr() then
        return false
    end
    if saveall_timer then
        saveall_timer()
    end
    saveall_timer = World.Timer(time or saveTimerTime,function()
        MapPatchMgr.ForceUpdateObjectChange()
        return true
    end)
end

-- *********************************************** --
----------------------------------------------------- reload method
local function reloadBlockChangeFromPatch(map, changeBlocks)
    local temp = {}
    for x, yzBlockTable in pairs(changeBlocks) do
        for y, zBlockTable in pairs(yzBlockTable) do
            for z, blockTable in pairs(zBlockTable) do
                local pos = {x = tonumber(x), y = tonumber(y), z = tonumber(z)}
                temp[#temp + 1] = {pos = pos, blockId = blockTable.newBlockId}
            end
        end
    end
    map:batchSetBlockConfigId(temp)
end

local function updateObjectProp(obj, tb)
    if tb.pos then
        obj:setPosition(tb.pos)
    end
    if tb.yaw then
        obj:setRotationYaw(tb.yaw)
    end
    if tb.pitch then
        obj:setRotationPitch(tb.pitch)
    end
    if tb.saveHp then
        obj:setHp(tb.saveHp)
    end
    if tb.isStartAI and not checkEntityIsEnableAI(obj) then
        obj:startAI()
    end
end

local function updateCreateByMapObject(tb, objID, params) -- params ->{isEntity, isDropItem}
    if not objID then
        return
    end
    local obj = curWorld:getObject(objID)
    if not obj then
        return
    end
    if tb.change == "destroy" then
        obj.notNotifyMapPatchMgr = true
        if params.isEntity then
            obj:kill()
        elseif params.isDropItem then
            obj:destroy()
        end
        return
    end
    updateObjectProp(obj, tb)
    if tb.objPatchKey then
        obj.objPatchKey = tb.objPatchKey
    end
end

local function reloadEntityChangeFromPatch(map, changeEntitys)
    for objPatchKey, tb in pairs(changeEntitys) do
        if tb.createByMapIndex and tb.createByMapIndex > 0 then
            local objID = createByMapEntityTable[tb.createByMapIndex]
            updateCreateByMapObject(tb, objID, {isEntity = true})
        else
            local obj = EntityServer.Create({map = map, pos = tb.pos, ry = tb.yaw, rp = tb.pitch, objPatchKey = tb.objPatchKey, 
                cfgName = tb.fullName, notNotifyMapPatchMgr = true})
            updateObjectProp(obj, tb)
        end
    end
end

local function reloadDropItemChangeFromPatch(map, changeDropItems)
    for objPatchKey, tb in pairs(changeDropItems) do
        if tb.createByMapIndex and tb.createByMapIndex > 0 then
            local objID = createByMapDropItemTable[tb.createByMapIndex]
            updateCreateByMapObject(tb, objID, {isDropItem = true})
        else
            local item = Item.CreateItem(tb.item_fullName, tb.item_count or 1, function(dropItem)
                if tb.item_fullName == "/block" then
                    dropItem:set_block_id(tb.block_id or 0)
                end
            end)
            DropItemServer.Create({map = map, pos = tb.pos, yaw = tb.yaw, pitch = tb.pitch, lifeTime = tb.lifeTime, item = item,
                objPatchKey = tb.objPatchKey, notNotifyMapPatchMgr = true, moveSpeed = tb.item_moveSpeed, moveTime = tb.item_moveTime})
        end
    end
end

local function reloadChange(map, patchFilepath)
    local cfg = assert(Lib_read_json_file(patchFilepath), "map_patch_mgr:reloadChange path error.path:" .. patchFilepath)
    if cfg.changeBlocks then
        reloadBlockChangeFromPatch(map, cfg.changeBlocks)
    end
    if not World.isClient then -- 暂时只让服务器处理obj
       if cfg.changeEntitys then
            reloadEntityChangeFromPatch(map, cfg.changeEntitys)
       end
       if cfg.changeDropItems then
            reloadDropItemChangeFromPatch(map, cfg.changeDropItems)
       end
    end

end

local function reloadWorldTime()
    local rootPatchPath = getAndCreatePatchRootDir(getAndCreateMapDir())
    if not rootPatchPath then
        return
    end
    local worldTimePatchFile = rootPatchPath .. "/worldTime.json"
    checkOrCreatePatchFile(worldTimePatchFile)
    local cfg = assert(Lib_read_json_file(worldTimePatchFile), "map_patch_mgr:reloadWorldTime path error.path:" .. worldTimePatchFile)
    local worldTime = cfg.worldTime
    if not worldTime then
        return
    end
    setWorldTime(tonumber(worldTime))
end

----------------------------------------------------- merge/clear method
local function mergePatchFileEntity2MapSetting(mapSettingPath, patchFile)
    if not checkFile(patchFile) then
        return
    end
    local patch_cfg = assert(Lib_read_json_file(patchFile), "map_patch_mgr:mergePatchFileEntity2MapSetting path error.path:" .. patchFile)
    local setting_cfg = assert(Lib_read_json_file(mapSettingPath), "map_patch_mgr:mergePatchFileEntity2MapSetting path error.path:" .. mapSettingPath)
    if not patch_cfg or not patch_cfg.changeEntitys or not setting_cfg then
        return
    end
    local setting_cfg_entitys = setting_cfg.entity
    if not setting_cfg_entitys then
        setting_cfg_entitys = {}
        setting_cfg.entity = setting_cfg_entitys
    end
    local patch_cfg_changeEntitys = patch_cfg.changeEntitys
    for _, tb in pairs(patch_cfg_changeEntitys) do
        if tb.createByMapIndex and tb.createByMapIndex > 0 then
            if tb.change == "destroy" then
                setting_cfg_entitys[tb.createByMapIndex] = {isDelete = true}
            else
                local setting_cfg_entitys_createByMapIndex = setting_cfg_entitys[tb.createByMapIndex]
                setting_cfg_entitys_createByMapIndex.pos = tb.pos
                setting_cfg_entitys_createByMapIndex.ry = tb.yaw
                setting_cfg_entitys_createByMapIndex.rp = tb.pitch
                setting_cfg_entitys_createByMapIndex.objPatchKey = tb.objPatchKey
            end
        else
            setting_cfg_entitys[#setting_cfg_entitys + 1] = {
                pos = tb.pos,
                ry = tb.yaw,
                rp = tb.pitch,
                objPatchKey = tb.objPatchKey,
                cfg = tb.fullName,
                derive = {
                    aiData = tb.isStartAI and {} or nil
                }
            }
        end
    end
    if #setting_cfg_entitys > 0 then
        for i = #setting_cfg_entitys, 1, -1 do
            if setting_cfg_entitys[i].isDelete then
                table.remove(setting_cfg_entitys, i)
            end
        end
    end
    local file = io_open(mapSettingPath, "w+")
    saveJson(mapSettingPath, setting_cfg or {})
    clearPatchFile(patchFile)
end

local function mergePatchFileDropItem2MapSetting(mapSettingPath, patchFile)
    if not checkFile(patchFile) then
        return
    end
    local patch_cfg = assert(Lib_read_json_file(patchFile), "map_patch_mgr:mergePatchFileDropItem2MapSetting path error.path:" .. patchFile)
    local setting_cfg = assert(Lib_read_json_file(mapSettingPath), "map_patch_mgr:mergePatchFileDropItem2MapSetting path error.path:" .. mapSettingPath)
    if not patch_cfg.changeDropItems or not setting_cfg then
        return
    end
    local setting_cfg_items = setting_cfg.item
    if not setting_cfg_items then
        setting_cfg_items = {}
        setting_cfg.item = setting_cfg_items
    end
    local patch_cfg_changeDropItems = patch_cfg.changeDropItems
    for _, tb in pairs(patch_cfg_changeDropItems) do
        if tb.createByMapIndex and tb.createByMapIndex > 0 then
            if tb.change == "destroy" then
                setting_cfg_items[tb.createByMapIndex] = {isDelete = true}
            else
                local setting_cfg_items_createByMapIndex = setting_cfg_items[tb.createByMapIndex]
                setting_cfg_items_createByMapIndex.pos = tb.pos
                setting_cfg_items_createByMapIndex.ry = tb.yaw
                setting_cfg_items_createByMapIndex.rp = tb.pitch
                setting_cfg_items_createByMapIndex.objPatchKey = tb.objPatchKey
            end
        else
            setting_cfg_items[#setting_cfg_items + 1] = {
                pos = tb.pos,
                ry = tb.yaw,
                rp = tb.pitch,
                objPatchKey = tb.objPatchKey,
                count = tb.item_count,
                cfg = tb.item_fullName,
                blockID = tb.block_id
            }
        end
    end
    if #setting_cfg_items > 0 then
        for i = #setting_cfg_items, 1, -1 do
            if setting_cfg_items[i].isDelete then
                table.remove(setting_cfg_items, i)
            end
        end
    end
    saveJson(mapSettingPath, setting_cfg or {})
    clearPatchFile(patchFile)
end

local isReloadBlock = false
local function mergeMapBlockPatch2MapSetting() -- 注：该方法需要启动编辑模式后动态调用该方法
    isReloadBlock = true
    local mapNames = getMapsNameList()
    for _, mapName in ipairs(mapNames) do
        local patchFilepath = getMapPatchFilePathByMapName(mapName, "block")
        if checkFile(patchFilepath) then
            local cfg = assert(Lib_read_json_file(patchFilepath), "map_patch_mgr:mergeMapBlockPatch2MapSetting path error.path:" .. patchFilepath)
            if cfg.changeBlocks then
                local map = curWorld:loadMap(curWorld:nextMapId(), mapName, false, {openedExclusively = true})
                reloadBlockChangeFromPatch(map, cfg.changeBlocks)
                map:saveChanges()
                clearPatchFile(patchFilepath)
                map:close()
            end
        end
    end
    isReloadBlock = false
end

function MapPatchMgr.MergeMapPatch2MapSetting()
    if not enableMapPatch then
        return
    end
    local mapRootDir = getAndCreateMapDir()
    local mergeFile = mapRootDir .. "needMergePatch.flag"
    if not lfs_attributes(mergeFile, "mode") then
        return
    end
    local mapNames = getMapsNameList()
    for _, mapName in ipairs(mapNames) do
        local mapSettingPath = getMapSettingFilePathByMapName(mapName)
        if checkFile(mapSettingPath) then
            mergePatchFileEntity2MapSetting(mapSettingPath, getMapPatchFilePathByMapName(mapName, "entity"))
            mergePatchFileDropItem2MapSetting(mapSettingPath, getMapPatchFilePathByMapName(mapName, "dropItem"))
        end
    end
    mergeMapBlockPatch2MapSetting()
    os.remove(mergeFile)
    removeAllPatchDir()
end

function MapPatchMgr.ClearAllPatchFile()
    if not enableMapPatch then
        return
    end
    local mapRootDir = getAndCreateMapDir()
    local mergeFile = mapRootDir .. "needRemovePatch.flag"
    if not lfs_attributes(mergeFile, "mode") then
        return
    end
    local mapNames = getMapsNameList()
    for _, mapName in ipairs(mapNames) do
        clearPatchFile(getMapPatchFilePathByMapName(mapName, "entity"))
        clearPatchFile(getMapPatchFilePathByMapName(mapName, "dropItem"))
        clearPatchFile(getMapPatchFilePathByMapName(mapName, "block"))
    end
    os.remove(mergeFile)
    removeAllPatchDir()
end

function MapPatchMgr.CheckDealWithMapPatch()
    -- if not checkPatchIsNeedOperating() then
    --     checkAndRemoveAllFlagFile()
    --     return
    -- end
    MapPatchMgr.MergeMapPatch2MapSetting()
    MapPatchMgr.ClearAllPatchFile()
end

----------------------------------------------------- setup logic
--[[
    TODO 玩家的数据
]]
function MapPatchMgr.RegistCreateByMapEntityToTable(objID, createByMapIndex)
    if not checkEnableMapPatchMgr() or not createByMapIndex then
        return false
    end
    createByMapEntityTable[createByMapIndex] = objID
end

function MapPatchMgr.RegistCreateByMapDropItemToTable(objID, createByMapIndex)
    if not checkEnableMapPatchMgr() or not createByMapIndex then
        return false
    end
    createByMapDropItemTable[createByMapIndex] = objID
end

function MapPatchMgr.ClearCreateByMapObjTable()
    createByMapEntityTable = {}
    createByMapDropItemTable = {}
end

local firstIn = false
local firstLoad = false
function MapPatchMgr.ReloadPatch(map)
    if not checkEnableMapPatchMgr() or isReloadBlock then
        return false
    end
    -- if not checkPatchIsNeedOperating() then
    --     checkAndRemoveAllFlagFile()
    --     return false
    -- end
    if not firstIn then
        firstIn = true
        World.Timer(20, function()
            if map:isValid() then
                MapPatchMgr.ReloadPatch(map) 
            end
        end)
        -- waiting the world init when first setup game.
        return
    end
    if not firstLoad then
        firstLoad = true
        reloadWorldTime()
    end
    local patchDir = getAndCreatePatchDir(getAndCreateMapDir(), map.name, true)
    if not patchDir then
        return
    end
    local filePathArr = {}
    for fileName in lfs_dir(patchDir) do
        if fileName ~= "." and fileName ~= ".." then
            local filepath = patchDir .. "/" .. fileName
            local fileattr = lfs_attributes(filepath, "mode")
            if fileattr and fileattr == "file" then
                reloadChange(map, filepath)
            end
        end
    end
    MapPatchMgr.ClearCreateByMapObjTable()
end