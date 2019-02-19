//
//  ShowAndHideCursor.h
//  Pixel Picker
//

#ifndef ShowAndHideCursor_h
#define ShowAndHideCursor_h

#import <Foundation/Foundation.h>

// Unfortunately `kCGDirectMainDisplay` is unavailable in Swift.
CGDirectDisplayID kCGDirectMainDisplayGetter(void);

#endif /* ShowAndHideCursor_h */
