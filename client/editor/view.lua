local state = require "editor.state"
local engine = require "editor.engine"
local input = require 'editor.input'
local def = require "editor.def"
local cmd = require "editor.cmd"
local obj = require "editor.obj"
local utils = require "editor.utils"
require "entity.entity"
require "common.world"
local entity_obj = require "editor.entity_obj"
local data_state = require "editor.dataState"

local tran = require "editor.Transform"

local M = {}

local Focus_Object = {
    Type = nil,
    Obj = nil
}

local Brush_Object = {
    Type = nil,
    Obj = nil
}

local Drag_Object = {
	Pos = nil,
	Type = nil,
	Obj = nil
}

local Frame_Pos_Object = {
	min_obj = nil,
	obj = nil,
	max_obj = nil,
	min = nil
 }

local focusPos = nil
local minObj = {min = {}, max = {}}

function M:init()
    self._brush = nil
    self._focus = nil
end

--返回范围
function M:get_Drag_Object_scope()
	if Drag_Object.Pos == nil then
		return nil
	else
		local pos = {
			x = Drag_Object.Pos.x,
			y = Drag_Object.Pos.y,
			z = Drag_Object.Pos.z
		}
		return pos
	end
end

local function delete_Drag_Object()
	if Drag_Object.Type == def.TBLOCK then
		if Drag_Object.Obj ~= nil then
			engine:del_widget_block(Drag_Object.Obj)
		end
		Drag_Object.Pos = nil
        Drag_Object.Obj = nil
        Drag_Object.Type = nil
	elseif Drag_Object.Type == def.TCHUNK then
		if Drag_Object.Obj ~= nil then
			engine:del_widget_chunk(Drag_Object.Obj)
		end
		Drag_Object.Pos = nil
        Drag_Object.Obj = nil
        Drag_Object.Type = nil
	elseif Drag_Object.Type == def.TREGION then
		if Drag_Object.Obj ~= nil then
			engine:del_widget_region(Drag_Object.Obj)
		end
		Drag_Object.Pos = nil
        Drag_Object.Obj = nil
        Drag_Object.Type = nil
	elseif Drag_Object.Type == def.TENTITY then
		if Drag_Object.Obj ~= nil then
			Drag_Object.Obj:destroy()
		end
		Drag_Object.Pos = nil
        Drag_Object.Obj = nil
        Drag_Object.Type = nil
	end
	data_state.touch_focus_pos = nil
end

function M:mpUpdate()
    do
        if input.touchPostion then
            local tmpPos = {
                x = math.ceil(input.touchPostion.x - 0.5),
                y = math.ceil(input.touchPostion.y - 0.5),
                z = math.ceil(input.touchPostion.z - 0.5)
            }

            if data_state.frame_pos_count == 1 then
                focusPos = tmpPos
                if Frame_Pos_Object.obj ~= nil then
                    local min = {
		                x = math.min(Frame_Pos_Object.min.x, focusPos.x),
		                y = math.min(Frame_Pos_Object.min.y, focusPos.y),
		                z = math.min(Frame_Pos_Object.min.z, focusPos.z)
	                }
	                local max = {
		                x = math.max(Frame_Pos_Object.min.x, focusPos.x) + 1,
		                y = math.max(Frame_Pos_Object.min.y, focusPos.y) + 1,
		                z = math.max(Frame_Pos_Object.min.z, focusPos.z) + 1
	                }
                    local scope = {
                        x = max.x - min.x,
                        y = max.y - min.y,
                        z = max.z - min.z
                    }
					Lib.emitEvent(Event.EVENT_BOUND_SCOPE, scope, Frame_Pos_Object.min, focusPos)
					Frame_Pos_Object.obj:set_bound(min, max)
					EditorModule:emitEvent("BOUND_CHANGE", scope, Frame_Pos_Object.min, focusPos)
				else
					EditorModule:emitEvent("BOUND_CHANGE", {x = 0, y = 0, z = 0})
				end
                if Frame_Pos_Object.max_obj ~= nil then
                    local focusMaxPos = Lib.v3add(focusPos, {x = 1, y = 1, z = 1})
                    Frame_Pos_Object.max_obj:set_bound(focusPos, focusMaxPos)
                end
			end
			if Brush_Object.Type == def.TCHUNK then
				Brush_Object.Obj:set_pos(tmpPos)
				EditorModule:getViewControl():upChunkSize()
				--EditorModule:emitEvent("BOUND_CHANGE", {x = 0, y = 0, z = 0})
            end
        end
	end
	--end

	-- 改变 focus 大小
	do
		local focus_obj = state:focus_obj()
		if state:focus_class() ~= nil then
			assert(state:focus_class() == Focus_Object.Type, string.format("%s:%s", Focus_Object.Type, state:focus_class()))
		end
		if focus_obj ~= nil and focus_obj.min then
            local min = {x = math.ceil(focus_obj.min.x - 0.5),
                             y = math.ceil(focus_obj.min.y - 0.5),
                             z = math.ceil(focus_obj.min.z - 0.5)}
            local max = {x = math.ceil(focus_obj.max.x - 0.5) + 1,
                             y = math.ceil(focus_obj.max.y - 0.5) + 1,
                             z = math.ceil(focus_obj.max.z - 0.5) + 1}
			if Focus_Object.Type == def.TFRAME then
				Focus_Object.Obj:set_bound(min, max)
            elseif Focus_Object.Type == def.TCHUNK and data_state.is_can_move then
                Focus_Object.Obj:set_bound(min, max)
            end
		end
	end
end

function M:update()
    -- 改变 brush 位置
	do
		if input.position then
            local inputPosMax = Lib.v3add(input.position, {x = 1, y = 1, z = 1})
			if Brush_Object.Type == def.TCHUNK then
				if input.sideNormal ~= nil then
					local pos = tran.CenterAlign(input.position,state:brush_obj(),input.sideNormal)
					Brush_Object.Obj:set_pos(pos)
				end
				--[[
				if state:focus_obj() ~= nil then
					local min = state:focus_obj().pos
					local chunk = state:focus_obj().data
					local max = {
						x = min.x + chunk.lx - 1,
						y = min.y + chunk.ly - 1,
						z = min.z + chunk.lz - 1}
				
					if engine:detect_collision(min,max) then
						engine:show_widget_block(Brush_Object.Obj,0)
					else
						engine:show_widget_block(Brush_Object.Obj,1)
					end
				end
				]]--
			elseif Brush_Object.Type == def.TBLOCK then
				--[[
				if state:focus_obj() ~= nil then
					local min = state:focus_obj().min
					local max = state:focus_obj().max
					if engine:detect_collision(min,max) then
						engine:show_widget_block(Brush_Object.Obj,0)
					else
						engine:show_widget_block(Brush_Object.Obj,1)
					end
				end
				]]--
				Brush_Object.Obj:set_pos(input.position)
			elseif Brush_Object.Type == def.TFRAME then
				Brush_Object.Obj:set_bound(input.position, inputPosMax)	-- todo 真实大小
			elseif Brush_Object.Type == def.TREGION then
				Brush_Object.Obj:set_bound(input.position, inputPosMax)	-- todo 真实大小
			elseif Brush_Object.Type == def.TENTITY then
				local pos = {
					x = input.position.x,
					y = input.position.y,
					z = input.position.z
				}
				local obj = Brush_Object.Obj
				if obj.isEntity then
					--obj:setMove(0, pos, obj.rotationYaw, obj.rotationPitch, 1, 0)
				else
					obj:setPosition(pos)
				end
				Brush_Object.Obj:setAlpha(0.5)
			end

			if Frame_Pos_Object.min_obj ~= nil and data_state.frame_pos_count == 0 then
				Frame_Pos_Object.min_obj:set_bound(input.position, inputPosMax)
			end
			if data_state.frame_pos_count == 1 then
                local pos = {
                    x = math.ceil(input.touchPostion.x - 0.5),
                    y = math.ceil(input.touchPostion.y - 0.5),
                    z = math.ceil(input.touchPostion.z - 0.5)
                }
                if Frame_Pos_Object.obj ~= nil then
                    local min = {
					    x = math.min(Frame_Pos_Object.min.x, pos.x),
					    y = math.min(Frame_Pos_Object.min.y, pos.y),
					    z = math.min(Frame_Pos_Object.min.z, pos.z)
				    }
				    local max = {
					    x = math.max(Frame_Pos_Object.min.x, pos.x) + 1,
					    y = math.max(Frame_Pos_Object.min.y, pos.y) + 1,
					    z = math.max(Frame_Pos_Object.min.z, pos.z) + 1
				    }
				    Frame_Pos_Object.obj:set_bound(min, max)
                end
                if Frame_Pos_Object.max_obj ~= nil then
                    Frame_Pos_Object.max_obj:set_bound(pos, Lib.v3add(pos, {x = 1, y = 1, z = 1}))
                end
            end
		end
	end

	-- 改变 focus 大小
	do
		local focus_obj = state:focus_obj()
		if state:focus_class() ~= nil then
			assert(state:focus_class() == Focus_Object.Type, string.format("%s:%s", Focus_Object.Type, state:focus_class()))
		end
		if focus_obj ~= nil then
			if Focus_Object.Type == def.TFRAME then
                local min = {x = math.ceil(focus_obj.min.x - 0.5),
                             y = math.ceil(focus_obj.min.y - 0.5),
                             z = math.ceil(focus_obj.min.z - 0.5)}
                local max = {x = math.ceil(focus_obj.max.x - 0.5) + 1,
                             y = math.ceil(focus_obj.max.y - 0.5) + 1,
                             z = math.ceil(focus_obj.max.z - 0.5)} + 1
				Focus_Object.Obj:set_bound(min, max)
			elseif Focus_Object.Type == def.TBLOCK then

			elseif Focus_Object.Type == def.TCHUNK then
				-- Brush_Object.Obj:set_color(0xFFFF0000)
			elseif Focus_Object.Type == def.TREGION then
				local min = obj:get_region(focus_obj.name).box.min
				local max = Lib.v3add(obj:get_region(focus_obj.name).box.max, {x = 1, y = 1, z = 1})
				Focus_Object.Obj:set_bound(min, max)
			elseif Focus_Object.Type == def.TBLOCK_FILL then
				Focus_Object.Obj:set_bound(focus_obj.min, Lib.v3add(focus_obj.max, {x = 1, y = 1, z = 1}))
			end
		end
		
	end
end

M:init()

-- 需要添加删除表现元素的通过事件通知，否则在 update 中取状态设置
Lib.subscribeEvent(Event.EVENT_EDITOR_STATE_CHANGE_MODE, function()
    -- 不同模式下看到的东西不一样
end)

local function delete_widget(class, obj)
    if class == def.TFRAME then
        engine:del_widget_frame(obj)
    elseif class == def.TCHUNK then
		engine:del_widget_frame(obj)
		engine:del_widget_block(obj)
	elseif class == def.TBLOCK then
		engine:del_widget_frame(obj)
		engine:del_widget_block(obj)
	elseif class == def.TREGION then
		engine:del_widget_region(obj)
	elseif class == def.TENTITY then
		if obj then
			--World.CurWorld:removeObject(obj)
			obj:destroy()
		end
	elseif class == def.TBLOCK_FILL then
		engine:del_widget_frame(obj)
    end
end

local _init_pos_ = {x = 0, y = 0, z = 0}

Lib.subscribeEvent(Event.EVENT_EDITOR_STATE_BACK_BRUSH, function()
-- delete
    state:set_brush({min = focusPos, max = focusPos}, def.TFRAME_POS)
    data_state.frame_pos_count = 1
	if Brush_Object.Obj ~= nil then
		delete_widget(Brush_Object.Type, Brush_Object.Obj)
		Brush_Object.Obj = nil
		Brush_Object.Type = nil
	end

	if Frame_Pos_Object.min_obj ~= nil then
		engine:del_widget_frame(Frame_Pos_Object.min_obj)
		Frame_Pos_Object.min_obj = nil
	end
	if state:brush_class() ~= def.TFRAME_POS then
		if Frame_Pos_Object.obj ~= nil then
			engine:del_widget_frame(Frame_Pos_Object.obj)
			Frame_Pos_Object.obj = nil
		end
		if Frame_Pos_Object.max_obj ~= nil then
			engine:del_widget_frame(Frame_Pos_Object.max_obj)
			Frame_Pos_Object.max_obj = nil
		end
	end

    local brush_mode = state:brush_class()

	if brush_mode == def.TFRAME_POS and data_state.frame_pos_count == 1 then
        local min = {
            x = math.min(minObj.min.x, focusPos.x),
            y = math.min(minObj.min.y, focusPos.y),
            z = math.min(minObj.min.z, focusPos.z)
        }
        local max = {
            x = math.max(minObj.min.x, focusPos.x),
            y = math.max(minObj.min.y, focusPos.y),
            z = math.max(minObj.min.z, focusPos.z)
        }
        Frame_Pos_Object.min = minObj.min
        Frame_Pos_Object.obj = engine:new_widget_frame(min, max)
        Frame_Pos_Object.obj:set_color(0x473C8BFF)
        Frame_Pos_Object.max_obj = engine:new_widget_frame(focusPos, focusPos)
        Frame_Pos_Object.max_obj:set_color(0xFF6A6AFF)
        Frame_Pos_Object.min_obj = engine:new_widget_frame(minObj.min, minObj.min)
         
    end
end)

Lib.subscribeEvent(Event.EVENT_EDITOR_STATE_CHANGE_BRUSH, function()
	-- delete
	if Brush_Object.Obj ~= nil then
		delete_widget(Brush_Object.Type, Brush_Object.Obj)
		Brush_Object.Obj = nil
		Brush_Object.Type = nil
	end

	if Frame_Pos_Object.min_obj ~= nil then
		engine:del_widget_frame(Frame_Pos_Object.min_obj)
		Frame_Pos_Object.min_obj = nil
	end
	if state:brush_class() ~= def.TFRAME_POS then
		if Frame_Pos_Object.obj ~= nil then
			engine:del_widget_frame(Frame_Pos_Object.obj)
			Frame_Pos_Object.obj = nil
		end
		if Frame_Pos_Object.max_obj ~= nil then
			engine:del_widget_frame(Frame_Pos_Object.max_obj)
			Frame_Pos_Object.max_obj = nil
		end
	end

	-- new
	local wobj = nil
    local brush_mode = state:brush_class()
	local brush_obj = state:brush_obj()
	if brush_mode == def.TFRAME then
		wobj = engine:new_widget_frame(brush_obj.min, brush_obj.max)
	elseif brush_mode == def.TFRAME_POS then
		if data_state.frame_pos_count == 0 then
			Frame_Pos_Object.min_obj = engine:new_widget_frame(brush_obj.min, brush_obj.max)
			Frame_Pos_Object.obj = nil
			Frame_Pos_Object.max_obj = nil
		elseif data_state.frame_pos_count == 1 then
            Frame_Pos_Object.obj = engine:new_widget_frame(brush_obj.min, brush_obj.max)
            Frame_Pos_Object.obj:set_color(0x473C8BFF)
			Frame_Pos_Object.max_obj = engine:new_widget_frame(brush_obj.min, brush_obj.max)
            Frame_Pos_Object.max_obj:set_color(0xFF6A6AFF)
            Frame_Pos_Object.min_obj = engine:new_widget_frame(Frame_Pos_Object.min, Frame_Pos_Object.min)
		end
	elseif brush_mode == def.TCHUNK then
		wobj = engine:new_widget_chunk(_init_pos_, brush_obj)
	elseif brush_mode == def.TREGION then
		wobj = engine:new_widget_region(brush_obj.min, brush_obj.max)
	end

	Brush_Object.Obj = wobj
	Brush_Object.Type = brush_mode
	engine:gizmo_widget_set_box({x=0,y=0,z=0},{x=0,y=0,z=0})
end)

function M:get_gizmo_pos(gizmo_pos)--获取轴位置
	local focus_mode = state:focus_class()
	local focus_obj = state:focus_obj()
	local pos = nil
	if focus_mode == def.TFRAME then
		
	elseif focus_mode == def.TBLOCK then
		pos = {
			x = gizmo_pos.x + 0.5,
			y = gizmo_pos.y + 0.5,
			z = gizmo_pos.z + 0.5
		}
	elseif focus_mode == def.TCHUNK then
		pos = {
			x =  gizmo_pos.x + focus_obj.data.lx / 2,
			y =  gizmo_pos.y + focus_obj.data.ly / 2,
			z =  gizmo_pos.z + focus_obj.data.lz / 2
		}
	elseif focus_mode == def.TREGION then
		
	elseif focus_mode == def.TENTITY then
		pos = gizmo_pos
	elseif focus_mode == def.TBLOCK_FILL then
		
	end
	return pos
end

Lib.subscribeEvent(Event.EVENT_EDITOR_STATE_CHANGE_FOCUS, function()
	do
		--engine:hide_widget_gizmo()
			engine:gizmo_widget_switch(0)
			engine:scaler_widget_switch(0)
			delete_Drag_Object()

		if Focus_Object.Obj ~= nil then
			delete_widget(Focus_Object.Type, Focus_Object.Obj)
			Focus_Object.Type = nil
			Focus_Object.Obj = nil
		end
	end
	-- new
	do
		local pos, need_confirm = nil, nil
		local wobj = nil
		local pos_min,pos_max = nil, nil

		local focus_mode = state:focus_class()
		local focus_obj = state:focus_obj()
		if focus_mode == def.TFRAME then
			engine:clear_property_dock()
			wobj = engine:new_widget_frame(focus_obj.min, focus_obj.max)
			local offset = Lib.v3cut(focus_obj.max, focus_obj.min)
			pos = {}
			pos.x = focus_obj.min.x + (offset.x) / 2
			pos.y = focus_obj.min.y + (offset.y) / 2
			pos.z = focus_obj.min.z + (offset.z) / 2
			pos_min = focus_obj.min
			pos_max = {
				x = focus_obj.max.x + 1,
				y = focus_obj.max.y + 1,
				z = focus_obj.max.z + 1
			}
			need_confirm = true
			--engine:Is_Controller(pos_min,focus_obj.max)
			engine:show_property_dock_scale(pos_min,pos_max)
		elseif focus_mode == def.TBLOCK then
			--engine:clear_property_dock()
			wobj = engine:new_widget_frame(focus_obj.pos, focus_obj.pos)
			pos = {
				x = focus_obj.pos.x + 0.5,
				y = focus_obj.pos.y + 0.5,
				z = focus_obj.pos.z + 0.5
			}
			pos_min = focus_obj.pos
			pos_max = {
				x = pos_min.x + 1,
				y = pos_min.y + 1,
				z = pos_min.z + 1
			}
			--engine:Is_Controller(pos_min,pos_min)
			--engine:editor_obj_type("TBLOCK")
			--engine:show_property_dock_move(pos_min)
		elseif focus_mode == def.TCHUNK then
			engine:clear_property_dock()
			pos_min = focus_obj.pos
			pos_max = {
				x = pos_min.x + state:focus_obj().data.lx + 1,
				y = pos_min.y + state:focus_obj().data.ly + 1,
				z = pos_min.z + state:focus_obj().data.lz + 1
			}
			local max = {
				x = pos_min.x + state:focus_obj().data.lx - 1,
				y = pos_min.y + state:focus_obj().data.ly - 1,
				z = pos_min.z + state:focus_obj().data.lz - 1
			}
			pos = {
				x =  focus_obj.pos.x + state:focus_obj().data.lx / 2,--3-1
				y =  focus_obj.pos.y + state:focus_obj().data.ly / 2,--2-1
				z =  focus_obj.pos.z + state:focus_obj().data.lz / 2
			}
			wobj = engine:new_widget_frame(pos_min, max)
			--engine:Is_Controller(pos_min,max)
			engine:show_property_dock_move(pos_min)
		elseif focus_mode == def.TREGION then
			local obj_region = obj:get_region(focus_obj.name)
			assert(obj_region)
			wobj = engine:new_widget_region(obj_region.box.min, obj_region.box.max)
			local offset = Lib.v3cut(obj_region.box.max, obj_region.box.min)
			pos = {}
			pos.x = obj_region.box.min.x + (offset.x) / 2
			pos.y = obj_region.box.min.y + (offset.y) / 2
			pos.z = obj_region.box.min.z + (offset.z) / 2 
			pos_min = obj_region.box.min
			pos_max = {
				x = obj_region.box.max.x + 1,
				y = obj_region.box.max.y + 1,
				z = obj_region.box.max.z + 1
			}
			--engine:Is_Controller(pos_min,obj_region.box.max)
		elseif focus_mode == def.TENTITY then
			engine:clear_property_dock()
			pos = entity_obj:getPosById(focus_obj.id)
			--wobj = entity_obj:get_entity_by_id(focus_obj.id)
			--engine:Is_Controller()
		elseif focus_mode == def.TBLOCK_FILL then
			engine:clear_property_dock()
			wobj = engine:new_widget_frame(focus_obj.min, focus_obj.max)
			local offset = Lib.v3cut(focus_obj.max, focus_obj.min)
			pos = {}
			pos.x = focus_obj.min.x + (offset.x) / 2
			pos.y = focus_obj.min.y + (offset.y) / 2
			pos.z = focus_obj.min.z + (offset.z) / 2
			pos_min = focus_obj.min
			pos_max = {
				x = focus_obj.max.x + 1,
				y = focus_obj.max.y + 1,
				z = focus_obj.max.z + 1
			}
		end
		if pos then
		--engine:show_widget_gizmo(pos, need_confirm)
			if state:get_editmode() == def.EMOVE then
				engine:gizmo_widget_set_pos(pos)
				if focus_mode ~= def.TENTITY and state:brush_obj() == nil then
					engine:gizmo_widget_set_box(Lib.v3cut(pos_min,pos),Lib.v3cut(pos_max,pos))
				end
				engine:gizmo_widget_switch(0)
				engine:setCanDragFace_widget_frame(wobj,1)
			elseif state:get_editmode() == def.ESCALE then
				engine:scaler_widget_set_pos(pos_min,pos_max)
				engine:scaler_widget_switch(0)
				engine:setCanDragFace_widget_frame(wobj,1)
			else
				engine:gizmo_widget_switch(0)
				engine:scaler_widget_switch(0)
				engine:setCanDragFace_widget_frame(wobj,0)
			end
		end

		Focus_Object.Type = focus_mode
		Focus_Object.Obj = wobj
	end
end)

local function is_same_focus()
	local fousObj = state:focus_obj()
	if Drag_Object.Pos ~= nil 
		and Drag_Object.Pos.x == fousObj.pos.x 
		and Drag_Object.Pos.y == fousObj.pos.y 
		and Drag_Object.Pos.z == fousObj.pos.z then
		if Drag_Object.Type == def.TBLOCK or Drag_Object.Type == def.TCHUNK then
			return true
		end
	end
	return false
end

Lib.subscribeEvent(Event.EVENT_EDITOR_GIZMO_DRAG_START, function()
	if Drag_Object.Obj ~= nil then
		return
	end
    local focusType = state:focus_class()
	local focusObj = state:focus_obj()
    if focusType then
        if focusType == def.TBLOCK then
            local id = engine:get_block(focusObj.pos)
            Drag_Object.Obj = engine:new_widget_block(focusObj.pos, id)
            Drag_Object.Type = focusType
			Drag_Object.Pos = focusObj.pos
		elseif focusType == def.TCHUNK then
			Drag_Object.Obj = engine:new_widget_chunk(focusObj.pos, focusObj.data)
			Drag_Object.Type = focusType
			Drag_Object.Pos = focusObj.pos
		elseif focusType == def.TENTITY then
			local cfg = entity_obj:getCfgById(focusObj.id)
			local pos = entity_obj:getPosById(focusObj.id)
			Drag_Object.Obj = EntityClient.CreateClientEntity({cfgName=cfg,pos=pos})
			Drag_Object.Type = focusType
			Drag_Object.Pos = pos
        end
    end
end)

Lib.subscribeEvent(Event.EVENT_EDITOR_GIZMO_DRAG_MOVE, function(beginPos, offset)
    if Drag_Object.Obj then
		if Drag_Object.Type == def.TBLOCK then
			local pos = {
				x = math.ceil(beginPos.x - 0.5),
				y = math.ceil(beginPos.y - 0.5),
				z = math.ceil(beginPos.z - 0.5)
			}
			Drag_Object.Pos = Lib.v3add(pos,offset)
			Drag_Object.Obj:set_pos(Drag_Object.Pos)
		elseif Drag_Object.Type == def.TCHUNK then
			local pos = {
				x = math.modf(beginPos.x - state:focus_obj().data.lx / 2),
				y = math.modf(beginPos.y - state:focus_obj().data.ly / 2),
				z = math.modf(beginPos.z - state:focus_obj().data.lz / 2)
			}
			Drag_Object.Pos = Lib.v3add(pos,offset)
			Drag_Object.Obj:set_pos(Drag_Object.Pos)
		elseif Drag_Object.Type == def.TENTITY then
			Drag_Object.Pos = Lib.v3add(beginPos, offset)
			Drag_Object.Obj:setPosition(Drag_Object.Pos)
			Drag_Object.Obj:setAlpha(0.5)
		end

		data_state.touch_focus_pos = Drag_Object.Pos

		if Drag_Object.Type == def.TBLOCK or Drag_Object.Type == def.TCHUNK then
			if is_same_focus() == false and data_state.is_GIZMO_DRAG_MOVE == false then
				engine:show_property_dock_move(Drag_Object.Pos)
			end
		end
	end
end)

Lib.subscribeEvent(Event.EVENT_EDITOR_GIZMO_DRAG_END, function(beginPos, offset)
	if Drag_Object.Type == def.TENTITY then
		local focus_obj = state:focus_obj()
		local id = focus_obj.id
		local pos_s = entity_obj:getPosById(id)
		local pos_d = Drag_Object.Pos
		local yaw = entity_obj:get_yaw_byid(id)
		local pitch = entity_obj:get_pitch_byid(id)

		local old_data = {
			pos = pos_s,
			yaw = yaw,
			pitch = pitch
		}

		local  new_data = {
			pos = pos_d,
			yaw = yaw,
			pitch = pitch
		}
		cmd:move_entity(id,old_data,new_data,true)
		delete_Drag_Object()
		return
	end
	if is_same_focus() == false then
		engine:show_property_TF_btn(data_state.is_property_change)
	end
	data_state.is_property_change = false
end)

function M:gizmo_darg_end_true()
	local focus_obj = state:focus_obj()
	local focus_class = state:focus_class()
	if focus_class == def.TBLOCK then
		cmd:move_block(focus_obj.pos,Drag_Object.Pos)
	elseif focus_class == def.TCHUNK then
		local chunk = state:focus_obj().data
		cmd:move_chunk(focus_obj.pos, Drag_Object.Pos, chunk)
	end
	delete_Drag_Object()
end

function M:gizmo_darg_end_false()
	delete_Drag_Object();
	Lib.emitEvent(Event.EVENT_EDITOR_STATE_CHANGE_FOCUS)
end

Lib.subscribeEvent(Event.FRAME_POSITION, function(focus_pos)
	if data_state.frame_pos_count == 0 then
		data_state.frame_pos_count = 1
		Frame_Pos_Object.min = focus_pos
        minObj.min = Lib.copy(focus_pos)
        minObj.max = Lib.copy(focus_pos)
		state:set_brush(Lib.copy(minObj), def.TFRAME_POS)
        data_state.is_can_update = true
	else
		local obj = {
			min = {
				x = math.min(Frame_Pos_Object.min.x,focus_pos.x),
				y = math.min(Frame_Pos_Object.min.y,focus_pos.y),
				z = math.min(Frame_Pos_Object.min.z,focus_pos.z)
			},
			max = {
				x = math.max(Frame_Pos_Object.min.x,focus_pos.x),
				y = math.max(Frame_Pos_Object.min.y,focus_pos.y),
				z = math.max(Frame_Pos_Object.min.z,focus_pos.z)
			}
		}
		data_state.frame_pos_count = 0
		if Frame_Pos_Object.min_obj ~= nil then
			engine:del_widget_frame(Frame_Pos_Object.min_obj)
			Frame_Pos_Object.min_obj = nil
		end
		if Frame_Pos_Object.obj ~= nil then
			engine:del_widget_frame(Frame_Pos_Object.obj)
			Frame_Pos_Object.obj = nil
		end
		if Frame_Pos_Object.max_obj ~= nil then
			engine:del_widget_frame(Frame_Pos_Object.max_obj)
			Frame_Pos_Object.max_obj = nil
		end
		Frame_Pos_Object.min = nil
		data_state.is_frame_pos = true
        data_state.is_can_update = false
		state:set_focus(obj,def.TFRAME)
		--state:set_editmode(def.ESCALE)
		engine:editor_obj_type("TFRAME")
	end
end)

function M:Brush_Object()
end

Lib.subscribeEvent(Event.EVENT_EDIT_BUILDINGS_BACK, function()
    state:set_focus({min = focusPos, max = focusPos}, def.TFRAME)
end)

return M