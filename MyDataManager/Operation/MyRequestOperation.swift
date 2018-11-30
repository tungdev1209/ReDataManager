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
}

enum ImageType {
    case PNG
    case JPEG
    case Unknown
}

enum MyError: Error {
    case InvalidUrl
    case InvalidImageData
    case ParseDataFail
    case DataNil
    case None
}

class HeaderField {
    static let ContentType = "Content-Type"
    static let Authorization = "Authorization"
}

class HeaderValue {
    static let MultiPart_FormData = "multipart/form-data"
    static let Application_JSON = "application/json"
    static let CharacterSet_UTF8 = "charset=utf-8"
}

class MyRequestOperation {
    var sessionConfiguration: URLSessionConfiguration = .ephemeral
    var sessionDelegate: URLSessionDelegate?
    var sessionDelegateQueue: OperationQueue?
    var requestMethod = RequestMethod.GET
    var cachePolicy = URLRequest.CachePolicy.useProtocolCachePolicy
    var timeout = 60.0
    var secondaryTimeout = 30.0
    var headers = [String: String]()
    var postBody: Any?
    var retryTimes = 3
    var shouldRequestAsynchronously = true
    
    private(set) var urlRequest: URLRequest?
    private(set) var errors: [Error]?
    private(set) var response: URLResponse?
    private(set) var callStack = [String]()
    
    private var synchronousRequestSemaphore: DispatchSemaphore?
    private var responseData: Data?
    
    fileprivate let _id = NSUUID.createBaseTime()
    typealias MyRequestCompletion = ((Data?, [Error]?, MyRequestOperation) -> Void)
    
    convenience init(_ url: String) {
        self.init()
        if let anURL = URL(string: url) {
            urlRequest = URLRequest(url: anURL, cachePolicy: cachePolicy, timeoutInterval: timeout)
        }
        else {
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
    
    func postImage(_ imageData: MyImageData) -> MyRequestOperation {
        guard postBody == nil else {return self}
        postBody = imageData
        return self
    }
    
    func postData(_ data: Data?) -> MyRequestOperation {
        guard postBody == nil else {return self}
        postBody = data
        return self
    }
    
    func shouldRequestAsynchronously(_ requestAsync: Bool) -> MyRequestOperation {
        shouldRequestAsynchronously = requestAsync
        return self
    }
    
    func execute(_ completion: MyRequestCompletion?) {
        guard errors == nil else {
            print("MyRequest - Errors: \(String(describing: errors))")
            completion?(nil, errors, self)
            return
        }
        
        MyRequestManager.shared.cacheOperation(self)
        
        callStack = Thread.callStackSymbols
        
        // add headers
        for field in headers.keys {
            urlRequest?.addValue(headers[field]!, forHTTPHeaderField: field)
        }
        
        // add post body
        if let body = postBody as? Data {
            urlRequest?.httpBody = body
        }
        else if let imageData = postBody as? MyImageData {
            imageData.execute()
            let _ = headers(imageData.headersAttachment)
            urlRequest?.httpBody = imageData.data
            if imageData.error != .None {
                appendError(imageData.error)
            }
        }
        
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
            completion?(self.responseData, self.errors, self)
            MyRequestManager.shared.removeOperation(self)
        }
    }
    
    private func createSession() -> URLSession {
        return URLSession(configuration: sessionConfiguration, delegate: sessionDelegate, delegateQueue: sessionDelegateQueue)
    }
    
    private func executeRequest(_ completion: MyRequestCompletion?) {
        let session = createSession()
        session.dataTask(with: urlRequest!, completionHandler: { [weak self] (data, response, error) in
            guard let `self` = self else { return }
            if let _ = error {
                if self.retryTimes > 0 {
                    session.finishTasksAndInvalidate()
                    self.retryTimes = self.retryTimes - 1
                    self.urlRequest?.timeoutInterval = self.secondaryTimeout
                    self.executeRequest(completion)
                    return
                }
                else {
                    self.appendError(error!)
                }
            }
            self.responseData = data
            self.response = response
            session.finishTasksAndInvalidate()
            
            if !self.shouldRequestAsynchronously {
                self.synchronousRequestSemaphore?.signal()
            }
            else {
                // for async request
                completion?(self.responseData, self.errors, self)
                MyRequestManager.shared.removeOperation(self)
            }
        }).resume()
    }
    
    deinit {
        print("=== Request Operation DEALLOC ===")
    }
}

class MyImageData {
    var boundary = "Boundary-\(UUID().uuidString)"
    var name = "image"
    var headersAttachment = [String: String]()
    
    private(set) var image: UIImage!
    private(set) var mimeType = ""
    private(set) var data: Data?
    private(set) var error = MyError.None
    private(set) var type = ImageType.Unknown {
        didSet {
            switch type {
            case .PNG:
                mimeType = "image/png"
            default:
                mimeType = "image/jpeg"
            }
        }
    }
    
    convenience init(_ uiImage: UIImage, imageType: ImageType) {
        self.init()
        image = uiImage
        type = imageType
    }
    
    func mimeType(_ mime: String) -> MyImageData {
        mimeType = mime
        return self
    }
    
    func name(_ imageName: String) -> MyImageData {
        name = imageName
        return self
    }
    
    func boundary(_ bound: String) -> MyImageData {
        boundary = bound
        return self
    }
    
    func headersAttachment(_ headers: [String: String]) -> MyImageData {
        for field in headers.keys {
            headersAttachment[field] = headers[field]
        }
        return self
    }
    
    private func createBody(_ imageData: Data) -> Data {
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition:form-data; name=\"attachment\"; filename=\"\(name)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }
    
    func execute() {
        headersAttachment[HeaderField.ContentType] = "\(HeaderValue.MultiPart_FormData); boundary=\(boundary)"
        
        switch type {
        case .PNG:
            guard let imageData = image.pngData() else {
                print("== MyImageData:: Can not get data from png image ==")
                error = .InvalidImageData
                return
            }
            data = createBody(imageData)
            
        case .JPEG:
            guard let imageData = image.jpegData(compressionQuality: 1) else {
                print("== MyImageData:: Can not get data from jpeg image ==")
                error = .InvalidImageData
                return
            }
            data = createBody(imageData)
            
        default:
            break
        }
    }
}

fileprivate class MyRequestManager {
    static let shared = MyRequestManager()
    var operations = [String: MyRequestOperation]()
    let operationQueue = DispatchQueue.init(label: "com.myrequestmanager.operation")
    func cacheOperation(_ operation: MyRequestOperation) {
        operationQueue.sync { [weak self] in
            guard let `self` = self else {return}
            self.operations[operation._id] = operation
        }
    }
    
    func removeOperation(_ operation: MyRequestOperation) {
        operationQueue.sync { [weak self] in
            guard let `self` = self else {return}
            self.operations.removeValue(forKey: operation._id)
        }
    }
}
