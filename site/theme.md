# Toastmasters Daily Design System

## Global Color Scheme

### Primary Colors
- **Primary**: `#6366F1` (Indigo) - Main brand color, buttons, accents
- **Primary Dark**: `#8B5CF6` (Purple) - Gradient end, hover states
- **Primary Gradient**: Linear gradient from `#6366F1` to `#8B5CF6`
- **Dark Gradient**: Linear gradient from `#1E1B4B` (Dark indigo) to `#312E81` (Darker purple) - Used in footer and challenge banners

### Text Colors
- **Primary Text**: `#212121` (Black87) - Main headings and important text
- **Secondary Text**: `#6B7280` (Gray 500) - Subtitles and secondary information
- **Tertiary Text**: `#4B5563` (Gray 600) - Body text, descriptions
- **Placeholder Text**: `#9CA3AF` (Gray 400) - Input field hints
- **White Text**: `Colors.white` - Text on dark/gradient backgrounds

### Background Colors
- **Page Background**: `Colors.white` (default scaffold background)
- **Card Background**: `Colors.white` - Card and container backgrounds
- **Input Field Background**: `#F2F1F0` - Light beige/grey for input fields
- **Subtle Background**: `#F9FAFB` (Gray 50) - Subtle backgrounds for nested content
- **Glassmorphism Background**: `Colors.white.withOpacity(0.15)` - Semi-transparent overlays on images

### Border Colors
- **Border**: `#E5E7EB` (Gray 200) - Card borders, dividers
- **Border Light**: `#E0E0E0` - Alternative border color
- **Glassmorphism Border**: `Colors.white.withOpacity(0.2)` - Borders on glassmorphism elements

### Shadow
- **Card Shadow**: `Colors.black.withOpacity(0.1)` with blur radius 12, offset (0, 4)
- **Banner Shadow**: Primary color with opacity 0.3, blur radius 20, offset (0, 8)
- **Button Hover Shadow**: Primary color with opacity 0.3, blur radius 8, offset (0, 4)

## Typography

### Heading Styles
- **Hero Heading**: `48px`, `FontWeight.w900`, `letterSpacing: -1.5`, `height: 1.1` - Large banner headings (white text)
- **Large Heading**: `36px`, `FontWeight.w900`, `letterSpacing: -1.0`, `height: 1.1` - Section titles (white text)
- **Section Heading**: `20px`, `FontWeight.w700`, `color: #212121` - Section titles
- **Subsection Heading**: `18px`, `FontWeight.w600`
- **Card Title**: `16px`, `FontWeight.w600`, `color: #212121` - Action tile titles
- **Label Text**: `14px`, `FontWeight.w600`, `color: white.withOpacity(0.8)`, `letterSpacing: 0.5` - Labels on cards

### Body Text
- **Body Large**: `16px`, `FontWeight.w400`, `height: 1.6`, `letterSpacing: 0.2` - Descriptions and call-to-action text
- **Body Medium**: `15px`, `FontWeight.w500` or `w600` - Button text, navigation
- **Body Small**: `14px`, `FontWeight.w400`, `color: #6B7280` - Tile descriptions
- **Body Small**: `13px`, `FontWeight.w400`

### Button Text
- **Primary Button**: `16px`, `FontWeight.w600`, `Colors.white`
- **Header Button**: `15px`, `FontWeight.w500` or `w600`, `letterSpacing: 0.2`

## Spacing

### Component Spacing
- **Section Margin**: `20px` horizontal, `16-24px` vertical
- **Card Padding**: `24-28px` all around
- **Element Spacing**: `12-16px` between related elements
- **Large Spacing**: `40px` for major section breaks
- **Banner Padding**: `40px` horizontal, `64px` vertical
- **Header Padding**: `20px` horizontal, `20px` vertical
- **Tile Spacing**: `16px` between tiles horizontally, `12px` between image and text

### Internal Spacing
- **Text Line Spacing**: `4px` between related text lines
- **Content Padding**: `40px` horizontal for banner content
- **Card Internal**: `20px` padding for glassmorphism cards

## Components

### Header

#### Header Container
- **Background**: `Colors.white`
- **Padding**: `20px` horizontal, `20px` vertical
- **Max Width**: `1200px`
- **Layout**: Row with space-between alignment

#### Header Buttons
- **Secondary Button** (Home, Club Login):
  - Text: `15px`, `FontWeight.w500`, `color: #1E1B4B`
  - Hover: `color: #6366F1`
  - Padding: `16px` horizontal, `10px` vertical
  - Hover Background: `Colors.grey.withOpacity(0.1)`
  - Border Radius: `8px`
  - Transition: `200ms` ease-in-out

- **Primary Button** (User Login):
  - Background: Gradient from `#6366F1` to `#8B5CF6` (opacity 0.9)
  - Hover: Full opacity gradient with shadow
  - Text: `15px`, `FontWeight.w600`, `Colors.white`, `letterSpacing: 0.2`
  - Padding: `24px` horizontal, `10px` vertical
  - Border Radius: `8px`
  - Shadow on Hover: Primary color with opacity 0.3, blur 8, offset (0, 4)
  - Transition: `200ms` ease-in-out

### Banners

#### Hero Banner (Home Banner)
- **Background**: Gradient from `#6366F1` to `#8B5CF6`
- **Border Radius**: `16px`
- **Padding**: `40px` horizontal, `64px` vertical
- **Shadow**: Primary color with opacity 0.3, blur 20, offset (0, 8)
- **Max Width**: `1200px`
- **Margin**: `20px` horizontal, `24px` bottom

#### Challenge Banner (Daily Challenge)
- **Background**: Image with gradient overlay
- **Gradient Overlay**: `#1E1B4B` to `#312E81` (opacity 0.85)
- **Border Radius**: `16px`
- **Padding**: `40px` horizontal, `48px` vertical
- **Shadow**: Dark indigo with opacity 0.3, blur 20, offset (0, 8)
- **Max Width**: `1200px`
- **Margin**: `20px` horizontal, `24px` bottom

### Buttons

#### Primary Button (Gradient)
- **Background**: Gradient from `#6366F1` to `#8B5CF6`
- **Text**: White, `16px`, `FontWeight.w600`
- **Padding**: `24px` horizontal, `16px` vertical
- **Border Radius**: `12px`
- **Elevation**: `0` (flat design)
- **Icon**: `20px` size, white color
- **Hover**: Enhanced shadow and full opacity

#### Secondary Button (White)
- **Background**: `Colors.white`
- **Text**: Primary color (`#6366F1`), `16px`, `FontWeight.w600`
- **Padding**: `24px` horizontal, `16px` vertical
- **Border Radius**: `12px`
- **Elevation**: `0`
- **Icon**: `20px` size, primary color

#### Text Button (Header Style)
- **Background**: Transparent
- **Text**: `15px`, `FontWeight.w500` or `w600`
- **Padding**: `16px` horizontal, `10px` vertical
- **Hover**: Background color change or text color change
- **Border Radius**: `8px`

### Cards

#### Standard Card
- **Background**: `Colors.white`
- **Border**: `1px`, `#E5E7EB`
- **Border Radius**: `12-16px`
- **Padding**: `24-28px`
- **Shadow**: `Colors.black.withOpacity(0.1)`, blur 12, offset (0, 4)

#### Glassmorphism Card (Challenge Topic)
- **Background**: `Colors.white.withOpacity(0.15)`
- **Border**: `1px`, `Colors.white.withOpacity(0.2)`
- **Border Radius**: `12px`
- **Padding**: `20px`
- **Text**: White with varying opacity

#### Action Tile Card
- **Image**: Square aspect ratio, `320px` max width
- **Border Radius**: `16px`
- **Shadow**: `Colors.black.withOpacity(0.1)`, blur 12, offset (0, 4)
- **Title**: `16px`, `FontWeight.w600`, `color: #212121`
- **Description**: `14px`, `FontWeight.w400`, `color: #6B7280`
- **Spacing**: `12px` between image and title, `4px` between title and description

### Input Fields
- **Width**: `280px` (or full width in containers)
- **Background**: `#F2F1F0`
- **Border Radius**: `12px`
- **Border**: None (borderless)
- **Padding**: `20px` horizontal, `16px` vertical
- **Letter Spacing**: `8.0` for code input
- **Max Length**: `9` (8 digits + 1 space)

### Loading States

#### Shimmer Effect
- **Base Color**: `Colors.grey.shade300`
- **Shimmer Color**: `Colors.white.withOpacity(0.2)`
- **Shimmer Width**: `40%` of container width
- **Animation**: Continuous loop
- **Border Radius**: `16px` (matches card)

#### Loading Indicator
- **Size**: `16px` width and height
- **Stroke Width**: `2px`
- **Color**: `Colors.white` (on dark backgrounds)
- **Padding**: `20px` container padding

## Layout

### Max Width Constraints
- **Content Max Width**: `1200px` - All main content areas (header, banners, tiles, footer)
- **Centering**: Content centered using `Center` widget or `constraints` with `maxWidth`
- **Horizontal Margin**: `20px` from screen edges

### Responsive Grid
- **4 columns**: Width > 1000px
- **3 columns**: Width > 700px
- **2 columns**: Width > 500px
- **1 column**: Width ≤ 500px

### Horizontal Scrolling
- **Action Tiles**: Horizontal `ListView` with `16px` spacing between tiles
- **Tile Width**: Max `320px`, square aspect ratio
- **Scroll Direction**: `Axis.horizontal`

## Gradients

### Primary Gradient
- **Colors**: `#6366F1` → `#8B5CF6`
- **Direction**: Top-left to bottom-right (`Alignment.topLeft` to `Alignment.bottomRight`)
- **Usage**: Hero banners, primary buttons, hover states

### Dark Gradient
- **Colors**: `#1E1B4B` → `#312E81`
- **Direction**: Top-left to bottom-right
- **Usage**: Footer, challenge banners, overlay gradients

### Shimmer Gradient
- **Colors**: `transparent` → `white.withOpacity(0.2)` → `transparent`
- **Direction**: Left to right
- **Stops**: `[0.0, 0.5, 1.0]`
- **Usage**: Loading states

## Icons

### Icon Sizes
- **Small**: `16-20px` - Inline with text, buttons
- **Medium**: `24px` - Card headers, buttons
- **Large**: `32px` - Play buttons, major actions

### Icon Colors
- **On Primary**: `Colors.white`
- **On Background**: `Colors.black87` or primary color
- **Secondary**: `#6B7280`

## Shadows

### Card Shadow
- **Color**: `Colors.black.withOpacity(0.1)`
- **Blur Radius**: `12px`
- **Offset**: `(0, 4)`

### Banner Shadow
- **Color**: Primary color with opacity `0.3`
- **Blur Radius**: `20px`
- **Offset**: `(0, 8)`

### Button Hover Shadow
- **Color**: Primary color with opacity `0.3`
- **Blur Radius**: `8px`
- **Offset**: `(0, 4)`

## Animations & Transitions

### Hover Transitions
- **Duration**: `200ms`
- **Curve**: `Curves.easeInOut`
- **Properties**: Color, opacity, shadow, transform

### Shimmer Animation
- **Duration**: `1500ms` (continuous loop)
- **Direction**: Left to right
- **Easing**: Linear

## Component Patterns

### Section Title Pattern
```dart
Text(
  'Section Title',
  style: TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: Color(0xFF212121),
  ),
)
```

### Hero Text Pattern
```dart
Text(
  'Hero Text',
  style: TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w900,
    color: Colors.white,
    letterSpacing: -1.5,
    height: 1.1,
  ),
)
```

### Glassmorphism Card Pattern
```dart
Container(
  padding: EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.15),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: Colors.white.withOpacity(0.2),
      width: 1,
    ),
  ),
  child: // Content
)
```

### Action Tile Pattern
- Square image card (`320px` max width)
- `16px` border radius
- Shadow: `Colors.black.withOpacity(0.1)`, blur 12, offset (0, 4)
- Title below: `16px`, `FontWeight.w600`, `#212121`
- Description below: `14px`, `FontWeight.w400`, `#6B7280`
- `12px` spacing between image and title
- `4px` spacing between title and description

### Banner Pattern
- Gradient background (primary or dark)
- `16px` border radius
- Shadow with primary/dark color, opacity 0.3, blur 20, offset (0, 8)
- `40px` horizontal padding
- `64px` vertical padding (hero) or `48px` (challenge)
- White text with large, bold typography
