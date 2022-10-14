local def = require "editor.def"
local setting = require "common.setting"
local base = require "editor.cmds.cmd_base"
local engine = require "editor.engine"

local M = Lib.derive(base)

local BUCKET_SIZE		= def.BLOCK_ITERATE_STEP
local BUCKET_STR_FMT	= "<" .. string.rep("H", BUCKET_SIZE)
local BUCKET_STR_SIZE	= string.packsize("<H") * BUCKET_SIZE

function M:init(pos_min, pos_max, rule)
	--assert(next(rule))

	base.init(self)
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
			local id_to = nil
            if tonumber(name_to) then
                id_to = tonumber(name_to)
            else
				id_to = setting:name2id("block", name_to)
			end
			self._rule[id_from] = id_to
		end
	end
end

function M:can_redo()
	if not base.can_redo(self) then
		return false
	end

	return not self._process
end

function M:can_undo()
	if not base.can_undo(self) then
		return false
	end

	return not self._process
end

function M:redo()
	assert(not self._process)

	base.redo(self)

	self._process = true

	engine:open_progress_window("replace")

	-- create chunk file
	if not self._chunk_file then

		local bucket = {}
		local iter = engine:iterate_block(
			self._pos_min,
			self._pos_max,
			function(pos)
				table.insert(bucket, engine:get_block(pos))
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
			self._chunk_file = packet
			bucket = {}

			if not fin then
				return true	-- continue
			end

		end)
	end

	local iter = engine:iterate_block(
		self._pos_min,
		self._pos_max,
		function(pos)
			local id_src = engine:get_block(pos)
			local id_dest = self._rule[id_src]
			if id_dest then
				engine:set_block(pos, id_dest)
			end
		end, BUCKET_SIZE
	)

	World.Timer(1, function()
		local fin, rmn, tot = iter()

		engine:update_req_count(fin, rmn, tot) 
		if not fin then
			return true
		end

		engine:set_bModify(true)
		-- finish
		self._process = false
	end)
end

function M:undo()
	assert(not self._process)

	base.undo(self)

	self._process = true
	engine:open_progress_window("replace")
	
	local bucket = {}
	local iter = engine:iterate_block(
		self._pos_min,
		self._pos_max,
		function(pos)
			local id = assert(table.remove(bucket, 1))
			engine:set_block(pos, id)
		end, BUCKET_SIZE
	)

	World.Timer(1, function()
		local packet = self._chunk_file
		bucket = {string.unpack(BUCKET_STR_FMT, packet)}
		table.remove(bucket)	-- remove first unread index
		assert(#bucket == BUCKET_SIZE)

		local fin, rmn, tot = iter()

		engine:update_req_count(fin, rmn, tot, false)
		if not fin then
			return true
		end

		-- finish
		engine:set_bModify(true)
		self._process = false
	end)
end

return M
