local Def = require "editor.def"
local Seri = require "editor.gamedata.seri"
local File = require "editor.file"
local Seri = require "editor.gamedata.seri"

local M = {}

local DEFAULT_LOCALE = "en"

function M:init()
	local data = Lib.read_json_file(Def.PATH_LANGUAGE)
	if data then
		DEFAULT_LOCALE = data.language
	end

	self._locale = DEFAULT_LOCALE

	self._header = {}
	self._key = {}
	self._text = {}

	self._user_header = {}
	self._user_key = {}
	self._user_text = {}

	self._modified = false

	self:load()
end

function M:load()
	local sheet, header = File.read_csv(Def.PATH_SYS_TEXT)
	for _, line in ipairs(sheet) do
		local key = assert(line["KEY"])
		if key ~= "" then
			for locale, text in pairs(line) do
				if locale ~= "KEY" then
					self._text[locale] = self._text[locale] or {}
					assert(not self._text[locale][key], key)
					self._text[locale][key] = text
				end
			end
		end
	end

	sheet, header = File.read_csv(Def.PATH_GAME_META_TEXT)
	for _, line in ipairs(sheet) do
		local key = assert(line["KEY"])

		assert(not self._user_key[key])
		table.insert(self._user_key, key)
		self._user_key[key] = true

		for locale, text in pairs(line) do
			if locale ~= "KEY" then
				self._user_text[locale] = self._user_text[locale] or {}
				assert(not self._user_text[locale][key])
				self._user_text[locale][key] = text
			end
		end
	end
	self._user_header = header

	Lib.emitEvent(Event.EVENT_EDITOR_LANG_LOADED)
end

function M:save()
	if self._modified then
		local sheet = {}
		for _, key in ipairs(self._user_key) do
			local line = {}
			line.KEY = key
			for locale, map in pairs(self._user_text) do
				line[locale] = map[key]
			end
			table.insert(sheet, line)
		end

		Seri("csv", sheet, Def.PATH_GAME_META_TEXT, true, self._user_header)
		self._modified = false
	end
end

function M:dump()
	Lib.emitEvent(Event.EVENT_EDITOR_LANG_DUMP)
end

function M:set_locale(locale)
	self._locale = assert(locale)

	local exist = false
	for _, v in ipairs(self._user_header) do
		if v == locale then
			exist = true
			break
		end
	end

	if not exist then
		table.insert(self._user_header, locale)
		self._user_text[locale] = {}
	end
end

function M:text(key, sys)
	local text
	if sys then
		local map = self._text[self._locale] or self._text[DEFAULT_LOCALE]
		text = map and map[key] or key
	else
		local map = self._user_text[self._locale] or self._user_text[DEFAULT_LOCALE]
		text = map and map[key] or key
	end

	text = string.gsub(text, "&tab;", "\t")
	return text
end

function M:set_text(key, text, locale)
	assert(key)
	assert(type(text) == "string")

	if not self._user_key[key] then
		table.insert(self._user_key, key)
		self._user_key[key] = true
	end

	local map = assert(self._user_text[locale or self._locale])
	map[key] = string.gsub(text, "\t", "&tab;")

	self._modified = true

	Lib.emitEvent(Event.EVENT_EDITOR_LANG_MODIFY)
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
end

function M:set_text_by_all_lang(key, text)
	assert(key)
	assert(type(text) == "string")
	local def_cfg = Lib.read_json_file("./conf/default_cfg.json")
	local langs = def_cfg["lang_data"]
	for k,v in pairs(langs) do
		M:set_text(key, text, k)
	end
end

function M:copy_text(key, target)
	if not self._user_key[key] then
		table.insert(self._user_key, key)
		self._user_key[key] = true
	end
	for _, map in pairs(self._user_text) do
		map[key] = map[target]
	end
	self._modified = true
	Lib.emitEvent(Event.EVENT_EDITOR_LANG_MODIFY)
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
end

function M:get_locale()
	return M._locale
end

function M:user_header()
	return self._user_header
end

function M:user_sheet()
	return self._user_key, self._user_text
end

return M
