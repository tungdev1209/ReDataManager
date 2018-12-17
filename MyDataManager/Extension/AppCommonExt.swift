//
//  App+Ext.swift
//  AppCommonExtension
//
//  Created by Tung Nguyen on 10/20/18.
//  Copyright © 2018 Tung Nguyen. All rights reserved.
//

import UIKit
import WebKit
import CommonCrypto

extension NSObject {
    func toString() -> String {
        return String(describing: self)
    }
}

extension String {
    func localizableString(loc: String) -> String {
        let path = Bundle.main.path(forResource: loc, ofType: "lproj")
        let bundel = Bundle(path: path!)
        return NSLocalizedString(self, tableName: nil, bundle: bundel!, value: "", comment: "")
    }
    
    func substringNumberCharactersOfEndString(_ number: Int) -> String {
        if isEmpty {return ""}
        let fromIndex = index(endIndex, offsetBy: (-1)*number)
        return String(self[fromIndex...])
    }
    
    func isValidEmail() -> Bool {
        if isEmpty {return false}
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
    
    func toData() -> Data? {
        return data(using: String.Encoding.utf8)
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
        var width = 30
        if UIDevice.current.isIpad() {
            width = 40
        }
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: width, height: 30))
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        appendToCustomView(imageView)
        return self
    }
    
    private func appendToCustomView(_ view: UIView) {
        if customView == nil {
            let itemView = UIStackView(frame: CGRect(x: 0, y: 0, width: 0, height: 44))
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
        var width: CGFloat = 0.0
        for v in stackView.arrangedSubviews {
            if v is UILabel {
                width += 40.0
            }
            if v is UIImageView {
                width += 30.0
            }
        }
        var frame = stackView.frame
        frame.size.width = width
        stackView.frame = frame
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

private var kLoadHTMLCompletion: UInt8 = 0
private var kNavigationHandler: UInt8 = 0
extension WKWebView {
    typealias HTMLCompletion = (() -> Void)
    
    var loadHTMLCompletion: HTMLCompletion? {
        get {
            return objc_getAssociatedObject(self, &kLoadHTMLCompletion) as? HTMLCompletion
        }
        set(block) {
            objc_setAssociatedObject(self, &kLoadHTMLCompletion, block, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    private var navigationHandler: WKNavigationDelegate? {
        get {
            return objc_getAssociatedObject(self, &kNavigationHandler) as? WKNavigationDelegate
        }
        set(handler) {
            objc_setAssociatedObject(self, &kNavigationHandler, handler, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    func loadHTMLString(_ string: String, baseURL: URL?, completion: (() -> Void)?) {
        loadHTMLCompletion = completion
        navigationHandler = WebNavigationHandler()
        navigationDelegate = navigationHandler
        loadHTMLString(string, baseURL: baseURL)
    }
}

class WebNavigationHandler: NSObject, WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.loadHTMLCompletion?()
    }
}

extension NSLayoutConstraint {
    static func activateFullViewFor(_ view: UIView) -> (left: NSLayoutConstraint, top: NSLayoutConstraint, width: NSLayoutConstraint, height: NSLayoutConstraint) {
        view.translatesAutoresizingMaskIntoConstraints = false
        let w = NSLayoutConstraint(item: view, attribute: NSLayoutConstraint.Attribute.width, relatedBy: NSLayoutConstraint.Relation.equal, toItem: view.superview, attribute: NSLayoutConstraint.Attribute.width, multiplier: 1.0, constant: 0.0)
        let h = NSLayoutConstraint(item: view, attribute: NSLayoutConstraint.Attribute.height, relatedBy: NSLayoutConstraint.Relation.equal, toItem: view.superview, attribute: NSLayoutConstraint.Attribute.height, multiplier: 1.0, constant: 0.0)
        let top = NSLayoutConstraint(item: view, attribute: NSLayoutConstraint.Attribute.top, relatedBy: NSLayoutConstraint.Relation.equal, toItem: view.superview, attribute: NSLayoutConstraint.Attribute.top, multiplier: 1.0, constant: 0.0)
        let left = NSLayoutConstraint(item: view, attribute: NSLayoutConstraint.Attribute.left, relatedBy: NSLayoutConstraint.Relation.equal, toItem: view.superview, attribute: NSLayoutConstraint.Attribute.left, multiplier: 1.0, constant: 0.0)
        let constraints = [left, top, w, h]
        NSLayoutConstraint.activate(constraints)
        return (left, top, w, h)
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
    
    func getAppName() -> String {
        var appName = ""
        if let name = object(forInfoDictionaryKey: "CFBundleName") as? String {
            appName = name
        }
        return appName
    }
    
    func getAppVersion() -> String {
        var version = ""
        if let v = object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            version = v
        }
        return version
    }
}

extension FileManager {
    func createDirectoryIfNeeded(_ path: String, attributes: [FileAttributeKey: Any]? = nil) -> Bool {
        var existing = fileExists(atPath: path)
        if !existing {
            do {
                try createDirectory(atPath: path, withIntermediateDirectories: true, attributes: attributes)
                existing = true
            } catch {
                print("Failed to create dir at path: \(path)")
            }
        }
        return existing
    }
    
    func encryptAESFileAt(_ path: String, newPath: String, key: [UInt8], iv: [UInt8]) -> Bool {
        guard let file = contents(atPath: path),
            let encData = file.toAESencrypted(key, iv: iv) else {return false}
        var success = false
        do {
            try encData.write(to: URL(fileURLWithPath: newPath), options: Data.WritingOptions.completeFileProtection)
            try removeItem(at: URL(fileURLWithPath: path))
            success = true
        } catch {
            print("Failed to decrypt file error - \(error)")
        }
        return success
    }
    
    func decryptAESFileAt(_ path: String, newPath: String, key: [UInt8], iv: [UInt8]) -> Bool {
        guard let file = contents(atPath: path),
            let decData = file.toAESdecrypted(key, iv: iv) else {return false}
        var success = false
        do {
            try decData.write(to: URL(fileURLWithPath: newPath), options: Data.WritingOptions.completeFileProtection)
            try removeItem(at: URL(fileURLWithPath: path))
            success = true
        } catch {
            print("Failed to decrypt file error - \(error)")
        }
        return success
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
    
    func toAESKey(_ length: Int = kCCKeySizeAES256) -> Data? {
        var status = Int32(0)
        var derivedBytes = [UInt8](repeating: 0, count: length)
        let salt = Data.randomSalt()
        withUnsafeBytes { (passwordBytes: UnsafePointer<Int8>!) in
            salt.withUnsafeBytes { (saltBytes: UnsafePointer<UInt8>!) in
                status = CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2),
                                              passwordBytes,
                                              count,
                                              saltBytes,
                                              salt.count,
                                              CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),
                                              10000,
                                              &derivedBytes,
                                              length)
            }
        }
        if status == 0 {
            return Data(bytes: UnsafePointer<UInt8>(derivedBytes), count: length)
        }
        print("Failed to gen key - error: \(status)")
        return nil
    }
    
    func toAESencrypted(_ key: [UInt8], iv: [UInt8]) -> Data? {
        return toAESencrypted(Data.init(bytes: key), iv: Data.init(bytes: iv))
    }
    
    func toAESencrypted(_ key: Data, iv: Data) -> Data? {
        if key.count == 16 {
            return toAEScrypted(key, iv: iv, operation: kCCEncrypt, size: kCCKeySizeAES128)
        }
        if key.count == 32 {
            return toAEScrypted(key, iv: iv, operation: kCCEncrypt, size: kCCKeySizeAES256)
        }
        return toAEScrypted(key, iv: iv, operation: kCCEncrypt, size: kCCKeySizeAES192)
    }
    
    func toAESdecrypted(_ key: [UInt8], iv: [UInt8]) -> Data? {
        return toAESdecrypted(Data(bytes: key), iv: Data(bytes: iv))
    }
    
    func toAESdecrypted(_ key: Data, iv: Data) -> Data? {
        if key.count == 16 {
            return toAEScrypted(key, iv: iv, operation: kCCDecrypt, size: kCCKeySizeAES128)
        }
        if key.count == 32 {
            return toAEScrypted(key, iv: iv, operation: kCCDecrypt, size: kCCKeySizeAES256)
        }
        return toAEScrypted(key, iv: iv, operation: kCCDecrypt, size: kCCKeySizeAES192)
    }
    
    func toAEScrypted(_ key: Data, iv: Data, operation: Int, size: Int) -> Data? {
        let data = self as NSData
        let ivData = iv as NSData
        let keyData = key as NSData
        
        let cryptLength = size_t(data.length + kCCBlockSizeAES128)
        var cryptData = Data(count: cryptLength)
        
        var numBytesCrypted: size_t = 0
        
        let cryptStatus = cryptData.withUnsafeMutableBytes { cryptBytes in
            CCCrypt(CCOperation(operation), //kCCDecrypt
                CCAlgorithm(kCCAlgorithmAES),
                CCOptions(kCCOptionPKCS7Padding),
                keyData.bytes, size_t(size), //kCCKeySizeAES128
                ivData.bytes,
                data.bytes, data.length,
                cryptBytes, cryptLength,
                &numBytesCrypted)
        }
        
        if UInt32(cryptStatus) == UInt32(kCCSuccess) {
            cryptData.removeSubrange(numBytesCrypted..<cryptData.count)
        }
        else {
            print("Failed to crypt - error: \(cryptStatus)")
        }
        
        return cryptData
    }
    
    func toUIImage() -> UIImage? {
        return UIImage(data: self)
    }
    
    static func randomIv() -> Data {
        return random(length: kCCBlockSizeAES128)
    }
    
    static func randomSalt() -> Data {
        return random(length: 8)
    }
    
    static func random(length: Int) -> Data {
        var data = Data(count: length)
        let _ = data.withUnsafeMutableBytes { mutableBytes in
            SecRandomCopyBytes(kSecRandomDefault, length, mutableBytes)
        }
        return data
    }
}

extension Float {
    func toString() -> String {
        return String(describing: self)
    }
}

extension Int {
    func toString() -> String {
        return String(describing: self)
    }
}

extension Error {
    func toString() -> String {
        return String(describing: self)
    }
}

extension Dictionary {
    func toString() -> String {
        guard let profileData = try? JSONSerialization.data(withJSONObject: self, options: JSONSerialization.WritingOptions.prettyPrinted) else {return ""}
        return profileData.toString()
    }
    
    func toData() -> Data? {
        return try? JSONSerialization.data(withJSONObject: self)
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

extension UIResponder {
    var parentViewController: UIViewController? {
        return (self.next as? UIViewController) ?? self.next?.parentViewController
    }
}
