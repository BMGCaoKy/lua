local itemSetting = require "editor.setting.item_setting"
local blockSetting = require "editor.setting.block_setting"
local buffSetting = require "editor.setting.buff_setting"
local entitySetting = require "editor.setting.entity_setting"

local editorSetting = require "editor.setting"
local skillSetting = require "editor.setting.skill_setting"
local setting = require "common.setting"

local buffTemple = Clientsetting.getBuffTemple()
local break_block_temp =  buffTemple and buffTemple["pressing"].breakEfficient or {}

function M:init()
	WinBase.init(self, "item_base_prop_setting.json")
	self:initUIName()
	self:initUI()
end

function M:initUIName()
	self.itemNameUI = self:child("base_prop_setting-name")
	self.itemPropGridUI = self:child("base_prop_setting-propGrid")
end

function M:initData()
	local cfg = self.cfg
	if not cfg then
		return
	end
	local getEditBaseFunc = cfg.editBaseFunc
	local func = Clientsetting[getEditBaseFunc]
	if not func then
		local data = Clientsetting.getData(getEditBaseFunc)
		if data then
			self.editPropData = data
		end
	else
		self.editPropData = func() 
	end
	self.wantSaveData = { base = {}, addBuff = {}, modifyList = {}, mod = {}}
end

function M:initUI()
	self:child("base_prop_setting-title"):SetText(Lang:toText("editor.ui.itemName"))
	self.itemPropGridUI:InitConfig(0, 30, 1)
end

function M:initItemName()
	local item = self.item
	if not item then
		return
	end
	self.itemNameUI:SetText(Lang:toText(item:getNameText()))
end



function M:getBasePropByPos(pos, fullName, typeSetting)
	local function getHurtDistance()
		local skill = itemSetting:getCfgByKey(fullName, "skill")
		if skill and type(skill) == "table" then
			local key, value = next(skill)
			skill = value
		end
		if skill then
			return skillSetting:getCfgByKey(skill, pos.propKey)
		end
	end
	local function getBreakBlock()
		local breakEff = itemSetting:getPropByBuffType(fullName, "breakEfficient", "handBuff")
		for k, v in pairs(breakEff or {}) do
			for blockName, value in pairs(v) do
				return value * 10000
			end 
		end
	end

	local function apple_hp()
		local extraHp = buffSetting:getCfgByKey(pos.name, "extraHp")
		return extraHp.hp
	end
	local function recoverHp()
		local recoverHpStepByStep = buffSetting:getCfgByKey(pos.name, "recoverHpStepByStep")
		return recoverHpStepByStep.times
	end

	local function lava_damage_var()
		return buffSetting:getCfgByKey(pos.name, "continueDamage")
	end

	local function lava_damage_time()
		return buffSetting:getCfgByKey(pos.name, "buffTime")
	end

	local otherPropGetFunc = {
		["hurtDistance"] = getHurtDistance,
		["break_block"] = getBreakBlock,
		["apple_hp"] = apple_hp,
		["recoverHp"] = recoverHp,
		["lava_damage_var"] = lava_damage_var,
		["lava_damage_time"] = lava_damage_time
	}
	local func = otherPropGetFunc[pos.propKey]
	local value
	if func then
		value = func()
	else
		value = typeSetting:getBasePropByPos(fullName, pos)
	end
	return value
end

function M:setBasePropByPos(pos, value, propItem)
	self.typeSetting:setBasePropDescValue(self.fullName, propItem, value)
	local function setHurtDistance()
		local skill = itemSetting:getCfgByKey(self.fullName, "skill")
		if skill and type(skill) == "table" then
			local k, v = next(skill)
			skill = v
		end
		if skill then
			skillSetting:saveCfgByKey(skill, pos.propKey, value)
		end
		self.wantSaveData.mod["skill" .. skill] = {
			mod = "skill",
			name = skill
		}
	end
	local function setBreakBlock()
		local breakEff = itemSetting:getPropByBuffType(self.fullName, "breakEfficient", "handBuff") or break_block_temp
		for k, v in pairs(breakEff or {}) do
			for blockName, _ in pairs(v) do
				breakEff[k][blockName] = value / 10000
			end 
		end
		itemSetting:setPropByBuffType(self.fullName, "breakEfficient", "handBuff", breakEff)
	end
	local function apple_hp()
		local extraHp = buffSetting:getCfgByKey(pos.name, "extraHp")
		extraHp.hp = value
		buffSetting:saveCfgByKey(pos.name, "extraHp", extraHp)

		self.wantSaveData.mod[pos.mod .. pos.name] = {
			mod = pos.mod,
			name = pos.name
		}
	end
	local function recoverHp()
		local recoverHpStepByStep = buffSetting:getCfgByKey(pos.name, "recoverHpStepByStep")
		recoverHpStepByStep.times = value
		buffSetting:saveCfgByKey(pos.name, "recoverHpStepByStep", recoverHpStepByStep)
		self.wantSaveData.mod[pos.mod .. pos.name] = {
			mod = pos.mod,
			name = pos.name
		}
	end

	local function lava_damage_var()
		buffSetting:saveCfgByKey(pos.name, "continueDamage", value)
		self.wantSaveData.mod[pos.mod .. pos.name] = {mod = pos.mod, name = pos.name}
	end

	local function lava_damage_time()
		buffSetting:saveCfgByKey(pos.name, "buffTime", value)
		self.wantSaveData.mod[pos.mod .. pos.name] = {mod = pos.mod, name = pos.name}
	end

	local function gunCapacity()
		-- 弹夹开关
		itemSetting:setBasePropByPos(self.fullName, pos, value)
		local gunSkillCfg = itemSetting:getCfgByKey(self.fullName, "skill")
		skillSetting:saveCfgByKey(gunSkillCfg[1], "container.takeNum", value and 1 or 0, true)
		self:fetchBaseProp()
	end

	local otherPropGetFunc = {
		["hurtDistance"] = setHurtDistance,
		["break_block"] = setBreakBlock,
		["apple_hp"] = apple_hp,
		["recoverHp"] = recoverHp,
		["container.gunCapacity"] = gunCapacity,
		["lava_damage_var"] = lava_damage_var,
		["lava_damage_time"] = lava_damage_time
	}
	local func = otherPropGetFunc[pos.propKey]
	if func then
		func()
	else
		local mod, name = self.typeSetting:setBasePropByPos(self.fullName, pos, value)
		mod = mod or pos.mod
		if pos.name and not pos.path then
			name = pos.name 
		end
		if mod and name then
			self.wantSaveData.mod[mod .. name] = {
				mod = mod,
				name = name
			}
		end
	end
end

local finishIndex = {
	maxCapacity = "onFinishTextChange",
	initCapacity = "onFinishTextChange",
}

function M:calcGunCapacity(title, value)
	if not self.gunCapacityUi.maxCapacity or not self.gunCapacityUi.initCapacity then
		return
	end
	local maxCapacityValue = self.gunCapacityUi.maxCapacity.value
	local initCapacityValue = self.gunCapacityUi.initCapacity.value
	local maxCapacityUI = self.gunCapacityUi.maxCapacity.ui
	local initCapacityUI = self.gunCapacityUi.initCapacity.ui
	if title == "initCapacity" and initCapacityValue > maxCapacityValue then
		maxCapacityUI:invoke("onEditValueChanged", value)
		self:setBasePropByPos(self.gunCapacityUi.maxCapacity.pos, value, self.gunCapacityUi.maxCapacity.propItem)
	end

	if title == "maxCapacity" and maxCapacityValue < initCapacityValue then
		initCapacityUI:invoke("onEditValueChanged", value)
		self:setBasePropByPos(self.gunCapacityUi.initCapacity.pos, value, self.gunCapacityUi.initCapacity.propItem)
	end

end

function M:createSlider(pos, value, propItem)
	local ui = UILib.createSlider({value = value or 9999999, index = propItem.descIndex or 1, listenType = finishIndex[propItem.desc]}, function(value)
		if propItem.SysConvert then
			value = value * propItem.SysConvert
		end
		self:setBasePropByPos(pos, value, propItem)
		if finishIndex[propItem.desc] then
			self.gunCapacityUi[propItem.desc].value = value
			self:calcGunCapacity(propItem.desc, value)
		end
	end)
	if finishIndex[propItem.desc] then
		self.gunCapacityUi[propItem.desc] = {
			ui = ui,
			value = value,
			pos = pos,
			propItem = propItem,
		}
	end
	return ui
end

function M:createSwitch(pos, value, propItem)
	local ui = UILib.createSwitch({
		value = value or false,
		index = propItem.descIndex or 1
	}, function(value)
		self:setBasePropByPos(pos, value, propItem)
	end)
	return ui
end

function M:createButton(pos, value, propItem)
	local ui = UILib.createButton({itemType = self.itemType, fullName = self.fullName, propItem = propItem}, function(dropData)
		self.typeSetting:saveCfgByKey(self.fullName, propItem.pos.propKey, dropData)
	end)
	return ui
end

function M:fetchBaseProp()
	self.itemPropGridUI:RemoveAllItems()
	local base = self.editPropData.base
	local gunCapacityValue
	for _, propItem in pairs(base or {}) do
		local pos = propItem.pos
		local value = self:getBasePropByPos(pos, self.fullName, self.typeSetting)
		if not value and pos.propKey == "hurtDistance" then
			goto continue
		end 
		if pos.propKey == "container.gunCapacity" then
			gunCapacityValue = value
		end
		if (pos.propKey == "container.maxCapacity" or pos.propKey == "container.initCapacity") and not gunCapacityValue then
			goto continue
		end
		if propItem.SysConvert and value then
			value = value / propItem.SysConvert
		end
		local uiType = propItem.uiType or "slider"
		local ui
		if uiType == "slider" then
			ui = self:createSlider(pos, value, propItem)
		elseif uiType == "switch" then
			ui = self:createSwitch(pos, value, propItem)
		elseif uiType == "button" then
			ui = self:createButton(pos, value, propItem)
		end
		self.itemPropGridUI:SetXPosition({0, 40})
		self.itemPropGridUI:AddItem(ui)
		::continue::
	end
end

function M:fetchAppendBuff()
	-- print("saveafter4============", "myplugin/item_buff3[damage", Lib.v2s(buffSetting:getBuff("myplugin/item_buff3[damage")))
	local function newAddBtn()
		local btn = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "button")
		btn:SetArea({0, 0}, {0, 0}, {0, 140}, {0, 140})
		btn:SetImage("set:setting_global.json image:btn_add_player_actor_a.png")
		self:subscribe(btn, UIEvent.EventWindowClick, function()
			-- open window
            local appendBuffNameList = self:getTypeBuffInfoList()
            local buffList = self:getBuffList(self.cfg)
            if not (appendBuffNameList and buffList) or (#appendBuffNameList < #buffList) then
				UI:openWnd("mapEditBuffSetting", self.fullName, self.cfg, self)
            else
                Lib.emitEvent(Event.EVENT_TOAST_TIP, Lang:toText("cant_add_already_buff"), 20)
            end
		end)
		return btn
	end

	local function newBuffItemUI(self, buffName)
		local itemUI = GUIWindowManager.instance:LoadWindowFromJSON("buffCell.json")
		local icon = self:getBuffIcon(buffName)
		local name = Lang:toText(self:getBuffName(buffName))
		local level = self:getBuffLevel(buffName)
		if level and level > 0 then
			name = name .. "(" .. level .. "lv)"
		end
		itemUI:child("buffCell-icon"):SetImage(icon)
		itemUI:child("buffCell-name"):SetText(name)
		return itemUI
	end
	-- todo new add btn
	local gridLayout = GUIWindowManager.instance:LoadWindowFromJSON("buffList.json")

	gridLayout:child("buffGrid-name"):SetText(Lang:toText("editor.ui.itemBuff"))
	local buffGrid = gridLayout:child("buffGrid-buffList")
	
	local function addBuffItem(self, item, row, cellWidth, index)
		local cellHegiht = 190
		buffGrid:AddChildWindow(item)
		item:SetXPosition({0, (index % row) * cellWidth})
		local height = math.floor(index / row) * cellHegiht
		item:SetYPosition({0, height})
		gridLayout:SetArea({0, 0}, {0, 0}, {0, 700}, {0, height + cellHegiht})

		local close = item:child("buffCell-close")
		local edit = item:child("buffCell-jumpSetting")
		if not close then
			return
		end
		self:subscribe(close, UIEvent.EventButtonClick, function()
			self:delBuff(index)
		end)
		self:subscribe(edit, UIEvent.EventButtonClick, function()
			self:popEditBuff(index)
		end)
	end

	local function removeAllBuffUI()
		local count = buffGrid:GetChildCount()
		for i = 1, count do
			local child = buffGrid:GetChildByIndex(0)
			buffGrid:RemoveChildWindow1(child)
		end
	end

	
	removeAllBuffUI()
	if self.buffLayout then
		self.itemPropGridUI:RemoveItem(self.buffLayout)
	end
	self.buffLayout = gridLayout
	local index = 0
	local appendBuffNameList = self:getTypeBuffInfoList()
	addBuffItem(self, newAddBtn(), 3, 182, index)
	for _, buffName in pairs(appendBuffNameList) do
		-- print("saveafter3============", buffName, Lib.v2s(buffSetting:getBuff(buffName)))
		local item = newBuffItemUI(self, buffName)
		index = index + 1
		addBuffItem(self, item, 3, 182, index)
	end
	self.itemPropGridUI:AddItem(gridLayout)
end

function M:getBuffValue(buffName)
	local function getValue(oValue)
		if type(oValue) == "table" then
			for k , v in pairs(oValue) do
				if type(v) == "number" then
					return v
				elseif type(v) == "table" then
					return getValue(v)
				end 
			end
		end
	end

	local buffType = self:getBuffType(buffName)
	local level = buffSetting:getLevel(buffName)
	local buffTemple = Clientsetting.getBuffTemple()
	local modifyListKey = buffType .. "_modify"
	local modifyList = buffTemple and buffTemple[modifyListKey]
	local convert = self:getConvert(buffName) or {}
	local ret = {}

	for i, modifyKey in ipairs(modifyList or {}) do
		local oValue = buffSetting:getCfgByKey(buffName, modifyKey)
		if type(oValue) == "number" then
			ret[#ret+1] = buffSetting:getCfgByKey(buffName, modifyKey) / (convert[i] or 1)
		else
			local v = getValue(oValue)
			ret[#ret+1] = v  / (convert[i] or 1)
		end
	end
	return ret
end

function M:popEditBuff(index)
	local buffList = self:getTypeBuffInfoList()
	local buffName = buffList[index]
	local value = self:getBuffValue(buffName)
	local buffIcon = self:getBuffIcon(buffName)
	local descIndex = self:getBuffDesc(buffName)
	local title = self:getBuffTitle(buffName)
	local dataUIList = self:getDataUIList(buffName)
	for i, v in ipairs(dataUIList or {}) do
		v.value = value[i] or 3
	end

	local desktop = GUISystem.instance:GetRootWindow()
	local ui = UIMgr:new_widget("leftTab")
	local function sureOnSaveBackFunc(value)
		local buffType = self:getBuffType(buffName)
		self:modifyBuff(buffName, value[1], buffType)
		self.wantSaveData.modifyList[buffName] = {
			value = value[1]
		}
		desktop:RemoveChildWindow1(ui)
		self:fetchAppendBuff()
	end

	local function cancelFunc()
		local buffItem = self.wantSaveData.modifyList[buffName] 
		local buffType = self:getBuffType(buffName)
		if buffItem then
			self:modifyBuff(buffName, buffItem.value, buffType)
			buffSetting:saveCfgByKey(buffName, "level", buffItem.level)
			editorSetting:saveCache("buff", buffName)
		end
		desktop:RemoveChildWindow1(ui)
	end
	ui:invoke("fillData", {
		tabDataList = {
			{
				leftTabName = "editor.ui.setCount",
				widgetName = "baseProp",
				params = {
					title = title,
					dataUIList = dataUIList or {
						{
							type = "slider",
							index = descIndex or 1, 
							value = value[1],
						},
						--{ 先去掉level属性
						--	type = "slider",
						--	index = 1, 
						--	value = level,
						--}
					}
				},
			}
		},
		sureOnSaveBackFunc = sureOnSaveBackFunc,
		cancelFunc = cancelFunc
	})
	ui:SetLevel(8)
	desktop:AddChildWindow(ui)
end

function M:getTypeBuffInfoList()
	local cfg = self.cfg
	if cfg and cfg.useAddBuff then
		return itemSetting:getUseBuffList(self.fullName) or {}
	else
		return self.itemType == "item" and itemSetting:getTypeBuffList(self.fullName) or {}
	end
end

function M:setTypeBuffInfoList(value)
	local cfg = self.cfg
	if cfg and cfg.useAddBuff then
		itemSetting:setUseBuffList(self.fullName, value)
	else
		itemSetting:setTypeBuffList(self.fullName, value)
	end

end

function M:addBuff(buffName, value, buffType)
	if not self.cfg.editBuffList then
		return
	end
	--buffSetting:saveCfgByKey(buffName, "level", value[1][2]) 先注释点buff等级属性
	local setBuffTemp = Clientsetting.getBuffTemple()
	local buffTemple = setBuffTemp and setBuffTemp[buffType]
	assert(buffTemple, "can not find buffTemple")
	for k, v in pairs(buffTemple) do
		buffSetting:saveCfgByKey(buffName, k, v)
	end
	self.wantSaveData.modifyList[buffName] = {
		value = value[1]
	}

	self:modifyBuff(buffName, value[1], buffType)
	local typeBuffList = self:getTypeBuffInfoList()
	if typeBuffList then
		typeBuffList[#typeBuffList + 1] = buffName
	end
	self:setTypeBuffInfoList(typeBuffList)
	self:fetchAppendBuff()
end

function M:delBuff(index)
	local buffList = self:getTypeBuffInfoList()
	table.remove(buffList, index)
	self:setTypeBuffInfoList(buffList)
	self:fetchAppendBuff()
end

function M:modifyBuff(buffName, value, buffType)
	if not value then
		return
	end
	local convert = self:getConvert(buffName) or {}
	local function modifyValue(oValue, number, i)
		if type(oValue) == "table" then
			for k , v in pairs(oValue) do
				if type(v) == "number" then
					oValue[k] = number * (convert[i] or 1)
				elseif type(v) == "table" then
					modifyValue(v, number, i)
				end 
			end
		end
	end

	local buffTemple = Clientsetting.getBuffTemple()
	local modifyListKey = buffType .. "_modify"
	local modifyList = buffTemple and buffTemple[modifyListKey]
	for i, modifyKey in ipairs(modifyList or {}) do
		local oValue = buffSetting:getCfgByKey(buffName, modifyKey)
		if type(oValue) == "number" then

			buffSetting:saveCfgByKey(buffName, modifyKey, value[i] * (convert[i] or 1))
		else
			modifyValue(oValue, value[i], i)
			buffSetting:saveCfgByKey(buffName, modifyKey, oValue)
		end
	end
end

function M:getBuffList(cfg)
    local editBuffList = cfg.editBuffList
	local func = Clientsetting[editBuffList]
	local buffList = {}

	if not func then
		local data = Clientsetting.getData(editBuffList)
		if data then
			buffList = data
		end
	else
		buffList = func() 
	end
    return buffList
end

function M:getBuffType(buffName)
	return buffSetting:getBuffType(buffName)
end

function M:getBuffIcon(buffName)
	return buffSetting:getIcon(buffName)
end

function M:getBuffLevel(buffName)
	return buffSetting:getLevel(buffName)
end

function M:getBuffName(buffName)
	return buffSetting:getName(buffName)
end

function M:getBuffDesc(buffName)
	return buffSetting:getDescIndex(buffName)
end

function M:getBuffTitle(buffName)
	return buffSetting:getName(buffName)
end

function M:getDataUIList(buffName)
	return buffSetting:getDataUIList(buffName)
end

function M:getConvert(buffName)
	return buffSetting:getConvert(buffName)
end

function M:onSave()
	-- 保存增加的buff
	self.typeSetting:save(self.fullName)
	local propDesc 
	if self.typeSetting.getCfgByKey then
		propDesc = self.typeSetting:getCfgByKey(self.fullName, "desc")
	end
	Lib.emitEvent(Event.EVENT_SETTING_BASE_PROP_UPDATE, {fullName = self.fullName, propDesc = propDesc})
	for _, saveItem in pairs(self.wantSaveData.mod) do
		editorSetting:saveCache(saveItem.mod, saveItem.name)
	end
	local list = self:getTypeBuffInfoList()
	for _, buffName in pairs(list or {}) do
		editorSetting:saveCache("buff", buffName)
	end
end

function M:onCancel()
	self.typeSetting:cancel(self.fullName)
	for _, saveItem in pairs(self.wantSaveData.mod) do
		editorSetting:clearData(saveItem.mod, saveItem.name)
	end
	local list = self:getTypeBuffInfoList()
	for _, buffName in pairs(list or {}) do
		editorSetting:clearData("buff", buffName)
	end
end

function M:onOpen(params)
	self.itemPropGridUI:ResetPos()
	local item
	if params then
		item = params.item
		self.item = item
	end
	self.buffLayout = nil
	self.gunCapacityUi = {}
	self.itemType = params and params.itemType or (item and item:type()) or "item"
	self.fullName = params and params.fullName or "myplugin/16"
	if self.itemType == "block" then
		self.cfg = setting:fetch("block", setting:id2name("block", item:block_id()))
	else
		self.cfg = params.cfg or setting:fetch(self.itemType, self.fullName)
	end
	if self.itemType == "item" then
		self.typeSetting = itemSetting
	elseif self.itemType == "entity" then
		self.typeSetting = entitySetting
	else
		self.typeSetting = blockSetting
	end
	self:initData()
	self:initItemName()
	self:fetchBaseProp()
	if self.cfg.editBuffList then
		self:fetchAppendBuff()
	end
end

return M