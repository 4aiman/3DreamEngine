local sh = { }

sh.type = "light"

sh.batchable = true

function sh:constructDefinesGlobal(dream)
	return [[
		extern int point_simple_count;
		
		extern vec3 point_simple_pos[]] .. dream.max_lights .. [[];
		extern vec3 point_simple_color[]] .. dream.max_lights .. [[];
	]]
end

function sh:constructDefines(dream, ID)
	
end

function sh:constructPixelGlobal(dream)
	return ([[
		for (int i = 0; i < point_simple_count; i++) {
			vec3 lightVecRaw = point_simple_pos[i] - vertexPos;
			vec3 lightVec = normalize(lightVecRaw);
			float distance = length(lightVecRaw);
			float power = 1.0 / (0.1 + distance * distance);
			vec3 lightColor = point_simple_color[i] * power;
			
			light += getLight(lightColor, viewVec, lightVec, normal, albedo.rgb, material.x, material.y);
			
			//backface light
			#ifdef TRANSLUCENT_ENABLED
				light += getLight(lightColor, viewVec, lightVec, reflect(normal, normalRaw), albedo.rgb, material.x, material.y) * translucent;
			#endif
		}
	]])
end

function sh:constructPixelBasicGlobal(dream)
	return ([[
		for (int i = 0; i < point_simple_count; i++) {
			vec3 lightVecRaw = point_simple_pos[i] - vertexPos;
			float distance = length(lightVecRaw);
			float power = 1.0 / (0.1 + distance * distance);
			light += point_simple_color[i] * power;
		}
	]])
end

function sh:constructPixel(dream, ID)

end

function sh:constructPixelBasic(dream, ID)

end

function sh:sendGlobalUniforms(dream, shaderObject, count, lighting)
	local shader = shaderObject.shader
	
	local colors = { }
	local pos = {}
	for d,s in ipairs(lighting) do
		if s.light_typ == "point_simple" then
			colors[#colors+1] = {s.r * s.brightness, s.g * s.brightness, s.b * s.brightness}
			pos[#pos+1] = {s.x, s.y, s.z}
		end
	end
	
	shader:send("point_simple_count", count)
	shader:send("point_simple_pos", unpack(pos))
	shader:send("point_simple_color", unpack(colors))
end

function sh:sendUniforms(dream, shaderObject, light, ID)
	
end

return sh