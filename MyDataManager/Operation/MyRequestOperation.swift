//
//  MyRequest.swift
//  MyRequestOperation
//
//  Created by Tung Nguyen on 10/3/18.
//  Copyright © 2018 Tung Nguyen. All rights reserved.
//

import UIKit

enum RequestMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
}

enum ImageType {
    case PNG
    case JPEG(_ quality: CGFloat)
    case Unknown
    
    var rawValue: String {
        switch self {
        case .PNG:
            return "PNG"
            
        case .JPEG(_):
            return "JPEG"
            
        default:
            return ""
        }
    }
    
    var mimeType: String {
        switch self {
        case .JPEG(_):
            return "image/jpeg"
            
        case .PNG:
            return "image/png"
            
        default:
            return ""
        }
    }
}

enum MyError: Error {
    case InvalidUrl
    case InvalidImageData
    case ParseDataFail
    case DataNil
    case None
}

enum HeaderValue {
    case Bearer(_ token: String)
    case AppJSON
    case Multipart(_ boundary: String)
    case FormUrlencoded
    
    var value: String {
        switch self {
        case let .Bearer(token):
            return "bearer \(token)"
            
        case .AppJSON:
            return "application/json"
            
        case .FormUrlencoded:
            return "application/x-www-form-urlencoded"
            
        case let .Multipart(boundary):
            return "multipart/form-data; boundary=\(boundary)"
        }
    }
}

enum HeaderKey {
    case Authorization(_ value: HeaderValue)
    case ContentType(_ value: HeaderValue)
    case Accept(_ value: HeaderValue)
    case None
    
    var value: [String: String] {
        switch self {
        case let .Authorization(type):
            return ["Authorization": type.value]
            
        case let .ContentType(type):
            return ["Content-Type" : type.value]
            
        case let .Accept(type):
            return ["Accept" : type.value]
            
        default:
            return [:]
        }
    }
}

extension Dictionary {
    mutating func merge(dict: [Key: Value]) {
        for (k, v) in dict {
            updateValue(v, forKey: k)
        }
    }
}

class Header {
    var headers = [String: String]()
    func add(_ type: HeaderKey) -> Header {
        headers.merge(dict: type.value)
        return self
    }
    
    func remove(_ type: HeaderKey) -> Header {
        if let key = type.value.keys.first {
            headers.removeValue(forKey: key)
        }
        return self
    }
    
    var value: [String: String] {
        return headers
    }
}

class MyRequestOperation {
    var sessionConfiguration = URLSessionConfiguration.ephemeral
    var sessionDelegate: URLSessionDelegate?
    var sessionDelegateQueue: OperationQueue?
    var requestMethod = RequestMethod.GET
    var cachePolicy = URLRequest.CachePolicy.useProtocolCachePolicy
    var timeout = 60.0
    var secondaryTimeout = 30.0
    var headers = [String: String]()
    var postBody: Data?
    var retryTimes = 3
    var shouldRequestAsynchronously = true
    
    var requestConfiguration: MyRequestConfiguration?
    
    private(set) var urlRequest: URLRequest?
    private(set) var errors: [Error]?
    private(set) var response: URLResponse?
    private(set) var callStack = [String]()
    
    private var synchronousRequestSemaphore: DispatchSemaphore?
    private var responseData: Data?
    
    fileprivate let _id = UUID().uuidString
    typealias MyRequestCompletion = ((Data?, [Error]?, MyRequestOperation) -> Void)
    
    convenience init(_ url: String) {
        self.init()
        if let anURL = URL(string: url) {
            urlRequest = URLRequest(url: anURL, cachePolicy: cachePolicy, timeoutInterval: timeout)
        } else {
            appendError(MyError.InvalidUrl)
        }
    }
    
    convenience init(_ url: URL) {
        self.init()
        urlRequest = URLRequest(url: url, cachePolicy: cachePolicy, timeoutInterval: timeout)
    }
    
    private func appendError(_ error: Error) {
        if errors == nil {
            errors = [Error]()
        }
        errors!.append(error)
    }
    
    func requestConfiguration(_ config: MyRequestConfiguration?) -> MyRequestOperation {
        requestConfiguration = config
        return self
    }
    
    func sessionConfiguration(_ sessionConfig: URLSessionConfiguration) -> MyRequestOperation {
        sessionConfiguration = sessionConfig
        return self
    }
    
    func sessionDelegate(_ delegate: URLSessionDelegate?) -> MyRequestOperation {
        sessionDelegate = delegate
        return self
    }
    
    func sessionDelegateQueue(_ queue: OperationQueue?) -> MyRequestOperation {
        sessionDelegateQueue = queue
        return self
    }
    
    func cachePolicy(_ policy: URLRequest.CachePolicy) -> MyRequestOperation {
        cachePolicy = policy
        return self
    }
    
    func timeoutInterval(_ timeoutInterval: TimeInterval) -> MyRequestOperation {
        timeout = timeoutInterval
        return self
    }
    
    func secondaryTimeoutInterval(_ secTimeoutInterval: TimeInterval) -> MyRequestOperation {
        secondaryTimeout = secTimeoutInterval
        return self
    }
    
    func retryTimes(_ retry: Int) -> MyRequestOperation {
        retryTimes = retry
        return self
    }
    
    func method(_ method: RequestMethod) -> MyRequestOperation {
        requestMethod = method
        return self
    }
    
    func headers(_ requestHeaders: [String: String]) -> MyRequestOperation {
        for field in requestHeaders.keys {
            headers[field] = requestHeaders[field]
        }
        return self
    }
    
    func postData(_ data: Data?) -> MyRequestOperation {
        postBody = data
        return self
    }
    
    func shouldRequestAsynchronously(_ requestAsync: Bool) -> MyRequestOperation {
        shouldRequestAsynchronously = requestAsync
        return self
    }
    
    private func applyConfig() {
        guard let requestConfiguration = requestConfiguration else {return}
        requestMethod = requestConfiguration.requestMethod
        sessionConfiguration = requestConfiguration.sessionConfiguration
        sessionDelegate = requestConfiguration.sessionDelegate
        sessionDelegateQueue = requestConfiguration.sessionDelegateQueue
        cachePolicy = requestConfiguration.cachePolicy
        timeout = requestConfiguration.timeout
        secondaryTimeout = requestConfiguration.secondaryTimeout
        headers = requestConfiguration.headers
        postBody = requestConfiguration.postBody
        retryTimes = requestConfiguration.retryTimes
        shouldRequestAsynchronously = requestConfiguration.shouldRequestAsynchronously
    }
    
    func execute(_ completion: MyRequestCompletion?) {
        guard errors == nil else {
            print("MyRequest - Errors: \(String(describing: errors))")
            completion?(nil, errors, self)
            return
        }
        
        MyRequestManager.shared.cacheOperation(self)
        
        callStack = Thread.callStackSymbols
        
        // apply configuration
        applyConfig()
        
        // add headers
        for field in headers.keys {
            urlRequest?.addValue(headers[field]!, forHTTPHeaderField: field)
        }
        
        // add post body
        urlRequest?.httpBody = postBody
        
        // add other fields
        urlRequest?.cachePolicy = cachePolicy
        urlRequest?.timeoutInterval = timeout
        urlRequest?.httpMethod = requestMethod.rawValue
        
        if !shouldRequestAsynchronously {
            synchronousRequestSemaphore = DispatchSemaphore(value: 0)
        }
        
        executeRequest(completion)
        
        if !shouldRequestAsynchronously {
            synchronousRequestSemaphore?.wait()
            
            // for sync request
            MyRequestManager.shared.removeOperation(self)
            completion?(self.responseData, self.errors, self)
        }
    }
    
    private func createSession() -> URLSession {
        return URLSession(configuration: sessionConfiguration, delegate: sessionDelegate, delegateQueue: sessionDelegateQueue)
    }
    
    private func executeRequest(_ completion: MyRequestCompletion?) {
        let session = createSession()
        session.dataTask(with: urlRequest!, completionHandler: { [weak self] (data, response, error) in
            guard let _self = self else { return }
            if let _ = error {
                if _self.retryTimes > 0 {
                    session.finishTasksAndInvalidate()
                    _self.retryTimes = _self.retryTimes - 1
                    _self.urlRequest?.timeoutInterval = _self.secondaryTimeout
                    _self.executeRequest(completion)
                    return
                }
                else {
                    _self.appendError(error!)
                }
            }
            _self.responseData = data
            _self.response = response
            session.finishTasksAndInvalidate()
            
            if !_self.shouldRequestAsynchronously {
                _self.synchronousRequestSemaphore?.signal()
            }
            else {
                // for async request
                MyRequestManager.shared.removeOperation(_self)
                completion?(_self.responseData, _self.errors, _self)
            }
        }).resume()
    }
    
    deinit {
        print("=== Request Operation DEALLOC ===")
    }
}

class MyAttachment {
    var boundary = UUID().uuidString
    
    private enum AttachmentType {
        case File(_ path: String)
        case FileData(_ data: Data?)
        case Image(_ image: UIImage, type: ImageType)
    }
    
    private struct Attachment {
        var type = AttachmentType.File("")
        var data: Data?
        var fileExtension = ""
        var fileName = ""
        var field = ""
        
        init(_ attType: AttachmentType) {
            type = attType
            switch attType {
            case let .Image(image, type: imgType):
                fileExtension = imgType.rawValue.lowercased()
                switch imgType {
                case let .JPEG(quality):
                    data = image.jpegData(compressionQuality: quality)
                    
                case .PNG:
                    data = image.pngData()
                    
                default: break
                }
                
            case let .FileData(d):
                data = d
                
            case let .File(path):
                let url = URL(fileURLWithPath: path)
                fileExtension = url.lastPathComponent.components(separatedBy: ".").last.unwrap
                fileName = url.lastPathComponent.components(separatedBy: ".").first.unwrap
                data = try? Data(contentsOf: url)
            }
        }
        
        var fileFullName: String {
            return fileName + ".\(fileExtension)"
        }
        
        var contentType: String {
            switch type {
            case .FileData(_), .File(_):
                return "application/" + fileExtension
                
            case let .Image(_, type: imgType):
                return imgType.mimeType
            }
        }
    }
    
    private(set) var error = MyError.None
    private var attachments = [Attachment]()
    
    func boundary(_ b: String) -> MyAttachment {
        boundary = b
        return self
    }
    
    func attach(image i: UIImage, imageName: String, imageType: ImageType, forField fieldName: String = "") -> MyAttachment {
        var att = Attachment(.Image(i, type: imageType))
        att.fileName = imageName
        att.field = fieldName
        attachments.append(att)
        return self
    }
    
    func attach(filePath path: String, forField fieldName: String = "") -> MyAttachment {
        var att = Attachment(.File(path))
        att.field = fieldName
        attachments.append(att)
        return self
    }
    
    func attach(fileData f: Data, fileName: String, fileExtension: String, forField fieldName: String = "") -> MyAttachment {
        var att = Attachment(.FileData(f))
        att.fileName = fileName
        att.fileExtension = fileExtension
        att.field = fieldName
        attachments.append(att)
        return self
    }
    
    private func createBody(_ attachment: Attachment) -> Data {
        var body = Data()
        body.append("--\(boundary)\r\n".asData.unwrap)
        body.append("Content-Disposition:form-data; name=\"\(attachment.field)\"; filename=\"\(attachment.fileFullName)\"\r\n".asData.unwrap)
        body.append("Content-Type: \(attachment.contentType)\r\n\r\n".asData.unwrap)
        body.append(attachment.data.unwrap)
        body.append("\r\n".asData.unwrap)
        return body
    }
    
    func execute() -> Data {
        var finalData = Data()
        attachments.forEach { finalData.append(createBody($0)) }
        finalData.append("--\(boundary)--\r\n".asData.unwrap)
        return finalData
    }
}

fileprivate class MyRequestManager {
    static let shared = MyRequestManager()
    var operations = [String: MyRequestOperation]()
    let operationQueue = DispatchQueue.init(label: "com.myrequestmanager.operation")
    func cacheOperation(_ operation: MyRequestOperation) {
        operationQueue.sync { [weak self] in
            guard let _self = self else {return}
            _self.operations[operation._id] = operation
        }
    }
    
    func removeOperation(_ operation: MyRequestOperation) {
        operationQueue.sync { [weak self] in
            guard let _self = self else {return}
            _self.operations.removeValue(forKey: operation._id)
        }
    }
}

class MyRequestConfiguration {
    private(set) var requestMethod = RequestMethod.GET
    
    var sessionConfiguration: URLSessionConfiguration = .ephemeral
    var sessionDelegate: URLSessionDelegate?
    var sessionDelegateQueue: OperationQueue?
    var cachePolicy = URLRequest.CachePolicy.useProtocolCachePolicy
    var timeout = 60.0
    var secondaryTimeout = 30.0
    var headers = [String: String]()
    var postBody: Data?
    var retryTimes = 3
    var shouldRequestAsynchronously = true
    
    convenience init(_ method: RequestMethod) {
        self.init()
        requestMethod = method
    }
    
    func sessionConfiguration(_ sessionConfig: URLSessionConfiguration) -> MyRequestConfiguration {
        sessionConfiguration = sessionConfig
        return self
    }
    
    func sessionDelegate(_ delegate: URLSessionDelegate?) -> MyRequestConfiguration {
        sessionDelegate = delegate
        return self
    }
    
    func sessionDelegateQueue(_ queue: OperationQueue?) -> MyRequestConfiguration {
        sessionDelegateQueue = queue
        return self
    }
    
    func cachePolicy(_ policy: URLRequest.CachePolicy) -> MyRequestConfiguration {
        cachePolicy = policy
        return self
    }
    
    func timeoutInterval(_ timeoutInterval: TimeInterval) -> MyRequestConfiguration {
        timeout = timeoutInterval
        return self
    }
    
    func secondaryTimeoutInterval(_ secTimeoutInterval: TimeInterval) -> MyRequestConfiguration {
        secondaryTimeout = secTimeoutInterval
        return self
    }
    
    func retryTimes(_ retry: Int) -> MyRequestConfiguration {
        retryTimes = retry
        return self
    }
    
    func headers(_ requestHeaders: [String: String]) -> MyRequestConfiguration {
        for field in requestHeaders.keys {
            headers[field] = requestHeaders[field]
        }
        return self
    }
    
    func postData(_ data: Data?) -> MyRequestConfiguration {
        postBody = data
        return self
    }
    
    func shouldRequestAsynchronously(_ requestAsync: Bool) -> MyRequestConfiguration {
        shouldRequestAsynchronously = requestAsync
        return self
    }
}

extension Optional where Wrapped == Data {
    var unwrap: Data {
        return self ?? Data()
    }
}

extension Optional where Wrapped == String {
    var unwrap: String {
        return self ?? ""
    }
}

extension String {
    var asData: Data? {
        return data(using: .utf8)
    }
}
