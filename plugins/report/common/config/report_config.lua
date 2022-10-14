local ReportConfig = T(Config, "ReportConfig")
local GameReport = T(Game, "Report")

function ReportConfig:init()
    local eventConfig = Lib.read_csv_file(Root.Instance():getGamePath() .. "config/report.csv", 2)
    local keyConfig = Lib.read_csv_file(Root.Instance():getGamePath() .. "config/reportKeyFuncConvert.csv", 2)
    GameReport:loadConfig(eventConfig, keyConfig)
end

ReportConfig:init()
return ReportConfig

