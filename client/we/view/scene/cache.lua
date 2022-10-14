local GameConfig = require "we.gameconfig"
local Map = require "we.view.scene.map"
local Def = require "we.def"
local Lfs = require "lfs"
local Module = require "we.gamedata.module.module"
local VN = require "we.gamedata.vnode"

local M = {}

local function collect(instances, bts_files, bts_dirs, merge_files, collision_files, mesh_collision_files)
	for _, obj in ipairs(instances) do
		-- get bts
		if Def.SCENE_SUPPORT_BLUEPRINT_TYPE[obj.class] then
			bts_files[obj.btsKey .. ".bts"] = true
			bts_dirs[obj.btsKey] = true
		end
		-- get merge
		if obj.mergeShapesDataKey then
			merge_files[obj.mergeShapesDataKey .. ".json"] = true
		end
		-- get collision
		if "MeshPart" == obj.class then
			local key = "" ~= obj.collisionUniqueKey and obj.collisionUniqueKey or obj.id
			collision_files[key] = true
			-- 获取meshpart collision文件名
			if "" ~= obj.mesh then
				key = string.gsub(obj.mesh, '/', '_')
				local len = string.len(key)
				if ".mesh" == string.sub(key, len - 4) then
					key = string.sub(key, 1, len - 5)
				end
				mesh_collision_files[key] = true
				mesh_collision_files[key .. "_btbvh"] = true
			end
		elseif "PartOperation" == obj.class then
			local key = "" ~= obj.collisionUniqueKey and obj.collisionUniqueKey or obj.id
			collision_files[key] = true
			collect(obj.componentList, bts_files, bts_dirs, merge_files, collision_files, mesh_collision_files)
		end
		collect(obj.children, bts_files, bts_dirs, merge_files, collision_files, mesh_collision_files)
	end
end

-- 检查目录中需删除的文件或目录
local function check_cache_dir(chk_dir, chk_set, del_set, is_dir)
	local type = is_dir and "directory" or "file"
	local set = del_set or {} 
	for fn in Lfs.dir(chk_dir) do
		if fn ~= "." and fn ~= ".." then
			local path = Lib.combinePath(chk_dir, fn)
			local attr = Lfs.attributes(path)
			if attr.mode == type then
				if not chk_set[fn] then
					table.insert(set, path)
				end
			end
		end
	end
	return set
end

-- 清理蓝图文件和空的bts文件
local function delete_bts(bts_files, bts_dirs)
	-- 检查待删除bts文件
	local function check_bts_dir_files(chk_dir, chk_set, del_set)
		local set = del_set or {} 
		for fn in Lfs.dir(chk_dir) do
			if fn ~= "." and fn ~= ".." then
				local path = Lib.combinePath(chk_dir, fn)
				local attr = Lfs.attributes(path)
				if attr.mode == "file" then
					-- 空的bts文件全部清理
					if 0 == attr.size or not chk_set[fn] then
						table.insert(set, path)
					end
				end
			end
		end
		return set
	end

	do
		-- 清理bts文件
		local dir = Lib.combinePath(Def.PATH_GAME, "events")
		local del_files = {}
		check_bts_dir_files(dir, bts_files, del_files)
		for _,path in ipairs(del_files) do
			os.remove(path)
		end
	end

	do
		-- 清理编辑器文件夹
		local del_dirs = {}
		for _,name in pairs(Def.SCENE_SUPPORT_BLUEPRINT_TYPE) do
			local dir = Lib.combinePath(Def.PATH_GAME_META_DIR, "module", name, "item")
			check_cache_dir(dir, bts_dirs, del_dirs, true)
		end
		for _,path in ipairs(del_dirs) do
			Lib.rmdir(path)
		end
	end
end

-- 清理网格文件
local function delete_merge(merge_files)
	local del_files = {}
	check_cache_dir(Def.PATH_MERGESHAPESDATA, merge_files, del_files)
	for _,path in ipairs(del_files) do
		os.remove(path)
	end
end

-- 清理collision文件
local function delete_collision(collision_files)
	local del_files = {}
	check_cache_dir(Def.PATH_PART_COLLISION, collision_files, del_files)
	for _,path in ipairs(del_files) do
		os.remove(path)
	end
end

-- 清理meshpart_collision文件
local function delete_meshpart_collision(mesh_collision_files)
	local del_files = {}
	check_cache_dir(Def.PATH_MESHPART_COLLISION, mesh_collision_files, del_files)
	for _,path in ipairs(del_files) do
		os.remove(path)
	end
end

--不清理工具生成的meshpart_collision文件
local function check_ignore_files(mesh_collision_files)
	local ignore_files = Lib.combinePath(Def.PATH_GAME, "editor_Ignore_files.txt")
	local file = io.open(ignore_files, 'r')
	if file then
		local dirLen = string.len("meshpart_collision/") + 1
		for line in file:lines() do
			line = string.sub(line, dirLen)
			if "" ~= line then
				mesh_collision_files[line] = true
			end
		end
		file:close()
	end
end

local function collect_triggers(proto_trigger_ids,part_ts_dirs)

	local function check_module_name(module_name)	
		for _,value in pairs(Def.SCENE_SUPPORT_BLUEPRINT_TYPE) do
			if value == module_name then
				return true
			end
		end
		return nil
	end

	for _,module in pairs(Module:list()) do
		local module_name = module:name()
		if "blue_protocol" == module_name then
			goto continue
		end
		local check = check_module_name(module_name)
		for _, item in pairs(module:list()) do
			local root = item:obj()
			local item_id = item:id()
			if check and not part_ts_dirs[item_id] then
				goto next
			end
			VN.iter(root,
				"Trigger",
				function(node)
                    if "Trigger_RegisterClientProto" == node["type"] or  "Trigger_RegisterServerProto" == node["type"] then
						proto_trigger_ids[node.proto_uuid] = true
					end
				end
			)
			::next::
		end
		::continue::
	end
end

local function delete_blue_protocols(part_ts_dirs)
	local proto_trigger_ids = {}
	collect_triggers(proto_trigger_ids,part_ts_dirs)
	
	local delete_ids = {}
	local module = Module:module("blue_protocol")
	for _, item in pairs(module:list()) do
		local root = item:obj()
		local item_id = item:id()
		local id = root.id.value
		if not proto_trigger_ids[item_id] then
			table.insert(delete_ids,item_id)
		end
	end

	for _,id in ipairs(delete_ids) do
		module:del_item(id)
	end
end

function M:clean_cache()
	if not GameConfig:disable_block() then
		return
	end
	-- 收集场景中的蓝图和网格文件
	local bts_files = {}
	local bts_dirs = {}
	local merge_files = {}
	local collision_files = {}
	local mesh_collision_files = {}
	for _, map in pairs(Map:maps()) do
		local node = map:get_node()
		local instances = node.__tree:value().instances
		collect(instances, bts_files, bts_dirs, merge_files, collision_files, mesh_collision_files)
	end

	delete_bts(bts_files, bts_dirs)

	delete_merge(merge_files)

	delete_collision(collision_files)

	check_ignore_files(mesh_collision_files)
	delete_meshpart_collision(mesh_collision_files)

	-- 删除没有实体的蓝图协议
	delete_blue_protocols(bts_dirs)
end

return M