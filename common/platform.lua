local platform = {}

platform.WINDOWS   		= 1
platform.LINUX     		= 2
platform.MAC_OSX   		= 3
platform.MAC_IOS   		= 4
platform.ANDROID   		= 5
platform.NACL			= 6

function platform.ZBStudioPath()
    return os.getenv("ZBStudioPath") or "bin/zbstudio"
end

return platform

