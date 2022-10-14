local editorViewControl = L("editorViewControl", Lib.derive(EditorModule.baseDerive))
local backViewFunc = nil
local bm = Blockman.instance
local engine = require "editor.engine"
local data_state = require "editor.dataState"
local state = require "editor.state"
local def = require "editor.def"

function editorViewControl:changeViewCfg(viewIndex, viewCfg)
    if not viewCfg or type(viewCfg) ~= "table" then
        self.error("changeViewCfg")
    end


    local cameraInfo = bm:getCameraInfo(viewIndex)
	if viewCfg then
		bm:changeCameraCfg(viewCfg, viewIndex)
	end

	backViewFunc = function()
		bm:changeCameraCfg(cameraInfo.viewCfg, viewIndex)
        bm:setPersonView(cameraInfo.curInfo.curPersonView)
        backViewFunc = nil
	end
end

function editorViewControl:restore()
    if backViewFunc then
        backViewFunc()
    end
end

function editorViewControl:fixedBodyView(lock)
	local personView = bm:getCurrPersonView()
    self:changeViewCfg(personView, {
        lockBodyRotation = lock
    })
end

function editorViewControl:setChunkSize(pos1, pos2)
    self.chunkMin = pos1 and Lib.copy(pos1)
    self.chunkMax = pos2 and Lib.copy(pos2)
end

function editorViewControl:upChunkSize()
    local min = {
        x = math.min(self.chunkMin.x, self.chunkMax.x),
        y = math.min(self.chunkMin.y, self.chunkMax.y),
        z = math.min(self.chunkMin.z, self.chunkMax.z)
    }
    local max = {
        x = math.max(self.chunkMin.x, self.chunkMax.x) + 1,
        y = math.max(self.chunkMin.y, self.chunkMax.y) + 1,
        z = math.max(self.chunkMin.z, self.chunkMax.z) + 1
    }
    local scope = {
        x = max.x - min.x,
        y = max.y - min.y,
        z = max.z - min.z
    }
    self:setBoundSize(scope, self.chunkMax, self.chunkMin)
end

function editorViewControl:setBoundSize(boundSize, pos1, pos2)
    local boundMaxSize = math.max(boundSize.x * 1.4, boundSize.y * 1.8, boundSize.z * 1.4) 
    self.boundMaxSize = boundMaxSize
    if pos1 and pos2 then
        self.boundSize = {
            x = pos2.x - pos1.x + 1, 
            z = pos2.z - pos1.z + 1, 
            y = pos2.y - pos1.y + 1, 
        }
    else
        self.boundSize = {
            x = 0, 
            z = 0, 
            y = 0, 
        }
		self.boundMaxSize = 0
    end
end

local function updateViewPosLock(self, lockViewPos)
	if  self.lockViewPos == nil or self.lockViewPos ~= lockViewPos then
		self.lockViewPos  = lockViewPos 
		for i = 0, 4 do
			self:changeViewCfg(i, {
				lockViewPos = lockViewPos	
			})
		end
		return true
	end
	return false
end

local function shouldMoveView(self)
    if state:brush_class() == def.TFRAME_POS and data_state.frame_pos_count == 1 then
        return true
    end
    if state:brush_class() == def.TCHUNK and data_state.is_can_move then
        return true
    end

    return false
end

function editorViewControl:tick()
    if not self.boundSize then
        self:setBoundSize({x = 0, y = 0, z = 0})
    end
    local player = Player.CurPlayer
    if not player or not player:isValid() then
        return
    end
    local lockViewPos = shouldMoveView(self)
    local fristFlag = updateViewPosLock(self, lockViewPos)
	if not lockViewPos  then
        player:changeCameraView(player:getRenderEyePos(0))
		return
	end
    local box = player:getBoundingBox()
    local abs = math.abs
    local offset = {
        x = -self.boundSize.x / 2,
        z = -self.boundSize.z / 2,
        y = -self.boundSize.y / 2,
    }
    local maxSize = math.max(self.boundMaxSize, abs(box[2].x - box[3].x), abs(box[2].y - box[3].y) * 2, abs(box[2].z -box[3].z))
    local distance = maxSize / 1.5 + 3
    local pos = player:getRenderEyePos(0)
    pos.y = pos.y +  abs(box[2].y - box[3].y) / 2
    pos.x = pos.x + offset.x
    pos.z = pos.z + offset.z
    pos.y = pos.y + offset.y
    if not self.distance or self.distance ~= distance then
        self.distance = distance
    end
    if (Lib.tov3(bm:viewerRenderPos()) - Lib.tov3(pos)):len() > 5 then
        player:changeCameraView(pos, nil, nil, distance, 1)
    else
        player:changeCameraView(pos, nil, nil, distance, fristFlag and 1 or 8)
    end
end
RETURN(editorViewControl)
