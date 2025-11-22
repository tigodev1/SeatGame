--// Simple Spin System
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Spin = {}
local busy = false
local config = nil

-- Idle scroll
local idleThread = nil
local function startIdle()
	if idleThread then return end
	idleThread = task.spawn(function()
		while task.wait() do
			if busy or not config then break end
			local pos = config.list.CanvasPosition.X + 10
			local max = config.list.AbsoluteCanvasSize.X - config.container.AbsoluteSize.X
			if max > 0 and pos > max then pos = 0 end
			config.list.CanvasPosition = Vector2.new(pos, 0)
		end
	end)
end

local function stopIdle()
	if idleThread then
		task.cancel(idleThread)
		idleThread = nil
	end
end

-- Sound helper
local function sound(s)
	if not s then return end
	local clone = s:Clone()
	clone.Parent = SoundService
	clone:Play()
	game:GetService("Debris"):AddItem(clone, 3)
end

-- Main spin
local function spin()
	if busy then
		print("Already spinning")
		return
	end

	print("Starting spin")
	busy = true
	stopIdle()

	-- Button
	config.button.Active = false
	config.button.Text = "..."

	-- Clear
	for _, v in config.list:GetChildren() do
		if v:IsA("GuiObject") then v:Destroy() end
	end

	-- Winner
	local winner = config.rng:GetWeightedRandom()
	local winPos = 135 -- position in the list

	-- Fill list
	for i = 1, 180 do
		local model = i == winPos and winner or config.models[math.random(#config.models)]
		local gui = config.makeDisplay(model, config.rng)
		gui.LayoutOrder = i
		gui.Parent = config.list
		if i % 10 == 0 then task.wait() end
	end

	config.list.CanvasPosition = Vector2.new(0, 0)
	task.wait()

	-- Measure
	local first = config.list:FindFirstChildOfClass("GuiObject")
	if not first then
		busy = false
		config.button.Active = true
		config.button.Text = "SPIN"
		startIdle()
		return
	end

	local itemW = first.AbsoluteSize.X
	local target = (winPos - 1) * itemW - config.container.AbsoluteSize.X / 2 + itemW / 2

	-- Sound thread
	local soundThread = task.spawn(function()
		local last = 0
		while busy do
			local curr = config.list.CanvasPosition.X
			if curr - last >= itemW then
				sound(config.rollSound)
				last = curr
			end
			task.wait()
		end
	end)

	-- Animate
	local tween = TweenService:Create(
		config.list,
		TweenInfo.new(4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{CanvasPosition = Vector2.new(target, 0)}
	)

	tween:Play()
	tween.Completed:Wait()

	-- Stop sound
	task.cancel(soundThread)

	-- Find winner
	local px = config.picker.AbsolutePosition.X + config.picker.AbsoluteSize.X / 2
	local closest = nil
	local closestD = math.huge

	for _, item in config.list:GetChildren() do
		if item:IsA("GuiObject") then
			local ix = item.AbsolutePosition.X + item.AbsoluteSize.X / 2
			local d = math.abs(ix - px)
			if d < closestD then
				closestD = d
				closest = item
			end
		end
	end

	-- Highlight
	if closest then
		local hi = Instance.new("UIStroke")
		hi.Color = Color3.fromRGB(255, 200, 0)
		hi.Thickness = 4
		hi.Parent = closest
		task.delay(1, function()
			if hi then hi:Destroy() end
		end)
	end

	-- Get name
	local name = nil
	if closest then
		local lbl = closest:FindFirstChild("Name")
		if lbl then name = lbl.Text end
	end

	-- Reward
	sound(config.rewardSound)

	-- Save
	if name then
		task.spawn(function()
			config.data:InvokeServer("UnlockChair", name)
		end)
	end

	-- Reset
	task.wait(0.5)
	config.button.Active = true
	config.button.Text = "SPIN"
	busy = false

	print("Spin done")
	startIdle()
end

-- Init
function Spin:Init(cfg)
	if config then return end

	config = {
		list = cfg.spinList,
		container = cfg.spinContainer,
		picker = cfg.picker,
		button = cfg.spinButton,
		models = cfg.models,
		rollSound = cfg.rollSound,
		rewardSound = cfg.rewardSound,
		rng = cfg.rngModule,
		makeDisplay = cfg.createDisplayFunc,
		data = cfg.dataRemote
	}

	-- Preview
	for i = 1, 30 do
		local m = config.models[math.random(#config.models)]
		local g = config.makeDisplay(m, config.rng)
		g.Parent = config.list
	end

	-- Button
	config.button.MouseButton1Click:Connect(spin)

	-- Idle
	startIdle()

	print("Spin ready")
end

return Spin
