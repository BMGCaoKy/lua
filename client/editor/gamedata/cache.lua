local Lfs = require "lfs"
local Misc = require "misc"

local M = {}

function M:init()
	self._cache = {}
	self._resident = nil	-- ��ֹ�� gc
end

function M:add(path, content)
	self._cache[path] = content
	VFS:add(path, content)
end

function M:pack()
	local id = GenUuid()
	self._resident = VFS:export(id, self._cache)
	return id
end

function M:pop()
	self._resident = nil
end

function M:dump(path)
	-- todo ����
end

return M
