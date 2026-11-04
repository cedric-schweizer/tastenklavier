import Foundation

// MARK: - Instrumente

enum Voice: Equatable {
    case sampler(UInt8)   // General-MIDI-Programm aus der macOS-Klangbibliothek
    case cow
    case cat
}

struct Instrument {
    let name: String
    let voice: Voice
    let low: Int          // Tonumfang der Melodie
    let high: Int
    let center: Int       // Mittellage, zu der die Melodie zurückkehrt
    let compProgram: UInt8 // Instrument für Akkorde und Bass
    let sustained: Bool   // gehaltener Ton (Bläser, Tiere): kürzer bei schnellem Tippen
}

let INSTRUMENTS: [Instrument] = [
    Instrument(name: "Klavier",  voice: .sampler(0),  low: 57, high: 86, center: 67, compProgram: 0,  sustained: false),
    Instrument(name: "E-Piano",  voice: .sampler(4),  low: 57, high: 84, center: 67, compProgram: 4,  sustained: false),
    Instrument(name: "Gitarre",  voice: .sampler(24), low: 52, high: 81, center: 64, compProgram: 24, sustained: false),
    Instrument(name: "Harfe",    voice: .sampler(46), low: 57, high: 88, center: 69, compProgram: 46, sustained: false),
    Instrument(name: "Marimba",  voice: .sampler(12), low: 57, high: 86, center: 69, compProgram: 12, sustained: false),
    Instrument(name: "Spieluhr", voice: .sampler(10), low: 69, high: 96, center: 79, compProgram: 46, sustained: false),
    Instrument(name: "Trompete", voice: .sampler(56), low: 55, high: 79, center: 67, compProgram: 0,  sustained: true),
    Instrument(name: "Kuh",      voice: .cow,         low: 45, high: 62, center: 52, compProgram: 0,  sustained: true),
    Instrument(name: "Katze",    voice: .cat,         low: 67, high: 86, center: 74, compProgram: 0,  sustained: true),
]

// MARK: - Songs

struct Chord {
    let name: String
    let root: Int
    let tones: [Int]
    let scale: [Int]?
    init(_ name: String, _ root: Int, _ tones: [Int], _ scale: [Int]? = nil) {
        self.name = name; self.root = root; self.tones = tones; self.scale = scale
    }
}

struct Song {
    let name: String
    let reverb: Float     // 0…1
    let scale: [Int]
    let change: Int       // Töne pro Akkord, bevor die Leertaste weiterschaltet
    let grace: Double     // Wahrscheinlichkeit für chromatischen Vorschlag
    let dom: Int          // Akkord für das Fragezeichen (offen)
    let roll: Double      // Abstand beim gebrochenen Akkord
    let rootless: Bool    // Jazz-Voicings ohne Grundton
    let chords: [Chord]
}

let SONGS: [Song] = [
    Song(name: "Pop", reverb: 0.30, scale: [0, 2, 4, 7, 9], change: 7, grace: 0, dom: 3, roll: 0.028, rootless: false,
         chords: [Chord("C", 0, [0, 4, 7]), Chord("Am", 9, [9, 0, 4]), Chord("F", 5, [5, 9, 0, 4]), Chord("G", 7, [7, 11, 2])]),
    Song(name: "Klassisch", reverb: 0.38, scale: [2, 4, 6, 7, 9, 11, 1], change: 6, grace: 0, dom: 7, roll: 0.09, rootless: false,
         chords: [Chord("D", 2, [2, 6, 9]), Chord("A", 9, [9, 1, 4]), Chord("Bm", 11, [11, 2, 6]), Chord("F#m", 6, [6, 9, 1]),
                  Chord("G", 7, [7, 11, 2]), Chord("D", 2, [2, 6, 9]), Chord("G", 7, [7, 11, 2]), Chord("A", 9, [9, 1, 4])]),
    Song(name: "Jazz", reverb: 0.22, scale: [0, 2, 4, 5, 7, 9, 11], change: 6, grace: 0.18, dom: 1, roll: 0.018, rootless: true,
         chords: [Chord("Dm9", 2, [2, 5, 9, 0, 4], [2, 4, 5, 7, 9, 11, 0]),
                  Chord("G13", 7, [7, 11, 5, 4, 9], [7, 9, 11, 0, 2, 4, 5]),
                  Chord("Cmaj9", 0, [0, 4, 7, 11, 2], [0, 2, 4, 7, 9, 11]),
                  Chord("A7b9", 9, [9, 1, 7, 10, 4], [9, 10, 1, 2, 4, 7])]),
    Song(name: "Blues", reverb: 0.20, scale: [0, 3, 5, 6, 7, 10], change: 5, grace: 0.22, dom: 11, roll: 0.022, rootless: false,
         chords: [Chord("C7", 0, [0, 4, 7, 10]), Chord("F7", 5, [5, 9, 0, 3]), Chord("C7", 0, [0, 4, 7, 10]), Chord("C7", 0, [0, 4, 7, 10]),
                  Chord("F7", 5, [5, 9, 0, 3]), Chord("F7", 5, [5, 9, 0, 3]), Chord("C7", 0, [0, 4, 7, 10]), Chord("C7", 0, [0, 4, 7, 10]),
                  Chord("G7", 7, [7, 11, 2, 5]), Chord("F7", 5, [5, 9, 0, 3]), Chord("C7", 0, [0, 4, 7, 10]), Chord("G7", 7, [7, 11, 2, 5])]),
    Song(name: "Melancholisch", reverb: 0.34, scale: [9, 11, 0, 2, 4, 7], change: 7, grace: 0, dom: 7, roll: 0.04, rootless: false,
         chords: [Chord("Am", 9, [9, 0, 4]), Chord("F", 5, [5, 9, 0]), Chord("C", 0, [0, 4, 7]), Chord("G", 7, [7, 11, 2]),
                  Chord("Am", 9, [9, 0, 4, 7]), Chord("Dm", 2, [2, 5, 9]), Chord("F", 5, [5, 9, 0, 4]), Chord("E", 4, [4, 8, 11])]),
    Song(name: "Verträumt", reverb: 0.50, scale: [5, 7, 9, 0, 2, 4], change: 7, grace: 0, dom: 3, roll: 0.05, rootless: false,
         chords: [Chord("Fmaj7", 5, [5, 9, 0, 4]), Chord("Dm9", 2, [2, 5, 9, 4]),
                  Chord("B♭maj7", 10, [10, 2, 5, 9]), Chord("Cadd9", 0, [0, 4, 7, 2])]),
]

// MARK: - Hilfen

func mtof(_ m: Int) -> Double { 440.0 * pow(2.0, Double(m - 69) / 12.0) }
func clamp<T: Comparable>(_ v: T, _ lo: T, _ hi: T) -> T { max(lo, min(hi, v)) }

/// Kleiner, reproduzierbarer Zufallsgenerator (SplitMix64).
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> Double {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z = z ^ (z >> 31)
        return Double(z >> 11) / Double(1 << 53)
    }
}
