local guiMgr = GUIManager:Instance()
local Module = require "we.gamedata.module.module"
local Layout = require "we.logic.ui.layout"
local window_class = require "we.logic.ui.window"
local UIRequest = require "we.proto.request_ui"
local Bunch_UI = require "we.logic.ui.bunch_ui"
local State = require "we.logic.ui.state_ui"
local Def = require "we.def"
local VN = require "we.gamedata.vnode"

local c_guiMgr = L("guiMgr", GUIManager:Instance())

local M = {}
local editor_layouts = {}
local editor_current_layout
local engine_layouts = {}
local engine_current_layout

local function new_cmd(name,...)
	local class = require(string.format("we.logic.ui.cmd.%s", name))
	assert(class, string.format("class %s is not exist", name))

	local obj = Lib.derive(class)
	obj:init(...)

	return obj
end

local function create(item_name)
	local layout = Lib.derive(Layout)
	local module = Module:module("layout")
	local item = module:item(item_name)
	local path = item:path()
	layout:init(path, item_name)
	editor_layouts[item_name] = layout
end

local function remove(item_name)
	editor_layouts[item_name]:close_window()
	editor_layouts[item_name] = nil
	if editor_current_layout == item_name then
		editor_current_layout = nil
	end
end

function M:init()
	State:init()
	local module = Module:module("layout")
	assert(module,"layout")
	for item_name in pairs(module:list()) do
		create(item_name)
	end
	self._copy_datas = {}
	Lib.subscribeEvent(Event.EVENT_EDITOR_ITEM_NEW, function(module, item_name)
		if module ~= "layout" then
			return
		end
		create(item_name)
	end)

	Lib.subscribeEvent(Event.EVENT_EDITOR_ITEM_DEL, function(module, item_name)
		if module ~= "layout" then
			return
		end
		remove(item_name)
	end)
	print("ui_manager---->>init-->>")
end

function M:show_root()
	guiMgr:getRootWindow():show()
end

function M:hide_root()
	if editor_layouts[editor_current_layout] then
		editor_layouts[editor_current_layout]:hide_window()
	end
	editor_current_layout = nil
	guiMgr:getRootWindow():hide()
end

function M:load_layout(path, id)
	local layout = Lib.derive(Layout)
	layout:init(path, id)
	editor_layouts[id] = layout
end

local function hide_editor_layout()
	local layout = editor_layouts[editor_current_layout]
	if layout then
		layout:hide_window()
		editor_current_layout = nil
	end
end

local function hide_engine_deflayout()
	local layout = engine_layouts[engine_current_layout]
	if layout then
		layout:hide()
		engine_current_layout = nil
	end
end

function M:show_editor_layout(layout)
	if editor_current_layout ~= layout then
		hide_engine_deflayout()
		hide_editor_layout()
		editor_layouts[layout]:show_window()
	end
	editor_current_layout = layout
end

function M:update_layout_window()
	local layout = editor_layouts[editor_current_layout]
	if layout then
		layout:update_window()
	end
end

function M:show_engine_deflayout(layout)
	if engine_current_layout ~= layout then
		hide_editor_layout()
		hide_engine_deflayout()
		local window = UI:isOpenWindow(layout)
		if window then
			window:show()
		else
			window = assert(UI:openSystemWindow(layout), layout)
			engine_layouts[layout] = window
			--UI:openSystemWindowAsync(function(window) engine_layouts[layout] = window end,layout)
		end
	end
	engine_current_layout = layout
end

function M:add_window(path, index, type, pos)
	local transform_pos = self:adaptpos(pos.x, pos.y)
	local cmd = new_cmd("add_window",editor_layouts[editor_current_layout], path, index, type, transform_pos)
end

function M:del_window(item_id_list)
	local cmd = new_cmd("del_window",editor_layouts[editor_current_layout], item_id_list)
end

function M:copy_window(paths)
	editor_layouts[editor_current_layout]:copy_window(paths)
	self._copy_datas = editor_layouts[editor_current_layout]:copy_datas()
end

function M:paste_window(path, index)
	local cmd = new_cmd("paste_window",editor_layouts[editor_current_layout],self._copy_datas, path, index)
end

function M:copy_count()
	return self._copy_datas and #self._copy_datas or -1
end

function M:move_window_tier(target_path, item_path_list, index)
	local cmd = new_cmd("move_window_tier",editor_layouts[editor_current_layout], target_path, item_path_list, index)
end

function M:peer_move_window_tier(target_path, item_path_list, index)
	local cmd = new_cmd("peer_move_window_tier",editor_layouts[editor_current_layout], target_path, item_path_list, index)
end

function M:logicpos_to_screenpos(x, y)
	local transform_pos = GUIManager.logicPosToScreenPos({x = x, y = y})
	local ret = {
		x = transform_pos.x,
		y = transform_pos.y
	}
	return ret
end

function M:adaptpos(x, y)
	local transform_pos = GUIManager.adaptPos({x = x, y = y})
	local ret = {
		x = transform_pos.x,
		y = transform_pos.y
	}
	return ret
end

function M:get_window_rect(id)
	local window = editor_layouts[editor_current_layout]:get_window(id)
	if not window then
		return
	end
	local unclippedOuterRect = window:getUnclippedOuterRect():getFresh(true)
	local pos = {
		x = unclippedOuterRect.left,
		y = unclippedOuterRect.top
	}
	local parentWidget = window:getParent()
	if parentWidget then
		local parentUnclippedOuterRect = parentWidget:getUnclippedOuterRect():getFresh(true)
		pos.x = pos.x - parentUnclippedOuterRect.left
		pos.y = pos.y - parentUnclippedOuterRect.top
	end
	pos = self:logicpos_to_screenpos(pos.x, pos.y)
	local size = self:logicpos_to_screenpos(unclippedOuterRect.right - unclippedOuterRect.left, unclippedOuterRect.bottom - unclippedOuterRect.top)

	local type = window:getType()
	if window_class:window_is_layout(type) and size["x"] == 0 and size["y"] == 0 then
		size = self:logicpos_to_screenpos(100, 100)
	end

	local rect = {
		left = pos.x,
		top = pos.y,
		width = size.x,
		height = size.y
	}
	return rect
end

function M:get_layout()
	return editor_layouts[editor_current_layout]
end

function M:current_layout_conversion_udim(path)
	local layout = editor_layouts[editor_current_layout]
	if not layout then
		return
	end

	if Bunch_UI:get_current_path_lsit() then
		layout:conversion_udim_by_paths(Bunch_UI:get_current_items_path(),path)
	else
		layout:conversion_udim_by_path(path)
	end
end

function M:on_layout_path_changed(old_path, new_path)
	local path = Lib.combinePath(Root.Instance():getGamePath(), old_path)
	local id = self:get_layout_map()[path]
	local module = Module:module("layout")
	if module:list()[id] then
		if new_path == "" then
			module:del_item(id)
		else
			local item = module:list()[id]
			local node = item:obj()
			VN.assign(node, "path", new_path, 0)
			item:set_layout_info()
		end
	end
	local ok,index = string.find(old_path,"asset/")
	if ok ~= -1 then
		local asset_path = string.sub(old_path,index+1)
		c_guiMgr:saveLayout(asset_path or "")
	end
end
function M:get_layout_map()
	local tb = {}
	local module = Module:module("layout")
	for id,_ in pairs(editor_layouts) do
		local item = module:item(id)
		assert(item,"not item")
		local path = item:path()
		tb[path] = id
	end
	return tb
end

function M:create_common_window(tree_id,item_path_list)
	Bunch_UI:attach_items(tree_id,item_path_list)
end

M:init()

return M