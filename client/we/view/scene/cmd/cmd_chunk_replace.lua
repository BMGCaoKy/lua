local def = require "we.def"
local setting = require "common.setting"
local Base = require "we.cmd.cmd_base"
local Engine = require "we.engine.engine"
local Receptor = require "we.view.scene.receptor.receptor"

local M = Lib.derive(Base)

local BUCKET_SIZE		= def.BLOCK_ITERATE_STEP
local BUCKET_STR_FMT	= "<" .. string.rep("H", BUCKET_SIZE)
local BUCKET_STR_SIZE	= string.packsize("<H") * BUCKET_SIZE

function M:init(pos_min, pos_max, rule)
	--assert(next(rule))

	Base.init(self)
	self._pos_min = pos_min
	self._pos_max = pos_max
	self._rule = {}

	self._chunk_file = nil
	self._process = false

	for name_from, name_to in pairs(rule or {}) do
		if name_from ~= name_to then
			local id_from = nil
			if tonumber(name_from) then
				id_from = tonumber(name_from)
			else
				id_from = setting:name2id("block", name_from)
			end
			local id_to = setting:name2id("block", name_to)
			self._rule[id_from] = id_to
		end
	end
end

function M:can_redo()
	if not Base.can_redo(self) then
		return false
	end

	return not self._process
end

function M:can_undo()
	if not Base.can_undo(self) then
		return false
	end

	return not self._process
end

function M:redo()
	assert(not self._process)

	Base.redo(self)

	self._process = true

	Engine:open_progress_window("replace")

	-- create chunk file
	if not self._chunk_file then
		self._chunk_file = io.tmpfile()

		local bucket = {}
		local iter = Engine:iterate_block(
				self._pos_min,
				self._pos_max,
				function(pos)
					table.insert(bucket, Engine:get_block(pos))
				end, BUCKET_SIZE
		)

		World.Timer(1, function()
			local fin, rmn, tot = iter()

			assert(#bucket > 0)
			assert(#bucket == BUCKET_SIZE or fin)

			-- padding
			if fin then
				for i = 1, BUCKET_SIZE - #bucket do
					table.insert(bucket, 0)
				end
			end

			assert(#bucket == BUCKET_SIZE)
			local packet = string.pack(BUCKET_STR_FMT, table.unpack(bucket))
			self._chunk_file:write(packet)
			bucket = {}

			if not fin then
				return true	-- continue
			end

			-- finish
			self._chunk_file:seek("set", 0)
		end)
	end

	local iter = Engine:iterate_block(
			self._pos_min,
			self._pos_max,
			function(pos)
				local id_src = Engine:get_block(pos)
				local id_dest = self._rule[id_src]
				if id_dest then
					Engine:set_block(pos, id_dest)
				end
			end, BUCKET_SIZE
	)

	World.Timer(1, function()
		local fin, rmn, tot = iter()

		Engine:update_req_count(fin, rmn, tot)
		if not fin then
			return true
		end

		Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
		-- finish

		if Receptor:binding():type() == "chunk" then
			Receptor:unbind()
			local receptor = Receptor:bind("CHUNK")
			receptor:attach(Lib.boxBound(self._pos_min, self._pos_max))
		end

		self._process = false
		Lib.emitEvent(Event.EVENT_UNDO_REDO)
	end)
end

function M:undo()
	assert(not self._process)

	Base.undo(self)

	self._process = true
	Engine:open_progress_window("replace")

	self._chunk_file:seek("set", 0)

	local bucket = {}
	local iter = Engine:iterate_block(
			self._pos_min,
			self._pos_max,
			function(pos)
				local id = assert(table.remove(bucket, 1))
				Engine:set_block(pos, id)
			end, BUCKET_SIZE
	)

	World.Timer(1, function()
		local packet = self._chunk_file:read(BUCKET_STR_SIZE)
		bucket = {string.unpack(BUCKET_STR_FMT, packet)}
		table.remove(bucket)	-- remove first unread index
		assert(#bucket == BUCKET_SIZE)

		local fin, rmn, tot = iter()

		Engine:update_req_count(fin, rmn, tot, false)
		if not fin then
			return true
		end

		if Receptor:binding():type() == "chunk" then
			Receptor:unbind()
			local receptor = Receptor:bind("CHUNK")
			receptor:attach(Lib.boxBound(self._pos_min, self._pos_max))
		end
		-- finish
		Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
		self._process = false
		--替换结束发送信号
		Lib.emitEvent(Event.EVENT_UNDO_REDO)
	end)
end

return M
