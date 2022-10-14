-- local function L(_, t) return t end
-- local function T(t, n) local r = t[n]; if not r then r = {}; t[n] = r end return r end
-- local function RETURN(t) return t end

-- local BigInteger = L("BigInteger", {})

local tostring = tostring
local string = string
local strfmt = string.format
local strmatch = string.match
local table = table
local tconcat = table.concat
local table_move = table.move
local math = math
local tointeger = math.tointeger
local math_max = math.max
--local math_min = math.min

local MT = T(BigInteger, "__metatable")
MT.__index = BigInteger
BigInteger.IsBigInteger = true

local SegmentDigits = 7
local SegmentBase = math.floor(10 ^ SegmentDigits)

local SegmentFmtStr = "%0" .. SegmentDigits .. "d"
local FormatDigits = 3
local FormatUints = { "", "K", "M", "B", "T", "P", "E", "Z", "Y", "N", "D" }

local function isBigInteger(v)
    return type(v) == "table" and v.IsBigInteger or false
end
---
---Create(120000) --> 120K
---Create("120000") ---> 120K
---Create(12,4) ---> 120K
---
function BigInteger.Create(data, bit)
    if isBigInteger(data) then
        return data
    end

    local bigInteger = setmetatable({
        segments = { 0 },
        negative = false,
    }, MT)
    if bit and type(bit) == "number" then
        for i = 1, bit do
            data = data .. "0"
        end
    end
    local typ = type(data)
    if typ == "string" then
        data = data == "" and '0' or data
        local tryRet = bigInteger:tryLoadFromDesignFormat(data)
        if tryRet then
            return tryRet
        end
        bigInteger:loadFromString(data)
    elseif typ == "number" then
        bigInteger:loadFromString(tostring(math.floor(data)))
    elseif typ == "table" and data.segments then
        return BigInteger.Recover(data)
    elseif typ ~= "nil" then
        perror("BigInteger will return 0,becuese can't create by the type:", typ)
        return BigInteger.Create(0)
    end
    return bigInteger
end
function BigInteger.Recover(data)
    return setmetatable(data, MT)
end
local function loadFromString(str)
    if type(str) ~= "string" then
        return nil
    end
    local sign, digits = strmatch(str, "([+-]?)(%d+)")
    if sign .. digits ~= str then
        return nil
    end

    local segments = {}
    local len = SegmentDigits - 1
    for i = digits:len() - len, -len, -len - 1 do
        segments[#segments + 1] = tonumber(digits:sub(i > 0 and i or 1, i + len))
    end
    return segments, sign == "-"
end

local function toBigInteger(v)
    if isBigInteger(v) then
        return v
    end
    if type(v) == "table" and v.segments then
        -- print("big integer w:this bigInteger Table lose its metatable,will auto recover:",Lib.v2s(v))
        return BigInteger.Recover(v)
    end
    if type(v) == "number" then
        --小数转大数先取整
        v = math.floor(v)
    end
    local segments, negative = loadFromString(tostring(v))
    if not segments then
        return nil
    end
    local integer = BigInteger.Create()
    integer.segments, integer.negative = segments, negative
    return integer
end

function BigInteger:tryLoadFromDesignFormat(str)
    if not string.find(str, ',') then
        return false
    end
    local sprice = Lib.splitString(str, ",")
    assert(tonumber(sprice[1]), "invalid format,if you want user 'val,bat',mabey you forget ','")
    assert(tonumber(sprice[2]), "invalid format,if you want user 'val,bat',mabey you forget ','")
    local useVal = {}
    useVal.val = math.floor(tonumber(sprice[1]) or 0) --(rHpPct.pct or 0) + (add and value or -value)
    useVal.bit = math.floor(tonumber(sprice[2]) or 0)
    return BigInteger.Create(useVal.val, useVal.bit)
end
function BigInteger:loadFromString(str)
    local segments, negative = loadFromString(str)
    assert(segments, "invalid format")
    self.segments, self.negative = segments, negative
end

function BigInteger:clone()
    local ret = BigInteger.Create()
    local segments = self.segments
    table_move(segments, 1, #segments, 1, ret.segments)
    ret.negative = self.negative
    return ret
end

local EMPTY_TABLE = {}
function BigInteger:assign(other)
    local dstSegments = self.segments
    local srcSegments = other.segments
    local srcSegLen = #srcSegments
    table_move(srcSegments, 1, srcSegLen, 1, dstSegments)
    table_move(EMPTY_TABLE, 1, #dstSegments - srcSegLen, srcSegLen + 1, dstSegments)
    self.negative = other.negative
end

---获得大数字数字信息
function BigInteger:getDigitalPart()
    local segments = self.segments
    local len = #segments
    local str = tostring(segments[len])
    local digits = (len - 1) * SegmentDigits + str:len()
    if len > 1 and str:len() < FormatDigits + FormatDigits then
        str = str .. strfmt(SegmentFmtStr, segments[len - 1])
    end
    local intLen = ((digits - 1) % FormatDigits) + 1
    local ret = str:sub(1, intLen)
    if intLen < digits then
        ret = ret .. "." .. str:sub(intLen + 1, intLen + FormatDigits - 1)
    end
    if self.negative then
        ret = "-" .. ret
    end
    local pointPos = string.find(ret, '.', 1, true)
    if ret:len() > 1 and pointPos then
        for i = 0, FormatDigits do
            --del unuse zero
            if string.sub(ret, -1) == '0' then
                ret = string.sub(ret, 1, -2)
            else
                break
            end
        end
        if string.sub(ret, -1) == '.' then
            ret = string.sub(ret, 1, -2)
        end
    end
    return ret, digits
end

function BigInteger:format()
    local ret, digits = self:getDigitalPart()
    return ret .. (FormatUints[math.floor((digits - 1) / FormatDigits) + 1] or "?")
end

function BigInteger:debugFullFormat()
    local segments = self.segments
    local len = #segments
    local temp = { tostring(segments[len]) }
    for i = 2, len do
        temp[i] = strfmt(SegmentFmtStr, segments[len - i + 1])
    end
    local ret = tconcat(temp, "")
    if self.negative then
        ret = "-" .. ret
    end
    return ret
end

function BigInteger:getTextWidth(font, jump)
    local text = self:format()
    if jump then
        local split = Lib.splitString(text, ".")
        if #split >= 2 then
            if #split[2] == 2 then
                text = text .. "0"
            end
        else
            if self >= 1000 then
                text = text .. ".00"
            end
        end
    end
    return font:GetTextExtent(text, 1)
end

function MT.__tostring(self)
    return self:format()
end

local function segmentsAdd(segments1, segments2)
    local segments = {}
    local carry = 0
    for i = 1, math_max(#segments1, #segments2) do
        local sum = carry + (segments1[i] or 0) + (segments2[i] or 0)
        if sum >= SegmentBase then
            carry = tointeger(math.floor(sum / SegmentBase))
            segments[i] = tointeger(sum - carry * SegmentBase)
        else
            carry = 0
            segments[i] = sum
        end
    end
    if carry > 0 then
        segments[#segments + 1] = carry
    end
    return segments
end

local function segmentsSub(segments1, segments2)
    local negative = false
    local len1, len2 = #segments1, #segments2
    if len1 < len2 then
        segments1, segments2 = segments2, segments1
        negative = true
    elseif len1 == len2 then
        for i = len1, 1, -1 do
            local v1, v2 = segments1[i], segments2[i]
            if v1 > v2 then
                break
            elseif v1 < v2 then
                segments1, segments2 = segments2, segments1
                negative = true
                break
            end
        end
    end
    local segments = {}
    local borrow = 0
    for i = 1, #segments1 do
        local value = segments1[i] - borrow - (segments2[i] or 0)
        if value < 0 then
            borrow = 1
            segments[i] = value + SegmentBase
        else
            borrow = 0
            segments[i] = value
        end
    end
    assert(borrow == 0)
    for i = #segments, 2, -1 do
        if segments[i] == 0 then
            segments[i] = nil
        end
    end
    return segments, negative
end
---
---大数除以大数，结果只在0~1之间取值，且仅保留小数点两位，以减少不必要运算，目前主要用于服务最大值和当前值的比例。
---
-----------------
-- ["segments"] = {
--     [1] = 7891234,
--     [2] = 123456
--   },
--   ["negative"] = false
--------------
-- local function segmentsLoopFunc(number1, number2)
-- 	local subTime = 0
-- 	local calcBigNum =  number1:clone()
-- 	while true do
-- 		local _calc = calcBigNum-number2
-- 		if _calc>0 then
-- 			calcBigNum = _calc
-- 			subTime = subTime+1
-- 		else

-- 		end
-- 	end
-- end
local function segmentsFastDiv(segments1, segments2)
    local len1, len2 = #segments1, #segments2
    --print("segments1",Lib.v2s(segments1))
    --print("segments2",Lib.v2s(segments2))
    if len1 > len2 then
        return 1
    elseif len2 - len1 > 1 then
        return 0
    elseif len2 > 1 and len1 == len2 then
        local calc = segments1[len1]
        local highBit = 1
        while true do
            if calc / 10 > 1 then
                highBit = highBit + 1
                calc = calc / 10
            else
                break
            end
        end
        local base = 10 ^ (SegmentDigits - (3 - highBit))
        local base2 = 10 ^ (3 - highBit)
        -- for i = 1,SegmentDigits-(3-highBit) do
        -- 	base*10
        -- end

        -- print("base:",base)
        -- print("base2:",base2)
        local dividend = segments1[len1] * base2 + math.floor(segments1[len1 - 1] / base)
        local divisor = segments2[len2] * base2 + math.floor(segments2[len2 - 1] / base)
        -- print("dividend:",dividend)
        -- print("divisor:",divisor)
        local ret = dividend / divisor
        -- print("ret:", ret)
        ret = math.floor(ret * 100) / 100
        return ret

        -- local dividend = segments1[len1]
        -- local divisor =  segments2[len2]*(SegmentBase^(len2-len1))+(len2-len1>0 and segments2[len1] or 0)
        -- local ret = dividend/divisor
        -- ret =math.floor(ret*100)/100
        -- return ret
    else
        local dividend = segments1[len1]
        local divisor = segments2[len2] * (SegmentBase ^ (len2 - len1)) + (len2 - len1 > 0 and segments2[len1] or 0)
        local ret = dividend / divisor
        ret = math.floor(ret * 100) / 100
        return ret
    end
end
local function checkArithmeticArgment(arg)
    local integer = toBigInteger(arg)
    if not integer then
        error("invalid arithmetic argment " .. tostring(arg))
    end
    return integer
end

function MT.__add(integer1, integer2)
    integer1 = checkArithmeticArgment(integer1)
    integer2 = checkArithmeticArgment(integer2)
    local segments1, segments2 = integer1.segments, integer2.segments
    local negative1, negative2 = integer1.negative, integer2.negative
    local segments, negative
    if negative1 == negative2 then
        -- both are negative or positive
        negative, segments = negative1, segmentsAdd(segments1, segments2)
    elseif negative1 then
        segments, negative = segmentsSub(segments2, segments1)
    else
        segments, negative = segmentsSub(segments1, segments2)
    end
    local ret = BigInteger.Create()
    ret.segments = segments
    ret.negative = negative
    return ret
end

function MT.__sub(integer1, integer2)
    if integer1 == 0 then
        return -integer2
    elseif integer2 == 0 then
        return integer1
    end
    integer1 = checkArithmeticArgment(integer1)
    integer2 = checkArithmeticArgment(integer2)
    local segments1, segments2 = integer1.segments, integer2.segments
    local negative1, negative2 = integer1.negative, integer2.negative
    local segments, negative
    if negative1 ~= negative2 then
        negative, segments = negative1, segmentsAdd(segments1, segments2)
    elseif negative1 then
        -- both negative
        segments, negative = segmentsSub(segments2, segments1)
    else
        -- both positive
        segments, negative = segmentsSub(segments1, segments2)
    end
    local ret = BigInteger.Create()
    ret.segments = segments
    ret.negative = negative
    return ret
end
function MT.__unm(integer1)
    local newInt = integer1:clone()
    if integer1.negative then
        newInt.negative = false
    else
        newInt.negative = true
    end
    return newInt
end

function MT.__mul(number1, number2)
    local integer, number
    if isBigInteger(number1) then
        if isBigInteger(number2) then
            if #number2.segments == 1 then
                number = number2.segments[1] * (number2.negative and -1 or 1)
                integer = number1
            elseif #number1.segments == 1 then
                number = number1.segments[1] * (number1.negative and -1 or 1)
                integer = number2
            else
                error("can not calc big mul big now ! " .. tostring(number2))
            end
        elseif type(number2) ~= "number" then
            error("invalid arithmetic argment " .. tostring(number2))
        else
            integer = number1
            number = number2
        end
    else
        if type(number1) ~= "number" then
            error("invalid arithmetic argment " .. tostring(number1))
        end
        integer, number = number2, number1
    end

    if number == 0 then
        return BigInteger.Create(0)
    end

    local negative = false
    if number > 0 and integer.negative or number < 0 and not integer.negative then
        negative = true
    end
    number = number > 0 and number or -number
    local carry = 0
    local segments = { [1] = 0 }
    for i, value in ipairs(integer.segments) do
        local result = value * number + carry
        if result >= SegmentBase then
            result = math.floor(result)
            segments[i] = math.floor(result % SegmentBase)
            carry = math.floor(result / SegmentBase)
            if i == #integer.segments then
                segments[i + 1] = carry
                break ;
            end
        elseif result > 0 then
            if i == 1 or result >= 1 then
                segments[i] = math.floor(result)
            else
                --高位乘小数造成的退位
                segments[i - 1] = segments[i - 1] + math.floor(result * SegmentBase)
                if i < #integer.segments then
                    segments[i] = 0
                end
            end
            carry = 0
        elseif result == 0 then
            if i < #integer.segments then
                segments[i] = 0
            end
            carry = 0
        end
    end

    local ret = BigInteger.Create()
    ret.segments = segments
    ret.negative = negative
    return ret
end

function MT.__div(number1, number2)
    if isBigInteger(number1) then
        if isBigInteger(number2) then
            --大数除以大数，结果只在0~1之间取值，且仅保留小数点两位，以减少不必要运算，目前主要用于服务最大值和当前值的比例。
            return segmentsFastDiv(number1.segments, number2.segments)
        elseif type(number2) == "number" then
            if number2 == 0 then
                error("divisor is equal to zero")
            end
            return number1 * (1 / number2)--大数除以小数，等于大数乘以小数的倒数  如果这个值小于1则会变为0
        else
            error("invalid arithmetic argment " .. tostring(number2))
        end
    else
        if type(number1) ~= "number" then
            error("invalid arithmetic argment " .. tostring(number1))
        elseif isBigInteger(number2) then
            --小数除以大数，直接约等于0
            return BigInteger.Create(0)
        end
    end

end

function MT.__eq(integer1, integer2)
    if integer1.negative ~= integer2.negative then
        return false
    end
    local segments1, segments2 = integer1.segments, integer2.segments
    local len1, len2 = #segments1, #segments2
    if len1 ~= len2 then
        return false
    end
    for i = 1, len1 do
        if segments1[i] ~= segments2[i] then
            return false
        end
    end
    return true
end

function MT.__le(integer1, integer2)
    if not isBigInteger(integer1) then
        integer1 = BigInteger.Create(integer1)
    elseif not isBigInteger(integer2) then
        integer2 = BigInteger.Create(integer2)
    end
    if integer1.negative ~= integer2.negative then
        return integer1.negative    -- if integer1 is negative and integer2 is positive then integer1 is smaller
    end
    -- integer1 and integer2 are both negative or positive
    local segments1, segments2 = integer1.segments, integer2.segments
    if integer1.negative then
        segments1, segments2 = segments2, segments1
    end
    local len1, len2 = #segments1, #segments2
    if len1 ~= len2 then
        return len1 < len2
    end
    --for i = 1, len1 do
    --	local v1, v2 = segments1[i], segments2[i]
    --	if v1 ~= v2 then
    --		return v1 < v2
    --	end
    --end
    for i = len1, 1, -1 do
        local v1, v2 = segments1[i], segments2[i]
        if v1 ~= v2 then
            return v1 < v2
        end
    end
    return true, true
end

function MT.__lt(integer1, integer2)
    local little, equal = MT.__le(integer1, integer2)
    return little and not equal
end
function MT.__concat(arg1, arg2)
    if not isBigInteger(arg1) then
        return arg1 .. tostring(arg2)
    else
        return tostring(arg1) .. arg2
    end
end

return RETURN()