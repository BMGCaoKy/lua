---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by 10184.
--- DateTime: 2020/11/23 16:10
---
---@type table<string, function>
local PluginFuncs = T(Plugins, "PluginFuncs")
local PluginRecord = T(Plugins, "PluginRecord")
---@type table<string, boolean>
local PluginLoader = {}

function Plugins.LoadAllPlugins()
    if World.isClient == true and Blockman.instance.singleGame and CGame.instance:getIsMobileEditor() and CGame.instance:getIsEditor() then
        print("Mobile Editor Edit Mode")
        local plugins = World.cfg.editorPlugins
        if type(plugins) == "table" then
            for _, plugin in pairs(plugins) do
                Plugins.LoadPlugin(plugin)
            end
        end
    else
        local plugins = World.cfg.plugins
        if type(plugins) == "table" then
            if not IS_EDITOR then
                for _, plugin in pairs(plugins) do
                    Plugins.LoadPlugin(plugin)
                end
            end
        elseif World.cfg.isEditorGame then
            Plugins.LoadPlugin("editor_template")
        end
    end
end

--PGC多插件并行下，保证调用顺序也符合引用顺序
function Plugins.CallPluginFunc(name, ...)
    local plugins = PluginRecord--World.cfg.plugins
    if type(plugins) == "table" then
        for _, plugin in pairs(plugins) do
            Plugins.CallTargetPluginFunc(plugin, name, ...)
        end
    else
        for _, func in pairs(PluginFuncs) do
            func(name, ...)
        end
    end
end

function Plugins.CallTargetPluginFunc(plugin, name, ...)
    local func = PluginFuncs[plugin]
    if func then
        return func(name, ...)
    end
end

function Plugins.PluginRegisterEventFunc( event, func, ...)
    local params = table.pack(...)

    Lib.subscribeEvent(event, function(...)
        local param = table.pack(...)
        for i, v in ipairs(param) do
            table.insert(params, v)
        end
        func(table.unpack(params))
    end)
end

local function isModuleAvailable(name)
    if package.loaded[name] then
        return true
    else
        for _, searcher in ipairs(package.searchers or package.loaders) do
            local loader = searcher(name)
            if type(loader) == 'function' then
                package.preload[name] = loader
                return true
            end
        end
        return false
    end
end

function Plugins.RequireScript(moduleName)
    local ret = isModuleAvailable(moduleName)
    if ret then
        return require(moduleName)
    else
        Lib.logWarning(string.format("try to require UNLOADED module[%s]", moduleName))
        return
    end
end

local function combineDefaultSetting(plugin, defaultSetting)
    if not defaultSetting then
        return
    end
    local settingKey = defaultSetting.settingKey or plugin .. "Setting"
    if World.cfg[settingKey] then
        for key, value in pairs(defaultSetting) do
            if tostring(World.cfg[settingKey][key]) == "nil" then
                World.cfg[settingKey][key] = value
            end
        end
    else
        World.cfg[settingKey] = defaultSetting
    end
end

function Plugins.IsLoader(plugin)
    return PluginLoader[plugin]
end

function Plugins.LoadPlugin(plugin)
    if PluginLoader[plugin] then
        return
    end
    Lib.logInfo("[Plugins.LoadPlugin]", "plugin=" .. plugin)
    local pluginPath = Root.Instance():getGamePath() .. "modules/" .. plugin .. "/"
    local jsonInEngine = false
    local file = io.open(pluginPath .. plugin .. ".lua")
    if not file then
        pluginPath = Root.Instance():getGamePath() .. "lua/plugins/" .. plugin .. "/"
        file = io.open(pluginPath .. plugin .. ".lua")
        if not file then
            pluginPath = Root.Instance():getRootPath() .. "lua/plugins/" .. plugin .. "/"
            file = io.open(pluginPath .. plugin .. ".lua")
            if not file then
                Lib.logWarning("[Plugins.LoadPlugin][Failed]", pluginPath .. plugin .. ".lua" .. " is not exist!")
                return
            end
            jsonInEngine = true
        end
    end
    Lib.logInfo("[Plugins "..plugin.."] load success:", pluginPath)
    file:close()
    -- json文件里的setting
    local defaultSetting
    if jsonInEngine then
        defaultSetting = Lib.read_json_file(pluginPath .. "setting.json")
    else
        defaultSetting = Lib.readGameJson("modules/" .. plugin .. "/setting.json")
    end
    combineDefaultSetting(plugin, defaultSetting)
    local paths = {}
    string.gsub(package.path, '[^;]+', function(w)
        table.insert(paths, w)
    end)
    table.insert(paths, #paths - 1, pluginPath .. "?.lua")
    if World.isClient then
        table.insert(paths, #paths - 1, pluginPath .. "client/?.lua")
    else
        table.insert(paths, #paths - 1, pluginPath .. "server/?.lua")
    end
    package.path = table.concat(paths, ";")
    --加载插件多语言
    if World.isClient then
        Lang:loadPlugin(pluginPath)
    end
    local func = require(plugin)
    if type(func) == "function" then
        PluginFuncs[plugin] = func
    end
    PluginLoader[plugin] = true
    --兼容一部分插件把默认配置放到函数里的情况
    defaultSetting = Plugins.CallTargetPluginFunc(plugin, "defaultSetting")
    combineDefaultSetting(plugin, defaultSetting)
    table.insert(PluginRecord,plugin)
end