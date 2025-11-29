# Toastmasters Daily Design System

## Global Color Scheme

### Primary Colors
- **Primary**: `#6366F1` (Indigo) - Main brand color, buttons, accents
- **Primary Dark**: `#8B5CF6` (Purple) - Gradient end, hover states
- **Primary Gradient**: Linear gradient from `#6366F1` to `#8B5CF6`

### Text Colors
- **Primary Text**: `Colors.black87` - Main headings and important text
- **Secondary Text**: `#6B7280` (Gray 500) - Subtitles and secondary information
- **Tertiary Text**: `#4B5563` (Gray 600) - Body text, descriptions
- **Placeholder Text**: `#9CA3AF` (Gray 400) - Input field hints

### Background Colors
- **Page Background**: `Colors.white` (default scaffold background)
- **Card Background**: `Colors.white` - Card and container backgrounds
- **Input Field Background**: `#F2F1F0` - Light beige/grey for input fields
- **Subtle Background**: `#F9FAFB` (Gray 50) - Subtle backgrounds for nested content

### Border Colors
- **Border**: `#E5E7EB` (Gray 200) - Card borders, dividers
- **Border Light**: `#E0E0E0` - Alternative border color

### Shadow
- **Card Shadow**: `Colors.black.withOpacity(0.04)` with blur radius 12, offset (0, 4)
- **Banner Shadow**: Primary color with opacity 0.3, blur radius 20, offset (0, 8)

## Typography

### Heading Styles
- **Large Heading**: `48px`, `FontWeight.w900`, `letterSpacing: -1.5`
- **Section Heading**: `22px`, `FontWeight.w700`, `letterSpacing: -0.5`
- **Subsection Heading**: `18px`, `FontWeight.w600`

### Body Text
- **Body Large**: `15px`, `FontWeight.w400`, `height: 1.6`
- **Body Medium**: `14px`, `FontWeight.w400`
- **Body Small**: `13px`, `FontWeight.w400`

### Button Text
- **Button**: `16px`, `FontWeight.w600`, `Colors.white`

## Spacing

### Component Spacing
- **Section Margin**: `20px` horizontal, `16-24px` vertical
- **Card Padding**: `24-28px` all around
- **Element Spacing**: `12-16px` between related elements
- **Large Spacing**: `40px` for major section breaks

## Components

### Buttons

#### Primary Button
- **Background**: `#6366F1` (Primary color)
- **Text**: White, `16px`, `FontWeight.w600`
- **Padding**: `16px` vertical
- **Border Radius**: `12px`
- **Elevation**: `0` (flat design)
- **Icon**: `20px` size, white color

### Cards

#### Standard Card
- **Background**: `Colors.white`
- **Border**: `1px`, `#E5E7EB`
- **Border Radius**: `12-16px`
- **Padding**: `24-28px`
- **Shadow**: `Colors.black.withOpacity(0.04)`, blur 12, offset (0, 4)

#### Nested Card (Subtle Background)
- **Background**: `#F9FAFB`
- **Border**: `1px`, `#E5E7EB`
- **Border Radius**: `12px`
- **Padding**: `16px`

### Input Fields
- **Width**: `280px` (or full width in containers)
- **Background**: `#F2F1F0`
- **Border Radius**: `12px`
- **Border**: None (borderless)
- **Padding**: `20px horizontal, 16px vertical`
- **Letter Spacing**: `8.0` for code input
- **Max Length**: `9` (8 digits + 1 space)

## Layout

### Max Width Constraints
- **Content Max Width**: `1200px` - All main content areas
- **Centering**: Content centered using `Center` widget or `constraints` with `maxWidth`

### Responsive Grid
- **4 columns**: Width > 1000px
- **3 columns**: Width > 700px
- **2 columns**: Width > 500px
- **1 column**: Width ≤ 500px

## Gradients

### Primary Gradient
- **Colors**: `#6366F1` → `#8B5CF6`
- **Direction**: Top-left to bottom-right
- **Usage**: Banners, icons, buttons

### Video Thumbnail Gradients
- Various color combinations for visual variety
- Used in video placeholder cards

## Icons

### Icon Sizes
- **Small**: `16-20px` - Inline with text
- **Medium**: `24px` - Card headers, buttons
- **Large**: `32px` - Play buttons, major actions

### Icon Colors
- **On Primary**: `Colors.white`
- **On Background**: `Colors.black87` or primary color
- **Secondary**: `#6B7280`
