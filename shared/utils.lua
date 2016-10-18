local Forward = Vector3.Forward
local AngleAxis = Angle.AngleAxis
local FromVectors = Angle.FromVectors

local bodies = {
	Sphere = true,
}

local characters = {
	Player = true,
	ClientActor = true,
	LocalPlayer = true,
}

function Angle:__add(w) -- rotate angle by vector amount
	local s = w:Length()
	return s > 0 and self * AngleAxis(s, w / s) or self
end

function Vector3:ToAngle() -- return angle in direction of vector
	return FromVectors(Forward, self)
end

function IsPhysicsBody(object)
	return bodies[object.__type] or false
end

function IsCharacter(object)
	return characters[object.__type] or false
end

function IsVehicle(object)
	return object.__type == 'Vehicle'
end

function IsDynamic(object)
	return IsVehicle(object) or IsCharacter(object) or IsPhysicsBody(object) and object.dynamic
end
