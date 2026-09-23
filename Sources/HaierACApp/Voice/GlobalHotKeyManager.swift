import Foundation
import Carbon.HIToolbox
import AppKit

/// 全局热键管理器：使用 Carbon RegisterEventHotKey 实现无视前台状态的全局快捷键响应
@MainActor
public final class GlobalHotKeyManager {
    public static let shared = GlobalHotKeyManager()

    public var onHotKeyPressed: (() -> Void)?
    public var onSleepHotKeyPressed: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var sleepHotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    private init() {}

    /// 注册全局快捷键：
    /// 1. Control + Option + A (Key code 0 = A) -> 语音控制胶囊
    /// 2. Control + Option + S (Key code 1 = S) -> 智能睡眠一键启停
    public func registerDefaultHotKey() {
        unregisterHotKey()

        // 快捷键 ID: 'HACV' (1), 'HACS' (2)
        let voiceHotKeyID = EventHotKeyID(signature: FourCharCode(0x48414356), id: 1)
        let sleepHotKeyID = EventHotKeyID(signature: FourCharCode(0x48414353), id: 2)

        // Modifiers: Control + Option
        let modifiers: UInt32 = UInt32(controlKey | optionKey)
        let voiceKeyCode: UInt32 = UInt32(kVK_ANSI_A) // 'A' 键 (0)
        let sleepKeyCode: UInt32 = UInt32(kVK_ANSI_S) // 'S' 键 (1)

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
            if status == noErr {
                if hkID.id == 1 {
                    Task { @MainActor in
                        GlobalHotKeyManager.shared.onHotKeyPressed?()
                    }
                } else if hkID.id == 2 {
                    Task { @MainActor in
                        GlobalHotKeyManager.shared.onSleepHotKeyPressed?()
                    }
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

        let registerVoiceStatus = RegisterEventHotKey(
            voiceKeyCode,
            modifiers,
            voiceHotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        let registerSleepStatus = RegisterEventHotKey(
            sleepKeyCode,
            modifiers,
            sleepHotKeyID,
            GetApplicationEventTarget(),
            0,
            &sleepHotKeyRef
        )

        if installStatus != noErr || registerVoiceStatus != noErr || registerSleepStatus != noErr {
            NSLog("⚠️ GlobalHotKeyManager 注册快捷键异常: install=\(installStatus) voice=\(registerVoiceStatus) sleep=\(registerSleepStatus)")
        } else {
            NSLog("✅ GlobalHotKeyManager: 已成功注册全局语音快捷键 (⌃⌥A) 与睡眠启停快捷键 (⌃⌥S)")
        }
    }

    /// 注销快捷键
    public func unregisterHotKey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let sleepHotKeyRef = sleepHotKeyRef {
            UnregisterEventHotKey(sleepHotKeyRef)
            self.sleepHotKeyRef = nil
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
        if let sleepHotKeyRef = sleepHotKeyRef {
            UnregisterEventHotKey(sleepHotKeyRef)
        }
        if let eventHandlerRef = eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }
}
