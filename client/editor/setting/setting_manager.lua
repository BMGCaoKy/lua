local editorSetting = require "editor.setting"
local settingManager = L("settingManager", {})

function settingManager:getValByKey(key)
    return editorSetting:getValueByKey(modName, nil, key)
end


RETURN(globalSetting)
