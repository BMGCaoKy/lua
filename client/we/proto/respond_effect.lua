local ModuleMgr = require "we.gamedata.module.module"
local EffectMain = require "we.sub_editors.effect_main"
local EffectModule = ModuleMgr:module("effect")


return {
	activate = function()
		EffectMain:init()
	end,

	deactivate = function()
		EffectMain:deinit()
	end,

	load_effect = function(item_value)
		local item_id = EffectModule:load_effect(item_value)
		EffectMain:set_preset_item(item_id)
		return item_id
	end,

	unload_effect = function(item_id)
		EffectModule:unload_effect(item_id)
		EffectMain:unset_preset(item_id)
	end,

	active_effect = function(item_id)
		EffectMain:set_preset_item(item_id)
	end,

	inactive_effect = function(item_id)
		EffectMain:unset_preset(item_id)
	end,

	unload_all_effects = function()
		EffectModule:unload_all_effects()
		EffectMain:unset_preset()
	end,

	active_preset = function(item_id, index)
		EffectMain:set_preset_item(item_id)
		EffectMain:set_preset(item_id, index)
	end,

	inactive_preset = function()
		EffectMain:unset_preset()
	end,

	add_preset = function(item_id, index, preset_value)
		EffectModule:item(item_id):add_preset(preset_value, index)
	end,

	remove_preset = function(item_id, index)
		EffectModule:item(item_id):remove_preset(index)
	end
}
