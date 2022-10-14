local cjson = require "cjson"
local engine = require "editor.engine"
local http = require "socket.http"
local https = require "luasec.https"
local ltn12 = require "ltn12"

local M = 
{
	url = "",
	engine_ver = "1",
	editor_ver = "1",
	timer = nil,
	is_login = false
}

local token = 
{
	access_token = "",--�û�����
	token_type = "",
	expires_at = -1, --��ʱʱ��
	uid = -1
}

local function split( str,reps )
    local resultStrList = {}
    string.gsub(str,'[^'..reps..']+',function ( w )
        table.insert(resultStrList,w)
    end)
    return resultStrList
end

-- method(string)
-- url(string)
local function request(method,url,header,body)
	print("------------------------START---------------------------")
	print(method,url)
	local data = {}--����ֵ
	local default_header = 
	{
		["Accept-Language"] = "en-US",
		["X-Platform"] = "3",
		["X-Engine-Ver"] = M.engine_ver,
		["X-Editor-Ver"] = M.editor_ver,
		["content-type"] = "application/json",
	}

	if method == "POST" then
		default_header["content-length"] = #(cjson.encode(body))
	end
	
	url = M.url..url

	local http_str = split(url,"://")
	for k,v in pairs(default_header or {}) do
		header[k] = v
	end
	print("------------------------Send---------------------------")
	print("------------------------HEAD---------------------------")
	Lib.pv(header)
	print("------------------------BODY---------------------------")
	Lib.pv(body,6)

	local obj = 
	{
		url = url,
		method = method,
		headers = header,
		sink = ltn12.sink.table(data),
	}

	if method == "POST" then
		obj["source"] = ltn12.source.string(cjson.encode(body))
	end

	local res, code, response_headers
	if http_str[1] == "https" then
		res, code, response_headers = https.request(obj)
	else
		res, code, response_headers = http.request(obj)	
	end
	print("------------------------Send---------------------------")
	print("code:",code)
	print("------------------------HEAD---------------------------")
	for k,v in pairs(response_headers) do
		print(k,v)
	end
	print("------------------------BODY---------------------------")
	Lib.pv(data)
	print(method,url)
	print("------------------------END---------------------------")

	return code,data[1]
end

local function error_msg(ret)
	if ret.code and ret.code ~= 200 then
		engine:show_msg_to_qt(ret.code)
	else
		engine:show_msg_to_qt(ret)
	end
end

local function save_access_token()
	local file = io.open("token.json","w")
	local obj = {
		access_token = token.access_token,
		token_type = token.token_type
	}
	local write_str = cjson.encode(obj)
	file:write(write_str)
	file:close()
end

local function timer_fun()
	local fun = M.timer
	if fun then fun() end
	if token.expires_at ~= -1 and token.expires_at ~= 0 then 
		M.timer = World.Timer(token.expires_at,function()
			M:refresh_token()
		end)
	end
	save_access_token()
end

function M:init()
	local file = io.open("editoruploadconfig.json","a+")
	if file then
		local read_all = file:read("a")
		if read_all ~= "" then
			local obj = cjson.decode(read_all)
			if obj then
				M.url = obj.url
				M.editor_ver = obj.editor_ver
			end
		end
		file.close()
	end

	file = io.open("Media/engineVersion.json","a+")
	if file then
		local read_all = file:read("a")
		if read_all ~= "" then
			local obj = cjson.decode(read_all)
			if obj then
				M.engine_ver = obj.engineVersion
			end
		end
		file.close()
	end

	file = io.open("token.json","a+")
	if file then
		local read_all = file:read("a")
		if read_all ~= "" then
			local obj = cjson.decode(read_all)
			if obj then
				token.access_token = obj.access_token
				token.token_type = obj.token_type
			end
		end
		file:close()
		if token.access_token ~= "" and token.access_token then
			M:refresh_token()
		else
			engine:inform_QT_logging_status(false)
		end
	else
		token.access_token = ""
		engine:inform_QT_logging_status(false)
	end
end

--��¼
function M:login(name,passward)
	local header = {}
	local boby = 
	{
		name = name,
		passwd = passward
	}
	local code, data = request("POST","/user-api/v1/sessions",header,boby)
	if code == 200 then
		local ret = cjson.decode(data)
		token.access_token = ret.access_token
		token.token_type = ret.token_type
		token.expires_at = ret.expires_at
		token.uid = ret.uid
		timer_fun()
		engine:inform_QT_logging_status(true)
	else
		token.access_token = ""
		engine:inform_QT_logging_status(false)
		save_access_token()
		return false
	end
	return true
end

--ˢ��token
function M:refresh_token()
	print(token.token_type)
	local header = 
	{
		["Authorization"] = token.token_type.." "..token.access_token
	}
	local boby = {}
	local code, data = request("POST","/user-api/v1/refresh_token",header,boby)
	local ret = cjson.decode(data)
	if code == 200 then
		token.access_token = ret.access_token
		token.token_type = ret.token_type
		token.expires_at = ret.expires_in
		timer_fun()
		engine:inform_QT_logging_status(true)
	elseif ret["code"] == 400100 then
		token.access_token = ""
		engine:inform_QT_logging_status(false)
		save_access_token()
		engine:forced_to_logout()
		return false
	else
		token.access_token = ""
		engine:inform_QT_logging_status(false)
		save_access_token()
		return false
	end
	return true
end

--�ǳ�
function M:logout()
	local header = 
	{
		["Authorization"] = token.token_type.." "..token.access_token
	}
	local boby = {}
	local code, data = request("DELETE","/user-api/v1/sessions",header,boby)
	local ret = cjson.decode(data)
	if code == 200 or ret["code"] == 400100 then
		token.access_token = ""
		token.token_type = ""
		token.expires_at = -1
		token.uid = -1
		timer_fun()
		engine:inform_QT_logging_status(false)
	else
		return false
	end
	return true
end

--��ȡaws�ļ��ϴ�ǩ��
function M:gen_sign_url(type,name,is_rename)
	local header = 
	{
		["Authorization"] = token.token_type.." "..token.access_token
	}
	local boby = 
	{
		business = 2,
		file_type = type,
		object_name = name,
		need_rename = is_rename
	}
	local code, data = request("POST","/file-api/v1/gen_sign_url",header,boby)
	local ret = cjson.decode(data)
	if code == 200 then
		return {
			ok = true,
			obj = ret
		}
	elseif ret["code"] == 400100 then
		token.access_token = ""
		engine:inform_QT_logging_status(false)
		save_access_token()
		engine:forced_to_logout()
		return {
			ok = false,
			obj = {}
		}
	else
		return {
			ok = false,
			obj = {}
		}
	end
end

--�ϴ���Ϸ
function M:upload_game(obj)
	local header = 
	{
		["Authorization"] = token.token_type.." "..token.access_token
	}
	local boby = obj
	local code, data = request("POST","/editor-api/v1/game",header,boby)
	local ret = cjson.decode(data)
	if code == 200 then
		return {
			ok = true,
			obj = ret
		}
	elseif ret["code"] == 400100 then
		token.access_token = ""
		engine:inform_QT_logging_status(false)
		save_access_token()
		engine:forced_to_logout()
		return {
			ok = false,
			obj = {}
		}
	elseif ret["code"] == 400101 then
		return {
			ok = false,
			obj = {
				code = 400101
			}
		}
	else
		return {
			ok = false,
			obj = {}
		}
	end
end

--��ȡ��Ϸ����汾
function M:game_latest_version(game_id,version_id)
	local header = 
	{
		["Authorization"] = token.token_type.." "..token.access_token
	}
	local boby = {}
	local code, data = request("GET",string.format("/editor-api/v1/game/%s/version/%s",game_id,version_id),header,boby)
	local ret = cjson.decode(data)
	if code == 200 then
		return {
			ok = true,
			obj = ret
		}
	elseif ret["code"] == 400100 then
		token.access_token = ""
		engine:inform_QT_logging_status(false)
		save_access_token()
		engine:forced_to_logout()
		return {
			ok = false,
			obj = {}
		}
	else
		return {
			ok = false,
			obj = {}
		}
	end

end

--��ȡ����Ϸ�б�
function M:simple_game_list()
	local header = 
	{
		["Authorization"] = token.token_type.." "..token.access_token
	}
	local boby = {}
	local code, data = request("GET","/editor-api/v1/simple_game_list",header,boby)
	if code == 200 then
		local ret = cjson.decode(data)
		return {
			ok = true,
			list = ret
		}
	else
		if code == 403 then
			return {
				ok = false,
				list = {}
			}
		elseif code == 400 and cjson.decode(data) and cjson.decode(data)["code"] == 400004 then
			local ret = cjson.decode(data)
			return {
				ok = true,
			list = ret
			}
		elseif cjson.decode(data) and cjson.decode(data)["code"] == 400100 then
			token.access_token = ""
			engine:inform_QT_logging_status(false)
			save_access_token()
			engine:forced_to_logout()
			return {
				ok = false,
				list = {}
			}
		else
			return {
				ok = false,
				list = {}
			}
		end
	end
end

--��ȡ������Ϣ
function M:basic_info()
	local header = 
	{
		["Authorization"] = token.token_type.." "..token.access_token
	}
	local boby = {}
	local code, data = request("GET","/editor-api/v1/basic_info",header,boby)
	local ret = cjson.decode(data)
	if code == 200 then
		return {
			ok = true,
			obj = ret
		}
	elseif ret["code"] == 400100 then
		token.access_token = ""
		engine:inform_QT_logging_status(false)
		save_access_token()
		engine:forced_to_logout()
		return {
			ok = false,
			obj = {}
		}
	else
		return {
			ok = false,
			obj = {}
		}
	end
end

--��ȡ��Ϸ����
function M:game_types()
	local header = 
	{
		["Authorization"] = token.token_type.." "..token.access_token
	}
	local boby = {}
	local code, data = request("GET","/editor-api/v1/game_types",header,boby)
	local ret = cjson.decode(data)
	if code == 200 then
		return {
			ok = true,
			obj = ret
		}
	elseif ret["code"] == 400100 then
		token.access_token = ""
		engine:inform_QT_logging_status(false)
		save_access_token()
		engine:forced_to_logout()
		return {
			ok = false,
			obj = {}
		}
	else
		return {
			ok = false,
			obj = {}
		}
	end
end

----------------------------------------------------
function M:is_login()
	if token.access_token ~= "" and token.access_token then
		return true
	else
		return false
	end
end

M:init()

return M