--// Services
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

--// Module
local SpinModule = {}

--// Config
local SPIN_DURATION = 4.5
local TOTAL_ITEMS = 180
local IDLE_SPEED = 15

--// State
local spinning = false
local initialized = false

--// References
local ui = {}
local game_data = {}

--// Connections
local idleLoop = nil
local soundLoop = nil
local activeSounds = {}

--// Functions
local function cleanup()
	if idleLoop then
		idleLoop:Disconnect()
		idleLoop = nil
	end

	if soundLoop then
		soundLoop:Disconnect()
		soundLoop = nil
	end

	for _, sound in activeSounds do
		if sound then
			sound:Destroy()
		end
	end
	activeSounds = {}
end

local function playSound(sound)
	if not sound then return end
	local s = sound:Clone()
	s.Parent = SoundService
	s:Play()
	table.insert(activeSounds, s)
	task.delay(2, function()
		if s then s:Destroy() end
	end)
end

local function startIdle()
	if idleLoop or spinning then return end

	idleLoop = RunService.Heartbeat:Connect(function(dt)
		if spinning or not ui.list then return end

		local max = ui.list.AbsoluteCanvasSize.X - ui.container.AbsoluteSize.X
		if max > 0 then
			local pos = ui.list.CanvasPosition.X + (IDLE_SPEED * dt)
			if pos > max then pos = 0 end
			ui.list.CanvasPosition = Vector2.new(pos, 0)
		end
	end)
end

local function stopIdle()
	if idleLoop then
		idleLoop:Disconnect()
		idleLoop = nil
	end
end

local function doSpin()
	if spinning then return end
	spinning = true

	stopIdle()
	cleanup()

	-- Update button
	ui.button.Active = false
	ui.button.Text = "SPINNING..."

	-- Clear list
	for _, child in ui.list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	-- Pick winner
	local winner = game_data.rng:GetWeightedRandom()
	local winIndex = math.floor(TOTAL_ITEMS * 0.75)

	-- Populate
	for i = 1, TOTAL_ITEMS do
		local seat = (i == winIndex) and winner or game_data.models[math.random(1, #game_data.models)]
		local display = game_data.createDisplay(seat, game_data.rng)
		display.LayoutOrder = i
		display.Parent = ui.list

		if i % 15 == 0 then
			task.wait()
		end
	end

	ui.list.CanvasPosition = Vector2.new(0, 0)
	task.wait(0.1)

	-- Get measurements
	local firstItem = ui.list:FindFirstChildOfClass("GuiObject")
	if not firstItem then
		spinning = false
		ui.button.Active = true
		ui.button.Text = "SPIN"
		startIdle()
		return
	end

	local itemWidth = firstItem.AbsoluteSize.X
	local target = (winIndex - 1) * itemWidth - (ui.container.AbsoluteSize.X / 2) + (itemWidth / 2)

	-- Sound loop
	local lastPos = 0
	soundLoop = RunService.Heartbeat:Connect(function()
		if not spinning then return end
		local pos = ui.list.CanvasPosition.X
		if pos - lastPos >= itemWidth then
			playSound(game_data.rollSound)
			lastPos = pos
		end
	end)

	-- Tween
	local tween = TweenService:Create(
		ui.list,
		TweenInfo.new(SPIN_DURATION, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{CanvasPosition = Vector2.new(target, 0)}
	)

	tween.Completed:Connect(function()
		-- Stop sounds
		cleanup()

		-- Find winner
		local pickerX = ui.picker.AbsolutePosition.X + (ui.picker.AbsoluteSize.X / 2)
		local closest = nil
		local closestDist = math.huge

		for _, item in ui.list:GetChildren() do
			if item:IsA("GuiObject") then
				local itemX = item.AbsolutePosition.X + (item.AbsoluteSize.X / 2)
				local dist = math.abs(itemX - pickerX)
				if dist < closestDist then
					closestDist = dist
					closest = item
				end
			end
		end

		-- Highlight
		if closest then
			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.fromRGB(255, 215, 0)
			stroke.Thickness = 3
			stroke.Parent = closest

			task.delay(1, function()
				if stroke then stroke:Destroy() end
			end)
		end

		-- Get name
		local wonName = nil
		if closest then
			local label = closest:FindFirstChild("Name")
			if label then wonName = label.Text end
		end

		-- Play reward
		playSound(game_data.rewardSound)

		-- Save
		if wonName then
			task.spawn(function()
				game_data.dataRemote:InvokeServer("UnlockChair", wonName)
			end)
		end

		-- Reset
		ui.button.Active = true
		ui.button.Text = "SPIN"
		spinning = false

		startIdle()
	end)

	tween:Play()
end

function SpinModule:Init(config)
	if initialized then return end

	ui.list = config.spinList
	ui.container = config.spinContainer
	ui.picker = config.picker
	ui.button = config.spinButton

	game_data.models = config.models
	game_data.rollSound = config.rollSound
	game_data.rewardSound = config.rewardSound
	game_data.rng = config.rngModule
	game_data.createDisplay = config.createDisplayFunc
	game_data.dataRemote = config.dataRemote

	-- Initial preview
	for i = 1, 40 do
		local seat = game_data.models[math.random(1, #game_data.models)]
		local display = game_data.createDisplay(seat, game_data.rng)
		display.Parent = ui.list
	end

	ui.list.CanvasPosition = Vector2.new(0, 0)

	-- Connect button
	ui.button.MouseButton1Click:Connect(doSpin)

	-- Start idle
	startIdle()

	initialized = true
end

function SpinModule:Cleanup()
	cleanup()
	stopIdle()
	spinning = false
	initialized = false
end

return SpinModule
