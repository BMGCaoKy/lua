-- * 用于生成存库的序列化压缩的地图chunk数据，适用于需要存库并且数据量大的场合
local DBHandler = require "dbhandler" ---@type DBHandler

local seri = require "seri"
local misc = require "misc"
local cjson = require "cjson"
local setting = require "common.setting"
--[[
    seri.deseristring_string(misc.base64_decode(txt))
    misc.base64_encode(seri.serialize_string(data))
]]

local worldCfg = World.cfg
local enableChunkSaveRemote = worldCfg.enableChunkSaveRemote

local math_floor = math.floor

-- test code -- TODO DEL
local misc = require "misc"
local now_nanoseconds = misc.now_nanoseconds
local function getTime()
    return now_nanoseconds() / 1000000
end
-- test code end

-- !!! map must have ownerPlatformUserId(a player userId) !!!
-- !!! 玩家的地图创建时必须设置所属owner ===> ownerPlatformUserId 所属玩家的userId !!!
--[[
    chunkSize = {x = 16, y = 256, z = 16}
    one db save data max size : 400k
    one chunk data 
        max size = 96k
        min size = 1 byte
]]
--[[
                       curMapId
    player --------------------------------> map
    player <-------------------------------- map
                  owner(owner player)

    ==== local data ====
    _localChunkOrderTables = {
        [player_platformUserId] = {
            [chunkOrderTable] = xxx
        }
        ..
    }

    玩家本地存着数据的表，暂存，别的玩家如果进来的时候，可以直接从这取，不用去询问数据库，这边取了没有并且orderTable能查询到数据库有改变，那才去数据库拿.
    假设一个玩家15M，30个玩家满额450M.
    这个表可以包含本地刚序列化要存的/从数据库拿的.
    _localChunkDataMap = {
        [player_platformUserId] = {
            [x] = {
                [z] = {
                    isZip = xx,
                    chunkBuffSize = xx,
                    data = xx
                }
            }
        }
    }

    玩家的地图改变时会更新这个表，玩家上传后会清空这个表(只改变/清空对应玩家的)
    _localChangeChunkMap = {
        [player_platformUserId] = {
            [x] = {
                [z] = true
            }
        }
        ..
    }
    ==== database data ====
    -- subKey
    玩家身上有一个表存着自己的chunk+order的chunkOrderTable,用来看玩家指定需要取哪个chunk的时候，传的subKey, 这个表需要跟随玩家存库
    直接用subKey -> 1000 来存服务器
    subKey == 1000
    chunkOrderTable = {
        lastSubDataKey = n,
        orderKey2subKeyMap = {
            orderKey1 = subKey1, orderKey2 = subKey2,...
        },
        subKey2orderKeyMap = {
            subKey1 = orderKey1, subKey2 = orderKey2,...
        }
        orderKey1 = { -- 一个chunk一条数据 chunkOrder_x_z
            [x] = {
                [z] = true
            },
        }
        ..
    }

    存数据库用subkey取的数据
    subkey {
        [x] = {
            [z] = {
                isZip = xx,
                chunkBuffSize = xx,
                data = xx
            }
        }
    }
    subkey2(dataKey2){
        xxx
    }
]]
------------------------------------------ local logic func
local _localChunkOrderTables = L("_localChunkOrderTables", {})
local _localChunkDataMap = L("_localChunkDataMap", {})
local _localChangeChunkMap = L("_localChangeChunkMap", {})
-- local _localRenderChunkPosArr =  L("_localRenderChunkPosArr", {})
local function reset()
    _localChunkOrderTables = {}
    _localChangeChunkMap = {}
    _localChunkDataMap = {}
    -- _localRenderChunkPosArr = {}
end

local function gerOrCreateTableInDataMapWithPlatformUserId(dataMap, platformUserId, defaultValue)
    local ret = dataMap[platformUserId]
    if not ret then
        ret = defaultValue or {}
        dataMap[platformUserId] = ret
    end
    return ret
end

local function updateTableDataWithChunkPos(dataMap, chunkPos, value)
    local xMap = dataMap[chunkPos.x]
    if not xMap then
        xMap = {}
        dataMap[chunkPos.x] = xMap
    end
    xMap[chunkPos.z] = value
end

local function getDataInDataMapWithChunkPos(dataMap, chunkPos)
    local xMap = dataMap[chunkPos.x]
    if not xMap then
        return false
    end
    return xMap[chunkPos.z]
end

local function chunkPos2orderKey(chunkPos)
    return "chunkOrder_" .. chunkPos.x .. "_" .. chunkPos.z
    -- return "chunkOrder_" .. math_floor(chunkPos.x/2) .. "_" .. math_floor(chunkPos.z/2)
end

local function getLocalChunkDataMap(map)
    local _localChunkDataMap = map._localChunkDataMap
    if not _localChunkDataMap then
        _localChunkDataMap = {}
        map._localChunkDataMap = _localChunkDataMap
    end
    return _localChunkDataMap
end

local function getLocalRenderChunkPosArr(map)
    local _localRenderChunkPosArr = map._localRenderChunkPosArr
    if not _localRenderChunkPosArr then
        _localRenderChunkPosArr = {}
        map._localRenderChunkPosArr = _localRenderChunkPosArr
    end
    return _localRenderChunkPosArr
end
------------------------------------------ other local func
local defaultChunkOrderTable = {
    lastSubDataKey = 1000,
    orderKey2subKeyMap = {},
    subKey2orderKeyMap = {}
}
local function updatePlayerChunkOrderTable(platformUserId, orderKey, chunkPos)
    local playerChunkOrderTable = gerOrCreateTableInDataMapWithPlatformUserId(_localChunkOrderTables, platformUserId, Lib.copy(defaultChunkOrderTable))
    local orderTable = playerChunkOrderTable[orderKey]
    if not orderTable then
        orderTable = {}
        playerChunkOrderTable[orderKey] = orderTable

        local lastSubDataKey = playerChunkOrderTable.lastSubDataKey
        lastSubDataKey = lastSubDataKey + 1
        playerChunkOrderTable.lastSubDataKey = lastSubDataKey
        playerChunkOrderTable.orderKey2subKeyMap[orderKey] = lastSubDataKey
        playerChunkOrderTable.subKey2orderKeyMap[lastSubDataKey] = orderKey
    end
    
    local xTb = orderTable[chunkPos.x]
    if not xTb then
        xTb = {}
        orderTable[chunkPos.x] = xTb
    end
    xTb[chunkPos.z] = true
end

local function globalCheck(map)
    if not enableChunkSaveRemote then
        return false
    end
    if not map or not map:isValid() then
        return false
    end

    return true
end

local function checkMapOwner(map)
    local ownerPlatformUserId = map:getVar("ownerPlatformUserId")
    if not ownerPlatformUserId then
        return false
    end
    -- todo ex
    return true
end
------------------------------------------ local database func
local playerChunkOrderTableKey = 1000
local function savePlayerChunkOrderTable2DB(platformUserId, data)
    -- print("savePlayerChunkOrderTable2DB ::::::: player, data ::::::: ", platformUserId, data)
    DBHandler:setData(platformUserId, playerChunkOrderTableKey, data, true)
end

local function getPlayerChunkOrderTableInDB(platformUserId, callBackFunc, getDataPlayer)
    local t_ret = Lib.copy(defaultChunkOrderTable)
    DBHandler:getDataByUserId(platformUserId, playerChunkOrderTableKey, 
    function(userId, data)
        local ret
        if data then
            ret = seri.deseristring_string(misc.base64_decode(data))
        end
        if not ret or not ret.lastSubDataKey then
            ret = t_ret
        end
        _localChunkOrderTables[platformUserId] = ret
        callBackFunc(ret)
    end, 
    function(userId, isEmptyData)
        if isEmptyData then
            _localChunkOrderTables[platformUserId] = t_ret
            callBackFunc(t_ret)
        else
            print(" get player chunk order table error. userId : ", userId, ", getDataPlayer userId ", getDataPlayer and getDataPlayer.platformUserId or nil)
            if getDataPlayer and getDataPlayer:isValid() then
                Game.KickOutPlayer(getDataPlayer)    
            end
        end
    end)
end

local function saveChunk2DB(platformUserId, subKey, data)
    -- print("saveChunk2DB ::::::: player, subKey, data ::::::: ", platformUserId, subKey, data)
    DBHandler:setData(platformUserId, subKey, data, true)
end

local function savePlayerChunk2DB(map)
    map.isSaving = true
    -- local beginTime = getTime() -- todo del
    local platformUserId = map:getVar("ownerPlatformUserId")
    local changeChunkMap = _localChangeChunkMap[platformUserId]
    if not changeChunkMap or not next(changeChunkMap) then
        map.isSaving = false
        return false
    end
    local _localRenderChunkPosArr = getLocalRenderChunkPosArr(map)
    local sendChangeChunkMapPlayers = {}
    for player_platformUserId, _ in pairs(_localRenderChunkPosArr) do
        sendChangeChunkMapPlayers[#sendChangeChunkMapPlayers + 1] = player_platformUserId
    end

    local playerChunkDataMap = gerOrCreateTableInDataMapWithPlatformUserId(_localChunkDataMap, platformUserId)
    local tempSaveDataKeys = {}
    for _x, zMap in pairs(changeChunkMap) do
        for _z in pairs(zMap) do
            local chunkPos = {x = _x, z = _z}
            local ret = map:serializerChunkData(chunkPos) -- ret = { isZip = is zip string, chunkBuffSize = before zip data size, data = after zip data}
            -- ret.data = misc.base64_encode(seri.serialize_string(ret.data))
            updateTableDataWithChunkPos(playerChunkDataMap, chunkPos, ret)
            local orderKey = chunkPos2orderKey(chunkPos)
            updatePlayerChunkOrderTable(platformUserId, orderKey, chunkPos)
            tempSaveDataKeys[orderKey] = true

            for _, player_platformUserId in pairs(sendChangeChunkMapPlayers) do
                local player = Game.GetPlayerByUserId(player_platformUserId)
                if player and player:isValid() then
                    player:sendPacket(
                        {
                            pid = "RecalcCacheChunkData",
                            mapId = map.id,
                            chunkPos = chunkPos,
                            data = ret
                        })
                end
            end
        end
    end
    local chunkOrderTable = _localChunkOrderTables[platformUserId]
    for orderKey in pairs(tempSaveDataKeys) do
        local tempData = {}
        local needSave = false
        for _x, zTb in pairs(chunkOrderTable[orderKey]) do
            for _z in pairs(zTb) do
                local temp = getDataInDataMapWithChunkPos(playerChunkDataMap, {x = _x, z = _z})
                if temp then
                    needSave = true
                    updateTableDataWithChunkPos(tempData, {x = _x, z = _z}, temp)
                end
            end
        end
        local subKey = chunkOrderTable.orderKey2subKeyMap[orderKey]
        if needSave and subKey then
            saveChunk2DB(platformUserId, subKey, misc.base64_encode(seri.serialize_string(tempData)))
        end
    end
    savePlayerChunkOrderTable2DB(platformUserId, misc.base64_encode(seri.serialize_string(chunkOrderTable)))
    _localChangeChunkMap[platformUserId] = {}
    map:clearBlockIdChanges()
    -- print(" common function savePlayerChunk2DB(map) ", getTime() - beginTime) -- todo del
    map.isSaving = false
    return true
end

local function sendDataToGetDataPlayer(map, getDataPlayer, data)
    if not getDataPlayer then
        return
    end
    getDataPlayer:sendPacket(
        {
            pid = "ChunkData",
            mapId = map.id,
            data = data
        }
    )
end

local function getChunkInDBFail(player)
	if player and player:isValid() then
        Game.KickOutPlayer(player)
    end
end

local function getChunkInDB(map, platformUserId, subKey, getDataPlayer)
    local playerChunkDataMap = gerOrCreateTableInDataMapWithPlatformUserId(_localChunkDataMap, platformUserId)
    DBHandler:getDataByUserId(platformUserId, subKey, 
    function(userId, data)
        local chunkData = seri.deseristring_string(misc.base64_decode(data))
        if not chunkData or not map or not map:isValid() or not getDataPlayer or not getDataPlayer:isValid() then
            return
        end
        if type(chunkData) ~= "table" then
            print(" get player map chunk data error. chunkData got string, userId : ", userId)
            getChunkInDBFail(getDataPlayer)
            return
        end
        local serverDesiTb = {}
        for _x, zTb in pairs(chunkData or {}) do
            for _z, dataTb in pairs(zTb or {}) do
                serverDesiTb[#serverDesiTb + 1] = {
                    x = _x,
                    z = _z,
                    isZip = dataTb.isZip,
                    data = dataTb.data,
                    chunkBuffSize = dataTb.chunkBuffSize
                }
            end
        end
        -- local begin = getTime()
        local notFullSetChunkMap = map:deserializerChunkData(serverDesiTb)
        if notFullSetChunkMap.gzUncompressFail then -- test
            print(" get player map chunk data error. deserializerChunkData error, userId : ", userId)
            getChunkInDBFail(getDataPlayer)
            return
        end

        local chunks = {}
        for _x, zTb in pairs(chunkData or {}) do
            for _z, dataTb in pairs(zTb or {}) do
                chunks[#chunks + 1] = {x = _x, z = _z}
                updateTableDataWithChunkPos(playerChunkDataMap, {x = _x, z = _z}, dataTb)
            end
        end
        sendDataToGetDataPlayer(map, getDataPlayer, serverDesiTb)
        -- print(" getChunkInDB deserializerChunkData ",getTime()-begin)
        MapChunkMgr.onServerDesiFinish(map, platformUserId, subKey, getDataPlayer, chunks)
    end, 
    function(userId)
        print(" get player map chunk data error. userId : ", userId, subKey)
        getChunkInDBFail(getDataPlayer)
    end)
end

local function checkPlayerHasLocalData(map, dataMap, platformUserId, getDataPlayer)
    local playerChunkDataMap = gerOrCreateTableInDataMapWithPlatformUserId(_localChunkDataMap, platformUserId)
    local sendPack = {}
    for _x, zTb in pairs(dataMap or {}) do
        for _z in pairs(zTb or {}) do
            local dataTb = playerChunkDataMap[_x] and playerChunkDataMap[_x][_z]
            if dataTb then
                sendPack[#sendPack+1] = {
                    x = _x,
                    z = _z,
                    isZip = dataTb.isZip,
                    data = dataTb.data,
                    chunkBuffSize = dataTb.chunkBuffSize
                }
            else
                return false
            end
        end
    end
    sendDataToGetDataPlayer(map, getDataPlayer, sendPack)
    return true
end

local function getPlayerChunkInDB(map, chunkPosArr, getDataPlayer)
    -- local beginTime = getTime() -- todo del
    local platformUserId = map:getVar("ownerPlatformUserId")
    local playerChunkOrderTable = _localChunkOrderTables[platformUserId]
    local tempHadGetOrderKeyTable = {}
    local setupChunk = function(inPlayerChunkOrderTable)
        local orderKey2subKeyMap = inPlayerChunkOrderTable.orderKey2subKeyMap
        for _x, zTb in pairs(chunkPosArr) do
            for _z in pairs(zTb) do
                local chunkPos = {x = _x, z = _z}
                local orderKey = chunkPos2orderKey(chunkPos)
                if tempHadGetOrderKeyTable[orderKey] then
                    goto CONTINUE
                end
                tempHadGetOrderKeyTable[orderKey] = true
                if not inPlayerChunkOrderTable[orderKey] then
                    goto CONTINUE
                end
                if checkPlayerHasLocalData(map, inPlayerChunkOrderTable[orderKey], platformUserId, getDataPlayer) then
                    goto CONTINUE
                end
                local subKey = orderKey2subKeyMap[orderKey]
                getChunkInDB(map, platformUserId, subKey, getDataPlayer)
                ::CONTINUE::
            end
        end
    end
    if playerChunkOrderTable and playerChunkOrderTable.lastSubDataKey and playerChunkOrderTable.lastSubDataKey > 0 then
        setupChunk(playerChunkOrderTable)
        -- print(" common getPlayerChunkInDB 1", getTime() - beginTime) -- todo del
        return
    end
    getPlayerChunkOrderTableInDB(platformUserId, setupChunk, getDataPlayer)
    -- print(" common getPlayerChunkInDB 2", getTime() - beginTime) -- todo del
end
------------------------------------------ out func
function MapChunkMgr.init()
    reset()
end

function MapChunkMgr.reset()
    reset()
end

function MapChunkMgr.setMapChunkChange(map, chunkPos)
    if not globalCheck(map) then
        return false
    end
    if not checkMapOwner(map) then
        return false
    end
    if not chunkPos or not chunkPos.x or not chunkPos.z then
        return false
    end
    -- local beginTime = getTime() -- todo del
    updateTableDataWithChunkPos(gerOrCreateTableInDataMapWithPlatformUserId(_localChangeChunkMap, map:getVar("ownerPlatformUserId")), chunkPos, true)
    -- print(" common MapChunkMgr.setMapChunkChange(map, chunkPos) ", getTime() - beginTime) -- todo del
end

function MapChunkMgr.saveMapChunkToDB(map)
    if not globalCheck(map) then
        return false
    end
    if not checkMapOwner(map) then
        return false
    end
    return savePlayerChunk2DB(map)
end

function MapChunkMgr.clearMapMgrData(map)
    if not globalCheck(map) then
        return false
    end
    if not checkMapOwner(map) then
        return false
    end
    local platformUserId = map:getVar("ownerPlatformUserId")
    _localChunkDataMap[platformUserId] = nil
    _localChunkOrderTables[platformUserId] = nil
    -- _localRenderChunkPosArr[platformUserId] = nil
end

function MapChunkMgr.getMapChunkInDB(map, getDataPlayer, chunkPosArr)
    if not globalCheck(map) then
        return false
    end
    if not checkMapOwner(map) then
        return false
    end
    if not getDataPlayer or not getDataPlayer:isValid() or not getDataPlayer.isPlayer then
        return false
    end
    return getPlayerChunkInDB(map, chunkPosArr, getDataPlayer)
end

function MapChunkMgr.getMapChunkInDBWithInit(map) -- 注：该函数需要在map创建完并且设置ownerUserId后马上调用，先预先去数据库拿玩家要进去的位置周围的chunk
    -- local begin = getTime()
    if not globalCheck(map) then
        return false
    end
    if not checkMapOwner(map) then
        return false
    end
    local platformUserId = map:getVar("ownerPlatformUserId")
    local mapInitPos = WorldServer.defaultMap.cfg.initPos or World.cfg.initPos
    if not mapInitPos then
        return false
    end
    local chunkPos = {x = math_floor(mapInitPos.x / 16), z = math_floor(mapInitPos.z / 16)}
    local chunkPosArr = {}
    for i = chunkPos.x-1, chunkPos.x+1 do
        if not chunkPosArr[i] then
            chunkPosArr[i] = {}
        end
        for j = chunkPos.z-1, chunkPos.z+1 do
            chunkPosArr[i][j] = 1
        end
    end
    getPlayerChunkInDB(map, chunkPosArr)
    -- print(" getMapChunkInDBWithInit ", getTime()-begin)
end

function MapChunkMgr.getMapChunkWithLocal(map)
    if not globalCheck(map) then
        return false
    end
    if not checkMapOwner(map) then
        return false
    end
    local platformUserId = map:getVar("ownerPlatformUserId")
    local playerChunkDataMap = gerOrCreateTableInDataMapWithPlatformUserId(_localChunkDataMap, platformUserId)
    local mapInitPos = WorldServer.defaultMap.cfg.initPos or World.cfg.initPos
    if not mapInitPos then
        return false
    end
    local chunkPos = {x = math_floor(mapInitPos.x / 16), z = math_floor(mapInitPos.z / 16)}
    local ret = {}
    for i = chunkPos.x-1, chunkPos.x+1 do
        for j = chunkPos.z-1, chunkPos.z+1 do
            if playerChunkDataMap[i] and playerChunkDataMap[i][j] then
                local dataTb = playerChunkDataMap[i][j]
                table.insert(ret, {
                    x = i,
                    z = j,
                    isZip = dataTb.isZip,
                    data = dataTb.data,
                    chunkBuffSize = dataTb.chunkBuffSize
                })
            end
        end
    end
    return ret
end

function MapChunkMgr.renderRangeChange(map, player, minRenderChunkPos, maxRenderChunkPos)
    -- local begin = getTime()
	local chunkPosArr = {}
    if not globalCheck(map) then
        return false
    end
    if not checkMapOwner(map) then
        return false
    end
    if map.isSaving then
        return
    end
    local platformUserId = player.platformUserId
    local _localRenderChunkPosArr = getLocalRenderChunkPosArr(map)
	local playerSaveChunkPosArr = _localRenderChunkPosArr[platformUserId]
	if not playerSaveChunkPosArr then
		playerSaveChunkPosArr = {}
		_localRenderChunkPosArr[platformUserId] = playerSaveChunkPosArr
	end
	for x = minRenderChunkPos.x, maxRenderChunkPos.x do
		for z = minRenderChunkPos.z, maxRenderChunkPos.z do
			if playerSaveChunkPosArr[x] and playerSaveChunkPosArr[x][z] then
				goto CONTINUE
			end
			local xTb = playerSaveChunkPosArr[x]
			if not xTb then
				xTb = {}
				playerSaveChunkPosArr[x] = xTb
			end
			xTb[z] = 1
			
			local xTb2 = chunkPosArr[x]
			if not xTb2 then
				xTb2 = {}
				chunkPosArr[x] = xTb2
			end
			xTb2[z] = 1
			
			::CONTINUE::
		end
	end
	if not next(chunkPosArr) then
		return
	end
	MapChunkMgr.getMapChunkInDB(map, player, chunkPosArr)
    -- print(" renderRangeChange ", getTime()-begin)
end

function MapChunkMgr.onPlayerLoginOrLogout(player)
    -- local begin = getTime()
    if not enableChunkSaveRemote then
        return
    end
    for _, map in pairs(World.mapList or {}) do
        -- print("map .id", map.id)
        if not globalCheck(map) then
            goto CONTINUE
        end
        if not checkMapOwner(map) then
            goto CONTINUE
        end
        local platformUserId = player.platformUserId
        local _localRenderChunkPosArr = getLocalRenderChunkPosArr(map)
        _localRenderChunkPosArr[platformUserId] = nil
        -- print(" MapChunkMgr.onPlayerLoginOrLogout ================ ")
        ::CONTINUE::
    end
    -- print(" onPlayerLoginOrLogout ", getTime()-begin)
end

function MapChunkMgr.onServerDesiFinish(map, platformUserId, subKey, getDataPlayer, chunks)
    if not getDataPlayer or not getDataPlayer:isValid() then
        return
    end
    Lib.logInfo('onServerDesiFinish----------------', getDataPlayer.platformUserId)
    Trigger.CheckTriggers(getDataPlayer, "LOAD_BLOCKS_FINISH", {
        ownerPlatformUserId = map.ownerPlatformUserId,
        player = getDataPlayer,
        chunks = chunks
    })
    -- MapChunkMgr.PrintLocalData()
end
------------------------------------------ debug func
function MapChunkMgr.PrintLocalData()
    Lib.logInfo("_localChangeChunkMap %s", Lib.v2s(_localChangeChunkMap))
    Lib.logInfo("_localChunkDataMap %s", Lib.v2s(_localChunkDataMap, 5))
    Lib.logInfo("_localChunkOrderTables %s", Lib.v2s(_localChunkOrderTables, 5))
end