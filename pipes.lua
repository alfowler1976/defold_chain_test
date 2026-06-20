



local M = {}

-- data to create pipe spline
M.user_points = {
	vmath.vector3(000, 50, 0),
	vmath.vector3(175, 375, 0),
	vmath.vector3(375, 450, 0),
	vmath.vector3(550, 465, 0),
	vmath.vector3(775, 485, 0),
	vmath.vector3(900, 575, 0),
	vmath.vector3(900, 700, 0)
}

-- pipe radius
M.pipe_radius = 25

M.segments_per_curve = 8

-- pipe chains
M.top_wall = {}
M.bottom_wall = {}


-- evaluate Catmull-Rom Position
local function get_catmull_rom_point(p0, p1, p2, p3, t)
	local t2 = t * t
	local t3 = t2 * t
	return 0.5 * ( (2 * p1) + 
	(-p0 + p2) * t + 
	(2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + 
	(-p0 + 3 * p1 - 3 * p2 + p3) * t3 )
end

-- prevent vertices being too close for chain
local function filter_vertices(vertices, min_dist)
	local filtered = {}
	if #vertices == 0 then return filtered end

	table.insert(filtered, vmath.vector3(vertices[1].x, vertices[1].y, 0))
	local last_pt = filtered[1]

	for i = 2, #vertices do
		local pt = vertices[i]

		
		local dist = math.sqrt((pt.x - last_pt.x)^2 + (pt.y - last_pt.y)^2)

		if dist >= min_dist then
			local clean_pt = vmath.vector3(pt.x, pt.y, 0)
			table.insert(filtered, clean_pt)
			last_pt = clean_pt
		end
	end

	return filtered
end


function M.generate_pipe(body,mesh_url)

	-- cleanup old Box2D chains
	if M.bottom_chain then b2d.chain.destroy(M.bottom_chain) end
	if M.top_chain then b2d.chain.destroy(M.top_chain) end

	M.top_wall = {}
	M.bottom_wall = {}


	-- generate high res base path
	local high_res_path = {}
	local sample_steps = 30 

	for i = 1, #M.user_points - 1 do
		local p0 = M.user_points[math.max(i - 1, 1)]
		local p1 = M.user_points[i]
		local p2 = M.user_points[i + 1]
		local p3 = M.user_points[math.min(i + 2, #M.user_points)]

		local start_t = (i == 1) and 0 or (1 / sample_steps)
		for j = 0, sample_steps do
			local t = j / sample_steps
			if t >= start_t then
				table.insert(high_res_path, get_catmull_rom_point(p0, p1, p2, p3, t))
			end
		end
	end


	-- calc total length
	local total_length = 0
	local distances = {0} 
	for i = 1, #high_res_path - 1 do
		local dist = vmath.length(high_res_path[i+1] - high_res_path[i])
		total_length = total_length + dist
		table.insert(distances, total_length)
	end


	-- extract Uniform Points
	local total_desired_segments = (#M.user_points - 1) * M.segments_per_curve
	local uniform_step = total_length / total_desired_segments

	local uniform_points = {}
	table.insert(uniform_points, high_res_path[1]) 

	local current_target_dist = uniform_step
	local current_hr_index = 1

	while current_target_dist < total_length do
		-- find the high-res segment that contains our target distance
		while current_hr_index < #high_res_path and distances[current_hr_index + 1] < current_target_dist do
			current_hr_index = current_hr_index + 1
		end

		local p_curr = high_res_path[current_hr_index]
		local p_next = high_res_path[current_hr_index + 1]
		local dist_curr = distances[current_hr_index]
		local dist_next = distances[current_hr_index + 1]

		-- prevent division by zero if duplicate points exist
		if dist_next - dist_curr > 0.0001 then
			local t = (current_target_dist - dist_curr) / (dist_next - dist_curr)
			table.insert(uniform_points, vmath.lerp(t, p_curr, p_next))
		end

		current_target_dist = current_target_dist + uniform_step
	end

	-- ensure the absolute final point is included safely
	local final_pt = high_res_path[#high_res_path]
	local dist_to_last = vmath.length(final_pt - uniform_points[#uniform_points])

	if dist_to_last > 0.001 then
		table.insert(uniform_points, final_pt)
	else
		-- just snap the last point to the exact end
		uniform_points[#uniform_points] = final_pt
	end

	-- generate pipe walls
	for i = 1, #uniform_points do
		local pt = uniform_points[i]
		local tangent

		-- calculate physical tangents looking at neighbors
		if i == 1 then
			tangent = vmath.normalize(uniform_points[2] - uniform_points[1])
		elseif i == #uniform_points then
			tangent = vmath.normalize(uniform_points[i] - uniform_points[i-1])
		else
			tangent = vmath.normalize(uniform_points[i+1] - uniform_points[i-1])
		end

		local normal = vmath.vector3(-tangent.y, tangent.x, 0)
		table.insert(M.top_wall, pt + (normal * M.pipe_radius))
		table.insert(M.bottom_wall, pt - (normal * M.pipe_radius))
	end

	-- generate mesh
	local num_points = #M.top_wall
	
	local vertex_count = (num_points - 1) * 6 

	if vertex_count > 0 then
		-- create a buffer with positions and UV coordinates 
		local buf = buffer.create(vertex_count, {
			{ name = hash("position"), type = buffer.VALUE_TYPE_FLOAT32, count = 3 },
			{ name = hash("texcoord0"), type = buffer.VALUE_TYPE_FLOAT32, count = 2 }})

		local positions = buffer.get_stream(buf, hash("position"))
		local texcoords = buffer.get_stream(buf, hash("texcoord0"))

		local v_idx = 1
		for i = 1, num_points - 1 do
			local p1_top = M.top_wall[i]
			local p1_bot = M.bottom_wall[i]
			local p2_top = M.top_wall[i+1]
			local p2_bot = M.bottom_wall[i+1]

			local u1 = (i - 1) / (num_points - 1)
			local u2 = i / (num_points - 1)

			-- helper function to write vertex data into the buffer streams
			local function set_vert(pos, u, v)
				positions[v_idx * 3 - 2] = pos.x
				positions[v_idx * 3 - 1] = pos.y
				positions[v_idx * 3 - 0] = pos.z or 0

				texcoords[v_idx * 2 - 1] = u
				texcoords[v_idx * 2 - 0] = v

				v_idx = v_idx + 1
			end

			-- triangle 1
			set_vert(p1_top, 0, 1)
			set_vert(p1_bot, 0, 0)
			set_vert(p2_top, 1, 1)

			-- triangle 2
			set_vert(p2_top, 1, 1)
			set_vert(p1_bot, 0, 0)
			set_vert(p2_bot, 1, 0)
		end

		-- aply the dynamically generated buffer to the mesh component
		local mesh_res = go.get(mesh_url, "vertices")
		resource.set_buffer(mesh_res, buf)
	end
	
	-- reverse the bottom wall to correct the winding order
	local i, j = 1, #M.bottom_wall
	while i < j do
		M.bottom_wall[i], M.bottom_wall[j] = M.bottom_wall[j], M.bottom_wall[i]
		i = i + 1
		j = j - 1
	end

	-- prevent vertices being too close in chain
	local safe_bottom_wall = filter_vertices(M.bottom_wall, 25.0)
	local safe_top_wall = filter_vertices(M.top_wall, 25.0)

	-- create new Box2D chains
	if #safe_bottom_wall >= 2 then
		M.bottom_chain, _ = b2d.body.create_chain(body, {vertices = safe_bottom_wall, restitution = 0.5})
	end

	if #safe_top_wall >= 2 then
		M.top_chain, _ = b2d.body.create_chain(body, {vertices = safe_top_wall, restitution = 0.5})
	end
end
	
return M