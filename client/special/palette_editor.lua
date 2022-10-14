
local PaletteEditor = L("PaletteEditor", {})
local TinterBoard = {}
local DrawingBoard = {}


local function ColorCompare(left, right)
    return left[1] == right[1] and left[2] == right[2] and left[3] == right[3] and left[4] == right[4] 
end

function PaletteEditor:init(drawWidth, drawHeight, tinterWidth, tinterHeight, updateColorHistory)
    self.config = Lib.readGameJson("palette_config.json")

    self.tinterBoard = TinterBoard
    self.drawingBoard = DrawingBoard
    self.penColor = nil

    self.updateColorHistoryCallBack = updateColorHistory

    self.pencil = {}
    self.curPencilIndex = 0
    self.colorHistory = {}

    for i, v in pairs(self.config.pen) do
        self.pencil[i] = {
            beginColor = {v.minColor[1]/255, v.minColor[2]/255, v.minColor[3]/255, 1.0}, 
            endColor = {v.maxColor[1]/255, v.maxColor[2]/255, v.maxColor[3]/255, 1.0}, 
            defaultColor = {v.defColor[1]/255, v.defColor[2]/255, v.defColor[3]/255, 1.0}
        }
    end

    self.tinterBoard:init(self, tinterWidth, tinterHeight, self.pencil[1])
    self.drawingBoard:init(self, drawWidth, drawHeight, self.config.Sketchpad.rows, self.config.Sketchpad.columns)

    self:selectPencil(1)
end

function PaletteEditor:getPenList()
    return self.config.pen
end

function PaletteEditor:getPencilColor()
    return self.pencilColor
end

function PaletteEditor:selectPencil(index)
    if self.curPencilIndex ~= index then
        self.curPencilIndex = index
        self.tinterBoard:setColorRange(self.pencil[self.curPencilIndex])
        self:setPencilColor(self.pencil[index].defaultColor)
    end
end

function PaletteEditor:setPencilColor(color)
    table.insert(self.colorHistory, 1, color)
    if #self.colorHistory == 5 then
        table.remove(self.colorHistory, 5)
    end
    self.pencilColor = color
    self.drawingBoard:setPencilColor(color)
    if self.updateColorHistoryCallBack ~= nil then
        self.updateColorHistoryCallBack()
    end
end

function PaletteEditor:pickColorFromHistory(color)
    for k, testColor in pairs(self.colorHistory) do
        if ColorCompare(color, testColor) then
            table.remove(self.colorHistory, k)
            self:setPencilColor(color)
            self.curPencilIndex = 0
        end
    end
end

function PaletteEditor:getColorHistory()
    return self.colorHistory
end

function PaletteEditor:getTinterBoard()
    return self.tinterBoard
end

function PaletteEditor:getDrawingBoard()
    return self.drawingBoard
end

function TinterBoard:init(editor, width, height, colorRange)
    self.colorRange = colorRange
    self.width = 0
    self.heigth = 0
    self.editor = editor
    self.colorStep = {}
    self.textureName = "tinter_texture"
    self.texture = FillColorTexture.new(self.textureName, self.width, self.height)
    self:onSize(width, height)
end

function TinterBoard:getTextureName()
    return self.textureName
end

function TinterBoard:setColorRange(colorRange)
    self.colorRange = colorRange
    self.colorStep[1]= (self.colorRange.endColor[1] -self.colorRange.beginColor[1])/self.height;
    self.colorStep[2]= (self.colorRange.endColor[2] -self.colorRange.beginColor[2])/self.height;
    self.colorStep[3]= (self.colorRange.endColor[3] -self.colorRange.beginColor[3])/self.height;
    self:updateTexture()
end 

function TinterBoard:onClick(pos)
    print("tinterboard click .."..pos.y)
    local r = (self.colorRange.beginColor[1] + pos.y*self.colorStep[1])
    local g = (self.colorRange.beginColor[2] + pos.y*self.colorStep[2])
    local b = (self.colorRange.beginColor[3] + pos.y*self.colorStep[3])
    self.editor:setPencilColor({r, g, b, 1.0})
end

function TinterBoard:onSize(width, height)
    if self.width == width and self.height == height then
        return
    end

    self.width = width
    self.height = height
    self.texture:onSize(self.width, self.height)
    self.colorStep[1]= (self.colorRange.endColor[1] -self.colorRange.beginColor[1])/self.height;
    self.colorStep[2]= (self.colorRange.endColor[2] -self.colorRange.beginColor[2])/self.height;
    self.colorStep[3]= (self.colorRange.endColor[3] -self.colorRange.beginColor[3])/self.height;
    self:updateTexture()
end

function TinterBoard:fillColor()
    for y=0, self.height-1 do
        local r = (self.colorRange.beginColor[1] + y*self.colorStep[1])
        local g = (self.colorRange.beginColor[2] + y*self.colorStep[2])
        local b = (self.colorRange.beginColor[3] + y*self.colorStep[3])
        self.texture:updateColor(0, self.width, y, y+1, { r, g, b, 1.0})
    end
end

function TinterBoard:updateTexture()
    self.texture:beginFill()
    self:fillColor()
    self.texture:endFill()
end


local OP_TYPE_DRAW = 0
local OP_TYPE_MOVE = 1
local OP_TYPE_CLEAR = 2

function DrawingBoard:init(editor, width, height, rows, columns)
    self.editor = editor
    self.moveBegin = false
    self.textureName = "drawingboard_texture"
    self.showArea = nil
    self.scale = 1
    self.curOp = {}
    self.opHistory = {}
    self.opIndexInfo = {index = 1, nextOp = 0}
    self.pencilColor = nil
    self.rows = rows
    self.columns = columns
    self.opType = OP_TYPE_DRAW
    self.touchMoveBegin = false

    local lineColor = {editor.config.Sketchpad.lineColor[1]/255, editor.config.Sketchpad.lineColor[2]/255, editor.config.Sketchpad.lineColor[3]/255}
    local bgColor =   {editor.config.Sketchpad.backgroundColor[1]/255, editor.config.Sketchpad.backgroundColor[2]/255, editor.config.Sketchpad.backgroundColor[3]/255}

    self.blockColorTexture = Lib.derive(require 'special.block_color_texture')
    self.blockColorTexture:init(self.textureName, width, height, columns, rows, bgColor, lineColor)

    self.bgColor = bgColor
    self.drawColor = self.bgColor

    self:onSize(width, height)
end

function DrawingBoard:onSize(width, height, callBack)
    if self.width == width and self.height == height then
        return
    end

    local blockWidth = math.floor(width / self.rows)
    local blockHeight = math.floor(height / self.columns)

    local minWidth =  math.min(blockWidth, blockHeight)
    
    self.width = minWidth * self.rows
    self.height = minWidth *self.columns

    self.showArea = {xBegin = 0, xEnd = self.width, yBegin = 0, yEnd = self.height}
    self.scale = 1

    self.blockColorTexture:onSize(self.width, self.height)
    if callBack and (self.width ~= width or self.height ~= height) then 
        callBack(self.width, self.height)
    end
end

function DrawingBoard:getTextureName()
    return self.textureName
end

function DrawingBoard:setInClear()
    self.opType = OP_TYPE_CLEAR
end

function DrawingBoard:setInDraw()
    self.opType = OP_TYPE_DRAW
end

function DrawingBoard:setInMove()
    if self.opType == OP_TYPE_MOVE then 
        self.opType = OP_TYPE_DRAW
    else
        self.opType = OP_TYPE_MOVE 
    end
end

function DrawingBoard:setPencilColor(color)
    self.pencilColor = color
end

function DrawingBoard:onClick(pos)
    self:clearOpHistory()
    self:drawPos(pos)
end

function DrawingBoard:onTouchDown(pos)
    local touchId = TouchManager.Instance():getActiveTouch()

    if self.touchId ~= nil and touchId ~= self.touchId then 
        return 
    end

    self:clearOpHistory()
    self.touchId = touchId
    self.touchDownPos = pos

end

function DrawingBoard:onTouchUp(pos)
    local touchId = TouchManager.Instance():getActiveTouch()

    if self.touchId ~= nil and touchId == self.touchId then 
        self.touchId = nil
        if self.touchMoveBegin == true then 
            if self.opType == OP_TYPE_MOVE then 
                self:doMoveEnd()
            else
                self:drawLineEnd()
            end
            self.touchMoveBegin = false
        else
            if self.touchDownPos ~= nil and self.touchDownPos.x == pos.x and self.touchDownPos.y == pos.y and self.opType ~= OP_TYPE_MOVE then
                self:onClick(pos)
            end
        end
    end
end


function DrawingBoard:onTouchMove(pos)
    local touchId = TouchManager.Instance():getActiveTouch()
    if self.touchId ~= nil and touchId ~= self.touchId then 
        return 
    end

    if self.touchMoveBegin == false then 
        self.touchMoveBegin = true
        if self.opType == OP_TYPE_MOVE then 
            self:doMoveBegin()
        else
            self:drawLineBegin()
        end
    end

    self.touchDownPos = pos
    if self.moveBegin == false then 
        if self.beginLine == true then
            if self.lastDrawPos == nil then 
                self.lastDrawPos = pos
            else
                self:drawLine(self.lastDrawPos, pos)
                self.lastDrawPos = pos
            end
        else
            self:drawPos(pos)
        end
    else
        self:move(pos)
    end
end

function DrawingBoard:drawPos(pos)
    if self.opType == OP_TYPE_CLEAR then 
        self.drawColor = self.bgColor
     else
        self.drawColor = self.pencilColor
     end

    local x = self.showArea.xBegin + (pos.x/self.scale)
    local y = self.showArea.yBegin + (pos.y/self.scale)

    local blockArea = self.blockColorTexture:getBlockArea()
    local w = math.floor(x/blockArea.width) + 1
    local h = math.floor(y/blockArea.height) + 1

    if w >self.rows or h > self.columns or w ==0 or h == 0 then
        return 
    end

    if self.blockColorTexture:getBlockColor(h, w) ~=self.drawColor then
        local opItem = {pos={x=w, y=h}, srcColor = self.blockColorTexture:getBlockColor(h, w), destColor = self.drawColor}
        table.insert(self.curOp, opItem)
        if self.beginLine == false then 
            table.insert(self.opHistory, 1, self.curOp)
            self.curOp = {}
        end
        self.blockColorTexture:updateBlockColor(w, h, self.drawColor)
    end
end

function DrawingBoard:drawLine(lineBegin, lineEnd)

    local xLen = math.abs(lineEnd.x - lineBegin.x)
    local yLen = math.abs(lineEnd.y - lineBegin.y)

    if xLen == 0 and yLen == 0 then 
        return
    end

    local xDirect = 1
    if lineEnd.x < lineBegin.x then 
        xDirect = -1
    end

    local yDirect = 1
    if lineEnd.y < lineBegin.y then 
        yDirect = -1
    end

    if xLen > yLen then 
        for i=0, xLen do
            local j = (i/xLen)*yLen
            self:drawPos({x=lineBegin.x + (xDirect*i), y= lineBegin.y + (j*yDirect)})
        end
    else 
        for i=0, yLen do
            local j = (i/yLen)*xLen
            self:drawPos({x= lineBegin.x + ( j * xDirect), y = lineBegin.y + (i*yDirect)})
        end
    end
end


function DrawingBoard:enlarge()
    if self.scale > 8 then
        return
    end

    self.scale = self.scale * 2

    local wFactor = self.scale
    local hFactor = self.scale

    local showWidth = self.showArea.xEnd - self.showArea.xBegin

    local xBegin = self.showArea.xBegin + (showWidth/4)
    local xEnd = self.showArea.xEnd - (showWidth/4)

    local showHeight = self.showArea.yEnd - self.showArea.yBegin

    local yBegin = self.showArea.yBegin  + (showHeight/4)
    local yEnd = self.showArea.yEnd  - (showHeight/4)

    self.showArea = {xBegin = xBegin, xEnd = xEnd, yBegin = yBegin, yEnd = yEnd}
end

function DrawingBoard:shrink()
    if self.scale == 1 then 
        return 
    end

    self.scale = self.scale/2

    local showWidth = (self.showArea.xEnd - self.showArea.xBegin)

    local xBegin = self.showArea.xBegin - (showWidth/2)
    local xEnd = self.showArea.xEnd + (showWidth/2)
    if xBegin <=0 then 
        xBegin = 0
        xEnd = xBegin + showWidth*2
    elseif xEnd >= self.width then 
        xEnd = self.width
        xBegin = xEnd - showWidth*2
    end
  

    local showHeight = self.showArea.yEnd - self.showArea.yBegin

    local yBegin = self.showArea.yBegin  - (showHeight/2)
    local yEnd = self.showArea.yEnd  + (showHeight/2)
    if yBegin <=0 then 
        yBegin = 0
        yEnd = yBegin + showHeight*2
    elseif yEnd >= self.height then 
        yEnd = self.height
        yBegin = self.height - showHeight*2
    end


    self.showArea = {xBegin = xBegin, xEnd = xEnd, yBegin = yBegin, yEnd = yEnd}
end

function DrawingBoard:move(pos)
    if self.scale <= 1 then 
        return 
    end

    if self.lastMovePos == nil then
        self.lastMovePos = pos
        return
    end

    local vFactor = ((pos.x - self.lastMovePos.x)/(self.scale * 1))
    local hFactor = ((pos.y - self.lastMovePos.y)/(self.scale * 1))

    local showWidth = self.showArea.xEnd - self.showArea.xBegin

    if vFactor > 0 then 
        self.showArea.xBegin = self.showArea.xBegin - vFactor
        if self.showArea.xBegin < 0 then 
            self.showArea.xBegin = 0 
        end
        self.showArea.xEnd = self.showArea.xBegin + showWidth
    else
        self.showArea.xEnd = self.showArea.xEnd - vFactor
        if self.showArea.xEnd > self.width then 
            self.showArea.xEnd = self.width
        end
        self.showArea.xBegin = self.showArea.xEnd - showWidth
    end

    local showHeight = self.showArea.yEnd - self.showArea.yBegin
    if hFactor > 0 then 
        self.showArea.yBegin = self.showArea.yBegin - hFactor
        if self.showArea.yBegin < 0 then 
            self.showArea.yBegin = 0 
        end
        self.showArea.yEnd = self.showArea.yBegin + showHeight
    else
        self.showArea.yEnd = self.showArea.yEnd - hFactor
        if self.showArea.yEnd > self.height then 
            self.showArea.yEnd = self.height
        end
        self.showArea.yBegin = self.showArea.yEnd - showHeight
    end
    self.lastMovePos = pos
    self.showAreaChanged = true
end

function DrawingBoard:isShowAreaChanged()
    return self.showAreaChanged or false
end

function DrawingBoard:getShowArea()
    self.showAreaChanged = false
    return {self.showArea.xBegin/self.width, self.showArea.yBegin/self.height, self.showArea.xEnd/self.width, self.showArea.yEnd/self.height}
end

function DrawingBoard:doMoveBegin()
    if self.moveBegin == false then
        self.moveBegin = true
        self.lastMovePos = nil
    end
end

function DrawingBoard:doMoveEnd()
    self.moveBegin = false
    self.lastMovePos = nil
end

function DrawingBoard:drawLineBegin()
    self.beginLine = true
    self.lastDrawPos = self.touchDownPos
    self.curOp = {}
    self:clearOpHistory()
end

function DrawingBoard:drawLineEnd()
    self.beginLine = false
    if #self.curOp ~= 0 then
        table.insert(self.opHistory, 1, self.curOp)
        self.curOp = {}
    end
end

function DrawingBoard:redo()
    if self.opIndexInfo.nextOp == 0 then
        self.opIndexInfo.index = self.opIndexInfo.index - 1
        if self.opIndexInfo.index == 0  then 
            self.opIndexInfo.index = 1
            return 
        end
    end
    self.isOp = true
    local opItems = self.opHistory[self.opIndexInfo.index]
    for _, v in pairs(opItems) do
        local curColor = self.drawColor
        self.drawColor = v.destColor
        self.blockColorTexture:updateBlockColor(v.pos.x, v.pos.y, self.drawColor)
        self.drawColor = curColor
        self.opIndexInfo.nextOp = 0
    end
end

function DrawingBoard:clearOpHistory()
    if not self.isOp then
        return
    end
    self.opIndexInfo = {index = 1, nextOp = 0}
    self.opHistory = {}
    self.isOp = false
end

function DrawingBoard:undo()
    if self.opIndexInfo.nextOp == 1 then
        self.opIndexInfo.index = self.opIndexInfo.index + 1
        if self.opIndexInfo.index > #self.opHistory then 
            self.opIndexInfo.index = self.opIndexInfo.index - 1
            return
        end
    end
    self.isOp = true
    if self.opIndexInfo.index <= #self.opHistory then 
        local opItems = self.opHistory[self.opIndexInfo.index]
        for _, v in pairs(opItems) do
            local curColor = self.drawColor
            self.drawColor = v.srcColor
            self.blockColorTexture:updateBlockColor(v.pos.x, v.pos.y, self.drawColor)
            self.drawColor = curColor
            self.opIndexInfo.nextOp = 1
        end
    end
end

function DrawingBoard:resetScale()
    while(self.scale > 1) do
        self:shrink()
    end
    self.scale = 1
end

function DrawingBoard:clean()
    self:resetScale()
    self.curOp = {}
    self.opHistory = {}
    self:setInDraw()
    self.opIndexInfo = {index = 1, nextOp = 0}
    self.blockColorTexture:clean()
end

function DrawingBoard:saveColorInfoToFile(filePath)
    self.blockColorTexture:saveColorInfo(filePath)
end

function DrawingBoard:getBlockTexture()
    return self.blockColorTexture
end

function DrawingBoard:replaceTexture(texture)
    self.blockColorTexture:updateAllColorInfo(texture:getAllColorInfo())
end

function DrawingBoard:toPng(path)
    return self.blockColorTexture:toPng(path)
end

RETURN(PaletteEditor)