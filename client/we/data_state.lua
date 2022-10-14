local def = require "we.def"
return {
	is_can_rid = false,
	isbrith = false,
	is_send_entity = false,
	is_select_region = false,
	is_frame_pos = false,
	frame_pos_count = 0,
	is_cursor_hand = false,
	is_gizmo_drag_move = false,
	touch_focus_pos = nil,
	is_property_change = false, --是否是属性面板修改
	region_box = {min = nil,max = nil},
	is_block_list = false,
	is_region = false
}