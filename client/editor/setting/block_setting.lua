local editorSetting = require "editor.setting"
local blockSetting = L("blockSetting", {})
local modName = "block"

local function getNameByFullName(fullName)
	assert(type(fullName) == "string", fullName)
	local splitRet = Lib.splitString(fullName, "/")
	local len = #splitRet
	local name = len > 0 and splitRet[len]
	return name
end

function blockSetting:getCfgByKey(fullName, key)
	local name = getNameByFullName(fullName)
    return editorSetting:getValueByKey(modName, name, key)
end

function blockSetting:saveCfgByKey(fullName, key, value, isSave)
	local name = getNameByFullName(fullName)
	return editorSetting:saveValueByKey(modName, name, key, value, isSave)
end

function blockSetting:getBasePropByPos(fullName, pos)
	if not pos.mod then
		pos.mod = modName
	end
	if pos.isSelf then
		return self:getCfgByKey(fullName, pos.propKey)
	end
end

function blockSetting:setBasePropByPos(fullName, pos, value)
	if not pos.mod then
		pos.mod = modName
	end
	if pos.isSelf then
		self:saveCfgByKey(fullName, pos.propKey, value)
	end
end

function blockSetting:save(fullName)
	local name = getNameByFullName(fullName)
	self:createDesc(fullName)
	editorSetting:saveCache(modName, name)

	-- 处理批量特殊操作的东西
	local changeGroup = self:getCfgByKey(fullName, "changeGroup")
	local ignoreList = {
		"texture",
		"changeGroup",
		"quads",
		"isOpaqueFullCube",
		"color",
		"defaultTexture",
		"base",
		"_baseDesc",
		"_desc",
		"dropItemList",
		"itemname",
		"climbDirType",
		"attackSide"
	}
	local cfg = self:getCfg(fullName)
	local function canChange(key2)
		for _, key1 in pairs(ignoreList) do
			if key1 == key2 then
				return false
			end
		end
		return true
	end
	for _, name in pairs(changeGroup or {}) do
		for key, value in pairs(cfg) do
			if canChange(key) then
				self:saveCfgByKey(name, key, value)
			end
		end
		self:save(name)
	end

end

function blockSetting:cancel(fullName)
	local name = getNameByFullName(fullName)
	editorSetting:clearData(modName, name)
end

function blockSetting:createDesc(fullName)
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
	local baseDesc = cfg.baseDesc or "base_block_desc"
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
			elseif type(valueDesc) == "table" then
				goto continue
			else
				valueDescRes = valueDescRes .. valueDesc
			end
		end
		if tonumber( valueDescRes ) ~= 0 then
			local propDesc = "{" .. lang .. "}" .. ":" .. valueDescRes
			resultDesc = resultDesc .. propDesc .. "\n"
		end
		::continue::
	end
	self:saveCfgByKey(fullName, "desc", resultDesc)
end

function blockSetting:getCfg(fullName)
    local data = editorSetting:fetch(modName, fullName)
	return Lib.copy(data and data.cfg)
end

function blockSetting:setBasePropDescValue(fullName, propItem, value)
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

RETURN(blockSetting)
