# SeatGame
The Random Seat Game - Spin to collect rare seats!

## 🎮 Game Concept

Join the game → instantly sitting

- **No walking, no tutorial—just vibes**
- Press the Spin Button to get random seats
- Common seats appear often, rare ones become legends
- Equip and swap seats anytime
- Collect & store in your inventory
- Flex with rarity tags, effects, and cosmetics

## 🛠️ Setup Instructions

### Getting the Code in VS Code

**If you haven't cloned yet:**
```bash
git clone https://github.com/tigodev1/SeatGame.git
cd SeatGame
git checkout claude/rng-seat-game-01SESGcnieiiXLjA5sNuvgaL
git pull
```

**If you already have it cloned:**
```bash
cd SeatGame
git fetch origin
git checkout claude/rng-seat-game-01SESGcnieiiXLjA5sNuvgaL
git pull origin claude/rng-seat-game-01SESGcnieiiXLjA5sNuvgaL
```

### Using the Scripts in Roblox Studio

1. **Open your Roblox Studio place**

2. **Set up the folder structure:**
   - In **ServerScriptService**: Create a folder called "Services"
   - In **ReplicatedStorage**: Create folders: SeatGame > SeatModels
   - In **Workspace**: Create a folder called "SeatsPlacing"

3. **Copy the script:**
   - Copy `src/ServerScriptService/Services/SeatMain.lua` into ServerScriptService > Services

4. **Create seat positions:**
   - In Workspace > SeatsPlacing, create numbered folders (1, 2, 3, etc.)
   - In each numbered folder, create a folder called "Seat"
   - In each Seat folder, create an invisible Part called "AnchorPoint":
     - Anchored = true
     - CanCollide = false
     - Transparency = 1
     - Size = (1, 1, 1)
   - Position these AnchorPoint parts where you want seats to appear

5. **Create the Default seat:**
   - In ReplicatedStorage > SeatGame > SeatModels, create a Model called "Default"
   - Inside this model, create a Seat part (the actual seat players sit on)
   - Add any additional parts for the chair design (backrest, legs, etc.)
   - All parts should be Anchored = true

## 📁 Required Structure

**ServerScriptService:**
```
Services/
└── SeatMain (Script) ← Copy from repo
```

**ReplicatedStorage:**
```
SeatGame/
└── SeatModels/
    └── Default (Model) ← Create your seat model here
        └── Seat (Seat part)
        └── [Other parts for chair design]
```

**Workspace:**
```
SeatsPlacing/
├── 1/
│   └── Seat/
│       └── AnchorPoint (Part - invisible)
├── 2/
│   └── Seat/
│       └── AnchorPoint (Part - invisible)
└── ... (create as many as you need)
```

## 🎯 Current Features (v0.1)

- ✅ Players auto-seated when joining
- ✅ Seats placed at designated anchor points
- ✅ Jump/movement disabled while seated
- ✅ Support for 8 concurrent players
- ✅ Default seat model

## 🚧 Coming Soon

- Spin button to get random seats
- Multiple seat rarities (Common, Rare, Epic, Legendary)
- Inventory system
- Seat equipping system
- Visual effects and cosmetics
- Rarity indicators

## 📝 Notes

- The game uses 8 pre-defined seat positions (expandable)
- Seats automatically anchor to the baseplate
- Players cannot jump or move when seated
- Default seat is a simple grey chair with backrest
