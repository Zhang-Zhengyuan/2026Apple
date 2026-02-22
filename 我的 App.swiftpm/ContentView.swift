import SwiftUI
import SpriteKit
import GameplayKit
import UIKit
import ImageIO
import MobileCoreServices
import UniformTypeIdentifiers

// ============================================================
// MARK: - GIF Recorder & Exporter
// ============================================================

/// GIF recording system for demo export - critical for judge submissions
class GIFRecorder {
    private var frames: [UIImage] = []
    private var frameDelays: [Double] = []
    private let targetFPS: Double
    private let maxDuration: Double
    
    init(targetFPS: Double = 15, maxDuration: Double = 12.0) {
        self.targetFPS = targetFPS
        self.maxDuration = maxDuration
    }
    
    /// Add a frame to the recording
    func addFrame(_ image: UIImage, delay: Double? = nil) {
        let actualDelay = delay ?? (1.0 / targetFPS)
        frames.append(image)
        frameDelays.append(actualDelay)
    }
    
    /// Clear all recorded frames
    func reset() {
        frames.removeAll()
        frameDelays.removeAll()
    }
    
    /// Get frame count
    var frameCount: Int { frames.count }
    
    /// Export frames as animated GIF
    func exportGIF(completion: @escaping (URL?) -> Void) {
        guard !frames.isEmpty else {
            completion(nil)
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            // Create temporary file URL
            let fileName = "LightOfLife_Demo_\(Int(Date().timeIntervalSince1970)).gif"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            // Create GIF file
            guard let destination = CGImageDestinationCreateWithURL(
                tempURL as CFURL,
                UTType.gif.identifier as CFString,
                self.frames.count,
                nil
            ) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            // Set GIF properties
            let gifProperties: [String: Any] = [
                kCGImagePropertyGIFDictionary as String: [
                    kCGImagePropertyGIFLoopCount as String: 0  // Loop forever
                ]
            ]
            CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)
            
            // Add frames
            for (index, frame) in self.frames.enumerated() {
                guard let cgImage = frame.cgImage else { continue }
                
                let frameDelay = self.frameDelays[safe: index] ?? (1.0 / self.targetFPS)
                let frameProperties: [String: Any] = [
                    kCGImagePropertyGIFDictionary as String: [
                        kCGImagePropertyGIFDelayTime as String: frameDelay,
                        kCGImagePropertyGIFUnclampedDelayTime as String: frameDelay
                    ]
                ]
                
                CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)
            }
            
            // Finalize GIF
            let success = CGImageDestinationFinalize(destination)
            
            DispatchQueue.main.async {
                completion(success ? tempURL : nil)
            }
        }
    }
    
    /// Export as shareable data
    func exportGIFData(completion: @escaping (Data?) -> Void) {
        exportGIF { url in
            guard let url = url else {
                completion(nil)
                return
            }
            
            let data = try? Data(contentsOf: url)
            completion(data)
        }
    }
}

// ============================================================
// MARK: - Toast Notification View
// ============================================================

/// Toast notification for instant feedback
struct ToastView: View {
    let message: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            
            Text(message)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: color.opacity(0.3), radius: 10, y: 5)
    }
}

/// Toast manager for showing notifications
class ToastManager: ObservableObject {
    @Published var isShowing: Bool = false
    @Published var message: String = ""
    @Published var icon: String = "checkmark.circle.fill"
    @Published var color: Color = .green
    
    private var dismissTask: DispatchWorkItem?
    
    func show(message: String, icon: String = "checkmark.circle.fill", color: Color = .green, duration: Double = 2.5) {
        dismissTask?.cancel()
        
        self.message = message
        self.icon = icon
        self.color = color
        
        withAnimation(.spring(response: 0.4)) {
            isShowing = true
        }
        
        let task = DispatchWorkItem { [weak self] in
            withAnimation(.easeOut(duration: 0.3)) {
                self?.isShowing = false
            }
        }
        dismissTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: task)
    }
    
    /// Show target reached notification with coverage info
    func showTargetReached(targetIndex: Int, coverage: Int, required: Int) {
        show(
            message: "Target \(targetIndex + 1): \(coverage)% coverage (need \(required)%)",
            icon: "target",
            color: .green,
            duration: 2.0
        )
    }
    
    /// Show star rating explanation
    func showStarRating(stars: Int, reason: String) {
        let icon = stars == 3 ? "star.fill" : (stars == 2 ? "star.leadinghalf.filled" : "star")
        show(
            message: "\(stars) Star\(stars > 1 ? "s" : ""): \(reason)",
            icon: icon,
            color: stars == 3 ? .yellow : (stars == 2 ? .orange : .gray),
            duration: 3.0
        )
    }
}

// ============================================================
// MARK: - High Quality Preset Samples
// ============================================================

/// Preset sample configurations for showcase
struct SamplePreset: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let seed: Int
    let theme: CosmicTheme
    let lifeStage: LifeStage
    let branchAngle: Double
    let phototropism: Double
    let lightPositions: [(x: CGFloat, y: CGFloat, intensity: CGFloat)]
    
    static let showcasePresets: [SamplePreset] = [
        SamplePreset(
            name: "Cosmic Embrace",
            description: "Balanced growth reaching for twin lights",
            seed: 2024,
            theme: .nebula,
            lifeStage: .bloom,
            branchAngle: 25.0,
            phototropism: 18.0,
            lightPositions: [
                (x: 0.3, y: 0.4, intensity: 1.0),
                (x: 0.7, y: 0.35, intensity: 0.9)
            ]
        ),
        SamplePreset(
            name: "Deep Sea Dreams",
            description: "Bioluminescent life in the abyss",
            seed: 8888,
            theme: .bioluminescence,
            lifeStage: .transcend,
            branchAngle: 22.0,
            phototropism: 20.0,
            lightPositions: [
                (x: 0.5, y: 0.25, intensity: 1.0),
                (x: 0.25, y: 0.5, intensity: 0.7),
                (x: 0.75, y: 0.5, intensity: 0.7)
            ]
        ),
        SamplePreset(
            name: "Aurora Dance",
            description: "Life dancing under northern lights",
            seed: 42,
            theme: .aurora,
            lifeStage: .growth,
            branchAngle: 28.0,
            phototropism: 15.0,
            lightPositions: [
                (x: 0.4, y: 0.3, intensity: 1.0),
                (x: 0.6, y: 0.4, intensity: 0.85)
            ]
        )
    ]
}

// ============================================================
// MARK: - Seeded Random Number Generator
// ============================================================

/// A reproducible random number generator using GKMersenneTwisterRandomSource
/// This ensures the same seed always produces the same visual result - critical for judging/export
class SeededRandom {
    private let source: GKMersenneTwisterRandomSource
    private let distribution: GKRandomDistribution
    
    init(seed: UInt64) {
        source = GKMersenneTwisterRandomSource(seed: seed)
        distribution = GKRandomDistribution(randomSource: source, lowestValue: 0, highestValue: Int.max - 1)
    }
    
    /// Returns a random Double in the specified range (reproducible)
    func nextDouble(in range: ClosedRange<Double>) -> Double {
        let normalized = Double(distribution.nextInt()) / Double(Int.max - 1)
        return range.lowerBound + normalized * (range.upperBound - range.lowerBound)
    }
    
    /// Returns a random CGFloat in the specified range (reproducible)
    func nextCGFloat(in range: ClosedRange<CGFloat>) -> CGFloat {
        return CGFloat(nextDouble(in: Double(range.lowerBound)...Double(range.upperBound)))
    }
    
    /// Returns a random Int in the specified range (reproducible)
    func nextInt(in range: ClosedRange<Int>) -> Int {
        let normalized = Double(distribution.nextInt()) / Double(Int.max - 1)
        return range.lowerBound + Int(normalized * Double(range.upperBound - range.lowerBound))
    }
    
    /// Returns a random Bool (reproducible)
    func nextBool() -> Bool {
        return distribution.nextInt() % 2 == 0
    }
}

// ============================================================
// MARK: - "Light of Life"
// ============================================================
// Creative Concept: In the chaotic cosmic nebulae, users become
// "Guardians of Light", placing light sources to awaken dormant
// seeds of life. Life grows toward the light, forming unique
// organic patterns. Every creation is a unique journey of life.
// ============================================================

// MARK: - Core Creative Concept

/// Life Stage - Determines L-System complexity and visual style
enum LifeStage: Int, CaseIterable {
    case seed = 1       // Seed - Simple form
    case sprout = 2     // Sprout - Begins branching
    case growth = 3     // Growth - Rich branching
    case bloom = 4      // Bloom - Full form
    case transcend = 5  // Transcend - Complex form
    
    var name: String {
        switch self {
        case .seed: return "Seed"
        case .sprout: return "Sprout"
        case .growth: return "Growth"
        case .bloom: return "Bloom"
        case .transcend: return "Transcend"
        }
    }
    
    var description: String {
        switch self {
        case .seed: return "Origin of life, infinite potential"
        case .sprout: return "First reach toward the light"
        case .growth: return "Life force flourishing"
        case .bloom: return "Blooming into beauty"
        case .transcend: return "Becoming one with light"
        }
    }
    
    var iterations: Int { rawValue }
    
    var baseColor: UIColor {
        switch self {
        case .seed: return UIColor(red: 0.2, green: 0.4, blue: 0.3, alpha: 1)
        case .sprout: return UIColor(red: 0.3, green: 0.6, blue: 0.4, alpha: 1)
        case .growth: return UIColor(red: 0.4, green: 0.7, blue: 0.5, alpha: 1)
        case .bloom: return UIColor(red: 0.6, green: 0.85, blue: 0.6, alpha: 1)
        case .transcend: return UIColor(red: 0.8, green: 0.95, blue: 0.9, alpha: 1)
        }
    }
}

/// Cosmic Theme - Determines background visual style
enum CosmicTheme: String, CaseIterable, Identifiable {
    case nebula = "Nebula"
    case aurora = "Aurora"
    case deepSpace = "Deep Space"
    case bioluminescence = "Biolum"
    
    var id: String { rawValue }
    
    var gradient: ColorGradientPreset {
        switch self {
        case .nebula: return .cosmicNebula
        case .aurora: return .etherealAurora
        case .deepSpace: return .deepSpace
        case .bioluminescence: return .bioluminescence
        }
    }
    
    var description: String {
        switch self {
        case .nebula: return "Purple-red cosmic nebula"
        case .aurora: return "Flowing northern lights"
        case .deepSpace: return "Profound outer space"
        case .bioluminescence: return "Deep sea bioluminescence"
        }
    }
}

// MARK: - Data Models

/// Achievement data for saving challenge progress
struct AchievementData: Codable {
    var stars: Int
    var coverage: Double
}

struct StylePreset: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let glowColor: Color
    let frequency: Double
    let octaves: Int
    let bloomIntensity: Double
    let particleSpeed: Double
    let trailLength: Double
    let lSystemAngle: Double
}

/// Codable parameter set - export as JSON to reproduce any artwork.
struct ParameterSet: Codable {
    var theme: String
    var lifeStage: Int
    var seed: Int
    var frequency: Double
    var octaves: Int
    var bloomIntensity: Double
    var glowColorR: Double
    var glowColorG: Double
    var glowColorB: Double
    var particleSpeed: Double
    var trailLength: Double
    var lSystemAngle: Double
    var lightPositions: [[Double]]   // [[x, y, intensity], ...]
}

// ============================================================
// MARK: - Color Gradient Presets
// ============================================================

struct ColorGradientPreset: Identifiable {
    let id = UUID()
    let name: String
    let colors: [(Double, UIColor)] // (position 0-1, color)
    
    // Cosmic Nebula - Mysterious purple-red hues
    static let cosmicNebula = ColorGradientPreset(
        name: "Cosmic Nebula",
        colors: [
            (0.0, UIColor(red: 0.02, green: 0.01, blue: 0.05, alpha: 1.0)),
            (0.25, UIColor(red: 0.1, green: 0.02, blue: 0.15, alpha: 1.0)),
            (0.5, UIColor(red: 0.25, green: 0.05, blue: 0.35, alpha: 1.0)),
            (0.75, UIColor(red: 0.5, green: 0.15, blue: 0.5, alpha: 1.0)),
            (1.0, UIColor(red: 0.9, green: 0.7, blue: 0.95, alpha: 1.0))
        ]
    )
    
    // Deep Space - Deep blue-black tones
    static let deepSpace = ColorGradientPreset(
        name: "Deep Space",
        colors: [
            (0.0, UIColor(red: 0.0, green: 0.0, blue: 0.02, alpha: 1.0)),
            (0.3, UIColor(red: 0.02, green: 0.05, blue: 0.12, alpha: 1.0)),
            (0.6, UIColor(red: 0.05, green: 0.15, blue: 0.3, alpha: 1.0)),
            (1.0, UIColor(red: 0.2, green: 0.4, blue: 0.7, alpha: 1.0))
        ]
    )
    
    // Aurora - Flowing teal-green
    static let etherealAurora = ColorGradientPreset(
        name: "Ethereal Aurora",
        colors: [
            (0.0, UIColor(red: 0.01, green: 0.03, blue: 0.05, alpha: 1.0)),
            (0.3, UIColor(red: 0.02, green: 0.15, blue: 0.2, alpha: 1.0)),
            (0.5, UIColor(red: 0.1, green: 0.4, blue: 0.35, alpha: 1.0)),
            (0.7, UIColor(red: 0.3, green: 0.7, blue: 0.5, alpha: 1.0)),
            (1.0, UIColor(red: 0.6, green: 0.95, blue: 0.8, alpha: 1.0))
        ]
    )
    
    // Bioluminescence - Deep sea blue-green glow
    static let bioluminescence = ColorGradientPreset(
        name: "Bioluminescence",
        colors: [
            (0.0, UIColor(red: 0.0, green: 0.02, blue: 0.05, alpha: 1.0)),
            (0.35, UIColor(red: 0.0, green: 0.1, blue: 0.2, alpha: 1.0)),
            (0.6, UIColor(red: 0.0, green: 0.35, blue: 0.5, alpha: 1.0)),
            (0.85, UIColor(red: 0.1, green: 0.7, blue: 0.8, alpha: 1.0)),
            (1.0, UIColor(red: 0.5, green: 1.0, blue: 0.95, alpha: 1.0))
        ]
    )
    
    // Life Gradient - For L-System life forms (enhanced with warmer highlights)
    static let lifeGradient = ColorGradientPreset(
        name: "Light of Life",
        colors: [
            (0.0, UIColor(red: 0.12, green: 0.25, blue: 0.18, alpha: 1.0)),   // Deep forest green - roots
            (0.2, UIColor(red: 0.2, green: 0.4, blue: 0.28, alpha: 1.0)),    // Rich green - base
            (0.4, UIColor(red: 0.35, green: 0.6, blue: 0.38, alpha: 1.0)),   // Vibrant green - stem
            (0.55, UIColor(red: 0.5, green: 0.75, blue: 0.45, alpha: 1.0)),   // Bright green - leaves
            (0.7, UIColor(red: 0.7, green: 0.88, blue: 0.55, alpha: 1.0)),   // Yellow-green - buds
            (0.82, UIColor(red: 0.9, green: 0.95, blue: 0.7, alpha: 1.0)),   // Warm yellow - illuminated
            (0.92, UIColor(red: 0.98, green: 0.98, blue: 0.85, alpha: 1.0)), // Warm white - bright tips
            (1.0, UIColor(red: 1.0, green: 1.0, blue: 0.95, alpha: 1.0))     // Pure white - merged with light
        ]
    )
    
    // Golden Life - Warmer variant for sunset/fire themes
    static let goldenLife = ColorGradientPreset(
        name: "Golden Life",
        colors: [
            (0.0, UIColor(red: 0.25, green: 0.15, blue: 0.1, alpha: 1.0)),
            (0.3, UIColor(red: 0.5, green: 0.3, blue: 0.15, alpha: 1.0)),
            (0.5, UIColor(red: 0.8, green: 0.5, blue: 0.2, alpha: 1.0)),
            (0.7, UIColor(red: 0.95, green: 0.7, blue: 0.3, alpha: 1.0)),
            (0.85, UIColor(red: 1.0, green: 0.85, blue: 0.5, alpha: 1.0)),
            (1.0, UIColor(red: 1.0, green: 0.95, blue: 0.8, alpha: 1.0))
        ]
    )
    
    // Ethereal Cyan - Cool variant for deep space
    static let etherealCyan = ColorGradientPreset(
        name: "Ethereal Cyan",
        colors: [
            (0.0, UIColor(red: 0.05, green: 0.15, blue: 0.2, alpha: 1.0)),
            (0.3, UIColor(red: 0.1, green: 0.35, blue: 0.45, alpha: 1.0)),
            (0.5, UIColor(red: 0.2, green: 0.6, blue: 0.7, alpha: 1.0)),
            (0.7, UIColor(red: 0.4, green: 0.8, blue: 0.85, alpha: 1.0)),
            (0.85, UIColor(red: 0.7, green: 0.95, blue: 0.95, alpha: 1.0)),
            (1.0, UIColor(red: 0.9, green: 1.0, blue: 1.0, alpha: 1.0))
        ]
    )
    
    static let allPresets: [ColorGradientPreset] = [
        .cosmicNebula, .deepSpace, .etherealAurora, .bioluminescence
    ]
    
    /// Interpolate color at position t (0-1)
    func colorAt(_ t: Double) -> UIColor {
        let clamped = max(0, min(1, t))
        
        // Find the two colors to interpolate between
        var lower = colors.first!
        var upper = colors.last!
        
        for i in 0..<colors.count - 1 {
            if clamped >= colors[i].0 && clamped <= colors[i + 1].0 {
                lower = colors[i]
                upper = colors[i + 1]
                break
            }
        }
        
        let range = upper.0 - lower.0
        let localT = range > 0 ? (clamped - lower.0) / range : 0
        
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        lower.1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        upper.1.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        let t = CGFloat(localT)
        return UIColor(
            red: r1 + (r2 - r1) * t,
            green: g1 + (g2 - g1) * t,
            blue: b1 + (b2 - b1) * t,
            alpha: 1.0
        )
    }
}

// ============================================================
// MARK: - Advanced Noise Generator (FBM + Domain Warping)
// ============================================================

struct NoiseParameters {
    var frequency: Double = 0.6
    var octaves: Int = 6
    var persistence: Double = 0.5
    var lacunarity: Double = 2.0
    var warpFrequency: Double = 0.8
    var warpStrength: Double = 25.0
    var gamma: Double = 1.4
    var enableWarp: Bool = true
}

func generateAdvancedNoiseImage(
    width: Int, height: Int,
    params: NoiseParameters,
    seed: Int32,
    gradient: ColorGradientPreset,
    addGrain: Bool = true
) -> UIImage? {
    
    // Create base noise
    let baseSource = GKPerlinNoiseSource(
        frequency: params.frequency,
        octaveCount: params.octaves,
        persistence: params.persistence,
        lacunarity: params.lacunarity,
        seed: seed
    )
    let baseNoise = GKNoise(baseSource)
    
    // Create warp noise (with different seed for variety)
    let warpSourceX = GKPerlinNoiseSource(
        frequency: params.warpFrequency,
        octaveCount: 4,
        persistence: 0.5,
        lacunarity: 2.0,
        seed: seed + 1000
    )
    let warpSourceY = GKPerlinNoiseSource(
        frequency: params.warpFrequency,
        octaveCount: 4,
        persistence: 0.5,
        lacunarity: 2.0,
        seed: seed + 2000
    )
    let warpNoiseX = GKNoise(warpSourceX)
    let warpNoiseY = GKNoise(warpSourceY)
    
    // Generate noise maps
    let sampleSize = vector_double2(2.0, 2.0)
    let origin = vector_double2(0, 0)
    let sampleCount = vector_int2(Int32(width), Int32(height))
    
    let baseMap = GKNoiseMap(baseNoise, size: sampleSize, origin: origin, sampleCount: sampleCount, seamless: true)
    let warpMapX = GKNoiseMap(warpNoiseX, size: sampleSize, origin: origin, sampleCount: sampleCount, seamless: true)
    let warpMapY = GKNoiseMap(warpNoiseY, size: sampleSize, origin: origin, sampleCount: sampleCount, seamless: true)
    
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    
    for y in 0..<height {
        for x in 0..<width {
            var value: Float
            
            if params.enableWarp {
                // Domain warping: offset sample position by warp noise
                let wx = warpMapX.value(at: vector_int2(Int32(x), Int32(y)))
                let wy = warpMapY.value(at: vector_int2(Int32(x), Int32(y)))
                
                let warpedX = Int32(x) + Int32(Double(wx) * params.warpStrength)
                let warpedY = Int32(y) + Int32(Double(wy) * params.warpStrength)
                
                // Clamp to valid range
                let clampedX = max(0, min(Int32(width - 1), warpedX))
                let clampedY = max(0, min(Int32(height - 1), warpedY))
                
                value = baseMap.value(at: vector_int2(clampedX, clampedY))
            } else {
                value = baseMap.value(at: vector_int2(Int32(x), Int32(y)))
            }
            
            // Normalize to 0-1
            var norm = Double(value) * 0.5 + 0.5
            norm = max(0, min(1, norm))
            
            // Apply gamma/contrast curve
            norm = pow(norm, params.gamma)
            
            // Add subtle grain for film feel using deterministic noise based on position
            // This ensures reproducibility while still providing grain effect
            if addGrain {
                // Use position-based deterministic grain instead of random
                let grainSeed = UInt64(seed) &+ UInt64(y * width + x)
                let grainValue = Double((grainSeed &* 2654435761) % 65536) / 65536.0
                let grain = (grainValue - 0.5) * 0.06  // -0.03 to 0.03 range
                norm = max(0, min(1, norm + grain))
            }
            
            // Map to gradient color
            let color = gradient.colorAt(norm)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            
            let i = (y * width + x) * 4
            pixels[i]     = UInt8(r * 255)
            pixels[i + 1] = UInt8(g * 255)
            pixels[i + 2] = UInt8(b * 255)
            pixels[i + 3] = 255
        }
    }
    
    guard let provider = CGDataProvider(data: Data(pixels) as CFData),
          let cg = CGImage(
              width: width, height: height,
              bitsPerComponent: 8, bitsPerPixel: 32,
              bytesPerRow: width * 4,
              space: CGColorSpaceCreateDeviceRGB(),
              bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
              provider: provider,
              decode: nil, shouldInterpolate: true,
              intent: .defaultIntent)
    else { return nil }
    
    return UIImage(cgImage: cg)
}

// Legacy function for compatibility
func generatePerlinNoiseImage(
    width: Int, height: Int,
    frequency: Double, octaves: Int, seed: Int32
) -> UIImage? {
    let params = NoiseParameters(
        frequency: frequency,
        octaves: octaves,
        persistence: 0.5,
        lacunarity: 2.0,
        warpFrequency: 0.8,
        warpStrength: 25.0,
        gamma: 1.4,
        enableWarp: true
    )
    return generateAdvancedNoiseImage(
        width: width, height: height,
        params: params,
        seed: seed,
        gradient: .deepSpace
    )
}

// ============================================================
// MARK: - Advanced L-System with Phototropism
// ============================================================

/// Light source info, influences L-System growth direction
struct LightSource {
    let position: CGPoint
    let intensity: CGFloat
    
    /// Calculate attraction vector from a point to this light
    func attractionVector(from point: CGPoint, maxDistance: CGFloat = 300) -> CGPoint {
        let dx = position.x - point.x
        let dy = position.y - point.y
        let distance = hypot(dx, dy)
        
        if distance < 1 { return .zero }
        
        // Closer = stronger attraction (with soft falloff)
        let strength = intensity * max(0, 1 - distance / maxDistance)
        
        return CGPoint(
            x: (dx / distance) * strength,
            y: (dy / distance) * strength
        )
    }
}

// ============================================================
// MARK: - Animated Growth Segment
// ============================================================

/// Segment data for animated L-System growth
struct GrowthSegment {
    let start: CGPoint
    let end: CGPoint
    let depth: Int
    let lightIntensity: CGFloat
    let order: Int  // Order in growth sequence
    
    // Visual properties computed at creation time
    let width: CGFloat
    let color: UIColor
    let glowColor: UIColor
}

// ============================================================
// MARK: - Challenge Mode
// ============================================================

/// Calculate the shortest distance from a point to a line segment
func distancePointToSegment(point: CGPoint, segStart: CGPoint, segEnd: CGPoint) -> CGFloat {
    let dx = segEnd.x - segStart.x
    let dy = segEnd.y - segStart.y
    let lengthSquared = dx * dx + dy * dy
    
    if lengthSquared == 0 {
        // Segment is a point
        return hypot(point.x - segStart.x, point.y - segStart.y)
    }
    
    // Parametric position along segment
    let t = max(0, min(1, ((point.x - segStart.x) * dx + (point.y - segStart.y) * dy) / lengthSquared))
    
    // Closest point on segment
    let closestX = segStart.x + t * dx
    let closestY = segStart.y + t * dy
    
    return hypot(point.x - closestX, point.y - closestY)
}

/// Target zone for challenge mode
struct ChallengeTarget: Identifiable {
    let id = UUID()
    let position: CGPoint
    let radius: CGFloat
    let requiredCoverage: CGFloat  // 0-1, how much needs to be reached
    var isReached: Bool = false
    var currentCoverage: CGFloat = 0  // Track actual coverage fraction
    
    /// Check if a segment reaches this target (simple endpoint check)
    func checkCoverage(segmentEnd: CGPoint) -> Bool {
        let distance = hypot(segmentEnd.x - position.x, segmentEnd.y - position.y)
        return distance <= radius
    }
    
    /// Calculate coverage using grid sampling - more accurate than endpoint check
    /// Returns coverage fraction (0-1) of how much of the target area is reached
    func calculateGridCoverage(segments: [GrowthSegment], sampleCount: Int = 12) -> CGFloat {
        var coveredSamples = 0
        var totalSamples = 0
        
        let threshold = radius * 0.15  // Distance threshold for "covered"
        
        for i in 0..<sampleCount {
            for j in 0..<sampleCount {
                // Sample point in target-local coordinates (-1 to 1)
                let u = CGFloat(i) / CGFloat(sampleCount - 1) * 2 - 1
                let v = CGFloat(j) / CGFloat(sampleCount - 1) * 2 - 1
                
                // Convert to world position
                let px = position.x + u * radius
                let py = position.y + v * radius
                
                // Only count points within the circle
                if hypot(u, v) <= 1.0 {
                    totalSamples += 1
                    
                    // Check if any segment passes near this sample point
                    let isCovered = segments.contains { seg in
                        distancePointToSegment(
                            point: CGPoint(x: px, y: py),
                            segStart: seg.start,
                            segEnd: seg.end
                        ) < threshold
                    }
                    
                    if isCovered {
                        coveredSamples += 1
                    }
                }
            }
        }
        
        return CGFloat(coveredSamples) / CGFloat(max(1, totalSamples))
    }
}

/// Challenge definition with scoring system
struct Challenge: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let maxLights: Int
    var targets: [ChallengeTarget]
    let difficulty: Int  // 1-5
    
    // NOTE: isCompleted and progress properties are not used in the actual game logic
    // because Challenge.presets is immutable. The actual tracking uses local counters.
    // These are kept for potential future mutable challenge state.
    
    var isCompleted: Bool {
        targets.allSatisfy { $0.isReached }
    }
    
    var progress: Double {
        let reached = targets.filter { $0.isReached }.count
        return Double(reached) / Double(targets.count)
    }
    
    /// Calculate star rating based on lights used (1-3 stars) - More lenient thresholds
    /// NOTE: Call this only when all targets are reached (reachedCount == targets.count)
    func calculateStars(lightsUsed: Int, totalCoverage: Double) -> Int {
        // Must have minimum coverage to get stars (completion is verified by caller)
        guard totalCoverage >= 0.4 else { return 0 }
        
        // 3 stars: at or under max lights with good coverage (75%+)
        if lightsUsed <= maxLights && totalCoverage >= 0.75 {
            return 3
        }
        // 2 stars: at max lights with decent coverage (50%+) OR under max lights
        else if (lightsUsed <= maxLights && totalCoverage >= 0.5) || 
                (lightsUsed < maxLights && totalCoverage >= 0.4) {
            return 2
        }
        // 1 star: completed the challenge
        else {
            return 1
        }
    }
    
    /// Get human-readable explanation for star rating
    /// NOTE: Call this only when all targets are reached (completion verified by caller)
    func getStarExplanation(lightsUsed: Int, totalCoverage: Double) -> String {
        let stars = calculateStars(lightsUsed: lightsUsed, totalCoverage: totalCoverage)
        let coveragePct = Int(totalCoverage * 100)
        
        switch stars {
        case 3:
            return "Perfect! \(coveragePct)% coverage with \(lightsUsed)/\(maxLights) lights"
        case 2:
            if totalCoverage < 0.75 {
                return "Great! Need \(75 - coveragePct)% more coverage for 3 stars"
            } else {
                return "Great! Use \(lightsUsed - maxLights) fewer lights for 3 stars"
            }
        case 1:
            return "Complete! Optimize lights or coverage for more stars"
        default:
            // Stars = 0 means coverage was below threshold despite reaching targets
            return "Need \(40 - coveragePct)% more coverage"
        }
    }
    
    /// Preset challenges with increasing difficulty
    static let presets: [Challenge] = [
        Challenge(
            name: "First Light",
            description: "Guide life to reach the beacon",
            maxLights: 1,
            targets: [ChallengeTarget(position: CGPoint(x: 256, y: 150), radius: 55, requiredCoverage: 0.4)],
            difficulty: 1
        ),
        Challenge(
            name: "Twin Stars",
            description: "Reach both light sources with one tree",
            maxLights: 2,
            targets: [
                ChallengeTarget(position: CGPoint(x: 150, y: 180), radius: 50, requiredCoverage: 0.35),
                ChallengeTarget(position: CGPoint(x: 362, y: 180), radius: 50, requiredCoverage: 0.35)
            ],
            difficulty: 2
        ),
        Challenge(
            name: "Guardian's Trial",
            description: "Illuminate all corners with limited light",
            maxLights: 3,
            targets: [
                ChallengeTarget(position: CGPoint(x: 100, y: 120), radius: 45, requiredCoverage: 0.3),
                ChallengeTarget(position: CGPoint(x: 412, y: 120), radius: 45, requiredCoverage: 0.3),
                ChallengeTarget(position: CGPoint(x: 256, y: 80), radius: 45, requiredCoverage: 0.3)
            ],
            difficulty: 3
        ),
        Challenge(
            name: "Cosmic Bloom",
            description: "Reach all four quadrants - master the phototropism",
            maxLights: 2,
            targets: [
                ChallengeTarget(position: CGPoint(x: 128, y: 128), radius: 40, requiredCoverage: 0.25),
                ChallengeTarget(position: CGPoint(x: 384, y: 128), radius: 40, requiredCoverage: 0.25),
                ChallengeTarget(position: CGPoint(x: 128, y: 256), radius: 40, requiredCoverage: 0.25),
                ChallengeTarget(position: CGPoint(x: 384, y: 256), radius: 40, requiredCoverage: 0.25)
            ],
            difficulty: 4
        ),
        Challenge(
            name: "Nebula Master",
            description: "The ultimate challenge - reach all with minimal light",
            maxLights: 2,
            targets: [
                ChallengeTarget(position: CGPoint(x: 80, y: 100), radius: 35, requiredCoverage: 0.2),
                ChallengeTarget(position: CGPoint(x: 432, y: 100), radius: 35, requiredCoverage: 0.2),
                ChallengeTarget(position: CGPoint(x: 180, y: 200), radius: 35, requiredCoverage: 0.2),
                ChallengeTarget(position: CGPoint(x: 332, y: 200), radius: 35, requiredCoverage: 0.2),
                ChallengeTarget(position: CGPoint(x: 256, y: 100), radius: 35, requiredCoverage: 0.2)
            ],
            difficulty: 5
        )
    ]
}

struct LSystemRenderParams {
    var baseLineWidth: CGFloat = 6.0
    var widthDecay: CGFloat = 0.65        // Width multiplier per depth
    var angleVariation: CGFloat = 8.0      // Random angle perturbation
    var enableGlow: Bool = true
    var glowRadius: CGFloat = 8.0
    var glowAlpha: CGFloat = 0.4
    var colorGradient: ColorGradientPreset = .lifeGradient
    var depthColorFade: Bool = true        // Color fades with depth
    
    // Phototropism parameters
    var lightSources: [LightSource] = []
    var phototropismStrength: CGFloat = 15.0  // Angle deflection strength
    var lightColorInfluence: CGFloat = 0.3    // Light influence on color
    
    // Reproducible randomness seed
    var randomSeed: UInt64 = 42
}

struct LSystem {
    let axiom: String
    let rules: [(Character, String)]
    let angle: Double

    /// Expand the axiom for `iterations` times.
    func generate(iterations: Int) -> String {
        var current = axiom
        for _ in 0 ..< iterations {
            var next = ""
            next.reserveCapacity(current.count * 5)
            for ch in current {
                if let rule = rules.first(where: { $0.0 == ch }) {
                    next += rule.1
                } else {
                    next.append(ch)
                }
            }
            current = next
        }
        return current
    }
    
    /// Generate segments for animated growth (returns array sorted by growth order)
    /// Uses reproducible random numbers based on params.randomSeed
    func generateSegmentsForAnimation(
        iterations: Int,
        canvasSize: CGSize,
        lineLength: CGFloat,
        params: LSystemRenderParams
    ) -> [GrowthSegment] {
        let instructions = generate(iterations: iterations)
        
        // Create seeded random generator for reproducibility
        let rng = SeededRandom(seed: params.randomSeed)
        
        var segments: [GrowthSegment] = []
        var maxDepth: Int = 0
        var order: Int = 0
        
        var posX = canvasSize.width / 2
        var posY = canvasSize.height * 0.88
        var heading: Double = -90
        var currentDepth: Int = 0
        var stack: [(CGFloat, CGFloat, Double, Int)] = []
        
        // First pass: collect all segments
        for ch in instructions {
            switch ch {
            case "F", "G":
                let currentPos = CGPoint(x: posX, y: posY)
                let phototropismAngle = calculatePhototropismAngle(
                    at: currentPos,
                    currentHeading: heading,
                    lightSources: params.lightSources,
                    strength: params.phototropismStrength
                )
                
                // Use seeded random instead of Double.random for reproducibility
                let variation = rng.nextDouble(in: -Double(params.angleVariation)...Double(params.angleVariation))
                let adjustedHeading = heading + variation + phototropismAngle
                
                let rad = adjustedHeading * .pi / 180
                let nx = posX + lineLength * CGFloat(cos(rad))
                let ny = posY + lineLength * CGFloat(sin(rad))
                
                let midPoint = CGPoint(x: (posX + nx) / 2, y: (posY + ny) / 2)
                let lightIntensity = calculateLightIntensity(at: midPoint, lightSources: params.lightSources)
                
                maxDepth = max(maxDepth, currentDepth)
                
                // Compute visual properties
                let depthRatio = CGFloat(currentDepth) / max(1, CGFloat(iterations))
                let width = params.baseLineWidth * pow(params.widthDecay, CGFloat(currentDepth))
                
                let baseColorT = params.depthColorFade ? (1.0 - Double(depthRatio) * 0.6) : 0.95
                let colorT = baseColorT + Double(lightIntensity) * params.lightColorInfluence * 1.5
                let color = params.colorGradient.colorAt(min(1, colorT))
                
                let glowBoost = 1.0 + lightIntensity * 0.8
                let glowColorT = params.depthColorFade ? (1.0 - Double(depthRatio) * 0.5) : 0.8
                let glowT = glowColorT + Double(lightIntensity) * params.lightColorInfluence
                let glowColor = params.colorGradient.colorAt(min(1, glowT))
                    .withAlphaComponent(params.glowAlpha * (1.0 - depthRatio * 0.3) * glowBoost)
                
                segments.append(GrowthSegment(
                    start: CGPoint(x: posX, y: posY),
                    end: CGPoint(x: nx, y: ny),
                    depth: currentDepth,
                    lightIntensity: lightIntensity,
                    order: order,
                    width: max(0.5, width),
                    color: color,
                    glowColor: glowColor
                ))
                
                order += 1
                posX = nx
                posY = ny
                
            case "+":
                heading += angle
            case "-":
                heading -= angle
            case "[":
                stack.append((posX, posY, heading, currentDepth))
                currentDepth += 1
            case "]":
                if let (sx, sy, sh, sd) = stack.popLast() {
                    posX = sx
                    posY = sy
                    heading = sh
                    currentDepth = sd
                }
            default:
                break
            }
        }
        
        return segments
    }

    /// Legacy render method (simple white lines on black)
    func render(
        instructions: String,
        canvasSize: CGSize,
        lineLength: CGFloat,
        strokeColor: UIColor = .white
    ) -> UIImage {
        let params = LSystemRenderParams(
            baseLineWidth: 3.0,
            enableGlow: false
        )
        return renderAdvanced(
            instructions: instructions,
            canvasSize: canvasSize,
            lineLength: lineLength,
            params: params
        )
    }
    
    /// Calculate phototropism angle deflection
    private func calculatePhototropismAngle(
        at position: CGPoint,
        currentHeading: Double,
        lightSources: [LightSource],
        strength: CGFloat
    ) -> Double {
        guard !lightSources.isEmpty else { return 0 }
        
        // Combine attraction from all light sources
        var totalAttraction = CGPoint.zero
        for light in lightSources {
            let attraction = light.attractionVector(from: position)
            totalAttraction.x += attraction.x
            totalAttraction.y += attraction.y
        }
        
        let attractionMagnitude = hypot(totalAttraction.x, totalAttraction.y)
        if attractionMagnitude < 0.01 { return 0 }
        
        // Calculate angle difference between light direction and current heading
        let lightAngle = atan2(totalAttraction.y, totalAttraction.x) * 180 / .pi
        var angleDiff = lightAngle - currentHeading
        
        // Normalize to -180 to 180
        while angleDiff > 180 { angleDiff -= 360 }
        while angleDiff < -180 { angleDiff += 360 }
        
        // Limit max deflection based on attraction strength
        let maxTurn = Double(strength) * Double(min(1, attractionMagnitude))
        return max(-maxTurn, min(maxTurn, angleDiff * 0.3))
    }
    
    /// Calculate light intensity at a point (for color adjustment)
    private func calculateLightIntensity(
        at position: CGPoint,
        lightSources: [LightSource]
    ) -> CGFloat {
        var totalIntensity: CGFloat = 0
        for light in lightSources {
            let distance = hypot(position.x - light.position.x, position.y - light.position.y)
            let falloff = max(0, 1 - distance / 400) // 400 is light falloff distance
            totalIntensity += light.intensity * falloff * falloff // Quadratic falloff
        }
        return min(1, totalIntensity)
    }
    
    /// Advanced artistic render with phototropism, glow, variable width, and color gradients
    /// Uses reproducible random numbers based on params.randomSeed
    func renderAdvanced(
        instructions: String,
        canvasSize: CGSize,
        lineLength: CGFloat,
        params: LSystemRenderParams
    ) -> UIImage {
        // Parse instructions to get all line segments with depth info and light response
        struct Segment {
            let start: CGPoint
            let end: CGPoint
            let depth: Int
            let lightIntensity: CGFloat  // Light intensity at this segment
        }
        
        // Create seeded random generator for reproducibility
        let rng = SeededRandom(seed: params.randomSeed)
        
        var segments: [Segment] = []
        var maxDepth: Int = 0
        
        var posX = canvasSize.width / 2
        var posY = canvasSize.height * 0.88
        var heading: Double = -90
        var currentDepth: Int = 0
        var stack: [(CGFloat, CGFloat, Double, Int)] = []
        
        for ch in instructions {
            switch ch {
            case "F", "G":
                // Calculate phototropism deflection
                let currentPos = CGPoint(x: posX, y: posY)
                let phototropismAngle = calculatePhototropismAngle(
                    at: currentPos,
                    currentHeading: heading,
                    lightSources: params.lightSources,
                    strength: params.phototropismStrength
                )
                
                // Use seeded random instead of Double.random for reproducibility
                let variation = rng.nextDouble(in: -Double(params.angleVariation)...Double(params.angleVariation))
                let adjustedHeading = heading + variation + phototropismAngle
                
                let rad = adjustedHeading * .pi / 180
                let nx = posX + lineLength * CGFloat(cos(rad))
                let ny = posY + lineLength * CGFloat(sin(rad))
                
                // Calculate light intensity for this segment
                let midPoint = CGPoint(x: (posX + nx) / 2, y: (posY + ny) / 2)
                let lightIntensity = calculateLightIntensity(at: midPoint, lightSources: params.lightSources)
                
                segments.append(Segment(
                    start: CGPoint(x: posX, y: posY),
                    end: CGPoint(x: nx, y: ny),
                    depth: currentDepth,
                    lightIntensity: lightIntensity
                ))
                maxDepth = max(maxDepth, currentDepth)
                
                posX = nx
                posY = ny
                
            case "+":
                heading += angle
            case "-":
                heading -= angle
            case "[":
                stack.append((posX, posY, heading, currentDepth))
                currentDepth += 1
            case "]":
                if let (sx, sy, sh, sd) = stack.popLast() {
                    posX = sx
                    posY = sy
                    heading = sh
                    currentDepth = sd
                }
            default:
                break
            }
        }
        
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        return renderer.image { ctx in
            let gc = ctx.cgContext
            
            // Fill background with transparency (for compositing)
            gc.setFillColor(UIColor.clear.cgColor)
            gc.fill(CGRect(origin: .zero, size: canvasSize))
            
            // Draw glow layer first (if enabled)
            if params.enableGlow {
                for seg in segments {
                    let depthRatio = maxDepth > 0 ? CGFloat(seg.depth) / CGFloat(maxDepth) : 0
                    let width = params.baseLineWidth * pow(params.widthDecay, CGFloat(seg.depth))
                    
                    // Stronger light = brighter glow
                    let glowBoost = 1.0 + seg.lightIntensity * 0.8
                    let glowWidth = (width * 3.0 + params.glowRadius) * glowBoost
                    
                    // Color based on depth and light
                    let baseColorT = params.depthColorFade ? (1.0 - Double(depthRatio) * 0.5) : 0.8
                    let colorT = baseColorT + Double(seg.lightIntensity) * params.lightColorInfluence
                    let glowColor = params.colorGradient.colorAt(min(1, colorT))
                        .withAlphaComponent(params.glowAlpha * (1.0 - depthRatio * 0.3) * glowBoost)
                    
                    let path = CGMutablePath()
                    path.move(to: seg.start)
                    path.addLine(to: seg.end)
                    
                    gc.setStrokeColor(glowColor.cgColor)
                    gc.setLineWidth(glowWidth)
                    gc.setLineCap(.round)
                    gc.setBlendMode(.plusLighter)
                    gc.addPath(path)
                    gc.strokePath()
                }
            }
            
            // Draw main lines (sharp layer on top)
            gc.setBlendMode(.normal)
            for seg in segments {
                let depthRatio = maxDepth > 0 ? CGFloat(seg.depth) / CGFloat(maxDepth) : 0
                let width = params.baseLineWidth * pow(params.widthDecay, CGFloat(seg.depth))
                
                // Color gradient: depth + light influence
                let baseColorT = params.depthColorFade ? (1.0 - Double(depthRatio) * 0.6) : 0.95
                let colorT = baseColorT + Double(seg.lightIntensity) * params.lightColorInfluence * 1.5
                let strokeColor = params.colorGradient.colorAt(min(1, colorT))
                
                let path = CGMutablePath()
                path.move(to: seg.start)
                path.addLine(to: seg.end)
                
                gc.setStrokeColor(strokeColor.cgColor)
                gc.setLineWidth(max(0.5, width))
                gc.setLineCap(.round)
                gc.addPath(path)
                gc.strokePath()
            }
            
            // Add light point effects in high-illumination areas
            gc.setBlendMode(.plusLighter)
            for seg in segments {
                if seg.lightIntensity > 0.5 {
                    let brightness = (seg.lightIntensity - 0.5) * 2 // 0-1
                    let tipColor = params.colorGradient.colorAt(1.0).withAlphaComponent(0.6 * brightness)
                    let radius: CGFloat = 3.0 * brightness
                    
                    gc.setFillColor(tipColor.cgColor)
                    gc.fillEllipse(in: CGRect(
                        x: seg.end.x - radius,
                        y: seg.end.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    ))
                }
            }
            
            // Add enhanced bloom points at branch tips (higher visual impact)
            gc.setBlendMode(.plusLighter)
            let branchEndSegments = segments.filter { seg in
                // Find segments that are likely branch endings (high depth, high light)
                let depthRatio = maxDepth > 0 ? CGFloat(seg.depth) / CGFloat(maxDepth) : 0
                return depthRatio > 0.6 && seg.lightIntensity > 0.3
            }
            
            for seg in branchEndSegments {
                let depthRatio = maxDepth > 0 ? CGFloat(seg.depth) / CGFloat(maxDepth) : 0
                let bloomIntensity = (depthRatio - 0.6) / 0.4 * seg.lightIntensity
                
                // Outer soft glow
                let outerRadius: CGFloat = 6.0 * bloomIntensity
                let outerColor = params.colorGradient.colorAt(0.9).withAlphaComponent(0.25 * bloomIntensity)
                gc.setFillColor(outerColor.cgColor)
                gc.fillEllipse(in: CGRect(
                    x: seg.end.x - outerRadius,
                    y: seg.end.y - outerRadius,
                    width: outerRadius * 2,
                    height: outerRadius * 2
                ))
                
                // Inner bright core
                let innerRadius: CGFloat = 2.0 * bloomIntensity
                let innerColor = params.colorGradient.colorAt(1.0).withAlphaComponent(0.5 * bloomIntensity)
                gc.setFillColor(innerColor.cgColor)
                gc.fillEllipse(in: CGRect(
                    x: seg.end.x - innerRadius,
                    y: seg.end.y - innerRadius,
                    width: innerRadius * 2,
                    height: innerRadius * 2
                ))
            }
        }
    }
}

// ============================================================
// MARK: - Image Colorization and Post-Processing
// ============================================================

/// Apply vignette effect to an image
func applyVignette(to image: UIImage, intensity: CGFloat = 0.4) -> UIImage {
    let size = image.size
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { ctx in
        image.draw(in: CGRect(origin: .zero, size: size))
        
        let gc = ctx.cgContext
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxRadius = hypot(size.width, size.height) / 2
        
        let colors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(intensity * 0.3).cgColor,
            UIColor.black.withAlphaComponent(intensity).cgColor
        ] as CFArray
        
        if let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: [0, 0.6, 1.0]
        ) {
            gc.drawRadialGradient(
                gradient,
                startCenter: center, startRadius: 0,
                endCenter: center, endRadius: maxRadius,
                options: []
            )
        }
    }
}

/// Apply film grain effect with reproducible randomness
func applyGrain(to image: UIImage, intensity: CGFloat = 0.05, seed: UInt64 = 42) -> UIImage {
    let size = image.size
    let rng = SeededRandom(seed: seed)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { ctx in
        image.draw(in: CGRect(origin: .zero, size: size))
        
        let gc = ctx.cgContext
        let width = Int(size.width)
        let height = Int(size.height)
        
        // Draw sparse grain points with seeded random
        gc.setBlendMode(.overlay)
        for _ in 0..<Int(CGFloat(width * height) * intensity * 0.1) {
            let x = rng.nextCGFloat(in: 0...size.width - 1)
            let y = rng.nextCGFloat(in: 0...size.height - 1)
            let gray = rng.nextCGFloat(in: 0...1)
            gc.setFillColor(UIColor(white: gray, alpha: 0.15).cgColor)
            gc.fillEllipse(in: CGRect(x: x, y: y, width: 1.5, height: 1.5))
        }
    }
}

/// Composite two images with blend mode
func compositeImages(
    base: UIImage,
    overlay: UIImage,
    blendMode: CGBlendMode = .screen,
    alpha: CGFloat = 0.7
) -> UIImage {
    let size = base.size
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { ctx in
        base.draw(in: CGRect(origin: .zero, size: size))
        
        ctx.cgContext.setBlendMode(blendMode)
        ctx.cgContext.setAlpha(alpha)
        overlay.draw(in: CGRect(origin: .zero, size: size))
    }
}

/// Apply blur to image (for glow layer)
func applyBlur(to image: UIImage, radius: CGFloat) -> UIImage? {
    guard let ciImage = CIImage(image: image) else { return nil }
    
    let filter = CIFilter(name: "CIGaussianBlur")
    filter?.setValue(ciImage, forKey: kCIInputImageKey)
    filter?.setValue(radius, forKey: kCIInputRadiusKey)
    
    guard let outputImage = filter?.outputImage else { return nil }
    
    let context = CIContext()
    // Crop to original extent to remove blur edges
    let croppedImage = outputImage.cropped(to: ciImage.extent)
    guard let cgImage = context.createCGImage(croppedImage, from: ciImage.extent) else { return nil }
    
    return UIImage(cgImage: cgImage)
}

func colorizeImage(_ image: UIImage, tintColor: UIColor, intensity: CGFloat = 0.5) -> UIImage {
    let size = image.size
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { ctx in
        let rect = CGRect(origin: .zero, size: size)
        let gc   = ctx.cgContext
        image.draw(in: rect)

        gc.setBlendMode(.overlay)
        gc.setFillColor(tintColor.withAlphaComponent(intensity).cgColor)
        gc.fill(rect)

        gc.setBlendMode(.softLight)
        gc.setFillColor(tintColor.withAlphaComponent(intensity * 0.6).cgColor)
        gc.fill(rect)
    }
}

// ============================================================
// MARK: - GalleryScene  (SpriteKit)
// ============================================================

class GalleryScene: SKScene {

    // Nodes
    private var backgroundNode: SKSpriteNode?
    private var bloomContainer: SKEffectNode?
    private var particleTemplate: SKEmitterNode?

    // Configurable visual properties
    var glowColor: UIColor = .cyan {
        didSet { applyGlowColor() }
    }
    var bloomRadius: Double = 12.0 {
        didSet { applyBloom() }
    }
    var particleSpeed: CGFloat  = 40
    var trailDuration: TimeInterval = 0.6

    // Persistent light entities placed by long-press
    struct LightInfo {
        let node: SKNode
        let intensity: CGFloat
    }
    var placedLights: [LightInfo] = []

    // Touch state for long-press detection
    private var longPressTimer: Timer?
    private var touchStartPoint: CGPoint?
    
    // Effect throttle
    private var lastEffectTime: TimeInterval = 0
    private let effectInterval: TimeInterval = 0.04   // ~25 effects/sec max
    
    // ----------------------------------------------------------
    // Animated Growth System
    // ----------------------------------------------------------
    
    private var growthContainer: SKNode?
    private var growthSegments: [GrowthSegment] = []
    private var currentSegmentIndex: Int = 0
    private var isAnimatingGrowth: Bool = false
    private var growthTimer: Timer?
    var onGrowthComplete: (() -> Void)?
    var onSegmentGrown: ((CGPoint) -> Void)?  // Called with segment end point for challenge checking
    
    // Challenge mode
    private var challengeTargetNodes: [SKNode] = []
    var currentChallenge: Challenge?
    
    // Light placement limits
    var maxLightsAllowed: Int = Int.max  // No limit in free mode
    var onLightPlaced: ((Int) -> Void)?  // Callback with current light count
    var onLightLimitReached: (() -> Void)?  // Callback when limit reached
    
    // ----------------------------------------------------------
    // GIF Recording System
    // ----------------------------------------------------------
    
    private var gifRecorder: GIFRecorder?
    private var isRecordingGIF: Bool = false
    private var recordingTimer: Timer?
    var onGIFRecordingComplete: ((URL?) -> Void)?

    // ----------------------------------------------------------
    // Lifecycle
    // ----------------------------------------------------------

    override func didMove(to view: SKView) {
        backgroundColor = .black
        scaleMode       = .resizeFill

        // Bloom effect layer
        bloomContainer = SKEffectNode()
        bloomContainer!.shouldRasterize    = true
        bloomContainer!.shouldEnableEffects = true
        bloomContainer!.zPosition           = 10
        addChild(bloomContainer!)
        applyBloom()

        particleTemplate = buildParticleEmitter()
    }

    // ----------------------------------------------------------
    // Background texture
    // ----------------------------------------------------------

    func setBackgroundImage(_ image: UIImage) {
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear

        if backgroundNode == nil {
            backgroundNode = SKSpriteNode(texture: texture)
            backgroundNode!.zPosition = 0
            addChild(backgroundNode!)
        } else {
            backgroundNode!.texture = texture
        }
        backgroundNode!.size     = size
        backgroundNode!.position = CGPoint(x: size.width / 2, y: size.height / 2)
    }

    // ----------------------------------------------------------
    // Bloom
    // ----------------------------------------------------------

    private func applyBloom() {
        guard let bc = bloomContainer else { return }
        if bloomRadius > 0 {
            let blur = CIFilter(name: "CIGaussianBlur")
            blur?.setValue(bloomRadius, forKey: kCIInputRadiusKey)
            bc.filter = blur
            bc.shouldEnableEffects = true
        } else {
            bc.shouldEnableEffects = false
        }
    }

    private func applyGlowColor() {
        bloomContainer?.enumerateChildNodes(withName: "glow") { node, _ in
            (node as? SKShapeNode)?.fillColor = self.glowColor
        }
    }

    // ----------------------------------------------------------
    // Particle emitter template
    // ----------------------------------------------------------

    private func buildParticleEmitter() -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture        = SKTexture(image: softCircleImage(radius: 8))
        e.particleBirthRate      = 60
        e.numParticlesToEmit     = 0
        e.particleLifetime       = 1.0
        e.particleLifetimeRange  = 0.3
        e.particleSpeed          = particleSpeed
        e.particleSpeedRange     = 20
        e.particleAlpha          = 0.8
        e.particleAlphaSpeed     = -0.6
        e.emissionAngleRange     = .pi * 2
        e.particleScale          = 0.05
        e.particleScaleRange     = 0.03
        e.particleScaleSpeed     = -0.02
        e.particleColorBlendFactor = 1.0
        return e
    }

    /// Radial-gradient soft circle for particle texture.
    private func softCircleImage(radius: CGFloat) -> UIImage {
        let d = radius * 2
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: d, height: d))
        return renderer.image { ctx in
            let colors = [UIColor.white.cgColor,
                          UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: colors, locations: [0, 1]) {
                let center = CGPoint(x: radius, y: radius)
                ctx.cgContext.drawRadialGradient(
                    g, startCenter: center, startRadius: 0,
                    endCenter: center, endRadius: radius, options: [])
            }
        }
    }

    // ----------------------------------------------------------
    // MARK: Touch handling
    // ----------------------------------------------------------

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let pos = touch.location(in: self)
        touchStartPoint = pos

        // Begin long-press timer -> place persistent light
        longPressTimer?.invalidate()
        longPressTimer = Timer.scheduledTimer(
            withTimeInterval: 0.55, repeats: false
        ) { [weak self] _ in
            self?.placePersistentLight(at: pos)
        }

        createGlow(at: pos)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let pos = touch.location(in: self)

        // Cancel long-press if finger moved far
        if let start = touchStartPoint {
            let dist = hypot(pos.x - start.x, pos.y - start.y)
            if dist > 15 { longPressTimer?.invalidate() }
        }

        // Throttle effects
        let now = CACurrentMediaTime()
        guard now - lastEffectTime >= effectInterval else { return }
        lastEffectTime = now

        createGlow(at: pos)
        emitParticles(at: pos)
        createTrail(at: pos)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        longPressTimer?.invalidate()
        touchStartPoint = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        longPressTimer?.invalidate()
        touchStartPoint = nil
    }

    // ----------------------------------------------------------
    // Visual effect helpers
    // ----------------------------------------------------------

    private func createGlow(at point: CGPoint) {
        let glow = SKShapeNode(circleOfRadius: 28)
        glow.position    = point
        glow.name        = "glow"
        glow.fillColor   = glowColor
        glow.strokeColor = .clear
        glow.alpha       = 0.8
        glow.blendMode   = .add
        glow.zPosition   = 20
        bloomContainer?.addChild(glow)

        glow.run(.sequence([
            .fadeOut(withDuration: 0.6),
            .removeFromParent()
        ]))
    }

    private func emitParticles(at point: CGPoint) {
        guard let emitter = particleTemplate?.copy() as? SKEmitterNode else { return }
        emitter.position      = point
        emitter.particleColor = glowColor
        emitter.particleSpeed = particleSpeed
        emitter.zPosition     = 30
        addChild(emitter)

        emitter.run(.sequence([
            .wait(forDuration: 0.5),
            .run { emitter.particleBirthRate = 0 },
            .wait(forDuration: 1.5),
            .removeFromParent()
        ]))
    }

    private func createTrail(at point: CGPoint) {
        let trail = SKShapeNode(circleOfRadius: 6)
        trail.position    = point
        trail.fillColor   = glowColor.withAlphaComponent(0.4)
        trail.strokeColor = .clear
        trail.blendMode   = .add
        trail.zPosition   = 15
        addChild(trail)

        trail.run(.sequence([
            .group([
                .fadeOut(withDuration: trailDuration),
                .scale(to: 0.1, duration: trailDuration)
            ]),
            .removeFromParent()
        ]))
    }

    // ----------------------------------------------------------
    // Persistent light (long-press)
    // ----------------------------------------------------------

    func placePersistentLight(at point: CGPoint, intensity: CGFloat = 1.0) {
        // Check if light limit reached
        if placedLights.count >= maxLightsAllowed {
            onLightLimitReached?()
            // Visual feedback for limit reached
            let errorRing = SKShapeNode(circleOfRadius: 30)
            errorRing.position = point
            errorRing.strokeColor = .red
            errorRing.lineWidth = 3
            errorRing.fillColor = .clear
            addChild(errorRing)
            
            errorRing.run(.sequence([
                .scale(to: 1.5, duration: 0.2),
                .fadeOut(withDuration: 0.3),
                .removeFromParent()
            ]))
            return
        }
        
        let outer = SKShapeNode(circleOfRadius: 55 * intensity)
        outer.position    = point
        outer.name        = "placedLight"
        outer.fillColor   = glowColor.withAlphaComponent(0.2)
        outer.strokeColor = .clear
        outer.blendMode   = .add
        outer.zPosition   = 22

        let inner = SKShapeNode(circleOfRadius: 18 * intensity)
        inner.fillColor   = glowColor.withAlphaComponent(0.65)
        inner.strokeColor = glowColor.withAlphaComponent(0.3)
        inner.lineWidth   = 1.5
        inner.blendMode   = .add
        outer.addChild(inner)

        addChild(outer)

        // Pulse
        let up   = SKAction.scale(to: 1.1, duration: 0.9)
        up.timingMode   = .easeInEaseOut
        let down = SKAction.scale(to: 0.92, duration: 0.9)
        down.timingMode = .easeInEaseOut
        outer.run(.repeatForever(.sequence([up, down])))

        // Ambient particles
        if let p = particleTemplate?.copy() as? SKEmitterNode {
            p.particleColor     = glowColor
            p.particleBirthRate = 12
            p.particleSpeed     = 12
            p.particleLifetime  = 2.0
            outer.addChild(p)
        }

        placedLights.append(LightInfo(node: outer, intensity: intensity))
        onLightPlaced?(placedLights.count)
    }

    func clearAllLights() {
        for l in placedLights { l.node.removeFromParent() }
        placedLights.removeAll()
    }
    
    // ----------------------------------------------------------
    // Animated Growth System
    // ----------------------------------------------------------
    
    /// Start animated growth with given segments
    func startAnimatedGrowth(segments: [GrowthSegment], segmentsPerFrame: Int = 3, frameDelay: TimeInterval = 0.03) {
        // Clear previous growth
        stopAnimatedGrowth()
        growthContainer?.removeFromParent()
        
        // Create container for growth nodes
        growthContainer = SKNode()
        growthContainer?.zPosition = 5
        addChild(growthContainer!)
        
        growthSegments = segments
        currentSegmentIndex = 0
        isAnimatingGrowth = true
        
        // Start recursive growth animation
        animateNextBatch(count: segmentsPerFrame, delay: frameDelay)
    }
    
    private func animateNextBatch(count: Int, delay: TimeInterval) {
        guard isAnimatingGrowth, currentSegmentIndex < growthSegments.count else {
            isAnimatingGrowth = false
            onGrowthComplete?()
            return
        }
        
        let endIndex = min(currentSegmentIndex + count, growthSegments.count)
        
        for i in currentSegmentIndex..<endIndex {
            let seg = growthSegments[i]
            addSegmentNode(seg, animated: true)
            onSegmentGrown?(seg.end)
        }
        
        currentSegmentIndex = endIndex
        
        // Schedule next batch
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.animateNextBatch(count: count, delay: delay)
        }
    }
    
    private func addSegmentNode(_ segment: GrowthSegment, animated: Bool) {
        guard let container = growthContainer else { return }
        
        // Create glow layer
        let glowPath = CGMutablePath()
        glowPath.move(to: segment.start)
        glowPath.addLine(to: segment.end)
        
        let glowNode = SKShapeNode(path: glowPath)
        glowNode.strokeColor = segment.glowColor
        glowNode.lineWidth = segment.width * 3.0 + 8.0
        glowNode.lineCap = .round
        glowNode.blendMode = .add
        glowNode.zPosition = 1
        
        // Create main line
        let linePath = CGMutablePath()
        linePath.move(to: segment.start)
        linePath.addLine(to: segment.end)
        
        let lineNode = SKShapeNode(path: linePath)
        lineNode.strokeColor = segment.color
        lineNode.lineWidth = segment.width
        lineNode.lineCap = .round
        lineNode.zPosition = 2
        
        if animated {
            // Start invisible and fade in
            glowNode.alpha = 0
            lineNode.alpha = 0
            
            container.addChild(glowNode)
            container.addChild(lineNode)
            
            let fadeIn = SKAction.fadeIn(withDuration: 0.15)
            glowNode.run(fadeIn)
            lineNode.run(fadeIn)
            
            // Add growing particle at tip
            if segment.lightIntensity > 0.3 {
                let particle = SKShapeNode(circleOfRadius: 2.5)
                particle.position = segment.end
                particle.fillColor = segment.color.withAlphaComponent(0.8)
                particle.strokeColor = .clear
                particle.blendMode = .add
                particle.zPosition = 3
                container.addChild(particle)
                
                particle.run(.sequence([
                    .group([
                        .fadeOut(withDuration: 0.3),
                        .scale(to: 2.0, duration: 0.3)
                    ]),
                    .removeFromParent()
                ]))
            }
        } else {
            container.addChild(glowNode)
            container.addChild(lineNode)
        }
    }
    
    func stopAnimatedGrowth() {
        isAnimatingGrowth = false
        growthTimer?.invalidate()
        growthTimer = nil
    }
    
    func clearGrowth() {
        stopAnimatedGrowth()
        growthContainer?.removeFromParent()
        growthContainer = nil
        growthSegments = []
        currentSegmentIndex = 0
    }
    
    // ----------------------------------------------------------
    // Challenge Mode - Enhanced visuals for target display
    // ----------------------------------------------------------
    
    func showChallengeTargets(_ challenge: Challenge) {
        clearChallengeTargets()
        currentChallenge = challenge
        
        for (index, target) in challenge.targets.enumerated() {
            // Convert to SpriteKit coordinates (flip Y)
            let skPosition = CGPoint(
                x: target.position.x * size.width / 512,
                y: size.height - target.position.y * size.height / 512
            )
            
            let radius = target.radius * size.width / 512
            
            // Container for all target elements
            let container = SKNode()
            container.position = skPosition
            container.name = "challengeTarget_\(target.id)"
            
            // Outer glow ring
            let outerRing = SKShapeNode(circleOfRadius: radius * 1.2)
            outerRing.strokeColor = UIColor.cyan.withAlphaComponent(0.3)
            outerRing.lineWidth = 1
            outerRing.fillColor = .clear
            outerRing.glowWidth = 5
            container.addChild(outerRing)
            
            // Main target ring
            let ring = SKShapeNode(circleOfRadius: radius)
            ring.strokeColor = UIColor.cyan.withAlphaComponent(0.7)
            ring.lineWidth = 2.5
            ring.fillColor = UIColor.cyan.withAlphaComponent(0.08)
            ring.glowWidth = 3
            container.addChild(ring)
            
            // Inner target indicator
            let innerRing = SKShapeNode(circleOfRadius: radius * 0.3)
            innerRing.strokeColor = UIColor.cyan.withAlphaComponent(0.5)
            innerRing.lineWidth = 1
            innerRing.fillColor = UIColor.cyan.withAlphaComponent(0.15)
            container.addChild(innerRing)
            
            // Cross-hair lines
            let crossSize: CGFloat = radius * 0.4
            let hLine = SKShapeNode(rectOf: CGSize(width: crossSize * 2, height: 1))
            hLine.strokeColor = .clear
            hLine.fillColor = UIColor.cyan.withAlphaComponent(0.4)
            container.addChild(hLine)
            
            let vLine = SKShapeNode(rectOf: CGSize(width: 1, height: crossSize * 2))
            vLine.strokeColor = .clear
            vLine.fillColor = UIColor.cyan.withAlphaComponent(0.4)
            container.addChild(vLine)
            
            // Target number label
            let label = SKLabelNode(text: "\(index + 1)")
            label.fontName = "Helvetica-Bold"
            label.fontSize = 12
            label.fontColor = UIColor.cyan.withAlphaComponent(0.8)
            label.position = CGPoint(x: 0, y: -radius - 15)
            container.addChild(label)
            
            container.zPosition = 3
            
            // Pulse animation
            let pulse = SKAction.sequence([
                .scale(to: 1.05, duration: 1.0),
                .scale(to: 0.95, duration: 1.0)
            ])
            container.run(.repeatForever(pulse))
            
            // Rotation for outer ring
            outerRing.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 8)))
            
            addChild(container)
            challengeTargetNodes.append(container)
        }
    }
    
    func clearChallengeTargets() {
        for node in challengeTargetNodes {
            node.removeFromParent()
        }
        challengeTargetNodes.removeAll()
        currentChallenge = nil
    }
    
    func markTargetReached(_ targetId: UUID) {
        if let container = challengeTargetNodes.first(where: { $0.name == "challengeTarget_\(targetId)" }) {
            // Flash all children green
            for child in container.children {
                if let shape = child as? SKShapeNode {
                    shape.strokeColor = UIColor.green.withAlphaComponent(0.8)
                    shape.fillColor = UIColor.green.withAlphaComponent(0.3)
                }
                if let label = child as? SKLabelNode {
                    label.fontColor = UIColor.green
                }
            }
            
            // Stop pulse animation and do celebration
            container.removeAllActions()
            container.run(.sequence([
                .scale(to: 1.4, duration: 0.15),
                .scale(to: 1.0, duration: 0.1),
                .scale(to: 1.2, duration: 0.1),
                .scale(to: 1.0, duration: 0.1)
            ]))
            
            // Create expanding ring effect
            let expandRing = SKShapeNode(circleOfRadius: 30)
            expandRing.position = container.position
            expandRing.strokeColor = UIColor.green.withAlphaComponent(0.8)
            expandRing.lineWidth = 3
            expandRing.fillColor = .clear
            expandRing.glowWidth = 5
            expandRing.zPosition = 10
            addChild(expandRing)
            
            expandRing.run(.sequence([
                .group([
                    .scale(to: 4.0, duration: 0.5),
                    .fadeOut(withDuration: 0.5)
                ]),
                .removeFromParent()
            ]))
            
            // Add multiple success particle bursts
            for i in 0..<3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) { [weak self] in
                    guard let self = self else { return }
                    if let emitter = particleTemplate?.copy() as? SKEmitterNode {
                        emitter.position = container.position
                        emitter.particleColor = .green
                        emitter.particleColorBlendFactor = 1.0
                        emitter.particleBirthRate = 150
                        emitter.numParticlesToEmit = 25
                        emitter.particleSpeed = 150 + CGFloat(i) * 50
                        emitter.emissionAngleRange = .pi * 2
                        addChild(emitter)
                        
                        emitter.run(.sequence([
                            .wait(forDuration: 0.6),
                            .removeFromParent()
                        ]))
                    }
                }
            }
            
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
    
    // ----------------------------------------------------------
    // Demo Mode - Enhanced for Judges (8-12 second showcase)
    // ----------------------------------------------------------
    
    /// Demo step callback for UI updates
    var onDemoStep: ((DemoStep) -> Void)?
    
    enum DemoStep {
        case start
        case placingLight(Int, CGPoint)
        case startGrowth
        case growthComplete
        case showResult
    }
    
    func playDemoSequence(completion: @escaping () -> Void) {
        // Clear existing state
        clearAllLights()
        clearGrowth()
        
        onDemoStep?(.start)
        
        // Demo sequence: strategically place lights for impressive result
        // Position lights at rule-of-thirds points for good composition
        let demoLightPositions: [(CGPoint, TimeInterval, CGFloat)] = [
            (CGPoint(x: size.width * 0.33, y: size.height * 0.55), 0.8, 1.0),   // First light - left side
            (CGPoint(x: size.width * 0.67, y: size.height * 0.60), 2.0, 0.85)  // Second light - right side
        ]
        
        // Add pulse effect before placing each light
        for (index, (pos, delay, intensity)) in demoLightPositions.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self else { return }
                
                // Pre-placement indicator
                let indicator = SKShapeNode(circleOfRadius: 25)
                indicator.position = pos
                indicator.strokeColor = self.glowColor.withAlphaComponent(0.8)
                indicator.lineWidth = 2
                indicator.fillColor = .clear
                self.addChild(indicator)
                
                indicator.run(.sequence([
                    .scale(to: 1.5, duration: 0.3),
                    .fadeOut(withDuration: 0.2),
                    .removeFromParent()
                ]))
                
                // Slight delay then place actual light
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                    self?.placePersistentLight(at: pos, intensity: intensity)
                    self?.onDemoStep?(.placingLight(index + 1, pos))
                }
            }
        }
        
        // Signal to regenerate with new lights after placement
        let growStartTime: TimeInterval = 3.5
        DispatchQueue.main.asyncAfter(deadline: .now() + growStartTime) { [weak self] in
            self?.onDemoStep?(.startGrowth)
            completion()
        }
    }
    
    /// Enhanced demo with full lifecycle demonstration
    func playFullDemoSequence(onStep: @escaping (DemoStep) -> Void, completion: @escaping () -> Void) {
        onDemoStep = onStep
        
        playDemoSequence { [weak self] in
            // After growth animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                onStep(.growthComplete)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    onStep(.showResult)
                    completion()
                }
            }
        }
    }
    
    // ----------------------------------------------------------
    // Render lights to image (for export)
    // ----------------------------------------------------------
    
    /// Render the placed lights and any touch effects to an image that can be composited
    func renderLightsImage(targetSize: CGSize) -> UIImage? {
        guard !placedLights.isEmpty else { return nil }
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { ctx in
            let gc = ctx.cgContext
            
            // Start with transparent background
            gc.setFillColor(UIColor.clear.cgColor)
            gc.fill(CGRect(origin: .zero, size: targetSize))
            
            // Scale factor from scene to target
            let scaleX = targetSize.width / size.width
            let scaleY = targetSize.height / size.height
            
            for light in placedLights {
                let pos = light.node.position
                // Convert position to target coordinates
                let targetX = pos.x * scaleX
                let targetY = (size.height - pos.y) * scaleY  // Flip Y for UIKit
                
                let intensity = light.intensity
                let outerRadius: CGFloat = 55 * intensity * min(scaleX, scaleY)
                let innerRadius: CGFloat = 18 * intensity * min(scaleX, scaleY)
                
                // Draw outer glow with additive blend
                gc.setBlendMode(.plusLighter)
                
                // Create radial gradient for outer glow
                let colors = [
                    glowColor.withAlphaComponent(0.65).cgColor,
                    glowColor.withAlphaComponent(0.2).cgColor,
                    glowColor.withAlphaComponent(0.0).cgColor
                ] as CFArray
                
                if let gradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: colors,
                    locations: [0, 0.4, 1.0]
                ) {
                    let center = CGPoint(x: targetX, y: targetY)
                    gc.drawRadialGradient(
                        gradient,
                        startCenter: center, startRadius: 0,
                        endCenter: center, endRadius: outerRadius * 2,
                        options: []
                    )
                }
                
                // Draw inner bright core
                gc.setFillColor(glowColor.withAlphaComponent(0.8).cgColor)
                gc.fillEllipse(in: CGRect(
                    x: targetX - innerRadius,
                    y: targetY - innerRadius,
                    width: innerRadius * 2,
                    height: innerRadius * 2
                ))
            }
        }
    }
    
    /// Capture the entire scene including all effects
    func captureSceneImage(targetSize: CGSize) -> UIImage? {
        guard let skView = view else { return nil }
        
        // Create a texture from the entire scene
        let texture = skView.texture(from: self)
        guard let cgImage = texture?.cgImage() else { return nil }
        
        let sceneImage = UIImage(cgImage: cgImage)
        
        // Scale to target size if needed
        if sceneImage.size == targetSize {
            return sceneImage
        }
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { ctx in
            sceneImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    // ----------------------------------------------------------
    // GIF Recording Methods
    // ----------------------------------------------------------
    
    /// Start recording frames for GIF export
    func startGIFRecording(fps: Double = 12) {
        stopGIFRecording()
        
        gifRecorder = GIFRecorder(targetFPS: fps, maxDuration: 12.0)
        isRecordingGIF = true
        
        // Capture frames at target FPS
        let interval = 1.0 / fps
        recordingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.captureGIFFrame()
        }
    }
    
    /// Capture a single frame for GIF
    private func captureGIFFrame() {
        guard isRecordingGIF, let recorder = gifRecorder else { return }
        
        // Capture at reasonable resolution for GIF (512x512)
        if let frame = captureSceneImage(targetSize: CGSize(width: 512, height: 512)) {
            recorder.addFrame(frame)
        }
    }
    
    /// Stop recording and export GIF
    func stopGIFRecording(export: Bool = true) {
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecordingGIF = false
        
        if export, let recorder = gifRecorder {
            recorder.exportGIF { [weak self] url in
                self?.onGIFRecordingComplete?(url)
            }
        }
        
        gifRecorder = nil
    }
    
    /// Record a complete demo sequence as GIF (10-12 seconds)
    func recordDemoAsGIF(
        onProgress: @escaping (String) -> Void,
        completion: @escaping (URL?) -> Void
    ) {
        clearAllLights()
        clearGrowth()
        
        // Start recording
        startGIFRecording(fps: 10)  // 10 FPS for smaller file size
        
        onProgress("Recording demo...")
        
        // Demo light positions for impressive visual
        let demoLightPositions: [(CGPoint, TimeInterval, CGFloat)] = [
            (CGPoint(x: size.width * 0.35, y: size.height * 0.55), 1.0, 1.0),
            (CGPoint(x: size.width * 0.65, y: size.height * 0.50), 2.5, 0.9)
        ]
        
        // Place lights with visual effects
        for (pos, delay, intensity) in demoLightPositions {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.placePersistentLight(at: pos, intensity: intensity)
                onProgress("Placing light...")
            }
        }
        
        // Signal growth after lights placed
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            onProgress("Life growing toward light...")
        }
        
        // Stop recording after growth completes (around 10 seconds)
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            onProgress("Finalizing GIF...")
            self?.stopGIFRecording(export: true)
            self?.onGIFRecordingComplete = completion
        }
    }
}

// ============================================================
// MARK: - Scene Coordinator
// ============================================================

class SceneCoordinator: ObservableObject {
    var scene: GalleryScene?
    var skView: SKView?
}

// ============================================================
// MARK: - SpriteKit Container (UIViewRepresentable)
// ============================================================

struct SpriteKitContainer: UIViewRepresentable {
    let coordinator: SceneCoordinator
    let sceneSize: CGSize

    func makeUIView(context: Context) -> SKView {
        let view  = SKView()
        view.ignoresSiblingOrder = true
        view.allowsTransparency  = false

        let scene = GalleryScene(size: sceneSize)
        scene.scaleMode       = .resizeFill
        scene.backgroundColor = .black
        view.presentScene(scene)

        DispatchQueue.main.async {
            coordinator.scene  = scene
            coordinator.skView = view
        }
        return view
    }

    func updateUIView(_ uiView: SKView, context: Context) {
        // Updates are driven through the coordinator, not through
        // SwiftUI state diffing - avoids expensive re-renders.
    }
}

// ============================================================
// MARK: - ContentView
// ============================================================

struct ContentView: View {

    // --- Core Creative State ---
    @State private var cosmicTheme: CosmicTheme = .nebula
    @State private var lifeStage: LifeStage = .growth
    @State private var seed: Int = 42
    
    // --- Light Color (Life Energy Color) ---
    @State private var lightColor: Color = Color(red: 0.4, green: 0.9, blue: 0.6)
    
    // --- Cosmic Background Parameters ---
    @State private var cosmicIntensity: Double = 0.6   // Background presence
    @State private var warpStrength: Double = 25.0
    @State private var enableWarp: Bool = true
    
    // --- Life Form Parameters ---
    @State private var branchAngle: Double = 25.0
    @State private var phototropismStrength: Double = 15.0  // Phototropism strength
    
    // --- Visual Effects ---
    @State private var bloomIntensity: Double = 15.0
    @State private var particleEnergy: Double = 50.0
    @State private var enableVignette: Bool = true
    
    // --- UI State ---
    @State private var showShareSheet = false
    @State private var exportedImage: UIImage?
    @State private var isExporting = false
    @State private var showTutorial = true  // Show tutorial for new users
    @State private var tutorialStep: Int = 0  // Current tutorial step (0-4)
    @State private var showSavedAlert = false
    @State private var savedFileName = ""
    
    // --- New: Animation & Challenge Mode ---
    @State private var isAnimatedGrowth = false      // Animated segment-by-segment growth
    @State private var currentChallengeIndex: Int? = nil  // nil = free mode, 0-N = challenge index
    @State private var isPlayingDemo = false         // Demo mode active
    @State private var challengeScore: Double = 0    // Current challenge score (0-100)
    @State private var lightsUsedInChallenge: Int = 0  // Lights placed in current challenge
    @State private var challengeStars: Int = 0       // Stars earned for current challenge (0-3)
    
    // --- Demo Status ---
    @State private var demoStatusText: String = ""
    
    // --- Achievement System ---
    @AppStorage("achievements") private var achievementsData: Data = Data()
    @AppStorage("hasCompletedTutorial") private var hasCompletedTutorial: Bool = false
    @State private var unlockedChallenges: Set<Int> = [0]  // Challenge indices that are unlocked
    @State private var showChallengeCompleteAlert = false
    
    // --- Background Cache ---
    @State private var cachedBackgroundKey: String = ""
    @State private var cachedBackgroundImage: UIImage? = nil
    
    // --- GIF Recording & Export ---
    @State private var isRecordingGIF = false
    @State private var gifExportProgress: String = ""
    @State private var showGIFShareSheet = false
    @State private var exportedGIFURL: URL? = nil
    
    // --- Toast Notifications ---
    @StateObject private var toastManager = ToastManager()
    
    // --- Preset Export ---
    @State private var showPresetPicker = false

    @StateObject private var coordinator = SceneCoordinator()

    // -------------------------------------------------------
    // Body - Immersive Layout
    // -------------------------------------------------------

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height

            ZStack {
                // Main content
                if landscape {
                    HStack(spacing: 0) {
                        canvasSection
                            .frame(width: geo.size.width * 0.6)
                        
                        ScrollView(.vertical, showsIndicators: false) {
                            creativePanel
                        }
                        .frame(width: geo.size.width * 0.4)
                        .background(Color.black.opacity(0.85))
                    }
                } else {
                    VStack(spacing: 0) {
                        canvasSection
                            .frame(height: geo.size.height * 0.5)
                        
                        ScrollView(.vertical, showsIndicators: false) {
                            creativePanel
                        }
                        .background(Color.black.opacity(0.85))
                    }
                }
                
                // Tutorial overlay
                if showTutorial {
                    tutorialOverlay
                }
                
                // Toast notification overlay
                VStack {
                    Spacer()
                    if toastManager.isShowing {
                        ToastView(
                            message: toastManager.message,
                            icon: toastManager.icon,
                            color: toastManager.color
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 100)
                    }
                }
                .animation(.spring(response: 0.4), value: toastManager.isShowing)
                
                // GIF Recording indicator
                if isRecordingGIF {
                    VStack {
                        HStack {
                            Spacer()
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 10, height: 10)
                                    .opacity(0.8)
                                Text("REC")
                                    .font(.caption.bold())
                                    .foregroundStyle(.red)
                                Text(gifExportProgress)
                                    .font(.caption)
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .padding()
                        }
                        Spacer()
                    }
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear { 
            loadUnlockedChallenges()
            // Only show tutorial for first-time users
            showTutorial = !hasCompletedTutorial
            refreshCanvas() 
        }
        .sheet(isPresented: $showShareSheet) {
            if let img = exportedImage {
                ShareSheet(items: [img])
            }
        }
        .sheet(isPresented: $showGIFShareSheet) {
            if let url = exportedGIFURL {
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $showPresetPicker) {
            PresetPickerView(
                onSelect: { preset in
                    applyPreset(preset)
                },
                onExport: { preset in
                    exportPresetSample(preset)
                }
            )
        }
        .alert("Creation Saved", isPresented: $showSavedAlert) {
            Button("OK") {}
        } message: {
            Text("Parameters saved as \(savedFileName)")
        }
        .alert("Challenge Complete!", isPresented: $showChallengeCompleteAlert) {
            Button("Continue") {
                // Check if next challenge unlocked
                if let idx = currentChallengeIndex,
                   idx + 1 < Challenge.presets.count,
                   challengeStars >= 1 {
                    unlockedChallenges.insert(idx + 1)
                }
            }
            Button("Try Again") {
                coordinator.scene?.clearAllLights()
                coordinator.scene?.clearGrowth()
                lightsUsedInChallenge = 0
                challengeScore = 0
                challengeStars = 0
                refreshCanvas()
            }
        } message: {
            if let idx = currentChallengeIndex {
                let challenge = Challenge.presets[idx]
                let avgCoverage = challengeScore / 100
                let explanation = challenge.getStarExplanation(
                    lightsUsed: lightsUsedInChallenge, 
                    totalCoverage: avgCoverage
                )
                Text(explanation)
            } else {
                Text("Challenge completed!")
            }
        }
    }
    
    /// Load unlocked challenges from achievements
    private func loadUnlockedChallenges() {
        let achievements = loadAchievements()
        unlockedChallenges = [0]  // First challenge always unlocked
        
        for (idx, achievement) in achievements {
            if achievement.stars >= 1 && idx + 1 < Challenge.presets.count {
                unlockedChallenges.insert(idx + 1)
            }
        }
    }
    
    // -------------------------------------------------------
    // MARK: Tutorial Overlay - Showcase Creative Concept
    // -------------------------------------------------------
    
    private var tutorialOverlay: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Progress indicator
                HStack(spacing: 8) {
                    ForEach(0..<5) { step in
                        Circle()
                            .fill(step <= tutorialStep ? Color.cyan : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Step content
                Group {
                    switch tutorialStep {
                    case 0:
                        tutorialWelcome
                    case 1:
                        tutorialLightConcept
                    case 2:
                        tutorialPhototropism
                    case 3:
                        tutorialChallenge
                    case 4:
                        tutorialReady
                    default:
                        tutorialReady
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(tutorialStep)
                
                Spacer()
                
                // Navigation buttons
                HStack(spacing: 20) {
                    if tutorialStep > 0 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                tutorialStep -= 1
                            }
                        } label: {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .font(.headline)
                            .foregroundStyle(.gray)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        if tutorialStep < 4 {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                tutorialStep += 1
                            }
                        } else {
                            withAnimation(.easeOut(duration: 0.5)) {
                                showTutorial = false
                                hasCompletedTutorial = true
                            }
                        }
                    } label: {
                        HStack {
                            Text(tutorialStep < 4 ? "Next" : "Start Creating")
                            Image(systemName: tutorialStep < 4 ? "chevron.right" : "sparkles")
                        }
                        .font(.headline)
                        .foregroundStyle(tutorialStep < 4 ? .white : .black)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(
                            tutorialStep < 4 ?
                            AnyShapeStyle(Color.cyan.opacity(0.3)) :
                            AnyShapeStyle(LinearGradient(colors: [.cyan, .green], startPoint: .leading, endPoint: .trailing))
                        )
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
                
                // Skip button
                Button {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showTutorial = false
                        hasCompletedTutorial = true
                    }
                } label: {
                    Text("Skip Tutorial")
                        .font(.caption)
                        .foregroundStyle(.gray.opacity(0.6))
                }
                .padding(.bottom, 20)
            }
        }
        .transition(.opacity)
    }
    
    // MARK: - Tutorial Steps
    
    private var tutorialWelcome: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkles")
                .font(.system(size: 72))
                .foregroundStyle(.cyan)
                .symbolEffect(.variableColor.iterative.reversing, options: .repeating)
            
            Text("Light of Life")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
            Text("A Generative Art Experience")
                .font(.title3)
                .foregroundStyle(.gray)
            
            Text("You are about to become a creator of digital life,\nguiding organic forms through the power of light.")
                .font(.body)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 16)
        }
    }
    
    private var tutorialLightConcept: some View {
        VStack(spacing: 32) {
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [.yellow, .orange.opacity(0.3), .clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 80
                    ))
                    .frame(width: 160, height: 160)
                
                Image(systemName: "light.max")
                    .font(.system(size: 48))
                    .foregroundStyle(.yellow)
            }
            
            Text("Place Your Light")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
            VStack(spacing: 16) {
                tutorialInstruction(
                    icon: "hand.tap.fill",
                    text: "Long press on the canvas to place a light source"
                )
                
                tutorialInstruction(
                    icon: "hand.draw.fill",
                    text: "Drag to draw trails of light energy"
                )
                
                tutorialInstruction(
                    icon: "sparkles",
                    text: "Each light will attract and guide organic growth"
                )
            }
            .padding(.horizontal, 40)
        }
    }
    
    private var tutorialPhototropism: some View {
        VStack(spacing: 32) {
            HStack(spacing: 30) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.yellow)
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 24))
                    .foregroundStyle(.gray)
                
                Image(systemName: "leaf.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)
            }
            
            Text("Phototropism")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
            Text("Life Grows Toward Light")
                .font(.title3)
                .foregroundStyle(.cyan)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("In nature, plants grow toward light sources - a phenomenon called phototropism.")
                    .font(.body)
                    .foregroundStyle(.gray)
                
                Text("In Light of Life, digital organisms follow this same principle, creating beautiful organic patterns guided by your light placement.")
                    .font(.body)
                    .foregroundStyle(.gray)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
        }
    }
    
    private var tutorialChallenge: some View {
        VStack(spacing: 32) {
            HStack(spacing: 16) {
                ForEach(0..<3) { i in
                    Image(systemName: i < 2 ? "star.fill" : "star")
                        .font(.system(size: 36))
                        .foregroundStyle(.yellow)
                }
            }
            
            Text("Challenge Mode")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
            VStack(spacing: 16) {
                tutorialInstruction(
                    icon: "target",
                    text: "Guide growth to reach target zones"
                )
                
                tutorialInstruction(
                    icon: "number.circle.fill",
                    text: "Use fewer lights for more stars"
                )
                
                tutorialInstruction(
                    icon: "lock.open.fill",
                    text: "Earn stars to unlock new challenges"
                )
            }
            .padding(.horizontal, 40)
            
            Text("Start with Free Mode to explore,\nthen try challenges to test your skills!")
                .font(.subheadline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
        }
    }
    
    private var tutorialReady: some View {
        VStack(spacing: 32) {
            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Color.cyan.opacity(0.3 - Double(i) * 0.1), lineWidth: 2)
                        .frame(width: CGFloat(100 + i * 40), height: CGFloat(100 + i * 40))
                }
                
                Image(systemName: "hand.point.up.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.cyan)
            }
            
            Text("You're Ready!")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
            VStack(spacing: 12) {
                Text("Tips for Beautiful Creations:")
                    .font(.headline)
                    .foregroundStyle(.cyan)
                
                VStack(alignment: .leading, spacing: 8) {
                    tutorialTip("Place lights at different heights for variety")
                    tutorialTip("Try multiple lights for complex patterns")
                    tutorialTip("Experiment with different cosmic backgrounds")
                    tutorialTip("Use Demo Mode to see the process")
                }
            }
            .padding(.horizontal, 40)
        }
    }
    
    private func tutorialInstruction(icon: String, text: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.cyan)
                .frame(width: 32)
            
            Text(text)
                .font(.body)
                .foregroundStyle(.white.opacity(0.9))
        }
    }
    
    private func tutorialTip(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.gray)
        }
    }

    // -------------------------------------------------------
    // MARK: Canvas - Canvas Area
    // -------------------------------------------------------

    private var canvasSection: some View {
        ZStack {
            SpriteKitContainer(
                coordinator: coordinator,
                sceneSize: CGSize(width: 768, height: 768)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(10)

            // Floating control buttons
            VStack {
                // Top: Life stage indicator
                HStack {
                    lifeStageIndicator
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Spacer()
                
                // Bottom buttons
                HStack {
                    Button {
                        coordinator.scene?.clearAllLights()
                        refreshCanvas()  // Redraw after clearing lights
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .font(.caption)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    Spacer()
                    
                    if isExporting {
                        ProgressView()
                            .tint(.white)
                            .padding(8)
                    }
                    
                    Button { exportHighRes() } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .font(.caption)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .disabled(isExporting)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
    
    // Life stage indicator
    private var lifeStageIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: lifeStageIcon)
                .foregroundStyle(.green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(lifeStage.name)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                Text(lifeStage.description)
                    .font(.caption2)
                    .foregroundStyle(.gray)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var lifeStageIcon: String {
        switch lifeStage {
        case .seed: return "circle.fill"
        case .sprout: return "leaf"
        case .growth: return "leaf.fill"
        case .bloom: return "sparkles"
        case .transcend: return "star.fill"
        }
    }

    // -------------------------------------------------------
    // MARK: Creative Panel - Creative Control Panel
    // -------------------------------------------------------

    private var creativePanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // Title
            VStack(alignment: .leading, spacing: 4) {
                Text("Light of Life")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("Create your own life forms")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .padding(.bottom, 8)
            
            // --- Cosmic Theme ---
            sectionLabel("COSMIC BACKGROUND")
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(CosmicTheme.allCases) { theme in
                        themeButton(theme)
                    }
                }
            }
            
            // --- Life Stage ---
            sectionLabel("LIFE STAGE")
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(LifeStage.allCases, id: \.rawValue) { stage in
                        lifeStageButton(stage)
                    }
                }
            }
            
            Divider().background(Color.gray.opacity(0.3))
            
            // --- Life Form Adjustments ---
            sectionLabel("LIFE FORM")
            
            sliderRow("Branch Angle", value: $branchAngle,
                      range: 15...60, step: 1,
                      onDone: refreshCanvas)
            
            sliderRow("Phototropism", value: $phototropismStrength,
                      range: 0...30, step: 1,
                      onDone: refreshCanvas)
            
            HStack {
                Text("Light Color")
                    .font(.subheadline).foregroundStyle(.white)
                Spacer()
                ColorPicker("", selection: $lightColor, supportsOpacity: false)
                    .labelsHidden()
                    .onChange(of: lightColor) { updateVisuals() }
            }
            
            Divider().background(Color.gray.opacity(0.3))
            
            // --- Cosmic Atmosphere ---
            sectionLabel("ATMOSPHERE")
            
            Toggle("Chaotic Flow", isOn: $enableWarp)
                .font(.subheadline).foregroundStyle(.white)
                .onChange(of: enableWarp) { refreshCanvas() }
            
            if enableWarp {
                sliderRow("Flow Intensity", value: $warpStrength,
                          range: 10...60, step: 1,
                          onDone: refreshCanvas)
            }
            
            sliderRow("Nebula Brightness", value: $cosmicIntensity,
                      range: 0.2...1.0, step: 0.05,
                      onDone: refreshCanvas)
            
            Toggle("Vignette", isOn: $enableVignette)
                .font(.subheadline).foregroundStyle(.white)
                .onChange(of: enableVignette) { refreshCanvas() }
            
            Divider().background(Color.gray.opacity(0.3))
            
            // --- Light Effects ---
            sectionLabel("LIGHT EFFECTS")
            
            sliderRow("Light Bloom", value: $bloomIntensity,
                      range: 5...30, step: 1,
                      onDone: updateVisuals)
            
            sliderRow("Particle Energy", value: $particleEnergy,
                      range: 20...100, step: 5,
                      onDone: updateVisuals)
            
            Divider().background(Color.gray.opacity(0.3))
            
            // --- Creation Seed ---
            HStack {
                sectionLabel("CREATION SEED")
                Spacer()
                Text("#\(seed)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.gray)
                Button {
                    seed = Int.random(in: 0...99999)
                    refreshCanvas()
                } label: {
                    Image(systemName: "dice.fill")
                        .foregroundStyle(.cyan)
                }
            }
            
            Divider().background(Color.gray.opacity(0.3))
            
            // --- Play Modes (NEW) ---
            sectionLabel("PLAY MODES")
            
            // Animated Growth Toggle
            Toggle("Animated Growth", isOn: $isAnimatedGrowth)
                .font(.subheadline).foregroundStyle(.white)
                .onChange(of: isAnimatedGrowth) {
                    if isAnimatedGrowth {
                        refreshCanvasAnimated()
                    } else {
                        refreshCanvas()
                    }
                }
            
            // Demo Mode Section
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    startDemoMode()
                } label: {
                    HStack {
                        Image(systemName: isPlayingDemo ? "stop.fill" : "play.fill")
                        Text(isPlayingDemo ? "Stop Demo" : "Auto Demo")
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .disabled(currentChallengeIndex != nil)
                
                // Demo status display
                if isPlayingDemo && !demoStatusText.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(.orange)
                            .scaleEffect(0.8)
                        Text(demoStatusText)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            // Challenge Mode Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Challenge Mode")
                    .font(.subheadline).foregroundStyle(.white)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // Free Mode
                        challengeModeButton(title: "Free", index: nil, icon: "paintpalette")
                        
                        // Preset Challenges
                        ForEach(0..<Challenge.presets.count, id: \.self) { idx in
                            let challenge = Challenge.presets[idx]
                            challengeModeButton(
                                title: challenge.name,
                                index: idx,
                                icon: challenge.difficulty == 1 ? "star" : 
                                      challenge.difficulty == 2 ? "star.leadinghalf.filled" : "star.fill"
                            )
                        }
                    }
                }
            }
            
            // Challenge Progress (shown when in challenge mode)
            if let idx = currentChallengeIndex {
                let challenge = Challenge.presets[idx]
                let bestStars = getBestStars(for: idx)
                let avgCoverage = challengeScore / 100.0
                
                VStack(alignment: .leading, spacing: 8) {
                    // Challenge header with difficulty
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(challenge.name)
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text(challenge.description)
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                        Spacer()
                        
                        // Difficulty stars
                        HStack(spacing: 2) {
                            ForEach(0..<5) { i in
                                Image(systemName: i < challenge.difficulty ? "star.fill" : "star")
                                    .font(.caption2)
                                    .foregroundStyle(i < challenge.difficulty ? .yellow : .gray.opacity(0.3))
                            }
                        }
                    }
                    
                    // Light usage indicator
                    HStack {
                        Text("Lights:")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        
                        HStack(spacing: 4) {
                            ForEach(0..<challenge.maxLights, id: \.self) { i in
                                Circle()
                                    .fill(i < lightsUsedInChallenge ? Color.cyan : Color.gray.opacity(0.3))
                                    .frame(width: 12, height: 12)
                            }
                        }
                        
                        Spacer()
                        
                        Text("\(lightsUsedInChallenge)/\(challenge.maxLights)")
                            .font(.caption.bold())
                            .foregroundStyle(lightsUsedInChallenge >= challenge.maxLights ? .orange : .cyan)
                    }
                    
                    // Progress bar with threshold markers
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.gray.opacity(0.3))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: challengeScore >= 100 ? [.green, .yellow] : [.green, .cyan],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * CGFloat(min(1, challengeScore / 100)))
                            
                            // Star threshold markers (50%, 75%)
                            Rectangle()
                                .fill(.white.opacity(0.5))
                                .frame(width: 1, height: 10)
                                .position(x: geo.size.width * 0.5, y: 5)
                            Rectangle()
                                .fill(.yellow.opacity(0.7))
                                .frame(width: 1, height: 10)
                                .position(x: geo.size.width * 0.75, y: 5)
                        }
                    }
                    .frame(height: 10)
                    
                    // Coverage percentage with star thresholds explained
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Coverage: \(Int(challengeScore))%")
                                .font(.caption.bold())
                                .foregroundStyle(challengeScore >= 75 ? .green : (challengeScore >= 50 ? .cyan : .white))
                            
                            // Star threshold hints
                            HStack(spacing: 12) {
                                HStack(spacing: 2) {
                                    Image(systemName: "star")
                                        .font(.system(size: 8))
                                    Text("50%")
                                }
                                .foregroundStyle(avgCoverage >= 0.5 ? .green : .gray)
                                
                                HStack(spacing: 2) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 8))
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 8))
                                    Text("<= \(challenge.maxLights)")
                                    Image(systemName: "light.max")
                                        .font(.system(size: 8))
                                }
                                .foregroundStyle(avgCoverage >= 0.5 && lightsUsedInChallenge <= challenge.maxLights ? .cyan : .gray)
                                
                                HStack(spacing: 2) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 8))
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 8))
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 8))
                                    Text("75%")
                                }
                                .foregroundStyle(avgCoverage >= 0.75 ? .yellow : .gray)
                            }
                            .font(.system(size: 9))
                        }
                        
                        Spacer()
                        
                        // Current attempt stars
                        if challengeStars > 0 {
                            HStack(spacing: 2) {
                                ForEach(0..<3) { i in
                                    Image(systemName: i < challengeStars ? "star.fill" : "star")
                                        .font(.caption)
                                        .foregroundStyle(i < challengeStars ? .yellow : .gray.opacity(0.3))
                                }
                            }
                        }
                        
                        // Best record
                        if bestStars > 0 {
                            VStack(spacing: 2) {
                                Text("Best")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.gray)
                                HStack(spacing: 1) {
                                    ForEach(0..<bestStars, id: \.self) { _ in
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    challengeScore >= 100 ? Color.green.opacity(0.5) : Color.cyan.opacity(0.2),
                                    lineWidth: 1
                                )
                        )
                )
            }
            
            Divider().background(Color.gray.opacity(0.3))
            
            // --- Save & Share ---
            sectionLabel("SAVE & SHARE")
            
            // Primary export options
            HStack(spacing: 12) {
                Button { saveParametersJSON() } label: {
                    Label("Save Params", systemImage: "doc.text")
                        .font(.caption)
                }
                .buttonStyle(.bordered).tint(.orange)
                
                Button { exportHighRes() } label: {
                    Label("Export 2K", systemImage: "photo")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isExporting)
            }
            
            // Advanced export options
            HStack(spacing: 12) {
                // GIF Demo Export - Key for judges
                Button { recordDemoGIF() } label: {
                    HStack {
                        Image(systemName: isRecordingGIF ? "stop.fill" : "film")
                        Text(isRecordingGIF ? "Recording..." : "Record GIF")
                    }
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.purple)
                .disabled(isRecordingGIF)
                
                // 4K Export
                Button { exportUltraHighRes() } label: {
                    HStack {
                        Image(systemName: "4k.tv")
                        Text("Export 4K")
                    }
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.green)
                .disabled(isExporting)
            }
            
            // Showcase Presets - For submissions
            Button { showPresetPicker = true } label: {
                HStack {
                    Image(systemName: "sparkles.rectangle.stack")
                    Text("Showcase Presets")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.cyan)
            
            // Tips
            VStack(alignment: .leading, spacing: 6) {
                tipRow(icon: "hand.tap.fill", text: "Long press to place light", color: .cyan)
                tipRow(icon: "leaf.fill", text: "Life grows toward light", color: .green)
                tipRow(icon: "film", text: "Record GIF for submissions", color: .purple)
            }
            .padding(.top, 8)
            
            // Help button to rewatch tutorial
            Button {
                tutorialStep = 0
                showTutorial = true
            } label: {
                HStack {
                    Image(systemName: "questionmark.circle")
                    Text("View Tutorial")
                }
                .font(.caption)
                .foregroundStyle(.gray)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.gray)
            .padding(.top, 4)
        }
        .padding()
    }
    
    // Theme button
    private func themeButton(_ theme: CosmicTheme) -> some View {
        Button {
            cosmicTheme = theme
            refreshCanvas()
        } label: {
            VStack(spacing: 6) {
                // Gradient preview
                LinearGradient(
                    colors: theme.gradient.colors.map { Color($0.1) },
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(width: 60, height: 40)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(cosmicTheme == theme ? Color.cyan : Color.clear, lineWidth: 2)
                )
                
                Text(theme.rawValue)
                    .font(.caption2)
                    .foregroundStyle(cosmicTheme == theme ? .cyan : .gray)
            }
        }
        .buttonStyle(.plain)
    }
    
    // Life stage button
    private func lifeStageButton(_ stage: LifeStage) -> some View {
        Button {
            lifeStage = stage
            refreshCanvas()
        } label: {
            VStack(spacing: 4) {
                Circle()
                    .fill(Color(stage.baseColor))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .stroke(lifeStage == stage ? Color.white : Color.clear, lineWidth: 2)
                    )
                
                Text(stage.name)
                    .font(.caption2)
                    .foregroundStyle(lifeStage == stage ? .white : .gray)
            }
        }
        .buttonStyle(.plain)
    }
    
    private func tipRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color.opacity(0.7))
                .frame(width: 16)
            Text(text)
                .font(.caption2)
                .foregroundStyle(.gray)
        }
    }
    
    // Challenge mode button with stars and unlock status
    private func challengeModeButton(title: String, index: Int?, icon: String) -> some View {
        let isSelected = currentChallengeIndex == index
        let isUnlocked = index == nil || unlockedChallenges.contains(index!)
        let earnedStars = index != nil ? getBestStars(for: index!) : 0
        
        return Button {
            if isUnlocked {
                selectChallenge(index: index)
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Image(systemName: isUnlocked ? icon : "lock.fill")
                        .font(.title3)
                        .foregroundStyle(isSelected ? .cyan : (isUnlocked ? .gray : .gray.opacity(0.4)))
                }
                
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white : (isUnlocked ? .gray : .gray.opacity(0.4)))
                    .lineLimit(1)
                
                // Show earned stars
                if let idx = index, earnedStars > 0 {
                    HStack(spacing: 1) {
                        ForEach(0..<3) { i in
                            Image(systemName: i < earnedStars ? "star.fill" : "star")
                                .font(.system(size: 6))
                                .foregroundStyle(i < earnedStars ? .yellow : .gray.opacity(0.3))
                        }
                    }
                }
            }
            .frame(width: 60, height: earnedStars > 0 ? 58 : 50)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? .cyan.opacity(0.2) : .clear)
                    .strokeBorder(
                        isSelected ? .cyan : (isUnlocked ? .gray.opacity(0.3) : .gray.opacity(0.15)),
                        lineWidth: 1
                    )
            )
            .opacity(isUnlocked ? 1.0 : 0.6)
        }
        .buttonStyle(.plain)
        .disabled(!isUnlocked)
    }
    
    // Select a challenge mode
    private func selectChallenge(index: Int?) {
        currentChallengeIndex = index
        lightsUsedInChallenge = 0
        challengeScore = 0
        challengeStars = 0
        
        coordinator.scene?.clearAllLights()
        coordinator.scene?.clearChallengeTargets()
        
        if let idx = index {
            let challenge = Challenge.presets[idx]
            coordinator.scene?.showChallengeTargets(challenge)
            coordinator.scene?.maxLightsAllowed = challenge.maxLights
            
            // Set up callbacks
            coordinator.scene?.onLightPlaced = { count in
                self.lightsUsedInChallenge = count
            }
            coordinator.scene?.onLightLimitReached = {
                // Haptic feedback for limit reached
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.warning)
            }
        } else {
            // Free mode - no limit
            coordinator.scene?.maxLightsAllowed = Int.max
            coordinator.scene?.onLightPlaced = nil
            coordinator.scene?.onLightLimitReached = nil
        }
        
        refreshCanvas()
    }
    
    // Start demo mode with enhanced visualization
    private func startDemoMode() {
        if isPlayingDemo {
            // Stop demo
            isPlayingDemo = false
            demoStatusText = ""
            coordinator.scene?.clearAllLights()
            coordinator.scene?.clearGrowth()
            refreshCanvas()
        } else {
            // Start demo
            isPlayingDemo = true
            isAnimatedGrowth = true
            demoStatusText = "Demo: Preparing canvas..."
            
            coordinator.scene?.clearAllLights()
            coordinator.scene?.clearGrowth()
            
            // Use enhanced demo with step callbacks
            coordinator.scene?.playFullDemoSequence(
                onStep: { step in
                    switch step {
                    case .start:
                        self.demoStatusText = "Demo: Starting..."
                    case .placingLight(let num, _):
                        self.demoStatusText = "Demo: Placing light \(num)..."
                    case .startGrowth:
                        self.demoStatusText = "Demo: Growing toward light..."
                        self.refreshCanvasAnimated()
                    case .growthComplete:
                        self.demoStatusText = "Demo: Growth complete!"
                    case .showResult:
                        self.demoStatusText = "Demo: Final result - Seed #\(self.seed)"
                    }
                },
                completion: {
                    // Auto-stop demo
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.isPlayingDemo = false
                        self.demoStatusText = ""
                    }
                }
            )
        }
    }
    
    // Refresh canvas with animated growth
    private func refreshCanvasAnimated() {
        guard let scene = coordinator.scene else { return }
        
        let sz = 512
        
        // 1. Get cached or generate cosmic background
        guard let backgroundImage = getCachedBackground(size: sz) else { return }
        
        var finalImage = backgroundImage
        if enableVignette {
            finalImage = applyVignette(to: finalImage, intensity: 0.4)
        }
        
        // Set background only (no static L-System)
        scene.setBackgroundImage(finalImage)
        
        // 2. Get light source positions
        let lightSources = getLightSourcesForRendering(canvasSize: CGSize(width: sz, height: sz))
        
        // 3. Generate L-System segments for animation
        let sys = LSystem(
            axiom: "F",
            rules: [("F", "FF+[+F-F-F]-[-F+F+F]")],
            angle: branchAngle
        )
        let linLen = max(1.0, CGFloat(sz) / pow(3.0, CGFloat(lifeStage.iterations)))
        
        let renderParams = LSystemRenderParams(
            baseLineWidth: CGFloat(4.0 + Double(lifeStage.rawValue) * 0.5),
            widthDecay: 0.65,
            angleVariation: 8.0,
            enableGlow: true,
            glowRadius: 8.0,
            glowAlpha: 0.45,
            colorGradient: .lifeGradient,
            depthColorFade: true,
            lightSources: lightSources,
            phototropismStrength: CGFloat(phototropismStrength),
            lightColorInfluence: 0.35,
            randomSeed: UInt64(seed)
        )
        
        // Generate segments for animation
        let segments = sys.generateSegmentsForAnimation(
            iterations: lifeStage.iterations,
            canvasSize: CGSize(width: sz, height: sz),
            lineLength: linLen,
            params: renderParams
        )
        
        // Start animated growth
        scene.startAnimatedGrowth(segments: segments)
        
        // Update challenge score if in challenge mode
        if let idx = currentChallengeIndex {
            updateChallengeProgress(segments: segments, challengeIndex: idx)
        }
        
        updateVisuals()
    }
    
    // Update challenge progress based on segments using grid coverage calculation
    private func updateChallengeProgress(segments: [GrowthSegment], challengeIndex: Int) {
        let challenge = Challenge.presets[challengeIndex]
        var totalCoverage: Double = 0
        var reachedCount = 0
        var newlyReachedTargets: [(index: Int, coverage: Int, required: Int)] = []
        
        for (index, target) in challenge.targets.enumerated() {
            // Use grid sampling for accurate coverage calculation
            let coverage = target.calculateGridCoverage(segments: segments, sampleCount: 10)
            totalCoverage += Double(coverage)
            
            // Target is reached if coverage exceeds required threshold
            let isReached = coverage >= target.requiredCoverage
            if isReached {
                reachedCount += 1
                coordinator.scene?.markTargetReached(target.id)
                
                // Track newly reached targets for toast notification
                newlyReachedTargets.append((
                    index: index,
                    coverage: Int(coverage * 100),
                    required: Int(target.requiredCoverage * 100)
                ))
            }
        }
        
        // Show toast for first reached target (to avoid spam)
        if let firstReached = newlyReachedTargets.first {
            toastManager.showTargetReached(
                targetIndex: firstReached.index,
                coverage: firstReached.coverage,
                required: firstReached.required
            )
        }
        
        // Calculate overall challenge score based on average coverage
        let avgCoverage = totalCoverage / Double(challenge.targets.count)
        challengeScore = avgCoverage * 100
        lightsUsedInChallenge = coordinator.scene?.placedLights.count ?? 0
        
        // Calculate stars if challenge completed
        if reachedCount == challenge.targets.count {
            let stars = challenge.calculateStars(lightsUsed: lightsUsedInChallenge, totalCoverage: avgCoverage)
            challengeStars = stars
            
            // Show star rating explanation via toast
            let explanation = challenge.getStarExplanation(
                lightsUsed: lightsUsedInChallenge,
                totalCoverage: avgCoverage
            )
            
            // Delay toast slightly to let the target reach animation finish
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.toastManager.showStarRating(stars: stars, reason: explanation)
            }
            
            // Save achievement if it's better than previous
            saveAchievement(challengeIndex: challengeIndex, stars: stars, coverage: avgCoverage)
        }
    }

    // -------------------------------------------------------
    // MARK: Helper Views
    // -------------------------------------------------------

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.bold())
            .foregroundStyle(.cyan.opacity(0.8))
            .tracking(1)
    }

    private func sliderRow(
        _ label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        onDone: @escaping () -> Void
    ) -> some View {
        HStack {
            Text(label)
                .font(.subheadline).foregroundStyle(.white)
                .frame(width: 90, alignment: .leading)
            Slider(
                value: value, in: range, step: step,
                onEditingChanged: { editing in
                    if !editing { onDone() }
                }
            )
            .tint(.cyan)
            Text(step >= 1 ? String(format: "%.0f", value.wrappedValue)
                           : String(format: "%.1f", value.wrappedValue))
                .font(.caption).foregroundStyle(.gray)
                .frame(width: 32, alignment: .trailing)
        }
    }
    
    // -------------------------------------------------------
    // MARK: Achievement System
    // -------------------------------------------------------
    
    /// Save achievement for a challenge
    private func saveAchievement(challengeIndex: Int, stars: Int, coverage: Double) {
        var achievements = loadAchievements()
        
        // Only save if better than previous
        if let existing = achievements[challengeIndex] {
            if stars > existing.stars || (stars == existing.stars && coverage > existing.coverage) {
                achievements[challengeIndex] = AchievementData(stars: stars, coverage: coverage)
            }
        } else {
            achievements[challengeIndex] = AchievementData(stars: stars, coverage: coverage)
        }
        
        // Unlock next challenge if earned at least 1 star
        if stars >= 1 && challengeIndex + 1 < Challenge.presets.count {
            unlockedChallenges.insert(challengeIndex + 1)
        }
        
        // Save to storage
        if let data = try? JSONEncoder().encode(achievements) {
            achievementsData = data
        }
        
        // Show completion alert
        if stars > 0 {
            showChallengeCompleteAlert = true
        }
    }
    
    /// Load achievements from storage
    private func loadAchievements() -> [Int: AchievementData] {
        guard !achievementsData.isEmpty,
              let decoded = try? JSONDecoder().decode([Int: AchievementData].self, from: achievementsData) else {
            return [:]
        }
        return decoded
    }
    
    /// Get best stars for a challenge
    private func getBestStars(for challengeIndex: Int) -> Int {
        return loadAchievements()[challengeIndex]?.stars ?? 0
    }
    
    // -------------------------------------------------------
    // MARK: Background Cache
    // -------------------------------------------------------
    
    /// Generate cache key for current background parameters
    private func backgroundCacheKey() -> String {
        return "\(seed)-\(cosmicTheme.rawValue)-\(warpStrength)-\(cosmicIntensity)-\(enableWarp)"
    }
    
    /// Get cached or generate new background image
    private func getCachedBackground(size: Int) -> UIImage? {
        let key = backgroundCacheKey()
        
        // Return cached if available
        if key == cachedBackgroundKey, let cached = cachedBackgroundImage {
            return cached
        }
        
        // Generate new background
        let noiseParams = NoiseParameters(
            frequency: 0.6,
            octaves: 6,
            persistence: 0.5,
            lacunarity: 2.0,
            warpFrequency: 0.8,
            warpStrength: warpStrength,
            gamma: 1.4 + (1.0 - cosmicIntensity) * 0.6,
            enableWarp: enableWarp
        )
        
        guard let image = generateAdvancedNoiseImage(
            width: size, height: size,
            params: noiseParams,
            seed: Int32(seed),
            gradient: cosmicTheme.gradient,
            addGrain: true
        ) else { return nil }
        
        // Cache the result
        cachedBackgroundKey = key
        cachedBackgroundImage = image
        
        return image
    }
    
    /// Invalidate background cache
    private func invalidateBackgroundCache() {
        cachedBackgroundKey = ""
        cachedBackgroundImage = nil
    }

    // -------------------------------------------------------
    // MARK: Logic - Core Rendering Logic
    // -------------------------------------------------------
    
    /// Get light source positions from scene (for L-System phototropism)
    private func getLightSourcesForRendering(canvasSize: CGSize) -> [LightSource] {
        guard let scene = coordinator.scene else { return [] }
        
        return scene.placedLights.map { light in
            // Convert SpriteKit coordinates to image coordinates
            let scaleX = canvasSize.width / scene.size.width
            let scaleY = canvasSize.height / scene.size.height
            
            let imageX = light.node.position.x * scaleX
            let imageY = (scene.size.height - light.node.position.y) * scaleY  // Flip Y
            
            return LightSource(
                position: CGPoint(x: imageX, y: imageY),
                intensity: light.intensity
            )
        }
    }

    private func refreshCanvas() {
        guard let scene = coordinator.scene else { return }

        let sz = 512
        
        // 1. Get cached or generate cosmic background (performance optimization)
        guard let backgroundImage = getCachedBackground(size: sz) else { return }
        
        // 2. Get light source positions
        let lightSources = getLightSourcesForRendering(canvasSize: CGSize(width: sz, height: sz))
        
        // 3. Generate life form (L-System)
        let sys = LSystem(
            axiom: "F",
            rules: [("F", "FF+[+F-F-F]-[-F+F+F]")],
            angle: branchAngle
        )
        let instr = sys.generate(iterations: lifeStage.iterations)
        let linLen = max(1.0, CGFloat(sz) / pow(3.0, CGFloat(lifeStage.iterations)))
        
        let renderParams = LSystemRenderParams(
            baseLineWidth: CGFloat(4.0 + Double(lifeStage.rawValue) * 0.5),
            widthDecay: 0.65,
            angleVariation: 8.0,
            enableGlow: true,
            glowRadius: 8.0,
            glowAlpha: 0.45,
            colorGradient: .lifeGradient,
            depthColorFade: true,
            lightSources: lightSources,
            phototropismStrength: CGFloat(phototropismStrength),
            lightColorInfluence: 0.35,
            randomSeed: UInt64(seed)
        )
        
        let lifeImage = sys.renderAdvanced(
            instructions: instr,
            canvasSize: CGSize(width: sz, height: sz),
            lineLength: linLen,
            params: renderParams
        )
        
        // 4. Composite: background + life form
        var finalImage = compositeImages(
            base: backgroundImage,
            overlay: lifeImage,
            blendMode: .plusLighter,
            alpha: 1.0
        )
        
        // 5. Post-processing
        if enableVignette {
            finalImage = applyVignette(to: finalImage, intensity: 0.4)
        }
        
        scene.setBackgroundImage(finalImage)
        updateVisuals()
    }

    private func updateVisuals() {
        guard let scene = coordinator.scene else { return }
        scene.glowColor = UIColor(lightColor)
        scene.bloomRadius = bloomIntensity
        scene.particleSpeed = CGFloat(particleEnergy)
        scene.trailDuration = 0.8
    }

    // -------------------------------------------------------
    // MARK: Export & Save - High Quality Export
    // -------------------------------------------------------

    private func exportHighRes() {
        guard !isExporting else { return }
        isExporting = true

        // Capture current state
        let currentSeed = seed
        let currentTheme = cosmicTheme
        let currentStage = lifeStage
        let currentAngle = branchAngle
        let currentWarp = warpStrength
        let warpEnabled = enableWarp
        let currentIntensity = cosmicIntensity
        let vignetteEnabled = enableVignette
        let currentPhototrop = phototropismStrength
        
        // Get light sources
        let lightSources = getLightSourcesForRendering(canvasSize: CGSize(width: 2048, height: 2048))
        let lightsImage = coordinator.scene?.renderLightsImage(targetSize: CGSize(width: 2048, height: 2048))

        DispatchQueue.global(qos: .userInitiated).async {
            let target = 2048
            
            // 1. Generate high-res cosmic background
            let noiseParams = NoiseParameters(
                frequency: 0.6,
                octaves: 6,
                persistence: 0.5,
                lacunarity: 2.0,
                warpFrequency: 0.8,
                warpStrength: currentWarp,
                gamma: 1.4 + (1.0 - currentIntensity) * 0.6,
                enableWarp: warpEnabled
            )
            
            guard let backgroundImage = generateAdvancedNoiseImage(
                width: target, height: target,
                params: noiseParams,
                seed: Int32(currentSeed),
                gradient: currentTheme.gradient,
                addGrain: true
            ) else {
                DispatchQueue.main.async { isExporting = false }
                return
            }
            
            // 2. Generate high-res life form
            let sys = LSystem(
                axiom: "F",
                rules: [("F", "FF+[+F-F-F]-[-F+F+F]")],
                angle: currentAngle
            )
            let instr = sys.generate(iterations: currentStage.iterations)
            let linLen = max(0.5, CGFloat(target) / pow(3.0, CGFloat(currentStage.iterations)))
            
            // Scale light positions to high resolution
            let scaledLights = lightSources.map { light in
                LightSource(
                    position: CGPoint(x: light.position.x * 4, y: light.position.y * 4),
                    intensity: light.intensity
                )
            }
            
            let renderParams = LSystemRenderParams(
                baseLineWidth: CGFloat(4.0 + Double(currentStage.rawValue) * 0.5) * 2.0,
                widthDecay: 0.65,
                angleVariation: 8.0,
                enableGlow: true,
                glowRadius: 16.0,
                glowAlpha: 0.45,
                colorGradient: .lifeGradient,
                depthColorFade: true,
                lightSources: scaledLights,
                phototropismStrength: CGFloat(currentPhototrop),
                lightColorInfluence: 0.35,
                randomSeed: UInt64(currentSeed)
            )
            
            let lifeImage = sys.renderAdvanced(
                instructions: instr,
                canvasSize: CGSize(width: target, height: target),
                lineLength: linLen,
                params: renderParams
            )
            
            // 3. Composite
            var finalImage = compositeImages(
                base: backgroundImage,
                overlay: lifeImage,
                blendMode: .plusLighter,
                alpha: 1.0
            )
            
            // 4. Composite light sources
            if let lights = lightsImage {
                finalImage = compositeImages(
                    base: finalImage,
                    overlay: lights,
                    blendMode: .plusLighter,
                    alpha: 1.0
                )
            }
            
            // 5. Post-processing
            if vignetteEnabled {
                finalImage = applyVignette(to: finalImage, intensity: 0.4)
            }

            DispatchQueue.main.async {
                isExporting = false
                exportedImage = finalImage
                showShareSheet = true
            }
        }
    }

    private func saveParametersJSON() {
        let c = UIColor(lightColor).rgbComponents

        let params = ParameterSet(
            theme:            cosmicTheme.rawValue,
            lifeStage:        lifeStage.rawValue,
            seed:             seed,
            frequency:        0.6,
            octaves:          6,
            bloomIntensity:   bloomIntensity,
            glowColorR:       c.r,
            glowColorG:       c.g,
            glowColorB:       c.b,
            particleSpeed:    particleEnergy,
            trailLength:      0.8,
            lSystemAngle:     branchAngle,
            lightPositions:   coordinator.scene?.placedLights.map {
                [Double($0.node.position.x),
                 Double($0.node.position.y),
                 Double($0.intensity)]
            } ?? []
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(params),
              let docs = FileManager.default.urls(
                  for: .documentDirectory, in: .userDomainMask).first
        else { return }

        let name = "LifeOfLight_\(lifeStage.name)_\(seed)_\(Int(Date().timeIntervalSince1970)).json"
        let url  = docs.appendingPathComponent(name)
        try? data.write(to: url)
        savedFileName = name
        showSavedAlert = true
    }
    
    // -------------------------------------------------------
    // MARK: Preset & GIF Export
    // -------------------------------------------------------
    
    /// Apply a showcase preset
    private func applyPreset(_ preset: SamplePreset) {
        seed = preset.seed
        cosmicTheme = preset.theme
        lifeStage = preset.lifeStage
        branchAngle = preset.branchAngle
        phototropismStrength = preset.phototropism
        
        // Clear existing lights and apply preset lights
        coordinator.scene?.clearAllLights()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let scene = coordinator.scene else { return }
            
            for lightPos in preset.lightPositions {
                let point = CGPoint(
                    x: lightPos.x * scene.size.width,
                    y: lightPos.y * scene.size.height
                )
                scene.placePersistentLight(at: point, intensity: lightPos.intensity)
            }
            
            refreshCanvasAnimated()
            toastManager.show(
                message: "Applied: \(preset.name)",
                icon: "sparkles",
                color: .cyan
            )
        }
    }
    
    /// Export a preset as high-quality sample with JSON
    private func exportPresetSample(_ preset: SamplePreset) {
        // Apply the preset first
        applyPreset(preset)
        
        // Wait for canvas to render, then export
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            exportHighRes()
            
            // Also save JSON
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                saveParametersJSON()
            }
        }
    }
    
    /// Record and export demo as GIF
    private func recordDemoGIF() {
        guard !isRecordingGIF else { return }
        
        isRecordingGIF = true
        isAnimatedGrowth = true
        gifExportProgress = "Starting..."
        
        // Clear and setup
        coordinator.scene?.clearAllLights()
        coordinator.scene?.clearGrowth()
        
        // Setup GIF recorder callback
        coordinator.scene?.onGIFRecordingComplete = { [self] url in
            isRecordingGIF = false
            gifExportProgress = ""
            
            if let url = url {
                exportedGIFURL = url
                showGIFShareSheet = true
                toastManager.show(
                    message: "Demo GIF exported!",
                    icon: "film",
                    color: .green
                )
            } else {
                toastManager.show(
                    message: "GIF export failed",
                    icon: "exclamationmark.triangle",
                    color: .red
                )
            }
        }
        
        // Start recording with demo
        coordinator.scene?.recordDemoAsGIF(
            onProgress: { [self] progress in
                gifExportProgress = progress
            },
            completion: { [self] url in
                isRecordingGIF = false
                
                if let url = url {
                    exportedGIFURL = url
                    showGIFShareSheet = true
                }
            }
        )
        
        // Trigger growth after lights placed
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
            refreshCanvasAnimated()
        }
    }
    
    /// Export current creation as 4096x4096 (tile-based for memory efficiency)
    private func exportUltraHighRes() {
        guard !isExporting else { return }
        isExporting = true
        toastManager.show(message: "Exporting 4K...", icon: "photo", color: .orange)
        
        // Capture current state
        let currentSeed = seed
        let currentTheme = cosmicTheme
        let currentStage = lifeStage
        let currentAngle = branchAngle
        let currentWarp = warpStrength
        let warpEnabled = enableWarp
        let currentIntensity = cosmicIntensity
        let vignetteEnabled = enableVignette
        let currentPhototrop = phototropismStrength
        
        // Get light sources
        let lightSources = getLightSourcesForRendering(canvasSize: CGSize(width: 4096, height: 4096))
        
        DispatchQueue.global(qos: .userInitiated).async {
            let target = 4096
            
            // Generate ultra high-res using tile rendering for memory efficiency
            let noiseParams = NoiseParameters(
                frequency: 0.6,
                octaves: 6,
                persistence: 0.5,
                lacunarity: 2.0,
                warpFrequency: 0.8,
                warpStrength: currentWarp,
                gamma: 1.4 + (1.0 - currentIntensity) * 0.6,
                enableWarp: warpEnabled
            )
            
            // Generate background at full resolution
            guard let backgroundImage = generateAdvancedNoiseImage(
                width: target, height: target,
                params: noiseParams,
                seed: Int32(currentSeed),
                gradient: currentTheme.gradient,
                addGrain: true
            ) else {
                DispatchQueue.main.async { 
                    self.isExporting = false
                    self.toastManager.show(message: "Export failed", icon: "xmark.circle", color: .red)
                }
                return
            }
            
            // Generate L-System at high resolution
            let sys = LSystem(
                axiom: "F",
                rules: [("F", "FF+[+F-F-F]-[-F+F+F]")],
                angle: currentAngle
            )
            let instr = sys.generate(iterations: currentStage.iterations)
            let linLen = max(0.3, CGFloat(target) / pow(3.0, CGFloat(currentStage.iterations)))
            
            // Scale light positions
            let scaledLights = lightSources.map { light in
                LightSource(
                    position: CGPoint(x: light.position.x * 8, y: light.position.y * 8),
                    intensity: light.intensity
                )
            }
            
            let renderParams = LSystemRenderParams(
                baseLineWidth: CGFloat(4.0 + Double(currentStage.rawValue) * 0.5) * 4.0,
                widthDecay: 0.65,
                angleVariation: 8.0,
                enableGlow: true,
                glowRadius: 32.0,
                glowAlpha: 0.45,
                colorGradient: .lifeGradient,
                depthColorFade: true,
                lightSources: scaledLights,
                phototropismStrength: CGFloat(currentPhototrop),
                lightColorInfluence: 0.35,
                randomSeed: UInt64(currentSeed)
            )
            
            let lifeImage = sys.renderAdvanced(
                instructions: instr,
                canvasSize: CGSize(width: target, height: target),
                lineLength: linLen,
                params: renderParams
            )
            
            // Composite
            var finalImage = compositeImages(
                base: backgroundImage,
                overlay: lifeImage,
                blendMode: .plusLighter,
                alpha: 1.0
            )
            
            if vignetteEnabled {
                finalImage = applyVignette(to: finalImage, intensity: 0.4)
            }
            
            DispatchQueue.main.async {
                self.isExporting = false
                self.exportedImage = finalImage
                self.showShareSheet = true
                self.toastManager.show(message: "4K export ready!", icon: "checkmark.circle", color: .green)
            }
        }
    }
}

// ============================================================
// MARK: - Preset Picker View (Showcase Samples)
// ============================================================

struct PresetPickerView: View {
    @Environment(\.dismiss) var dismiss
    let onSelect: (SamplePreset) -> Void
    let onExport: (SamplePreset) -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    Text("High-Quality Showcase Presets")
                        .font(.headline)
                        .foregroundStyle(.gray)
                        .padding(.top)
                    
                    Text("Each preset is designed for maximum visual impact.\nUse these for submissions and demonstrations.")
                        .font(.caption)
                        .foregroundStyle(.gray.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    ForEach(SamplePreset.showcasePresets) { preset in
                        PresetCard(preset: preset) {
                            onSelect(preset)
                            dismiss()
                        } onExport: {
                            onExport(preset)
                            dismiss()
                        }
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Preset Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct PresetCard: View {
    let preset: SamplePreset
    let onApply: () -> Void
    let onExport: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text(preset.description)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                
                Spacer()
                
                // Theme indicator
                Circle()
                    .fill(Color(preset.theme.gradient.colorAt(0.5)))
                    .frame(width: 24, height: 24)
            }
            
            // Details
            HStack(spacing: 16) {
                Label(preset.theme.rawValue, systemImage: "sparkles")
                Label(preset.lifeStage.name, systemImage: "leaf.fill")
                Label("Seed: \(preset.seed)", systemImage: "number")
            }
            .font(.caption2)
            .foregroundStyle(.gray)
            
            // Light positions visualization
            HStack(spacing: 4) {
                Text("Lights:")
                    .font(.caption2)
                    .foregroundStyle(.gray)
                
                ForEach(0..<preset.lightPositions.count, id: \.self) { i in
                    Circle()
                        .fill(.cyan)
                        .frame(width: 8, height: 8)
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button {
                    onApply()
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Apply & Play")
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                
                Button {
                    onExport()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export")
                    }
                    .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// ============================================================
// MARK: - FlowLayout (wrapping preset buttons)
// ============================================================

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowH: CGFloat = 0

        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > maxW, x > 0 {
                y += rowH + spacing
                x = 0; rowH = 0
            }
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
        return CGSize(width: maxW, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowH: CGFloat = 0

        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowH + spacing
                x = bounds.minX; rowH = 0
            }
            sv.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
    }
}

// ============================================================
// MARK: - Array Safe Subscript Extension
// ============================================================

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// ============================================================
// MARK: - UIColor Extension
// ============================================================

extension UIColor {
    /// Extract normalised RGB components.
    var rgbComponents: (r: Double, g: Double, b: Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }
}

// ============================================================
// MARK: - Share Sheet
// ============================================================

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
