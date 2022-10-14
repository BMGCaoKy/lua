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

GMItem["聊天插件/窗体层级向前1级"] = function()
    local chatRt = UI:getWnd("chatMain")._root

    chatRt:SetLevel(chatRt:GetLevel()-1)
    print("the win_chat wnd level is :",chatRt:GetLevel())
end
GMItem["聊天插件/窗体层级向后1级"] = function()
    local chatRt = UI:getWnd("chatMain")._root
    chatRt:SetLevel(chatRt:GetLevel()+1)
    print("the win_chat wnd level is :",chatRt:GetLevel())
end

GMItem["聊天插件/开入口"] = function()
    UI:openWnd("chatBar")
end