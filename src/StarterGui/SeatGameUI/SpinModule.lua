--// Services
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

--// Module
local SpinModule = {}

--// Config
local SPIN_DURATION = 5
local ITEMS_PER_SET = 50
local NUMBER_OF_SETS = 4

--// State
local connection = nil
local soundClones = {}
local isSpinning = false

--// Easing Function
local function easeOutQuart(t)
	return 1 - math.pow(1 - t, 4)
end

--// Sound Functions
local function playSound(sound)
	local clone = sound:Clone()
	clone.Parent = SoundService
	clone:Play()
	table.insert(soundClones, clone)
	task.delay(sound.TimeLength, function()
		if clone and clone.Parent then
			clone:Destroy()
		end
		local index = table.find(soundClones, clone)
		if index then
			table.remove(soundClones, index)
		end
	end)
end

function SpinModule:Stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end

	local sounds = soundClones
	soundClones = {}

	for _, sound in sounds do
		if sound and sound.Parent then
			sound:Stop()
			sound:Destroy()
		end
	end

	isSpinning = false
end

function SpinModule:StartSpin(spinList, spinContainer, picker, models, rollSound, rngModule, createDisplayFunc, onComplete)
	if isSpinning then return end
	isSpinning = true

	for _, child in spinList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local wonSeat = rngModule:GetWeightedRandom()
	local totalItems = ITEMS_PER_SET * NUMBER_OF_SETS

	for i = 1, totalItems do
		local model
		if i == math.floor(totalItems * 0.85) then
			model = wonSeat
		else
			model = models[math.random(1, #models)]
		end

		local display = createDisplayFunc(model, rngModule)
		display.LayoutOrder = i
		display.Parent = spinList

		if i % 20 == 0 then
			task.wait()
		end
	end

	task.wait(0.1)
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
	local targetIndex = math.floor(totalItems * 0.85)
	local targetPosition = (targetIndex - 1) * itemWidth - (containerWidth / 2) + (itemWidth / 2)

	local startTime = os.clock()
	local lastSoundPos = 0

	connection = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - startTime
		local progress = math.min(elapsed / SPIN_DURATION, 1)
		local easedProgress = easeOutQuart(progress)
		local currentPos = easedProgress * targetPosition

		spinList.CanvasPosition = Vector2.new(currentPos, 0)

		if currentPos - lastSoundPos >= itemWidth then
			playSound(rollSound)
			lastSoundPos = currentPos
		end

		if progress >= 1 then
			self:Stop()
			spinList.CanvasPosition = Vector2.new(targetPosition, 0)

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
			return
		end
	end)
end

return SpinModule
