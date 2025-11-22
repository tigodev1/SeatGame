--!strict

--// Services
local StarterGui = game:GetService("StarterGui")

--// Disable Reset Button
task.spawn(function()
	pcall(function()
		StarterGui:SetCore("ResetButtonCallback", false)
	end)
end)
