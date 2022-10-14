local debugport = require "common.debugport"

local lastKeyState	 = L("lastKeyState", {})
local bm			 = Blockman.Instance()
local appState		 = L("appState", {})
local slideTick		 = L("slideTick", 0)
local nextLine		 = L("nextLine", nil)
local slideJumpFlag	 = L("slideJumpFlag", false)
local nextRollTime	 = L("nextRollTime", 0)
local rollBeginTime	 = L("rollBeginTime", 0)
local rollEndTime	 = L("rollEndTime", 0)
local isRolling		 = L("isRolling", false)
local slideTimes	 = L("slideTimes", 0)
local nextTurnTick	 = L("nextTurnTick", 0)
local lastDist		 = L("lastDist", 0)
local lastTouch		 = L("lastTouch", false)

local useJumpProgress = World.cfg.jumpControlConfig and World.cfg.jumpControlConfig.useJumpProgress

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

local nextJumpTime = 0
local jumpBeginTime = 0
local jumpEndTime = 0
local onGround = true
---@param control PlayerControl
---@param player EntityClientMainPlayer
local function checkJump(control, player)
	local playerCfg = player:cfg()
	local worldCfg = World.cfg
    local nowTime = World.Now()
    if onGround ~= player.onGround then  -- aerial landing
        onGround = player.onGround
        if onGround then
			nextJumpTime = nowTime + (playerCfg.jumpInterval or 2)
			if worldCfg.jumpProgressIcon or useJumpProgress then
				Lib.emitEvent(Event.EVENT_UPDATE_JUMP_PROGRESS, {jumpStop = true})
			end
			player.twiceJump = nil
			player.takeoff = false
			jumpBeginTime = 0
        end
    end


   	if bm:getVerticalSlide() > 0 then 
    	bm:setVerticalSlide(0)
    	slideJumpFlag = true
    end
    if PlayerControl.checkJump() or slideJumpFlag then
		local canJump = player.onGround or player:isSwimming()
		local id = player.rideOnId
		local pet
		if id > 0 and not player:isCameraMode() then
			pet = player.world:getEntity(id)
			canJump = pet.onGround or pet:isSwimming()
		end
		if canJump then
			jumpBeginTime = nowTime
			jumpEndTime = nowTime + (playerCfg.maxPressJumpTime or 0)
			if worldCfg.jumpProgressIcon or useJumpProgress  then
				Lib.emitEvent(Event.EVENT_UPDATE_JUMP_PROGRESS, {jumpStart = true, jumpBeginTime = jumpBeginTime, jumpEndTime = jumpEndTime})
			end
		end
		if worldCfg.enableTwiceJump and 0 == jumpEndTime and not player.twiceJump then -- twice jump
			player.twiceJump = true
			if playerCfg.twiceJumpSkill and (nowTime - jumpBeginTime >= (playerCfg.twiceJumpTouchTime or 0) ) then
				Skill.Cast(playerCfg.twiceJumpSkill)
			end
		end
        if nowTime > jumpEndTime or nowTime < nextJumpTime then
        	if slideJumpFlag then slideJumpFlag = false end
            return
		end

		--暂时只对普通的跳跃做前后摇忽略
		if Skill.CanIgnoreBySwing(player,"Jump") then
			return 
		end

		control:jump()
	else
		if worldCfg.jumpProgressIcon or useJumpProgress  then
			Lib.emitEvent(Event.EVENT_UPDATE_JUMP_PROGRESS, {jumpStop = true})
		end
        jumpEndTime = 0
	end
end

--local function改为global function,方便业务根据需求进行覆盖扩展处理
function PlayerControl.checkClickChangeBlock(pos)
	local cfg = Me.map:getBlock(pos)
	if not cfg or not cfg.clickChangeBlock then 
		return false
	end

	local toBlockCfg = Block.GetNameCfg(cfg.clickChangeBlock)
	if toBlockCfg then 
		if Blockman.instance.singleGame then
			Me.map:setBlockConfigId(pos, toBlockCfg.id)
		else
			local packet = {
				pid = "ClickChangeBlock",
				pos = pos,
			}
			Me:sendPacket(packet)
		end
		return true
	else
		print("Error cfg in block "..cfg.fullName..", clickChangeBlock: "..cfg.clickChangeBlock)
	end
	return false
end

local function checkRoll(player)
	local tryRoll = false
	if bm:getVerticalSlide() < 0 then 
		bm:setVerticalSlide(0)
		tryRoll = true
	end

	local nowTime = World.Now()
	if nowTime < nextRollTime then 
		return
	end

	if isRolling and nowTime > rollEndTime then 
		isRolling = false
		return
	end

	if tryRoll and not isRolling then 
		isRolling = true
		local playerCfg = player:cfg()
		local worldCfg = World.cfg

		rollBeginTime = nowTime
		rollEndTime = nowTime + worldCfg.maxRollTime or 0
		nextRollTime = nowTime + worldCfg.rollInterval or 0
		Skill.Cast(playerCfg.rollSkill)
	end
end

local speSinVal = {0,1,0,-1}
local speCosVal = {1,0,-1,0}
local function setNearRunLine(player, left, baseZ, baseX)
	-- local sinYaw = math.sin(-math.rad(player:getRotationYaw()))
	-- local cosYaw = math.cos(-math.rad(player:getRotationYaw()))
	-- if player:getRotationYaw() % 90 == 0 then --math.rad 精度问题导致 math.cos(-math.rad(-90)) ~= 0
	-- 	if math.abs(sinYaw) < 0.00001 then 
	-- 		sinYaw = 0
	-- 	elseif math.abs(cosYaw) < 0.00001 then 
	-- 		cosYaw = 0
	-- 	end
	-- end
	local sinYaw = speSinVal[math.modf((-player:getRotationYaw()) % 360 / 90) + 1]
	local cosYaw = speCosVal[math.modf((-player:getRotationYaw()) % 360 / 90) + 1]
	local tarZ = baseZ - left * sinYaw
	local tarX = baseX + left * cosYaw

	nextLine = {A = sinYaw, B = -cosYaw, C = tarX * cosYaw - tarZ * sinYaw} --直线/平面Az + Bx + C = 0, 左偏时Az + Bx + C > 0
	slideTick = World.CurWorld:getTickCount() --左偏时Az + Bx + C < 0
end

local function setRunLineAfterTurn(player, tarZ, tarX)
	-- local sinYaw = math.sin(-math.rad(player:getRotationYaw()))
	-- local cosYaw = math.cos(-math.rad(player:getRotationYaw()))
	-- if player:getRotationYaw() % 90 == 0 then --math.rad 精度问题导致 math.cos(-math.rad(-90)) ~= 0
	-- 	if math.abs(sinYaw) < 0.00001 then 
	-- 		sinYaw = 0
	-- 	elseif math.abs(cosYaw) < 0.00001 then 
	-- 		cosYaw = 0
	-- 	end
	-- end
	local sinYaw = speSinVal[math.modf((-player:getRotationYaw()) % 360 / 90) + 1]
	local cosYaw = speCosVal[math.modf((-player:getRotationYaw()) % 360 / 90) + 1]
	nextLine = {A = sinYaw, B = -cosYaw, C = tarX * cosYaw - tarZ * sinYaw}
end

local lastMoveStatus = {forward = 0, left = 0, isMoving = false}
local function checkMovingChange(control, player, forward, left)
	local playerCfg = player:cfg()
	local movingChangeStatusSkill = playerCfg.movingChangeStatusSkill
	if movingChangeStatusSkill and (((lastMoveStatus.forward == 0 and lastMoveStatus.left == 0) and (forward ~= 0 or left ~= 0)) -- 按键变化(比如刹车动作需要放开按键)
		 or ((lastMoveStatus.forward ~= 0 or lastMoveStatus.left ~= 0) and (forward == 0 and left == 0))) then
		Skill.Cast(movingChangeStatusSkill)
		lastMoveStatus.forward = forward
		lastMoveStatus.left = left
	end
	local movingChangeSkill = playerCfg.movingChangeSkill
	if movingChangeSkill and lastMoveStatus.isMoving ~= player.isMoving then -- 实际移动状态变化
		Skill.Cast(movingChangeSkill)
		lastMoveStatus.isMoving = player.isMoving
	end
end

local lockVisionCfg = World.cfg.lockVision
local function CheckSlideScreen(player)
	if not (lockVisionCfg and lockVisionCfg.open) then 
		bm:setVerticalSlide(0)
		bm:setHorizonSlide(0)
		return
	end 
	if not player:getValue("canSlide") then 
		bm:setVerticalSlide(0)
		bm:setHorizonSlide(0)
		return
	end
	
	local verticalSlide = bm:getVerticalSlide()
	local horizonSlide = bm:getHorizonSlide()
	if slideTimes > 0 then 
		if TouchManager.Instance():getSceneTouch1() then --一次长按屏幕仅允许一次有效滑动
			verticalSlide = 0
			horizonSlide = 0
			lastTouch = true
		elseif lastTouch then 
			verticalSlide = 0
			horizonSlide = 0
			lastTouch = false
		else
			slideTimes = 0
		end
	end

	if player.isFlying then 
		verticalSlide = 0
	end
	if verticalSlide ~= 0 and math.abs(verticalSlide) < (lockVisionCfg.touchDist or 20) then --忽略小幅度滑动
		verticalSlide = 0
	end
	if horizonSlide ~= 0 and math.abs(horizonSlide) < (lockVisionCfg.touchDist or 20) then 
		horizonSlide = 0
	end

	if math.abs(verticalSlide) > 0 or math.abs(horizonSlide) > 0 then 
		slideTimes = slideTimes + 1
	end
	if math.abs(verticalSlide) > math.abs(horizonSlide) then --一次滑屏只允许一个动作
		horizonSlide = 0
	else
		verticalSlide = 0
	end
	bm:setVerticalSlide(verticalSlide)
	bm:setHorizonSlide(horizonSlide)
end

local function doHorizonSlide(player, left, forward)
	local horizonSlide = bm:getHorizonSlide()
	local slideDir = -Lib.sgn(horizonSlide)
	local changeLine = slideDir ~= 0
	local nowPos = player:getPosition()
	if changeLine then 
		if World.CurWorld:getTickCount() - slideTick < (lockVisionCfg.senseTick or 5) then --一定距离内同向滑动
			changeLine = false
		end
		bm:setHorizonSlide(0)
	end
	if not nowPos then 
		return 0,0
	end
	local _, regionTurnDir = player.map:getRegionValue(nowPos, "slideTurnDir")
	if slideDir ~= 0 and regionTurnDir then --触发转向
		if World.Now() > nextTurnTick and regionTurnDir == slideDir then 
			player:addYawOrPitch(-slideDir * 90, 0)
			nextTurnTick = World.Now() + 11
			setRunLineAfterTurn(player, math.floor(nowPos.z) + 0.5, math.floor(nowPos.x) + 0.5)
		end
	elseif nextLine ~= nil then -- 移动到目标线/面
		local distance = (nowPos.z * nextLine.A + nowPos.x * nextLine.B + nextLine.C) --A^2+B^2=1 距离公式不需要该部分 / math.sqrt(nextLine.A*nextLine.A+nextLine.B*nextLine.B)
		lastDist = distance
		if math.abs(distance) < 0.1 or Lib.sgn(distance) * Lib.sgn(lastDist) < -1 then --接近或者越过目标线
			if nextLine.A ~= 0 then 
				nowPos.z = (nextLine.A * nowPos.z - nextLine.B * nowPos.x - nextLine.C) / (2 * nextLine.A)
			end
			if nextLine.B ~= 0 then 
				nowPos.x = (- nextLine.A * nowPos.z + nextLine.B * nowPos.x - nextLine.C) / (2 * nextLine.B)
			end
			
			local motion = player.motion
			motion.x = 0
			motion.z = 0
			player.motion = motion

			player:setPosition(nowPos) --接近目标时求出一个最近点并设置为当前位置
			nextLine = nil
			left = 0
			forward = 0
		else
			if changeLine then --以上一次的目标路线为当前路线,设置新的目标路线
				left = Lib.sgn(slideDir) * lockVisionCfg.slideWidth
				local zOnNextLine = -nextLine.C * nextLine.A
				local xOnNextLine = -nextLine.C * nextLine.B

				setNearRunLine(player, left, zOnNextLine, xOnNextLine)
			else
				left = Lib.sgn(distance) * lockVisionCfg.slideWidth
				forward = lockVisionCfg.slideWidth * math.tan(math.rad(90 - lockVisionCfg.slideAngle))
			end
		end
	elseif slideDir ~= 0 then --变道
		left = Lib.sgn(slideDir) * lockVisionCfg.slideWidth
		setNearRunLine(player, left, nowPos.z, nowPos.x)
	elseif lockVisionCfg and lockVisionCfg.open then 
		left = 0
	end
	return left, forward
end

local inSprint = nil
local function checkSprintEvent(movingStyle, isMoving, forward, left)
	if not World.cfg.enableSprintEvent then
		return
	end
	local bmGameSettings = bm.gameSettings
	local fov = bmGameSettings:getFovSetting()
	if not inSprint and isMoving and movingStyle == 2 then
		Lib.emitEvent(Event.BEGIN_SPRINT, forward, left)
		inSprint = true
	elseif inSprint and (not isMoving or movingStyle ~= 2) then
		Lib.emitEvent(Event.END_SPRINT, forward, left)
		inSprint = nil
	end
end

function PlayerControl.checkSprint()
	if (Player.CurPlayer:prop().sprintSpeed or 0) > 0 then
		return true
	end
	return false
end

function PlayerControl.checkSneak()
	return bm:isKeyPressing("key.sneak")
end

function PlayerControl.checkJump()
	return bm:isKeyPressing("key.jump")
end

function PlayerControl.checkFloatUp()
	return bm:isKeyPressing("key.floatUp")
end

function PlayerControl.checkFloatDown()
	return bm:isKeyPressing("key.floatDown")
end

local sceneManager = World.CurWorld:getSceneManager()

local worldCfgViewBobbing = World.cfg.viewBobbing
function PlayerControl.UpdateControl(frame_time)
	local player = Player.CurPlayer
	local control = bm:control() ---@type PlayerControl

	if player.disableControl then
		control:setMove(0, 0)
		return
	end

	FrontSight.checkHit(player)
	local movingStyle = 0
	if PlayerControl.checkSneak() then
		movingStyle = 1
	elseif PlayerControl.checkSprint() then
		movingStyle = 2
	end

	if World.cfg.bobbingCameraEffect == false then
		bm.gameSettings.bobbingCameraEffect = false
	end

	if player and player.movingStyle~=movingStyle then
		player:setValue("movingStyle", movingStyle)
		bm.gameSettings.viewBobbing = worldCfgViewBobbing or false
	end

	if isKeyNewDown("key.f5") then
		bm:switchPersonView()
		PlayerControl.UpdatePersonView()
	end
    if isKeyNewDown("key.f1") and World.gameCfg.gm then
        Lib.emitEvent(Event.EVENT_SHOW_GMBOARD)
    end
	if isKeyNewDown("key.f11") and World.gameCfg.debug then
		if movingStyle==0 then
            Game.RunTelnet(1, debugport.port)
		else
            Game.RunTelnet(2, debugport.serverPort)
		end
	end
	if (isKeyNewDown("key.exit") or isKeyNewDown("key.android.back")) and not (UI.guideMask and next(UI.guideMask)) then
		Lib.emitEvent(Event.EVENT_BACK_KEY_DOWN)
	end

	if isKeyNewDown("key.chat") then
		Lib.emitEvent(Event.EVENT_CHAT_KEY_DOWN)
	end

	if isKeyNewDown("key.pack") and not World.cfg.disableKeyPack then
		Lib.emitEvent(Event.EVENT_MAIN_ROLE, true)
	end

	if isKeyNewDown("key.mouse_state") then
		Lib.emitEvent(Event.EVENT_CHANGE_MOUSE_STATE)
	end

	local poleForwar = bm.gameSettings.poleForward
	local poleStrafe = bm.gameSettings.poleStrafe

	local forward = axisValue("key.forward", "key.back") + poleForwar
	if bm:isKeyPressing("key.top.left") or bm:isKeyPressing("key.top.right") then
		forward = forward + 1
	end

	if bm:isKeyPressing("key.bottom.left") or bm:isKeyPressing("key.bottom.right") then
		forward = forward - 1
	end

	if player and player:getValue("isKeepAhead") then 
		forward = 1
	end

	local left = 0.0
	if not (World.cfg.moveOneAxisOnly and math.abs(forward) > 0)  then
		left = axisValue("key.left", "key.right") + poleStrafe + axisValue("key.top.left", "key.top.right") + axisValue("key.bottom.left", "key.bottom.right")
	end

	if not player then
		if forward~=0 or left~=0 then
			local sinYaw = math.sin(math.rad(bm:getViewerYaw()))
			local cosYaw = math.cos(math.rad(bm:getViewerYaw()))
			local MOVE_SPEED = 0.2
			local pos = Lib.tov3(bm:getViewerPos())
			pos.x = pos.x + (left * cosYaw - forward * sinYaw) * MOVE_SPEED
			pos.z = pos.z + (left * sinYaw + forward * cosYaw) * MOVE_SPEED
			bm:setViewerPos(pos, bm:getViewerYaw(), bm:getViewerPitch(), 1)
		end
		return
	end

	CheckSlideScreen(player, left, forward)
	left, forward = doHorizonSlide(player, left, forward)
	checkRoll(player)
	forward = isRolling and 1 or forward
	player:refreshFloatData()
	local floatData = player and player:data("floatSkill") or nil
	local control = bm:control() ---@type PlayerControl
	control:setVerticalSpeed(0)
	if World.CurWorld.isEditor then
		PlayerControl.do_move()
	elseif player.cameraEditModeCtrl then
		PlayerControl.do_edit_move()
	elseif floatData and next(floatData) then
		if bm:isKeyPressing("key.floatUp") then 
			control:setVerticalSpeed(1)
			player:setFloatMode(Define.SkillFloatType.Free)
			if Skill.CanIgnoreBySwing(player,"Move") then
				--设置前后摇忽略移动
				control:setMove(0, 0)
			else
				control:setMove(forward, left)
			end
			--移动打断前后摇
			if forward ~= 0 or left ~= 0 then
				Skill.BreakSwingByMove(player,false)
			end
		elseif bm:isKeyPressing("key.floatDown") then 
			control:setVerticalSpeed(-1)
			player:setFloatMode(Define.SkillFloatType.Free)
			if Skill.CanIgnoreBySwing(player,"Move") then
				--设置前后摇忽略移动
				control:setMove(0, 0)
			else
				control:setMove(forward, left)
			end
			--移动打断前后摇
			if forward ~= 0 or left ~= 0 then
				Skill.BreakSwingByMove(player,false)
			end
		else 
			local floatType = Define.SkillFloatType.None
			if floatData[Define.SkillFloatType.Free]  then 
				floatType = Define.SkillFloatType.Free
			end
			if floatData[Define.SkillFloatType.Direction] then 
				if left ~= 0 or forward ~= 0 then 
					if floatType == Define.SkillFloatType.Free then
						floatType = Define.SkillFloatType.ALL
					else 
						floatType = Define.SkillFloatType.Direction
					end
				else
					floatType = Define.SkillFloatType.Direction
					if not floatData[Define.SkillFloatType.Direction].isPressJoystickMove then 
						forward = 1
					end
				end
			end
			player:setFloatMode(floatType)
			if Skill.CanIgnoreBySwing(player,"Move") then
				--设置前后摇忽略移动
				control:setMove(0, 0)
			else
				control:setMove(forward, left)
			end
			--移动打断前后摇
			if forward ~= 0 or left ~= 0 then
				Skill.BreakSwingByMove(player,false)
			end
		end
	else
		player:setFloatMode(Define.SkillFloatType.None)
		if Skill.CanIgnoreBySwing(player,"Move") then
			--设置前后摇忽略移动
			control:setMove(0, 0)
		else
			control:setMove(forward, left)
		end
		--移动打断前后摇
		if forward ~= 0 or left ~= 0 then
			Skill.BreakSwingByMove(player,false)
		end
	end
	if player:isDead() then
		Skill.DoBreakSwing(player,"Dead")
	end
	control:setBraking(bm:isKeyPressing("key.brake"))

	if not player:isSwimming() and (forward~= 0 or left ~= 0) and player.curHp > 0 and player.rideOnId > 0 and player.rideOnId > 0 or player.onGround and player.isMoving then
		FrontSight.Diffuse(nil, 2)
	end

	if floatData and next(floatData) then 
	else
		PlayerControl.checkJump_impl(control, player)
		checkSprintEvent(movingStyle, player.isMoving, forward, left)

		if isKeyNewDown("key.jump") then
			local name = player:data("skill").jumpSkill
			if name then
				Skill.Cast(name)
			end
		end
	end

	local act = bm:getUserAction().action
	if not checkNewState("act", act) and act~="CLICK" and act~="TOUCH_BEGIN" then
		return
	end
	local hit = bm:getHitInfo()
	local packet = {}
	if hit.type=="ENTITY" then
		local entity = hit.entity
		packet.targetID = entity.objID
		packet.targetPos = entity:getPosition()
		packet.hitPos = hit.worldPos
	elseif hit.type=="PART" then
		local part = hit.part
		packet.partID = (part and part:isValid() and part:getInstanceID()) or -1
		packet.hitPos = hit.worldPos
	elseif hit.type=="BLOCK" then
		packet.blockPos = hit.blockPos
		packet.sideNormal = hit.sideNormal
		if packet.sideNormal then
			packet.isUp = (packet.sideNormal.y == 0.0 and (hit.worldPos.y - hit.blockPos.y) > 0.5) or (packet.sideNormal.y == -1.0)
		end
	end
	if act=="CLICK" then
		PlayerControl.processClick(hit, packet)
		Lib.emitEvent(Event.EVENT_CLICK_ENTITY, hit.entity)
	elseif act=="TOUCH_BEGIN" then
		packet.touchAtScene = true
		Skill.TouchBegin(packet)
	elseif act=="TOUCH_END" then
		Skill.TouchEnd(packet)
	end
end

--点击处理逻辑独立出来，方便业务根据需求进行覆盖扩展处理
function PlayerControl.processClick(hit, packet)
	if not hit then
		return
	end

	Skill.ClickCast(packet)
	
	if hit.type == "BLOCK"  then
		PlayerControl.checkClickChangeBlock(packet.blockPos)
	end
end

function PlayerControl.checkJump_impl(control, player)
	checkJump(control, player)
end

function PlayerControl.UpdatePersonView()
	local view = bm:getCurrPersonView()
	local entity =  bm:viewEntity()
	if view==0 and entity and entity:cfg().canFirstView==false then
		bm:switchPersonView()
	end
end

function PlayerControl.do_edit_move()
	local player = Player.CurPlayer
	if not player then
		return
	end
	local nextPos = nil
	local poleForwar = bm.gameSettings.poleForward
	local poleStrafe = bm.gameSettings.poleStrafe
	local forward = axisValue("key.forward", "key.back") +poleForwar
	if bm:isKeyPressing("key.top.left") or bm:isKeyPressing("key.top.right") then
		forward = forward + 1
	end
	local left = axisValue("key.left", "key.right") + axisValue("key.top.left", "key.top.right") + poleStrafe
	local up = axisValue("key.jump", "key.sneak")
	nextPos = player:getPosition()

	if forward== 0.0 and left== 0.0 and up== 0.0 then
		player.isMoving = false
		return
	end
	local MOVE_SPEED = player.camaraModeSpd or 0.2
	local rotationYaw = math.rad(player:getRotationYaw())
	local f1 = math.sin(rotationYaw)
	local f2 = math.cos(rotationYaw)
	nextPos.x = nextPos.x + (left * f2 - forward * f1) * MOVE_SPEED
	nextPos.z = nextPos.z + (forward * f2 + left * f1) * MOVE_SPEED
	nextPos.y = nextPos.y + up * MOVE_SPEED
	player:setMove(0, nextPos, player:getRotationYaw(), player:getRotationPitch(), 1, 0)
	player.isMoving = true
end

function PlayerControl.do_move()
	local player = Player.CurPlayer
	if not player then
		Lib.logDebug("do moveeeeeeeeeeeeeeeeeeeeeeeeeeee error no player")
		return
	end
	Lib.logDebug("do moveeeeeeeeeeeeeeeeeeeeeeeeeeee start", player.objID, player.platformUserId)
	local nextPos = nil
	local poleForwar = bm.gameSettings.poleForward
	local poleStrafe = bm.gameSettings.poleStrafe
	local forward = axisValue("key.forward", "key.back") + poleForwar
	if bm:isKeyPressing("key.top.left") or bm:isKeyPressing("key.top.right") then
		forward = forward + 1
	end
	local left = axisValue("key.left", "key.right") + axisValue("key.top.left", "key.top.right") + poleStrafe
	local up = axisValue("key.rise", "key.descend")
	nextPos = player:getPosition()

	if forward== 0.0 and left== 0.0 and up== 0.0 then
		player.isMoving = false
		Lib.logDebug("do moveeeeeeeeeeeeeeeeeeeeeeeeeeee end no moving")
		return
	end

	local rotationYaw = math.rad(player:getRotationYaw())
	local rotationPitch = math.rad(player:getRotationPitch())
	local f1 = math.sin(rotationYaw)
	local f2 = math.cos(rotationYaw)
	local f3 = math.sin(rotationPitch)
	local MOVE_SPEED = 0.2

	nextPos.x = nextPos.x + (left * f2 - forward * f1) * MOVE_SPEED
	nextPos.z = nextPos.z + (forward * f2 + left * f1) * MOVE_SPEED
	if up ~= 0.0 then
		nextPos.y = nextPos.y + (up - forward * f3) * MOVE_SPEED
	end
	player:setMove(0, nextPos, player:getRotationYaw(), player:getRotationPitch(), 1, 0)
	player.isMoving = true
	Lib.logDebug("do moveeeeeeeeeeeeeeeeeeeeeeeeeeee end success")
end

function PlayerControl.OnRebirth()
	nextLine = nil
end

function PlayerControl.OnTouchBlock(player, pos)
	if lockVisionCfg.collideBack then 
		-- local sinYaw = speSinVal[math.modf((-player:getRotationYaw()) % 360 / 90) + 1]
		local cosYaw = speCosVal[math.modf((-player:getRotationYaw()) % 360 / 90) + 1]
		-- local dz = -sinYaw
		local dx = cosYaw
		local pPos = player:getPosition()
		if (math.floor(pPos.x) + dx == pos.x) or (math.floor(pPos.x) - dx == pos.x) then 
			setNearRunLine(player, 0, math.floor(pPos.z) + 0.5, math.floor(pPos.x) + 0.5)
		end
	end
end

local pauseWhenOpenCfg = World.cfg.pauseWhenOpen
function PlayerControl.CheckUIOpenPauseGame(name, state)
	if pauseWhenOpenCfg and pauseWhenOpenCfg[name] and World.CurWorld:isGamePause() == not state then 
		local newMainUI = UI:getWnd("newmainuinavigation", true)
		if newMainUI and newMainUI.pause and newMainUI.pause.show then --TODO: is Visible condition needed?
			Lib.emitEvent(Event.EVENT_PAUSE_BY_CLIENT)
			-- Me:setValue("isKeepAhead", not state)
		end
	end
end

function PlayerControl.UpdateControlInfo(target)
    local control = bm:control()
    local player = Player.CurPlayer
    if target and not player:isCameraMode() then
        local pos = target:cfg().ridePos[player.rideOnIdx + 1]
        control:attach(target)
        control.enable = pos.ctrl
        bm:setViewEntity(pos.view and target or player)
    else
        control:attach(player)
        control.enable = true
        bm:setViewEntity(player)
    end
end

RETURN()
