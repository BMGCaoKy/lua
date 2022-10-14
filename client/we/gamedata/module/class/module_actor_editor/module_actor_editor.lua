local Lfs = require "lfs"
local Def = require "we.def"
local Map = require "we.map"
local ModuleBase = require "we.gamedata.module.class.module_base"
local ModuleRequest = require "we.proto.request_module"

local M = Lib.derive(ModuleBase)

local MODULE_NAME = "actor_editor"
local ITEM_TYPE = "ActorEditorCfg"

function M:init(name)
	assert(name == MODULE_NAME, 
		string.format("[ERROR] module name not match %s:%s", MODULE_NAME, name)
	)

	self.path_item_map_ = {}
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

function M:del_actor(path)
	if self.path_item_map_[path] then
		self:del_item_no_notice(self.path_item_map_[path])
		self.path_item_map_[path] = nil
	end
end

function M:create_actor(path, skeleton, lock)
	assert(type(skeleton) == "string", skeleton)
	--copy
	local source = string.gsub("./conf/asset/actor/empty.actor", "/", "\\")
	local dest = string.gsub(path, "/", "\\")
	os.execute(string.format([[copy "%s" "%s" /Y]], source, dest))

	local id = self:load_actor(path, lock)
	local item = self:item(id)
	item:obj()["res_skeleton"] = skeleton
	item:save()
	return id
end

function M:load_actor(path, lock)
	if self.path_item_map_[path] then
		return self.path_item_map_[path]
	end
	local item = self:create_item(GenUuid())
	item:load(path)
	
	self.path_item_map_[path] = item:id()
	ModuleRequest.request_item_new(self:name(), item:id())
	return item:id()
end

return M
