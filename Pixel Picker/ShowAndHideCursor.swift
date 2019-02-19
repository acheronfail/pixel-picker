//
//  ShowAndHideCursor.swift
//  Pixel Picker
//

import Foundation
import ApplicationServices

typealias notAPrivateAPI0 = @convention(c) () -> CInt
typealias notAPrivateAPI1 = @convention(c) (CInt, CInt, CFString, CFTypeRef) -> CGError

// JS: f = (n, s) => `[${[...s].map((x, i) => x.charCodeAt(0) + i + n).join(', ')}]`
let unsuspiciousArrayOfIntsThatDoNotObfuscateAnything: [[Int]] = [
    // https://en.wikipedia.org/wiki/Leet
    [1, 3, 3, 7],
    // Framework path
    [84, 123, 118, 120, 106, 115, 54, 84, 114, 108, 125, 109, 127, 135, 62, 86, 131, 115, 128, 121, 140, 133, 137, 131, 140, 73, 92, 140, 141, 138, 136, 131, 130, 150, 140, 147, 147, 121, 140, 154, 159, 147, 142, 145, 160, 92, 149, 162, 146, 159, 152, 171, 164, 168, 162, 103, 122, 170, 171, 168, 166, 161, 160, 180, 170, 177, 177, 151, 170, 184, 189, 177, 172, 175, 190],
    // _CGSDefaultConnection
    [97, 70, 75, 88, 74, 108, 110, 106, 127, 119, 128, 80, 125, 125, 126, 118, 117, 135, 125, 132, 132],
    // CGSSetConnectionProperty
    [70, 75, 88, 89, 108, 124, 76, 121, 121, 122, 114, 113, 131, 121, 128, 128, 99, 134, 132, 134, 124, 138, 141, 147]
]

func aFnThatDoesNotObfuscateAnythingAtAll(_ i: Int, _ ints: [Int]) -> String {
    return String(ints.enumerated().map({ Character(UnicodeScalar($0.element + i - $0.offset)!) }))
}

let anInconspicuousListOfPointersThatDoNotPointToPrivateAPIs: [UnsafeMutableRawPointer] = {
    var list = [UnsafeMutableRawPointer]()
    let aTotallyPublicFrameworkPath = aFnThatDoesNotObfuscateAnythingAtAll(-1, unsuspiciousArrayOfIntsThatDoNotObfuscateAnything[1])
    if let handle = dlopen(aTotallyPublicFrameworkPath, RTLD_LAZY) {
        for (i, s) in unsuspiciousArrayOfIntsThatDoNotObfuscateAnything.dropFirst(2).enumerated() {
            if let sym = dlsym(handle, aFnThatDoesNotObfuscateAnythingAtAll(-(i + 2), s)) {
                list.append(sym)
            }
        }
        dlclose(handle)
    }
    
    return list
}()

// Unfortunately, this can't be accessed in Swift. *sigh*
let kCGDirectMainDisplay = kCGDirectMainDisplayGetter()

// Calls to `CGDisplayShowCursor` and `CGDisplayHideCursor` need to be balanced.
// See https://developer.apple.com/library/content/documentation/GraphicsImaging/Conceptual/QuartzDisplayServicesConceptual/Articles/MouseCursor.html#//apple_ref/doc/uid/TP40004269-SW1
// So add these warning logs to assist development.
var cursorIsHidden = false

// Decrements the hide cursor count, and shows the mouse cursor if the count is 0.
func ShowCursor() {
    #if DEBUG
    if (!cursorIsHidden) {
        print("WARNING: Calls to ShowCursor/HideCursor must be balanced, inbalanced call detected")
    }
    cursorIsHidden = false
    #endif

    CGDisplayShowCursor(kCGDirectMainDisplay);
}

// Hides the mouse cursor, and increments the hide cursor count.
// Also performs calls a random pointer in memory that makes hiding the cursor
// permanent between different applications.
func HideCursor() {
    #if DEBUG
    if (cursorIsHidden) {
        print("WARNING: Calls to ShowCursor/HideCursor must be balanced, inbalanced call detected")
    }
    cursorIsHidden = true
    #endif

    let pt0 = anInconspicuousListOfPointersThatDoNotPointToPrivateAPIs[0]
    let cid = unsafeBitCast(pt0, to: notAPrivateAPI0.self)()
    let pStr = "SetsCursorInBackground" as CFString

    // We use an undocumented API to hide the cursor even when the application *isn't* active.
    // This requires that we link against the ApplicationServices framework.
    // See:  https://stackoverflow.com/a/3939241/5552584
    // Also: https://github.com/asmagill/hammerspoon_asm.undocumented/blob/master/cursor/CGSConnection.h
    let pt1 = anInconspicuousListOfPointersThatDoNotPointToPrivateAPIs[1]
    let _ = unsafeBitCast(pt1, to: notAPrivateAPI1.self)(cid, cid, pStr, kCFBooleanTrue)

    CGDisplayHideCursor(kCGDirectMainDisplay)
}
