import AVFoundation

enum KeyKind { case char(Character), space, enter, back }

/// Macht aus Tastendrücken Musik: Melodie in der Tonleiter des Songs, Akkordwechsel, Bass, Kadenzen.
final class Music {
    private let audio: AudioEngine
    private(set) var instrumentIndex = 0
    private(set) var songIndex = 0
    private var inst: Instrument { INSTRUMENTS[instrumentIndex] }
    private var song: Song { SONGS[songIndex] }

    private var chordI = 0, inChord = 0, bassAlt = 0, cur = 67
    private var steps: [Int] = []
    private var force = false
    private var last: TimeInterval = 0
    private var seed: UInt32 = 2166136261
    private var rng = SeededRandom(seed: 1)
    private var animalCache: [Int: AVAudioPCMBuffer] = [:]
    private let synthQueue = DispatchQueue(label: "tastenklavier.synth", qos: .userInitiated)

    private let STEPS = [-3, -2, -1, 0, 1, 2, 3, 4]
    private let WEIGHTS = [0.3, 1, 3, 0.35, 3, 1, 0.3, 0.15]

    init(audio: AudioEngine) { self.audio = audio }

    // MARK: Einstellungen

    func setInstrument(_ i: Int, announce: Bool = true) {
        instrumentIndex = clamp(i, 0, INSTRUMENTS.count - 1)
        if case .sampler(let p) = inst.voice { audio.setPrograms(lead: p, comp: inst.compProgram) }
        else { audio.setPrograms(lead: nil, comp: inst.compProgram) }
        reset()
        prewarmAnimals()
        if announce { playChord(0.34) }
    }

    func setSong(_ i: Int, announce: Bool = true) {
        songIndex = clamp(i, 0, SONGS.count - 1)
        audio.setReverb(song.reverb)
        reset()
        if announce { playChord(0.34) }
    }

    private func reset() {
        chordI = 0; inChord = 0; bassAlt = 0; cur = inst.center; steps = []; force = false; last = 0
    }

    // MARK: Töne

    private var chord: Chord { song.chords[chordI] }
    private func scale(_ c: Chord? = nil) -> [Int] { (c ?? chord).scale ?? song.scale }
    private func notes(_ sc: [Int]? = nil) -> [Int] {
        let s = sc ?? scale()
        return (inst.low...inst.high).filter { s.contains($0 % 12) }
    }
    private func nearest(_ notes: [Int], _ m: Int) -> Int {
        var best = 0, d = Int.max
        for (i, n) in notes.enumerated() where abs(n - m) < d { best = i; d = abs(n - m) }
        return best
    }

    private func lead(_ m: Int, _ v: Double, delay: Double = 0, dt: Double = 1000) {
        let fast = dt < 260
        switch inst.voice {
        case .sampler:
            audio.note(audio.lead, m, velocity: v, length: inst.sustained ? (fast ? 0.28 : 0.65) : 2.2, delay: delay)
        case .cow, .cat:
            if let b = animalBuffer(m, short: fast) {
                audio.play(buffer: b, gain: Float(pow(clamp(v, 0.05, 1), 1.4)), delay: delay)
            }
        }
    }

    private func compNote(_ m: Int, _ v: Double, delay: Double = 0) {
        audio.note(audio.comp, m, velocity: v, length: 3.0, delay: delay)
    }

    private func voicing(_ c: Chord? = nil) -> [Int] {
        let ch = c ?? chord
        let tones = (song.rootless && ch.tones.count >= 4) ? Array(ch.tones.dropFirst()) : ch.tones
        var out = Set<Int>()
        for pc in tones {
            var m = 48 + pc
            while m < 52 { m += 12 }
            while m > 64 { m -= 12 }
            out.insert(m)
        }
        return out.sorted()
    }

    private func bass(_ c: Chord) -> Int { let b = 36 + c.root; return b > 43 ? b - 12 : b }

    private func playChord(_ v: Double = 0.32) {
        compNote(bass(chord), v + 0.12)
        for (i, m) in voicing().enumerated() { compNote(m, v * 0.8, delay: 0.02 + Double(i) * song.roll) }
    }

    private func advance(to: Int? = nil) {
        chordI = to ?? (chordI + 1) % song.chords.count
        inChord = 0; bassAlt = 0
        playChord()
    }

    // MARK: Melodie

    private func mix(_ code: UInt32) {
        seed = (seed ^ code) &* 16777619
        rng = SeededRandom(seed: UInt64(seed))
    }

    private func step(_ notes: [Int]) -> Int {
        let i = nearest(notes, cur), center = nearest(notes, inst.center)
        var w: [Double] = []
        for (s, base) in zip(STEPS, WEIGHTS) {
            let c = i + s
            if c < 0 || c >= notes.count { w.append(0); continue }
            var x = base * exp(-pow(Double(c - center) / 5.5, 2))
            if s == 0 && steps.first == 0 { x = 0 }
            if s != 0 && steps.count >= 3 && steps.prefix(3).allSatisfy({ $0 != 0 && ($0 > 0) == (s > 0) }) { x *= 0.35 }
            if let f = steps.first, abs(f) >= 3, s * f > 0 { x *= 0.2 }
            w.append(x)
        }
        var r = rng.next() * w.reduce(0, +)
        var k = 0
        for (j, x) in w.enumerated() { k = j; r -= x; if r <= 0 { break } }
        steps = Array(([STEPS[k]] + steps).prefix(4))
        return clamp(i + STEPS[k], 0, notes.count - 1)
    }

    private func snap(_ notes: [Int], _ i: Int, root: Bool = false) -> Int {
        var best = i, d = Double.infinity
        for (j, m) in notes.enumerated() where chord.tones.contains(m % 12) {
            let dd = Double(abs(j - i)) + ((root && m % 12 != chord.root) ? 1.5 : 0)
            if dd < d { best = j; d = dd }
        }
        return best
    }

    private func vel(_ dt: Double) -> Double {
        clamp(0.36 + min(dt, 900) / 900 * 0.42, 0.34, 0.8) + (Double.random(in: 0..<1) - 0.5) * 0.06
    }

    // MARK: Tasten

    func handle(_ key: KeyKind) {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = last > 0 ? (now - last) * 1000 : 2000
        last = now
        switch key {
        case .space: onSpace(dt)
        case .enter: onEnter()
        case .back: onBack()
        case .char(let c):
            if ".!?,;:".contains(c) { onPunct(c) } else { onChar(c, dt) }
        }
    }

    private func onChar(_ ch: Character, _ dt: Double) {
        mix(ch.unicodeScalars.first?.value ?? 0)
        let phrase = dt > 1800
        if force || (phrase && inChord >= 3) { force = false; advance() }
        let ns = notes()
        var i = step(ns)
        let strong = phrase || inChord % 4 == 0
        if strong { i = snap(ns, i) }
        let m = ns[i]
        cur = m
        let v = vel(dt) + (strong ? 0.06 : 0)
        let isSampler: Bool = { if case .sampler = inst.voice { return true }; return false }()
        if song.grace > 0 && isSampler && !strong && rng.next() < song.grace {
            lead(m - 1, v * 0.55, dt: 100)        // chromatischer Vorschlag von unten
            lead(m, v, delay: 0.05, dt: dt)
        } else {
            lead(m, v, dt: dt)
        }
        if ch.isUppercase {                        // Grossbuchstabe: zweite Stimme darunter
            for h in stride(from: m - 3, to: m - 10, by: -1) where chord.tones.contains(((h % 12) + 12) % 12) {
                lead(h, v * 0.6, delay: 0.012, dt: dt)
                break
            }
        }
        inChord += 1
        if inChord >= song.change + 5 { force = true }
    }

    private func onSpace(_ dt: Double) {
        if inChord >= song.change { advance(); return }
        let c = chord
        let seq = [c.root, c.tones.count > 2 ? c.tones[2] : c.tones[1], c.tones[1]]
        let pc = seq[bassAlt % 3]
        bassAlt += 1
        compNote(43 + ((pc - 7) % 12 + 12) % 12, clamp(vel(dt) * 0.6, 0.22, 0.45))
    }

    private func onPunct(_ ch: Character) {
        switch ch {
        case ".", "!":
            advance(to: 0)
            let ns = notes()
            var i = snap(ns, nearest(ns, cur), root: true)
            if ch == "!" { i = snap(ns, min(ns.count - 1, i + 3)) }
            cur = ns[i]
            lead(cur, ch == "!" ? 0.8 : 0.58, delay: 0.06)
        case "?":
            advance(to: song.dom)
            let ns = notes()
            let i = snap(ns, min(ns.count - 1, nearest(ns, cur) + 2))
            cur = ns[i]
            lead(cur, 0.58, delay: 0.06)
        default:                                   // , ; :  leiser Zweiklang
            let vo = voicing()
            if let top = vo.last, let bottom = vo.first {
                compNote(top, 0.3)
                compNote(bottom, 0.22, delay: 0.03)
            }
        }
    }

    private func onEnter() {
        advance(to: 0)
        let ns = notes()
        cur = ns[snap(ns, nearest(ns, inst.center + 4), root: true)]
        lead(cur, 0.6, delay: 0.12)
        steps = []
    }

    private func onBack() {
        let ns = notes()
        cur = ns[max(0, nearest(ns, cur) - 1)]
        lead(cur, 0.22)
    }

    // MARK: Tierstimmen

    private func animalKey(_ voice: Voice, _ m: Int, _ short: Bool) -> Int {
        (voice == .cow ? 0 : 100_000) + m * 2 + (short ? 1 : 0)
    }

    private func animalBuffer(_ m: Int, short: Bool) -> AVAudioPCMBuffer? {
        let key = animalKey(inst.voice, m, short)
        if let b = animalCache[key] { return b }
        let samples = inst.voice == .cow ? AnimalSynth.cow(midi: m, short: short) : AnimalSynth.cat(midi: m, short: short)
        let b = audio.makeBuffer(samples)
        animalCache[key] = b
        return b
    }

    /// Tierstimmen im Hintergrund vorberechnen, damit der erste Anschlag nicht hängt.
    private func prewarmAnimals() {
        let voice = inst.voice
        guard voice == .cow || voice == .cat else { return }
        var todo = Set<Int>()
        for s in SONGS { for c in s.chords { for m in notes(c.scale ?? s.scale) { todo.insert(m) } } }
        let pitches = todo.sorted { abs($0 - inst.center) < abs($1 - inst.center) }
        for m in pitches {
            for short in [false, true] {
                let key = animalKey(voice, m, short)
                if animalCache[key] != nil { continue }
                synthQueue.async { [weak self] in
                    let samples = voice == .cow ? AnimalSynth.cow(midi: m, short: short) : AnimalSynth.cat(midi: m, short: short)
                    DispatchQueue.main.async {
                        guard let self, self.animalCache[key] == nil else { return }
                        self.animalCache[key] = self.audio.makeBuffer(samples)
                    }
                }
            }
        }
    }
}
