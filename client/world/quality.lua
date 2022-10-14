local M = L("M", {})
local gameQualityCfg = World.cfg.gameQuality
local reportFPSInterval = World.cfg.reportFPSInterval
local interval = gameQualityCfg and gameQualityCfg.interval and gameQualityCfg.interval > 0 and gameQualityCfg.interval or 20
local calcTick = L("calcTick", 0)
local nextReportFPSTick = L("nextReportFPSTick", 0)

function M.Tick()
	M:CheckQuality()
	M:ReportFPS()
	M:tryReportFPS()
	M:TryPerformanceReport()
end

function M:CheckQuality()
	if World.Now() % interval ~= 0 or not gameQualityCfg then 
		return
	end
	local nQualiyLv = tostring(math.modf(Clientsetting.getGameQualityLeve()))
	local info = gameQualityCfg[nQualiyLv]
	if not info then 
		return
	end

	local fps = Root.Instance():getFPS()
	local bReset = true
	for i = 1, #info.arr do 
		if fps < info.arr[i][1] then 
			calcTick = calcTick + interval
			bReset = false
			if calcTick >= info.time then 
				Lib.emitEvent(Event.EVENT_TOOLBAR_TO_SETTING_QUALITY, info.arr[i][2])
				calcTick = 0

				Lib.emitEvent(Event.EVENT_CENTER_TIPS, 40, nil, nil, { gameQualityCfg[nQualiyLv].hint })
			end
			break
		end
	end

	if bReset and calcTick > 0 then 
		calcTick = 0
	end
end

local TotalFPS = 0
local GetFPSTimes = 0
local FirstCanReport = false
local LastReportFPSTime = os.time()

local FPSRange = {
	{ key = "0_4", value = 4 },
	{ key = "5_9", value = 9 },
	{ key = "10_14", value = 14 },
	{ key = "14_19", value = 19 },
	{ key = "20_24", value = 24 },
	{ key = "25_29", value = 29 },
	{ key = "30_44", value = 44 },
	{ key = "45_59", value = 59 },
	{ key = "60_max", value = 9999999 },
}

local function getFPSRange(fps)
	for _, range in pairs(FPSRange) do
		if fps <= range.value then
			return range.key
		end
	end
	return FPSRange[#FPSRange].key
end

function M:tryReportFPS()
	if os.time() - LastReportFPSTime < 60 or GetFPSTimes == 0 or TotalFPS == 0 then
		local curFps = CGame.Instance():getCurFps()
		if curFps > 0 then
			TotalFPS = TotalFPS + CGame.Instance():getCurFps()
			GetFPSTimes = GetFPSTimes + 1
		end
		return
	end
	LastReportFPSTime = os.time()
	if not FirstCanReport then
		FirstCanReport = true
		TotalFPS = 0
		GetFPSTimes = 0
		return
	end

	local fps = math.floor((TotalFPS / GetFPSTimes) + 0.5)
	local jankNum = math.floor(PerformanceStatistics.GetJankCount() or 0)
	if fps and type(fps) == "number" and fps ~= math.huge then
		local reportData = {
			fps = fps,
			minute_jank = jankNum
		}
		if World.cfg.reportSetting and World.cfg.reportSetting.useGameFpsReport then
			Plugins.CallTargetPluginFunc("report", "report", "engine_fps", reportData)
		else
			GameAnalytics.NewDesign("engine_fps", reportData)
		end
	end

	TotalFPS = 0
	GetFPSTimes = 0

end

function M:ReportFPS()
	if not reportFPSInterval or reportFPSInterval <= 0 or World.Now() < nextReportFPSTick then 
		return 
	end
	nextReportFPSTick = World.Now() + reportFPSInterval

    Me:sendPacket({
        pid = "ReportFPS",
        fps = Root.Instance():getFPS()
    })
end

local LastReportPerformanceTime = os.time()

function M:TryPerformanceReport()
	if os.time() - LastReportPerformanceTime < 60 then
		return
	end
	self:PerformanceReport()
end


function M:PerformanceReport()

	if not Me or not next(Me) then return end

	local fpsInfo = PerformanceStatistics.GetFpsInfo() or {}
	local netPingInfo = PerformanceStatistics.GetNetPingInfo() or {}
	local logicPingInfo = PerformanceStatistics.GetLogicPingInfo() or {}

	if not next(fpsInfo) and not next(netPingInfo) and not next(logicPingInfo) then return end
	Me:sendPacket({
		pid = "PerformanceReport",
		fps = fpsInfo,
		netPing = netPingInfo,
		logicPing = logicPingInfo
	})

	LastReportPerformanceTime = os.time()
end

RETURN(M)