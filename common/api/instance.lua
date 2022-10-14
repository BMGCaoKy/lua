function Instance.new(className, parent, params)
    local instance
    if className == "WeldConstraint" then
        className = "FixedConstraint"
    end
    if className == "Entity" then
        instance = Instance.createEntity({cfgName = params.cfgName, map = params.map})
    elseif className == "DropItem" then
        return
        --todo
    elseif className == "Missile" then
        return
        --instance = Missile.Create(params.cfgName, { map = params.map, fromID = 0, targetID = 0, targetDir = 0 })
        --todo
    elseif className == "MeshPart" then
        return -- api暂时不开放动态创建, 目前有bug，可能穿透地面
    else
        instance = Instance.Create(className)
    end
    for k,v in pairs(params or {}) do
        instance[k] = v
    end
    instance:setParent(parent)
    return instance
end

-- -- it is a test interface now : Missile need special handling
-- function Instance.new2(className, parent, createParams)
--     local params = createParams or {}
--     if className == "WeldConstraint" then
--         className = "FixedConstraint"
--     end
--     params.class = className
--     local map = params.map
--     local instance = Instance.newInstance(params, map)
--     instance:setParent(parent)
--     return instance
-- end

function Instance.GetInstanceByID(id)
    return Instance.getByInstanceId(id)
end

function Instance:GetChildren(recursive)
    if recursive then
        return self:getDescendants()
    end
    return self:getAllChild()
end

function Instance:GetAttributes()
    local ret = {}
    self:collectAttributes(ret) -- todo: 有bug
    return ret
end

function Instance:GetMap()
    local scene = self:getScene()
    if not scene then
        return
    end
    local mapObj = scene:getMap()
    local map = World.CurWorld:getMapById(mapObj:getId())
    return map
end

local function hideClientFlag(className)
    local pos = string.find(className, "Client")
    return not pos and className or string.sub(className, 1, pos - 1)
end

local fieldMap =
{
	--[Noraml property]
	Name = {get = "getName", set = "setName"},
	Parent = {get = "getParent", set = "setParent"},

	--[ReadOnly property]
	Map = {get = "GetMap"},
	ClassName = {get = "getTypeName", getTypeFunc = hideClientFlag},
	ID = {get = "getInstanceID"},

	--[Function]
	IsValid = {func = "isValid"},
	Destroy = {func = "destroy"},
	Clone = {func = "clone"},
	IsAncestorOf = {func = "isAncestorOf"},
	IsDescendantOf = {func = "isDescendantOf"},
	IsClass = {func = "isA"},
	FindFirstAncestor = {func = "findFirstAncestor"},
	FindFirstAncestorByClass = {func = "findFirstAncestorWhichIsA"},
	FindFirstChild = {func = "findFirstChild"},
	FindFirstChildByClass = {func = "findFirstChildWhichIsA"},
	--GetChildren
	AddChild = {func = "addChild"},
	DestroyAllChildren = {func = "delAllChild"},
	--GetAttributes
	GetAttribute = {func = "getAttribute"},
	SetAttribute = {func = "setAttribute"},
}

APIProxy.RegisterFieldMap(fieldMap)
