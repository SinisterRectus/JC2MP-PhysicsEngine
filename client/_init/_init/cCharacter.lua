local huge = math.huge
local Vector3 = Vector3

-- Character models are approximated as spheres
-- Having dynamic values would be too expensive
-- Rico's radius is 1.0 to 1.2 meters
-- Colonel's radius is 1.3 to 1.6 meters
-- 1.5 m and 80 kg are used as an approximation

local radius = 1.5
local restitution = 0.3
local mass = 80
local inv_mass = 1 / mass
local inertia = 2/5 * mass * radius^2
local inv_inertia = 1 / inertia

local Character = {}

function Character:GetCentroid()
	return self:GetBonePosition("ragdoll_Hips")
end

function Character:GetAngularVelocity()
	return Vector3()
end

function Character:GetRadius()
	return radius
end

function Character:GetRestitution()
	return restitution
end

function Character:GetMass()
	return mass
end

function Character:GetInverseMass()
	return inv_mass
end

function Character:GetInertia()
	return Vector3(inertia, inertia, inertia)
end

function Character:GetInverseInertia()
	return Vector3(inv_inertia, inv_inertia, inv_inertia)
end

function Character:GetBoundingBox() -- expensive!

	local min_x, min_y, min_z = huge, huge, huge
	local max_x, max_y, max_z = -huge, -huge, -huge

	for _, bone in pairs(self:GetBones()) do
		local p = bone.position
		if p.x < min_x then min_x = p.x end
		if p.y < min_y then min_y = p.y end
		if p.z < min_z then min_z = p.z end
		if p.x > max_x then max_x = p.x end
		if p.y > max_y then max_y = p.y end
		if p.z > max_z then max_z = p.z end
	end

	return Vector3(min_x, min_y, min_z), Vector3(max_x, max_y, max_z)

end

function Character:GetNearestBone(position) -- expensive!

	local nearest_distance, nearest_bone = huge, nil

	for name, bone in pairs(self:GetBones()) do
		if name ~= 'ragdoll_Reference' then
			local distance = position:DistanceSqr(bone.position)
			if distance < nearest_distance then
				nearest_distance = distance
				nearest_bone = bone
			end
		end
	end

	return nearest_bone

end

for k, v in pairs(Character) do
	Player[k] = v
	ClientActor[k] = v
end
