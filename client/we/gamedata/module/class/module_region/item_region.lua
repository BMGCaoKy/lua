local Cjson = require "cjson"
local Def = require "we.def"
local Seri = require "we.gamedata.seri"
local ItemDataUtils = require "we.gamedata.item_data_utils"
local Converter = require "we.gamedata.export.data_converter"
local ItemBase = require "we.gamedata.module.class.item_base"
local Meta = require "we.gamedata.meta.meta"
local PropImport = require "we.gamedata.module.prop_import"

local M = Lib.derive(ItemBase)

local MODULE_NAME = "region"
local ITEM_TYPE = "RegionCfg"
local PATH_DATA_DIR = Lib.combinePath(Def.PATH_GAME, string.format("plugin/%s/%s", Def.DEFAULT_PLUGIN, MODULE_NAME))

M.config = {
	{
		key = "setting.json",
	
		reader = function(item_name, raw)
			local path = Lib.combinePath(PATH_DATA_DIR, item_name, "setting.json")
			return Lib.read_file(path, raw)
		end,

		import = function(content, ref, item)
			local setting = Cjson.decode(content)

			if setting.viewSetting then
				local smoothView = setting.viewSetting and setting.viewSetting.smoothView or nil
				if smoothView then
					ref.rotateTheCamera = {
						enable = true,
						time = PropImport.Time(smoothView.smooth),
						pitch = smoothView.pitch,
						yaw = smoothView.yaw
					}
				end
				local viewCfg = setting.viewSetting and setting.viewSetting.viewCfg or nil
				if viewCfg then
					ref.view = {
						enable = true,
						viewFovAngle = viewCfg.viewFovAngle,
						distance = viewCfg.distance,
						viewIsBlocked = viewCfg.enableCollisionDetect and "PushCamera" or "Don't",
						back_dragView = not viewCfg.lockSlideScreen,
						pos = { pos = viewCfg.pos }
					}
				end
				if setting.viewSetting.personView then
					local views = { "FirstPerson", "Back", "Front", "Follow", "Fixed" }
					ref.view.type = views[setting.viewSetting.personView + 1]
				end
			end
			if not ref.name then
				local trans_key = item:module_name() .. "_" .. item:id()
				ref.name = PropImport.Text(trans_key)
			end
			return ref
		end,

		export = function(rawval, content)
			local meta = Meta:meta(ITEM_TYPE)
			local item = meta:ctor(rawval)

			local ret
			if content then
				ret = Cjson.decode(content)
			else
				ret = {}
			end

			ret.viewSetting = ret.viewSetting or {}
			if item.rotateTheCamera.enable then
				ret.viewSetting.smoothView = {
					smooth = item.rotateTheCamera.time.value,
					pitch = item.rotateTheCamera.pitch,
					yaw = item.rotateTheCamera.yaw
				}
			else
				ret.viewSetting.smoothView = nil
			end
			if item.view.enable then
				local viewCfg = {
					viewFovAngle = item.view.viewFovAngle,
					lockSlideScreen = not item.view.back_dragView
				}
				if item.view.type == "Back" or item.view.type == "Front" or item.view.type == "Follow" then
					viewCfg.enableCollisionDetect = item.view.viewIsBlocked == "PushCamera"
					viewCfg.distance = item.view.distance
				elseif item.view.type == "Fixed" then
					viewCfg.pos = item.view.pos.pos
				end
				ret.viewSetting.viewCfg = viewCfg
				ret.viewSetting.canSwitch = false
				local viewType = { FirstPerson = 0, Back = 1, Front = 2, Follow = 3, Fixed = 4 }
				ret.viewSetting.personView = viewType[item.view.type]
			else
				ret.viewSetting.personView = nil
				ret.viewSetting.canSwitch = nil
				ret.viewSetting.viewCfg = nil
			end

			if item.rotateTheCamera.enable or item.view.enable then
				ret.type = "camera"
				ret.isClient = true
			end

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
			return Lib.read_file(path, raw)
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
