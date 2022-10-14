local meta = {
	{
		type = "Action_SpawnItemToWorld",
		value = function(oval)
			local ret = Lib.copy(oval)

			local params = ret.components[1].params
			table.insert(params, 6, {key = "params_control", value = ctor("T_Bool")})

			return ret
		end
	}
}

return {
	meta = meta
}
