local Module = require "we.gamedata.module.module"
local Lang = require "we.gamedata.lang"
local Mapping = require "we.gamedata.module.mapping"
local Engine = require "we.engine"
local UserData = require "we.user_data"
local GameRequest = require "we.proto.request_game"
local Cmdr = require "we.cmd.cmdr"
local TreeSet = require "we.gamedata.vtree"
local VN = require "we.gamedata.vnode"
local Coin = require "we.gamedata.coin"
local Map = require "we.view.scene.map"
local Cache = require "we.view.scene.cache"

local mapping = {
	["SAVE"] = function()
		Map:update_staticBatchNo() --保存地图前，更新当前地图vnode的静态合批批次号
		Module:save()
		Lang:save()
		Mapping:save()
		Engine:save_all_map()
		UserData:save()
		Coin:save()
		Map:save()
		if DataLink:useDataLink() then
			DataLink:save()
		end

		GameRequest.request_modify_flag(false)
		return true
	end,

	["QUALITYLEVEL"] = function(level)
	  Blockman.instance.gameSettings:setCurQualityLevel(level)
	  Clientsetting.refreshSaveQualityLeve(level)

	  return true
	end,

	["UNDO"] = function()
		Cmdr:undo()

		return true
	end,

	["REDO"] = function()
		Cmdr:redo()

		return true
	end,

	["SWITCH_EDITOR"] = function(name)
		if name == "scene" then
			local Map = require "we.view.scene.map"
			local curr = Map:curr()
			if curr then
				Cmdr:bind(curr:stack())
			end
		end
	end,

	["CLOSE"] = function()
		Cache:clean_cache()
	end
}

return {
	OP = function(op, ...)
		local processor = mapping[string.upper(op)]
		assert(processor)

		return { ok = processor(...) }
	end,

	LOG_OPERATION = function(enabled)
		TreeSet:set_log_ops(enabled)
	end,

	ACTIVE_NODE = function(id, path)
		if not path then
			print("unbind stack")
			Cmdr:bind(nil)
		else
			local tree = assert(TreeSet:tree(id))
			local node = tree:node(path)
			local stack = VN.undo_stack(node, true)
			print("bind stack", stack)
			Cmdr:bind(stack)
		end

		return { ok = true}
	end,

	INACTIVE_NODE = function()
		Cmdr:bind(nil)
	end,

	MODIFIED = function()
		local _modified = Module:modified()
		return {data = _modified}
	end
}
