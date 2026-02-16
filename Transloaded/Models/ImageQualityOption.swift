import CoreGraphics

enum ImageQualityOption: String, CaseIterable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    var maxDimension: CGFloat {
        switch self {
        case .high: return 2560
        case .medium: return 1280
        case .low: return 640
        }
    }

    var compressionQuality: CGFloat {
        switch self {
        case .high: return 0.85
        case .medium: return 0.75
        case .low: return 0.60
        }
    }
}
