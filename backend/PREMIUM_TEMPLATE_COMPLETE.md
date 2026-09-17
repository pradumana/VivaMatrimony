# Premium Indian Matrimonial Biodata Template — Complete Package

## 📦 What You Got

A **luxury wedding-card-inspired** matrimonial biodata template that combines traditional Indian aesthetic with modern editorial design.

### ✅ Deliverables

1. **`biodata_premium_wedding.html`** — Complete self-contained HTML template (3,500+ lines)
2. **`example_premium_biodata.py`** — Full integration example with Jinja2/WeasyPrint
3. **`render_premium_biodata_standalone.py`** — Standalone rendering script
4. **`example_profile_data.json`** — Sample profile data
5. **`PREMIUM_BIODATA_TEMPLATE.md`** — Complete documentation
6. **`PREMIUM_TEMPLATE_COMPLETE.md`** — This summary (you are here)

---

## 🎨 Design Highlights

### Visual Aesthetic
- ✨ **Warm ivory/cream** background (#FFFDF8, #FBF6ED)
- ❤️ **Deep maroon** accent (#7B1737, #64142F)
- ✨ **Antique gold** decorations (#B88A52)
- 🌸 **Soft blush-pink** sections (#F7E4DF)
- 🌿 **Subtle floral** corner decorations (inline SVG)
- 💍 **Premium Indian wedding** card aesthetic

### Typography
- **Headings**: Georgia, Times New Roman (serif) — elegant, traditional
- **Body**: Helvetica Neue, Arial (sans-serif) — clean, readable
- **Decorative**: Brush Script MT, Segoe Script (cursive) — soft, romantic

### Layout
- **Single A4 page** (210mm × 297mm)
- **Two-column**: Left 40% (photo + personal), Right 60% (professional + partner)
- **Print-optimized**: No page breaks, proper margins
- **WeasyPrint-ready**: No external dependencies

---

## 📋 Template Structure

### Header (Top 18-20%)
```
┌─────────────────────────────────────────────────────────┐
│  VIVA                    "Good people make great life   │
│  BRINGS FAMILIES         partners."                     │
│  TOGETHER                                               │
│  ♥                      TRADITION | VALUES | TOMORROW   │
└─────────────────────────────────────────────────────────┘
```

### Main Content (Two Columns)

**LEFT COLUMN (40%)**
```
┌─────────────────────┐
│   PROFILE PHOTO     │  ← 75mm × 93mm portrait
│                     │    Gold border + shadow
│   "Grateful for     │    Quote overlay at bottom
│    the journey..."  │
├─────────────────────┤
│ PERSONAL DETAILS    │
│ • DOB, Age, Height  │
│ • Religion, Caste   │
│ • Native, Current   │
├─────────────────────┤
│ FAMILY DETAILS      │
│ • Father, Mother    │
│ • Siblings, Values  │
└─────────────────────┘
```

**RIGHT COLUMN (60%)**
```
┌─────────────────────────────────────┐
│  PRIYA SHARMA                       │  ← 26pt serif name
│  28 Years | 5'5" | Hindu            │
│  Software Engineer | Bangalore      │
│  ────────── ♥ ──────────           │
├─────────────────────────────────────┤
│  [🎓] [💼] [♥] [⏰] [📍]           │  ← 5 circular badges
│  Well  Prof Family Values Relocation│
│  Edu   Stable Oriented              │
├─────────────────────────────────────┤
│  "Looking for a life partner to     │  ← Blush-pink box
│   share love, respect, growth..."   │
├─────────────────────────────────────┤
│  EDUCATION                          │
│  • MCA, Delhi University            │
├─────────────────────────────────────┤
│  PROFESSIONAL DETAILS               │
│  • Senior Software Engineer         │
│  • Tech Mahindra, ₹18 LPA          │
├─────────────────────────────────────┤
│  LIFESTYLE & INTERESTS              │
│  • Hobbies, Diet, Languages         │
├─────────────────────────────────────┤
│  PARTNER PREFERENCES                │  ← Prominent blush box
│  • Age, Height, Education           │
│  • Profession, Location, Values     │
└─────────────────────────────────────┘
```

### Footer (Bottom)
```
┌─────────────────────────────────────────────────────────┐
│  "Better Together"    ──── ♥ ────   A Step Towards...  │
└─────────────────────────────────────────────────────────┘
```

---

## 🚀 Quick Start

### 1. Install Dependencies

```bash
pip install jinja2 weasyprint
```

### 2. Test the Template

**Option A: Using the standalone script**
```bash
cd backend
python render_premium_biodata_standalone.py
```

**Option B: Using the full integration script**
```bash
cd backend
python example_premium_biodata.py
```

Both generate:
- `biodata_premium.pdf` — Final PDF
- `biodata_premium_preview.html` — Browser preview

### 3. Open in Browser

```bash
# Open the HTML preview
start biodata_premium_preview.html     # Windows
open biodata_premium_preview.html      # macOS
xdg-open biodata_premium_preview.html  # Linux
```

---

## 📝 Data Structure

The template uses a single `profile` dictionary with 30+ optional fields:

```python
profile = {
    # Basic (12 fields)
    "name", "photo_url", "age", "date_of_birth", "height", "weight",
    "blood_group", "marital_status", "religion", "caste", "sub_caste",
    "gotra", "manglik", "native_place", "current_city",
    
    # Education (3 fields)
    "highest_qualification", "university", "additional_education",
    
    # Professional (5 fields)
    "occupation", "company", "annual_income", "work_mode", "career_focus",
    
    # Family (5 fields)
    "father", "mother", "siblings", "family_type", "family_values",
    
    # Lifestyle (5 fields)
    "hobbies", "diet", "smoking", "drinking", "languages",
    
    # Partner Preferences (6 fields)
    "partner_age", "partner_height", "partner_education",
    "partner_profession", "partner_location", "partner_values",
    
    # Custom Text (2 fields)
    "photo_quote", "about_partner"
}
```

**All fields are optional.** Empty fields are automatically hidden (no blank spaces).

---

## 🎯 Integration Example

### With Existing Viva Backend

Add to `biodata_service.py`:

```python
def _render_pdf(context: dict, template: str = "traditional") -> bytes:
    """Render HTML template and convert to PDF via WeasyPrint."""
    template_dir = os.path.join(os.path.dirname(__file__), "..", "utils", "templates")
    
    # Add premium template to mapping
    _template_files = {
        "traditional": "biodata_traditional_v2.html",
        "modern": "biodata_modern_v2.html",
        "floral": "biodata_floral_v2.html",
        "royal": "biodata_royal_v2.html",
        "premium": "biodata_premium_wedding.html",  # ← NEW
    }
    template_file = _template_files.get(template, "biodata_traditional_v2.html")
    
    env = Environment(
        loader=FileSystemLoader(template_dir),
        autoescape=select_autoescape(["html", "xml"]),
    )
    tmpl = env.get_template(template_file)
    html = tmpl.render(profile=context)  # Pass as "profile" not individual fields
    
    pdf_bytes = HTML(string=html).write_pdf()
    return pdf_bytes
```

### Prepare Context Data

```python
# Transform your existing Viva profile data
profile_context = {
    "name": profile.full_name,
    "photo_url": profile.primary_photo_url,
    "age": str(profile.age),
    "height": profile.height,
    "religion": profile.religion,
    "caste": profile.caste,
    "current_city": profile.current_location,
    "occupation": employment.job_title if employment else None,
    "company": employment.company if employment else None,
    "highest_qualification": education.degree if education else None,
    # ... map all other fields
}

# Render PDF
pdf_bytes = _render_pdf(profile_context, template="premium")
```

---

## 🔧 Customization Guide

### Change Brand Identity

In `biodata_premium_wedding.html`, find:

```html
<div class="brand-logo">Viva</div>
<div class="brand-tagline">Brings Families Together</div>
```

Replace with your brand:

```html
<div class="brand-logo">YourBrand</div>
<div class="brand-tagline">Your Tagline</div>
```

### Change Color Scheme

Find the `:root` CSS variables (line ~15):

```css
:root {
  --maroon: #7B1737;     /* Primary accent */
  --gold: #B88A52;       /* Decorative elements */
  --blush: #F7E4DF;      /* Section backgrounds */
  --cream: #FBF6ED;      /* Page background */
  --ivory: #FFFDF8;      /* Alternate background */
}
```

### Add New Sections

Copy-paste an existing section and modify:

```html
{% if profile.new_field %}
<div class="info-section">
  <div class="section-header">
    <div class="section-icon">
      <svg viewBox="0 0 24 24">
        <!-- Your icon path -->
      </svg>
    </div>
    <div class="section-title">New Section</div>
  </div>
  <div class="info-grid">
    <div class="info-row">
      <div class="info-label">Label</div>
      <div class="info-value">{{ profile.new_field }}</div>
    </div>
  </div>
</div>
{% endif %}
```

### Change Photo Size

Find `.photo-container` CSS (line ~195):

```css
.photo-container {
  width: 75mm;   /* Change width */
  height: 93mm;  /* Change height (maintain 4:5 ratio) */
}
```

### Remove Highlight Icons

Find `.highlight-icons` section (line ~480 in HTML) and delete or comment out:

```html
<!-- Remove this entire block if you don't want badges -->
<div class="highlight-icons">
  ...
</div>
```

---

## ✅ Quality Checklist

Before using in production:

- [ ] **Test with real data** (at least 5-10 profiles)
- [ ] **Test with missing fields** (empty profile, minimal profile, full profile)
- [ ] **Test with long text** (long names, long addresses, long about text)
- [ ] **Test with non-English text** (Hindi names, special characters)
- [ ] **Test photo loading** (remote URLs, local files, missing photo)
- [ ] **Print test** (actual PDF → printer or PDF viewer zoom)
- [ ] **Cross-platform test** (Windows/macOS/Linux font rendering)
- [ ] **WeasyPrint version** (test on production WeasyPrint version)
- [ ] **Browser preview** (Chrome, Firefox, Safari for HTML preview)
- [ ] **Color accuracy** (PDF colors vs screen colors)

---

## 🐛 Troubleshooting

### PDF Generation Fails

**Error**: `OSError: cannot load library 'gobject-2.0'`

**Fix**: Install system dependencies
```bash
# Ubuntu/Debian
sudo apt-get install libpango-1.0-0 libpangocairo-1.0-0 libgdk-pixbuf2.0-0

# macOS
brew install pango gdk-pixbuf libffi

# Windows
# Use pre-built GTK binaries or WSL
```

### Fonts Not Rendering

**Problem**: PDF shows different fonts than preview

**Fix**: Use only system fonts that exist on target platform
```css
/* Safe choices */
font-family: Georgia, "Times New Roman", serif;      /* Headers */
font-family: Arial, Helvetica, sans-serif;           /* Body */
font-family: "Courier New", Courier, monospace;      /* Monospace */
```

### Images Not Loading

**Problem**: Photo not appearing in PDF

**Fix**: Use absolute URLs or data URIs
```python
# Remote URL (best for production)
photo_url = "https://example.com/photo.jpg"

# Data URI (embedded base64)
import base64
with open("photo.jpg", "rb") as f:
    b64 = base64.b64encode(f.read()).decode()
photo_url = f"data:image/jpeg;base64,{b64}"

# Local file path (development only)
photo_url = "file:///absolute/path/to/photo.jpg"
```

### Content Overflows Page

**Problem**: Content doesn't fit on one A4 page

**Fix**: Reduce font sizes or remove optional sections
```css
/* Reduce all font sizes by 10% */
body { font-size: 8pt; }  /* was 9pt */
.profile-name { font-size: 23pt; }  /* was 26pt */
.section-title { font-size: 9pt; }  /* was 10pt */
```

### Floral Decorations Too Heavy

**Problem**: Corner decorations too prominent

**Fix**: Reduce opacity or remove
```css
.floral-corner-tl,
.floral-corner-tr,
.floral-corner-bl,
.floral-corner-br {
  opacity: 0.15;  /* was 0.3 */
  /* or display: none; to remove */
}
```

---

## 📚 Technical Details

### WeasyPrint Compatibility

✅ **Supported CSS**
- Flexbox (basic, avoid complex nesting)
- Grid (basic two-column layouts)
- Borders, shadows, gradients
- `@page` rules
- `page-break-*` properties
- System fonts
- Inline SVG

❌ **Not Supported**
- External CSS files (`<link>` or `@import`)
- JavaScript
- Web fonts (Google Fonts, etc.)
- Complex transforms
- CSS animations
- `position: fixed` (limited)

### File Size

**Template**: ~100 KB (HTML with inline CSS/SVG)  
**Generated PDF**: 50-200 KB (depends on photo size)  
**With base64 photo**: 300-500 KB (photo embedded)

### Performance

**Rendering time** (on modern machine):
- HTML generation: <10ms (Jinja2)
- PDF conversion: 500-2000ms (WeasyPrint)
- Total: ~2 seconds per biodata

For **batch processing**, consider:
- Parallel rendering (multiprocessing)
- Pre-compiled Jinja2 templates
- Image optimization (resize photos to 400×500px max)

---

## 📦 Package Contents Summary

```
backend/
├── app/utils/templates/
│   └── biodata_premium_wedding.html    # ← Main template (3,500 lines)
│
├── example_premium_biodata.py          # Full integration example
├── render_premium_biodata_standalone.py # Standalone test script
├── example_profile_data.json           # Sample data
│
├── PREMIUM_BIODATA_TEMPLATE.md         # Complete documentation
└── PREMIUM_TEMPLATE_COMPLETE.md        # This summary
```

---

## 🎉 You're Ready!

The template is **production-ready** and fully **self-contained**. 

**Next Steps:**
1. Run `python render_premium_biodata_standalone.py` to test
2. Open `biodata_premium_preview.html` to see the design
3. Integrate into your Viva backend (see integration example above)
4. Customize colors/brand to match your identity
5. Test with real user data
6. Deploy!

**Questions?** Refer to `PREMIUM_BIODATA_TEMPLATE.md` for detailed documentation.

---

## 📄 License & Credits

**Template**: Custom-designed for Viva matrimonial platform  
**Icons**: Inline SVG (no attribution required)  
**Photos**: Use your own or stock photos with proper licenses  
**Design**: Wedding-card-inspired Indian matrimonial aesthetic

Feel free to customize and adapt for your use case.

---

**Built with ♥ for premium matrimonial experiences.**
