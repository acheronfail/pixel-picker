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
// See:  https://stackoverflow.com/a/3939241/5552584
// Also: https://github.com/asmagill/hammerspoon_asm.undocumented/blob/master/cursor/CGSConnection.h

// Every application is given a singular connection ID through which it can receieve and manipulate
// values, state, notifications, events, etc. in the Window Server.
typedef int CGSConnectionID;

// Associates a value for the given key on the given connection.
CGError CGSSetConnectionProperty(CGSConnectionID cid, CGSConnectionID targetCID, CFStringRef key, CFTypeRef value);

// Gets the default connection for this process. `CGSMainConnectionID` is just a more modern name.
CGSConnectionID _CGSDefaultConnection(void);
CGSConnectionID CGSMainConnectionID(void);

#endif /* ShowAndHideCursor_h */
