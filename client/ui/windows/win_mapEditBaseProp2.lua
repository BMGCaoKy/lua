local entitySetting = require "editor.setting.entity_setting"
local buffSetting = require "editor.setting.buff_setting"
local editorSetting = require "editor.setting"
local skillSetting = require "editor.setting.skill_setting"
local setting = require "common.setting"

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
	local getEditBaseFunc = cfg.editBaseFunc
	local func = Clientsetting[getEditBaseFunc]
	if func then
		self.editPropData = func() 
	end
	self.wantSaveData = { base = {}, addBuff = {}, modifyList = {}, mod = {}}
end

function M:initUI()
	self:child("base_prop_setting-title"):SetText(Lang:toText("editor.ui.itemName"))
	self.itemPropGridUI:InitConfig(0, 30, 1)
	self.itemPropGridUI:SetAutoColumnCount(true)
end

function M:initItemName()
	local item = self.item
	if not item then
		return
	end
	self.itemNameUI:SetText(Lang:toText(item:getNameText()))
end

function M:getBasePropByPos(pos, fullName)
	local function isReviveTime()
		local value = entitySetting:getReviveTime(fullName)
		local enable = entitySetting:getCfgByKey(fullName, "editorEnableReviveTime")
		return value and true or (enable and true or false)
	end
	local function reviveTime()
		local value = entitySetting:getCfgByKey(fullName, "editorReviveTime")
		return value or 1
	end
    local function hideHp()
        return entitySetting:getBasePropByPos(fullName, pos) == 0
    end
	local otherPropGetFunc = {
		["isReviveTime"] = isReviveTime,
		["reviveTime"] = reviveTime,
        ["hideHp"] = hideHp
	}
	local func = otherPropGetFunc[pos.propKey]
	local value
	if func then
		value = func()
	else
		value = entitySetting:getBasePropByPos(fullName, pos)
	end
	return value
end

function M:setBasePropByPos(pos, value, propItem)
	local function hideHp()
		entitySetting:setBasePropByPos(self.fullName, pos, value and 0 or 1)
    end
	local function isReviveTime()
		entitySetting:saveCfgByKey(self.fullName, "editorEnableReviveTime", value)
		local time = entitySetting:getCfgByKey(self.fullName, "editorReviveTime")
		if value then
			entitySetting:setReviveTime(self.fullName, time or 20)
		else
			entitySetting:setReviveTime(self.fullName, nil)
		end

		entitySetting:setBasePropDescValue( self.fullName, {
			descIndex = 2008,
			SysConvert = value and 20,
		}, value and ( time or 20 ) )
	end

	local function reviveTime()
		entitySetting:saveCfgByKey(self.fullName, "editorReviveTime", value)
		local enable = entitySetting:getCfgByKey(self.fullName, "editorEnableReviveTime")
		if enable then
			entitySetting:setReviveTime(self.fullName, value or 20)
			entitySetting:setBasePropDescValue( self.fullName, propItem, value )
		end
	end
	local otherPropGetFunc = {
		["isReviveTime"] = isReviveTime,
		["reviveTime"] = reviveTime,
		["hideHp"] = hideHp
	}
	local func = otherPropGetFunc[pos.propKey]
	if func then
		func()
	else
		entitySetting:setBasePropDescValue(self.fullName, propItem, value)
		entitySetting:setBasePropByPos(self.fullName, pos, value)
	end
end

function M:fetchBaseProp()
	self.itemPropGridUI:RemoveAllItems()
	local base = self.editPropData.base
	for _, propItem in pairs(base or {}) do
		local pos = propItem.pos
		local value = self:getBasePropByPos(pos, self.fullName)
		if propItem.SysConvert and value then
			value = value / propItem.SysConvert
		end
		local uiType = propItem.uiType or "slider"
		local ui
		if uiType == "slider" then
			ui = UILib.createSlider({value = value or 9999999, index = propItem.descIndex or 1}, function(value)
				if propItem.SysConvert then
					value = value * propItem.SysConvert
				end
				self:setBasePropByPos(pos, value, propItem)
			end)
		elseif uiType == "switch" then
			ui = UILib.createSwitch({
				value = value or false,
				index = propItem.descIndex or 1
			}, function(value)
				self:setBasePropByPos(pos, value, propItem)
			end)
		end
		self.itemPropGridUI:SetXPosition({0, 40})
		self.itemPropGridUI:AddItem(ui)
	end
end

function M:onSave()
	-- 保存增加的buff
	entitySetting:save(self.fullName)
end

function M:onCancel()
	entitySetting:cancel(self.fullName)
end

function M:onOpen(params)
	if params then
		local item = params.item
		self.item = item
	end
	self.buffLayout = nil
	self.itemType = params and params.itemType or "entity"
	self.fullName = params and params.fullName or "myplugin/16"
	self.cfg = setting:fetch("entity", self.fullName)
	self:initData()
	self:initItemName()
	self:fetchBaseProp()
end

return M