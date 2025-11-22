--[[
	Server Knit Initialization
	This script loads all Knit services and starts the framework
--]]

--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

--// Knit
local Knit = require(ReplicatedStorage.Packages.Knit)

--// Add Services
Knit.AddServices(ServerScriptService.Services)

--// Start Knit
Knit.Start():andThen(function()
	print("✓ Knit Started [Server]")
end):catch(function(err)
	warn("✗ Knit Start Failed [Server]:", err)
end)
