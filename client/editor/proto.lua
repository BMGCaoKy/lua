local cjson = require "cjson"
local setting = require "common.setting"
local state = require "editor.state"
local log = require "editor.log"
local cmd = require "editor.cmd"
local def = require "editor.def"
local readjson = require "editor.readjson"
local obj = require "editor.obj"
local engine = require "editor.engine"
local lfs = require "lfs"
local data_state = require "editor.dataState"
local utils = require "editor.utils"
local entity_obj = require "editor.entity_obj"
local item_obj = require "editor.item_obj"
local blockVector_obj = require "editor.blockVector_obj"
local file = require "editor.file"
local input = require 'editor.input'
local view = require "editor.view"
local map_setting = require "editor.map_setting"
local allSetting = require "editor.setting"
local shopSetting = require "editor.setting.shop_setting"
local globalSetting = require "editor.setting.global_setting"
local similarity = require "editor.edit_record.similarity"

local M = {}

local temporary_obj = nil

local Drag_Object = {
	Obj = nil
}

local processor = {
	init = function(params)

	end,

	set_palette = function(params)
        Lib.emitEvent(Event.EVENT_SWITCH_PALETTE)
		local type = assert(params.mode_type,params.mode_type)
		local idname
		local cell = params.cell
		local blockId = type == "Entity" and cell:data("moveBlockSize") and cell:data("item"):block_id()
		if type == "Block" then
			if params.name == "" then
				idname = 0
			else
				idname = assert(setting:name2id("block", params.name), params.name)
			end
			local _table = {id = idname}
			state:set_brush(_table, def.TBLOCK)
		elseif type == "Entity" then
			idname = assert(params.name,params.name)

            local  item = cell:data("item")
			local _table = {
				cfg = idname, 
				moveBlockSize = cell:data("moveBlockSize"), 
				blockId = blockId,
                dropobjects = item.dropobjects and item:dropobjects()
			}
			state:set_brush(_table,def.TENTITY)
            state:set_editmode(def.EMOVE)
		elseif type == "Item" then
			idname = assert(params.name, params.name)

            local  item = cell:data("item")
			local _table = {cfg = idname, dropobjects = item.dropobjects and item:dropobjects()}
			state:set_brush(_table, def.TITEM)
            state:set_editmode(def.EMOVE)
		end
		Lib.emitEvent(Event.EVENT_ESC_CMD)
	end,

    set_fillchunk = function(params)
  		local idname
		local isFill = params.bool
		if params.name == "/air" then
			idname = 0
		elseif params.name == "default" then

		else
			idname = assert(setting:name2id("block", params.name), params.name)
		end
		if state:focus_class() == def.TCHUNK then
			if params.name == "default" then
				if temporary_obj ~= nil then
					engine:del_widget_chunk(temporary_obj)
					temporary_obj = nil
				end
			else
				if isFill == "true" then
					if temporary_obj ~= nil then
						engine:del_widget_chunk(temporary_obj)
						temporary_obj = nil
					end
					cmd:fill_chunk(state:focus_obj().pos,state:focus_obj().data,idname)
				else
					local min = state:focus_obj().pos
					local max = {
						x = state:focus_obj().data.lx + min.x - 1,
						y = state:focus_obj().data.ly + min.y - 1,
						z = state:focus_obj().data.lz + min.z - 1
					}
					local chunkobj = engine:make_chunk_byid(min, max,true,idname)
					if temporary_obj ~= nil then
						engine:del_widget_chunk(temporary_obj)
						temporary_obj = nil
					end
					temporary_obj = engine:new_widget_chunk(min,chunkobj)
				end
				
			end
		elseif state:focus_class() == def.TFRAME then
			if params.name == "default" then
				if temporary_obj ~= nil then
					engine:del_widget_chunk(temporary_obj)
					temporary_obj = nil
				end
			else
				local min = state:focus_obj().min
				local max = state:focus_obj().max
				local chunkobj = engine:make_chunk_byid(min, max,true,idname)
				if temporary_obj ~= nil then
					engine:del_widget_chunk(temporary_obj)
					temporary_obj = nil
				end
				temporary_obj = engine:new_widget_chunk(min,chunkobj)
			end
		elseif state:focus_class() == def.TBLOCK then
			local pos = state:focus_obj().pos
			if isFill == "true" then
				if temporary_obj ~= nil then
					temporary_obj = nil
				end
				engine:set_block(pos,idname)
			else
				if params.name == "default" then
					if temporary_obj ~= nil then
						engine:set_block(pos,temporary_obj)
						temporary_obj = nil
					end
				else
					if temporary_obj == nil then
						temporary_obj = engine:get_block(pos)
					end
					engine:set_block(pos,idname)
				end
			end
        else
            local _table = {id = idname}
            state:set_brush(_table,def.TBLOCK)
		end  
    end,

	redo = function(params)
		cmd:redo()
	end,

	undo = function(params)
		cmd:undo()
	end,

	copy = function(params)
		local engine = require "editor.engine"
		local _table, class = state:focus_obj(), state:focus_class()
		if state:focus_class() == def.TBLOCK then
			state:set_clipboard({id = engine:get_block(state:focus_obj().pos)}, state:focus_class())
		elseif state:focus_class() == def.TCHUNK then
			state:set_clipboard(_table.data, class)
		elseif state:focus_class() == def.TENTITY then
			local cfg = entity_obj:getCfgById(_table.id)
			state:set_clipboard({cfg = cfg},def.TENTITY)
		end
		state:set_brush(state:clipboard_obj(), state:clipboard_class())
	end,

	cut = function(params)
		local engine = require "editor.engine"
		local _table, class = state:focus_obj(), state:focus_class()
		
		if not _table or not class then
			return
		end

		if class == def.TBLOCK then
			state:set_clipboard({id = engine:get_block(_table.pos)}, class)
			cmd:del_block(_table.pos)
		elseif class == def.TENTITY then
			local cfg = entity_obj:getCfgById(_table.id)
			state:set_clipboard({cfg = cfg},def.TENTITY)
			cmd:del_entity(_table.id)
		elseif class == def.TREGION then
			--cmd:del_region(obj)
		elseif class == def.TCHUNK then
			state:set_clipboard(_table.data, class)
			cmd:del_chunk(_table.pos,_table.data,false)
		elseif class == def.TFRAME then
			
		else
			assert(false, string.format("class %s is invalid", class))
		end

		state:set_brush(state:clipboard_obj(), state:clipboard_class())
	end,

	paste = function(params)
		state:set_brush(state:clipboard_obj(), state:clipboard_class())
	end,

	query = function(params)

	end,

	esc = function(params)
		state:set_brush(nil)
		EditorModule:emitEvent("emptyClick")
	end,

	frame = function(params)
		state:set_brush({1, 1, 1}, def.TFRAME)
	end,

	fill = function(params)
		
	end,

	editormode = function(params)
		local mode = assert(params.mode)
		if mode == "region" then
			local obj = Lib.boxOne()
			state:set_brush(obj,def.TREGION)
			engine:editor_obj_type("TREGION")
			state:set_editmode(def.ESCALE)
		elseif mode == "entity" then
			
			engine:editor_obj_type("TENTITY")
			state:set_editmode(def.EMOVE)
		end
	end,

	eraser = function (params)
		state:set_brush({id = 0},def.TBLOCK)
		--num��Ƥ�ߣ�1��3��5��
		local num = assert(params.size)
	end,


	delete = function(params)
		local _table, class = state:focus_obj(), state:focus_class()
		if class == def.TBLOCK then
			cmd:del_block(_table.pos)
		elseif class == def.TENTITY then
			cmd:del_entity(_table.id)
		elseif class == def.TITEM then
			cmd:del_item(_table.id)
		elseif class == def.TREGION then
			cmd:del_region(obj:get_region(_table.name).name)
		elseif class == def.TCHUNK then
			cmd:del_chunk(_table.pos,_table.data,true)
			--state:set_brush(state:brush_lastobj(),state:brush_lastclass());
		elseif class == def.TFRAME then
			local obj = Lib.boxOne()
			state:set_brush(obj,def.TFRAME);
		else
			assert(false, string.format("class %s is invalid", class))
		end
	end,

	del_region = function(params)
		local name = params.name
		cmd:del_region(name)
	end,

	--���浥ѡ�Ϳ�ѡ
	focusmode = function(params)
		local m = assert(params.mode)
		if m == "common" then
			state:set_focus(nil)
			state:set_brush(nil)
			engine:editor_obj_type("common")
			state:set_editmode(def.EMOVE)
		elseif m == "frame" then
			local obj = Lib.boxOne()
			state:set_brush(obj,def.TFRAME);
			--engine:editor_obj_type("TFRAME")
			state:set_editmode(def.ESCALE)
		elseif m == "frame_p" then
			--�����ѡ
			--state:set_focus(nil)
			--state:set_brush(nil)
			local obj = Lib.boxOne()
			data_state.frame_pos_count = 0
			state:set_editmode(def.ECOMMON)
			state:set_brush(obj, def.TFRAME_POS, true)
			data_state.is_frame_pos = false
		end
	end,

	--�������ƶ�������
	coordinateaxis = function(params)
		local m = assert(params.mode)
		if m == "move" then
			state:set_editmode(def.EMOVE)
		elseif m == "scale" then
			state:set_editmode(def.ESCALE)
		end
	end,

	fillchunk = function(params)
		local id = assert(setting:name2id("block", params.name), params.name)
		if state:focus_class() == def.TCHUNK then
			cmd:fill_chunk(state:focus_obj().pos,state:focus_obj().data,id)
		end
	end,

	get_regionCfg_by_name = function(params)
		local _name = assert(params.name)
		return obj:get_cfg_by_name(_name)
	end,

	get_present_region = function(params)
		return obj:get_present_region()
	end,

	get_current_map_entities = function(params)
		return entity_obj:getCurMapEntities()
	end,

	set_region_name = function(params)
		local id = assert(params.id)
		local name = assert(params.name)

		obj:set_region_name(id,name)
	end,

	set_region = function(params)
		local id = assert(params.id)
		local jsonobj = assert(params.obj)

		jsonobj.box.min.x = math.min(jsonobj.box.max.x, jsonobj.box.min.x)
		jsonobj.box.max.x = math.max(jsonobj.box.max.x, jsonobj.box.min.x)
		jsonobj.box.min.y = math.min(jsonobj.box.max.y, jsonobj.box.min.y)
		jsonobj.box.max.y = math.max(jsonobj.box.max.y, jsonobj.box.min.y)
		jsonobj.box.min.z = math.min(jsonobj.box.max.z, jsonobj.box.min.z)
		jsonobj.box.max.z = math.max(jsonobj.box.max.z, jsonobj.box.min.z)
		
		cmd:move_region(id,jsonobj,false)
	end,

    save_MpMap = function(params)
        Lib.emitEvent(Event.EVENT_BEFORE_SAVE_MAP_SETTING)
        globalSetting:saveKey("isLatestModification", true, true)
        local path = assert(params.path)
        local pos_obj = {
			pos = Player.CurPlayer:getPosition(),
			yaw = Player.CurPlayer:getRotationYaw(),
			pitch = Player.CurPlayer:getRotationPitch()
		}
		local t1 = Lib.getTime()

		engine:save_map()
		local saveMapTime = Lib.getTime() - t1
		print(saveMapTime)
		log(string.format("save_map time:%f", saveMapTime))

		map_setting:save_pos(data_state.now_map_name,pos_obj)
		local savePosSettingTime = Lib.getTime() - t1 - saveMapTime
		log(string.format("map_setting:save_pos time:%f", savePosSettingTime))

		obj:save(path)
		local saveObjTime = Lib.getTime() - t1 - saveMapTime - savePosSettingTime
		log(string.format("obj:save(path) time:%f", saveObjTime))
 
		entity_obj:save(path)
		local saveEntityObjTime = Lib.getTime() - t1 - saveMapTime - savePosSettingTime - saveObjTime
		log(string.format("entity_obj:save(path) time:%f", saveEntityObjTime))

		item_obj:save(path)
		local saveItemObjTime = Lib.getTime() - t1 - saveMapTime -
		savePosSettingTime - saveObjTime - saveEntityObjTime
		log(string.format("item_obj:save(path) time:%f", saveItemObjTime))

		blockVector_obj:save(path)
		map_setting:save(path)
		local saveMapSettingTime = Lib.getTime() - t1 - saveMapTime -
		savePosSettingTime - saveObjTime - saveEntityObjTime - saveItemObjTime
		log(string.format("map_setting:save(path) time:%f", saveMapSettingTime))

		engine:clear_mem_file()
		engine:set_bModify(false)
		Clientsetting.saveCustomHandBag()
		local saveCustomHandBagTime = Lib.getTime() - t1 - saveMapTime -
		savePosSettingTime - saveObjTime - saveEntityObjTime - saveItemObjTime - saveMapSettingTime
		log(string.format("Clientsetting.saveCustomHandBag() time:%f", saveCustomHandBagTime))

		allSetting:saveAll()
		local saveAllSettingTime = Lib.getTime() - t1 - saveMapTime -
		savePosSettingTime - saveObjTime - saveEntityObjTime - saveItemObjTime - saveMapSettingTime
		- saveCustomHandBagTime
		log(string.format("allSetting:saveAll() time:%f", saveAllSettingTime))

		shopSetting:save()
		local saveShopSettingTime = Lib.getTime() - t1 - saveMapTime -
		savePosSettingTime - saveObjTime - saveEntityObjTime - saveItemObjTime - saveMapSettingTime
		- saveCustomHandBagTime - saveAllSettingTime
		log(string.format("shopSetting:save() time:%f", saveShopSettingTime))

		local touchFile = Root.Instance():getGamePath() .. "version.json"
		local ok, msg = lfs.touch(touchFile)
		assert(ok, msg)

		similarity:saveAll()
	end,

	save_map = function(params)
		local path = assert(params.path)
		if path == "" then
			engine:save_map()
		else
			local map_path = string.format("%s%s/", path, "map/map001")
			lfs.mkdir(string.format("%s%s",path,"map"))
			lfs.mkdir(map_path)
			engine:save_map(map_path)
		end
		
	end,

	--����json
	save_injson = function(params)
		local path = assert(params.path)
		--lfs.mkdir()
		local pos_obj = {
			pos = Player.CurPlayer:getPosition(),
			yaw = Player.CurPlayer:getRotationYaw(),
			pitch = Player.CurPlayer:getRotationPitch()
		}
		map_setting:save_pos(data_state.now_map_name,pos_obj)
		obj:save(path)
		entity_obj:save(path)
		item_obj:save(path)
		blockVector_obj:save(path)
		map_setting:save(path)
		engine:clear_mem_file()
		--engine:reload()
	end,

	quit_run_game = function(params)
		local porto = assert(params.name)
		if porto == "quit_run_game" then
			--�˳�������Ϸ
			--print(porto);
		end
	end,

	run_game = function(params)
		local path = assert(params.path)
		--���в�����Ϸ
		if string.byte(path, #path) == string.byte("/") then
			path = string.sub(path, 1, #path - 1)
		end

		local root, game = string.match(path, "(.*)/(.*)")
        root = "./" .. root .. "/"

		local run_server = ""
		local run_client = ""
		if DEBUG then
			run_server = string.format("start ./GameServer_d.exe %s %s", root, game)
			run_client = string.format("start ./WinShell_d.exe %s %s %s", "editor", root, game)
		else
			run_server = string.format("start ./GameServer.exe %s %s", root, game)
			run_client = string.format("start ./WinShell.exe %s %s %s", "editor", root, game)
		end

		os.execute(run_server)

		os.execute(run_client)
		
	end,

	quit_run_game = function(params)
		if DEBUG then
			os.execute("taskkill /f /im GameServer_d.exe")
			os.execute("taskkill /f /im WinShell_d.exe")
		else
			os.execute("taskkill /f /im GameServer.exe")
			os.execute("taskkill /f /im WinShell.exe")
		end
		
	end,

	getjson = function(params)
		local jsonname = assert(params.jsonname)
		local text = readjson:getjson(jsonname)
		--print(text)

		return text
	end,

	set_focustoregion = function(params)
		local id = assert(params.id)
		local obj = {
			name = id
		}
		state:set_focus(obj,def.TREGION)
	end,

	reload = function(params)

	end,

	frame_to_chunk = function(params)
		if state:focus_class() == def.TFRAME then
			local focusobj = state:focus_obj()
			local chunkobj = engine:make_chunk(focusobj.min, focusobj.max, nil, true)
			EditorModule:getViewControl():setChunkSize(focusobj.min, focusobj.max)
			local obj = { pos = focusobj.min, data = chunkobj}
			state:set_focus(obj, def.TCHUNK)
			state:set_editmode(def.EMOVE)
			engine:editor_obj_type("TCHUNK")
		end
	end,

	set_scene_position = function(params)
		state:set_focus(nil)
		state:set_brush(nil)
		data_state.isbrith = true
	end,

	finish_region = function(params)
		local min = state:focus_obj().min
		local max = state:focus_obj().max
		engine:get_finish_region(min,max)
	end,

	select_region = function(params)
		data_state.is_select_region = params.is_select
	end,

	get_entity_from_scene = function(params)
		state:set_focus(nil)
		state:set_brush(nil)
		data_state.is_send_entity = true
	end,

	switchstate = function(params)
		data_state.isCanRid = params.bool
		Lib.emitEvent(Event.EVENT_EDITOR_STATE_CHANGE_FOCUS)
	end,

	find_focusobj = function(params)
		if state:focus_class() == def.TBLOCK then
			utils.focus_target(state:focus_obj().pos,10)
		elseif state:focus_class() == def.TFRAME then
			local min = state:focus_obj().min
			local max = state:focus_obj().max
			local pos = {
				x = (max.x + 1 - min.x)/2 + min.x,
				y = (max.y + 1 - min.y)/2 + min.y,
				z = (max.z + 1 - min.z)/2 + min.z
			}
			utils.focus_target(pos,10)
		elseif state:focus_class() == def.TCHUNK then
			local min = state:focus_obj().pos
			local pos = {
				x = min.x + state:focus_obj().data.lx / 2,
				y = min.y + state:focus_obj().data.ly / 2,
				z = min.z + state:focus_obj().data.lz / 2
			}

			local dis = 
			utils.focus_target(pos,dis)
		elseif state:focus_class() == def.TREGION then
			local min = obj:get_region(state:focus_obj().name).box.min
			local max = obj:get_region(state:focus_obj().name).box.max
			local pos = {
				x = (max.x - min.x)/2 + min.x,
				y = (max.y - min.y)/2 + min.y,
				z = (max.z - min.z)/2 + min.z
			}
			utils.focus_target(pos,10)
		elseif state:focus_class() == def.TENTITY then
			local pos = entity_obj:getPosById(state:focus_obj().id)
			utils.focus_target(pos,10)
		end
	end,

	req_count = function(params)
		--engine:open_progress_window("req_count")
		if state:focus_class() ~= def.TFRAME and state:focus_class() ~= def.TCHUNK then
			return
		end
		local ret = {}
		local min = {}
		local max = {}
		if state:focus_class() == def.TFRAME then
			min = state:focus_obj().min
			max = state:focus_obj().max
		elseif state:focus_class() == def.TCHUNK then
			min = state:focus_obj().pos
			max = {
				x = min.x + state:focus_obj().data.lx - 1,
				y = min.y + state:focus_obj().data.ly - 1,
				z = min.z + state:focus_obj().data.lz - 1
			}
		end
		local iter = engine:iterate_block(
			--params.pos_min,
			--params.pos_max,
			min,
			max,
			function(pos)
				local name = setting:id2name("block", engine:get_block(pos))
				--assert(name)
				if name == nil then
					name = tostring(engine:get_block(pos))
				end
				ret[name] = ret[name] or 0
				ret[name] = ret[name] + 1
			end,
			def.BLOCK_ITERATE_STEP
		)
		World.Timer(1, function()
			local fin, rmn, tot = iter()

--			-- todo notify progress
			--print("count progress", fin, rmn, tot)
			--engine:update_req_count(fin, rmn, tot)
			if not fin then
				return true
			end

--			-- todo repote ret
            Lib.emitEvent(Event.EVENT_EDIT_REPLACE_COUNT, ret)
			--engine:get_repote_ret(ret)
		end)
	end,

	req_replace = function(params)
		local min = {}
		local max = {}
		if state:focus_class() == def.TFRAME then
			min = state:focus_obj().min
			max = state:focus_obj().max
		elseif state:focus_class() == def.TCHUNK then
			min = state:focus_obj().pos
			max = {
				x = min.x + state:focus_obj().data.lx - 1,
				y = min.y + state:focus_obj().data.ly - 1,
				z = min.z + state:focus_obj().data.lz - 1
			}
		end
		cmd:replace(min, max, params.rule)
	end,

    req_replace2 = function(params)
		local min = {}
		local max = {}
		if state:focus_class() == def.TFRAME then
			min = state:focus_obj().min
			max = state:focus_obj().max
		elseif state:focus_class() == def.TCHUNK then
			min = state:focus_obj().pos
			max = {
				x = min.x + state:focus_obj().data.lx - 1,
				y = min.y + state:focus_obj().data.ly - 1,
				z = min.z + state:focus_obj().data.lz - 1
			}
		end
		cmd:replace_2(min, max, params.rule)
	end,

	entity_item_click = function(params)
		local num = assert(params.num,params.num)
		local obj = {
			id = num
		}
		state:set_focus(obj,def.TENTITY,false)
	end,

	get_allname_by_cfg = function(params)
		local cfg = assert(params.cfg,params.cfg)
		return obj:get_allname_bycfg(cfg)
	end,

	save_jsonobj_entity = function(params)
		local id = assert(params.id,params.id)
		local obj = assert(params.obj,params.obj)
		local pos_s = entity_obj:getPosById(id)
		local yaw_s = entity_obj:getYawById(id)
		local pitch_s = entity_obj:getPitchById(id)
		local pos_d = obj.pos
		local yaw_d = obj.ry
		local pitch_d = obj.pitch
		local old_data = {
			pos = pos_s,
			ry = yaw_s,
			pitch = pitch_s
		}
		local new_data = {
			pos = pos_d,
			ry = yaw_d,
			pitch = pitch_d
		}
		cmd:move_entity(id,old_data,new_data,false)
	end,

	modify = function(params)
		local path = assert(params.path,params.path)
		local content = assert(params.content,params.content)
		engine:set_mem_file("./"..path, content)
		engine:reload(path)
	end,

	--����λ�úͷ��������ɷ���
	build_block = function(params)
		local _id = assert(params._id,params._id)
		local pos = nil
		if state:focus_class() == def.TBLOCK then
			pos = state:focus_obj().pos
			local idname = assert(setting:name2id("block", _id), _id)
			cmd:set_block(pos,idname,false)
		elseif state:focus_class() == def.TENTITY then
			pos = entity_obj:getPosById(state:focus_obj().id)
			cmd:del_entity(state:focus_obj().id)
			cmd:set_entity(pos,_id)
		end
	end,

	write_csv = function(params)
		local path = assert(params.path)
		local json = assert(params.json)
		return file:write(path,json)
	end,

	read_csv = function(params)
		local path = assert(params.path)
		return file:read(path)
	end,

	save_to_component = function(params)
		local brush_obj = state:focus_obj()
		local _json_obj = {
			min = brush_obj.min,
			max = brush_obj.max,
			model = {}
		}
		local lx = brush_obj.max.x - brush_obj.min.x + 1
		local ly = brush_obj.max.y - brush_obj.min.y + 1
		local lz = brush_obj.max.z - brush_obj.min.z + 1
		for x=1,lx do
			for y = 1,ly do
				for z = 1,lz do
					local pos = {
						x = brush_obj.min.x + x - 1,
						y = brush_obj.min.y + y - 1,
						z = brush_obj.min.z + z - 1
					}
					local id = engine:get_block(pos)
					table.insert(_json_obj.model,id)
				end
			end
		end
		return _json_obj
	end,

	showcomponentitem = function(params)
		local obj = assert(params.obj,params.obj)
		local chunkobj = engine:make_chunk_bytable(obj.min, obj.max, true, obj.model)
		state:set_brush(chunkobj,def.TCHUNK)
		state:set_editmode(def.EMOVE)
	end,

	change_focus_scale = function(params)
		local min = assert(params.min,params.min)
		local max = assert(params.max,params.max)
		if state:focus_obj() ~= nil and state:get_editmode() == def.ESCALE then
			if state:focus_class() == def.TFRAME then
				local _max = {
					x = max.x - 1,
					y = max.y - 1,
					z = max.z - 1
				}
				engine:scaler_widget_set_pos(min,max)
				state:focus_obj().min = min
				state:focus_obj().max = _max
			end
		end
	end,

	--��������ƶ��ı�
	create_focus_moveobj = function(params)
		local begin_pos = assert(params.begin_pos,params.begin_pos)
		local end_pos = assert(params.end_pos,params.end_pos)
		if state:focus_obj() ~= nil and state:get_editmode() == def.EMOVE then
			data_state.is_GIZMO_DRAG_MOVE = true
			local pos = view:get_gizmo_pos(begin_pos)
			data_state.is_property_change = true
			Lib.emitEvent(Event.EVENT_EDITOR_GIZMO_DRAG_START,pos,end_pos)
			Lib.emitEvent(Event.EVENT_EDITOR_GIZMO_DRAG_MOVE,pos,end_pos)
			Lib.emitEvent(Event.EVENT_EDITOR_GIZMO_DRAG_END,pos,end_pos)
			engine:gizmo_widget_set_pos(Lib.v3add(pos,end_pos))
			data_state.is_GIZMO_DRAG_MOVE = false
		end
	end,

	change_map = function(params)
		local packet = assert(params,params)
		local old_obj = packet.old_obj
		local new_obj = packet.new_obj
		map_setting:save_pos(data_state.now_map_name,old_obj)
		data_state.now_map_name = packet.name
		World.CurWorld:loadCurMap(packet, new_obj.pos)
		map_setting:load()
		map_setting:set_pos()
		obj:load()
		item_obj:load()
		entity_obj:load()
		state:set_focus(nil)
		state:set_brush(nil)
		EditorModule:emitEvent("changeMap")
	end,

	delete_map = function(params)
		local map_name = assert(params.map_name,params.map_name)
		obj:delete_map(map_name)
		blockVector_obj:delete_map(map_name)
		entity_obj:delete_map(map_name)
        item_obj:delete_map(map_name)
		map_setting:delete_map(map_name)
		globalSetting:deleteMap(map_name)

		local map = World.CurWorld:getOrCreateStaticMap(map_name)
		if map then
			map:close()
		end
	end,

	rename_map = function(params)
		local _oldname = assert(params._oldname,params._oldname)
		local _newname = assert(params._newname,params._newname)
		obj:rename_map(_oldname,_newname)
		entity_obj:rename_map(_oldname,_newname)
		local issame = false
		for k, v in pairs(World.staticList) do
			if k == _oldname then
				issame = true
				break
			end
		end
		if issame == true then
			World.staticList[_oldname]:rename(_newname)
		end
	end,

	property_true_btn = function(params)
		view:gizmo_darg_end_true()
	end,

	property_false_btn = function(params)
		view:gizmo_darg_end_false()
	end,

	get_player_pos = function(params)
		local obj = {
			pos = Player.CurPlayer:getPosition(),
			yaw = Player.CurPlayer:getRotationYaw(),
			pitch = Player.CurPlayer:getRotationPitch()
		}
		return obj
	end,

	get_nowmap_name = function(params)
		return data_state.now_map_name
	end,
}

function handle_editor_command(cmd)
--	log(string.format("receive command:%s", cmd))
	local ret0, ret1 = pcall(cjson.decode, cmd)
	assert(ret0, ret1)

	local func = processor[ret1.type]
	assert(func, string.format("invalid command %s", ret1.type))

	ret0, ret1 = xpcall(func, debug.traceback, ret1.params)
	assert(ret0, ret1)

	if not ret1 then
		ret1 = {}
	end

	if type(ret1) == "table" then
		local r = cjson.encode(ret1 or {})
		return r
	elseif type(ret1) == "string" then
		return ret1
	else
		assert("invalid type", type(ret1))
	end
end

function handle_mp_editor_command(cmd, params)

	local func = processor[cmd]
	assert(func, string.format("invalid command %s", cmd))
	
	local ret0, ret1 = xpcall(func, debug.traceback, params)
	assert(ret0, ret1)
	
	if not ret1 then
		ret1 = {}
	end

	if cmd == "esc" then
		Lib.emitEvent(Event.EVENT_ESC_CMD)
	end

	if params and params.dontEncode then
		return ret1
	end

	if type(ret1) == "table" then
		local r = cjson.encode(ret1 or {})
		return r
	elseif type(ret1) == "string" then
		return ret1
	else
		assert("invalid type", type(ret1))
	end
end