# Gothic Box UI Frame Assets (Roblox Studio & Figma Ready)

This directory contains the refined, transparent, and editable assets for the ornate **Gothic Obsidian & Silver Filigree UI Box Frame**.

---

## 📁 Asset Catalog

| File | Resolution | Type | Description |
| :--- | :--- | :--- | :--- |
| **`GothicFrame.png`** | `1024 × 572` | PNG (32-bit ARGB) | **Full Canvas Master Frame**. Transparent exterior background and 100% transparent interior viewport. Ready for direct upload to Roblox Studio. |
| **`GothicFrame_Cropped.png`** | `690 × 303` | PNG (32-bit ARGB) | **Tightly Cropped Frame**. Frame and purple ambient glow bounded tightly (+6px margin). Saves GPU texture memory in Roblox. |
| **`GothicFrame.svg`** | `1024 × 572` | Scalable Vector (SVG) | **Layered Editable Master File**. Opens directly in **Figma**, **Adobe Illustrator**, and **Inkscape**. Contains editable vector layers, gradients, and plate. |
| **`GothicFrame_Vector.svg`** | `1024 × 572` | Pure Vector (SVG) | Pure mathematical paths (curves, spires, chamfers, and filters) with zero raster dependency. |
| **`GothicFrame_Cropped.svg`** | `690 × 303` | Scalable Vector (SVG) | Cropped vector format for tight component workflows. |

---

## 🛠️ Roblox Studio Setup Guide

### 1. Uploading the Asset
1. In Roblox Studio, open the **Asset Manager** (`View` > `Asset Manager`) or **Game Explorer**.
2. Click **Bulk Import** (or upload via `ImageLabel.Image` file picker).
3. Select `GothicFrame.png` or `GothicFrame_Cropped.png`.
4. Copy the resulting Asset ID (`rbxassetid://<ID>`).

### 2. Setting up 9-Slice (SliceCenter)

Using **9-Slice** ensures the ornate corner spires and gothic filigree remain crisp at 1:1 scale while the window borders stretch infinitely to fit any dialog, card, or button.

#### For `GothicFrame.png` (`1024 × 572`):
* **ScaleType**: `Enum.ScaleType.Slice`
* **SliceCenter**: `Rect.new(350, 250, 674, 320)`
* **BackgroundTransparency**: `1`

#### For `GothicFrame_Cropped.png` (`690 × 303`):
* **ScaleType**: `Enum.ScaleType.Slice`
* **SliceCenter**: `Rect.new(174, 105, 518, 195)`
* **BackgroundTransparency**: `1`

---

## 💻 Luau Code Example

```lua
--!strict
local function createGothicFrame(parent: Instance, assetId: string): ImageLabel
    local frame = Instance.new("ImageLabel")
    frame.Name = "GothicDialogBox"
    frame.Image = assetId -- e.g. "rbxassetid://110449235011652" or your uploaded asset ID
    frame.ScaleType = Enum.ScaleType.Slice
    frame.SliceCenter = Rect.new(350, 250, 674, 320) -- For GothicFrame.png
    frame.SliceScale = 0.55 -- 0.55 for Windows, 0.35 for Cards, 0.20 for Buttons
    frame.BackgroundTransparency = 1
    frame.Size = UDim2.fromOffset(500, 320)
    frame.Position = UDim2.fromScale(0.5, 0.5)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Parent = parent

    -- Content Container (100% transparent interior allows clean positioning)
    local content = Instance.new("Frame")
    content.Name = "ContentArea"
    content.BackgroundTransparency = 1
    content.Size = UDim2.new(1, -60, 1, -50)
    content.Position = UDim2.fromScale(0.5, 0.5)
    content.AnchorPoint = Vector2.new(0.5, 0.5)
    content.Parent = frame

    return frame
end
```

---

## 🎨 Editing in Figma / Adobe Illustrator
- Open `GothicFrame.svg` in Figma or Illustrator.
- The layers are organized into:
  - **Outer Glow**: Violet/purple emission (`#a87bff`). You can change this to Gold (`#ffd700`), Crimson (`#ff2a4b`), Ice Blue (`#00e1ff`), or Emerald (`#00ff9d`).
  - **Metallic Rails & Spires**: Silver/chrome gradients (`#ffffff` to `#9d98ad`).
  - **Corner Chamfers**: Gothic cathedral arch brackets.
  - **Viewport**: The transparent cutout in the center.
