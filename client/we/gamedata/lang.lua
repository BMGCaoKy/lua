local Lfs = require "lfs"
local Def = require "we.def"
local Seri = require "we.gamedata.seri"
local Core = require "editor.core"
local Cjson = require "cjson"

local M = {}

local DEFAULT_LOCALE = "en"

function M:init()
	local data = Lib.read_json_file(Def.PATH_LANGUAGE)
	self._locale = data.language or DEFAULT_LOCALE

	self._sys_text = {}

	self._user_header = {}
	self._user_text = {}
	self._user_text_temp = {}

	self._modified = false
	self._loaded = false
end

function M:load_sys_text()
	local path_meta_lang = Lib.combinePath(Def.PATH_SYS_TEXT, "meta_lang.csv")
	local sheet, header = Lib.read_csv_file(path_meta_lang)
	if sheet then
		for _, line in ipairs(sheet) do
			local key = assert(line["KEY"])
			if key ~= "" then
				assert(not self._sys_text[key], key)
				self._sys_text[key] = line
			end
		end
   end

	local path_custom_lang = Lib.combinePath(Def.PATH_SYS_TEXT, "custom_lang.csv")
	local sheet, header = Lib.read_csv_file(path_custom_lang)
	if sheet then
		for _, line in ipairs(sheet) do
			local key = assert(line["KEY"])
			if key ~= "" then
				assert(not self._sys_text[key], key)
				self._sys_text[key] = line
			end
		end
	end

	if header then
		self._user_header = header
		if self:has_lang(self._locale) == false then
			self._locale = DEFAULT_LOCALE
		end
	else
		self._locale = DEFAULT_LOCALE
	end
end

function M:load_user_text()
	if Lfs.attributes(Def.PATH_EXPORT_TEXT, "mode") == "file" then
		local sheet, header = Lib.read_csv_file(Def.PATH_EXPORT_TEXT)
		for _, line in ipairs(sheet) do
			local key = assert(line["KEY"])
			if key ~= "" then
				assert(not self._user_text[key], key)
				self._user_text[key] = line
				table.insert(self._user_text, line)
			end
		end
		--self._user_header = header
	end
end

--自定义meta的翻译
function M:load_custom_text()
	local custom_lang_path = Lib.combinePath(Def.PATH_ADDITIONAL_META, "custom_meta_lang.csv")
	if Lfs.attributes(custom_lang_path, "mode") == "file" then
		local sheet, header = Lib.read_csv_file(custom_lang_path)
		for _, line in ipairs(sheet) do
			local key = assert(line["KEY"])
			if key ~= "" then
				if not self._sys_text[key] then
					self._sys_text[key] = line
				end
			end
		end
	end
end

function M:load()
	if self._loaded then
		return
	end

	self:load_sys_text()
	self:load_user_text()
	self:load_custom_text()
	self._loaded = true
end

function M:reload()	
	self._user_text = {}	
	self:load_user_text()
end

function M:save()
	if not self._modified then
		return
	end

	local sheet = {}
    for _, line in ipairs(self._user_text) do
		table.insert(sheet, line)
    end
    Seri("csv", sheet, Def.PATH_EXPORT_TEXT, true, self._user_header)
		
	self._modified = false
end

function M:has_lang(lang)
	assert(type(lang) == "string")
	assert(lang ~= "KEY")
	for _, v in ipairs(self._user_header) do
		if v == lang then
			return true
		end
	end
	return false
end

function M:set_locale(locale)
	if self:has_lang(locale) then
		self._locale = locale
	end
end

function M:text(key, sys , custom_locale)
	local locale = custom_locale or self._locale or DEFAULT_LOCALE
	--找不到此语言则返回key本身
	--assert(self:has_lang(locale), locale)
	if self:has_lang(self._locale) == false then
		return key
	end

	local map = sys and self._sys_text or self._user_text
	local line = map[key]
	local text = line and line[locale] or key
	text = string.gsub(text, "&tab;", "\t")
	return text
end

function M:set_text(key, text, locale)
	assert(key)
	assert(type(text) == "string")

	text = string.gsub(text, "\t", "&tab;")

	if not self._user_text[key] then
		local line = {}
		line["KEY"] = key
		for _, lang in ipairs(self._user_header) do
			if lang ~= "KEY" then
				line[lang] = text
			end
		end
		self._user_text[key] = line
		table.insert(self._user_text, line)
	else
		locale = locale or self._locale
		--assert(self:has_lang(locale), locale)
		self._user_text[key][locale] = text
	end

	self._modified = true
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
end

function M:remove_key(key)
	assert(key)
	if not self._user_text[key] then
		return
	end

	self._user_text[key] = nil
	for i ,value in ipairs(self._user_text) do
		if value["KEY"] == key then
			table.remove(self._user_text , i)
			break
		end
	end
	self._modified = true
end

--因为新属性面板获取翻译都是从sys_text拿的
--set_text设置的翻译是存在user_text
function M:set_sys_text(key, text, locale)
	assert(key)
	assert(type(text) == "string")

	text = string.gsub(text, "\t", "&tab;")

	if not self._sys_text[key] then
		local line = {}
		line["KEY"] = key
		for _, lang in ipairs(self._user_header) do
			if lang ~= "KEY" then
				line[lang] = text
			end
		end
		self._sys_text[key] = line
		table.insert(self._sys_text, line)
	end

	self._modified = true
end

function M:locale_codes( )--获取语言的列表 key vuale 如key: cn v:中文  
	-- body
	local ret ={}
	for _, v in ipairs(self._user_header) do
		if v  ~= "KEY" and v ~= "" then
			local  c = self:text("Language",true,v)
			ret[v] = c
		end
	end
	return Cjson.encode(ret)
end

function M:copy_text(target,custom_key)
	local key = custom_key and custom_key or GenUuid()
	if self._user_text[key] then
		return
	end
	if self._user_text[target] then
		local line = Lib.copy(self._user_text[target])
		line.KEY = key
		self._user_text[key] = line
		table.insert(self._user_text, line)

		self._modified = true
		Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
	else
		print("[Warning]has no key : " .. target, debug.getinfo(1).name .. ".lua line: " .. debug.getinfo(1).currentline)
	end

	return key
end

function M:get_locale()
	return M._locale
end

function M:copy_text_to_temp_text(target,custom_key)
	local key = custom_key and custom_key or GenUuid()
	if self._user_text[key] then
		return
	end
	if self._user_text[target] then
		local line = Lib.copy(self._user_text[target])
		line.KEY = key
		self._user_text_temp[key] = line
	end
end

function M:copy_text_from_temp_text(target,custom_key)
	local key = custom_key and custom_key or GenUuid()
	if self._user_text_temp[key] then
		return
	end
	if self._user_text_temp[target] then
		local line = Lib.copy(self._user_text_temp[target])
		line.KEY = key
		self._user_text[key] = line
		table.insert(self._user_text, line)

		self._modified = true
		Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED)
	end
end

return M
