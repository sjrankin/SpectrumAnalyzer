//
//  MusicAudioTap.swift
//  SpectrumAnalyzer
//
//  Created by Stuart Rankin on 1/18/26.
//

#if os(macOS)
import AppKit
import CoreAudio

/// Captures the Music app's audio output with a Core Audio process tap
/// (macOS 14.2+) and feeds it to a `SpectrumDSP`.
///
/// The tap observes Music's output without muting it. Not main-actor isolated:
/// the IO block runs on a dedicated audio queue.
nonisolated final class MusicAudioTap: @unchecked Sendable {
    static let musicBundleID = "com.apple.Music"

    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private let queue = DispatchQueue(label: "SpectrumAnalyzer.MusicTap", qos: .userInteractive)

    func start(dsp: SpectrumDSP, publish: @escaping @Sendable ([Float]) -> Void) throws {
        guard let music = NSRunningApplication.runningApplications(
            withBundleIdentifier: Self.musicBundleID
        ).first else {
            throw AudioEngineError.musicNotRunning
        }

        let processObject = try Self.processObject(for: music.processIdentifier)

        // Tap Music's output as a stereo mixdown, without muting it.
        let description = CATapDescription(stereoMixdownOfProcesses: [processObject])
        description.uuid = UUID()
        description.muteBehavior = .unmuted
        description.isPrivate = true

        try Self.check(AudioHardwareCreateProcessTap(description, &tapID), "create tap")

        do {
            let format = try Self.tapFormat(tapID)
            guard format.mFormatID == kAudioFormatLinearPCM,
                  format.mFormatFlags & kAudioFormatFlagIsFloat != 0,
                  format.mBitsPerChannel == 32 else {
                throw AudioEngineError.invalidFormat
            }

            // The aggregate needs a real device to supply its clock; without one
            // the IO callback never fires and the tap delivers nothing.
            let outputUID = try Self.defaultOutputDeviceUID()

            let aggregate: [String: Any] = [
                kAudioAggregateDeviceNameKey: "SpectrumAnalyzer Music Tap",
                kAudioAggregateDeviceUIDKey: UUID().uuidString,
                kAudioAggregateDeviceMainSubDeviceKey: outputUID,
                kAudioAggregateDeviceIsPrivateKey: true,
                kAudioAggregateDeviceIsStackedKey: false,
                kAudioAggregateDeviceTapAutoStartKey: true,
                kAudioAggregateDeviceSubDeviceListKey: [[
                    kAudioSubDeviceUIDKey: outputUID
                ]],
                kAudioAggregateDeviceTapListKey: [[
                    kAudioSubTapUIDKey: description.uuid.uuidString,
                    kAudioSubTapDriftCompensationKey: true
                ]]
            ]
            try Self.check(
                AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID),
                "create device"
            )

            try Self.check(
                AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, queue) { _, input, _, _, _ in
                    let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
                    guard let first = buffers.first, let data = first.mData else { return }
                    let channels = max(1, Int(first.mNumberChannels))
                    let frames = Int(first.mDataByteSize) / MemoryLayout<Float>.size / channels
                    let samples = data.assumingMemoryBound(to: Float.self)
                    if let bands = dsp.process(samples: samples, count: frames, stride: channels) {
                        publish(bands)
                    }
                },
                "create IO proc"
            )
            try Self.check(AudioDeviceStart(aggregateID, procID), "start device")
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        if let procID {
            AudioDeviceStop(aggregateID, procID)
            AudioDeviceDestroyIOProcID(aggregateID, procID)
            self.procID = nil
        }
        if aggregateID != kAudioObjectUnknown {
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = AudioObjectID(kAudioObjectUnknown)
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
    }

    // MARK: - Core Audio helpers

    /// Translates a process ID into Core Audio's process object. Core Audio only
    /// knows about processes that have used audio, hence "not playing yet".
    private static func processObject(for pid: pid_t) throws -> AudioObjectID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var pid = pid
        var object = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address,
            UInt32(MemoryLayout<pid_t>.size), &pid, &size, &object
        )
        try check(status, "find Music process")
        guard object != kAudioObjectUnknown else { throw AudioEngineError.musicNotPlaying }
        return object
    }

    private static func defaultOutputDeviceUID() throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultSystemOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        try check(
            AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device),
            "find output device"
        )

        address.mSelector = kAudioDevicePropertyDeviceUID
        var uid: Unmanaged<CFString>?
        size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        try check(AudioObjectGetPropertyData(device, &address, 0, nil, &size, &uid), "read output device UID")
        guard let uid else { throw AudioEngineError.captureFailed(step: "read output device UID", status: -1) }
        return uid.takeRetainedValue() as String
    }

    private static func tapFormat(_ tapID: AudioObjectID) throws -> AudioStreamBasicDescription {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try check(AudioObjectGetPropertyData(tapID, &address, 0, nil, &size, &format), "read tap format")
        return format
    }

    private static func check(_ status: OSStatus, _ step: String) throws {
        guard status == noErr else { throw AudioEngineError.captureFailed(step: step, status: status) }
    }
}
#endif
