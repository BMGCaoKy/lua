local VN = require "we.gamedata.vnode"
local M = {}

function M:is_layout(type)
	if string.find(type,"LayoutContainer") or
		string.find(type,"GridViewContainer") or type == "GridView" then
		return true
	else
		return false
	end
end

function M:set_pos_max_min(node)
	VN.set_attr(node.pos.UDim_X,"Scale","Max","10000")
	VN.set_attr(node.pos.UDim_X,"Offect","Max","10000")
	VN.set_attr(node.pos.UDim_Y,"Scale","Max","10000")
	VN.set_attr(node.pos.UDim_Y,"Offect","Max","10000")
	VN.set_attr(node.pos.UDim_X,"Scale","Min","-10000")
	VN.set_attr(node.pos.UDim_X,"Offect","Min","-10000")
	VN.set_attr(node.pos.UDim_Y,"Scale","Min","-10000")
	VN.set_attr(node.pos.UDim_Y,"Offect","Min","-10000")
end

function M:set_pos_enabled(node)
	VN.set_attr(node.pos,"UDim_X","Enabled","false")
	VN.set_attr(node.pos,"UDim_Y","Enabled","false")
end

function M:set_anchor(node)
	VN.set_attr(node,"anchor","Visible","false")
end

function M:set_auto_scale(value,node)
	local enabled_width = (value == "1" or value == "3") and "false" or "true"
	VN.set_attr(node.size, "UDim_X", "Enabled", enabled_width)

	local enabled_height = (value == "2" or value == "3") and "false" or "true"
	VN.set_attr(node.size, "UDim_Y", "Enabled", enabled_height)

	local enabled_ww = (value == "1" or value == "3") and "false" or "true"
	VN.set_attr(node,"word_warpped", "Enabled", enabled_ww)
	local enabled_ats = value == "0" and "true" or "false"
	VN.set_attr(node,"AutoTextScale", "Enabled", enabled_ats)
	if value == "1" then
		VN.assign(node, "word_warpped", false)
		VN.assign(node, "AutoTextScale", false)
	elseif value == "2" then
		VN.assign(node, "AutoTextScale", false)
	elseif value == "3" then
		VN.assign(node, "word_warpped", false)
		VN.assign(node, "AutoTextScale", false)
	end
end

function M:set_attrs(node)
	self:set_pos_max_min(node)
	local type = node.gui_type
	local children = node.children
	if self:is_layout(type) then
		for _,child in ipairs(children) do
			self:set_pos_enabled(child)
			self:set_anchor(child)
		end
	end

	local auto_scale = node.AutoScale
	if auto_scale then
		self:set_auto_scale(auto_scale,node)
	end

end

function M:init(node)
	self:set_attrs(node)
	local children = node.children
	for _,child in ipairs(children) do
		self:init(child)
	end
end

return M