--[[
	Client Knit Initialization
	This script loads all Knit controllers and starts the framework
--]]

--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--// Knit
local Knit = require(ReplicatedStorage.Packages.Knit)

--// Add Controllers
-- The UIController is located in StarterGui/SeatGameUI
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local seatGameUI = playerGui:WaitForChild("SeatGameUI")
Knit.AddControllers(seatGameUI)

--// Start Knit
Knit.Start():andThen(function()
	print("✓ Knit Started [Client]")
end):catch(function(err)
	warn("✗ Knit Start Failed [Client]:", err)
end)
