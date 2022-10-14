local meta = {
	{
		type = "GameCfg",
		value = function(oval)
			local Lang = require "we.gamedata.lang"
			Lang:set_text("UserCurrency.green_currency.name", "绿钞", "zh")
			Lang:set_text("UserCurrency.green_currency.name", "Green Currency", "en")
			local ret = Lib.copy(oval)
			ret.currency = {
				{
					__OBJ_TYPE = "UserCurrency",
					id = "green_currency",
					icon = "set:jail_break.json image:jail_break_currency",
					name = { value = "UserCurrency.green_currency.name" }
				}
			}
			return ret
		end
	},
	{
		type = "EntityCfg",
		value = function(oval)
			local ret = Lib.copy(oval)
			if ret.triggers and #ret.triggers.list > 0 then
				for i = #ret.triggers.list, 1, -1 do
					local trigger = ret.triggers.list[i]
					if trigger.type == "Trigger_HitBlock" then	
						table.remove(ret.triggers.list, i)
					end
				end
			end
			return ret
		end
	}
}

for _, patch in ipairs(meta) do
	patch.value = string.dump(patch.value)
end

return {
	meta = meta
}