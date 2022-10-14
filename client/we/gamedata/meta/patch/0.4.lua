local meta = {
	{
		type = "Block_Quad",
		value = function(oval)
			local ret = ctor("Block_Quad")
			ret.texture = oval.texture
			for i, ver in ipairs(ret.vertices) do
				ver.position = oval.pos[i]
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