function Object:rotateByVector3(v3)
    self:setRotation(v3.y, v3.x, v3.z)
end

function Object:getRotationVector3()
    return Vector3.new(self:getRotationPitch(), self:getRotationYaw(), self:getRotationRoll())
end