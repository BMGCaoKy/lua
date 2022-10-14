local cjson = require "cjson"
local http = require "socket.http"
--local https = require "luasec.https"
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
	access_token = "",--用户令牌
	expires_at = -1, --超时时间
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
local function request(method, url, header, body)
	print("------------------------START---------------------------")
	print(method,url)
	local data = {}--返回值
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
--	if http_str[1] == "https" then
--		res, code, response_headers = https.request(obj)
--	else
		res, code, response_headers = http.request(obj)	
--	end
	print("------------------------Send---------------------------")
	print("code:",code)
	print("------------------------HEAD---------------------------")
	for k,v in pairs(response_headers or {}) do
		print(k,v)
	end
	print("------------------------BODY---------------------------")
	Lib.pv(data)
	print(method,url)
	print("------------------------END---------------------------")

	return code,data[1]
end

function M:init()
	--M.url = "http://mods.sandboxol.com/editorproxy" --for test
	M.url = CGame.instance:getEditorUrl() --"http://dev.mods.sandboxol.cn/editorproxy" --for formal dress
	M.editor_ver = 1
	M.engine_ver = EngineVersionSetting.getEngineVersion()
    token.access_token = CGame.instance:getUserToken()
    token.uid = CGame.instance:getPlatformUserId()
end


--获取aws文件上传签名
function M:gen_sign_url(type, name, is_rename)
	local header = 
	{
		["Access-Token"] = token.access_token,
        ["userId"] = token.uid
	}
	local body = 
	{
		business = 2,
		file_type = type,
		object_name = name,
		need_rename = is_rename
	}
	local code, data = request("POST", "/meditor-api/v1/file/gen_sign_url", header, body)
	if code == 200 then
		local ret = cjson.decode(data)
            return {
			ok = true,
			obj = ret
		}
    end
	print(string.format("Editor network error: func: %s, code: %s", "gen_sign_url", code))

	return {
			ok = false,
			obj = {}
		}
end

--批量获取aws文件上传签名
function M:gen_sign_urls(fileList)
    local gen_sign_url_reqs = {}
    for i, file in ipairs(fileList or {}) do
        gen_sign_url_reqs[i] = file
    end
    local body = {gen_sign_url_reqs = gen_sign_url_reqs}
    local header = 
	{
		["Access-Token"] = token.access_token,
        ["userId"] = token.uid
	}
    local code, data = request("POST", "/meditor-api/v1/file/gen_sign_urls", header, body)
	if code == 200 then
		local ret = cjson.decode(data)
            return {
			ok = true,
			obj = ret
		}
    end
	print(string.format("Editor network error: func: %s, code: %s", "gen_sign_urls", code))
	
	return {
			ok = false,
			obj = {}
		}
end

--add_game

function M:add_game(name, access_url, description)
	local header = 
	{
		["Access-Token"] = token.access_token,
        ["userId"] = token.uid
	}
    local body = 
	{
		name = name,
		file_url = access_url[3],
		description = description,
		game_cover_pic_url  = access_url[1],
		game_show_pic_urls = {access_url[2]}
	}
    local code, data = request("POST", "/gameupload-v2-api/v1/add_game", header, body)
	if code == 200 then
		local ret = cjson.decode(data)
            return {
			ok = true,
			obj = ret
		}
    end
	print(string.format("Editor network error: func: %s, code: %s", "add_game", code))
	
	return {
			ok = false,
			obj = {}
		}
end

--获取简单游戏列表
function M:simple_game_list()
	local header = {}
	local body = {}
	local code, data = request("GET", "/meditor-api/v1/pub/meditor_template", header, body)
	if code == 200 then
		local ret = cjson.decode(data)
		return 
        {
			ok = true,
			ret = ret
		}
	end
	print(string.format("Editor network error: func: %s, code: %s", "simple_game_list", code))
	
	return 
    {
			ok = false,
			ret = {}
	}
end


--获取客户端cache
function M:get_client_cache(keyTab)
	local header = 
    {
        ["userId"] = token.uid,
        ["Access-Token"] = token.access_token
    }
    local body = {}
    local url = "/meditor-api/v1/client_cache"
    for i, key in ipairs(keyTab) do
        if i == 1 then
            url = url .. "?key=" .. key
        else
            url = url .. "&key=" .. key
        end
    end
	local code, data = request("GET", url, header, body)
	if code == 200 then
        local ret = cjson.decode(data)
		return
        {
			ok = true,
			ret = ret
		}
    end
	print(string.format("Editor network error: func: %s, code: %s", "get_client_cache", code))
	
    return 
    {
		ok = false,
		ret = {}
	}
end


--设置客户端cache
function M:set_client_cache(key, value)
    local body = {}
    if type(key) == "table" and type(value) == "table" then
        for i, k in ipairs(key) do
            body[k] = value[i]
        end
    else
        body = 
	    {
		    [key] = value
	    }
    end

    local header = 
    {
        ["userId"] = token.uid, 
        ["Access-Token"] = token.access_token
    }
    local url = "/meditor-api/v1/client_cache"
	local code, data = request("POST", url, header, body)
    
	if code == 200 then
        local ret = cjson.decode(data)
		return 
        {
			ok = true,
			ret = ret
		}
    end
	print(string.format("Editor network error: func: %s, code: %s", "set_client_cache", code))
	
    return 
    {
		ok = false,
		ret = {}
    }
end


M:init()

return M