local Seri = require "editor.gamedata.seri"
local Base = require "editor.gamedata.export.module.export_base"
local Converter = require "editor.gamedata.export.data_converter"
local Def = require "editor.def"

local M = Lib.derive(Base)

local MODULE_DIR = Lib.combinePath(Root.Instance():getGamePath(), "plugin/myplugin/skill/")

local item_class = {
	init = function(self, module, item)
		self._module = module
		self._item = module:item(item)
	end,

	seri = function(self, dump)
		local item = self._item:val()
		local item_base = item.skill.base

		-- json
		do	
			local data = {
				["icon"] = Converter(item.icon.asset, Def.TYPE_ASSET),

				["cdTime"] = function()
					return item.cdTime.value > 0 and item.cdTime.value
				end,

				["consumeItem"] = function()
					local consumeItem_array = {}
					for _, it in ipairs(item.consumeItem) do
						local newItem = {}
						if it.itemType.type == "Block" then
							newItem.consumeName = "/block"
							newItem.consumeBlock = it.itemType.block ~= "" and it.itemType.block
						else
							newItem.consumeName = it.itemType.item ~= "" and it.itemType.item
						end
						newItem.count = it.count
						table.insert(consumeItem_array, newItem)
					end
					return consumeItem_array
				end,

				["consumeVp"] = item.consumeVp,

				["container"] = function()
					if (item.container.active) then
						return {
							takeNum = item.container.takeNum,
							autoReloadSkill = item.container.autoReloadSkill
						}
					end
				end,

				["isClick"] = item.isClick,

				["isTouch"] = item.isTouch,

				["touchTime"] = Converter(item.touchTime),

				["castAction"] = item.castAction,
				["castActionTime"] = Converter(item.castActionTime),
				["castSound"] = Converter(item.castSound),				
				["castEffect"] = Converter(item.castEffect),
				["startAction"] = item.startAction,
				["startEffect"] = Converter(item.startEffect),
				["sustainAction"] = item.sustainAction,
				["sustainEffect"] = Converter(item.sustainEffect),
				["stopEffect"] = Converter(item.stopEffect),
				["fallingAction"] = item.fallingAction,

				["type"] = item.skill.type,
			}

			if data.type == "MeleeAttack" then
				data.hurtDistance = item_base.hurtDistance
				data.damage = item_base.damage
				data.range = item_base.range
				data.dmgFactor = item_base.dmgFactor
			elseif data.type == "Reload" then
				data.reloadTime = item_base.reloadTime.value
			elseif data.type == "Buff" then
				data.buffCfg = item_base.buffCfg
				data.buffTime = item_base.buffTime.value
				data.target = "self"
			elseif data.type == "Ray" then
				data.frontSight = item_base.frontSight
				data.isHitPointRandom = item_base.isHitPointRandom
				data.rayLenth = item_base.rayLenth
				data.hitEffect = Converter(item_base.hitEffect.asset,Def.TYPE_ASSET)
				data.trajectoryEffect = Converter(item_base.trajectoryEffect.asset,Def.TYPE_ASSET)
				data.recoil = item_base.recoil
				if item_base.autoRecoverRecoil.recover then
					data.autoRecoverRecoil = {
						value = item_base.autoRecoverRecoil.value,
						time = item_base.autoRecoverRecoil.time.value
					}
				end			
				data.hitEntitySkill = item_base.hitEntitySkill
				data.hitEntityHeadSkill = item_base.hitEntityHeadSkill
				data.hitBlockSkill = item_base.hitBlockSkill
			elseif data.type == "Missile" then
				data.startFrom = item_base.startFrom
				data.frontDistance = item_base.frontDistance
				data.frontRange = item_base.frontRange
				data.frontHeight = item_base.frontHeight
				data.targetType = item_base.targetType
				
				data.missileCount = #item_base.missile
				data.missileCfg = {}
				data.startPos = {}
				data.startYaw = {}
				data.startPitch = {}
				data.startWait = {}
				for i, missile in ipairs(item_base.missile or {}) do
					data.missileCfg[i] = missile.missileCfg
					data.startPos[i] = {
						x = missile.startPos.x,
						y = missile.startPos.y,
						z = missile.startPos.z
					}
					data.startYaw[i] = missile.startYaw
					data.startPitch[i] = missile.startPitch
					data.startWait[i] = missile.startWait
				end
				
			elseif data.type == "Charge" then
				data.chargeType = item_base.chargeType
				data.consumeType = item_base.consumeType
				data.computeType = item_base.computeType

				data.minSustainTime = item_base.minSustainTime.value
				data.maxSustainTime = Converter(item_base.maxSustainTime)
			end

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
	Base.init(self,module,item_class)
end

return M
