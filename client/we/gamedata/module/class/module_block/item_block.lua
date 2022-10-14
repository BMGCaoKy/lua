local Cjson = require "cjson"
local Lfs = require "lfs"
local Def = require "we.def"
local Seri = require "we.gamedata.seri"
local ItemDataUtils = require "we.gamedata.item_data_utils"
local Converter = require "we.gamedata.export.data_converter"
local ItemBase = require "we.gamedata.module.class.item_base"
local PropImport = require "we.gamedata.module.prop_import"
local Meta = require "we.gamedata.meta.meta"
local Lang = require "we.gamedata.lang"
local Setting = require "common.setting"
local ModuleRequest = require "we.proto.request_module"

local M = Lib.derive(ItemBase)

local MODULE_NAME = "block"
local ITEM_TYPE = "BlockCfg"
local PATH_DATA_DIR = Lib.combinePath(Def.PATH_GAME, string.format("plugin/%s/%s", Def.DEFAULT_PLUGIN, MODULE_NAME))

local function convert_asset(path, item)
	if path then
		local first_str = string.sub(path, 1, 1)
		if first_str == "@" then
			path = string.sub(path, 2)
		elseif first_str == "/" then
			path = "plugin/myplugin" .. path
		else
			path = Lib.combinePath("plugin/myplugin/block", item:id(), path)
		end
		return { asset = path }
	end
end

function M:update_props_cache(rawval)
	rawval = rawval or self:val()

	self._props = {
		["name"] = function()
			return rawval.name and rawval.name.value or "anonymous"
		end,
		["icon"] = function()
			-- todo, 不应该用 Setting，要根据 rawval 来设置
			-- 先不改了，之后方块会用 3D 来渲染
			local setting = Setting:fetch("block", string.format("%s/%s", Def.DEFAULT_PLUGIN, self:id()))
			if setting == nil then
				return ""
			end
			local icon = nil

			repeat
				if setting.defaultTexture then
					icon = setting.defaultTexture
					local icon2 = setting._defaultTexture
					if type(icon2) == "string" then
						if string.sub(icon2, 1, 1) == "@" and string.sub(icon2, 2, 6) ~= "asset" then
							icon = "asset/" .. icon
						end
					end
				elseif setting.quads and setting.quads[1] and setting.quads[1].texture then
					icon = setting.quads[1].texture
					local icon2 = setting.quads_[1].texture
					if type(icon2) == "string" then
						if string.sub(icon2, 1, 1) == "@" and string.sub(icon2, 2, 6) ~= "asset" then
							icon = "asset/" .. icon
						end
					end
				else
					icon = setting.texture and setting.texture[3]
					local icon2 = setting._texture and setting._texture[3]
					if type(icon2) == "string" then
						if string.sub(icon2, 1, 1) == "@" and string.sub(icon2, 2, 6) ~= "asset" then
							icon = "asset/" .. icon
						end
					end
				end

			until(true)
			return (icon and icon ~= "") and Lib.combinePath(Def.PATH_GAME, icon) or ""
		end
	}

	local key, val = next(self._props)
	while(key) do
		if type(val) == "function" then
			self._props[key] = val()
		end
		assert(type(self._props[key]) == "string", key)
		key, val = next(self._props, key)
	end
end


M.config = {
	{
		key = "setting.json",
	
		reader = function(item_name, raw)
			local path = Lib.combinePath(PATH_DATA_DIR, item_name, "setting.json")
			return Lib.read_file(path, raw)
		end,

		import = function(content, ref, item)
			local props = {
				collisionBoxes			= PropImport.original,
				spring					= PropImport.original,
				fall					= PropImport.original,
				candrop					= PropImport.original,
				canClick				= PropImport.original,
				maxFallSpee				= PropImport.original,
				canSwim					= PropImport.original,
				recycle					= PropImport.original,
				recycleTime				= PropImport.Time,
				placeBlockSound			= PropImport.CastSound,
				breakBlockSound			= PropImport.CastSound,
				onBuff					= PropImport.original,
				inBuff					= PropImport.original,
				jumpBuff				= PropImport.original,
				runBuff					= PropImport.original,
				sprintBuff				= PropImport.original,
				clickChangeBlock		= PropImport.original
			}

			local setting = Setting:fetch("block", string.format("%s/%s", Def.DEFAULT_PLUGIN, item:id()))
			local ok, setting2 = pcall(Cjson.decode, content)
			if not ok then
				ModuleRequest.request_item_error(Def.ERROR_CODE.TYPE_ERROR, item:game_dir())
				goto Exit0
			end
			for k, v in pairs(setting) do
				if type(props[k]) == "function" then
					ref[k] = props[k](v, item)
				end
			end
			--[[上面遍历引擎数据一对一转成编辑器数据，避免写很多if，
			当引擎数据与编辑器数据的关系是一对多或多对一或多对多时，用下面的写法]]
			ref.isOpaqueFullCube = setting.isOpaqueFullCube

			ref.maxFallSpeed = setting.maxFallSpeed and setting.maxFallSpeed * 20
			ref.climbSpeed = setting.climbSpeed and setting.climbSpeed * 20
			ref.maxSpeed = setting.maxSpeed and setting.maxSpeed * 20

			if setting.dropSelf then
				ref.dropSelf = {
					canDropSelf = setting.dropSelf,
					dropCount = setting.dropCount
				}
			else
				ref.dropSelf = { canDropSelf = false }
			end
			if setting.breakTime then
				ref.canBreak = setting.breakTime > 0
				ref.breakTime = PropImport.Time(setting.breakTime)
			end
			if setting.texture then
				ref.textures = {
					down	= convert_asset(setting2.texture[1], item),
					up		= convert_asset(setting2.texture[2], item),
					front	= convert_asset(setting2.texture[3], item),
					back	= convert_asset(setting2.texture[4], item),
					left	= convert_asset(setting2.texture[5], item),
					right	= convert_asset(setting2.texture[6], item)
				}
			end
			if type(setting.quads) == "table" and #setting.quads > 0 then
				ref.isQuad = true
			end
			if setting.dropItem then
				ref.dropItems = setting.dropItem
			end

			if not ref.name then
				local trans_key = item:module_name() .. "_" .. item:id()
				ref.name = PropImport.Text(trans_key)
			end

			::Exit0::

			return ref
		end,

		--val:编辑器数据, content：引擎数据
		export = function(rawval, content)
			local meta = Meta:meta(ITEM_TYPE)
			local val = meta:ctor(rawval)

			local ret
			if content then
				ret = Cjson.decode(content)
			else
				ret = {}
			end

			ret.collisionBoxes = val.collisionBoxes
			ret.spring = val.spring
			local buff_list = { "jumpBuff", "runBuff", "sprintBuff" }
			for _, buff in ipairs(buff_list) do
				ret[buff] = {}
				for _, v in ipairs(val[buff] or {}) do
					if v ~= "" then
						table.insert(ret[buff], v)
					end
				end
				if #ret[buff] == 0 then
					ret[buff] = nil
				end
			end

			ret.onBuff = function()
				if val.onBuff and val.onBuff ~= "" then
					return val.onBuff
				end
			end
			ret.inBuff = function()
				if val.inBuff and val.inBuff ~= "" then
					return val.inBuff
				end
			end
			ret.fall = val.fall
			ret.candrop = val.candrop
			ret.canSwim = val.canSwim
			ret.canClick = val.canClick
			ret.maxSpeed = val.maxSpeed / 20
			ret.climbSpeed = val.climbSpeed / 20
			ret.maxFallSpeed = val.maxFallSpeed / 20
			ret.isOpaqueFullCube = function()
				if val.isOpaqueFullCube then
					return nil
				else
					return val.isOpaqueFullCube
				end
			end
			ret.clickChangeBlock = (val.canClick == true and val.clickChangeBlock ~= "") and val.clickChangeBlock or nil
			ret.breakTime = function()
				return val.canBreak and val.breakTime.value
			end

			ret.texture = {
				Converter(val.textures.down, "add_asset"),
				Converter(val.textures.up, "add_asset"),
				Converter(val.textures.front, "add_asset"),
				Converter(val.textures.back, "add_asset"),
				Converter(val.textures.left, "add_asset"),
				Converter(val.textures.right, "add_asset")
			}

			--dropSelf
			ret.dropSelf = val.dropSelf.canDropSelf
			ret.dropCount = val.dropSelf.dropCount

			ret.dropItem = #val.dropItems > 0 and val.dropItems or nil

			ret.placeBlockSound = Converter(val.placeBlockSound)
			ret.breakBlockSound = Converter(val.breakBlockSound)
			ret.recycle = val.recycle
			ret.recycleTime = val.recycleTime.value

			local key, val = next(ret)
			while(key) do
				if type(val) == "function" then
					ret[key] = val()
				end
				key, val = next(ret, key)
			end

			return ret
		end,

		writer = function(item_name, data, dump)
			assert(type(data) == "table")
			local path = Lib.combinePath(PATH_DATA_DIR, item_name, "setting.json")
			return Seri("json", data, path, dump)
		end,

		discard = function(item_name)
			local path = Lib.combinePath(PATH_DATA_DIR, item_name, "setting.json")
			ItemDataUtils:del(path)
		end
	},

	{
		key = "triggers.bts",

		member = "triggers",

		reader = function(item_name, raw)
			local path = Lib.combinePath(PATH_DATA_DIR, item_name, "triggers.bts")
			if Lfs.attributes(path, "mode") == "file" then
				return Lib.read_file(path, raw)
			end
		end,

		import = function(content, ref)
			-- todo
			return {}
		end,

		export = function(item)
			return item.triggers or {}
		end,

		writer = function(item_name, data, dump)
			local path = Lib.combinePath(PATH_DATA_DIR, item_name, "triggers.bts")
			return Seri("bts", data, path, dump)
		end,

		discard = function(item_name)
			local path = Lib.combinePath(PATH_DATA_DIR, item_name, "triggers.bts")
			ItemDataUtils:del(path)
		end
	},

	discard = function(item_name)
		local path = Lib.combinePath(PATH_DATA_DIR, item_name)
		ItemDataUtils:delDir(path)
	end
}

return M
