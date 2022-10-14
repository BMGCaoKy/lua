require "common.compat.compat"

print("Start client entry script!", World.GameName)

local function _loadLua(name, searchPath, env)
    local path, chuck = loadLua(name, searchPath)
    if path then
        local ret, errorMsg
        if env then
            ret, errorMsg = load(chuck, "@" .. path, "bt", env)
        else
            ret, errorMsg = load(chuck, "@" .. path, "bt")
        end
        assert(ret, errorMsg)
        print("load lua file success!", name)
        return ret()
    else
        print("lua file not exist.", name, searchPath)
    end
end

local searchPath = Root.Instance():getGamePath():gsub("\\", "/") .. "lua/?.lua"
package.path = package.path .. ";" .. searchPath

_loadLua("main", searchPath)