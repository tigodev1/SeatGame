# Templates Folder

This folder contains UI templates used by the UIController.

## Required Templates:

1. **ChairTemplate** (Frame)
   - UI template for displaying chairs in inventory
   - Must contain: ViewportFrame, Name (TextLabel), Rarity (Frame), Equip (TextButton)

2. **SpinTemplate** (Frame)
   - UI template for displaying chairs in the spin wheel
   - Must contain: ViewportFrame, Name (TextLabel), Rarity (Frame)

## Setup Instructions:

In Roblox Studio, move these templates from `StarterGui/SeatGameUI` to `StarterPlayer/StarterPlayerScripts/Templates`:
- ChairTemplate
- SpinTemplate

These are cloned by the UIController when needed.
