local editorSetting = require "editor.setting"
local setting = require "common.setting"
local entity_obj = require "editor.entity_obj"
local buffSetting = require "editor.setting.buff_setting"
local entitySetting = L("entitySetting", {})
local globalSetting = require "editor.setting.global_setting"
local modName = "entity"

local relevanceSave = {}

function relevanceSave.actorName(fullName, value, isSave)
	if not fullName == "player1" then
		return
	end
	local isOpenImmue = value == "character_new_red_mario_nohat.actor" or value == "character_new_blue_mario.actor"
	--editorSetting:saveValueByKey("global", nil, "isOpenImmue", isOpenImmue, isSave) 先注释关闭伤害免疫。
end

function entitySetting:getCfgByKey(fullName, key)
    assert(fullName)
    return editorSetting:getValueByKey(modName, fullName, key)
end

function entitySetting:saveCfgByKey(fullName, key, value, isSave)
    assert(fullName)
	if relevanceSave[key] then
		relevanceSave[key](fullName, value, isSave)
	end
	return editorSetting:saveValueByKey(modName, fullName, key, value, isSave)
end

local function getNameByFullName(fullName)
	assert(type(fullName) == "string", fullName)
	local splitRet = Lib.splitString(fullName, "/")
	local len = #splitRet
	local name = len > 0 and splitRet[len]
	return name
end

function entitySetting:parsePath(fullName, pos)
	local name = pos.name
	local path = pos.path
	if path and path:sub(1, 1) == "$" then
		local index = path:find("/")
		if index then
			name = self:getCfgByKey(fullName, path:sub(2, index - 1))
			if name and type(name) == "table" then
				local key, value = next(name)
				name = value
			end
		end
	end
	name = getNameByFullName(name)
	return name
end

function entitySetting:getMaxHp(fullName)
	return self:getCfgByKey(fullName, "maxHp")
end

function entitySetting:saveMaxHp(fullName, value, isSave)
	self:saveCfgByKey(fullName, "maxHp", value, isSave)
end

function entitySetting:getMoveSpeed(fullName)
	return self:getCfgByKey(fullName, "moveSpeed")
end

function entitySetting:saveMoveSpeed(fullName, value, isSave)
	self:saveCfgByKey(fullName, "moveSpeed", value, isSave)
    local buffs = self:getCfgByKey(fullName, "moveSpeedRelatedBuffs")
	for k, v in pairs(buffs or {}) do
		buffSetting:saveCfgByKey(k, "moveSpeed", value * v)
        buffSetting:saveCfgByKey(k, "swimSpeed", value * v)
		buffSetting:save(k)
    end
end

function entitySetting:getJumpSpeed(fullName)
	return self:getCfgByKey(fullName, "jumpSpeed")
end

function entitySetting:saveJumpSpeed(fullName, value, isSave)
	return self:saveCfgByKey(fullName, "jumpSpeed", value, isSave)
end

function entitySetting:getOriDamage(fullName)
	return self:getCfgByKey(fullName, "oriDamage")
end

function entitySetting:setOriDamage(fullName, value, isSave)
	return self:saveCfgByKey(fullName, "oriDamage", value, isSave)
end

function entitySetting:getCanAttackObject(fullName)
	return self:getCfgByKey(fullName, "canAttackObject")
end

function entitySetting:setCanAttackObject(fullName, value, isSave)
	return self:saveCfgByKey(fullName, "canAttackObject", value, isSave)
end

function entitySetting:getIcon(fullName)
	return self:getCfgByKey(fullName, "icon")
end

function entitySetting:getName(fullName)
	return self:getCfgByKey(fullName, "name")
end

function entitySetting:delShopName(groupName,save)
	local fullName
	entity_obj:allEntityCmd("setShopGroup", function(entity)
		local entityName = entity:cfg().fullName
		local cfg = self:getCfg(entityName)
		local merchantGroupName = cfg and cfg.shopGroupName
		if entityName == fullName then
			return true
		elseif merchantGroupName == groupName then
			entitySetting:saveCfgByKey(entityName, "shopGroupName", nil, save)
			entitySetting:saveCfgByKey(entityName, "damageByCollision", true, save)
			fullName = entityName
			return true
		end
	end)
end

function entitySetting:setShopName(fullName, groupName, save)
	entitySetting:saveCfgByKey(fullName, "shopGroupName", groupName, save)
	entitySetting:saveCfgByKey(fullName, "damageByCollision", not groupName, save)
	entity_obj:allEntityCmd("setShopGroup", function(entity)
		if entity:cfg().fullName == fullName then
			return true
		end
	end)
end

function entitySetting:setHpTextOpen(fullName, open, isSave)
	self:saveCfgByKey(fullName, "hideHp", open and 0 or 1, isSave)
end

function entitySetting:setReviveTime(fullName, time, isSave)
	self:saveCfgByKey(fullName, "reviveTime", time, isSave)
end

function entitySetting:getReviveTime(fullName, time, isSave)
	return self:getCfgByKey(fullName, "reviveTime")
end

function entitySetting:getKillScore(fullName)
	return self:getCfgByKey(fullName, "addScore")
end

function entitySetting:setKillScore(fullName, value, isSave)
	self:saveCfgByKey(fullName, "addScore", value, isSave)
end

function entitySetting:getDamagebByCollision(fullName, value, isSave)
	self:getCfgByKey(fullName, "damageByCollision")
end

function entitySetting:setDamagebByCollision(fullName, open, isSave)
	self:saveCfgByKey(fullName, "damageByCollision", open, isSave)
end

function entitySetting:getActor(fullName)
	self:getCfgByKey(fullName, "actorName")
end

function entitySetting:setActor(fullName, actorName, isSave)
	self:saveCfgByKey(fullName, "actorName", actorName, isSave)
end

function entitySetting:clearData(name)
    editorSetting:clearData(modName, name)
end

function entitySetting:getBasePropByPos(fullName, pos)
	local cfg = EditorModule:getCfg("entity", fullName)
	if not pos.mod then
		pos.mod = modName
	end
	if pos.isSelf then
		return cfg and cfg[pos.propKey]
	else
		local name = self:parsePath(fullName, pos)
		return editorSetting:getValueByKey(pos.mod, name, pos.propKey)
	end
end

function entitySetting:setBasePropByPos(fullName, pos, value)
	if not pos.mod then
		pos.mod = modName
	end
	if pos.isSelf then
		self:saveCfgByKey(fullName, pos.propKey, value)
	else
		local name = self:parsePath(fullName, pos)
		editorSetting:saveValueByKey(pos.mod, name, pos.propKey, value)
		return pos.mod, name
	end
end

function entitySetting:save(name)
	self:createDesc(name)
	editorSetting:saveCache(modName, name)

	local oldCfg = setting:fetch(modName, name)
	local newCfg = self:getCfg(name)
	if modName ~= "entity" or not oldCfg or not newCfg or oldCfg.hideHp == newCfg.hideHp then
		return
	end
	oldCfg.hideHp = newCfg.hideHp
	for _, entity in ipairs(World.CurWorld:getAllEntity()) do
		if entity:cfg().fullName == name then
			entity:setEditorModHideHp(newCfg.hideHp > 0 and "true" or "false")
		end
	end
end

function entitySetting:cancel(name)
	editorSetting:clearData(modName, name)
end

function entitySetting:createDesc(fullName)
	local function getBuffType(buffName)
		local splitRet = Lib.splitString(buffName, "/")
		local len = #splitRet
		local name = len > 0 and splitRet[len]
		splitRet = Lib.splitString(buffName, "[")
		len = #splitRet
		local type = len > 0 and splitRet[len]
		return type
	end

	local cfg = self:getCfg(fullName)
	local desc = cfg.desc
	local baseDesc = cfg.baseDesc
	if desc then
		local index = desc:find("{") 
		if not index then
			self:saveCfgByKey(fullName, "baseDesc", desc)
			baseDesc = desc
		end
	end
	local resultDesc = ""
	if baseDesc then
		resultDesc = resultDesc .. "{" .. baseDesc .. "}" .. "\n" 
	end
	local basePropDesc = cfg and cfg.basePropDesc
	for lang, valueItem in pairs(basePropDesc or {}) do
		local valueDescRes = ""
		for _, valueDesc in pairs(valueItem) do
			if type(valueDesc) == "string" then
				valueDescRes = valueDescRes .. "{" .. valueDesc .."}"
			elseif type(valueDesc) == "boolean" then
				goto continue

			else
				valueDescRes = valueDescRes .. valueDesc
			end
		end
		if tonumber( valueDescRes ) ~= 0 then
			local propDesc = "{" .. lang .. "}" .. valueDescRes
			resultDesc = resultDesc .. propDesc .. "\n"
		end
		::continue::
	end

	-- local buffList = self:getTypeBuffList(fullName) or {}
	-- local buffDesc = "" 
	-- for index, v in pairs(buffList) do
	-- 	local buffName = getBuffType(v)
	-- 	if buffDesc == "" then
	-- 		buffDesc = "{attach_buff_desc}"
	-- 	end
	-- 	if index ~= 1 then
	-- 		buffDesc = buffDesc .. ",{" .. buffName .."}"
	-- 	else
	-- 		buffDesc = buffDesc .. "{" ..  buffName .."}"
	-- 	end
	-- end
	-- resultDesc = resultDesc .. buffDesc
	self:saveCfgByKey(fullName, "desc", resultDesc)
end

function entitySetting:setBasePropDescValue(fullName, propItem, value)
	local cfg = self:getCfg(fullName)
	local basePropDesc = cfg and cfg.basePropDesc
	if not basePropDesc then
		basePropDesc = {}
	end
	local descIndex = propItem.descIndex
	local descDataItem = Clientsetting.getUIDescCsvData(descIndex)
	local descTitleLangKey = descDataItem.title
	local descTaildLangKey = descDataItem.tailText
	local sysConvert = propItem.SysConvert
	if  sysConvert  and sysConvert ~=0 then
		value = value / sysConvert
	end
	basePropDesc[descTitleLangKey] = {
		value, descTaildLangKey
	}
	self:saveCfgByKey(fullName, "basePropDesc", basePropDesc)
end

function entitySetting:getCfg(fullName)
    local data = editorSetting:fetch(modName, fullName)
	return Lib.copy(data and data.cfg)
end

RETURN(entitySetting)