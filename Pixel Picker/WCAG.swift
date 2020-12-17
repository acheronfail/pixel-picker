//
//  WCAG.swift
//  Pixel Picker
//

import Foundation

// Represents the different WCAG contrast levels defined by: https://www.w3.org/TR/WCAG20/.
enum WCAGLevel: String {
    case AAA
    case AA
    case OK
    case Fail
    
    // The contrast intervals are based on the minimums for regular text in https://www.w3.org/TR/WCAG20/.
    init(contrastRatio: CGFloat) {
        switch contrastRatio {
        case _ where contrastRatio >= 7:
            self = .AAA
        case _ where contrastRatio >= 4.5:
            self = .AA
        case _ where contrastRatio >= 3:
            self = .OK
        default:
            self = .Fail
        }
    }
}
