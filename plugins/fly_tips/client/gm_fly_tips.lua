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

GMItem["tips队列/添加普通1"] = function()
    local content = "{}" .. os.time()
    Plugins.CallTargetPluginFunc("fly_tips", "pushNormalFlyTipsItem", content)
end

GMItem["tips队列/添加普通2"] = function()
    local itemInfo = {}
    itemInfo.type = 1
    itemInfo.content = os.time()
    Plugins.CallTargetPluginFunc("fly_tips", "pushOneFlyTipsItem", itemInfo)
end

GMItem["tips队列/添加物品"] = function()
    local itemInfo = {}
    itemInfo.type = 2
    itemInfo.content1 = "获得"
    itemInfo.content2 = os.time()
    itemInfo.content3 = "x" .. math.random(1, 100)
    itemInfo.iconRes = "set:email_system.json image:btn_9_tab"
    Plugins.CallTargetPluginFunc("fly_tips", "pushOneFlyTipsItem", itemInfo)
end

GMItem["tips队列/图片文字"] = function()
    --"set:g2043_punk_player_info.json image:img_0_exp01"
    local itemInfo = {
        type = 2,
        -- 按照contentData的key排列，填多少个显示多少个
        --  最多支持4个Define.FlyTipsContentType.Text 2个Define.FlyTipsContentType.Image
        contentData = {
            {
                contentType = Define.FlyTipsContentType.Text,       -- 必填参数
                contentInfo = "测试文本1",                             -- 必传参数
                contentColor = "ac1235",           -- 可不填
                contentFont = "HT20",                               -- 可不填
            },
            {
                contentType = Define.FlyTipsContentType.Image,                              -- 必填参数
                contentInfo = "set:g2043_punk_player_info.json image:img_0_exp01",       -- 必填参数
            },
            {
                contentType = Define.FlyTipsContentType.Text,       -- 必填参数
                contentInfo = "测试文本2",                             -- 必传参数
                contentColor = "ffff35",           -- 可不填
                contentFont = "HT20",                               -- 可不填
            }
        }
    }
    Plugins.CallTargetPluginFunc("fly_tips", "pushOneNewFlyTipsItem", itemInfo)
end