local widget_base = require "ui.widget.widget_base"

local M = Lib.derive(widget_base)

--[[
	{
		[1] = {image = "xxx"},
		[2] = {image = "" },
	}
]]

function M:init(speed, config)
	assert(speed > 0)
	assert(#config > 0)

	widget_base.init(self)
	self._root:SetArea({0, 0}, {0, 0}, {1, 0}, {1, 0})

	self._nodes = {}
	self._curr = 0
	self._timer = nil
	
	self:reset(speed, config)
end

local node_pool = {}

local function col_node(node)
	node:SetImage("")
	table.insert(node_pool, assert(node))
end

local function get_node(data)
	local node = table.remove(node_pool)
	if not node then
		node = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "")
		node:SetArea({0, 0}, {0, 0}, {1, 0}, {1, 0})
	end
	
	node:SetImage(data.image)
	node:SetVisible(false)
	return node
end

function M:set_curr(curr)
	if self._nodes[self._curr] then
		self._nodes[self._curr]:SetVisible(false)
	end

	self._curr = curr

	if self._nodes[self._curr] then
		self._nodes[self._curr]:SetVisible(true)
	end
end

function M:reset(speed, config)
	-- clear
	do
		if self._timer then
			self._timer()
			self._timer = nil
		end

		for _, node in ipairs(self._nodes) do
			self._root:RemoveChildWindow1(node)
			col_node(node)
		end
		self._nodes = {}
	end

	for _, data in ipairs(config) do
		local node = get_node(data)
		self._root:AddChildWindow(node)
		table.insert(self._nodes, node)
	end
	assert(#self._nodes > 0)

	self:set_curr(0)
	self._timer = World.Timer(speed, function()
		self:set_curr(self._curr % #self._nodes + 1)
		return true
	end)
end

return M
