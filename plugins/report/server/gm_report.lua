
local path = Root.Instance():getGamePath():gsub("\\", "/") .. "lua/gm_server.lua"
local file, err = io.open(path, "r")
local GMItem
if file then
    GMItem = require("gm_server")
    file:close()
end
if not GMItem then
    GMItem = GM:createGMItem()
end

GMItem["report/打开上报弹窗"] = function(self)
    self:setIsNeedReportDialog(true)
end

GMItem["report/关闭上报弹窗"] = function(self)
    self:setIsNeedReportDialog(false)
end