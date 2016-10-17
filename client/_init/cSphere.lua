local min, lerp, sqrt = math.min, math.lerp, math.sqrt
local insert = table.insert
local pi = math.pi

class 'Sphere'

function Sphere:__init(wno)

	for k, v in pairs(wno:GetValues()) do
		self[k] = v
	end

	self.id = wno:GetId()
	self.position = wno:GetPosition()
	self.angle = wno:GetAngle()

	self.volume = 4/3 * pi * self.radius ^ 3
	self.mass = self.volume * self.density
	self.inv_mass = 1 / self.mass

	local i = 2/5 * self.mass * self.radius ^ 2
	local inv_i = 1/i
	self.inertia = Vector3(i, i, i)
	self.inv_inertia = Vector3(inv_i, inv_i, inv_i)

	self.linear_damping = 0.5 * config.air_density * self.drag_coefficient * pi * self.radius ^ 2
	self.angular_damping = 0.4 -- hardcoded, just cause
	self.weight = self.mass * config.gravity

	self.network_position = self.position
	self.network_linear_velocity = self.linear_velocity
	self.network_angular_velocity = self.angular_velocity

	self.position_error = Vector3()
	self.linear_velocity_error = Vector3()
	self.angular_velocity_error = Vector3()

	self.transform = Transform3()
	self.transform:Translate(self.position)
	self.transform:Rotate(self.angle)

	self.entities = {
		Player = {}, LocalPlayer = {},
		ClientActor = {}, Vehicle = {},
	}

	self.wno = wno
	self.sync_timer = Timer()
	self.nearest_timer = Timer()

	self:InitModel()
	self:InitTrigger()

	PhysicsManager.spheres[self.id] = self

end

function Sphere:InitModel()

	local radius = self.radius

	local vectors = {}
	local function AddVector(x, y, z)
		insert(vectors, Vector3(x, y, z))
	end

	local triangles = {}
	local function AddTriangle(a, b, c)
		insert(triangles, {vectors[a], vectors[b], vectors[c]})
	end

	local vertices = {}
	local function AddVertex(position, color)
		insert(vertices, Vertex(position, color))
	end

	local t = 0.5 * (1 + sqrt(5))
	local length = sqrt(1 + t ^ 2)
	local a = radius / length
	local b = a * t

	AddVector(-a,  b,  0)
	AddVector( a,  b,  0)
	AddVector(-a, -b,  0)
	AddVector( a, -b,  0)
	AddVector( 0, -a,  b)
	AddVector( 0,  a,  b)
	AddVector( 0, -a, -b)
	AddVector( 0,  a, -b)
	AddVector( b,  0, -a)
	AddVector( b,  0,  a)
	AddVector(-b,  0, -a)
	AddVector(-b,  0,  a)

	AddTriangle( 1, 12,  6)
	AddTriangle( 1,  6,  2)
	AddTriangle( 1,  2,  8)
	AddTriangle( 1,  8, 11)
	AddTriangle( 1, 11, 12)
	AddTriangle( 2,  6, 10)
	AddTriangle( 6, 12,  5)
	AddTriangle(12, 11,  3)
	AddTriangle(11,  8,  7)
	AddTriangle( 8,  2,  9)
	AddTriangle( 4, 10,  5)
	AddTriangle( 4,  5,  3)
	AddTriangle( 4,  3,  7)
	AddTriangle( 4,  7,  9)
	AddTriangle( 4,  9, 10)
	AddTriangle( 5, 10,  6)
	AddTriangle( 3,  5, 12)
	AddTriangle( 7,  3, 11)
	AddTriangle( 9,  7,  8)
	AddTriangle(10,  9,  2)

	for i = 1, self.levels do -- #triangles = 20 * 4^levels
		local temp = {}
		for _, triangle in ipairs(triangles) do
			local a = lerp(triangle[1], triangle[2], 0.5):Normalized() * radius
			local b = lerp(triangle[2], triangle[3], 0.5):Normalized() * radius
			local c = lerp(triangle[3], triangle[1], 0.5):Normalized() * radius
			insert(temp, {triangle[1], a, c})
			insert(temp, {triangle[2], b, a})
			insert(temp, {triangle[3], c, b})
			insert(temp, {a, b, c})
		end
		triangles = temp
	end

	local hue = self.hue
	local light = Vector3.Backward
	for _, triangle in ipairs(triangles) do
		for _, position in ipairs(triangle) do
			local n = 0.4 * position:Normalized():Dot(light)
			AddVertex(position, Color.FromHSV(hue, 1 - n, 1 + n))
		end
	end

	self.model = Model.Create(vertices)
	self.model:SetTopology(Topology.TriangleList)

end

function Sphere:InitTrigger()
	local r = self.radius
	self.trigger = ShapeTrigger.Create({
		position = self.position,
		angle = self.angle,
		components = {
			{type = TriggerType.Sphere, size = Vector3(r, r, r)}
		},
		trigger_player = true,
		trigger_player_in_vehicle = false,
		trigger_vehicle = true,
		trigger_npc = true
	})
	PhysicsManager.triggers[self.trigger:GetId()] = self
end

function Sphere:Tick(dt, spheres)

	local p = self.position
	local v = self.linear_velocity
	local w = self.angular_velocity
	local q = self.angle

	p, v, w, q = self:Step(p, v, w, q, dt)
	if self.collisions then
		p, v, w = self:CheckCollisions(p, v, w, spheres)
	end
	p, v, w = self:Sync(p, v, w, dt, spheres)

	self:Teleport(p, q)
	self.linear_velocity = v
	self.angular_velocity = w

end

function Sphere:Step(p, v, w, q, dt)

	local f = self.weight - self.linear_damping * v * v:Length()
	-- might add buoyancy in future
	v = v + self.inv_mass * f * dt
	p = p + v * dt

	local t = -self.angular_damping * w * w:Length() / v:Length() -- hacky, but works
	w = w + t * dt
	q = q + w * dt

	return p, v, w, q

end

function Sphere:Sync(p1, v1, w1, dt, spheres)

	local nearest = self.nearest
	if self.nearest_timer:GetSeconds() > 1 or nearest == nil then
		self.nearest_timer:Restart()
		nearest = true
		local distance = p1:DistanceSqr(LocalPlayer:GetPosition())
		for player in Client:GetStreamedPlayers() do
			if p1:DistanceSqr(player:GetPosition()) < distance then
				nearest = false
				break
			end
		end
	end
	self.nearest = nearest

	if nearest then

		local dt = self.sync_timer:GetSeconds()
		local dp = self.network_position:Distance(p1)

		if dp * dt > config.sync_rate then
			self.sync_timer:Restart()
			self.network_position = p1
			Network:Send('Update', {self.id, p1, v1, w1})
		end

	else

		local p_error = self.position_error
		local v_error = self.linear_velocity_error
		local w_error = self.angular_velocity_error

		dt = min(dt, 1)

		p1 = p1 + p_error * dt
		v1 = v1 + v_error * dt
		w1 = w1 + w_error * dt

		dt = 1 - dt

		self.position_error = p_error * dt
		self.linear_velocity_error = v_error * dt
		self.angular_velocity_error = w_error * dt

	end

	return p1, v1, w1

end

function Sphere:CheckCollisions(p, v, w, spheres)

	p, v, w = self:CheckRaycastCollision(p, v, w, v:Normalized())

	local direction = Vector3.Down
	if direction:Dot(v) > 0 then
		p, v, w = self:CheckRaycastCollision(p, v, w, direction)
	end

	for _, sphere in pairs(spheres) do
		if self ~= sphere and sphere.collisions then
			p, v, w = self:CheckSphereCollision(p, v, w, sphere)
		end
	end

	-- game entities are approximated as spheres
	for type, entities in pairs(self.entities) do
		for id, entity in pairs(entities) do
			p, v, w = self:CheckSphereCollision(p, v, w, entity)
		end
	end

	return p, v, w

end

function Sphere:CheckRaycastCollision(p, v, w, direction)

	local distance = self.radius
	local ray = Physics:Raycast(p, direction, 0, distance)
	if ray.entity and IsDynamic(ray.entity) then return p, v, w end

	local d = distance - ray.distance
	if d < 0.001 then return p, v, w end
	p = p - direction * d -- position correction

	return self:ResolveStaticCollision(p, v, w, ray.position - p, ray.normal)

end

function Sphere:CheckSphereCollision(p1, v1, w1, other)

	local r1 = self.radius
	local r2 = other:GetRadius()
	local p2 = other:GetCentroid()
	local p_rel = p2 - p1

	if p_rel:LengthSqr() > (r1 + r2) ^ 2 then return p1, v1, w1 end

	local v2 = other:GetLinearVelocity()
	local v_rel = v2 - v1

	if p_rel:Dot(v_rel) > 0 then return p1, v1, w1 end

	local n = p_rel:Normalized()
	r1 = n * r1

	if IsDynamic(other) then

		local m1 = self.inv_mass
		local i1 = self.inv_inertia
		local e = min(self.restitution, other:GetRestitution())
		local u = self.friction_coefficient

		local w2 = other:GetAngularVelocity()
		local m2 = other:GetInverseMass()
		local i2 = other:GetInverseInertia()
		r2 = -n * r2

		local v = (v2 + w2:Cross(r2)) - (v1 + w1:Cross(r1))
		local dot = v:Dot(n)
		local j = (1 + e) * dot / (m1 + m2)
		local t = (v - dot * n):Normalized()

		v1 = v1 + j * n * m1
		v2 = v2 - j * n * m2

		j = u * j

		v1 = v1 + j * t * m1
		w1 = w1 + j * i1:ComponentMultiply(r1:Cross(t))

		local SetLinearVelocity = other.SetLinearVelocity
		if SetLinearVelocity then
			SetLinearVelocity(other, v2 - j * t * m2)
		end

		local SetAngularVelocity = other.SetAngularVelocity
		if SetAngularVelocity then
			SetAngularVelocity(other, w2 - j * i2:ComponentMultiply(r2:Cross(t)))
		end

		return p1, v1, w1

	else

		return self:ResolveStaticCollision(p1, v1, w1, r1, n)

	end

end

function Sphere:ResolveStaticCollision(p, v, w, r, n)

	local m = self.inv_mass
	local i = self.inv_inertia
	local e = self.restitution
	local u = self.friction_coefficient

	local vr = -(v + w:Cross(r)) -- velocity at point
	local dot = vr:Dot(n)
	local j = (1 + e) * dot / m -- collision impulse
	local t = (vr - dot * n):Normalized() -- collision tangent

	v = v + j * n * m
	j = u * j -- friction impulse
	v = v + j * t * m
	w = w + j * i:ComponentMultiply(r:Cross(t))

	return p, v, w

end

function Sphere:GetId()
	return self.id
end

function Sphere:GetRadius()
	return self.radius
end

function Sphere:GetRestitution()
	return self.restitution
end

function Sphere:GetMass()
	return self.mass
end

function Sphere:GetInverseMass()
	return self.inv_mass
end

function Sphere:GetInertia()
	return self.inertia
end

function Sphere:GetInverseInertia()
	return self.inv_inertia
end

function Sphere:GetPosition()
	return self.position
end

function Sphere:GetCentroid()
	return self.position
end

function Sphere:GetAngle()
	return self.angle
end

function Sphere:GetLinearVelocity()
	return self.linear_velocity
end

function Sphere:GetAngularVelocity()
	return self.angular_velocity
end

function Sphere:GetLinearDamping()
	return self.linear_damping
end

function Sphere:GetAngularDamping()
	return self.angular_damping
end

function Sphere:SetPosition(position)
	local transform = self.transform
	transform:SetIdentity()
	transform:Translate(position)
	transform:Rotate(self.angle)
	self.trigger:SetPosition(position)
	self.position = position
end

function Sphere:SetAngle(angle)
	local transform = self.transform
	transform:SetIdentity()
	transform:Translate(self.position)
	transform:Rotate(angle)
	self.trigger:SetAngle(angle)
	self.angle = angle
end

function Sphere:Teleport(position, angle)
	local transform, trigger = self.transform, self.trigger
	transform:SetIdentity()
	transform:Translate(position)
	transform:Rotate(angle)
	trigger:SetPosition(position)
	trigger:SetAngle(angle)
	self.position = position
	self.angle = angle
end

function Sphere:SetLinearVelocity(velocity)
	self.linear_velocity = velocity
end

function Sphere:SetAngularVelocity(velocity)
	self.angular_velocity = velocity
end

function Sphere:Draw()
	Render:SetTransform(self.transform)
	self.model:Draw()
	Render:ResetTransform()
end

function Sphere:Remove()
	local trigger = self.trigger
	PhysicsManager.spheres[self.id] = nil
	PhysicsManager.triggers[trigger:GetId()] = nil
	trigger:Remove()
end
