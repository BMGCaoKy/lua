require "common.map"
require "common.world"
require "world.map"
require "world.region"

local init
World.vars = Vars.MakeVars("global", nil)

function WorldClient.Reload()
	init(true)
end

function init(reload)
	local worldCfg = World.cfg
	local bi = Blockman.instance
	bi.gameSettings.forcePickBlock = worldCfg.forcePickBlock or false
	if not reload and worldCfg.maxViewRange then	-- 不支持热更
		bi:setViewRange(worldCfg.maxViewRange, 2)
	end
	if not reload and worldCfg.midViewRange then	-- 不支持热更
		bi:setViewRange(worldCfg.midViewRange, 1)
	end
	if not reload and worldCfg.minViewRange then	-- 不支持热更
		bi:setViewRange(worldCfg.minViewRange, 0)
	end

	if not reload and worldCfg.globalMaxViewRange then	-- 不支持热更
		bi:setGlobalMaxViewRange(worldCfg.globalMaxViewRange)
	end

	if not reload and World.cfg.globalMaxViewRange then	-- 不支持热更
		Blockman.instance:setGlobalMaxViewRange(World.cfg.globalMaxViewRange)
	end

	if not reload and World.cfg.volumetricCloud then	-- 不支持热更
		if not reload and World.cfg.volumetricCloud.switch then
			Blockman.instance:setVolumetricCloud(World.cfg.volumetricCloud.switch)
		end
		local defaultHeight = World.cfg.volumetricCloud.defaultHeight or 50
		local defaultDensity = World.cfg.volumetricCloud.defaultDensity or 1
		local defaultColorMinR = World.cfg.volumetricCloud.defaultColorMinR or 0.8
		local defaultColorMinG = World.cfg.volumetricCloud.defaultColorMinG or 0.8
		local defaultColorMinB = World.cfg.volumetricCloud.defaultColorMinB or 0.8
		local defaultColorMaxR = World.cfg.volumetricCloud.defaultColorMaxR or 1.0
		local defaultColorMaxG = World.cfg.volumetricCloud.defaultColorMaxG or 1.0
		local defaultColorMaxB = World.cfg.volumetricCloud.defaultColorMaxB or 1.0
		for i, layer in pairs(World.cfg.volumetricCloud.layers or {}) do
			Blockman.instance:addVolumetricCloudLayer(layer.upperY or 0, layer.height or defaultHeight, layer.density or defaultDensity, layer.colorMinR or defaultColorMinR, layer.colorMinG or defaultColorMinG, layer.colorMinB or defaultColorMinB, layer.colorMaxR or defaultColorMaxR, layer.colorMaxG or defaultColorMaxG, layer.colorMaxB or defaultColorMaxB, true)
		end
	end
	Blockman.instance:updateVolumetricCloudLayers()

	if not reload and World.cfg.waterColor then	-- 不支持热更
		local waterColorR = World.cfg.waterColor.waterColorR or 0.0
		local waterColorG = World.cfg.waterColor.waterColorG or 0.38
		local waterColorB = World.cfg.waterColor.waterColorB or 0.456
		bi.gameSettings:setWaterColor(waterColorR, waterColorG, waterColorB)
	end

	--支持热更
	if worldCfg.asynLoadSectionMaxInterval ~= nil then
		bi.gameSettings:setAsynLoadSectionMaxInterval(worldCfg.asynLoadSectionMaxInterval)
	end

	--支持热更
	if worldCfg.threadRespondEventMaxNum ~= nil then
		bi.gameSettings:setThreadRespondEventMaxNum(worldCfg.threadRespondEventMaxNum)
	end	
	
	--支持热更
	if worldCfg.maxEventsHandleTime ~= nil then
		bi.gameSettings:setMaxEventsHandleTime(worldCfg.maxEventsHandleTime)
	end

	--支持热更
	local delayShaderQueue = function ()
		-- shaders 是存储一些默认需要延时的 ShaderProgram
		local shaders = {}
	    for _, name  in ipairs (worldCfg.delayHandleShaderQueue or {}) do
			shaders[#shaders + 1] = name
		end
		return shaders
	end
	bi.gameSettings:setDelayHandleShaderQueue(delayShaderQueue())

	--支持热更,重新刷新blocks
	if worldCfg.enableUseBlockLodCull ~= nil then
		bi:setEnableUseBlockLodCull(worldCfg.enableUseBlockLodCull)
	end 

	if worldCfg.clipCustomRenderTaskByWindowSize ~= nil then
		local instance = GUISystem.Instance()
		GUISystem.Instance():setClipCustomRenderTaskByWindowSize(worldCfg.clipCustomRenderTaskByWindowSize)
	end

	--支持热更,部分需要重新刷新blocks
	if worldCfg.qualityLevelData then
		for i, group in ipairs(worldCfg.qualityLevelData.maxLevel or {}) do
			bi:setQualityLevelData(2, i, group)
		end
		for i, group in ipairs(worldCfg.qualityLevelData.midLevel or {}) do
			bi:setQualityLevelData(1, i, group)
		end
		for i, group in ipairs(worldCfg.qualityLevelData.minLevel or {}) do
			bi:setQualityLevelData(0, i, group)
		end
	else
		bi:resetQualityLevelData()
	end
	
	-- NOTE: 不能影响运行这一行之前的报错上报
	if IS_UGC_ENGINE or worldCfg.needReport then
		CGame.instance:setGameNeedReport(true)
	else
		CGame.instance:setGameNeedReport(false)
	end

	--支持热更,section render视锥范围外删除释放内存百分比，>=1为不释放，0.5释放外圈一半，<=0视锥外完全释放
	if World.cfg.sectionRenderViewFrustumFreePercent ~= nil then
		Blockman.instance.gameSettings:setSectionRenderViewFrustumFreePercent(World.cfg.sectionRenderViewFrustumFreePercent)
	end 

	--支持热更,破坏方块的section会变脏，然后半径内的会走主线程刷新，半径外走子线程加载，会空白一帧
	if worldCfg.blockSectionDealwithDirtyRadiusToView ~= nil then
		bi.gameSettings:setBlockSectionDealwithDirtyRadiusToView(worldCfg.blockSectionDealwithDirtyRadiusToView)
	end

	if worldCfg.useNewFirstViewer then
		bi.gameSettings:setUseNewFirstViewer(true)
	end

	if worldCfg.autoChangeEntityRenderMode then
		bi:setAutoChangeEntityRenderMode(worldCfg.autoChangeEntityRenderMode.isAuto or false, worldCfg.autoChangeEntityRenderMode.realNum or -1, worldCfg.autoChangeEntityRenderMode.nameNum or -1)
	end

	if worldCfg.sceneFollowAmbientLight ~= nil then
		bi.gameSettings:setSceneFollowAmbientLight(worldCfg.sceneFollowAmbientLight)
	end

	if worldCfg.firstPersonViewSway then
		local cfg = worldCfg.firstPersonViewSway
		bi.gameSettings:setFirstPersonViewSwayStrength(cfg.strength or 0)
		if cfg.center then
			bi.gameSettings:setFirstPersonViewSwayCenterOffset(table.unpack(cfg.center))
		end
		if cfg.maxDegrees then
			bi.gameSettings:setFirstPersonViewSwayMaxDegrees(table.unpack(cfg.maxDegrees))
		end
	end
end

init()
