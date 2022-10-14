local Def = require "editor.def"

local M = {}

function M:init()
	self._modules = {}
	local conf = Lib.read_json_file(Def.PATH_MODULE_CONFIG)
	for _, mc in ipairs(conf.module) do
		self:new(mc.name, mc.version)
	end
	self:load()

	local ret = require "editor.gamedata.module.class.module_temp"
	local mo = Lib.derive(ret)
	mo:init()
	self._modules["temp"] = mo
end

function M:list()
	return self._modules
end

function M:module(name)
	return self._modules[name]
end

function M:new(mn)
	assert(not self._modules[mn], string.format("[ERROR] module '%s' is exist", mn))

	local ok, ret = pcall(require, string.format("%s.module_%s.module_%s", "editor.gamedata.module.class", mn, mn))
	assert(ok, ret)

	local mo = Lib.derive(ret)
	mo:init(mn)
	self._modules[mn] = mo
	
	Lib.emitEvent(Event.EVENT_EDITOR_MODULE_NEW, mn)
end

function M:load()
	local conf = Lib.read_json_file(Lib.combinePath(Def.PATH_GAME_META_DIR, "module.json"))
	assert(conf)

	for _, mc in ipairs(conf.module) do
		local mo = self._modules[mc.name]
		if mo then
			mo:load(mc.version)
		else
			print("[warring] module '%s' is end of support", mc.name)
		end
	end
end

function M:save()
	for _, mo in pairs(self._modules) do
		mo:save()
	end

	local module = {}
	local conf = Lib.read_json_file(Def.PATH_MODULE_CONFIG)
	for _, mc in ipairs(conf.module) do
		table.insert(module, {
			name = mc.name,
			version = mc.version
		})
	end

	local chunk = Lib.toJson({module = module})
	local file = io.open(Lib.combinePath(Def.PATH_GAME_META_DIR, "module.json"), "w+")
	assert(file)
	file:write(chunk)
	file:close()
end

function M:dump()
	for _, mo in pairs(self._modules) do
		mo:dump()
	end

	-- ×ÊÔ´
	os.execute(string.format([[xcopy /A/E/C/R/Y "%s" "%s/*"]],
		Def.PATH_GAME_META_ASSET,
		Def.PATH_EXPORT_ASSET
	))
end

return M
