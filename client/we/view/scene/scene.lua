local Signal = require "we.signal"
local Map = require "we.view.scene.map"
local Storage = require "we.view.scene.storage"
local State = require "we.view.scene.state"
local Input = require "we.view.scene.input"
local Camera = require "we.view.scene.camera"
local CameraIndicator = require "we.view.scene.camera_indicator"
local Object = require "we.view.scene.object.object"
local Placer = require "we.view.scene.placer.placer"
local Picker = require "we.view.scene.picker.picker"
local Selector = require "we.view.scene.selector.selector"
local Receptor = require "we.view.scene.receptor.receptor"
local Gizmo = require "we.view.scene.gizmo"
local Operator = require "we.view.scene.operator.operator"
local Dialog = require "we.view.scene.dialog"
local Bunch = require "we.view.scene.bunch"
local BindObject = require "we.view.scene.bind.bind_object"
local M = {}


function M:init(mode)
	Map:init()
	State:init()
	Input:init()
	Camera:init()
	CameraIndicator:init()
	BindObject:init()
	Object:init()
	Placer:init()
	Picker:init()
	Selector:init()
	Receptor:init()
	Gizmo:init()
	Operator:init()
	Dialog:init()
	Storage:init()
	World.CurWorld.enablePhysicsSimulation = false
end

local Recorder = require "we.gamedata.recorder"
function M:update(frame_time)
	Camera:update(frame_time)
	CameraIndicator:update(frame_time)
	Bunch:update()
	Receptor:update()
end

function M:reset()
	Placer:unbind()
	Picker:unbind()
	Selector:unbind()
	Receptor:unbind()
	Gizmo:switch(Gizmo.TYPE.NONE)
end

return M
