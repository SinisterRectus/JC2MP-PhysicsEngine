local timers = {}
local despawn_time = 60 -- seconds

-- Note: All spheres are removed by PhysicsManager on ModuleUnload.

Network:Subscribe('CreateSphere', function(_, sender)
	local p = sender:GetPosition()
	local v = sender:GetLinearVelocity()
	local q = (sender:GetAimTarget().position - p):ToAngle()
	local sphere = Sphere({
		position = p + q * Vector3(0, 1, -5),
		linear_velocity = v + q * Vector3(0, 2, -10),
		restitution = 0.6,
		drag_coefficient = 0.47,
		friction_coefficient = 0.3,
		radius = 0.8,
		density = 100,
	})
	timers[sphere] = Timer()
end)

local sphere, timer
Events:Subscribe('PreTick', function()
	sphere, timer = next(timers, sphere)
	if timer and timer:GetSeconds() > despawn_time then
		sphere:Remove()
		timers[sphere] = nil
	end
end)
