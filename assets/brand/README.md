# Haltian Brand Assets

This directory contains official Haltian brand assets extracted from the brandbook (October 2024).

## Directory Structure

```
brand/
├── Logo/                      # Official Haltian logos
│   ├── Haltian_logo_2024_*.png    # Full logos (black, green, white variants)
│   ├── Haltian_icon_2024_*.png    # Icon/mark only (black, green, white)
│   └── *.png                       # Logo usage guidelines
├── Graphics/                  # Brand graphic elements
│   ├── Mountain line graphics/     # Digital twin mountain elements
│   ├── Building line graphics/     # Digital twin building elements
│   ├── Occupancy visuals/          # Sensor visualization graphics
│   ├── CTA_*.png                   # Call-to-action buttons
│   ├── Tag_*.png                   # Tag/label graphics
│   ├── Pointers_*.png              # Pointer/arrow elements
│   └── Short_text_graphics_*.png   # Text callout boxes
└── Icons/                     # Icon library
    ├── Icons for light backgrounds/  # Green and orange icon variants
    └── Icons for dark backgrounds/    # Icon variants for dark mode

```

## Logo Usage

### Available Logo Variants

1. **Full Logo** (word mark + icon)
   - `Haltian_logo_2024_white.png` - For dark backgrounds (navigation bar)
   - `Haltian_logo_2024_green.png` - For light backgrounds (Radiant Green)
   - `Haltian_logo_2024_black.png` - For print/light backgrounds

2. **Icon/Mark Only**
   - `Haltian_icon_2024_green.png` - Primary icon (used as favicon)
   - `Haltian_icon_2024_white.png` - For dark backgrounds
   - `Haltian_icon_2024_black.png` - For light backgrounds

### Logo Clear Space

Maintain clear space around the logo equal to the height of the mountain triangle (see `Logo clear space.png`).

### Logo Placement

- **Preferred**: Bottom left or right corner of advertisements
- **Navigation**: Top left of site navigation bar
- Always use sufficient contrast with background

## Graphics Usage

### Mountain Line Graphics

Digital twin visualization of Halti mountain. Available in multiple opacity levels:

- **100% opacity**: Main visual element when no photography
- **20-50% opacity**: Overlay on photography

**Colors available**: Nordic Water, Radiant Green, Pure White

**Placement**: Always bottom left or right corner

### Building Line Graphics

Digital twin visualization of buildings representing smart spaces.

**Colors available**: Nordic Water, Radiant Green, Pure White

**Usage**: Similar to mountain graphics, for workspace/building contexts

### CTA Buttons

Pre-designed call-to-action button graphics:
- `CTA_green.png` - Primary actions (Radiant Green)
- `CTA_orange.png` - Secondary actions (Clay Orange)

### Tags and Pointers

Visual elements for highlighting content:
- `Tag_*.png` - Labels and categories
- `Pointers_*.png` - Directional indicators
- `Short_text_graphics_*.png` - Text callout boxes

## Icons Usage

### Icon Library

250+ icons covering topics like:
- IoT devices and sensors (occupancy, temperature, humidity, CO2, etc.)
- Business concepts (growth, efficiency, sustainability)
- Applications (Haltian IoT Studio, API, data centers)
- Industries (hospital equipment, warehouse, offices, factories)

### Icon Variants

**For Light Backgrounds**:
- Green variant (Radiant Green #73F9C1) - Default
- Orange variant (Clay Orange #FF8862) - Accent

**For Dark Backgrounds**:
- Available in `Icons for dark backgrounds/` directory
- White/light variants for Nordic Water backgrounds

### Icon Implementation

Icons follow the brand "sensor pop-up" effect with concentric circles:

```scss
// Icon on light background (Radiant Green)
- Inner circle: Radiant Green #73F9C1 at 100%
- Middle stroke: Radiant Green #73F9C1 at 70%
- Outer stroke: Radiant Green #73F9C1 at 30%
- Fill: Pure White #FFFFFF

// Icon on dark background (Clay Orange)
- Inner circle: Clay Orange #FF8862 at 100%
- Middle stroke: Clay Orange #FF8862 at 70%
- Outer stroke: Clay Orange #FF8862 at 40%
- Fill: Transparent
```

## Brand Colors Reference

### Primary Colors
- **Radiant Green**: `#73F9C1` - Primary brand color, links, accents
- **Nordic Water**: `#143633` - Dark backgrounds, headers, text

### Secondary Colors
- **Clay Orange**: `#FF8862` - CTAs, hover states, highlights
- **Grey White**: `#F6FAFA` - Light backgrounds, sidebar
- **Pure White**: `#FFFFFF` - Text on dark, backgrounds

### Color Usage Ratio
- 25% Nordic Water
- 25% Grey White
- 20% Radiant Green
- 20% Pure White
- 10% Clay Orange

## Typography

**Primary Typeface**: Montserrat (Google Fonts)

Weights used:
- Regular 400 - Body text
- Medium 500 - Navigation, labels
- Semibold 600 - Headlines, subheadlines

## Brand Values

**Core Values**: Passion, Fair, Together

**Value Proposition**: "Because every space can work better"

**Mission**: "We solve the challenges of sustainable future, one IoT innovation at a time"

**Tagline**: "Technology made easy, from start to finish"

## Using Assets in Hugo

### In Markdown Content

```markdown
<!-- Logo -->
![Haltian Logo](/assets/brand/Logo/Haltian_logo_2024_green.png)

<!-- Icon -->
![Occupancy Icon](/assets/brand/Icons/Icons for light backgrounds/Occupancy_green_whiteBG.png)

<!-- Graphic Element -->
![Mountain Graphic](/assets/brand/Graphics/Mountain line graphics/Mountain_line_graphics_radiant_green_20%.png)
```

### In HTML/Shortcodes

```html
<img src="/assets/brand/Logo/Haltian_logo_2024_white.png" 
     alt="Haltian" 
     class="navbar-logo">
```

### Background Images (CSS)

```scss
.hero-section {
  background-image: url('/assets/brand/Graphics/Mountain line graphics/Mountain_line_graphics_white_20%.png');
  background-position: bottom right;
  background-repeat: no-repeat;
}
```

## Asset Optimization

All brand assets are production-ready but consider:

1. **Convert to WebP** for faster loading (keep PNG as fallback)
2. **Optimize PNGs** with tools like pngquant or ImageOptim
3. **Use appropriate sizes** - don't load full-size icons when thumbnails suffice
4. **Lazy load** graphics that are below the fold

## Guidelines Compliance

All usage must comply with:
- Haltian Brand Guidelines (October 2024)
- Constitution Principle II: Brand Consistency
- Constitution Principle III: Asset Organization

For questions or additional assets, contact: marketing@haltian.com

## References

- Full brand guidelines: `/brand/README.md` (Git submodule)
- Brand repository: `git@gitlab.haltian.com:haltian/etna/haltian-brandbook.git`
- Constitution: `.specify/memory/constitution.md`
