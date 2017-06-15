//
//  NetworkMgr.swift
//  LucasBot
//
//  Created by Mirko Justiniano on 1/8/17.
//  Copyright © 2017 LB. All rights reserved.
//

import Foundation
import Alamofire
import SocketIO

class NetworkMgr {
    
    // PROD
    
    //let MESSAGE_API_URL = "https://mariebot.herokuapp.com/bot/send?text="
    //let PAYLOAD_API_URL = "https://mariebot.herokuapp.com/bot/payload?text="
    //let MENU_API_URL    = "https://mariebot.herokuapp.com/bot/menu"
    let SIGN_UP_URL = "https://mariebot.herokuapp.com/user"
    
    // DEV
    let MESSAGE_API_URL = "http://localhost:3000/bot/send?text="
    let PAYLOAD_API_URL = "http://localhost:3000/bot/payload?text="
    let MENU_API_URL    = "http://localhost:3000/bot/menu"
    
    // UNDER CONSTRUCTION
    
    let POST_CLIENT_URL = "http://localhost:3000/clients"
    let AUTHORIZE_TRANSACTION_URL = "http://localhost:3000/oauth2/authorize?"
    let AUTHORIZE_ALLOW_URL = "http://localhost:3000/oauth2/authorize?allow=Allow"
    let TOKEN_URL = "http://localhost:3000/oauth2/token"
    
    /// sharedInstance: the NetworkMgr singleton
    static let sharedInstance = NetworkMgr()
    static let socket = SocketIOClient(socketURL: URL(string: "https://mariebot.herokuapp.com/")!, config: [.log(false), .forcePolling(true)])
    
    let sessionId: String = NSUUID().uuidString
    
    typealias NetworkMgrCallback = (Message?) -> Void
    typealias NetworkMgrReqCallback = (String?) -> Void
    typealias NetworkMgrResCallback = (DataResponse<Any>?) -> Void
    typealias NetworkMgrStringCallback = (DataResponse<String>?) -> Void
    typealias NetworkMgrSocketCallback = (Bool) -> Void
    typealias NetworkMgrMenuCallback = ([MenuButton?]) -> Void
    
    // MARK:- SOCKET API
    
    func initSocket(callback: @escaping NetworkMgrSocketCallback) {
        
        NetworkMgr.socket.on("connect") {data, ack in
            debugPrint("socket connected")
            callback(true)
        }
        
        NetworkMgr.socket.on(DataMgr.sharedInstance.getKey(key: Keys.email.rawValue)!) { data, ack in
            
            debugPrint("socket on data...")
            //debugPrint(data)
            if let msg = data[0] as? String {
                BotMgr.sharedInstance.sendSocketMessage(msg: msg as String)
            }
            else if let obj = data[0] as? NSDictionary {
                if let imgUrl = obj.object(forKey: "imgUrl") as? String {
                    BotMgr.sharedInstance.sendSocketImage(imgUrl: imgUrl as String)
                }
                else if let giphy = obj.object(forKey: "giphy") as? String {
                    let width = obj.object(forKey: "width") as? String
                    let height = obj.object(forKey: "height") as? String
                    BotMgr.sharedInstance.sendSocketGif(url: giphy, width: width!, height: height!)
                }
                else if let menu = obj.object(forKey: "menu") as? NSDictionary {
                    //debugPrint("menu: ", menu)
                    BotMgr.sharedInstance.sendSocketMenu(title: menu.object(forKey: "title") as! String, buttons: menu.object(forKey: "buttons") as! [Any], width: obj.object(forKey: "width") as! String, height: obj.object(forKey: "height") as! String)
                }
                else if let gallery = obj.object(forKey: "gallery") as? NSDictionary {
                    //debugPrint("gallery: ", gallery)
                    BotMgr.sharedInstance.sendSocketGallery(buttons: gallery.object(forKey: "buttons") as! [Any], width: obj.object(forKey: "width") as! String, height: obj.object(forKey: "height") as! String)
                }
                else if let text = obj.object(forKey: "text") as? String {
                    BotMgr.sharedInstance.sendSocketReplies(text: text, buttons: obj.object(forKey: "quickReplies") as! [Any], height: obj.object(forKey: "height") as! String)
                }
            }
        }
        
        NetworkMgr.socket.connect()
    }
    
    // MARK:- REST API
    
    /// sendMessage(msg: String): Sends a message to Backend
    func sendMessage(msg: String, callback: @escaping NetworkMgrReqCallback) {
        
        let msgUrl = MESSAGE_API_URL + msg.addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlPathAllowed)!
        var headers: HTTPHeaders = [:]
        if let authorizationHeader = Request.authorizationHeader(user: DataMgr.sharedInstance.getKey(key: Keys.email.rawValue)!, password: DataMgr.sharedInstance.getKey(key: Keys.password.rawValue)!) {
            headers[authorizationHeader.key] = authorizationHeader.value
        }
        
        Alamofire.request(msgUrl, headers: headers).response { response in
            debugPrint("got response from Backend:")
            //debugPrint(response)
            var res: String?
            if response.error == nil {
                res = "success"
            }
            callback(res)
        }
    }
    
    func sendPayload(msg: String, callback: @escaping NetworkMgrReqCallback) {
        
        let msgUrl = PAYLOAD_API_URL + msg.addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlPathAllowed)!
        var headers: HTTPHeaders = [:]
        if let authorizationHeader = Request.authorizationHeader(user: DataMgr.sharedInstance.getKey(key: Keys.email.rawValue)!, password: DataMgr.sharedInstance.getKey(key: Keys.password.rawValue)!) {
            headers[authorizationHeader.key] = authorizationHeader.value
        }
        
        Alamofire.request(msgUrl, headers: headers).response { response in
            debugPrint("got response from Payload:")
            //debugPrint(response)
            var res: String?
            if response.error == nil {
                res = "success"
            }
            callback(res)
        }
    }
    
    func fetchMenu(callback: @escaping NetworkMgrMenuCallback) {

        var headers: HTTPHeaders = [:]
        if let authorizationHeader = Request.authorizationHeader(user: DataMgr.sharedInstance.getKey(key: Keys.email.rawValue)!, password: DataMgr.sharedInstance.getKey(key: Keys.password.rawValue)!) {
            headers[authorizationHeader.key] = authorizationHeader.value
        }
        
        Alamofire.request(MENU_API_URL, headers: headers).responseJSON { response in
            debugPrint("got response from Menu:")
            //debugPrint(response)
            var menu: [MenuButton] = []
            if let JSON = response.result.value as? NSDictionary {
                //debugPrint("JSON: \(JSON)")
                if let buttons = JSON.object(forKey: "buttons") as? [NSDictionary] {
                    //debugPrint(buttons)
                    for obj: NSDictionary in buttons {
                        //debugPrint(obj)
                        let btn = MenuButton(title: obj.object(forKey: "title") as? String, payload: obj.object(forKey: "payload") as? String, url: obj.object(forKey: "url") as? String, imgUrl: obj.object(forKey: "imgUrl") as? String)
                        menu.append(btn)
                    }
                }
                callback(menu)
            }
            else {
                callback(menu)
            }
        }
    }
    
    // MARK:- SIGN UP
    
    func postUser(email: String, password: String, callback: @escaping NetworkMgrReqCallback) {
        
        let parameters: Parameters = ["username": email, "password": password]
        
        Alamofire.request(SIGN_UP_URL, method: .post, parameters: parameters, encoding: URLEncoding.httpBody).responseJSON { response in
            
            if response.result.isSuccess {
                callback("good")
            }
            else {
                callback(nil)
            }
        }
    }
    
    func postClients(username: String, password: String, name: String, secret: String, idString: String, callback: @escaping NetworkMgrReqCallback) {
        
        let parameters: Parameters = ["name": name, "secret": secret, "id": idString]
        var headers: HTTPHeaders = [:]
        if let authorizationHeader = Request.authorizationHeader(user: username, password: password) {
            headers[authorizationHeader.key] = authorizationHeader.value
        }
        
        Alamofire.request(POST_CLIENT_URL, method: .post, parameters: parameters, encoding: URLEncoding.httpBody, headers: headers).responseJSON { response in
            
            if response.result.isSuccess {
                callback("success")
            }
            else {
                callback(nil)
            }
        }
    }
    
    func getTransactionId(username: String, password: String, clientId: String, callback: @escaping NetworkMgrResCallback) {
        
        let authUrl = AUTHORIZE_TRANSACTION_URL + "client_id=" + clientId.addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlPathAllowed)! + "&response_type=code&redirect_uri=allow"
        var headers: HTTPHeaders = [:]
        if let authorizationHeader = Request.authorizationHeader(user: username, password: password) {
            headers[authorizationHeader.key] = authorizationHeader.value
        }
        
        Alamofire.request(authUrl, headers: headers).responseJSON { response in
            callback(response)
        }
    }
    
    func postAuthorizationTransaction(username: String, password: String, transactionId: String, callback: @escaping NetworkMgrResCallback) {
        
        let parameters: Parameters = ["transaction_id": transactionId]
        var headers: HTTPHeaders = [:]
        if let authorizationHeader = Request.authorizationHeader(user: username, password: password) {
            headers[authorizationHeader.key] = authorizationHeader.value
        }
        
        Alamofire.request(AUTHORIZE_ALLOW_URL, method: .post, parameters: parameters, encoding: URLEncoding.httpBody, headers: headers).responseJSON { response in
            debugPrint(response.result.value ?? "nada")
            callback(response)
        }
    }
    
    // MARK:- TOKEN
    
    func getToken(clientId: String, secret: String, code: String, callback: @escaping NetworkMgrResCallback) {
        
        let parameters: Parameters = ["code": code, "grant_type": "authorization_code", "redirect_uri": "allow"]
        var headers: HTTPHeaders = [:]
        if let authorizationHeader = Request.authorizationHeader(user: clientId, password: secret) {
            headers[authorizationHeader.key] = authorizationHeader.value
        }
        
        Alamofire.request(TOKEN_URL, method: .post, parameters: parameters, encoding: URLEncoding.httpBody, headers: headers).responseJSON { response in
            callback(response)
        }
    }
}
