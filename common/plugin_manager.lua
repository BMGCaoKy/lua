local M = {}
local pluginLoaded = {}

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

local function loadPlugin(pluginName, pluginSearchPath)
    local env = setmetatable({}, {__index = _G})
    local prefix = "plugin." .. pluginName .. ".lua."
    env.__pluginName = pluginName
    env.__pluginPath = Root.Instance():getGamePath():gsub("\\", "/") .. "plugin/" .. pluginName
    env.require = function(modName)
        local fullName = prefix .. modName
        local m = pluginLoaded[fullName] or pluginLoaded[modName]
        if m then
            return m
        end
        if package.searchpath(fullName, pluginSearchPath) then
            pluginLoaded[fullName] = _loadLua(fullName, pluginSearchPath, env)
            return pluginLoaded[fullName]
        elseif package.searchpath(modName, pluginSearchPath) then
            pluginLoaded[modName] = _loadLua(modName, pluginSearchPath, env)
            return pluginLoaded[modName]
        end
        m = package.loaded[modName]
        if m then
            return m
        end
        assert(false, string.format("can't find module: %s", modName))
    end
    local ok, errMsg = pcall(_loadLua, prefix .. "main", pluginSearchPath, env)
    assert(ok, errMsg)
end

function M:loadGamePlugins()
    local gamePath = Root.Instance():getGamePath():gsub("\\", "/")
    local pluginSearchPath = gamePath .. "?.lua"

    pluginLoaded = {}
    for pluginName, _ in Lib.dir("plugin", "directory") do
        loadPlugin(pluginName, pluginSearchPath)
    end

    _loadLua("lua/main", pluginSearchPath)
end

return M
