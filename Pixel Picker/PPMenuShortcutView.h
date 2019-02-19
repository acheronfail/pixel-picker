//
//  CarbonEventInterceptor.h
//  Pixel Picker
//

#ifndef CarbonEventInterceptor_h
#define CarbonEventInterceptor_h

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <MASShortcut/Shortcut.h>

@interface PPMenuShortcutView: NSView

- (instancetype)initWithShortcut:(MASShortcutView *)shortcutView;
- (bool)processInterceptedEvent:(EventRef)_event;

@end

#endif /* CarbonEventInterceptor_h */
