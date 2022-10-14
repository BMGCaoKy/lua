local meta = {
	{
		type = "T_MapEntry",
		value = function(oval)
			return ctor("T_Map", Lib.copy(oval))
		end
	}
}

return {
	meta = meta
}
