--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Knit
local Knit = require(ReplicatedStorage.Packages.Knit)

local UIController = require(script.Parent.Controllers.UIController)

Knit.Start():andThen(function()
	print("✓ Knit Started [Client]")
end):catch(function(err)
	warn("✗ Knit Start Failed [Client]:", err)
end)
