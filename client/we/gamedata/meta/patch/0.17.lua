local Def = require "we.def"
local Lang = require "we.gamedata.lang"
local lfs = require "lfs"

local meta = {
	{
		type = "Team",
		value = function(oval)
			local ret = Lib.copy(oval)

			ret.use_init_pos = ret.initPos and ret.initPos.is_show or false
			ret.use_start_pos = ret.startPos and ret.startPos.is_show or false

			return ret
		end
	},
	{
		type = "MapCfg",
		value = function(oval)
			Lang:load()
			local ret = Lib.copy(oval)
			ret.instances = ret.instances or {}
			for _,region in ipairs(ret.regions) do
				local id = region.id
				local min = region.min
				local max = region.max
				--取对角点
				max = {x = max.x + 1, y = max.y + 1, z = max.z + 1}
				local size = {x = max.x - min.x, y = max.y - min.y, z = max.z - min.z}
				local scale = Lib.copy(size)
				local position = {x = max.x - size.x/2,
							y = max.y - size.y/2,
							z = max.z -size.z/2}
				local name = Lang:text("region_"..id,false)
				local new_region = ctor("Instance_RegionPart",{cfgName = "myplugin/"..id,
														name = name,
														position = position,
														scale = scale,
														size = size})
				table.insert(ret.instances,new_region)
			end
			ret.regions = nil
			for _,entity in ipairs(ret.entitys) do
				local cfgs = Lib.split(entity.cfg,"/")
				local uid = cfgs[2] or ""
				local pos = entity.pos
				local config = entity.cfg
				local name = Lang:text("entity_" .. uid, false)
				local new_entity = ctor("Instance_Entity",{config = config,
														name = name,
														position = pos})
				table.insert(ret.instances,new_entity)
			end
			ret.entitys = nil
			return ret
		end
	},
	{
		type = "GameCfg",
		value = function(oval)
			local ret = Lib.copy(oval)
			local layout_path = Lib.combinePath(Def.PATH_GAME, "gui/layouts")
			local lua_path = Lib.combinePath(Def.PATH_GAME, "gui/lua_scripts")
			local assest_path = Lib.combinePath(Def.PATH_GAME, "asset")
			for it in lfs.dir(layout_path) do
				if it ~= '.' and it ~= ".." then
					local name_strs = Lib.split(it,".")
					if name_strs[2] and name_strs[2] == "layout" then
						local file_name = name_strs[1]
						local layout_file = Lib.combinePath(layout_path, file_name..".layout")
						local lua_file = Lib.combinePath(lua_path, file_name..".lua")
						Lib.copyFile(layout_file, Lib.combinePath(assest_path, file_name..".layout"))
						local file = io.open(lua_file, "rb")
						if file then
							local data = file:read("*a")
							file:close()
							file = io.open(Lib.combinePath(assest_path, file_name..".lua"), "wb")
							file:write(data)
							file:close()
							os.remove(lua_file)
						end
						os.remove(layout_file)
					end
				end
			end
			return ret
		end
	},
	{
  		type = "T_TipType",
		value = function(oval)
			local ret = Lib.copy(oval)
			ret.rawval = ctor("TipType", ret.rawval.type)
			return ret
		end
	},
	{
		type = "Action_IfEntityInArea",
		value = function(oval)
			local ret = Lib.copy(oval)

			ret.components[1].params[2].value = ctor("T_SceneRegion")

			return ret
		end
	},
	{
		type = "T_MinInt",
		value = function(oval)
			local ret = Lib.copy(oval)

			ret = ctor("T_Int",{rawval = ret.rawval})

			return ret
		end
	}
}

return {
	meta = meta
}