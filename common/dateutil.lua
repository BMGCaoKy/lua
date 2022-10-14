local math_ceil = math.ceil

function Lib.getYearMonthStr(time)
	return os.date("%Y%m", time)
end

function Lib.getYearWeekStr(time)
	return os.date("%Y", time)..Lib.getWeeksOfYear(time)
end

function Lib.getWeeksOfYear(time)
	if not time then
		time = os.time()
	end
	local startTime = os.time({year = os.date("%Y", time), month = 1, day = 1})
	local startDate = os.date("*t", startTime)
	local startWday = startDate.wday - 1
	local yday = os.date("*t", time).yday
	return math_ceil((startWday + yday) / 7)
end

function Lib.getYearDayStr(time)
	local day = string.format("%03d",os.date("*t", time).yday)
	return os.date("%Y", time)..day
end

-- Notice!!!
-- functions below like 'getXXXTime' return the timestamp of GMT;
-- When TIME_ZONE > 0, functions like 'getXXXStartTime' will not work right on time < TIME_ZONE * 3600,
-- use functions like 'getXXXEndTime' is better

function Lib.getMonthStartTime(time)
	local date = os.date("*t", time)
	return os.time({year = date.year, month = date.month, day = 1, hour = 0})
end

function Lib.getWeekStartTime(time)
	local date = os.date("*t", time)
	return os.time({year = date.year, month = date.month, day = date.day - date.wday + 1, hour = 0})
end

function Lib.getDayStartTime(time)
	local date = os.date("*t", time)
	return os.time({year = date.year, month = date.month, day = date.day, hour = 0})
end

function Lib.getMonthEndTime(time)
	local date = os.date("*t", time)
	return os.time({year = date.year, month = date.month + 1, day = 1, hour = 0})
end

function Lib.getWeekEndTime(time)
	local date = os.date("*t", time)
	return os.time({year = date.year, month = date.month, day = date.day - date.wday + 8, hour = 0})
end

function Lib.getDayEndTime(time)
	local date = os.date("*t", time)
	return os.time({year = date.year, month = date.month, day = date.day + 1, hour = 0})
end

function Lib.isSameDay(time1, time2)
	local date1 = os.date("*t", time1)
	local date2 = os.date("*t", time2)
	return date1.year == date2.year and date1.yday == date2.yday
end

function Lib.isSameWeek(time1, time2)
	return Lib.getWeekEndTime(time1) == Lib.getWeekEndTime(time2)
end

function Lib.getTimeDiff(time1, time2)
	local longTime, shortTime, carry, diff = nil, nil, false, {}
	local date1, date2 = os.date("*t",time1), os.date("*t",time2)
	if tonumber(time1) >= tonumber(time2) then
		longTime, shortTime = date1, date2
	else
		longTime, shortTime = date2, date1
	end
	local dayMax = os.date("*t", os.time{year = shortTime.year, month = shortTime.month + 1, day = 0}).day  -- get the days of this month
	local colMax = {60, 60, 24, dayMax, 12, 0}
	longTime.hour = longTime.hour - (longTime.isdst and 1 or 0) + (shortTime.isdst and 1 or 0) -- handle DST
	for i,v in ipairs({"sec", "min", "hour", "day", "month", "year"}) do
		diff[v] = longTime[v] - shortTime[v] + (carry and -1 or 0)
		carry = diff[v] < 0
		if carry then
			diff[v] = diff[v] + colMax[i]
		end
	end
	return diff
end

function Lib.getYear(time)
	return os.date("%Y", time)
end

function Lib.getMonth(time)
	return os.date("%m", time)
end

function Lib.getDayOfMonth(time)
	return os.date("%d", time)
end

function Lib.getDayOfWeek(time)
	return os.date("%w", time)
end

function Lib.getDayOfWeekString(time)
	return os.date("%A", time)
end

function Lib.getDayOfYear(time)
	return os.date("%j", time)
end

local function checkTime(text, append, format, pattern, split)
	split = split or ":"
	if string.find(format, pattern) ~= nil then
		if #text ~= 0 then
			text = text .. split
		end
		if append < 10 then
			text = text .. "0" .. append
		else
			text = text .. append
		end
	end
	return text
end

---获取格式化后的时间字符串 默认(HH:mm:ss)
---@param seconds number 秒
---@param format string 格式(HH:mm:ss)
function Lib.getFormatTime(seconds, format)
	format = format or "HH:mm:ss"
	local text = ""
	local hour = math.floor(seconds / 3600)
	local minute = math.floor((seconds % 3600) / 60)
	local second = seconds % 60
	text = checkTime(text, hour, format, "HH")
	text = checkTime(text, minute, format, "mm")
	text = checkTime(text, second, format, "ss")
	return text
end

---获取北京跟当前服务器时间戳的差值
local function getBeiJingDiffTime()
	return os.time(os.date("*t")) - os.time(os.date("!*t")) - 28800
end

---根据date获取北京时间戳
---@param date table 某个北京时间日期的table
---eg: { year = 2020, month = 1, day = 20, hour = 1, min = 1, sec = 0 }
function Lib.date2BeiJingTime(date)
	date.isdst = false
	return os.time(date) + getBeiJingDiffTime()
end

function Lib.getWeekSeconds()
	return 604800
end

function Lib.getDaySeconds()
	return 86400
end


function Lib.getHourStartTime(time)
	local date = os.date("*t", time)
	return os.time({year = date.year, month = date.month, day = date.day, hour = date.hour, min = 0})
end

function Lib.getHourEndTime(time)
	local date = os.date("*t", time)
	return os.time({year = date.year, month = date.month, day = date.day, hour = date.hour + 1, min = 0})
end

function Lib.isSameHour(time1, time2)
	return Lib.getHourEndTime(time1) == Lib.getHourEndTime(time2)
end

function Lib.getMinStartTime(time)
	local date = os.date("*t", time)
	return os.time({year = date.year, month = date.month, day = date.day, hour = date.hour, min = date.min, sec = 0})
end

function Lib.getMinEndTime(time)
	local date = os.date("*t", time)
	return os.time({year = date.year, month = date.month, day = date.day, hour = date.hour, min = date.min + 1})
end

function Lib.isSameMin(time1, time2)
	return Lib.getMinEndTime(time1) == Lib.getMinEndTime(time2)
end

--根据生日计算星座 birthDate 格式 如 1992-10-22
function Lib.calConstellationWithBirth(birthDate)
	local birthDate = Lib.splitString(birthDate,"-")
	local month = tonumber(birthDate[2])
	local day = tonumber(birthDate[3])
	local constellation = 1
	if month == 1 and day >= 20 then            --水瓶座
		constellation = 1
	elseif month == 2 and day <= 18 then        --水瓶座
		constellation = 1
	elseif month == 2 and day >= 19 then        --双鱼座
		constellation = 2
	elseif month == 3 and day <= 20 then        --双鱼座
		constellation = 2
	elseif month == 3 and day >= 21 then        --白羊座
		constellation = 3
	elseif month == 4 and day <= 19 then        --白羊座
		constellation = 3
	elseif month == 4 and day >= 20 then        --金牛座
		constellation = 4
	elseif month == 5 and day <= 20 then        --金牛座
		constellation = 4
	elseif month == 5 and day >= 21 then        --双子座
		constellation = 5
	elseif month == 6 and day <= 21 then        --双子座
		constellation = 5
	elseif month == 6 and day >= 22 then        --巨蟹座
		constellation = 6
	elseif month == 7 and day <= 22 then        --巨蟹座
		constellation = 6
	elseif month == 7 and day >= 23 then        --狮子座
		constellation = 7
	elseif month == 8 and day <= 22 then        --狮子座
		constellation = 7
	elseif month == 8 and day >= 23 then        --处女座
		constellation = 8
	elseif month == 9 and day <= 22 then        --处女座
		constellation = 8
	elseif month == 9 and day >= 23 then        --天秤座
		constellation = 9
	elseif month == 10 and day <= 23 then        --天秤座
		constellation = 9
	elseif month == 10 and day >= 24 then        --天蝎座
		constellation = 10
	elseif month == 11 and day <= 22 then        --天蝎座
		constellation = 10
	elseif month == 11 and day >= 23 then        --射手座
		constellation = 11
	elseif month == 12 and day <= 21 then        --射手座
		constellation = 11
	elseif month == 12 and day >= 22 then        --摩羯座
		constellation = 12
	elseif month == 1 and day <= 19 then        --摩羯座
		constellation = 12
	end
	return constellation
end