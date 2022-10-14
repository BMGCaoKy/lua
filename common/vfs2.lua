function VFS2:init()
    self:start()
end

local io_open, lfs_dir, lfs_touch, lfs_attributes, package_searchpath, _loadfile
function VFS2:start()
    io_open = io_open or io.open
    io.open = function(path, mod)
        local localFile, msg = io_open(path, mod)
        if localFile then
            return localFile, msg
        end

		path = Lib.normalizePath(path)
        local zipFile = ZipFile.new(path)
        if not zipFile:isExist() then
            zipFile = nil
            msg = string.format("open zip file fail: %s ", path)
        end
        return zipFile, msg
    end

    lfs_dir = lfs_dir or lfs.dir
    lfs.dir = function(dir)
        local attr = lfs.attributes(dir, nil, true)
        if attr then
            --print(string.format("lfs.dir local : %s ", dir))
            return lfs_dir(dir)
        end
        local dirName = Lib.getZipEntryName(dir)
        --zip的目录最后都带"/"
        if not Lib.stringEnds(dirName, "/") and dirName ~= "" then
            dirName = dirName .. "/"
        end
        --fileList包含子文件名和子目录名，pureName,目录名后面带"/"
        local fileList = ZipResourceManager.Instance():getGameFilesInEntry(dirName)
        local all = {}
        for _, file in pairs(fileList) do
            --if Lib.stringEnds(file, "/") then
            --    file = string.sub(file, 1, string.len(file) - 1)
            --end
            table.insert(all, file)
        end
        local index = 0
        local count = #fileList
        return function()
            index = index + 1
            if index > count then
                --print("End dir!!!!!!!!!!!!!!!!!!!!!!!!!:" .. dir)
                return nil
            end
            if string.sub(all[index], -1) == "/" then 
                return string.sub(all[index], 1, string.len(all[index]) - 1)
            end
            return all[index]
        end, all
    end

    lfs_attributes = lfs_attributes or lfs.attributes
    lfs.attributes = function(path, attributename, raw)
        local result = lfs_attributes(path, attributename)
        if result then
            return result
        end
        if raw then
            return nil
        end
		path = Lib.normalizePath(path)

		local fileName
		if FileResourceManager:Instance():ResourceExistInZip(path) then 
			fileName = Lib.getZipEntryName(path, true)
		elseif string.sub(path, -1) ~= "/" and FileResourceManager:Instance():ResourceExistInZip(path.."/") then 
			path = path.."/"
			fileName = Lib.getZipEntryName(path, true)
		end
        if fileName then
            if attributename == "mode" then
                local archive = ZipResourceManager.Instance():getArchByAbsPath(path)
                if archive:isFile(fileName) then
                    result = "file"
                else
                    result = "directory"
                end
            elseif attributename == "modification" then
                local time = ZipResourceManager.Instance():getEntryTimestampByAbsPath(path)
                if time == 0 then
                    result = nil
                else
                    result = time
                end
            else
                result = {}
                local archive = ZipResourceManager.Instance():getArchByAbsPath(path)
                if archive:isFile(fileName) then
                    result["mode"] = "file"
                else
                    result["mode"] = "directory"
                end
                result["modification"] = ZipResourceManager.Instance():getEntryTimestampByAbsPath(path)
            end
        else
            --print(traceback())
            --perror(string.format("lfs.attributes fail path:%s  ||  zipName:%s  ||  attributename:%s", path, fileName, attributename))
            result = nil
        end
        return result
    end

    lfs_touch = lfs_touch or lfs.touch
    lfs.touch = function(filePath)
        local ok, msg = lfs_touch(filePath)
        if not ok then
            local fileName = Lib.getZipEntryName(filePath)
            ok = FileResourceManager.Instance():TouchToGameZip(fileName)
            if ok then
                msg = string.format("Lib.touch in Zip: %s", fileName)
            else
                msg = string.format("Lib.touch in Zip fail: %s", fileName)
            end
        end
        return ok, msg
    end

	package_searchpath = package_searchpath or package.searchpath
	package.searchpath = function(name, path, sep, dirsep)
		local path = package_searchpath(name, path, sep, dirsep) or searchpathEx(name, path, sep, dirsep)
		
		return path
	end

	_loadfile = _loadfile or loadfile
	loadfile = function(path, mode, env)
		local func, errmsg = _loadfile(path, mode, env)
		if func then
		else
			local chunk = FileResourceManager.Instance():ReadResourceInZip(path)
			func, errmsg = load(chunk, "@"..path, mode, env)
		end
		
		return func, errmsg
	end
end

VFS2:init()