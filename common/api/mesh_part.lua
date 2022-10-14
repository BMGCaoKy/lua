local fieldMap = 
{
    Mesh = {get = "getMesh", set = "setMesh"},
    Texture = {get = "getTexture", set = "setTexture"} -- TODO: delete ?
}

APIProxy.RegisterFieldMap(fieldMap)