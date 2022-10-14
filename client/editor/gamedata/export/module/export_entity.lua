local Seri = require "editor.gamedata.seri"
local Base = require "editor.gamedata.export.module.export_base"
local Converter = require "editor.gamedata.export.data_converter"

local M = Lib.derive(Base)

local MODULE_DIR = Lib.combinePath(Root.Instance():getGamePath(), "plugin/myplugin/entity/")

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
				["actorName"] = function()
					if item.actorName.asset and item.actorName.asset ~= "" then
						return item.actorName.asset
					else
						return "cdfc13604fe4b1a38326aca21c8d190c.actor"
					end
				end,
				["name"] = item.name.value,
				["maxHp"] = item.maxHp,
				["clickDistance"] = item.clickDistance,
				["canClick"] = item.canClick,
				["unassailable"] = function()
					if item.unAssailable then
						return 1
					else
						return 0
					end
				end,
				["undamageable"] = function()
					if item.unDamageable then
						return 1
					else
						return 0
					end
				end,
				["stepHeight"] = item.stepHeight,
				["deadSound"] = Converter(item.deadSound),
				["canAttack"] = item.canAttack,
				["damage"] = item.damage,
				["canMove"] = item.canMove,
				["moveAcc"] = item.moveAcc,
				["moveSpeed"] = item.moveSpeed,
				["moveFactor"] = item.moveFactor,
				["canJump"] = item.canJump,
				["jumpSpeed"] = item.jumpSpeed,
				["gravity"] = item.gravity,
				["jumpHeight"] = item.jumpHeight,
				["hideHp"] = item.hideHp,
				["hpFaceCamera"] = item.hpFaceCamera,
				["hpBarColor"] = item.hpBarColor.value,
				["hpBarHeight"] = item.hpBarHeight,
				["hpBarWidth"] = item.hpBarWidth,
				["dropDamageStart"] = item.dropDamageStart,
				["skills"] = function()
					local skills = {}
					for _,v in pairs(item.skill) do
						if v and v ~= "" then
							table.insert(skills,v)
						end
					end
					return skills
				end,
				["skillList"] = function()
					local skill_list = {}
					for _,v in pairs(item.skillList) do
						local skill = {
							["attackDis"] = v.attackDis,
							["prioity"] = v.prioity,
							["fullName"] = v.fullName
						}
						table.insert(skill_list,skill)
					end
					return skill_list
				end,
				["eyeHeight"] = item.eyeHeight,
				["canBoat"] = item.canBoat,
				["waterline"] = item.waterLine,
				["collision"] = item.collision,
				["boundingVolume"] = Converter(item.boundingVolume),
				["equipTrays"] = function()
					local equip = {}
					for _,v in pairs(item.equip) do
						if v and v ~= "" then
							table.insert(equip,tonumber(v))
						end
					end
					return equip
				end,
				["enableAI"] = item.enableAI,
				["autoAttack"] = item.autoAttack,
				["attackNpc"] = item.attackNpc,
				["patrolDistance"] = item.patrolDistance,
				["chaseDistance"] = item.chaseDistance,
				["homeSize"] = item.homeSize,
				["idleTime"] = function()
					return {
						item.idleTime.min.value,
						item.idleTime.max.value
					}
				end,
				["idleProb"] = item.idleProb.value,
				["ridePos"] = item.ridePos,
				["headContentLimitMinSize"] = item.headContentLimitMinSize,
				["headUIHeight"] = item.headUIHeight
			}

			local key, val = next(data)
			while(key) do
				if type(val) == "function" then
					data[key] = val()
				end
				key, val = next(data, key)
			end

			local path = Lib.combinePath(MODULE_DIR, self._item:id(), "setting.json")
			Seri("json", data, path, dump)
		end

		-- bts
		do
			local data = item.triggers
			local path = Lib.combinePath(MODULE_DIR, self._item:id(), "triggers.bts")
			Seri("bts", data, path, dump)
		end
	end,
}

function M:init(module)
	Base.init(self, module, item_class)
end

return M
