import CoreAudio
import Foundation

struct AudioInputDevice: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let coreAudioID: AudioDeviceID
    let transportType: UInt32

    var isAirPods: Bool {
        name.localizedCaseInsensitiveContains("AirPods")
    }

    var isBuiltIn: Bool {
        transportType == kAudioDeviceTransportTypeBuiltIn
    }
}

enum AudioInputSelection: Codable, Hashable, Sendable {
    case automatic
    case device(uid: String)
}

enum AudioInputDeviceError: LocalizedError {
    case noInputDevice
    case selectedDeviceUnavailable
    case couldNotSelectDevice(String)

    var errorDescription: String? {
        switch self {
        case .noInputDevice:
            "No microphone is available. Connect a microphone or choose another input device in OpenYap Settings."
        case .selectedDeviceUnavailable:
            "The selected microphone is not connected. Connect it or choose Automatic in OpenYap Settings."
        case let .couldNotSelectDevice(name):
            "OpenYap could not use \(name). Choose another microphone in OpenYap Settings."
        }
    }
}

struct AudioInputDeviceCatalog: Sendable {
    func availableDevices() -> [AudioInputDevice] {
        allDeviceIDs()
            .filter(hasInputStreams)
            .compactMap(makeDevice)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func resolve(_ selection: AudioInputSelection) throws -> AudioInputDevice {
        let devices = availableDevices()
        switch selection {
        case .automatic:
            guard let device = Self.automaticDevice(from: devices, defaultDeviceID: defaultInputDeviceID()) else {
                throw AudioInputDeviceError.noInputDevice
            }
            return device
        case let .device(uid):
            guard let device = devices.first(where: { $0.id == uid }) else {
                throw AudioInputDeviceError.selectedDeviceUnavailable
            }
            return device
        }
    }

    static func automaticDevice(
        from devices: [AudioInputDevice],
        defaultDeviceID: AudioDeviceID?
    ) -> AudioInputDevice? {
        let defaultDevice = devices.first { $0.coreAudioID == defaultDeviceID }

        if let defaultDevice, defaultDevice.isAirPods {
            return defaultDevice
        }
        if let airPods = devices.first(where: \.isAirPods) {
            return airPods
        }
        if let defaultDevice, defaultDevice.isBuiltIn {
            return defaultDevice
        }
        if let builtIn = devices.first(where: \.isBuiltIn) {
            return builtIn
        }
        return defaultDevice ?? devices.first
    }

    private func allDeviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var byteCount: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &byteCount
        ) == noErr else {
            return []
        }

        var devices = Array(
            repeating: AudioDeviceID(kAudioObjectUnknown),
            count: Int(byteCount) / MemoryLayout<AudioDeviceID>.size
        )
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &byteCount,
            &devices
        ) == noErr else {
            return []
        }
        return devices
    }

    private func hasInputStreams(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var byteCount: UInt32 = 0
        return AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &byteCount) == noErr
            && byteCount >= MemoryLayout<AudioStreamID>.size
    }

    private func makeDevice(_ deviceID: AudioDeviceID) -> AudioInputDevice? {
        guard let uid = stringProperty(kAudioDevicePropertyDeviceUID, for: deviceID),
              let name = stringProperty(kAudioObjectPropertyName, for: deviceID)
        else {
            return nil
        }

        return AudioInputDevice(
            id: uid,
            name: name,
            coreAudioID: deviceID,
            transportType: uint32Property(kAudioDevicePropertyTransportType, for: deviceID) ?? 0
        )
    }

    private func defaultInputDeviceID() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var byteCount = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &byteCount,
            &deviceID
        ) == noErr, deviceID != kAudioObjectUnknown else {
            return nil
        }
        return deviceID
    }

    private func stringProperty(_ selector: AudioObjectPropertySelector, for deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: Unmanaged<CFString>?
        var byteCount = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &byteCount, &value) == noErr else {
            return nil
        }
        return value?.takeUnretainedValue() as String?
    }

    private func uint32Property(_ selector: AudioObjectPropertySelector, for deviceID: AudioDeviceID) -> UInt32? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = 0
        var byteCount = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &byteCount, &value) == noErr else {
            return nil
        }
        return value
    }
}
