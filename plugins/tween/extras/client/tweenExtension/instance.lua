function Instance.doMove(instance, to, duration)
    local function getter()
    end
    
    local function setter()
    end
    
    local operator = Tween.tweener(getter, setter, to, duration)
    
    return operator
end

function Instance.doBaselMove(instance, points, duration)
    
end

function Instance.doRotate(instance, to, duration)
    local function getter()
        return instance:getRotation()
    end
    
    local function setter(value)
        instance:setRotation(value)
    end
    
    local operator = Tween.tweener(getter, setter, Vector3.new(to.x, to.y, to.z), duration, "InstanceDoRotate_" .. instance.id)
    
    local oldFrom = operator.from
    
    function operator:from(value)
        return oldFrom(self, Vector3.new(value.x, value.y, value.z))
    end
    
    return operator
end

function Instance.doRotateX(instance, to, duration)
    local function getter()
        return instance:getRotation().x
    end
    
    local function setter(value)
        local rotation = instance:getRotation()
        instance:setRotation(Vector3.new(value, rotation.y, rotation.z))
    end
    
    return Tween.tweener(getter, setter, to, duration, "InstanceDoRotateX_" .. instance.id)
end

function Instance.doRotateY(instance, to, duration)
    local function getter()
        return instance:getRotation().y
    end
    
    local function setter(value)
        local rotation = instance:getLocalRotation()
        instance:setLocalRotation(Vector3.new(rotation.x, value, rotation.z))
    end
    
    return Tween.tweener(getter, setter, to, duration, "InstanceDoRotateY_" .. instance.id)
end

function Instance.doRotateZ(instance, to, duration)
    local function getter()
        return instance:getRotation().z
    end
    
    local function setter(value)
        local rotation = instance:getLocalRotation()
        instance:setLocalRotation(Vector3.new(rotation.x, rotation.y, value))
    end
    
    return Tween.tweener(getter, setter, to, duration, "InstanceDoRotateZ_" .. instance.id)
end
