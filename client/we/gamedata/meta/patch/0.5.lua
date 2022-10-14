local meta = {
	{
		type = "Resource_BlockTexture",
		value = function(oval)
			if oval.asset ~= "" then	
				oval.asset = "asset/" .. oval.asset
			end
			return oval
		end
	},
	{
		type = "Resource_EntityTexture",
		value = function(oval)
			if oval.asset ~= "" then	
				oval.asset = "asset/" .. oval.asset
			end
			return oval
		end
	},
	{
		type = "Resource_SkillTexture",
		value = function(oval)
			if oval.asset ~= "" then	
				oval.asset = "asset/" .. oval.asset
			end
			return oval
		end
	},
	{
		type = "Resource_ItemTexture",
		value = function(oval)
			if oval.asset ~= "" then	
				oval.asset = "asset/" .. oval.asset
			end
			return oval
		end
	},
	{
		type = "Resource_ShopTexture",
		value = function(oval)
			if oval.asset ~= "" then	
				oval.asset = "asset/" .. oval.asset
			end
			return oval
		end
	},
	{
		type = "Resource_Sound",
		value = function(oval)
			if oval.asset ~= "" then	
				oval.asset = "asset/" .. oval.asset
			end
			return oval
		end
	},
	{
		type = "Resource_Actor",
		value = function(oval)
			if oval.asset ~= "" then	
				oval.asset = "asset/" .. oval.asset
			end
			return oval
		end
	},
	{
		type = "Resource_Effect",
		value = function(oval)
			if oval.asset ~= "" then	
				oval.asset = "asset/" .. oval.asset
			end
			return oval
		end
	},
	{
		type = "Resource_Mesh",
		value = function(oval)
			if oval.asset ~= "" then	
				oval.asset = "asset/" .. oval.asset
			end
			return oval
		end
	}
}

for _, patch in ipairs(meta) do
	patch.value = string.dump(patch.value)
end

return {
	meta = meta
}
