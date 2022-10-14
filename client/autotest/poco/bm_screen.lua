local misc = require "misc"
local IScreen = require('autotest.poco.sdk.IScreen')
local b64encode = require('autotest.poco.support.base64')

local screen = {}
screen.__index = screen
setmetatable(screen, IScreen)

-- local director = cc.Director:getInstance()
-- local winSize = director:getWinSize()  -- default win size is the design resolution
-- local frameSize = director:getOpenGLView():getFrameSize()

function screen:getPortSize()
    -- return {frameSize.width, frameSize.height}
    local screenSize = Blockman.instance:getScreenSize()
    return {screenSize.w, screenSize.h}
end

function screen:getScreen(width)
    -- local designRes = winSize
    -- local filename = "screenshot.png"

    -- local screenshotScaleFactor = width / designRes.width
    -- local scene = director:getRunningScene()

    -- -- return a future object
    return function(cb)
        -- cc.utils:captureScreen(function(succeed, outputFile)
        --     if succeed then
        --         print('截图成功：' .. outputFile)
        --         local f = io.open(outputFile, "rb")
        --         if not f then
        --             print('截图文件不存在 2333')
        --         end
        --         local screendata = f:read("*all")
        --         screendata = b64encode(screendata)
        --         cb({screendata, 'png'})
        --         f:close()
        --         print('done!')
        --     else
        --         print('截图失败')
        --     end
        -- end, filename)
		cb({misc.base64_encode(CGame.Instance():captureScreen(80)), 'jpeg'})
    end
end

return screen