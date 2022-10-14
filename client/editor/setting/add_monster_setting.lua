local editorSetting = require "editor.setting"
local addMonsterSetting = L("add_monster", {})
local modName = "add_monster"

local M = addMonsterSetting
local calssName = "main"

function M:save()
	editorSetting:saveCache(modName, calssName)
end

function M:getCfgByKey(key)
    return editorSetting:getValueByKey(modName, calssName, key)
end

function M:saveCfgByKey(key, value, isSave)
	return editorSetting:saveValueByKey(modName, calssName, key, value, isSave)
end

function M:getAddMonsters()
	return self:getCfgByKey("addMonsters")
end

function M:saveAddMonsters(value)
	self:saveCfgByKey("addMonsters", value, true)
end

RETURN(M)
