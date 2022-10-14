local core = require "editor.core"
local setting = require "common.setting"
local cjson = require "cjson"
local data_state = require "editor.dataState"
local cmd = require "editor.cmd"
local memoryfile = require "memoryfile"
local lfs = require "lfs"
local def = require "editor.def"

local M = {}

local Req_count = {
	fin = nil,
	rmn = nil,
	tot = nil
}

-----------------------------------------------------------
-- block
function M:set_block(pos, id, result)
	local map = World.CurMap
	local function checkBreakAttachBlockEvent(pos, result)
		local oldId = map:getBlockConfigId(pos)
		if oldId == 0 or id ~= 0 then
			return
		end
		local posx = pos.x
		local posy = pos.y
		local posz = pos.z

		local checkPosList = {
			["1:0:0"]  = {x = posx + 1, y = posy, z = posz},
			["-1:0:0"] = {x = posx - 1, y = posy, z = posz},
			["0:1:0"]  = {x = posx, y = posy + 1, z = posz},
			["0:-1:0"]  = {x = posx, y = posy - 1, z = posz},
			["0:0:1"]  = {x = posx, y = posy, z = posz + 1},
			["0:0:-1"]  = {x = posx, y = posy, z = posz - 1},
		}
		for key, mPos in pairs(checkPosList) do
			local blockCfg = map:getBlock(mPos)
			local id = blockCfg.id
			if blockCfg.attackSide == key then
				map:setBlockConfigId(mPos, 0)
				if id ~= 0 then
					table.insert(result.attachBlockList, {pos = mPos, id = id})
				end
			end
		end
	end
	if result and type(result) == "table" then
		result.attachBlockList = {}
		checkBreakAttachBlockEvent(pos, result)
	end
	return World.CurMap:setBlockConfigId(pos, id)
end

function M:get_block(pos)
	return World.CurMap:getBlockConfigId(pos)
end

function M:clr_block(pos)
	return World.CurMap:setBlockConfigId(pos, 0)
end

----------------------------------------------------------
-- chunk
function M:isOuNumber(num)
    local num1, num2 = math.modf(num / 2)
    if num2 == 0 then
        return true
    end
    return false
end

function M:make_chunk(pos_min, pos_max, solid, isRecord) --flag,
	assert(pos_min.x <= pos_max.x)
	assert(pos_min.y <= pos_max.y)
	assert(pos_min.z <= pos_max.z)

	local chunk = core.make_chunk(pos_min, pos_max, solid)
	assert(chunk)

    local lx, ly, lz = pos_max.x - pos_min.x + 1, pos_max.y - pos_min.y + 1, pos_max.z - pos_min.z + 1

	local prop = {
		lx = lx,
		ly = ly,
		lz = lz
	}
    if isRecord then
        self.blockIdInChunk = {}    --save block id in chunk
        local idx = 1
        for i = pos_min.x, pos_max.x do
            for j = pos_min.y, pos_max.y do
                for k = pos_min.z, pos_max.z do
                    if i < pos_min.x and k < pos_min.z then
                        self.blockIdInChunk[idx] = 0
                    else
                        self.blockIdInChunk[idx] = self:get_block({x = i, y = j, z = k})
                    end
                    idx = idx + 1
                end
            end
        end
    end

	return debug.setmetatable(chunk, {
		__index = function(chunk, key)
			assert(prop[key], string.format("invalid prop %s", key))
			return prop[key]
		end
	})
end

function M:make_chunk_byid(pos_min, pos_max, solid, id)
	assert(pos_min.x <= pos_max.x)
	assert(pos_min.y <= pos_max.y)
	assert(pos_min.z <= pos_max.z)

	local chunk = core.make_chunk_byid(pos_min, pos_max, solid, id)
	assert(chunk)

	local prop = {
		lx = pos_max.x - pos_min.x + 1,
		ly = pos_max.y - pos_min.y + 1,
		lz = pos_max.z - pos_min.z + 1
	}

	return debug.setmetatable(chunk, {
		__index = function(chunk, key)
			assert(prop[key], string.format("invalid prop %s", key))
			return prop[key]
		end
	})
end

function M:make_chunk_bytable(pos_min, pos_max, solid, _table)
	assert(pos_min.x <= pos_max.x)
	assert(pos_min.y <= pos_max.y)
	assert(pos_min.z <= pos_max.z)

    local lx = pos_max.x - pos_min.x + 1;
	local ly = pos_max.y - pos_min.y + 1;
	local lz = pos_max.z - pos_min.z + 1;

	local chunk = core.make_chunk_bytable(lx, ly, lz, solid, _table)
	assert(chunk)

	local prop = {
		lx = pos_max.x - pos_min.x + 1,
		ly = pos_max.y - pos_min.y + 1,
		lz = pos_max.z - pos_min.z + 1
	}

	return debug.setmetatable(chunk, {
		__index = function(chunk, key)
			assert(prop[key], string.format("invalid prop %s", key))
			return prop[key]
		end
	})
end

function M:set_chunk(pos_min, chunk)
	return core.set_chunk(pos_min, chunk)
end

function M:clr_chunk(pos_min, chunk)
	return core.clr_chunk(pos_min, chunk)
end

function M:calculate_block(vMin, vMax, rotate)  --rotate==1,clockwise, rotate==2,anticlockwise
    assert(vMin.x <= vMax.x)
	assert(vMin.y <= vMax.y)
	assert(vMin.z <= vMax.z)
    local ret = {}
    local lx, ly, lz = vMax.x - vMin.x + 1, vMax.y - vMin.y + 1, vMax.z - vMin.z + 1
    local idx = 1
    if rotate == 1 then
        for x = 1, lz do
            for y = 1, ly do
                for z = lx, 1, -1 do
                    local index = (z - 1) * ly * lz + (y - 1) * lz + x
                    ret[idx] = self.blockIdInChunk[index]
                    idx = idx + 1
                end
            end
        end
    else
        for x = lz, 1, -1 do
            for y = 1, ly do
                for z = 1, lx do
                    local index = (z - 1) * ly * lz + (y - 1) * lz + x
                    ret[idx] = self.blockIdInChunk[index]
                    idx = idx + 1
                end
            end
        end 
    end
    self.blockIdInChunk = ret
    return ret
end

----------------------------------------------------------
-- pick
function M:make_pick(blocks, entities)
	return {
		
	}
end

function M:set_pick(pos, pick)

end

function M:clr_pick(pos, pick)

end

----------------------------------------------------------
--entity obj
function M:on_new_entity(id,obj)
	local paramsjson = cjson.encode({
		type = "on_new_entity",
		params = {
			id = id,
			obj = obj
		}
	})
	return core.notify(paramsjson)
end

function M:on_del_entity(id)
	local paramsjson = cjson.encode({
			type = "on_del_entity",
			id = id
		}
	)
	return core.notify(paramsjson)
end

function M:on_update_entity(id,pos,yaw,pitch)
	local paramsjson = cjson.encode({
			type = "on_update_entity",
			params = {
				id = id,
				pos = pos,
				yaw = yaw,
				pitch = pitch
			}
		}
	)
	return core.notify(paramsjson)
end

function M:pitch_on_entity(id)
	local paramsjson = cjson.encode({
			type = "pitch_on_entity",
			id = id
		}
	)
	return core.notify(paramsjson)
end

----------------------------------------------------------
-- region obj
function M:on_new_region(id, obj)
	local paramsjson = cjson.encode({
		type = "on_new_region",
		params = {
			id = id,
			obj = obj
		}
	}
	)
	return core.notify(paramsjson)
end

function M:on_del_region(id)
	local paramsjson = cjson.encode({
			type = "on_del_region",
			id = id
		}
	)
	return core.notify(paramsjson)
end

function M:on_update_region(id, obj)
	local paramsjson = cjson.encode({
			type = "on_update_region",
			params = {
				id = id,
				obj = obj
			}
		}
	)
	return core.notify(paramsjson)
end

function M:on_update_region_name(id,name)
	local paramsjson = cjson.encode({
		type = "on_update_region_name",
		params = {
			id = id,
			name = name
		}
	})
	return core.notify(paramsjson)
end

function M:del_region(name)
end

function M:move_region(id, pos)
	
end

function M:get_region(pos)
	--TODO TO id
end

----------------------------------------------------------
-- frame widget
function M:new_widget_frame(pos_min, pos_max, flag)
	assert(pos_min.x <= pos_max.x)
	assert(pos_min.y <= pos_max.y)
	assert(pos_min.z <= pos_max.z)
    if not flag then
        pos_max = Lib.v3add(pos_max, {x = 1, y = 1, z = 1})
    end

	local obj = core.new_widget_frame(pos_min, pos_max)

	return debug.setmetatable(obj, {
		__index = core.frame_lib
	})
end

function M:del_widget_frame(obj)
	return core.del_widget_frame(obj)
end

function M:show_widget_frame(nId,bool)
	return core.show_widget_frame(nId,bool)
end

function M:setCanDragFace_widget_frame(nId,bool)
	if nId ~= nil then
		--return core.setCanDragFace_widget_frame(nId,bool)
	end
end

----------------------------------------------------------
-- block widget
function M:new_widget_block(pos, id)
    local obj = core.new_widget_block(pos, id)

    return debug.setmetatable(obj, {
        __index = core.block_lib
    })
end

function M:del_widget_block(obj)
    return core.del_widget_block(obj)
end

function M:show_widget_block(id,bool)
	return core.show_widget_block(id,bool)
end

----------------------------------------------------------
-- chunk widget
function M:new_widget_chunk(pos, chunk)
	local obj = core.new_widget_chunk(pos, chunk)

	return debug.setmetatable(obj, {
		__index = core.chunk_lib
	})
end

function M:del_widget_chunk(obj)
	return core.del_widget_chunk(obj)
end

----------------------------------------------------------
-- region widget 
function M:new_widget_region(pos_min, pos_max)
	assert(pos_min.x <= pos_max.x)
	assert(pos_min.y <= pos_max.y)
	assert(pos_min.z <= pos_max.z)

	local obj = core.new_widget_frame(pos_min, pos_max)

	return debug.setmetatable(obj, {
		__index = core.frame_lib
	})
end

function M:del_widget_region(obj)
	return core.del_widget_frame(obj)
end

function M:has_widget(obj)
	return core.has_widget(obj)
end

----------------------------------------------------------
-- gizmo
function M:gizmo_widget_set_pos(pos)
    core.gizmo_widget_set_pos(pos)
end
function M:gizmo_widget_set_box(min,max)
    core.gizmo_widget_set_box(min,max)
end
function M:gizmo_widget_switch(on)
    core.gizmo_widget_switch(on)
end

local gizmo
function M:show_widget_gizmo(pos, need_confirm)
	gizmo = UI:openWnd("editorhelper")
	gizmo:reset(pos, need_confirm)
end

function M:hide_widget_gizmo()
	UI:closeWnd("editorhelper")
	gizmo = nil
end

----------------------------------------------------------
-- scaler
function M:scaler_widget_set_pos(min,max)
    core.scaler_widget_set_pos(min,max)
end
function M:scaler_widget_switch(on)
    core.scaler_widget_switch(on)
end

----------------------------------------------------------
-- isController

function M:Is_Controller(min,max,omin,omax)
	core.Left_Is_Controller(1)
	core.Right_Is_Controller(1)
	core.Up_Is_Controller(1)
	core.Down_Is_Controller(1)
	core.Front_Is_Controller(1)
	core.Back_Is_Controller(1)

	if data_state.isCanRid == true then
		return
	end
	if min == nil and max == nil and omin == nil and omax == nil then
		return
	end

	local pos = {}
	for z = 0,max.z - min.z do
		for y = 0,max.y - min.y do
			pos = {
				x = min.x - 1,
				y = min.y + y,
				z = min.z + z
			}
			if omin == nil or omax == nil then
				if self:get_block(pos) ~= 0 then
					core.Right_Is_Controller(0);
					--cmd:set_block(pos,7)
				end
			else
				if pos.x < omin.x 
				or pos.x > omax.x 
				or pos.y < omin.y 
				or pos.y > omax.y
				or pos.z < omin.z
				or pos.z > omax.z then
					if self:get_block(pos) ~= 0 then
						core.Right_Is_Controller(0);
						--cmd:set_block(pos,7)
					end
				end
			end
		end
	end
	for z = 0,max.z - min.z do
		for y = 0,max.y - min.y do
			pos = {
				x = max.x + 1,
				y = max.y - y,
				z = max.z - z
			}
			if omin == nil or omax == nil then
				if self:get_block(pos) ~= 0 then
					core.Left_Is_Controller(0);
					--cmd:set_block(pos,7)
				end
			else
				if pos.x < omin.x 
				or pos.x > omax.x 
				or pos.y < omin.y 
				or pos.y > omax.y
				or pos.z < omin.z
				or pos.z > omax.z then
					if self:get_block(pos) ~= 0 then
						core.Left_Is_Controller(0);
						--cmd:set_block(pos,7)
					end
				end
			end
		end
	end
	for z = 0,max.z - min.z do
		for x = 0,max.x - min.x do
			pos = {
				x = max.x - x,
				y = max.y + 1,
				z = max.z - z
			}
			if omin == nil or omax == nil then
				if self:get_block(pos) ~= 0 then
					core.Up_Is_Controller(0);
					--cmd:set_block(pos,7)
				end
			else
				if pos.x < omin.x 
				or pos.x > omax.x 
				or pos.y < omin.y 
				or pos.y > omax.y
				or pos.z < omin.z
				or pos.z > omax.z then
					if self:get_block(pos) ~= 0 then
						core.Up_Is_Controller(0);
						--cmd:set_block(pos,7)
					end
				end
			end
		end
	end
	for z = 0,max.z - min.z do
		for x = 0,max.x - min.x do
			pos = {
				x = min.x + x,
				y = min.y - 1,
				z = min.z + z
			}
			if omin == nil or omax == nil then
				if self:get_block(pos) ~= 0 then
					core.Down_Is_Controller(0);
					--cmd:set_block(pos,7)
				end
			else
				if pos.x < omin.x 
				or pos.x > omax.x 
				or pos.y < omin.y 
				or pos.y > omax.y
				or pos.z < omin.z
				or pos.z > omax.z then
					if self:get_block(pos) ~= 0 then
						core.Down_Is_Controller(0);
						--cmd:set_block(pos,7)
					end
				end
			end
		end
	end
	for y = 0,max.y - min.y do
		for x = 0,max.x - min.x do
			pos = {
				x = max.x - x,
				y = max.y - y,
				z = max.z + 1
			}
			if omin == nil or omax == nil then
				if self:get_block(pos) ~= 0 then
					core.Front_Is_Controller(0);
					--cmd:set_block(pos,7)
				end
			else
				if pos.x < omin.x 
				or pos.x > omax.x 
				or pos.y < omin.y 
				or pos.y > omax.y
				or pos.z < omin.z
				or pos.z > omax.z then
					if self:get_block(pos) ~= 0 then
						core.Front_Is_Controller(0);
						--cmd:set_block(pos,7)
					end
				end
			end
		end
	end
	for y = 0,max.y - min.y do
		for x = 0,max.x - min.x do
			pos = {
				x = min.x + x,
				y = min.y + y,
				z = min.z - 1
			}
			if omin == nil or omax == nil then
				if self:get_block(pos) ~= 0 then
					core.Back_Is_Controller(0);
					--cmd:set_block(pos,7)
				end
			else
				if pos.x < omin.x 
				or pos.x > omax.x 
				or pos.y < omin.y 
				or pos.y > omax.y
				or pos.z < omin.z
				or pos.z > omax.z then
					if self:get_block(pos) ~= 0 then
						core.Back_Is_Controller(0);
						--cmd:set_block(pos,7)
					end
				end
			end
		end
	end
end

----------------------------------------------------------
-- rungame
function M:set_bModify(isModify)
	data_state.is_warning_save = isModify
end

function M:save_map(path)
	core.save_map(path)
end

function M:detect_collision(min,max)
	return core.detect_collision(min,max)
end

function M:open_menu(focus_class)
	local paramsjson = cjson.encode(
		{
			type = "open_menu",
			params = {
				focus_class = focus_class
			}
		}
	)
	return core.notify(paramsjson)
end

function M:editor_obj_type(obj_type)
	local paramsjson = cjson.encode(
		{
			type = "editor_obj_type",
			params = {
				obj_type = obj_type
			}
		}
	)
	return core.notify(paramsjson)
end

function M:birth_position(pos)
	local paramsjson = cjson.encode({
		type = "birth_position",
		params = {
			pos = pos
		}
	})
	return core.notify(paramsjson)
end

function M:get_finish_region(min,max)
	local paramsjson = cjson.encode({
		type = "get_finish_region",
		params = {
			min = min,
			max = max
		}
	})
	return core.notify(paramsjson)
end

function  M:down_region()
	local paramsjson = cjson.encode({
		type = "down_region"
	})
	return core.notify(paramsjson)
end

function  M:up_region()
	local paramsjson = cjson.encode({
		type = "up_region"
	})
	return core.notify(paramsjson)
end


function M:send_entity_id(id)
	local paramsjson = cjson.encode({
		type = "send_entity_id",
		params = {
			id = id
		}
	})
	return core.notify(paramsjson)
end

function M:send_block_name(name)
	local paramsjson = cjson.encode({
		type = "send_block_name",
		params = {
			name = name
		}
	})
	return core.notify(paramsjson);
end

function M:show_scene_menu()
	local paramsjson = cjson.encode({
		type = "show_scene_menu"
	})
	return core.notify(paramsjson)
end

function M:recently_block(name)

	local paramsjson = cjson.encode({
		type = "recently_block",
		params = {
			name = name
		}
	})
	return core.notify(paramsjson)
end

function M:recently_entity(name)

	local paramsjson = cjson.encode({
		type = "recently_entity",
		params = {
			name = name
		}
	})
	return core.notify(paramsjson)
end

function M:iterate_block(pos_min, pos_max, func, step)
	step = step or 1
	assert(step > 0)

	local total = (pos_max.x - pos_min.x + 1) * (pos_max.y - pos_min.y + 1) * (pos_max.z - pos_min.z + 1)
	assert(total > 0)
	local remain = total
	
	local co = coroutine.create(function()
		local count = step
		for x = pos_min.x, pos_max.x do
			for y = pos_min.y, pos_max.y do
				for z = pos_min.z, pos_max.z do
					local ret, errmsg = xpcall(func, traceback, {x = x, y = y, z = z})
					assert(ret, errmsg)
					count = count - 1
					remain = remain - 1
					if remain <= 0 then
						goto FINISH
					elseif count <= 0 then
						coroutine.yield(false, remain, total)
						count = step
					end
				end
			end
		end

::FINISH::
		assert(remain == 0)
		return true, remain, total
	end)

	return function()
		local rets = {coroutine.resume(co)}
		if not rets[1] then
			assert(false, rets[2])
		end

		return table.unpack(rets, 2)
	end
end

local mem_file = {}
function M:set_mem_file(path, content)
	local file = memoryfile.open(path, "w")
	file:write(content)
	file:close()

	lfs.touch(path)
	mem_file[path] = file
end


function M:clear_mem_file()
	for _, file in pairs(mem_file) do
		memoryfile.remove(file)
	end
	mem_file = {}
end

function M:check_mem_file(path)
	return mem_file[path]
end

function M:reload_item(plugin, module, item)
	ResourceGroupManager.Instance():addResourceLocation("./", def.PATH_GAME_META_ASSET, "FileSystem")

	local fullname = string.format("%s/%s", plugin, item)
	local mod = setting:mod(module)
	setting:loadId()
	mod:reloadCfg(mod:get(fullname))
	if module == "block" then
		Blockman.instance:refreshBlocks()
	end
end

--�򿪽���������
function M:open_progress_window(_type)
	local paramsjson = cjson.encode({
		type = "open_progress_window",
		params = {
			_type = _type
		}
	})
	return core.notify(paramsjson)
end


--����ѡ�з������
function M:update_req_count(fin,rmn,tot)
	local paramsjson = cjson.encode({
		type = "update_req_count",
		params = {
			fin = fin,
			rmn = rmn,
			tot = tot
		}
	})
	return core.notify(paramsjson)
end

--������ɣ��ص�����teble
function M:get_repote_ret(ret)
	local paramsjson = cjson.encode({
		type = "get_repote_ret",
		params = {
			ret = ret
		}
	})
	return core.notify(paramsjson)
end

function M:ClearWheelValue()
	local paramsjson = cjson.encode({
		type = "clear_wheel_value"
	})
	return core.notify(paramsjson);
end

--�ı������״̬
function M:set_cursor(cursor)
	local paramsjson = cjson.encode({
		type = "set_cursor",
		params = {
			cursor = cursor
		}
	})
	return core.notify(paramsjson)
end

--�ƶ���ʾʱ���������ʾ�������
function M:show_property_dock_move(pos)
	local paramsjson = cjson.encode({
		type = "show_property_dock_move",
		params = {
			pos = pos
		}
	})
	return core.notify(paramsjson);
end

--��������ʾʱ���������ʾ�������
function M:show_property_dock_scale(min,max)
	local paramsjson = cjson.encode({
		type = "show_property_dock_scale",
		params = {
			min = min,
			max = max
		}
	})
	return core.notify(paramsjson)
end

--����������
function M:clear_property_dock()
	local paramsjson = cjson.encode({
			type = "clear_property_dock"
		})
	return core.notify(paramsjson);
end

--���������ʾȷ��ȡ����ť
function M:show_property_TF_btn(b)
	local paramsjson = cjson.encode({
			type = "show_property_TF_btn",
			params = {
				show = b
			}
		})
	return core.notify(paramsjson)
end

--ͨ��QT����json�����и�ʽ��
function M:save_json(path,json)
	local paramsjson = cjson.encode({
			type = "save_json",
			params = {
				path = path,
				content = json
			}
		})
	return core.notify(paramsjson)
end

return M
