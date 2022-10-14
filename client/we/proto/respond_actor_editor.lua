local Meta = require "we.gamedata.meta.meta"
local Lang = require "we.gamedata.lang"
local TreeSet = require "we.gamedata.vtree"
local VN = require "we.gamedata.vnode"
local ModuleMgr = require "we.gamedata.module.module"

local ActorMain = require("we.sub_editors.actor_main")
local ActorSkill = require("we.sub_editors.actor_skill")
local ActorModule = ModuleMgr:module("actor_editor")

return {
	activate = function()
		ActorMain:activate()
	end,

	deactivate = function()
		ActorMain:deactivate()
	end,

	--创建actor文件并返回item的id
	CREATE_ACTOR = function(path, skeleton, lock)
		local item_id = ActorModule:create_actor(path, skeleton , lock)
		if lock then
			ActorMain:setActor(path)
		else
			ActorModule:del_actor(path)--只是释放vnode
		end
		return {ok = true, item = item_id}
	end,

	LOCK_ACTOR_FILE = function(item_id)
		local item = ActorModule:item(item_id)
		if item then
			item:lock_actor_file()
		end
	end,

	UNLOCK_ACTOR_FILE = function(item_id)
		local item = ActorModule:item(item_id)
		if item then
			item:unlock_actor_file()
		end
	end,

	MODIFY_ACTOR = function (path)
		ActorMain:modify_actor(path)
	end,

	DEL_ACTOR = function (path)
		ActorMain:set_root_nil()
		ActorModule:del_actor(path)
	end,

	LOAD_ACTOR = function(path, lock)
		local item_id = ActorModule:load_actor(path, lock)
		ActorMain:setActor(path)
		return {ok = true, item = item_id}
	end,

	SAVE_ACTOR = function(item_id)
		ActorModule:item(item_id):save()
		return {ok = true}
	end,

	SAVE_ACTOR_AS = function(item_id, path)
		ActorModule:item(item_id):save_as(path)
		return {ok = true}
	end,

	set_master_actor = function(item_id)
		ActorMain:setActorID(item_id)
	end,

	GET_ACTIONS_BY_ACTOR = function(path)
		return {ok = true, actions = ActorSkill:get_skills_by_path(path)}
	end
}
