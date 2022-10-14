---@class Recorder
local Recorder = T(Lib, "Recorder")
---@type VideoEffectConfig
local Config = T(Config, "VideoEffectConfig")
---@type setting
local CommonSetting = require "common.setting"

function Recorder:SetHideName(hide)
	Blockman.instance.gameSettings:setHideName(hide)
end

function Recorder:SetHidePlayerOnly(only)
	Blockman.instance.gameSettings:setHidePlayerOnly(only)
end

function Recorder:SetHideSelf(hide)
	self:SetHidePlayerOnly(true)
	Blockman.instance.gameSettings:setHideSelf(hide)
end

function Recorder:SetHideOtherPlayers(hide)
	self:SetHidePlayerOnly(true)
	Blockman.instance.gameSettings:setHideOtherPlayers(hide)
end

function Recorder:SetHideUi(hide)
	if self.hideUi == hide then
		return
	end
	self.hideUi = hide

	if hide then
		UI:HideAllWindowsExcept(self.hideUiWhiteList or {})
	else
		UI:RestoreAllWindows()
	end
	UI:SetWindowsAlphaToZero(self.AlphaTo0UiList or {}, hide)
end

function Recorder:GetUiEffectWindows()
	local ret = {}
	for _, wnd in pairs(self.uiEffects or {}) do
		ret[wnd] = true
	end
	return ret
end

function Recorder:CanUiShow(name)
	return (not self.hideUi) or self.hideUiWhiteList[name]
end

-- Windows in list wont be affected by SetHideUi
-- list: {"wndName1", "wndName2", ...}
function Recorder:SetHideUiWhiteList(list)
	self.hideUiWhiteList = Lib.Vector2Map(list)
end

function Recorder:SetAlphaToZeroUiList(list)
	self.AlphaTo0UiList = Lib.Vector2Map(list)
end

function Recorder:PrintUiNames()
	local names = UI:GetAllWindowNames()
	for _, name in ipairs(names) do
		print(name)
	end
end

local weathers = {
	sunny = {
		skybox = {
			"Media/Textures/skybox/sunny/qing_right.png",
			"Media/Textures/skybox/sunny/qing_left.png",
			"Media/Textures/skybox/sunny/qing_top.png",
			"Media/Textures/skybox/sunny/qing_bottom.png",
			"Media/Textures/skybox/sunny/qing_front.png",
			"Media/Textures/skybox/sunny/qing_back.png",
		},
		effects = {
		},
		light = {
			direct = Lib.v3(0.161690, 0.808452, -0.565916),
			ambient = {246 / 255, 247 / 255, 251 / 255},
			diffuse = {253 / 255, 184 / 255, 141 / 255},
			specular = {102 / 255, 102 / 255, 102 / 255},
			exposure = 1.972,
			gamma = 1.893,
		},
	},
	rainy = {
		skybox = {
			"Media/Textures/skybox/rain/yu_right.png",
			"Media/Textures/skybox/rain/yu_left.png",
			"Media/Textures/skybox/rain/yu_top.png",
			"Media/Textures/skybox/rain/yu_bottom.png",
			"Media/Textures/skybox/rain/yu_front.png",
			"Media/Textures/skybox/rain/yu_back.png",
		},
		effects = {
			--"camera_effect_weather_rain_heavy.effect"
			"camera_effect_weather_rain.effect"
		},
		light = {
			direct = Lib.v3(0.161690, 0.808452, -0.565916),
			ambient = {200 / 255, 167 / 255, 150 / 255},
			diffuse = {205 / 255, 149 / 255, 114 / 255},
			specular = {102 / 255, 102 / 255, 102 / 255},
			exposure = 2.008,
			gamma = 1.831,
		},
	},
	snowy = {
		skybox = {
			"Media/Textures/skybox/snow/xue_right.png",
			"Media/Textures/skybox/snow/xue_left.png",
			"Media/Textures/skybox/snow/xue_top.png",
			"Media/Textures/skybox/snow/xue_bottom.png",
			"Media/Textures/skybox/snow/xue_front.png",
			"Media/Textures/skybox/snow/xue_back.png",
		},
		effects = {
			"camera_effect_weather_snow.effect"
		},
		light = {
			direct = Lib.v3(0.161690, 0.808452, -0.565916),
			ambient = {200 / 255, 167 / 255, 150 / 255},
			diffuse = {205 / 255, 149 / 255, 114 / 255},
			specular = {102 / 255, 102 / 255, 102 / 255},
			exposure = 2.008,
			gamma = 1.831,
		},
	},
	star = {
		skybox = {
			"Media/Textures/skybox/stars/fanxing_right.png",
			"Media/Textures/skybox/stars/fanxing_left.png",
			"Media/Textures/skybox/stars/fanxing_top.png",
			"Media/Textures/skybox/stars/fanxing_bottom.png",
			"Media/Textures/skybox/stars/fanxing_front.png",
			"Media/Textures/skybox/stars/fanxing_back.png",
		},
		effects = {
		},
		light = {
			direct = Lib.v3(0.161690, 0.808452, -0.565916),
			ambient = {78 / 255, 65 / 255, 173 / 255},
			diffuse = {123 / 255, 103 / 255, 133 / 255},
			specular = {102 / 255, 102 / 255, 102 / 255},
			exposure = 1.435,
			gamma = 1.218,
		},
	},
	sunset = {
		skybox = {
			"Media/Textures/skybox/sunset/wanxia_right.png",
			"Media/Textures/skybox/sunset/wanxia_left.png",
			"Media/Textures/skybox/sunset/wanxia_top.png",
			"Media/Textures/skybox/sunset/wanxia_bottom.png",
			"Media/Textures/skybox/sunset/wanxia_front.png",
			"Media/Textures/skybox/sunset/wanxia_back.png",
		},
		effects = {
		},
		light = {
			direct = Lib.v3(0.161690, 0.808452, -0.565916),
			ambient = {200 / 255, 167 / 255, 150 / 255},
			diffuse = {205 / 255, 149 / 255, 114 / 255},
			specular = {102 / 255, 102 / 255, 102 / 255},
			exposure = 2.008,
			gamma = 1.831,
		},
	},
}

function Recorder:reloadWeather()
	if not self.weatherId then
		return
	end

	local weatherId = self.weatherId
	self.weatherId = nil
	self:setWeather(weatherId, false)
end

function Recorder:setWeather(id, disable)
	if not self.initSkyColor then
		self.initSkyColor = EngineSceneManager.Instance():getSkyColor()
	end

	if disable then
		if self.weatherId ~= id then
			return
		end
		self.weatherId = nil

		self:restoreLight()
		self:restoreSkyBox()
		self:removeWeatherEffects()
		return
	end

	if self.weatherId == id then
		return
	end
	self.weatherId = id

	self:updateLight()
	self:updateSkyBox()
	self:updateWeatherEffect()
end

function Recorder:IsUsingWeather()
	return self.weatherId ~= nil
end

function Recorder:setLight(cfg)
	local engineSceneManager = EngineSceneManager.Instance()
	engineSceneManager:setExposure(cfg.exposure)
    engineSceneManager:setGamma(cfg.gamma)

    engineSceneManager:setDirLightDir(cfg.direct)
    engineSceneManager:setDirLightAmbient(cfg.ambient)
    engineSceneManager:setDirLightDiffuse(cfg.diffuse)
    --engineSceneManager:setDirLightSpecular(cfg.specular)

    engineSceneManager:setMainLightDir(cfg.direct)
    engineSceneManager:setAmbientColor(cfg.ambient)
    engineSceneManager:setMainLightColor(cfg.diffuse)
    engineSceneManager:setMainLightSpecular(cfg.specular)
end

function Recorder:restoreLight()
	if not self.oldLight then
		return
	end
	self:setLight(self.oldLight)
end

function Recorder:updateLight()
	local cfg = (weathers[self.weatherId or ""] or {}).light
	if not next(cfg or {}) then
		return
	end

	local engineSceneManager = EngineSceneManager.Instance()
	self.oldLight = {
		exposure = engineSceneManager:getExposure(),
	    gamma = engineSceneManager:getGamma(),
	    direct = engineSceneManager:getDirLightDir(),
	    ambient = engineSceneManager:getAmbientColor(),
	    diffuse = engineSceneManager:getDirLightDiffuse(),
	    specular = engineSceneManager:getMainLightSpecular(),
	}

	self:setLight(cfg)
end

function Recorder:restoreSkyBox()
    local map = Me.map
	local mapCfg = CommonSetting:loadDir("map/" .. map.name .. "/", true)
    if mapCfg and mapCfg.skyBox then
	    map.cfg.skyBox = mapCfg.skyBox
	    map:updateSkyBox()
    end

    EngineSceneManager.Instance():setSkyColor(self.initSkyColor)
end

function Recorder:updateSkyBox()
	local cfg = weathers[self.weatherId or ""]
	if not cfg then
		return
	end

	local settings = Blockman.instance.gameSettings
	settings:clearSky()

	local t1, t2, t3, t4, t5, t6 = table.unpack(cfg.skybox)
	settings:addSky(t1, t2, t3, t4, t5, t6, 0, 0, 0)
end

function Recorder:removeWeatherEffects()
	if self.renderTickCloser then
		self.renderTickCloser()
		self.renderTickCloser = nil
	end

	for _, tb in ipairs(self.weatherEffects or {}) do
		local name, pos = table.unpack(tb)
		Blockman.instance:delEffect(name, pos)
	end
	self.weatherEffects = {}
end

function Recorder:updateWeatherEffect()
	self:removeWeatherEffects()

	local cfg = weathers[self.weatherId or ""]
	if not cfg or not next(cfg.effects or {}) then
		return
	end

	local camera = Camera:getActiveCamera()
    local pos = camera:getPosition() + camera:getDirection() * 2.0
    pos = {x = math.floor(pos.x),y = math.floor(pos.y), z = math.floor(pos.z)}

    for _, effectName in ipairs(cfg.effects) do
	    Blockman.instance:playEffectByPos(effectName, pos, 0, -1, Lib.v3(3, 3, 3))
	    self.weatherEffects = self.weatherEffects or {}
	    table.insert(self.weatherEffects, {effectName, pos})
	end

	local lastPos = nil
	self.renderTickCloser = Lib.lightSubscribeEvent("error: EVENT_CLIENT_HANDLE_TICK",
    	Event.EVENT_CLIENT_HANDLE_TICK, function()
	    local camera = Camera:getActiveCamera()
	    local pos = camera:getPosition() + camera:getDirection() * 2.0
	    pos.x = math.floor(pos.x)
		pos.y = math.floor(pos.y)
		pos.z = math.floor(pos.z)
		if lastPos and lastPos == pos then
			return
		end
		lastPos = pos

		for _, effectData in ipairs(self.weatherEffects) do
			local name, initPos = table.unpack(effectData)
	        local effect = WorldEffectManager:Instance():getSimpleEffect(name, initPos)
	        if effect then
	            effect.mPosition = pos
	        end
	    end
	end)
end

function Recorder:playUiEffect(effectName, stop)
	self.uiEffects = self.uiEffects or {}
	if stop then
		local wnd = self.uiEffects[effectName]
		if not wnd then
			return
		end

		UI:RemoveWndInstance(wnd)
		GUIWindowManager.instance:DestroyGUIWindow(wnd)
        self.uiEffects[effectName] = nil
	    return
	end

	if self.uiEffects[effectName] then
		return
	end

	self:removeAllUiEffects()

    local wnd = GUIWindowManager.instance:CreateGUIWindow1("Layout", effectName)
    wnd:SetArea({0, 0}, {-0.5, 0}, {1, 0}, {1, 0})
    wnd:SetTouchable(false)
    UI:AddWndInstance(wnd)
    wnd:SetEffectName(effectName)
    wnd:SetEffectScale(Lib.v2(1, 1.8))
    self.uiEffects[effectName] = wnd
    wnd:PlayEffect(math.huge)
end

function Recorder:removeAllUiEffects()
	for name in pairs(self.uiEffects or {}) do
		self:playUiEffect(name, true)
	end
	self.uiEffects = {}
end

local bloomSettings = {
	enable = true,
	enableFullScreen = true,
	threshold = 0.75,
	saturation = 0.552,
	intensity = 2.098,
	blurDeviation = 2.587,
	blurMultiplier = 1.399,
	blurSampler = 7,
}
function Recorder:enableFilterLightBlur(disable)
	if self.filterLightBlurDisabled == disable then
		return
	end
	self.filterLightBlurDisabled = disable

	local gameSettings = Blockman.instance.gameSettings
	local settings = self.oldBloomSettings or {}
	if not disable then -- save old
		self.oldBloomSettings = {
			enable = gameSettings:getEnableBloom(),
			enableFullScreen = gameSettings:getEnableFullscreenBloom(),
			threshold = gameSettings:getBloomThreshold(),
			saturation = gameSettings:getBloomSaturation(),
			intensity = gameSettings:getBloomIntensity(),
			blurDeviation = gameSettings:getBloomBlurDeviation(),
			blurMultiplier = gameSettings:getBloomBlurMultiplier(),
			blurSampler = gameSettings:getBloomBlurSampler(),
		}
		settings = bloomSettings
	end

	gameSettings:setEnableBloom(settings.enable or false)
    gameSettings:setEnableFullscreenBloom(settings.enableFullScreen or false)
    gameSettings:setBloomThreshold(settings.threshold or 0)
    gameSettings:setBloomSaturation(settings.saturation or 0)
    gameSettings:setBloomIntensity(settings.intensity or 0)
    gameSettings:setBloomBlurDeviation(settings.blurDeviation or 0)
    gameSettings:setBloomBlurMultiplier(settings.blurMultiplier or 0)
    gameSettings:setBloomBlurSampler(settings.blurSampler or 0)
end

function Recorder:EnablePatternTorch(disable)
	local strength = disable and 0 or 1
	Blockman.instance.gameSettings:setPatternTorchStrength(strength)
end

function Recorder:EnableSpeedLine(disable)
	local strength = disable and 0 or 1
	local interval = 0.1
	Blockman.instance.gameSettings:setPatternSpeedLine(strength, interval)
end

function Recorder:enableTopBottomCover(disable)
	local height = disable and 0 or 0.122
	local colorRGBA = {}
	Blockman.instance.gameSettings:setTopBottomCoverHeight(height)
	if next(colorRGBA or {}) then
		Blockman.instance.gameSettings:setTopBottomCoverColor(table.unpack(colorRGBA))
	end
end

function Recorder:closeGroup(group)
	local items = Config:getCfgByTabId(group)
	for _, cfg in pairs(items) do
		self:doEvent(cfg, false)
	end
end

function Recorder:doEvent(cfg, selected)
	local type = cfg.eventType
	if type == "FilterLut" then
		Blockman.instance.gameSettings:setLutTextureName(selected and cfg.param or "")
	elseif type == "FilterLightBlur" then
		Recorder:enableFilterLightBlur(not selected)
	elseif type == "Weather" then
		Recorder:setWeather(cfg.param, not selected)
	elseif type == "EffectMovie" then
		Recorder:enableTopBottomCover(not selected)
	elseif type == "EffectTorch" then
		Recorder:EnablePatternTorch(not selected)
	elseif type == "EffectSpeed" then
		Recorder:EnableSpeedLine(not selected)
	elseif type == "UiEffect" then
		Recorder:playUiEffect(cfg.param, not selected)
	end
end

function Recorder:OnSelect(cfg, selected)
	self:closeGroup(cfg.tabId)
	self:doEvent(cfg, selected)
end

function Recorder:OnQuit()
	self:SetHideUi(false)
	self:SetHideName(false)
	self:SetHideSelf(false)
	self:SetHideOtherPlayers(false)

	for i = 1, 3 do
		self:closeGroup(i)
	end

	self:restoreLight()
	self:restoreSkyBox()
end

function Recorder:AppRecordStart()
	CGame.instance:getShellInterface():videoRecordStart()
end

function Recorder:AppRecordStop()
	CGame.instance:getShellInterface():vidoeRecordStop()
end

function Recorder:IsAppRecording()
	return CGame.instance:getShellInterface():isVideoRecordRecording()
end

function Recorder:IsAppRecordSupported()
	return CGame.instance:getShellInterface():isVideoRecordSupported()
end

function Recorder:onQualityLevelChange()
	if self.filterLightBlurDisabled == nil or self.filterLightBlurDisabled then
		return false
	end
	self:enableFilterLightBlur(true)
	self:enableFilterLightBlur(false)
	return false
end

function Recorder:LoadConfigFromJson()
	local config =  World.cfg.new_videoSetting or World.cfg.Recorder
	if not config then
		return
	end

	local whiteList = config.HideUiWhiteList
	if next(whiteList or {}) then
		Recorder:SetHideUiWhiteList(whiteList)
	end

	local transparentList = config.AlphaTo0UiList
	if next(transparentList or {}) then
		Recorder:SetAlphaToZeroUiList(transparentList)
	end

	for name, cfg in pairs(config.Weather or {}) do
		local w = weathers[name]
		if w then
			for k, v in pairs(cfg) do
				w[k] = v
			end
		end
	end
end
Recorder:LoadConfigFromJson()

Lib.lightSubscribeEvent("error!!!!! EVENT_QUALITY_LEVEL_CHANGE",
    Event.EVENT_QUALITY_LEVEL_CHANGE, function(level)
	World.Timer(1, Recorder.onQualityLevelChange, Recorder)
end)

Lib.lightSubscribeEvent("error!!!!! EVENT_LOAD_WORLD_END",
	Event.EVENT_LOAD_WORLD_END, function()
	Recorder:reloadWeather()
end)