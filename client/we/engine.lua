local core = require "editor.core"
local setting = require "common.setting"
local cjson = require "cjson"
local data_state = require "we.data_state"
local cmd = require "we.cmd"
local memoryfile = require "memoryfile"
local lfs = require "lfs"
local def = require "we.def"
local Module = require "we.gamedata.module.module"
local lang = require "we.gamedata.lang"
local state = require "we.state"

local M = {}

local Req_count = {
	fin = nil,
	rmn = nil,
	tot = nil
}

-----------------------------------------------------------
-- block
function M:set_block(pos, id)
	if pos.y < 0 or pos.y > 255 then
		return
	end
	return World.CurMap:setBlockConfigId(pos, id)
end

function M:get_block(pos)
	return World.CurMap:getBlockConfigId(pos)
end

function M:clr_block(pos)
	return World.CurMap:setBlockConfigId(pos, 0)
end

function M:on_click_block()
	local cfg = setting:id2name("block",self:get_block(state:focus_obj().pos))
	local proto = cjson.encode({
		type = "ON_CLICK_BLOCK",
		params = {
			cfg = cfg,
			pos = state:focus_obj().pos
		}
	})
	core.notify(proto)
end

----------------------------------------------------------
-- chunk
function M:make_chunk(pos_min, pos_max, solid)
	assert(pos_min.x <= pos_max.x)
	assert(pos_min.y <= pos_max.y)
	assert(pos_min.z <= pos_max.z)

	local chunk = core.make_chunk(pos_min, pos_max, solid)
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

function M:make_chunk_bytable(obj,solid)
	local chunk = core.make_chunk_bytable(obj.lx, obj.ly, obj.lz, solid, obj.model)
	assert(chunk)

	local prop = {lx = obj.lx,ly = obj.ly,lz = obj.lz}

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
-- frame widget
function M:new_widget_frame(pos_min, pos_max)
	assert(pos_min.x <= pos_max.x)
	assert(pos_min.y <= pos_max.y)
	assert(pos_min.z <= pos_max.z)

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
		return core.setCanDragFace_widget_frame(nId,bool)
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

function M:save_map(path)
	core.save_map(path)
end

function M:save_all_map()
	core.save_all_map()
end

function M:detect_collision(min,max)
	return core.detect_collision(min,max)
end

function M:open_menu(focus_class)
	local paramsjson = cjson.encode(
		{
			type = "OPEN_MENU",
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
			type = "EDITOR_OBJ_TYPE",
			params = {
				obj_type = obj_type
			}
		}
	)
	return core.notify(paramsjson)
end

function M:birth_position(pos)
	local paramsjson = cjson.encode({
		type = "BIRTH_POSITION",
		params = {
			pos = pos
		}
	})
	return core.notify(paramsjson)
end

function M:get_finish_region(min,max)
	local paramsjson = cjson.encode({
		type = "GET_FINISH_REGION",
		params = {
			min = min,
			max = max
		}
	})
	return core.notify(paramsjson)
end

function  M:down_region()
	local paramsjson = cjson.encode({
		type = "DOWN_REGION",
		params = {}
	})
	return core.notify(paramsjson)
end

function  M:up_region()
	local paramsjson = cjson.encode({
		type = "UP_REGION",
		params = {}
	})
	return core.notify(paramsjson)
end


function M:send_entity_id(id,name)
	local paramsjson = cjson.encode({
		type = "SEND_ENTITY_ID",
		params = {
			id = id,
			name = name
		}
	})
	return core.notify(paramsjson)
end

function M:recently_block(name)

	local paramsjson = cjson.encode({
		type = "RECENTLY_BLOCK",
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

function M:reload(path)
	if not path then
		local changed = setting:init()
		ResLoader:reload(changed)
		if #changed>0 then
			Block.Reload()
			Entity.Reload()
		end
    else
		local changed = setting:init()
		ResLoader:reload(changed)
		if string.find(path,"block") then
			local plugin, name = string.match(path, [[.*/(.*)/block/(.*)/setting.json]])
			local fullname = plugin .. "/" .. name
			Block.ReloadSingleParse(fullname, false)
			Blockman.instance:refreshBlocks()
		elseif string.find(path,"entity") then
			local plugin, name = string.match(path, [[.*/(.*)/entity/(.*)/setting.json]])
			local fullname = plugin .. "/" .. name
			Entity.ReloadSingle(fullname)
        end
	end
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

function M:update_entitys()
	for _, entity in ipairs(World.CurWorld:getAllEntity()) do
		entity:onCfgChanged()
	end
end

--打开进度条窗口
function M:open_progress_window(_type)
	local paramsjson = cjson.encode({
		type = "OPEN_PROGRESS_WINDOW",
		params = {
			_type = _type,
			params = {}
		}
	})
	return core.notify(paramsjson)
end


--分析选中方块进度
function M:update_req_count(fin,rmn,tot)
	local paramsjson = cjson.encode({
		type = "UPDATE_REQ_COUNT",
		params = {
			fin = fin,
			rmn = rmn,
			tot = tot
		}
	})
	return core.notify(paramsjson)
end

--分析完成，回调方块teble
function M:get_repote_ret(ret)
	local paramsjson = cjson.encode({
		type = "GET_REPOTE_RET",
		params = {
			ret = ret
		}
	})
	return core.notify(paramsjson)
end

function M:clear_wheel_value()
	local paramsjson = cjson.encode({
		type = "CLEAR_WHEEL_VALUE",
		params = {}
	})
	return core.notify(paramsjson);
end

--改变鼠标光标状态
function M:set_cursor(cursor)
	local paramsjson = cjson.encode({
		type = "set_cursor",
		params = {
			cursor = cursor
		}
	})
	return core.notify(paramsjson)
end

--移动显示时属性面板显示相关属性
function M:show_property_dock_move(pos)
	local paramsjson = cjson.encode({
		type = "SHOW_PROPERTY_DOCK_MOVE",
		params = {
			pos = pos
		}
	})
	return core.notify(paramsjson);
end

--缩放轴显示时属性面板显示相关属性
function M:show_property_dock_scale(min,max)
	local paramsjson = cjson.encode({
		type = "SHOW_PROPERTY_DOCK_SCALE",
		params = {
			min = min,
			max = max
		}
	})
	return core.notify(paramsjson)
end

--清空属性面板
function M:clear_property_dock()
	local paramsjson = cjson.encode({
			type = "CLEAN_PROPERTY_DOCK",
			params = {}
		})
	return core.notify(paramsjson);
end

--属性面板显示确认取消按钮
function M:show_property_TF_btn(b)
	local paramsjson = cjson.encode({
			type = "SHOW_PROPERTY_TF_BTN",
			params = {
				show = b
			}
		})
	return core.notify(paramsjson)
end

--显示是否确定添加方块组
function M:show_block_list_TF_btn()
	local paramsjson = cjson.encode({
		type = "SHOW_BLOCK_LIST_TF_BTN",
		params = {}
	})
	return core.notify(paramsjson)
end

function M:show_region_TF_btn()
	local paramsjson = cjson.encode({
		type = "SHOW_REGION_TF_BTN",
		params = {}
	})
	return core.notify(paramsjson)
end

--改变选择按钮状态
function M:set_selectbtn_mode(mode)
	local paramsjson = cjson.encode({
			type = "SET_SELECTBTN_STATE",
			params = {
				mode = mode
			}
		})
	return core.notify(paramsjson)
end

--改变工具栏移动按钮状态
function M:set_movebtn_mode(mode)
	local paramsjson = cjson.encode({
			type = "SET_MOVEBTN_STATE",
			params = {
				mode = mode
			}
		})
	return core.notify(paramsjson)
end

--改变工具栏替换按钮状态
function M:set_replacebtn_mode(mode)
	local paramsjson = cjson.encode({
			type = "SET_REPLACEBTN_STATE",
			params = {
				mode = mode
			}
		})
	return core.notify(paramsjson)
end
--改变工具栏填充按钮状态
function M:set_fillbtn_mode(mode)
	local paramsjson = cjson.encode({
			type = "SET_FILLBTN_STATE",
			params = {
				mode = mode
			}
		})
	return core.notify(paramsjson)
end
--改变工具栏删除按钮状态
function M:set_deletebtn_mode(mode)
	local paramsjson = cjson.encode({
			type = "SET_DELETEBTN_STATE",
			params = {
				mode = mode
			}
		})
	return core.notify(paramsjson)
end

--显示错误信息面板
function M:show_msg_to_qt(code)
	local paramsjson = cjson.encode({
			type = "SHOW_MSG_TO_QT",
			params = {
				code = code
			}
		})
	return core.notify(paramsjson)
end

--通知QT登录状态
function M:inform_QT_logging_status(bool,name,token)
	if name == nil then
		name = ""
	end
	local paramsjson = cjson.encode({
		type = "INFORM_QT_LOGGING_STATUS",
		params = {
			status = bool,
			nickName = name,
			access_token = token
		}
	})
	return core.notify(paramsjson)
end

local function find_in_dir(zp, srcDir, pat)
	for name in lfs.dir(srcDir) do
		if name ~= '.' and name ~= '..' then
			local fileattr = lfs.attributes(srcDir.."/"..name, "mode", true)
			--assert(type(fileattr) == "table")
			if fileattr == "directory" then
				find_in_dir(zp, srcDir.."/"..name, pat)
			else
				local dir_name = srcDir.."/"..name
				local path_name = string.gsub(dir_name, pat, "")
				core.zip_add_file(zp, path_name, dir_name)
			end
		end
	end
end

function M:zip(dir, out)
	local function pack_dir(Z, dir, entry)
		assert(lfs.attributes(dir, "mode", true) == "directory")

		for fn in lfs.dir(dir, true) do
			if fn ~= "." and fn ~= ".." then
				local path = Lib.combinePath(dir, fn)
				local path_entry = Lib.combinePath(entry, fn)
				local mode = lfs.attributes(path, "mode", true)
				if mode == "directory" then
					pack_dir(Z, path, path_entry)
				elseif mode == "file" then
					core.zip_add_file(Z, path_entry, Lib.combinePath(dir, fn))
				end
			end
		end
	end

	local Z = core.zip_open(out)
	pack_dir(Z, dir, "")
	core.zip_close(Z)
end

function M:forced_to_logout()
	local paramsjson = cjson.encode({
			type = "FORCED_TO_LOGOUT",
			params = {
			}
		})
	return core.notify(paramsjson)
end

function M:copy_dir(srcFilePath,tgtFilePath)
	local paramsjson = cjson.encode({
			type = "COPY_DIR",
			params = {
				srcFilePath,
				tgtFilePath
			}
		})
	return core.notify(paramsjson)
end

function M:sync_camera_pos(pos)
	local paramsjson = cjson.encode({
			type = "SYNC_CAMERA_POS",
			params = {
				pos = pos
			}
		})
	return core.notify(paramsjson)
end

function M:get_block_list_name(name_index)
	local m = Module:module("block_list")
	assert(m,"block_list")
	local default = "blockset"
	local new_name = ""
	for k,v in pairs(m:list()) do
		while true do
			if default..tostring(name_index) == lang:text( v:obj().name.value) then
				name_index = name_index + 1
				return M:get_block_list_name(name_index)
			end
			break
		end
	end
	return default..name_index
end

function M:on_focus_clear()
	local paramsjson = cjson.encode({
			type = "ON_FOCUS_CLEAR",
			params = {
			}
		})
	return core.notify(paramsjson)
end

function M:show_module_dock_item(module,id)
	local paramsjson = cjson.encode({
			type = "SHOW_MODULE_DOCK_ITEM",
			params = {
				module = module,
				id = id
			}
		})
	return core.notify(paramsjson)
end

function M:export_block_list(path,json)
	local paramsjson = cjson.encode({
			type = "EXPORT_BLOCK_LIST",
			params = {
				dir = path,
				item_json = json
			}
		})
	return core.notify(paramsjson)
end

function M:on_game_load_progress_changed(info,progress)
	local paramsjson = cjson.encode({
			type = "ONGLPC",
			params = {
				info = info,
				progress = progress
			}
		})
	return core.notify(paramsjson)
end

function M:Up_Is_Controller(b)
	core.Up_Is_Controller(b)
end

function M:Down_Is_Controller(b)
	core.Down_Is_Controller(b)
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

function M:request(json_req)
	local args = {}

	local json_rep = core.notify(json_req)
	local ret = cjson.decode(json_rep)
	table.insert(args, ret.ok)
	if ret.params then
		table.move(ret.params, 1, #ret.params, 2, args)
	end

	return table.unpack(args)
end

function M:get_login_server_type()
	local paramsjson = cjson.encode({
		type = "GET_LOGIN_SERVER_TYPE"
	})
	return core.notify(paramsjson)
end

return M