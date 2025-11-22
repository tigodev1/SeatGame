--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

--// Knit
local Knit = require(ReplicatedStorage.Packages.Knit)

Knit.AddServices(ServerScriptService.Services)

Knit.Start():andThen(function()
	print("✓ Knit Started [Server]")
end):catch(function(err)
	warn("✗ Knit Start Failed [Server]:", err)
end)
