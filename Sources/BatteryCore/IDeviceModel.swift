import Foundation

/// Facts about iPhone and iPad models that the device doesn't report itself.
public enum IDeviceModel {
    /// The cycles Apple rates the battery for: 1000 for an iPad and for iPhone 15 and later
    /// (`iPhone15,4`, `iPhone15,5` and every `iPhone16,x` on), 500 for an earlier iPhone, `nil`
    /// when the model is unknown. A gauge that publishes its own rating
    /// (``IDeviceBattery/designCycleCount``) wins over this table.
    public static func ratedCycles(productType: String?, deviceClass: String?) -> Int? {
        if deviceClass == "iPad" || modelNumber(productType, family: "iPad") != nil { return 1000 }
        guard let (major, minor) = modelNumber(productType, family: "iPhone") else { return nil }
        if major >= 16 || (major == 15 && (minor == 4 || minor == 5)) { return 1000 }
        return 500
    }

    /// The SF Symbol for the device: `ipad` for an iPad, `iphone` otherwise.
    public static func symbolName(deviceClass: String?) -> String {
        deviceClass == "iPad" ? "ipad" : "iphone"
    }

    /// `(18, 2)` for `iPhone18,2`; `nil` unless the identifier has exactly that shape.
    static func modelNumber(_ productType: String?, family: String) -> (major: Int, minor: Int)? {
        guard let productType, productType.hasPrefix(family) else { return nil }
        let numbers = productType.dropFirst(family.count).split(separator: ",", omittingEmptySubsequences: false)
        guard numbers.count == 2, let major = Int(numbers[0]), let minor = Int(numbers[1]), major > 0, minor >= 0
        else { return nil }
        return (major, minor)
    }
}
