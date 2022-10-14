local def = require "editor.def"
local data = {
	isCanRid = false,
	isbrith = false,
	is_send_entity = false,
	is_select_region = false,
	is_frame_pos = false,
	frame_pos_count = 0,
	is_cursor_hand = false,
	is_GIZMO_DRAG_MOVE = false,
	touch_focus_pos = nil,
	now_map_name = World.cfg.defaultMap or "map001",
	is_property_change = false,
	is_del_state = false,
	is_warning_save = false,
    is_can_place = true,
    is_can_update = true,
    is_can_move = false,
}
return data

