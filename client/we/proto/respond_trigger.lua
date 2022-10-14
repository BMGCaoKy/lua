local CustomTrigger = require "we.logic.trigger_action.custom_trigger"
local CopyAction = require "we.logic.trigger_action.copy_action"
local MergeAction = require "we.logic.trigger_action.merge_action"
local ExpandAction = require "we.logic.trigger_action.expand_action"
local Trigger = require "we.gamedata.trigger"

return {
	Custom_Trigger = function(module,item,name)
		CustomTrigger:init(module,item)
		name = CustomTrigger:insert()
		return {ok = true, data = name}
	end,

	ACTION_COPY = function(type, nodes)
		CopyAction.init(type, nodes)
		return {ok = true}
	end,

	GET_COPY_TYPE = function()
		return {ok = true, data = CopyAction.copy_types()}
	end,

	ACTION_COUNT = function()
		local count = CopyAction.node_count()
		return {ok = true, data = count}
	end,

	ACTION_PASTE = function(type, x, y)
		local pos = {
			x = x,
			y = y
		}
		local nodes = CopyAction.paste(type, pos)
		return {ok = true,data = nodes}
	end,

	ACTION_MERGE = function(nodes)
		MergeAction.init(nodes)
		local out = MergeAction.merge()
		return {ok = true,data = out}
	end,

	ACTION_EXPAND = function(groups)
		ExpandAction.init(groups)
		local out = ExpandAction.expand()
		return {ok = true,data = out}
	end,

	SET_RUN_TYPE = function (run_type)
		Trigger:set_run_type(run_type)
	end,

	GET_RUN_TYPE = function ()
		return Trigger:get_run_type()
	end,

	SEARCH_BLUE_PRINT_NODE = function(additional)
		return Trigger:search_action_node(additional)
	end,

	SYNC_BLUE_PRINT_NODE = function(additional,path,index,value)
		return Trigger:sync_reference_node_value(additional,path,index,value)
	end,

	FIND_CUSTOM_TRIGGER_DEFINE = function(additional)
		return Trigger:find_custom_trigger_define(additional)
	end,
}
