import Cocoa
import Carbon

class HotkeyManager: ObservableObject {
    private var hotKeyRef: EventHotKeyRef?
    var action: () -> Void = {}
    var keyUpAction: () -> Void = {}
    var currentModifier: NSEvent.ModifierFlags?
    var currentKeyCode: UInt16?
    static let shared = HotkeyManager()
    static let meetingShared = HotkeyManager()
    private let managerID: UInt32
    
    private static let hotKeySignature = fourCharCode("WCPK")
    private static var nextManagerID: UInt32 = 1
    private static var managersByID: [UInt32: WeakManagerBox] = [:]
    private static var hotKeyEventHandler: EventHandlerRef?
    private static let hotKeyHandlerUPP: EventHandlerUPP = { _, eventRef, _ in
        guard let eventRef else { return noErr }
        
        var hotKeyID = EventHotKeyID()
        let hotKeyIDStatus = GetEventParameter(
            eventRef,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        
        guard hotKeyIDStatus == noErr,
              hotKeyID.signature == HotkeyManager.hotKeySignature,
              let manager = HotkeyManager.managersByID[hotKeyID.id]?.manager else {
            return noErr
        }
        
        let eventKind = GetEventKind(eventRef)
        DispatchQueue.main.async {
            if eventKind == UInt32(kEventHotKeyPressed) {
                manager.action()
            } else if eventKind == UInt32(kEventHotKeyReleased) {
                manager.keyUpAction()
            }
        }
        
        return noErr
    }

    private init() {
        managerID = Self.nextManagerID
        Self.nextManagerID += 1
        Self.managersByID[managerID] = WeakManagerBox(manager: self)
        Self.installHotKeyEventHandlerIfNeeded()
    }

    func setAction(action: @escaping () -> Void) {
        self.action = action
    }

    func setKeyUpAction(action: @escaping () -> Void) {
        self.keyUpAction = action
    }

    func setupSystemHotkey(modifier: NSEvent.ModifierFlags, keyCode: UInt16) {
        // Skip if same hotkey is already active
        if currentModifier == modifier && currentKeyCode == keyCode {
            Logger.log("Same hotkey combination already active, skipping setup", log: Logger.hotkey)
            return
        }

        removeSystemHotkey()

        Logger.log("Setting up system hotkey with modifier: \(modifier) and keyCode: \(keyCode)", log: Logger.hotkey)

        // Store current settings
        currentModifier = modifier
        currentKeyCode = keyCode
        
        let carbonModifierFlags = Self.carbonModifierFlags(from: modifier)
        let hotKeyID = EventHotKeyID(signature: Self.hotKeySignature, id: managerID)
        let registerStatus = RegisterEventHotKey(
            UInt32(keyCode),
            carbonModifierFlags,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if registerStatus == noErr, hotKeyRef != nil {
            Logger.log("Global hotkey registered", log: Logger.hotkey)
        } else {
            hotKeyRef = nil
            Logger.log("Failed to register global hotkey, status=\(registerStatus)", log: Logger.hotkey, type: .error)
        }
    }

    func removeSystemHotkey() {
        Logger.log("Removing system hotkey", log: Logger.hotkey)
        
        if let hotKeyRef {
            let status = UnregisterEventHotKey(hotKeyRef)
            Logger.log("Global hotkey unregistered (status=\(status))", log: Logger.hotkey)
            self.hotKeyRef = nil
            currentModifier = nil
            currentKeyCode = nil
        }
    }

    func updateSystemHotkey(hotkeyEnabled: Bool, modifier: NSEvent.ModifierFlags, keyCode: UInt16) {
        Logger.log("Updating hotkey monitor with modifier: \(modifier) and keyCode: \(keyCode)", log: Logger.hotkey)

        if hotkeyEnabled {
            setupSystemHotkey(
                modifier: modifier,
                keyCode: keyCode
            )
        } else {
            removeSystemHotkey()
        }
    }

    deinit {
        removeSystemHotkey()
        Self.managersByID.removeValue(forKey: managerID)
    }

    private static func installHotKeyEventHandlerIfNeeded() {
        guard hotKeyEventHandler == nil else { return }
        
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyHandlerUPP,
            eventTypes.count,
            &eventTypes,
            nil,
            &hotKeyEventHandler
        )
        
        if installStatus == noErr {
            Logger.log("Hotkey event handler installed", log: Logger.hotkey)
        } else {
            Logger.log("Failed to install hotkey event handler, status=\(installStatus)", log: Logger.hotkey, type: .error)
        }
    }
    
    private static func carbonModifierFlags(from modifier: NSEvent.ModifierFlags) -> UInt32 {
        var flags: UInt32 = 0
        if modifier.contains(.command) { flags |= UInt32(cmdKey) }
        if modifier.contains(.option) { flags |= UInt32(optionKey) }
        if modifier.contains(.control) { flags |= UInt32(controlKey) }
        if modifier.contains(.shift) { flags |= UInt32(shiftKey) }
        return flags
    }
    
    private static func fourCharCode(_ text: String) -> OSType {
        text.utf8.reduce(0) { ($0 << 8) + OSType($1) }
    }
}

private final class WeakManagerBox {
    weak var manager: HotkeyManager?
    
    init(manager: HotkeyManager) {
        self.manager = manager
    }
}
