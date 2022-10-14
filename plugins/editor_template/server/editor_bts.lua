local Handlers = T(Trigger, "Handlers")
local lfs = require "lfs"
local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions

local mt = setmetatable({}, {
	__index = function(t, key)
		return Actions[key]
	end
})
	
local PluginTrigger = T(Trigger, "PluginTrigger", mt) 
local function handleTrigger(name, context)
	local handler = Handlers[name]
	if not handler then
		return
	end
	local ok, msg = xpcall(handler, traceback, context)
	if not ok then
		perror("handle trigger error", name, msg)
	end
end

function PluginTrigger:requireAll()
	local path = lfs.currentdir()
	local luaTriggerPath = Root.Instance():getRootPath() .. "lua/plugins/editor_template/server/editor_trigger_handle"
	local luaRequireRootPath = "plugins.editor_template.server.editor_trigger_handle"
	for pluginName, pluginPath in Lib.dir(luaTriggerPath, "directory", true) do
		for modName, modPath in Lib.dir(pluginPath, "directory", true) do
			for name, filePath in Lib.dir(modPath, "file", true) do
				local name, index = string.gsub(name, ".lua$", "")
				if index > 0 then
					local fileName = luaRequireRootPath .. "." .. pluginName .. "." .. modName .. "." .. name
					local fullName = pluginName .. "/" .. name
					self.handleFuns[modName] = self.handleFuns[modName] or {}
					self.handleFuns[modName][fullName] = require(fileName)
				end
			end
		end
	end
end

function PluginTrigger:init()
	self.handleFuns = {}
    self:requireAll()
end

function PluginTrigger:getVar(obj, key)
	if not obj or not key then
		return
	end
	return obj.vars[key]
end

function PluginTrigger:setVar(obj, key, value)
	if not obj or not key then
		return
	end
	obj.vars[key] = value
end 

function PluginTrigger:handle(cfg, eventName, context)
	local mod = cfg.modName
	local fullName = cfg.fullName
	local modHandleFuncs = self.handleFuns[mod]
	if not modHandleFuncs then
		return
	end
	local funcs = modHandleFuncs[fullName]
	if not funcs then
		local baseFullName = cfg.base and "myplugin/" .. cfg.base
		if not baseFullName then
			return
		end
		funcs = modHandleFuncs[baseFullName]
		if not funcs then
			return
		end
	end
	local func = funcs[eventName]
	if func then
		func(funcs, context)
		return true
	end
end


function Trigger.CheckTriggers(cfg, name, context)
	local luaDoTrigger = false
    if cfg then
		context.dir = cfg.dir
		luaDoTrigger = PluginTrigger:handle(cfg, name, context)
	end

	handleTrigger(name, context)
	if not luaDoTrigger then
		Trigger.doTrigger(cfg and cfg.triggerSet, name, context)
	end
	Trigger.doTrigger(World.cfg.triggerSet, name, context)
end
PluginTrigger:init()