local cjson = require("cjson")

local M = {}

function M:disconnect(req)
	self:log("disconnected")
	self:response(req)
	self:close()
end

local function getDir(path)
	path = path:gsub("\\", "/"):gsub("//", "/")
	if path:sub(-1) ~= "/" then
		path = path .. "/"
	end
	while true do
		local index = path:find("/%.%./")
		if not index then
			break
		end
		local startIndex = 0
		local tempIndex = path:find("/")
		while tempIndex<index do
			startIndex = tempIndex
			tempIndex = path:find("/", startIndex + 1)
		end
		path = path:sub(1, startIndex) .. path:sub(index + 4)
	end
	return path
end

local function addConvert(tb, luaPath, sysPath)
	if not sysPath then
		return
	end
	tb[getDir(luaPath)] = getDir(sysPath):gsub("{gameName}", World.GameName)
end

function M:attach(req)
	self.args = req.arguments
	self.pathConvert = {}
	addConvert(self.pathConvert, Root.Instance():getRootPath(), self.args.resDir)
	addConvert(self.pathConvert, Root.Instance():getGamePath(), self.args.gameDir)
	self:sendevent("initialized")
	return true
end
M.launch = M.attach

function M:configurationDone(req)
	self:response(req)
	if self.stopThread then
		return
	end
	if self.args.stopOnEntry then
		self:dostop(nil, "entry")
	else
		self:updateHook()
	end
end

function M:setExceptionBreakpoints(req)
	local excMap = {}
	for _, exc in ipairs(req.arguments.filters) do
		excMap[exc] = true
	end
	local endlessCheck = excMap.endless or false
	if endlessCheck~=self.endlessCheck then
		self.endlessCheck = endlessCheck
		if not self.stopThread then
			self:updateHook()
		end
	end
	self.excMap = excMap
	return true
end

function M:exceptionInfo(req)
	if not self.excMsg then
		return false
	end
	return {
		exceptionId = "0",
		description = self.excMsg,
		breakMode = "always",
	}
end

function M:setBreakpoints(req)
	local luaPath = nil
	local as = req.arguments.source
	if as.sourceReference and as.sourceReference>0 then
		luaPath = assert(self.sourceIds[as.sourceReference]).path
	else
		local path = as.path:gsub("\\", "/"):gsub("//", "/")
		local ml = 0	-- 客户端目录嵌套的情况下，匹配最长的
		for lua, sys in pairs(self.pathConvert) do
			if #sys>ml and path:sub(1, #sys):lower()==sys:lower() then
				ml = #sys
				luaPath = lua .. path:sub(ml + 1)
			end
		end
	end
	if not luaPath then
		return "source not found!"
	end

	local bps = req.arguments.breakpoints
	local vbps = setmetatable({}, cjson.as_array)
	local lines = nil
	if bps[1] then
		lines = {}
		for i, bp in ipairs(bps) do
			lines[i] = bp.line
			vbps[i] = {
				verified = true,
				source = bp.source,
				line = bp.line,
			}
		end
	end
	self.breakpoints[luaPath] = lines
	if not self.stopThread then
		self:updateHook()
	end
	return { breakpoints = vbps }
end

function M:threads(req)
	return {
        threads = {
			{ id = 1, name = "main thread" },
		}
    }
end

local function getSource(self, lpath)
	local source = self.sourcePaths[lpath]
	if source then
		return source
	end
	local info = self:getPathInfo(lpath)
	if not info.lua then
		return nil
	elseif info.sys then
		return {
			name = info.name,
			path = info.sys,
		}
	end
	source = {
		name = info.name,
		path = info.lua,
		sourceReference = #self.sourceIds + 1,
	}
	self.sourcePaths[lpath] = source
	self.sourceIds[source.sourceReference] = source
	return source
end

function M:stackTrace(req)
	assert(self.stopThread)
	local frames = {}
	for level = (self.hookLevel or 1) - 1, 999 do
		local info = debug.getinfo(self.stopThread, level)
		if not info then
			break
		end
		local name = info.name or string.format("(%s)", tostring(info.func))
		local args = {}
		for i = 1, info.nparams do
			local k = debug.getlocal(self.stopThread, level, i)
			args[i] = k
		end
		if info.isvararg then
			args[info.nparams + 1] = "..."
		end
		frames[#frames+1] = {
			id = level + 1,
			name = string.format("%s(%s)", name, table.concat(args, ",")),
			source = getSource(self, info.source),
			line = info.currentline,
			column = 0,
		}
	end
	return { stackFrames = frames }
end

function M:scopes(req)
	assert(self.stopThread)
	local level = req.arguments.frameId - 1
	local info = debug.getinfo(self.stopThread, level)
	return {
		scopes = {
			{
				name = "Arguments",
				variablesReference = self:var(level),
				expensive = false,
			}, {
				name = "Locals",
				variablesReference = self:var(-level),
				expensive = false,
			}, {
				name = "Upvalues",
				variablesReference = self:var(info.func),
				expensive = false,
			}
		}
	}
end

local function getVar(self, value)
	local ref
	local typ = type(value)
	local str
	if typ=="function" then
		ref = self:var(value)
		local info = debug.getinfo(value)
		if info and info.name then
			str = info.name .. "()"
		else
			str = tostring(value)
		end
	elseif typ=="table" then
		local c, m = 0, 0
		for k in pairs(value) do
			if type(k)~="number" or math.floor(k)~=k or k<=0 then
				c = nil
				break
			end
			if k>m then
				m = k
			end
			c = c + 1
		end
		if not c then
			str = "{...}"
			ref = self:var(value)
		elseif c<=0 then
			str = "{}"
			ref = 0
		elseif c==m then
			str = string.format("[%d]", c)
			ref = self:var(value)
		else
			str = string.format("[%d/%d]", c, m)
			ref = self:var(value)
		end
	elseif typ=="userdata" and getmetatable(value) then
		ref = self:var(getmetatable(value))
		str = tostring(value)
	else
		ref = 0
		str = tostring(value)
	end
	return ref, typ, str
end

function M:variables(req)
	assert(self.stopThread)
	local value = assert(self.varsI2V[req.arguments.variablesReference])
	local typ = type(value)
	local variables = setmetatable({}, cjson.as_array)
	local function varInfo(k, v, name)
		local ref, t, str = getVar(self, v)
		variables[#variables+1] = {
			name = k,
			value = str,
			type = t,
			variablesReference = ref,
			evaluateName = name,
		}
	end
	if typ=="number" then	-- level
		local level = math.abs(value)
		local info = debug.getinfo(self.stopThread, level)
		if value>0 then
			for i = 1, info.nparams do
				local k, v = debug.getlocal(self.stopThread, level, i)
				varInfo(k, v, k)
			end
			for i = -1, -999, -1 do
				local k, v = debug.getlocal(self.stopThread, level, i)
				if not k then
					break
				end
				varInfo("..." .. -i, v)
			end
		else
			for i = info.nparams+1, 999 do
				local k, v = debug.getlocal(self.stopThread, level, i)
				if not k then
					break
				end
				varInfo(k, v, k)
			end
		end
	elseif typ=="function" then
		for i = 1, 999 do
			local k, v = debug.getupvalue(value, i)
			if not k then
				break
			end
			varInfo(k, v, k)
		end
	elseif typ=="table" then
		for k, v in pairs(value) do
			if type(k)=="string" then
				varInfo('"'..k..'"', v)
			else
				varInfo(tostring(k), v)
			end
		end
		local mt = getmetatable(value)
		if mt then
			varInfo('(metatable)', mt)
		end
	end
	return { variables = variables }
end

function M:setVariable(req)
	assert(self.stopThread)
	local args = req.arguments
	local value = assert(self.varsI2V[args.variablesReference])
	local typ = type(value)
	local function getValue(oldValue)
		local newValue = args.value
		if newValue:sub(1,2)=="==" then
			newValue = newValue:sub(2)
		elseif newValue:sub(1,1)=="=" then
			newValue = assert(load("return " .. newValue:sub(2)))()
		elseif type(oldValue)=="string" then
			newValue = args.value
		else
			newValue = assert(load("return " .. newValue))()
		end
		local ref, t, str = getVar(self, newValue)
		self:response(req, {
			value = str,
			type = t,
			variablesReference = ref,
		})
		return newValue
	end
	local name = args.name
	if typ=="number" then	-- level
		local level = math.abs(value)
		local info = debug.getinfo(self.stopThread, level)
		if value>0 then
			if name:sub(1,3)=="..." then
				local i = tonumber(name:sub(4))
				local k, v = debug.getlocal(self.stopThread, level, -i)
				debug.setlocal(self.stopThread, level, -i, getValue(v))
				return
			end
			for i = 1, info.nparams do
				local k, v = debug.getlocal(self.stopThread, level, i)
				if k==name then
					debug.setlocal(self.stopThread, level, i, getValue(v))
					return
				end
			end
		else
			for i = info.nparams+1, 999 do
				local k, v = debug.getlocal(self.stopThread, level, i)
				if not k then
					break
				end
				if k==name then
					debug.setlocal(self.stopThread, level, i, getValue(v))
					return
				end
			end
		end
	elseif typ=="function" then
		for i = 1, 999 do
			local k, v = debug.getupvalue(value, i)
			if not k then
				break
			end
			if k==name then
				debug.setupvalue(value, i, getValue(v))
				return
			end
		end
	elseif typ=="table" then
		for k, v in pairs(value) do
			local kn = type(k)=="string" and '"'..k..'"' or tostring(k)
			if kn==name then
				value[k] = getValue(v)
				return
			end
		end
		if name=='(metatable)' then
			local mt = getmetatable(value)
			setmetatable(value, getValue(mt))
			return
		end
	end
	return "var not found!"
end

function M:pause(req)
	assert(not self.stopThread)
	self:response(req)
	self:dostop(nil, "pause")
end

function M:continue(req)
	self.stepHookType = nil
	self.stepHookLevel = nil
	self.stopThread = nil
	return { allThreadsContinued = true }
end

function M:next(req)
	if not self.stopThread then
		return "not stoped!"
	end
	self.stepHookType = "over"
	self.stepHookLevel = 0
	self.stopThread = nil
	return true
end

function M:stepIn(req)
	if not self.stopThread then
		return "not stoped!"
	end
	self.stepHookType = "in"
	self.stepHookLevel = nil
	self.stopThread = nil
	return true
end

function M:stepOut(req)
	if not self.stopThread then
		return "not stoped!"
	end
	self.stepHookType = "out"
	self.stepHookLevel = 1
	self.stopThread = nil
	return true
end

local function envGetSet(self, key, ...)
	local set = select("#", ...) > 0
	for i = 1, 999 do
		local k, v = debug.getlocal(self.thread, self.level, i)
		if not k then
			break
		end
		if k==key then
			if set then
				debug.setlocal(self.thread, self.level, i, ...)
			end
			return true, v
		end
	end
	for i = 1, 999 do
		local k, v = debug.getupvalue(self.func, i)
		if not k then
			break
		end
		if k==key then
			if set then
				debug.setupvalue(self.func, i, ...)
			end
			return true, v
		end
	end
	return false
end

local EnvMT = { __info={} }
function EnvMT:__index(key)
	local ok, value = envGetSet(self.__info, key)
	if ok then
		return value
	else
		return rawget(_G, key)
	end
end
function EnvMT:__newindex(key, value)
	local ok = envGetSet(self.__info, key, value)
	if not ok then
		rawset(_G, key, value)
	end
end

function M:evaluate(req)
	local env = _G
	local args = { n = 0 }
	if req.arguments.frameId then
		local level = req.arguments.frameId - 1
		local info = debug.getinfo(self.stopThread, level)
		env = setmetatable({
			__info = {
				thread = self.stopThread,
				level = level,
				func = info.func,
			}
		}, EnvMT)
		for i = -1, -999, -1 do
			local k, v = debug.getlocal(self.stopThread, level, i)
			if not k then
				args.n = -i - 1
				break
			end
			args[-i] = v
		end
	end

	local exp = req.arguments.expression
	if exp:sub(1,1)=="!" then
		exp = exp:sub(2)
	else
		exp = "return " .. exp
	end
	local func, msg = load(exp, "evaluate", "t", env)
	if not func then
		return msg
	end
	local value = func(table.unpack(args, 1, args.n))
	local ref, typ, str = getVar(self, value)
	return {
		result = str,
		type = typ,
		variablesReference = ref,
	}
end

function M:source(req)
	local source = assert(self.sourceIds[req.arguments.sourceReference])
	local f = assert(io.open(source.path), source.path)
	local text = f:read("a")
	f:close()
	return { content = text }
end


return M
