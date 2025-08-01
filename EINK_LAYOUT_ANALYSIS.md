# eInk Display Layout Analysis

## Layout Structure (Top to Bottom)

Based on analysis of `liturgical_calendar/image_generation/pipeline.py` and `layout_engine.py`:

### 1. **Header Section** (Top)
- **Content**: `SEASON — Date` (e.g., "EASTER — 20 April, 2025")
- **Layout**: Centered horizontally
- **Fonts**: 
  - Season: HankenGrotesk (sans-serif, uppercase, 36px)
  - Dash: HankenGrotesk (sans-serif, 36px) 
  - Date: HappyTimes (serif, 36px)
- **Positioning**: Top padding (48px from top)

### 2. **Artwork Section** (Below Header)
- **Content**: Main liturgical artwork image
- **Layout**: Centered horizontally, square format (1080x1080px)
- **Positioning**: 48px below header baseline
- **Special Case**: If no artwork available, shows "NEXT:" section with thumbnail of next feast

### 3. **Title Section** (Below Artwork)
- **Content**: Feast name or day name (e.g., "Easter" or "Monday")
- **Layout**: Centered horizontally, can wrap to multiple lines
- **Font**: HappyTimes (serif, 96px)
- **Positioning**: 48px below artwork bottom

### 4. **Readings Section** (Bottom)
- **Content**: Week name + reading list
- **Layout**: 
  - Week name: Centered, uppercase (e.g., "EASTER 1")
  - Readings: Left-aligned list
- **Fonts**:
  - Week: HankenGrotesk (sans-serif, uppercase, 36px)
  - Readings: HappyTimes (serif, 36px)
- **Positioning**: 96px below title baseline

## Key Design Principles

### Typography Hierarchy
1. **HappyTimes (serif)** for:
   - Large titles (96px)
   - Body text (36px)
   - Date in header (36px)
   - Reading list (36px)

2. **HankenGrotesk (sans-serif)** for:
   - Headers and labels (36px, uppercase)
   - Season names (36px, uppercase)
   - Week names (36px, uppercase)

### Spacing System
- **48px** between major sections (header→artwork→title→readings)
- **96px** between title and readings section
- **48px** padding from edges

### Layout Philosophy
- **Centered alignment** for headers, artwork, and titles
- **Left alignment** for reading lists
- **Clean, minimal design** with no decorative elements
- **High contrast** with white background and dark text
- **No drop shadows, borders, or background colors** except for the artwork itself

### Color Usage
- **Text**: `#4a4a4a` (dark gray)
- **Lines**: `#979797` (medium gray)
- **Background**: `#ffffff` (white)
- **Season colors**: Only used as small indicators, not background colors

## Web Design Implications

The web version should:
1. **Match the vertical order**: Header → Artwork → Title → Readings
2. **Use the same typography hierarchy** but scale appropriately for web
3. **Maintain the same spacing proportions** (48px → ~24px for web)
4. **Keep the centered/left-aligned layout structure**
5. **Remove decorative elements** (shadows, borders, colored backgrounds)
6. **Use the same color palette** but adapted for web readability 