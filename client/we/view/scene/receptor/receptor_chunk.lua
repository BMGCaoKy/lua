local Signal = require "we.signal"
local Cmd = require "we.view.scene.cmd.cmd"

local Engine = require "we.engine.engine"
local IWorld = require "we.engine.engine_world"
local IScene = require "we.engine.engine_scene"
local Placer = require "we.view.scene.placer.placer"
local State = require "we.view.scene.state"
local Input = require "we.view.scene.input"
local Receptor = require "we.view.scene.receptor.receptor"

local Base = require "we.view.scene.receptor.receptor_base"

local LIMIT = 200

local M = Lib.derive(Base)

local chunk_class = {
	init = function(self)
		self._orig = { x = 0, y = 0, z = 0 }
		self._pos = { x = 0, y = 0, z = 0 }
		self._size = { x = 0, y = 0, z = 0 }
		self._max = { x = 0, y = 0, z = 0 }

		self._box = nil
		self._chunk = nil
		self._last = nil
		self._press_pos = nil
	end,

	update = function(self)
		self._box:set_pos(self._pos)
		self._chunk:set_pos(self._pos)
	end,

	resize = function(self, min, max)
		self._orig = Lib.copy(min)
		self._pos = Lib.copy(min)
		self._size = {
			x = max.x - min.x + 1,
			y = max.y - min.y + 1,
			z = max.z - min.z + 1
		}
		self._max = {
			x = self._pos.x + self._size.x,
			y = self._pos.y + self._size.y,
			z = self._pos.z + self._size.z
		}

		if self._box then
			IWorld:remove_box_widget(self._box)
			self._box = nil
		end

		if self._chunk then
			IWorld:remove_chunk_widget(self._chunk)
			self._chunk = nil
		end

		self._box = IWorld:create_box_widget(min, max)
		self._chunk = IWorld:create_chunk_widget(
			Engine:make_chunk(min, max),
			min
		)
	end,

	move = function(self, dx, dy, dz)
		self._pos.x = self._pos.x + dx
		self._pos.y = self._pos.y + dy
		self._pos.z = self._pos.z + dz

		self:update()
	end,

	pos = function(self)
		return self._pos
	end,

	max = function(self)
		return self._max
	end,

	bound = function(self)
		return self._pos, {
			x = self._pos.x + self._size.x - 1,
			y = self._pos.y + self._size.y - 1,
			z = self._pos.z + self._size.z - 1,
		}
	end,

	original = function(self)
		return self._orig
	end,

	center = function(self)
		return {
			x = self._pos.x + self._size.x / 2,
			y = self._pos.y + self._size.y / 2,
			z = self._pos.z + self._size.z / 2,
		}
	end,

	size = function(self)
		return self._size
	end,

	dtor = function(self)
		if self._box then
			IWorld:remove_box_widget(self._box)
			self._box = nil
		end

		if self._chunk then
			IWorld:remove_chunk_widget(self._chunk)
			self._chunk = nil
		end
	end,

	adjust = function(self, forward)
		if forward then
			self._orig = Lib.copy(self._pos)
		else
			self._pos = Lib.copy(self._orig)
		end

		self:update()
	end
}

function M:init()
	Base.init(self, "chunk")

	self._chunk = nil
	self._offset = {x = 0, y = 0, z = 0}
	self._moving = false
end

function M:ephemerid()
	return true
end

function M:on_bind()
	self._chunk = Lib.derive(chunk_class)
	self._chunk:init()
end

function M:on_unbind()
	self._chunk:dtor()
	self._chunk = nil
end

function M:center()
	return self._chunk:center()
end

local op_checker = {
	CONFIRM = function(self)
		return self._moving
	end,

	SPIN = function(self)
		Lib.pv(self._offset)
		if self._offset.x ~= 0 or self._offset.y ~= 0 or self._offset.z ~= 0 then
			return false
		end

		return true
	end,

	SCALE = function(self)
		if self._offset.x ~= 0 or self._offset.y ~= 0 or self._offset.z ~= 0 then
			return false
		end

		return true
	end,
	
	COPY = function(self)
		return true
	end,

	CUT = function(self)
		return true
	end,
	
	FILL = function(self)
		return true
	end,

	REPLACE = function(self)
		return true
	end,

	DELETE = function(self)
		return true
	end,

	MIRROR = function(self)
		return true
	end
}

local op_executer = {	
	MOVE = function(self, offset, pos_d)
		local pos_s = self:center()
		local dx = math.floor(pos_d.x - pos_s.x)
		local dy = math.floor(pos_d.y - pos_s.y)
		local dz = math.floor(pos_d.z - pos_s.z)
		if dx == 0 and dy == 0 and dz == 0 then
			return
		end

		self._offset.x = self._offset.x + dx
		self._offset.y = self._offset.y + dy
		self._offset.z = self._offset.z + dz

		self._chunk:move(dx, dy, dz)

		self._moving = true
	end,

	SPIN = function(self, direction)
		local obj = {}
		local ids = {}
		local pos = {}
		local min = self._chunk:original()
		local size = self._chunk:size()
		local lx = size.x
		local ly = size.y
		local lz = size.z

		--0:x顺时针 1:x逆时针 2:y顺时针 3:y逆时针 4:z顺时针 5:z逆时针
		if direction == 0 then
			for i = 1, lx do
				for k = lz, 1, -1 do
					for j = 1, ly do
						pos = {
							x = i + min.x - 1,
							y = j + min.y - 1,
							z = k + min.z - 1
						}
						local id = Engine:get_block(pos)
						table.insert(ids,id)
					end
				end
			end
			obj.lx = lx
			obj.ly = lz
			obj.lz = ly
			obj.model = ids
		elseif direction == 1 then
			for i = 1, lx do
				for k = 1, lz do
					for j = ly, 1, -1 do
						pos = {
							x = i + min.x - 1,
							y = j + min.y - 1,
							z = k + min.z - 1
						}
						local id = Engine:get_block(pos)
						table.insert(ids,id)
					end
				end
			end
			obj.lx = lx
			obj.ly = lz
			obj.lz = ly
			obj.model = ids
		elseif direction == 2 then
			for k = 1, lz do
				for j = 1, ly do
					for i = lx, 1, -1 do
						pos = {
							x = i + min.x - 1,
							y = j + min.y - 1,
							z = k + min.z - 1
						}
						local id = Engine:get_block(pos)
						table.insert(ids,id)
					end
				end
			end
			obj.lx = lz
			obj.ly = ly
			obj.lz = lx
			obj.model = ids
		elseif direction == 3 then
			for k = lz, 1, -1 do
				for j = 1, ly do
					for i = 1, lx do
						pos = {
							x = i + min.x - 1,
							y = j + min.y - 1,
							z = k + min.z - 1
						}
						local id = Engine:get_block(pos)
						table.insert(ids,id)
					end
				end
			end
			obj.lx = lz
			obj.ly = ly
			obj.lz = lx
			obj.model = ids
		elseif direction == 4 then
			for j = ly, 1, -1 do
				for i = 1, lx do
					for k = 1, lz do
						pos = {
							x = i + min.x - 1,
							y = j + min.y - 1,
							z = k + min.z - 1
						}
						local id = Engine:get_block(pos)
						table.insert(ids,id)
					end
				end
			end
			obj.lx = ly
			obj.ly = lx
			obj.lz = lz
			obj.model = ids
		elseif direction == 5 then
			for j = 1, ly do
				for i = lx, 1, -1 do
					for k = 1, lz do
						pos = {
							x = i + min.x - 1,
							y = j + min.y - 1,
							z = k + min.z - 1
						}
						local id = Engine:get_block(pos)
						table.insert(ids,id)
					end
				end
			end
			obj.lx = ly
			obj.ly = lx
			obj.lz = lz
			obj.model = ids
		end
		local chunkobj = Engine:make_chunk_bytable(obj, true)
		local placer = Placer:bind("chunk")
		placer:select(chunkobj)
		Receptor:unbind()
	end,

	CONFIRM = function(self, ok)
		if ok then
			Cmd:chunk_move(self._chunk:original(), self._chunk:size(), self._offset)
		end

		self._chunk:adjust(ok)

		Signal:publish(self, M.SIGNAL.BOUND_BOX_CHANGED)
		self._moving = false
		self._offset = {x = 0, y = 0, z = 0}
	end,

	SCALE = function(self, aix, offset, stretch, pos_d)
		local aix = aix == 1 and "x" or aix == 2 and "y" or "z"

		local size = self._chunk:size()
		if size[aix] <= 1 and not stretch then
			return
		end
		
		local pos_s = self:center()
		local dist = math.floor((pos_d[aix] - pos_s[aix]) * 2)
		if dist == 0 then
			return
		end
		
		local min, max = self._chunk:bound()
		
		if stretch then
			if 0 > offset[aix] then
				if 0 < dist then 
					return 
				end
				min[aix] = min[aix] + dist
				if max[aix] - min[aix] > LIMIT then
					min[aix] = max[aix] - LIMIT
				end
			else
				if 0 > dist then 
					return 
				end
				max[aix] = max[aix] + dist
				if max[aix] - min[aix] > LIMIT then
					max[aix] = min[aix] + LIMIT
				end
			end
		else
			if 0 > offset[aix] then
				max[aix] = max[aix] + dist
				if min[aix] > max[aix] then
					max[aix] = min[aix]
				end
				if max[aix] - min[aix] > LIMIT then
					max[aix] = min[aix] + LIMIT
				end
			else
				min[aix] = min[aix] + dist
				if max[aix] < min[aix] then
					min[aix] = max[aix]
				end
				if max[aix] - min[aix] > LIMIT then
					min[aix] = max[aix] - LIMIT
				end
			end
		end

		-- local mm = max[aix] - min[aix]
		-- if 0 > mm + dist then
		-- 	if stretch then
		-- 		return
		-- 	end
		-- end
		
		-- local positive = (stretch and dist > 0) or (not stretch and dist < 0)
		-- if positive then
		-- 	max[aix] = max[aix] + dist
		-- else
		-- 	min[aix] = min[aix] + dist
		-- end
		
		self._chunk:resize(min, max)
		Signal:publish(self, M.SIGNAL.BOUND_BOX_CHANGED)
	end,

	COPY = function(self)
		local pos = self._chunk:original()
		local size = self._chunk:size()
		Cmd:chunk_copy(pos,size)
	end,

	CUT = function(self)
		local pos = self._chunk:original()
		local size = self._chunk:size()
		Cmd:chunk_cut(pos,size)
	end,

	REPLACE = function(self, obj)
		local min = {}
		local max = {}
		min = self._chunk:original()
		local size = self._chunk:size()
		max = {
			x = min.x + size.x - 1,
			y = min.y + size.y - 1,
			z = min.z + size.z - 1,
		}
		Cmd:chunk_replace(min, max, obj)
	end,

	FILL = function(self, block_name)
		local pos = self._chunk:original()
		local size = self._chunk:size()
		local chunk = Engine:make_chunk(pos, {
			x = pos.x + size.x - 1,
			y = pos.y + size.y - 1,
			z = pos.z + size.z - 1,
		})
		Cmd:chunk_fill(pos, chunk, block_name)
	end,

	DELETE = function(self)
		local pos = self._chunk:original()
		local size = self._chunk:size()
		local chunk = Engine:make_chunk(pos, {
			x = pos.x + size.x - 1,
			y = pos.y + size.y - 1,
			z = pos.z + size.z - 1,
		})
		Cmd:chunk_dele(pos, chunk)
	end,

	MIRROR = function(self, direction)
		local ids = {}
		local pos = {}
		local min = self._chunk:original()
		local size = self._chunk:size()
		local lx = size.x
		local ly = size.y
		local lz = size.z

		if direction == 0 or direction == 1 then
			--up
			for i = 1, lx do
				for j = ly, 1, -1 do
					for k = 1, lz do
						pos = {
							x = i + min.x - 1,
							y = j + min.y - 1,
							z = k + min.z - 1
						}
						local id = Engine:get_block(pos)
						table.insert(ids,id)
					end
				end
			end
		elseif direction == 2 or direction == 3 then
			--left
			for i = lx, 1, -1 do
				for j = 1, ly do
					for k = 1, lz do
						pos = {
							x = i + min.x - 1,
							y = j + min.y - 1,
							z = k + min.z - 1
						}
						local id = Engine:get_block(pos)
						table.insert(ids,id)
					end
				end
			end
		elseif direction == 4 or direction == 5 then
			--front
			for i = 1, lx do
				for j = 1, ly do
					for k = lz, 1, -1 do
						pos = {
							x = i + min.x - 1,
							y = j + min.y - 1,
							z = k + min.z - 1
						}
						local id = Engine:get_block(pos)
						table.insert(ids,id)
					end
				end
			end
		end
		local obj = {}
		obj.lx = lx
		obj.ly = ly
		obj.lz = lz
		obj.model = ids
		local chunkobj = Engine:make_chunk_bytable(obj, true)
		local placer = Placer:bind("chunk")
		placer:select(chunkobj)
		Receptor:unbind()
	end
}

function M:check_op(op, ...)
	local proc = op_checker[string.upper(op)]
	if proc then
		return proc(self, op, ...)
	end

	return op_executer[string.upper(op)] ~= nil
end

function M:exec_op(op, ...)
	local proc = op_executer[string.upper(op)]
	assert(proc, string.format("op [%s] is not support", op))
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
	return proc(self, ...)
end

function M:attach(min, max)
	self._chunk:resize(min, max)
	Signal:publish(self, M.SIGNAL.BOUND_BOX_CHANGED)
end

function M:chunk()
	return self._chunk
end

function M:on_key_release(key)
	if Input:check_key_press(Input.KEY_CODE.Key_Control) then
		if key == Input.KEY_CODE.Key_C then
			self:exec_op("COPY")
			return true
		end
	end
	if key == Input.KEY_CODE.Key_Delete then
		self:exec_op("DELETE")
		return true
	end
end

function M:on_mouse_release(x, y, button, is_click)
	if is_click and Engine:detect_collision(self._chunk:pos(), self._chunk:max()) then
		if button == Input.MOUSE_BUTTON_TYPE.BUTTON_RIGHT then
			if self._type then
				Engine:open_menu(self._type)
				return true
			end
		end
	end
end

return M
