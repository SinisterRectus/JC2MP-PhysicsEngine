local create, resume, yield = coroutine.create, coroutine.resume, coroutine.yield

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
	})
	timers[sphere] = Timer()
end)

local loop = create(function()
	while true do
		for sphere, timer in pairs(timers) do
			if timer:GetSeconds() > despawn_time then
				sphere:Remove()
				timers[sphere] = nil
			end
			yield()
		end
		yield()
	end
end)

Events:Subscribe('PreTick', function() assert(resume(loop)) end)
