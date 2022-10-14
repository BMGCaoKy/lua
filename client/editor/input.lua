local cmd = require "editor.cmd"
local state = require "editor.state"
local def = require "editor.def"
local engine = require "editor.engine"
local utils = require "editor.utils"
local obj = require "editor.obj"
local tran = require "editor.Transform"
local data_state = require "editor.dataState"
local setting = require "common.setting"
local entity_obj = require "editor.entity_obj"
local item_obj = require "editor.item_obj"
local misc = require "misc"
local debugport = require "common.debugport"
local entity_obj_derive = require "editor.entity_obj_derive"
local worldCfg = World.cfg

local bm = Blockman.Instance()

local nextPos = nil
local nextMoveBlockPos = {
	x = 0,
	y = 0,
	z = 0 
}
local M = {}


local hit = nil
local curTouch = nil

local touch_focus_pos = nil

local MAXCOUNT = 100
local focusPos = nil
local rotateFlag = false
local isMoveX = true
local isMoveY = true
local isMoveZ = true

local ctrlspeed = 0
local lastKeyState = L("lastKeyState", {})
local appState = L("appState", {})

-- 手机编辑器视角配置自己管理
bm:changeCameraCfg({
	offset = {
		x = 0,
		y = 0,
		z = 0
	}
}, -1)
local function batchProduction(pos, callBackFunc)
	local batchProductionProp = worldCfg.batchProductionProp
	if not batchProductionProp then
		callBackFunc(pos)
		return
	end
	local count = batchProductionProp.count or 1
	pos = {x = math.floor( pos.x ), y = math.floor( pos.y ), z = math.floor( pos.z )}
	local area = batchProductionProp.area or {min = {x = 0,y = 0,z = 0}, max = {x = 0,y = 0,z = 0}}
	local region = {min = Lib.v3add(area.min,pos), max = Lib.v3add(area.max,pos)}
	local poss = Me.map:getRandomPosInRegion(count, true, nil, region)
	for _,p in pairs(poss) do
		callBackFunc(p)
	end
end

local function checkNewState(key, new)
	if lastKeyState[key] == new then
		return false
	end
	lastKeyState[key] = new
	return true
end

local function isKeyNewDown(key)
	local state = bm:isKeyPressing(key)
	return checkNewState(key, state) and state
end

local function axisValue(forward, back)
	local value = 0.0;
	if bm:isKeyPressing(forward) then
		value = value + 1
	end
	if bm:isKeyPressing(back) then
		value = value - 1
	end
	return value
end

local function runTelnet(index, port)
	local handle = appState[index]
	print("runTelnet", index, port, handle)
	if handle then
		if not misc.win_waitobject(handle) then
			misc.win_exitapp(handle)
			port = nil
		end
		misc.win_closehandle(handle)
		appState[index] = nil
	end
	if port then
		appState[index] = misc.win_exec("telnet.exe", "127.0.0.1 "..port, nil, nil, true)
	end
end

local function do_move(obj)
	local player = Player.CurPlayer
	if not player then
		return
	end
	local poleForwar = bm.gameSettings.poleForward
	local poleStrafe = bm.gameSettings.poleStrafe
	local forward = axisValue("key.forward", "key.back") + poleForwar
	local left = axisValue("key.left", "key.right") + axisValue("key.top.left", "key.top.right") + poleStrafe
	local up = axisValue("key.rise", "key.descend")
	nextPos = player:getPosition()
    local posX = 0
    local posY = 0
    local posZ = 0
    local flag1 = true
    local flag2 = false
	if forward==0.0 and left==0.0 and up==0.0 then
		player.isMoving = false
		flag1 = false
	end
    if  flag1 then
		local rYaw = bm:viewerRenderYaw()
		if Blockman.instance:getPersonView() == 4 then
			rYaw = 0
			rYaw = rYaw + bm:viewerRenderYaw()
		end
	    local rotationYaw = math.rad(rYaw)
	    local rotationPitch = math.rad(player:getRotationPitch())
	    local f1 = math.sin(rotationYaw)
	    local f2 = math.cos(rotationYaw)
	    local f3 = math.sin(rotationPitch)
	    local MOVE_SPEED = 0.2 * 2
		
        if bm:isKeyPressing("key.ctrl") then
            ctrlspeed = ctrlspeed + 0.03;
        else
            ctrlspeed = 0;
        end
        ctrlspeed = math.max(math.min(ctrlspeed, 4.5), 0)
        MOVE_SPEED = MOVE_SPEED + ctrlspeed
        posX = (left * f2 - forward * f1) * MOVE_SPEED
        posZ = (forward * f2 + left * f1) * MOVE_SPEED
	    if up ~= 0.0 then
            posY = (up - forward * f3) * MOVE_SPEED
	    end

    end
    if state:focus_class() == def.TFRAME and data_state.is_can_update then
        focusPos = state:focus_obj()
        obj.touchPostion = Lib.v3add(focusPos.min, {x = posX, y = posY, z = posZ})
        obj.touchPostion.y = math.max(obj.touchPostion.y, 0)
        obj.touchPostion.y = math.min(obj.touchPostion.y, 254)
        flag2 = true
        focusPos.min = obj.touchPostion
        focusPos.max = focusPos.min
    end

    if state:brush_class() == def.TFRAME_POS and data_state.frame_pos_count == 1 then
        local brushObj = state:brush_obj()
        if (not isMoveX) and posX * (brushObj.min.x - focusPos.min.x ) > 0  then
            posX = 0
        end
        if (not isMoveY) and posY * (brushObj.min.y - focusPos.min.y ) > 0 then
            posY = 0
        end
        if (not isMoveZ) and posZ * (brushObj.min.z - focusPos.min.z ) > 0 then
            posZ = 0
        end
        obj.touchPostion = Lib.v3add(brushObj.min, {x = posX, y = posY, z = posZ})
        obj.touchPostion.y = math.max(obj.touchPostion.y, 0)
        obj.touchPostion.y = math.min(obj.touchPostion.y, 254)
        flag2 = true
        brushObj.min = obj.touchPostion
    end

    if state:brush_class() == def.TCHUNK and data_state.is_can_move then
        local brush_obj = state:brush_obj()
        obj.touchPostion = Lib.v3add(focusPos.min, {x = posX, y = posY, z = posZ})
        obj.touchPostion.y = math.max(obj.touchPostion.y, 0)
        obj.touchPostion.y = math.min(obj.touchPostion.y, 254)
        flag2 = true
        focusPos.min = obj.touchPostion
        focusPos.max = obj.touchPostion
	end
	local cfg = player:cfg()
	local customFlag = false
	local movePos
	if cfg.entityDerive and cfg.entityDerive == "moveBlock" or cfg.entityDerive == "monster" or cfg.entityDerive == "pointEntity" then
		nextMoveBlockPos = Lib.v3add(nextMoveBlockPos, {x = posX, y = posY, z = posZ})
		if math.ceil(nextMoveBlockPos.x - 0.5) ~= 0  then
			nextPos.x = nextPos.x + math.ceil(nextMoveBlockPos.x - 0.5) * 0.5
			nextMoveBlockPos.x = 0
		end
		if math.ceil(nextMoveBlockPos.z - 0.5) ~= 0  then
			nextPos.z = nextPos.z + math.ceil(nextMoveBlockPos.z - 0.5) * 0.5
			nextMoveBlockPos.z = 0
		end
        if math.ceil(nextMoveBlockPos.y - 0.5) ~= 0  then
			nextPos.y = nextPos.y + math.ceil(nextMoveBlockPos.y - 0.5) * 0.5
			nextMoveBlockPos.y = 0
		end
		customFlag = true
	else
        local tmpPos = flag2 and {
                                    x = math.ceil(obj.touchPostion.x - 0.5),
                                    y = math.ceil(obj.touchPostion.y - 0.5),
                                    z = math.ceil(obj.touchPostion.z - 0.5)
                                    } or nil
		nextPos = tmpPos or Lib.v3add(nextPos, {x = posX, y = posY, z = posZ})
	end

	if customFlag then
		if (Lib.tov3(nextPos) - Lib.tov3(player:getPosition())):len() > 0.1 then
			player:setMove(0, nextPos, player:getRotationYaw(), player:getRotationPitch(), 7, 1, true)
		end
	else
		player:setMove(0, nextPos, player:getRotationYaw(), player:getRotationPitch(), 2, 1, true)
	end
	player.isMoving = flag1 or customFlag 
end

local function wheel_step_move(wheel_step)
	local player = Player.CurPlayer
	if not player then
		return
	end

	local forward = wheel_step

	if forward==0.0 then
		return
	end

	local rotationYaw = math.rad(player:getRotationYaw())
	local rotationPitch = math.rad(player:getRotationPitch())
	local f1 = math.sin(rotationYaw)
	local f2 = math.cos(rotationYaw)
	local f3 = math.sin(rotationPitch)
	local MOVE_SPEED = math.abs(forward)
	if (nextPos.y + (0 - forward * f3) * MOVE_SPEED < 3) then
		return
	end

	nextPos.x = nextPos.x + (0 - forward * f1) * MOVE_SPEED
	nextPos.z = nextPos.z + (forward * f2 + 0) * MOVE_SPEED
	nextPos.y = nextPos.y + (0 - forward * f3) * MOVE_SPEED
	player.isMoving = true
	bm:cleanWheelStep()
end

local function on_click_block(posi)
	local _table = {pos = posi}
	state:set_focus(_table,def.TBLOCK)
end

local function on_click_brith(posi)
	engine:birth_position(posi)
	data_state.isbrith = false
end

local function on_click_block_vector(blockPos, cfg)
	if not cfg or not cfg.blockVector then
		return
	end
	local params = {
		pos = blockPos,
		cfg = cfg
	}
	Lib.emitEvent(Event.EVENT_BLOCK_VECTOR, true, params)
end

local function empty_click_entity(id)
	entity_obj:deriveEmptyClick(id)
end

local function on_click_entity(entity)
	local id = entity_obj:getIdByEntity(entity)
	if not id then
		return
	end
	local name = entity_obj:getCfgById(id)
	local cfg = Entity.GetCfg(name)
	if data_state.is_send_entity then
		engine:send_entity_id(id)
		data_state.is_send_entity = false
		return
	end
	local _table = {id = id}
	state:set_focus(_table,def.TENTITY)
	engine:pitch_on_entity(id)
end

local function control_entity(entity)
    local bpos = entity:getPosition()
    bm:setMainPlayer(entity)
    Player.CurPlayer = entity
    Player.CurPlayer:setPosition(bpos)
    nextPos = bpos
    Player.CurPlayer:setRotationYaw(entity:getRotationYaw())
    Player.CurPlayer:setRotationPitch(entity.rotationPitch)
    -- bm.gameSettings.cameraYaw = entity.rotationYaw
end

local function on_click_item(item)
	local id = item_obj:get_id_by_itemobj(item)
--	if data_state.is_send_item then
--		engine:send_item_id(id)
--		data_state.is_send_item = false
--		return
--	end
	local _table = {id = id}
	state:set_focus(_table,def.TITEM)
end

local function on_create_dir_block(cfg, side)
	if not cfg.direction then
		return
	end
	local concatStr = ""
	local dir = Lib.v3normalize(side)
	local StrTab = {
		[0] = "_left",
		[6] = "_right",
		[1] = "_down",
		[5] = "_up",
		[2] = "_front",
		[4] = "_back"
	}
	local concatIndex = math.tointeger(dir.x + dir.y * 2 + dir.z * 3 + 3) 
	local id = Block.GetNameCfgId(cfg.fullName .. StrTab[concatIndex])
	return id
end

local function checkDeriveEntity(bpos)
	local isok = true
	local entitys = entity_obj:getEntitysByDeriveTypeAndTeamID({1, 2, 3, 4, 7})

	for _, entity in pairs(entitys) do
		local position = entity:getPosition()
		local pos = {y = math.floor(position.y)}
		for x= math.floor(position.x - 0.4), math.floor(position.x + 0.4) do
			for z = math.floor(position.z - 0.4), math.floor(position.z + 0.4) do
				for i = -1, 1 do
					pos.x = x
					pos.z = z
					pos.y = math.floor(position.y) + i
					if pos.x == bpos.x and pos.y == bpos.y and pos.z == bpos.z then
						isok = false
					end
				end
			end
		end
	end
	if not isok then
		Lib.emitEvent(Event.EVENT_TOAST_TIP, Lang:toText("cant_place_block"), 20)
	end
	return isok
end

local function blockNormalSet(block_cfg, sideNormal)
	local changers = block_cfg.changers
	local blockId
	if type(changers) == "table" then
		local snKey = string.format("%d:%d:%d", sideNormal.x, sideNormal.y, sideNormal.z)
		if not changers[snKey] then
			return false
		end

		local placeInfo = changers[snKey]
		local blockName = placeInfo
		if type(placeInfo) == "table" then
			local yaw = Player.CurPlayer:getRotationYaw()
			local index = math.floor(((yaw + 360) % 360 + 45) / 90)
			index = index == 0 and 4 or index
			blockName = placeInfo[index]
			block_cfg = Block.GetNameCfg(blockName)
			blockId = Block.GetNameCfgId(blockName)
			return true, block_cfg, blockId
		end
		block_cfg = Block.GetNameCfg(blockName)
		blockId = Block.GetNameCfgId(blockName)
	end
	return true, block_cfg, blockId
end

local function on_click_cmd_block(pos, side, b, hitBox, ishitBlock)
	local bpos = nil
	side = side or {x = 0, y = 0, z = 0}
	local _table = state:brush_obj()
	local blockId = _table.id
	local cfg = Block.GetIdCfg(blockId)
	blockId = on_create_dir_block(cfg, side) or blockId
	if blockId ~= 0 then
		bpos = Lib.v3add(pos, side)
	else
		bpos = pos
	end

	if cfg.isDropItem and not UI:getWnd("mapEditShortcut"):isBlockState() then
		local box = cfg.boundingVolume and cfg.boundingVolume.params or {1, 1.8, 1}
		local addY
		if side.y > 0 then
			addY = hitBox[2]
		else
			addY = box[2]
		end
		bpos = pos
		if ishitBlock then
			bpos = Lib.v3add(bpos, {x = 0.5, y = 0, z = 0.5})
		end
		bpos = Lib.v3add(bpos, {
			x = side.x * (hitBox[1] + box[1]) * 0.5, 
			y = side.y * addY + 0.01,
			z = side.z * (hitBox[3] + box[3]) * 0.5
		})
		cmd:set_item(bpos, "/block", blockId)
		return
	end

	bpos.y = math.floor(bpos.y)
	bpos.x = math.floor(bpos.x)
	bpos.z = math.floor(bpos.z)
	on_click_block_vector(bpos, cfg)
	local placeBlockCfg = cfg
	local touchBlockCfg = Block.GetIdCfg(World.CurMap:getBlockConfigId(pos))
	if touchBlockCfg.cannotStack and placeBlockCfg.cannotStack then
		-- local cannotStackList = Clientsetting.getCannotStackList()
		-- for k, mutexName in pairs(cannotStackList) do
		-- 	if placeBlockCfg.fullName == mutexName then
		-- 		return 
		-- 	end
		-- end
		return
	end
	local ok, newCfg, id = blockNormalSet(cfg, side)
	ok = ok and checkDeriveEntity(bpos)
	id = id or blockId
	if not ok then
		return
	end
	if cfg and cfg.placeBlockSound then
		Player.CurPlayer:playSound(cfg.placeBlockSound) 
	end
	cmd:set_block(bpos, id, b, newCfg)
end

local function on_click_cmd_item(pos, side, ishitBlock, hitBox)
	local bpos = nil
	local _table = state:brush_obj()
	local cfg = setting:fetch("item", _table.cfg)
	local box = cfg.boundingVolume and cfg.boundingVolume.params or {1, 1.8, 1}
	local addY
	if side.y > 0 then
		addY = hitBox[2]
	else
		addY = box[2]
	end
	bpos = pos
	if ishitBlock then
		bpos = Lib.v3add(bpos, {x = 0.5, y = 0, z = 0.5})
	end
	bpos = Lib.v3add(bpos, {
		x = side.x * (hitBox[1] + box[1]) * 0.5, 
		y = side.y * addY + 0.01,
		z = side.z * (hitBox[3] + box[3]) * 0.5
	})
	cmd:set_item(bpos, _table.cfg)
end

local function getDirEntityCfg(baseCfg, dirCfgs, side)
		--[[
			  5   4
			  �� �J
		 0<---|--->6
			�L��
		   2  1
		]]
		local dir = Lib.v3normalize(side)
		local index = math.tointeger(dir.x + dir.y * 2 + dir.z * 3 + 3)
		local dirCfg = dirCfgs[tostring(index)]
		assert(dirCfg, index)
		return baseCfg .. dirCfg
	end

local function on_click_cmd_entity(pos, side, ishitBlock, hitBox, isEntity)
	local bpos = nil
	local _table = state:brush_obj()
    if isEntity then
		local maxCount = hit.entity:cfg().maxCount
		local flag = maxCount and (maxCount == 1) or false
        if flag and hit.entity:cfg().fullName == _table.cfg then
            return
        end
    end
	local cfg = setting:fetch("entity", _table.cfg)
	local oriCfg = _table.cfg --for reset _table.cfg
	if not side then
		return
	end
	if cfg.dirCfgs then
		_table.cfg = getDirEntityCfg(_table.cfg, cfg.dirCfgs, side)
		cfg = Entity.GetCfg(_table.cfg)
	end
	local box = cfg.boundingVolume and cfg.boundingVolume.params or _table.moveBlockSize or {1, 1.8, 1}
	_table.side = side --for ry
	local addY
	if side.y > 0 then
		addY = hitBox[2]
	else
		addY = box[2]
	end
	bpos = pos
	if ishitBlock then
		bpos = Lib.v3add(bpos, {x = 0.5, y = 0, z = 0.5})
	end
	bpos = Lib.v3add(bpos, {
		x = side.x * (hitBox[1] + box[1]) * 0.5, 
		y = side.y * addY,
		z = side.z * (hitBox[3] + box[3]) * 0.5
	})
	local ok = checkDeriveEntity({x = math.floor(bpos.x), y = math.floor(bpos.y), z = math.floor(bpos.z)})
	if not ok then
		return
	end
	batchProduction(bpos, function(pos)
		cmd:set_entity(pos, Lib.copy(_table))
	end)
	_table.cfg = oriCfg --for reset _table.cfg
end

local function on_click_region(pos,side)
	--���ˢ�ӣ����ý���
	pos = Lib.v3add(pos, side)
	cmd:add_region(pos)
end

local function on_click_frame(pos, side, isNoInfo)
	local obj = {
		min = Lib.v3add(pos, side),
		max = Lib.v3add(pos, side)
	}
	state:set_focus(obj,def.TFRAME)
	engine:editor_obj_type("TFRAME")
    nextPos = Lib.copy(obj.min)
    if not isNoInfo then
        Lib.emitEvent(Event.EVENT_CONFIRM_POINT)
    end
end

local function on_click_frame_pos(pos)
	-- Lib.emitEvent(Event.FRAME_POSITION,pos)
end

local function on_click_cmd_chunk(pos,side)
	--pos = Lib.v3add(pos, side)
	--local minpos = tran.CenterAlign(pos,state:brush_obj(),side)
	cmd:set_chunk(pos,side,state:brush_obj())
	engine:editor_obj_type("TCHUNK");
end

local function click_right_block()
	local min = state:focus_obj().pos
	if engine:detect_collision(min,min) then
		engine:send_block_name(setting:id2name("block",engine:get_block(hit.blockPos)))
		engine:open_menu("block")
	else
		state:set_focus(nil)
	end
end

local function click_right_entity()
	if hit.type == "ENTITY" then
		on_click_entity(hit.entity)
		engine:open_menu("entity")
	else
		state:set_focus(nil)
	end
end

local function click_right_region()
	local min = obj:get_region(state:focus_obj().name).box.min
	local _max = obj:get_region(state:focus_obj().name).box.max
	local max = {
		x = _max.x + 1,
		y = _max.y + 1,
		z = _max.z + 1
	}
	if engine:detect_collision(min,max) then
		engine:open_menu("region")
	else
		state:set_focus(nil)
		engine:editor_obj_type("COMMON")
	end
end

local function click_right_chunk()
	local min = state:focus_obj().pos
	local max = {
		x = min.x + state:focus_obj().data.lx - 1,
		y = min.y + state:focus_obj().data.ly - 1,
		z = min.z + state:focus_obj().data.lz - 1
	}
	if engine:detect_collision(min,max) then
		engine:editor_obj_type("TCHUNK")
		engine:open_menu("chunk")
	else
		if data_state.is_frame_pos then
			local obj = Lib.boxOne()
			data_state.frame_pos_count = 0
			state:set_editmode(def.ECOMMON)
			state:set_brush(obj,def.TFRAME_POS)
			data_state.is_frame_pos = false
		else
			local obj = Lib.boxOne()
			state:set_brush(obj,def.TFRAME)
			state:set_editmode(def.ESCALE)
		end
		engine:editor_obj_type("NOTFill")
	end
end

local function click_right_frame()
	local min = state:focus_obj().min
	local max = state:focus_obj().max
	if engine:detect_collision(min,max) then
		engine:editor_obj_type("TFRAME")
		engine:open_menu("frame")
	else
		if data_state.is_frame_pos then
			local obj = Lib.boxOne()
			data_state.frame_pos_count = 0
			state:set_editmode(def.ECOMMON)
			state:set_brush(obj,def.TFRAME_POS)
			data_state.is_frame_pos = false
		else
			local obj = Lib.boxOne()
			state:set_brush(obj,def.TFRAME)
			state:set_editmode(def.ESCALE)
		end
		engine:editor_obj_type("NOTFill")
	end
end

local function click_right_frame_pos()

end

local function click_right_block_fill()
	local _table = {id = state:focus_obj().id}
	state:set_brush(_table, def.TBLOCK)
end

local function detect_collision_cursor()
	if state:focus_obj() ~= nil and state:get_editmode() == def.EMOVE and state:brush_obj() == nil then
		local min = nil
		local max = nil
		local focus_obj = state:focus_obj()
		local focus_class = state:focus_class()
		if data_state.touch_focus_pos then
			min = data_state.touch_focus_pos
		else
			min = focus_obj.pos
		end
		
		if focus_class == def.TBLOCK then
			max = min
		elseif focus_class == def.TCHUNK then
			max = {
				x = min.x + focus_obj.data.lx - 1,
				y = min.y + focus_obj.data.ly - 1,
				z = min.z + focus_obj.data.lz - 1
			}
		end
		if min == nil or max == nil then
			return false
		else
			if engine:detect_collision(min,max) then
				return true
			else
				return false
			end
		end
	else
		return false
	end
end

local function touch_begin_left()
	if detect_collision_cursor() and data_state.is_cursor_hand == false then
		--engine:set_cursor("QT_CLOSE_HAND_CURSOR")
		local focus_class = state:focus_class()
		local focus_obj = state:focus_obj()
		if focus_class == def.TBLOCK then
			state:set_brush({id = engine:get_block(focus_obj.pos)},focus_class,false)
		elseif focus_class == def.TCHUNK then
			local max = {
				x = focus_obj.pos.x + focus_obj.data.lx - 1,
				y = focus_obj.pos.y + focus_obj.data.ly - 1,
				z = focus_obj.pos.z + focus_obj.data.lz - 1
			}
			local new_chunk = engine:make_chunk(focus_obj.pos, max, true)
			state:set_brush(new_chunk,focus_class,false)
		end
		if data_state.touch_focus_pos == nil then
			data_state.touch_focus_pos = {
				x = focus_obj.pos.x,
				y = focus_obj.pos.y,
				z = focus_obj.pos.z
			}
		end
		data_state.is_cursor_hand = true
		
	else
		--engine:set_cursor("QT_OPEN_HAND_CURSOR")
	end
end

local function touch_bengin_right()
end

local function touch_end_left()
	if data_state.is_cursor_hand and hit.blockPos then
		--engine:set_cursor("QT_ARROW_CURSOR")
		local end_pos = Lib.v3add(hit.blockPos, hit.sideNormal)
		if state:brush_class() == def.TCHUNK then
			end_pos = tran.CenterAlign(Lib.v3add(hit.blockPos, hit.sideNormal),state:brush_obj(),hit.sideNormal)
		end
		local pos = nil
		if state:focus_class() == def.TBLOCK then
			pos = {
				x = data_state.touch_focus_pos.x + 0.5,
				y = data_state.touch_focus_pos.y + 0.5,
				z = data_state.touch_focus_pos.z + 0.5
			}
		elseif state:focus_class() == def.TCHUNK then
			pos = {
				x =  data_state.touch_focus_pos.x + state:focus_obj().data.lx / 2,
				y =  data_state.touch_focus_pos.y + state:focus_obj().data.ly / 2,
				z =  data_state.touch_focus_pos.z + state:focus_obj().data.lz / 2
			}
		end
		local offset = Lib.v3cut(end_pos, data_state.touch_focus_pos)
		if pos then
			Lib.emitEvent(Event.EVENT_EDITOR_GIZMO_DRAG_START,pos,offset)
			Lib.emitEvent(Event.EVENT_EDITOR_GIZMO_DRAG_MOVE,pos,offset)
			Lib.emitEvent(Event.EVENT_EDITOR_GIZMO_DRAG_END,pos,offset)

			--engine:gizmo_widget_set_pos(Lib.v3add(pos,offset))
		end
		state:set_brush(nil)
		data_state.is_cursor_hand = false
	end
end

local function touch_end_right()
	
end

local function set_brush_frame()
	local obj = {}
	local pos, sideNormal
	if hit.type == "BLOCK" then
		obj = Lib.boxOne()
		pos = hit.blockPos
		sideNormal = hit.sideNormal
	elseif hit.type == "ENTITY" then
		local id = tostring(state:focus_obj().id)
		local name = entity_obj:getCfgById(id)
		local cfg = Entity.GetCfg(name)
		local box = cfg.boundingVolume and cfg.boundingVolume.params or {1, 1, 1}
		obj.min = Lib.v3(box[1], box[2], box[3])
		obj.max = Lib.v3(box[1], box[2], box[3])
		sideNormal = Lib.v3(0, 0, 0)
	else
		return
	end
	if data_state.is_frame_pos then
    	state:set_brush(obj,def.TFRAME)
		data_state.is_frame_pos = false
		on_click_frame_pos(pos)
	else
		on_click_frame(pos, sideNormal)
	end
end

local function click_left()
    if not data_state.is_can_place then
        return
	end
	Player.CurPlayer:updateUpperAction("attack2", -1)
	if state:brush_obj() == nil then
		if hit.type == "BLOCK" and hit.blockPos then
			if state:focus_class() == def.TFRAME then
				--set_brush_frame()
			elseif state:focus_class() == def.TREGION then
				state:set_focus(nil)
				state:set_editmode(def.EMOVE)
			elseif state:focus_class() == def.TCHUNK then
			else
                if data_state.isbrith == true then
					on_click_brith(hit.worldPos)
                else
					on_click_block(hit.blockPos)
					if data_state.is_del_state then
						local _table = state:focus_obj()
						cmd:del_block(_table.pos)
						state:set_focus(nil)
					else
						local cfg = hit.blockPos and World.CurMap:getBlock(hit.blockPos) or nil
						on_click_block_vector(hit.blockPos, cfg)
					end
                end
			end
		elseif hit.type == "ENTITY" then
			state:set_editmode(def.EMOVE)
			on_click_entity(hit.entity)
			if data_state.is_del_state then
				local _table = state:focus_obj()
				if not _table then
					return
				end
                local derive = entity_obj:getDataById(_table.id)
                if not derive or not derive.pointEntity then
				    cmd:del_entity(_table.id)
				    state:set_focus(nil)
                end
			else
				local id = entity_obj:getIdByEntity(hit.entity)
				if not id then
					return
				end
				local name = entity_obj:getCfgById(id)
				local cfg = hit.entity.GetCfg(name)
				empty_click_entity(id)
			end
		elseif hit.type == "ITEM" then
			--set_brush_frame()
			state:set_editmode(def.EMOVE)
			on_click_item(hit.item)
			if data_state.is_del_state then
				local _table = state:focus_obj()
				cmd:del_item(_table.id, hit.item)
				state:set_focus(nil)
			end
		end
	else
		if hit.blockPos then
			if state:brush_class() == def.TBLOCK and hit.type == "BLOCK" then
				on_click_cmd_block(hit.blockPos, hit.sideNormal, false, {1, 1, 1}, true)
			elseif state:brush_class() == def.TENTITY then
				on_click_cmd_entity(hit.blockPos, hit.sideNormal, true, {1, 1, 1})
			elseif state:brush_class() == def.TREGION then
				on_click_region(hit.blockPos,hit.sideNormal)
			elseif state:brush_class() == def.TCHUNK then
				on_click_cmd_chunk(hit.blockPos,hit.sideNormal)
			elseif state:brush_class() == def.TFRAME then
				on_click_frame(hit.blockPos, hit.sideNormal)
			elseif state:brush_class() == def.TFRAME_POS then
				on_click_frame_pos(hit.blockPos)
			elseif state:brush_class() == def.TITEM then
				on_click_cmd_item(hit.blockPos, hit.sideNormal, true, {1, 1, 1})
			end
		end
		if hit.type == "ITEM" then
			local pos = hit.item:getPosition()
			local BoundingBox = hit.item:getBoundingBox()
			local box = {
				math.abs(BoundingBox[2].x - BoundingBox[3].x),
				math.abs(BoundingBox[2].y - BoundingBox[3].y),
				math.abs(BoundingBox[2].z - BoundingBox[3].z)
			}
			if state:brush_class() == def.TENTITY then
				on_click_cmd_entity(pos,  hit.sideNormal, false, box)
			elseif state:brush_class() ==  def.TBLOCK then
				on_click_cmd_block(pos, hit.sideNormal, false, box)
			elseif state:brush_class() == def.TITEM then
				on_click_cmd_item(pos, hit.sideNormal, false, box)
			end
		elseif hit.type == "ENTITY" then
			local pos = hit.entity:getPosition()
			local BoundingBox = hit.entity:getBoundingBox()
			local box = {
				math.abs(BoundingBox[2].x - BoundingBox[3].x),
				math.abs(BoundingBox[2].y - BoundingBox[3].y),
				math.abs(BoundingBox[2].z - BoundingBox[3].z)
			}
			local id = entity_obj:getIdByEntity(hit.entity)
			if not id then
				return
			end
			local derive = entity_obj:getDataById(id)
			local pointEntity = derive and derive.pointEntity
			local canPlace = not pointEntity or (pointEntity.typePoint == 5 or pointEntity.typePoint == 6)
			if not canPlace then
				Lib.emitEvent(Event.EVENT_TOAST_TIP, Lang:toText("cant_place_block"), 20)
				return
			end
			if state:brush_class() == def.TENTITY then
				on_click_cmd_entity(pos, hit.sideNormal, false, box, true)
			elseif state:brush_class() ==  def.TBLOCK then
				on_click_cmd_block(pos, hit.sideNormal, false, box)
			elseif state:brush_class() == def.TITEM then
				on_click_cmd_item(pos, hit.sideNormal, false, box)
			end
		end
	end
end

local function click_right()
	if data_state.touch_focus_pos == nil then
	if state:brush_obj() == nil then
		local class = state:focus_class()
		if class == def.TBLOCK then
			click_right_block()
		elseif class == def.TENTITY then
			click_right_entity()
		elseif class == def.TREGION then
			click_right_region()
		elseif class == def.TCHUNK then
			click_right_chunk()
		elseif class == def.TFRAME then
			click_right_frame()
		elseif class == def.TFRAME_POS then
			click_right_frame_pos()
		elseif class == def.TBLOCK_FILL then
			click_right_block_fill()
		else
			if state:clipboard_obj() ~= nil then
				engine:show_scene_menu()--��ʾ�ϴ�ճ��������
			end
		end
	else
		if state:brush_class() ~= def.TFRAME and state:brush_class() ~= def.TFRAME_POS then
			if state:brush_class() ~= def.TBLOCK then
				engine:editor_obj_type("COMMON")
			end
			state:set_brush(nil)
		end
	end
	end
end

local function action_null()
	if detect_collision_cursor() then
		--engine:set_cursor("QT_OPEN_HAND_CURSOR")
	else
		--engine:set_cursor("QT_ARROW_CURSOR")
	end
end

local function touch_begin()
	touch_begin_left()
	--[[
	print(hit.action_param)
	if hit.action_param == 0 then
		print("touch_bengin")
		touch_bengin_left()
	elseif hit.action_param == 1 then
		print("touch_bengin_1")
		touch_bengin_right()
	end
	]]--
end

local function touch_end()
	action_null()
	touch_end_left()
	--[[
	if hit.action_param == 0 then
		print("touch_end_0")
		touch_end_left()
	elseif hit.action_param == 1 then
		print("touch_end_1")
		touch_end_right()
	end
	]]--
end

local function click()
	click_left()
--	if hit.action_param == 0 then
--		click_left()
--	elseif hit.action_param == 1 then
--		--click_right()
--	end
end

local function getTouchTime(hit)
	if hit.type=="ENTITY" then
		return 20
--		local entity = hit.entity
--		return entity:cfg().touchTime or 20
	elseif hit.type=="BLOCK" then
		local player = Player.CurPlayer
		local blockPos = hit.blockPos
		if not blockPos then
			return nil
		end
		local block = player.map:getBlock(blockPos)
		local clickDis = player:cfg().clickBlockDistance
		if clickDis and Lib.getPosDistance(player:getPosition(), blockPos) > clickDis then
			return false
		end
		return 20 --or block.breakTime
	end
end

local function stop_timer()
	if not curTouch then
		return
	end
	local tmp = curTouch
	curTouch = nil
	if tmp.timer then
		tmp.timer()
	end
	return tmp.packet
end

local function stopSound(player, name)
	if player then
		local soundId = player:data("soundId")[name]
		if soundId then
			player:stopSound(soundId)
		end
	end
end

local function touchEnd()
	if not stop_timer() then
		return
	end
	local player = Player.CurPlayer
	Lib.emitEvent(Event.EVENT_BREAK_BLOCK_UI_MANAGE, false)
	player:destroyBlockStop()
	stopSound(player, "breakBlockSound")
end

local function checkTouch(touch, packet)
	local _packet = touch.packet
	if not packet or (not packet.blockPos and not packet.targetID) then
		touchEnd()
		return true
	end
	if not _packet and (not _packet.blockPos or not _packet.targetID)  then
		return true
	end
	if _packet.blockPos and packet.blockPos then
		local oldBlockPos = _packet.blockPos
		local newBlockPos = packet.blockPos
		if oldBlockPos.x == newBlockPos.x and oldBlockPos.y == newBlockPos.y and oldBlockPos.z == newBlockPos.z then
			return true
		end
		touchEnd()
		return false
	elseif _packet.targetID and packet.targetID then
		if _packet.targetID == packet.targetID then
			return true
		end
		touchEnd()
		return false
	end
	touchEnd()
	return false
end

local function touchBegin(packet, hitType)
	if curTouch and checkTouch(curTouch, packet) then
		return
	end
	local player = Player.CurPlayer
	if player.cantUseSkill then
		return
	end
	packet.touchTime = getTouchTime(hit)
	if not packet.touchTime then
		return
	end
	Lib.emitEvent(Event.EVENT_BREAK_BLOCK_UI_MANAGE, true, packet.touchTime)
	local blockCfg
	if hitType == "BLOCK" then
		blockCfg = World.CurMap:getBlock(packet.blockPos)
		if blockCfg and blockCfg.breakBlockSound then
			player:data("soundId").breakBlockSound = player:playSound(blockCfg.breakBlockSound) 
		end
		player:destroyBlockStart(packet.blockPos, packet.touchTime)
	end
	curTouch = {
		packet = packet,
		timer = World.Timer(packet.touchTime, function() 
			stop_timer()
			if hitType == "BLOCK" then 
				cmd:del_block(packet.blockPos)
				player:destroyBlockStop()
				stopSound(player, "breakBlockSound")
				if blockCfg and blockCfg.breakBlockAfterSound then
					player:data("soundId").breakBlockAfterSound = player:playSound(blockCfg.breakBlockAfterSound) 
				end
			end
			if hitType == "ENTITY" then
				local entity = World.CurWorld:getEntity(packet.targetID)
				local id = entity_obj:getIdByEntity(entity)
				if not id then
					return
				end
				local pos = entity_obj:getPosById(id)
                local derive = entity_obj:getDataById(id)
                if not derive or not derive.pointEntity then
				    cmd:del_entity(id)
                end
				Lib.emitEvent(Event.EVENT_ENTITY_SETTING, nil, nil, true)
				local path = "plugin/myplugin/effect/Burst_mario_die.effect" 
				local fullpath = CGame.Instance():getGameRootDir().. "/"  .. World.GameName .. "/" .. path
				local f, err = io.open(fullpath, "r+")
				if not err then
					pos.y = pos.y + 0.5
					Blockman.instance:playEffectByPos(path, pos, 0, 1000)
				end
			end		
		end)
	}
end

function M:updateHitInfo()
	local act = bm:getUserAction().action
	if act == "NULL" then
		return
	end
	hit = bm:getHitInfo()
	if not hit.sideNormal then
		return
	end
	self:updatePosition(hit)
	local packet = {}
	if hit.type=="ENTITY" then
		local entity = hit.entity
		packet.targetID = entity.objID
		packet.targetPos = entity:getPosition()
	elseif hit.type=="BLOCK" then
		packet.blockPos = hit.blockPos
		packet.sideNormal = hit.sideNormal
	end
	if act == "CLICK" then
		click()
	elseif act=="TOUCH_BEGIN" then
		if data_state.is_can_place then
			touchBegin(packet, hit.type)
		end	
	elseif act=="TOUCH_END" then
		touchEnd()
	else
		--action_null()
	end
end

function M:subscribeKeyBoard()
	local movingStyle = 0
	if bm:isKeyPressing("key.sneak") then
		movingStyle = 1
	end
	if isKeyNewDown("key.f11") then
		if movingStyle==0 then
			runTelnet(1, debugport.port)
		else
			runTelnet(2, debugport.serverPort)
		end
	end

	if isKeyNewDown("key.f1") then
        Lib.emitEvent(Event.EVENT_SHOW_GMBOARD)
	end
end

function M:updateMove()
	local moveControl = EditorModule:getMoveControl()
	if moveControl:updateMove() then
		return
	end
	do_move(self)
	local player = Player.CurPlayer
	local entityDerive = player:cfg().entityDerive
	if entityDerive and entityDerive == "moveBlock" then
	else
		--player:setMove(0, nextPos, player:getRotationYaw(), player:getRotationPitch(), 1, 0)
	end
end

function M:update()
	local player = Player.CurPlayer
	if not player then
		return
	end
	self:updateHitInfo()
	self:subscribeKeyBoard()
	self:updateMove()
	local wheel_step = bm:getWheelStep();
	if wheel_step ~= 0 then
		wheel_step_move(wheel_step)
		engine:ClearWheelValue();
	end
end

function M:updatePosition(hit)
	if hit.type == "BLOCK" and hit.sideNormal then
		self.position = {x = 0; y = 0; z = 0;}
		if state:brush_obj() == nil 
		or (state:brush_class() == def.TBLOCK and state:brush_obj().id == 0) 
		or state:brush_class() == def.TFRAME_POS
		then
			self.position = hit.blockPos
		else
			self.position = Lib.v3add(hit.blockPos, hit.sideNormal)
			self.sideNormal = hit.sideNormal
		end
	else
		self.position = nil
		self.sideNormal = nil
	end
end

Lib.subscribeEvent(Event.EVENT_EDITOR_GIZMO_CONFIRM, function(is_confirm)
    if is_confirm then
        --��frame���chunk
        local focusobj = state:focus_obj()
        local chunkobj = engine:make_chunk(focusobj.min, focusobj.max)
        local obj = { pos = focusobj.min, data = chunkobj }
        state:set_focus(obj, def.TCHUNK)
    else
        --���������ᣬ������block
        state:set_focus(nil)
    end
end)

Lib.subscribeEvent(Event.EVENT_EDITOR_SCALER_DRAG_START, function(positive,reverse)
	engine:down_region()
end)

Lib.subscribeEvent(Event.EVENT_EDITOR_SCALER_DRAG_MOVE, function(positive,reverse)
	--����
	local reverse_pos = {
		x = reverse.x - 1,
		y = reverse.y - 1,
		z = reverse.z - 1
	}
	local _table = state:focus_obj()
	if state:get_editmode() == def.ESCALE then
		local focus_type = state:focus_class()
		if focus_type == def.TFRAME then
			_table.min = positive
			_table.max = reverse_pos
			engine:show_property_dock_scale(positive,reverse)
		elseif focus_type == def.TREGION then
			obj:get_region(_table.name).box.min = positive
			obj:get_region(_table.name).box.max = reverse_pos
		elseif focus_type == def.TBLOCK_FILL then
			_table.min = positive
			_table.max = reverse_pos
		end
	end
end)

Lib.subscribeEvent(Event.EVENT_EDITOR_SCALER_DRAG_END, function(positive,reverse)
	local reverse_pos = {
		x = reverse.x - 1,
		y = reverse.y - 1,
		z = reverse.z - 1
	}
	local focus_obj = state:focus_obj()
	local focus_class = state:focus_class()
	if focus_class == def.TREGION then
		local min = obj:get_region(focus_obj.name).box.min
		local max = obj:get_region(focus_obj.name).box.max
		if state:get_editmode() == def.ESCALE then
			min = positive
			max = reverse_pos
		end
		
		state:set_focus(nil)

		local obj = {
			regionCfg = obj:get_region(focus_obj.name).regionCfg,
			box = {
				min = min,
				max = max
			}
		}
		cmd:move_region(focus_obj.name,obj,true)
	elseif focus_class == def.TBLOCK_FILL then
		focus_obj.min = positive
		focus_obj.max = reverse_pos
		cmd:block_fill(focus_obj)
		focus_obj.old_min = positive
		focus_obj.old_max = reverse_pos
	end
	--TODO
	if data_state.is_select_region == true then
		engine:up_region()
		--data_state.is_select_region = false
		--return
	end
end)

Lib.subscribeEvent(Event.EVENT_ENTITY_SET_POS, function(id)
    local playerEidtor = entity_obj:getEntityById(id)
	Lib.emitEvent(Event.EVENT_ENTITY_CONTROL, playerEidtor)
end)


Lib.subscribeEvent(Event.EVENT_ENTITY_CONTROL, function(entity)
	control_entity(entity)
end)

Lib.subscribeEvent(Event.EVENT_EDIT_CONFRIM, function(pos)
	focusPos.min = Lib.copy(pos)
    focusPos.max = focusPos.min
end)

Lib.subscribeEvent(Event.EVENT_BOUND_SCOPE, function(scope)
    isMoveX = scope.x < MAXCOUNT
    isMoveY = scope.y < MAXCOUNT
	isMoveZ = scope.z < MAXCOUNT
end)

Lib.subscribeEvent(Event.EVENT_EDIT_COPY_SURE, function(side)
    local tmpPos = {
                x = math.ceil(focusPos.min.x - 0.5),
                y = math.ceil(focusPos.min.y - 0.5),
                z = math.ceil(focusPos.min.z - 0.5)
            }
    cmd:set_chunk(tmpPos, nil, state:brush_obj())
end)

Lib.subscribeEvent(Event.EVENT_EDIT_ROTATE, function(operationType)
    assert(operationType)
    rotateFlag = not rotateFlag
    local brush_class = state:brush_class()
    if brush_class ~= def.TCHUNK then
        return
    end
    local brush_obj = state:brush_obj()
    focusPos.min = {
                x = math.ceil(focusPos.min.x - 0.5),
                y = math.ceil(focusPos.min.y - 0.5),
                z = math.ceil(focusPos.min.z - 0.5)
            }
    local vMin = Lib.copy(focusPos.min)
    local width, longth, height = brush_obj.lx - 1, brush_obj.lz - 1, brush_obj.ly - 1  
    local vMax = Lib.v3add(vMin, {x = width, y = height, z = longth})

    local block_table = engine:calculate_block(vMin, vMax, operationType)
    local flagX = false
    local flagZ = false
    if not engine:isOuNumber(width) then
        vMin.x = vMin.x - 1
        width = width + 1
        flagX = true
    end
    if not engine:isOuNumber(longth) then
        vMin.z = vMin.z - 1
        longth = longth + 1
        flagZ = true
    end
    local dxz = (width - longth) / 2
    local dzx = (longth - width) / 2
    local xz =  (longth + width) / 2
    focusPos.min = Lib.v3add(vMin, {x = dxz, y = 0, z = dzx})
    vMax = Lib.v3add(vMin, {x = xz, y = brush_obj.ly - 1, z = xz})
    focusPos.max = focusPos.min
    focusPos.min.z = (flagX and (focusPos.min.z + 1) or focusPos.min.z)
    focusPos.min.x = (flagZ and (focusPos.min.x + 1) or focusPos.min.x)
    local obj = {obj = {min = focusPos.min, max = vMax, model = block_table}}
    handle_mp_editor_command("showcomponentitem", obj)
end)

Lib.subscribeEvent(Event.EVENT_BUILDING_TOOLS, function()
    data_state.is_can_place = true
    handle_mp_editor_command("focusmode", {mode = "frame"})
    local currentPos = Player.CurPlayer:getPosition()
    on_click_frame(currentPos, {x = 0, y = 0, z = 0})
end)

Lib.subscribeEvent(Event.EVENT_SETTING_POS, function(pos)
    data_state.is_can_place = true
    handle_mp_editor_command("focusmode", {mode = "frame"})
    local currentPos = Player.CurPlayer:getPosition()
    if pos and next(pos) then
        currentPos = pos
    end
    on_click_frame(currentPos, {x = 0, y = 0, z = 0}, true)
end)

local guideEntityObj = nil
Lib.subscribeEvent(Event.EVENT_GUIDE_PLACE_ENTITY, function(pos, isClickEntity)
    if isClickEntity then
        empty_click_entity(guideEntityObj.id)
    else
        on_click_cmd_entity(pos, {x = 0, y = 1, z = 0}, true, {1, 1, 1})
        guideEntityObj = state:focus_obj()
    end

end)

return M
