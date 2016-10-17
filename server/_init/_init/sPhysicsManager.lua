class 'PhysicsManager'

function PhysicsManager:__init()

	self.spheres = {}

	Events:Subscribe('ModuleUnload', self, self.ModuleUnload)
	Network:Subscribe('Update', self, self.Update)

end

function PhysicsManager:Update(args, sender)
	local sphere = self.spheres[args[1]]
	if not sphere then return end
	local wno = sphere.wno
	wno:SetPosition(args[2])
	wno:SetNetworkValue('linear_velocity', args[3])
	wno:SetNetworkValue('angular_velocity', args[4])
end

function PhysicsManager:ModuleUnload()
	for _, sphere in pairs(self.spheres) do
		sphere:Remove()
	end
end

PhysicsManager = PhysicsManager()
