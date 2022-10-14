local Cjson = require "cjson"
local Def = require "we.def"
local Lfs = require "lfs"
local Seri = require "we.gamedata.seri"
local ItemDataUtils = require "we.gamedata.item_data_utils"
local Converter = require "we.gamedata.export.data_converter"
local ItemBase = require "we.gamedata.module.class.item_base"
local Meta = require "we.gamedata.meta.meta"
local PropImport = require "we.gamedata.module.prop_import"
local Map = require "we.map"
local Utils = require "we.view.scene.utils"
local EngineFile = require "we.view.scene.create_engine_file"
local GameConfig = require "we.gameconfig"
local Core = require "editor.core"
local View = require "we.view"
local Lang = require "we.gamedata.lang"

local M = Lib.derive(ItemBase)

local MODULE_NAME = "map"
local ITEM_TYPE = "MapCfg"

local PATH_DATA_DIR = Lib.combinePath(Def.PATH_GAME, MODULE_NAME)

function M:on_modify(reload, no_store)
	if no_store then
		return
	end
	self:set_modified(true)
	if reload then
		self:flush()
		Map:reload_map(self:id())
	end
	self:update_props_cache()
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED, self._module:name(), self._id)
end

--天空盒贴图(引擎顺序:right、left、top、bottom、back、front)
local function convert_texture(texture)
	local function convert(text)
		if not text then
			return ""
		elseif "@" == string.sub(text, 1, 1) then
			return string.sub(text, 2)
		else
			return text
		end
	end

	return {
		right	= { asset = convert(texture[1]) },
		left	= { asset = convert(texture[2]) },
		top		= { asset = convert(texture[3]) },
		bottom	= { asset = convert(texture[4]) },
		back	= { asset = convert(texture[5]) },
		front	= { asset = convert(texture[6]) }
	}
end

--加载数据
function M:load_data()
	return function()
		local item_path = Lib.combinePath(Def.PATH_GAME_META_DIR,
			"module", self._module:name(),
			"item",	self._id,
			"setting.json")
		local data = Lib.read_json_file(item_path)
		assert(data.data, item_path)

		-- load folder data set
		local exportMD5s = {}
		local folderPath = Lib.combinePath(Def.PATH_GAME_META_DIR, "module", self._module:name(), "item", self._id, self.folderConfig.folder_name)
		self.folderConfig:load_folder_editor(data.data.instances, folderPath, exportMD5s)
		return data.data
	end
end

--[FolderDataSet]导出节点资源数据（编辑器）
function M:export_folder_editor(val, dataSetMD5s, is_preprocess)
	local folderPath = Lib.combinePath(Def.PATH_GAME_META_DIR, "module", self._module:name(), "item", self._id, self.folderConfig.folder_name)
	self.folderConfig:export_folder_editor(val, dataSetMD5s, folderPath, is_preprocess)
end

M.config = {
	{
		key = "setting.json",

		reader = function(item_name, raw, item)
			local path = Lib.combinePath(PATH_DATA_DIR, item_name, "setting.json")
			local content = Lib.read_file(path, raw)
			--读取时，导入引擎节点资源数据（计算节点资源各个文件的md5，编辑器数据和引擎数据不同时，以引擎数据为准）
			local contentMd5 = ""
			local dataSetMD5s = {}
			if content then
				contentMd5 = content ~= "" and Core.md5(content) or ""

				local setting = Cjson.decode(content)
				local folderPath = Lib.combinePath(PATH_DATA_DIR, item_name, item.folderConfig.folder_name)
				item.folderConfig:load_folder_engine(setting.scene, folderPath, dataSetMD5s)
				content = Lib.toJson(setting)
			end
			return content, contentMd5, dataSetMD5s
		end,

		--content引擎数据，ref编辑器数据，item类
		import = function(content, ref, item)
			local setting = Cjson.decode(content)

			local props = {
				canAttack			= PropImport.original,
				canBreak			= PropImport.original,
				fog = function(v)
					local ret = {
						hideFog = v.hideFog == nil and true or v.hideFog,
						start = v.start,
						density = v.density and { value = v.density },
						type = v.type,
						min = v.min
					}
					if v.start and v["end"] then
						ret.range = v["end"] - v.start
					end
					if v.color then
						ret.color = { 
							r = math.ceil((v.color.x or 1) * 255), 
							g = math.ceil((v.color.y or 1) * 255), 
							b = math.ceil((v.color.z or 1) * 255) 
						}
					end
					return ret
				end
			}
			
			for k, v in pairs(setting) do
				if type(props[k]) == "function" then
					ref[k] = props[k](v)
				end
			end

			ref.touch_pos = {}
			ref.touch_pos.down = setting.touchPosY and setting.touchPosY.touchdownPosY or -30.00
			ref.touch_pos.up = setting.touchPosY and setting.touchPosY.touchupPosY or 720.00
			--光源全局参数
			ref.blinn = setting.blinn == 1 and true or false
			ref.hdr = setting.hdr == 1 and true or false
			ref.reinhard = setting.reinhard
			ref.exposure = setting.exposure
			if setting.useLod~=nil then
				ref.useLod=setting.useLod
			end
			--ret.gamma = setting.gamma
			--ret.ambientStrength = setting.ambientStrength

			--天空盒
			do
				--天空盒切换模式
				local type = setting.skyBoxMode
				local base
				if setting.skyBox and next(setting.skyBox) then
					--处理之前没有保存skyBoxMode的情况
					if not type or "" == type then
						if #setting.skyBox > 1 or setting.skyBox[1].time then
							type = "dynamic_switch"
						else
							type = "static_display"
						end
					end
					if "static_display" == type then
						--天空盒静态贴图
						if setting.skyBox[1].texture then
							base = convert_texture(setting.skyBox[1].texture)
							base[Def.OBJ_TYPE_MEMBER] = "SkyBoxStatic"
						end
					elseif "dynamic_switch" == type then
						--天空盒动态贴图
						base = {
							[Def.OBJ_TYPE_MEMBER] = "SkyBoxDynamic",
							items = {}
						}
						for _, v in ipairs(setting.skyBox) do
							if v.texture then
								local info = {
									time = v.time,
									transition = v.transition,
									texture = convert_texture(v.texture)
								}
								table.insert(base.items, info)
							end
						end
					else
						print("convert skyBox fail: " .. type)
					end
				end
				ref.box = {
					type = type,
					base = base
				}
				--天空盒旋转速度
				if setting.skyBoxRotate then
					ref.rotateSpeed = setting.skyBoxRotate.y / 60
				else
					ref.rotateSpeed = 0
				end
			end

			--entity
			do
				ref.regions = nil
				ref.entitys = nil
			end
			
			if not ref.name then
				local trans_key = item:module_name() .. "_" .. item:id()
				ref.name = PropImport.Text(trans_key)
			end
			-- instance
			repeat
				if setting.scene then
					ref.instances = {}
					for _, item in ipairs(setting.scene) do
						table.insert(ref.instances, Utils.import_inst(item))
					end
				end
			until(true)
			ref.bake_texture_size = setting.bake_texture_size
			ref.is_bake_light_effect_visible = setting.is_bake_light_effect_visible
			
			return ref
		end,

		-- rawval编辑器数据，content引擎数据，save_merge_file是否保存网格数据
		export = function(rawval, content, save_merge_file)
			local ret = content and Cjson.decode(content) or {}

			local item = Meta:meta(ITEM_TYPE):ctor(rawval)

			ret.hideCloud = true
			ret.touchPosY = {
				touchdownPosY = item.touch_pos and item.touch_pos.down or -30.00,
				touchupPosY = item.touch_pos and item.touch_pos.up or 720.00
			}

			ret.canAttack	= item.canAttack
			ret.canBreak	= item.canBreak
			ret.moveDownGravity = GameConfig:disable_block() and 0.15 or nil
			--光源全局参数
			ret.blinn = item.blinn and 1 or 0
			ret.hdr = item.hdr and 1 or 0
			ret.reinhard = item.reinhard
			ret.exposure = item.exposure
			ret.gamma = item.gamma
			ret.ambientStrength = item.ambientStrength
			if(content) then
				ret.useLod=content.useLod
			else
				ret.useLod=false
			end

			--天空盒
			do
				ret.skyBoxTexSize = 512
				ret.skyBoxTexPixFmt = "RGBA8"
				--天空盒切换模式
				ret.skyBoxMode = item.box.type
				--天空盒贴图(引擎顺序:right、left、top、bottom、back、front)
				local sky_base = item.box.base
				local sky_type = sky_base.__OBJ_TYPE
				if "SkyBoxStatic" == sky_type then
					ret.skyBox = {}
					local skyBoxItem = {
						texture = {}
					}
					table.insert(skyBoxItem.texture, #sky_base.right.asset > 0	and "@"..sky_base.right.asset	or "")
					table.insert(skyBoxItem.texture, #sky_base.left.asset > 0	and "@"..sky_base.left.asset	or "")
					table.insert(skyBoxItem.texture, #sky_base.top.asset > 0	and "@"..sky_base.top.asset		or "")
					table.insert(skyBoxItem.texture, #sky_base.bottom.asset > 0	and "@"..sky_base.bottom.asset	or "")
					table.insert(skyBoxItem.texture, #sky_base.back.asset > 0	and "@"..sky_base.back.asset	or "")
					table.insert(skyBoxItem.texture, #sky_base.front.asset > 0	and "@"..sky_base.front.asset	or "")
					table.insert(ret.skyBox, skyBoxItem)
				elseif "SkyBoxDynamic" == sky_type then
					ret.skyBox = {}
					for _, v in ipairs(sky_base.items or {}) do
						local skyBoxItem = {
							texture = {}
						}
						skyBoxItem.time = v.time
						skyBoxItem.transition = v.transition
						table.insert(skyBoxItem.texture, #v.texture.right.asset > 0		and "@"..v.texture.right.asset	or "")
						table.insert(skyBoxItem.texture, #v.texture.left.asset > 0		and "@"..v.texture.left.asset	or "")
						table.insert(skyBoxItem.texture, #v.texture.top.asset > 0		and "@"..v.texture.top.asset	or "")
						table.insert(skyBoxItem.texture, #v.texture.bottom.asset > 0	and "@"..v.texture.bottom.asset or "")
						table.insert(skyBoxItem.texture, #v.texture.back.asset > 0		and "@"..v.texture.back.asset	or "")
						table.insert(skyBoxItem.texture, #v.texture.front.asset > 0		and "@"..v.texture.front.asset	or "")
						table.insert(ret.skyBox, skyBoxItem)
					end
				else
					--默认天空盒
					ret.skyBox = {}
					local skyBoxItem = {
						texture = {}
					}
					table.insert(skyBoxItem.texture, "@asset/Sky03_right.png")
					table.insert(skyBoxItem.texture, "@asset/Sky03_left.png")
					table.insert(skyBoxItem.texture, "@asset/Sky03_top.png")
					table.insert(skyBoxItem.texture, "@asset/Sky03_bottom.png")
					table.insert(skyBoxItem.texture, "@asset/Sky03_back.png")
					table.insert(skyBoxItem.texture, "@asset/Sky03_front.png")
					table.insert(ret.skyBox, skyBoxItem)
				end
				--天空盒旋转速度
				ret.skyBoxRotate = {
					x = 0,
					y = item.rotateSpeed * 60,
					z = 0
				}
			end

			--entitys
			do
				ret.entity = nil
				ret.region = nil
			end
			
			if item.useLod~=nil then
				ret.useLod=item.useLod
			end

			if not item.fog.hideFog then
				ret.fog = {
					hideFog = item.fog.hideFog,
					start = item.fog.start,
					density = item.fog.density.value,
					color = {
						x = item.fog.color.r / 256,
						y = item.fog.color.g / 256,
						z = item.fog.color.b / 256
					},
					type = item.fog.type,
					min = item.fog.min
				}
				ret.fog["end"] = item.fog.start + item.fog.range
			else
				ret.fog = nil
			end

			repeat
				local check_inst = Utils.raw_check_inst(ret.scene)
				ret.scene = nil
				if not next(item.instances) then
					break
				end

				if save_merge_file then
					EngineFile:create_merge_shapes_file(item.instances)
				end

				ret.scene = {}
				for _, val in ipairs(item.instances) do
					local ins = Utils.export_inst(val)
					table.insert(ret.scene,check_inst(ins))
				end
			until(true)

			ret.bake_texture_size = item.bake_texture_size
			ret.is_bake_light_effect_visible = item.is_bake_light_effect_visible

			return ret
		end,

		writer = function(item_name, data, dump, item)
			assert(type(data) == "table")

			--写入时，导出引擎节点资源数据（返回节点资源各个文件的md5，编辑器数据和引擎数据不同时，以引擎数据为准）
			local folderPath = Lib.combinePath(PATH_DATA_DIR, item_name, item.folderConfig.folder_name)
			local dataSetMD5s = item.folderConfig:export_folder_engine(data.scene, folderPath)
			
			local path = Lib.combinePath(PATH_DATA_DIR, item_name, "setting.json")
			return Seri("json", data, path, dump), dataSetMD5s
		end,

		discard = function(item_name)
			local path = Lib.combinePath(PATH_DATA_DIR, item_name, "setting.json")
			ItemDataUtils:del(path)
		end
	},

	discard = function(item_name)
		local path = Lib.combinePath(PATH_DATA_DIR, item_name)
		ItemDataUtils:delDir(path)
		-- todo：要对地形对象执行 VoxelTerrain::clearStorage()
	end
}

--检查修改权限
local function check_has_dataSet_acl(aclNames)
	if not aclNames or not next(aclNames) then
		return true --权限名单为空时不限制
	end
	local ok, login_username = View:get_login_username()
	if not ok then
		return false
	end
	for _,name in ipairs(aclNames) do
		name = Lib.stringTrim(name)
		if name == login_username then
			return true
		end
	end
	return false
end

M.folderConfig = {
	--文件夹名字
	folder_name = "DataSet",

	--加载节点资源数据（编辑器）
	load_folder_editor = function(self, val, folderPath, exportMD5s)
		if not val or not next(val) or not folderPath then
			return
		end
		for key,_ in ipairs(val) do
			if "Instance_Folder" == val[key]["__OBJ_TYPE"] then
				if val[key].isDataSet then
					local name = val[key].id .. ".json"
					local path = Lib.combinePath(folderPath, name)
					if Lib.fileExists(path) then
						local item = Lib.read_json_file(path)
						assert(item, path)
						local children
						-- 兼容旧数据
						if item.meta then
							children = item.data
							exportMD5s[name] = item.meta.EXPORT_MD5
						else
							children = item
						end
						-- load folder child data set
						self:load_folder_editor(children, folderPath, exportMD5s)

						val[key].children = children
					end
				else
					-- load folder child data set
					self:load_folder_editor(val[key].children, folderPath, exportMD5s)
				end
			end
		end
	end,

	--加载节点资源数据（引擎）
	load_folder_engine = function(self, val, folderPath, dataSetMD5s)
		if not val or not next(val) or not folderPath or not dataSetMD5s then
			return
		end
		for key,_ in ipairs(val) do
			if "Folder" == val[key].class then
				if "true" == val[key].properties.isDataSet then -- 引擎是字符串
					local name = val[key].properties.id .. ".json"
					local path = Lib.combinePath(folderPath, name)
					if Lib.fileExists(path) then
						local data = Lib.read_json_file(path)
						assert(data, path)
						--记录文件的MD5
						local content = Lib.read_file(path)
						dataSetMD5s[name] = content and content ~= "" and Core.md5(content) or ""
						--遍历加载folder所有数据
						self:load_folder_engine(data, folderPath, dataSetMD5s)

						val[key].children = data
					end
				else
					--遍历加载folder所有数据
					self:load_folder_engine(val[key].children, folderPath, dataSetMD5s)
				end
			end
		end
	end,

	--导出节点资源数据（编辑器）
	export_folder_editor = function(self, val, dataSetMD5s, folderPath, is_preprocess)
		local exportFiles = {}
		local ids = {}

		local function export_folder(folder)
			if not folder.children or not next(folder.children) then
				return
			end
			-- 1.先导出children数据
			for key,_ in ipairs(folder.children) do
				if "Folder" == folder.children[key].class then
					export_folder(folder.children[key])
				end
			end
			-- 2.再导出folder数据
			if folder.isDataSet then
				-- create dir
				Lib.mkPath(folderPath)

				local name = folder.id .. ".json"
				local md5 = dataSetMD5s[name] or "" --md5没有则为空字符串

				-- 数据升级 or 检查修改权限
				if is_preprocess or check_has_dataSet_acl(folder.aclNames) then
					local meta = Meta:meta(folder["__OBJ_TYPE"])
					local data = meta:diff(folder, nil, true) or {}

					local item = {
						meta = {
							EXPORT_MD5 = md5
						},
						data = data.children
					}
					local path = Lib.combinePath(folderPath, name)
					os.remove(path)
					local file, errmsg = io.open(path, "w+b")
					assert(file, errmsg)
					file:write(Lib.toJson(item))
					file:close()
				else
					table.insert(ids, folder.id)
				end
				exportFiles[name] = true
				folder.children = {}
			end
		end

		if not val or not val.instances or not next(val.instances) or not dataSetMD5s then
			return
		end

		for key,_ in ipairs(val.instances) do
			if "Folder" == val.instances[key].class then
				export_folder(val.instances[key])
			end
		end
		if next(ids) then
			local strIds = table.concat(ids, ',')
			if not is_preprocess then
				View:show_dataSet_permission_msg(Lang:text("DataSetNotPermission", true), strIds)
			end
		end
		self:clear_folder(folderPath, exportFiles)
	end,

	--导出节点资源数据（引擎）
	export_folder_engine = function(self, val, folderPath)
		local dataSetMD5s = {}

		local function export_folder(folder)
			if not folder.children or not next(folder.children) then
				return
			end
			-- 1.先导出children数据
			for key,_ in ipairs(folder.children) do
				if "Folder" == folder.children[key].class then
					export_folder(folder.children[key])
				end
			end
			-- 2.再导出folder数据
			if "true" == folder.properties.isDataSet then
				-- create dir
				Lib.mkPath(folderPath)

				local name = folder.properties.id .. ".json"
				local file_path = folderPath .. '/' .. name
				local md5
				-- 检查修改权限
				if check_has_dataSet_acl(folder.properties.aclNames) then
					md5 = Seri("json", folder.children, file_path, true)
				else
					local content = Lib.read_file(file_path)
					md5 = content and content ~= "" and Core.md5(content) or ""
				end
				dataSetMD5s[name] = md5
				folder.children = nil --置为nil
			end
		end

		if not val or not next(val) then
			return dataSetMD5s
		end

		for key,_ in ipairs(val) do
			if "Folder" == val[key].class then
				export_folder(val[key])
			end
		end
		self:clear_folder(folderPath, dataSetMD5s)
		return dataSetMD5s
	end,

	--清理节点资源数据
	clear_folder = function(self, folderPath, exportFiles)
		if not folderPath then
			return
		end
		for entry in Lfs.dir(folderPath) do
			if entry ~= "." and entry ~= ".." then
				local curFile = folderPath .. '/' .. entry
				if "file" == Lfs.attributes(curFile, "mode") and (not exportFiles or not exportFiles[entry]) then
					os.remove(curFile)
				end
			end
		end
	end,

	check_md5_same = function(self, set, dataSet)
		local function getLen(tab)
			local count = 0
			for k,v in pairs(tab) do
				count = count + 1
			end
			return count
		end

		set = set or {}
		dataSet = dataSet or {}
		local same = true
		if getLen(set) ~= getLen(dataSet) then
			same = false
		else
			for k,v in pairs(set) do
				if not dataSet[k] or dataSet[k] ~= v then
					same = false
					break
				end
			end
		end
		return same
	end
}

return M
