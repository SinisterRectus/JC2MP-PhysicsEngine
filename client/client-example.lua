local ceil = math.ceil
local format, byte = string.format, string.byte

local timer = Timer()
local delay = 1
local message = 'Please wait %i second(s) before spawning another sphere!'
local color = Color.Silver

-- Press Z to spawn a sphere.
-- A more robust script would restrict spawning server-side, as well.

Events:Subscribe('KeyUp', function(args)
	if args.key == byte('Z') then
		local dt = delay - timer:GetSeconds()
		if dt > 0 then
			Chat:Print(format(message, ceil(dt)), color)
		else
			timer:Restart()
			Network:Send('CreateSphere')
		end
	end
end)
