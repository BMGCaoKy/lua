local PhysicProperties = class("PhysicProperties") --- @class PhysicProperties

function PhysicProperties:ctor(density, friction, elasticity)
    self.Density = density
    self.Friction = friction
    self.Elasticity = elasticity
end

function PhysicProperties:__tostring()
    return string.format("PhysicProperties {Density: %s, Friction: %s, Elasticity: %s}", self.Density, self.Friction, self.Elasticity)
end