# Gothic UI Vector & Frame Assets (Roblox Studio, Figma & Pure Vector)

This directory contains the authoritative vector and raster assets for Infinite Tower's **Gothic Obsidian, Gold & Silver UI System**.
All assets are structured in scalable vector formats (SVG) and procedural Luau components (`GothicVectorIcons.luau` and `GothicBoxStyle.luau`) to guarantee resolution independence and eliminate distortion or blurring when UI elements are resized.

---

## 📁 Asset Catalog

### 1. Vector Master Assets (Pure Mathematical Vectors)

| File | Resolution | Format | Description |
| :--- | :--- | :--- | :--- |
| **`GothicFrame_Vector.svg`** | `1024 × 572` | SVG | **Gothic Box Frame**. Pure mathematical paths (curves, spires, chamfers, and ambient glow). |
| **`GothicFrame_Cropped.svg`** | `690 × 303` | SVG | **Tightly Cropped Frame**. Bounded frame for compact component layouts. |
| **`ShopIcon_Vector.svg`** | `256 × 256` | SVG | **Shop Medallion**. Gothic merchant pavilion canopy, gold vault coin, and filigree rim. |
| **`SquadIcon_Vector.svg`** | `256 × 256` | SVG | **Squad Crest**. Crossed broadswords, knightly heraldic shield, and silver rim. |
| **`OverdriveIcon_Vector.svg`** | `256 × 256` | SVG | **Overdrive Burst**. Celestial 8-point starburst, dynamic lightning bolt, and fiery rim. |
| **`RecallIcon_Vector.svg`** | `256 × 256` | SVG | **Recall Rift**. Arcane spiral vortex, sacred return chevron, and cyan rune diamonds. |
| **`TowerIcon_Vector.svg`** | `256 × 256` | SVG | **Tower Spire**. Monolith citadel silhouette, tiered spire, and pinnacle beacon star. |
| **`GoldIcon_Vector.svg`** | `128 × 128` | SVG | **Gold Medallion**. Beveled gold coin, starburst engraving, and specular sheen. |
| **`GemIcon_Vector.svg`** | `128 × 128` | SVG | **Gem Crystal**. Faceted 45° cyan diamond with specular facet highlights. |

---

## 💻 In-Game Vector Architecture

In runtime Roblox UI, raster images stretch and pixelate when resized across different device resolutions.
To prevent this:
1. **`GothicBoxStyle.luau`**:
   - Uses procedural vector GuiObjects (`Frame`, `UICorner`, `UIStroke`, `UIGradient`) for windows, cards, and buttons.
   - Eliminates 9-slice raster stretching, keeping silver rails and corner spires crisp at 100% vector scale.
2. **`GothicVectorIcons.luau`**:
   - Generates pure vector action emblems (`Shop`, `Squad`, `Overdrive`, `Recall`, `Tower`, `Gold`, `Gems`, `Aura`).
   - Equipped with `UIAspectRatioConstraint` (1:1), ensuring icons remain perfectly proportioned regardless of layout resizing.
3. **`OrnateFrameButton.luau`**:
   - Rendered using vector double rails and faceted vector diamond gems.
