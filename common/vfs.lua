local MemoryFile = require "memoryfile"
local Misc = require "misc"
local Seri = require "seri"
local Lfs = require "lfs"

local CAPACITY = 1024 * 1204 * 128

function VFS:init()
	self._files = {}
	self._dirs = {}

	if MEMORY_FILE and MEMORY_FILE ~= "" then
		self:import(MEMORY_FILE)
		self:start()
	end

	self._hook = {}
end

function VFS:import(id)
	local sm = Misc.win_open_sharememory(id)
	local files = Seri.deseristring_string(sm:read())
	for path, content in pairs(files) do
		self:add(path, content)
	end
end

function VFS:export(id, files)
	if not self._hook[id] then
		self._hook[id] = Misc.win_create_sharememory(id, CAPACITY)
	end
	
	local chunk = Seri.serialize_string(files)
	self._hook[id]:write(chunk)

	return self._hook[id]
end

function VFS:add(path, content)
	path = Lib.normalizePath(path)

	if type(content) == "string" then
		local file = MemoryFile.open(path, "wb")
		file:write(content)
		file:close()
		self._files[path] = file
	else
		-- 延迟加载
		assert(type(content) == "function")
		self._files[path] = content
	end

	local names = {}
	for name in string.gmatch(path, "[^/]+") do
		if name ~= "." then
			table.insert(names, name)
		end
	end

	local fn = table.remove(names)
	local curr = self._dirs
	for _, name in ipairs(names) do
		curr[name] = curr[name] or {}
		assert(type(curr[name]) == "table")
		curr = curr[name]
	end

	local function curr_time()
		local now = os.time()

		if not curr[fn] then
			return now
		end

		if curr[fn] >= now then
			return curr[fn] + 0.01
		end

		return now
	end

	curr[fn] = curr_time()
end

function VFS:del(path)
	local file = self._files[path]
	if file then
		MemoryFile.remove(file)
		self._files[path] = nil
	end

	local names = {}
	for name in string.gmatch(path, "[^/]+") do
		if name ~= "." then
			table.insert(names, name)
		end
	end

	local function remove(dirs, names)
		local name = table.remove(names, 1)

		if not dirs then
			return true
		end

		if not next(names) then
			dirs[name] = nil
		else
			if remove(dirs[name], names) then
				dirs[name] = nil
			end
		end

		return not next(dirs)
	end

	remove(self._dirs, names)
end

function VFS:check_path(path)
	local names = {}
	local cd = self._dirs
	for name in string.gmatch(path, "[^/]+") do
		if name ~= "." then
			if type(cd) ~= "table" then
				return false
			end
			cd = cd[name]
		end
	end

	return true
end

local io_open, lfs_dir, lfs_attributes
function VFS:start()
	io_open = io_open or io.open
	
	io.open = function(path, mod, raw)
		path = Lib.normalizePath(path)
		repeat
			if raw then
				break
			end

			if mod and string.sub(mod, 1, 1) ~= 'r' then
				break
			end

			if not self:check_path(path) then
				break
			end

			local info = self._files[path]
			if not info then
				break
			end

			if type(info) == "function" then
				local content = info()
				local file = MemoryFile.open(path, "wb")
				file:write(content)
				file:close()
				self._files[path] = file
			end

			local ret = MemoryFile.open(path, "r")
			if  not ret then
				break
			end

			return ret
		until(true)
	
		return io_open(path, mod)
	end

	lfs_dir = lfs_dir or lfs.dir
	lfs.dir = function(dir, raw)
		dir = Lib.normalizePath(dir)
		repeat
			if raw then
				break
			end

			local curr = self._dirs
			for name in string.gmatch(dir, "[^/]+") do
				if name ~= "." then
					curr = curr[name]
					if type(curr) ~= "table" then
						break
					end
				end
			end

			if type(curr) ~= "table" then
				goto NOT_FIND
			end

			local entries = Lib.copy(curr)
			for entry in lfs_dir(dir) do
				entries[entry] = true
			end

			return next, entries
		until(true)

	::NOT_FIND::
		return lfs_dir(dir)
	end

	lfs_attributes = lfs_attributes or lfs.attributes
	lfs.attributes = function(path, attributename, raw)
		path = Lib.normalizePath(path)
		repeat
			if raw then
				break
			end

			if not self:check_path(path) then
				break
			end

			local curr = self._dirs
			for name in string.gmatch(path, "[^/]+") do
				if name ~= "." then
					if type(curr) == "table" then
						curr = curr[name]
					else
						goto NOT_FIND
					end
				end
			end
			if not curr then
				goto NOT_FIND
			end

			if attributename then
				if attributename == "mode" then
					if type(curr) == "table" then
						return "directory"
					else
						return "file"
					end
				elseif attributename == "modification" then
					if type(curr) == "table" then
						assert(false, "dir modification can't support")
					else
						return curr
					end
				else
					assert(false, attributename)
				end
			else
				local attrs = {}

				if type(curr) == "table" then
					attrs["mode"] = "directory"
				else
					attrs["mode"] = "file"
				end

				return attrs
			end
		until(true)
	::NOT_FIND::
		return lfs_attributes(path, attributename, raw)
	end
end

VFS:init()
