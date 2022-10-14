--用来放一些多个模块都可以用的数据转换方法
local Meta = require "we.gamedata.meta.meta"
local Def = require "we.def"
local UIProperty = require "we.logic.ui.ui_property"

local function remove_obj_type(data)
	if _G.type(data) ~= "table" then
		return data
	end
	local ret = {}	
	if #data == 0 then
		for k, v in pairs(data) do
			if k ~= "__OBJ_TYPE" then
				ret[k] = remove_obj_type(v)
			end
		end
	else
		for i, v in ipairs(data) do
			table.insert(ret, remove_obj_type(v))
		end
	end
	return ret
end

local mapping = {
	["remove_obj_type"] = remove_obj_type,
	["BoundingVolume"] = function(data)
		local boundingVolume = {}
		boundingVolume["type"] = data.type
		if data.type == "Box" then
			boundingVolume["extent"] = {x = data.size.x, y = data.size.y, z = data.size.z}
		elseif data.type == "Capsule" then
			boundingVolume["radius"] = data.radius_c
		else 
			boundingVolume["radius"] = data.radius
		end
		
		if data.type == "Capsule" then
			boundingVolume["height"] = data.height_c
		elseif data.type == "Cylinder" or data.type == "Sector" then
			boundingVolume["height"] = data.height
		end

		if data.type == "Sector" then
			boundingVolume["angle"] = {min = data.angle.min, max = data.angle.max}
		end
		boundingVolume["offset"] = {x = data.position.x, y = data.position.y, z = data.position.z}
		boundingVolume["rotation"] = {x = data.rotate.x, y = data.rotate.y, z = data.rotate.z}
		return boundingVolume
	end,
	["Vector3"] = function(data)
		return {
			x = data.x,
			y = data.y,
			z = data.z,
		}
	end,
	["AttackBound"] = function(data)
		local boundingVolume = {}
		boundingVolume["type"] = data.type
		if data.type == "Box" then
			boundingVolume["extent"] = {x = data.size.x, y = data.size.y, z = data.size.z}
		elseif data.type == "Capsule" then
			boundingVolume["radius"] = data.radius_c
		else 
			boundingVolume["radius"] = data.radius
		end
		
		if data.type == "Capsule" then
			boundingVolume["height"] = data.height_c
		elseif data.type == "Cylinder" or data.type == "Sector" then
			boundingVolume["height"] = data.height
		end

		if data.type == "Sector" then
			boundingVolume["angle"] = {min = data.angle.min, max = data.angle.max}
		end
		boundingVolume["offset"] = {x = data.position.x, y = data.position.y, z = data.position.z}
		boundingVolume["rotation"] = {x = data.rotate.x, y = data.rotate.y, z = data.rotate.z}
		return boundingVolume
	end,
	["Time"] = function(data)
		return data.value
    end,
	["TalkList"] = function(data)
		local talk = {}
		for _,v in pairs(data.talk) do
			table.insert(talk,{
				["npc"] = v.npc,
				["msg"] = v.msg.value
			})
		end
		return talk
	end,
	["OptionList"] = function(data)
		local option = {}
		for _,v in pairs(data.option) do
			table.insert(option,{
				["showText"] = v.showText.value,
				["triggerName"] = v.triggerName.value
			})
		end
		return option
	end,
	["ScenePos"] = function(data)
		return {
			map = data.map,
			x = data.pos.x,
			y = data.pos.y,
			z = data.pos.z,
		}
	end,
	["SceneRegion"] = function(data)
		return {
			map = data.map,
			min = data.region.min,
			max = data.region.max
		}
	end,
	["BlockArray"] = function(data)
		if #data.blockArray > 0 then
			return data.blockArray
		end
	end,
	["CommodityPageIndexArray"] = function(data)
		local Commodity = require "we.logic.commodity.commodity"
		local ret = {}
		if #data.array > 0 then
			for _, id in ipairs(data.array) do
				if Commodity:has_id(id) then
					table.insert(ret, id)
				end
			end
		end
		return ret
	end,
	["TipTypeCvr"] = function(data)
		return tonumber(data.type)
	end,
	["Text"] = function(data)
		return data.value
	end
}

mapping[Def.TYPE_ASSET] = function(data, global)
		return convert_asset(data, global)
end

function mapping.Resource_Effect(data)
	return mapping.prefixless_asset(data)
end

function mapping.Resource_Actor(data)
	return mapping.prefixless_asset(data)
end

function mapping.Resource_Layout(data)
	return string.sub(data.asset, 7, -8)
end

function mapping.LayoutHierarchy(data)
	return data.path
end

--编辑器调用时引擎需要FF000000格式
--蓝图又要{r = 0,g = 0,b = 0}格式
--零件蓝图又是[1.0,1.0,1.0,1.0]
function mapping.UIBluePrintColor(data)
	return {r = data.r, g = data.g, b = data.b}
end

function mapping.UDim2(data)
	return {{data.UDim_X.Scale, data.UDim_X.Offect}, {data.UDim_Y.Scale, data.UDim_Y.Offect}}
end

function mapping.Anchor(data)
	local tb_h = {Left = 0, Centre = 1, Right = 2}
	local tb_v = {Top = 0, Centre = 1, Bottom = 2}
	return { hAlignment = tb_h[data.HorizontalAlignment], 
		vAlignment = tb_v[data.VerticalAlignment]}
end

function mapping.MissileEffect(data)
	if data.effect.asset ~= "" then
		local ret = {
			yaw = data.yaw,
			once = data.once,
			pos = {
				x = data.pos.x,
				y = data.pos.y,
				z = data.pos.z
			},
			effect = mapping.add_asset(data.effect),
			scale = {
				x = data.scale.x,
				y = data.scale.y,
				z = data.scale.z
			}
		}
		if data.timeLimit then
			ret.time = data.time.value
		end
		return ret
	end
end

function mapping.EntityEffect(data)
	if data.effect.asset ~= "" then
		return{
			yaw = data.yaw,
			selfOnly = data.selfOnly,
			once = data.once,
			pos = {
				x = data.pos.x,
				y = data.pos.y,
				z = data.pos.z
			},
			effect = data.effect.asset,
			scale = {
				x = data.scale.x,
				y = data.scale.y,
				z = data.scale.z
			}
		}
	end
end

function mapping.CastSound(data)
	if data.sound.asset == "" then
		return nil
	end
	local ret = {
		selfOnly = data.selfOnly,
		loop = data.loop,
		volume = data.volume.value,
		multiPly = data.playRate,
		path = data.sound.asset,
		sound = mapping.asset(data.sound)
	}
	if true == data.is3dSound then
		ret.is3dSound = data.is3dSound
		ret.attenuationType = data.attenuationType
		ret.losslessDistance = data.losslessDistance
		ret.maxDistance = data.maxDistance
	end
	return ret
end

function mapping.DeadSound(data)
	return mapping.CastSound(data)
end

function mapping.asset(res)
	assert(res and res.asset)

	--在字符串str中找pattert出现第n次的位置
	local function find(str, pattern, n)
		local index = 0
		for i = 1, n do
			if not index then
				return index
			end
			index = string.find(str, pattern, index + 1)
		end
		return index
	end

	local path = res.asset
	local ret
	if string.find(path, "asset/") == 1 then
		ret = string.gsub(path, "asset/", "@", 1)
	elseif path == "" then
		ret = path
	elseif string.find(path, "plugin/myplugin/") == 1 then
		ret = string.gsub(path, "plugin/myplugin", "", 1)
	end
	return ret
end

function mapping.add_asset(res)
	assert(res and res.asset)

	local path = res.asset
	local ret
	if string.find(path, "asset/") == 1 then
		ret = "@" .. path
	elseif path == "" then
		ret = path
	elseif string.find(path, "plugin/myplugin/") == 1 then
		ret = string.gsub(path, "plugin/myplugin", "", 1)
	end
	return ret
end


function mapping.prefixless_asset(res)
	assert(res and res.asset)
	if res.asset == "" then
		return nil
	end
	if string.find(res.asset, "asset/") == 1 then
		return string.sub(res.asset, 7)
	else
		return res.asset
	end
end

function mapping.Area(data)
	return string.format(
		"{{%s,%s},{%s,%s},{%s,%s},{%s,%s}}",
		data.pos.UDim_X.Scale,
		data.pos.UDim_X.Offect,
		data.pos.UDim_Y.Scale,
		data.pos.UDim_Y.Offect,
		data.pos.UDim_X.Scale + data.size.UDim_X.Scale,
		data.pos.UDim_X.Offect + data.size.UDim_X.Offect,
		data.pos.UDim_Y.Scale + data.size.UDim_Y.Scale,
		data.pos.UDim_Y.Offect + data.size.UDim_Y.Offect
	)
end

function mapping.MarginProperty(data)
	return string.format(
		"{top:{%s,%s},left:{%s,%s},bottom:{%s,%s},right:{%s,%s}}",
		data.top.x,data.top.y,
		data.bottom.x,data.bottom.y,
		data.left.x,data.left.y,
		data.right.x,data.right.y
	)
end

local function FileSuffix(file_path)
	local file_paths = Lib.splitString(file_path,"/")
	local file_info = file_paths[#file_paths]
	local file_infos = Lib.splitString(file_info,".")
	local file_suffix = file_infos[#file_infos]
	return file_suffix
end

local function ImagesetPath(file_path)
	local file_paths = Lib.splitString(file_path,"/")
	local file_info = file_paths[#file_paths]
	local file_infos = Lib.splitString(file_info,".")
	local file_name = file_infos[1]
	table.remove(file_paths,#file_paths)
	local path = table.concat(file_paths, "/")
	return string.format("%s/%s:",path,file_name)
end

function mapping.SoundKey(data)
	local sound_key = ""
	if data.asset ~= "" then
		sound_key = "gameres|"..data.asset
	end
	--print("converter----------->>",data.assert,sound_key)
	return sound_key
end

function mapping.ImageKey(data)
	local image_key = ""
	if data.asset ~= "" then
		local type = FileSuffix(data.asset)
		if type == "imageset" then
			local path = ImagesetPath(data.asset)
			if data.imageset_key ~= "" then
				image_key = "gameres|"..path..data.imageset_key
			end
		elseif type == "png" or type == "tga" then
			image_key = "gameres|"..data.asset
		else
			image_key = data.asset
		end
	end
	print("converter----------->>",data.imageset_key,image_key)
	return image_key
end

function mapping.Image(data)
	local image_key = mapping.ImageKey(data)
	return (image_key == "" and {"editor_image_empty[2910a1]"} or {image_key})[1]
end

function mapping.Resource_CEGUITexture(data)
	return mapping.Image(data)
end

function mapping.Stretch(data)
	return string.format(
		"%s %s %s %s",
		data.top_left,
		data.top_right,
		data.bottom_left,
		data.bottom_right
	)
end

function mapping.Colours(data)
	return mapping.ColorConversion(data)
end

function mapping.ColorConversion(color)
   local hex_color_tb = {a="00",r="00",b="00",g="00"}
   for k,v in pairs(color) do
		local length = 0
		if(hex_color_tb[k] ~= nil) then
			length = string.len(string.sub(string.format("%#x",v),3))
		end
		if length == 1 then 
			hex_color_tb[k] = "0" .. string.sub(string.format("%#x",v),3)
		elseif length == 2 then
			hex_color_tb[k] = string.sub(string.format("%#x",v),3)
		else
			hex_color_tb[k] = "00"
		end
   end
   return hex_color_tb["a"]..hex_color_tb["r"]..hex_color_tb["g"]..hex_color_tb["b"]
end

function mapping.Rotation(data)
	return GUILib.deg2QuaternionStr(data.x, data.y, data.z)
end

function mapping.ActorName(data)
	return data.asset
end

function mapping.EffectName(data)
	return data.asset
end

function mapping.ProgressBarDir(data)
	return string.format(
		"{%s,%s}",
		tostring(data.VerticalProgress),
		tostring(data.ReversedProgress)
	)
end

function mapping.Vector2(data)
	return string.format(
		"x:%s y:%s",
		tostring(data.x),
		tostring(data.y)
	)
end

function mapping.attr(data)
	for _,property in pairs(UIProperty.UI_WINDOW) do
		local type = property[data.key]
		if type then
			local c_type = Lib.splitIncludeEmptyString(type,"/")[1]
			if c_type == "string" then
				return tostring(data.value)
			elseif c_type == "colours" then
				return mapping.Colours(data.value)
			elseif c_type == "image" then
				return mapping.Image(data.value)
			elseif c_type == "sound" then
				return mapping.SoundKey(data.value)
			elseif c_type == "Percentage" then
				return  tostring(data.value.value)
			elseif c_type == "stretch" then
				return mapping.Stretch(data.value)
			elseif c_type == "Rotation" then
				return mapping.Rotation(data.value)
			elseif c_type == "ActorName" then
				return mapping.ActorName(data.value)
			elseif c_type == "EffectName" then
				return mapping.EffectName(data.value)
			elseif c_type == "Vector2" then
				return mapping.Vector2(data.value)
			elseif c_type == "key" then
				return data.value.value
			end
		end
	end
end

function mapping.window_type(data)
	local meta = Meta:meta(data)
	local type = meta:info()["attrs"]["Catalog"]
	local ret
	if data == "DefaultWindow" then
		ret = "DefaultWindow"
	else
		ret = (type ~= "layout" and {"WindowsLook/"..data} or {data})[1]
	end
	return ret
end

function mapping.GridSize(data)
	return string.format(
		"w:%s h:%s",
		data[1],data[2]
	)
end

function mapping.ObjectTreeEntry(data)
	return data.id
end

function mapping.StorageEntry(data)
	return data.id
end

return function(data, type, ...)
	if not type then
		if _G.type(data) == "table" then
			type = data[Def.OBJ_TYPE_MEMBER]
		end
	end

	local converter = mapping[type]
	if not converter then
		return data
	end

	return converter(data, ...)
end
