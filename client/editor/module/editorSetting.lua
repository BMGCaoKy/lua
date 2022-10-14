local editorSetting = L("editorSetting", Lib.derive(EditorModule.baseDerive))
local editorSetting = require "editor.setting"

local function getNameByFullName(fullName)
    if not fullName then
        return
    end
	assert(type(fullName) == "string", fullName)
	local splitRet = Lib.splitString(fullName, "/")
	local len = #splitRet
	local name = len > 0 and splitRet[len]
	return name
end

function editorSetting:fetchCfg(mod, name)
	name = getNameByFullName(name)
    local ret = editorSetting:fetch(mod, name)
    assert(ret and ret.cfg)
    local retCfg = ret.cfg
    local base = {}
    local baseName = retCfg.base
    if baseName and name ~= baseName then
        base = self:fetchCfg(mod, baseName) or {}
    end

    return setmetatable({}, {
        __index = function(t, k)
            if retCfg[k] ~= nil then
                return retCfg[k]
            end
            return base[k]
        end
    })
end

function editorSetting:getCfg(mod, fullName)
	local name = getNameByFullName(fullName)
    local retCfg = self:fetchCfg(mod, name)
    local attach = {
        _name = name,
        fullName = fullName,
        modName = mod,
        plugin = "myplugin",
    }
    return setmetatable({}, {
        __index = function(t, k)
            return attach[k] or retCfg[k]
        end,
        __newindex = function(t, k, v)
            error(string.format("want set setting data table key:%s", k), 2)
        end
    })
end

RETURN(editorSetting)
