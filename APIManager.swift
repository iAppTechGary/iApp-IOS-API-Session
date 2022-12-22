//
//  APIManager.swift
//  AppName
//
//  Created by iApp on 15/07/22.
//

import Foundation
import Alamofire
import UIKit


/// error object will allow to give error
struct  ErrorObject {
    /// error message for the error `descriptio`
    var message: String?
    /// key for the error
    var key: String?
    /// specific code for the given error here
    var statusCode: Int = 0
}

/// different type of `enviroments` for the server
enum NetworkEnvironment {
    /// `dev` - used for develpment perpose - all the develppment will be done by this server
    /// dev server currently not available
    case dev
    
    /// `production` - used for the production - to work server path for production to make live
    /// this is the running server for now
    case production
    
    /// `stage` used for different stages - currently not available
    case stage
    
    /// `stage` used for different stages - currently not available
    case advancedMode
}

/// `APIManager`
/// ---------- responsing for the server session
/// -------- will able to hit all the  `endpoints` for every querey
/// ---------- genric functions used for the genral modulation  using `T`
/// -------- this have shared instacnce for the current session , `shared` instacne will be used in the current session
/// --------- whole `API's` gonna depend on this manager at all, no need to create another
class APIManager: NSObject {
    
    /// `shared` session for the manager
    /// currently will available for single app session
    private let sessionManager: Session
    static let networkEnviroment: NetworkEnvironment = .production
    
    // MARK: - Vars & Lets
    private static var sharedApiManager: APIManager = {
        let apiManager = APIManager(sessionManager: Session())
        return apiManager
    }()
    
    // MARK: - Accessors
    class func shared() -> APIManager {
        return sharedApiManager
    }
    
    // MARK: - Initialization
    private init(sessionManager: Session) {
        self.sessionManager = sessionManager
    }
    
    var isInternetAvailable:Bool {
        if (NetworkReachabilityManager()?.isReachable ?? false){
            return true
        }
        return false
    }
    
    
    func call<T>(type: EndPointType, params: Parameters? = nil, success: @escaping (T?)->(),_ failure: @escaping (_ error: ErrorObject?)->()) -> DataRequest where T: Codable {
        
        let dataRequest = self.sessionManager.request(type.url, method: type.httpMethod, parameters: params,  encoding: type.encoding,
                                                      headers: type.headers).validate().responseData(completionHandler: { data in
            switch data.result {
            case .success( _):
                let decoder = JSONDecoder()
                if let jsonData = data.data {
                    do {
                        let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String:Any]
                        debugPrint("JSON result", json ?? "Json is not in correct format")
                        let results = try decoder.decode(T.self, from: jsonData)
                        success(results)
                    } catch let error {
                        print(error.localizedDescription)
                        failure(ErrorObject(message: "Error to load data, Please try after sometime.", key: nil,statusCode: 0))
                    }
                } else {
                    failure(ErrorObject(message: "Error to load data, Please try after sometime.", key: nil,statusCode: 0))
                }
                break
            case .failure(let failed):
                failure(ErrorObject(message: failed.errorDescription, key: nil,statusCode: failed.responseCode ?? 0))
                break
            }
        })
        return dataRequest
    }
   
    func uploadFile<T>(type: EndPointType, params: Parameters? = nil,imageToUpload: UIImage?,uploadProgress: @escaping(_ progress:Float) -> Void , success: @escaping (T?, UIImage?)->(),_  failure: @escaping (_ error: ErrorObject?)->()) -> UploadRequest where T: Codable {
        let uploadRequest = self.sessionManager.upload(multipartFormData: {[weak self] (multipartFormData) in
            if params != nil {
                for (key, value) in params! {
                    multipartFormData.append("\(value)".data(using: String.Encoding.utf8)!, withName: key as String)
                }
            }
            if var fileName = self?.getName() {
                fileName += ".jpg"
                if imageToUpload != nil {
                    let imageData = imageToUpload!.jpegData(compressionQuality: 1.0)
                    if let data = imageData{
                        multipartFormData.append(data, withName: "file", fileName:  fileName, mimeType: "image/jpeg")
                    }
                }
            }
        }, to: type.url, usingThreshold: UInt64.init(), method: type.httpMethod, headers: type.headers) { (encodedResults) in
            
        }.uploadProgress { progress in
            
            print("uploading progress Total Unit Count is ",progress.totalUnitCount, "Upload Count", progress.completedUnitCount)
            
            let percentage = Float(progress.completedUnitCount) / Float(progress.totalUnitCount)
            
            uploadProgress(percentage)
            
        }.validate().responseData { data in
            switch data.result {
            case .success( _):
                if let jsonData = data.data {
                    if let resultImage = UIImage(data: jsonData){
                        success(nil, resultImage)
                    }else{
                        let decoder = JSONDecoder()
                        let result = try! decoder.decode(T.self, from: jsonData)
                        success(result, nil)
                    }
                } else {
                    failure(ErrorObject(message: "Error to load data, Please try after sometime.", key: nil,statusCode: 0))
                }
                break
            case .failure(let failed):
                failure(ErrorObject(message: failed.errorDescription, key: nil,statusCode: failed.responseCode ?? 0))
                break
            }
        }
        return uploadRequest
    }

}
