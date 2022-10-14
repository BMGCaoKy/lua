--[[
---@class World
---@field staticList table

World = World
]]

local lfs = require "lfs"
---@class setting
local setting = require "common.setting"
local World = World ---@type World
local mapList = T(World, "mapList")
local staticList = T(World, "staticList")
local nextRegionId = L("nextRegionId", 1)

local idRegions = T(World, "idRegions")
---@class Map
local Map = T(World, "Map")
Map.__index = Map
local Region = T(World, "Region", Region)
Region.__index = Region

local AllCfg = T(Map, "AllCfg")

--[[
	cacheMapObjs = {
		[mapId] = {
			id = map的id, mapObj = map的obj, effectiveTime = obj缓存有效时间, cacheTime = obj缓存时的时间
		}
	}
]]
local cacheMapObjs = T(World, "cacheMapObjs", {})
local checkCacheMapObjTimer = T(World, "checkCacheMapObjTimer", false)

--下面这个for循环请不要在业务层重写，不然会造成lua和c++调用时序混乱，有野指针风险
for k, v in pairs(MapInstance) do
    -- 复制MapInstance导出函数（不含导出成员变量）
    if k:sub(1, 2) ~= "__" and type(v) == "function" then
        Map[k] = function(self, ...)
            local obj = assert(self.obj, k)    -- map is closed
            return v(obj, ...)
        end
    end
end

local lastMapId = L("lastMapId", 0)

function World:nextMapId()
    repeat
        lastMapId = lastMapId + 1
        if lastMapId > 0x7fffffff then
            lastMapId = 1
        end
    until not mapList[lastMapId]
    return lastMapId
end

function World:getMapById(id)
    local ret = mapList[id]
    -- assert(ret and ret:isValid(), "World:getMapById(id) -> not map !!! id => " .. id)
    return ret
end

function World:getOrCreateStaticMap(name)
    return staticList[name] or self:loadMap(self:nextMapId(), name, true)
end

function World:getScene(map)
    local manager = World.CurWorld:getSceneManager()
    local scene = manager:getOrCreateScene(map)
    return scene
end

local function getMapObj(world, id, path, openedExclusively)
    local ret = cacheMapObjs[id]
    if ret and ((ret.effectiveTime + ret.cacheTime) >= World.Now()) then
        cacheMapObjs[id] = nil
        return ret.mapObj, true
    end
    return world:createMap(id, path, openedExclusively), false
end

local sourceMemoryMaps = {}
local function getSourceMemoryMap(self, dir)
    if not dir then
        return
    end
    local sourceMemoryMap = sourceMemoryMaps[dir]
    if sourceMemoryMap then
        return sourceMemoryMap
    end
    local id = self:nextLocalID()
    local path = dir .. "#MEMORY#_mapId=" .. id
    local mapObj = self:createMap(id, path, true)
    mapObj:copyStorageWithMemoryType(dir)
    sourceMemoryMaps[dir] = mapObj
    return mapObj
end

function World:reloadMap(map)
    local id = map.id
    local name = map.name
    local static = map.static
    --map:close()
    map:onCfgChanged()

    local cfg = Map.GetCfg(name)
    for key, region in pairs(cfg.region or {}) do
        map:removeRegion(key)
        map:addRegion(key, region.box.min, region.box.max, region.regionCfg)
    end

    for i, entity in ipairs(cfg.entity or {}) do
        map:addEntity(i, entity)
    end

    for i, item in ipairs(cfg.item or {}) do
        map:addItem(i, item.ry, item.pos, item.cfg, item.blockID)
    end

end

function World:loadMap(id, name, static)
    print("loadMap", id, name, static, World.CurWorld:checkEditor(0xFF))
    assert(not mapList[id], id)
    static = not not static
    if static then
        assert(not staticList[name], name)
    end

    local cfg = Map.GetCfg(name)
    local useRemoteMap = cfg.useRemoteMap
    local openedExclusively = World.CurWorld:checkEditor(0xFF) or World.gameCfg.editMap or useRemoteMap
    local dir = (Root.Instance():getGamePath() .. cfg.dir)
    local path = useRemoteMap and (dir .. "#MEMORY#_mapId=" .. id) or dir
    local mapObj, isCache = getMapObj(self, id, path, openedExclusively)
    if useRemoteMap then
        -- mapObj:copyStorageWithMemoryType(dir)
        mapObj:copyStorageWithMemoryMap(getSourceMemoryMap(self, dir))
    end
    local map = {
        id = id,
        name = name,
        dir = cfg.dir,
        cfg = cfg,
        static = static,
        world = self,
        obj = mapObj,
        objects = {},
        players = {},
        keyRegions = {},
        keyEntitys = {},
        keyItems = {},
        allBlockData = cfg.blockData or {},
        lastRegionSubKey = 0,
        newRegionInfos = {},
        delRegionInfos = {},
        timers = {},
        isClosing = false
    }

    mapList[id] = setmetatable(map, Map)
    if static then
        staticList[name] = map
    end

    for key, region in pairs(cfg.region or {}) do
        map:addRegion(key, region.box.min, region.box.max, region.regionCfg)
    end

    if Map.init then
        -- 留给client、server扩展
        map:init(isCache)
    end

    for i, entity in ipairs(cfg.entity or {}) do
        map:addEntity(i, entity)
    end

    for i, item in ipairs(cfg.item or {}) do
        map:addItem(i, item.ry, item.pos, item.cfg, item.blockID)
    end

    if cfg.cacheTimeout then
        map:setCacheTimeout(cfg.cacheTimeout)
    end

    if isCache then
        -- 暂时reloadMap之前 resetMap
        map:resetMap()
        map:reloadMap()
    else
        for _, collisionBoxTb in ipairs(cfg.staticCollisionBox or {}) do
            if map.addStaticCollisionBox then
                if collisionBoxTb.collider then
                    map:addStaticCollisionBox(collisionBoxTb.position, collisionBoxTb.collider, true)
                else
                    map:addStaticCollisionBox(collisionBoxTb.position, collisionBoxTb.boundingVolume, false)
                end
            end
        end
        map:loadMoveCfg({
            maxCanMoveSlope = cfg.maxCanMoveSlope,
            moveDownGravity = cfg.moveDownGravity,
        })

        if cfg.touchPosY then
            map:loadTouchPosY(cfg.touchPosY)
        end

        if cfg.useLod~=nil then
            map:setUseLod(cfg.useLod)
        end

        if cfg.touchupUnlimited then
            map:loadTouchupUnlimited({ touchupUnlimited = cfg.touchupUnlimited })
        end

        if cfg.isGridTerraria then
            print("createGridTerraria: ", map.dir)

            local gridTerrariaArg = {}
            gridTerrariaArg.name = cfg.sceneName
            gridTerrariaArg.path = "map/" .. map.name .. "/"
            gridTerrariaArg.maxCanMoveSlope = cfg.maxCanMoveSlope or 15.0
            gridTerrariaArg.moveDownGravity = cfg.moveDownGravity or 0.15
            gridTerrariaArg.baseHeight = cfg.baseHeight or 10.0
            gridTerrariaArg.enableMapVieDisCfg = false
            gridTerrariaArg.mapViewDisCfg = cfg.mapViewDisCfg or {}
            gridTerrariaArg.enableStaticMeshTextureLod = cfg.enableStaticMeshTextureLod or false
            gridTerrariaArg.enableStaticMeshTextureAutoLod = (cfg.enableStaticMeshTextureAutoLod ~= nil and { cfg.enableStaticMeshTextureAutoLod } or { true })[1]
            if cfg.mapViewDisCfg then
                gridTerrariaArg.enableMapVieDisCfg = true
            end
            local resGroupMgr = ResourceGroupManager:Instance()
            local zipResMgr = ZipResourceManager:Instance()
            local sub_dirs = {}
            local fullMapPath = Root.Instance():getGamePath() .. "map/" .. map.name .. '/'
            local mapBasePath = Root.Instance():getGamePath()
            local mapBaseLen = string.len(mapBasePath)
            print("full map  path: " .. fullMapPath .. " map base dir: " .. mapBasePath)
            Lib.getSubDirs(fullMapPath, sub_dirs)
            for _, dir in pairs(sub_dirs) do
                print("add gird sub dirs: " .. mapBasePath .. " dir: " .. dir)
                resGroupMgr:addResourceLocation(mapBasePath, "map/" .. map.name .. '/' .. dir, "FileSystem", "Custom", true)
            end
            zipResMgr:attachFilesToArchive("map/" .. map.name .. "/mesh", "GameZipArchive")
            zipResMgr:attachFilesToArchive("map/" .. map.name .. "/texture", "GameZipArchive")
            map:createGridTerraria(gridTerrariaArg)
            print("over create terraria")
        end

    end

    local manager = World.CurWorld:getSceneManager()
    local scene = self:getScene(mapObj)
    if World.isClient then
        manager:setCurScene(scene)
    end
    map:createSceneRegion()
    return map, isCache
end

local function onReload(cfg)
    for id, map in pairs(mapList) do
        if map.cfg == cfg then
            map:onCfgChanged()
        end
    end
end

function Map.GetCfg(name, force)
    local cfg = AllCfg[name]
    if cfg and not force then
        return cfg
    end
    cfg = setting:loadDir("map/" .. name .. "/", force)
    cfg.onReload = onReload
    AllCfg[name] = cfg
    return cfg
end

function Map:__tostring()
    return string.format("%s[%d]", self.name, self.id)
end

function Map:isValid()
    return self.obj ~= nil
end

function Map:getBlock(pos)
    local id = self:getBlockConfigId(pos)
    return Block.GetIdCfg(id)
end

function Map:loadCfg()
    self.cfg = Map.GetCfg(self.name, true)
end

function Map:addRegion(key, min, max, cfgName)
    assert(not self.keyRegions[key], key)
    if not (cfgName and #cfgName > 0) then
        return
    end
    local cfg = setting:fetch("region", cfgName)
    if not cfg then
        return
    end

    for k, v in pairs(min) do
        min[k] = math.floor(v)
    end
    for k, v in pairs(max) do
        max[k] = math.floor(v)
    end

    local region = {
        cfg = cfg,
        key = key,
        min = Lib.tov3(min),
        max = Lib.tov3(max),
        map = self,
        removed = false,
    }

    local id = nextRegionId
    nextRegionId = id + 1
    region.cid = id
    idRegions[id] = region

    self.keyRegions[key] = setmetatable(region, Region)
    if Region.init then
        -- 留给client、server扩展
        region:init()
    end

    self:setRegion(region.cid, min, max, false)
    return region
end

function Map:removeRegion(key, isCheckTrigger)
    local region = self.keyRegions[key]
    if not region then
        return
    end
    local id = region.cid
    if id then
        self:delRegion(id, isCheckTrigger)
        idRegions[id] = nil
    end
    region.removed = true
    self.keyRegions[key] = nil
    return region
end

function Map:getRegion(key)
    return self.keyRegions[key]
end

function Map:getAllRegion()
    return self.keyRegions
end

function Map:getRegionValue(pos, cfgKey)
    pos = Lib.tov3(pos):blockPos()
    for _, region in pairs(self.keyRegions) do
        if region.min <= pos and pos <= region.max then
            if not cfgKey then
                return region
            end
            if region.cfg then
                local value = region.cfg[cfgKey]
                if value ~= nil then
                    return region, value
                end
            end
        end
    end
    return nil
end

function Map:addEntity(key, data)
    self:removeEntity(key)
    local entity = {
        data = data,
        key = key,
        map = self
    }
    self.keyEntitys[key] = entity
    return entity
end

function Map:removeEntity(key)
    local entity = self.keyEntitys[key]
    if not entity then
        return
    end

    entity.removed = true
    self.keyEntitys[key] = nil
end

function Map:getEntity(key)
    return self.keyEntitys[key]
end

function Map:addItem(key, ry, pos, cfgName, blockID)
    self:removeItem(key)
    local cfg = cfgName
    if ry == 0 then
        ry = nil
    end
    local item = {
        ry = ry,
        pos = pos,
        cfg = cfg,
        key = key,
        blockID = blockID,
        map = self
    }
    self.keyItems[key] = item
    return item
end

function Map:removeItem(key)
    local item = self.keyItems[key]
    if not item then
        return
    end

    item.removed = true
    self.keyItems[key] = nil
end

function Map:getItem(key)
    return self.keyItems(key)
end

function Map:rename(new_name)
    local obj = self.obj
    assert(obj, self.name)
    mapList[self.id].name = new_name
    if self.static then
        staticList[new_name] = Lib.copy(staticList[self.name])
        staticList.remove(self.name)
    end
    self.name = new_name
end

local DEFAULT_CACHE_CLOSE_MAP_TIME = 20 * 600
local function startCheckCacheMapObjTimer()
    if checkCacheMapObjTimer then
        return
    end
    checkCacheMapObjTimer = World.Timer(DEFAULT_CACHE_CLOSE_MAP_TIME, function()
        local now = World.Now()
        for id, temp in pairs(cacheMapObjs) do
            if (temp.effectiveTime + temp.cacheTime) < now then
                cacheMapObjs[id] = nil
                temp.mapObj:close()
            end
        end
        local ret = next(cacheMapObjs)
        if not ret then
            checkCacheMapObjTimer = nil
        end
        return ret
    end)
end

local function cacheMapObj(id, mapObj, mapCfg)
    mapObj:resetMap()
    if cacheMapObjs[id] then
        cacheMapObjs[id].mapObj:close()
    end
    cacheMapObjs[id] = {
        mapObj = mapObj,
        id = id,
        effectiveTime = mapCfg.cacheCloseMapObjTime or World.cfg.cacheCloseMapObjTime or DEFAULT_CACHE_CLOSE_MAP_TIME,
        cacheTime = World.Now()
    }
    startCheckCacheMapObjTimer()
end

function Map:close()
    self.isClosing = true
    local obj = self.obj
    if not obj then
        Lib.logError("Map close not obj", self.name)
        return
    end
    assert(not next(self.players), self.name)
    mapList[self.id] = nil
    if self.static then
        staticList[self.name] = nil
    end
    for _, obj in pairs(self.objects) do
        obj:destroy()
    end
    for key in pairs(self.keyRegions) do
        self:removeRegion(key)
    end
    self.obj = nil
    if self.cfg.cacheCloseMapObj or World.cfg.cacheCloseMapObj then
        cacheMapObj(self.id, obj, self.cfg)
    else
        obj:close()
    end
    -- obj:close()
end

function Map:onCfgChanged()
    if self.cfg.cacheTimeout then
        self:setCacheTimeout(self.cfg.cacheTimeout)
    end
end

local function cloneSceneCfg(sceneCfg)
    local function isConstraintClass(class)
        return class == "FixedConstraint" or class == "HingeConstraint" or class == "RodConstraint" or class == "RopeConstraint" or
                class == "SliderConstraint" or class == "SpringConstraint"
    end
    local ret = Lib.copy(sceneCfg)
    local idMap = {}
    local itemCfgs = {}

    local function changeIdAndGetAllItemCfgs(cfg)
        for _, child in pairs(cfg.children or {}) do
            changeIdAndGetAllItemCfgs(child)
        end
        idMap[cfg.properties.id] = cfg
        cfg.properties.id = tostring(Instance:allocateId())
        itemCfgs[#itemCfgs + 1] = cfg
    end
    for _, item in pairs(ret) do
        changeIdAndGetAllItemCfgs(item)
    end

    for _, cfg in pairs(itemCfgs) do
        if isConstraintClass(cfg.class) and cfg.properties.slavePartID ~= "" then
            if not idMap[cfg.properties.slavePartID] then
                Lib.logWarning("slavePartID not exist", cfg.properties.slavePartID)
            else
                cfg.properties.slavePartID = idMap[cfg.properties.slavePartID].properties.id
            end
        end
    end

    return ret
end

local function createScene(self, sceneCfg, isOnlyCreateDisNeedSync)
    local scene = World.CurWorld:getScene(self.obj)

	if not sceneCfg or not next(sceneCfg) then
		return scene
	end
	if self.isDynamicMap then
		sceneCfg = cloneSceneCfg(sceneCfg)
	end
	local enableNavmesh = false
	local navimeshAgentRadius = nil --0.6
	local navimeshAgentMaxClimb = nil --0.9
	local navimeshAgentHeight =nil-- 2

	local function dealNotNeedSyncPart(cfg)
			local subPart = Instance.newInstance(cfg, self)
			if subPart then
				subPart:setParent(scene:getRoot())
				return true
			end
	end

	local function dealEntityBake(cfg)
		--地形是否需要烘培的判断
			local entity_cfg = Entity.GetCfg(cfg.config)
			if entity_cfg and entity_cfg.enableMeshNavigate then
				navimeshAgentMaxClimb = navimeshAgentMaxClimb or entity_cfg.stepHeight
				if entity_cfg.stepHeight and navimeshAgentMaxClimb > entity_cfg.stepHeight then 
					navimeshAgentMaxClimb = entity_cfg.stepHeight
				end

				
				if entity_cfg.collider then 
					local collider = entity_cfg.collider 
					local colliderRadius = nil
					local colliderHeight = nil
					if collider.type == "Capsule" or collider.type == "Cylinder"  then
						colliderRadius = collider.radius
						colliderHeight = collider.height
					elseif collider.type == "Box" then 
						local extent = collider.extent
						colliderRadius = math.sqrt(extent.x * extent.x / 4 + extent.z * extent.z / 4)
						colliderHeight = extent.y
					elseif collider.type == "Sphere" then 
							colliderRadius = collider.radius
							colliderHeight = collider.radius * 2
					end
					
					navimeshAgentRadius = navimeshAgentRadius or colliderRadius
					navimeshAgentHeight = navimeshAgentHeight or colliderHeight
					if colliderRadius and navimeshAgentRadius < colliderRadius then navimeshAgentRadius = colliderRadius end
					if colliderHeight and navimeshAgentHeight < colliderHeight then navimeshAgentHeight = colliderHeight end
				end 

				enableNavmesh = true
			end
	end

	local RootDir = Root.Instance():getGamePath()
	local EMPTY = setmetatable({}, { __newindex = error })
	local function checkNode(cfg, ignoreSyncPart)
		cfg.scene = scene
		if not IS_EDITOR then
			--进入游戏加载Folder DataSet数据
			if cfg.class=="Folder" and (cfg.properties.isDataSet or "false") =="true" then
				cfg.children = Lib.read_json_file(RootDir..self.dir.."DataSet/"..cfg.properties.id..".json") or EMPTY
				cfg.properties.isDataSet = "false"
			end
		end
		if (cfg.properties.needSync == "false" or not isOnlyCreateDisNeedSync) and not ignoreSyncPart then
			ignoreSyncPart = dealNotNeedSyncPart(cfg)
		end
		if cfg.class =="Entity" then 
			dealEntityBake(cfg)
		end

		if cfg.children then 
			for _, child in ipairs(cfg.children) do
				checkNode(child, ignoreSyncPart)
			end
		end
	end

	for _, cfg in ipairs(sceneCfg) do
		checkNode(cfg)
	end

	if enableNavmesh and not World.isClient then
		local cfg  = {
			scene = scene,
			class = "NavigationMgr",
			properties = {
				agentRadius = navimeshAgentRadius,
				agentMaxClimb = navimeshAgentMaxClimb,
				agentHeight = navimeshAgentHeight
			}
		}
		local subPart = Instance.newInstance(cfg,self)
		if subPart then 
			subPart:setParent(scene:getRoot())
		end
	end

	return scene
end

local regionPartImcId = 0
local strV3Zero = "x:0 y:0 z:0"
local function createSceneRegion(params, map, regionPartId)
    if IS_EDITOR or not map then
        return
    end
    local properties = params.properties or {}
    local cfgName = params.cfgName or properties.cfgName
    if not cfgName then
        return
    end
    local position = Lib.deserializerStrV3(properties.position or strV3Zero)
    if params.getPosition then
        position = params:getPosition()
    end
    local scale = Lib.deserializerStrV3(properties.scale or strV3Zero)
    if params.getScale then
        scale = params:getScale()
    end
    local region = World.Map.addRegion(map,
            "id:" .. cfgName .. "_name:" .. (properties.name or "") .. "_imcKey:" .. regionPartImcId,
            { x = position.x - scale.x / 2, y = position.y - scale.y / 2, z = position.z - scale.z / 2 },
            { x = position.x + scale.x / 2, y = position.y + scale.y / 2, z = position.z + scale.z / 2 },
            cfgName)
    regionPartImcId = regionPartImcId + 1
    if region then
        region.regionPartId = tonumber(properties.id) or regionPartId
    end
end

 -- 将一个不存在的region加入地图
function Map:addSceneRegionByRegionPart(regionPart)
	createSceneRegion(regionPart, self, regionPart.id)
end

function Map:createSceneRegion()
    local function seekRegionPart(data)
        for _, info in pairs(data or {}) do
            if info.class == "RegionPart" then
                createSceneRegion(info, self, info.id)
            end
            if info.children then
                seekRegionPart(info.children)
            end
        end
    end
    seekRegionPart(self.cfg.scene)
end

function Map:updateSceneRegionByRegionPart(regionPart, add)
    local id = regionPart:getInstanceID()
    local map = regionPart.map
    if not map then
        return
    end
    local regions = map:getAllRegion()
    for key, region in pairs(regions or {}) do
        if region.regionPartId and region.regionPartId == id then
            if add then
                return
            else
                map:removeRegion(key, true)
            end
        end
    end
    if add then
        createSceneRegion(regionPart, map, id)
    end
end

function Map:loadMeshPartCollision()
    local function loadMeshPartJson(compatiblePath)
        local collisionInfoList = {}
        local gamePath = Root.Instance():getGamePath() .. compatiblePath
        for fileName in lfs.dir(gamePath) do
            if fileName ~= '.' and fileName ~= ".." then
                if (fileName:match(".+%.(%w+)$") ~= "json") then
                    -- 检查兼容的后缀名是否是json
                    break
                end
                local path = compatiblePath .. "/" .. fileName
                local table = Lib.readGameJson(path)
                if table and table.meshPartName then
                    collisionInfoList[#collisionInfoList + 1] = table
                end
            end
        end
        return collisionInfoList[1] and collisionInfoList
    end

    local infoList = loadMeshPartJson("meshpart_collision") or loadMeshPartJson("meshCollisionInfo")

    if not infoList or not infoList[1] then
        return
    end

    MeshPartManager.Instance():loadLocalMeshPartData(infoList)
end

function Map:createScene(isOnlyCreateDisNeedSync)
    return createScene(self, self.cfg.scene, isOnlyCreateDisNeedSync)
end

function Map:getScene()
    local manager = World.CurWorld:getSceneManager()
    ---@type MapScene
    local scene = manager:getOrCreateScene(self.obj)
    return scene
end

function Map:getWorkSpace()
    local scene = self:getScene()
    return scene and scene:getRoot()
end

local function getRegionBorder(self, regionKey, region)
    if not (region or regionKey) then
        return
    end
    if region then
        return region.min, region.max
    else
        region = self:getRegion(regionKey)
        assert(region, "Wrong regionKey: " .. regionKey)
        return region.min, region.max
    end
end

local function isTouchCollision(self, pos)
    local collisionBoxes = Block.GetIdCfg(self:getBlockConfigId(pos)).collisionBoxes
    if collisionBoxes == nil or next(collisionBoxes) then
        return true
    end
    local entities = self:getTouchEntities(pos, Lib.v3add(pos, { x = 1, y = 1, z = 1 }))
    for _, entity in pairs(entities) do
        if entity:cfg().collision then
            return true
        end
    end
    return false
end

function Map:getRandomPosInRegion(posCount, isExcludeCollision, regionKey, region)
    local ret = {}
    local min, max = getRegionBorder(self, regionKey, region)
    if not (min and max) then
        return ret
    end
    for i = 1, posCount do
        local pos = Lib.v3(math.random(min.x, max.x), math.random(min.y, max.y), math.random(min.z, max.z))
        local tryCount = 0
        if isExcludeCollision then
            while tryCount < 3 and isTouchCollision(self, pos) do
                pos = Lib.v3(math.random(min.x, max.x), math.random(min.y, max.y), math.random(min.z, max.z))
                tryCount = tryCount + 1
            end
            pos = (not isTouchCollision(self, pos)) and pos or nil
        end
        if pos then
            ret[#ret + 1] = pos
        end
    end
    return ret
end

function Map:fillBlocksInRegion(blockName, regionKey, region)
    local min, max = getRegionBorder(self, regionKey, region)
    if not (min and max) then
        return false
    end
    local blockId = Block.GetNameCfgId(blockName)
    self:fillBlocksConfigId(min, max, blockId)
    for i = min.x, max.x do
        for j = min.y, max.y do
            for k = min.z, max.z do
                local pos = { x = i, y = j, z = k }
                self:createBlock(pos, blockName)
            end
        end
    end
    return true
end

function Map:clearBlocksInRegion(blockArray, regionKey, region)
    local min, max = getRegionBorder(self, regionKey, region)
    if not (min and max) then
        return false
    end
    local removeIds = {}
    for i = 1, #blockArray do
        removeIds[#removeIds + 1] = Block.GetNameCfgId(blockArray[i])
    end
    self:clearBlocksConfigId(min, max, removeIds)
    return true
end

function Map:removeBlocksInRegion(regionKey, region, isAll, blockName)
    local min, max = getRegionBorder(self, regionKey, region)
    if not (min and max) then
        return false
    end
    local single = type(blockName) == "string"

    for i = min.x, max.x do
        for j = min.y, max.y do
            for k = min.z, max.z do
                local pos = { x = i, y = j, z = k }
                local cfg = self:getBlock(pos).fullName
                if isAll then
                    self:removeBlock(pos)
                elseif single then
                    if cfg == blockName then
                        self:removeBlock(pos)
                    end
                else
                    for _, v in pairs(blockName) do
                        if cfg == v then
                            self:removeBlock(pos)
                            break
                        end
                    end
                end
            end
        end
    end

    return true
end

function Map:replaceBlockInRegion(region, replaceTb)
    if not replaceTb or #replaceTb == 0 then
        return
    end
    local min, max = region.min, region.max
    if not (min and max) then
        return false
    end
    for i = min.x, max.x do
        for j = min.y, max.y do
            for k = min.z, max.z do
                local pos = { x = i, y = j, z = k }
                local block = self:getBlock(pos)
                for _, v in pairs(replaceTb) do
                    if block[v.key] == v.value then
                        self:createBlock(pos, v.destBlock)
                    end
                end
            end
        end
    end
end

function Region.GetCfg(cfgName)
    if not cfgName then
        perror("Region.GetCfg: cfgName is nil !", traceback())
        return nil
    end
    return setting:fetch("region", cfgName)
end

function Map:posConvertBlock(pos, fullName)
	local blockId = Block.GetNameCfgId(fullName)
	return self:setBlockConfigId(pos, blockId)
end

function Map:fillBlocks(min, max, fullName)
	local blockId = Block.GetNameCfgId(fullName)
	self:fillBlocksConfigId(min, max, blockId)
end

function Map:clearBlocksInArea(min, max, fullNames)
	local blockIds = {}
	for i, name in ipairs(fullNames or {}) do
		local id = Block.GetNameCfgId(name)
		table.insert(blockIds,id)
	end
	self:clearBlocksConfigId(min, max, blockIds)
end

function Map:getBlockPosInArea(min, max, fullNames)
	local blockIds = {}
	for i, name in ipairs(fullNames or {}) do
		local id = Block.GetNameCfgId(name)
		table.insert(blockIds,id)
	end
	return self:getPosArrayWithIdsInArea(min, max, blockIds)
end