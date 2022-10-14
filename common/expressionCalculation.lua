--[[
ParameterFormat = #t/f/p:cfg/prop/self/value:key#
    source = t->target/f->from/p->packet; -- todo ex
    getTableFunc = cfg->:cfg()(key)/prop->:prop(key)/self->[key]/value->:getValue(key); -- todo ex
    key = key->the key; 

expression like: "return (#t:cfg:maxHp#*20+2)/#t:prop:curHp#-1" => return (target:cfg().maxHp*20+2)/target:prop("curHp")-1
    just deseri #xxxxx# and return a num, then use lua 'loadstring(str)()' to get the result!
]]
--[[
reference code
    print(loadstring("if 10>0 then return 0 else return 1 end")())
    print(loadstring("return 10+20+30")())

    d p(Lib.getExpressionResult("return (#t:cfg:maxHp#*20+2)/#t:self:curHp#-1", {target = Me}))
    d p(Lib.getExpressionResult("return 1/0", {target = Me}))
    d p(Lib.getExpressionResult("return 0/1", {target = Me}))
]]

local l_loadstring = rawget(_G, "loadstring") or load
local l_xpcall = xpcall
local huge = math.huge
local _huge = -huge

local EXPRESSION_STR_MARK = "return "

local GET_SOURCE_FUNC = {}
local HANDLE_METHOD_FUNC = {}

GET_SOURCE_FUNC.t = function(params)
    return params.target
end
GET_SOURCE_FUNC.f = function(params)
    return params.from
end
GET_SOURCE_FUNC.p = function(params)
    return params.packet
end

HANDLE_METHOD_FUNC.cfg = function(source, params, key)
    return source.cfg and source:cfg()[key] or 0
end

HANDLE_METHOD_FUNC.prop = function(source, params, key)
    return source.prop and source:prop(key) or 0
end

HANDLE_METHOD_FUNC.prop = function(source, params, key)
    return source.getValue and source:getValue(key) or 0
end

HANDLE_METHOD_FUNC.self = function(source, params, key)
    return source[key]
end

local function deseriMatchStr(matchStr, params)
    local arr = Lib.splitString(string.sub(matchStr, 2, #matchStr-1), ":") -- 1.sourceKey 2.methodKey 3.keyKey
    local sourceKey, methodKey, keyKey = table.unpack(arr)
    if not sourceKey or not methodKey or not keyKey then
        return 0
    end
    local sourceFunc = GET_SOURCE_FUNC[sourceKey]
    if not sourceFunc then
        return 0
    end
    local source = sourceFunc(params)
    if not source then
        return 0
    end
    local handlerMethodFunc = HANDLE_METHOD_FUNC[methodKey]
    if not handlerMethodFunc then
        return 0
    end
    return handlerMethodFunc(source, params, keyKey) or 0
end

local function deseriExpression(expression, params)
    local matchArray = {}
    for k in string.gmatch(expression, "#%w+:%w+:%w+#") do
        matchArray[#matchArray + 1] = k
    end
    local expression = string.gsub(expression, "#(%w+):(%w+):(%w+)#", "%%d")
    for index, matchStr in ipairs(matchArray) do
        matchArray[index] = deseriMatchStr(matchStr, params)
    end
    return string.format(expression, table.unpack(matchArray))
end

function Lib.getExpressionResult(expression, params) -- expression -> must be string
    if type(expression) ~= "string" or not params then
        return expression
    end
    if not string.find(expression, EXPRESSION_STR_MARK) then -- must be have return, cause like reference code always can be load.
        Lib.logWarning("getExpressionResult warning! the str had not 'return'! expression = ", expression)
        return expression
    end
    -- todo ex check

    local func = l_loadstring(deseriExpression(expression, params))
    if not func then
        Lib.logWarning("getExpressionResult warning! the str can't load func! expression = ", expression)
        return 0
    end
    local ok, ret = l_xpcall(func, traceback)
    if not ok then
        Lib.logWarning("getExpressionResult warning! the str func call error! expression = ", expression)
        return 0
    end
    if ret == nil or ret == huge or ret == _huge then
        Lib.logWarning("getExpressionResult warning! the str func call warning! return error! ret = ", ret)
        return 0
    end
    return ret
end