local BindHandler = BindHandler

function BindHandler:ctor(Function)
    self.__Function = Function
    self.__Data = {}
    self.__Destroy = nil --不许为空, 调用者new出来后应当立刻赋值
    self.__Active = false
end

function BindHandler:Destroy()
    self.__Function = nil
    self.__Data = nil
    self.__Active = false
    if self.__Destroy then
        self.__Destroy()
        self.__Destroy = nil
    else
        --Lib.logWarning("Attempt to destroy an EventHandler that has already been destroyed", traceback())
    end
end

function BindHandler:SetDestroy(Function)
    self.__Destroy = Function
end

function BindHandler:Activate()
    self.__Active = true
end

function BindHandler:IsActive()
    return self.__Active
end

function BindHandler:GetFunction()
    if not self:IsActive() then
        Lib.logWarning("Attempt to call a unactivated event", traceback())
        return
    end

    return self.__Function
end

function BindHandler:GetFunctionRaw()
    return self.__Function
end

function BindHandler:GetBindData(key)
    return self.__Data[key]
end

function BindHandler:SetBindData(key, value)
    self.__Data[key] = value
end

function BindHandler:ChangeBind(Function)
    self.__Function = Function
end
