local M = {}

local materials = {
	{ texture = "part_suliao.tga",		props = {2.2, 0.3, 0.37		}},
	{ texture = "part_gangban.tga",		props = {7.9, 0.06, 0.2		}},
	{ texture = "part_muban.tga",		props = {2.5, 0.2, 0.28		}},
	{ texture = "part_caodi.tga",		props = {1.3, 0.1, 0.35		}},
	{ texture = "part_bingkuai.tga",	props = {0.9, 0.2, 0.022	}},
	{ texture = "part_eluanshi.tga",	props = {4.5, 0.17, 0.53	}},
	{ texture = "part_shiban.tga",		props = {2.7, 0.17, 0.61	}},
	{ texture = "part_zhuankuai.tga",	props = {2.5, 0.15, 0.6		}},
	{ texture = "part_ditan.tga",		props = {0.6, 0.06, 0.46	}},
	{ texture = "part_shuini.tga",		props = {4, 0.2, 0.63		}},
	{ texture = "part_shatu.tga",		props = {3.4, 0.06, 0.4		}},
	{ texture = "part_dalishi.tga",		props = {2.7, 0.17, 0.56	}},
	{ texture = "part_mutou.tga",		props = {1.26, 0.15, 0.28	}},	
	{ texture = "part_xiushijinshu.tga",props = {7.70, 0.05, 0.44	}},
	{ texture = "part_huawenban.tga",   props = {5.50, 0.07, 0.56	}},
	{ texture = "part_xibo.tga",		props = {5.50, 0.03, 0.26	}},
	{ texture = "part_buliao.tga",		props = {0.60, 0.03, 0.46	}},
	{ texture = "part_huagangyan.tga",	props = {3.85, 0.17, 0.20	}},
	{ texture = "part_luanshi.tga",		props = {3.63, 0.17, 0.20	}},
	{ texture = "part_boli.tga",		props = {2.20, 0.18, 0.15	}},
	{ texture = "part_shihuizhuan.tga", props = {2.93, 0.20, 0.74	}}
}

function M:material_list()
	local ret = {}

	for _, item in ipairs(materials) do
		table.insert(ret, {value = item.texture})
	end

	return ret
end

function M:material_property(texture)
	for _, item in ipairs(materials) do
		if item.texture == texture then
			return item.props
		end
	end

	return {1, 0.9, 0.9}
end

return M
