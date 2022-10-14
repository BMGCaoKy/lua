local Seri = require "editor.gamedata.seri"
local Base = require "editor.gamedata.export.module.export_base"

local M = Lib.derive(Base)

local MODULE_DIR = Lib.combinePath(Root.Instance():getGamePath())

local item_class = {
	init = function(self, module, item)
		self._module = module
		self._item = module:item(item)
	end,

	seri = function(self, dump)
		local item = self._item:val()

		-- json
		do
			local data = {
				["playerCfg"] = string.format("myplugin/%s", item.playerCfg),
				["defaultMap"] = item.initPos.map,
				["initPos"] = function()
					return {
						x = item.initPos.pos.x,
						y = item.initPos.pos.y,
						z = item.initPos.pos.z,
					}
				end,
				["replay"] = item.replay,
				["waitPlayerTime"] = item.waitPlayerTime.value,
				["waitStartTime"] = item.waitStartTime.value,
				["waitGoTime"] = item.waitGoTime.value,
				["playTime"] = item.playTime.value,
				["reportTime"] = item.reportTime.value,
				["maxPlayers"] = item.maxPlayers,
				["minPlayers"] = item.minPlayers,
				["isTimeStopped"] = item.isTimeStopped,
				["nowTime"] = item.nowTime.value,
				["oneDayTime"] = item.oneDayTime.value,
				["bagCap"] = item.bagCap,
				["needTask"] = item.needTask,
				["automatch"] = item.team.automatch,
				["teammateHurt"] = item.team.teammateHurt,
				["canJoinMidway"] = item.canJoinMidway,
				["team"] = function()
					local teams = {}
					for _,v in pairs(item.team.team) do
						local team = {
							["id"] = v.id,
							["initPos"] = v.startPos.pos
						}
						table.insert(teams,team)
					end
					return teams
				end,
				["forcePickBlock"] = true,
				["vars"] = function()
					local vars = {}
					for k, page in pairs(item.vars) do
						local p = {}
						for _, v in ipairs(page) do
							local var = {}
							var.key = v.key
							var.save = v.save
							if v.value.rawval then
								var.value = v.value.rawval
							end
							table.insert(p, var)
						end
						vars[k] = p
					end
					return vars
				end
			}
			
			local key, val = next(data)
			
			while(key) do
				if type(val) == "function" then
					data[key] = val()
				end
				key, val = next(data, key)
			end
			local path = Lib.combinePath(MODULE_DIR, "setting.json")
			Seri("json", data, path, dump)
		end

		-- bts
		do
			local data = item.triggers
			local path = Lib.combinePath(MODULE_DIR, "triggers.bts")
			Seri("bts", data, path, dump)
		end
	end,
}

function M:init(module)
	Base.init(self, module, item_class)
end

return M
