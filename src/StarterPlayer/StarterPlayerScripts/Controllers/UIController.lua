--[[
	UIController - Manages the seat game UI
	Handles inventory display, equipping chairs, and spinning
--]]

--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

--// Knit
local Knit = require(ReplicatedStorage.Packages.Knit)

--// Create Controller
local UIController = Knit.CreateController {
	Name = "UIController",
}

--// References
local DataService = nil -- Will be set in KnitStart

-- UI elements (will be initialized in KnitInit)
local gui = nil
local canvas = nil
local buttons = nil
local invButton = nil
local spinButton = nil
local invFrame = nil
local invClose = nil
local ownedButton = nil
local ownedStroke = nil
local indexButton = nil
local indexStroke = nil
local invList = nil
local invGridLayout = nil
local spinFrame = nil
local spinClose = nil
local spinContainer = nil
local spinList = nil
local picker = nil
local spinAction = nil
local chairTemplate = nil
local spinTemplate = nil

-- Game elements
local seatGame = nil
local seats = nil
local sounds = nil
local hoverSound = nil
local clickSound = nil
local rollSound = nil
local rewardSound = nil
local rng = nil
local spin = nil

--// State
local invOpen = false
local buttonSizes = {}
local equippedChair = "Default"
local currentCategory = "Owned" -- "Owned" or "Index"

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
	-- Set ViewportFrame properties to remove any colored outline/tint
	vp.ImageColor3 = Color3.fromRGB(255, 255, 255)
	vp.Ambient = Color3.fromRGB(255, 255, 255)
	vp.LightColor = Color3.fromRGB(255, 255, 255)

	local cam = createCamera(vp)
	local clone = model:Clone()
	clone.Parent = vp

	if not owned then
		for _, part in clone:GetDescendants() do
			if part:IsA("BasePart") then
				part.Color = Color3.fromRGB(20, 20, 20)
			end
		end

		-- Add blur effect for unowned chairs
		local blur = Instance.new("BlurEffect")
		blur.Size = 10
		blur.Parent = cam
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

	-- Remove all outlines/borders completely
	local rarity = item:FindFirstChild("Rarity")
	if rarity then
		rarity:Destroy()
	end

	-- Remove all UIStrokes (outlines)
	for _, descendant in item:GetDescendants() do
		if descendant:IsA("UIStroke") then
			descendant:Destroy()
		end
	end

	-- Setup equip button based on category
	local equipBtn = item:FindFirstChild("Equip")
	if equipBtn then
		if currentCategory == "Owned" then
			-- In Owned category, only show button if chair is owned
			if owned then
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
			else
				equipBtn.Visible = false
			end
		else
			-- In Index category, hide equip button completely
			equipBtn.Visible = false
		end
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

	-- Set CellPadding based on category
	if invGridLayout then
		if currentCategory == "Owned" then
			invGridLayout.CellPadding = UDim2.new(0, 15, 0, 50)
		else
			invGridLayout.CellPadding = UDim2.new(0, 15, 0, 15)
		end
	end

	-- Get equipped chair from server (using Knit)
	local success, equippedResult = pcall(function()
		return DataService:GetEquippedChair():expect()
	end)
	if success and equippedResult then
		equippedChair = equippedResult
	end

	-- Get owned chairs list
	local owned = {"Default"}
	local ownedSuccess, ownedResult = pcall(function()
		return DataService:GetOwnedChairs():expect()
	end)
	if ownedSuccess and type(ownedResult) == "table" then
		owned = ownedResult
	end

	-- Collect all chairs
	local chairList = {}
	for _, folder in seats:GetChildren() do
		if folder:IsA("Folder") then
			for _, model in folder:GetChildren() do
				if model:IsA("Model") then
					local has = table.find(owned, model.Name) ~= nil

					-- Filter based on category
					if currentCategory == "Owned" then
						-- Only show owned chairs
						if has then
							table.insert(chairList, {model = model, owned = has})
						end
					else
						-- Show all chairs in Index
						table.insert(chairList, {model = model, owned = has})
					end
				end
			end
		end
	end

	-- Sort chairs
	table.sort(chairList, function(a, b)
		if currentCategory == "Owned" then
			-- In Owned: equipped first, then alphabetically
			local aEquipped = a.model.Name == equippedChair
			local bEquipped = b.model.Name == equippedChair

			if aEquipped ~= bEquipped then
				return aEquipped
			end
		end

		return a.model.Name < b.model.Name
	end)

	-- Create chair items
	for _, entry in ipairs(chairList) do
		createChair(entry.model, entry.owned)
	end
end

--// Equip/Unequip
equipChair = function(chairName)
	equippedChair = chairName

	-- Save to server and update the physical chair (using Knit)
	task.spawn(function()
		pcall(function()
			DataService:SetEquippedChair(chairName)
		end)
	end)

	-- Update all chair buttons
	updateInventory()
end

unequipChair = function()
	equippedChair = "Default"

	-- Save to server and update the physical chair (using Knit)
	task.spawn(function()
		pcall(function()
			DataService:SetEquippedChair("Default")
		end)
	end)

	-- Update all chair buttons
	updateInventory()
end

--// Category Switching
local function updateCategoryHighlight()
	if not ownedStroke or not indexStroke then return end

	local activeColor = Color3.fromRGB(255, 255, 255)
	local inactiveColor = Color3.fromRGB(173, 173, 173)

	if currentCategory == "Owned" then
		-- Animate Owned to active
		TweenService:Create(ownedStroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = activeColor
		}):Play()

		-- Animate Index to inactive
		TweenService:Create(indexStroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = inactiveColor
		}):Play()
	else
		-- Animate Index to active
		TweenService:Create(indexStroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = activeColor
		}):Play()

		-- Animate Owned to inactive
		TweenService:Create(ownedStroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = inactiveColor
		}):Play()
	end
end

local function switchToOwned()
	if currentCategory == "Owned" then return end

	playSound(clickSound)
	currentCategory = "Owned"

	-- Update immediately
	updateInventory()
	updateCategoryHighlight()
end

local function switchToIndex()
	if currentCategory == "Index" then return end

	playSound(clickSound)
	currentCategory = "Index"

	-- Update immediately
	updateInventory()
	updateCategoryHighlight()
end

--// UI Control
local function closeInv()
	invOpen = false

	-- Smooth fade out
	TweenService:Create(invFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		GroupTransparency = 1
	}):Play()

	task.wait(0.15)
	hide(invFrame)
	invFrame.GroupTransparency = 0
end

local function toggleInv()
	playSound(clickSound)
	invOpen = not invOpen

	if invOpen then
		show(invFrame)
		invFrame.GroupTransparency = 1

		-- Smooth fade in
		TweenService:Create(invFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			GroupTransparency = 0
		}):Play()

		updateInventory()
		if spinFrame.Visible then hide(spinFrame) end
	else
		-- Smooth fade out
		TweenService:Create(invFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			GroupTransparency = 1
		}):Play()

		task.wait(0.15)
		hide(invFrame)
		invFrame.GroupTransparency = 0
	end
end

local function toggleSpin()
	playSound(clickSound)
	local vis = spinFrame.Visible

	if not vis then
		show(spinFrame)
		spinFrame.GroupTransparency = 1

		-- Smooth fade in
		TweenService:Create(spinFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			GroupTransparency = 0
		}):Play()

		if invFrame.Visible then
			-- Fade out inventory
			TweenService:Create(invFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				GroupTransparency = 1
			}):Play()
			task.wait(0.15)
			hide(invFrame)
			invFrame.GroupTransparency = 0
		end
	else
		-- Smooth fade out
		TweenService:Create(spinFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			GroupTransparency = 1
		}):Play()

		task.wait(0.15)
		hide(spinFrame)
		spinFrame.GroupTransparency = 0
	end
end

--// Knit Lifecycle
function UIController:KnitInit()
	-- Disable reset button
	task.spawn(function()
		pcall(function()
			StarterGui:SetCore("ResetButtonCallback", false)
		end)
	end)

	-- Get UI references (wait for them to replicate)
	local player = game:GetService("Players").LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	gui = playerGui:WaitForChild("SeatGameUI")
	canvas = gui:WaitForChild("Canvas")
	buttons = canvas:WaitForChild("ButtonContainer")
	invButton = buttons:WaitForChild("InventoryButton")
	spinButton = buttons:WaitForChild("SpinButton")
	invFrame = canvas:WaitForChild("Inventory")
	invClose = invFrame:WaitForChild("CloseButton")
	ownedButton = invFrame:WaitForChild("Owned")
	indexButton = invFrame:WaitForChild("Index")
	invList = invFrame:WaitForChild("List")
	invGridLayout = invList:FindFirstChildOfClass("UIGridLayout")

	-- Get UIStrokes for category buttons
	ownedStroke = ownedButton:FindFirstChildOfClass("UIStroke")
	indexStroke = indexButton:FindFirstChildOfClass("UIStroke")
	spinFrame = canvas:WaitForChild("SpinningFrame")
	spinClose = spinFrame:WaitForChild("CloseButton")
	spinContainer = spinFrame:WaitForChild("SpinContainer")
	spinList = spinContainer:WaitForChild("List")
	picker = spinContainer:WaitForChild("Picker")
	spinAction = spinFrame:WaitForChild("Spin")

	-- Get templates from StarterPlayerScripts/Templates
	local templatesFolder = script.Parent.Parent:WaitForChild("Templates")
	chairTemplate = templatesFolder:WaitForChild("ChairTemplate")
	spinTemplate = templatesFolder:WaitForChild("SpinTemplate")

	-- Get game elements
	seatGame = ReplicatedStorage:WaitForChild("SeatGame")
	seats = seatGame:WaitForChild("SeatModels")
	sounds = seatGame:WaitForChild("Sounds")
	hoverSound = sounds:WaitForChild("Hover")
	clickSound = sounds:WaitForChild("Click")
	rollSound = sounds:WaitForChild("Roll")
	rewardSound = sounds:WaitForChild("Reward")
	rng = require(seatGame.Modules.RNGModule)
	spin = require(seatGame.Modules.SpinModule)

	-- Setup UI
	invFrame.Visible = false
	spinFrame.Visible = false

	setupButton(invButton)
	setupButton(spinButton)
	setupButton(spinAction)
	setupButton(invClose)
	setupButton(spinClose)
	setupButton(ownedButton)
	setupButton(indexButton)

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

	ownedButton.MouseButton1Click:Connect(switchToOwned)
	indexButton.MouseButton1Click:Connect(switchToIndex)

	-- Set initial category highlight
	updateCategoryHighlight()
end

function UIController:KnitStart()
	-- Get DataService reference
	DataService = Knit.GetService("DataService")

	if not DataService then
		warn("Failed to get DataService!")
		return
	end

	-- Init Spin (pass DataService instead of RemoteFunction)
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
		dataService = DataService -- Changed from dataRemote to dataService
	})

	print("✓ UIController Initialized", {
		Buttons = "Inventory, Spin",
		Animations = "Button hover/press effects",
		Viewports = "3D seat previews with rotation"
	})
end

return UIController
