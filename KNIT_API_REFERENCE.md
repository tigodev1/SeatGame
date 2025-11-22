# Knit API Reference - SeatGame

## DataService (Server & Client)

### Client Methods (callable from client)

```lua
local Knit = require(ReplicatedStorage.Packages.Knit)
local DataService = Knit.GetService("DataService")

-- Get list of owned chairs
local ownedChairs = DataService:GetOwnedChairs()
-- Returns: {"Default", "Chair1", "Chair2", ...}

-- Get currently equipped chair
local equippedChair = DataService:GetEquippedChair()
-- Returns: "ChairName" or "Default"

-- Set equipped chair
local success = DataService:SetEquippedChair("ChairName")
-- Returns: boolean

-- Unlock a new chair
local success = DataService:UnlockChair("ChairName")
-- Returns: boolean

-- Increment rolls counter
local success = DataService:IncrementRolls()
-- Returns: boolean

-- Check if player owns a chair
local owns = DataService:OwnsChair("ChairName")
-- Returns: boolean
```

### Server-Only Methods

```lua
local Knit = require(ReplicatedStorage.Packages.Knit)
local DataService = Knit.GetService("DataService")

-- Get player's profile
local profile = DataService:GetProfile(player)
-- Returns: ProfileStore profile object or nil

-- Get player's data table
local data = DataService:GetData(player)
-- Returns: data table or nil

-- Add chair to player (internal method)
local success = DataService:AddChair(player, "ChairName")
-- Returns: boolean

-- Get player's rolls count
local rolls = DataService:GetRolls(player)
-- Returns: number
```

---

## SeatService (Server Only)

### Server Methods

```lua
local Knit = require(ReplicatedStorage.Packages.Knit)
local SeatService = Knit.GetService("SeatService")

-- Swap player's physical chair model
SeatService:SwapPlayerChair(player)
-- Returns: void
```

---

## UIController (Client Only)

The UIController manages all UI interactions automatically. You don't need to call it directly - it sets up event listeners for:

- Inventory button clicks
- Spin button clicks
- Chair equip/unequip actions
- UI animations

---

## Migration Comparison

### Old RemoteFunction System

```lua
-- SERVER: DataManager.lua
remoteFunction.OnServerInvoke = function(player, action, ...)
    if action == "GetEquippedChair" then
        return DataManager:GetEquippedChair(player)
    elseif action == "SetEquippedChair" then
        local chairName = ...
        return DataManager:SetEquippedChair(player, chairName)
    end
end

-- CLIENT: InventoryScript.client.lua
local data = game.ReplicatedStorage.SeatGame:WaitForChild("DataRemote")
local equippedChair = data:InvokeServer("GetEquippedChair")
local success = data:InvokeServer("SetEquippedChair", "ChairName")
```

### New Knit System

```lua
-- SERVER: DataService.lua
function DataService.Client:GetEquippedChair(player)
    return self.Server:GetEquippedChair(player)
end

function DataService.Client:SetEquippedChair(player, chairName)
    return self.Server:SetEquippedChair(player, chairName)
end

-- CLIENT: UIController.lua
local Knit = require(ReplicatedStorage.Packages.Knit)
local DataService = Knit.GetService("DataService")

local equippedChair = DataService:GetEquippedChair()
local success = DataService:SetEquippedChair("ChairName")
```

**Key Difference:** No more string-based action names! Direct method calls with type safety.

---

## Lifecycle Methods

### Services (Server)

```lua
function MyService:KnitInit()
    -- Called when service is created
    -- All services exist but may not be ready
    -- Good for: Setting up connections, initializing data structures
end

function MyService:KnitStart()
    -- Called after all KnitInit methods complete
    -- All services are ready to use
    -- Good for: Getting other services, setting up cross-service communication
end
```

### Controllers (Client)

```lua
function MyController:KnitInit()
    -- Called when controller is created
    -- All controllers exist but may not be ready
    -- Good for: Setting up UI elements, local state
end

function MyController:KnitStart()
    -- Called after all KnitInit methods complete
    -- All services and controllers are ready
    -- Good for: Getting services, setting up communication
end
```

---

## Common Patterns

### Getting a Service (Client)

```lua
-- In KnitStart (recommended)
function MyController:KnitStart()
    local DataService = Knit.GetService("DataService")
    local chairs = DataService:GetOwnedChairs()
end
```

### Getting a Service (Server)

```lua
-- In KnitStart (recommended)
function MyService:KnitStart()
    local DataService = Knit.GetService("DataService")
    local data = DataService:GetData(player)
end
```

### Exposing Methods to Clients

```lua
-- Server-side service
local MyService = Knit.CreateService {
    Name = "MyService",
    Client = {},
}

-- Server-only method
function MyService:DoSomething(player)
    -- Implementation
end

-- Client-accessible method
function MyService.Client:DoSomething(player)
    return self.Server:DoSomething(player)
end
```

---

## SpinModule Integration

The SpinModule has been updated to accept a DataService instead of a RemoteFunction:

```lua
-- OLD
spin:Init({
    -- ...
    dataRemote = data -- RemoteFunction instance
})

-- NEW
spin:Init({
    -- ...
    dataService = DataService -- Knit service
})
```

Internal calls updated:
```lua
-- OLD
config.data:InvokeServer("IncrementRolls")
config.data:InvokeServer("UnlockChair", chairName)

-- NEW
config.data:IncrementRolls()
config.data:UnlockChair(chairName)
```

---

## Error Handling

All client-server communication should still use pcall for safety:

```lua
local success, result = pcall(function()
    return DataService:GetEquippedChair()
end)

if success then
    print("Equipped chair:", result)
else
    warn("Failed to get equipped chair:", result)
end
```

---

## Directory Structure

```
Services go in:    ServerScriptService/Services/
Controllers go in: StarterGui/SeatGameUI/ (or StarterPlayerScripts/Controllers/)
Init scripts:      ServerScriptService/KnitInit.server.lua
                  StarterPlayerScripts/KnitInit.client.lua
```

---

**For full Knit documentation, visit:** https://sleitnick.github.io/Knit/
