local ItemBase = require "we.gamedata.module.class.item_base"
local Meta = require "we.gamedata.meta.meta"
local VN = require "we.gamedata.vnode"
local Def = require "we.def"
local Seri = require "we.gamedata.seri"
local ItemDataUtils = require "we.gamedata.item_data_utils"
local Lfs = require "lfs"
local Converter = require "we.gamedata.export.data_converter"
local loadstring = rawget(_G, "loadstring") or load
local core = require "editor.core"
local Module = require "we.gamedata.module.module"
local UIRequest = require "we.proto.request_ui"
local Lang = require "we.gamedata.lang"

local M = Lib.derive(ItemBase)
local MODULE_NAME = "layout"
local ITEM_TYPE = "LayoutCfg"
local PATH_DATA_DIR = Lib.combinePath(Def.PATH_GAME, "gui/layouts")
local UIProperty = require "we.logic.ui.ui_property"
local guiMgr = L("guiMgr", GUIManager:Instance())

local function convert_asset(name)
	if name == "" then
		return {
			asset = "",
			selector = ""
		}
	end
	local names = Lib.splitString(name,"|")
	local head = names[1]
	if head ~= "gameres" then
		return {asset = name,selector = name}
	end
	local path = name:gsub("gameres|","")
	local paths = Lib.splitString(path,"/")
	local file_info = paths[#paths]
	local file_infos = Lib.splitString(file_info,".")
	local file_suffix = file_infos[#file_infos]
	if (string.find(file_info,":")) == nil and (file_suffix == "png" or file_suffix == "tga") then
		return {asset = path,asset = path}
	elseif file_suffix == "mp3" then
		return {asset = path,asset = path}
	else
		local file_infos = Lib.splitString(file_info,":")
		if #file_infos == 2 then
			table.remove(paths,#paths)
			local path = table.concat(paths, "/")
			local imageset = file_infos[1]
			local imageset_key = file_infos[2]
			local asset = string.format("%s/%s.imageset",path,imageset)
			return {
				imageset_key = imageset_key,
				asset = asset,
				selector = asset
			}
		end
	end
end

local function convert_stretch(value)
	local strs = {}
	for v in string.gmatch(value,"[^ ]+") do
		table.insert(strs,v)
	end
	return {
		top_left = tonumber(strs[1]),
		top_right = tonumber(strs[2]),
		bottom_left = tonumber(strs[3]),
		bottom_right = tonumber(strs[4])
	}
end

local function convert_text_warpped(value)
	if #value <= 13 then
		return false, value
	end
	return true, string.sub(value,9,#value)
end

local function get_md5(path)
	local file, errmsg = io.open(path, "rb")
	assert(file, errmsg)
	local content = file:read("a")
	file:close()
	if not content then
		return ""
	end
	return core.md5(content)
end

function M:init(id, module, rawval)
	local val = {}
	--启动编辑器初始化时rawval为nil
	--在module_layout新建layout时会传入路径
	--使用指定的layout文件初始化这个item,这时将覆盖原有编辑器数据(无论其是否存在)
	--这里的MD5是为了确认有没有在运行时手动编辑layout文件,在未启动编辑器时修改会走
	--会走module的预处理逻辑，运行时修改重新打开时会走这里
	if rawval then
		local path = rawval.path
		self._asset_path = path
		path = Lib.combinePath(Def.PATH_GAME, path)
		local layout_op =self.config[1] 
		val = layout_op.import(layout_op.reader(path),val,self)
		val.path = rawval.path
		val.md5 = get_md5(path)
	else
		val = nil
	end
	ItemBase.init(self,id, module, val)
	if not rawval then
		return
	end
	self:set_layout_info()
end

function M:load()
	ItemBase.load(self)
	self:set_layout_info()
end

function M:MD5Compare(path)
	return self._md5 == get_md5(path)
end

function M:set_md5(md5)
	self._md5 = md5
	VN.assign(self:obj(), "md5", self._md5, 0)
end

function M:path()
	return self._path
end

--从asset开始的路径
function M:set_layout_info()
	local node = self:obj()
	assert(node,"not node")
	self._md5 = node.md5

	local path = node.path
	self._path = Lib.combinePath(Def.PATH_GAME, path)
	self._asset_path = path
	VN.assign(self:obj(), "path", self._asset_path, 0)
	ItemBase.save(self)
end

function M:save()
	if not self:modified() or not self._path then
		return
	end

	ItemBase.save(self)
end

local function read_json_by_id(id)
	local dir = Lib.combinePath(Def.PATH_GAME_META_DIR, "module", "layout", "item", id, "setting.json")
	if Lfs.attributes(dir, "mode") == "file" then
	  return Lib.read_json_file(dir)
  end
  return nil
end

-- 旧字段未删除，暂时可以不启用
--[[
local function update_effect_window(win,key,value)
	if key == "effectXRotate" or key == "effectYRotate" or key == "effectZRotate" then
		if  not win["EffectRotation"] then 
			win["EffectRotation"] = {}
		end
		if key == "effectXRotate" then
			win["EffectRotation"].x = tonumber(value)
		end
		if key == "effectYRotate" then
			win["EffectRotation"].y = tonumber(value)
		end
		if key == "effectZRotate" then
			win["EffectRotation"].z = tonumber(value)
		end
	end

	if key == "effectXPosition" or key == "effectYPosition" then
		if not win["EffectPosition"] then
			win["EffectPosition"] = {}
		end
		local new_key = (key == "effectXPosition") and "x" or "y"
		win["EffectPosition"][new_key] = tonumber(value)
	end
end
]]

local get_trigger_map
get_trigger_map = function(window, name, ref, bts_map)
	local name_path = Lib.combinePath(name, window.name)
	if window.name == "Root" then
		--root本身
		name_path = ""
	elseif window.name == "" then
		--root的子节点
		name_path = window.name
	end

	if #window.triggers.list ~= 0 then
		--只导出存在节点的蓝图
		local info = bts_map[name_path]
		local bts_key = info and info.bts_key or nil
		local md5 = info and info.md5 or ""
		bts_key = bts_key and bts_key or UIRequest.request_get_uuid()
		ref[name_path] = {trigger = window.triggers, bts_key = bts_key, md5 = md5}
	end
	
	--遍历子节点
	for _,child_window in ipairs(window.children) do
		get_trigger_map(child_window, name_path, ref, bts_map)
	end
end


M.config = {
	{
		key = "layout",

		--item_base调用过来的是id，即存在编辑器数据
		--item_layout调用过来的是路径
		reader = function(id)
			--为id时
			local tb = read_json_by_id(id)
			if not tb or not tb["data"] then
				--为路径时
				if Lfs.attributes(id, "mode") == "file" then
					return Lib.read_file(id)
				else
					return nil
				end
			end
			local path = tb["data"]["path"]
			path = Lib.combinePath(Def.PATH_GAME, path)
			if Lfs.attributes(path, "mode") == "file" then
				return Lib.read_file(path)
			end
		end,

		import = function(content, ref, item)
			local data = Lib.XmltoTable(content)
			local root = data.GUILayout.Window

			local old_root = nil
			if ref and ref.root then
				old_root = ref.root
			end

			local ret = {
				__OBJ_TYPE = "LayoutCfg",
				root = {}
			}

			local asset_path = item._asset_path
			local resolve_to
			local create_win = function(window)
				local win_name = window._attr.name
				local win_type = window._attr.type
				for v in string.gmatch(window._attr.type,"[^/]+") do
					win_type = v
				end
				local win = {
					__OBJ_TYPE = win_type,
					id = {
						__OBJ_TYPE = "Uuid",
						value = GenUuid()
					},
					name = win_name,
					children = {},
					anchor = {}
				}
				for _,v in pairs(window.Property) do
					local key = v._attr.name
					if key == "Area" then
						local value = Lib.s2v(v._attr.value)	
						win["pos"] = {
							UDim_X = {
								Scale = value[1][1],
								Offect = value[1][2]
							},
							UDim_Y = {
								Scale = value[2][1],
								Offect = value[2][2]
							}
						}
						win["size"] = {
							UDim_X = {
								Scale = value[3][1] - value[1][1],
								Offect = value[3][2] - value[1][2]
							},
							UDim_Y = {
								Scale = value[4][1] - value[2][1],
								Offect = value[4][2] - value[2][2]
							}
						}
					else
						local map = UIProperty.AttributeSheetMapping
						local type = map["DefaultWindow"][key] or map[win_type][key]
						if type then
							local c_type = Lib.splitIncludeEmptyString(type,"/")[2]
							if c_type == "string" then
								win[key] = v._attr.value
							elseif c_type == "number" then
								win[key] = tonumber(v._attr.value)
							elseif c_type == "boolean" then
								win[key] = v._attr.value == "true" and true or false
							elseif c_type == "colours" then
								local color = v._attr.value
								win[key] = {
									r = tonumber(string.sub(color,3,4),16),
									g = tonumber(string.sub(color,5,6), 16),
									b = tonumber(string.sub(color,7,8), 16),
									a = tonumber(string.sub(color,1,2), 16)
								}
							elseif c_type == "Percentage" then 
								win[key] = { 
									value = tonumber(v._attr.value) 
								}
							elseif c_type == "image" then
								win[key] = convert_asset(v._attr.value)
							elseif c_type == "sound" then
								win[key] = convert_asset(v._attr.value)
							elseif c_type == "ActorName" then
								win[key] = {
									asset = v._attr.value
								}
							elseif c_type == "EffectName" then
								win[key] = {
									asset = v._attr.value
								}
							elseif c_type == "CurrentProgress" then
								win[key] = {
									value = tonumber(v._attr.value)
								}
							elseif c_type == "stretch" then
								win[key] = convert_stretch(v._attr.value)
							elseif c_type == "Font" then
								local value_strs = Lib.splitString(v._attr.value,"-")
								table.remove(value_strs)
								local font = table.concat(value_strs, "-")
								win[key] = font
							elseif c_type == "HorzFormatting" then
								local is_warpped,h_alignment = convert_text_warpped(v._attr.value)
								win["word_warpped"] = is_warpped
								win["HorzFormatting"] = h_alignment
							elseif c_type == "MousePassThrough" then
								local value = v._attr.value
								if value == "false" then
									value = "MousePassThroughClose"
								elseif value == "true" then
									value = "MousePassThroughOpen"
								end
									win["WindowTouchThroughMode"] = value 
							elseif c_type == "Vector3i" then
								local strs = {}
								for str in string.gmatch(v._attr.value,"[^ ]+") do
									local quaternions_value = Lib.splitString(str,":")[2] or 0
									table.insert(strs,quaternions_value)
								end
								--由引擎数据的四元数角转角度,处理数据升级
								local Angle = v._attr.value and GUILib.quaternion2Deg(strs[1], strs[2], strs[3], strs[4]) or {0, 0, 0}
								win[key] = {
									x = tonumber(Angle[1]),
									y = tonumber(Angle[2]),
									z = tonumber(Angle[3])
								}
							elseif c_type == "Vector2" then
								local strs = {}
								for str in string.gmatch(v._attr.value,"[^ ]+") do
									local quaternions_value = Lib.splitString(str,":")[2] or 0
									table.insert(strs,quaternions_value)
								end
								local value_vector2 = v._attr.value and {strs[1], strs[2]} or {1, 1}
								win[key] = {
									x = tonumber(value_vector2[1]),
									y = tonumber(value_vector2[2])
								}
							elseif c_type == "Anchor" then
								win["anchor"][key] = v._attr.value
							elseif c_type == "TextOffset" then
								if not win["TextOffset"] then
									win["TextOffset"] = {}
								end
								local new_key = (key == "TextXOffset" and "x" or "y")
								win["TextOffset"][new_key] = tonumber(v._attr.value)
							elseif c_type == "Space" then
								if not win["Space"] then
									win["Space"] = {}
								end
								local new_key = (key == "hInterval" and "x" or "y")
								win["Space"][new_key] = tonumber(v._attr.value)
							elseif c_type == "key" then
								win["text_key"] = {value = v._attr.value}
							end
						end
					end
				end

				-- 导入layout时，如果发现有翻译，则认为是重复的key（对应复制layout或者手动删除了编辑器数据）
				if win.text_key then
					local key = win.text_key.value
					local text = Lang:text(key)
					if text ~= key then
						local new_key = asset_path.."."..win_type.."#"..GenUuid()
						Lang:copy_text(key,new_key)
						win.text_key =  {value = new_key}	
					elseif win.Text and (win.Text ~= key) then
						--Lang:set_text(key,win.Text)
					end
				elseif win.Text then
					local text = Lang:text(win.Text)		
					if text ~= win.Text then
						local new_key = asset_path.."."..win_type.."#"..GenUuid()
						Lang:copy_text(win.Text,new_key)
						win.text_key =  {value = new_key}
						win.Text = text
					end
				end

				if window.Window then
					resolve_to(window.Window,win.children)
				end
				local auto_window = window.AutoWindow
				if auto_window then
					local namePath = auto_window._attr.namePath
					if namePath == "__auto_thumb__" then
						win.thumb = {}
						for _,v in pairs(auto_window.Property) do
							local key = v._attr.name
							if key == "thumb_image" then
								win["thumb"][key] = convert_asset(v._attr.value)
							elseif key == "thumb_stretch" then
								win["thumb"][key] = convert_stretch(v._attr.value)
							end
						end
					end
				end
				--Lib.pv(win)
				return win
				--->
			end

			resolve_to = function(window,window_children)
				if #window > 0 then
					for _,v in pairs(window) do
						table.insert(window_children,create_win(v))
					end
				else
					table.insert(window_children,create_win(window))
				end
			end

			ret.root = create_win(root)
			local tb = read_json_by_id(item._id)
			if tb then
				ret.path = tb["data"]["path"]
				local path = Lib.combinePath(Def.PATH_GAME, ret.path)
				ret.md5 = get_md5(path)
			end

			local copy_triggers
			copy_triggers = function(window, old_window)
				if not window or not old_window then
					return
				end

				window.triggers = old_window.triggers

				for _,child in ipairs(window.children) do
					if old_window.children then
						for _,old_child in ipairs(old_window.children) do
							if child.name == old_child.name or child.name == old_child.__OBJ_TYPE then
								copy_triggers(child,old_child)
							end
						end
					end
				end
			end
			copy_triggers(ret.root,old_root)

			return ret
		end,

		export = function(rawval)
			local meta = Meta:meta(ITEM_TYPE)
			local item = meta:ctor(rawval)
			--Lib.pv(item,20)
			--todo
			local resolve_to
			resolve_to = function(window,array)
				for _,child in pairs(window.children) do
					local Window = {}
					Window._attr = {
						type = Converter(child.__OBJ_TYPE,"window_type"),
						name = child.name
					}
					
					Window.Property = {
						{
							_attr = { name = "Area", value = Converter({ pos = child.pos, size = child.size },"Area")}
						},
						{
							_attr = { name = "MaxSize", value = "{{999,0},{999,0}}"}
						},
						{
							_attr = { name = "HorizontalAlignment", value = child.anchor.HorizontalAlignment}
						},
						{
							_attr = { name = "VerticalAlignment", value = child.anchor.VerticalAlignment}
						}
					}

					for k ,v in pairs(child)do
						if k == "MousePassThroughEnabled" then
							goto continue
						end	

						if k == "thumb" then
							Window.AutoWindow = {
								_attr = { namePath = "__auto_thumb__" },
								Property = {
									{
										_attr = { name = "thumb_image", value = Converter(v.thumb_image,"Image") }
									},
									{
										_attr = { name = "thumb_stretch", value = Converter(v.thumb_stretch,"Stretch") }
									}
								}
							}
						end
						local c_value = Converter({key = k, value = v},"attr")
						if c_value then
							--TODO text的换行与水平对齐
							if k == "HorzFormatting" and child.word_warpped then
								c_value = "WordWrap"..c_value
							end
							if k == "Font" then
								c_value = c_value.."-"..child.Font_size
							end
							if c_value == "editor_image_empty[2910a1]" then
								c_value = ""
							end
							local attr = { _attr = { name = k,value = c_value}}
							table.insert(Window.Property,attr)
						end
						::continue::
					end

					table.insert(array,Window)
					if #child.children > 0 then
						Window.Window = {}
						resolve_to(child,Window.Window)
					end
				end
			end

			local root = {
				_attr = { version = '4' },
				Window = {
					_attr = { type = "DefaultWindow", name = item.root.name },
					Property = {
						{
							_attr = { name = "Area", value = Converter({ pos = item.root.pos, size = item.root.size },"Area")}
						},
						{
							_attr = { name = "MaxSize", value = "{{999,0},{999,0}}"}
						},
						{
							_attr = { name = "HorizontalAlignment", value = item.root.anchor.HorizontalAlignment}
						},
						{
							_attr = { name = "VerticalAlignment", value = item.root.anchor.VerticalAlignment}
						}
					}
				}
			}
			for k, v in pairs(item.root) do
				local c_value = Converter({key = k, value = v},"attr")
				if c_value then
					local attr = { _attr = { name = k,value = c_value}}
					table.insert(root.Window.Property,attr)
				end
			end
			if #item.root.children > 0 then
				root.Window.Window = {}
				resolve_to(item.root,root.Window.Window)
			end
			
			local data = { root }
			return data
		end,

		writer = function(id, data, dump)
			assert(type(data) == "table")
			--从item_base调用过来的path是id
			local module = Module:module("layout")
			local item = module:list()[id]
			local path = item:path()
			if not path then
				return
			end
			local md5 = Seri("xml",data, path, dump,"GUILayout",2)
			item:set_md5(md5)

			local ok,index = string.find(path,"asset/")
			if not index then
				ok,index = string.find(path,"gui/layout_presets/")
			end	
			if ok ~= -1 then
				local asset_path = string.sub(path,index+1)
				guiMgr:saveLayout(asset_path or "")
			end

			return md5
		end,

		discard = function(item_name)
			local path = Lib.combinePath(string.format("%s/%s.layout",PATH_DATA_DIR,item_name))
			ItemDataUtils:del(path)
		end
	},
	{
		key = "triggers.bts",

		member = "triggers",

		reader = function(item_name, raw)
			--返回包含路径与bts对应关系的表

			local module = Module:module("layout")
			local item = module:list()[item_name]
			local path = item._asset_path
			if not path then
				local tb = read_json_by_id(item_name)
				if not tb or not tb["data"] then
					return
				end
				path = tb["data"]["path"]
			end
			local index = string.find(path,"/")
			path = string.sub(path, index+1, -8)
			local setting_path = Lib.combinePath(Def.PATH_UI_EVENTS, path, "setting.json")
			local tb = Lib.read_json_file(setting_path)
			local bts_info = {}
			if tb and tb.widget then
				for _,v in ipairs(tb.widget) do
					bts_info[v.name] = {bts_key = v.btsKey, md5 = v.md5}
				end
			end
			return bts_info
		end,

		import = function(content, ref)
			-- todo
			return {}
		end,

		export = function(item,bts_info)
			--将layout中所有控件的triggers以路径为key创建表
			local tb = {}

			if not bts_info then
				return tb
			end

			get_trigger_map(item.root, "", tb, bts_info)
			
			return tb
		end,

		writer = function(item_name, data, dump)
			--数据升级时
			if type(data)~= "table" then
				return
			end
			--data :{window_name = {trigger,bts_key,md5}}
			--是覆盖一个文件快，还是获取MD5快？
			local module = Module:module("layout")
			local item = module:list()[item_name]
			local asset_path = item._asset_path
			if not asset_path then
				return
			end
			local index = string.find(asset_path, "/")
			local folder_path = Lib.combinePath(Def.PATH_UI_EVENTS, string.sub(asset_path, index+1, -8))
			Lib.mkPath(folder_path)

			local widget = {}
			local effective_bts = {}
			--保存bts
			for window_name, info in pairs(data) do
				local bts_path = Lib.combinePath(folder_path, info.bts_key .. ".bts")
				local md5 = info.md5
				if not lfs.attributes(bts_path) or get_md5(bts_path) ~= info.md5 or dump then
					md5 = Seri("bts", info.trigger, bts_path, true)
				end
				effective_bts[info.bts_key] = true
				--构建setting.json
				table.insert(widget,{name = window_name, btsKey = info.bts_key, md5 = md5})
			end

			--删除多余bts
			for file in lfs.dir(folder_path) do
				local strs = Lib.splitString(file, ".")
				if strs[#strs] == "bts" and not effective_bts[strs[1]] then
					os.remove(Lib.combinePath(folder_path, file))
				end
			end

			--保存json
			local json_path = Lib.combinePath(folder_path, "setting.json")
			return Seri("json", {widget = widget}, json_path, true)
		end,

		discard = function(item_name)
			local path = Lib.combinePath(PATH_DATA_DIR, item_name, "triggers.bts")
			ItemDataUtils:del(path)
		end
	},
	
	discard = function(item_name)
		local layout = Lib.combinePath(string.format("%s/%s.layout",PATH_DATA_DIR,item_name))
		local PATH_DATA_DIR = string.gsub(Lib.combinePath(Root.Instance():getGamePath(), "gui/lua_scripts/", item_name), "/", "\\")
		local lua = string.format("%s.lua",PATH_DATA_DIR)
		ItemDataUtils:delFile(layout)
		ItemDataUtils:delFile(lua)
	end
}
return M
