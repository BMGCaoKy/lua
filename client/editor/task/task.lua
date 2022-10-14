return {
	entry = function(linda, task, ...)
		set_finalizer(function( err, stk)
			if err and type( err) ~= "userdata" then
				-- no special error: true error
				print( " error: "..tostring(err))
				return Task
			elseif type( err) == "userdata" then
				-- lane cancellation is performed by throwing a special userdata as error
				print( "after cancel")
			else
				-- no error: we just got finalized
				print( "finalized")
			end
		end)


		-- 找到对应的 task，执行
		return obj:exec(...)
	end,

	STATUS_ERROR	= -1,
	STATUS_INIT		= 0,
	STATUS_RUNNING	= 1,
	STATUS_FINISH	= 2,
}
