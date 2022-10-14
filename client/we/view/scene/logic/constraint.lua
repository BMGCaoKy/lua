local Signal = require "we.signal"
local Receptor = require "we.view.scene.receptor.receptor"
local Meta = require "we.gamedata.meta.meta"
local IWorld = require "we.engine.engine_world"
local IInstance = require "we.engine.engine_instance"

local M = {}

local constraint_class = {
	SIGNAL = {
		CONSTRAINTDESTROY			= "CONSTRAINTDESTROY",
		CONSTRAINTSELECTIONCHANGED	= "CONSTRAINTSELECTIONCHANGED",
		SLAVEPARTDESTROY			= "SLAVEPARTDESTROY",
		SLAVEPARTSET				= "SLAVEPARTSET",
		SLAVEPIVOTPOSCHANGED		= "SLAVEPIVOTPOSCHANGED",
		MASTERPIVOTPOSCHANGED		= "MASTERPIVOTPOSCHANGED",
	},

	SLOTS = {
		MASTERPIVOTPOS			= "master_pivot_pos",
		SLAVEPIVOTPOS			= "slave_pivot_pos"
	},

	init = function(self)
		self._constraint_watcher = {}
		self._master_watcher = {}
		self._slave_watcher = {}
	end,

	constraint_id = function(self)
		return self:constraint():id()
	end,

	master_id = function(self)
		return self:master():id()
	end,

	slave_id = function(self)
		if self:slave() then
			return self:slave():id()
		end
	end,

	set_master = function(self,master)
		self:master_cancel()
		self._master = master
		table.insert(self._master_watcher,Signal:subscribe(self._master, self._master.SIGNAL.GEOMETRIC_CHANGED, function()
			self:set_anchor_space()
		end))
		table.insert(self._master_watcher,Signal:subscribe(self._master, self._master.SIGNAL.NAME_CHANGED, function(name)
			self:constraint():set_master_part_name(name)
		end))
	end,

	master = function(self)
		return self._master
	end,

	master_pivot = function(self)
		return IWorld:get_instance(self:constraint():node():getMasterPivotID())
	end,

	set_slave = function(self,slave)
		self:slave_cancel()
		self._slave = slave
		table.insert(self._slave_watcher,Signal:subscribe(self._slave, self._slave.SIGNAL.GEOMETRIC_CHANGED, function()
			self:set_anchor_space()
		end))
		table.insert(self._slave_watcher,Signal:subscribe(self._slave, self._slave.SIGNAL.DESTROY, function()
			self:master_cancel()
			self:slave_cancel()
			self._slave = nil
			Signal:publish(self, self.SIGNAL.SLAVEPARTDESTROY)
		end))
		table.insert(self._slave_watcher,Signal:subscribe(self._slave, self._slave.SIGNAL.NAME_CHANGED,function(name)
			self:constraint():set_slave_part_name(name)
		end))
		Signal:publish(self, self.SIGNAL.SLAVEPARTSET)
	end,

	slave = function(self)
		return self._slave
	end,

	slave_pivot = function(self)
		return IWorld:get_instance(self:constraint():node():getSlavePivotID())
	end,

	set_constraint = function(self,constraint)
		self:constraint_cancel()
		self._constraint = constraint
		table.insert(self._constraint_watcher,Signal:subscribe(self._constraint, self._constraint.SIGNAL.DESTROY, function()
			self:dtor()
			self:constraint_unselected()
			Signal:publish(self, self.SIGNAL.CONSTRAINTDESTROY)
		end))
		table.insert(self._constraint_watcher,Signal:subscribe(self._constraint, self._constraint.SIGNAL.SELECTED_CHANGED, function(selected)
			if selected then
				self:constraint_selected()
			else
				self:constraint_unselected()
			end
		end))

		constraint:node():listenPropertyChange(self.SLOTS.MASTERPIVOTPOS,function(inst, pos)
			local world_pos = self:master():node():toWorldPosition(pos)
			self:set_master_local_pos(pos)
			self:set_master_world_pos(world_pos)
			if self:slave() then
				self:set_anchor_space()
			end
			Signal:publish(self, self.SIGNAL.MASTERPIVOTPOSCHANGED)
		end)

		constraint:node():listenPropertyChange(self.SLOTS.SLAVEPIVOTPOS,function(inst, pos)
			local world_pos = self:slave():node():toWorldPosition(pos)
			self:set_slave_local_pos(pos)
			self:set_slave_world_pos(world_pos)
			self:set_anchor_space()
			Signal:publish(self, self.SIGNAL.SLAVEPIVOTPOSCHANGED)
		end)
	end,

	set_constraint_normally_on = function(self, on)
		local show = self:constraint():selected() and true or on
		self:constraint():node():setDebugGraphShow(show)
	end,

	constraint = function(self)
		return self._constraint
	end,

	constraint_selected = function(self)
		self:master():set_translucence()
		if self:slave() then
			self:slave():set_translucence()
		end
	end,

	constraint_unselected = function(self)
		self:master():recover_translucence()
		if self:slave() then
			self:slave():recover_translucence()
		end
	end,

	anchor_space = function(self)
		if not self:slave() then
			return 0
		end

		local slave_part = self:slave():node()
		local master_part = self:master():node()
		local slave_pos = self:constraint():slave_local_pos()
		local master_pos = self:constraint():master_local_pos()
		local pos1 = slave_part:toWorldPosition(slave_pos)
		local pos2 = master_part:toWorldPosition(master_pos)
		self:set_slave_world_pos(pos1)
		self:set_master_world_pos(pos2)
		return Lib.getPosDistance(pos1,pos2)
	end,

	set_length = function(self)
		if self:constraint():check_ability(self:constraint().ABILITY.HAVELENGTH) then
			local space = self:anchor_space()
			self:constraint():set_length(space)
		end
	end,

	set_anchor_space = function(self)
		if self:constraint():check_ability(self:constraint().ABILITY.ANCHORSPACE) then
			local space = self:anchor_space()
			self:constraint():set_anchor_space(space)
		end
	end,

	set_master_local_pos = function(self, pos)
		if self:constraint():class() ~= "FixedConstraint" then
			local curr = self:constraint():master_local_pos()
			if math.abs(curr.x - pos.x) < 0.01 and
			   math.abs(curr.y - pos.y) < 0.01 and
			   math.abs(curr.z - pos.z) < 0.01 then
			   return
			end
			self:constraint():set_master_local_pos(pos)
		end
	end,

	set_master_world_pos = function(self, pos)
		if self:constraint():class() ~= "FixedConstraint" then
			local curr = self:constraint():master_world_pos()
			if math.abs(curr.x - pos.x) < 0.01 and
			   math.abs(curr.y - pos.y) < 0.01 and
			   math.abs(curr.z - pos.z) < 0.01 then
			   return
			end
			self:constraint():set_master_world_pos(pos)
		end
	end,

	set_slave_local_pos = function(self, pos)
		if self:constraint():class() ~= "FixedConstraint" then
			local curr = self:constraint():slave_local_pos()
			if math.abs(curr.x - pos.x) < 0.01 and
			   math.abs(curr.y - pos.y) < 0.01 and
			   math.abs(curr.z - pos.z) < 0.01 then
			   return
			end
			self:constraint():set_slave_local_pos(pos)
		end
	end,

	set_slave_world_pos = function(self, pos)
		if self:constraint():class() ~= "FixedConstraint" then
			local curr = self:constraint():slave_world_pos()
			if math.abs(curr.x - pos.x) < 0.01 and
			   math.abs(curr.y - pos.y) < 0.01 and
			   math.abs(curr.z - pos.z) < 0.01 then
			   return
			end
			self:constraint():set_slave_world_pos(pos)
		end
	end,

	set_select = function(self,selected, on)
		self:constraint():set_select_inc(selected, on)
	end,

	remove = function(self)
		local parent = self:constraint():parent()
		parent:remove_child(self:constraint())
	end,

	constraint_cancel = function(self)
		for _,cancel in ipairs(self._constraint_watcher) do
			cancel()
		end
		self._constraint_watcher = {}
	end,

	master_cancel = function(self)
		for _,cancel in ipairs(self._master_watcher) do
			cancel()
		end
		self._master_watcher = {}
	end,

	slave_cancel = function(self)
		for _,cancel in ipairs(self._slave_watcher) do
			cancel()
		end
		self._slave_watcher = {}
	end,

	dtor = function(self)
		self:constraint_cancel()
		self:master_cancel()
		self:slave_cancel()
	end
}

function M:new_constraint()
	assert(self._map)
	local constraint = Lib.derive(constraint_class)
	constraint:init()
	table.insert(self._constraints,constraint)
	Signal:subscribe(constraint, constraint.SIGNAL.CONSTRAINTDESTROY, function()
		self:remove_constraint(constraint:constraint_id())
	end)
	return constraint
end


function M:remove_constraint(id)
	assert(self._map)
	for index, cons in ipairs(self._constraints) do
		if cons:constraint_id() == id then
			cons:dtor()
			table.remove(self._constraints,index)
			return true
		end
	end
	return false
end

function M:check_constraint(object_instance, update_space)
	for _, child in ipairs(object_instance:children()) do
		if child:check_base("Instance_ConstraintBase") then
			local id = tostring(IInstance:id(child:node()))
			local cons = self:query_constraint_by_constraint_id(id)
			if not cons then
				self:relevance_constraint(child)
				cons = self:query_constraint_by_constraint_id(id)
			end
			if update_space then
				cons:anchor_space()
			end
			local State = require "we.view.scene.state"
			self:set_constraint_normally_on(State:constraint_normally_on())
		else
			self:check_constraint(child)
		end
	end
end

--id type string
function M:query_constraint_by_constraint_id(id)
	assert(self._map)
	for _,cons in ipairs(self._constraints) do
		if cons:constraint_id() == id then
			return cons
		end
	end
end

--id type string
function M:query_constraint_by_slave_id(id)
	assert(self._map)
	for _,cons in ipairs(self._constraints) do
		if cons:slave_id() == id then
			return cons
		end
	end
end

--id type string
function M:query_constraint_by_master_id(id)
	assert(self._map)
	for _,cons in ipairs(self._constraints) do
		if cons:master_id() == id then
			return cons
		end
	end
end

function M:query_pivot(id)
	assert(self._map)
	local pivots = {}
	for _,cons in ipairs(self._constraints) do
		table.insert(pivots,cons:master_pivot())
		table.insert(pivots,cons:slave_pivot())
	end

	for _,pivot in ipairs(pivots) do
		local pivot_id = IInstance:id(pivot)
		if pivot_id == id then
			return pivot
		end
	end
end

function M:query_pivot_position(id)
	assert(self._map)
	for _,cons in ipairs(self._constraints) do
		if cons:master_pivot() and IInstance:id(cons:master_pivot()) == id then
			local pos = cons:master_pivot():position()
			return cons:master():node():toWorldPosition(pos)
		end
		if cons:slave_pivot() and IInstance:id(cons:slave_pivot()) == id then
			local pos = cons:slave_pivot():position()
			return cons:slave():node():toWorldPosition(pos)
		end
	end
end

function M:relevance_constraint(cons)
	local constraint = self:new_constraint()
	constraint:set_master(cons:parent())
	constraint:set_constraint(cons)
		
	if cons:slave_part_id() ~= "" then
		local slave = self._map:query_instance(cons:slave_part_id())
		if slave then
			constraint:set_slave(slave)
		end
	end
end

function M:relevance_constraints(map, constraints)
	self._map = map
	self._constraints = {}
	for _, cons in ipairs(constraints) do
		self:relevance_constraint(cons)
	end
end

function M:disrelevance_constraints()
	assert(self._map)
	for _,cons in ipairs(self._constraints) do
		cons:dtor()
	end
	self._constraints = {}
end

function M:check_fixed_constraint(master,slave)
	assert(self._map)
	for _, cons in ipairs(self._constraints) do
		if master == cons:master() and slave == cons:slave() then
			return true
		end
		if master == cons:slave() and slave == cons:master() then
			return true
		end
	end
	return false
end

local function set_master_pivot(cons_instant,master_instant)
	IInstance:set_parent(cons_instant,master_instant)
	local master_pivot = IWorld:get_instance(cons_instant:getMasterPivotID())
	local pos = master_instant:toWorldPosition({ x = 0, y = 0, z = 0 })
	IInstance:set_world_pos(master_pivot,pos)
end

local function set_slave_pivot(cons_instant,slave_instant)
	local slave_pivot = IWorld:get_instance(cons_instant:getSlavePivotID()) 
	local pos = slave_instant:toWorldPosition({ x = 0, y = 0, z = 0 })
	IInstance:set_world_pos(slave_pivot,pos)
end

function M:instant_fixed()
	assert(self._map)
	local receptor = Receptor:bind("instance")
	local parts = receptor:list(
		function(obj)
			return obj:class() == "Part" or obj:class() == "MeshPart" or obj:class() == "PartOperation"
		end
	)
	if Lib.getTableSize(parts) <= 1 then
		return
	end

	local master = parts[1]
	Lib.tableRemove(parts,master)

	local nodes = {}
	for _, slave in ipairs(parts) do
		local ret = self:check_fixed_constraint(master,slave)
		if not ret then
			local meta = Meta:meta("Instance_FixedConstraint"):ctor({
				id = tostring(IWorld:gen_instance_id()),
				masterPartName = master:name()
			})
			local cons = master:new_child(meta)
			set_master_pivot(cons:node(),master:node())
			local id = tostring(IInstance:id(slave:node()))
			cons:set_slave_part_id(id)
			cons:set_slave_part_name(slave:name())
			set_slave_pivot(cons:node(),slave:node())
			table.insert(nodes,cons:node())

			local constraint = self:new_constraint()
			constraint:set_master(master)
			constraint:set_constraint(cons)
			constraint:set_slave(slave)
		end
	end
	Receptor:select("constraint", nodes)
end

function M:set_constraint_normally_on(on)
	assert(self._map)
	for _,cons in ipairs(self._constraints) do
		cons:set_constraint_normally_on(on)
	end
end

function M:cur_map()
	return self._map
end

return M