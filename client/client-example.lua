local ceil = math.ceil
local format, byte = string.format, string.byte

local timer = Timer()
local delay = example_config.delay
local color = example_config.color
local message = example_config.message

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
