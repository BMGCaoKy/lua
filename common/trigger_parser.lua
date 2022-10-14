-- trigger parser
-- author: great90
-- date: 2018-12-05
-- version: 1.0
-- BNF:
--[[
	chunk ::= {trigger}
	trigger ::= Name [params] actionlist
	params ::= ‘(’ [{expr ‘,’} pair {‘,’ pair}] ‘)’
	pair ::= Name ‘=’ expr
	unopr ::= ‘-’ | ‘~’ | ‘not’
	binopr ::= ‘and’ | ‘or’ | ‘&&’ | ‘||’ | ‘==’ | ‘~=’ | ‘<’ | ‘<=’ | ‘>’ | ‘>=’ | ‘|’ | ‘~’ | ‘&’ | ‘<<’ | ‘>>’ | ‘+’ | ‘-’ | ‘*’ | ‘/’ | ‘//’ | ‘%’ | ‘^’
	expr ::= actioncall {fieldindex} | value | unopr expr | expr binopr expr {binopr expr} | ‘(’ expr ‘)’
	expr ::= actioncall {fieldindex} | value
	actioncall ::= Name params | actionabbr
	actionabbr ::= ‘$’ Name | ‘$’ ‘[’ expr ‘]’ | ‘@’ Name | ‘@’ ‘[’ expr ‘]’
	fieldindex ::= ‘.’ Name | ‘[’ expr ‘]’
	actionlist ::= ‘{’ {action [‘;’]} ‘}’
	action ::= Name [params] [actionlist] | Name params fieldindex {fieldindex} ‘=’ expr | actionabbr {fieldindex} ‘=’ expr
	value ::= nil | false | true | Numeral | String | object | array
	object ::= ‘{’ [fieldlist] ‘}’
	fieldlist ::= field {‘,’ field} [‘,’]
	field ::= Name ‘=’ value
	array ::= ‘[’ valuelist [‘,’] ‘]’
	valuelist ::= value {‘,’ value}
]]

local strfmt = string.format
local strsub = string.sub
local strlen = string.len
local strfind = string.find
local table_remove = table.remove

local TABSIZE = 4

local function new_token(type, token, line, column, offset)
	return {type = type, token = token, line = line, column = column, offset = offset}
end

local function fmt_token(t)
	if not t then
		return "nil"
	end
	return strfmt("{type:%s, token:%q, line:%d, column:%d, offset:%d}", t.type, t.token, t.line, t.column, t.offset)	
end

local TriggerLexer = {}

function TriggerLexer.create(input)
	local state = {
		input = input,
		offset = 1,
		line = 1,
		column = 1,
		lookaheads = {},
	}
	return setmetatable(state, {__index = TriggerLexer})
end

function TriggerLexer:tostring()
	local lookaheads = ""
	for i = 1, #self.lookaheads do
		lookaheads = lookaheads..fmt_token(self.lookaheads[i])
	end
	return strfmt("{line:%d, column:%d, offset:%d, lookaheads = {%s}}", self.line, self.column, self.offset, lookaheads)
end

function TriggerLexer:newline()
	local input = self.input
	local pos = self.offset - 1
	local last = strsub(input, pos, pos)
	assert(last == "\r" or last == "\n", last)
	pos = pos + 1
	local char = strsub(input, pos, pos)
	if (char == "\n" or char == "\r") and char ~= last then
		self.offset = pos + 1	-- skip '\n\r' or '\r\n'
	end
	self.line = self.line + 1
	self.column = 1
end

function TriggerLexer:skip_comment()
	local input = self.input
	local offset = self.offset - 1
	assert(strsub(input, offset - 1, offset) == "--", offset)
	local _, pos = strfind(input, "([\r\n])", offset)
	if pos then
		self.offset = pos + 1
		self:newline()
	else
		self.offset = #input + 1
		self.column = self.column + #input - offset + 3
	end
end

function TriggerLexer:read_string()
	local input = self.input
	local offset = self.offset
	while true do
		local from, to, value = strfind(input, '(\\*")', offset)
		if value == nil then
			self:error("broken string")
		end
		if #value % 2 == 1 then
			local str = strsub(input, offset, to - 1)
			if strfind(str, "\n", 1, true) then
				self:error("string contains \\n")
			end
			self.column = self.column + (to + 1 - self.offset)
			self.offset = to + 1
			return str
		end
		offset = to + 1
	end
end

function TriggerLexer:error(message, column)
	error(strfmt("%s at line %d:%d", message, self.line, column or self.column))
end

function TriggerLexer:error_token(t, expect)
	local msg = strfmt("Invalid token [%s] '%s'", t.type, t.token)
	if expect then
		msg = strfmt("%s, expect \"%s\"", msg, expect)
	end
	error(strfmt("%s at line %d:%d", msg, t.line, t.column))
end

local TOKEN_PATTERNS = {
	COMMENT = { "%-%-" },
	LOGIC   = { "(not) ", "(and) ", "(or) " },
	NAME    = { "([%a_]+[%w_]*)" },
	NUMBER  = { "([%+%-]?%d+%.?%d*)" },
	STRING  = { '"' },
	TAB		= { "\t" },
	NEWLINE = { "([\n\r])" },
	BRACKET = { "([%(%)%[%]{}])" },
	SEP     = { "([,;])" },
	SIGN    = {
				"(~=?)", "(==?)", "(<[<=]?)", "(>[>=]?)",
				"(//?)", "(&&?)", "(||?)", "([%@%$%.%+%-%*%%^])",
			  },
	EOS     = { "$" },
}
for _, patterns in pairs(TOKEN_PATTERNS) do
	for k, v in pairs(patterns) do
		patterns[k] = "^[ ]*"..v
	end
end
local ORDERED_PATTERNS_TYPE = {
	"COMMENT", "LOGIC", "NAME", "NUMBER", "STRING", "TAB",
	"NEWLINE", "BRACKET", "SEP", "SIGN", "EOS"
}
function TriggerLexer:_read_token()
	local input = self.input
	local offset = self.offset
	local type, from, to, token
	for _, t in ipairs(ORDERED_PATTERNS_TYPE) do
		for _, pattern in ipairs(TOKEN_PATTERNS[t]) do
			from, to, token = strfind(input, pattern, offset)
			if from then
				type = t
				goto matched
			end
		end
	end
	self:error("read token error")
	::matched::
	local newpos = to + 1
	local column = self.column
	self.column = column + (newpos - offset)
	self.offset = newpos
	if type == "COMMENT" then
		self:skip_comment()
		return self:_read_token()
	elseif type == "NEWLINE" then
		self:newline()
		return self:_read_token()
	elseif type == "TAB" then
		self.column = self.column + TABSIZE - 1
		return self:_read_token()
	elseif type == "STRING" then
		offset = offset - 1
		token = self:read_string()
	end
	return new_token(type, token, self.line, column + from - offset, from)
end

function TriggerLexer:check_next(expect)
	local t = self:next_token()
	if t.token ~= expect then
		self:error_token(t, expect)
	end
end

function TriggerLexer:lookahead(index)
	if not index then
		index = 1
	end
	local lookaheads = self.lookaheads
	for i = #lookaheads + 1, index do
		lookaheads[i] = self:_read_token()
	end
	return lookaheads[index]
end

function TriggerLexer:next_token()
	local token = table_remove(self.lookaheads, 1)
	if token then
		return token
	end
	return self:_read_token()
end

--------------------------------------------------------------------------------

local TriggerParser = {}

local function is_action(object)
	return type(object) == "table" and object.__action
end

local function gen_action(name, args, line, column, offset, source)
	local params = {}
	local funcs = {}
	local children = {}
	for k, v in pairs(args) do
		local tv = type(v)
		if name == "Sequence" or name == "Selector" or name == "Parallel" then
			assert(k == #children + 1, k)
			children[k] = v
		elseif is_action(v) then
			funcs[k] = v
		else
			params[k] = v
		end
	end
	local action = {
		type = name,
		params = next(params) and params or nil,
		funcs = next(funcs) and funcs or nil,
		children = next(children) and children or nil,
	}
	local mt = {__action = true, __line = line, __column = column,	__offset = offset, __source = source}
	return setmetatable(action, {__index = mt})
end

function TriggerParser:object()
	local lexer = self.lexer
	lexer:check_next("{")
	local fields = {}
	while true do
		local t = lexer:lookahead()
		if t.token == "}" then
			break
		end
		local key
		if t.token == "[" then
			lexer:next_token()
			key = self:expr()
			lexer:check_next("]")
		else
			t = self:name_token()
			key = t.token
		end
		lexer:check_next("=")
		fields[key] = self:expr()
		t = lexer:lookahead()
		if t.token ~= "}" then
			lexer:check_next(",")
		end
	end
	lexer:check_next("}")
	return fields
end

function TriggerParser:array()
	local lexer = self.lexer
	lexer:check_next("[")
	local list = {}
	while true do
		local t = lexer:lookahead()
		if t.token == "]" then
			break
		end
		list[#list + 1] = self:expr()
		t = lexer:lookahead()
		if t.token ~= "]" then
			lexer:check_next(",")
		end
	end
	lexer:check_next("]")
	return list
end

function TriggerParser:value()
	local lexer = self.lexer
	local t = lexer:lookahead()
	local token = t.token
	if token == "["	then
		return self:array()
	elseif token == "{" then
		return self:object()
	end
	lexer:next_token()
	local type = t.type
	if type == "STRING"then
		return token
	elseif type == "NUMBER" then
		return tonumber(token)
	elseif token == "nil" then
		return nil
	elseif token ~= "true" and token ~= "false" then
		lexer:error_token(t, "VALUE")
	end
	return token == "true"
end

function TriggerParser:name_token()
	local lexer = self.lexer
	local t = lexer:next_token()
	if t.type ~= "NAME" then
		lexer:error_token(t, "NAME")
	end
	return t
end

function TriggerParser:fieldindex()
	local lexer = self.lexer
	local t = lexer:next_token()
	local token = t.token
	local key
	if token == "." then
		key = self:name_token().token
	elseif token == "[" then
		key = self:expr()
		lexer:check_next("]")
	else
		lexer:error_token(t, ".|[")
	end
	return key
end

function TriggerParser:ifstat()
	local lexer = self.lexer
	local t = lexer:lookahead()
	local token = t.token
	assert(token == "If", t.token)
	local result = gen_action("If", {}, t.line, t.column, t.offset, self.source)
	local children = {}
	repeat
		lexer:next_token()
		local params = token == "Else" and {true} or self:params()
		if #params ~= 1 then
			lexer:error("if need a cond", t.column)
		end
		local action = gen_action("IfBranch", params, t.line, t.column, t.offset, self.source)
		action.children = self:actionlist()
		children[#children + 1] = action
		if token == "Else" then
			break
		end
		t = lexer:lookahead()
		token = t.token
	until (token ~= "ElseIf" and token ~= "Else")
	result.children = children
	return result
end

function TriggerParser:action()
	local lexer = self.lexer
	local t = lexer:lookahead()
	local token = t.token
	if token == "If" then
		return self:ifstat()
	elseif token == "ElseIf" or token == "Else" then
		lexer:error("unexpect "..token, t.column)
	end
	lexer:next_token()
	local action, key, suffix
	if t.type == "NAME" then
		local n = lexer:lookahead()
		local params = n.token == '(' and self:params() or {}
		action = gen_action(token, params, t.line, t.column, t.offset, self.source)

		local token = lexer:lookahead().token
		if token == "{" then
			action.children = self:actionlist()
			return action
		elseif token ~= "." and token ~= "[" then
			if n.token ~= "(" and n.token ~= "{" then
				lexer:error_token(n, "(|{")
			end
			return action
		end
		suffix, key = "ObjectVar", self:fieldindex()
	elseif t.type == "SIGN" and (token == "@" or token == "$") then
		if lexer:lookahead().type == "NAME" then
			key = self:name_token().token
		else
			lexer:check_next("["); key = self:expr(); lexer:check_next("]")
		end
		suffix = token == "@" and "GlobalVar" or "ContextVar"
	else
		lexer:error_token(t, "NAME|@|$")
	end

	while true do
		t = lexer:lookahead()
		token = t.token
		if token == "=" then
			break
		elseif token ~= "." and token ~= "[" then
			lexer:error_token(t, "=|.|[")
		end
		action = gen_action("Get"..suffix, {obj = action, key = key}, t.line, t.column, t.offset, self.source)
		suffix, key = "ObjectVar", self:fieldindex()
	end
	lexer:check_next("=")
	return gen_action("Set"..suffix, {obj = action, key = key, value = self:expr()}, t.line, t.column, t.offset, self.source)
end

function TriggerParser:actionlist()
	local lexer = self.lexer
	lexer:check_next("{")
	local actions = {}
	while true do		
		local t = lexer:lookahead()
		if t.token == "}" then
			break
		end
		actions[#actions + 1] = self:action()
		t = lexer:lookahead()
		if t.token == ";" then
			lexer:next_token()
		end
	end
	lexer:check_next("}")
	return actions
end

function TriggerParser:actioncall()
	local lexer = self.lexer
	local t = lexer:next_token()
	local token = t.token
	if t.type == "NAME" then
		local params = self:params()
		return gen_action(token, params, t.line, t.column, t.offset, self.source)
	elseif t.type == "SIGN" and (token == "@" or token == "$") then
		token = token == "@" and "GetGlobalVar" or "GetContextVar"
	else
		lexer:error_token(t, "NAME|@|$")
	end
	local n = lexer:lookahead()
	local key = n.token
	if n.type == "NAME" then
		lexer:next_token()
	else
		lexer:check_next("["); key = self:expr(); lexer:check_next("]")
	end
	return gen_action(token, {key = key}, t.line, t.column, t.offset, self.source)
end

local UnaryOperators = { ['not'] = true, ['-'] = true, ['~'] = true, }	-- ['!'] = true, 
local BinOperPriorities = {
	['or']  = {1, 1},   ['and'] = {2, 2},   ['||'] = {1, 1},   ['&&'] = {2, 2},
	['==']  = {3, 3},   ['~=']  = {3, 3},   ['<']  = {3, 3},   ['<='] = {3, 3},
	['>']   = {3, 3},   ['>=']  = {3, 3},   ['|']  = {4, 4},   ['~']  = {5, 5},
	['&']   = {6, 6},   ['<<']  = {7, 7},   ['>>'] = {7, 7},
	['+']   = {10, 10}, ['-']   = {10, 10}, ['*']  = {11, 11}, ['/']  = {11, 11},
	['//']  = {11, 11}, ['%']   = {11, 11}, ['^']  = {14, 13}, -- right associative
}
local UNARY_OPER_PRIORITY = 12
function TriggerParser:subexpr(limit)
	local lexer = self.lexer
	local t = lexer:lookahead()
	local token = t.token
	local action
	if (t.type == "LOGIC" or t.type == "SIGN") and UnaryOperators[token] then
		lexer:next_token()
		local value = self:subexpr(UNARY_OPER_PRIORITY)
		action = gen_action("UnaryOper", {op = token, value = value}, t.line, t.column, t.offset, self.source)
	else
		action = self:simpleexpr()
	end
	local nt = lexer:lookahead()
	token = nt.token
	local priority = BinOperPriorities[token]
	while (nt.type == "LOGIC" or nt.type == "SIGN") and priority and priority[1] > limit do
		lexer:next_token()
		local left = action
		local right, rt = self:subexpr(priority[2])
		if token == "&&" or token == "||" or token == "and" or token == "or" then
			action = gen_action("BinaryOper", {op = token}, nt.line, nt.column, nt.offset, self.source)
			if not is_action(left) then
				left = gen_action("Value", {left}, t.line, t.column, t.offset, self.source)
			end
			if not is_action(right) then
				right = gen_action("Value", {right}, rt.line, rt.column, rt.offset, self.source)
			end
			action.children = {left, right}
		else
			action = gen_action("BinaryOper", {op = token, left = left, right = right}, t.line, t.column, t.offset, self.source)
		end
		t = rt
		nt = lexer:lookahead()
		token = nt.token
		priority = BinOperPriorities[token]
	end
	return action, t
end

function TriggerParser:simpleexpr()
	local lexer = self.lexer
	local t = lexer:lookahead()
	local n = lexer:lookahead(2)
	local token = t.token
	local action
	if token == "(" then
		lexer:next_token()
		action = self:expr()
		lexer:check_next(")")
	elseif (t.type ~= "SIGN" or token ~= "$" and token ~= "@") and (t.type ~= "NAME" or n.token ~= "(") then
		local v = self:value()
		if type(v) ~= "table" then
			return v
		end
		return gen_action("Table", v, t.line, t.column, t.offset, self.source)
	else
		action = self:actioncall()
	end
	while true do
		t = lexer:lookahead()
		token = t.token
		if token ~= "." and token ~= "[" then
			break
		end
		local key = self:fieldindex()
		action = gen_action("GetObjectVar", {obj = action, key = key}, t.line, t.column, t.offset, self.source)
	end
	return action
end

function TriggerParser:expr()
	return self:subexpr(0)
end

function TriggerParser:params()
	local lexer = self.lexer
	lexer:check_next("(")
	local params = {}
	local needpair = false
	local i = 0
	while true do
		local t = lexer:lookahead()
		if t.token == ")" then
			break	-- finished
		end
		local n = lexer:lookahead(2)
		if t.type == "NAME" and n.token == "=" then	-- get pair
			if not needpair then
				needpair = true
				goto continue
			end
			lexer:next_token()	-- key
			lexer:next_token()	-- '='
			params[t.token] = self:expr()
		elseif not needpair then
			i = i + 1
			params[i] = self:expr()
		else			
			lexer:error_token(t, ")")
		end
		n = lexer:lookahead()
		if n.token ~= ")" then
			lexer:check_next(",")
		end
		::continue::
	end
	lexer:check_next(")")
	return params
end

function TriggerParser:trigger()
	local lexer = self.lexer
	local t = lexer:next_token()
	if t.type == "EOS" then
		return nil
	elseif t.type ~= "NAME" then
		lexer:error_token(t, "NAME")
	end
	local n = lexer:lookahead()
	local trigger = n.token == "(" and self:params() or {}
	trigger.type = t.token
	trigger.actions = self:actionlist()
	local mt = {__line = t.line, __column = t.column, __offset = t.offset, __source = self.source}
	return setmetatable(trigger, {__index = mt})
end

function TriggerParser:triggerlist()
	local triggers = {}
	while true do
		local trigger = self:trigger()
		if not trigger then
			break
		end
		triggers[#triggers + 1] = trigger
	end
	return triggers
end

function TriggerParser.parse(input, source)
	local parser = {
		lexer = TriggerLexer.create(input),
		source = source,
	}
	setmetatable(parser, {__index = TriggerParser})
	return parser:triggerlist()
end

local M = {}

function M.parse(filename)
	local content = Lib.read_file(filename)
	assert(content or content ~= "", "cannot open file " .. tostring(filename))
	--[[	local file = assert(io.open(filename, "r"), "cannot open file "..tostring(filename))
        local content = file:read("*a")
        file:close()]]
	local ok, ret = pcall(TriggerParser.parse, content, filename)
	if not ok then
		return nil, ret:gsub("(.-:%d+: )", "", 1)
	end
	return ret
end

return M
