//
//  CarbonEventInterceptor.m
//  PixelPicker
//

#import "PPMenuShortcutView.h"
#import "PixelPicker-Swift.h"

// The trailing end of the cancel button in the MASShortcutView (within the NSMenuItem).
CGFloat cancelBoundary = 15;

// In order to have a MASShortcutView inside our menubar dropdown menu, we need to
// perform some hacks. Basically, we catch all the key and mouse events, and then
// use those to manually control the shortcut view (the MASShortcutView doesn't work
// properly when its application isn't active, and since it's in a menu, the app isn't active).
//
// The way we do this is by intercepting the key events on the NSMenu which - since NSMenu's
// are old Carbon-based windows - requires using some Carbon event handling APIs.
// To catch mouse events we just override the "NSView.hitTest" to return itself.
//
// See https://kazakov.life/2017/05/18/hacking-nsmenu-keyboard-navigation/ for the inspiration
// to catch the NSMenu's key events.

@implementation PPMenuShortcutView
{
    EventHandlerRef m_EventHandler;
    MASShortcutView *shortcutView;
    unsigned short lastKeyCode;
}

- (instancetype)initWithShortcut:(MASShortcutView *)passedShortcutView
{
    self = [super initWithFrame:NSMakeRect(0, 0, 200, 22)];
    if (self) {
        [self setAutoresizingMask: NSViewWidthSizable];
        [self addSubview:passedShortcutView];
        shortcutView = passedShortcutView;
        lastKeyCode = kVK_Escape;

        // Center and position MASShortcutView with contraints.
        shortcutView.translatesAutoresizingMaskIntoConstraints = false;
        [self addConstraint: [NSLayoutConstraint constraintWithItem:shortcutView attribute:NSLayoutAttributeCenterX  relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterX  multiplier:1.0 constant:  0.0]];
        [self addConstraint: [NSLayoutConstraint constraintWithItem:shortcutView attribute:NSLayoutAttributeLeading  relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeLeading  multiplier:1.0 constant: 20.0]];
        [self addConstraint: [NSLayoutConstraint constraintWithItem:shortcutView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:-20.0]];
        [shortcutView setFrame: self.frame];
    }
    return self;
}

-(void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];

    // Draw a border around the view.
    // Currently we don't use any of MASShortcut's custom drawing styles since they don't draw
    // nicely with macOS 10.14's new dark interface style.
    CGFloat xInset = 20;
    CGFloat yInset = 1;
    NSRect borderRect = NSMakeRect(self.frame.origin.x + xInset, self.frame.origin.y + yInset, self.frame.size.width - xInset - cancelBoundary, self.frame.size.height - (yInset * 2));
    NSBezierPath *border = [NSBezierPath bezierPathWithRoundedRect:borderRect xRadius:3 yRadius:3];
    [[[NSColor scrollBarColor] colorWithAlphaComponent:0.5] set];
    [border stroke];
}

// This is called when the NSMenu is opened, so it's a good time to register our
// intercepting event handlers to catch all keyboard events inside the NSMenu.
- (void)viewDidMoveToWindow
{
    [super viewDidMoveToWindow];
    
    if (m_EventHandler != nil) {
        RemoveEventHandler(m_EventHandler);
        m_EventHandler = nil;
    }
    
    NSWindow *carbonWindow = [self window];
    if (carbonWindow != nil) {
        if (![carbonWindow.className isEqualToString:@"NSCarbonMenuWindow"]) {
            NSLog(@"PPMenuShortcutView is designed to work with NSCarbonMenuWindow.");
            return;
        }

        EventTargetRef target = GetApplicationEventTarget();
        if (!target) {
            NSLog(@"GetEventDispatcherTarget() failed.");
            return;
        }
        
        EventTypeSpec events[] = {
            { kEventClassKeyboard, kEventRawKeyDown },
            { kEventClassKeyboard, kEventRawKeyModifiersChanged }
        };
        OSStatus result = InstallEventHandler(target, CarbonEventHandler, GetEventTypeCount(events), events, (__bridge void*)self, &m_EventHandler);
        
        if (result != noErr) {
            NSLog(@"InstallEventHandler() failed.");
        }
    }
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event
{
    return true;
}

// Here, since we catch all mouse events on this view, we manually check where the
// click was in the MASShortcutView and control the view accordingly.
- (void)mouseDown:(NSEvent *)event
{
    NSPoint point = event.locationInWindow;
    // Start of the MASShortcutView.
    CGFloat start = shortcutView.frame.origin.x;
    // End of the MASShortcutView.
    CGFloat end = start + shortcutView.frame.size.width;
    // Start of the cancel button in the MASShortcutView.
    CGFloat cancelStart = end - cancelBoundary;

    if (shortcutView.shortcutValue != nil) {
        if (point.x >= start && point.x <= cancelStart) {
            [shortcutView setRecording: !shortcutView.isRecording];
        } else if (point.x >= cancelStart && point.x <= end) {
            shortcutView.isRecording ? [shortcutView setRecording: false] : [shortcutView setShortcutValue: nil];
        }
    } else if (point.x >= start && point.x <= end) {
        [shortcutView setRecording: !shortcutView.isRecording];
    }
}

// Override hitTest to catch all click events and handle them ourselves.
- (NSView *)hitTest:(NSPoint)point
{
    return self;
}

// If the shortcut view is recording, then try to create a new shortcut from the passed event.
// If it's valid, then set that shortcut.
- (bool)processInterceptedEvent:(EventRef)_event
{
    NSEvent *event = [NSEvent eventWithEventRef:_event];
    if (shortcutView.isRecording) {
        unsigned long keyDown = [event type] & NSEventTypeKeyDown;
        unsigned long flagsChanged = [event type] & NSEventTypeFlagsChanged;
        
        if (keyDown && flagsChanged) {
            MASShortcut *shortcut = [MASShortcut shortcutWithEvent:event];
            if (shortcut.keyCodeString.length > 0 && [[MASShortcutValidator sharedValidator] isShortcutValid:shortcut]) {
                [shortcutView setRecording: false];
                [shortcutView setShortcutValue:shortcut];
            } else {
                [shortcutView setValue:shortcut.modifierFlagsString forKey:@"shortcutPlaceholder"];
            }
        }

        // Return true to indicate the the next event handler shouldn't be called.
        // We want to disable standard NSMenu behaviour when the shortcut is recording.
        return true;
    } else {
        if (lastKeyCode == kVK_ANSI_P && event.keyCode == kVK_ANSI_A) {
            PPState.shared.paschaModeEnabled = !PPState.shared.paschaModeEnabled;
        }
        lastKeyCode = event.keyCode;
    }

    return false;
}

// This is the event handler to catch Carbon's EventRefs. We pass the event through
// to `processInterceptedEvent` for handling, and stop the next handlers if we use it.
static OSStatus CarbonEventHandler(EventHandlerCallRef _handler, EventRef _event, void *_user_data)
{
    if (!_event || !_user_data) return noErr;
    
    PPMenuShortcutView *menu_item = (__bridge PPMenuShortcutView*)_user_data;
    if ([menu_item processInterceptedEvent: _event]) return noErr;
    
    return CallNextEventHandler(_handler, _event);
}

@end
