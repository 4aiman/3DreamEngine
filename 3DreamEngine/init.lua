--[[
#3DreamEngine - 3D library by Luke100000
#Copyright 2019 Luke100000
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--]]

local lib = { }

_3DreamEngine = lib
lib.root = (...)
require((...) .. "/functions")
require((...) .. "/shader")
require((...) .. "/loader")
require((...) .. "/present")
require((...) .. "/collision")
require((...) .. "/particlesystem")
require((...) .. "/boneManager")
require((...) .. "/saveTable")

lib.ffi = require("ffi")

function lib.decodeObjectName(self, name)
	if self.nameDecoder == "blender" then
		local last, f = 0, false
		while last and string.find(name, "_", last+1) do
			f, last = string.find(name, "_", last+1)
		end
		return name:sub(1, f and (f-1) or #name)
	else
		return name
	end
end

if love.filesystem.read("debugEnabled") == "true" then
	_DEBUGMODE = true
end


--loader
lib.loader = { }
for d,s in pairs(love.filesystem.getDirectoryItems((...) .. "/loader")) do
	require((...) .. "/loader/" .. s:sub(1, #s-4))
end

matrix = require((...) .. "/matrix")
_3DreamEngine = nil

--sun
lib.sun = {-0.3, 0.6, 0.5}
lib.color_ambient = {1.0, 1.0, 1.0, 0.25}
lib.color_sun = {1.0, 1.0, 1.0, 1.5}

--field of view
lib.fov = 90

--distance fog
lib.fog = 0.0
lib.near = lib.canvasFormats["depth32f"] and 0.1 or lib.canvasFormats["depth24"] and 0.25 or 0.5
lib.far = lib.canvasFormats["depth32f"] and 1000 or lib.canvasFormats["depth24"] and 750 or 500

--root directory of objects
lib.objectDir = ""

--settings
lib.AO_enabled = true
lib.AO_strength = 0.5
lib.AO_quality = 24
lib.AO_quality_smooth = 1
lib.AO_resolution = 0.5

lib.reflections_enabled = false

lib.lighting_max = 16

lib.abstractionDistance = 30

lib.nameDecoder = "blender"

lib.startWithMissing = false

lib.object_light = lib:loadObject(lib.root .. "/objects/light")
lib.object_clouds = lib:loadObject(lib.root .. "/objects/clouds_high", {forceTextured = true})
lib.object_sky = lib:loadObject(lib.root .. "/objects/sky", {forceTextured = true})
lib.texture_missing = love.graphics.newImage(lib.root .. "/missing.png")

--set lib clouds to an cloud texture (noise, tilable) to enable clouds
lib.clouds = false
lib.cloudDensity = 0.5

--set sky sphere (set sky and night to the textures) (if night is nil/false it will only use day)
--time is the factor between sky and night textures (0 is sky) (only works with night tetxure set)
--color can be used to manually set color (vec4), or when set to true it uses realistic lighting
lib.sky = false
lib.night = false
lib.time = 0
lib.color = true

--used as default value for getDayLight() and for the skysphere
lib.dayTime = 0

function lib.init(self)
	self:resize(love.graphics.getWidth(), love.graphics.getHeight())
	self:loadShader()
	
	self.lighting = { }
	
	if self.clouds then
		self.clouds:setWrap("repeat")
		self.object_clouds.objects.Cube.mesh:setTexture(self.clouds)
	end
	
	if self.sky then
		self.sky:setWrap("repeat")
		self.object_sky.objects.Cube.mesh:setTexture(self.sky)
		if self.night then
			self.night:setWrap("repeat")
			self.shaderSkyNight:send("night", self.night)
		end
	end
end

function lib.prepare(self, c, noDepth)
	self.noDepth = noDepth
	
	local cam = c == false and self:newCam() or c or self.cam
	self.currentCam = cam
	
	local sun = {self.sun[1], self.sun[2], self.sun[3]}
	sun[1] = sun[1] * 1000
	sun[2] = sun[2] * 1000
	sun[3] = sun[3] * 1000
	
	self.shaderVars_sun = sun
	self.shaderVars_viewPos = -self.currentCam.transform^"T" * (matrix{{self.currentCam.transform[1][4], self.currentCam.transform[2][4], self.currentCam.transform[3][4], self.currentCam.transform[4][4]}}^"T")
	self.shaderVars_viewPos = {self.shaderVars_viewPos[1][1], self.shaderVars_viewPos[2][1], self.shaderVars_viewPos[3][1]}
	
	local n = lib.near
	local f = lib.far
	local fov = self.fov
	local S = 1 / (math.tan(fov/2*math.pi/180))
	
	local projection = matrix{
		{S,	0,	0,	0},
		{0,	-S/love.graphics.getHeight()*love.graphics.getWidth(),	0,	0},
		{0,	0,	-f/(f-n),	-(f*n)/(f-n)},
		{0,	0,	-1,	0},
	}
	
	--camera transformation
	self.shaderVars_transformProj = projection * self.currentCam.transform
	
	--camera normal
	local normal = self.currentCam.transform^"T" * (matrix{{0, 0, 1, 0}}^"T")
	--print(normal[1][1], normal[2][1], -normal[3][1]) io.flush()
	cam.normal = {normal[1][1], normal[2][1], normal[3][1]}
	
	--clear draw table
	lib.drawTable = { }
	
	--show light sources
	if self.lighting_enabled and self.showLightSources then
		for d,s in ipairs(self.lighting) do
			love.graphics.setColor(s.r, s.g, s.b)
			self:draw(self.object_light, s.x, s.y, s.z, 0.2, nil, nil)
		end
		love.graphics.setColor(1, 1, 1, 1)
	end
end

function lib.reset(obj)
	obj.transform = matrix{
		{1, 0, 0, 0},
		{0, 1, 0, 0},
		{0, 0, 1, 0},
		{0, 0, 0, 1},
	}
end

function lib.translate(obj, x, y, z)
	local translate = matrix{
		{1, 0, 0, x},
		{0, 1, 0, y},
		{0, 0, 1, z},
		{0, 0, 0, 1},
	}
	obj.transform = translate * obj.transform
end

function lib.scale(obj, x, y, z)
	local scale = matrix{
		{x, 0, 0, 0},
		{0, y or x, 0, 0},
		{0, 0, z or x, 0},
		{0, 0, 0, 1},
	}
	obj.transform = scale * obj.transform
end

function lib.rotateX(obj, rx)
	local c = math.cos(rx or 0)
	local s = math.sin(rx or 0)
	local rotX = matrix{
		{1, 0, 0, 0},
		{0, c, -s, 0},
		{0, s, c, 0},
		{0, 0, 0, 1},
	}
	obj.transform = rotX * obj.transform
end

function lib.rotateY(obj, ry)
	local c = math.cos(ry or 0)
	local s = math.sin(ry or 0)
	local rotY = matrix{
		{c, 0, -s, 0},
		{0, 1, 0, 0},
		{s, 0, c, 0},
		{0, 0, 0, 1},
	}
	obj.transform = rotY * obj.transform
end

function lib.rotateZ(obj, rz)
	local c = math.cos(rz or 0)
	local s = math.sin(rz or 0)
	local rotZ = matrix{
		{c, s, 0, 0},
		{-s, c, 0, 0},
		{0, 0, 1, 0},
		{0, 0, 0, 1},
	}
	obj.transform = rotZ * obj.transform
end

function lib.newCam(self)
	return {
		transform = matrix{
			{1, 0, 0, 0},
			{0, 1, 0, 0},
			{0, 0, 1, 0},
			{0, 0, 0, 1},
		},
		normal = {0, 0, 0},
		x = 0,
		y = 0,
		z = 0,
		
		reset = self.reset,
		translate = self.translate,
		scale = self.scale,
		rotateX = self.rotateX,
		rotateY = self.rotateY,
		rotateZ = self.rotateZ,
	}
end

lib.cam = lib:newCam()
lib.currentCam = lib.cam

lib.drawTable = { }
function lib.draw(self, obj, x, y, z, sx, sy, sz)
	x = x or 0
	y = y or 0
	z = z or 0
	local transform = matrix{
		{sx or 1, 0, 0, x},
		{0, sy or sx or 1, 0, y},
		{0, 0, sz or sx or 1, z},
		{0, 0, 0, 1},
	}
	
	local bones
	if obj.bones then
		bones = { }
		for d,s in pairs(obj.bones) do
			bones[d] = {
				x = 0,
				y = 0,
				z = 0,
				rotation = matrix{
					{1, 0, 0},
					{0, 1, 0},
					{0, 0, 1},
				}
			}
		end
		
		--move
		local todo = {obj.bones.root.mountedBy}
		while #todo > 0 do
			local old = todo
			todo = { }
			for _,sp in ipairs(old) do
				for _,d in ipairs(sp) do
					local s = obj.bones[d]
					local ms = obj.bones[s.mount]
					todo[#todo+1] = s.mountedBy
					if s.mount ~= "root" then
						--move
						local ox, oy, oz = unpack(bones[s.mount].rotation * (matrix{{s.x - ms.x, s.y - ms.y, s.z - ms.z}}^"T"))
						bones[d].x = bones[s.mount].x + ox[1]
						bones[d].y = bones[s.mount].y + oy[1]
						bones[d].z = bones[s.mount].z + oz[1]
						
						local rx, ry, rz = s.rotationX, s.rotationY, s.rotationZ
						
						--local space
						local cc = math.cos(s.initRotationX)
						local ss = math.sin(s.initRotationX)
						local rotX = matrix{
							{1, 0, 0},
							{0, cc, -ss},
							{0, ss, cc},
						}
						
						local cc = math.cos(s.initRotationY)
						local ss = math.sin(s.initRotationY)
						local rotY = matrix{
							{cc, 0, -ss},
							{0, 1, 0},
							{ss, 0, cc},
						}
						
						local localSpace = rotY * rotX
						
						--to local space
						bones[d].rotation = localSpace * bones[d].rotation
						
						
						--rotate
						local cc = math.cos(rx or 0)
						local ss = math.sin(rx or 0)
						local rotX = matrix{
							{1, 0, 0},
							{0, cc, -ss},
							{0, ss, cc},
						}
						
						local cc = math.cos(ry or 0)
						local ss = math.sin(ry or 0)
						local rotY = matrix{
							{cc, 0, -ss},
							{0, 1, 0},
							{ss, 0, cc},
						}
						
						local cc = math.cos(rz or 0)
						local ss = math.sin(rz or 0)
						local rotZ = matrix{
							{cc, ss, 0},
							{-ss, cc, 0},
							{0, 0, 1},
						}
						
						bones[d].rotation = rotX * rotY * rotZ * bones[d].rotation
						
						--back to global space
						bones[d].rotation = localSpace:transpose() * bones[d].rotation
						
						
						--add mount bone rotation
						bones[d].rotation = bones[s.mount].rotation * bones[d].rotation
					end
				end
			end
		end
		
		for d,s in pairs(obj.bones) do
			local b = bones[d]
			local r = b.rotation
			
			local rotate = matrix{
				{r[1][1], r[1][2], r[1][3], 0},
				{r[2][1], r[2][2], r[2][3], 0},
				{r[3][1], r[3][2], r[3][3], 0},
				{0, 0, 0, 1},
			}
			
			local center = matrix{
				{1, 0, 0, -s.x},
				{0, 1, 0, -s.y},
				{0, 0, 1, -s.z},
				{0, 0, 0, 1},
			}
			
			local translate = matrix{
				{1, 0, 0, b.x},
				{0, 1, 0, b.y},
				{0, 0, 1, b.z},
				{0, 0, 0, 1},
			}
			
			bones[d] = translate * rotate * center
		end
	end
	
	local levelOfAbstraction = math.floor(math.sqrt((self.currentCam.x-x)^2 + (self.currentCam.y-y)^2 + (self.currentCam.z-z)^2) / self.abstractionDistance) - 1
	local t = obj.objects or {obj}
	for d,s in pairs(t) do
		if not s.disabled and not s.simple and (not s.particleSystem or levelOfAbstraction <= 2) then
			for i = 1, levelOfAbstraction do
				s = t[s.simpler] or s
			end
			local super
			while not s.mesh and s.simpler and t[s.simpler] do
				super = s
				s = t[s.simpler] or s
			end
			if super then
				super.requestMeshLoad = true
			end
			
			--insert intro draw todo list
			if s.mesh then
				local shaderInfo = self:getShaderInfo(s.material.tex_diffuse and "textured" or "flat", s.material.shader or s.shader, s.material.tex_normal, s.material.tex_specular, s.material.reflections)
				if not lib.drawTable[shaderInfo] then
					lib.drawTable[shaderInfo] = { }
				end
				if not lib.drawTable[shaderInfo][s.material] then
					lib.drawTable[shaderInfo][s.material] = { }
				end
				s.material.levelOfAbstraction = math.min(s.material.levelOfAbstraction or 99, levelOfAbstraction)
				local r, g, b = love.graphics.getColor()
				table.insert(lib.drawTable[shaderInfo][s.material], {
					(transform * (bones and (obj.transform * bones[d]) or obj.transform or 1))^"T",
					s,
					r, g, b
				})
			else
				s.requestMeshLoad = true
			end
		end
	end
end

function lib.resetLight(self, noDayLight)
	if noDayLight then
		self.lighting = { }
	else
		self.lighting = {
			{
				x = self.sun[1] * 1000,
				y = self.sun[2] * 1000,
				z = self.sun[3] * 1000,
				r = self.color_sun[1] / math.sqrt(self.color_sun[1]^2 + self.color_sun[2]^2 + self.color_sun[3]^2) * self.color_sun[4] * 0.02,
				g = self.color_sun[2] / math.sqrt(self.color_sun[1]^2 + self.color_sun[2]^2 + self.color_sun[3]^2) * self.color_sun[4] * 0.02,
				b = self.color_sun[3] / math.sqrt(self.color_sun[1]^2 + self.color_sun[2]^2 + self.color_sun[3]^2) * self.color_sun[4] * 0.02,
				meter = 1/100000,
				importance = math.huge,
			},
		}
	end
end

function lib.addLight(self, posX, posY, posZ, red, green, blue, brightness, meter, importance)
	self.lighting[#self.lighting+1] = {
		x = posX,
		y = posY,
		z = posZ,
		r = red / math.sqrt(red^2+green^2+blue^2) * (brightness or 10.0),
		g = green / math.sqrt(red^2+green^2+blue^2) * (brightness or 10.0),
		b = blue / math.sqrt(red^2+green^2+blue^2) * (brightness or 10.0),
		meter = 1.0 / (meter or 1.0),
		importance = importance or 1.0,
	}
end

return lib