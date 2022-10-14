local ModuleBase = require "we.gamedata.module.class.module_base"
local ModuleRequest = require "we.proto.request_module"

local cjson = require "cjson"

local M = Lib.derive(ModuleBase)

local MODULE_NAME = "effect"
local ITEM_TYPE = "EffectCfg"


function M:init(name)
	assert(name == MODULE_NAME,
			string.format("[ERROR] module name not match %s:%s", MODULE_NAME, name)
	)
	ModuleBase.init(self, MODULE_NAME, ITEM_TYPE)
end


function M:load()
end


function M:check_valid_items()
	return {}
end


function M:new_item()
	assert(false)
end


function M:copy_item()
	assert(false)
end


function M:load_effect(item_value)
	local presets = cjson.decode(item_value)
	local item = self:create_item(GenUuid())
	item:load(presets)
	ModuleRequest.request_item_new(self:name(), item:id())
	return item:id()
end


function M:unload_effect(item_id)
	self:unload_item(item_id)
end


function M:unload_all_effects()
	for _, item in pairs(self:list()) do
		if item then
			self:unload_item(item:id())
		end
	end
end


return M
