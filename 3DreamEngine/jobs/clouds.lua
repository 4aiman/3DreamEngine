local job = { }
local lib = _3DreamEngine

job.cost = 1

--random numbers with seed
local randoms = { }
local function random(i)
	randoms[i] = randoms[i] or math.random()
	return randoms[i]
end

local spritebatch
local quads = { }
for x = 0, 3 do
	for y = 0, 3 do
		quads[#quads+1] = love.graphics.newQuad(x, y, 1, 1, 4, 4)
	end
end

--add a cloud to the spritebatch, performs out of bounds check
local function addCloud(q, x, y, r, sx, ...)
	if x > -sx*0.5 and x < 1+sx*0.5 and y > -sx*0.5 and y < 1+sx*0.5 then
		spritebatch:add(q, x, y, r, sx, ...)
	end
end

function job:init()
	spritebatch = nil
	lib.cloudCanvas = love.graphics.newCanvas(lib.clouds_resolution, lib.clouds_resolution, {format = "r8"})
	lib.cloudCanvas:setWrap("repeat")
end

function job:queue(times)
	if lib.skyInUse then
		spritebatch = spritebatch or love.graphics.newSpriteBatch(lib.textures.clouds)
		lib:addOperation("clouds")
		lib.skyInUse = false
	end
end

function job:execute(times, delta)
	local size = lib.weather_rain^2 + 0.2
	local amount = lib.clouds_amount
	
	local a = math.atan2(lib.clouds_wind.y, lib.clouds_wind.x) + lib.clouds_angle
	local strength = lib.clouds_wind:length() * lib.clouds_stretch_wind + lib.clouds_stretch
	if strength < 0 then
		a = a + math.pi / 2
		strength = -strength
	end
	local stretch = vec2(
		1.0 + math.abs(math.cos(a)) * strength,
		1.0 + math.abs(math.sin(a)) * strength
	)
	
	lib.clouds_pos = lib.clouds_pos + lib.clouds_wind * delta
	
	--add clouds
	spritebatch:clear()
	for i = 1, amount do
		local q = quads[i % 16 + 1]
		local sz = random(i)*0.5 + love.math.noise(i, love.timer.getTime() * lib.clouds_anim_size)*0.5
		sz = sz * (1.0 - lib.weather_temperature * i / amount) + 0.0 * lib.weather_temperature * i / amount
		local wp = lib.clouds_pos * (random(i * 1/8)-0.5) * lib.clouds_anim_position
		local x, y = (random(i + 0.5) + wp.x) % 1, (random(i + 0.25) + wp.y) % 1
		local r = lib.clouds_rotations and (random(i + 0.125) * math.pi * 2) or 0
		local brightness = 0.25 + random(i + 1 / 16) * 0.5
		
		spritebatch:setColor(brightness, brightness, brightness)
		for xx = -1, 1 do
			for yy = -1, 1 do
				addCloud(q, (x+xx) / stretch.x, (y+yy) / stretch.y, r, sz * size, nil, 0.5, 0.5)
			end
		end
	end
	
	--render
	love.graphics.push("all")
	love.graphics.setColor(1, 1, 1)
	love.graphics.setCanvas(lib.cloudCanvas)
	love.graphics.clear(0, 0, 0, 1)
	love.graphics.setBlendMode("screen", "premultiplied")
	love.graphics.scale(lib.cloudCanvas:getWidth() * stretch.x, lib.cloudCanvas:getWidth() * stretch.y)
	love.graphics.draw(spritebatch)
	love.graphics.pop()
end

return job