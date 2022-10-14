local Cjson = require "cjson"
local Def = require "we.def"
local Seri = require "we.gamedata.seri"
local Converter = require "we.gamedata.export.data_converter"
local ItemBase = require "we.gamedata.module.class.item_base"
local Meta = require "we.gamedata.meta.meta"
local PropImport = require "we.gamedata.module.prop_import"
local File = require "we.file"
local GameConfig = require "we.gameconfig"

local M = Lib.derive(ItemBase)

local PATH_DATA_DIR = Def.PATH_GAME
local ITEM_TYPE = "GameCfg"
local get_udim_or_widget_var_table
get_udim_or_widget_var_table = function(tb)
	if not tb or not next(tb) or type(tb) ~= "table" then
		return {}
	end

	local rawval = {}
	if tb.__OBJ_TYPE == "UDim2" then
		rawval = {{tb.UDim_X.Scale,tb.UDim_X.Offect},{tb.UDim_Y.Scale,tb.UDim_Y.Offect}}
	else
		for _,v in ipairs(tb) do
			table.insert(rawval, get_udim_or_widget_var_table(v))
		end
	end
	return rawval
end

M.config = {
	{
		key = "setting.json",
	
		reader = function(item_name, raw)
			local path = Lib.combinePath(PATH_DATA_DIR, "setting.json")
			return Lib.read_file(path, raw)
		end,

		import = function(content, ref, item)
			local props = {
				replay				= PropImport.original,
				waitPlayerTime		= PropImport.Time,
				waitStartTime		= PropImport.Time,
				waitGoTime			= PropImport.Time,
				reportTime			= PropImport.Time,
				--maxPlayers			= PropImport.original,
				--minPlayers			= PropImport.original,
				isTimeStopped		= PropImport.original,
				bagCap				= PropImport.original,
				canJoinMidway		= PropImport.original,
				needSave			= PropImport.original
			}

			local setting = Cjson.decode(content)
			for k, v in pairs(setting) do
				if type(props[k]) == "function" then
					ref[k] = props[k](v, item)
				end
			end
			if setting.useNewMaterial~=nil then
				ref.useNewMaterial=setting.useNewMaterial
			end

			if nil == setting.partGameStaticBatch then
				ref.partGameStaticBatch = true
			else
				ref.partGameStaticBatch = setting.partGameStaticBatch
			end

			if nil == setting.screenSpaceCull then
				ref.screenSpaceCull = false
			else
				ref.screenSpaceCull = setting.screenSpaceCull
			end

			if nil == setting.meshPartStaticMergeRender then
				ref.meshPartStaticMergeRender = true
			else
				ref.meshPartStaticMergeRender = setting.meshPartStaticMergeRender
			end

			if nil == setting.useHalfImageSize then
				ref.useHalfImageSize = true
			else
				ref.useHalfImageSize = setting.useHalfImageSize
			end
			
			ref.player_range = {}
			ref.player_range.min = setting.minPlayers
			ref.player_range.max = setting.maxPlayers
			--[[上面遍历引擎数据一对一转成编辑器数据，避免写很多if，
			当引擎数据与编辑器数据的关系是一对多或多对一或多对多时，用下面的写法]]
			ref.ui_enable = setting.engineDefUIEnable
			ref.oneDayTime = { value = setting.oneDayTime * 20 }

			local time = ((setting.nowTime + 6) % 24) * 3600
			local time_h = math.floor(time / 3600)
			time = time - time_h * 3600
			local time_m = time > 0 and math.floor(time / 60) or 0
			time = time - time_m * 60
			local time_s = time > 0 and math.floor(time) or 0
			ref.nowTime = {h = time_h, m = time_m, s = time_s}

			if setting.playTime == -1 then
				ref.unlimitedPlayTime = true
			else
				ref.unlimitedPlayTime = false
				ref.playTime = PropImport.Time(setting.playTime)
			end

			if (setting.automatch~=nil) or (setting.teammateHurt~=nil) or (setting.hideTeamStatusBar~=nil) then
				ref.team = {
					automatch = setting.automatch,
					teammateHurt = setting.teammateHurt,
					showTeamStatusBar = not setting.hideTeamStatusBar
				}
				for _, v in ipairs(setting.team or {}) do
					ref.team.team = ref.team.team or {}
					local team = { 
						id = v.id ,
						name = v.name, 
						memberLimit=v.memberLimit,
						ignorePlayerSkinEditor =v.ignorePlayerSkinEditor,
						actorName = { asset = v.actorName }
					}
					if v.initPos and #v.initPos > 0 then
						team.initPos = {
							map = v.initPos[1].map,
							pos = v.initPos[1]
						}
					else
						team.initPos = {
							map = (v.initPos or {}).map,
							pos = v.initPos
						}
					end
					if v.startPos and #v.startPos > 0 then
						team.startPos = {
							map = v.startPos[1].map,
							pos = v.startPos[1]
						}
					else
						team.startPos = {
							map = (v.startPos or {}).map,
							pos = v.startPos
						}
					end
					table.insert(ref.team.team, team)
				end
			end


			if setting.defaultMap or setting.initPos then
				ref.initPos = {
					pos = setting.initPos,
					map = setting.defaultMap
				}
			end

			if setting.defaultMap or setting.startPos then
				ref.startPos = {
					pos = setting.startPos and setting.startPos[1] or {x = 0, y = 0, z = 0},
					map = setting.defaultMap
				}
			end

			local camera = setting.cameraCfg
			if camera then
				if camera.defaultView then
					local views = { "FirstPerson", "Back", "Front", "Follow", "Fixed" }
					ref.defaultView = views[camera.defaultView + 1]
				end
				ref.canSwitchView = camera.canSwitchView
				ref.defaultPitch = camera.defaultPitch
				ref.defaultYaw = camera.defaultYaw
				if camera.viewModeConfig then
					local viewCfg = camera.viewModeConfig
					if viewCfg[1] then
						ref.firstPerson_enable = { enable = viewCfg[1].enable }
						ref.firstPerson_viewFovAngle = viewCfg[1].viewFovAngle
						ref.firstPerson_dragView = not viewCfg[1].lockSlideScreen
					end
					if viewCfg[2] then
						ref.back_enable = { enable = viewCfg[2].enable }
						ref.back_viewFovAngle = viewCfg[2].viewFovAngle
						ref.back_distance = viewCfg[2].distance
						ref.back_view_offset = viewCfg[2].offset
						ref.back_viewIsBlocked = viewCfg[2].enableCollisionDetect and "PushCamera" or "Don't"
						ref.back_dragView = not viewCfg[2].lockSlideScreen
					end
					if viewCfg[3] then
						ref.front_enable = { enable = viewCfg[3].enable }
						ref.front_viewFovAngle = viewCfg[3].viewFovAngle
						ref.front_distance = viewCfg[3].distance
						ref.front_view_offset = viewCfg[3].offset
						ref.front_viewIsBlocked = viewCfg[3].enableCollisionDetect and "PushCamera" or "Don't"
						ref.front_dragView = not viewCfg[3].lockSlideScreen
					end
					if viewCfg[4] then
						ref.follow_enable = { enable = viewCfg[4].enable }
						ref.follow_viewFovAngle = viewCfg[4].viewFovAngle
						ref.follow_distance = viewCfg[4].distance
						ref.follow_view_offset = viewCfg[4].offset
						ref.follow_viewIsBlocked = viewCfg[4].enableCollisionDetect and "PushCamera" or "Don't"
						ref.follow_dragView = not viewCfg[4].lockSlideScreen
					end
					if viewCfg[5] then
						ref.fixed_enable = { enable = viewCfg[5].enable }
						ref.fixed_viewFovAngle = viewCfg[5].viewFovAngle
						ref.fixed_viewPos = { pos = viewCfg[5].pos }
						ref.fixed_dragView = not viewCfg[5].lockSlideScreen
					end
				end
			end

			for _, v in ipairs(setting.uiNavigation or {}) do
				if v.name == "shop" then
					ref.showShop = true
				end
			end

			ref.enableNewLighting = setting.enableNewLighting
			ref.batchType = setting.batchType or ref.batchType

			--碰撞组
			--if setting.useNewCollisionFiltering then
			--	ref.useNewCollisionFiltering = setting.useNewCollisionFiltering --默认开启碰撞组，无需导入
			--end
			if setting.collisionMatrix then
				local items = {}
				for index, val in pairs(setting.collisionMatrix or {}) do
					table.insert(items, {
						name = string.format("Group%d", index),
						matrix = val
					})
				end
				ref.collisionGroup = {
					items = items
				}
			end

			--[[if setting.vars then
				ref.vars = {}
				for k, v in pairs(setting.vars) do
					--ref.vars
				end
			end]]

			ref.enableBakeLight = setting.enableBakeLight
			ref.qualityLevel = tostring(setting.defaultQualityLevel)

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

			ret.useNewQuadConfig = true
			ret.personalShop = false
			ret.playerCfg = string.format("myplugin/%s", item.playerCfg)
			ret.defaultMap = item.initPos.map
			ret.waitAtInitPos=true
			ret.initPos = function()
				return {
					x = item.initPos.pos.x,
					y = item.initPos.pos.y,
					z = item.initPos.pos.z,
					map = item.initPos.map
				}
			end
			ret.startPos = function()
				return {{ 
					x = item.startPos.pos.x,
					y = item.startPos.pos.y,
					z = item.startPos.pos.z,
					map = item.startPos.map
				}}
			end
			ret.nowTime = function()
				local tb = Lib.copy(item.nowTime)
				local time = tb.h + tb.m / 60 + tb.s /3600
				return (time+ 18) % 24 * 1000
			end
			ret.partGameStaticBatch = item.partGameStaticBatch
            ret.screenSpaceCull = item.screenSpaceCull
            ret.meshPartStaticMergeRender = item.meshPartStaticMergeRender
            ret.useHalfImageSize = item.useHalfImageSize
			ret.replay = item.replay
			ret.waitPlayerTime = item.waitPlayerTime.value
			ret.waitStartTime = item.waitStartTime.value
			ret.waitGoTime = item.waitGoTime.value
			ret.playTime = item.unlimitedPlayTime and -1 or item.playTime.value
			ret.reportTime = item.reportTime.value
			ret.maxPlayers = item.player_range.max
			ret.minPlayers = item.player_range.min
			ret.isTimeStopped = item.isTimeStopped
			ret.oneDayTime = item.oneDayTime.value / 20
			ret.bagCap = item.bagCap
			ret.needTask = item.needTask
			ret.automatch = item.team.automatch
			ret.teammateHurt = item.team.teammateHurt
			ret.hideTeamStatusBar = not item.team.showTeamStatusBar
			ret.canJoinMidway = item.canJoinMidway
			ret.needSave = item.needSave
			ret.noLoadHp = true
			ret.ignoreEmptyStartPos = ret.ignoreEmptyStartPos or false
			--默认画质等级
			ret.defaultQualityLevel = tonumber(item.qualityLevel)
			ret.notReadUserSettingCfgAtEditor = true
			ret.topTeamInfo ={
				["teamDieIcon"] ="flag_textures/flag_die",
				["teamDieIconArea"] = {
					 {0,5},
					 {0,-7},
					 {0,20},
					 {0,20}
				},
				["teamInfoArea"] ={
					 {0,-5},
					 {0,-3},
					 {0,53.45},
					 {0,17}
				}
			}
			ret.team = function()
				local teams = {}
				local base_init_pos = item.initPos
				local base_start_pos = item.startPos
				for _,v in pairs(item.team.team) do
					local use_team_init_pos = v.use_init_pos
					local use_team_start_pos = v.use_start_pos
					local init_pos = use_team_init_pos and v.initPos or Lib.copy(base_init_pos)
					local start_pos = use_team_start_pos and v.startPos or Lib.copy(base_start_pos)
					local team = {
						["id"] = v.id,
						["name"]= v.name,
						["memberLimit"] = v.memberLimit,
						["initPos"] = { 
							x = init_pos.pos.x,
							y = init_pos.pos.y,
							z = init_pos.pos.z,
							map = init_pos.map
						},
						["startPos"] = {{ 
							x = start_pos.pos.x,
							y = start_pos.pos.y,
							z = start_pos.pos.z,
							map = start_pos.map
						}},
						["actorName"] = v.ignorePlayerSkinEditor and  #v.actorName.asset >0 and v.actorName.asset or nil,
						["ignorePlayerSkin"] = true,--引擎必须一直设置这个值为true
						["image"] = v.image.asset,
						["mainTeamImageBg"] ="",
						["mainTeamImageFrame"] = "flag_textures/flag_frame"
					}
					table.insert(teams,team)
				end
				return teams
			end
			ret.forcePickBlock = true
			ret.vars = function()
				local vars = {}
				for k, page in pairs(item.vars) do
					local p = {}
					for _, v in ipairs(page) do
						local var = {}
						var.key = v.key
						var.save = v.save
						var.run_type = v.run_type
						local rawval = v.value.rawval
						Lib.pv(rawval)
						if v.type == "udim2" or v.type == "widget" then
							rawval = get_udim_or_widget_var_table(rawval)
						end
						if rawval then
							var.value = rawval
						end
						table.insert(p, var)
					end
					vars[k] = p
				end
				return vars
			end
			ret.skillJack = {
				sectorSkills= {
					{
						jackNum = 3,
						radius = 170,
						jackSize = 88,
						startAngle = 270,
						deltaAngle = 45
					}
				},
				lineSkills = {
					{
						jackNum = 2,
						xOffset = -50,
						yOffset = 0,
						jackSize = 80,
						itemSpace = 30,
						hAlign = 2,
						vAlign = 1
					},
					{
						jackNum = 4,
						xOffset = 0,
						yOffset = 50,
						jackSize = 80,
						itemSpace = 30,
						hAlign = 1,
						vAlign = 0
					}
				},
				AJackArea = {
					{0, -40}, {0, -40}, {0, 120}, {0, 120}
				},
				hideBJack = true
			}
			ret.cameraCfg = function()
				local view = {
					viewModeConfig = {
						{
							enable = item.firstPerson_enable.enable,
							viewFovAngle = item.firstPerson_viewFovAngle,
							lockSlideScreen = not item.firstPerson_dragView
						},
						{
							enable = item.back_enable.enable,
							distance = item.back_distance,
							offset = item.back_view_offset,
							enableCollisionDetect = item.back_viewIsBlocked == "PushCamera",
							viewFovAngle = item.back_viewFovAngle,
							lockSlideScreen = not item.back_dragView
						},
						{
							enable = item.front_enable.enable,
							distance = item.front_distance,
							offset = item.front_view_offset,
							enableCollisionDetect = item.front_viewIsBlocked == "PushCamera",
							viewFovAngle = item.front_viewFovAngle,
							lockSlideScreen = not item.front_dragView
						},
						{
							enable = item.follow_enable.enable,
							distance = item.follow_distance,
							offset = item.follow_view_offset,
							viewFovAngle = item.follow_viewFovAngle,
							lockBodyRotation = false,
							enableCollisionDetect = item.follow_viewIsBlocked == "PushCamera",
							lockSlideScreen = not item.follow_dragView
						},
						{
							enable = item.fixed_enable.enable,
							viewFovAngle = item.fixed_viewFovAngle,
							lockViewPos = true,
							lockBodyRotation = false,
							pos = item.fixed_viewPos.pos,
							lockSlideScreen = not item.fixed_dragView
						}
					},
					canSwitchView = item.canSwitchView,
					defaultPitch = item.defaultPitch,
					defaultYaw = item.defaultYaw
				}
				local viewType = { FirstPerson = 0, Back = 1, Front = 2, Follow = 3, Fixed = 4 }
				view.defaultView = viewType[item.defaultView]
				return view
			end
			ret.engineDefUIEnable = {
					actionControl = item.ui_enable.actionControl,
					actionControlMode = ret.engineDefUIEnable and ret.engineDefUIEnable.actionControlMode,
					toolbar = item.ui_enable.toolbar,
					topteamInfo = item.ui_enable.topteamInfo,
					shortcutBar = item.ui_enable.shortcutBar,
					appMainRole = item.ui_enable.appMainRole,
					chat = item.ui_enable.chat,
					playerinfo = item.ui_enable.playerinfo
			}
			

			if item.showShop then
				ret.uiNavigation = {
					{
						name = "shop",
						iconPath = "set:main_page.json image:shop_icon.png",
						list = 1
					}
				}
			else
				ret.uiNavigation = nil
			end

			--碰撞组
			ret.useNewCollisionFiltering = item.useNewCollisionFiltering
			ret.collisionMatrix = function()
				local ret = {}
				for _, val in pairs(item.collisionGroup.items or {}) do
					table.insert(ret, val.matrix)
				end
				return ret
			end

			ret.useVoxelTerrain = GameConfig:disable_block()
			local key, val = next(ret)
			while(key) do
				if type(val) == "function" then
					ret[key] = val()
				end
				key, val = next(ret, key)
			end
			ret.enableBakeLight = item.enableBakeLight

			ret.enableNewLighting = item.enableNewLighting
			if ret.enableNewLighting then
				ret.glesMinorVersion = 0
				ret.glesVersion = 3
			end

			ret.batchType = item.batchType

			return ret
		end,

		writer = function(item_name, data, dump)
			assert(type(data) == "table")
			local path = Lib.combinePath(PATH_DATA_DIR, "setting.json")
			return Seri("json", data, path, dump)
		end
	},

	{
		key = "triggers.bts",

		member = "triggers",

		reader = function(item_name, raw)
			local path = Lib.combinePath(PATH_DATA_DIR, "triggers.bts")
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
			local path = Lib.combinePath(PATH_DATA_DIR, "triggers.bts")
			return Seri("bts", data, path, dump)
		end
	},

		{
		key = "triggers_client.bts",

		member = "triggers_client",

		reader = function(item_name, raw)
			local path = Lib.combinePath(PATH_DATA_DIR, "triggers_client.bts")
			return Lib.read_file(path, raw)
		end,

		import = function(content, ref)
			-- todo
			return {}
		end,

		export = function(item)
			return item.triggers_client or {}
		end,

		writer = function(item_name, data, dump)
			local path = Lib.combinePath(PATH_DATA_DIR, "triggers_client.bts")
			return Seri("bts", data, path, dump)
		end
	},

	--魔方商店
	{
		key = "shop.csv",

		member = "shops", 

		reader = function(item_name, raw)
			local path = Lib.combinePath(PATH_DATA_DIR, "shop.csv")
			local file = io.open(path)
			if not file then
				return ""
			end
			local content = file:read("a")
			file:close()
			return content
		end,

		import = function(content, ref, item)
			local path = Lib.combinePath(PATH_DATA_DIR, "shop.csv")
			local ok, content = pcall(File.read_csv, path)
			ref = {}
			if not ok then
				return ref
			end
			local page_key = {}
			for _, line in ipairs(content) do
				--page
				local page
				if not page_key[line.type] then
					page = {
						name = PropImport.Text(line.name),
						items = {}
					}
					page_key[line.type] = page
					table.insert(ref, page)
				else
					page = page_key[line.type]
				end
				--道具
				local shop_item = {
					num = line.num,
					price = line.price,
					name = PropImport.Text(line.desc),
					detail = PropImport.Text(line.detail)
				}
				
				if line.itemName == "/block" then
					shop_item.item = {
						type = "block",
						item = string.gsub(line.blockName, "myplugin/", "")
					}
				else
					shop_item.item = {
						type = "item",
						item = string.gsub(line.itemName, "myplugin/", "")
					}
				end

				if line.limit < 0 then
					shop_item.limitType = "NoLimit"
				elseif line.limitType == 1 then
					shop_item.limitType = "Personal"
					shop_item.limit = line.limit
				elseif line.limitType == 0 then
					shop_item.limitType = "Common"
					shop_item.limit = line.limit
				end
				if type(line.coinName) == "number" then
					line.coinName = tostring(line.coinName)
				end
				shop_item.coinId = line.coinName
				table.insert(page.items, shop_item)
			end
			return ref
		end,

		export = function(rawval)
			local data = {}
			local item_index = 1
			local page_index = 0
			for i, page in ipairs(rawval.shops or {}) do
				if #page.items > 0 then
					page_index = page_index + 1
				end
				for _, v in ipairs(page.items) do
					if v.item.item ~= "" then
						local item = {}
						item.type = page_index
						item.index = item_index
						item_index = item_index + 1
						item.icon = ""
						item.name = page.name.value
						item.detail = v.detail.value
						item.desc = v.name.value
						item.itemName = ""
						item.blockName = ""
						if v.item.type == "item" then
							item.itemName = "myplugin/" .. v.item.item
						elseif v.item.type == "block" then
							item.itemName = "/block"
							item.blockName = "myplugin/" .. v.item.item
						end
						item.num = v.num
						item.coinName = v.coinId
						item.price = v.price
						if v.limitType == "NoLimit" then
							item.limitType = 1
							item.limit = -1
						elseif v.limitType == "Personal" then
							item.limitType = 1
							item.limit = v.limit
						elseif v.limitType == "Common" then
							item.limitType = 0
							item.limit = v.limit
						end
						item.stackLimit = 999
						table.insert(data, item)
					end
				end
			end
			return data
		end,

		writer = function(item_name, data, dump)
			assert(type(data) == "table")
			local header = {"index", "type", "icon", "name", "detail" , "desc", "itemName", "blockName",
				"num", "coinName", "price", "limit", "limitType", "stackLimit"}
			local path = Lib.combinePath(PATH_DATA_DIR, "shop.csv")
			return Seri("csv", data, path, dump, header)
		end
	}
}

return M
