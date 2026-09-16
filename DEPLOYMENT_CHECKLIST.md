# VIVA BIODATA 2.0 — DEPLOYMENT CHECKLIST

**Date:** January 2025  
**Version:** 2.0  
**Status:** Pre-Production Testing

---

## PRE-DEPLOYMENT CHECKLIST

### ✅ CODE FIXES COMPLETED

- [x] **Unicode Icon Fix** — All templates updated with CSS decorations
- [x] **Privacy Filter Fix** — `show_parents_info` enforcement added
- [x] **Image Optimization** — `_optimize_image_for_pdf()` function created
- [x] **Test Suite** — Comprehensive normalization tests added
- [x] **Error Handling** — Graceful fallbacks for image optimization failures
- [x] **Logging** — Structured logging for debugging
- [x] **Constants** — Image dimensions and quality centralized

### 🔄 TESTING REQUIRED (CRITICAL)

#### Backend Tests
- [ ] **Run biodata normalization tests**
  ```bash
  cd backend
  python -m pytest tests/unit/test_biodata_normalization.py -v
  ```
  
- [ ] **Run security tests**
  ```bash
  python -m pytest tests/security/test_security.py::test_biodata_pdf_requires_auth -v
  ```
  
- [ ] **Run all tests**
  ```bash
  python -m pytest tests/ -v --tb=short
  ```
  
- [ ] **Verify 100% test pass rate**

#### Visual Verification (MANDATORY)

**Generate test PDFs for each template:**

1. **Traditional Template** (`template_id='traditional'`)
   - [ ] Complete profile (all fields populated)
   - [ ] Minimal profile (sparse data)
   - [ ] No photos
   - [ ] 5 photos
   - [ ] Long About text (1000+ chars)
   - [ ] Privacy filters enabled (`show_parents_info=False`)
   
2. **Modern Template** (`template_id='modern'`)
   - [ ] Complete profile
   - [ ] Minimal profile
   - [ ] Multiple photos
   
3. **Floral Template** (`template_id='floral'`)
   - [ ] Complete profile
   - [ ] Minimal profile
   - [ ] Multiple photos
   
4. **Royal Template** (`template_id='royal'`)
   - [ ] Complete profile
   - [ ] Minimal profile
   - [ ] Multiple photos

**Visual Inspection Criteria:**

For EACH generated PDF, verify:

- [ ] No broken Unicode boxes (✓ should see CSS shapes instead)
- [ ] Page 1 hero section looks professional
- [ ] Photo is cleanly cropped (no phone UI/status bar)
- [ ] Long names wrap correctly (not truncated)
- [ ] Long text wraps (no overflow)
- [ ] Missing fields disappear cleanly (no "null" or blank rows)
- [ ] Privacy filter works (parent info hidden when `show_parents_info=False`)
- [ ] Hobbies wrap without overflow
- [ ] Page breaks don't orphan headings
- [ ] Margins are safe (content not clipped)
- [ ] Colors print well on A4 paper
- [ ] File size <2 MB (typical profile)
- [ ] File size <5 MB (5 photos + long text)

**Physical Print Test:**

- [ ] Print Traditional template on A4 paper
- [ ] Print Modern template on A4 paper
- [ ] Verify colors look professional (not washed out)
- [ ] Verify text is readable (not too small)
- [ ] Verify margins are appropriate

**WhatsApp Sharing Test:**

- [ ] Share PDF via WhatsApp
- [ ] Verify page 1 preview looks good
- [ ] Verify file sends successfully (not rejected for size)
- [ ] Verify recipient can open and view PDF

#### Flutter App Testing

- [ ] **Fix signup navigation issue**
  ```bash
  cd viva_app
  flutter clean
  flutter pub get
  flutter run
  ```
  
- [ ] **Test "Create account" button** on login screen
  - [ ] Tapping button navigates to register screen
  - [ ] Register screen displays correctly
  - [ ] Registration flow works end-to-end
  
- [ ] **Test biodata template selection**
  - [ ] All 4 templates appear in UI
  - [ ] Icons match template themes
  - [ ] Descriptions are accurate
  - [ ] Template selection is stored
  
- [ ] **Test biodata generation**
  - [ ] Generate biodata (any template)
  - [ ] PDF downloads successfully
  - [ ] PDF opens in device PDF viewer
  - [ ] Share functionality works

---

## EDGE CASE TESTING

### Data Scenarios

Test biodata generation with:

1. **Minimal Profile**
   - [ ] Name only
   - [ ] Name + age + gender
   - [ ] No photos
   - [ ] No education
   - [ ] No career
   - [ ] No family info
   - [ ] No partner preferences

2. **Complete Profile**
   - [ ] All fields populated
   - [ ] 5 photos
   - [ ] Long About (1000 chars)
   - [ ] 20 hobbies
   - [ ] Complete family details
   - [ ] Complete partner preferences

3. **Long Text**
   - [ ] Very long name (30+ chars)
   - [ ] Very long company name (50+ chars)
   - [ ] Very long education (100+ chars)
   - [ ] Very long About (2000+ chars)
   - [ ] Very long partner preferences (1000+ chars)

4. **Unicode/Special Characters**
   - [ ] Hindi name (संदीप शर्मा)
   - [ ] Special characters in company (& Co. Pvt. Ltd.)
   - [ ] Accented characters (Café, José)
   - [ ] Rupee symbol (₹10-15 LPA)

5. **Privacy Scenarios**
   - [ ] `show_parents_info = False`
   - [ ] `show_company = False`
   - [ ] `show_income = False`
   - [ ] All privacy flags enabled

6. **Photo Scenarios**
   - [ ] No photos
   - [ ] 1 photo
   - [ ] 2 photos
   - [ ] 5 photos
   - [ ] Very large image (15 MB)
   - [ ] Very small image (50 KB)
   - [ ] Portrait orientation (3:4)
   - [ ] Landscape orientation (16:9)
   - [ ] Square orientation (1:1)
   - [ ] Invalid/corrupted image
   - [ ] Missing image URL

7. **Null Handling**
   - [ ] `name = null`
   - [ ] `age = null`
   - [ ] `height = null`
   - [ ] `education = null`
   - [ ] `career = null`
   - [ ] `family = null`
   - [ ] `hobbies = []`
   - [ ] `about = ""`

---

## PERFORMANCE TESTING

### Metrics to Measure

- [ ] **PDF Generation Time**
  - Target: <5 seconds for typical profile
  - Measure with: Structured logging timestamps
  
- [ ] **Image Optimization Time**
  - Target: <2 seconds per image
  - Measure with: Logger timestamps
  
- [ ] **Memory Usage**
  - Target: <500 MB peak for 5 large images
  - Measure with: System monitoring
  
- [ ] **File Size**
  - Typical profile: <2 MB ✓
  - With 5 photos: <5 MB ✓
  - Measure with: Actual generated files

### Load Testing

- [ ] **Concurrent Requests**
  - 10 concurrent PDF generations
  - 50 concurrent PDF generations
  - Verify no timeouts or crashes
  
- [ ] **Large Profile**
  - 5 photos (each 15 MB original)
  - 2000 char About text
  - 20 hobbies
  - Complete all sections
  - Verify generation completes successfully

---

## SECURITY VERIFICATION

- [x] **Authentication Required** — Existing test passes
- [x] **Privacy Filters Enforced** — New test added
- [ ] **No PII Leakage** — Verify no internal IDs exposed
- [ ] **Rate Limiting** — TODO: Add rate limiting
- [ ] **Input Validation** — TODO: Add validation for malicious inputs

---

## DEPENDENCY VERIFICATION

- [x] **httpx >= 0.24.0** — Already in requirements.txt (0.27.2)
- [x] **Pillow >= 10.0.0** — Already in requirements.txt (11.0.0)
- [x] **weasyprint >= 62.0** — Already in requirements.txt (62.3)
- [x] **pytest >= 8.0** — Already in requirements.txt (8.3.4)

---

## DATABASE MIGRATION

No database changes required ✓

---

## DEPLOYMENT STEPS

### 1. Pre-Deployment
- [ ] All tests pass
- [ ] Visual verification complete
- [ ] Edge cases tested
- [ ] Performance acceptable
- [ ] Security verified

### 2. Staging Deployment
- [ ] Deploy backend to staging
- [ ] Deploy Flutter app to staging
- [ ] Run smoke tests on staging
- [ ] Generate sample PDFs on staging
- [ ] Share PDFs via WhatsApp on staging

### 3. Production Deployment
- [ ] Deploy backend to production
- [ ] Deploy Flutter app to production
- [ ] Monitor error logs for 24 hours
- [ ] Monitor PDF generation success rate
- [ ] Monitor average file size

### 4. Post-Deployment Monitoring

**Metrics to Track:**
- PDF generation success rate (target: >99%)
- Average PDF file size (target: <2 MB)
- Image optimization success rate (target: >95%)
- PDF generation time (target: <5 seconds)
- Memory usage (target: <500 MB peak)

**Alerts to Set:**
- PDF generation failure rate >5%
- Average generation time >10 seconds
- Memory usage >1 GB
- Disk space low (optimized images accumulate)

---

## ROLLBACK PLAN

### If Critical Issues Found

**Scenario 1: PDF Generation Failures**
- Revert `biodata_service.py` changes
- Deploy previous working version
- Investigation required before retry

**Scenario 2: Image Optimization Crashes**
- Disable optimization temporarily
- Set `if size_mb < float('inf'):` to skip optimization
- Fix and redeploy

**Scenario 3: Privacy Filter Breaking**
- Revert `_normalize_family()` changes
- Review test cases
- Fix and redeploy

**Rollback Command:**
```bash
git revert <commit-hash>
git push origin main
# Trigger deployment pipeline
```

---

## KNOWN LIMITATIONS

### Partial Fixes
1. **Screenshot Problem** (🟡 Partial)
   - Image optimization helps but doesn't eliminate root cause
   - Users can still upload screenshots with UI elements
   - Future fix: Add client-side photo cropping UI

### Not Implemented Yet
1. **PDF Caching** — PDFs regenerated on every request
2. **Rate Limiting** — No limit on PDF generation frequency
3. **Monitoring Dashboard** — Manual log inspection required
4. **Photo Cropping UI** — Client-side cropping not implemented

---

## SUCCESS CRITERIA

✅ **PRODUCTION READY** when:

1. All backend tests pass (100%)
2. All 4 templates visually verified
3. All edge cases tested
4. Physical print test passes
5. WhatsApp sharing works
6. Signup navigation confirmed working
7. Performance metrics met
8. No critical security issues

---

## SIGN-OFF

### Developer
- [ ] All code changes committed
- [ ] All tests written and passing
- [ ] Documentation updated
- [ ] Deployment checklist reviewed

**Signed:** ________________ **Date:** __________

### QA Engineer
- [ ] Visual verification complete
- [ ] Edge cases tested
- [ ] Performance acceptable
- [ ] Security verified

**Signed:** ________________ **Date:** __________

### Product Manager
- [ ] Acceptance criteria met
- [ ] User experience acceptable
- [ ] Business requirements satisfied
- [ ] Approved for production

**Signed:** ________________ **Date:** __________

---

## QUICK START TESTING

### For Developers (5 minutes)

```bash
# 1. Test backend
cd backend
python -m pytest tests/unit/test_biodata_normalization.py -v

# 2. Fix signup navigation
cd ../viva_app
flutter clean && flutter pub get && flutter run

# 3. Test in app
# - Tap "Create account" on login screen
# - Complete registration
# - Navigate to biodata screen
# - Select template and generate PDF
```

### For QA (30 minutes)

1. Run `backend/run_biodata_tests.bat`
2. Generate PDFs for all 4 templates
3. Visually inspect each PDF
4. Print Traditional template on A4
5. Share Modern template via WhatsApp
6. Test signup navigation flow
7. Test edge cases (no photos, long text, privacy filters)

---

## CONTACT

**Questions about:**
- Fixes: See `docs/BIODATA_FIXES_SUMMARY.md`
- Audit: See `docs/BIODATA_QA_AUDIT_REPORT.md`
- Quick Reference: See `FIXES_APPLIED.md`

---

**DOCUMENT VERSION:** 1.0  
**LAST UPDATED:** January 2025  
**STATUS:** Pre-Production Testing

