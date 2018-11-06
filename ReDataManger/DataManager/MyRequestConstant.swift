//
//  MyRequestConstant.swift
//  ReDataManager
//
//  Created by Tung Nguyen on 10/4/18.
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
