# Biodata Templates Status — Current Usage

## Currently Active Templates (In Production)

These are the **4 templates actively used** by the Viva app:

### 1. **Traditional** (`biodata_traditional_v2.html`) ✅
- **Status**: ACTIVE
- **Mapped to**: `traditional`
- **Design**: Deep maroon (#8B1A1A) gradient hero, ivory background, Georgia serif
- **Features**: 180×220px photo, 34pt name, editorial layout
- **App Label**: "Traditional — Classic maroon & gold"
- **Icon**: `Icons.auto_awesome_outlined`

### 2. **Modern** (`biodata_modern_v2.html`) ✅
- **Status**: ACTIVE
- **Mapped to**: `modern` + `half_photo` (legacy fallback)
- **Design**: White/charcoal (#2c3e50), blue accent (#3498db), sans-serif
- **Features**: 32pt lightweight name, minimal decoration, rounded pills
- **App Label**: "Modern — Clean minimal design"
- **Icon**: `Icons.view_column_outlined`

### 3. **Floral** (`biodata_floral_v2.html`) ✅
- **Status**: ACTIVE
- **Mapped to**: `floral`
- **Design**: Dusty rose (#a85f6b), muted green (#9ba892), soft gradients
- **Features**: Elegant serif, subtle floral feel, blush backgrounds
- **App Label**: "Floral — Soft pastel colors"
- **Icon**: `Icons.local_florist_outlined`

### 4. **Royal** (`biodata_royal_v2.html`) ✅
- **Status**: ACTIVE
- **Mapped to**: `royal`
- **Design**: Deep wine (#6B1A1A), antique gold (#c8a876), luxury aesthetic
- **Features**: Bold serif, premium feel, warm ivory backgrounds
- **App Label**: "Royal — Premium gold accents"
- **Icon**: `Icons.diamond_outlined`

---

## Template Not In Use (But Available)

### 5. **Premium Wedding** (`biodata_premium_wedding.html`) ⚠️
- **Status**: NOT MAPPED (not accessible from app)
- **Design**: Wedding-card-inspired, warm ivory/cream, deep maroon, floral decorations
- **Features**: Two-column layout, 5 circular badges, blush statement box
- **Special**: Uses different data structure (`profile` object instead of flat context)

**To activate**, add to `biodata_service.py`:
```python
_template_files = {
    "traditional": "biodata_traditional_v2.html",
    "modern": "biodata_modern_v2.html",
    "floral": "biodata_floral_v2.html",
    "royal": "biodata_royal_v2.html",
    "premium": "biodata_premium_wedding.html",  # ← ADD THIS
}
```

**And add to Flutter app** (`biodata_screen.dart`):
```dart
_TemplateCard(
  id: 'premium',
  label: 'Premium',
  description: 'Wedding card style',
  icon: Icons.auto_awesome_mosaic_outlined,
  selected: _template == 'premium',
  onTap: () => setState(() => _template = 'premium'),
),
```

---

## Legacy/Unused Templates (Can Delete)

These are **old templates NO LONGER IN USE**:

### ❌ `biodata.html` (Original template)
- **Status**: UNUSED
- **Reason**: Replaced by v2 templates
- **Can delete**: Yes

### ❌ `biodata_floral.html` (Old floral)
- **Status**: UNUSED
- **Reason**: Replaced by `biodata_floral_v2.html`
- **Can delete**: Yes

### ❌ `biodata_half_photo.html` (Old modern)
- **Status**: LEGACY FALLBACK
- **Reason**: Now redirects to `biodata_modern_v2.html`
- **Can delete**: Yes (after migration)

### ❌ `_colors.css` and `_design_system.css`
- **Status**: NOT USED
- **Reason**: WeasyPrint doesn't support CSS imports, all CSS is inline in templates
- **Can delete**: Yes (documentation only)

---

## Template Mapping (Backend)

From `biodata_service.py` line 183:

```python
_template_files = {
    "traditional": "biodata_traditional_v2.html",  # ← Used
    "modern": "biodata_modern_v2.html",            # ← Used
    "floral": "biodata_floral_v2.html",            # ← Used
    "royal": "biodata_royal_v2.html",              # ← Used
    "half_photo": "biodata_modern_v2.html",        # ← Legacy fallback
}
```

Default fallback: `biodata_traditional_v2.html`

---

## Flutter App Template Selection

From `biodata_screen.dart` line 35:

```dart
String _template = 'traditional';  // Default
```

User sees 4 template cards in a 2×2 grid:

```
┌─────────────────┬─────────────────┐
│   Traditional   │     Modern      │
│  Classic maroon │  Clean minimal  │
│   & gold        │     design      │
└─────────────────┴─────────────────┘
┌─────────────────┬─────────────────┐
│     Floral      │      Royal      │
│  Soft pastel    │  Premium gold   │
│    colors       │    accents      │
└─────────────────┴─────────────────┘
```

When user selects a template:
1. Flutter calls `POST /biodata/generate` with `{template: 'modern'}`
2. Backend maps to `biodata_modern_v2.html`
3. WeasyPrint renders PDF
4. User clicks "Download" → `GET /biodata/pdf?template=modern`

---

## Data Flow

### Current V2 Templates (Traditional/Modern/Floral/Royal)

**Input**: Flat context dictionary
```python
context = {
    "full_name": "Priya Sharma",
    "age": 28,
    "height": "5'5\"",
    "religion": "Hindu",
    "education": {"degree": "MCA", "college_university": "Delhi University"},
    "employment": {"job_title": "Software Engineer", "company": "TechM"},
    # ... more flat fields
}
```

**Template usage**:
```jinja2
{{ full_name }}
{{ age }}
{% if education %}{{ education.degree }}{% endif %}
```

### Premium Wedding Template

**Input**: Nested `profile` object
```python
context = {
    "profile": {
        "name": "Priya Sharma",
        "age": "28",
        "height": "5'5\"",
        "highest_qualification": "MCA",
        "university": "Delhi University",
        "occupation": "Software Engineer",
        # ... all fields in profile object
    }
}
```

**Template usage**:
```jinja2
{{ profile.name }}
{{ profile.age }}
{{ profile.highest_qualification }}
```

---

## Summary

### ✅ Currently Active (Production)
1. `biodata_traditional_v2.html` — Traditional
2. `biodata_modern_v2.html` — Modern
3. `biodata_floral_v2.html` — Floral
4. `biodata_royal_v2.html` — Royal

### ⚠️ Available But Not Mapped
5. `biodata_premium_wedding.html` — Premium Wedding (needs integration)

### ❌ Legacy/Unused (Can Delete)
- `biodata.html` (original)
- `biodata_floral.html` (old floral)
- `biodata_half_photo.html` (old modern)
- `_colors.css` (not imported by templates)
- `_design_system.css` (not imported by templates)

---

## Recommendation

**Option 1: Keep 4 current templates** (no changes needed)
- Traditional, Modern, Floral, Royal are working well
- Already tested and deployed
- User has 4 distinct choices

**Option 2: Add Premium Wedding as 5th option**
- Requires backend + Flutter integration
- Different data structure (needs adapter)
- Truly distinct wedding-card aesthetic
- Could be positioned as "premium paid template"

**Option 3: Replace one existing template with Premium Wedding**
- If you want to keep 4 templates but swap one
- Example: Replace Floral with Premium Wedding
- Requires re-mapping in backend

**Clean up:**
- Delete unused legacy templates
- Remove `_colors.css` and `_design_system.css` (or move to docs folder)

---

## File Locations

```
backend/app/utils/templates/
├── biodata_traditional_v2.html    ← ACTIVE
├── biodata_modern_v2.html         ← ACTIVE
├── biodata_floral_v2.html         ← ACTIVE
├── biodata_royal_v2.html          ← ACTIVE
├── biodata_premium_wedding.html   ← NOT MAPPED
├── biodata.html                   ← DELETE
├── biodata_floral.html            ← DELETE
├── biodata_half_photo.html        ← DELETE
├── _colors.css                    ← DELETE or MOVE TO DOCS
└── _design_system.css             ← DELETE or MOVE TO DOCS
```

Backend mapping: `backend/app/services/biodata_service.py` line 183  
Flutter UI: `viva_app/lib/features/biodata/presentation/screens/biodata_screen.dart` line 35
