--// Services
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

--// Module
local SpinModule = {}

--// Config
local SPIN_DURATION = 5
local TOTAL_ITEMS = 200

--// State
local currentTween = nil
local soundConnection = nil
local soundClones = {}
local isSpinning = false

--// Sound Management
local function stopAllSounds()
	if soundConnection then
		soundConnection:Disconnect()
		soundConnection = nil
	end

	for _, sound in soundClones do
		if sound and sound.Parent then
			sound:Stop()
			sound:Destroy()
		end
	end
	soundClones = {}
end

local function playSound(sound)
	local clone = sound:Clone()
	clone.Parent = SoundService
	clone:Play()
	table.insert(soundClones, clone)
end

function SpinModule:Stop()
	if currentTween then
		currentTween:Cancel()
		currentTween = nil
	end

	stopAllSounds()
	isSpinning = false
end

function SpinModule:StartSpin(spinList, spinContainer, picker, models, rollSound, rngModule, createDisplayFunc, onComplete)
	if isSpinning then return end
	isSpinning = true

	self:Stop()

	for _, child in spinList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local wonSeat = rngModule:GetWeightedRandom()
	local winnerIndex = math.floor(TOTAL_ITEMS * 0.85)

	for i = 1, TOTAL_ITEMS do
		local model = (i == winnerIndex) and wonSeat or models[math.random(1, #models)]
		local display = createDisplayFunc(model, rngModule)
		display.LayoutOrder = i
		display.Parent = spinList

		if i % 25 == 0 then
			task.wait()
		end
	end

	spinList.CanvasPosition = Vector2.new(0, 0)
	task.wait(0.1)

	local firstItem = nil
	for _, child in spinList:GetChildren() do
		if child:IsA("GuiObject") then
			firstItem = child
			break
		end
	end

	if not firstItem then
		isSpinning = false
		if onComplete then onComplete(nil) end
		return
	end

	local itemWidth = firstItem.AbsoluteSize.X
	local containerWidth = spinContainer.AbsoluteSize.X
	local targetPosition = (winnerIndex - 1) * itemWidth - (containerWidth / 2) + (itemWidth / 2)

	local lastSoundPos = 0
	soundConnection = RunService.Heartbeat:Connect(function()
		local currentPos = spinList.CanvasPosition.X
		if currentPos - lastSoundPos >= itemWidth then
			playSound(rollSound)
			lastSoundPos = currentPos
		end
	end)

	local tweenInfo = TweenInfo.new(
		SPIN_DURATION,
		Enum.EasingStyle.Quart,
		Enum.EasingDirection.Out
	)

	currentTween = TweenService:Create(spinList, tweenInfo, {
		CanvasPosition = Vector2.new(targetPosition, 0)
	})

	currentTween.Completed:Connect(function()
		stopAllSounds()

		local pickerCenter = picker.AbsolutePosition.X + (picker.AbsoluteSize.X / 2)
		local closestItem = nil
		local closestDistance = math.huge

		for _, child in spinList:GetChildren() do
			if child:IsA("GuiObject") then
				local itemCenter = child.AbsolutePosition.X + (child.AbsoluteSize.X / 2)
				local distance = math.abs(itemCenter - pickerCenter)
				if distance < closestDistance then
					closestDistance = distance
					closestItem = child
				end
			end
		end

		local wonSeatName = nil
		if closestItem then
			local nameLabel = closestItem:FindFirstChild("Name")
			if nameLabel then
				wonSeatName = nameLabel.Text
			end
		end

		isSpinning = false
		if onComplete then onComplete(wonSeatName) end
	end)

	currentTween:Play()
end

return SpinModule
