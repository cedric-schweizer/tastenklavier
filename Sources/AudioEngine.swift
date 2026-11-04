import AVFoundation
import AudioToolbox

/// Klangerzeugung: zwei Sampler (Melodie, Begleitung) mit den Instrumenten, die macOS mitbringt,
/// dazu Abspieler für die synthetischen Tierstimmen und ein Hall.
final class AudioEngine {
    let engine = AVAudioEngine()
    let lead = AVAudioUnitSampler()
    let comp = AVAudioUnitSampler()
    private let reverb = AVAudioUnitReverb()
    private let bus = AVAudioMixerNode()
    private let animalMixer = AVAudioMixerNode()
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    let monoFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    private(set) var soundBankAvailable = true
    private var generation: [Int: Int] = [:]
    private var leadProgram: UInt8 = 255
    private var compProgram: UInt8 = 255

    static let soundBank = URL(fileURLWithPath:
        "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls")

    init() {
        [lead, comp, reverb, bus, animalMixer].forEach { engine.attach($0) }
        for _ in 0..<12 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: animalMixer, fromBus: 0, toBus: animalMixer.nextAvailableInputBus, format: monoFormat)
            players.append(p)
        }
        engine.connect(lead, to: bus, fromBus: 0, toBus: bus.nextAvailableInputBus, format: nil)
        engine.connect(comp, to: bus, fromBus: 0, toBus: bus.nextAvailableInputBus, format: nil)
        engine.connect(animalMixer, to: bus, fromBus: 0, toBus: bus.nextAvailableInputBus, format: nil)
        engine.connect(bus, to: reverb, format: nil)
        engine.connect(reverb, to: engine.mainMixerNode, format: nil)
        reverb.loadFactoryPreset(.mediumHall)
        animalMixer.outputVolume = 1.6
        start()
        NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            // z. B. Kopfhörer ein- oder ausgesteckt
            self?.start()
        }
    }

    func start() {
        if !engine.isRunning { try? engine.start() }
        players.forEach { if !$0.isPlaying { $0.play() } }
    }

    var volume: Float {
        get { engine.mainMixerNode.outputVolume }
        set { engine.mainMixerNode.outputVolume = newValue }
    }

    func setReverb(_ amount: Float) { reverb.wetDryMix = clamp(amount * 100 + 8, 0, 100) }

    func setPrograms(lead lp: UInt8?, comp cp: UInt8) {
        if let lp, lp != leadProgram { load(lead, lp); leadProgram = lp }
        if cp != compProgram { load(comp, cp); compProgram = cp }
    }

    private func load(_ s: AVAudioUnitSampler, _ program: UInt8) {
        do {
            try s.loadSoundBankInstrument(at: Self.soundBank, program: program,
                                          bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                                          bankLSB: UInt8(kAUSampler_DefaultBankLSB))
        } catch {
            soundBankAvailable = false
            NSLog("Tastenklavier: Klangbibliothek nicht geladen: \(error)")
        }
    }

    /// Ton auf einem Sampler, mit automatischem Loslassen nach `length` Sekunden.
    func note(_ s: AVAudioUnitSampler, _ midi: Int, velocity: Double, length: Double, delay: Double = 0) {
        let n = UInt8(clamp(midi, 0, 127))
        let v = UInt8(clamp(Int(20 + velocity * 100), 1, 127))
        let key = (s === lead ? 0 : 1000) + Int(n)
        let fire = { [weak self] in
            guard let self else { return }
            s.stopNote(n, onChannel: 0)
            s.startNote(n, withVelocity: v, onChannel: 0)
            let gen = (self.generation[key] ?? 0) + 1
            self.generation[key] = gen
            DispatchQueue.main.asyncAfter(deadline: .now() + length) { [weak self] in
                if self?.generation[key] == gen { s.stopNote(n, onChannel: 0) }
            }
        }
        if delay <= 0 { fire() } else { DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: fire) }
    }

    func play(buffer: AVAudioPCMBuffer, gain: Float, delay: Double = 0) {
        let fire = { [weak self] in
            guard let self else { return }
            let p = self.players[self.nextPlayer]
            self.nextPlayer = (self.nextPlayer + 1) % self.players.count
            p.volume = gain
            p.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
            if !p.isPlaying { p.play() }
        }
        if delay <= 0 { fire() } else { DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: fire) }
    }

    func makeBuffer(_ samples: [Float]) -> AVAudioPCMBuffer? {
        guard let b = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: AVAudioFrameCount(samples.count)) else { return nil }
        b.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { src in
            b.floatChannelData![0].update(from: src.baseAddress!, count: samples.count)
        }
        return b
    }
}
