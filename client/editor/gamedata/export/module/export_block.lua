local Seri = require "editor.gamedata.seri"
local Base = require "editor.gamedata.export.module.export_base"
local Converter = require "editor.gamedata.export.data_converter"

local M = Lib.derive(Base)

local MODULE_DIR = Lib.combinePath(Root.Instance():getGamePath(), "plugin/myplugin/block/")

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
				["collisionBoxes"] = item.collisionBoxes,
				["spring"] = item.spring,
				["onBuff"] = function()
					if item.onBuff and item.onBuff ~= "" then
						return item.onBuff
					end
				end,
				["inBuff"] = function()
					if item.inBuff and item.inBuff ~= "" then
						return item.inBuff
					end
				end,
				["fall"] = item.fall,
				["canSwim"] = item.canSwim,
				["canClick"] = item.canClick,
				["maxSpeed"] = item.maxSpeed,
				["climbSpeed"] = item.climbSpeed,
				["maxFallSpeed"] = item.maxFallSpeed,
				["lightOpacity"] = item.lightOpacity,
				["renderPass"] = item.renderPass,
				["lightEmitted"] = item.lightEmitted,
				["isOpaqueFullCube"] = item.isOpaqueFullCube,
				["emitLightInMaxLightMode"] = item.emitLightInMaxLightMode,
				["renderable"] = item.renderable,
				["blockObjectOnCollision"] = item.blockObjectOnCollision,

				["breakTime"] = function()
					return item.canBreak and item.breakTime.value
				end,

				["texture"] = {
					"@" .. item.textures.down.asset,
					"@" .. item.textures.up.asset,
					"@" .. item.textures.front.asset,
					"@" .. item.textures.back.asset,
					"@" .. item.textures.left.asset,
					"@" .. item.textures.right.asset
				},

				["quads"] = function()
					if #item.quads == 0 then
						return nil
					end

					local ret = {}
					for _, v in ipairs(item.quads) do
						local quad = {}
						quad.pos = v.pos
						quad.texture = v.texture.asset
						table.insert(ret, quad)
					end
					return ret
				end,

				["color"] = Converter(item.color),

				--dropSelf
				["dropSelf"] = item.dropSelf.canDropSelf,
				["dropCount"] = item.dropSelf.dropCount,

				["dropItem"] = function()
					if #item.dropItems == 0 then
						return nil
					end

					local ret = {}
					for _, v in ipairs(item.dropItems) do
						table.insert(ret, {item = v.item, count = v.count})
					end
					return ret
				end,

				["runSound"] = Converter(item.runSound),
				["sneakSound"] = Converter(item.sneakSound),
				["placeBlockSound"] = Converter(item.placeBlockSound),
				["breakBlockSound"] = Converter(item.breakBlockSound),
				["sprintSound"] = Converter(item.sprintSound),
				["jumpSound"] = Converter(item.jumpSound),
				["recycle"] = Converter(item.recycle),
				["recycleTime"] = Converter(item.recycleTime)
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
