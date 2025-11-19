# Toastmasters Daily Design System

## Home Screen Design

### Colors

#### Text Colors
- **Primary Text**: `Colors.black87` - Main headings and important text
- **Secondary Text**: `Colors.grey[600]` - Subtitles and secondary information
- **Placeholder Text**: `Colors.grey[500]` - Input field hints

#### Background Colors
- **Page Background**: `Colors.white` (default scaffold background)
- **Input Field Background**: `#F2F1F0` - Light beige/grey for input fields

#### Button Colors
- **Primary Button Background**: `Colors.grey[800]` - Dark grey for primary actions
- **Button Text**: `Colors.white` - White text on buttons

### Typography

#### Heading (Main Title)
- **Font Size**: `28px`
- **Font Weight**: `600` (Semi-bold)
- **Color**: `Colors.black87`
- **Text Align**: Center

#### Subtitle
- **Font Size**: `16px`
- **Font Weight**: `400` (Regular)
- **Color**: `Colors.grey[600]`
- **Text Align**: Center

#### Input Text
- **Font Size**: `16px`
- **Font Weight**: `500` (Medium)
- **Letter Spacing**: `8.0`
- **Text Align**: Center

#### Button Text
- **Font Size**: `16px`
- **Font Weight**: `500` (Medium)
- **Color**: `Colors.white`

### Spacing

- **Title to Subtitle**: `8px`
- **Subtitle to Input**: `32px`
- **Input to Button**: `32px`
- **Vertical Alignment Offset**: `-0.15` (slightly above center)

### Components

#### Input Field
- **Width**: `280px`
- **Background**: `#F2F1F0`
- **Border Radius**: `12px`
- **Border**: None (borderless)
- **Padding**: `20px horizontal, 16px vertical`
- **Letter Spacing**: `8.0` for code input
- **Max Length**: `9` (8 digits + 1 space)

#### Primary Button
- **Width**: `140px`
- **Height**: `48px`
- **Background**: `Colors.grey[800]`
- **Border Radius**: `8px`
- **Elevation**: `0` (flat design)
- **Text**: "Join"

### Layout

- **Content Alignment**: Centered vertically with slight upward offset (`-0.15`)
- **Content Width**: Constrained by container (280px for input)
- **Scroll Behavior**: `ClampingScrollPhysics` for smooth scrolling

