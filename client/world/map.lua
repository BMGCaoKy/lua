require "client.world.map_event"

local mapList = World.mapList
local staticList = World.staticList
---@type Map
local Map = World.Map

---@class MapClient : Map
local MapClient = T(World, "MapClient", Lib.derive(Map))
MapClient.__index = MapClient
--下面这个for循环请不要在业务层重写，不然会造成lua和c++调用时序混乱，有野指针风险
for k, v in pairs(MapInstanceClient) do	-- 澶嶅埗MapInstanceClient瀵煎嚭鍑芥暟锛堜笉鍚鍑烘垚鍛樺彉閲忥級
	if k:sub(1,2)~="__" and type(v)=="function" then
		MapClient[k] = function (self, ...)
			local obj = assert(self.obj, k)	-- map is closed
			return v(obj, ...)
		end
	end
end

local function isArrayTable(t) 
	if type(t) ~= "table" then 
		return false 
	end 
	local n = #t 
	for i,v in pairs(t) do 
		if type(i) ~= "number" then 
			return false 
		end 
		if i > n then 
			return false 
		end 
	end 
	return true 
end

local function initPlayer(isEditor, map, map_cfg, pos)
	local player = Player.CurPlayer
	if not player then
		return
	end

	player:setMap(map)
	player:setPosition(pos)
	player:resetPrevPosition()
	if pos.yaw then
		player:setRotationYaw(pos.yaw)
	end
	if pos.pitch then 
		player:setRotationPitch(pos.pitch)
	end

	if isEditor then
		player:setRotationYaw(map_cfg.yaw or 0)
		player:setRotationPitch(map_cfg.pitch or 0)
	end

end

local function initMiniMap(map_cfg)
	if map_cfg.miniMap then
		if World.openMiniMapTimer then
			World.openMiniMapTimer()
		end
		if Player.CurPlayer and not Player.CurPlayer:isWatch() then
			World.openMiniMapTimer = World.Timer(20, function()
				if UI:isOpen("minimap") == false then
					UI:openWnd("minimap")
				end
				Lib.emitEvent(Event.EVENT_MAP_RELOAD)
				World.openMiniMapTimer = nil
				return false
			end)
		end
    else
        UI:closeWnd("minimap")
        Lib.emitEvent(Event.EVENT_MAP_CLOSE)
    end
end

local function initSky(map, isEditor)
	map:updateSkyBox(isEditor)
end

local function initLightGlobalParam(bm_gameSettings, map_cfg)
	if map_cfg.roughness then
		bm_gameSettings:setGlobalRoughness(map_cfg.roughness);
	end

	if map_cfg.metalness then
		bm_gameSettings:setGlobalMetalness(map_cfg.metalness)
	end

	if map_cfg.blinn then
		bm_gameSettings:setBlinn(map_cfg.blinn)
	end

	if map_cfg.hdr then
		bm_gameSettings:setHdr(map_cfg.hdr)
	end

	if map_cfg.exposure then
		bm_gameSettings:setExposure(map_cfg.exposure)
	end

	if map_cfg.gamma then
		bm_gameSettings:setGamma(map_cfg.gamma)
	end

	if map_cfg.ambientStrength then
		bm_gameSettings:setAmbientStrength(map_cfg.ambientStrength)
	end

end

local function initDynamicBrightness(bm_gameSettings, map_cfg, isEditor)
	bm_gameSettings:clearLight()
	local dynamicBrightness = isEditor and map_cfg.editorDynamicBrightness or map_cfg.dynamicBrightness --不是条件表达式
	if dynamicBrightness then
		for k, v in pairs(dynamicBrightness) do
			bm_gameSettings:addLight(v.mainLightDir or {x = 0.2, y = 1.0, z = -0.7}, v.mainLightColor or {x = 0.6, y = 0.6, z = 0.6}, 
				v.subLightColor or {x = 0.6, y = 0.6, z = 0.6}, v.ambientLightColor or {x = 0.6, y = 0.6, z = 0.6}, v.brightness, v.time, v.transition)
		end
	end

end

local function initFog(bm_gameSettings, map_cfg)
	if map_cfg.fog then
		local fog = map_cfg.fog
		bm_gameSettings:setCustomFog(fog.start, fog["end"], fog.density, fog.color, fog.type, fog.min);
		bm_gameSettings.hideFog = false
	else
		bm_gameSettings.hideFog = true
	end

	if map_cfg.fogColorInLiquidR then
		bm_gameSettings:setFogColorInLiquidR(map_cfg.fogColorInLiquidR)
	end

	if map_cfg.fogColorInLiquidG then
		bm_gameSettings:setFogColorInLiquidG(map_cfg.fogColorInLiquidG)
	end

	if map_cfg.fogColorInLiquidB then
		bm_gameSettings:setFogColorInLiquidB(map_cfg.fogColorInLiquidB)
	end

	if map_cfg.fogDensityInLiquid then
		bm_gameSettings:setFogDensityInLiquid(map_cfg.fogDensityInLiquid)
	end

end

local function initMainLight(bm_gameSettings, map_cfg, isEditor)
	----------------------------------------------------------------------------------
	--new lighting
	Lib.logDebug("initMainLight isEditor = ", isEditor)
	local DEG2RAD = 0.01745329
	local engineSceneManager = EngineSceneManager.Instance()

	--[[engineSceneManager:setDirLightDir({x = 0.2, y = 1.0, z =-0.7})
	engineSceneManager:setDirLightColor(World.cfg.dirLightColor or {0.85, 0.85, 0.85, 1.0})
	engineSceneManager:setDirLightIntensity(World.cfg.dirLightIntensity or 1.0)

	engineSceneManager:setAmbientLightColor(World.cfg.ambientLightColor or {0.90, 0.90, 0.90, 1.0})
	engineSceneManager:setAmbientStrength(World.cfg.ambientStrength or 1.0)
	engineSceneManager:setAmbientLightIntensity(World.cfg.ambientStrength or 1.0)

	engineSceneManager:setPointLightPos(0, {x = 161.0, y = 20.6779, z = 138.928})--Y需要比场景编辑器增加10米（观察场景编辑器camera的坐标比较方便）
	engineSceneManager:setPointLightColor(0, {0.6, 0.0, 0.0, 1.0})
	engineSceneManager:setPointLightIntensity(0, 1.0)
	engineSceneManager:setPointLightRadius(0, 5.0)

	engineSceneManager:setSpotLightPos(0, {x = 0, y = 0, z = 0})
	engineSceneManager:setSpotLightDir(0, {x = 0.2, y = 1.0, z =-0.7})
	engineSceneManager:setSpotLightColor(0, {0.0, 0.0, 0.0, 1.0})
	engineSceneManager:setSpotLightIntensity(0, 1.0)
	engineSceneManager:setSpotLightRadius(0, 5.0)


	engineSceneManager:setGlobalRoughness(0.9)
	engineSceneManager:setGlobalMetalness(0.0)
	engineSceneManager:setBlinn(1)
	engineSceneManager:setHdr(1)
	engineSceneManager:setExposure(1.0)
	engineSceneManager:setGamma(1.0)
	engineSceneManager:setSSAOIntensity(0.0)]]

	----------------------------------------------------------------------------------


	bm_gameSettings:setMainLightDir( {x = 0.2, y = 1.0, z =-0.7})
	bm_gameSettings:setMainLightColor({x = 0.6, y = 0.6, z = 0.6})
	bm_gameSettings:setSubLightColor({x = 0.6, y = 0.6, z = 0.6})
	bm_gameSettings:setAmbientColor({x = 0.6 ,y = 0.6, z = 0.6})
	bm_gameSettings:setBrightness({x = 0.6, y = 0.6, z = 0.6})

	bm_gameSettings:setUiActorMainLightDir(  {x = 0.2, y = 1.0, z =-0.7})
	bm_gameSettings:setUiActorMainLightColor({x = 0.6, y = 0.6, z = 0.6})
	bm_gameSettings:setUiActorSubLightColor( {x = 0.6, y = 0.6, z = 0.6})
	bm_gameSettings:setUiActorAmbientColor(  {x = 0.6, y = 0.6, z = 0.6})
	bm_gameSettings:setUiActorBrightness(    {x = 0.8, y = 0.8, z = 0.8})

	local light = map_cfg.light
	if light then
		if light.mainLightDir then
			bm_gameSettings:setMainLightDir(light.mainLightDir)
		end
		if light.mainLightColor then
			bm_gameSettings:setMainLightColor(light.mainLightColor)
		end
		if light.subLightColor then
			bm_gameSettings:setSubLightColor(light.subLightColor)
		end
		if light.ambientLightColor then
			bm_gameSettings:setAmbientColor(light.ambientLightColor)
		end
		if light.brightness then
			bm_gameSettings:setBrightness(light.brightness)
		end
	end

end

local function initActorLight(bm_gameSettings, map_cfg, isEditor)
	bm_gameSettings:setActorReceiveBlockLight(false)
	if map_cfg.actorReceiveBlockLight~= nil then
		bm_gameSettings:setActorReceiveBlockLight(map_cfg.actorReceiveBlockLight)
	end

	if World.cfg.allMapEnableActorReceiveBlockLight then
		bm_gameSettings:setActorReceiveBlockLight(true)
	end

	bm_gameSettings:clearActorLight()
	local actorLight = map_cfg.actorLight
	if actorLight then
		if isArrayTable(actorLight) == true then
			for k, v in pairs(actorLight) do
				bm_gameSettings:addActorLight(v.mainLightColor or {x = 0.6, y = 0.6, z = 0.6}, v.subLightColor or {x = 0.6, y = 0.6, z = 0.6}, v.ambientLightColor or {x = 0.6, y = 0.6, z = 0.6}, v.brightness, v.time, v.transition)
			end
		else
		    if actorLight.mainLightColor then
		    	bm_gameSettings:setActorMainLightColor(actorLight.mainLightColor)
		    end
		    if actorLight.subLightColor then
		    	bm_gameSettings:setActorSubLightColor(actorLight.subLightColor)
		    end
		    if actorLight.ambientLightColor then
		    	bm_gameSettings:setActorAmbientColor(actorLight.ambientLightColor)
		    end
		    if actorLight.brightness then
		    	bm_gameSettings:setActorBrightness(actorLight.brightness)
		    end
		end
	end
		
	local uiActorLight = map_cfg.uiActorLight
	if uiActorLight then
		if uiActorLight.mainLightDir then
			bm_gameSettings:setUiActorMainLightDir(uiActorLight.mainLightDir)
		end
		if uiActorLight.mainLightColor then
			bm_gameSettings:setUiActorMainLightColor(uiActorLight.mainLightColor)
		end
		if uiActorLight.subLightColor then
			bm_gameSettings:setUiActorSubLightColor(uiActorLight.subLightColor)
		end
		if uiActorLight.ambientLightColor then
			bm_gameSettings:setUiActorAmbientColor(uiActorLight.ambientLightColor)
		end
		if uiActorLight.brightness then
			bm_gameSettings:setUiActorBrightness(uiActorLight.brightness)
		end
	end

end

local function initRealtimeShadow(bm_gameSettings, map_cfg, isEditor)
	if map_cfg.realtimeShadowCamHighestLevel then
		bm_gameSettings:setRealtimeShadowCamHighestLevel(map_cfg.realtimeShadowCamHighestLevel)
	end
	if map_cfg.realtimeShadowCamLowestLevel then
		bm_gameSettings:setRealtimeShadowCamLowestLevel(map_cfg.realtimeShadowCamLowestLevel)
	end
	if map_cfg.realtimeShadowCamHighestAndLowestFixed then
		bm_gameSettings:setRealtimeShadowCamHighestAndLowestFixed(map_cfg.realtimeShadowCamHighestAndLowestFixed)
	end

end

local function loadQuality(bm, qualityLevelData)
	for i, group in ipairs(qualityLevelData.maxLevel or {}) do
		bm:setQualityLevelData(2, i, group)
	end

	for i, group in ipairs(qualityLevelData.midLevel or {}) do
		bm:setQualityLevelData(1, i, group)
	end

	for i, group in ipairs(qualityLevelData.minLevel or {}) do
		bm:setQualityLevelData(0, i, group)
	end
end
local function initQuality(bm, map_cfg, isEditor)
	if map_cfg.qualityLevelData then
		 loadQuality(bm, map_cfg.qualityLevelData)
	elseif World.cfg.qualityLevelData then
		 loadQuality(bm, World.cfg.qualityLevelData)
	else
		bm:resetQualityLevelData()
	end

end

local function initVolumetricCloud(bm, map_cfg, isEditor)
	local map_cfg_volumetricCloud = map_cfg.volumetricCloud or {}
	if map_cfg_volumetricCloud.switch then
		bm:setVolumetricCloud(map_cfg_volumetricCloud.switch)
	end
	if map_cfg_volumetricCloud.layers and next(map_cfg_volumetricCloud.layers) then
		local defaultHeight = map_cfg_volumetricCloud.defaultHeight or 50
		local defaultDensity = map_cfg_volumetricCloud.defaultDensity or 1
		local defaultColorMinR = map_cfg_volumetricCloud.defaultColorMinR or 0.8
		local defaultColorMinG = map_cfg_volumetricCloud.defaultColorMinG or 0.8
		local defaultColorMinB = map_cfg_volumetricCloud.defaultColorMinB or 0.8
		local defaultColorMaxR = map_cfg_volumetricCloud.defaultColorMaxR or 1.0
		local defaultColorMaxG = map_cfg_volumetricCloud.defaultColorMaxG or 1.0
		local defaultColorMaxB = map_cfg_volumetricCloud.defaultColorMaxB or 1.0
		for i, layer in pairs(map_cfg_volumetricCloud.layers) do
			bm:addVolumetricCloudLayer(
				layer.upperY or 0, 
				layer.height or defaultHeight, 
				layer.density or defaultDensity, 
				layer.colorMinR or defaultColorMinR, 
				layer.colorMinG or defaultColorMinG, 
				layer.colorMinB or defaultColorMinB, 
				layer.colorMaxR or defaultColorMaxR, 
				layer.colorMaxG or defaultColorMaxG, 
				layer.colorMaxB or defaultColorMaxB, 
				false)
		end
	end
	bm:updateVolumetricCloudLayers()

end

local function initOthers(bm,bm_gameSettings, map_cfg, isEditor)
	if World.cfg.disableCameraCollision ~= nil then
		World.CurWorld.disableCameraCollision = World.cfg.disableCameraCollision
		if map_cfg.disableCameraCollision ~= nil then
			World.CurWorld.disableCameraCollision = map_cfg.disableCameraCollision
		end
	end
	if not World.CurWorld:checkEditor(0xFF) then
		Camera.getActiveCamera():setFarClip(map_cfg.cameraFarClip or World.cfg.cameraFarClip or 256)
	end
	bm_gameSettings.hideCloud = map_cfg.hideCloud or false

	if map_cfg.blockLodCullRenderRangeMulti then
		bm_gameSettings:setBlockLodCullRenderRangeMulti(map_cfg.blockLodCullRenderRangeMulti)
	end

	if map_cfg.enablePureColorBlock then
		bm_gameSettings:setEnablePureColorBlock(map_cfg.enablePureColorBlock)
	end

	if map_cfg.pureColorBlockDistance then
		bm_gameSettings:changePureColorBlockDistance(map_cfg.pureColorBlockDistance - bm_gameSettings:getPureColorBlockDistance())
	end

	if map_cfg.blockLodColor and bm.setBlockLodColor then
		bm.setBlockLodColor(map_cfg.blockLodColor)
	end
end

function WorldClient:loadCurMap(data, pos, mapChunkData)
	loadingUiPage("loading_page", 6)	-- enumShowType.LOAD_WORLD_STARTR

	local map, isCache = World.mapList[data.id] or self:loadMap(data.id, data.name, data.static)
	map:loadCfg()
	if mapChunkData and next(mapChunkData) then
		map:loadChunk(mapChunkData, pos)
	end
	---@type MapClient
	World.CurMap = map

	local bm = Blockman.instance
	local bm_gameSettings = bm.gameSettings
	local isEditor = World.CurWorld.isEditor
	local map_cfg = map.cfg
	bm:setCurMap(map.id, pos)

	initPlayer(isEditor, map, map_cfg, pos)
	initMiniMap(map_cfg)
	initSky(map, isEditor)
	initDynamicBrightness(bm_gameSettings, map_cfg, isEditor)
	initFog(bm_gameSettings, map_cfg)
	initMainLight(bm_gameSettings, map_cfg, isEditor)
	initLightGlobalParam(bm_gameSettings, map_cfg)
	initActorLight(bm_gameSettings, map_cfg, isEditor)
	initRealtimeShadow(bm_gameSettings, map_cfg, isEditor)
	initQuality(bm, map_cfg, isEditor)
	initVolumetricCloud(bm, map_cfg, isEditor)
	initOthers(bm,bm_gameSettings, map_cfg, isEditor)

	map:loadMeshPartCollision()
	if bm.singleGame and not isEditor then
		map:loadSingle()
	elseif not isEditor then
		map:loadMultiplayer()
	end
	if map_cfg.useLod~=nil then
		map:setUseLod(map_cfg.useLod)
	end


	if World.CurWorld:checkEditor(0xFF) and World.cfg.editorFovAngle then
		Blockman.instance:setViewFovAngle(World.cfg.editorFovAngle)
	end

	Lib.emitEvent(Event.EVENT_LOAD_WORLD_END)
	Event:EmitEvent("OnLoadMapDone")

	loadingUiPage("loading_page", 7)	-- enumShowType.LOAD_WORLD_END
end

function MapClient:close()
	if self.recalcChunkLightTimer then
		self.recalcChunkLightTimer()
		self.recalcChunkLightTimer = nil
	end
	Map.close(self)
end

function MapClient:GetSceneAsTable(scene)
	if not scene then
		return
	end

	local root = scene:getRoot()
	local sceneTable = {}
	root:getAllChildrenAsTable(sceneTable)
	return sceneTable
end

local function checkRecalcChunkLight(self)
	if not self.recalcChunkLightTimer then
		self.recalcChunkLightTimer = World.Timer(20 * 3, function()
			if not self.recalcChunkLightArray or #self.recalcChunkLightArray <= 0 then
				self.recalcChunkLightArray = {}
				self.recalcChunkLightTimer = nil
				return false
			end
			self:recalcChunkLight(self.recalcChunkLightArray[1])
			table.remove(self.recalcChunkLightArray, 1)
			return true
		end)
	end

end

function MapClient:loadChunk(chunkData, centerPos)
	local centerChunk = {x = math.floor(centerPos.x / 8), y = 0, z = math.floor(centerPos.z / 8)}
	local notFullSetChunkMap = self:deserializerChunkData(chunkData)
	if notFullSetChunkMap.gzUncompressFail then
		CGame.instance:exitGame()
		return
	end
	local recalcChunkLightArray = self.recalcChunkLightArray
	if not recalcChunkLightArray then
		recalcChunkLightArray = {}
		self.recalcChunkLightArray = recalcChunkLightArray
	end
	for _, v3 in pairs(notFullSetChunkMap) do
		recalcChunkLightArray[#recalcChunkLightArray + 1] = v3
	end
	if #recalcChunkLightArray > 0 then
		table.sort(recalcChunkLightArray, function(c1, c2)
			return Lib.getPosDistanceSqr(c1,centerChunk) > Lib.getPosDistanceSqr(c2,centerChunk)
		end)
	end
	checkRecalcChunkLight(self)
end

function MapClient:createBlock(pos, fullName)
	local cfg = Block.GetNameCfg(fullName)
	local id = cfg.id
	self:setBlockConfigId(pos, id)
end

function MapClient:createBlockSimple(pos, fullName)
	local cfg = Block.GetNameCfg(fullName)
	local id = cfg.id
	self:setBlockConfigIdSimple(pos, id)
end

function MapClient:removeBlock(pos)
	local blockcfg = self:getBlock(pos)

	if not self:setBlockConfigId(pos, 0) then
		return
	end

	local upPos = pos + Lib.v3(0, 1, 0)
	self:checkBlockFall(upPos)
end

function MapClient:leaveAllEntity()
	for _, obj in pairs(self.objects) do
		if obj.isEntity then
			obj:setMap(nil)
		end
	end
end

function MapClient:leaveObject(object, newMap)
    self.objects[object.objID] = nil
end

function MapClient:joinObject(object, oldMap)
    self.objects[object.objID] = object
end

function MapClient:loadMultiplayer()
	self:createScene(true)
end

function MapClient:loadSingle()
	if not IS_EDITOR then
		for _, tb in ipairs(self.keyEntitys) do
			local data = tb.data
			EntityClient.CreateClientEntity({
				cfgName		= data.cfg, 
				pos			= data.pos, 
				ry 			= data.ry,
			})
		end
		local i = 1
		for _, tb in ipairs(self.keyItems) do
			i = i + 1
			local item = Item.CreateItem(tb.cfg, 1)
			local dropitem = DropItemClient.Create(i, tb.pos, item)
			dropitem:setRotation(tb.ry or 0, tb.rp or 0)
		end

		local sceneManager = World.CurWorld:getSceneManager()
		local scene = self:createScene()
		sceneManager:setCurScene(scene)
	end
end

function MapClient:__tostring()
	return Map.__tostring(self)
end


function Map:init(isCache)
	setmetatable(self, MapClient)
	local cfg = self.cfg;

	if not isCache and cfg.skyLightScale~= nil then
		self:setSkyLightScale(cfg.skyLightScale)
	end

	if not isCache and cfg.minOpacityValue~= nil then
		self:setMinOpacityValue(cfg.minOpacityValue)
	end

	if not isCache and cfg.minSkyOpacityValue~= nil then
		self:setMinSkyOpacityValue(cfg.minSkyOpacityValue)
	end

	if not isCache and cfg.minBlockOpacityValue~= nil then
		self:setMinBlockOpacityValue(cfg.minBlockOpacityValue)
	end
end

function MapClient:bakeLightAndSave(maxLightMode, forceRecalculate)
	self:bakeAndSave(maxLightMode, forceRecalculate)
	print("bakeLightAndSave ok...")
end

local defauleSkyTex = "blank.png"
local string_find = string.find
local function getTexWithSpilt(texture)
	return texture and (texture~="") and (string_find(texture,"@") and texture:sub(2) or "") or defauleSkyTex
end
local function getTexWithMapName(map_name, texture)
	return texture and (texture~="") and ("map/" .. map_name .. "/" .. texture) or defauleSkyTex
end
local function getTexWithPlugin(texture)
	return texture and (texture~="") and ("plugin/" .. texture) or defauleSkyTex
end
local pixFmtMap = {
	RGB8 = 10,
	RGBA8 = 15
}
function MapClient:updateSkyBox(isEditor)
	local bm_gameSettings = Blockman.instance.gameSettings
	local map_cfg = self.cfg
	local map_name = self.name
	bm_gameSettings:clearSky()
	local function addSky(skyBox)
		if isArrayTable(skyBox) == true then
			local function tempFunc(v)
				local v_texture = v.texture
				local checkTex
				for i = 1, #v_texture do
					checkTex = v_texture[i]
					if checkTex ~= "" then
						break
					end
				end
				if string_find(checkTex,"@") then
					bm_gameSettings:addSky(getTexWithSpilt(v_texture[1]), getTexWithSpilt(v_texture[2]), getTexWithSpilt(v_texture[3]), 
						getTexWithSpilt(v_texture[4]), getTexWithSpilt(v_texture[5]), getTexWithSpilt(v_texture[6]), v.time or 0, v.transition or 0, v.heightOffset or 0)
				elseif string_find(checkTex,"/") == nil then
					bm_gameSettings:addSky(getTexWithMapName(map_name, v_texture[1]),getTexWithMapName(map_name, v_texture[2]),getTexWithMapName(map_name, v_texture[3]),
						getTexWithMapName(map_name, v_texture[4]),getTexWithMapName(map_name, v_texture[5]),getTexWithMapName(map_name, v_texture[6]), v.time or 0, v.transition or 0, v.heightOffset or 0)
				else
					local i, j = string.find(checkTex, "plugin")
					if i == 1 and j == 6 then
						Lib.logDebug("load skybox with plugin")
						bm_gameSettings:addSky(v_texture[1],v_texture[2],v_texture[3],
								v_texture[4],v_texture[5],v_texture[6], v.time or 0, v.transition or 0, v.heightOffset or 0)
					else
						bm_gameSettings:addSky(getTexWithPlugin(v_texture[1]),getTexWithPlugin(v_texture[2]),getTexWithPlugin(v_texture[3]),
								getTexWithPlugin(v_texture[4]),getTexWithPlugin(v_texture[5]),getTexWithPlugin(v_texture[6]), v.time or 0, v.transition or 0, v.heightOffset or 0)
					end

				end
			end
			if skyBox[1].time and skyBox[1].time ~= 0 then
				local temp = Lib.copy(skyBox[#skyBox])
				temp.time = 0
				temp.transition = 0
				tempFunc(temp)
			end
			bm_gameSettings:setSkyRotate(map_cfg.skyBoxRotate or { x = 0, y = 0, z = 0 })
			local skyBoxTexSize = map_cfg.skyBoxTexSize
			if skyBoxTexSize and (skyBoxTexSize > 0) then
				bm_gameSettings:setSkyBoxTexSize(skyBoxTexSize)
			end
			local skyBoxTexPixFmt = map_cfg.skyBoxTexPixFmt
			if skyBoxTexPixFmt and pixFmtMap[skyBoxTexPixFmt] then
				bm_gameSettings:setSkyBoxTexPixFmt(pixFmtMap[skyBoxTexPixFmt])
			end
			for k, v in pairs(skyBox) do
				tempFunc(v)
			end
		else
			bm_gameSettings:setSkyRotate(skyBox.rotate or { x = 0, y = 0, z = 0 }, 1)
			if skyBox.texture:sub(1,1) == "@" then
				bm_gameSettings:addSky1(skyBox.texture:sub(2), 0, 0, skyBox.heightOffset or 0)
			elseif string_find(skyBox.texture,"/") == nil then
				bm_gameSettings:addSky1("map/" .. map_name .. "/" .. skyBox.texture, 0, 0, skyBox.heightOffset or 0)
			else
				bm_gameSettings:addSky1("plugin/" .. skyBox.texture, 0, 0, skyBox.heightOffset or 0)
			end
		end
	end

	local skyBox = isEditor and map_cfg.editorSkyBox or map_cfg.skyBox --不是条件表达式
	if skyBox and next(skyBox) then
		addSky(skyBox)
	end
end