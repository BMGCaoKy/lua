local editorSetting = require "editor.setting"
local buffSetting = L("buffSetting", {})
local modName = "buff"

local function getNameByFullName(fullName)
	assert(type(fullName) == "string", fullName)
	local splitRet = Lib.splitString(fullName, "/")
	local len = #splitRet
	local name = len > 0 and splitRet[len]
	return name
end

function buffSetting:getBuff(buffName)
	local retCfg
	local name
	if buffName then
		name = getNameByFullName(buffName)
	end
	if name then
		return editorSetting:fetch("buff", name, true)
	end
end

function buffSetting:getCfgByKey(fullName, key)
	local buff = self:getBuff(fullName)
	local buffCfg = buff and buff.cfg
	return buffCfg and buffCfg[key]
end

function buffSetting:saveCfgByKey(fullName, key, value)
	local buff = self:getBuff(fullName)
	local buffCfg = buff and buff.cfg
	if buffCfg then
		buffCfg[key] = value
		buff.isChange = true
	else
		print("nil the buffCfg")
	end
end

function buffSetting:getBuffType(buffName)
	local splitRet = Lib.splitString(buffName, "/")
	local len = #splitRet
	local name = len > 0 and splitRet[len]
	splitRet = Lib.splitString(buffName, "[")
	len = #splitRet
	local type = len > 0 and splitRet[len]
	return type
end



function buffSetting:getIcon(fullName)
	return self:getCfgByKey(fullName, "edit_icon")
end

function buffSetting:getName(fullName)
	return self:getCfgByKey(fullName, "name")
end

function buffSetting:getDescIndex(fullName)
	return self:getCfgByKey(fullName, "desc_index")
end

function buffSetting:getDataUIList(fullName)
	return self:getCfgByKey(fullName, "dataUIList")
end

function buffSetting:getConvert(fullName)
	return self:getCfgByKey(fullName, "sysConvert")
end

function buffSetting:getLevel(fullName)
	return self:getCfgByKey(fullName, "level")
end

function buffSetting:setLevel(fullName, value)
	return self:saveCfgByKey(fullName, "level", value)
end


function buffSetting:save(name)
	editorSetting:saveCache(modName, name)
end


RETURN(buffSetting)
