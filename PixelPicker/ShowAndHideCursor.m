//
//  ShowAndHideCursor.m
//  PixelPicker
//

#include "ShowAndHideCursor.h"

// Unfortunately `kCGDirectMainDisplay` is unavailable in Swift.
CGDirectDisplayID kCGDirectMainDisplayGetter() {
    return kCGDirectMainDisplay;
}
