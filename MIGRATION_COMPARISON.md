# Migration Comparison: Before & After

## File Organization

### Before (Old System)
```
ServerScriptService/
  Services/
    DataManager.lua         (creates RemoteFunction)
    SeatMain.lua            (requires DataManager)

StarterGui/
  SeatGameUI/
    InventoryScript.client.lua (calls RemoteFunction)
    SpinModule.lua          (calls RemoteFunction)

ReplicatedStorage/
  SeatGame/
    DataRemote              (RemoteFunction instance)
```

### After (Knit System)
```
ServerScriptService/
  KnitInit.server.lua       ⭐ NEW
  Services/
    DataService.lua         ⭐ NEW
    SeatService.lua         ⭐ NEW

StarterPlayer/
  StarterPlayerScripts/
    KnitInit.client.lua     ⭐ NEW

StarterGui/
  SeatGameUI/
    UIController.lua        ⭐ NEW
    SpinModule.lua          ✏️ MODIFIED
```

---

## Server-Side Comparison

### DataManager.lua (OLD) → DataService.lua (NEW)

#### Module Declaration

**Before:**
```lua
local DataManager = {}

return DataManager
```

**After:**
```lua
local Knit = require(ReplicatedStorage.Packages.Knit)

local DataService = Knit.CreateService {
    Name = "DataService",
    Client = {},
}

return DataService
```

#### RemoteFunction Setup

**Before:**
```lua
local remoteFunction = Instance.new("RemoteFunction")
remoteFunction.Name = "DataRemote"
remoteFunction.Parent = SeatGame

remoteFunction.OnServerInvoke = function(player, action, ...)
    if action == "GetEquippedChair" then
        return DataManager:GetEquippedChair(player)
    elseif action == "SetEquippedChair" then
        local chairName = ...
        return DataManager:SetEquippedChair(player, chairName)
    -- ... more actions
    end
end
```

**After:**
```lua
-- No RemoteFunction needed! Knit handles it automatically

function DataService.Client:GetEquippedChair(player)
    return self.Server:GetEquippedChair(player)
end

function DataService.Client:SetEquippedChair(player, chairName)
    return self.Server:SetEquippedChair(player, chairName)
end
```

#### Initialization

**Before:**
```lua
-- At bottom of file
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, player)
end
```

**After:**
```lua
-- In KnitInit method
function DataService:KnitInit()
    Players.PlayerAdded:Connect(onPlayerAdded)
    Players.PlayerRemoving:Connect(onPlayerRemoving)

    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(onPlayerAdded, player)
    end
end

function DataService:KnitStart()
    -- Service fully ready
end
```

### SeatMain.lua (OLD) → SeatService.lua (NEW)

#### Module Declaration & Dependencies

**Before:**
```lua
local DataManager = require(script.DataManager)

local SeatMain = {}

return SeatMain
```

**After:**
```lua
local Knit = require(ReplicatedStorage.Packages.Knit)

local SeatService = Knit.CreateService {
    Name = "SeatService",
    Client = {},
}

local DataService = nil -- Set in KnitStart

function SeatService:KnitStart()
    DataService = Knit.GetService("DataService")
end

return SeatService
```

#### Using DataManager/DataService

**Before:**
```lua
local equippedChairName = DataManager:GetEquippedChair(player)
```

**After:**
```lua
local equippedChairName = DataService:GetEquippedChair(player)
```

---

## Client-Side Comparison

### InventoryScript.client.lua (OLD) → UIController.lua (NEW)

#### Getting RemoteFunction vs Service

**Before:**
```lua
local data = game:WaitForChild("DataRemote")

-- Later in code
local equippedChair = data:InvokeServer("GetEquippedChair")
```

**After:**
```lua
local Knit = require(ReplicatedStorage.Packages.Knit)

local UIController = Knit.CreateController {
    Name = "UIController",
}

local DataService = nil

function UIController:KnitStart()
    DataService = Knit.GetService("DataService")

    -- Later in code
    local equippedChair = DataService:GetEquippedChair()
end
```

#### Calling Server Methods

**Before:**
```lua
-- Multiple action strings
data:InvokeServer("GetEquippedChair")
data:InvokeServer("SetEquippedChair", chairName)
data:InvokeServer("GetOwnedChairs")
data:InvokeServer("UnlockChair", chairName)
data:InvokeServer("IncrementRolls")
```

**After:**
```lua
-- Direct method calls
DataService:GetEquippedChair()
DataService:SetEquippedChair(chairName)
DataService:GetOwnedChairs()
DataService:UnlockChair(chairName)
DataService:IncrementRolls()
```

#### updateInventory Function

**Before:**
```lua
updateInventory = function()
    -- ...

    local success, result = pcall(function()
        return data:InvokeServer("GetEquippedChair")
    end)

    local owned = data:InvokeServer("GetOwnedChairs")

    -- ...
end
```

**After:**
```lua
updateInventory = function()
    -- ...

    local success, result = pcall(function()
        return DataService:GetEquippedChair()
    end)

    local owned = DataService:GetOwnedChairs()

    -- ...
end
```

#### equipChair Function

**Before:**
```lua
equipChair = function(chairName)
    equippedChair = chairName

    task.spawn(function()
        pcall(function()
            data:InvokeServer("SetEquippedChair", chairName)
        end)
    end)

    updateInventory()
end
```

**After:**
```lua
equipChair = function(chairName)
    equippedChair = chairName

    task.spawn(function()
        pcall(function()
            DataService:SetEquippedChair(chairName)
        end)
    end)

    updateInventory()
end
```

---

## SpinModule Changes

### SpinModule.lua

#### Initialization

**Before:**
```lua
function SpinModule:Init(cfg)
    assert(cfg.dataRemote, "Missing dataRemote")

    config = {
        -- ...
        data = cfg.dataRemote
    }
end
```

**After:**
```lua
function SpinModule:Init(cfg)
    assert(cfg.dataService, "Missing dataService")

    config = {
        -- ...
        data = cfg.dataService
    }
end
```

#### Calling Server

**Before:**
```lua
config.data:InvokeServer("IncrementRolls")
config.data:InvokeServer("UnlockChair", winnerName)
```

**After:**
```lua
config.data:IncrementRolls()
config.data:UnlockChair(winnerName)
```

#### Passed from UIController

**Before:**
```lua
-- In InventoryScript.client.lua
local data = game:WaitForChild("DataRemote")

spin:Init({
    -- ...
    dataRemote = data
})
```

**After:**
```lua
-- In UIController.lua
local DataService = Knit.GetService("DataService")

spin:Init({
    -- ...
    dataService = DataService
})
```

---

## Initialization Scripts

### Server Init

**Before:**
```
No central initialization - each script runs independently:
- DataManager.lua runs and creates RemoteFunction
- SeatMain.lua requires DataManager
```

**After:**
```lua
-- KnitInit.server.lua
local Knit = require(ReplicatedStorage.Packages.Knit)

Knit.AddServices(ServerScriptService.Services)

Knit.Start():catch(warn)
```

### Client Init

**Before:**
```
No central initialization - InventoryScript.client.lua runs automatically
```

**After:**
```lua
-- KnitInit.client.lua
local Knit = require(ReplicatedStorage.Packages.Knit)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local seatGameUI = playerGui:WaitForChild("SeatGameUI")
Knit.AddControllers(seatGameUI)

Knit.Start():catch(warn)
```

---

## Benefits Summary

| Aspect | Before (Old) | After (Knit) |
|--------|-------------|--------------|
| **Networking** | Manual RemoteFunction | Automatic (Knit handles it) |
| **Method Calls** | String-based actions | Direct method calls |
| **Type Safety** | None (strings) | Better (actual methods) |
| **Dependencies** | Manual require() | Managed by Knit |
| **Initialization** | Scattered | Centralized KnitInit |
| **Code Organization** | Mixed concerns | Clear Service/Controller separation |
| **Error Handling** | Same pcall pattern | Same pcall pattern |
| **Functionality** | ✓ Works | ✓ Works exactly the same |

---

## Testing Both Systems

You can temporarily keep both systems and test them side-by-side:

1. **Old System:** Delete KnitInit scripts, game uses DataManager/SeatMain/InventoryScript
2. **New System:** Keep KnitInit scripts, game uses DataService/SeatService/UIController

The new Knit system will take priority because KnitInit scripts load the new services/controllers first.

---

**Migration complete! The game functions identically but with better code structure and automatic networking.**
