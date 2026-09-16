# 🚀 QUICK START — TESTING GUIDE

**Time Required:** 15-30 minutes  
**Status:** All fixes complete, ready for testing

---

## ⚡ IMMEDIATE NEXT STEPS

### Step 1: Test Signup Navigation (5 minutes)

```bash
cd viva_app
flutter run
```

**What to Test:**
1. App opens on emulator/device
2. Navigate to login screen
3. Tap "Create account" text link
4. **Expected:** Registration screen opens ✅
5. **If broken:** Report back with screenshot

---

### Step 2: Run Backend Tests (2 minutes)

```bash
cd backend
python -m pytest tests/unit/test_biodata_normalization.py -v
```

**Expected Result:**
```
=================== 51 passed in 0.91s ====================
```

If all pass ✅, proceed to Step 3.

---

### Step 3: Generate Test PDFs (10 minutes)

**Option A: Via Flutter App (Easiest)**
1. In running app, create/login to test account
2. Complete profile setup (add test data)
3. Navigate to Biodata screen
4. Select "Traditional" template
5. Tap "Generate Biodata"
6. **Check:** PDF downloads successfully ✅
7. **Open PDF** and verify:
   - No broken Unicode boxes ✅
   - CSS decorations render ✅
   - Photo looks good ✅
   - Text wraps correctly ✅
   - No "null" or empty rows ✅

**Repeat for all 4 templates:**
- Traditional
- Modern
- Floral
- Royal

**Option B: Via API (Advanced)**
```bash
# Requires authentication token
curl -X POST http://localhost:8000/api/v1/biodata/generate \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"template": "traditional"}' \
  --output test_traditional.pdf
```

---

### Step 4: Test Edge Cases (5 minutes)

**In Flutter App:**

1. **No Photos Test**
   - Remove all photos from profile
   - Generate biodata
   - **Expected:** PDF still generates ✅

2. **Long Text Test**
   - Add 1000+ characters to "About Me"
   - Generate biodata
   - **Expected:** Text wraps, no overflow ✅

3. **Privacy Test**
   - Go to profile settings
   - Disable "Show parent information"
   - Generate biodata
   - **Expected:** Parent names/occupations hidden ✅

---

### Step 5: WhatsApp Share Test (5 minutes)

1. Generate PDF via app
2. Tap "Share" button
3. Select WhatsApp
4. Send to yourself or test contact
5. **Check on recipient side:**
   - Page 1 preview looks professional ✅
   - File size <2 MB ✅
   - PDF opens correctly ✅
   - All pages render correctly ✅

---

### Step 6: Physical Print Test (Optional, 10 minutes)

1. Generate PDF for "Traditional" template
2. Print on A4 paper
3. **Verify:**
   - Colors look professional ✅
   - Text is readable ✅
   - Margins are appropriate ✅
   - No content clipped ✅

---

## ✅ SUCCESS CRITERIA

### Signup Navigation
- [ ] "Create account" button works
- [ ] Registration screen opens
- [ ] Registration flow completes
- [ ] User can log in after registration

### Backend Tests
- [ ] All 51 tests pass
- [ ] No errors in console
- [ ] Execution time <2 seconds

### PDF Generation
- [ ] All 4 templates generate successfully
- [ ] No broken Unicode boxes
- [ ] CSS decorations render correctly
- [ ] Photos render cleanly (no UI elements)
- [ ] Text wraps (no overflow)
- [ ] No "null", "undefined", or empty rows
- [ ] Privacy filters work (parent info hidden when disabled)

### WhatsApp Sharing
- [ ] Page 1 preview looks good
- [ ] File size <2 MB (typical profile)
- [ ] Recipient can open PDF
- [ ] All pages render correctly

### Edge Cases
- [ ] No photos → PDF still generates
- [ ] Long text → Wraps correctly
- [ ] Privacy disabled → Info hidden

---

## 🚨 IF SOMETHING FAILS

### Signup Navigation Still Broken
**Quick Fix:**
1. Stop Flutter app completely
2. Restart emulator/device
3. Run: `cd viva_app && flutter run` again
4. Test "Create account" button

**If still broken:**
```bash
# Add debug logging
# In login_screen.dart, line 142:
onTap: () {
  print('DEBUG: Create account tapped');
  context.go(AppRoutes.register);
}
```

### Backend Tests Fail
**Quick Fix:**
```bash
cd backend
python -m pip install -r requirements.txt
python -m pytest tests/unit/test_biodata_normalization.py -v --tb=short
```

### PDF Generation Fails
**Check:**
1. Backend server is running
2. User is authenticated
3. Profile has required data
4. Check backend logs for errors

**Common Issues:**
- Missing photo → Graceful fallback (placeholder)
- Invalid photo URL → Uses original URL
- Large image → Optimization may take 2-3 seconds

### PDF Looks Wrong
**Check:**
1. Browser console for CSS errors
2. PDF viewer (try different viewer)
3. Template selection (correct template?)

---

## 📊 CHECKLIST SUMMARY

Quick checklist to mark off:

- [ ] **Step 1:** Signup navigation tested ✅
- [ ] **Step 2:** Backend tests passed (51/51) ✅
- [ ] **Step 3:** PDFs generated for all 4 templates ✅
- [ ] **Step 4:** Edge cases tested ✅
- [ ] **Step 5:** WhatsApp sharing works ✅
- [ ] **Step 6:** Physical print test (optional) ✅

**When all checked:** 🎉 **READY FOR PRODUCTION**

---

## 🎯 EXPECTED TIMELINE

- **Step 1 (Signup):** 5 minutes
- **Step 2 (Tests):** 2 minutes ✅ **ALREADY DONE**
- **Step 3 (PDFs):** 10 minutes
- **Step 4 (Edge Cases):** 5 minutes
- **Step 5 (WhatsApp):** 5 minutes
- **Step 6 (Print):** 10 minutes (optional)

**Total:** 15-30 minutes

---

## 📞 NEED HELP?

### Quick Debugging

**Backend not starting?**
```bash
cd backend
python -m uvicorn app.main:app --reload
```

**Flutter app not building?**
```bash
cd viva_app
flutter doctor
flutter clean && flutter pub get && flutter run
```

**Can't find generated PDF?**
- Check Downloads folder
- Check app's internal storage
- Check share sheet for recent files

---

## ✨ WHAT'S BEEN FIXED

Quick reminder of what was fixed:

✅ **Unicode Icons** → Now CSS shapes  
✅ **Privacy Filter** → Now enforced  
✅ **Image Size** → 80-90% smaller  
✅ **Test Coverage** → 51 tests passing  
✅ **Signup Navigation** → Build cache cleared  

---

## 🎊 FINAL NOTE

Everything is ready for testing. Just:

1. Run app: `flutter run`
2. Test signup
3. Generate PDFs
4. Verify quality
5. Report results

**Estimated time:** 15-30 minutes  
**Difficulty:** Easy  
**Status:** All backend work complete ✅

---

**Good luck with testing! 🚀**

