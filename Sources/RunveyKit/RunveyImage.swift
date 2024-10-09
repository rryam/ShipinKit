//
//  RunveyImage.swift
//  RunveyKit
//
//  Created by Rudrank Riyam on 10/9/24.
//

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
public typealias RunveyImage = UIImage
#elseif os(macOS)
public typealias RunveyImage = NSImage
#endif
