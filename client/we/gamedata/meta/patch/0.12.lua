local meta = {
	{
		type = "Action_GetAllEntities",
		value = function(oval)
			local ret = Lib.copy(oval)
			ret.type = "T_EntityArray"
			return ret
		end
	},
	{
		type = "Action_GetEntitiesByFullName",
		value = function(oval)
			local ret = Lib.copy(oval)
			ret.type = "T_EntityArray"
			return ret
		end
	},
	{
		type = "Action_GetAllPlayers",
		value = function(oval)
			local ret = Lib.copy(oval)
			ret.type = "T_EntityArray"
			return ret
		end
	},
}

return {
	meta = meta
}
