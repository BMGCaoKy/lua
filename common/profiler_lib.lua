local strfmt = string.format
local tconcat = table.concat

local profilerGroup = {}

function ProfilerLib.BeginGroup(name, group)
	local group = group or 1
	if not profilerGroup[group] then
		profilerGroup[group] = {}
	end
	profilerGroup[group][name] = true
	Profiler:begin(name)
end

function ProfilerLib.EndGroup(name)
	Profiler:finish(name)
end

function ProfilerLib.Reset()
	Profiler:reset()
	Profiler:init()
	profilerGroup = {}
end

local function fmtTime(time)
	return strfmt("%.6f", time)
end

function ProfilerLib.DumpGroup(group)
	local group = group or 1
	local keys = {}
	local curGroup = profilerGroup[group]
	for name in pairs(Profiler.stats) do
		if curGroup[name] then
			keys[#keys + 1] = name
		end
	end
	table.sort(keys)
	local fmt = tconcat({"%-45s", "%7s", "%13s", "%11s", "%10s", "%13s\n"}, "\t")
	local ret = strfmt(fmt, "Name", "Count", "TotalTime", "AverageTime", "MinTime", "MaxTime")
	for _, name in pairs(keys) do
		local stat = Profiler.stats[name]
		local average = fmtTime(stat.count > 0  and stat.time / stat.count or 0)
		ret = ret..strfmt(fmt, name, stat.count, fmtTime(stat.time), average, fmtTime(stat.min), fmtTime(stat.max))
	end
	print(Lib.v2s(ret))
end