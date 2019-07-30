--load the 3D lib
dream = require("3DreamEngine")
love.window.setTitle("Blacksmith")

--settings
dream.objectDir = "examples/reflections"

dream.AO_enabled = true       --ambient occlusion?
dream.AO_strength = 0.75      --blend strength
dream.AO_quality = 24         --samples per pixel (8-32 recommended)
dream.AO_quality_smooth = 2   --smoothing steps, 1 or 2 recommended, lower quality (< 12) usually requires 2 steps
dream.AO_resolution = 0.75    --resolution factor

dream.sky = love.graphics.newImage(dream.objectDir .. "/background.jpg")

dream.reflections_enabled = true
dream.startWithMissing = true

dream:init()

scene = dream:loadObject("scene", {splitMaterials = true})

love.graphics.setBackgroundColor(128/255, 218/255, 235/255)

math.randomseed(os.time())
io.stdout:setvbuf("no")

love.mouse.setRelativeMode(true)

player = {
	x = 0,
	y = 0,
	z = 0,
	ax = 0,
	ay = 0,
	az = 0,
}

--because it is easier to work with two rotations
dream.cam.rx = 0
dream.cam.ry = 0

function love.draw()
	--update camera
	dream.cam:reset()
	dream.cam:translate(-dream.cam.x, -dream.cam.y, -dream.cam.z) --note that x, y, z are usually extracted from the camera matrix in prepare(), but we use it that way.
	dream.cam:rotateY(dream.cam.ry)
	dream.cam:rotateX(dream.cam.rx)
	
	--update lights
	dream:resetLight(true) --true disables the sun
	for d,s in ipairs(scene.lights) do
		if s.name == "torch" then
			dream:addLight(s.x, s.y, s.z, 1.0, 0.75, 0.1, 1.0 + 0.5 * love.math.noise(love.timer.getTime()*2, 1.0))
		end
	end
	
	dream:prepare()
	dream:draw(scene, 0, 0, 0)

	dream:present()
	
	if love.keyboard.isDown(".") then
		local shadersInUse = ""
		for d,s in pairs(dream.stats.perShader) do
			shadersInUse = shadersInUse .. d.name .. ": " .. s .. "x  "
		end
		love.graphics.print("Stats" ..
			"\ndifferent shaders: " .. dream.stats.shadersInUse ..
			"\ndifferent materials: " .. dream.stats.materialDraws ..
			"\ndraws: " .. dream.stats.draws ..
			"\nshaders: " .. shadersInUse,
			15, 400)
		end
end

function love.mousemoved(_, _, x, y)
	local speedH = 0.005
	local speedV = 0.005
	dream.cam.ry = dream.cam.ry - x * speedH
	dream.cam.rx = math.max(-math.pi/2, math.min(math.pi/2, dream.cam.rx + y * speedV))
end

--collision not implemented yet
function collide(x, y, w, h)
	return false
end

function love.update(dt)
	local d = love.keyboard.isDown
	local speed = 10*dt
	
	--collision
	player.x = player.x + player.ax * dt
	player.y = player.y + player.ay * dt
	player.z = player.z + player.az * dt
	
	if d("w") then
		player.ax = player.ax + math.cos(-dream.cam.ry-math.pi/2) * speed
		player.az = player.az + math.sin(-dream.cam.ry-math.pi/2) * speed
	end
	if d("s") then
		player.ax = player.ax + math.cos(-dream.cam.ry+math.pi-math.pi/2) * speed
		player.az = player.az + math.sin(-dream.cam.ry+math.pi-math.pi/2) * speed
	end
	if d("a") then
		player.ax = player.ax + math.cos(-dream.cam.ry-math.pi/2-math.pi/2) * speed
		player.az = player.az + math.sin(-dream.cam.ry-math.pi/2-math.pi/2) * speed
	end
	if d("d") then
		player.ax = player.ax + math.cos(-dream.cam.ry+math.pi/2-math.pi/2) * speed
		player.az = player.az + math.sin(-dream.cam.ry+math.pi/2-math.pi/2) * speed
	end
	if d("space") then
		player.ay = player.ay + speed
	end
	if d("lshift") then
		player.ay = player.ay - speed
	end
	
	--air resistance
	player.ax = player.ax * (1 - dt*3)
	player.ay = player.ay * (1 - dt*3)
	player.az = player.az * (1 - dt*3)
	
	--mount cam
	dream.cam.x = player.x
	dream.cam.y = player.y+0.3
	dream.cam.z = player.z
	
	dream.resourceLoader:update()
end

function love.keypressed(key)
	--screenshots!
	if key == "f2" then
		if love.keyboard.isDown("lctrl") then
			love.system.openURL(love.filesystem.getSaveDirectory() .. "/screenshots")
		else
			love.filesystem.createDirectory("screenshots")
			if not screenShotThread then
				screenShotThread = love.thread.newThread([[
					require("love.image")
					channel = love.thread.getChannel("screenshots")
					while true do
						local screenshot = channel:demand()
						screenshot:encode("png", "screenshots/screen_" .. tostring(os.time()) .. ".png")
					end
				]]):start()
			end
			love.graphics.captureScreenshot(love.thread.getChannel("screenshots"))
		end
	end

	--fullscreen
	if key == "f11" then
		love.window.setFullscreen(not love.window.getFullscreen())
	end
end

function love.resize()
	dream:init()
end