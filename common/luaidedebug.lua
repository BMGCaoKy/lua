local Cjson = require "cjson"
local Platform = require "common.platform"

local function read_file(path)
	local file, errmsg = io.open(path, "rb")
	if not file then
		print("[Info]", errmsg)
		return nil
	end
	local content = file:read("a")
	file:close()

	-- remove BOM
	local c1, c2, c3 = string.byte(content, 1, 3)
	if (c1 == 0xEF and c2 == 0xBB and c3 == 0xBF) then	-- UTF-8
		content = string.sub(content, 4)
	elseif (c1 == 0xFF and c2 == 0xFE) then	-- UTF-16(LE)
		content = string.sub(content, 3)
	end
	return content
end

local function read_json_file(path)
	local content = read_file(path)
	if content then
		local ok, ret = pcall(Cjson.decode, content)
		assert(ok, path)
		return ret
	end
end

local _conf = read_json_file(Root.Instance():getRootPath() .. "editor_setting.json")
--print (_conf.luadebugmode)
--print (_conf.language)
--0¿Í‘ô¶Ëµ÷ÊÔ´ò¿ª
--1·þÎñ¶Ëµ÷ÊÔ´ò¿ª

local  function file_exists(path)
  local file = io.open(path,"r")
  if file then file:close() end
  return file ~= nil
end

if _conf then
	local debug_value = 1
	if _conf.luadebugmode then
		debug_value = _conf.luadebugmode
	end

	local  debug_open = false
	print(World.isClient )
	if ( World.isClient  ==true and debug_value ==0 )  then
		debug_open = true
		local  p = "./conf/client_debug_run.txt"
		if ( Root.platform() == Platform.MAC_OSX ) then
			p = "client_debug_run.txt"
		end
		local exist = file_exists(p)
		if exist then
			debug_open = false
		else
			local file = io.open(p, "a")
			file:write("--test")
			file:close()
		end
		if debug_open then
			print("**********************************debung client ************************");
		end
	end 

	if (World.isClient ==nil and debug_value ==1 )  then
		debug_open = true
		print("**********************************debung server ************************");
	end 

	function ZBREQUIRE(mod)
		local _serchers = package.searchers
		package.searchers = {
			function(mod)
				local ZBS = os.getenv("ZBS") or Platform.ZBStudioPath()
				local pattern = ZBS.."/lualibs/?.lua;"..ZBS.."/lualibs/?/?.lua"
				local path, errmsg = package.searchpath(mod, pattern)
				assert(path, errmsg)
				print(path)
				return loadfile(path), path
			end
		}
		local ret = require(mod)
		package.searchers = _serchers

		return ret
	end

	if debug_open then
		local ZBS = os.getenv("ZBS") or Platform.ZBStudioPath()
		if ( Root.platform() == Platform.WINDOWS ) then
			package.cpath = package.path ..';'..ZBS..'/bin/?.dll;'..ZBS..'/bin/clibs/?.dll'
		else
			package.cpath = package.path ..';'..ZBS..'/bin/?.dylib;'..ZBS..'/bin/clibs/?.dylib;' .. ZBS .. '/bin/clibs/?/?.dylib'
			package.path = package.path .. ';' .. ZBS .. '/?.lua;' -- .. ZBS .. "/lualibs/?.lua;" .. ZBS.."/lualibs/?/?.lua;"
		end
		ZBREQUIRE('mobdebug').start()
		return ZBREQUIRE('mobdebug')
	else
		return false
	end
end
