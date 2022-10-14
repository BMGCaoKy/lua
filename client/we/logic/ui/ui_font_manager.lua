local guiMgr = L("guiMgr", GUIManager:Instance())
local Def = require "we.def"
local Seri = require "we.gamedata.seri"
local Lfs = require "lfs"
local Lang = require "we.gamedata.lang"
local Recorder = require "we.gamedata.recorder"



--字体名:文件名
local fonts_lang = {}
local fonts = {}

local changed_lang = function()
	local lang_count = #Lang._user_header
	for _,name in ipairs(fonts) do
		local key = "Resource_Font." .. name
		local text = guiMgr:getFontFamilyName(name.."-12")
		Lang:set_sys_text(key, text)
	end
end

local init_date = function()
	local json_attr = Lfs.attributes(Def.PATH_UI_FONTS_JSON)
	if not json_attr or json_attr.mode ~= "file" then
		return
	end
	fonts = Lib.read_json_file(Def.PATH_UI_FONTS_JSON)
	changed_lang()
end

local get_font_xml_str = function(name, font_size)
	local attr = {}
	attr["version"]			= "3"
	attr["resourceGroup"]	= "asset"
	attr["type"]			= "FreeType"
	attr["nativeHorzRes"]	= "1280"
	attr["nativeVertRes"]	= "720"
	attr["autoScaled"]		= "vertical"
	attr["name"]			= name.."-"..tostring(font_size)
	attr["filename"]		= name..".ttf"
	attr["size"]			= tostring(font_size)

	local str = Lib.toXml({Font = {_attr = attr}})
	local xml_head = "<?xml version=\"1.0\" ?>\n"
	str = xml_head .. str
	return str
end

local write_xml = function(path,str)
	local dir = string.match(path, "^(.*)/[^/]+$")
	Lib.mkPath(dir)
	os.remove(path)
	local file = io.open(path, "w+b", true)
	assert(file, tostring(path))
	file:write(str)
	file:close()
end

--并不需要读取font文件
local write_fonts_json = function()
	Seri("json", fonts, Def.PATH_UI_FONTS_JSON, true)
end

local write_font = function()
	for _,name in ipairs(fonts) do
		--每个font导出72个文件TAT
		for i = 8,72 do
			local font_size = tostring(i)
			local str = get_font_xml_str(name, font_size)
			local path = Lib.combinePath(Def.PATH_UI_FONTS, name.."-"..font_size..".font")

			local attr = Lfs.attributes(path)
			if not attr or attr.mode ~= "file" then
				write_xml(path, str)
			end
		end
	end
end

----------------------------------------
local M = {}
function M:Init()
	init_date()
	self:save()
end

--传入全局路径
function M:add_font(path)
	local asset_path = string.sub(path,1,#Def.PATH_GAME_ASSET)

	--根据asset的全局路径定位到文件跟asset的相对位置，避免path中存在多个asset
	assert(asset_path == Def.PATH_GAME_ASSET, Def.PATH_GAME_ASSET .. "not find :" .. path)
	local file_path = string.sub(path, #Def.PATH_GAME_ASSET + 1)

	--是否是ttf文件
	assert(string.find(file_path,".ttf"), file_path .. " File format error")
	local font_name = string.sub(file_path,1, #file_path - 4)

	--是否重复
	for _,name in ipairs(fonts) do
		if name == font_name then
			return
		end
	end
	table.insert(fonts, font_name)
	self:save()

	if not guiMgr:isValidFontFamilyName(font_name.."-12") then
		self:delete_font("asset/" .. font_name .. ".ttf")	
		return
	end

	--修改翻译
	local key = "Resource_Font." .. font_name
	local text = guiMgr:getFontFamilyName(font_name.."-12")
	Lang:set_sys_text(key, text)
end

function M:delete_font(path)
	local font_list = self:get_font_list()
	local next_font = font_list[1].value
	local font_name = string.sub(path,7, #path - 4)

	if not self:has_font(font_name) then
		return
	end

	local index = 1
	while index <= #fonts do
         if fonts[index] == font_name then
             table.remove(fonts,index)
         else
             index = index + 1
         end
    end

	--更新到已经创建的window的node，继而影响界面
	Lib.emitEvent(Event.EVENT_PC_EDITOR_DELETE_FONT, font_name, next_font)

	--删除.font文件
	for i = 8,72 do
		local font_size = tostring(i)
		local font_path = Lib.combinePath(Def.PATH_UI_FONTS, font_name.."-"..font_size..".font")
		local attr = Lfs.attributes(font_path)
		if attr and attr.mode == "file" then
			os.remove(font_path)
		end
	end

	--保存json
	self:save()
end

function M:save()
	write_fonts_json()
	write_font()
end

function M:get_font_list()
	local ret = {}
	--初始预设字体
	table.insert(ret, {value = "DroidSans"})
	table.insert(ret, {value = "HarmonyOS_Sans_SC_Regular"})
	table.insert(ret, {value = "HarmonyOS_Sans_SC_Bold"})
	table.insert(ret, {value = "HarmonyOS_Sans_SC_Black"})

	--用户添加的字体
	for _,name in ipairs(fonts) do
		table.insert(ret, {value = name})
	end

	return ret
end

function M:get_preset_font_count()
	return #self:get_font_list() - #fonts
end

function M:has_font(name)
	local font_list = self:get_font_list()
	for _,tb in ipairs(font_list) do
		if tb.value == name then
			return true
		end
	end
	return false
end

M:Init()

return M