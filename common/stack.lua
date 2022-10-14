local Stack = L("Stack", {})

function Stack:Clear()
    self.stack = {}
end

function Stack:Push(element)
    self.stack[#self.stack + 1] = element
end

function Stack:Top()
    return self.stack[#self.stack]
end

function Stack:Pop(stack)
    local stack = self.stack
    local ret = stack[#stack]
    stack[#stack] = nil
    return ret
end

function Stack:Size(stack)
    return #self.stack
end

function Stack:Create()
    local s = { stack = {} }
    return setmetatable(s, { __index = Stack })
end

RETURN(Stack)