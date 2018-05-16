//
//  ShowAndHideCursor.m
//  PixelPicker
//

#include "ShowAndHideCursor.h"

// Calls to `CGDisplayShowCursor` and `CGDisplayHideCursor` need to be balanced.
// See https://developer.apple.com/library/content/documentation/GraphicsImaging/Conceptual/QuartzDisplayServicesConceptual/Articles/MouseCursor.html#//apple_ref/doc/uid/TP40004269-SW1
bool cursorIsHidden = false;

void ShowCursor() {
    if (!cursorIsHidden) LogWarning();
    cursorIsHidden = false;

    CGDisplayShowCursor(kCGDirectMainDisplay);
}

void HideCursor() {
    if (cursorIsHidden) LogWarning();
    cursorIsHidden = true;

    CFStringRef propertyString = CFStringCreateWithCString(NULL, "SetsCursorInBackground", kCFStringEncodingUTF8);
    CGSSetConnectionProperty(_CGSDefaultConnection(), _CGSDefaultConnection(), propertyString, kCFBooleanTrue);
    CFRelease(propertyString);

    CGDisplayHideCursor(kCGDirectMainDisplay);
}

void LogWarning() {
    NSLog(@"WARNING: Calls to ShowCursor/HideCursor must be balanced, inbalanced call detected");
}
