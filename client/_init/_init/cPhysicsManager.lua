class 'PhysicsManager'

function PhysicsManager:__init()

	self.spheres = {}
	self.triggers = {}

	Events:Subscribe('GameRender', self, self.Tick)
	Events:Subscribe('ModuleUnload', self, self.ModuleUnload)
	Events:Subscribe('ShapeTriggerEnter', self, self.TriggerEnter)
	Events:Subscribe('ShapeTriggerExit', self, self.TriggerExit)
	Events:Subscribe('WorldNetworkObjectCreate', self, self.ObjectSpawn)
	Events:Subscribe('WorldNetworkObjectDestroy', self, self.ObjectDespawn)
	Events:Subscribe('NetworkObjectValueChange', self, self.ObjectValueChange)

end

function PhysicsManager:TriggerEnter(args)
	local sphere = self.triggers[args.trigger:GetId()]
	if not sphere then return end
	local entity = args.entity
	sphere.entities[entity.__type][entity:GetId()] = entity
end

function PhysicsManager:TriggerExit(args)
	local sphere = self.triggers[args.trigger:GetId()]
	if not sphere then return end
	local entity = args.entity
	sphere.entities[entity.__type][entity:GetId()] = nil
end

function PhysicsManager:Tick(args)
	if LocalPlayer:IsTeleporting() then return end
	local dt = args.delta
	local spheres = self.spheres
	for _, sphere in pairs(spheres) do
		if sphere.dynamic then
			sphere:Tick(dt, spheres)
		end
		sphere:Draw()
	end
end

function PhysicsManager:ObjectSpawn(args)
	local wno = args.object
	if wno:GetValue('__type') ~= 'Sphere' then return end
	Sphere(wno, self)
end

function PhysicsManager:ObjectDespawn(args)
	local wno = args.object
	if wno:GetValue('__type') ~= 'Sphere' then return end
	local sphere = self.spheres[wno:GetId()]
	if not sphere then return end
	sphere:Remove()
end

function PhysicsManager:ObjectValueChange(args)

	local wno = args.object
	if wno:GetValue('__type') ~= 'Sphere' then return end
	local sphere = self.spheres[wno:GetId()]
	if not sphere then return end

	if args.key == 'linear_velocity' then
		local network_p = wno:GetPosition()
		local network_v = args.value
		sphere.network_position = network_p
		sphere.network_linear_velocity = network_v
		sphere.position_error = network_p - sphere.position
		sphere.linear_velocity_error = network_v - sphere.linear_velocity
	elseif args.key == 'angular_velocity' then
		local network_w = args.value
		sphere.network_angular_velocity = network_w
		sphere.angular_velocity_error = network_w - sphere.angular_velocity
	end

end

function PhysicsManager:ModuleUnload()
	for _, sphere in pairs(self.spheres) do
		sphere:Remove()
	end
end

PhysicsManager = PhysicsManager()
