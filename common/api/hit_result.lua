local HitResult = class("HitResult") --- @class HitResult

function HitResult:ctor(instance, position, normal, distance)
    self.Instance = instance
    self.Position = position
    self.Normal = normal
    self.Distance = distance
end

function HitResult:__tostring()
    return string.format("HitResult {Instance: %s, Position: %s, Normal: %s, Distance: %s}", self.Instance, self.Position, self.Normal, self.Distance) -- todo
end