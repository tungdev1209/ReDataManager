//
//  App+Ext.swift
//  AppCommonExtension
//
//  Created by Tung Nguyen on 10/20/18.
//  Copyright © 2018 Tung Nguyen. All rights reserved.
//

import UIKit
import CommonCrypto

extension String {
    func localizableString(loc: String) -> String {
        let path = Bundle.main.path(forResource: loc, ofType: "lproj")
        let bundel = Bundle(path: path!)
        return NSLocalizedString(self, tableName: nil, bundle: bundel!, value: "", comment: "")
    }
    
    func substringNumberCharactersOfEndString(_ number: Int) -> String {
        let fromIndex = index(endIndex, offsetBy: (-1)*number)
        return String(self[fromIndex...])
    }
    
    func isValidEmail() -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,4}"
        let pred = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return pred.evaluate(with: self)
    }
    
    func isValidAppDeepLinkUrl() -> Bool {
        if let url = Bundle.main.getAppUrlSchemes().first, !url.isEmpty, contains(url) {
            return true
        }
        return false
    }
    
    func dataFromJPGBase64() -> Data? {
        let plainBase64String = self.replacingOccurrences(of: "data:image/jpg;base64,", with: "")
        return Data(base64Encoded: plainBase64String, options: .ignoreUnknownCharacters)
    }
    
    func to128BarImage() -> UIImage? {

        let data = self.data(using: String.Encoding.ascii)
        
        if let filter = CIFilter(name: "CICode128BarcodeGenerator") {
            filter.setDefaults()
            filter.setValue(7.00, forKey: "inputQuietSpace")
            filter.setValue(data, forKey: "inputMessage")
            let transform = CGAffineTransform(scaleX: 3, y: 3)
            
            if let output = filter.outputImage?.transformed(by: transform) {
                let context:CIContext = CIContext.init(options: nil)
                let cgImage:CGImage = context.createCGImage(output, from: output.extent)!
                let rawImage:UIImage = UIImage.init(cgImage: cgImage)
                
                let cgimage: CGImage = (rawImage.cgImage)!
                let cropZone = CGRect(x: 0, y: 0, width: Int(rawImage.size.width), height: Int(rawImage.size.height))
                let cWidth: size_t  = size_t(cropZone.size.width)
                let cHeight: size_t  = size_t(cropZone.size.height)
                let bitsPerComponent: size_t = cgimage.bitsPerComponent
                let bytesPerRow = (cgimage.bytesPerRow) / (cgimage.width  * cWidth)
                
                let context2: CGContext = CGContext(data: nil, width: cWidth, height: cHeight, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: cgimage.bitmapInfo.rawValue)!
                
                context2.draw(cgimage, in: cropZone)
                
                let result: CGImage  = context2.makeImage()!
                let finalImage = UIImage(cgImage: result)
                
                return finalImage
                
            }
        }
        
        return nil
    }
    
    func isJPGBase64() -> Bool {
        return self.contains("data:image/jpg;base64,")
    }
}

private var kBackItemSelectedBlock: UInt8 = 0
extension UIBarButtonItem {
    typealias ItemAction = ((UIBarButtonItem) -> Void)
    
    var itemSelected: ItemAction? {
        get {
            return objc_getAssociatedObject(self, &kBackItemSelectedBlock) as? ItemAction
        }
        set(item) {
            objc_setAssociatedObject(self, &kBackItemSelectedBlock, item, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    func title(_ t: String) -> UIBarButtonItem {
        title = t
        let titleView = UILabel()
        titleView.text = title
        titleView.textColor = UIColor(displayP3Red: 26/255, green: 148/255, blue: 239/255, alpha: 1)
        appendToCustomView(titleView)
        return self
    }
    
    func image(_ i: UIImage?) -> UIBarButtonItem {
        image = i
        var width = 23
        if UIDevice.current.isIpad() {
            width = 40
        }
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: width, height: 44))
        imageView.image = image
        imageView.contentMode = .scaleAspectFill
        appendToCustomView(imageView)
        return self
    }
    
    private func appendToCustomView(_ view: UIView) {
        if customView == nil {
            let itemView = UIStackView(frame: CGRect(x: 0, y: 0, width: 70, height: 44))
            itemView.axis = NSLayoutConstraint.Axis.horizontal
            itemView.alignment = .fill
            itemView.distribution = .fill
            customView = itemView
        }
        guard let stackView = customView as? UIStackView else {return}
        if view is UILabel {
            stackView.addArrangedSubview(view)
        }
        else if view is UIImageView {
            stackView.insertArrangedSubview(view, at: 0)
        }
    }
    
    func selectionBlock(_ block: ItemAction?) -> UIBarButtonItem {
        itemSelected = block
        let tap = UITapGestureRecognizer(target: self, action: #selector(itemAction(_:)))
        customView?.addGestureRecognizer(tap)
        customView?.isUserInteractionEnabled = true
        return self
    }
    
    @objc private func itemAction(_ item: UIBarButtonItem) {
        itemSelected?(item)
    }
}

extension UINavigationBar {
    func transparent() {
        setBackgroundImage(UIImage(), for: .default)
        shadowImage = UIImage()
        isTranslucent = true
    }
}

extension Bundle {
    func contentsOfFile(_ fileName: String?, type: String?) -> String? {
        guard let path = path(forResource: fileName, ofType: type) else {return nil}
        return try? String(contentsOfFile: path, encoding: String.Encoding.utf8)
    }
    
    func pathDirectoryURL() -> URL {
        return URL(fileURLWithPath: bundlePath, isDirectory: true)
    }
    
    func getAppUrlSchemes() -> [String] {
        var urls = [String]()
        if let urlSchemesDic = object(forInfoDictionaryKey: "CFBundleURLTypes") as? [Dictionary<String, [String]>],
            let _urls = urlSchemesDic.first?["CFBundleURLSchemes"] {
            urls = _urls
        }
        return urls
    }
}

extension UIDevice {
    func isIpad() -> Bool {
        return userInterfaceIdiom == .pad
    }
    
    func isIphone() -> Bool {
        return userInterfaceIdiom == .phone
    }
}

extension Data {
    func toJSON() -> Any? {
        return try? JSONSerialization.jsonObject(with: self, options: JSONSerialization.ReadingOptions.allowFragments)
    }
    
    func toString() -> String {
        return String(data: self, encoding: .utf8) ?? ""
    }
    
    func toModel<T: Decodable>(_ type: T.Type) -> T? {
        let decoder = JSONDecoder()
        do {
            let model = try decoder.decode(T.self, from: self)
            return model
        }
        catch {
            print("Failed to parse \(String(describing: T.self)) - error: \(error)")
            return nil
        }
    }
    
    func aes128(_ key: [UInt8], iv: [UInt8]) -> Data? {
        return aes128(Data.init(bytes: key), iv: Data.init(bytes: iv))
    }
    
    func aes128(_ key: Data, iv: Data) -> Data? {
        let data = self as NSData
        let ivData = iv as NSData
        let keyData = key as NSData
        
        let cryptLength = size_t(count + kCCBlockSizeAES128)
        var cryptData = Data(count: cryptLength)
        
        let keyLength = size_t(kCCKeySizeAES128)
        let options = CCOptions(kCCOptionPKCS7Padding)
        
        var numBytesEncrypted: size_t = 0
        
        let cryptStatus = cryptData.withUnsafeMutableBytes { cryptBytes in
            CCCrypt(CCOperation(kCCEncrypt),
                    CCAlgorithm(kCCAlgorithmAES),
                    options,
                    keyData.bytes, keyLength,
                    ivData.bytes,
                    data.bytes, count,
                    cryptBytes, cryptLength,
                    &numBytesEncrypted)
        }
        
        if UInt32(cryptStatus) == UInt32(kCCSuccess) {
            cryptData.removeSubrange(numBytesEncrypted..<cryptData.count)
        }
        else {
            print("Failed to encrypt - error: \(cryptStatus)")
        }
        
        return cryptData
    }
    
    func toJPGBase64() -> String {
        return "data:image/jpg;base64," + self.base64EncodedString()
    }
    
    func toUIImage() -> UIImage? {
        return UIImage(data: self)
    }
}

extension Dictionary {
    func toString() -> String {
        guard let profileData = try? JSONSerialization.data(withJSONObject: self, options: JSONSerialization.WritingOptions.prettyPrinted) else {return ""}
        return profileData.toString()
    }
}

extension KeyedDecodingContainer {
    func decode<T>(_ key: KeyedDecodingContainer<K>.Key, defaultValue: T) -> T {
        do {
            switch defaultValue.self {
            case is Bool:
                return try decode(Bool.self, forKey: key) as! T
                
            case is Int:
                return try decode(Int.self, forKey: key) as! T
                
            case is String:
                return try decode(String.self, forKey: key) as! T
                
            case is Double:
                return try decode(Double.self, forKey: key) as! T
                
            default:
                return try decode(Float.self, forKey: key) as! T
            }
        } catch {
            return defaultValue
        }
    }
    
    func decode<T: Codable>(_ key: KeyedDecodingContainer<K>.Key, defaultType: T.Type) -> T? {
        do {
            return try decode(defaultType.self, forKey: key)
        } catch {
            return nil
        }
    }
}

extension Encodable {
    func toString() -> String {
        let data = try? JSONEncoder().encode(self)
        return data == nil ? "" : data!.toString()
    }
}

let UUIDQueue = DispatchQueue.init(label: "com.nsuuid.basetime")
extension NSUUID {
    static func createBaseTime() -> String {
        var uuidString: String = ""
        UUIDQueue.sync {
            let uuidSize = MemoryLayout.size(ofValue: uuid_t.self)
            let uuidPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: uuidSize)
            uuid_generate_time(uuidPointer)
            let uuid = NSUUID(uuidBytes: uuidPointer)
            uuidPointer.deallocate()
            uuidString = uuid.uuidString
        }
        return uuidString
    }
}

extension UIColor {
    static var major: UIColor {
        get {
            return UIColor(red: 86.0/255.0, green: 203.0/255.0, blue: 249.0/255.0, alpha: 1.0)
        }
    }
    
    static var appGrey: UIColor {
        get {
            return UIColor(red: 49.0/255.0, green: 59.0/255.0, blue: 78.0/255.0, alpha: 1.0)
        }
    }
    
    static var systemBlue: UIColor {
        get {
            return UIColor(red: 0.0, green: 122.0/255.0, blue: 1.0, alpha: 1.0)
        }
    }
}

extension CGSize {
    static var creditCard: CGSize {
        get {
            return CGSize(width: 348.0, height: 220.0)
        }
    }
}

extension UIView {
    func imageSnapshot() -> UIImage {
        return self.imageSnapshotCroppedToFrame(frame: nil)
    }
    
    func imageSnapshotCroppedToFrame(frame: CGRect?) -> UIImage {
        let scaleFactor = UIScreen.main.scale
        UIGraphicsBeginImageContextWithOptions(bounds.size, false, scaleFactor)
        self.drawHierarchy(in: bounds, afterScreenUpdates: true)
        var image: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        if let frame = frame {
            let scaledRect = frame.applying(CGAffineTransform(scaleX: scaleFactor, y: scaleFactor))
            
            if let imageRef = image.cgImage!.cropping(to: scaledRect) {
                image = UIImage(cgImage: imageRef)
            }
        }
        return image
    }
}
