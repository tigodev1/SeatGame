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

--// UI
local gui = script.Parent
local canvas = gui:WaitForChild("Canvas")
local buttons = canvas:WaitForChild("ButtonContainer")
local invButton = buttons:WaitForChild("InventoryButton")
local spinButton = buttons:WaitForChild("SpinButton")
local invFrame = canvas:WaitForChild("Inventory")
local invClose = invFrame:WaitForChild("CloseButton")
local spinFrame = canvas:WaitForChild("SpinningFrame")
local spinClose = spinFrame:WaitForChild("CloseButton")
local spinContainer = spinFrame:WaitForChild("SpinContainer")
local spinList = spinContainer:WaitForChild("List")
local picker = spinContainer:WaitForChild("Picker")
local spinAction = spinFrame:WaitForChild("Spin")
local invList = invFrame:WaitForChild("List")
local chairTemplate = script:WaitForChild("ChairTemplate")
local spinTemplate = script:WaitForChild("SpinTemplate")

--// Game
local game = ReplicatedStorage:WaitForChild("SeatGame")
local seats = game:WaitForChild("SeatModels")
local sounds = game:WaitForChild("Sounds")
local hoverSound = sounds:WaitForChild("Hover")
local clickSound = sounds:WaitForChild("Click")
local rollSound = sounds:WaitForChild("Roll")
local rewardSound = sounds:WaitForChild("Reward")
local rng = require(game.Modules.RNGModule)
local spin = require(game.Modules.SpinModule)
local data = game:WaitForChild("DataRemote")

--// State
local invOpen = false
local buttonSizes = {}
local equippedChair = "Default"

-- Forward declarations
local updateInventory
local equipChair
local unequipChair

--// Utils
local function playSound(sound)
	local s = sound:Clone()
	s.Parent = SoundService
	s:Play()
	task.delay(sound.TimeLength, function() s:Destroy() end)
end

local function scale(udim, s)
	return UDim2.new(udim.X.Scale * s, udim.X.Offset * s, udim.Y.Scale * s, udim.Y.Offset * s)
end

local function show(frame)
	frame.Visible = true
end

local function hide(frame)
	frame.Visible = false
end

--// Button Animations
local function setupButton(btn)
	btn.Active = true
	buttonSizes[btn] = btn.Size
	local info = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	btn.MouseEnter:Connect(function()
		playSound(hoverSound)
		TweenService:Create(btn, info, {Size = scale(buttonSizes[btn], 1.05)}):Play()
	end)

	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, info, {Size = buttonSizes[btn]}):Play()
	end)

	btn.MouseButton1Down:Connect(function()
		TweenService:Create(btn, info, {Size = scale(buttonSizes[btn], 0.95)}):Play()
	end)

	btn.MouseButton1Up:Connect(function()
		TweenService:Create(btn, info, {Size = scale(buttonSizes[btn], 1.05)}):Play()
	end)
end

--// Viewport
local function createCamera(vp)
	local cam = Instance.new("Camera")
	cam.Parent = vp
	vp.CurrentCamera = cam
	return cam
end

local function setupViewport(vp, model, rotate, owned)
	local cam = createCamera(vp)
	local clone = model:Clone()
	clone.Parent = vp

	if not owned then
		for _, part in clone:GetDescendants() do
			if part:IsA("BasePart") then
				part.Color = Color3.fromRGB(20, 20, 20)
			end
		end
	end

	local cf, size = clone:GetBoundingBox()
	local dist = math.max(size.X, size.Y, size.Z) * 1.0
	cam.CFrame = CFrame.new(cf.Position + Vector3.new(dist, dist * 0.3, dist))
	cam.CFrame = CFrame.lookAt(cam.CFrame.Position, cf.Position)

	if rotate then
		local angle = 0
		RunService.RenderStepped:Connect(function(dt)
			if clone and clone.Parent then
				angle = angle + (dt * 50)
				clone:PivotTo(CFrame.new(cf.Position) * CFrame.Angles(0, math.rad(angle), 0))
			end
		end)
	end
end

--// Displays
local function createChair(model, owned)
	local item = chairTemplate:Clone()
	item.Visible = true

	local vp = item:FindFirstChild("ViewportFrame")
	if vp then setupViewport(vp, model, true, owned) end

	local name = item:FindFirstChild("Name")
	if name then name.Text = model.Name end

	-- Setup equip button
	local equipBtn = item:FindFirstChild("Equip")
	if equipBtn and owned then
		local isEquipped = equippedChair == model.Name

		equipBtn.Text = isEquipped and "UNEQUIP" or "EQUIP"
		equipBtn.BackgroundColor3 = isEquipped and Color3.fromRGB(200, 50, 50) or Color3.fromRGB(50, 200, 50)
		equipBtn.Visible = true

		setupButton(equipBtn)

		equipBtn.MouseButton1Click:Connect(function()
			playSound(clickSound)

			if equippedChair == model.Name then
				unequipChair()
			else
				equipChair(model.Name)
			end
		end)
	elseif equipBtn then
		equipBtn.Visible = false
	end

	item.Parent = invList
end

local function createSpin(model, rngMod)
	local item = spinTemplate:Clone()
	item.Visible = true

	local vp = item:FindFirstChild("ViewportFrame")
	if vp then setupViewport(vp, model, false, true) end

	local name = item:FindFirstChild("Name")
	if name then name.Text = model.Name end

	local rarity = item:FindFirstChild("Rarity")
	if rarity then
		local r = rngMod:GetSeatRarity(model)
		rarity.BackgroundColor3 = rngMod:GetRarityColor(r)
	end

	return item
end

--// Inventory
updateInventory = function()
	for _, child in invList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	-- Get equipped chair from server
	local success, result = pcall(function()
		return data:InvokeServer("GetEquippedChair")
	end)

	if success and result then
		equippedChair = result
	end

	local owned = data:InvokeServer("GetOwnedChairs")

	-- Sort chairs: equipped first, then by name
	local chairList = {}
	-- Iterate through all rarity folders to get all chair models
	for _, folder in seats:GetChildren() do
		if folder:IsA("Folder") then
			for _, model in folder:GetChildren() do
				if model:IsA("Model") then
					local has = table.find(owned, model.Name) ~= nil
					table.insert(chairList, {model = model, owned = has})
				end
			end
		end
	end

	table.sort(chairList, function(a, b)
		local aEquipped = a.model.Name == equippedChair
		local bEquipped = b.model.Name == equippedChair

		if aEquipped ~= bEquipped then
			return aEquipped -- Equipped chair goes first
		end

		return a.model.Name < b.model.Name -- Then sort alphabetically
	end)

	-- Create chair items in sorted order
	for _, entry in ipairs(chairList) do
		createChair(entry.model, entry.owned)
	end
end

--// Equip/Unequip
equipChair = function(chairName)
	equippedChair = chairName

	-- Save to server and update the physical chair
	task.spawn(function()
		pcall(function()
			data:InvokeServer("SetEquippedChair", chairName)
		end)
	end)

	-- Update all chair buttons
	updateInventory()
end

unequipChair = function()
	equippedChair = "Default"

	-- Save to server and update the physical chair
	task.spawn(function()
		pcall(function()
			data:InvokeServer("SetEquippedChair", "Default")
		end)
	end)

	-- Update all chair buttons
	updateInventory()
end

--// UI Control
local function closeInv()
	invOpen = false
	hide(invFrame)
end

local function toggleInv()
	playSound(clickSound)
	invOpen = not invOpen

	if invOpen then
		show(invFrame)
		updateInventory()
		if spinFrame.Visible then hide(spinFrame) end
	else
		hide(invFrame)
	end
end

local function toggleSpin()
	playSound(clickSound)
	local vis = spinFrame.Visible

	if not vis then
		show(spinFrame)
		if invFrame.Visible then hide(invFrame) end
	else
		hide(spinFrame)
	end
end

--// Setup
invFrame.Visible = false
spinFrame.Visible = false

setupButton(invButton)
setupButton(spinButton)
setupButton(spinAction)
setupButton(invClose)
setupButton(spinClose)

invButton.MouseButton1Click:Connect(toggleInv)
spinButton.MouseButton1Click:Connect(toggleSpin)
invClose.MouseButton1Click:Connect(function()
	playSound(clickSound)
	closeInv()
end)
spinClose.MouseButton1Click:Connect(function()
	playSound(clickSound)
	hide(spinFrame)
end)

--// Init Spin
spin:Init({
	spinList = spinList,
	spinContainer = spinContainer,
	picker = picker,
	spinButton = spinAction,
	models = rng:GetSeatModels(),
	rollSound = rollSound,
	rewardSound = rewardSound,
	rngModule = rng,
	createDisplayFunc = createSpin,
	dataRemote = data
})

print("✓ UI Client Initialized", {
	Buttons = "Inventory, Spin",
	Animations = "Button hover/press effects",
	Viewports = "3D seat previews with rotation"
})
