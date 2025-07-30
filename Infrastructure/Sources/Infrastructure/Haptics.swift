//
//  Haptics.swift
//  Infrastructure
//
//  Centralized haptic feedback helper for consistent tactile responses
//

import UIKit

@MainActor
public enum Haptics {
    // Impact feedback generators
    public static func light() {
        // Check accessibility settings
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        // Check if we're in testing
        guard !ProcessInfo.processInfo.arguments.contains("--disable-haptics") else { return }
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    public static func medium() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        guard !ProcessInfo.processInfo.arguments.contains("--disable-haptics") else { return }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    public static func heavy() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        guard !ProcessInfo.processInfo.arguments.contains("--disable-haptics") else { return }
        
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
    
    // Notification feedback generator
    public static func success() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        guard !ProcessInfo.processInfo.arguments.contains("--disable-haptics") else { return }
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    public static func warning() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        guard !ProcessInfo.processInfo.arguments.contains("--disable-haptics") else { return }
        
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
    
    public static func error() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        guard !ProcessInfo.processInfo.arguments.contains("--disable-haptics") else { return }
        
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
    
    // Selection feedback generator
    public static func selection() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        guard !ProcessInfo.processInfo.arguments.contains("--disable-haptics") else { return }
        
        UISelectionFeedbackGenerator().selectionChanged()
    }
}