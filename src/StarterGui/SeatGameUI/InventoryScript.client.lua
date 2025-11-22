--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

task.spawn(function()
	pcall(function()
		StarterGui:SetCore("ResetButtonCallback", false)
	end)
end)

--// Instances
local screenGui = script.Parent
local canvas = screenGui:WaitForChild("Canvas")
local buttonContainer = canvas:WaitForChild("ButtonContainer")
local inventoryButton = buttonContainer:WaitForChild("InventoryButton")
local spinButton = buttonContainer:WaitForChild("SpinButton")
local inventoryFrame = canvas:WaitForChild("Inventory")
local inventoryCloseButton = inventoryFrame:WaitForChild("CloseButton")
local spinningFrame = canvas:WaitForChild("SpinningFrame")
local spinningCloseButton = spinningFrame:WaitForChild("CloseButton")
local spinContainer = spinningFrame:WaitForChild("SpinContainer")
local spinList = spinContainer:WaitForChild("List")
local picker = spinContainer:WaitForChild("Picker")
local spinActionButton = spinningFrame:WaitForChild("Spin")
local list = inventoryFrame:WaitForChild("List")
local chairTemplate = script:WaitForChild("ChairTemplate")
local spinTemplate = script:WaitForChild("SpinTemplate")

local seatGame = ReplicatedStorage:WaitForChild("SeatGame")
local seatModels = seatGame:WaitForChild("SeatModels")
local soundsFolder = seatGame:WaitForChild("Sounds")
local hoverSound = soundsFolder:WaitForChild("Hover")
local clickSound = soundsFolder:WaitForChild("Click")
local rollSound = soundsFolder:WaitForChild("Roll")
local rewardSound = soundsFolder:WaitForChild("Reward")
local rngModule = require(seatGame.Modules.RNGModule)
local spinModule = require(script:WaitForChild("SpinModule"))
local dataRemote = seatGame:WaitForChild("DataRemote")

--// Config
local IDLE_SCROLL_SPEED = 20
local BUTTON_TWEEN_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BUTTON_CLICK_INFO = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FRAME_SLIDE_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SPIN_COOLDOWN = 0.5

--// Variables
local isInventoryOpen = false
local canSpin = true
local lastSpinTime = 0
local buttonSizes = {}
local idleRollConnection = nil
local buttonOriginalColors = {}

--// Utility Functions
local function playSound(sound)
	local clone = sound:Clone()
	clone.Parent = SoundService
	clone:Play()
	task.delay(sound.TimeLength, function()
		clone:Destroy()
	end)
end

local function scaleUDim2(udim2, scale)
	return UDim2.new(
		udim2.X.Scale * scale,
		udim2.X.Offset * scale,
		udim2.Y.Scale * scale,
		udim2.Y.Offset * scale
	)
end

local function showFrame(frame)
	frame.Visible = true
	frame.Position = UDim2.new(0.5, 0, 1.2, 0)

	local slideIn = TweenService:Create(frame, FRAME_SLIDE_INFO, {
		Position = UDim2.new(0.5, 0, 0.5, 0)
	})
	slideIn:Play()
end

local function hideFrame(frame, callback)
	local slideOut = TweenService:Create(frame,
		TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In),
		{Position = UDim2.new(0.5, 0, 1.2, 0)}
	)

	slideOut.Completed:Connect(function()
		frame.Visible = false
		frame.Position = UDim2.new(0.5, 0, 0.5, 0)
		if callback then callback() end
	end)

	slideOut:Play()
end

local function setButtonEnabled(button, enabled)
	button.Active = enabled

	local targetColor = enabled and (buttonOriginalColors[button] or Color3.fromRGB(255, 255, 255))
		or Color3.fromRGB(100, 100, 100)

	local targetTransparency = enabled and 0 or 0.5

	TweenService:Create(button, TweenInfo.new(0.2), {
		BackgroundColor3 = targetColor,
		BackgroundTransparency = targetTransparency
	}):Play()

	local textLabel = button:FindFirstChildOfClass("TextLabel") or button:FindFirstChildOfClass("TextButton")
	if textLabel then
		TweenService:Create(textLabel, TweenInfo.new(0.2), {
			TextTransparency = enabled and 0 or 0.5
		}):Play()
	end
end

--// Button Animation Setup
local function setupButtonAnimation(button)
	buttonSizes[button] = button.Size
	buttonOriginalColors[button] = button.BackgroundColor3

	button.MouseEnter:Connect(function()
		if button.Active then
			playSound(hoverSound)
			TweenService:Create(button, BUTTON_TWEEN_INFO, {
				Size = scaleUDim2(buttonSizes[button], 1.08)
			}):Play()
		end
	end)

	button.MouseLeave:Connect(function()
		TweenService:Create(button, BUTTON_TWEEN_INFO, {
			Size = buttonSizes[button]
		}):Play()
	end)

	button.MouseButton1Down:Connect(function()
		if button.Active then
			TweenService:Create(button, BUTTON_CLICK_INFO, {
				Size = scaleUDim2(buttonSizes[button], 0.92)
			}):Play()
		end
	end)

	button.MouseButton1Up:Connect(function()
		if button.Active then
			TweenService:Create(button, BUTTON_CLICK_INFO, {
				Size = scaleUDim2(buttonSizes[button], 1.08)
			}):Play()
		end
	end)
end

--// Viewport Functions
local function createViewportCamera(viewport)
	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return camera
end

local function setupChairInViewport(viewport, chairModel, rotating, isOwned)
	local camera = createViewportCamera(viewport)
	local clone = chairModel:Clone()
	clone.Parent = viewport

	if isOwned == false then
		for _, descendant in clone:GetDescendants() do
			if descendant:IsA("BasePart") or descendant:IsA("MeshPart") then
				descendant.Color = Color3.fromRGB(20, 20, 20)
			end
		end
	end

	local cframe, size = clone:GetBoundingBox()
	local distance = math.max(size.X, size.Y, size.Z) * 1.0

	camera.CFrame = CFrame.new(cframe.Position + Vector3.new(distance, distance * 0.3, distance))
	camera.CFrame = CFrame.lookAt(camera.CFrame.Position, cframe.Position)

	if rotating then
		local angle = 0
		RunService.RenderStepped:Connect(function(dt)
			if clone and clone.Parent then
				angle = angle + (dt * 50)
				local rotatedCFrame = CFrame.new(cframe.Position) * CFrame.Angles(0, math.rad(angle), 0)
				clone:PivotTo(rotatedCFrame)
			end
		end)
	end
end

--// Display Creation
local function createChairDisplay(chairModel, isOwned)
	local template = chairTemplate:Clone()
	template.Visible = true

	local viewport = template:FindFirstChild("ViewportFrame")
	local nameLabel = template:FindFirstChild("Name")

	if viewport then
		setupChairInViewport(viewport, chairModel, true, isOwned)
	end

	if nameLabel then
		nameLabel.Text = chairModel.Name
	end

	template.Parent = list
end

local function createSpinDisplay(chairModel, rngMod)
	local template = spinTemplate:Clone()
	template.Visible = true

	local viewport = template:FindFirstChild("ViewportFrame")
	local nameLabel = template:FindFirstChild("Name")
	local rarityFrame = template:FindFirstChild("Rarity")

	if viewport then
		setupChairInViewport(viewport, chairModel, false, true)
	end

	if nameLabel then
		nameLabel.Text = chairModel.Name
	end

	if rarityFrame then
		local rarity = rngMod:GetSeatRarity(chairModel)
		rarityFrame.BackgroundColor3 = rngMod:GetRarityColor(rarity)
	end

	return template
end

--// Inventory Functions
local function populateInventory()
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local ownedChairs = dataRemote:InvokeServer("GetOwnedChairs")

	for _, chairModel in seatModels:GetChildren() do
		if chairModel:IsA("Model") then
			local isOwned = table.find(ownedChairs, chairModel.Name) ~= nil
			createChairDisplay(chairModel, isOwned)
		end
	end
end

--// Spin Functions
local function populateSpinList()
	for _, child in spinList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local models = seatModels:GetChildren()
	local selectedSeats = {}

	for i = 1, 10 do
		selectedSeats[i] = models[math.random(1, #models)]
	end

	for loop = 1, 4 do
		for _, model in ipairs(selectedSeats) do
			local display = createSpinDisplay(model, rngModule)
			display.Parent = spinList
		end
		if loop < 4 then
			task.wait()
		end
	end

	spinList.CanvasPosition = Vector2.new(0, 0)
end

local function startIdleRoll()
	if idleRollConnection then return end

	idleRollConnection = RunService.Heartbeat:Connect(function(dt)
		if not spinModule:IsSpinning() and spinList then
			local maxScroll = spinList.AbsoluteCanvasSize.X - spinContainer.AbsoluteSize.X
			if maxScroll > 0 then
				local newPosition = spinList.CanvasPosition.X + (IDLE_SCROLL_SPEED * dt)
				if newPosition > maxScroll then
					newPosition = newPosition % maxScroll
				end
				spinList.CanvasPosition = Vector2.new(newPosition, 0)
			end
		end
	end)
end

local function stopIdleRoll()
	if idleRollConnection then
		idleRollConnection:Disconnect()
		idleRollConnection = nil
	end
end

local function performSpin()
	-- Multiple spam prevention checks
	if spinModule:IsSpinning() then
		warn("[Client] Spin already in progress (module check)")
		return
	end

	if not canSpin then
		warn("[Client] Spin on cooldown")
		return
	end

	if not spinActionButton.Active then
		warn("[Client] Button not active")
		return
	end

	local currentTime = tick()
	if currentTime - lastSpinTime < SPIN_COOLDOWN then
		warn("[Client] Cooldown not elapsed")
		return
	end

	-- Lock all spin controls
	canSpin = false
	lastSpinTime = currentTime
	stopIdleRoll()
	playSound(clickSound)

	setButtonEnabled(spinActionButton, false)
	spinActionButton.Text = "SPINNING..."

	local models = seatModels:GetChildren()

	spinModule:StartSpin(spinList, spinContainer, picker, models, rollSound, rngModule, createSpinDisplay, function(wonSeatName)
		task.wait(0.2)

		if wonSeatName then
			playSound(rewardSound)
			task.spawn(function()
				dataRemote:InvokeServer("UnlockChair", wonSeatName)
			end)
		end

		task.wait(0.3)

		-- Re-enable spin controls
		spinActionButton.Text = "SPIN"
		setButtonEnabled(spinActionButton, true)

		task.wait(SPIN_COOLDOWN)
		canSpin = true

		startIdleRoll()
	end)
end

--// UI Control Functions
local function closeInventory()
	isInventoryOpen = false
	hideFrame(inventoryFrame)
end

local function closeSpinning()
	hideFrame(spinningFrame, function()
		stopIdleRoll()
	end)
end

local function toggleInventory()
	playSound(clickSound)
	isInventoryOpen = not isInventoryOpen

	if isInventoryOpen then
		showFrame(inventoryFrame)
		populateInventory()
		if spinningFrame.Visible then
			hideFrame(spinningFrame)
		end
	else
		hideFrame(inventoryFrame)
	end
end

local function toggleSpinning()
	playSound(clickSound)
	local wasVisible = spinningFrame.Visible

	if not wasVisible then
		showFrame(spinningFrame)
		populateSpinList()
		startIdleRoll()
		if inventoryFrame.Visible then
			hideFrame(inventoryFrame)
		end
	else
		hideFrame(spinningFrame, function()
			stopIdleRoll()
		end)
	end
end

--// Initialize
inventoryFrame.Visible = false
spinningFrame.Visible = false

setupButtonAnimation(inventoryButton)
setupButtonAnimation(spinButton)
setupButtonAnimation(spinActionButton)
setupButtonAnimation(inventoryCloseButton)
setupButtonAnimation(spinningCloseButton)

inventoryButton.MouseButton1Click:Connect(toggleInventory)
spinButton.MouseButton1Click:Connect(toggleSpinning)
spinActionButton.MouseButton1Click:Connect(performSpin)
inventoryCloseButton.MouseButton1Click:Connect(function()
	playSound(clickSound)
	closeInventory()
end)
spinningCloseButton.MouseButton1Click:Connect(function()
	playSound(clickSound)
	closeSpinning()
end)
