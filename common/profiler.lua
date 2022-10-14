local cjson = require "cjson"
local misc = require "misc"

local now_nanoseconds = misc.now_nanoseconds
local csv_encode = misc.csv_encode
local tconcat = table.concat
local strfmt = string.format

local function getTime()
	return now_nanoseconds() / 1000000
end

local function fmtTime(time)
	return strfmt("%.6f", time)
end

function Profiler:begin(name)
	if not self.inited then
		return
	end
	local start = getTime()
	local stack = self.stack
	local index = #stack + 1
	stack[index] = { name = name, time = start, garbage = collectgarbage("count")}
	self:stat("Profiler.begin", getTime() - start)
	return index
end

function Profiler:finish(name)
	if not self.inited then
		return
	end
	local start = getTime()
	local stack = self.stack
	local index = #stack
	while index > 1 and name ~= stack[index].name do	-- TODO need more check
		print("Profiler miss end", stack[index].name, index)
		table.remove(stack, index)
		index = index - 1
	end
	if not stack or not stack[index] then
		return
	end
	local time = getTime() - stack[index].time
	local deltaGarbage = collectgarbage("count") - stack[index].garbage
	stack[index] = nil
	self:stat(name, time, deltaGarbage)
	self:stat("Profiler.end", getTime() - start)
end

function Profiler:stat(name, time, garbage)
	local stat = self.stats[name]
	if not stat then
		stat = { count = 0, time = 0, min = math.huge, max = -1, garbage = 0 }
		self.stats[name] = stat
	end

	if time <= 0 then
		print("Profiler stat time <= 0", name, time)
		return
	end

	stat.count = stat.count + 1
	stat.time = stat.time + time
	if time < stat.min then
		stat.min = time
	end
	if time > stat.max then
		stat.max = time
	end	
	if garbage and garbage > 0 then 
		stat.garbage = stat.garbage + garbage
	end
end

function Profiler:dumpString()
	if not self.stats then
		Lib.logError("Profiler:dumpString not self.stats")
		return
	end
	local fmt = tconcat({"%-45s", "%7s", "%13s", "%11s", "%10s", "%13s\n"}, "\t")
	local ret = strfmt(fmt, "Name", "Count", "TotalTime", "AverageTime", "MinTime", "MaxTime")
	local keys = {}
	for name in pairs(self.stats) do
		keys[#keys + 1] = name
	end
	table.sort(keys, function(a, b)
			return self.stats[a].time > self.stats[b].time
	end)
	for _, name in pairs(keys) do
		local stat = self.stats[name]
		local average = fmtTime(stat.count > 0  and stat.time / stat.count or 0)
		ret = ret..strfmt(fmt, name, stat.count, fmtTime(stat.time), average, fmtTime(stat.min), fmtTime(stat.max))
	end
	return ret
end

function Profiler:dumpCSV(fileName)	-- os.date("Profile_%Y%m%d%H%M%S.csv")
	local keys = {}
	for name in pairs(self.stats) do
		keys[#keys + 1] = name
	end
	table.sort(keys)
	local header = { "Name", "Count", "TotalTime", "AverageTime", "MinTime", "MaxTime", "Garbage", "AvgGabage" }
	local list = { csv_encode(header) }
	for _, name in pairs(keys) do
		local stat = self.stats[name]
		local average = stat.count > 0  and stat.time / stat.count or 0
		local avgGarbage = stat.count and stat.garbage / stat.count or 0
		list[#list + 1] = csv_encode({ name, stat.count, stat.time, average, stat.min, stat.max, stat.garbage, avgGarbage })
	end
	return misc.write_utf16(fileName, tconcat(list, "\n"))
end

function Profiler:enableForCpuTimer(flag)
	self._orgBegin = self._orgBegin or self.begin
	self._orgFinish = self._orgFinish or self.finish
	if flag then
		self.begin = function(self, name)
			CPUTimer.StartForLua(name)
		end
		self.finish = CPUTimer.Stop
	else
		self.begin = self._orgBegin
		self.finish = self._orgFinish
	end
	print("Profiler.enableForCpuTimer = "..tostring(flag))
end

-- called by gm, not in world.tick
function Profiler:startCpuStaticsFor(ticks, enableLuaProfiler)
	if World.isClient then
		Lib.emitEvent(Event.EVENT_CLOSE_GMBOARD)
	end
	if enableLuaProfiler then
		Profiler:enableForCpuTimer(true)
	end
	PerformanceStatistics.SetCPUTimerEnabled(true)
	World.Timer(ticks + 1, function()
		-- cannot close in timer (pls close by gm) Profiler:enableForCpuTimer(false)
		PerformanceStatistics.PrintResults(ticks)
	end)
end

function Profiler:init()
	if self.inited then
		Lib.logError("Profiler already inited")
		return
	end
	self.stack = {}
	self.stats = {}
	self.inited = true
	Profiler:enableForCpuTimer(false)
end

function Profiler:reset()
	if not self.inited then
		return
	end
	self.inited = false
	self.stack = {}
	self.stats = {}
end
