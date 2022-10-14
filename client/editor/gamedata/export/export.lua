local ExportMapping = require "editor.gamedata.export.export_mapping"
local ExportLang = require "editor.gamedata.export.export_lang"
local ExportModule = require "editor.gamedata.export.export_module"
local ExportCoin = require "editor.gamedata.export.export_coin"

local M = {}

function M:init()
	ExportMapping:init()
	ExportLang:init()
	ExportModule:init()
	ExportCoin:init()
end

function M:sync()
	ExportMapping:sync()
	ExportLang:sync()
	ExportModule:sync()
	ExportCoin:sync()
end

return M
