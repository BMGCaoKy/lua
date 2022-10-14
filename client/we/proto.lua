local cjson = require "cjson"
local setting = require "common.setting"
local state = require "we.state"
local log = require "we.log"
local cmd = require "we.cmd"
local def = require "we.def"
local engine = require "we.engine"
local lfs = require "lfs"
local data_state = require "we.data_state"
local utils = require "we.utils"
local file = require "we.file"
local input = require "we.input"
local view = require "we.view"
local networdaccess = require "we.network_access_mgr"
local lang = require "we.gamedata.lang"
local Module = require "we.gamedata.module.module"
local mapping = require "we.gamedata.module.mapping"
local core = require "editor.core"
local Map = require "we.map"
local user_data = require "we.user_data"
local Meta = require "we.gamedata.meta.meta"
local pfun = require "we.public_fun"
local hotfix = require "we.hotfix"
local Cmd = require "we.view.scene.cmd.cmd"
local Operator = require "we.view.scene.operator.operator"
local Receptor = require "we.view.scene.receptor.receptor"
local Placer = require "we.view.scene.placer.placer"
local Camera = require "we.view.scene.camera"
local Recorder = require "we.gamedata.recorder"
local Platform = require "common.platform"

local M = {}

local temporary_obj = nil

local Drag_Object = {
	Obj = nil
}

local processor_common = {
	init = function(params)

	end,

	set_palette = function(name,mode_type)
		local type = assert(mode_type,mode_type)
		local idname
		if type == "block" then
			if name == "" then
				idname = 0
			else
				idname = assert(setting:name2id("block", name), name)
				--idname = 1
			end
			local _table = {id = idname}
			state:set_brush(_table, def.TBLOCK)
		elseif type == "entity" then
			idname = assert(name,name)
			local _table = {cfg = idname, yaw = 0}
			state:set_brush(_table,def.TENTITY)
		end
		state:set_editmode(def.EMOVE)
		--engine:set_movebtn_mode("checked")
		engine:set_selectbtn_mode("checked");
	end,

    --Ìî³ächunk
    set_fillchunk = function(block_name)
  		local idname = assert(setting:name2id("block", block_name), "block_name") -- if block is air, id is 0!

		local op = Operator:operator("FILL")
		if op:check(Receptor:binding()) then
			op:exec(Receptor:binding(), idname)
		end
    end,

	redo = function()
		cmd:redo()
	end,

	undo = function()
		cmd:undo()
	end,

	copy = function(params)
		local op = Operator:operator("COPY")
		if op:check(Receptor:binding()) then
			op:exec(Receptor:binding())
		end
	end,

	cut = function()
		Recorder:start()
		local op = Operator:operator("CUT")
		if op:check(Receptor:binding()) then
			op:exec(Receptor:binding())
		end
		Recorder:stop()
	end,

	paste = function(params)
		local placer = Placer:bind("instance")
		if placer.check_select then
			 placer:check_select()
		end
	end,

	query = function(params)

	end,

	esc = function()
		state:set_brush(nil)
	end,

	frame = function(params)
		state:set_brush({1, 1, 1}, def.TFRAME)
	end,

	fill = function(params)
		
	end,

	editormode = function(mode)
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

	eraser = function ()
		--state:set_brush({id = 0},def.TBLOCK)
		
		engine:set_movebtn_mode("disabled")
	end,


	delete = function()
		local op = Operator:operator("DELETE")
		if op:check(Receptor:binding()) then
			op:exec(Receptor:binding())
		end
	end,

	del_region = function(params)
		local name = params.name
		cmd:del_region(name)
	end,

	--常规单选和框选
	focusmode = function(mode)
		if mode == "common" then
			state:set_focus(nil)
			state:set_brush(nil)
			engine:editor_obj_type("common")
			state:set_editmode(def.EMOVE)
			engine:set_movebtn_mode("checked")
		elseif mode == "frame" then
			local obj = Lib.boxOne()
			state:set_brush(obj,def.TFRAME);
			--engine:editor_obj_type("TFRAME")
			state:set_editmode(def.ESCALE)
			engine:set_movebtn_mode("disabled")
		elseif mode == "frame_p" then
			--两点框选
			state:set_focus(nil)
			state:set_brush(nil)
			local obj = Lib.boxOne()
			data_state.frame_pos_count = 0
			state:set_editmode(def.ECOMMON)
			engine:set_movebtn_mode("disabled")
			state:set_brush(obj,def.TFRAME_POS)
			data_state.is_frame_pos = false
		end
	end,

	--坐标轴移动和缩放
	coordinateaxis = function(mode)
		if mode == "move" then
			state:set_editmode(def.EMOVE)
		elseif mode == "scale" then
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
		
		cmd:move_region(id,jsonobj)
	end,

	--保存json
	save_injson = function(params)
		local path = assert(params.path)
		--lfs.mkdir()
		obj:save(path)
		entity_obj:save(path)
		map_setting:save(path)
		engine:clear_mem_file()
		--engine:reload()
	end,

	quit_run_game = function(params)
		local porto = assert(params.name)
		if porto == "quit_run_game" then
			--退出测试游戏
			--print(porto);
		end
	end,

	request_test_game = function(root, game, close, clientCount)--目前启动逻辑是已经放在c++
		if close then
			if DEBUG then
				os.execute("taskkill /f /im GameServer_d.exe")
				os.execute("taskkill /f /im WinShell_d.exe")
			else
				os.execute("taskkill /f /im GameServer.exe")
				os.execute("taskkill /f /im WinShell.exe")
			end
		else
			os.remove("./conf/client_debug_run.txt"); --TODO luaidedebug 用文件来判断客户端调试只能启动一个 有点隐晦
	  		if ( Root.platform() == Platform.MAC_OSX ) then
				os.remove("client_debug_run.txt")
			end
			local client, server
			if DEBUG then
				client = "./WinShell_d.exe"
				server = "./GameServer_d.exe"
			else
				client = "./WinShell.exe"
				server = "./GameServer.exe"
			end

			local run_client = string.format(
					"set IS_WORLD_EDITOR=true && start %s --editor editor --root %s --game %s",
					client, root, game)

			local run_server = string.format(
					"set IS_WORLD_EDITOR=true && start %s %s %s", server, root, game)

			os.execute(run_server)
			os.execute("ping -n 7 127.0.0.1")
			for i = 1, clientCount do
				os.execute(run_client)
			end
		end

	::EXIT::
		return { ok = true}
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

	region_item_click = function(num)
		local obj = {
			id = num
		}
		state:set_focus(obj,def.TREGION)
		state:set_editmode(def.ESCALE)
	end,

	reload = function(params)

	end,

	frame_to_chunk = function(params)
		if state:focus_class() == def.TFRAME then
			local focusobj = state:focus_obj()
			local chunkobj = engine:make_chunk(focusobj.min, focusobj.max)
			local obj = { pos = focusobj.min, data = chunkobj }
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

	finish_region = function()
		
		local min = state:focus_obj().min
		local max = state:focus_obj().max
		local obj = {
			min = min,
			max = max
		}
		return obj
	end,

	select_region = function(is_select)
		data_state.is_select_region = is_select
	end,

	--方块组
	request_send_block_list = function(is_block_list)
		data_state.is_block_list = is_block_list
	end,

	request_send_region = function(is_region)
		data_state.is_region = is_region
	end,

	request_add_block_list = function()
		local lx, ly, lz
		local min
		local focus_obj = state:focus_obj()
		if state:focus_class() == def.TFRAME then
			lx = focus_obj.max.x - focus_obj.min.x + 1
			ly = focus_obj.max.y - focus_obj.min.y + 1
			lz = focus_obj.max.z - focus_obj.min.z + 1
			min = focus_obj.min
		elseif state:focus_class() == def.TCHUNK then
			lx = focus_obj.data.lx
			ly = focus_obj.data.ly
			lz = focus_obj.data.lz
			min = focus_obj.pos
		end
		local _json_obj = {
			lx = lx,
			ly = ly,
			lz = lz,
			model = {}
		}
		for x=1,lx do
			for y = 1,ly do
				for z = 1,lz do
					local pos = {
						x = min.x + x - 1,
						y = min.y + y - 1,
						z = min.z + z - 1
					}
					local id = engine:get_block(pos)
					table.insert(_json_obj.model,id)
				end
			end
		end
		local m = Module:module("block_list")
		assert(m,"block_list")

		--名字
		local new_name = engine:get_block_list_name(1)

		local uuid = GenUuid()
		lang:set_text(uuid,new_name)
		local obj = {
			name = {
				value = uuid
			},
			model = _json_obj.model,
			dis = {
				x = _json_obj.lx,
				y = _json_obj.ly,
				z = _json_obj.lz
			}
		}
		local item = m:new_item(nil,obj)
		engine:show_module_dock_item("block_list",item._id)
	end,

	request_add_region = function()
		local focus_obj = state:focus_obj()
		assert(state:focus_class() == def.TFRAME)

		local Req = require "we.proto.request_region"
		local ok, cfg = Req.request_new_region()
		if ok then
			cmd:add_region(focus_obj.min, focus_obj.max, cfg)
		end
	end,

	get_entity_from_scene = function(params)
		state:set_focus(nil)
		state:set_brush(nil)
		data_state.is_send_entity = true
	end,

	switchstate = function(params)
		data_state.is_can_rid = params.bool
		Lib.emitEvent(Event.EVENT_EDITOR_STATE_CHANGE_FOCUS)
	end,

	focus_pos =function( xx,yy,zz )
		local pos = {
			x = xx,
			y =yy,
			z =zz
		}
		utils.focus_target(pos, 10)
	end,

	focus_aabb =function( min_x,min_y,min_z , max_x,max_y,max_z)
		local aabb = {
			min={x=min_x,y = min_y,z=min_z},
			max={x=max_x,y = max_y,z=max_z},
		}
		Camera:focus(aabb)
	end,

	find_focusobj = function(params)
		local receptor = Receptor:binding()
		if not receptor then
			return
		end

		local bound = receptor:bound()
		if not bound then
			return
		end

		Camera:focus(bound)
	end,

	req_count = function()
		engine:open_progress_window("req_count")
		if Receptor:binding():type() ~= "chunk" then
			return
		end
		local ret = {}
		local min = {}
		local max = {}
		if Receptor:binding():type() == "chunk" then
			local chunk = Receptor:binding():chunk()
			min = chunk:original()
			local size = chunk:size()
			max = {
				x = min.x + size.x - 1,
				y = min.y + size.y - 1,
				z = min.z + size.z - 1,
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
			
			-- todo notify progress
			print("count progress", fin, rmn, tot)
			engine:update_req_count(fin, rmn, tot)
			if not fin then
				return true
			end

			-- todo repote ret
			engine:get_repote_ret(ret)
		end)
	end,

	req_replace = function(obj)
		local op = Operator:operator("REPLACE")
		if op:check(Receptor:binding()) then
			op:exec(Receptor:binding(), obj)
		end
	end,

	entity_item_click = function(num)
		local obj = {
			id = num
		}
		state:set_editmode(def.EMOVE)
		state:set_focus(obj,def.TENTITY,false)
	end,

	get_allname_by_cfg = function(params)
		local cfg = assert(params.cfg,params.cfg)
		return obj:get_allname_bycfg(cfg)
	end,

	modify = function(params)
		local path = assert(params.path,params.path)
		local content = assert(params.content,params.content)
		engine:set_mem_file("./"..path, content)
		engine:reload(path)
	end,

	--根据位置和方块名生成方块
	build_block = function(params)
		local _id = assert(params._id,params._id)
		local pos = nil
		if state:focus_class() == def.TBLOCK then
			pos = state:focus_obj().pos
			local idname = assert(setting:name2id("block", _id), _id)
			cmd:set_block(pos,idname,false)
		elseif state:focus_class() == def.TENTITY then
			pos = Map:curr_map():get_pos_byid(state:focus_obj().id)
			local yaw = Map:curr_map():get_yaw_byid(state:focus_obj().id)
			cmd:del_entity(state:focus_obj().id)
			cmd:set_entity(pos,_id,yaw)
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

	showcomponentitem = function(id)
		local m = Module:module("block_list")
		assert(m,"block_list")

		local item = m:item(id)

		local obj = item:obj()

		local model = {}
		for i = 1,#(obj.model) do
			--local _id = setting:name2id("block",obj.mapping[obj.model[i]])
			table.insert(model,obj.model[i])
		end

		local obj2 = {
			lx = obj.dis.x,
			ly = obj.dis.y,
			lz = obj.dis.z,
			model = model
		}

		local chunkobj = engine:make_chunk_bytable(obj2, true)
		state:set_brush(chunkobj,def.TCHUNK)
		state:set_editmode(def.EMOVE)
	end,

	request_scene_height = function(mode,height)
		if mode == "Set" then
			user_data:set_value("viewport_height",height)
			user_data:save()
		end
		return {value = user_data:get_value("viewport_height")}
	end,
	request_scene_width = function(mode,width)
		if mode == "Set" then
			user_data:set_value("viewport_width",width)
			user_data:save()
		end
		return {value = user_data:get_value("viewport_width")}
	end,

	request_move_speed = function(mode,movespeed)
		if mode == "Set" then
			user_data:set_value("camera_move_speed",movespeed / 10)
			user_data:save()
		end
		return {value = user_data:get_value("camera_move_speed") * 10}
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

	--属性面板移动改变
	create_focus_moveobj = function(params)
		local begin_pos = assert(params.begin_pos,params.begin_pos)
		local end_pos = assert(params.end_pos,params.end_pos)
		if state:focus_obj() ~= nil and state:get_editmode() == def.EMOVE then
			data_state.is_gizmo_drag_move = true
			local pos = view:get_gizmo_pos(begin_pos)
			data_state.is_property_change = true
			Lib.emitEvent(Event.EVENT_EDITOR_GIZMO_DRAG_START,pos,end_pos)
			Lib.emitEvent(Event.EVENT_EDITOR_GIZMO_DRAG_MOVE,pos,end_pos)
			Lib.emitEvent(Event.EVENT_EDITOR_GIZMO_DRAG_END,pos,end_pos)
			engine:gizmo_widget_set_pos(Lib.v3add(pos,end_pos))
			data_state.is_gizmo_drag_move = false
		end
	end,

	change_map = function(name)
		Lib.emitEvent(Event.EVENT_EDITOR_CHANGE_MAP,name)
		--entity_obj:load()
		state:set_focus(nil)
		state:set_brush(nil)
		user_data:save()
	end,

	delete_map = function(params)
		local map_name = assert(params.map_name,params.map_name)
		obj:delete_map(map_name)
		entity_obj:delete_map(map_name)
		local issame = false
		for k, v in pairs(World.staticList) do
			if k == map_name then
				issame = true
				break
			end
		end
		if issame == true then
			World.staticList[map_name]:close()
		end
	end,

	Send_PropertyBtnFun = function(b)
		if b then
			view:gizmo_darg_end_true()
		else
			view:gizmo_darg_end_false()
		end
	end,

	get_player_pos = function(params)
		return bm:getViewerPos()
	end,

	mirror = function(direction)
		local op = Operator:operator("MIRROR")
		if op:check(Receptor:binding()) then
			op:exec(Receptor:binding(), direction)
		end
	end,

	rotate = function(direction)
		local op = Operator:operator("SPIN")
		if op:check(Receptor:binding()) then
			op:exec(Receptor:binding(), direction)
		end
	end,

	is_login = function()
		return networdaccess:is_login()
	end,

	request_login = function(name,passwd)
		local obj = {ok = networdaccess:login(name,passwd)}
		return obj
	end,

	request_logout = function()
		local obj = networdaccess:logout()
		return obj
	end,

	request_simple_game_list = function()
		local obj = networdaccess:simple_game_list()
		return obj
	end,

	request_basic_info = function()
		local obj = networdaccess:basic_info()
		return obj
	end,

	request_upload_game = function(obj)
		--上传资料
		return networdaccess:upload_game(obj)
	end,

	request_game_latest_version = function(game_id,version_id)
		local obj = networdaccess:game_latest_version(game_id,version_id)
		return obj
	end,

	request_gen_sign_url = function(type,name,is_rename)
		local obj = networdaccess:gen_sign_url(type,name,is_rename)
		return obj
	end,

	request_game_types = function()
		local obj = networdaccess:game_types()
		return obj
	end,

	request_get_lang_type = function()
		local obj = {lang = lang.get_locale()}
		return obj
	end,

	entity_attribute_changes = function(obj)
		local new_obj = {
			pos = obj.pos,
			yaw = obj.ry
		}
		cmd:move_entity(obj.id,new_obj)
	end,

	region_attribute_changes = function(obj)
		cmd:move_region(obj.id,obj)
	end,

	request_map_pos_changes = function(item_name,obj)
		local m = Module:module("map")
		assert(m,"map")
		local item = m:item(item_name)
		item:obj().initPos = obj
	end,

	request_get_curr_map_name = function()
		local obj = {name = Map:curr_map_name()}
		return obj
	end,

	get_md5 = function(path)
		return {md5 = core.md5(path)}
	end,

	zip = function()
		local out = Lib.combinePath(def.DIR_GAME_OUTPUT, World.GameName..".zip")
		engine:zip(def.PATH_GAME, out)
		return {path = out}
	end,

	delete_entity_data = function(cfg)
		local m = Module:module("map")
		assert(m,"map")
		local item = m:item(Map:curr_map_name())
		local entitys = item:obj().entitys

		local curr = 1
		repeat
			if not entitys[curr] then
				break
			end

			if entitys[curr].cfg == cfg then
				item:data():remove("entitys",curr)
				
			else
				curr = curr + 1
			end
		until(false)

		if state:focus_class() == def.TENTITY then
			state:set_focus(nil)
			engine:editor_obj_type("common")
		end
		if state:brush_class() == def.TENTITY then
			state:set_brush(nil)
			engine:editor_obj_type("common")
		end
		
	end,

	request_get_item_cfg = function()
		local op = Operator:operator("GET_CFG")
		local obj = {}
		if op:check(Receptor:binding()) then
			obj = op:exec(Receptor:binding())
		end
		return obj
	end,

	request_set_map_camera = function(pos)
		local bm = Blockman.Instance()
		pos.y = math.max(pos.y,0)
		pos.y = math.min(pos.y,255)
		bm:setViewerPos(pos, bm:getViewerYaw(), bm:getViewerPitch(), 1)
		Map:update(pos)
	end,

	request_get_map_camera = function()
		local map = Map:curr_map()
		return map and map:get_pos() or {x = 0, y = 0, z = 0}
	end,

	request_set_map_pos = function(map_name,map_pos)
		Map:update_by_name(map_name,map_pos)
	end,

	request_get_map_pos = function(map_name)
		return user_data:get_value("map_pos")[map_name]
	end,

	request_save_map_pos = function()
		user_data:save();
	end,

	request_clear_map_mca = function(map_name)
		Map:clear_map_mca(map_name)
	end,

	save_item_by_path = function(module,id,dir_path)
		local m = Module:module(module)
		assert(m,module)
		local item = m:item(id)
		
		local item_json = {
			meta = {
				[def.ITEM_META_VERSION] = Meta:version()
			},
			data = item:val()
		}

		engine:export_block_list(dir_path,item_json)

		return {ok = true}
	end,

	request_web_login = function(token)
		networdaccess:web_login(token)
	end,

	request_web_get_url = function()
		local murl =  networdaccess:get_url()
		local mok = false
		if murl ~= "" then
			mok = true
		else
			mok = false
		end
		return {url = murl,ok = mok}
	end,

	on_actor_modify = function()
		engine:update_entitys()
	end,

	request_replace_focus = function(module,id)
		if module == "block" and state:focus_class() == def.TBLOCK then
			local bpos = state:focus_obj().pos
			local id_ = setting:name2id("block","myplugin/"..id)
			cmd:set_block(bpos,id_,true)
		elseif module == "entity" and state:focus_class() == def.TENTITY then
			local old_id = state:focus_obj().id
			local pos_ = Map:curr_map():get_pos_byid(old_id)
			local yaw_ = Map:curr_map():get_yaw_byid(old_id)
			local pos = {
				x = pos_.x,
				y = pos_.y,
				z = pos_.z
			}
			cmd:del_entity(old_id)
			cmd:set_entity(pos,"myplugin/"..id,yaw)
		end
	end,

	cmd_push_only = function(uid)
		Cmd:uni_cmd(uid)
	end,

	hotfix_lua = function()
		hotfix:reload()
	end,
	
	place_region = function()
		local placer = Placer:bind("region")
		placer:select()
	end,
}

function handle_editor_command(cmd)
--	print(string.format("receive command:%s", cmd))
	local function _handle_editor_command(cmd)
		local ret0, ret1 = pcall(cjson.decode, cmd)
		assert(ret0, ret1)

		local processor
		if ret1.proto then
			processor = require(string.format("we.proto.respond_%s", string.lower(ret1.proto)))
		else
			processor = processor_common
		end

		local func = processor[ret1.type]
		assert(func, string.format("invalid proto %s:%s", ret1.proto, ret1.type))

		local count = 0
		for idx in pairs(ret1.params or {}) do
			if idx > count then
				count = idx
			end
		end
		ret1 = func(table.unpack(ret1.params or {}, 1, count)) or {}

		if type(ret1) == "table" then
			local r = cjson.encode(ret1 or {})
			return r
		elseif type(ret1) == "string" then
			return ret1
		else
			assert("invalid type", type(ret1))
		end
	end

	local ok, ret = xpcall(_handle_editor_command, debug.traceback, cmd)
	if not ok then
		print(ret)
	end

	return ret
end
