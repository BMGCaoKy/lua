local Cinemachine = T(Lib, "LuaCinemachine")

-------------------------------------------------
-- Cinemachine doesn't control real camera directly.
-- It hijacks real camera by overwriting it's data before shooting.
--
-- body: Determines virtual camera's position, how should it move (follow)
-- aim:  Determines virtual camera's orientation, how should it rotate (look at)
-- noise: Make it possible to shake virtual camera
-- avoider: The strategy of avoiding obstacle between virtual camera and it's target
-------------------------------------------------

-- Create a virtual camere
-- `name' is the identity of the camera
-- `cfg' specified the parts the camera has
function Cinemachine:createCamera(name, cfg)
    local vcam = CinemachineBrain.Instance():createVirtualCamera(name)
    if cfg.follow then
       vcam.followId = cfg.follow:getInstanceID()
    end
    if cfg.lookAt then
       vcam.lookAtId = cfg.lookAt:getInstanceID()
    end
    vcam:setBody(cfg.body or {})
    vcam:setAim(cfg.aim or {})
    vcam:setNoise(cfg.noise or {})
    vcam:setAvoider(cfg.avoider or {})
    vcam:setPostprocessor(cfg.postprocessor or {})
    return vcam
end

-- Destroy a virtual camera
function Cinemachine:destroyCamera(name)
    CinemachineBrain.Instance():destroyVirtualCamera(name)
end

-- Get current live camera's name
-- live camera is the virtual camera currently in effect
-- only one live camera at a time
function Cinemachine:getLiveCameraName()
    return CinemachineBrain.Instance():getLiveCameraName()
end

-- Get a virtual camera
-- Notice: when use this function I intentially ignore error checking
--         to make it easier to locate typo (nonexist name)
function Cinemachine:getCamera(name)
    return CinemachineBrain.Instance():getVirtualCamera(name)
end

-- Copy `srcName's states(position & orientation) to camera `destName'
-- This is useful when switching to another camera and dont wanna have a sudden cut
function Cinemachine:stateCopy(srcName, destName)
    CinemachineBrain.Instance():stateCopy(srcName, destName)
end

-- Blend to named camera smoothly in given seconds
-- callback: (optional) called when finish
function Cinemachine:blendTo(name, seconds, callback)
    local callbackId = self:saveBlendCallback(callback)
    CinemachineBrain.Instance():blendTo(name, seconds, callbackId)
end

-- Setup Cinemachine from game's setting.json
-- Internal use only, don't call this except initializing from json purpose
function Cinemachine:_loadFromJsonConfig(cfg)
    if not next(cfg or {}) then
        return
    end

    local cam = self:createCamera(cfg.name or "main", cfg)
    cam.followId = Me:getInstanceID()
    cam.lookAtId = Me:getInstanceID()
end

-- Enable/Disable entire Cinemachine's functionality
function Cinemachine:enable(enabled)
	CinemachineBrain.Instance():enable(enabled)
end

-- Enable/Disable debug mode. In debug mode, additional marks would be drawn with
-- virtual cameras to help debugging
function Cinemachine:enableDebug(enabled)
    CinemachineBrain.Instance():enableDebug(enabled)
end

-- Enable/Disable named camere's body part
function Cinemachine:enableBody(name, enabled)
    self:getCamera(name):enableBody(enabled)
end

-- Enable/Disable named camere's aim part
function Cinemachine:enableAim(name, enabled)
    self:getCamera(name):enableAim(enabled)
end

-- Enable/Disable named camere's noise part
function Cinemachine:enableNoise(name, enabled)
    self:getCamera(name):enableNoise(enabled)
end

-- Enable/Disable named camere's avoider part
function Cinemachine:enableAvoider(name, enabled)
    self:getCamera(name):enableAvoider(enabled)
end

-- Enable/Disable named camere's postprocessor part
function Cinemachine:enablePostprocessor(name, enabled)
    self:getCamera(name):enablePostprocessor(enabled)
end

-- Set named camera's follow target (instance)
function Cinemachine:setFollow(name, instance)
    self:getCamera(name).followId = instance and instance:getInstanceID() or 0
end

-- Set named camera's look at target (instance)
function Cinemachine:setLookAt(name, instance)
    self:getCamera(name).lookAtId = instance and instance:getInstanceID() or 0
end

-- Helper function creating a top-view debug camera
function Cinemachine:createDebugCamera(name)
    self:createCamera(name or "debug", {
        follow = Me,
        lookAt = Me,
        body = {
            type = "HardLockToTarget",
            offset = {0, 15, 0},
            localspace = false,
        },
        aim = {
            type = "HardLookAt",
        },
    })
end

---------------------------------------------------------
-- Private functions below
---------------------------------------------------------
Cinemachine.blendCallbacks = {}
Cinemachine.blendCallbackId = 0
function Cinemachine:saveBlendCallback(callback)
    if not callback then
        return 0
    end

    self.blendCallbackId = (self.blendCallbackId or 0) + 1
    self.blendCallbacks[self.blendCallbackId] = callback
    return self.blendCallbackId
end

function Cinemachine:onBlendResult(callbackId, success)
    local func = self.blendCallbacks[callbackId]
    if not func then
        return
    end

    if success then
        func()
    end
    self.blendCallbacks[callbackId] = nil
end