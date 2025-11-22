--// Services
local StarterGui = game:GetService("StarterGui")

--// Initialize
task.spawn(function()
	pcall(function()
		StarterGui:SetCore("ResetButtonCallback", false)
	end)
end)
