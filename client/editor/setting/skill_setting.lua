local editorSetting = require "editor.setting"
local skillSetting = L("skillSetting", {})
local modName = "skill"

function skillSetting:getCfgByKey(fullName, key)
	assert(fullName)
    return editorSetting:getValueByKey(modName, fullName, key)
end

function skillSetting:saveCfgByKey(fullName, key, value, isSave)
	assert(fullName)
	return editorSetting:saveValueByKey(modName, fullName, key, value, isSave)
end

RETURN(skillSetting)
