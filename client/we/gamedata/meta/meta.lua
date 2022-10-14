local Lfs = require "lfs"
local Def = require "we.def"
local Loader = require "we.gamedata.meta.loader"
local Configure = require "we.gamedata.meta.custom_configure"

local meta_set_class = {
	init = function(self, path, version)
		self._meta_set = {}
		self._patch = nil
		self._version = version

		self._action_sequence = {}
		self._widget_sequence = {}
		self._widget_trigger_sequence = {}
	
		local confs = Loader(path, Def.PATH_ADDITIONAL_META )
		for _, conf in ipairs(confs) do
			local specifier = assert(conf.specifier)
			local ok, meta_class = pcall(
				require,
				string.format("%s.meta_%s", "we.gamedata.meta.class", specifier)
			)
			if not ok then
				print(meta_class, string.format("%s.meta_%s", "we.gamedata.meta.class", specifier))
				return false, string.format("[ERROR] can't find meta specifier.:%s", tostring(specifier))
			end
			local meta = Lib.derive(meta_class)
			meta:init(conf, self)
			self._meta_set[conf.name] = meta
			if conf.specifier == "struct" and meta:inherit("Action_Base") then
				table.insert(self._action_sequence,conf.name)
			end
			if conf.specifier == "struct" and meta:inherit("Window") then
				table.insert(self._widget_sequence,conf.name)
			end
			if conf.specifier == "struct" and meta:inherit("Trigger_Widget") then
				table.insert(self._widget_trigger_sequence,conf.name)
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
		return self._action_sequence
	end,

	widget_sequence = function(self)
		return self._widget_sequence
	end,

	widget_trigger_sequence = function (self)
		return self._widget_trigger_sequence
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

function M:init(dev)
	self._meta_set_list = {}
	self._last_major, self._last_minor = 0, 0
	self._conf = Lib.read_json_file(Def.PATH_META_CONFIG)
	assert(self._conf)
	self._dev = dev or "dev"

	self._last_major, self._last_minor = unpack_version(self._conf.version)

	print(string.format("last game data version %s.%s", self._last_major, self._last_minor))
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
	local vmeta = meta_set_from:meta(vtype)
	val = vmeta:ctor(val)
	local pmeta_list = {}
	for _, patch in ipairs(patchs) do
		local pmeta = meta_set_from:meta(patch.type)
		pmeta:set_processor(patch.value)
		table.insert(pmeta_list, pmeta)
	end
	val = vmeta:process(val)
	for _, pmeta in ipairs(pmeta_list) do
		pmeta:set_processor(nil)	
	end
	pmeta_list = {}

	local newtype = val[Def.OBJ_TYPE_MEMBER]
	local newmeta = meta_set_to:meta(newtype)
	local ok, errmsg = newmeta:verify(val)
	assert(ok, errmsg)

	return val
end

local LOCALTION_FILE = "we.gamedata.meta.patch.patch"
function M:upgrade(val, version)
	assert(type(val) == "table")
	local meta_set_from = assert(self:meta_set(version), version)

	local next_version = next_version(self, version)
	if not next_version then
		local vtype = assert(val[Def.OBJ_TYPE_MEMBER])
		local vmeta = meta_set_from:meta(vtype)
		return vmeta:process(vmeta:ctor(val)), version
	end

	local meta_set_to = assert(self:meta_set(next_version), next_version)
	if not meta_set_to._patch then
		local sp = package.searchpath(LOCALTION_FILE, package.path)
		local path = string.gsub(sp, "patch.lua", string.format("%s.lua", next_version))
		local env_funcs = {
			ctor = function(type, rawval)
				local meta = meta_set_to:meta(type)
				return meta:ctor(rawval)
			end
		}
		
		local chunk, errmsg = loadfile(path, "bt", setmetatable(env_funcs, {__index = _G}))
		assert(chunk, errmsg)
		meta_set_to._patch = chunk()
	end

	local patch = meta_set_to._patch
	local meta_set_to = assert(self:meta_set(next_version), next_version)
	val = apply_patch(val, patch.meta, meta_set_from, meta_set_to)

	return self:upgrade(val, next_version)
end

function M:meta_set(version)
	if not version then
		version = self._dev
	end

	if not self._meta_set_list[version] then
		local path = Lib.combinePath(Def.PATH_META_DIR, version..".meta")
		assert(Lfs.attributes(path, "mode") == "file", path)
		local meta_set = Lib.derive(meta_set_class)
		meta_set:init(path, version)
		if version == self._dev and Lib.fileExists(Def.PATH_META_CUSTOM_CONFIG) then
			-- PGC/UGC版本配置
			Configure(meta_set, Def.PATH_META_CUSTOM_CONFIG)
		end
		self._meta_set_list[version] = meta_set
		print(string.format("load meta version: %s", version))
	end

	return assert(self._meta_set_list[version])
end

function M:meta(type)
	return self:meta_set():meta(type)
end

return M
