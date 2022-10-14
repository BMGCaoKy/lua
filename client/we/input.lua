local cmd = require "we.cmd"
local state = require "we.state"
local def = require "we.def"
local engine = require "we.engine"
local utils = require "we.utils"
local tran = require "we.Transform"
local data_state = require "we.data_state"
local setting = require "common.setting"
local Module = require "we.gamedata.module.module"
local Map = require "we.map"
local user_data = require "we.user_data"
local Mapping = require "we.gamedata.module.mapping"


local bm = Blockman.Instance()

local nextPos = nil

local M = {}

local hit = nil

local touch_focus_pos = nil

local ctrlspeed = 0

local function axisValue(forward, back)
	local value = 0.0;
	if bm:isKeyPressing(forward) then
		value = value + 1
	end
	if bm:isKeyPressing(back) then
		value = value - 1
	end
	return value
end

local function do_move(frame_time)
	local forward = axisValue("key.forward", "key.back")
	local left = axisValue("key.left", "key.right")
	local up = axisValue("key.top.left", "key.pack")
	nextPos = bm:getViewerPos()

	nextPos.y = math.max(nextPos.y,0)
	nextPos.y = math.min(nextPos.y,255)

	if forward==0.0 and left==0.0 and up==0.0 then
		return false
	end

	local rotationYaw = math.rad(bm:getViewerYaw())
	local rotationPitch = math.rad(bm:getViewerPitch())
	local f1 = math.sin(rotationYaw)
	local f2 = math.cos(rotationYaw)
	local f3 = math.sin(rotationPitch)
	local MOVE_SPEED = user_data:get_value("camera_move_speed") * frame_time / 33.333

	nextPos.x = nextPos.x + (left * f2 - forward * f1) * MOVE_SPEED
	nextPos.z = nextPos.z + (forward * f2 + left * f1) * MOVE_SPEED
	nextPos.y = nextPos.y + (up - forward * f3) * MOVE_SPEED
	return true
end

local function wheel_step_move(wheel_step)
	local forward = wheel_step

	if forward==0.0 then
		return false
	end

	local rotationYaw = math.rad(bm:getViewerYaw())
	local rotationPitch = math.rad(bm:getViewerPitch())
	local f1 = math.sin(rotationYaw)
	local f2 = math.cos(rotationYaw)
	local f3 = math.sin(rotationPitch)
	local MOVE_SPEED = math.abs(forward)
	
	--TODO,不是最优解，解决编辑器Y轴过小，且f3接近零时，以下判断必成立问题
	local smooth = 3
	if nextPos.y + (0 - forward * f3) * MOVE_SPEED < smooth and nextPos.y > 3 then
		return false
	end
	
	MOVE_SPEED = MOVE_SPEED / 5 --slow down speed, slow down shaking
	
	nextPos.x = nextPos.x + (0 - forward * f1) * MOVE_SPEED
	nextPos.z = nextPos.z + (forward * f2 + 0) * MOVE_SPEED
	nextPos.y = nextPos.y + (0 - forward * f3) * MOVE_SPEED
	bm:cleanWheelStep()
	return true
end

local function on_click_block(posi)
	local _table = {pos = posi}
	state:set_focus(_table,def.TBLOCK)
	state:set_editmode(def.EMOVE)
	--请空属性面板
	engine:on_focus_clear()
	engine:on_click_block()
end

local function on_click_brith(posi)
	engine:birth_position(posi)
	data_state.isbrith = false
end

local function on_click_entity(entity)
	local id = Map:curr_map():get_id_by_entityobj(entity)
	engine:send_entity_id(id,Map:curr_map_name())
	local _table = {id = id}
	state:set_focus(_table,def.TENTITY)
end

local function on_click_cmd_block(pos, side,b)
	local bpos = nil
	local _table = state:brush_obj()
	if _table.id ~= 0 then
		bpos = Lib.v3add(pos, side or {x=0,y=1,z=0})
		cmd:set_block(bpos,_table.id,b)
	else
		bpos = pos
		cmd:set_block(bpos,_table.id,false)
	end
end

local function on_click_cmd_entity(pos,side)
	pos = {
		x = pos.x,
		y = pos.y - 1,
		z = pos.z
	}
	local bpos = nil
	local _table = state:brush_obj()
	if _table.id ~= 0 then
		bpos = Lib.v3add(pos, side)
		bpos = {
			x = bpos.x,
			y = bpos.y,
			z = bpos.z
		}
		cmd:set_entity(bpos,_table.cfg,_table.yaw)
	else
		local id = Map:curr_map():get_id_by_entityobj(hit.entity)
		cmd:del_entity(id)
	end
end

--[[local function on_click_region(pos,side)
	--清空刷子，设置焦点
	pos = Lib.v3add(pos, side)
	local Req = require "we.proto.request_region"
	local ok, cfg = Req.request_new_region()
	if ok then
		cmd:add_region(pos, cfg)
	end
end]]

local function on_click_frame(pos,side)
	local obj = {
		min = Lib.v3add(pos, side),
		max = Lib.v3add(pos, side)
	}
	state:set_editmode(def.ESCALE)
	state:set_focus(obj,def.TFRAME)
	engine:editor_obj_type("TFRAME");
end

local function on_click_frame_pos(pos,side)
	state:set_editmode(def.ESCALE)
	if state:shift_is_touch() then
		pos = Lib.v3add(pos, side)
	end
	Lib.emitEvent(Event.FRAME_POSITION, pos)
end

local function on_click_cmd_chunk(pos,side)
	--pos = Lib.v3add(pos, side)
	--local minpos = tran.CenterAlign(pos,state:brush_obj(),side)
	cmd:set_chunk(pos,side,state:brush_obj())
	engine:editor_obj_type("TCHUNK");
end

local function click_right_block()
	local min = state:focus_obj().pos
	
	if engine:detect_collision(min,min) then
		local id = engine:get_block(min)
		if Mapping:id2name("block",id) then
			engine:open_menu("block")
		else
			engine:open_menu("colorful_block")
		end
		
	else 
		state:set_focus(nil)
	end
end

local function click_right_entity()
	if hit.type == "ENTITY" then
		on_click_entity(hit.entity)
		engine:open_menu("entity")
	else
		state:set_focus(nil)
	end
end

local function click_right_region()
	local min = nil
	local _max = nil

	local m = Module:module("map")
	assert(m,"map")
	local item = m:item(Map:curr_map_name())
	local regions = item:obj().regions
	for i = 1, #regions do
		if state:focus_obj().id == regions[i].id then
			min = regions[i].min
			_max = regions[i].max
			break
		end
	end
	assert(min)
	assert(_max)

	local max = {
		x = _max.x + 1,
		y = _max.y + 1,
		z = _max.z + 1
	}
	if engine:detect_collision(min,max) then
		engine:open_menu("region")
	else
		state:set_focus(nil)
		engine:editor_obj_type("COMMON")
		state:set_editmode(def.EMOVE)
	end
end

local function click_right_chunk()
	local min = state:focus_obj().pos
	local max = {
		x = min.x + state:focus_obj().data.lx - 1,
		y = min.y + state:focus_obj().data.ly - 1,
		z = min.z + state:focus_obj().data.lz - 1
	}
	if engine:detect_collision(min,max) then
		engine:editor_obj_type("TCHUNK")
		engine:open_menu("chunk")
	else
		if data_state.is_frame_pos then
			local obj = Lib.boxOne()
			data_state.frame_pos_count = 0
			state:set_editmode(def.ECOMMON)
			state:set_brush(obj,def.TFRAME_POS)
			data_state.is_frame_pos = false
		else
			local obj = Lib.boxOne()
			state:set_brush(obj,def.TFRAME)
			state:set_editmode(def.ESCALE)
		end
		engine:editor_obj_type("NOTFill")
	end
end

local function click_right_frame()
	local min = state:focus_obj().min
	local max = state:focus_obj().max
	if engine:detect_collision(min,max) then
		engine:editor_obj_type("TFRAME")
		engine:open_menu("frame")
	else
		if data_state.is_frame_pos then
			local obj = Lib.boxOne()
			data_state.frame_pos_count = 0
			state:set_editmode(def.ECOMMON)
			state:set_brush(obj,def.TFRAME_POS)
			data_state.is_frame_pos = false
		else
			local obj = Lib.boxOne()
			state:set_brush(obj,def.TFRAME)
			state:set_editmode(def.ESCALE)
		end
		engine:editor_obj_type("NOTFill")
	end
end

local function click_right_frame_pos()

end

local function click_right_block_fill()
	local _table = {id = state:focus_obj().id}
	state:set_brush(_table, def.TBLOCK)
end

local function detect_collision_cursor()
	if state:focus_obj() ~= nil and state:get_editmode() == def.EMOVE and state:brush_obj() == nil then
		local min = nil
		local max = nil
		local focus_obj = state:focus_obj()
		local focus_class = state:focus_class()
		if data_state.touch_focus_pos then
			min = data_state.touch_focus_pos
		else
			min = focus_obj.pos
		end
		
		if focus_class == def.TBLOCK then
			max = min
		elseif focus_class == def.TCHUNK then
			max = {
				x = min.x + focus_obj.data.lx - 1,
				y = min.y + focus_obj.data.ly - 1,
				z = min.z + focus_obj.data.lz - 1
			}
		end
		if min == nil or max == nil then
			return false
		else
			if engine:detect_collision(min,max) then
				return true
			else
				return false
			end
		end
	else
		return false
	end
end

local function touch_begin_left()
	if detect_collision_cursor() and data_state.is_cursor_hand == false then
		--engine:set_cursor("QT_CLOSE_HAND_CURSOR")
		local focus_class = state:focus_class()
		local focus_obj = state:focus_obj()
		if focus_class == def.TBLOCK then
			state:set_brush({id = engine:get_block(focus_obj.pos)},focus_class,false)
		elseif focus_class == def.TCHUNK then
			local max = {
				x = focus_obj.pos.x + focus_obj.data.lx - 1,
				y = focus_obj.pos.y + focus_obj.data.ly - 1,
				z = focus_obj.pos.z + focus_obj.data.lz - 1
			}
			local new_chunk = engine:make_chunk(focus_obj.pos, max, true)
			state:set_brush(new_chunk,focus_class,false)
		end
		if data_state.touch_focus_pos == nil then
			data_state.touch_focus_pos = {
				x = focus_obj.pos.x,
				y = focus_obj.pos.y,
				z = focus_obj.pos.z
			}
		end
		data_state.is_cursor_hand = true
		
	else
		--engine:set_cursor("QT_OPEN_HAND_CURSOR")
	end
end

local function touch_bengin_right()
end

local function touch_end_left()
	if data_state.is_cursor_hand and hit.blockPos then
		--engine:set_cursor("QT_ARROW_CURSOR")
		local end_pos = Lib.v3add(hit.blockPos, hit.sideNormal)
		if state:brush_class() == def.TCHUNK then
			end_pos = tran.CenterAlign(Lib.v3add(hit.blockPos, hit.sideNormal),state:brush_obj(),hit.sideNormal)
		end
		local pos = nil
		if state:focus_class() == def.TBLOCK then
			pos = {
				x = data_state.touch_focus_pos.x + 0.5,
				y = data_state.touch_focus_pos.y + 0.5,
				z = data_state.touch_focus_pos.z + 0.5
			}
		elseif state:focus_class() == def.TCHUNK then
			pos = {
				x =  data_state.touch_focus_pos.x + state:focus_obj().data.lx / 2,
				y =  data_state.touch_focus_pos.y + state:focus_obj().data.ly / 2,
				z =  data_state.touch_focus_pos.z + state:focus_obj().data.lz / 2
			}
		end
		local offset = Lib.v3cut(end_pos, data_state.touch_focus_pos)
		if pos then
			Lib.emitEvent(Event.EVENT_EDITOR_GIZMO_DRAG_START,pos,offset)
			Lib.emitEvent(Event.EVENT_EDITOR_GIZMO_DRAG_MOVE,pos,offset)
			Lib.emitEvent(Event.EVENT_EDITOR_GIZMO_DRAG_END,pos,offset)

			--engine:gizmo_widget_set_pos(Lib.v3add(pos,offset))
		end
		state:set_brush(nil)
		data_state.is_cursor_hand = false
	end
end

local function touch_end_right()

end

local function click_left()
	if state:brush_obj() == nil then
		if hit.type == "BLOCK" and hit.blockPos then
			if state:focus_class() == def.TFRAME then
				local obj = Lib.boxOne()
				state:set_brush(obj,def.TFRAME);
				if data_state.is_frame_pos then
					data_state.is_frame_pos = false
					on_click_frame_pos(hit.blockPos, hit.sideNormal)
				else
					on_click_frame(hit.blockPos, hit.sideNormal)
				end
			elseif state:focus_class() == def.TREGION then
				state:set_focus(nil)
				state:set_editmode(def.EMOVE)
			elseif state:focus_class() == def.TCHUNK then
			else
                if data_state.isbrith == true then
					on_click_brith(hit.blockPos)
                else
					on_click_block(hit.blockPos)
                end
			end
		elseif hit.type == "ENTITY" then
			state:set_editmode(def.EMOVE)
			on_click_entity(hit.entity)
		end
	else
		if hit.blockPos then
			if state:brush_class() == def.TBLOCK then
				on_click_cmd_block(hit.blockPos, hit.sideNormal, true)
			elseif state:brush_class() == def.TENTITY then
				on_click_cmd_entity(hit.worldPos, hit.sideNormal)
			elseif state:brush_class() == def.TREGION then
				--on_click_region(hit.blockPos,hit.sideNormal)
			elseif state:brush_class() == def.TCHUNK then
				on_click_cmd_chunk(hit.blockPos,hit.sideNormal)
			elseif state:brush_class() == def.TFRAME then
				on_click_frame(hit.blockPos, hit.sideNormal)
			elseif state:brush_class() == def.TFRAME_POS then
				on_click_frame_pos(hit.blockPos, hit.sideNormal)
			end
		elseif state:brush_obj()["id"] == 0 then
			if hit.type == "ENTITY" then
				on_click_cmd_entity(hit.worldPos, hit.sideNormal)
			end
		end
	end
end

local function click_right()
	if data_state.touch_focus_pos == nil then
	if state:brush_obj() == nil then
		local class = state:focus_class()
		if class == def.TBLOCK then
			click_right_block()
		elseif class == def.TENTITY then
			click_right_entity()
		elseif class == def.TREGION then
			click_right_region()
		elseif class == def.TCHUNK then
			click_right_chunk()
		elseif class == def.TFRAME then
			click_right_frame()
		elseif class == def.TFRAME_POS then
			click_right_frame_pos()
		elseif class == def.TBLOCK_FILL then
			click_right_block_fill()
		else
			if state:clipboard_obj() ~= nil then
				engine:open_menu("scene_menu")--显示上次粘贴板内容
			end
		end
	else
		if state:brush_class() ~= def.TFRAME and state:brush_class() ~= def.TFRAME_POS then
			if state:brush_class() ~= def.TBLOCK then
				engine:editor_obj_type("COMMON")
			end
			state:set_brush(nil)
		end
	end
	end
end

local function action_null()
	if detect_collision_cursor() then
		--engine:set_cursor("QT_OPEN_HAND_CURSOR")
	else
		--engine:set_cursor("QT_ARROW_CURSOR")
	end
end

local function touch_begin()
	touch_begin_left()
	--[[
	print(hit.action_param)
	if hit.action_param == 0 then
		print("touch_bengin")
		touch_bengin_left()
	elseif hit.action_param == 1 then
		print("touch_bengin_1")
		touch_bengin_right()
	end
	]]--
end

local function touch_end()
	action_null()
	touch_end_left()
	--[[
	if hit.action_param == 0 then
		print("touch_end_0")
		touch_end_left()
	elseif hit.action_param == 1 then
		print("touch_end_1")
		touch_end_right()
	end
	]]--
end

local function click()
	if hit.action_param == 0 then
		click_left()
	elseif hit.action_param == 1 then
		click_right()
	end
end

function M:update(frame_time)
	local isdomove = do_move(frame_time)

	hit = bm:getHitInfo()
	for k, v in pairs(bm:getUserAction()) do
		hit[k] = v
	end

	self:updatePosition(hit)
	local act = hit.action
	if act == "CLICK" then
		click()
	elseif act == "TOUCH_BEGIN" then
		--touch_begin()
	elseif act == "TOUCH_END" then
		--touch_end()
	else
		--action_null()
	end
	
	local wheel_step = bm:getWheelStep();
	if wheel_step ~= 0 then
		isdomove = wheel_step_move(wheel_step)
		engine:clear_wheel_value();
	end
	if isdomove then
		nextPos.y = math.max(nextPos.y,0)
		nextPos.y = math.min(nextPos.y,255)
		bm:setViewerPos(nextPos, bm:getViewerYaw(), bm:getViewerPitch(), 1)
		--同步到数据
		Map:update(nextPos)
	end
end

function M:updatePosition(hit)
	if hit.type == "BLOCK" then
		self.position = {x = 0; y = 0; z = 0;}
		if state:brush_obj() == nil 
		or (state:brush_class() == def.TBLOCK and state:brush_obj().id == 0) 
		or (not state:shift_is_touch() and state:brush_class() == def.TFRAME_POS)
		then
			self.position = hit.blockPos
		elseif state:brush_class() == def.TENTITY then
			self.position = Lib.v3add(Lib.v3cut(hit.worldPos,{x=0,y=1,z=0}), hit.sideNormal)
		else
			self.position = Lib.v3add(hit.blockPos, hit.sideNormal or {x=0,y=1,z=0})
			self.sideNormal = hit.sideNormal
		end
		self.position.y = math.max(self.position.y,0)
		self.position.y = math.min(self.position.y,255)
	else
		self.position = nil
		self.sideNormal = nil
	end
end

Lib.subscribeEvent(Event.EVENT_EDITOR_GIZMO_CONFIRM, function(is_confirm)
    if is_confirm then
        --将frame变成chunk
        local focusobj = state:focus_obj()
        local chunkobj = engine:make_chunk(focusobj.min, focusobj.max)
        local obj = { pos = focusobj.min, data = chunkobj }
        state:set_focus(obj, def.TCHUNK)
    else
        --隐藏坐标轴，焦点变成block
        state:set_focus(nil)
    end
end)

Lib.subscribeEvent(Event.EVENT_EDITOR_SCALER_DRAG_START, function(positive,reverse)
	engine:down_region()
	data_state.region_box.min = nil
	data_state.region_box.max = nil
end)

Lib.subscribeEvent(Event.EVENT_EDITOR_SCALER_DRAG_MOVE, function(positive,reverse)
	--缩放
	local reverse_pos = {
		x = reverse.x - 1,
		y = reverse.y - 1,
		z = reverse.z - 1
	}
	local _table = state:focus_obj()
	if state:get_editmode() == def.ESCALE then
		local focus_type = state:focus_class()
		if focus_type == def.TFRAME then
			_table.min = positive
			_table.max = reverse_pos
			engine:show_property_dock_scale(positive,reverse)
		elseif focus_type == def.TREGION then
			--obj:get_region(_table.name).box.min = positive
			--obj:get_region(_table.name).box.max = reverse_pos
			data_state.region_box.min = positive
			data_state.region_box.max = reverse_pos
		elseif focus_type == def.TBLOCK_FILL then
			_table.min = positive
			_table.max = reverse_pos
		end
	end
end)

Lib.subscribeEvent(Event.EVENT_EDITOR_SCALER_DRAG_END, function(positive,reverse)
	local reverse_pos = {
		x = reverse.x - 1,
		y = reverse.y - 1,
		z = reverse.z - 1
	}
	local focus_obj = state:focus_obj()
	local focus_class = state:focus_class()
	if focus_class == def.TREGION then
		local min = nil
		local max = nil
		local regionCfg = nil

		local m = Module:module("map")
		assert(m,"map")
		local item = m:item(Map:curr_map_name())
		local regions = item:obj().regions
		for i = 1, #regions do
			if focus_obj.id == regions[i].id then
				min = regions[i].min
				max = regions[i].max
				regionCfg = regions[i].cfg
				break
			end
		end
		assert(min)
		assert(max)
		assert(regionCfg)

		if state:get_editmode() == def.ESCALE then
			min = positive
			max = reverse_pos
		end
		
		state:set_focus(nil)

		local obj = {
			cfg = regionCfg,
			box = {
				min = min,
				max = max
			}
		}
		cmd:move_region(focus_obj.id,obj)
		data_state.region_box.min = nil
		data_state.region_box.max = nil
	elseif focus_class == def.TBLOCK_FILL then
		focus_obj.min = positive
		focus_obj.max = reverse_pos
		cmd:block_fill(focus_obj)
		focus_obj.old_min = positive
		focus_obj.old_max = reverse_pos
	end
	--TODO
	if data_state.is_select_region == true then
		engine:up_region()
		--data_state.is_select_region = false
		--return
	end
end)

return M
