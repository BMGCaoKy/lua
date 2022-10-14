local invalid_nodes = {}

local meta = {
	{
		type = "Trigger",
		value = function(oval)
			local ret = Lib.copy(oval)

			local idx = 1
			repeat
				local action = ret.actions[idx]
				if not action then
					break
				end

				if action.name == "CloseMap" then
					invalid_nodes[action.id.value] = true
					table.remove(ret.actions, idx)
				else
					idx = idx + 1
				end
			until(false)

			return ret
		end
	},

	{
		type = "T_Base",
		value = function(oval)
			local ret = Lib.copy(oval)
			if invalid_nodes[ret.action] then
				ret.action = ""
			end

			return ret
		end
	}
}


return {
	meta = meta
}
