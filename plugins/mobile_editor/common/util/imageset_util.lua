---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by 10184.
--- DateTime: 2022/3/31 16:18
---
---@class ImagesetUtil
local ImagesetUtil = T(MobileEditor, "ImagesetUtil")

function ImagesetUtil:format(group, imageset, name)
    return string.format("gameres|asset/UI/%s/imageset/%s:%s", group, imageset, name)
end