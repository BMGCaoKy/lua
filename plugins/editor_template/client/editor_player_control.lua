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

local function pcKeyBindCheck(flag)
	if not flag then
		return	
	end
	if isKeyNewDown("key.mouse_state") then
		Lib.emitEvent(Event.EVENT_CHANGE_MOUSE_STATE)
	end
end

local nextJumpTime = 0
local jumpBeginTime = 0
local jumpEndTime = 0
local onGround = true
local function checkJump(control, player)
	local playerCfg = player:cfg()
	local worldCfg = World.cfg
    local nowTime = World.Now()
    if onGround ~= player.onGround then  -- aerial landing
        onGround = player.onGround
        if onGround then
			nextJumpTime = nowTime + (playerCfg.jumpInterval or 2)
			if worldCfg.jumpProgressIcon then
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
    if bm:isKeyPressing("key.jump") or slideJumpFlag then 
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
			if worldCfg.jumpProgressIcon then
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

		control:jump()
	else
		if worldCfg.jumpProgressIcon then
			Lib.emitEvent(Event.EVENT_UPDATE_JUMP_PROGRESS, {jumpStop = true})
		end
        jumpEndTime = 0
	end
end

local function checkClickChangeBlock(pos)
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


function PlayerControl.UpdateControl()
	local player = Player.CurPlayer

	FrontSight.checkHit(player)
	local movingStyle = 0
	if bm:isKeyPressing("key.sneak") then
		movingStyle = 1
	end
	
	if (player:prop().sprintSpeed or 0) > 0 then
		movingStyle = 2
	end

	if player and player.movingStyle~=movingStyle then
		player:setValue("movingStyle", movingStyle)
	end

	if isKeyNewDown("key.f5") then
		bm:switchPersonView()
		PlayerControl.UpdatePersonView()
	end
    if isKeyNewDown("key.f1") then
        Lib.emitEvent(Event.EVENT_SHOW_GMBOARD)
    end
	if isKeyNewDown("key.f11") then
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

	if isKeyNewDown("key.pack") then
		Lib.emitEvent(Event.EVENT_MAIN_ROLE, true)
	end

	local poleForwar = bm.gameSettings.poleForward
	local poleStrafe = bm.gameSettings.poleStrafe

	local forward = axisValue("key.forward", "key.back") + poleForwar
	if bm:isKeyPressing("key.top.left") or bm:isKeyPressing("key.top.right") then
		forward = forward + 1
	end

	if player and player:getValue("isKeepAhead") then 
		forward = 1
	end

	local left = 0.0
	if not (World.cfg.moveOneAxisOnly and math.abs(forward) > 0)  then
		left = axisValue("key.left", "key.right") + poleStrafe + axisValue("key.top.left", "key.top.right")
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
	local control = bm:control()
	control:setMove(forward, left)
	control:setBraking(bm:isKeyPressing("key.brake"))

	if not player:isSwimming() and (forward~= 0 or left ~= 0) and player.curHp > 0 and player.rideOnId > 0 and player.rideOnId > 0 or player.onGround and player.isMoving then
		FrontSight.Diffuse(nil, 2)
	end	

	checkJump(control, player)
	checkSprintEvent(player.movingStyle, player.isMoving, forward, left)

	if isKeyNewDown("key.jump") then
		local name = player:data("skill").jumpSkill
		if name then
			Skill.Cast(name)
		end
	end

	pcKeyBindCheck(CGame.instance:getPlatformId() == 1 and (not CGame.instance:isShowPlayerControlUi())) --only pc
	
	local hit = bm:getHitInfo()
	local act = hit.action
	if not checkNewState("act", act) and act~="CLICK" and act~="TOUCH_BEGIN" then
		return
	end
	local packet = {}
	if hit.type=="ENTITY" then
		local entity = hit.entity
		packet.targetID = entity.objID
		packet.targetPos = entity:getPosition()
	elseif hit.type=="BLOCK" then
		packet.blockPos = hit.blockPos
		packet.sideNormal = hit.sideNormal
	end
	if act=="CLICK" then
		if hit.type == "BLOCK" and checkClickChangeBlock(packet.blockPos) then 
		else
			Skill.ClickCast(packet)
		end
	elseif act=="TOUCH_BEGIN" then
		packet.touchAtScene = true
		Skill.TouchBegin(packet)
	elseif act=="TOUCH_END" then
		Skill.TouchEnd(packet)
	end
end

function PlayerControl.UpdatePersonView()
	local view = bm:getCurrPersonView()
	local entity =  bm:viewEntity()
	if view==0 and entity and entity:cfg().canFirstView==false then
		bm:switchPersonView()
	end
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

RETURN()
