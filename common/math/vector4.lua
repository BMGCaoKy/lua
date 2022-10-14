
local index = {}
local v4mt = { __index=index}

local function new(x, y, z, w)
	local v4 = {x=x, y=y, z=z, w=w}
	return setmetatable(v4, v4mt)
end

function v4mt:__add(v4)
	return new(self.x+ v4.x, self.y+ v4.y, self.z+ v4.z, self.w+ v4.w)
end
function v4mt:__sub(v4)
	return new(self.x- v4.x, self.y- v4.y, self.z- v4.z, self.w- v4.w)
end
function v4mt:__mul(n)
	assert(type(n)=="number")
	return new(self.x*n, self.y*n, self.z*n, self.w*n)
end
function v4mt:__div(n)
	assert(type(n)=="number")
	return new(self.x/n, self.y/n, self.z/n, self.w/n)
end
function v4mt:__unm()
	return new(-self.x, -self.y, -self.z, -self.w)
end
function v4mt:__eq(v4)
	return self.x== v4.x and self.y== v4.y and self.z== v4.z and self.w== v4.w
end
function v4mt:__lt(v4)
	return self.x< v4.x and self.y< v4.y and self.z< v4.z and self.w< v4.w
end
function v4mt:__le(v4)
	return self.x<= v4.x and self.y<= v4.y and self.z<= v4.z and self.w<= v4.w
end
function v4mt:__tostring()
	return string.format("{%s,%s,%s,%s}", self.x, self.y, self.z, self.w)
end

function index:add(v4)
	self.x = self.x + v4.x
	self.y = self.y + v4.y
	self.z = self.z + v4.z
	self.w = self.w + v4.w
end

function index:sub(v4)
	self.x = self.x - v4.x
	self.y = self.y - v4.y
	self.z = self.z - v4.z
	self.w = self.w - v4.w
end

function index:mul(n)
	assert(type(n)=="number")
	self.x = self.x * n
	self.y = self.y * n
	self.z = self.z * n
	self.w = self.w * n
end

function index:lenSqr(n)
	return self.x*self.x + self.y*self.y + self.z*self.z + self.w*self.w
end

function index:len(n)
	return math.sqrt(self.x*self.x + self.y*self.y + self.z*self.z + self.w*self.w)
end

function index:unpack()
	return self.x, self.y, self.z, self.w
end

function index:copy()
	return new(self.x, self.y, self.z, self.w)
end

function index:isZero()
	return self.x==0 and self.y==0 and self.z==0 and self.w==0
end

function index:inArea(v4, offset)
	return v4.x >= self.x - offset and v4.x <= self.x + offset
			and v4.y >= self.y - offset and v4.y <= self.y + offset
			and v4.z >= self.z - offset and v4.z <= self.z + offset
			and v4.w >= self.w - offset and v4.w <= self.w + offset
end

function index:normalize()
	local len = self:len()
	if len>0 then
		self:mul(1/len)
	end
end

function index:blockPos()
	return new(math.floor(self.x), math.floor(self.y), math.floor(self.z))
end

function Lib.v4(x, y, z, w)
	return new(x, y, z, w)
end

function Lib.tov4(v4)
	return setmetatable(v4, v4mt)
end

function Lib.strToV4(str)
	if type(str) ~= "string" then
		return nil
	end
	local result = Lib.splitString(str, ",", true)
	return Lib.v4(result[1], result[2], result[3], result[4])
end
