# Star Printer Integration - Setup Instructions

## ⚠️ MANUAL STEPS REQUIRED

The code for Star Printer integration has been implemented, but you need to complete these manual steps in Xcode to finish the integration.

---

## Step 1: Download Star SDK

1. Go to https://star-m.jp/products/s_print/sdk/
2. Download the **StarIO10.xcframework** for iOS
3. Unzip the downloaded file

---

## Step 2: Add Framework to Xcode Project

1. Open `BarPOS.xcodeproj` in Xcode
2. In Xcode, locate the `StarIO10.xcframework` file you downloaded
3. **Drag and drop** `StarIO10.xcframework` into your Xcode project navigator
   - Drop it into the root of the BarPOS project
4. When the dialog appears:
   - ✅ Check "Copy items if needed"
   - ✅ Select "Create groups"
   - ✅ Check the BarPOS target
   - Click "Finish"

---

## Step 3: Embed the Framework

1. In Xcode, select the **BarPOS** project in the navigator
2. Select the **BarPOS** target
3. Go to the **General** tab
4. Scroll down to **Frameworks, Libraries, and Embedded Content**
5. Find `StarIO10.xcframework` in the list
6. Change the **Embed** setting from "Do Not Embed" to **"Embed & Sign"**

---

## Step 4: Update Info.plist

1. In Xcode, locate `Info.plist` (usually in the BarPOS folder)
2. Right-click on `Info.plist` and select "Open As" → "Source Code"
3. Add the following entry inside the `<dict>` tag:

```xml
<key>UISupportedExternalAccessoryProtocols</key>
<array>
    <string>jp.star-m.starpro</string>
</array>
```

Alternatively, using the GUI:
1. Open `Info.plist` normally
2. Click the **+** button to add a new row
3. Type: `Supported external accessory protocols`
4. Set Type to: `Array`
5. Click the **+** next to the array to add an item
6. Set Value to: `jp.star-m.starpro`

---

## Step 5: Build the Project

1. In Xcode, select a device or simulator
2. Press **⌘B** (Command + B) to build
3. **Expected result:** Build should succeed with no errors

### If you see errors:

#### "No such module 'StarIO10'"
- ✅ Verify framework was added to project
- ✅ Verify framework is set to "Embed & Sign"
- ✅ Clean build folder (⌘⇧K) and rebuild

#### "Framework not found StarIO10"
- ✅ Check that framework is in Frameworks, Libraries, and Embedded Content
- ✅ Check that it's set to "Embed & Sign", not "Do Not Embed"

#### Other build errors
- Try cleaning the build folder: **Product** → **Clean Build Folder** (⌘⇧K)
- Restart Xcode
- Make sure you're building for a real device or compatible simulator

---

## Step 6: Test the Integration

### Connect the Printer

1. Connect your **Star TSP143IIIU** printer to your Mac or iPad via USB-C
   - If using Mac, you may need a USB-C hub
   - Make sure printer is powered on
2. Load paper into the printer
3. Connect the cash drawer cable to the printer's DK port (if testing drawer)

### Run the App

1. Build and run the app on your device
2. Watch the Xcode console for connection messages
3. **Expected console output:**
   ```
   ✅ Connected to: Star TSP143
   ```

### Test Printing

1. In the app, start a shift (if not already on one)
2. In the register view (right side), you should see two new buttons:
   - 🟢 **Test Printer** (green)
   - 🟠 **Test Drawer** (orange)
3. Tap **Test Printer**
   - A test receipt should print with:
     - "TEST RECEIPT" header
     - 2x Miller Lite $4.00
     - 1x Well Whiskey $6.00
     - Subtotal, Tax, Total
     - "Thank You!" footer
4. Tap **Test Drawer**
   - The cash drawer should pop open

### Expected Console Output

```
✅ Connected to: Star TSP143
✅ Receipt printed
✅ Drawer opened
```

---

## Troubleshooting

### Printer Not Discovered

**Symptom:** Console shows `❌ Discovery error` or no connection message

**Solutions:**
- Unplug and replug the USB cable
- Make sure printer is powered on
- Check that USB-C cable supports data (not just charging)
- Try a different USB port or hub
- Restart the printer

### Print Command Fails

**Symptom:** Console shows errors when tapping Test Printer

**Solutions:**
- Make sure printer has paper loaded
- Check printer status lights (should be solid green, not blinking)
- Open the printer cover and close it to reset
- Power cycle the printer

### Drawer Doesn't Open

**Symptom:** Tapping Test Drawer doesn't open the drawer

**Solutions:**
- Verify drawer cable is connected to printer's DK port
- Check that drawer cable is fully inserted
- Some drawers have a key lock - make sure it's unlocked
- Try the Test Printer button first (drawer may be in sleep mode)

### Build Errors After Adding Framework

**Symptom:** Xcode shows build errors after adding StarIO10

**Solutions:**
1. Clean build folder: **⌘⇧K**
2. Delete derived data:
   - Xcode → Preferences → Locations
   - Click arrow next to Derived Data path
   - Delete the BarPOS folder
3. Restart Xcode
4. Rebuild

---

## What Was Implemented

### New Files Created

1. **StarPrinterManager.swift** (BarPOS/BarPOS/)
   - Manages Star printer connection and discovery
   - Handles receipt printing
   - Handles cash drawer kick
   - Uses Star SDK's StarIO10 framework

2. **STAR_PRINTER_SETUP.md** (this file)
   - Setup and troubleshooting documentation

### Modified Files

1. **ReceiptFormatter.swift**
   - Added `formatReceiptContent()` function
   - Returns `StarReceiptContent` for Star printer

2. **RegisterView.swift**
   - Added `@StateObject private var starPrinter = StarPrinterManager()`
   - Added "Test Printer" and "Test Drawer" buttons
   - Buttons appear in right column when on shift

---

## Next Steps (Phase 2)

Once Phase 1 is working:

- [ ] Integrate Star printer into close tab workflow
- [ ] Add automatic receipt printing option
- [ ] Add automatic drawer open on cash payment
- [ ] Improve error handling and user feedback
- [ ] Add printer status indicator in UI

---

## Technical Details

### Drawer Kick Command

The cash drawer opens using the ESC/POS command:
```
ESC p m t1 t2
0x1B 0x70 0x00 0x19 0x64
```

This sends a pulse to the drawer kick port (DK) on the printer.

### Receipt Format

- Uses Star's XpandCommand builder
- 80mm thermal paper width
- Partial cut after printing
- Center-aligned header/footer
- Left-aligned line items
- Bold total amount

---

## Support

**Common Issues:**
- Framework not found → Check "Embed & Sign" setting
- Printer not discovered → Check USB connection
- Commands fail → Check printer has paper loaded
- Drawer doesn't open → Check DK cable connection

**Console Logs to Watch:**
- `✅ Connected to: ...` = Success
- `❌ Discovery error` = Check USB
- `✅ Receipt printed` = Print succeeded
- `✅ Drawer opened` = Drawer kick succeeded

---

## Additional Resources

- Star Micronics SDK Documentation: https://star-m.jp/products/s_print/sdk/
- StarIO10 API Reference: Check the SDK download for documentation
- ESC/POS Command Reference: Included with printer documentation
