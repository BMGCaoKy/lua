local misc = require "misc"
local lfs = require "lfs"

local locale = os.setlocale(".UTF-8", "collate") and os.setlocale(".UTF-8", "ctype")
os.setlocale("C", "numeric")

local u8s_to_mbs = misc.win_u8s_to_mbs
local mbs_to_u8s = misc.win_mbs_to_u8s

if u8s_to_mbs and mbs_to_u8s then

	local is_locale_utf8 = false
	if locale then
		is_locale_utf8 = true
		print("Locale: " .. locale)
		return
	else
		locale = os.setlocale("")
		print("Locale: " .. locale)
	end

	---------------- lua ----------------

	local do_file = dofile
	dofile = function(filename)
		--print("### [u8-mb] dofile", filename)
		return do_file(u8s_to_mbs(filename))
	end

	local load_file = loadfile
	loadfile = function(filename, mode, env)
		--print("### [u8-mb] loadfile", filename)
		return load_file(u8s_to_mbs(filename), mode, env)
	end

	local io_open = io.open
	io.open = function(filename, mode)
		--print("### [u8-mb] io.open", filename)
		return io_open(u8s_to_mbs(filename), mode)
	end

	local io_popen = io.popen
	io.popen = function(prog, mode)
		--print("### [u8-mb] io.popen", prog)
		return io_popen(u8s_to_mbs(prog), mode)
	end

	local os_execute = os.execute
	os.execute = function(command)
		--print("### [u8-mb] os.execute", command)
		return os_execute(u8s_to_mbs(command))
	end

	local os_getenv = os.getenv
	os.getenv = function(varname)
		--print("### [u8-mb] os.getenv", varname)
		return os_getenv(u8s_to_mbs(varname))
	end

	local os_remove = os.remove
	os.remove = function(filename)
		--print("### [u8-mb] os.remove", filename)
		return os_remove(u8s_to_mbs(filename))
	end

	local os_rename = os.rename
	os.rename = function(oldname, newname)
		--print("### [u8-mb] os.rename", oldname, newname)
		return os_rename(u8s_to_mbs(oldname), u8s_to_mbs(newname))
	end

	---------------- lfs ----------------

	local lfs_attributes = lfs.attributes
	lfs.attributes = function(filepath, attributename_attributetable)
		--print("### [u8-mb] lfs.attributes", filepath)
		return lfs_attributes(u8s_to_mbs(filepath), attributename_attributetable)
	end

	local lfs_chdir = lfs.chdir
	lfs.chdir = function(path)
		--print("### [u8-mb] lfs.chdir", path)
		return lfs_chdir(u8s_to_mbs(path))
	end

	local lfs_dir = lfs.dir
	lfs.dir = function(path)
		--print("### [u8-mb] lfs.dir", path)
		local iter, dir_obj = lfs_dir(u8s_to_mbs(path))
		return function()
			local file = iter(dir_obj)
			if file then
				return mbs_to_u8s(file)
			else
				return file
			end
		end, dir_obj
	end

	local lfs_link = lfs.link
	lfs.link = function(old, new, symlink)
		--print("### [u8-mb] lfs.link", old, new)
		return lfs_link(u8s_to_mbs(old), u8s_to_mbs(new), symlink)
	end

	local lfs_lock_dir = lfs.lock_dir
	lfs.lock_dir = function(path)
		--print("### [u8-mb] lfs.lock_dir", path)
		return lfs_lock_dir(u8s_to_mbs(path))
	end

	local lfs_mkdir = lfs.mkdir
	lfs.mkdir = function(path)
		--print("### [u8-mb] lfs.mkdir", path)
		return lfs_mkdir(u8s_to_mbs(path))
	end

	local lfs_rmdir = lfs.rmdir
	lfs.rmdir = function(path)
		--print("### [u8-mb] lfs.rmdir", path)
		return lfs_rmdir(u8s_to_mbs(path))
	end

	local lfs_setmode = lfs.setmode
	lfs.setmode = function(filepath, mode)
		--print("### [u8-mb] lfs.setmode", filepath)
		return lfs_setmode(u8s_to_mbs(filepath), mode)
	end

	local lfs_symlinkattributes = lfs.symlinkattributes
	lfs.symlinkattributes = function(filepath, attributename)
		--print("### [u8-mb] lfs.symlinkattributes", filepath)
		return lfs_symlinkattributes(u8s_to_mbs(filepath), attributename)
	end

	local lfs_touch = lfs.touch
	lfs.touch = function(filepath, atime, mtime)
		--print("### [u8-mb] lfs.touch", filepath)
		return lfs_touch(u8s_to_mbs(filepath), atime, mtime)
	end

	local lfs_currentdir = lfs.currentdir
	lfs.currentdir = function()
		return mbs_to_u8s(lfs_currentdir())
	end

end
