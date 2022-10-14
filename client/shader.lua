local c = require "shader.core"

local PRECISION = "#version 100\nprecision mediump float;\n"

---@language Renderscript
local vs_common = PRECISION.. [[
	attribute vec3 inPosition;
	attribute vec4 inColor;
	attribute vec2 inTexCoord;

	uniform mat4 matWVP;

	varying vec4 color;
	varying vec2 texCoord;

	void main(void)
	{
		gl_Position = matWVP * vec4(inPosition, 1.0);

		color = inColor;
		texCoord = inTexCoord;
	}
]]

local ps_common = PRECISION .. [[
	uniform sampler2D texSampler;

	varying vec4 color;
	varying vec2 texCoord;

	void main(void)
	{
		vec4 textureColor = texture2D(texSampler, texCoord);
		gl_FragColor = textureColor * color;
	}
]]

local ps_circle = PRECISION .. [[
	uniform sampler2D texSampler;
	uniform vec4 iSize;
	uniform float iRadius;
	uniform vec4 iColor;
	uniform float iThk;
	uniform float iSolid;

	varying vec4 color;
	varying vec2 texCoord;

	void main(void)
	{
		float px = texCoord.x * iSize.x;
		float py = texCoord.y * iSize.y;
		float dx = px - iSize.x / 2.0;
		float dy = py - iSize.y / 2.0;
		float dis = sqrt(dx * dx + dy * dy);
		float solid = iSolid;

		vec4 color = iColor;
		float dis2 = abs(iRadius - dis);

		if (dis2 < iThk)
		{
			if (solid < 1.0)
			{
				color.a = 1.0 - smoothstep(0.0, iThk, dis2);
			}
			gl_FragColor = color;
		}
		else
		{
			vec4 textureColor = texture2D(texSampler, texCoord);
			gl_FragColor = textureColor * vec4(1.0, 1.0, 1.0, 0.0);
		}
	}
]]

local ps_clock = PRECISION .. [[
	uniform sampler2D texSampler;
	uniform vec4 iSize;
	uniform vec4 iColor;
	uniform float iProgress;
	uniform float iRadius;
	uniform float iColorAlpha;

	varying vec4 color;
	varying vec2 texCoord;

	void main(void)
	{
		float px = texCoord.x * iSize.x;
		float py = texCoord.y * iSize.y;

		vec4 color = iColor;
		float progress = 1.0 - (degrees(atan(px - iSize.x / 2.0, py - iSize.y / 2.0)) + 180.0) / 360.0;
		if (progress > iProgress)
		{
			if(-1.0 != iColorAlpha && -1.0 != iRadius){
				float dx = px - iSize.x / 2.0;
				float dy = py - iSize.y / 2.0;
				float dis = sqrt(dx * dx + dy * dy);
				color.a = iColorAlpha - smoothstep(iRadius, iRadius, dis);
			}
			gl_FragColor = color;
		}
		else
		{
			vec4 textureColor = texture2D(texSampler, texCoord);
			gl_FragColor = textureColor * vec4(1.0, 1.0, 1.0, 0.0);
		}
	}
]]

local ps_guidemask= PRECISION .. [[
	uniform sampler2D texSampler;
	uniform vec4 iSize;
	uniform vec4 iColor;
	uniform float iProgress;
	uniform float iRadius;
	uniform vec4 iPos;

	varying vec4 color;
	varying vec2 texCoord;

	void main(void)
	{
		float px = texCoord.x * iSize.x;
		float py = texCoord.y * iSize.y;

		float progress = 1.0 - (degrees(atan(iPos.x , iPos.y)));

		float dis = (px - iPos.x)*(px - iPos.x) + (py - iPos.y)*(py - iPos.y);

		if (progress <= iProgress && dis <= iRadius * iRadius)
		{
			vec4 textureColor = texture2D(texSampler, texCoord);
			gl_FragColor = textureColor * vec4(1.0, 1.0, 1.0, 0.0);
		}
		else
		{
			gl_FragColor = iColor;
		}
	}
]]

local ps_rectangle_mask= PRECISION .. [[
	uniform sampler2D texSampler;
	uniform vec4 iSize;
	uniform vec4 iColor;
	uniform vec4 iTopleft;
	uniform vec4 iBottomright;

	varying vec4 color;
	varying vec2 texCoord;

	void main(void)
	{
		float px = texCoord.x * iSize.x;
		float py = texCoord.y * iSize.y;

		if (iTopleft.x > px || iBottomright.x <= px
            || iTopleft.y > py || iBottomright.y <= py)
		{	
            gl_FragColor = iColor;
		}
		else
		{
            vec4 textureColor = texture2D(texSampler, texCoord);
			gl_FragColor = textureColor * vec4(1.0, 1.0, 1.0, 0.0);
		}
	}
]]

local ps_circle_cut= PRECISION .. [[
	uniform sampler2D texSampler;
	uniform vec4 iSize;
	uniform float iRadius;

	varying vec4 color;
	varying vec2 texCoord;

	void main(void)
	{
		float px = texCoord.x * iSize.x;
		float py = texCoord.y * iSize.y;
		float dx = px - iSize.x / 2.0;
		float dy = py - iSize.y / 2.0;
		float dis = sqrt(dx * dx + dy * dy);

		vec4 textureColor = texture2D(texSampler, texCoord);
		if (dis <= iRadius)
		{	
			gl_FragColor = textureColor;
		}
		else
		{
			gl_FragColor = textureColor * vec4(1.0, 1.0, 1.0, 0.0);
		}
	}
]]

local ps_gray = PRECISION .. [[
	uniform sampler2D texSampler;

	varying mediump vec4 color;
	varying mediump vec2 texCoord;

	void main(void)
	{
		vec4 textureColor = texture2D(texSampler, texCoord);
		vec3 weight = vec3(0.299, 0.587, 0.114);
		float gray_value =  dot(textureColor.xyz * color.rgb, weight );
		gl_FragColor = vec4(gray_value, gray_value, gray_value, color.a*textureColor.a);
	}
]]

--15 50
local ps_sectorbar =  PRECISION .. [[
	uniform sampler2D texSampler;
	uniform vec4 iSize;
	uniform float iProgress;
	uniform float iDistancex;
	uniform float iDistancey;

	varying vec4 color;
	varying vec2 texCoord;

	void main(void)
	{
		float px = texCoord.x * iSize.x;
		float py = texCoord.y * iSize.y;
		float dx = px - iDistancex;
		float dy = py - iDistancey;

		
		float act = (degrees(atan(dx, dy)) + 180.0);
		float progress = 1.0 - act / 360.0;
		if (progress < 0.0){
			progress = -progress;
		}

		vec4 textureColor = texture2D(texSampler, texCoord);
		if (progress <= iProgress)
		{	
			gl_FragColor = textureColor;
		}
		else
		{
			gl_FragColor = textureColor * vec4(1.0, 1.0, 1.0, 0.0);
		}
	}
]]


local ps_sectorbar2 =  PRECISION .. [[
	uniform sampler2D texSampler;
	uniform vec4 iSize;
	uniform float iProgress;
	uniform float iDistancex;
	uniform float iDistancey;

	varying vec4 color;
	varying vec2 texCoord;

	void main(void)
	{
		float px = texCoord.x * iSize.x;
		float py = texCoord.y * iSize.y;
		float dx = px - iDistancex;
		float dy = py - iDistancey;


		float act = (degrees(atan(dy, dx)) + 180.0);
		float progress = 1.0 - act / 360.0;
		if (progress < 0.0){
			progress = -progress;
		}

		vec4 textureColor = texture2D(texSampler, texCoord);
		if (progress <= iProgress)
		{
			gl_FragColor = textureColor;
		}
		else
		{
			gl_FragColor = textureColor * vec4(1.0, 1.0, 1.0, 0.0);
		}
	}
]]


local ps_ring = PRECISION .. [[
	uniform sampler2D texSampler;
	uniform vec4 iSize;
	uniform float iHeadProgress;
	uniform float iTailProgress;
	uniform float iInRadius;
	uniform float iOutRadius;

	varying vec2 texCoord;

	void main(void)
	{
		float px = texCoord.x * iSize.x;
		float py = texCoord.y * iSize.y;

		float progress = 1.0 - (degrees(atan(px - iSize.x / 2.0, py - iSize.y / 2.0)) + 180.0) / 360.0;

		vec4 textureColor = texture2D(texSampler, texCoord);
		float dx = px - iSize.x / 2.0;
		float dy = py - iSize.y / 2.0;
		float dis = sqrt(dx * dx + dy * dy);

		if(iHeadProgress <= 1.0)
		{
			if(progress >= iTailProgress && progress <= iHeadProgress)
			{
				if(dis >= iInRadius && dis <= iOutRadius)
				{
					gl_FragColor = textureColor;
				}
				else
				{
					gl_FragColor = textureColor * vec4(1.0, 1.0, 1.0, 0.0);
				}
			}
			else
			{
				gl_FragColor = textureColor * vec4(1.0, 1.0, 1.0, 0.0);
			}
		}
		else
		{	
			float newProgress = iHeadProgress - 1.0;
			if(progress > newProgress && progress < iTailProgress)
			{
				gl_FragColor = textureColor * vec4(1.0, 1.0, 1.0, 0.0);
			}
			else
			{
				if(dis >= iInRadius && dis <= iOutRadius)
				{
					gl_FragColor = textureColor;
				}
				else
				{
					gl_FragColor = textureColor * vec4(1.0, 1.0, 1.0, 0.0);
				}
			}
		}
	}
]]

local ps_ring2 = PRECISION .. [[
	uniform sampler2D texSampler;
	uniform vec4 iSize;
	uniform float iHeadProgress;
	uniform float iTailProgress;
	uniform float iInRadius;
	uniform float iOutRadius;

	varying vec2 texCoord;

	void main(void)
	{
		float px = texCoord.x * iSize.x;
		float py = texCoord.y * iSize.y;

		float progress = 1.0 - (degrees(atan(px - iSize.x / 2.0, py - iSize.y / 2.0)) + 180.0) / 360.0;

		vec4 textureColor = texture2D(texSampler, texCoord);
		float dx = px - iSize.x / 2.0;
		float dy = py - iSize.y / 2.0;
		float dis = sqrt(dx * dx + dy * dy);

		if(iHeadProgress <= 1.0)
		{
			if(dis >= iInRadius && dis <= iOutRadius)
			{
				if(progress >= iTailProgress && progress <= iHeadProgress)
				{
					gl_FragColor = textureColor;
				}
				else
				{
					gl_FragColor = textureColor * vec4(1.0, 1.0, 1.0, 0.0);
				}
			}
			else
			{
				gl_FragColor = textureColor;
			}
		}
		else
		{	
			float newProgress = iHeadProgress - 1.0;
			if(dis >= iInRadius && dis <= iOutRadius)
			{
				if(progress > newProgress && progress < iTailProgress)
				{
					gl_FragColor = textureColor * vec4(1.0, 1.0, 1.0, 0.0);
				}
				else
				{
					gl_FragColor = textureColor;
				}
			}
			else
			{
				gl_FragColor = textureColor;
			}
		}
	}
]]

local programs = {
	NORMAL = {
		vs = vs_common,
		ps = ps_common
	},

	SECTOR = {
		ps = ps_sectorbar,
		uniform = {
			{
				name = "iDistancey",
				type = "float",
				value = 0.0
			},
			{
				name = "iDistancex",
				type = "float",
				value = 0.0
			},
			{
				name = "iSize",
				type = "float4",
				value = {0.0, 0.0, 0.0, 0.0}
			},
			{
				name = "iProgress",
				type = "float",
				value = 1.0
			}
		}
	},

	SECTOR2 = {
		ps = ps_sectorbar2,
		uniform = {
			{
				name = "iDistancey",
				type = "float",
				value = 0.0
			},
			{
				name = "iDistancex",
				type = "float",
				value = 0.0
			},
			{
				name = "iSize",
				type = "float4",
				value = {0.0, 0.0, 0.0, 0.0}
			},
			{
				name = "iProgress",
				type = "float",
				value = 1.0
			}
		}
	},

	CIRCLE = {
		ps = ps_circle,
		uniform = {
			{
				name = "iSize",
				type = "float4",
				value = {0.0, 0.0, 0.0, 0.0}
			},
			{
				name = "iRadius",
				type = "float",
				value = 32.0
			},
			{
				name = "iColor",
				type = "float4",
				value = {0.0, 0.0, 0.0, 0.5}
			},
			{
				name = "iThk",
				type = "float",
				value = 5.0
			},
			{
				name = "iSolid",
				type = "float",
				value = 0.0
			}
		}
	},

	CLOCK = {
		ps = ps_clock,
		uniform = {
			{
				name = "iSize",
				type = "float4",
				value = {0.0, 0.0, 0.0, 0.0}
			},
			{
				name = "iColor",
				type = "float4",
				value = {0.0, 0.0, 0.0, 0.5}
			},
			{
				name = "iProgress",
				type = "float",
				value = 1.0
			},
			{
				name = "iRadius",
				type = "float",
				value = -1.0
			},
			{
				name = "iColorAlpha",
				type = "float",
				value = -1.0
			}
		}
	},

	GUIDEMASK = {
		ps = ps_guidemask,
		uniform = {
			{
				name = "iSize",
				type = "float4",
				value = {0.0, 0.0, 0.0, 0.0}
			},
			{
				name = "iColor",
				type = "float4",
				value = {0.0, 0.0, 0.0, 0.5}
			},
			{
				name = "iProgress",
				type = "float",
				value = 1.0
			},
			{
				name = "iRadius",
				type = "float",
				value = 1.0
			},
			{
				name = "iPos",
				type = "float4",
				value = {1.0, 1.0, 0.0, 0.0}
			}
		}
	},

	CIRCLECUT = {
		ps = ps_circle_cut,
		uniform = {
			{
				name = "iSize",
				type = "float4",
				value = {0.0, 0.0, 0.0, 0.0}
			},
			{
				name = "iRadius",
				type = "float",
				value = 1.0
			}
		}
	},

	RECTANGLEMASK = {
		ps = ps_rectangle_mask,
		uniform = {
			{
				name = "iSize",
				type = "float4",
				value = {0.0, 0.0, 0.0, 0.0}
			},
			{
				name = "iColor",
				type = "float4",
				value = {0.0, 0.0, 0.0, 0.0}
			},
			{
				name = "iTopleft",
				type = "float4",
				value = {0.0, 0.0, 0.0, 0.0}
			},
			{
				name = "iBottomright",
				type = "float4",
				value = {0.0, 0.0, 0.0, 0.0}
			}
		}
	},

	RING = {
		ps = ps_ring,
		uniform = {
			{
				name = "iSize",
				type = "float4",
				value = {0.0, 0.0, 0.0, 0.0}
			},
			{
				name = "iHeadProgress",
				type = "float",
				value = 0.0
			},
			{
				name = "iTailProgress",
				type = "float",
				value = 0.0
			},
			{
				name = "iInRadius",
				type = "float",
				value = 0.0
			},
			{
				name = "iOutRadius",
				type = "float",
				value = 0.0
			},
		}
	},

	RING2 = {
		ps = ps_ring2,
		uniform = {
			{
				name = "iSize",
				type = "float4",
				value = {0.0, 0.0, 0.0, 0.0}
			},
			{
				name = "iHeadProgress",
				type = "float",
				value = 0.0
			},
			{
				name = "iTailProgress",
				type = "float",
				value = 0.0
			},
			{
				name = "iInRadius",
				type = "float",
				value = 0.0
			},
			{
				name = "iOutRadius",
				type = "float",
				value = 0.0
			},
		}
	},

	GRAY = {
		ps = ps_gray
	}
}

for name, data in pairs(programs) do
	c.load(name, data.vs or vs_common, data.ps or ps_common)
end

return programs
