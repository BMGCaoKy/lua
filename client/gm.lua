
require "common.gm"
local setting = require "common.setting"
local debugport = require "common.debugport"
local mri = require("common.util.MemoryReferenceInfo")
local uiLogger = require 'ui.ui_hover_logger'
local LuaTimer = T(Lib, "LuaTimer") ---@type LuaTimer

-- Set config.
mri.m_cConfig.m_bAllMemoryRefFileAddTime = false
--mri.m_cConfig.m_bSingleMemoryRefFileAddTime = false
--mri.m_cConfig.m_bComparedMemoryRefFileAddTime = false

GM.itemsShowPriorityMap = {
    ["PART"] = 1000,
}

local itemShowPriorityIndex = 1000
local function getItemShowPriorityIndex()
    itemShowPriorityIndex = itemShowPriorityIndex - 1
    return itemShowPriorityIndex
end

GM.itemShowPriorityMap = {
    ["LuaProfiler"] = {
        ["开启C性能统计"] = getItemShowPriorityIndex(),
        ["关闭C性能统计"] = getItemShowPriorityIndex(),
        ["导出C性能统计"] = getItemShowPriorityIndex(),
        ["开启S性能统计"] = getItemShowPriorityIndex(),
        ["关闭S性能统计"] = getItemShowPriorityIndex(),
        ["导出S性能统计"] = getItemShowPriorityIndex(),

        ["client start"] = getItemShowPriorityIndex(),
        ["client stop"] = getItemShowPriorityIndex(),
        ["client dump"] = getItemShowPriorityIndex(),
        ["server start"] = getItemShowPriorityIndex(),
        ["server stop"] = getItemShowPriorityIndex(),
        ["server dump"] = getItemShowPriorityIndex(),

        ["C内存分析"] = getItemShowPriorityIndex(),
        ["C内存清理"] = getItemShowPriorityIndex(),
        ["S内存分析"] = getItemShowPriorityIndex(),
        ["S内存清理"] = getItemShowPriorityIndex(),
        ["控制台client"] = getItemShowPriorityIndex(),
        ["控制台server"] = getItemShowPriorityIndex(),

        ["统计C网络包"] = getItemShowPriorityIndex(),
        ["显示C网络包"] = getItemShowPriorityIndex(),
        ["统计S网络包"] = getItemShowPriorityIndex(),
        ["显示S网络包"] = getItemShowPriorityIndex(),
        ["lua C内存占用"] = getItemShowPriorityIndex(),
        ["lua S内存占用"] = getItemShowPriorityIndex(),

        ["C 1-Before"] = getItemShowPriorityIndex(),
        ["C 2-After"] = getItemShowPriorityIndex(),
        ["C ComparedFile"] = getItemShowPriorityIndex(),
        ["S 1-Before"] = getItemShowPriorityIndex(),
        ["S 2-After"] = getItemShowPriorityIndex(),
        ["S ComparedFile"] = getItemShowPriorityIndex(),

        ["LuaProfiler/C 性能统计n帧"] = getItemShowPriorityIndex(),
        ["C Statistics"] = getItemShowPriorityIndex(),
        ["C PrintResults"] = getItemShowPriorityIndex(),
        ["S Statistics"] = getItemShowPriorityIndex(),
        ["S PrintResults"] = getItemShowPriorityIndex(),

        ["C LuaMemState"] = getItemShowPriorityIndex(),
        ["S LuaMemState"] = getItemShowPriorityIndex(),
        ["打开 Profiler"] = getItemShowPriorityIndex(),
        ["关闭 Profiler"] = getItemShowPriorityIndex(),
    },
}

function GM.setItemsShowPriorityMap(key, value)
    GM.itemsShowPriorityMap[key] = value
end

function GM.setItemShowPriorityMap(key, value)
    GM.itemShowPriorityMap[key] = value
end

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

function GM:click(key)
    if GM.call(self, key) then
        return
    end
    self:sendPacket({
        pid = "GM",
        typ = "GMCall",
        key = key,
    })
end

function GM:input(key, value)
    GM.inputBoxCallBack(self, {key = key, value = value})
end

local showErrMsgToChatBar = GM.isOpen
function GM:sendErrMsgToChatBar(msg)
    if showErrMsgToChatBar then
        Lib.emitEvent(Event.EVENT_CHAT_MESSAGE, msg)
    end
end

function GM:listCallBack(item)
    self:sendPacket({pid = "GM", typ = "ListCallBack", item = item})
end

--------------------------------------------------------------------------------------------------------------------

local function testDecal(part)
    local decal = Instance.Create("Decal")
    decal:setSurface(4)
    decal:setTexture("100008_pine_stage_4.png")
    decal:setParent(part)
    -- decal:setProperty("decalColor", "r:1 g:0 b:0 a1")
    decal:setProperty("decalAlpha", "0.2")

    -- local decal = Instance.Create("Decal")
    -- decal:setSurface(1)
    -- decal:setTexture("redstone_torch_off.png")
    -- decal:setParent(part)

    -- local decal = Instance.Create("Decal")
    -- decal:setSurface(2)
    -- decal:setTexture("redstone_torch_off.png")
    -- decal:setParent(part)

    -- local decal = Instance.Create("Decal")
    -- decal:setSurface(3)
    -- decal:setTexture("glass_orange.png")
    -- decal:setParent(part)

    -- local decal = Instance.Create("Decal")
    -- decal:setSurface(4)
    -- decal:setTexture("glass_magenta.png")
    -- decal:setParent(part)

    -- local decal = Instance.Create("Decal")
    -- decal:setSurface(5)
    -- decal:setTexture("glass_red.png")
    -- decal:setParent(part)
end

local function face2Pos(target)
	local cur = Me:getPosition()
	if cur then
		Me:setRotationYaw(Lib.v3AngleXZ(Lib.v3cut(target, cur)))
	end
end

local show_fps = false
local show_parts = false
local show_gameInfo = false
local _density = 0
local relative = "true"
local function TEST2(useType)
	local self = Me
	local manager = World.CurWorld:getSceneManager()
	local scene = manager:getOrCreateScene(self.map.obj)
	manager:setCurScene(scene)
	local pos = self:getFrontPos(1, true, true) + Lib.v3(0, 0.5, 2)
    local rolePos = self:getPosition()
    local roleEye = self:getEyePos()
    self.scene = scene
    self.part2 = Instance.Create("Part")
    self.part2:setPosition(pos)
    self.part2:setDensity(_density)
    self.part2:setParent(scene:getRoot())
    self.part2:setShape(2)
    -- Me:setFlyMode(1)
    local obj = GizmoTransformRotate:create()
    manager:setGizmo(obj)
    obj:setPosition(pos)
    obj:setNode(self.part2)
    obj:setShowAxis(2)
    -- self.part2:setMaterialPath("g2030_yinghua_1.tga")
    -- self.part2:setProperty("materialColor", "r:1 g:0 b:0 a:1")
    -- self.part2:setProperty("radialSegments", "4")
    -- self.part2:setProperty("rings", "2")
    -- face2Pos(pos)
end

local function TEST3(useType)
	local self = Me
	local manager = World.CurWorld:getSceneManager()
	local scene = manager:getOrCreateScene(self.map.obj)
	manager:setCurScene(scene)
	local pos = self:getFrontPos(1, true, true) + Lib.v3(0, 0.5, 2)
    local rolePos = self:getPosition()
    local roleEye = self:getEyePos()
    self.scene = scene
    self.part2 = Instance.Create("MeshPart")
    self.part2:setPosition(pos)
    self.part2:setProperty("mesh", "yuanhuan.mesh")
    self.part2:setParent(scene:getRoot())

    face2Pos(pos)
end

local function TEST1(useType)
	local self = Me
	local manager = World.CurWorld:getSceneManager()
	local scene = manager:getOrCreateScene(self.map.obj)
	manager:setCurScene(scene)
	self.scene = scene
	local pos = self:getFrontPos(1, true, true) + Lib.v3(0, 0, 5)
	local part = Instance.Create("Model")
	
    part:setPosition(pos)
	part:setParent(scene:getRoot())
    
    local part1 = Instance.Create("Part")
	part1:setParent(part)
	part1:setPosition(pos)
    part1:setMaterialPath("part_zhuankuai.tga")
    part1:setShape(4)
    
    local part2 = Instance.Create("Part")
	part2:setParent(part)
	part2:setPosition(pos + Lib.v3(1, 1, 0))
    part2:setMaterialPath("part_zhuankuai.tga")
    part2:setShape(1)
	
	self.part2 = part
end

GMItem["PART/添加一个"] = function()
    TEST2()
end




GMItem["PART/TEST1"] = function()
    TEST1()
end
GMItem["PART/TEST3"] = function()
    TEST3()
end

local part0, part1, sceneRoot, pos

GMItem["PART/CSG测试"] = function()
    local manager = World.CurWorld:getSceneManager()
    sceneRoot = manager:getOrCreateScene(Me.map.obj):getRoot()
    
    pos = Me:getFrontPos(1, true, true) + Lib.v3(5,2,0)

    local head2 = Instance.Create("Part")
    head2:setShape(2)
    head2:setSize(Lib.v3(4,4,4))
    head2:setPosition(pos)
    head2:setParent(sceneRoot)
    
    local body1 = Instance.Create("Part")
    body1:setShape(1)
    body1:setSize(Lib.v3(2,2,4))
    body1:setPosition(pos)
    body1:setParent(sceneRoot)

    local body2 = Instance.Create("Part")
    body2:setShape(1)
    body2:setSize(Lib.v3(6,6,2))
    body2:setPosition(pos)
    body2:setParent(sceneRoot)

    local op = head2:reversePart({body2, body1})
    op:setMaterialPath("part_zhuankuai.tga")
    -- testDecal(op)
    Me.part2 = op
    face2Pos(pos)
end

GMItem["PART/开启飞行"] = function()
    Me:setFlyMode(1)
    Me:setPosition(Me:getPosition() + Lib.v3(0, 5, 0))
end

GMItem["PART/关闭飞行"] = function()
    Me:setFlyMode(0)
    Me:setPosition(Me:getPosition() + Lib.v3(0, -5, 0))
end

local draw = false
local debugDraw = DebugDraw.instance

GMItem["PART/画框"] = function()
    draw = not draw
    debugDraw:setEnabled(draw)
    debugDraw:setDrawPartAABBEnabled(draw)
end

local function createPart(position, shapeType, sizeScale, propertyList)
	--CUBE = 1,
	--SPHERE,
	--CYLINDER,
	--CIRCULAR_CONE,
	local part
	local manager = World.CurWorld:getSceneManager()
	local scene = manager:getOrCreateScene(Me.map.obj)
	manager:setCurScene(scene)
	local part = Instance.Create("Part")
	part:setSize(sizeScale)
    part:setShape(shapeType)
	for k, v in pairs(propertyList or {}) do
		part:setProperty(k, v)
	end
	part:setParent(scene:getRoot())
    part:setPosition(position)

	return part
end



GMItem["PART/Physx测试"] = GM:inputNumber(function(self, num)
    local cur = 0
    World.Timer(3, function()
        local pos1 = self:getPosition() + Lib.v3(0, 5, 0)
        local part1 = createPart(pos1, 1, Lib.v3(1,1,1), {
	        useAnchor = "false",
        })
        cur = cur + 1
        if cur < num then
            return true
        end
        return false
    end)
end, 200)

GMItem["PART/Physx约束测试"] = GM:inputNumber(function(self, num)
    local pos1 = self:getPosition() + Lib.v3(0, 5, 0)
    local part1 = createPart(pos1, 1, Lib.v3(1,1,1), {
	    useAnchor = "true",
    })

    local pos2 = self:getPosition() + Lib.v3(0, 6, 0)
    local part2 = createPart(pos2, 1, Lib.v3(1,1,1), {
	    useAnchor = "false",
    })
    self.map:getPhysicsWorld():createPointJoint(part1, part2)
end, 200)


GMItem["PART/Physx链条"] = GM:inputNumber(function(self, num)
    local pos1 = self:getPosition() + Lib.v3(0, 5, 0)
    local part1 = createPart(pos1, 1, Lib.v3(1,1,1), {
	    useAnchor = "true",
    })

    local parentPart = part1
    local lastPos = pos1
    for i = 0, 5 do
        local pos2 = lastPos + Lib.v3(0, -1, 0)
        local part = createPart(pos2, 1, Lib.v3(0.3,1,0.1), {
	        useAnchor = "false",
        })
        self.map:getPhysicsWorld():createPointJoint(parentPart, part)
        parentPart = part
        lastPos = pos2
    end

end, 200)


GMItem["PART/Physx链条高质量比"] = GM:inputNumber(function(self, num)
    local pos1 = self:getPosition() + Lib.v3(0, 5, 0)
    local part1 = createPart(pos1, 1, Lib.v3(1,1,1), {
	    useAnchor = "true",
    })

    local parentPart = part1
    local lastPos = pos1
    for i = 0, 5 do
        local pos2 = lastPos + Lib.v3(0, -1, 0)
        local density = 1
        if i % 3 == 0 then
            density = 10
        end
        local part = createPart(pos2, 1, Lib.v3(0.3,1,0.1), {
	        useAnchor = "false",
            density = tostring(density)
        })
        self.map:getPhysicsWorld():createPointJoint(parentPart, part)
        parentPart = part
        lastPos = pos2
    end
end, 200)

GMItem["PART/Physx创建地板"] = GM:inputNumber(function(self, num)
    local pos1 = self:getPosition() + Lib.v3(0, -10, 0)
    local part1 = createPart(pos1, 1, Lib.v3(100,1,100), {
	    useAnchor = "true",
    })
end, 200)

GMItem["PART/开关物理动力"] = function()
	local value = not World.CurWorld.enablePhysicsSimulation
    World.CurWorld.enablePhysicsSimulation = value
end

GMItem["PART/打印体积"] = function()
	print(Me.part2:getVolume())
end

GMItem["PART/设置密度"] = GM:inputNumber(function(self, density)
	_density = density
end, 99)

GMItem["PART/设置是否相对"] = GM:inputNumber(function(self, val)
	relative = val == 0 and "false" or "true"
end, 0)

GMItem["PART/弹力系数"] = GM:inputNumber(function(self, var)
	local pos1 = self:getPosition() + Lib.v3(0, 5, 0)
	local pos2 = self:getPosition() + Lib.v3(0, 10, 0)
	local part1 = createPart(pos1, 1, Lib.v3(20,2,20), {
		density = 0,
		restitution = 1.0
	})
	local part2 = createPart(pos2, 2, Lib.v3(1,1,1), {
		density = 0.1,
		restitution = var
	})

    Me:setFlyMode(1)
	Me:setPosition(pos1 + Lib.v3(0, 13, 0))
end, 0.5)

GMItem["PART/锚定线速度"] = GM:inputStr(function(self, var)
    local v = var
	local pos1 = self:getPosition() + Lib.v3(0, 5, 0)
	local pos2 = self:getPosition() + Lib.v3(0, 10, 0)
	local part1 = createPart(pos1, 1, Lib.v3(100,2,100), {
		density = 0,
		restitution = 1.0,
		useAnchor = "true",
		lineVelocity = v,
	})
	local part2 = createPart(pos2, 1, Lib.v3(3,1,3), {
		density = 0.1,
	})
	Me:setPosition(pos1 + Lib.v3(0, 13, 0))
end, function()
	return string.format("x:%f y:%f z:%f", 0.01, 0, 0)
end
)

GMItem["PART/锚定角速度"] = GM:inputStr(function(self, var)
    local v = var
	local pos1 = self:getPosition() + Lib.v3(0, 5, 0)
	local pos2 = self:getPosition() + Lib.v3(0, 10, 0)
	local part1 = createPart(pos1, 1, Lib.v3(100,2,100), {
		density = 0,
		restitution = 1.0,
		useAnchor = "true",
		angleVelocity = v,
	})
	local part2 = createPart(pos2, 1, Lib.v3(3,1,3), {
		density = 0.1,
	})
	Me:setPosition(pos1 + Lib.v3(0, 13, 0))
end, function()
	return string.format("x:%f y:%f z:%f", 0, 0.02, 0)
end
)

GMItem["PART/测试力"] = GM:inputStr(function(self, var)
    local v = var
	local pos1 = self:getPosition() + Lib.v3(0, 5, 0)
	local pos2 = self:getPosition() + Lib.v3(0, 5, 0)
	local part1 = createPart(pos1, 1, Lib.v3(100,2,100), {
		density = 0,
		restitution = 1.0,
	})
	local part2 = createPart(pos2, 1, Lib.v3(1,1,1), {
		density = 0.1,
	})
	local force = Instance.Create("Force")
	force:setProperty("relativeForce", v)
	force:setProperty("force", v)
	force:setProperty("useRelativeForce", tostring(relative))
	force:setParent(part2)
	Me:setPosition(pos1 + Lib.v3(2, 5, 0))
	force:setDebugGraphShow(true)
end, function()
	return string.format("x:%f y:%f z:%f", 0, 0.1, 0)
end
)

GMItem["PART/固定约束"] = GM:inputStr(function(self, var)
    local v = var
	local pos1 = self:getPosition() + Lib.v3(0, 5, 0)
	local pos2 = self:getPosition() + Lib.v3(0, 8, 0)

	local part1 = createPart(pos1, 1, Lib.v3(100,2,100), {
		density = 0,
		restitution = 1.0,
	})
	local part2 = createPart(pos2, 1, Lib.v3(1,1,1), {
		density = 1,
	})

	local part3 = createPart(pos2 + Lib.v3(0, 2, 0), 1, Lib.v3(1,2,1), {
		density = 1,
	})

	local force = Instance.Create("Torque")
	force:setProperty("relativeTorque", v)
	force:setProperty("torque", v)
	force:setProperty("useRelativeTorque", tostring(relative))
	--force:setParent(part2)

	local fixedConstraint = Instance.Create("FixedConstraint")
	fixedConstraint:setProperty("slavePartID", tostring(part3:getInstanceID()))
	local rotation = Lib.v3(45, 45, 0)
    part3:setRotation(rotation)
	fixedConstraint:setParent(part2)
	fixedConstraint:calcAndUpdateParams()
	Me:setPosition(pos2 + Lib.v3(3, 0, 0))
	force:setDebugGraphShow(true)
end, function()
	return string.format("x:%f y:%f z:%f", 0, 0.1, 0)
end
)

GMItem["PART/杆约束"] = GM:inputStr(function(self, var)
    local v = var
	local pos1 = Me:getPosition() + Lib.v3(0, 5, 0)
	local pos2 = Me:getPosition() + Lib.v3(0, 8, 0)

	local part1 = createPart(pos1, 1, Lib.v3(100,2,100), {
		density = 0,
		restitution = 1.0,
	})
	local part2 = createPart(pos2, 1, Lib.v3(2, 1, 2), {
		density = 1,
	})

	local part3 = createPart(pos2 + Lib.v3(5, 1, 0), 1, Lib.v3(2,1,2), {
		density = 1,
	})

	local force = Instance.Create("Force")
	force:setProperty("relativeForce", v)
	force:setProperty("force", v)
	force:setProperty("useRelativeForce", tostring(relative))
	--force:setParent(part2)

	local RodConstraint = Instance.Create("RodConstraint")
	RodConstraint:setProperty("slavePartID", tostring(part3:getInstanceID()))
	RodConstraint:setProperty("masterLocalPos", "x:1 y:0.5 z:1")
	RodConstraint:setProperty("slaveLocalPos", "x:1 y:0.5 z:1")
	RodConstraint:setProperty("length", "5")
	RodConstraint:setProperty("radius", "0.05")
	RodConstraint:setProperty("visible", "true")
	RodConstraint:setDebugGraphShow(true)

	local rotation = Lib.v3(0, 90, 0)
    part3:setRotation(rotation)
	RodConstraint:setParent(part2)
	RodConstraint:calcAndUpdateParams()
	print("length:", RodConstraint:getSuitableLength())
	local pos3 = pos2
	pos3.z = pos3.z + 10
	Me:setPosition(pos3)
	force:setDebugGraphShow(true)
end, function()
	return string.format("x:%f y:%f z:%f", 0, 0.1, 0)
end
)


GMItem["PART/弹簧约束"] = GM:inputStr(function(self, var)
    local v = var
	local pos1 = Me:getPosition() + Lib.v3(0, 5, 0)
	local pos2 = Me:getPosition() + Lib.v3(0, 8, 0)

	local part1 = createPart(pos1, 1, Lib.v3(100,2,100), {
		density = 0,
		restitution = 1.0,
	})
	local part2 = createPart(pos2 + Lib.v3(5, 7, 0), 1, Lib.v3(2, 1, 2), {
		density = 0,
	})

	local part3 = createPart(pos2 + Lib.v3(5, 6, 0), 1, Lib.v3(2,1,2), {
		density = 0.01,
	})

	local force = Instance.Create("Force")
	force:setProperty("relativeForce", v)
	force:setProperty("force", v)
	force:setProperty("useRelativeForce", tostring(relative))
	--force:setParent(part2)

	local RodConstraint = Instance.Create("SpringConstraint")
	RodConstraint:setProperty("slavePartID", tostring(part3:getInstanceID()))
	RodConstraint:setProperty("masterLocalPos", "x:1 y:0.5 z:1")
	RodConstraint:setProperty("slaveLocalPos", "x:1 y:0.5 z:1")
	RodConstraint:setProperty("length", "4")
	RodConstraint:setProperty("radius", "0.15")
	RodConstraint:setProperty("thickness", "0.07")
	RodConstraint:setProperty("coil", "5")
	RodConstraint:setProperty("visible", "true")
	local rotation = Lib.v3(45, 89, 0)
    part3:setRotation(rotation)
	RodConstraint:setParent(part2)
	RodConstraint:calcAndUpdateParams()
	print("length:", RodConstraint:getSuitableLength())
	local pos3 = pos2
	pos3.z = pos3.z + 10
	Me:setPosition(pos3)
	force:setDebugGraphShow(true)
end, function()
	return string.format("x:%f y:%f z:%f", 0, 0.1, 0)
end
)

GMItem["PART/铰链约束"] = GM:inputStr(function(self, var)
    local v = var
	local pos1 = Me:getPosition() + Lib.v3(0, 5, 0)
	local pos2 = Me:getPosition() + Lib.v3(0, 8, 0)

	local part1 = createPart(pos1, 1, Lib.v3(100,2,100), {
		density = 0,
		restitution = 1.0,
	})
	local part2 = createPart(pos2 + Lib.v3(3, -0, 0), 1, Lib.v3(1, 2, 0.2), {
		density = 0,
	})

	local part3 = createPart(pos2 + Lib.v3(6, -0, 0), 1, Lib.v3(4,2,0.2), {
		density = 10,
	})

	local RodConstraint = Instance.Create("HingeConstraint")
	RodConstraint:setProperty("slavePartID", tostring(part3:getInstanceID()))
	RodConstraint:setProperty("masterLocalPos", "x:1 y:-1 z:0")
	RodConstraint:setProperty("slaveLocalPos", "x:-2 y:1 z:0")

	RodConstraint:setProperty("useMotor", "false")
	RodConstraint:setProperty("motorTargetAngleVelocity", "0.1")
	RodConstraint:setProperty("motorForce", "1000")

	RodConstraint:setProperty("useSpring", "true")
	RodConstraint:setProperty("stiffness", "100")
	RodConstraint:setProperty("damping", "50")
	RodConstraint:setProperty("springTargetAngle", "90")

	--RodConstraint:setProperty("thickness", "0.07")
	--RodConstraint:setProperty("coil", "5")
	local rotation = Lib.v3(45, 89, 0)
    --part3:setRotation(rotation)
	RodConstraint:setParent(part2)
	RodConstraint:calcAndUpdateParams()
	--print("length:", RodConstraint:getSuitableLength())
	local pos3 = pos2
	pos3.z = pos3.z + 10
	Me:setPosition(pos3)
end, function()
	return string.format("x:%f y:%f z:%f", 0, 0.1, 0)
end
)


GMItem["PART/绳子约束"] = GM:inputStr(function(self, var)
    local v = var
	local pos1 = Me:getPosition() + Lib.v3(0, 5, 0)
	local pos2 = Me:getPosition() + Lib.v3(0, 8, 0)

	local part1 = createPart(pos1, 1, Lib.v3(100,2,100), {
		density = 0,
		restitution = 1.0,
	})
	local part2 = createPart(pos2 + Lib.v3(5, 7, 0), 1, Lib.v3(2, 1, 2), {
		density = 0,
	})

	local part3 = createPart(pos2 + Lib.v3(5, 6, 0), 1, Lib.v3(2,1,2), {
		density = 0.01,
	})

	local force = Instance.Create("Force")
	force:setProperty("relativeForce", v)
	force:setProperty("force", v)
	force:setProperty("useRelativeForce", tostring(relative))
	--force:setParent(part2)

	local RodConstraint = Instance.Create("RopeConstraint")
	RodConstraint:setProperty("slavePartID", tostring(part3:getInstanceID()))
	RodConstraint:setProperty("masterLocalPos", "x:1 y:0.5 z:1")
	RodConstraint:setProperty("slaveLocalPos", "x:1 y:0.5 z:1")
	RodConstraint:setProperty("length", "4")
	RodConstraint:setProperty("radius", "0.05")
	RodConstraint:setProperty("visible", "true")
	local rotation = Lib.v3(45, 89, 0)
    part3:setRotation(rotation)
	RodConstraint:setParent(part2)
	RodConstraint:calcAndUpdateParams()
	print("length:", RodConstraint:getSuitableLength())
	local pos3 = pos2
	pos3.z = pos3.z + 10
	Me:setPosition(pos3)
	force:setDebugGraphShow(true)
end, function()
	return string.format("x:%f y:%f z:%f", 0, 0.1, 0)
end
)

GMItem["PART/测试编辑器新建约束"] = function()
	local RodConstraint = Instance.Create("FixedConstraint")
	RodConstraint:setDebugGraphShow(true)
end

GMItem["PART/滑块约束"] = GM:inputStr(function(self, var)
    local v = var
	local pos1 = Me:getPosition() + Lib.v3(0, 5, 0)
	local pos2 = Me:getPosition() + Lib.v3(0, 8, 0)

	local part1 = createPart(pos1, 1, Lib.v3(100,2,100), {
		density = 0,
		restitution = 1.0,
	})
	local part2 = createPart(pos2 + Lib.v3(5, 7, 0), 1, Lib.v3(2, 1, 2), {
		density = 0,
	})

	local part3 = createPart(pos2 + Lib.v3(5, 6, 0), 1, Lib.v3(2,1,2), {
		density = 0.01,
	})

	local force = Instance.Create("Force")
	force:setProperty("relativeForce", v)
	force:setProperty("force", v)
	force:setProperty("useRelativeForce", tostring(relative))
	--force:setParent(part2)

	local RodConstraint = Instance.Create("SliderConstraint")
	RodConstraint:setProperty("slavePartID", tostring(part3:getInstanceID()))
	RodConstraint:setProperty("masterLocalPos", "x:1 y:0.5 z:1")
	RodConstraint:setProperty("slaveLocalPos", "x:1 y:0.5 z:1")
	RodConstraint:setProperty("upperLimit", "0")
	RodConstraint:setProperty("lowerLimit", "0")
	local rotation = Lib.v3(90, 0, 0)
    part3:setRotation(rotation)
	RodConstraint:setParent(part2)
	RodConstraint:calcAndUpdateParams()
	local pos3 = pos2
	pos3.z = pos3.z + 10
	Me:setPosition(pos3)
	force:setDebugGraphShow(true)
end, function()
	return string.format("x:%f y:%f z:%f", 0, 0.1, 0)
end
)

GMItem["PART/力矩"] = GM:inputStr(function(self, var)
    local v = var
	local pos1 = self:getPosition() + Lib.v3(0, 5, 0)
	local pos2 = self:getPosition() + Lib.v3(0, 8, 0)
	local part1 = createPart(pos1, 1, Lib.v3(100,2,100), {
		density = 0,
		restitution = 1.0,
	})
	local part2 = createPart(pos2, 2, Lib.v3(5,5,5), {
		density = 0.1,
	})
	local force = Instance.Create("Torque")
	force:setProperty("torque", v)
	force:setProperty("relativeTorque", v)
	force:setProperty("useRelativeTorque", relative)
	force:setParent(part2)
	Me:setPosition(pos1 + Lib.v3(2, 11, 0))
	force:setDebugGraphShow(true)
end, function()
	return string.format("x:%f y:%f z:%f", 0, 0.02, 0)
end
)

GMItem["PART/roateX"] = function()
    Me.part2:rotate(Lib.v3(30, 0, 0))
end

GMItem["PART/roateY"] = function()
    Me.part2:rotate(Lib.v3(0, 30, 0))
end

GMItem["PART/roateZ"] = function()
    Me.part2:rotate(Lib.v3(0, 0, 30))
end

local sized = false

GMItem["PART/变形"] = function()
    if not sized then
        Me.part2:setSize(Lib.v3(4,5,6))
        sized = true
    else
        Me.part2:setSize(Lib.v3(1,1,1))
        sized = false
    end
end

local type = 0

GMItem["PART/切换"] = function()
    type = type + 1
    Me.part2:setShape(type % 4 + 1)
end

GMItem["PART/是否碰撞"] = function()
    local manager = World.CurWorld:getSceneManager()
    local scene = manager:getCurScene()
    scene:setEditorCanCollide(not scene:getEditorCanCollide())
end

local sceneManager = World.CurWorld:getSceneManager()

GMItem["PART/+y"] = function()
    Me.part2:moveUntilCollide(Lib.v3(0, 1, 0))
end
GMItem["PART/-y"] = function()
    Me.part2:moveUntilCollide(Lib.v3(0, -1, 0))
end

GMItem["PART/头顶加一个"] = function()
    local part = Instance.Create("Part")
    part:setShape(2)
    local pos = Me.part2:toWorldPosition(Lib.v3(0, 2, 0))
    part:setPosition(pos)
    part:setParent(Me.part2)
end

GMItem["PART/打印scene"] = function()
    local manager = World.CurWorld:getSceneManager()
    local sceneTable = Me.map:GetSceneAsTable(manager:getCurScene())
    print("GetSceneAsTable", Lib.v2s(sceneTable))
end

GMItem["PART/scene读取"] = function()
    local manager = World.CurWorld:getSceneManager()
    Me.map:createScene()
end

GMItem["PART/scene存档"] = function()
    local manager = World.CurWorld:getSceneManager()
    local path = "map/map001/setting.json"
    local obj = Lib.readGameJson(path)
    local sceneTable = Me.map:GetSceneAsTable(manager:getCurScene())
    obj.scene = sceneTable
    Lib.saveGameJson(path, obj)
end

GMItem["显示/FPS"] = function()
    show_fps = not show_fps
    CGame.instance:toggleFPSShown(show_fps)
end

GMItem["显示/场景Parts"] = function()
    show_parts = not show_parts
    CGame.instance:toggleRenderableObjsShown(show_parts)
end

GMItem["显示/调试信息"] = function()
    show_gameInfo = not show_gameInfo
    CGame.instance:toggleDebugMessageShown(show_gameInfo)
end

GMItem["显示/服务器端口"] = function()
    local msg = "server port: " .. (debugport.serverPort or "")
    print(msg)
    Lib.emitEvent(Event.EVENT_CHAT_MESSAGE, msg)
end

local show_collision = false
local showColliders = function()
    show_collision = not show_collision
	local debugDraw = DebugDraw.instance
    if show_collision and not debugDraw:isEnabled() then
        debugDraw:setEnabled(show_collision)
    end
	debugDraw:setDrawColliderEnabled(show_collision)
	debugDraw:setDrawAuraEnabled(show_collision)
	debugDraw:setDrawRegionEnabled(show_collision)
end
GMItem["显示/显示碰撞体"] = showColliders

GMItem["显示/附近碰撞体"] = GM:inputNumber(function(self, range)
    WorldConfig.Load("{\"debugDrawColliderRange\":"..range.."}")
    show_collision = false
    showColliders()
end, 15)

local show_terrain_wire = false
GMItem["显示/地形线框"] = function()
    show_terrain_wire = not show_terrain_wire
    VoxelRenderManager.Instance():setUsedWire(show_terrain_wire)
end

local show_terrain_shadow = false
GMItem["显示/地形阴影"] = function()
    show_terrain_shadow = not show_terrain_shadow
    VoxelRenderManager.Instance():setCastShadow(show_terrain_shadow)
end

local show_block_pbr_light = false
GMItem["显示/显示方块PBR光照"] = function()
    show_block_pbr_light = not show_block_pbr_light
    Blockman.instance.gameSettings:setEnableBlockPBRLightType(show_block_pbr_light)
end

GMItem["显示/显示高光"] = function()
	local val = Blockman.instance.gameSettings:getEnableSpecular()
	if val > 0.0 then
		val = val - 1.0
	else
		val = val + 1.0
	end
    Blockman.instance.gameSettings:setEnableSpecular(val)
end

GMItem["显示/显示实时阴影"] = function()
	local val = Blockman.instance.gameSettings:getEnableRealtimeShadow()
	if val > 0.0 then
		val = val - 1.0
	else
		val = val + 1.0
	end
    Blockman.instance.gameSettings:setEnableRealtimeShadow(val)
end

local isFly = false
GMItem["工具/飞行模式"] = function(self)
    isFly = (not isFly)
    Me:setFlyMode(isFly and 1 or 0)
end

GMItem["工具/开启升采样"] = function(self)
    Blockman.instance.gameSettings:setGMUpSampleState(true)
end

GMItem["工具/关闭升采样"] = function(self)
    Blockman.instance.gameSettings:setGMUpSampleState(false)
end

GMItem["工具/开启降采样"] = function(self)
    Blockman.instance.gameSettings:setGMDownSampleState(true)
end

GMItem["工具/关闭降采样"] = function(self)
    Blockman.instance.gameSettings:setGMDownSampleState(false)
end

GMItem["工具/2x降采样"] = function(self)
    Blockman.instance.gameSettings:setGMDownSampleScale(0)
end

GMItem["工具/1.5x降采样"] = function(self)
    Blockman.instance.gameSettings:setGMDownSampleScale(1)
end

GMItem["工具/1.2x降采样"] = function(self)
    Blockman.instance.gameSettings:setGMDownSampleScale(2)
end

GMItem["显示/actor接收阴影"] = function()
	local val = Blockman.instance.gameSettings:getEnableActorReceiveShadow()
	if val > 0.0 then
		val = val -1.0
	else
		val = val + 1.0
	end
    Blockman.instance.gameSettings:setEnableActorReceiveShadow(val)
end

local tex_size = 0
GMItem["显示/阴影贴图size"] = function()
    tex_size = tex_size + 1
    if tex_size > 3 then
        tex_size = 0
    end
    Blockman.instance.gameSettings:setRealtimeShadowTexSizeLevel(tex_size)
end

local cam_size = 1.0
GMItem["显示/阴影镜头size +"] = function()
    cam_size = cam_size - 0.1
    if cam_size < 0.1 then
        cam_size = 0.1
    end
    Blockman.instance.gameSettings:setRealtimeShadowCamSizeLevel(cam_size)
end
GMItem["显示/阴影镜头size -"] = function()
    cam_size = cam_size + 0.1
    Blockman.instance.gameSettings:setRealtimeShadowCamSizeLevel(cam_size)
end

GMItem["显示/阴影镜头highest +"] = function()
    local val = Blockman.instance.gameSettings:getRealtimeShadowCamHighestLevel()
	val = val + 1
    Blockman.instance.gameSettings:setRealtimeShadowCamHighestLevel(val)
end
GMItem["显示/阴影镜头highest -"] = function()
    local val = Blockman.instance.gameSettings:getRealtimeShadowCamHighestLevel()
	val = val - 1
    Blockman.instance.gameSettings:setRealtimeShadowCamHighestLevel(val)
end
GMItem["显示/阴影镜头lowest +"] = function()
    local val = Blockman.instance.gameSettings:getRealtimeShadowCamLowestLevel()
	val = val + 1
    Blockman.instance.gameSettings:setRealtimeShadowCamLowestLevel(val)
end
GMItem["显示/阴影镜头lowest -"] = function()
    local val = Blockman.instance.gameSettings:getRealtimeShadowCamLowestLevel()
	val = val - 1
    Blockman.instance.gameSettings:setRealtimeShadowCamLowestLevel(val)
end

GMItem["显示/阴影bias +"] = function()
    local val = Blockman.instance.gameSettings:getEnableRealtimeShadow()
	val = val + 0.00001
    Blockman.instance.gameSettings:setEnableRealtimeShadow(val)
end
GMItem["显示/阴影bias -"] = function()
    local val = Blockman.instance.gameSettings:getEnableRealtimeShadow()
	val = val - 0.00001
    Blockman.instance.gameSettings:setEnableRealtimeShadow(val)
end

GMItem["显示/角色阴影bias +"] = function()
    local val = Blockman.instance.gameSettings:getEnableActorReceiveShadow()
	val = val + 0.00001
    Blockman.instance.gameSettings:setEnableActorReceiveShadow(val)
end
GMItem["显示/角色阴影bias -"] = function()
    local val = Blockman.instance.gameSettings:getEnableActorReceiveShadow()
	val = val - 0.00001
    Blockman.instance.gameSettings:setEnableActorReceiveShadow(val)
end

local show_depthmap_mask = -1
GMItem["显示/显示阴影Mask"] = function()
	show_depthmap_mask = show_depthmap_mask + 1
	if(show_depthmap_mask >= 3) then
		show_depthmap_mask = -1
	end
    Blockman.instance.gameSettings:setRealtimeShadowOpenMask(show_depthmap_mask)
end

local render_ui = false
GMItem["显示/ui render"] = function()
    render_ui = not render_ui
    Blockman.instance.gameSettings:setEnableRenderUI(render_ui)
end

local render_edge = false
GMItem["显示/edge render"] = function()
    render_edge = not render_edge
    Blockman.instance.gameSettings:setEnableRenderEdge(render_edge)
end

GMItem["显示/audio update"] = function()
	local todo = Blockman.instance.gameSettings:getEnableAudioUpdate()
    todo = not todo
    Blockman.instance.gameSettings:setEnableAudioUpdate(todo)
end

local block_update = false
GMItem["显示/block update"] = function()
    block_update = not block_update
    Blockman.instance.gameSettings:setEnableBlockUpdate(block_update)
end

local block_render = false
GMItem["显示/block render"] = function()
    block_render = not block_render
    Blockman.instance.gameSettings:setEnableBlockRender(block_render)
end

GMItem["显示/block uvs"] = function()
    local todo = Blockman.instance.gameSettings:getEnableRnederBlockUVs()
	todo = not todo
    Blockman.instance.gameSettings:setEnableRnederBlockUVs(todo)
end

GMItem["显示/UIRStageBlend"] = function()
    local todo = Blockman.instance.gameSettings:getEnableUIRenderStageBlend()
	todo = not todo
    Blockman.instance.gameSettings:setEnableUIRenderStageBlend(todo)
end

GMItem["显示/EntityGUI"] = function()
    local todo = Blockman.instance.gameSettings:getEnableRenderEntityGUI()
	todo = not todo
    Blockman.instance.gameSettings:setEnableRenderEntityGUI(todo)
end

GMItem["显示/SceneGUI"] = function()
    local todo = Blockman.instance.gameSettings:getEnableRenderSceneGUI()
	todo = not todo
    Blockman.instance.gameSettings:setEnableRenderSceneGUI(todo)
end

GMItem["显示/entity tick"] = function()
    local entity_tick = Blockman.instance.gameSettings:getEnableEntityTick()
	entity_tick = not entity_tick
    Blockman.instance.gameSettings:setEnableEntityTick(entity_tick)
end

local actorLodNormal = Blockman.instance.gameSettings:getEnableUseActorLodCull()
GMItem["显示/actor lod"] = function()
    local todo = Blockman.instance.gameSettings:getEnableUseActorLodCull()
	if todo == 0 then
		todo = actorLodNormal;
	else
		todo = 0;
	end
    Blockman.instance.gameSettings:setEnableUseActorLodCull(todo)
end

GMItem["显示/object update"] = function()
    local todo = Blockman.instance.gameSettings:getEnableObjectUpdate()
	todo = not todo
    Blockman.instance.gameSettings:setEnableObjectUpdate(todo)
end

GMItem["显示/object render"] = function()
    local todo = Blockman.instance.gameSettings:getEnableObjectRender()
	todo = not todo
    Blockman.instance.gameSettings:getEnableObjectRender(todo)
end

local actor_update = false
GMItem["显示/actor update"] = function()
    actor_update = not actor_update
    Blockman.instance.gameSettings:setEnableActorUpdate(actor_update)
end

local actor_render = false
GMItem["显示/actor render"] = function()
    actor_render = not actor_render
    Blockman.instance.gameSettings:setEnableActorRender(actor_render)
end

local effect_update = false
GMItem["显示/effect update"] = function()
    effect_update = not effect_update
    Blockman.instance.gameSettings:setEnableEffectUpdate(effect_update)
end

local effect_render = false
GMItem["显示/effect render"] = function()
    effect_render = not effect_render
    Blockman.instance.gameSettings:setEnableEffectRender(effect_render)
end

local show_sky = false
GMItem["显示/显示sky"] = function()
    show_sky = not show_sky
    Blockman.instance.gameSettings:setEnableSkyShow(show_sky)
end

local shadow_pcf = 0
GMItem["显示/阴影采样PCF"] = function()
    shadow_pcf = shadow_pcf + 1
    if shadow_pcf >= 4 then
        shadow_pcf = 0
    end
    Blockman.instance.gameSettings:setRealtimeShadowPcfLevel(shadow_pcf)
end

GMItem["显示/抗锯齿"] = function()
	local settings = Blockman.instance.gameSettings;
	settings:setEnableAntiAliasing(not settings:getEnableAntiAliasing())
end

local show_bloom = false
GMItem["显示/bloom"] = function()
	show_bloom = not show_bloom
	Blockman.instance.gameSettings:setEnableBloom(show_bloom)
end

local show_fullscreen_bloom = true
GMItem["显示/全屏bloom"] = function()
	show_fullscreen_bloom = not show_fullscreen_bloom
	Blockman.instance.gameSettings:setEnableFullscreenBloom(show_fullscreen_bloom)
end

local is_rasterizer = false
GMItem["显示/软光栅"] = function()
	is_rasterizer = not is_rasterizer
	Blockman.instance.gameSettings:setEnableRasterizerMesh(is_rasterizer)
end

GMItem["显示/特效热干扰"] = function()
    local val = Blockman.instance.gameSettings:getEnableDistortionRender()
	val = not val
    Blockman.instance.gameSettings:setEnableDistortionRender(val)
end

GMItem["显示/体积云"] = function()
	local val = Blockman.instance.gameSettings:getEnableVolumetricCloud()
	val = not val
	Blockman.instance.gameSettings:setEnableVolumetricCloud(val)
end

GMItem["显示/海面"] = function()
	local val = Blockman.instance.gameSettings:getEnableOceanBlock()
	val = not val
	Blockman.instance.gameSettings:setEnableOceanBlock(val)
	Blockman.instance:refreshBlocks()
end

GMItem["显示/纯色方块"] = function()
	local val = Blockman.instance.gameSettings:getEnablePureColorBlock()
	val = not val
	Blockman.instance.gameSettings:setEnablePureColorBlock(val)
end

GMItem["显示/纯色方块+"] = function()
	Blockman.instance.gameSettings:changePureColorBlockDistance(5.0)
end

GMItem["显示/纯色方块-"] = function()
	Blockman.instance.gameSettings:changePureColorBlockDistance(-5.0)
end

GMItem["显示/section cull"] = function()
    local val = Blockman.instance.gameSettings:getSectionRenderViewFrustumFreePercent()
	if val > 0.0 then
		val = val - 1.0
	else
		val = val + 1.0
	end
    Blockman.instance.gameSettings:setSectionRenderViewFrustumFreePercent(val)
end

local is_performanceProfiler = false
GMItem["显示/debug类型"] = function()
    is_performanceProfiler = not is_performanceProfiler
    Blockman.instance.gameSettings:setEnablePerformanceProfiler(is_performanceProfiler)
end

local is_debugMessageDetail = false
GMItem["显示/debugDetail"] = function()
    is_debugMessageDetail = not is_debugMessageDetail
    Blockman.instance.gameSettings:setDebugMessageDetail(is_debugMessageDetail)
end

local _draw_pathmap_inited = false
local function GMDrawServerPathMap()
    if _draw_pathmap_inited then return end
    _draw_pathmap_inited = true
    DebugDraw.addEntry("serverPathMap", function()
        local pathMapInfo = GM.serverPathMapInfo
        if not pathMapInfo then
            return
        end
        local passPts, radius = pathMapInfo.passPts, pathMapInfo.radius
        local y = Me:getPosition().y
        local up = Vector3.new(0, 1, 0)
        local color = 0x00FFCCFF
        for i = 1, #passPts, 2 do
            local pt = {x = passPts[i], y = y, z = passPts[i + 1]}
            DebugDraw.instance:drawCircle(pt, radius, up, color)
        end
    end)
end

local is_showServerPathMap = false
local showServerPathMapTimer = nil
-- supply getCurrentPathRoomId and showServerPathMapRange to show server pathmap
GMItem["显示/serverpathmap"] = function(self)
    local getRoomIdFn = GM.getCurrentPathRoomId
    if not getRoomIdFn then
        Lib.logError("reqiure GM.getCurrentRoomId fn")
        return
    end
    local range = GM.showServerPathMapRange or 10
    is_showServerPathMap = not is_showServerPathMap
    GMDrawServerPathMap()
    DebugDraw.instance:setServerPathMapEnabled(is_showServerPathMap)
    showServerPathMapTimer =  World.Timer(10, function ()
        if not is_showServerPathMap then
            return
        end
        local roomId = getRoomIdFn()
        if not roomId then
            return 10
        end
        self:sendPacket({
            pid = "GM",
            typ = "QueryPathInfo",
            params = {roomId = roomId, position = self:getPosition(), range = range},
        }, function (data)
            GM.serverPathMapInfo = data
        end)
        return 10
    end)
end

GMItem["系统/更新当前client"] = function(self)
    debugport.Reload()
end

GMItem["系统/完全更新client"] = function(self)
    debugport.Reload(true)
end

GMItem["系统/自动更新client"] = function(self)
    Lib.emitEvent(Event.EVENT_CHAT_MESSAGE, debugport.AutoReload() and "AutoReload start" or "AutoReload stop")
end

GMItem.NewLine()

GMItem["LuaProfiler/控制台server"] = function()
    Game.RunTelnet(2, debugport.serverPort)
end

GMItem["LuaProfiler/控制台client"] = function()
    Game.RunTelnet(1, debugport.port)
end

GMItem["系统/开启client性能统计"] = function(self)
    Profiler:init()
end

GMItem["系统/打印client性能统计"] = function(self)
    print(Profiler:dumpString())
end

GMItem["系统/关闭client性能统计"] = function(self)
    Profiler:reset()
end

GMItem["手机编辑器/导出地图方块csv"] = function(self)
    Blockman.instance:exportMapBlockList()
end

GMItem["系统/打开或者关闭UI信息查看"] = function(self)
    uiLogger.enabled = not uiLogger.enabled
end

GMItem.NewLine()
GMItem.NewLine()

GMItem["系统/重载UI"] = function(self)
    UI:reloadAllUI()
    UI:reloadAllSceneUI()
    Lib.logInfo("All UI reloads completed!")
end

GMItem["手机编辑器/生成描述(item类型)"] = function(self)
    EditorModule:setDescCreate("item")
	UI:openNewWnd("mapEditItemBag")
end

GMItem["手机编辑器/生成描述(block类型)"] = function(self)
    EditorModule:setDescCreate("block")
	UI:openNewWnd("mapEditItemBag")
end

local function showBBox(flag)
    local debugDraw = DebugDraw.instance
    debugDraw:setEnabled(flag)
    debugDraw:setEditVolumeBoxEnabled(flag)
    debugDraw:setDrawColliderAABBEnabled(flag)
    debugDraw:setDrawColliderEnabled(flag)
    debugDraw:setDrawAuraEnabled(flag)
    debugDraw:setDrawRegionEnabled(flag)
end

GMItem["开发/碰撞盒编辑"] = function (self)
    local debugDraw = DebugDraw.instance
    if UI:isOpen("editVolumeBox") then
        UI:closeWnd("editVolumeBox")
        showBBox(false)
    else
        UI:openWnd("editVolumeBox")
        showBBox(true)
    end
end
local editRegionMode = false
GMItem["开发/区域编辑器"] = function(self)
    local debugDraw = DebugDraw.instance
    if editRegionMode  and debugDraw:isEditRegionBoxEnabled() then
        debugDraw:setEnabled(false)
        debugDraw:setDrawRegionEnabled(false)
        debugDraw:setEditRegionBoxEnabled(false)
        UI:closeWnd("editRegionTool", 0)
    else
        editRegionMode = true
        if UI:isOpen("editRegionTool") then
            UI:getWnd("editRegionTool", true):onReload(0)
        else
            UI:openWnd("editRegionTool", 0)
        end
        debugDraw:setEnabled(true)
        debugDraw:setDrawRegionEnabled(true)
        debugDraw:setEditRegionBoxEnabled(true)
      
    end
    Me:cfg().collision = not debugDraw:isEditRegionBoxEnabled()
    Me:setFlyMode(1)
end

GMItem["UI/打开或者关闭UI信息查看"] = function(self)
    uiLogger.enabled = not uiLogger.enabled
end

GMItem["开发/关闭客户端Entity推挤"] = function()
	local value = not World.CurWorld.canPushable
    World.CurWorld.canPushable = value
	print("World canPushable is "..tostring(value))
end

GMItem["开发/关闭客户端静态Entity更新"] = function()
	local value = not World.CurWorld.disableStaticEntityTick
    World.CurWorld.disableStaticEntityTick = value
	print("WorldClient disableStaticEntityTick is "..tostring(value))
end

Lib.emitEvent(Event.EVENT_SHOW_GM_LIST)	-- 热更新用，放在最后一�

GMItem["开发/创建一个blank"] = function(self)
    self:sendPacket({
        pid = "GM",
        typ = "GMCallEditEntity",
        params = {key = "NewEditObject", playerId = Me.objID, fullName = self:cfg().plugin .. "/blank"},
    })
end

GMItem["LuaProfiler/开始client采样"] = function(self)
    LuaProfiler.Start()
end

GMItem["LuaProfiler/结束client采样"] = function(self)
    LuaProfiler.Stop()
end

GMItem["LuaProfiler/测试client采样准确率"] = function(self)
    LuaProfiler.TestAccuracy()
end

GMItem["LuaProfiler/开启C性能统计"] = function(self)
    Profiler:init()
end

GMItem["LuaProfiler/关闭C性能统计"] = function(self)
    Profiler:reset()
end

GMItem["LuaProfiler/导出C性能统计"] = function(self)
    print(Profiler:dumpString())
end

GMItem["LuaProfiler/C内存分析"] = function (self)
    require("common.mem").List()
end

--GMItem["LuaProfiler/client内存分析index"] = GM:inputNumber(function(self, index)
--    require("common.mem").List(index)
--end)

GMItem["LuaProfiler/C内存清理"] = function (self)
    require("common.mem").Clear()
end

GMItem["开发/MD5Maker"] = function (self)
    ResourceMD5Maker.processGameFolder(CGame.Instance():getGameRootDir():gsub("\\", "/"), World.GameName, 1, "", false)
end

GMItem["开发/ResCache转换"] = function (self)
    FileResourceManager:Instance():ResCacheToOriginRes()
end

GMItem["开发/OpenResCount"] = function (self)
    FileResourceManager:Instance():DumpOpenResourceCount()
end

GMItem["LuaProfiler/统计C网络包"] = function (self)
    -- script packet enable and clear
    World.EnablePacketCount(true)

    -- engine packet enable and clear
    CGame.instance:enablePacketStat();
    CGame.instance:clearPacketStat();
end

GMItem["LuaProfiler/显示C网络包"] = function (self)
    World.ShowPacketCount()
    CGame.instance:printPacketStat();
end

GMItem["LuaProfiler/lua C内存占用"] = function (self)
    collectgarbage("collect")
    collectgarbage("collect")
    Lib.logInfo(string.format("lua memory %dKB", math.ceil(collectgarbage("count"))))
end

GMItem["LuaProfiler/C 性能统计n帧"] = GM:inputNumber(function(self, ticks)
    Profiler:startCpuStaticsFor(ticks, true)
end, 200)

GMItem["LuaProfiler/C Statistics"] = function (self)
    PerformanceStatistics.SetCPUTimerEnabled(true)
end

GMItem["LuaProfiler/C PrintResults"] = function (self)
    PerformanceStatistics.PrintResults(300)
end

GMItem["开发/关闭客户端Entity推挤"] = function()
	local value = not World.CurWorld.canPushable
    World.CurWorld.canPushable = value
	print("World canPushable is "..tostring(value))
end

GMItem["开发/关闭客户端静态Entity更新"] = function()
	local value = not World.CurWorld.disableStaticEntityTick
    World.CurWorld.disableStaticEntityTick = value
	print("WorldClient disableStaticEntityTick is "..tostring(value))
end

local testEvent = "TEST_REGISTER"
local testCount = 0
GMItem["A_Test_dataCacheContainer/注册测试容器(TYPE_OVERRIVE)"] = function()
    print("A_Test_dataCacheContainer/注册测试容器(TYPE_OVERRIVE)")
	DataCacheContainer.registerContainer(testEvent)
end
GMItem.NewLine()
GMItem["A_Test_dataCacheContainer/注册测试容器(TYPE_OVERRIVE+5s)"] = function()
    print("A_Test_dataCacheContainer/注册测试容器(TYPE_OVERRIVE+5s)")
	DataCacheContainer.registerContainer(testEvent, nil, 100)
end
GMItem.NewLine()
GMItem["A_Test_dataCacheContainer/注册测试容器(TYPE_APPEND)"] = function()
    print("A_Test_dataCacheContainer/注册测试容器(TYPE_APPEND)")
	DataCacheContainer.registerContainer(testEvent, DataCacheContainer.ContainerType.TYPE_APPEND)
end
GMItem.NewLine()
GMItem["A_Test_dataCacheContainer/注册测试容器(TYPE_APPEND+5s)"] = function()
    print("A_Test_dataCacheContainer/注册测试容器(TYPE_APPEND+5s)")
	DataCacheContainer.registerContainer(testEvent, DataCacheContainer.ContainerType.TYPE_APPEND, 100)
end
GMItem.NewLine()
GMItem["A_Test_dataCacheContainer/清除测试容器数据"] = function()
    print("A_Test_dataCacheContainer/清除测试容器数据")
	DataCacheContainer.cleanDataCache(testEvent)
end
GMItem.NewLine()
GMItem["A_Test_dataCacheContainer/删除测试容器和事件"] = function()
    print("A_Test_dataCacheContainer/删除测试容器和事件")
    DataCacheContainer.removeContainer(testEvent)
    Lib.TestClean(testEvent) -- 注：事件需要在Lib那里加一个强制清除用作测试，测完删掉。
    --[[
        function Lib.TestClean(name)
            eventCalls[name] = nil
        end
    ]]
end
GMItem.NewLine()
GMItem["A_Test_dataCacheContainer/注册测试事件"] = function()
    print("A_Test_dataCacheContainer/注册测试事件")
    Lib.subscribeEvent(testEvent, function(subArg1, subArg2, subArg3, emitArg)
        print(" subArg1, subArg2, subArg3, emitArg ", subArg1, subArg2, subArg3, emitArg)
    end, "test 1!!!"..testCount, "test 2!!!"..testCount, "test 3!!!"..testCount)
end
GMItem.NewLine()
GMItem["A_Test_dataCacheContainer/触发测试事件"] = function()
    print("A_Test_dataCacheContainer/触发测试事件")
    testCount = testCount + 1
    Lib.emitEvent(testEvent, "test 100E"..testCount)
end

GMItem["开发/创建一个blank"] = function(self)
    self:sendPacket({
        pid = "GM",
        typ = "GMCallEditEntity",
        params = {key = "NewEditObject", playerId = Me.objID, fullName = self:cfg().plugin .. "/blank"},
    })
end

GMItem["开发/场景entity编辑模式"] = function(self)
    local isCan = false
    for _,skill in pairs(self:cfg().defaultSkills) do
        if "/click" == skill then
            isCan = true
            break
        end
    end
    if not isCan then
        Client.ShowTip(1,"先为player1 setting.json 的defaultSkills配置添加\"/click\"",100)
        return
    end
    World.cfg.enableShowEditEntityPosRot = true

end

GMItem["LuaProfiler/C 1-Before"] = function (self)
    collectgarbage("collect")
    collectgarbage("collect")
    mri.m_cMethods.DumpMemorySnapshot("./", "C1-Before", -1)
end

GMItem["LuaProfiler/C 2-After"] = function (self)
    collectgarbage("collect")
    collectgarbage("collect")
    mri.m_cMethods.DumpMemorySnapshot("./", "C2-After", -1)
end

GMItem["LuaProfiler/C ComparedFile"] = function (self)
    mri.m_cMethods.DumpMemorySnapshotComparedFile("./", "Compared", -1, "./LuaMemRefInfo-All-[C1-Before].txt", "./LuaMemRefInfo-All-[C2-After].txt")
end

GMItem["LuaProfiler/C LuaMemState"] = function(self)
    Lib.logInfo("**********************************************************")
    LuaTimer:printState()
    Lib.logInfo("timerCalls size", Lib.getTableSize(World.getTimerCalls()))
    Lib.logInfo("ObjectList size", Lib.getTableSize(self.ObjectList))
    Lib.logInfo("mapList size", Lib.getTableSize(World.mapList))
    Lib.logInfo("**********************************************************")
end

GMItem["LuaProfiler/打开 Profiler"] = function (self)
    if UI:isOpenWindow("profiler") then
        return
    end
    --UI:openSystemWindowAsync(function(window) end,"profiler")
    UI:openSystemWindow("profiler")
end

GMItem["LuaProfiler/关闭 Profiler"] = function (self)
    local instance = UI:isOpenWindow("profiler")
    if instance then
        instance:close()
    end
end

GMItem["LuaProfiler/测试 Profiler"] = function (self)
    local instance = UI:isOpenWindow("profiler")
    if instance then
        instance:close()
    end
    --UI:openSystemWindowAsync(function(window) end,"profiler", "profiler", 2)
    UI:openSystemWindow("profiler", "profiler", 2)
end

GMItem["LuaProfiler/清 UI Pool"] = function (self)
    UI:clearWindowPool()
    print("clearWindowPool")
end

GMItem["自动测试/录制-开始"] = function(self)
    AT.RecordBegin()
end

GMItem["自动测试/录制-完成"] = function(self)
    AT.RecordEnd()
end

GMItem["自动测试/录制-放弃"] = function(self)
    AT.RecordEnd(true)
end

GMItem["自动测试/录制-位置"] = function(self)
    AT.RecordPos()
end

GMItem["自动测试/开始任务"] = function(self)
    AT.Begin()
end

GMItem["自动测试/结束任务"] = function(self)
    AT.Stop()
end

GMItem["报错处理/(客户端)启用异常\n输出到聊天框"] = function()
    showErrMsgToChatBar = true
end

GMItem["报错处理/(客户端)禁用异常\n输出到聊天框"] = function()
    showErrMsgToChatBar = false
end

GMItem["报错处理/故意报错测试"] = function()
	test_test_test()
end

GMItem["shader/更新全部文件创建shader"] = function()
    Blockman.instance.gameSettings:updateAllFileShaders()
end
GMItem.NewLine()

GMItem["shader/windows自动监听shader"] = function()
    Blockman.instance.gameSettings:setStartMonitorShader()
end

GMItem.NewLine()
GMItem["A-动画相关/冻结动画"] = function(self)
    self:setActorPause(true)
end
GMItem.NewLine()
GMItem["A-动画相关/解除冻结动画"] = function(self)
    self:setActorPause(false)
end
GMItem.NewLine()
GMItem["A-动画相关/倒放动画"] = function(self)
    self:setActorAnimRewind(true)
end
GMItem.NewLine()
GMItem["A-动画相关/解除倒放动画"] = function(self)
    self:setActorAnimRewind(false)
end
GMItem.NewLine()
GMItem["A-动画相关/刷新上身动画"] = function(self)
    self:refreshUpperAction()
end
GMItem.NewLine()
GMItem["A-动画相关/刷新全身动画"] = function(self)
    self:refreshBaseAction()
end
GMItem.NewLine()
GMItem["A-动画相关/设置全身动画播放速度0.5倍"] = function(self)
    self:setBaseActionScale(0.5)
end
GMItem.NewLine()
GMItem["A-动画相关/设置全身动画播放速度1倍(正常速度)"] = function(self)
    self:setBaseActionScale(1)
end
GMItem.NewLine()
GMItem["A-动画相关/设置全身动画播放速度2倍"] = function(self)
    self:setBaseActionScale(2)
end

GMItem["LIGHT/新建灯光节点"] = function(self)
    local manager = World.CurWorld:getSceneManager()
    sceneRoot = manager:getOrCreateScene(Me.map.obj):getRoot()
    local light = Instance.Create("Light")
    light:setParent(sceneRoot)

end

GMItem["开发/保存entity的MeshAABB盒"] = GM:inputStr(function(self, value)
    if not value then
        return
    end

    print(value)

    local entities = World.CurWorld:getAllEntity()
    for _, entity in pairs(entities) do
        if entity:cfg().fullName == "myplugin/"..value then
            local meshMap = entity:getBodyMeshMap()
            for bodyPartFilter, meshList in pairs(meshMap) do
                for i, meshName in ipairs(meshList) do
                    local box = entity:getPartsAABB(meshName)
                    local pos = entity:getPosition()

                    local w_x = box.vMax.x - box.vMin.x
                    local w_y = box.vMax.y - box.vMin.y
                    local w_z = box.vMax.z - box.vMin.z
                    --Lib.pv(box)
                    local sendParams = {
                        fullName = value,
                        w_x = w_x,
                        w_y = w_y,
                        w_z = w_z,
                    }

                    Me:sendPacket({
                        pid = "SaveEntityBoundingVolume",
                        params = sendParams
                    })
                    return
                end
            end
        end
    end

end, function(self)
    return nil
end)

GMItem["系统/webview"] = function()
    print(">>>>> 打开网页")
    Interface.onAppActionTrigger(10000, "url=https://www.youtube.com/embed/nED8Ulo7mRA&functionName=onWatchAudio")
end


Lib.emitEvent(Event.EVENT_SHOW_GM_LIST)	-- 热更新用，放在最后一行
