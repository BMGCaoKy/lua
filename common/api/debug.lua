function Debug:Log(...)
    Lib.logInfo(...)
end

function Debug:LogWarning(...)
    Lib.logWarning(...)
end

function Debug:LogError(...)
    Lib.logError(...)
end

function Debug:LogTraceback(level)
    print(debug.traceback("LogTraceback", level or 1))
end

function Debug:ClearLog()
    os.execute("cls")
end

