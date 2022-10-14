local Def = require "we.def"
local Meta = require "we.gamedata.meta.meta"
local IWorld = require "we.engine.engine_world"
local IInstance = require "we.engine.engine_instance"


--检查浮点型是否改变
local function check_size_is_modify(new, old)
	local PRECISION = 0.01

	if old then
		--小于0.01不做修改
		if math.abs(new.x - old.x) < PRECISION and
			math.abs(new.y - old.y) < PRECISION and
			math.abs(new.z - old.z) < PRECISION then
			return false
		end
	end
	----整数不做修改
	--if math.ceil(new.x) == new.x and
	--	math.ceil(new.y) == new.y and
	--	math.ceil(new.z) == new.z then
	--	return false
	--end
	return true
end

local serializer = {
	["Vector3"] = function(val)
		return string.format("x:%s y:%s z:%s", val.x, val.y, val.z or 1.0)
	end,

	["Vector2"] = function(val)
		return string.format("x:%s y:%s", val.x, val.y)
	end,

	["Color"] = function(val)
		return string.format("r:%s g:%s b:%s a:%s", val.r/255, val.g/255, val.b/255, val.a/255)
	end,

	["LodData"]=function(val)
		return string.format("id:%s distance:%s meshName:%s",val["id"],val["distance"],val["meshName"])
	end,

	["LodGroup"]=function(val)
		local ret=""
		for k,v in pairs(val) do
			local tmp=string.format("id:%s distance:%s meshName:%s ;",v["id"],v["distance"],v["meshName"])
			ret=ret..tmp
		end
		return ret
	end,

	["PartTexture"] = function(val)
		if string.sub(val, -4) ~= ".tga" then
			val = val .. ".tga"
		end
		return val
	end
}

local deserializer = {
	["Vector3"] = function(str)
		if not str then
			return
		end
		local x, y, z = string.match(str, "x:(.+) y:(.+) z:(.+)")

		return { x = tonumber(x), y = tonumber(y), z = tonumber(z) }
	end,

	["Vector2"] = function(str)
		if not str then
			return
		end
		local x, y = string.match(str, "x:(.+) y:(.+)")

		return { x = tonumber(x), y = tonumber(y)}
	end,

	["Color"] = function(str)
		if not str then
			return
		end
		local function transform(number)
			local value = tonumber(number) * 255
			return math.floor(value + 0.5) --四舍五入
		end
		local r, g, b, a = string.match(str, "r:([^ ]+) g:([^ ]+) b:([^ ]+)(.*)")
		if a ~= "" then
			a = transform(string.match(a, " a:([^ ]+)"))
		else
			a = nil
		end
		return { r = transform(r), g = transform(g), b = transform(b), a = a}
	end,

	["PartTexture"] = function(str)
		if not str then
			return
		end
		if string.sub(str, -4) ~= ".tga" then
			str = str .. ".tga"
		end
		return str
	end,

	["Bool"] = function(str)
		if not str then
			return
		end
		local value = str == "true" and true or false
		return value
	end,

	["Number"] = function(str)
		if not str then
			return
		end
		return tonumber(str)
	end,

	["LodData"]=function(str)
		if not str then
			return
		end
		local id,distance,meshName=string.match(str,"id:(.+) distance:(.+) meshName:(.+)")
		local val={id=tonumber(id),distance=tonumber(distance),meshName=tostring(meshName)}
		return val
	end
}

local function seri_prop(type, val)
	if not val then
		return nil
	end

	local proc = serializer[type]
	assert(proc, string.format("property [%s] is not support", type))

	return proc(val)
end

local function deseri_prop(type, str)
	local proc = deserializer[type]
	assert(proc, string.format("property [%s] is not support", type))

	return proc(str)
end


local class_prop_processor
class_prop_processor = {
	["Instance"] = {
		export = function(properties, val, ...)
			properties["name"] = val.name
			properties["id"] = val.id ~= "" and tostring(val.id) or nil
			properties["useForCollision"]=tostring(val.useForCollision)
			properties["isVisibleInEditor"]=tostring(val.isVisibleInEditor)
		end,

		import = function(val, properties, ...)
			val.id = properties["id"]
			val.name = properties["name"]
			val.useForCollision=deseri_prop("Bool",properties["useForCollision"] or "false")
			if properties["isVisibleInEditor"]~=nil then
				val.isVisibleInEditor=deseri_prop("Bool",properties["isVisibleInEditor"])
			end
		end
	},

	["Folder"] = {
		export = function(properties, val, ...)
			class_prop_processor["Instance"].export(properties, val, ...)

			properties["isDataSet"] = tostring(val.isDataSet)
			if val.aclNames then
				properties["aclNames"] = val.aclNames
			end
		end,

		import = function(val, properties, ...)
			class_prop_processor["Instance"].import(val, properties, ...)

			val.isDataSet = deseri_prop("Bool", properties["isDataSet"])
			if properties["aclNames"] then
				val.aclNames = properties["aclNames"]
			end
		end,
	},

	["MovableNode"] = {
		export = function(properties, val, ...)
			class_prop_processor["Instance"].export(properties, val, ...)

			properties["position"] = seri_prop("Vector3", val.position)
			properties["rotation"] = seri_prop("Vector3", val.rotation)
			if val.class ~= "Model" then
				properties["originSize"] = seri_prop("Vector3", val.originSize)
				properties["scale"] = seri_prop("Vector3", val.scale)
			end
			properties["selectable"] = tostring(val.selectable)
			properties["needSync"] = tostring(val.needSync)
			properties["batchType"] = tostring(val.batchType)
			properties["useAnchor"] = tostring(val.useAnchor)
			properties["canAcceptShadow"] = tostring(val.canAcceptShadow)
			properties["canGenerateShadow"] = tostring(val.canGenerateShadow)
			properties["bakeTextureWeight"] = tostring(val.bakeTextureWeight)
		end,

		import = function(val, properties, ...)
			class_prop_processor["Instance"].import(val, properties, ...)
			val.position = deseri_prop("Vector3", properties["position"])
			val.rotation = deseri_prop("Vector3", properties["rotation"])
			val.scale = deseri_prop("Vector3", properties["scale"])
			if not val.scale then
				val.scale = {x = 1,y = 1,z = 1}
			end

			val.originSize = deseri_prop("Vector3", properties["originSize"])
			if not val.originSize then
				local sz = properties["size"]
				if sz then
					local new = deseri_prop("Vector3",sz)
					if check_size_is_modify(new, val.size) then
						val.size = new
						val.originSize = {
							x = val.size.x / val.scale.x,
							y = val.size.y / val.scale.y,
							z = val.size.z / val.scale.z
						}
					end
				else
					val.size = val.scale
					val.originSize = {x = 1,y = 1,z = 1}
				end
			else
				local new = {
					x = val.scale.x * val.originSize.x, 
					y = val.scale.y * val.originSize.y, 
					z = val.scale.z * val.originSize.z
				}
				if check_size_is_modify(new, val.size) then
					val.size = new
				end
			end

			val.selectable = deseri_prop("Bool", properties["selectable"])
			val.needSync = deseri_prop("Bool", properties["needSync"])
			val.batchType = properties["batchType"]
			val.useAnchor = deseri_prop("Bool", properties["useAnchor"])
			val.canAcceptShadow = deseri_prop("Bool", properties["canAcceptShadow"])
			val.canGenerateShadow = deseri_prop("Bool", properties["canGenerateShadow"])
			val.bakeTextureWeight = deseri_prop("Number", properties["bakeTextureWeight"])
		end
	},

	["NullObject"] = {
		export = function(properties, val, ...)
			class_prop_processor["Instance"].export(properties, val, ...)

			properties["position"] = seri_prop("Vector3", val.xform.pos)
			properties["rotation"] = seri_prop("Vector3", val.xform.rotation)
			properties["scale"] = seri_prop("Vector3", val.xform.scale)
			properties["selectable"] = tostring(val.selectable)
		end,

		import = function(val, properties, ...)
			class_prop_processor["Instance"].import(val, properties, ...)
			val.xform = {}
			val.xform.position = deseri_prop("Vector3", properties["position"])
			val.xform.rotation = deseri_prop("Vector3", properties["rotation"])
			val.xform.scale = deseri_prop("Vector3", properties["scale"])
		end
	},

	["VoxelTerrain"] = {
		export = function(properties, val, ...)
			class_prop_processor["Instance"].export(properties, val, ...)

			properties["uniqueKey"] = tostring(val.uniqueKey)
			properties["collisionGroup"] = val.collisionGroup
		end,

		import = function(val, properties, ...)
			class_prop_processor["Instance"].import(val, properties, ...)

			val.uniqueKey = properties["uniqueKey"]
			val.collisionGroup = properties["collisionGroup"]
		end
	},

	["Collision"]={
		export = function(properties, val)
			class_prop_processor["Instance"].export(properties, val)
		--	properties["uniqueKey"] = tostring(val.uniqueKey)
		end,

		import = function(val, properties)
			class_prop_processor["Instance"].import(val, properties)
		--	val.uniqueKey = properties["uniqueKey"]
		end
	},
	["PostProcess"] = {
		export = function(properties, val, ...)
			class_prop_processor["Instance"].export(properties, val, ...)
			properties["enableBloom"] = tostring(val["postProcessBloom"]["enableBloom"])
			properties["fullScreenBloom"] = tostring(val["postProcessBloom"]["fullScreenBloom"])
			properties["ignoreMainLight"] = tostring(val["postProcessBloom"]["ignoreMainLight"])
			properties["bloomIsAttenuation"] = tostring(val["postProcessBloom"]["bloomIsAttenuation"])
			properties["intensity"] = tostring(val["postProcessBloom"]["intensity"])
			properties["threshold"] = tostring(val["postProcessBloom"]["threshold"])
			properties["saturation"] = tostring(val["postProcessBloom"]["saturation"])
			properties["blurType"] = tostring(val["postProcessBloom"]["blurType"])
			properties["gaussianBlurDeviation"] = tostring(val["postProcessBloom"]["gaussianBlurDeviation"])
			properties["gaussianBlurMultiplier"] = tostring(val["postProcessBloom"]["gaussianBlurMultiplier"])
			properties["gaussianBlurSampler"] = tostring(val["postProcessBloom"]["gaussianBlurSampler"])
			properties["iterations"] = tostring(val["postProcessBloom"]["iterations"])
			properties["offset"] = tostring(val["postProcessBloom"]["offset"])
		end,
		import = function(val, properties, ...)
			class_prop_processor["Instance"].import(val, properties, ...)
			val["postProcessBloom"] = {}
			val["postProcessBloom"]["enableBloom"] = deseri_prop("Number", properties["enableBloom"])
			val["postProcessBloom"]["fullScreenBloom"] = deseri_prop("Number", properties["fullScreenBloom"])
			val["postProcessBloom"]["ignoreMainLight"] = deseri_prop("Number", properties["ignoreMainLight"])
			val["postProcessBloom"]["bloomIsAttenuation"] = deseri_prop("Number", properties["bloomIsAttenuation"])                                  
			val["postProcessBloom"]["intensity"] = deseri_prop("Number", properties["intensity"])
			val["postProcessBloom"]["threshold"] = deseri_prop("Number", properties["threshold"])
			val["postProcessBloom"]["saturation"] = deseri_prop("Number", properties["saturation"])
			val["postProcessBloom"]["blurType"] = deseri_prop("Number", properties["blurType"])
			val["postProcessBloom"]["gaussianBlurDeviation"] = deseri_prop("Number", properties["gaussianBlurDeviation"])
			val["postProcessBloom"]["gaussianBlurMultiplier"] = deseri_prop("Number", properties["gaussianBlurMultiplier"])
			val["postProcessBloom"]["gaussianBlurSampler"] = deseri_prop("Number", properties["gaussianBlurSampler"])
			val["postProcessBloom"]["offset"] = deseri_prop("Number", properties["offset"])
		end
	},
	["Fog"] = {
		export = function(properties, val, ...)
			class_prop_processor["Instance"].export(properties, val, ...)
			properties["fogType"] = tostring(val.fogType)
			properties["fogColor"] = seri_prop("Color", val.fogColor)
			properties["density"] = tostring(val.fogDensity)
			properties["fogAlpha"] = tostring(val.fogAlpha)
			properties["fogStart"] = tostring(val.fogStart)
			properties["fogEnd"] = tostring(val.fogEnd)
			properties["showFog"] = tostring(val.showFog)
		end,
		import = function(val, properties, ...)
			class_prop_processor["Instance"].import(val, properties, ...)
			val.fogType = properties["fogType"]
			val.fogColor = deseri_prop("Color", properties["fogColor"])
			val.fogDensity = deseri_prop("Number", properties["density"])
			val.fogAlpha = deseri_prop("Number", properties["fogAlpha"])
			val.fogStart = deseri_prop("Number", properties["fogStart"])
			val.fogEnd = deseri_prop("Number", properties["fogEnd"])
			val.showFog = deseri_prop("Number", properties["showFog"])
		end
	},
	["Decal"] = {
		export = function(properties, val, ...)
			class_prop_processor["Instance"].export(properties, val, ...)

			properties["decalOffset"] = seri_prop("Vector3", val.decalOffset)
			properties["decalColor"] = seri_prop("Color", val.decalColor)
			properties["decalAlpha"] = tostring(val.decalAlpha)
			properties["decalSurface"] = tostring(val.decalSurface)
			properties["decalImageType"] = tostring(val.decalImageType)
			properties["decalTiling"] = seri_prop("Vector3", val.decalTiling)
			properties["decalTexture"] = tostring(val.decalTexture["asset"])
		end,

		import = function(val, properties, ...)
			class_prop_processor["Instance"].import(val, properties, ...)

			val.decalOffset = deseri_prop("Vector3", properties["decalOffset"])
			val.decalColor = deseri_prop("Color", properties["decalColor"])
			val.decalAlpha = deseri_prop("Number", properties["decalAlpha"])
			val.decalSurface = properties["decalSurface"]
			val.decalImageType = properties["decalImageType"]
			val.decalTiling = deseri_prop("Vector3", properties["decalTiling"])
			val.decalTexture = {asset = properties["decalTexture"]}
		end
	},

	["TextDecal"] = {
		export = function(properties, val, ...)
			class_prop_processor["Decal"].export(properties, val, ...)

			properties["textDecalPosition"] = seri_prop("Vector3",val.textDecalPosition)
			properties["textDecalSize"] = seri_prop("Vector3", val.textDecalSize)
			properties["textDecalRotationZ"] = tostring(val.textDecalRotationZ)
			properties["textDecalSurface"] = tostring(val.textDecalSurface)
			properties["textDecalAlpha"] = tostring(val.textDecalAlpha)
			properties["textDecalImageType"] = tostring(val.textDecalImageType)
			properties["textDecalOffset"] = seri_prop("Vector3", val.textDecalOffset)
			properties["textDecalTiling"] = seri_prop("Vector3", val.textDecalTiling)
			properties["textDecalText"] = tostring(val.textDecalText)
			properties["textDecalFontStyle"] = tostring(val.textDecalFontStyle)
			properties["textDecalFontSize"] = tostring(val.textDecalFontSize)
			properties["textDecalAutoScale"] = tostring(val.textDecalAutoScale)
			properties["textDecalAutoTextScale"] = tostring(val.textDecalAutoTextScale)
			properties["textDecalMinAutoTextScale"] = tostring(val.textDecalMinAutoTextScale)
			properties["textDecalTextBoldWeight"] = tostring(val.textDecalTextBoldWeight)
			properties["textDecalTextColor"] = seri_prop("Color",val.textDecalTextColor)
			properties["textDecalBackgroundEnabled"] = tostring(val.textDecalBackgroundEnabled)
			properties["textDecalBackgroundColor"] = seri_prop("Color",val.textDecalBackgroundColor)
			properties["textDecalFrameEnabled"] = tostring(val.textDecalFrameEnabled)
			properties["textDecalFrameColor"] = seri_prop("Color",val.textDecalFrameColor)
			properties["textDecalWordWrapped"] = tostring(val.textDecalWordWrapped)
			properties["textDecalTextWordBreak"] = tostring(val.textDecalTextWordBreak)
			properties["textDecalHorzFormatting"] = tostring(val.textDecalHorzFormatting)
			properties["textDecalVertFormatting"] = tostring(val.textDecalVertFormatting)
			properties["textDecalBorderEnabled"] = tostring(val.textDecalBorderEnabled)
			properties["textDecalBorderWidth"] = tostring(val.textDecalBorderWidth)
			properties["textDecalBorderColor"] = seri_prop("Color",val.textDecalBorderColor)
		end,

		import = function(val, properties, ...)
			class_prop_processor["Decal"].import(val, properties, ...)

			val.textDecalPosition = deseri_prop("Vector3",properties["textDecalPosition"])
			val.textDecalSize = deseri_prop("Vector3",properties["textDecalSize"])
			val.textDecalRotationZ = deseri_prop("Number", properties["textDecalRotationZ"])
			val.textDecalSurface = properties["textDecalSurface"]
			val.textDecalAlpha = deseri_prop("Number", properties["textDecalAlpha"])
			val.textDecalImageType = properties["textDecalImageType"]
			val.textDecalOffset = deseri_prop("Vector3", properties["textDecalOffset"])		
			val.textDecalTiling = deseri_prop("Vector3", properties["textDecalTiling"])
			val.textDecalText = properties["textDecalText"]
			val.textDecalFontStyle = properties["textDecalFontStyle"]
			val.textDecalFontSize = deseri_prop("Number", properties["textDecalFontSize"])
			val.textDecalAutoScale = deseri_prop("Bool",properties["textDecalAutoScale"])
			val.textDecalAutoTextScale = deseri_prop("Number", properties["textDecalAutoTextScale"]) 
			val.textDecalMinAutoTextScale = deseri_prop("Number", properties["textDecalMinAutoTextScale"]) 
			val.textDecalTextBoldWeight = properties["textDecalTextBoldWeight"]
			val.textDecalTextColor = deseri_prop("Color",properties["textDecalTextColor"])
			val.textDecalBackgroundEnabled = deseri_prop("Bool",properties["textDecalBackgroundEnabled"])
			val.textDecalBackgroundColor = deseri_prop("Color",properties["textDecalBackgroundColor"])
			val.textDecalFrameEnabled = deseri_prop("Bool",properties["textDecalFrameEnabled"])
			val.textDecalFrameColor = deseri_prop("Color",properties["textDecalFrameColor"])
			val.textDecalWordWrapped = deseri_prop("Bool",properties["textDecalWordWrapped"])
			val.textDecalTextWordBreak = deseri_prop("Bool",properties["textDecalTextWordBreak"])
			val.textDecalHorzFormatting = properties["textDecalHorzFormatting"]
			val.textDecalVertFormatting = properties["textDecalVertFormatting"]
			val.textDecalBorderEnabled = deseri_prop("Bool",properties["textDecalBorderEnabled"])
			val.textDecalBorderWidth = deseri_prop("Number", properties["textDecalBorderWidth"])
			val.textDecalBorderColor = deseri_prop("Color",properties["textDecalBorderColor"])
		end
	},

	["EffectPart"] = {
		export = function(properties, val, ...)
			class_prop_processor["MovableNode"].export(properties, val, ...)
			properties["visible"] = tostring(val.csgShapeVisible)
			properties["effectFilePath"] = val["csgShapeEffect"]["asset"]
			-- properties["position"] = seri_prop("Vector3", val.transform.pos) 构造时候使用世界坐标
			-- properties["rotation"] = seri_prop("Vector3", val.transform.rotate) 
			properties["scale"] = seri_prop("Vector3", val.scale)

			-- 因为引擎设计不愿意多存一个字节，所以只能兼容处理
			if val.loop.enable then
				properties["loopCount"] = tostring(-val.loop.play_times)
			else
				properties["loopCount"] = tostring(val.loop.play_times)
			end

			properties["loopInterval"] = tostring(val.loop.interval)
			properties["loopReset"] = tostring(val.loop.reset)
			properties["maxViewDistance"]=tostring(val.maxViewDistance)
			
		end,

		import = function(val, properties, ...)
			class_prop_processor["MovableNode"].import(val, properties, ...)

			val.csgShapeVisible = deseri_prop("Bool", properties["visible"])
			val["csgShapeEffect"] = {asset = properties["effectFilePath"]}
			val.transform = {}
			val.transform.pos = deseri_prop("Vector3", properties["localPosition"])
			val.transform.rotate = deseri_prop("Vector3", properties["localRotation"])
			val.transform.scale = deseri_prop("Vector3", properties["scale"])

			val.loop = {}
			local loop_count = deseri_prop("Number", properties["loopCount"]) 
			if loop_count then
				if 0 > loop_count then
					val.loop.enable = true
					val.loop.play_times = -loop_count
				else
					val.loop.enable = false
					val.loop.play_times = loop_count
				end
			end
			val.loop.interval = deseri_prop("Number", properties["loopInterval"])
			val.loop.reset =  deseri_prop("Bool", properties["loopReset"])
			val.maxViewDistance=deseri_prop("Number", properties["maxViewDistance"])
		end
	},

	["AudioNode"] = {
		export = function(properties, val, ...)
			class_prop_processor["MovableNode"].export(properties, val, ...)

			properties["audioFilePath"] = val["sound"]["asset"]

			properties["autoState"] = tostring(val.autoState)
			properties["loopState"] = tostring(val.loopState)
			properties["multiPly"] = tostring(val.playRate)
			properties["losslessDistance"] = tostring(val.losslessDistance)
			properties["maxDistance"] = tostring(val.maxDistance)
			properties["attenuationType"] = val.attenuationType
			properties["volume"] = tostring(val.volume)
		end,

		import = function(val, properties, ...)
			class_prop_processor["MovableNode"].import(val, properties, ...)

			val["sound"] = {asset = properties["audioFilePath"]}

			val.relative_pos = deseri_prop("Vector3", properties["localPosition"])

			val.autoState =  deseri_prop("Bool", properties["autoState"])
			val.loopState =  deseri_prop("Bool", properties["loopState"])
			val.playRate = deseri_prop("Number", properties["multiPly"])
			val.losslessDistance = deseri_prop("Number", properties["losslessDistance"])
			val.maxDistance = deseri_prop("Number", properties["maxDistance"])
			val.attenuationType = properties["attenuationType"]
			val.volume = deseri_prop("Number", properties["volume"])
		end
	},

	["EmptyNode"] = {
		export = function(properties, val, ...)
			class_prop_processor["MovableNode"].export(properties, val, ...)
		end,

		import = function(val, properties, ...)
			class_prop_processor["MovableNode"].import(val, properties, ...)
		end
	},

	["ActorNode"] = {
		export = function(properties, val, ...)
			class_prop_processor["MovableNode"].export(properties, val, ...)
			properties["actorTemplate"] =  val.actorObject.asset
		end,

		import = function(val, properties, ...)
			class_prop_processor["MovableNode"].import(val, properties, ...)
			val.actorObject = {}
			val.actorObject.asset = properties["actorTemplate"]
			val.actorObject.selector = properties["actorTemplate"]
		end
	},

	["MountPoint"] = {
		export = function(properties, val, ...)
			class_prop_processor["NullObject"].export(properties, val, ...)
		end,

		import = function(val, properties, ...)
			class_prop_processor["NullObject"].import(val, properties, ...)
		end
	},
	
	["SceneUI"] = {
		export = function(properties, val, ...)
			class_prop_processor["Instance"].export(properties, val, ...)
			local file = val.layoutFile["asset"]
			local layoutFile = string.sub(file,7,string.len(file))

			properties["uiID"] = val.uiID ~= "" and tostring(val.id) or nil
			properties["isTop"] = tostring(val.isTop)
			properties["isFaceCamera"] = tostring(val.isFaceCamera)
			properties["position"] = seri_prop("Vector3", val.position)
			properties["rotation"] = seri_prop("Vector3", val.rotation)
			properties["size"] = seri_prop("Vector2", val.size)
			properties["rangeDistance"] = tostring(val.rangeDistance)
			properties["layoutFile"] = tostring(layoutFile)
			properties["uiScaleMode"] = val.uiScaleMode and "0" or "1"
			properties["stretch"] = tostring(val.stretch)
			properties["isLock"] = tostring(val.isLock)
		end,

		import = function(val, properties, ...)
			class_prop_processor["Instance"].import(val, properties, ...)
			local file = properties["layoutFile"]
			local pre = "asset/"
			local layoutFile = ""
			local path = Lib.combinePath(Def.PATH_GAME_ASSET,file)
			if lfs.attributes(path, "mode") ~= "file" then
				layoutFile = file
			else
				layoutFile = pre..file
			end
			val.uiID = properties["uiID"]
			val.isTop = deseri_prop("Bool", properties["isTop"])
			val.isFaceCamera = deseri_prop("Bool", properties["isFaceCamera"])
			val.position = deseri_prop("Vector3", properties["position"])
			val.rotation = deseri_prop("Vector3", properties["rotation"])
			val.size = deseri_prop("Vector2", properties["size"])
			val.rangeDistance = deseri_prop("Number", properties["rangeDistance"])
			val.layoutFile = {asset = layoutFile}
			val.rangeDistance = deseri_prop("Number", properties["rangeDistance"])
			val.layoutFile = {asset = properties["layoutFile"]}
			val.uiScaleMode = properties["uiScaleMode"] == "0"
			val.stretch = deseri_prop("Bool", properties["stretch"])
			val.isLock = deseri_prop("Bool", properties["isLock"])
		end
	},

	["Object"] = {
		export = function(properties, val, ...)
			class_prop_processor["MovableNode"].export(properties, val, ...)
		end,

		import = function(val, properties, ...)
			class_prop_processor["MovableNode"].import(val, properties, ...)
		end
	},

	["Entity"] = {
		export = function(properties, val, ...)
			class_prop_processor["Object"].export(properties, val, ...)

			properties["collisionGroup"] = val.collisionGroup
		end,

		import = function(val, properties, ...)
			class_prop_processor["Object"].import(val, properties, ...)

			val.collisionGroup = properties["collisionGroup"]
		end
	},

	["DropItem"] = {
		export = function(properties, val, ...)
			class_prop_processor["Object"].export(properties, val, ...)
			properties["fixRotation"] = tostring(not val.fixRotation)
		end,

		import = function(val, properties, ...)
			class_prop_processor["Object"].import(val, properties, ...)
			val.fixRotation = not deseri_prop("Bool", properties["fixRotation"])
		end
	},
	
	["BasePart"] = {
		export = function(properties, val, ...)
			class_prop_processor["MovableNode"].export(properties, val, ...)

			properties["density"] = tostring(val.density)
			properties["collisionUniqueKey"] = tostring(val.collisionUniqueKey)
			properties["restitution"] = tostring(val.restitution)
			properties["friction"] = tostring(val.friction)
			properties["lineVelocity"] = seri_prop("Vector3", val.lineVelocity)
			properties["angleVelocity"] = seri_prop("Vector3", val.angleVelocity)
			properties["partNavMeshType"] = tostring(val.partNavMeshType)
			properties["useGravity"] = tostring(val.useGravity)
			properties["useCollide"] = tostring(val.useCollide)
			properties["staticObject"] = tostring(val.staticObject)
			properties["cameraCollideEnable"] = tostring(val.cameraCollideEnable)
			if val.staticBatchNo then
				properties["staticBatchNo"] = tostring(val.staticBatchNo)
			end
			properties["collisionGroup"] = val.collisionGroup
		end,

		import = function(val, properties, ...)
			class_prop_processor["MovableNode"].import(val, properties, ...)
			
			val.density = deseri_prop("Number", properties["density"])
			val.collisionUniqueKey = properties["collisionUniqueKey"]
			val.restitution = deseri_prop("Number", properties["restitution"])
			val.friction = deseri_prop("Number", properties["friction"])
			val.lineVelocity = deseri_prop("Vector3", properties["lineVelocity"])
			val.angleVelocity = deseri_prop("Vector3", properties["angleVelocity"])
			val.partNavMeshType =  tostring(properties["partNavMeshType"])
			val.useGravity = deseri_prop("Bool", properties["useGravity"])
			val.useCollide = deseri_prop("Bool", properties["useCollide"])
			val.staticObject = deseri_prop("Bool", properties["staticObject"])
			val.cameraCollideEnable = deseri_prop("Bool", properties["cameraCollideEnable"])
			if properties["staticBatchNo"] then
				val.staticBatchNo = properties["staticBatchNo"]
			else
				val.staticBatchNo = nil
			end
			val.collisionGroup = properties["collisionGroup"]
		end
	},

	["CSGShape"] = {
		export = function(properties, val, ...)
			class_prop_processor["BasePart"].export(properties, val, ...)

			properties["isLockedInEditor"] = tostring(val.isLockedInEditor)
			properties["isVisibleInEditor"] = tostring(val.isVisibleInEditor)
			--properties["mass"] = tostring(val.mass)
			properties["massCenter"] = seri_prop("Vector3", val.massCenter)
			properties["materialColor"] = seri_prop("Color", val.material.color)
			properties["materialTexture"] = seri_prop("PartTexture", val.material.texture)
			properties["materialOffset"] = seri_prop("Vector3", val.material.offset)
			properties["materialAlpha"] = tostring(val.material.alpha)
			properties["useTextureAlpha"] = tostring(val.material.useTextureAlpha)
			properties["discardAlpha"] = tostring(val.material.discardAlpha)
			properties["booleanOperation"] = tostring(val.booleanOperation)
			properties["customThreshold"] = tostring(val.customThreshold)
			properties["bloom"] = tostring(val.bloom)
			properties["collisionFidelity"] = val.collisionFidelity	
			if val.materialData.materialJson~="" then
				properties["material"]=val.materialData.materialJson
			end
		end,

		import = function(val, properties, ...)
			class_prop_processor["BasePart"].import(val, properties, ...)

			val.isLockedInEditor = deseri_prop("Bool", properties["isLockedInEditor"])
			val.isVisibleInEditor = deseri_prop("Bool", properties["isVisibleInEditor"])
			val.isVisibleInTree =  deseri_prop("Bool", properties["isVisibleInTree"])
			--val.mass = deseri_prop("Number", properties["mass"])
			val.massCenter = deseri_prop("Vector3", properties["massCenter"])
			val.material = {}
			val.material.color = deseri_prop("Color", properties["materialColor"])
			val.material.texture = deseri_prop("PartTexture", properties["materialTexture"])
			val.material.offset = deseri_prop("Vector3", properties["materialOffset"])
			val.material.alpha = deseri_prop("Number", properties["materialAlpha"])
			val.material.useTextureAlpha = deseri_prop("Bool", properties["useTextureAlpha"])
			val.material.discardAlpha = deseri_prop("Number", properties["discardAlpha"])
			val.booleanOperation = deseri_prop("Number", properties["booleanOperation"])
			val.customThreshold = deseri_prop("Number", properties["customThreshold"])
			val.bloom = deseri_prop("Bool", properties["bloom"])
			val.collisionFidelity = properties["collisionFidelity"]
			if(properties["material"] and properties["material"] ~="") then
				val.materialData={}
				val.materialData.materialJson=properties["material"]	
			end
		end
	},
	
	["MeshPart"] = {
		export = function(properties, val, ...)
			class_prop_processor["CSGShape"].export(properties, val, ...)
			properties["mesh"] = tostring(val.mesh)
			properties["metalness"] = tostring(val.metalness)
			properties["roughness"] = tostring(val.roughness)
			properties["autoAnchor"] = tostring(val.autoAnchor)
			properties["originAnchor"] = tostring(val.originAnchor)
			properties["localAnchorPoint"] = seri_prop("Vector3", val.localAnchorPoint)
			properties["btsKey"] = tostring(val.btsKey)
			if val.customShapeData then
				properties["customShapeData"]=val.customShapeData
			end
			local lodModelItems={}
			if val.replaceLodModel ~=nil then
				properties["useLodModel"]=tostring(val.replaceLodModel)
			end
			if val.lodData then
				if(val.lodData.lodModelItem) then
					local lodDataItem=val.lodData.lodModelItem
					for k,v in pairs(lodDataItem) do
						table.insert(lodModelItems,seri_prop("LodData",v))
					end
					properties["lodData"]={lodModelItem=lodModelItems}
					properties["lodGroup"]=seri_prop("LodGroup",val.lodData.lodModelItem)
				end
			end
		end,

		import = function(val, properties, ...)
			class_prop_processor["CSGShape"].import(val, properties, ...)
			val.mesh = properties["mesh"]
			val.metalness = deseri_prop("Number", properties["metalness"])
			val.roughness = deseri_prop("Number", properties["roughness"])
			val.autoAnchor = deseri_prop("Bool", properties["autoAnchor"])
			val.originAnchor = deseri_prop("Bool", properties["originAnchor"])
			val.localAnchorPoint = deseri_prop("Vector3", properties["localAnchorPoint"])
			val.mesh_selector = {}
			val.mesh_selector.asset = properties["mesh"]
			val.mesh_selector.selector = properties["mesh"]
			val.btsKey = properties["btsKey"]
			if properties["customShapeData"] then
				val.customShapeData=properties["customShapeData"]
			end		
			if properties["useLodModel"]~=nil then 
				val.replaceLodModel=deseri_prop("Bool",properties["useLodModel"])
			end
			if properties.LodGroup then
				val.lodGroup=properties.lodGroup
			end
			if properties.lodData then
				if properties.lodData.lodModelItem then
					local lodDataItems={}
					local items=properties.lodData.lodModelItem
					for k,v in pairs(items) do
						local tmpLodData=deseri_prop("LodData",v)
						table.insert(lodDataItems,tmpLodData)
					end
					val.lodData={lodModelItem=lodDataItems}
				end
			end
					
		end
	},

	["RegionPart"] = {
		export = function(properties, val, ...)
			class_prop_processor["MovableNode"].export(properties, val, ...)
			properties["cfgName"] = val.cfgName
		end,

		import = function(val, properties, ...)
			class_prop_processor["MovableNode"].import(val, properties, ...)

			val.cfgName = properties["cfgName"]
		end
	},


	["Part"] = {
		export = function(properties, val, ...)
			class_prop_processor["CSGShape"].export(properties, val, ...)

			properties["shape"] = val.shape
			properties["btsKey"] = val.btsKey
		end,

		import = function(val, properties, ...)
			class_prop_processor["CSGShape"].import(val, properties, ...)

			val.shape = properties["shape"]
			val.btsKey = properties["btsKey"]
		end
	},

	["PartOperation"] = {
		export = function(properties, val, ...)
			class_prop_processor["CSGShape"].export(properties, val, ...)
	
			properties["useOriginalColor"] = tostring(val.useOriginalColor)
			properties["mergeShapesDataKey"] = (val.mergeShapesDataKey)
			properties["btsKey"] = tostring(val.btsKey)
		end,
	
		import = function(val, properties, ...)
			class_prop_processor["CSGShape"].import(val, properties, ...)
	
			val.useOriginalColor = deseri_prop("Bool", properties["useOriginalColor"])
			val.mergeShapesDataKey = (properties["mergeShapesDataKey"])
			val.btsKey = properties["btsKey"]
		end
	  },

	["Force"] = {
		export = function(properties, val, ...)
			class_prop_processor["Instance"].export(properties, val, ...)

			properties["useRelativeForce"] = tostring(val.useRelativeForce)
			properties["force"] = seri_prop("Vector3", val["force"])
		end,

		import = function(val, properties, ...)
			class_prop_processor["Instance"].import(val, properties, ...)

			val.useRelativeForce =  deseri_prop("Bool", properties["useRelativeForce"])
			val.force = deseri_prop("Vector3", properties["force"])
		end
	},

	["Torque"] = {
		export = function(properties, val, ...)
			class_prop_processor["Instance"].export(properties, val, ...)

			properties["useRelativeTorque"] = tostring(val.useRelativeTorque)
			properties["torque"] = seri_prop("Vector3", val["torque"])
		end,

		import = function(val, properties, ...)
			class_prop_processor["Instance"].import(val, properties, ...)
			
			val.useRelativeTorque =  deseri_prop("Bool", properties["useRelativeTorque"])
			val.torque = deseri_prop("Vector3", properties["torque"])
		end
	},

	["ConstraintBase"] = {
		export = function(properties, val, ...)
			class_prop_processor["Instance"].export(properties, val, ...)

			properties["slavePartID"] = val.slavePartID
			properties["slaveLocalPos"] = seri_prop("Vector3",val.slaveLocalPos)
			properties["masterLocalPos"] = seri_prop("Vector3",val.masterLocalPos)
			properties["collision"] = tostring(val.collision)
		end,

		import = function(val, properties, ...)
			class_prop_processor["Instance"].import(val, properties, ...)

			val.slavePartID = properties["slavePartID"]
			val.slaveLocalPos = deseri_prop("Vector3", properties["slaveLocalPos"])
			val.masterLocalPos = deseri_prop("Vector3", properties["masterLocalPos"])
			val.collision =  deseri_prop("Bool", properties["collision"])
		end

	},

	["FixedConstraint"] = {
		export = function(properties, val, ...)
			class_prop_processor["ConstraintBase"].export(properties, val, ...)
		end,

		import = function(val, properties, ...)
			class_prop_processor["ConstraintBase"].import(val, properties, ...)
		end
	},

	["HingeConstraint"] = {
		export = function(properties, val, ...)
			class_prop_processor["ConstraintBase"].export(properties, val, ...)

			properties["visible"] = tostring(val.visible)
			properties["useSpring"] = tostring(val.useSpring)
			properties["stiffness"] = tostring(val.stiffness)
			properties["damping"] = tostring(val.damping)
			properties["springTargetAngle"] = tostring(val.springTargetAngle)
			properties["useMotor"] = tostring(val.useMotor)
			properties["motorTargetAngleVelocity"] = tostring(val.motorTargetAngleVelocity)
			properties["motorForce"] = tostring(val.motorForce)
			properties["useAngleLimit"] = tostring(val.useAngleLimit)
			properties["angleUpperLimit"] = tostring(val.angleUpperLimit)
			properties["angleLowerLimit"] = tostring(val.angleLowerLimit)
		end,

		import = function(val, properties, ...)
			class_prop_processor["ConstraintBase"].import(val, properties, ...)
			
			val.useSpring =  deseri_prop("Bool", properties["useSpring"])
			val.stiffness = deseri_prop("Number", properties["stiffness"])
			val.damping = deseri_prop("Number", properties["damping"])
			val.springTargetAngle = deseri_prop("Number", properties["springTargetAngle"])
			val.useMotor =  deseri_prop("Bool", properties["useMotor"])
			val.motorTargetAngleVelocity = deseri_prop("Number", properties["motorTargetAngleVelocity"])
			val.motorForce = deseri_prop("Number", properties["motorForce"])
			val.visible =  deseri_prop("Bool", properties["visible"])
			val.useAngleLimit =  deseri_prop("Bool", properties["useAngleLimit"])
			val.angleUpperLimit =  deseri_prop("Number", properties["angleUpperLimit"])
			val.angleLowerLimit =  deseri_prop("Number", properties["angleLowerLimit"])
		end
	},

	["RodConstraint"] = {
		export = function(properties, val, ...)
			class_prop_processor["ConstraintBase"].export(properties, val, ...)

			properties["radius"] = tonumber(tostring(val.radius))
			properties["length"] = tonumber(tostring(val.length))
			properties["visible"] = tostring(val.visible)
			properties["fixedJustify"] = tostring(val.fixedJustify)
			properties["color"] = seri_prop("Color", val.color)
		end,

		import = function(val, properties, ...)
			class_prop_processor["ConstraintBase"].import(val, properties, ...)

			val.radius = properties["radius"]
			val.length = properties["length"]
			val.visible =  deseri_prop("Bool", properties["visible"])
			val.fixedJustify =  deseri_prop("Bool", properties["fixedJustify"])
			val.color = deseri_prop("Color", properties["color"])
		end
	},

	["SpringConstraint"] = {
		export = function(properties, val, ...)
			class_prop_processor["ConstraintBase"].export(properties, val, ...)

			properties["radius"] = tostring(val.radius)
			properties["length"] = tostring(val.length)
			properties["visible"] = tostring(val.visible)
			properties["fixedJustify"] = tostring(val.fixedJustify)
			properties["thickness"] = tostring(val.thickness)
			properties["coil"] = tostring(val.coil)
			properties["color"] = seri_prop("Color", val.color)
			properties["stiffness"] = tostring(val.stiffness)
			properties["damping"] = tostring(val.damping)
		end,

		import = function(val, properties, ...)
			class_prop_processor["ConstraintBase"].import(val, properties, ...)

			val.radius = deseri_prop("Number", properties["radius"])
			val.length = deseri_prop("Number", properties["length"])
			val.visible =  deseri_prop("Bool", properties["visible"])
			val.fixedJustify =  deseri_prop("Bool", properties["fixedJustify"])
			val.thickness = deseri_prop("Number", properties["thickness"])
			val.coil = deseri_prop("Number", properties["coil"])
			val.color = deseri_prop("Color", properties["color"])
			val.stiffness = deseri_prop("Number", properties["stiffness"])
			val.damping = deseri_prop("Number", properties["damping"])
		end
	},

	["RopeConstraint"] = {
		export = function(properties, val, ...)
			class_prop_processor["ConstraintBase"].export(properties, val, ...)

			properties["radius"] = tostring(val.radius)
			properties["length"] = tostring(val.length)
			properties["visible"] = tostring(val.visible)
			properties["color"] = seri_prop("Color", val.color)
		end,

		import = function(val, properties, ...)
			class_prop_processor["ConstraintBase"].import(val, properties, ...)

			val.radius = deseri_prop("Number", properties["radius"])
			val.length = deseri_prop("Number", properties["length"])
			val.visible = deseri_prop("Bool", properties["visible"])
			val.color = deseri_prop("Color", properties["color"])
		end
	},

	["SliderConstraint"] = {
		export = function(properties, val, ...)
			class_prop_processor["ConstraintBase"].export(properties, val, ...)

			properties["visible"] = tostring(val.visible)
			properties["upperLimit"] = tostring(val.upperLimit)
			properties["lowerLimit"] = tostring(val.lowerLimit)
		end,

		import = function(val, properties, ...)
			class_prop_processor["ConstraintBase"].import(val, properties, ...)

			val.visible = deseri_prop("Bool", properties["visible"])
			val.upperLimit = deseri_prop("Number", properties["upperLimit"])
			val.lowerLimit = deseri_prop("Number", properties["lowerLimit"])
		end
	},

	["Model"] = {
		export = function(properties, val, ...)
			class_prop_processor["MovableNode"].export(properties, val, ...)
		end,

		import = function(val, properties, ...)
			class_prop_processor["MovableNode"].import(val, properties, ...)
		end
	},

	["Light"] = {
		export = function(properties, val, ...)
			class_prop_processor["MovableNode"].export(properties, val, ...)
			properties["lightType"] = tostring(val.lightType)
			properties["skyColor"] = seri_prop("Color",val.skyColor)
			properties["skyLineColor"] = seri_prop("Color",val.skyLineColor)
			properties["lightColor"] = seri_prop("Color",val.lightColor)
			properties["lightBrightness"] = tostring(val.lightBrightness)
			properties["lightRange"] = tostring(val.lightRange)
			properties["lightAngle"] = tostring(val.lightAngle)
			properties["lightLength"] = tostring(val.lightLength)
			properties["lightWidth"] = tostring(val.lightWidth)
			properties["lightActived"] = tostring(val.lightActived)
			properties["ID"] = tostring(val.ID)
			properties["shadowsType"] = tostring(val.shadows.shadowsType)
			properties["shadowsIntensity"] = tostring(val.shadows.shadowsIntensity)
			properties["shadowsOffset"] = tostring(val.shadows.shadowsOffset)
			properties["shadowsPresicion"] = tostring(val.shadows.shadowsPresicion)
			properties["shadowsDistance"] = tostring(val.shadows.shadowsDistance)
		end,

		import = function(val, properties, ...)
			class_prop_processor["MovableNode"].import(val, properties, ...)
			val.lightType = properties["lightType"]
			val.skyColor = deseri_prop("Color",properties["skyColor"])
			val.skyLineColor = deseri_prop("Color",properties["skyLineColor"])
			val.lightColor = deseri_prop("Color",properties["lightColor"])
			val.lightBrightness = deseri_prop("Number", properties["lightBrightness"])
			val.lightRange = deseri_prop("Number", properties["lightRange"])
			val.lightAngle = deseri_prop("Number", properties["lightAngle"])
			val.lightLength = deseri_prop("Number", properties["lightLength"])
			val.lightWidth = deseri_prop("Number", properties["lightWidth"])
			val.ID = deseri_prop("Number", properties["ID"])
			val.lightActived = deseri_prop("Bool",properties["lightActived"])
			local shadows = {}
			shadows.shadowsType = properties["shadowsType"]
			shadows.shadowsIntensity = deseri_prop("Number", properties["shadowsIntensity"])
			shadows.shadowsOffset = deseri_prop("Number", properties["shadowsOffset"])
			shadows.shadowsPresicion = properties["shadowsPresicion"]
			shadows.shadowsDistance = deseri_prop("Number", properties["shadowsDistance"])
			val.shadows = shadows
		end
	},
}

local extern = {}	-- [class] = {export = {}, import = {}}}

for class, v in pairs(class_prop_processor) do
	local export = v.export
	local import = v.import

	v.export = function(properties, val, customProperties)
		export(properties, val, customProperties)

		-- extern
		local funcs = extern[class] and extern[class].export
		for _, func in ipairs(funcs or {}) do
			func(customProperties, val)
		end
	end

	v.import = function(val, properties, customProperties)
		import(val, properties, customProperties)

		-- extern
		local funcs = extern[class] and extern[class].import
		for _, func in ipairs(funcs or {}) do
			func(val, customProperties)
		end
	end
end

local function export_inst(val, exclude_children)
	local ret = {
		["class"] = val.class,
		["config"] = val.config,
		["properties"] = {},
		["customProperties"] = {}
	}
	local properties = ret.properties
	local processor = assert(class_prop_processor[val.class].export, val.class)
	processor(properties, val, ret.customProperties)

	if val.AddCustom then
		ret["attributes"] = {}
		for _,attr in pairs(val.AddCustom.attrs) do
			local obj_type = attr.val["__OBJ_TYPE"]
			if (obj_type == "T_String") then
				ret.attributes[attr.key] = tostring(attr.val.rawval)
			elseif(obj_type == "T_Bool") then
				ret.attributes[attr.key] = tostring(attr.val.rawval)
			elseif(obj_type == "T_Double") then
				ret.attributes[attr.key] = tostring(attr.val.rawval)
			elseif(obj_type == "T_Int") then
				ret.attributes[attr.key] = tostring(attr.val.rawval)
			elseif(obj_type == "T_Vector2") then
				ret.attributes[attr.key] = seri_prop("Vector2",attr.val.rawval)
			elseif(obj_type == "T_Vector3") then
				ret.attributes[attr.key] = seri_prop("Vector3",attr.val.rawval)
			elseif(obj_type == "T_Time") then
				ret.attributes[attr.key] = tostring(attr.val.rawval.value)
			elseif(obj_type == "T_Percentage") then
				ret.attributes[attr.key] = tostring(attr.val.rawval.value)
			elseif(obj_type == "T_Color") then
				ret.attributes[attr.key] = seri_prop("Color",attr.val.rawval)
			end
		end
	end

	if next(val.children) and not exclude_children then
		ret.children = {}
		for _, child in ipairs(val.children) do
			table.insert(ret.children, export_inst(child))
		end
	end

	local inst = IWorld:get_instance(math.tointeger(val.id))
	if inst then
		local name = next(ret.properties)
		repeat
			if not name then
				break
			end
			if not inst:isPropertyDirty(name) then
				ret.properties[name] = nil
			end
			name = next(ret.properties, name)
		until(false)
	end

	return ret
end

local function import_inst(item)
	local class = assert(item.class)
	local type = string.format("Instance_%s", class)
	assert(Meta:meta(type), type)

	local ret = {
		[Def.OBJ_TYPE_MEMBER] = type,
		class = class,
		children = {},
		config = item.config
	}

	if class == "PartOperation" then
		local key = item.properties.mergeShapesDataKey
		local path = Lib.combinePath(Def.PATH_MERGESHAPESDATA, string.format("%s.json",key))
		local data = Lib.read_json_file(path)

		ret.componentList = {}
		if nil ~= data and nil ~= data.basicShapesData then
			for _,child in ipairs(data.basicShapesData) do
				table.insert(ret.componentList, import_inst(child))
			end
		end
	end

	-- properties
	local processor = assert(class_prop_processor[class].import, class)
	processor(ret, item.properties, item.customProperties or {})

  -- attributes
  local attributes22 = item.attributes
  if attributes22 then
    ret.AddCustom = {}
    ret.AddCustom.attrs = {}
    for k,v in pairs(attributes22) do
      table.insert(ret.AddCustom.attrs, {
        key = tostring(k),
        val = {
          __OBJ_TYPE = "T_String",
          rawval = tostring(v)
        }
      })
    end
  end

	-- children
	if item.children then
		for _, child in ipairs(item.children) do
			table.insert(ret.children, import_inst(child))
		end
	end

	return ret
end

local function calc_min_pos(pos, size, side)
	local Direction = {
		NONE = 0, UP = 1, DOWN = 2, LEFT = 3, RIGHT = 4, FRONT = 5, BACK = 6
	}

	local function CalcPositionRelations(side)
		if side.x ~= 0 then
			return side.x > 0 and Direction.LEFT or Direction.RIGHT
		end
		if side.y ~= 0 then
			return side.y > 0 and Direction.DOWN or Direction.UP
		end
		if side.z ~= 0 then
			return side.z > 0 and Direction.BACK or Direction.FRONT
		end
		return Direction.NONE
	end

    local box_x, box_y, box_z = size.x, size.y, size.z
    if box_x == 1 and box_y == 1 and box_z == 1 then
        return pos
    end
    local dir = CalcPositionRelations(side)
    local minPosition = {}
    minPosition.x = pos.x
    minPosition.y = pos.y
    minPosition.z = pos.z
    if dir == Direction.UP or dir == Direction.DOWN then
        --  ???  x ??  z
        minPosition.x = pos.x - (box_x == 2 and 0 or math.floor(box_x / 2))
        minPosition.z = pos.z - (box_z == 2 and 0 or math.floor(box_z / 2))
        if dir == Direction.UP then
            minPosition.y = minPosition.y - box_y + 1
        end
    elseif dir == Direction.LEFT or dir == Direction.RIGHT then
        --  ???  z ??  y
        minPosition.y = pos.y - (box_y == 2 and 0 or math.floor(box_y / 2))
        minPosition.z = pos.z - (box_z == 2 and 0 or math.floor(box_z / 2))
        if dir == Direction.RIGHT then
            minPosition.x = minPosition.x - box_x + 1
        end
    elseif dir == Direction.FRONT or dir == Direction.BACK then
        --??? x  y
        minPosition.x = pos.x - (box_x == 2 and 0 or math.floor(box_x / 2))
        minPosition.y = pos.y - (box_y == 2 and 0 or math.floor(box_y / 2))
        if dir == Direction.FRONT then
            minPosition.z = minPosition.z - box_z + 1
        end
    end
    return minPosition
end

local function inject(class, export, import)
	extern[class] = extern[class] or { export = {}, import = {}}
	table.insert(extern[class].export, export)
	table.insert(extern[class].import, import)
end

local function raw_check_inst(list_inst)
	local list_check_obj = {}
	if list_inst then
		for _,val in ipairs(list_inst) do
			if val.properties then
				list_check_obj[val.properties.id] = val
			end
		end
	end
	return function(obj)
		local op = obj.properties 
		if op then
			local mt = list_check_obj[op.id]
			if mt then
				for k,v in pairs(mt.properties) do
					if not op[k] then
						obj.properties[k] = v
					end
				end
			end
		end
		return obj
	end
end

return {
	import_inst = import_inst,
	export_inst = export_inst,

	deseri_prop = deseri_prop,
	seri_prop = seri_prop,

	calc_min_pos = calc_min_pos,
	raw_check_inst = raw_check_inst,
	inject = inject
}
