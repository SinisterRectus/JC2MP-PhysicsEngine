local ceil = math.ceil
local format = string.format
local insert = table.insert

local players = {}

local function AddPlayer(player)
	players[player:GetId()] = {timer = Timer(), spheres = {}}
end

local function RemovePlayer(player)
	players[player:GetId()] = nil
end

local function RemoveSpheres(spheres)
	for _, sphere in pairs(spheres) do
		sphere:Remove()
	end
end

Events:Subscribe('ModuleLoad', function()
	for player in Server:GetPlayers() do
		AddPlayer(player)
	end
end)

Events:Subscribe('PlayerJoin', function(args)
	AddPlayer(args.player)
end)

Events:Subscribe('PlayerQuit', function(args)
	RemoveSpheres(players[args.player:GetId()].spheres)
	RemovePlayer(args.player)
end)

-- Note: All spheres are removed by PhysicsManager on ModuleUnload

local delay = example_config.delay
local color = example_config.color
local message = example_config.message

Network:Subscribe('CreateSphere', function(_, sender)
	local player = players[sender:GetId()]
	local dt = delay - player.timer:GetSeconds()
	if dt > 0 then
		Chat:Send(sender, format(message, ceil(dt)), color)
	else
		player.timer:Restart()
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
		insert(player.spheres, sphere)
	end
end)
