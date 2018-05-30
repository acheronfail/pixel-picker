//
//  ShowAndHideCursor.m
//  PixelPicker
//

#include "ShowAndHideCursor.h"

// Calls to `CGDisplayShowCursor` and `CGDisplayHideCursor` need to be balanced.
// See https://developer.apple.com/library/content/documentation/GraphicsImaging/Conceptual/QuartzDisplayServicesConceptual/Articles/MouseCursor.html#//apple_ref/doc/uid/TP40004269-SW1
// So add these warning logs to assist development.
#ifdef DEBUG
bool cursorIsHidden = false;
void LogWarning() {
    NSLog(@"WARNING: Calls to ShowCursor/HideCursor must be balanced, inbalanced call detected");
}
#endif

void ShowCursor() {
    #ifdef DEBUG
    if (!cursorIsHidden) LogWarning();
    cursorIsHidden = false;
    #endif

    CGDisplayShowCursor(kCGDirectMainDisplay);
}

void HideCursor() {
    #ifdef DEBUG
    if (cursorIsHidden) LogWarning();
    cursorIsHidden = true;
    #endif

    CFStringRef propertyString = CFStringCreateWithCString(NULL, "SetsCursorInBackground", kCFStringEncodingUTF8);
    CGSConnectionID cid = _CGSDefaultConnection();
    CGSSetConnectionProperty(cid, cid, propertyString, kCFBooleanTrue);
    CFRelease(propertyString);

    CGDisplayHideCursor(kCGDirectMainDisplay);
}
