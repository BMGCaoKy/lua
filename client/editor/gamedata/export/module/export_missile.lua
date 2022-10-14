local Seri = require "editor.gamedata.seri"
local Base = require "editor.gamedata.export.module.export_base"
local Converter = require "editor.gamedata.export.data_converter"
local Export_Mapping = require "editor.gamedata.export.export_mapping"

local M = Lib.derive(Base)

local MODULE_DIR = Lib.combinePath(Root.Instance():getGamePath(), "plugin/myplugin/missile/")

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
				["boundingVolume"] = Converter(item.boundingVolume),

				["moveSpeed"] = item.moveSpeed,
				["moveAcc"] = item.moveAcc,
				["gravity"] = item.gravity,
				["rotateSpeed"] = item.rotateSpeed,
				["isPitch"] = item.isPitch,

				["followTarget"] = item.followTarget,
				["followTargetPositionOffset"] = item.followTargetPositionOffset,
				["followTargetPosition"] = item.followTargetPosition,

				["lifeTime"] = item.lifeTime.value,
				["vanishTime"] = item.vanishTime.value,
				["vanishShow"] = item.vanishShow,

				["collideBlock"] = tonumber(item.collideBlock),
				["collideEntity"] = tonumber(item.collideEntity),

				["startSkill"] = (item.startSkill ~= "") and item.startSkill or nil,
				["startSound"] = Converter(item.startSound),
				["startEffect"] = Converter(item.startEffect),

				["hitInterval"] = item.hitInterval.value,
				["hitCount"] = item.hitCount.open and item.hitCount.hitCount or nil,
				["hitEntityCount"] = item.hitCount.open and item.hitCount.hitEntityCount or nil,
				["hitBlockCount"] = item.hitCount.open and item.hitCount.hitBlockCount or nil,
				["hitSkill"] = (item.hitSkill ~= "") and item.hitSkill or nil,
				["hitEntitySkill"] = (item.hitEntitySkill ~= "") and item.hitEntitySkill or nil,
				["hitBlockSkill"] = (item.hitBlockSkill ~= "") and item.hitBlockSkill or nil,
				["hitEffect"] = Converter(item.hitEffect),
				["hitSound"] = Converter(item.hitSound),
				["hitEntitySound"] = Converter(item.hitEntitySound),
				["hitBlockSound"] = Converter(item.hitBlockSound),
				["reboundBlockSound"] = Converter(item.reboundBlockSound),

				["vanishSkill"] = (item.vanishSkill ~= "") and item.vanishSkill or nil,
				["vanishEffect"] = Converter(item.vanishEffect),
				["vanishSound"] = Converter(item.vanishSound)
			}
			if item.missileModel.type == "mesh" then
				data.modelMesh = item.missileModel.modelMesh
			elseif item.missileModel.type == "block" then
				data.modelBlock = item.missileModel.modelBlock
			elseif item.missileModel.type == "picture" then
				data.modelPicture = item.missileModel.modelPicture.asset
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

	end
}

function M:init(module)
	Base.init(self,module,item_class)
end

return M
