local TreeSet = require "we.gamedata.vtree"
local VN = require "we.gamedata.vnode"
local Signal = require "we.signal"
local Map = require "we.view.scene.map"
local Def = require "we.def"
local Constraint = require "we.view.scene.logic.constraint"
local Bunch = require "we.view.scene.bunch"

local M = {}

local function on_map_change(self)
	local on = self:constraint_normally_on()
	local map = self._root["active_map"]
	Map:change_map(map)
	if self._init then
		Constraint:set_constraint_normally_on(on)
	end

	local Receptor = require "we.view.scene.receptor.receptor"
	local receptor = Receptor:binding()
	if receptor and receptor:ephemerid() then
		Receptor:unbind()
	end

	local Picker = require "we.view.scene.picker.picker"
	local picker = Picker:binding()
	if picker then
		Picker:bind(Picker.MODE.RECT)
	end

	local Selector = require "we.view.scene.selector.selector"
	Selector:unbind(true)
end

function M:init()
	local tree = assert(TreeSet:create("EDIT_STATE_SCENE", {}, "TREE_ID_SCENE_STATE"))
	self._root = tree:root()
	self._init = false

	Signal:subscribe(self._root, Def.NODE_EVENT.ON_ASSIGN, function(key)
		if key == "active_map" then
			on_map_change(self)
			self._init = true
		elseif key == "instantfixed_state" then
			if self._root.instantfixed_state then
				Constraint:instant_fixed()
				self._root.instantfixed_state = false
			end
		elseif key == "constraint_normally_on" then
			local on = self:constraint_normally_on()
			Constraint:set_constraint_normally_on(on)
		end
	end)

	Signal:subscribe(Bunch, Bunch.SIGNAL.ON_TREE_CHANGED, function(tid, clear)
		self:focus_tree(tid, clear)
	end)

	-- placer
	do
		local Placer = require "we.view.scene.placer.placer"
		Signal:subscribe(Placer, Placer.SIGNAL.ON_BIND_CHANGED, function(placer)
			if not placer then
				local Picker = require "we.view.scene.picker.picker"
				local picker = Picker:binding()
				if not picker then
					Picker:bind(Picker.MODE.RECT)
				end
				return
			end

			local Receptor = require "we.view.scene.receptor.receptor"
			local receptor = Receptor:binding()
			if receptor and receptor:ephemerid() then
				Receptor:unbind()
			end

			local Picker = require "we.view.scene.picker.picker"
			local picker = Picker:binding()
			if picker then
				Picker:unbind()--选了方块之后，两点框选还在
			end
			local Gizmo = require "we.view.scene.gizmo"
			self:gizmo()["type"] = Gizmo.TYPE.NONE
			local Selector = require "we.view.scene.selector.selector"
			Selector:unbind(true)
		end)
	end

	-- picker
	do
		local Picker = require "we.view.scene.picker.picker"
		Signal:subscribe(Picker, Picker.SIGNAL.ON_BIND_CHANGED, function(picker)
			if not picker then
				return
			end

			local Placer = require "we.view.scene.placer.placer"
			Placer:unbind()
		end)	
	end

	-- selector
	do
		local Selector = require "we.view.scene.selector.selector"
		Signal:subscribe(Selector, Selector.SIGNAL.ON_BIND_CHANGED, function(selector)
			if not selector then
				VN.assign(self._root, "selector_state", false, VN.CTRL_BIT.SYNC)
				return
			end			

			local Placer = require "we.view.scene.placer.placer"
			Placer:unbind()

			local Picker = require "we.view.scene.picker.picker"
			local picker = Picker:binding()
			if picker then
				picker:reset()
			end

			VN.assign(self._root, "selector_state", true, VN.CTRL_BIT.SYNC)
		end)
	end

	do
		Signal:subscribe(self._root, Def.NODE_EVENT.ON_ASSIGN, function(key)
			if key == "part_align" then
				local flag = self:part_align()
				Blockman.instance:setRayTestPartAutoRotate(flag)
			end
		end)
	end
end

function M:placer()
	return self._root["placer"]
end

function M:part_place_settings()
	return self._root["part_place_settings"]
end

function M:picker()
	return self._root["picker"]
end

function M:selector()
	return self._root["selector"]
end

function M:selector_clear()
	self:selector()["mode"] = ""
	self:selector()["data"] = ""
end

function M:gizmo()
	return self._root["gizmo"]
end

function M:focus(vnode)
	if not vnode then
		self._root["focus"] = { tree = "", path = ""}
	else
		local tree = VN.tree(vnode)
		local path = VN.path(vnode)

		self._root["focus"] = { tree = tree:id(), path = path}
	end
end

function M:focus_tree(id, clear)
	self._root["focus"] = { tree = id, path = "", clear = clear}
end

function M:set_rect_pick_state(state)
	self._root["rect_pick_state"] = state
end

function M:set_custom_collision_editing(state,id)
	self._root["custom_collision_editing"]=state
	self._root["collision_id"]=tostring(id)
end

function M:get_custom_collision_editing()
	return self._root["custom_collision_editing"],self._root["collision_id"]
end

function M:set_point_pick_state(state)
	self._root["point_pick_state"] = state
end

function M:set_rect_pick_region(from, to)
	local left = math.min(from.x, to.x) 
	local top = math.min(from.y, to.y)

	local width = math.abs(from.x - to.x)
	local height = math.abs(from.y - to.y)

	self._root["rect_pick_region"] = {left = left, top = top, width = width, height = height}
end

function M:set_active_map(map)
	self._root["active_map"] = map
end

function M:operator()
	return self._root["operator"]
end

function M:set_part_place_settings(value)
	self._root["part_place_settings"] = value
end

function M:set_enable(enable)
	self._root["enable"] = enable
end

function M:enable()
	return self._root["enable"]
end

function M:part_place_setting()
	return self._root["part_place_settings"]
end

function M:part_align()
	return self._root["part_align"]
end

function M:instance_align_setting()
	return self._root["instance_align_setting"]
end

function M:constraint_normally_on()
	return self._root["constraint_normally_on"]
end

function M:pb_type()
	return self._root["pb_type"]
end

function M:get_root()
	return self._root
end


return M
