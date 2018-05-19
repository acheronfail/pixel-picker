//
//  ShowAndHideCursor.h
//  PixelPicker
//

#ifndef ShowAndHideCursor_h
#define ShowAndHideCursor_h

#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>

void ShowCursor(void);
void HideCursor(void);
void LogWarning(void);

// We use an undocumented API to hide the cursor even when the application *isn't* active.
// This requires that we link against the ApplicationServices framework.
// See https://stackoverflow.com/a/3939241/5552584
// and https://web.archive.org/web/20150609013355/http://lists.apple.com:80/archives/carbon-dev/2006/Jan/msg00555.html
// and http://doomlaser.com/cursorcerer-hide-your-cursor-at-will/
void CGSSetConnectionProperty(int a, int b, CFStringRef c, CFBooleanRef d);
int _CGSDefaultConnection(void);

#endif /* ShowAndHideCursor_h */
