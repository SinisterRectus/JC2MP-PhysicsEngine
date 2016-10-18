local random = math.random

class 'Sphere'

function Sphere:__init(args)

	local values = {
		__type = 'Sphere',
		dynamic = args.dynamic or args.dynamic == nil,
		collisions = args.collisions or args.collisions == nil,
		hue = args.hue or random(0, 360),
		density = args.density or 100,
		restitution = args.restitution or 0.6,
		drag_coefficient = args.drag_coefficient or 0.47,
		friction_coefficient = args.friction_coefficient or 0.3,
		radius = args.radius or 1,
	}

	values.linear_velocity = values.dynamic and args.linear_velocity or Vector3()
	values.angular_velocity = values.dynamic and args.angular_velocity or Vector3()

	self.wno = WorldNetworkObject.Create({
		position = args.position,
		angle = args.angle,
		world = args.world,
		values = values
	})

	PhysicsManager.spheres[self.wno:GetId()] = self

end

function Sphere:Remove()
	PhysicsManager.spheres[self.wno:GetId()] = nil
	self.wno:Remove()
end
