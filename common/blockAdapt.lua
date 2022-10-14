local Lib_tov3 = Lib.tov3

local BlockAdapt = L("BlockAdapt", {})

------------------------------------------------------- logic util func
--[[
    右手坐标系， x+ 为东， z- 为北
    面向 yawDir
	x+
	↑
		 \  0  /
	      \   /  1
	   3  /   \  
		 /  2  \
	O				→z+
]]
local function getPosByDir(sPos, yawDir)
    local tPos = {x = 0, y = 0, z = 0}
    tPos.y = sPos.y
    if yawDir == 3 then
        tPos.x = sPos.x
        tPos.z = sPos.z - 1
    elseif yawDir == 0 then
        tPos.x = sPos.x + 1
        tPos.z = sPos.z
    elseif yawDir == 1 then
        tPos.x = sPos.x
        tPos.z = sPos.z + 1
    elseif yawDir == 2 then
        tPos.x = sPos.x - 1
        tPos.z = sPos.z
    end
    return tPos
end

function BlockAdapt.SetBlockConfigIdAdapt(params)
    local map, pos, tId, fromYaw, hitSideNormal, isUp =
        params.map, params.pos, params.tId, params.fromYaw, params.hitSideNormal, params.isUp
    local s_cfg = map:getBlock(pos)
    local t_cfg = Block.GetIdCfg(tId)
    local needFenceAdapt = (tId == 0 and (s_cfg.isFence or s_cfg.canConnectionFence)) or t_cfg.isFence or t_cfg.canConnectionFence
    local needStairAdapt = (tId == 0 and s_cfg.isStair) or t_cfg.isStair
    if needFenceAdapt then
        BlockAdapt.fenceAdapt(map, pos, tId, true)
    end
    if needStairAdapt then
        BlockAdapt.StairAdapt({
            map = map, pos = pos, tId = tId, fromYaw = fromYaw, 
            hitSideNormal = hitSideNormal, isUp = isUp, referAround = true
            }) 
    end
    if not needFenceAdapt and not needStairAdapt then
        return map:setBlockConfigId(pos, tId)
    end
    return true
end
-- **************************************************** 

-- ===================== fence
------------------------------------------------------- 
--[[
    fence block must has prop: 
        base_fence_id : fence default block id
        isFence ：..
    other block can has prop:
        canConnectionFence ：if has this prop, then this block can refer fence block
]]
--[[
    ↑+                                  ↑+  逻辑增量
            0                                   1
            |                                   |
    ----3---o---1----                   ----8---o---2----
            |                                   |
            2                                   4
    O               →+                  O               →+
]]
--[[ 渲染id增量
    栅栏_单独               x
    栅栏_单方向_北          x + 1
    栅栏_单方向_东          x + 2
    栅栏_双方向_东北        x + 3
    栅栏_单方向_南          x + 4
    栅栏_双方向_北南        x + 5
    栅栏_双方向_东南        x + 6
    栅栏_三方向_北东南      x + 7
    栅栏_单方向_西          x + 8
    栅栏_双方向_西北        x + 9
    栅栏_双方向_东西        x + 10
    栅栏_三方向_西北东      x + 11
    栅栏_双方向_西南        x + 12
    栅栏_三方向_南西北      x + 13
    栅栏_三方向_东南西      x + 14
    栅栏_四方向_北东南西    x + 15
]]
local function getAroundFenceBlockState(map, pos)
    local imc = 0
    local referAroundPosTb = {}
    for yawDir = 0, 3 do
        local tPos = getPosByDir(pos, yawDir)
        local cfg = map:getBlock(tPos)
        if cfg and cfg.blockId ~= 0 and (cfg.canConnectionFence or cfg.isFence) then
            imc = imc + (2 ^ yawDir)
            referAroundPosTb[#referAroundPosTb + 1] = tPos
        end
    end
    return imc, referAroundPosTb
end
------------------------------------------------------- 
--[[
栅栏(fence) size = 16 (初始1 单4 两两邻近组合4 两两对角组合2 三角邻近组合4 四角组合1)
	注：传入的方块id  tId  为fence的初始的那个方块的id  /  空气方块
	注：初始方块和该方块所有变化后的方块的id必须保持连续！保持顺序！并且长度是固定的，不能多不能少
    
    注：放/拆栅栏的时候会影响周围的栅栏，周围的栅栏/能连接栅栏的方块会影响放进去的栅栏
]]
function BlockAdapt.fenceAdapt(map, pos, tId, referAround)
    local imc, referAroundPosTb = getAroundFenceBlockState(map, pos)
    map:setBlockConfigId(pos, Block.GetIdCfg(tId).isFence and (imc + tId) or tId)
    if not referAround then
        return
    end
    for _, referPos in pairs(referAroundPosTb) do
        local cfg = map:getBlock(referPos)
        local base_fence_id = cfg.base_fence_id
        if cfg.isFence and base_fence_id and base_fence_id > 0 then
            BlockAdapt.fenceAdapt(map, referPos, base_fence_id, false)
        end
    end
end
-- **************************************************** 


-- ===================== stair
--[[
    stair block must has prop: 
        base_stair_id : stair default block id
        isStair ：..
]]
--[[
    ↑+                                  ↑+  逻辑增量
    -------------                       -------------
    |     |     |                       |     |     |
    |  0  |  1  |                       |  1  |  2  |
    ------o------                       ------o------
    |  3  |  2  |                       |  8  |  4  |
    |     |     |                       |     |     |
    -------------                       -------------
    O               →+                  O               →+
]]
--[[ 渲染id增量
    注：内角是3块，外角是1块的 !!!
    楼梯_base               x
    楼梯_北_下              x+1 -- > 0 1 
    楼梯_东北内角_下        x+2 -- > 0 1 2
    楼梯_东北外角_下        x+3 -- > 1
    楼梯_东_下              x+4 -- > 1 2
    楼梯_东南内角_下        x+5 -- > 1 2 3
    楼梯_东南外角_下        x+6 -- > 2
    楼梯_南_下              x+7 -- > 2 3
    楼梯_西南内角_下        x+8 -- > 0 2 3
    楼梯_西南外角_下        x+9 -- > 3
    楼梯_西_下              x+10 -- > 0 3
    楼梯_西北内角_下        x+11 -- > 0 1 3
    楼梯_西北外角_下        x+12 -- > 0

    楼梯_北_上              x+13 -- > 0 1 
    楼梯_东北内角_上        x+14 -- > 0 1 2
    楼梯_东北外角_上        x+15 -- > 1
    楼梯_东_上              x+16 -- > 1 2
    楼梯_东南内角_上        x+17 -- > 1 2 3
    楼梯_东南外角_上        x+18 -- > 2
    楼梯_南_上              x+19 -- > 2 3
    楼梯_西南内角_上        x+20 -- > 0 2 3
    楼梯_西南外角_上        x+21 -- > 3
    楼梯_西_上              x+22 -- > 0 3
    楼梯_西北内角_上        x+23 -- > 0 1 3
    楼梯_西北外角_上        x+24 -- > 0
                    适应地图转换工具排序 ↓ 的顺序                   
    楼梯_base               x
    楼梯_北_下              x+1 -- > 0 1 
    楼梯_东_下              x+2 -- > 1 2
    楼梯_南_下              x+3 -- > 2 3
    楼梯_西_下              x+4 -- > 0 3
    楼梯_东北内角_下        x+5 -- > 0 1 2
    楼梯_东南内角_下        x+6 -- > 1 2 3
    楼梯_西南内角_下        x+7 -- > 0 2 3
    楼梯_西北内角_下        x+8 -- > 0 1 3
    楼梯_西北外角_下        x+9 -- > 0
    楼梯_东北外角_下        x+10 -- > 1
    楼梯_东南外角_下        x+11 -- > 2
    楼梯_西南外角_下        x+12 -- > 3
    
    楼梯_北_上              x+13 -- > 0 1 
    楼梯_东_上              x+14 -- > 1 2
    楼梯_南_上              x+15 -- > 2 3
    楼梯_西_上              x+16 -- > 0 3
    楼梯_西北内角_上        x+17 -- > 0 1 3
    楼梯_东北内角_上        x+18 -- > 0 1 2
    楼梯_东南内角_上        x+19 -- > 1 2 3
    楼梯_西南内角_上        x+20 -- > 0 2 3
    楼梯_东北外角_上        x+21 -- > 1
    楼梯_东南外角_上        x+22 -- > 2
    楼梯_西南外角_上        x+23 -- > 3
    楼梯_西北外角_上        x+24 -- > 0
]]

-- 原排序 -> 地图转换工具转换后的方块排序
local rotationOrder2toolOrder = {
    [1] = 1,
    [2] = 5,
    [3] = 10,
    [4] = 2,
    [5] = 6,
    [6] = 11,
    [7] = 3,
    [8] = 7,
    [9] = 12,
    [10] = 4,
    [11] = 8,
    [12] = 9,

    [13] = 13,
    [14] = 18,
    [15] = 21,
    [16] = 14,
    [17] = 19,
    [18] = 22,
    [19] = 15,
    [20] = 20,
    [21] = 23,
    [22] = 16,
    [23] = 17,
    [24] = 24,
}

-- 面向 <--> 单位正 逻辑id增量
local yawDir2PositiveLogicImcId = {
    [0] = 3,
    [1] = 6,
    [2] = 12,
    [3] = 9,
}

-- 逻辑id增量 <--> 渲染id增量
-- 如果 isUp， 那么渲染imcid直接 +12 即可
local stairImcIdAdaptTb = {
    [3] = 1,
    [7] = 2,
    [2] = 3,
    [6] = 4,
    [14] = 5,
    [4] = 6,
    [12] = 7,
    [13] = 8,
    [8] = 9,
    [9] = 10,
    [11] = 11,
    [1] = 12,
}

local blockImcId2yawDir = {
    [1] = 0,
    [2] = 0,
    [3] = 0,
    [4] = 1,
    [5] = 1,
    [6] = 1,
    [7] = 2,
    [8] = 2,
    [9] = 2,
    [10] = 3,
    [11] = 3,
    [12] = 3,
}

local function getBlockStairMetaByHitAndYaw(fromYaw, hitSideNormal, isUp)
    local yawDir = 0
    if hitSideNormal.y ~= 0 then
        local tempYaw = fromYaw and (fromYaw % 360 + 135) % 360 or 0 
        if tempYaw < 0 then
            tempYaw = tempYaw + 360
        end
        yawDir = tempYaw // 90
        isUp = hitSideNormal.y < 0
    else
        if hitSideNormal.x == 1 then
            yawDir = 0
        elseif hitSideNormal.x == -1 then
            yawDir = 2
        elseif hitSideNormal.z == 1 then
            yawDir = 1
        elseif hitSideNormal.z == -1 then
            yawDir = 3
        end
    end
    return yawDir, isUp
end

local function getAroundStairBlockState(map, pos)
    local referAroundPosTb = {}
    for yawDir = 0, 3 do
        local tPos = getPosByDir(pos, yawDir)
        local cfg = map:getBlock(tPos)
        if cfg and cfg.blockId ~= 0 and cfg.isStair then
            -- referAroundPosTb[#referAroundPosTb + 1] = tPos
            referAroundPosTb[yawDir] = tPos
        end
    end
    return referAroundPosTb
end

local BlockStairYawDirMetaMap = L("BlockStairYawDirMetaMap", {})
local function updateBlockStairYawDirMetaMap(pos, yawDir)
    local v3Pos = Lib_tov3(pos):blockPos()
    local xMap = BlockStairYawDirMetaMap[v3Pos.x]
    if not xMap then
        xMap = {}
        BlockStairYawDirMetaMap[v3Pos.x] = xMap
    end
    local yMap = xMap[v3Pos.y]
    if not yMap then
        yMap = {}
        xMap[v3Pos.y] = yMap
    end
    yMap[v3Pos.z] = yawDir
end

local function getBlockStairYawDirMetaByPos(pos)
    local v3Pos = Lib_tov3(pos):blockPos()
    local xMap = BlockStairYawDirMetaMap[v3Pos.x]
    if not xMap then
        return false
    end
    local yMap = xMap[v3Pos.y]
    if not yMap then
        return false
    end
    return yMap[v3Pos.z]
end

local function stairPos2YawDir(map, pos)
    local yawDir = getBlockStairYawDirMetaByPos(pos)
    if yawDir then
        return yawDir
    end
    local blockCfg = map:getBlock(pos)
    local imcId = (blockCfg.blockId or 0) - (blockCfg.base_stair_id or 0)
    imcId = imcId > 12 and (imcId - 12) or imcId
    return blockImcId2yawDir[imcId]
end

local function stairBlockAdapt(params)
    local map, pos, tId, yawDir, isUp, referAroundPosTb
        = params.map, params.pos, params.tId, params.yawDir, params.isUp, params.referAroundPosTb
    local adapt_imc_id = stairImcIdAdaptTb[yawDir2PositiveLogicImcId[yawDir]]
    local forward = yawDir
    local left = ((yawDir - 1) >= 0) and (yawDir - 1) or 3
    local right = ((yawDir + 1) <= 3) and (yawDir + 1) or 0
    local back = ((yawDir - 2) >= 0) and (yawDir - 2) or ((yawDir - 2) + 4)
    local nPos = referAroundPosTb[forward]
    local sPos = referAroundPosTb[back]
    if nPos then
        local n_yaw_dir = stairPos2YawDir(map, nPos)
        if n_yaw_dir == left then
            adapt_imc_id = ((adapt_imc_id - 1) > 0) and (adapt_imc_id - 1) or ((adapt_imc_id - 1) + 12)
        elseif n_yaw_dir == right then
            adapt_imc_id = adapt_imc_id + 2
        end
    elseif sPos then
        local s_yaw_dir = stairPos2YawDir(map, sPos)
        if s_yaw_dir == left then
            adapt_imc_id = ((adapt_imc_id - 2) > 0) and (adapt_imc_id - 2) or ((adapt_imc_id - 2) + 12)
        elseif s_yaw_dir == right then
            adapt_imc_id = adapt_imc_id + 1
        end
    end

    map:setBlockConfigId(pos, tId + rotationOrder2toolOrder[isUp and adapt_imc_id + 12 or adapt_imc_id] or 0)
end

------------------------------------------------------- 
--[[
楼梯(stair) size = 24 (up 12, down 12, base 1)
    使用该接口时，传入初始方块Id，自动转换成目标方块Id
    注：base仅用来放入背包用，实际放置时base不可也没必要用到！
	注：传入的方块id为stair的初始的那个方块的id
	注：初始方块和该方块所有变化后的方块的id必须保持连续！保持顺序！并且长度是固定的，不能多不能少
    注：分上下层， isUp 是判断是否是上下层(是否反转)， 下层直接 +12 对应上层

    注：
        1.放置时必须携带放置方向，此时会先根据方向选择该方向对应的楼梯方块
        2.放下时正上方是左方向则隐藏右边，正上方如果是右方向则隐藏左边，其他不变，正下方同理
]]
--[[
    首先可以通过判断 hitSideNormal 来判断点的是方块的哪个面，如果是四周的面那么
        1.yawDir 就为点的那个面
        2.默认isUp为false
    如果点的是上下面，那么
        1.更改isUp为点的面
            点的方块的上面 -> isUp = false
            点的方块的下面 -> isUp = true
        2.需要根据 玩家的面向 + 180度 来重新计算yaw_dir ↓
    面向 yawDir
        45~135 -> yawDir = 0
        135~225 -> yawDir = 1
        225~315 -> yawDir = 2
        315~360 0~45 -> yawDir = 3
]]
function BlockAdapt.StairAdapt(params)
    local map, pos, tId, fromYaw, hitSideNormal, isUp, p_yaw_dir, p_isUp, referAround = 
        params.map, params.pos, params.tId, params.fromYaw, params.hitSideNormal, params.isUp,
        params.p_yaw_dir, params.p_isUp, params.referAround
    local referAroundPosTb = getAroundStairBlockState(map, pos)
    if tId > 0 then
        local f_yawDir, f_isUp = 0, isUp
        if p_yaw_dir then
            f_yawDir, f_isUp = p_yaw_dir, p_isUp
        else
            f_yawDir, f_isUp = getBlockStairMetaByHitAndYaw(fromYaw, hitSideNormal, isUp)
        end
        stairBlockAdapt({map = map, pos = pos, tId = tId, yawDir = f_yawDir, 
            isUp = f_isUp, referAroundPosTb = referAroundPosTb})
        updateBlockStairYawDirMetaMap(pos, f_yawDir)
    else
        map:setBlockConfigId(pos, 0)
        updateBlockStairYawDirMetaMap(pos, nil)
    end

    if not referAround then
        return
    end
    for _, tPos in pairs(referAroundPosTb) do
        local referBlockCfg = map:getBlock(tPos)
        local base_stair_id = referBlockCfg.base_stair_id or 0
        if base_stair_id > 0 then
            local referBlockYawDir = getBlockStairYawDirMetaByPos(tPos)
            if referBlockYawDir then
                BlockAdapt.StairAdapt({
                    map = map, pos = tPos, tId = base_stair_id, referAround = false,
                    p_yaw_dir = referBlockYawDir, p_isUp = (referBlockCfg.blockId - base_stair_id) > 12
                    })
            end
        end
    end
end
-- **************************************************** 

RETURN(BlockAdapt)