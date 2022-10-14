local editorSetting = require "editor.setting"
local compositeSetting = L("composite", {})
local modName = "composition"

--目前合成只是用到了 composition/mian， 且只用了第一个合成配置
local M = compositeSetting
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

function M:getComposites()
	return self:getCfgByKey("composites")
end

function M:saveComposites(value)
	self:saveCfgByKey("composites", value)
end

function M:getMainComposite()
    if not self:canSetComposition() then
        return false
    end
	local com = self:getComposites()
	return com and com[1]
end

function M:canSetComposition()
    if self.canComposition == nil then
        local dirPath = Root.Instance():getGamePath() .. "plugin/myplugin/" .. modName .. "/" .. calssName
        local filePath = dirPath .. "/setting.json"
        local file, err = io.open(filePath, "r")
        if file then
            file:close()
            self.canComposition = true
        else
            self.canComposition = false
        end
    end
    return self.canComposition
end

RETURN(M)
