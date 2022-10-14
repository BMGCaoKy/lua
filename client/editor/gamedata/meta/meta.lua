local Lfs = require "lfs"
local Def = require "editor.def"
local Loader = require "editor.gamedata.meta.loader"

local meta_set_class = {
	init = function(self, path, version)
		self._meta_set = {}
		self._version = version

		self._sequence = {}
		for _, conf in ipairs(Loader(path)) do
			local specifier = assert(conf.specifier)
			local ok, meta_class = pcall(
				require,
				string.format("%s.meta_%s", "editor.gamedata.meta.class", specifier)
			)
			if not ok then
				print(meta_class, string.format("%s.meta_%s", "editor.gamedata.meta.class", specifier))
				return false, string.format("[ERROR] can't find meta specifier.:%s", tostring(specifier))
			end
			local meta = Lib.derive(meta_class)
			meta:init(conf, self)
			self._meta_set[conf.name] = meta
			if conf.specifier == "struct" and meta:inherit("Action_Base") then
				table.insert(self._sequence,conf.name)
			end
		end
	end,

	meta = function(self, type)
		return self._meta_set[type]
	end,

	list = function(self)
		return self._meta_set
	end,

	version = function(self)
		return self._version
	end,

	action_sequence = function(self)
		return self._sequence
	end

}

local function pack_version(major, minor)
	assert(math.tointeger(major) >= 0 and math.tointeger(minor) >= 0)
	return string.format("%s.%s", major, minor)
end

local function unpack_version(version)
	local major, minor = string.match(version, "^(%d+)%.(%d+)$")
	assert(major and minor)
	major, minor = math.tointeger(major), math.tointeger(minor)
	assert(major >= 0 and minor >= 0)
	return major, minor
end

local M = {}

function M:init()
	self._meta_set_list = {}
	self._last_major, self._last_minor = 0, 0
	print(Def.PATH_META_CONFIG)
	self._conf = Lib.read_json_file(Def.PATH_META_CONFIG)
	assert(self._conf)

	self._last_major, self._last_minor = unpack_version(self._conf.version)
	print(string.format("last game data version %s.%s", self._last_major, self._last_minor))

	for fn in Lfs.dir(Def.PATH_META_DIR) do
		if fn ~= "." and fn ~= ".." then
			local path = Lib.combinePath(Def.PATH_META_DIR, fn)
			if Lfs.attributes(path, "mode") == "file" then
				local version = string.match(fn, "^(%d+%.%d+).meta$")
				assert(version, fn)
				assert(not self._meta_set_list[version], 
					string.format("version conflict %s", version)
				)

				print(string.format("load meta version: %s", version))
				local meta_set = Lib.derive(meta_set_class)
				meta_set:init(path, version)
				self._meta_set_list[version] = meta_set
			end
		end
	end
end

function M:version()
	return self._conf.version
end

local function next_version(self, version)
	local major, minor = unpack_version(version)

	if minor == 0 and self._last_major > major then
		return pack_version(major + 1, 0)
	end

	if minor < self._last_minor then
		return pack_version(major, minor + 1)	
	end

	return
end

local function apply_patch(val, patchs, meta_set_from, meta_set_to)
	local vtype = assert(val[Def.OBJ_TYPE_MEMBER])
	for _, patch in ipairs(patchs) do
		local vmeta = meta_set_from:meta(vtype)
		local pmeta = meta_set_from:meta(patch.type)

		local env_funcs = {
			ctor = function(type, rawval)
				local meta = meta_set_to:meta(type)
				return meta:ctor(rawval)
			end
		}

		local converter = load(
			patch.value,
			"",
			"bt",
			setmetatable(env_funcs, {__index = _G})
		)

		pmeta:set_processor(converter)
		val = vmeta:process(val)
		pmeta:set_processor(nil)

		local newtype = val[Def.OBJ_TYPE_MEMBER]
		local newmeta = meta_set_to:meta(newtype)
		assert(newmeta:verify(val, true))
	end

	return val
end

local LOCALTION_FILE = "editor.gamedata.meta.patch.patch"
function M:upgrade(val, version)
	assert(type(val) == "table")
	local meta_set_from = assert(self._meta_set_list[version], version)

	local next_version = next_version(self, version)
	if not next_version then
		local vtype = val[Def.OBJ_TYPE_MEMBER]
		local vmeta = meta_set_from:meta(vtype)
		return vmeta:process(val), version
	end

	table.insert(package.searchers, function(path)
		local version = string.match(path, "^editor.gamedata%.meta%.patch%.(.+)$")
		local sp = package.searchpath(LOCALTION_FILE, package.path)
		path = string.gsub(sp, "patch.lua", string.format("%s.lua", version))

		return loadfile(path), path
	end)
	local ok, patch = pcall(require, string.format("editor.gamedata.meta.patch.%s", next_version))
	assert(ok, patch)
	table.remove(package.searchers)

	local meta_set_to = assert(self._meta_set_list[next_version], next_version)
	val = apply_patch(val, patch.meta, meta_set_from, meta_set_to)

	return self:upgrade(val, next_version)
end


function M:meta_set(version)
	if not version then
		version = self._conf.version
	end

	return self._meta_set_list[version]
end

function M:meta(type)
	return self._meta_set_list[self._conf.version]:meta(type)
end

return M
