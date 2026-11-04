import Foundation

/// Erzeugt Muhen und Miauen per Formant-Synthese (keine Aufnahmen nötig).
enum AnimalSynth {
    static let sr = 44100.0

    private struct Formant { let center: [Double]; let bw: Double; let gain: Double }

    private static func interp(_ x: Double, _ xs: [Double], _ ys: [Double]) -> Double {
        if x <= xs[0] { return ys[0] }
        for i in 1..<xs.count where x <= xs[i] {
            let a = (x - xs[i - 1]) / (xs[i] - xs[i - 1])
            return ys[i - 1] + a * (ys[i] - ys[i - 1])
        }
        return ys[ys.count - 1]
    }

    private static func voice(f0: [Double], formants: [Formant], env: [Double], tilt: Double, fmax: Double) -> [Double] {
        let n = f0.count
        var phase = [Double](repeating: 0, count: n)
        var acc = 0.0
        for i in 0..<n { acc += 2 * .pi * f0[i] / sr; phase[i] = acc }
        let minF = f0.min() ?? 100
        let kMax = max(1, Int(fmax / minF))
        var out = [Double](repeating: 0, count: n)
        for k in 1...kMax {
            let kd = Double(k)
            let weight = pow(kd, -tilt)
            for i in 0..<n {
                let fk = kd * f0[i]
                if fk > fmax * 1.3 { continue }
                var g = 0.02
                for f in formants {
                    let d = (fk - f.center[i]) / f.bw
                    g += f.gain * exp(-0.5 * d * d)
                }
                out[i] += g * weight * sin(kd * phase[i])
            }
        }
        for i in 0..<n { out[i] *= env[i] }
        return out
    }

    private static func normalized(_ x: [Double], peak: Double) -> [Float] {
        let m = x.map { abs($0) }.max() ?? 1
        let s = peak / max(m, 1e-9)
        return x.map { Float($0 * s) }
    }

    static func cow(midi: Int, short: Bool) -> [Float] {
        let f = mtof(midi)
        let dur = short ? 0.7 : 1.35
        let n = Int(sr * dur)
        var f0 = [Double](repeating: 0, count: n), F1 = f0, F2 = f0, env = f0, F3 = f0
        let seed = Double(midi)
        for i in 0..<n {
            let t = Double(i) / sr, x = t / dur
            let wob = 1 + 0.01 * (0.6 * sin(2 * .pi * 1.3 * t + seed) + 0.4 * sin(2 * .pi * 2.7 * t + 2 * seed))
            f0[i] = f * interp(x, [0, 0.2, 0.55, 1], [0.9, 1.06, 1.0, 0.78])
                * (1 + 0.012 * sin(2 * .pi * 5.2 * t) * min(1, t / 0.3)) * wob
            F1[i] = interp(x, [0, 0.12, 0.5, 1], [260, 520, 480, 330])
            F2[i] = interp(x, [0, 0.12, 0.5, 1], [900, 880, 820, 700])
            F3[i] = 2600
            env[i] = pow(interp(x, [0, 0.14, 0.75, 1], [0, 1, 0.85, 0]), 1.2)
        }
        var out = voice(f0: f0, formants: [Formant(center: F1, bw: 90, gain: 1.0),
                                           Formant(center: F2, bw: 120, gain: 0.5),
                                           Formant(center: F3, bw: 300, gain: 0.08)],
                        env: env, tilt: 0.5, fmax: 4500)
        let peak = out.map { abs($0) }.max() ?? 1
        // etwas Atem
        var rng = SeededRandom(seed: UInt64(midi) &* 7919)
        var smooth = 0.0
        for i in 0..<n {
            smooth = smooth * 0.92 + (rng.next() * 2 - 1) * 0.08
            out[i] = out[i] / max(peak, 1e-9) + smooth * env[i] * 0.25
        }
        return normalized(out, peak: 0.32)
    }

    static func cat(midi: Int, short: Bool) -> [Float] {
        let f = mtof(midi)
        let dur = short ? 0.42 : 0.75
        let n = Int(sr * dur)
        var f0 = [Double](repeating: 0, count: n), F1 = f0, F2 = f0, env = f0, F3 = f0
        let seed = Double(midi)
        for i in 0..<n {
            let t = Double(i) / sr, x = t / dur
            let wob = 1 + 0.008 * (0.6 * sin(2 * .pi * 1.7 * t + seed) + 0.4 * sin(2 * .pi * 3.1 * t + 2 * seed))
            let vib = 1 + 0.015 * sin(2 * .pi * 6 * t) * clamp((x - 0.3) * 3, 0, 1)
            f0[i] = f * interp(x, [0, 0.25, 0.6, 1], [0.92, 1.12, 1.05, 0.82]) * vib * wob
            F1[i] = interp(x, [0, 0.12, 0.4, 0.75, 1], [300, 350, 950, 700, 420])
            F2[i] = interp(x, [0, 0.12, 0.4, 0.75, 1], [1300, 2400, 1600, 1100, 900])
            F3[i] = 3300
            env[i] = interp(x, [0, 0.08, 0.7, 1], [0, 1, 0.8, 0])
        }
        let out = voice(f0: f0, formants: [Formant(center: F1, bw: 110, gain: 1.0),
                                           Formant(center: F2, bw: 150, gain: 0.7),
                                           Formant(center: F3, bw: 400, gain: 0.15)],
                        env: env, tilt: 0.7, fmax: 7000)
        return normalized(out, peak: 0.28)
    }
}
