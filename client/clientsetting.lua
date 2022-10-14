local cjson = require "cjson"
local m_settingMapping = {}
local m_keySettingDefault = {}
local m_customKeySetting = {}
local m_vkcode2string = {}
local m_mapName = {}
local m_arrayPlugin = {}
local m_customHandBag = {}
local m_guideInfo = {}
local m_localGuideInfo = {}

local strfmt = string.format
local strsub = string.sub
local strlen = string.len
local strfind = string.find
local MAX_COUNT = 7

local enumMouseState = { MOUSE_NONE = 0, MOUSE_SHOW = 1, MOUSE_HIDE = 2 }

function Clientsetting.init()
    Clientsetting.loadSettingTxt()
	Clientsetting.setVolume()
	Clientsetting.saveSettingTxt()
	Clientsetting.loadPlugin()
    Clientsetting.loadCustomHandBagConfig()
	if not World.CurWorld.isEditor then
		Clientsetting.getGuideInfo()
	end
	if CGame.instance:getPlatformId() == 1 then  --pc
		Clientsetting.loadKeySettingDefault()
		Clientsetting.loadCustomKeySetting()
		Clientsetting.loadVkcode2string()
		Clientsetting.saveCustomKeySetting()
		Clientsetting.saveCustomKeySettingToGame()
	end
end

function Clientsetting.loadSettingTxt()
    Clientsetting.readClientSettingTxt(Root.Instance():getRootPath() .. "document/blockManClientConfig.txt")
end  

function Clientsetting.loadPlugin()
	local pluginSettingPath = "lua/plugins/editor_template/plugin_setting.json"
	m_arrayPlugin = Lib.read_json_file(Root.Instance():getRootPath()..pluginSettingPath)
end

function Clientsetting.loadCustomHandBagConfig()
	Clientsetting.readCustomHandBag(Root.Instance():getGamePath() .. "customHandbagConfig.json")
end

function Clientsetting.getAllItemList()
	local allItemList = {
		m_arrayPlugin.block,
		m_arrayPlugin.special,
		m_arrayPlugin.equip,
		m_arrayPlugin.entity,
		m_arrayPlugin.item,
		m_arrayPlugin.moveBlock,
		m_arrayPlugin.bagWeaponList,
		m_arrayPlugin.resourceList,
	}
	local data = {}
	for _, list in pairs(allItemList) do
		for idx = 1, #list do
			local itemName = list[idx].name or list[idx]
			data[itemName] = list[idx]
		end
	end
	return Lib.copy(data)
end

function Clientsetting.getItemList()
	return Lib.copy(m_arrayPlugin.item)
end

function Clientsetting.getMoveBlock()
	return Lib.copy(m_arrayPlugin.moveBlock)
end

function Clientsetting.getMonsterList()
	return Lib.copy(m_arrayPlugin.monster)
end
function Clientsetting.getBlockFoldList()
	return Lib.copy(m_arrayPlugin.blockFoldList)
end

function Clientsetting.getBlockList()
	return Lib.copy(m_arrayPlugin.block)
end

function Clientsetting.getSpecialBlockList()
	return Lib.copy(m_arrayPlugin.specialblock)
end

function Clientsetting.getEntityList()
	return Lib.copy(m_arrayPlugin.entity)
end 

function Clientsetting.getequipList()
	return Lib.copy(m_arrayPlugin.equip)
end

function Clientsetting.getWeaponList()
	return Lib.copy(m_arrayPlugin.bagWeaponList)
end

function Clientsetting.getResourceList()
	return Lib.copy(m_arrayPlugin.resourceList)
end

function Clientsetting.getData(key)
	if m_arrayPlugin[key] then
		return Lib.copy(m_arrayPlugin[key]) 
	end
end

function Clientsetting.getFireBulletPropEdit()
	return Lib.copy(m_arrayPlugin.fireBulletPropEdit)
end

function Clientsetting.getToolPropEdit()
	return Lib.copy(m_arrayPlugin.toolPropEdit)
end

function Clientsetting.getMonsterPropEdit()
	return Lib.copy(m_arrayPlugin.monsterPropEdit)
end

function Clientsetting.getWeaponPropEdit()
	return Lib.copy(m_arrayPlugin.weaponPropEdit)
end

function Clientsetting.getWeaponBuffList()
	return Lib.copy(m_arrayPlugin.weaponBuffList)
end

function Clientsetting.getBuffTemple()
	return Lib.copy(m_arrayPlugin.buff_template)
end

function Clientsetting.getSpecialList()
	return Lib.copy(m_arrayPlugin.special)
end

function Clientsetting.getBlockStyleList()
	return Lib.copy(m_arrayPlugin.blockStyle)
end

function Clientsetting.getTeamTemplate()
	return Lib.copy(m_arrayPlugin.teamTemplate)
end

function Clientsetting.saveSettingTxt()
    Clientsetting.saveClientSetting(Root.Instance():getRootPath() .. "document/blockManClientConfig.txt")
end

function Clientsetting.readClientSettingTxt(path)
	m_settingMapping.camera_sensitive = Blockman.instance.gameSettings:getCameraSensitive()
	m_settingMapping.gui_size = Blockman.instance.gameSettings.playerActivityGuiSize
	m_settingMapping.horizon = Blockman.instance.gameSettings:getFovSetting()
	m_settingMapping.isJumpDefault = Blockman.instance.gameSettings.isJumpSneakDefault
	m_settingMapping.luminance = Blockman.instance.gameSettings.gammaSetting
	m_settingMapping.usePole = Blockman.instance.gameSettings.usePole
	m_settingMapping.dropBubble = Blockman.instance.gameSettings.dropBubble
	m_settingMapping.volume = Blockman.instance.gameSettings.musicVolume
	m_settingMapping.renderRange = 1
	m_settingMapping["saveQualityLeve"] = 1

	local editorModeCameraSensitive = Blockman.instance.gameSettings:getEditorModeCameraSensitive()
	if not editorModeCameraSensitive or editorModeCameraSensitive == 0 then
		editorModeCameraSensitive = 0.65
	end
	m_settingMapping["editorModeCameraSensitive"] = editorModeCameraSensitive

--	m_settingMapping.realTime = Blockman.instance.gameSettings.realTime
--	m_settingMapping.screenSoft = Blockman.instance.gameSettings.screenSoft
--	m_settingMapping.squareNormal = Blockman.instance.gameSettings.squareNormal
--	m_settingMapping.roleHighlight = Blockman.instance.gameSettings.roleHighlight
--	m_settingMapping.bloomState = Blockman.instance.gameSettings.bloomState
--	m_settingMapping.diffusionStrength = Blockman.instance.gameSettings.diffusionStrength
--	m_settingMapping.diffusionSampStep = Blockman.instance.gameSettings.diffusionSampStep
	m_settingMapping.isRemind = Blockman.instance.gameSettings.isRemind
	m_settingMapping.isPathRemind = Blockman.instance.gameSettings.isPathRemind
	m_settingMapping.isAreaRemind = Blockman.instance.gameSettings.isAreaRemind

	if PlatformUtil.isPlatformWindows() then
		-- m_settingMapping.mouseState = Blockman.instance.gameSettings.mouseState
		m_settingMapping["mouseState"] = enumMouseState.MOUSE_SHOW
	end

	local file = io.open(path, "r")
	if file == nil then
		Clientsetting.setFirstLoginedInit()
		return m_settingMapping
	end

	for str in file:lines() do
		local t = {}
		local npos = strfind(str, "=")
		if npos then
			local key = strsub(str, 1, npos - 1)
			t[key] = strsub(str, npos + 1)
			m_settingMapping[key] = tonumber(t[key])
		end
	end
	file:close()

	--从res/document/setting_config.json中读取画质等级
	local path = Root.Instance():getRootPath() .. "document/setting_config.json"
	local content = Lib.read_json_file(path)
	if not content then
		content = {}
	end
	local settingConfig = nil
	local videoConfigData = nil
	if content.globalConfig then
		settingConfig = content.globalConfig["audioAndVideoSetting"]
		videoConfigData = settingConfig.videoData
	end
	
	if videoConfigData and videoConfigData.qualityLevel then
		m_settingMapping["saveQualityLeve"] = videoConfigData.qualityLevel
	end
		

	Blockman.instance.gameSettings.gammaSetting = m_settingMapping["luminance"]

	local fGuiSize = m_settingMapping["gui_size"]
	fGuiSize = math.max(0.5, fGuiSize)
	fGuiSize = math.min(1.0, fGuiSize)
	Blockman.instance.gameSettings.playerActivityGuiSize = fGuiSize

	Blockman.instance.gameSettings.dropBubble = m_settingMapping["dropBubble"]
	Blockman.instance.gameSettings.isJumpSneakDefault = m_settingMapping["isJumpDefault"]
	Blockman.instance.gameSettings.musicVolume = m_settingMapping["volume"]
	Blockman.instance.gameSettings.isRemind = m_settingMapping["isRemind"]
	Blockman.instance.gameSettings.isPathRemind = m_settingMapping["isPathRemind"]
	Blockman.instance.gameSettings.isAreaRemind = m_settingMapping["isAreaRemind"]
	
	if PlatformUtil.isPlatformWindows() and not IS_EDITOR then
		-- Blockman.instance.gameSettings.mouseState = math.floor(m_settingMapping["mouseState"])
		m_settingMapping["mouseState"] = math.floor(m_settingMapping["mouseState"])
		Lib.emitEvent(Event.EVENT_CHANGE_MOUSE_STATE, m_settingMapping["mouseState"] == enumMouseState.MOUSE_SHOW)
	end

	--镜头灵敏度
	local cameraSensitive = m_settingMapping["camera_sensitive"]
	Blockman.instance.gameSettings:setCameraSensitive(cameraSensitive)

	--视野
	Blockman.instance.gameSettings:setFovSetting(m_settingMapping["horizon"])

	-- 方块视距
	local curRenderRange = World.cfg.curMaxViewRange or World.cfg.minViewRange or 256
	local curViewRange = math.floor((m_settingMapping["renderRange"]*curRenderRange))
	Blockman.instance.gameSettings:setSpecifiedRenderRange(curViewRange)
	Blockman.instance.gameSettings.usePole = m_settingMapping["usePole"]
	if videoConfigData and videoConfigData.qualityLevel then
		Blockman.instance.gameSettings:setCurQualityLevel(Clientsetting.getGameQualityLeve()) --使用新的配置
	else
		Blockman.instance.gameSettings:setCurQualityLevel(Clientsetting.getGameQualityLeve() - 1)  ---兼容老的配置
	end
	
	return m_settingMapping
end

-- 初次登入视野setting的默认设置值
function Clientsetting.setFirstLoginedInit(path)
	if not m_settingMapping.isFirstLogined then
		m_settingMapping.isFirstLogined = 1
		-- 初始化默认镜头灵敏度
		if World.cfg.initSensitive then
			local minSize = 0.45
			local maxSize = 1.00
			local size = minSize + (maxSize - minSize) * World.cfg.initSensitive
			m_settingMapping["camera_sensitive"] = size
			local cameraSensitive = CGame.instance:getIsEditor() and m_settingMapping["editorModeCameraSensitive"] or m_settingMapping["camera_sensitive"]
			Blockman.instance.gameSettings:setCameraSensitive(cameraSensitive)
		end
		-- 初始化默认视野
		if World.cfg.initHorizon then
			m_settingMapping["horizon"] = World.cfg.initHorizon
			Blockman.instance.gameSettings:setFovSetting(m_settingMapping["horizon"])
		end
		-- 初始化默认方块视距
		if World.cfg.initRenderRangeRate then
			m_settingMapping["renderRange"] = World.cfg.initRenderRangeRate
			local curRenderRange = World.cfg.curMaxViewRange or World.cfg.minViewRange or 256
			local curViewRange = math.floor((m_settingMapping["renderRange"]*curRenderRange))
			Blockman.instance.gameSettings:setSpecifiedRenderRange(curViewRange)
		end
		-- 摇杆按键切换
		if World.cfg.initUsePole then
			m_settingMapping["usePole"] = World.cfg.initUsePole
			Blockman.instance.gameSettings.usePole = m_settingMapping["usePole"]
		end
		Clientsetting.saveSettingTxt()
	end
end

function Clientsetting.saveClientSetting(path)
	local file = io.open(path, "w")
	if not file then
		print(string.format("can't open file: %s", path))
		return
	end

	for k, v in pairs(m_settingMapping) do
		local str = strfmt("%s=%.2f\n", k, v)
		file:write(str)
	end
	file:close()
end
--音量
function Clientsetting.refreshVolume(volume)
    m_settingMapping["volume"] = volume
	Blockman.instance.gameSettings.musicVolume = m_settingMapping["volume"]
	Clientsetting.setVolume()
	Clientsetting.saveSettingTxt()
end
--亮度
function Clientsetting.refreshLuminance(luminance)
    m_settingMapping["luminance"] = luminance
	Blockman.instance.gameSettings.gammaSetting = m_settingMapping["luminance"]
	Clientsetting.saveSettingTxt()
end
--视野
function Clientsetting.refreshHorizon(horizon)
    m_settingMapping["horizon"] = horizon
	Blockman.instance.gameSettings:setFovSetting(m_settingMapping["horizon"])
	Clientsetting.saveSettingTxt()
end
--渲染距离
function Clientsetting.refreshRenderRange(renderRange)
	if renderRange <=0.1 then
		renderRange = 0.1
	elseif renderRange > 1 then
		renderRange = 1
	end
	m_settingMapping["renderRange"] = renderRange
	local curRenderRange = World.cfg.curMaxViewRange or World.cfg.minViewRange or 256
	local curViewRange = math.floor((m_settingMapping["renderRange"]*curRenderRange))
	Blockman.instance.gameSettings:setSpecifiedRenderRange(curViewRange)
	Clientsetting.saveSettingTxt()
end
--按钮大小
function Clientsetting.refreshGuiSize(gui_size)
	local size = 0.5 + (1.0 - 0.5) * gui_size
    m_settingMapping["gui_size"] = size
	Blockman.instance.gameSettings.playerActivityGuiSize = m_settingMapping["gui_size"]
	Clientsetting.saveSettingTxt()
end
--镜头灵敏度
function Clientsetting.refreshCameraSensitive(sensitive)
	local minSize = 0.45
	local maxSize = 1.00
	local size = minSize + (maxSize - minSize) * sensitive
    m_settingMapping["camera_sensitive"] = size
	Blockman.instance.gameSettings:setCameraSensitive(m_settingMapping["camera_sensitive"])
	Clientsetting.saveSettingTxt()
end
--跳跃潜行
function Clientsetting.refreshJumpSneakState(isJumpDefault)
    m_settingMapping["isJumpDefault"] = isJumpDefault
	Blockman.instance.gameSettings.isJumpSneakDefault = m_settingMapping["isJumpDefault"]
	Clientsetting.saveSettingTxt()
end
--操作方式
function Clientsetting.refreshPoleControlState(poleControlState)
    m_settingMapping["usePole"] = poleControlState
	Blockman.instance.gameSettings.usePole = m_settingMapping["usePole"]
	Clientsetting.saveSettingTxt()
end

function Clientsetting.refreshDropBubbleState(dropBubbleState)
	if CGame.instance:getEditorType() ~= 1 then
		return
	end
	local entity_obj = require "editor.entity_obj"
	m_settingMapping["dropBubble"] = dropBubbleState
	Blockman.instance.gameSettings.dropBubble = m_settingMapping["dropBubble"]
	Clientsetting.saveSettingTxt()
	local refreshBubbleList = {"switchMonsterShowBubble", "switchVectorBlockShowBubble"}
	for _,bubble in pairs(refreshBubbleList) do
		entity_obj:allEntityCmd(bubble)
	end
end

local function saveNewUISettingQualityLeve(saveQualityLeve)
	--[[
	new ui, setting use new json save, so when here save, must save the new ui save json.
	cause here may edit in editor.
	]]
	if not saveQualityLeve then
		return
	end
	local file = "setting_config.json"
	local path = Root.Instance():getRootPath() .. "document/"
	local content = Lib.read_json_file(path..file)
	if not content then
		return
	end
	local audioAndVideoSetting = content.globalConfig and content.globalConfig.audioAndVideoSetting
	if not audioAndVideoSetting then
		return
	end
	local videoData = audioAndVideoSetting.videoData
	if not videoData then
		return
	end
	videoData.qualityLevel = saveQualityLeve 
	Lib.saveGameJson1(file, content, path)
end

function Clientsetting.refreshSaveQualityLeve(saveQualityLeve)
	m_settingMapping["saveQualityLeve"] = saveQualityLeve
	Clientsetting.saveSettingTxt()
	saveNewUISettingQualityLeve(saveQualityLeve)
end

function Clientsetting.getEditorModeCameraSensitive()
    return m_settingMapping["editorModeCameraSensitive"] or 0.65
end

function Clientsetting.refreshEditorModeCameraSensitive(editorModeCameraSensitive)
    m_settingMapping["editorModeCameraSensitive"] = editorModeCameraSensitive
    Clientsetting.saveSettingTxt()
end

function Clientsetting.getRemindConsume()
    return m_settingMapping["isConsumeRemind"] or 1
end

function Clientsetting.refreshRemindConsume(isConsumeRemind)
    m_settingMapping["isConsumeRemind"] = isConsumeRemind
    Clientsetting.saveSettingTxt()
end

function Clientsetting.refreshRemindState(isRemind)
   m_settingMapping["isRemind"] = isRemind
   Blockman.instance.gameSettings.isRemind = m_settingMapping["isRemind"]
   Clientsetting.saveSettingTxt()
end

function Clientsetting.refreshPathRemindState(isPathRemind)
   m_settingMapping["isPathRemind"] = isPathRemind
   Blockman.instance.gameSettings.isPathRemind = m_settingMapping["isPathRemind"]
   Clientsetting.saveSettingTxt()
end

function Clientsetting.refreshAreaRemindState(isAreaRemind)
   m_settingMapping["isAreaRemind"] = isAreaRemind
   Blockman.instance.gameSettings.isAreaRemind = m_settingMapping["isAreaRemind"]
   Clientsetting.saveSettingTxt()
end

function Clientsetting.getGameQualityLeve()
	return m_settingMapping["saveQualityLeve"] or World.cfg.defaultQualityLevel or 1
end

function Clientsetting.setVolume()
	TdAudioEngine.Instance():setGlobalVolume(m_settingMapping["volume"])
    SoundSystem.instance:setBackgroundMusicVolume(m_settingMapping["volume"])
	SoundSystem.instance:setEffectsVolume(m_settingMapping["volume"])	
end

-- 鼠标状态（PC）
function Clientsetting:isMouseShow()
	return m_settingMapping["mouseState"] == enumMouseState.MOUSE_SHOW
end
function Clientsetting:refreshMouseState(isShowMouse)
	m_settingMapping["mouseState"] = isShowMouse and enumMouseState.MOUSE_SHOW or enumMouseState.MOUSE_HIDE
	Clientsetting.saveSettingTxt()
end

function Clientsetting:getSetting()
    return m_settingMapping
end

function Clientsetting:getKeySettingDefault()
    return m_keySettingDefault
end

function Clientsetting:getCustomKeySetting()
    return m_customKeySetting
end

function Clientsetting.loadKeySettingDefault()
	local defaultLine = Lib.read_csv_file(Root.Instance():getGamePath().."config/keysettingdefault.csv",2) --ignore second line
	if not defaultLine then
		defaultLine = Lib.read_csv_file(Root.Instance():getRootPath().."Media/Setting/keysettingdefault.csv",2) --ignore second line
	end
	for i, key_item in pairs(defaultLine) do
		local setting = {}
		setting.KeyItemId = tonumber(key_item.KeyItemId)
		setting.KeyCode = tonumber(key_item.KeyCode)
		setting.IsTitle = tonumber(key_item.IsTitle)
		setting.Language = key_item.Language
		m_keySettingDefault[setting.KeyItemId] = setting
		if setting.KeyCode and setting.KeyCode > 0 and setting.KeyCode < 255 then
			m_customKeySetting[setting.KeyCode] = setting.KeyCode
		end
	end
end

function Clientsetting.getKeySetting(id)
    return m_keySettingDefault[id]
end

function Clientsetting.loadCustomKeySetting()
	local path = Root.Instance():getRootPath() .. "document/CustomKeyConfig.txt"
	local file = io.open(path, "r")
	if not file then
		return
	end
	for str in file:lines() do
		local t = {}
		local key = tonumber(strsub(str, 1, strfind(str, "=") - 1))
		t[key] = strsub(str, strfind(str, "=") + 1)
		m_customKeySetting[key] = tonumber(t[key])
	end
	file:close()
end

function Clientsetting.saveCustomKeySetting()
	local path = Root.Instance():getRootPath() .. "document/CustomKeyConfig.txt"
	local file = io.open(path, "w")
	for k, v in pairs(m_customKeySetting) do
		local str = strfmt("%s=%s\n", k, v)
		file:write(str)
	end
	file:close()
end

function Clientsetting.getCustomKeySettingKeyCode(keyCode)
	return m_customKeySetting[keyCode]
end

function Clientsetting.setCustomKeySettingKeyCode(key, keyCode)
	m_customKeySetting[key] = keyCode
end

function Clientsetting.loadVkcode2string()
	local line = Lib.read_csv_file(Root.Instance():getRootPath().."Media/Setting/vkcode2string.csv", 2)
	for i, vkcode_item in pairs(line) do
		m_vkcode2string[tonumber(vkcode_item.KeyCode)] = vkcode_item.KeyString
	end
end

function Clientsetting.string2vkcode(keyString)
	if not keyString then
		return
	end
	local upperKeyString = string.upper(keyString)
	for i, vkcode_item in pairs(m_vkcode2string) do
		if vkcode_item == upperKeyString then
			return i
		end
	end
	return 0
end

function Clientsetting.vkcode2String(keyCode)
	local result = m_vkcode2string[keyCode]
	if not result then
		return
	end
	local upperResult =  string.upper(result)
	return upperResult
end

function Clientsetting.isInvaildString(keyString)
	if not keyString then
		return
	end
	local upperKeyString = string.upper(keyString)
	for i, vkcode_item in pairs(m_vkcode2string) do
		if vkcode_item == upperKeyString then
			return true
		end
	end
	return false
end

function Clientsetting.resetAllKeySetting()
	for i,keySetting_item in pairs(m_keySettingDefault) do
		if keySetting_item.IsTitle < 1 then
				m_customKeySetting[keySetting_item.KeyCode] = keySetting_item.KeyCode
			end
	end
	local msg = Lang:toText("gui_setting_key_reset_all_suc")--send message to menu
end

function Clientsetting.resetItemKey(keyCode)
	for i, keySetting_item in pairs(m_keySettingDefault) do
		if keySetting_item.KeyCode == keyCode then
				m_customKeySetting[keyCode] = keySetting_item.KeyCode
			end
	end
end

function Clientsetting.saveCustomKeySettingToGame()
    for i, customKeySettingItem in pairs(m_customKeySetting) do
		Blockman.instance.gameSettings:setKeySettingMapByKeyCode(i, customKeySettingItem)
	end
end

function Clientsetting.readCustomHandBag(path)
	m_customHandBag = {}
	local itemsList = Clientsetting.getBagItemsList()
	for _, itemsName in pairs(itemsList) do
		m_customHandBag[itemsName] = {}
		for i = 1, MAX_COUNT do
			if itemsName == "allItem" then
				break
			end
			if itemsName ~= "moveBlock" then
				m_customHandBag[itemsName][i] = m_arrayPlugin[itemsName] and m_arrayPlugin[itemsName][i] or nil
			end
		end
	end
	local ok, tmpHandBag = pcall(Lib.read_json_file, path)
	m_customHandBag = tmpHandBag or m_customHandBag 
	if not ok then
		print("[Error] the readCustomHandBag json file parase error!!")
	end
end

function Clientsetting.getBagItemsList()
	local ItemsList = Clientsetting.getData("bagItemsList")
	return ItemsList or {"block", "special", "item", "entity", "moveBlock"}
end

function Clientsetting.getCannotStackList()
	local ItemsList = Clientsetting.getData("cannotStackList")
	return ItemsList or {}
end

function Clientsetting.getEnumStateType()
	return Clientsetting.getData("enumStateType") or {BLOCK = 1, SPECIAL = 2, ITEM = 3, MONSTER = 4, MOVE_BLOCK = 5}
end

function Clientsetting.getCustomHandBag()
    return m_customHandBag
end

function Clientsetting.saveCustomHandBag()
	local path = Root.Instance():getGamePath() .. "customHandbagConfig.json"
    local file, errmsg = io.open(path, "w")
	if not file then
		print(errmsg)
		return false
	end
    local ok, content = pcall(cjson.encode, m_customHandBag)
    assert(ok, path)
    file:write(content)
	file:close()   
end

function Clientsetting.getGuideInfo()
	local path = Root.Instance():getGamePath() .. "guideinfo.json"
	local file = io.open(path, "r")
	if not file then
		return 
	end
	file:close()
	m_guideInfo = Lib.read_json_file(path) or {}
	local userId = tostring(CGame.instance:getPlatformUserId())
	m_localGuideInfo = m_guideInfo[userId] or m_localGuideInfo
	return m_guideInfo[userId]
end

function Clientsetting.setlocalGuideInfo(key, value)
	if not m_localGuideInfo then
		m_localGuideInfo = {}
	end
	m_localGuideInfo[key] = value
end

function Clientsetting.setGuideInfo(key, value, dontSave)
	local userId = tostring(CGame.instance:getPlatformUserId())
	if not m_guideInfo[userId] then
		m_guideInfo[userId] = {}
	end
	m_guideInfo[userId][key] = value
	Clientsetting.setlocalGuideInfo(key, value)
	if not dontSave then
		Clientsetting.saveGuideInfo()
	end
end

function Clientsetting.isKeyGuide(key)
	if m_localGuideInfo[key] == nil then
		m_localGuideInfo = {}
		m_localGuideInfo[key] = true
	end
	local state = CGame.instance:getNetworkState()
	return false --and state and m_localGuideInfo[key]
end

function Clientsetting.saveGuideInfo() 
	local path = Root.Instance():getGamePath() .. "guideinfo.json"
    local file, errmsg = io.open(path, "w")
	if not file then
		print(errmsg)
		return false
	end
    local ok, content = pcall(cjson.encode, m_guideInfo)
    assert(ok, path)
    file:write(Lib.jsonToFormat(content))
	file:close()   
end

function Clientsetting.getUIDescCsvData(index)
	local cmp = function(item1, index)
		if item1.index and item1.index == index then
			return true
		end
		return false
	end
	local uiWidgetPath = "lua/plugins/editor_template/ui_widget_datas.json"
	local sliderList = Lib.read_json_file(Root.Instance():getRootPath()..uiWidgetPath)
	for _, item in ipairs(sliderList) do
		if cmp(item, index) then
			return item
		end
	end
end