local meta = {
	{
		type = "Color",
		value = function(oval)
			val = {}
			val.r = oval.value % 256
			val.g = (oval.value - val.r) / 256 % 256
			val.b = (oval.value - val.r - val.g * 256) / 65536 % 256
			val.a = 255
			local ret = ctor("Color", val)
			return ret
		end
	},
	{
		type = "ColorRGBA",
		value = function(oval)
			local ret = ctor("Color", {
				r = oval.r and oval.r * 255,
				g = oval.g and oval.g * 255,
				b = oval.b and oval.b * 255,
				a = 255
			})
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