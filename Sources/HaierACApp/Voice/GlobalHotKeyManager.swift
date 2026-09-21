import Foundation
import Carbon.HIToolbox
import AppKit

/// 全局热键管理器：使用 Carbon RegisterEventHotKey 实现无视前台状态的全局快捷键响应
@MainActor
public final class GlobalHotKeyManager {
    public static let shared = GlobalHotKeyManager()

    public var onHotKeyPressed: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    private init() {}

    /// 注册默认全局快捷键：Control + Option + A (Key code 0 = A)
    public func registerDefaultHotKey() {
        unregisterHotKey()

        // 快捷键 ID
        let hotKeyID = EventHotKeyID(signature: FourCharCode(0x48414356), id: 1) // 'HACV', 1

        // Modifiers: Control + Option
        let modifiers: UInt32 = UInt32(controlKey | optionKey)
        let keyCode: UInt32 = UInt32(kVK_ANSI_A) // 'A' 键

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handlerBlock: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let event = event else { return noErr }
            var hkID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hkID
            )
            if status == noErr && hkID.id == 1 {
                Task { @MainActor in
                    GlobalHotKeyManager.shared.onHotKeyPressed?()
                }
            }
            return noErr
        }

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            handlerBlock,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if installStatus != noErr || registerStatus != noErr {
            NSLog("⚠️ GlobalHotKeyManager 注册全局快捷键失败: install=\(installStatus) register=\(registerStatus)")
        } else {
            NSLog("✅ GlobalHotKeyManager: 已成功注册全局语音快捷键 Control+Option+A")
        }
    }

    /// 注销快捷键
    public func unregisterHotKey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef = eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    deinit {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef = eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }
}
