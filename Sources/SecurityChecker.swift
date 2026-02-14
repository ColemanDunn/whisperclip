import Foundation
import ApplicationServices
import AVFoundation
import AppKit
import Combine
import Quartz

enum SecurityPermission {
    case accessibility
    case microphone
    case appleEvents
    case inputMonitoring
}

struct PermissionStatus {
    let isGranted: Bool
    let message: String
}

class SecurityChecker: ObservableObject {
    static let shared = SecurityChecker()
    
    @Published var microphonePermissionGranted: Bool = false
    @Published var accessibilityPermissionGranted: Bool = false
    @Published var appleEventsPermissionGranted: Bool = false
    @Published var inputMonitoringPermissionGranted: Bool = false
    
    private init() {
        updateAllPermissions()
    }

    
    func updateAllPermissions() {
        microphonePermissionGranted = checkMicrophonePermission().isGranted
        accessibilityPermissionGranted = checkAccessibilityPermission().isGranted
        appleEventsPermissionGranted = checkAppleEventsPermission().isGranted
        inputMonitoringPermissionGranted = checkInputMonitoringPermission().isGranted
    }
    
    func checkAllPermissions() -> [SecurityPermission: PermissionStatus] {
        var statuses: [SecurityPermission: PermissionStatus] = [:]
        
        statuses[.accessibility] = checkAccessibilityPermission()
        statuses[.microphone] = checkMicrophonePermission()
        statuses[.appleEvents] = checkAppleEventsPermission()
        statuses[.inputMonitoring] = checkInputMonitoringPermission()
        
        return statuses
    }
    
    private func checkRequiredPermissions() -> [SecurityPermission: PermissionStatus] {
        // Global hotkeys are registered via Carbon and do not require Accessibility/Input Monitoring.
        var statuses: [SecurityPermission: PermissionStatus] = [:]
        statuses[.microphone] = checkMicrophonePermission()
        statuses[.appleEvents] = checkAppleEventsPermission()
        return statuses
    }
    
    func checkAccessibilityPermission() -> PermissionStatus {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false
        ] as CFDictionary
        
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        
        return PermissionStatus(
            isGranted: isTrusted,
            message: isTrusted ? "Accessibility permission granted" : "Accessibility permission required"
        )
    }
    
    func checkMicrophonePermission() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return PermissionStatus(
                isGranted: true,
                message: "Microphone permission granted"
            )
        case .notDetermined:
            return PermissionStatus(
                isGranted: false,
                message: "Microphone permission required"
            )
        case .denied, .restricted:
            return PermissionStatus(
                isGranted: false,
                message: "Microphone permission denied"
            )
        @unknown default:
            return PermissionStatus(
                isGranted: false,
                message: "Unknown microphone permission status"
            )
        }
    }
    
    func checkAppleEventsPermission() -> PermissionStatus {
        // Try to control System Events with a simple command
        let script = """
        tell application "System Events"
            set frontProcess to first process
            return name of frontProcess
        end tell
        """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let _ = scriptObject.executeAndReturnError(&error)
            if error == nil {
                Logger.log("Apple Events permission granted", log: Logger.general)
                return PermissionStatus(
                    isGranted: true,
                    message: "Apple Events permission granted"
                )
            }

            // Check for permission denied error
            if let errorNumber = error?[NSAppleScript.errorNumber] as? NSNumber,
               errorNumber.intValue == -1743 {
                Logger.log("Apple Events permission denied", log: Logger.general)
                return PermissionStatus(
                    isGranted: false,
                    message: "Apple Events permission required for clipboard operations"
                )
            }

            Logger.log("Apple Events check error: \(error ?? [:])", log: Logger.general, type: .error)
        }

        return PermissionStatus(
            isGranted: false,
            message: "Apple Events permission required for clipboard operations"
        )
    }

    func checkInputMonitoringPermission() -> PermissionStatus {
        if canCreateInputMonitoringTap() {
            return PermissionStatus(
                isGranted: true,
                message: "Input monitoring permission granted"
            )
        }
        return PermissionStatus(
            isGranted: false,
            message: "Input monitoring permission required for global hotkeys"
        )
    }

    func requestInputMonitoringPermission() {
        Logger.log("Requesting Input Monitoring permission", log: Logger.general)
        openSecurityPrivacyPanel("ListenEvent")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.updateAllPermissions()
        }
    }

    func areAllPermissionsGranted() -> Bool {
        let statuses = checkRequiredPermissions()
        return statuses.values.allSatisfy { $0.isGranted }
    }
    
    func getMissingPermissions() -> [String] {
        let statuses = checkRequiredPermissions()
        return statuses
            .filter { !$0.value.isGranted }
            .map { $0.value.message }
    }

    func requestAccessibilityPermission() {
        Logger.log("Requesting Accessibility permission", log: Logger.general)
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if trusted {
            Logger.log("Accessibility permission granted", log: Logger.general)
        } else {
            Logger.log("Accessibility permission denied", log: Logger.general)
        }
        // Update the published property to trigger UI refresh
        DispatchQueue.main.async {
            self.updateAllPermissions()
        }
    }

    func requestMicrophonePermission() {
        Logger.log("Starting microphone permission request", log: Logger.general)
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                if granted {
                    Logger.log("Microphone permission granted by user", log: Logger.general)
                } else {
                    let status = AVCaptureDevice.authorizationStatus(for: .audio)
                    switch status {
                    case .authorized:
                        Logger.log("Microphone permission granted by user", log: Logger.general)
                    case .denied:
                        Logger.log("Microphone permission denied by user", log: Logger.general)
                    case .restricted:
                        Logger.log("Microphone permission restricted by system", log: Logger.general)
                    case .notDetermined:
                        Logger.log("Microphone permission not determined", log: Logger.general)
                    @unknown default:
                        Logger.log("Unknown microphone permission status", log: Logger.general)
                    }
                }
                // Update the published property to trigger UI refresh
                self.updateAllPermissions()
            }
        }
    }

    func requestAppleEventsPermission() {
        Logger.log("Requesting Apple Events permission", log: Logger.general)
        // Try to control System Events with a more specific command that will trigger the permission dialog
        let script = """
        tell application "System Events"
            tell process "System Settings"
                return name
            end tell
        end tell
        """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let _ = scriptObject.executeAndReturnError(&error)
            if error == nil {
                Logger.log("Apple Events permission granted", log: Logger.general)
            } else {
                Logger.log("Apple Events permission denied: \(error?.description ?? "unknown error")", log: Logger.general)
            }
        } else {
            Logger.log("Failed to create AppleScript object", log: Logger.general)
        }
        // Update the published property to trigger UI refresh
        DispatchQueue.main.async {
            self.updateAllPermissions()
        }
    }

    private func openSecurityPrivacyPanel(_ section: String) {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_\(section)"
        guard let url = URL(string: urlString) else {
            Logger.log("Could not open privacy settings for section: \(section)", log: Logger.general, type: .error)
            return
        }
        
        let opened = NSWorkspace.shared.open(url)
        Logger.log("Opened system privacy panel for \(section): \(opened)", log: Logger.general)
    }

    private func canCreateInputMonitoringTap() -> Bool {
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, _, event, _ in
                Unmanaged.passUnretained(event)
            },
            userInfo: nil
        ) else {
            Logger.log("Input monitoring permission check tap creation failed", log: Logger.general, type: .error)
            return false
        }

        // If creation succeeds, the permission check has passed. Disable and tear down the temporary tap.
        CGEvent.tapEnable(tap: tap, enable: false)
        CFMachPortInvalidate(tap)
        return true
    }
}
