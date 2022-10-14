local BehaviorTree = L("BehaviorTree", {})
local Actions = T(BehaviorTree, "Actions")
local T_RETURN = L("T_RETURN", {})
local T_BREAK = L("T_BREAK", {})
local T_CONTINUE = L("T_CONTINUE", {})
local DICTIONARY_MT = T(BehaviorTree, "DICTIONARY_MT", {})

local setting = require "common.setting"

local strfmt = string.format

local isEnd = {}
local returnRet = {}
local func_deep = 0
local func_size = 0
local funcReturnMap = {}

local function v2s(v)
	local t = type(v)
	if t=="table" and not v.__name and v.x and v.y and v.z then
		return string.format("{%s,%s,%s}", v.x, v.y, v.z)
	elseif t=="string" then
		return '"'..v..'"'
	else
		return tostring(v)
	end
end

local function IsFuncsEnd()
	return isEnd[func_deep] == true
end 

local function run(node, context, action)
	if IsFuncsEnd() then 
		return 
	end
	local func = Actions[node.type]
	if not func then
		local info = ""
		local source = node.__source
		if source then
			source = source:gsub("/", "\\", 1)
			info = strfmt("\n\t%s(%d): at column:%d", source,
						node.__line or -1, node.__column or -1)
		end
		error("Action not define: "..node.type..info)
	end
	Profiler:begin("Actions."..node.type)
	local params = {}
	local txt = {}
	for k, v in pairs(node.params or {}) do
		params[k] = v
		txt[#txt+1] = strfmt("$%s:%s", k, v2s(v))
	end	
	if context.debug then
		print("Action:", node.path.." ( "..table.concat(txt,", ").." )")
	end
	for k, v in pairs(node.funcs or {}) do
		params[k],returnRet[func_deep] = run(v, context)
	end	
	local ok, ret = xpcall(func, traceback, node, params, context)
	Profiler:finish("Actions."..node.type)
	if not ok then
		if ret == T_BREAK or ret == T_CONTINUE or ret == T_RETURN then
			error(ret, 0)
		end
		if type(ret) ~= "table" then
			ret = { msg = ret }
		end
		if not action or action == node.type then
			local info = ","
			local source = node.__source
			if source then
				source = source:gsub("/", "\\", 1)
				if source:sub(1, 1) ~= "/" and not source:find(":\\") and not source:find(":/") then
					source = ".\\../res/"..source
				end
				info = strfmt("\n\t%s(%d): at column:%d", source,
							node.__line or -1, node.__column or -1)
			end
			ret[#ret + 1] = strfmt("%s in action '%s'", info, node.type)
		end
		Lib.sendErrMsgToChat(context.obj1, ret)
		error(ret)
	end
	if context.debug then
		print("Action:", node.path .. " = " .. v2s(ret))
	end

	return ret,returnRet and returnRet[func_deep]
end

function BehaviorTree.Run(nodes, context,is_funcs)
	context = context or {}
	local node = {
		type = "Parallel",
		children = nodes,
	}
	local ok, ret = xpcall(Actions.Parallel, traceback, node, {}, context)
	if not ok then
		local msg = ret
		if msg == T_RETURN then
			return true
		elseif msg == T_BREAK or msg == T_CONTINUE then
			error("'Break' or 'Continue' must in a loop")
		end
		if type(ret) == "table" then
			local bt = ""
			local err = ret.msg
			if type(err) == "string" then
				err, bt = err:match("(.-)([\r\n]*stack traceback.+)")
			end
			msg = (err or "")..table.concat(ret, "")..bt
		end
		if context.dir then
			msg = msg .. "\ncfg.dir: " .. context.dir
		end
		perror("BehaviorTree error:", msg)
		Lib.sendErrMsgToChat(context.obj1, msg)
	end
	return ok,returnRet and returnRet[func_deep]
end

local function initNode(node, path, key)
	assert(type(node) == "table", string.format("%s#%s#%s", node, path, key))
	node.path = string.format("%s + %s%s", path, key, node.type)
	for k, n in pairs(node.funcs or {}) do
		initNode(n, path .. " | ", "$"..k..":")
	end
	for i, n in ipairs(node.children or {}) do
		initNode(n, path .. " | ", "["..i.."]")
	end
end

function BehaviorTree.InitNodes(nodes, path)
	for i, node in ipairs(nodes or {}) do
		initNode(node, path, "["..i.."]")
	end
end

-- 基础Action定义

function Actions.Sequence(node, params, context)
	for _, child in ipairs(node.children or {}) do
		if run(child, context)==false then
			return false
		end
	end
	return true
end

function Actions.Parallel(node, params, context)
	for _, child in ipairs(node.children or {}) do
		run(child, context)
	end
	return true
end

function Actions.Sum(node, params, context)
	local sum = 0
	for _, child in ipairs(node.children or {}) do
		local ret = run(child, context)
		if type(ret)=="number" then
			sum = sum + ret
		end
	end
	return sum
end

function Actions.Assert(node, params, context)
	return assert(params[1], params[2])
end

function Actions.SequenceNot(node, params, context)
	return not Actions.Sequence(node, params, context)
end

local UnaryOprFuncs = {
	['not'] = function(v) return not v end,
	['!'] = function(v) return not v end,
	['-'] = function(v) return -v end,
	['~'] = function(v) return Bitwise64.Not(v) end,
}

function Actions.UnaryOper(node, params, context)
	local func = UnaryOprFuncs[params.op]
	assert(func, string.format("unsupport unary operation '%s'", tostring(params.op)))
	return func(params.value)
end

local BinaryOprFuncs = {
	-- arithmetic
	['+']  = function(l, r) return l + r end,
	['-']  = function(l, r) return l - r end,
	['*']  = function(l, r) return l * r end,
	['/']  = function(l, r) return l / r end,
	['//'] = function(l, r) return math.floor(l / r) end,
	['%']  = function(l, r) return l % r end,
	-- bit
	['^']  = function(l, r) return math.pow(l, r) end,
	['&']  = function(l, r) return Bitwise64.And(l, r) end,
	['|']  = function(l, r) return Bitwise64.Or(l, r) end,
	['~']  = function(l, r) return Bitwise64.Xor(l, r) end,
	['<<'] = function(l, r) return Bitwise64.Sl(l, r) end,
	['>>'] = function(l, r) return Bitwise64.Sr(l, r) end,
	-- logic
	--['&&'] = function(l, r) return l and r end,
	--['||'] = function(l, r) return l or r end,
	['=='] = function(l, r) return l == r end,
	['~='] = function(l, r) return l ~= r end,
	['<']  = function(l, r) return l < r end,
	['>']  = function(l, r) return l > r end,
	['<='] = function(l, r) return l <= r end,
	['>='] = function(l, r) return l >= r end,
}

function Actions.BinaryOper(node, params, context)
	local op = params.op
	if op == "and" or op == "&&" then
		local ret
		for _, child in ipairs(node.children) do
			ret = run(child, context)
			if not ret then
				return ret
			end
		end
		return op == "and" and ret or true
	elseif op == "or" or op == "||" then
		local ret
		for _, child in ipairs(node.children) do
			ret = run(child, context)
			if ret then
				return op == "or" and ret or true
			end
		end
		if op == "or" then
			return ret
		end
		return false
	else
		local func = BinaryOprFuncs[op]
		assert(func, string.format("unsupport binary operation '%s'", tostring(op)))
		return func(params.left, params.right)
	end
end

function Actions.Selector(node, params, context)
	for _, child in ipairs(node.children or {}) do
		if run(child, context)~=false then
			return true
		end
	end
	return false
end

function Actions.IfBranch(node, params, context)
	--assert(#params <= 1, #params)
	if not (params[1] or params.condition) then
		return false
	end
	for _, child in ipairs(node.children or {}) do
		run(child, context)
	end
	return true
end

function Actions.If(node, params, context)
	for _, child in ipairs(node.children or {}) do
		--assert(child.type == "IfBranch", tostring(child.type))
		if run(child, context, "IF") then
			return
		end
	end
end

function Actions.Return(node, params, context)
	error(T_RETURN, 0)
end

function Actions.Break(node, params, context)
	assert(context._isInLoop_, "'Break' must in a loop")
	error(T_BREAK, 0)
end

function Actions.Continue(node, params, context)
	assert(context._isInLoop_, "'Continue' must in a loop")
	error(T_CONTINUE, 0)
end

local function runLoopChildren(children, context)
	local inLoop = context._isInLoop_
	context._isInLoop_ = true
	for _, child in ipairs(children or {}) do
		local ok, ret = pcall(run, child, context)
		if ok then
			goto continue
		end
		context._isInLoop_ = inLoop
		if ret == T_CONTINUE then
			break
		elseif ret == T_BREAK then
			return true
		elseif ret == T_RETURN then
			error(ret, 0)
		else
			error(ret)
		end
		::continue::
	end
	return false
end

local function doLoop(from, to, step, key, children, context)
	for i = from, to, step do
		if key then
			if context and context.isFunc then
				context = context or {}
				context.func = context.func or {}
				context.func.vars = context.func.vars or {}
				context.func.vars[key] = v
			else 
				context[key] = i
			end
		end
		if runLoopChildren(children, context) then
			break
		end
	end
end

function Actions.While(node, params, context)
	if not node.children or #node.children == 0 or not node.funcs then
		return
	end
	repeat
		for _, tempNode in ipairs(node.funcs) do
			for _, child in ipairs(tempNode.children or {}) do
				if not run(child, context, "WHILE_JUDGMENT") then
					return
				end
			end
			if not run(tempNode, context, "WHILE_JUDGMENT") then
				return
			end
		end
		if runLoopChildren(node.children, context) then
			break
		end
	until(false)
end

function Actions.WhileBranch(node, params, context)
	repeat
		if not node.funcs and not node.params then
			return false
		end
		if node.funcs and (not run(node.funcs.condition, context, "WHILE_BLANCE_JUDGMENT")) then
			return false
		end
		if node.params and node.params.condition == false then
			return false
		end
		if runLoopChildren(node.children, context) then
			break
		end
	until(false)
end

function Actions.LoopTimes(node, params, context)
	local times, key = params[1] or params.times, params[2] or params.key
	assert(type(times) == "number", "loop times must be a number")
	assert(not key or type(key) == "string", "loop times key must be a string or nil")
	doLoop(1, times, 1, key, node.children, context)
end

function Actions.ForLoop(node, params, context)
	local from = assert(params.from, "for loop need from")
	local to = assert(params.to, "for loop need to")
	local step, key = params.step or 1, params.key
	ActionsLib.tipIfWillOccursEndlessLoop(from, to, step)
	doLoop(from, to, step, key, node.children, context)
end

function Actions.Foreach(node, params, context)
	local key = assert(params.key, "foreach need key name")
	local array = params.array
	if type(array) ~= "table" then
		Lib.logError("Actions.Foreach: array is invalid !")
		return
	end
	for _, v in ipairs(array) do
		if key then
			if context and context.isFunc then
				context = context or {}
				context.func = context.func or {}
				context.func.vars = context.func.vars or {}
				context.func.vars[key] = v
			else 
				context[key] = v
			end
		end
		if runLoopChildren(node.children, context) then
			break
		end
	end
end

function Actions.ForeachDictionary(node, params, context)
	local keyName = assert(params.keyName, "foreach need keyName name")
	local valueName = assert(params.valueName, "foreach need valueName name")
	local tb = params.dict
	assert(getmetatable(tb) == DICTIONARY_MT, "dict must be a dictionary")
	for k, v in pairs(tb.data) do
		context[keyName] = k
		context[valueName] = v
		if runLoopChildren(node.children, context) then
			break
		end
	end
end

function Actions.ExecScript(node, params, context)
	assert(params.script_name,"not_script")
	local path = Root.Instance():getGamePath()
	local trans_path = Lib.combinePath(path, "trigger_script/")
	local script_dir = string.format("%s%s.lua", trans_path, params.script_name)
	local script_context = Lib.read_file(script_dir)
	local loadstring = rawget(_G, "loadstring") or load

	local pre_str = [[
		local params = {...}
		params = params[1] or {}
	]]

	return loadstring(pre_str..script_context)(params)
end

function Actions.ExecFunction(node, params, context)
	if not params.func_name then return nil end 
	local temp_context = {}
	temp_context.func = {}
	temp_context.params = params
	temp_context.isFunc = true
	func_deep = func_deep+1
	isEnd[func_deep] = false
	local ret = Trigger.ExeFuncs(params.func_name,temp_context)
	isEnd[func_deep] = false
	func_deep = func_deep-1
	return ret
end

function Actions.ReturnFuncs(node, params, context)
	if params and params.value then 
		returnRet[func_deep] = params.value
		--print("ReturnFuncs value=============",func_deep," " ,func_size," ", params.value)
		isEnd[func_deep] = true
		return params.value
	end
	local ret = nil
	if node.funcs then 
		ret = run(node.funcs.value , context) 
	end
	isEnd[func_deep] = true
	returnRet[func_deep] = ret
	--print("ReturnFuncs func=============",func_deep," ",func_size," " ,ret)
	return ret
end

-- TODO need to delete
function Actions.Loop(node, params, context)
	if not node.children or #node.children == 0 then
		return
	end

	repeat
		for _, child in ipairs(node.children) do
			if run(child, context) == false then	-- todo select
				return
			end
		end
	until(false)
end

-- TODO need to delete
function Actions.Compute(node,params,context)
    local op = params.op
    if op=="add" then
        return params.p1+params.p2
    end
    if op=="sub" then
        return params.p1-params.p2
    end
    if op=="mul" then
        return params.p1*params.p2
    end
    if op=="div" then
        return params.p1/params.p2
    end
    if op=="mod" then
        return params.p1 % params.p2
    end
end

-- TODO need to delete
function Actions.Compare(node,params,context)
    local co = params.co
    if co==">" then
        return params.p1>params.p2
    end
    if co=="<" then
        return params.p1<params.p2
    end
    if co=="==" then
        return params.p1==params.p2
    end
    if co=="!=" then
        return params.p1~=params.p2
    end
    if co==">=" then
        return params.p1>=params.p2
    end
    if co=="<=" then
        return params.p1<=params.p2
    end
end

-- TODO need to delete
function Actions.Value(node, params, context)	-- for short circuit of '&&', '||', 'and' and 'or'
	return params[1]
end

RETURN(BehaviorTree)
