
local blockTextureNameIndex = 1
local BlockColorTexture = {}
local function ColorCompare(left, right)
    return left and right and left[1] == right[1] and left[2] == right[2] and left[3] == right[3] and left[4] == right[4]
end

local function stripFileName(filename)
    local fn_flag = string.find(filename, "\\")
    local dest_filename = nil
    if fn_flag then
        dest_filename = string.match(filename, ".+\\([^\\]*%.%w+)$")
    end

    fn_flag = string.find(filename, "/")
    if fn_flag then
        dest_filename = string.match(filename, ".+/([^/]*%.%w+)$")
    end
    return dest_filename
end

function BlockColorTexture:initFromWin(url)
    local paletteConfig = Lib.readGameJson("palette_config.json").Sketchpad

    local lineColor = nil
    if paletteConfig.showLineColor ~= nil then
        lineColor = {paletteConfig.showLineColor[1]/255, paletteConfig.showLineColor[2]/255, paletteConfig.showLineColor[3]/255}
    end

    local bgColor =   {paletteConfig.backgroundColor[1]/255, paletteConfig.backgroundColor[2]/255, paletteConfig.backgroundColor[3]/255}
    local name = stripFileName(url);
    self:init(name, paletteConfig.rows * 10, paletteConfig.columns * 10, paletteConfig.columns, paletteConfig.rows, bgColor, lineColor)
end

function BlockColorTexture:getTextureName()
    return self.name
end

function BlockColorTexture:init(name, width, height, columns, rows, bgColor, lineColor)
    if name == nil  then 
        name = "block_color_texture_"..blockTextureNameIndex
        blockTextureNameIndex = blockTextureNameIndex + 1
    end

    print("create new blockcolor texture "..name)

    self.asyncLoadColor = false
    self.name = name
    self.drawLine = false
    if lineColor then
        self.drawLine = true
    end
    self.refs = 0
    self.hide = false
    self.width = 0
    self.height = 0
    self.columns = columns
    self.rows = rows
    self.bgColor = bgColor
    self.lineColor = lineColor
    self.blockColorInfo = {}
    for h=1, self.columns do
        self.blockColorInfo[h] = {}
        for w=1, self.rows do
         self.blockColorInfo[h][w] = self.bgColor
        end
    end

    self.texture = FillColorTexture.new(self.name, self.width, self.height)
    self:onSize(width, height)
end

function BlockColorTexture:onSize(width, height)
    if width == 0 or height == 0 then 
        return
    end

    if self.width == width and self.height == height then
        return
    end

    self.width = width
    self.height = height
    self.texture:onSize(self.width, self.height)
    self.blockWidth = math.floor(width / self.rows)
    self.blockHeight = math.floor(height / self.columns)
    self:updateTexture()
end

function BlockColorTexture:show()
    print("show texture "..self.refs)
    self.refs = self.refs + 1
    if self.hide == true then 
        self.texture:create()
        if self.asyncLoadColor == false then
            self:updateTexture()
        end
        self.hide = false
    end
end

function BlockColorTexture:close()
    print("close texture "..self.refs)
    if self.refs > 0 then 
        self.refs = self.refs - 1
    end

    if self.refs < 0 or self.refs == 0 and self.hide == false then
        self.texture:release()
        self.hide = true
    end
end


function BlockColorTexture:loadColorInfoFromUrl(url)
    if url == nil then 
        return 
    end

    self.retryLoadCount = 0;
    self.colorInfoUrl = url;

    local cacheName = stripFileName(url);

    local tempPath = Root.Instance():getWriteablePath() .. cacheName
    self.cacheColorPath = tempPath
    self:loadColorInfoFromFile(tempPath)
end

function BlockColorTexture:downloadColorInfo()
    AsyncProcess.DownloadFile(self.colorInfoUrl, self.cacheColorPath, function (response)
        self.retryLoadCount = self.retryLoadCount + 1
        if response.code == 1 then 
            self:loadColorInfoFromFile(self.cacheColorPath)
        end
    end)
end

function BlockColorTexture:loadColorInfoFromFile(filePath)
    self.asyncLoadColor = true
    self.texture:decode(filePath, self.bgColor)
    World.Timer(20, self.checkLoadColorInfoResult, self)
end

function BlockColorTexture:checkLoadColorInfoResult()
    if self.texture.hasDecodeColorInfo(self:getTextureName()) then 
        local decodeResult = self.texture.getDecodeColorInfo(self:getTextureName())
        self.texture.clearColorInfo(self:getTextureName())
        if #decodeResult == 0 and self.retryLoadCount < 3 then 
            self:downloadColorInfo()
        else
            if #decodeResult ~= 0 then 
                self.blockColorInfo = decodeResult
            end

            self.asyncLoadColor = false
            if self.rows ~= #self.blockColorInfo[1] or self.columns ~= #self.blockColorInfo then
                self.rows = #self.blockColorInfo[1]
                self.columns = #self.blockColorInfo
                local width = self.rows * 10
                local height = self.columns * 10
                self:onSize(width, height)
                if self.hide == true then 
                    self.texture:release()
                end
            elseif self.hide == false then
                self:updateTexture()
            end
        end
    else
        World.Timer(20, self.checkLoadColorInfoResult, self)
    end
end


function BlockColorTexture:saveColorInfo(dir)
    local savePath = dir .. "\\" ..self.name
    self.texture:encode(savePath, self.blockColorInfo)
    return savePath
end

function BlockColorTexture:getBlockArea()
    return {width = self.blockWidth, height = self.blockHeight}
end

function BlockColorTexture:getBlockColor(h, w)
    return self.blockColorInfo[h][w]
end

function BlockColorTexture:fillColor()
    -- background
    self.texture:fillAll(self.bgColor)

    if self.drawLine == true then 
        for x=0, self.rows-1 do
            self.texture:updateColor(x*self.blockWidth, x*self.blockWidth + 1, 0, self.height, self.lineColor)
        end

        for y=0, self.columns-1 do
            self.texture:updateColor(0, self.width, y*self.blockHeight, y*self.blockHeight+1, self.lineColor)
        end
    end

    for h=0, self.columns-1 do
        for w=0, self.rows-1 do
            local color = self.blockColorInfo[h+1][w+1]
            if ColorCompare(color, self.bgColor) == false then
                if self.drawLine == true then
                    self.texture:updateColor(w*self.blockWidth+1, (w+1)*self.blockWidth, (h)*self.blockHeight+1, (h+1)*self.blockHeight, color)
                else
                    self.texture:updateColor(w*self.blockWidth , (w+1)*self.blockWidth, (h)*self.blockHeight , (h+1)*self.blockHeight, color)
                end

            end
        end
    end
end

function BlockColorTexture:updateTexture()
    self.texture:beginFill()
    self:fillColor()
    self.texture:endFill()
end

function BlockColorTexture:updateBlockColor(w, h, color)
    self.blockColorInfo[h][w] = color
    local pxBegin = (w-1)*self.blockWidth+1
    local pxEnd = pxBegin + self.blockWidth-1
    local pyBegin = (h-1)*self.blockHeight+1
    local pyEnd = pyBegin + self.blockHeight-1
    self.texture:updateColor(pxBegin, pxEnd, pyBegin, pyEnd, self.blockColorInfo[h][w])
end


function BlockColorTexture:saveColorInfo(filePath)
    self.texture:encode(self.blockColorInfo, self.bgColor, filePath)
end

function BlockColorTexture:isEmpty()
    for h = 1, self.columns do
        for w = 1, self.rows do
            if self.blockColorInfo[h][w] ~= self.bgColor then
                return false
            end
        end
    end

    return true
end

function BlockColorTexture:updateAllColorInfo(colorInfo)
    self.blockColorInfo = colorInfo
    if self.hide == false then 
        self:updateTexture()
    end
end

function BlockColorTexture:getAllColorInfo()
    return self.blockColorInfo
end

function BlockColorTexture:clean()
    self.texture:beginFill()
    self.texture:fillAll(self.bgColor)

    if self.drawLine == true then 
        for x=0, self.rows-1 do
            self.texture:updateColor(x*self.blockWidth, x*self.blockWidth + 1, 0, self.height, self.lineColor)
        end

        for y=0, self.columns-1 do
            self.texture:updateColor(0, self.width, y*self.blockHeight, y*self.blockHeight+1, self.lineColor)
        end
    end

    for h=0, self.columns-1 do
        for w=0, self.rows-1 do
            self.blockColorInfo[h+1][w+1] = self.bgColor
        end
    end
    self.texture:endFill()
end

function BlockColorTexture:toPng(path)
    return self.texture:toPng(self.blockColorInfo, path)
end

return BlockColorTexture