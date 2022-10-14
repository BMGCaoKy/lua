local meta = {
    {
        type = "Instance_Light",
        value = function (oval)
            local ret = Lib.copy(oval)
            ret.needSync = false
            return ret
        end
    }
}

return {
	meta = meta
}