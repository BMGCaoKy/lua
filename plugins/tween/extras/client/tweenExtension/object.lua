function Object.doMove(obj, to, duration)
    if not obj:isValid() then
        perror("this object is not valid.")
        return
    end

    local getter = function()
        return obj:getPosition()
    end

    local setter = function(value)
        obj:setPosition(value)
    end

    return Tween.tweener(getter, setter, to, duration, "ObjectDoMove_" .. obj.objID)
end

function Object.doRotate(obj, to, duration)
    local getter = function()
        return obj:getRotationVector3()
    end

    local setter = function(value)
        obj:rotateByVector3(value)
    end

    local operator = Tween.tweener(getter, setter, Vector3.new(to.x, to.y, to.z), duration, "ObjectDoRotate_" .. obj.objID)

    local oldFrom = operator.from
    function operator:from(value)
        return oldFrom(self, Vector3.new(value.x, value.y, value.z))
    end

    return operator
end

function Object.doRotateY(self, to, duration)
    local getter = function()
        return self:getRotationYaw()
    end

    local setter = function(value)
        self:setRotationYaw(value)
        print(value, self:getRotationYaw(), math.deg(self:getRotationYaw()))
    end

    return Tween.tweener(getter, setter, to, duration, "ObjectDoRotateY_" .. self.objID)
end