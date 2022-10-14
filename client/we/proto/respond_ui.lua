local guiMgr = require "we.logic.ui.layout_manager"
local fontMgr = require "we.logic.ui.ui_font_manager"
local Layout = require "we.logic.ui.layout"
local ModuleMgr = require "we.gamedata.module.module"
local LayoutModule = ModuleMgr:module("layout")
local Recorder = require "we.gamedata.recorder"

return {
	UNDO = function()
		guiMgr:undo()
		return {ok = true}
	end,

	REDO = function()
		guiMgr:redo()
		return {ok = true}
	end,

	LOAD_LAYOUT = function(path,id)
		LayoutModule:load_layout(path, id)
		return {ok = true}
	end,

	GET_LAYOUT_MAP = function()
		local tb = guiMgr:get_layout_map()
		return {ok = true, data = tb}
	end,

	SHOW_ROOT = function()
		guiMgr:show_root()
		return {ok = true}
	end,
	
	HIDE_ROOT = function()
		guiMgr:hide_root()
		return {ok = true}
	end,

	SHOW_EDITOR_LAYOUT = function(layout)
		guiMgr:show_editor_layout(layout)
		return {ok = true}
	end,
	
	UPDATE_LAYOUT_WINDOW = function()
		guiMgr:update_layout_window()
		return {ok = true}
	end,

	SHOW_ENGINE_DEFLAYOUT = function(layout)
		guiMgr:show_engine_deflayout(layout)
		return {ok = true}
	end,

	OPEN_ENGINE_DEFLAYOUT = function(layout)
		guiMgr:open_engine_deflayout(layout)
		return {ok = true}
	end,

	ADD_WINDOW = function(path, index, type, x, y)
		local pos = {
			x = x,
			y = y
		}
		guiMgr:add_window(path,index,type, pos)
		return {ok = true}
	end,

	DEL_WINDOW = function(item_id_list)
		guiMgr:del_window(item_id_list)
		return {ok = true}
	end,

	COPY_WINDOW = function(paths)
		guiMgr:copy_window(paths)
		return {ok = true}
	end,

	PASTE_WINDOW = function(path, index)
		guiMgr:paste_window(path, index)
		return {ok = true}
	end,

	COPY_COUNT = function()
		local count = guiMgr:copy_count()
		return {ok = true, data = count}
	end,

	MOVE_WINDOW_TIER = function(target_path, item_path_list, index)
		guiMgr:move_window_tier(target_path, item_path_list, index)
		return {ok = true}
	end,

	PEER_MOVE_WINDOW_TIER = function(target_path, item_path_list, index)
		guiMgr:peer_move_window_tier(target_path, item_path_list, index)
		return {ok = true}
	end,

	ADAPTPOS = function(x, y)
		local ret = guiMgr:adaptpos(x, y)
		return {ok = true, pos = ret}
	end,

	GET_WINDOW_RECT = function(id)
		local ret = guiMgr:get_window_rect(id)
		return {ok = true, rect = ret}
	end,

	GET_XML_CONTENT = function(path)
		local ret = Lib.LoadXmltoTable(path)
		return {ok = true, content = ret}
	end,

	CONVERSION_UDIM = function(path)
		guiMgr:current_layout_conversion_udim(path)
		return {ok = true}
	end,

	UPDATE_LAYOUT_PATH = function(old_path, new_path)
		--需要更新sceneui与item_layout的索引
		guiMgr:on_layout_path_changed(old_path, new_path)
		return {ok = true}
	end,

	ADD_FONT = function(path)
		fontMgr:add_font(path)
		return {ok = true}
	end,

	GET_PRESET_FONT_COUNT = function()
		local count = fontMgr:get_preset_font_count()
		return {ok = true, count = count}
	end,

	DELETE_FONT = function(asset_path)
		fontMgr:delete_font(asset_path, true)
		return {ok = true}
	end,

	CREATE_COMMON_TREE = function(tree_id,select_items_path)
		guiMgr:create_common_window(tree_id,select_items_path)
		return {ok = true}
	end,

	GET_LAYOUT_INFO = function(path)
	end,
}