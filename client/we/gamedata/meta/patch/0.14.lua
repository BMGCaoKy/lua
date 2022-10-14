local meta = {
	{
		type = "Action_LoopTimes",
		value = function(oval)
			local ret = Lib.copy(oval)

			ret.components[1].params[1].value = ctor("T_Int", {rawval = ret.components[1].params[1].value.rawval.value})

			return ret
		end
	}
}

return {
	meta = meta
}
