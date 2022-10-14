local path = Root.Instance():getGamePath():gsub("\\", "/") .. "lua/gm_client.lua"
local file, err = io.open(path, "r")
local GMItem
if file then
    GMItem = require("gm_client")
    file:close()
end
if not GMItem then
    GMItem = GM:createGMItem()
end

GMItem["录像/打开新UI"] = function(self)
    Plugins.CallTargetPluginFunc("new_video", "updateNewVideoShow", true)
end

GMItem["录像/wndName"] = function(self)
    local root = UI.root
    if not root then
        return
    end
    local count = root:getChildCount()
    for index = 0, count - 1 do
        local wnd = root:getChildAtIdx(index)
        local name = wnd:getName()
        print("wnd name", name)
    end
end