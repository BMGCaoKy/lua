local Utils = require "common.api.util"


local constraintMap = {
    Weld = "FixedConstraint",
    Hinge = "HingeConstraint",
    Rod = "RodConstraint",
    Spring = "SpringConstraint",
    Rope = "RopeConstraint",
    SlidingJoint = "SliderConstraint"
}

local materials = {
	{ texture = "part_suliao.tga",		props = {2.2, 0.3, 0.37		}},
	{ texture = "part_gangban.tga",		props = {7.9, 0.06, 0.2		}},
	{ texture = "part_muban.tga",		props = {2.5, 0.2, 0.28		}},
	{ texture = "part_caodi.tga",		props = {1.3, 0.1, 0.35		}},
	{ texture = "part_bingkuai.tga",	props = {0.9, 0.2, 0.022	}},
	{ texture = "part_eluanshi.tga",	props = {4.5, 0.17, 0.53	}},
	{ texture = "part_shiban.tga",		props = {2.7, 0.17, 0.61	}},
	{ texture = "part_zhuankuai.tga",	props = {2.5, 0.15, 0.6		}},
	{ texture = "part_ditan.tga",		props = {0.6, 0.06, 0.46	}},
	{ texture = "part_shuini.tga",		props = {4, 0.2, 0.63		}},
	{ texture = "part_shatu.tga",		props = {3.4, 0.06, 0.4		}},
	{ texture = "part_dalishi.tga",		props = {2.7, 0.17, 0.56	}},
	{ texture = "part_mutou.tga",		props = {1.26, 0.15, 0.28	}},	
	{ texture = "part_xiushijinshu.tga",props = {7.70, 0.05, 0.44	}},
	{ texture = "part_huawenban.tga",   props = {5.50, 0.07, 0.56	}},
	{ texture = "part_xibo.tga",		props = {5.50, 0.03, 0.26	}},
	{ texture = "part_buliao.tga",		props = {0.60, 0.03, 0.46	}},
	{ texture = "part_huagangyan.tga",	props = {3.85, 0.17, 0.20	}},
	{ texture = "part_luanshi.tga",		props = {3.63, 0.17, 0.20	}},
	{ texture = "part_boli.tga",		props = {2.20, 0.18, 0.15	}},
	{ texture = "part_shihuizhuan.tga", props = {2.93, 0.20, 0.74	}}
}

---@param type Enum.ConstraintType
function BasePart:GetConstraints(type)
    local constraints = self:getAllConstrainPtr()
    if not type or not constraintMap[type] then
        return constraints
    end
    local filterRet = {}
    local target = constraintMap[type]
    for _, cst in pairs(constraints) do
        if cst:isA(target) then
            filterRet[#filterRet + 1] = cst
        end
    end
    return filterRet
end

function BasePart:MoveUntilCollide(displacement, isWorldSpace)
    if isWorldSpace then
        self:moveUntilCollide(displacement)
    else
        self:moveUntilCollideInLocalSpace(displacement)
    end
end

local function getMaterialProperty(texture)
	for _, item in ipairs(materials) do
		if item.texture == texture then
			return item.props
		end
	end

	return {1, 0.9, 0.9}
end

function BasePart:ResetMaterialPhysicsProperties(material)
    material = material or self:getMaterialPath()
    local props = getMaterialProperty(material)
    self:setDensity(props[1]);
    self:setRestitution(props[2]);
    self:setFriction(props[3]);
end

function BasePart:SetMaterial(material)
    self:setMaterialPath(material)
    if not self.hasCustomPhysicProperties then
        self:ResetMaterialPhysicsProperties(material)
    end
end

function BasePart:GetMaterial()
    return self:getMaterialPath()
end

function BasePart:SetCustomPhysicProperties(props)
    local isValid = false
    if type(props) == "table" then
        local density = props.Density
        local friction = props.Friction
        local elasticity = props.Elasticity
        if density then
            self:setDensity(density)
        end
        if friction then
            self:setFriction(math.clamp(friction, 0, 1))
        end
        if elasticity then
            self:setRestitution(math.clamp(elasticity, 0, 1))
        end
        isValid = density or friction or elasticity
    end
    self.hasCustomPhysicProperties = isValid
    if not self.hasCustomPhysicProperties then
        self:ResetMaterialPhysicsProperties()
    end
end

function BasePart:GetCustomPhysicProperties()
    if self.hasCustomPhysicProperties then
        return PhysicProperties.new(self.Density, self.Friction, self.Elasticity)
    end
end

-- 因为csgshape不对外暴露，这里会附加csgshape的一些属性和接口
local fieldMap =
{
    Material =  {get = "GetMaterial", set = "SetMaterial"},
    Color = {get = "getColor", set = "setColor", getTypeFunc = Utils.ArrayToColor3, setTypeFunc = Utils.Color3ToArray},
    Transparency = {get = "getAlpha", set = "setAlpha"},
    Anchored = {get = "isUseAnchor", set = "setUseAnchor"},
    UseGravity = {get = "isUseGravity", set = "setUseGravity"},
    CanCollide = {get = "isUseCollide", set = "setUseCollide"},
    CollisionGroupID = {get = "getCollisionGroup", set = "setCollisionGroup"},
    CustomPhysicProperties = {get = "GetCustomPhysicProperties", set = "SetCustomPhysicProperties"},
    --[ReadOnly]
    Density = {get = "getDensity"},
    Friction = {get = "getFriction"},
    Elasticity = {get = "getRestitution"},
    Mass = {get = "getMass"},

    --CenterOfMass todo: 引擎暂时不好支持，等physix
    AngularVelocity = {get = "getCurAngleVelocity", set = "setAngleVelocity", getTypeFunc = Utils.ToNewVector3},
    LinearVelocity = {get = "getCurLineVelocity", set = "setLineVelocity", getTypeFunc = Utils.ToNewVector3},

    ApplyForce = {func = "applyForce"},
    ApplyTorque = {func = "applyTorque"},
    
    IsConstrainted = {func = "isConstrainted"},


}

APIProxy.RegisterFieldMap(fieldMap)