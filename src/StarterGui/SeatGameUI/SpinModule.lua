--[[
	SpinModule - Slot Machine Spinning System
	Features:
	- Smooth idle scrolling at 20px/sec
	- Exponential easing for dramatic slow-down
	- Instant reward feedback
	- 2 second highlight celebration
--]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local SpinModule = {}

-- State
local isSpinning = false
local config = nil
local idleConnection = nil

-- Constants
local IDLE_SCROLL_SPEED = 20
local SPIN_DURATION = 4.5
local TOTAL_ITEMS = 200
local WINNER_POSITION = 150
local HIGHLIGHT_COLOR = Color3.fromRGB(255, 215, 0)
local HIGHLIGHT_THICKNESS = 5
local HIGHLIGHT_DURATION = 2
local EASING_STYLE = Enum.EasingStyle.Exponential
local EASING_DIRECTION = Enum.EasingDirection.Out

--[[
	Sound Helper
--]]
local function playSound(sound)
	if not sound then return end

	local clone = sound:Clone()
	clone.Parent = SoundService
	clone:Play()

	task.delay(clone.TimeLength + 0.5, function()
		if clone then
			clone:Destroy()
		end
	end)
end

--[[
	Idle Animation
--]]
local function startIdleScroll()
	if idleConnection then return end

	idleConnection = RunService.Heartbeat:Connect(function(deltaTime)
		if isSpinning or not config then
			return
		end

		local currentX = config.list.CanvasPosition.X
		local newX = currentX + (IDLE_SCROLL_SPEED * deltaTime)
		local maxX = config.list.AbsoluteCanvasSize.X - config.container.AbsoluteSize.X

		if maxX > 0 and newX > maxX then
			newX = 0
		end

		config.list.CanvasPosition = Vector2.new(newX, 0)
	end)
end

local function stopIdleScroll()
	if idleConnection then
		idleConnection:Disconnect()
		idleConnection = nil
	end
end

--[[
	List Management
--]]
local function clearList()
	for _, child in pairs(config.list:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function populateList(winner)
	clearList()

	for i = 1, TOTAL_ITEMS do
		local model

		if i == WINNER_POSITION then
			model = winner
		else
			model = config.models[math.random(1, #config.models)]
		end

		local gui = config.makeDisplay(model, config.rng)
		gui.LayoutOrder = i
		gui.Name = "Item_" .. i
		gui.Parent = config.list

		if i % 20 == 0 then
			task.wait()
		end
	end

	task.wait(0.1)
end

--[[
	Calculate Target Position
--]]
local function calculateTargetPosition()
	local firstItem = config.list:FindFirstChild("Item_1")
	if not firstItem then
		return 0
	end

	local itemWidth = firstItem.AbsoluteSize.X
	local pickerCenterX = config.picker.AbsolutePosition.X + (config.picker.AbsoluteSize.X / 2)
	local containerStartX = config.container.AbsolutePosition.X
	local pickerOffsetFromContainer = pickerCenterX - containerStartX
	local winnerItemCenterX = (WINNER_POSITION - 1) * itemWidth + (itemWidth / 2)
	local targetScroll = winnerItemCenterX - pickerOffsetFromContainer
	local maxScroll = config.list.AbsoluteCanvasSize.X - config.container.AbsoluteSize.X

	return math.clamp(targetScroll, 0, maxScroll)
end

--[[
	Roll Sound Thread
--]]
local function createSoundThread()
	local soundActive = true
	local lastPosition = 0
	local firstItem = config.list:FindFirstChild("Item_1")
	if not firstItem then return function() end end

	local itemWidth = firstItem.AbsoluteSize.X

	local thread = task.spawn(function()
		while soundActive and isSpinning do
			local currentPosition = config.list.CanvasPosition.X

			if currentPosition - lastPosition >= itemWidth then
				playSound(config.rollSound)
				lastPosition = currentPosition
			end

			task.wait()
		end
	end)

	return function()
		soundActive = false
		task.cancel(thread)
	end
end

--[[
	Find Winner Element
--]]
local function findWinnerElement()
	local pickerCenterX = config.picker.AbsolutePosition.X + (config.picker.AbsoluteSize.X / 2)

	local closestItem = nil
	local closestDistance = math.huge

	for _, item in pairs(config.list:GetChildren()) do
		if item:IsA("GuiObject") then
			local itemCenterX = item.AbsolutePosition.X + (item.AbsoluteSize.X / 2)
			local distance = math.abs(itemCenterX - pickerCenterX)

			if distance < closestDistance then
				closestDistance = distance
				closestItem = item
			end
		end
	end

	return closestItem
end

--[[
	Highlight Winner with Pulsing Effect
--]]
local function highlightWinner(item)
	if not item then return end

	local stroke = Instance.new("UIStroke")
	stroke.Color = HIGHLIGHT_COLOR
	stroke.Thickness = HIGHLIGHT_THICKNESS
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = item

	local pulseTween = TweenService:Create(
		stroke,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, true),
		{Thickness = HIGHLIGHT_THICKNESS + 2}
	)
	pulseTween:Play()

	-- Fade out smoothly before cleanup
	task.delay(HIGHLIGHT_DURATION - 0.3, function()
		if stroke then
			local fadeTween = TweenService:Create(
				stroke,
				TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{Thickness = 0}
			)
			fadeTween:Play()
			fadeTween.Completed:Wait()
		end

		if pulseTween then
			pulseTween:Cancel()
		end
		if stroke then
			stroke:Destroy()
		end
	end)
end

--[[
	Get Item Name
--]]
local function getItemName(item)
	if not item then return nil end

	local nameLabel = item:FindFirstChild("Name")
	if nameLabel and nameLabel:IsA("TextLabel") then
		return nameLabel.Text
	end

	return nil
end

--[[
	Main Spin Function
--]]
local function executeSpin()
	if isSpinning then return end

	isSpinning = true
	stopIdleScroll()

	config.button.Active = false
	config.button.Text = "SPINNING..."

	local winner = config.rng:GetWeightedRandom()
	if not winner then
		isSpinning = false
		config.button.Active = true
		config.button.Text = "SPIN"
		startIdleScroll()
		return
	end

	populateList(winner)

	config.list.CanvasPosition = Vector2.new(0, 0)
	task.wait(0.2)

	local targetPosition = calculateTargetPosition()
	local stopSounds = createSoundThread()

	local spinTween = TweenService:Create(
		config.list,
		TweenInfo.new(SPIN_DURATION, EASING_STYLE, EASING_DIRECTION),
		{CanvasPosition = Vector2.new(targetPosition, 0)}
	)

	spinTween:Play()
	spinTween.Completed:Wait()

	stopSounds()

	-- Find winner and give INSTANT feedback
	local winnerElement = findWinnerElement()
	local winnerName = getItemName(winnerElement)

	highlightWinner(winnerElement)
	playSound(config.rewardSound)

	-- Save to player data (async)
	if winnerName then
		task.spawn(function()
			pcall(function()
				config.data:InvokeServer("UnlockChair", winnerName)
			end)
		end)
	end

	-- Wait for highlight to finish before transitioning to idle
	task.wait(HIGHLIGHT_DURATION)

	config.button.Active = true
	config.button.Text = "SPIN"
	isSpinning = false

	startIdleScroll()
end

--[[
	Initialize
--]]
function SpinModule:Init(cfg)
	if config then return end

	-- Validate config
	assert(cfg.spinList, "Missing spinList")
	assert(cfg.spinContainer, "Missing spinContainer")
	assert(cfg.picker, "Missing picker")
	assert(cfg.spinButton, "Missing spinButton")
	assert(cfg.models, "Missing models")
	assert(cfg.rngModule, "Missing rngModule")
	assert(cfg.createDisplayFunc, "Missing createDisplayFunc")
	assert(cfg.dataRemote, "Missing dataRemote")

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

	-- Create initial preview items
	for i = 1, 40 do
		local randomModel = config.models[math.random(1, #config.models)]
		local gui = config.makeDisplay(randomModel, config.rng)
		gui.LayoutOrder = i
		gui.Parent = config.list
	end

	task.wait(0.2)

	config.button.MouseButton1Click:Connect(executeSpin)
	startIdleScroll()

	print("✓ SpinModule Initialized", {
		Models = #config.models,
		IdleSpeed = IDLE_SCROLL_SPEED .. "px/s",
		SpinDuration = SPIN_DURATION .. "s",
		Items = TOTAL_ITEMS,
		Easing = tostring(EASING_STYLE.Name)
	})
end

--[[
	Cleanup
--]]
function SpinModule:Cleanup()
	stopIdleScroll()
	clearList()
	config = nil
	isSpinning = false
end

return SpinModule
