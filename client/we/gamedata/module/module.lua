local Def = require "we.def"

local M = {}

function M:init()
	self._modules = {}

	local conf = Lib.read_json_file(Def.PATH_MODULE_CONFIG)
	for _, mc in ipairs(conf.module) do
		local ok, ret = pcall(require, string.format("%s.module_%s.module_%s", "we.gamedata.module.class", mc.name, mc.name))
		assert(ok, ret)

		local mo = Lib.derive(ret)
		mo:init(mc.name)
		table.insert(self._modules, mo)
	end
end

function M:preprocess(export)
	for _, mo in pairs(self._modules) do
		mo:preprocess(export)
	end
end

function M:load()
	for _, mo in ipairs(self._modules) do
		mo:load()
	end
end

function M:save()
	for _, mo in pairs(self._modules) do
		mo:save()
	end
end

function M:modified()
	for _, mo in pairs(self._modules) do
		local _modified = mo:modified()
		if _modified then
			return true
		end
	end
	return false
end

function M:list()
	return self._modules
end

function M:module(name)
	for _, mo in ipairs(self._modules) do
		if mo:name() == name then
			return mo
		end
	end
end

return M
