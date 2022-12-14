---
--- Generated by PluginCreator
--- camera_movie gm
--- DateTime:2021-08-27
---

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

GMItem["飘字/entity上"] = function(self)
    Plugins.CallTargetPluginFunc("fly_text", "onShowWorldFlyText", self, "white", "200", 1)
end

GMItem["飘字/ui上"] = function(self)
    Plugins.CallTargetPluginFunc("fly_text", "onShowUIFlyText", self, "red", "200", 1)
end