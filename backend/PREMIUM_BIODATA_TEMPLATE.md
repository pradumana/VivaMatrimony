# Premium Indian Matrimonial Biodata Template

A sophisticated, wedding-card-inspired biodata template designed for Indian matrimonial profiles. Single A4 page, WeasyPrint-compatible, Jinja2-ready.

## Design Features

### Visual Aesthetic
- **Warm ivory/cream background** with subtle gradients
- **Deep maroon/burgundy** primary accent color
- **Antique gold** decorative elements
- **Soft blush-pink** section backgrounds
- **Elegant serif typography** (Georgia) for headings
- **Refined script/cursive** for decorative text
- **Subtle floral line-art** corner decorations
- **Premium Indian wedding aesthetic**

### Layout Structure
- **Single A4 portrait page** (210mm × 297mm)
- **Header** (18-20%): Brand identity + inspirational quote
- **Two-column main content**: 
  - Left (40%): Photo, Personal Details, Family
  - Right (60%): Introduction, Highlights, Professional Info, Partner Preferences
- **Footer**: Full-width maroon bar with taglines

### Color Palette
```css
--cream: #FBF6ED
--ivory: #FFFDF8
--maroon: #7B1737
--deep-maroon: #64142F
--gold: #B88A52
--light-gold: #D9B982
--blush: #F7E4DF
--text: #292126
--muted: #6E6264
--border: #DFCDBB
```

## Technical Requirements

### Compatibility
- ✅ **WeasyPrint** compatible (no external CSS, no JS)
- ✅ **Jinja2** template variables
- ✅ **Self-contained** (all CSS inline, inline SVG icons)
- ✅ **Print-optimized** (@page rules, page-break controls)
- ✅ **Responsive preview** (centers on screen, full-width on print)

### Typography Stack
```css
/* Headings */
font-family: Georgia, "Times New Roman", serif;

/* Body */
font-family: "Helvetica Neue", Arial, sans-serif;

/* Decorative/Script */
font-family: "Brush Script MT", "Segoe Script", cursive;
```

### No External Dependencies
- ❌ No external CSS files
- ❌ No CSS imports
- ❌ No JavaScript
- ❌ No Bootstrap/Tailwind
- ❌ No Font Awesome
- ✅ Uses inline SVG icons
- ✅ Uses system fonts

## Data Structure

The template expects a Jinja2 `profile` object with the following fields:

### Profile Data Schema

```python
profile = {
    # Basic Information
    "name": str,              # Full name
    "photo_url": str,         # Profile photo URL
    "age": str,               # Age in years
    "date_of_birth": str,     # Date of birth
    "height": str,            # Height (e.g., "5'5\"")
    "weight": str,            # Weight (e.g., "55 kg")
    "blood_group": str,       # Blood group
    "marital_status": str,    # Marital status
    "religion": str,          # Religion
    "caste": str,             # Caste
    "sub_caste": str,         # Sub-caste (optional)
    "gotra": str,             # Gotra (optional)
    "manglik": str,           # Manglik status
    "native_place": str,      # Native place
    "current_city": str,      # Current city
    
    # Education
    "highest_qualification": str,  # Highest degree
    "university": str,             # University/college
    "additional_education": str,   # Additional certifications
    
    # Professional
    "occupation": str,        # Job title/occupation
    "company": str,           # Company name
    "annual_income": str,     # Annual income
    "work_mode": str,         # Work mode (office/remote/hybrid)
    "career_focus": str,      # Career aspirations
    
    # Family
    "father": str,            # Father's name and occupation
    "mother": str,            # Mother's name and occupation
    "siblings": str,          # Sibling information
    "family_type": str,       # Family type (nuclear/joint)
    "family_values": str,     # Family values
    
    # Lifestyle
    "hobbies": str,           # Hobbies and interests
    "diet": str,              # Diet preference
    "smoking": str,           # Smoking status
    "drinking": str,          # Drinking status
    "languages": str,         # Languages known
    
    # Partner Preferences
    "partner_age": str,       # Preferred age range
    "partner_height": str,    # Preferred height
    "partner_education": str, # Preferred education
    "partner_profession": str,# Preferred profession
    "partner_location": str,  # Preferred location
    "partner_values": str,    # Preferred values
    
    # Custom Text
    "photo_quote": str,       # Quote on photo overlay
    "about_partner": str,     # Partner expectations statement
}
```

### Conditional Rendering

All fields are **optional**. If a field is empty/None, the template automatically hides that row:

```jinja2
{% if profile.gotra %}
<div class="info-row">
    <div class="info-label">Gotra</div>
    <div class="info-value">{{ profile.gotra }}</div>
</div>
{% endif %}
```

No blank spaces are left for missing information.

## Usage

### 1. Installation

```bash
pip install jinja2 weasyprint
```

### 2. Python Script

```python
from jinja2 import Environment, FileSystemLoader
from weasyprint import HTML
import os

# Sample profile data
profile_data = {
    "name": "Priya Sharma",
    "photo_url": "https://example.com/photo.jpg",
    "age": "28",
    "height": "5'5\"",
    "religion": "Hindu",
    "occupation": "Software Engineer",
    "current_city": "Bangalore",
    # ... more fields
}

# Setup Jinja2
template_dir = "path/to/templates"
env = Environment(loader=FileSystemLoader(template_dir))
template = env.get_template("biodata_premium_wedding.html")

# Render HTML
html_content = template.render(profile=profile_data)

# Generate PDF
HTML(string=html_content).write_pdf("biodata.pdf")
```

### 3. Quick Test

Run the example script:

```bash
python backend/example_premium_biodata.py
```

This generates:
- `biodata_premium.pdf` — Final PDF output
- `biodata_premium_preview.html` — HTML preview (open in browser)

## Template Sections

### Header
- **Left**: Viva brand logo + "Brings Families Together" tagline + heart icon
- **Right**: Inspirational quote + "Tradition | Values | A Brighter Tomorrow"

### Profile Photo
- **Large portrait** (75mm × 93mm, 4:5 aspect ratio)
- **Rounded corners** with antique-gold border
- **Translucent quote overlay** at bottom with custom text

### Profile Introduction
- **Name** (26pt Georgia serif, maroon)
- **Age | Height | Religion**
- **Occupation | Current City**
- **Decorative divider** with heart

### Highlight Icons (5 circular badges)
1. Well Educated (graduation cap icon)
2. Professionally Stable (briefcase icon)
3. Family Oriented (heart icon)
4. Values & Traditions (clock icon)
5. Open to Relocation (location pin icon)

### Personal Statement
- **Blush-pink rounded box**
- **Italic serif quote** about partner expectations
- **Small heart decoration**

### Information Cards

Each card has:
- Maroon heading with icon
- Thin border, rounded corners
- Two-column grid layout
- Conditional rendering (hides if empty)

**Cards:**
1. **Personal Details**: DOB, age, height, weight, blood group, marital status, religion, caste, sub-caste, gotra, manglik, native place, current city
2. **Family Details**: Father, mother, siblings, family type, family values
3. **Education**: Highest qualification, university, additional education
4. **Professional Details**: Occupation, company, annual income, work mode, career focus
5. **Lifestyle & Interests**: Hobbies, diet, smoking, drinking, languages
6. **Partner Preferences**: Age range, height, education, profession, location, values (prominent blush background)

### Bottom Decoration
- **Script text** (bottom-left): "Rooted in Values ♥ / Growing Together"

### Footer
- **Full-width maroon bar**
- **Left**: "Better Together"
- **Center**: Decorative line with heart
- **Right**: "A Step Towards a Happier Tomorrow"

## Customization

### Change Colors

Modify the `:root` CSS variables:

```css
:root {
  --maroon: #YOUR_COLOR;
  --gold: #YOUR_COLOR;
  --blush: #YOUR_COLOR;
}
```

### Change Brand

Replace "Viva" in the header:

```html
<div class="brand-logo">Your Brand</div>
<div class="brand-tagline">Your Tagline</div>
```

### Add/Remove Sections

Wrap sections in `{% if %}` blocks:

```jinja2
{% if show_section %}
<div class="info-section">
  <!-- Section content -->
</div>
{% endif %}
```

### Change Icons

Replace inline SVG with your own paths from [Material Design Icons](https://materialdesignicons.com/) or similar.

## WeasyPrint Tips

### Font Support
WeasyPrint uses system fonts. Test on target system:
- **Windows**: Georgia, Times New Roman, Arial work well
- **Linux**: Install Microsoft fonts or use Liberation fonts
- **macOS**: System fonts work perfectly

### Image Loading
- Use **absolute URLs** for remote images
- Or use **base64 data URIs** for embedded images
- Or use **local file paths** (WeasyPrint can access local files)

### Page Breaks
Control page breaks with CSS:
```css
page-break-inside: avoid;  /* Keep section together */
page-break-before: always; /* Start new page */
```

### Debugging
Generate HTML first to preview in browser:
```python
with open("preview.html", "w") as f:
    f.write(html_content)
```

## Quality Checklist

✅ **Visual hierarchy** — Name dominates, clear section separation  
✅ **Elegant typography** — Serif headings, clean body text  
✅ **Proper spacing** — Comfortable padding, consistent gaps  
✅ **Print quality** — A4 dimensions, proper margins  
✅ **Readability** — High contrast, legible font sizes  
✅ **Indian wedding aesthetic** — Warm colors, floral decorations  
✅ **Modern premium appearance** — Clean, sophisticated  
✅ **One-page A4 composition** — All content fits naturally  
✅ **WeasyPrint compatibility** — No external dependencies  
✅ **Reusability** — Jinja2 variables, conditional rendering  

## File Structure

```
backend/
├── app/
│   └── utils/
│       └── templates/
│           └── biodata_premium_wedding.html    # Main template
├── example_premium_biodata.py                   # Example script
└── PREMIUM_BIODATA_TEMPLATE.md                  # This file
```

## License

This template is part of the Viva matrimonial platform. Customize freely for your use case.

## Support

For issues or customization requests, refer to the main Viva documentation.
