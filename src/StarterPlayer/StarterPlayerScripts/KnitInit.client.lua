--[[
	Client Knit Initialization
	This script loads all Knit controllers and starts the framework
--]]

--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Knit
local Knit = require(ReplicatedStorage.Packages.Knit)

--// Add Controllers
local UIController = require(script.Parent.Controllers.UIController)

--// Start Knit
Knit.Start():andThen(function()
	print("✓ Knit Started [Client]")
end):catch(function(err)
	warn("✗ Knit Start Failed [Client]:", err)
end)
