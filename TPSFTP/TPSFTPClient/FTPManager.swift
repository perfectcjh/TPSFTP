//
//  FTPManager.swift
//  FreeNAS
//
//  Created by chenjinheng on 2018/7/2.
//  Copyright © 2018年 refineit. All rights reserved.
//

import Foundation
import CFNetwork

/** attributesKeys
 DLFileAccessDate,
 NSFileGroupOwnerAccountID,
 NSFileModificationDate,
 NSFileOwnerAccountID,
 NSFilePosixPermissions,
 NSFileSize,
 NSFileType
 */
struct FTPFile {
    
    var name: String!
    var path: String!
    var accessDate: Date!
    var attributes: [AnyHashable: Any]!
    
    init(file: DLSFTPFile) {
        self.name = file.filename()
        self.path = file.path
        self.accessDate = file.attributes["DLFileAccessDate"] as! Date
        self.attributes = file.attributes
    }
}


class FTPManager: NSObject {

    var connection: DLSFTPConnection?
    
    static var shared: FTPManager {
        struct Static {
            static let instance: FTPManager = FTPManager()
        }
        return Static.instance
    }
    
    
    private override init() {
       
    }

}


extension FTPManager {
    ///MARK: - 控制
    
    //开始连接
    func startConnect(successBlock: @escaping () -> Void, failureBlock: @escaping (Error?) -> Void) {
        
        let username = ""
        let password = ""
        
        let hostname = ""
        let port = ""
        
        self.connection = DLSFTPConnection.init(hostname: hostname, port: UInt(port)!, username: username, password: password)
        
        self.connection?.connect(successBlock: {
            DispatchQueue.main.async {
                successBlock()
            }
        }) { (error) in
            DispatchQueue.main.async {
                failureBlock(error)
            }
        }
    }

    
    //重新连接
    func restartConnect(successBlock: @escaping () -> Void, failureBlock: @escaping (Error?) -> Void) {

        self.connection?.connect(successBlock: {
            DispatchQueue.main.async {
                successBlock()
            }
        }) { (error) in
            DispatchQueue.main.async {
                failureBlock(error)
            }
        }
    }
    
    
    //结束连接
    func stopConnect() {
        self.connection?.disconnect()
    }
    
    
    //取消所有请求
    func cancelAllRequests() {
        self.connection?.cancelAllRequests()
    }
    
    
    //判断是否在连接
    func checkIsConnect() -> Bool {
        return self.connection == nil ? false : self.connection!.isConnected()
    }

}


extension FTPManager {
    ///MARK: - 管理
    
    //获取目录下的文件
    func getFileList(remotePath: String, successBlock: @escaping ([FTPFile]) -> Void, failureBlock: @escaping (Error?) -> Void) {

        guard self.checkIsConnect() == true else {
            self.restartConnect(successBlock: {
                self.getFileList(remotePath: remotePath, successBlock: successBlock, failureBlock: failureBlock)
            }) { (error) in
                print(String(describing: error?.localizedDescription))
                DispatchQueue.main.async {
                    failureBlock(error)
                }
            }
            return
        }
        let request = DLSFTPListFilesRequest.init(directoryPath: remotePath, successBlock: { (fileArray) in
            DispatchQueue.main.async {
                var newFileArray = [FTPFile]()
                for file in fileArray! {
                    let newFile = FTPFile.init(file: file as! DLSFTPFile)
                    newFileArray.append(newFile)
                }
                successBlock(newFileArray)
            }
        }) { (error) in
            DispatchQueue.main.async {
                failureBlock(error)
            }
        }
        self.connection?.submitRequest(request)
    }
    
    
    //在指定目录下新建文件夹
    func createFolder(remotePath: String, successBlock: @escaping () -> Void, failureBlock: @escaping (Error?) -> Void) {

        guard self.checkIsConnect() == true else {
            self.restartConnect(successBlock: {
                self.createFolder(remotePath: remotePath, successBlock: successBlock, failureBlock: failureBlock)
            }) { (error) in
                print(String(describing: error?.localizedDescription))
                DispatchQueue.main.async {
                    failureBlock(error)
                }
            }
            return
        }
        let request = DLSFTPMakeDirectoryRequest.init(directoryPath: remotePath, successBlock: { (fileArray) in
            DispatchQueue.main.async {
                successBlock()
            }
        }) { (error) in
            DispatchQueue.main.async {
                failureBlock(error)
            }
        }
        self.connection?.submitRequest(request)
    }
    
    
    //删除指定目录下的文件夹
    func removeFolder() {
        
    }
    
    
    //删除指定目录下的文件
    func removeFile(remotePath :String, successBlock: @escaping () -> Void, failureBlock: @escaping (Error?) -> Void) {

        guard self.checkIsConnect() == true else {
            self.restartConnect(successBlock: {
                self.removeFile(remotePath: remotePath, successBlock: successBlock, failureBlock: failureBlock)
            }) { (error) in
                print(String(describing: error?.localizedDescription))
                DispatchQueue.main.async {
                    failureBlock(error)
                }
            }
            return
        }
        let request = DLSFTPRemoveFileRequest.init(filePath: remotePath, successBlock: {
            DispatchQueue.main.async {
                successBlock()
            }
        }) { (error) in
            DispatchQueue.main.async {
                failureBlock(error)
            }
        }
        self.connection?.submitRequest(request)
    }
    
    
    //上传文件到指定目录下
    func uploadFile(localPath: String, remotePath: String, progressBlock:@escaping (Double, Double) -> Void, successBlock: @escaping () -> Void, failureBlock: @escaping (Error?) -> Void) {

        guard self.checkIsConnect() == true else {
            self.restartConnect(successBlock: {
                self.uploadFile(localPath: localPath, remotePath: remotePath, progressBlock: progressBlock, successBlock: successBlock, failureBlock: failureBlock)
            }) { (error) in
                print(String(describing: error?.localizedDescription))
                DispatchQueue.main.async {
                    failureBlock(error)
                }
            }
            return
        }
        let request = DLSFTPUploadRequest.init(remotePath: remotePath, localPath: localPath, successBlock: { (file, startTime, finishTime) in
            DispatchQueue.main.async {
                successBlock()
            }
        }, failureBlock: { (error) in
            DispatchQueue.main.async {
                failureBlock(error)
            }
        }) { (bytesReceived, bytesTotal) in
            DispatchQueue.main.async {
                progressBlock(Double(bytesReceived), Double(bytesTotal))
            }
        }
        self.connection?.submitRequest(request)
    }
    
    
    //下载文件到指定目录下
    func downloadFile(localPath: String, remotePath: String, progressBlock:@escaping (Double, Double) -> Void, successBlock: @escaping (FTPFile?) -> Void, failureBlock: @escaping (Error?) -> Void) {

        guard self.checkIsConnect() == true else {
            self.restartConnect(successBlock: {
                self.downloadFile(localPath: localPath, remotePath: remotePath, progressBlock: progressBlock, successBlock: successBlock, failureBlock: failureBlock)
            }) { (error) in
                print(String(describing: error?.localizedDescription))
                DispatchQueue.main.async {
                    failureBlock(error)
                }
            }
            return
        }
        DispatchQueue.global().async {
            let request = DLSFTPDownloadRequest.init(remotePath: remotePath, localPath: localPath, resume: true, successBlock: { (file, startTime, finishTime) in
                DispatchQueue.main.async {
                    let newFile = FTPFile.init(file: file!)
                    successBlock(newFile)
                }
            }, failureBlock: { (error) in
                DispatchQueue.main.async {
                    failureBlock(error)
                }
            }) { (bytesReceived, bytesTotal) in
                DispatchQueue.main.async {
                    progressBlock(Double(bytesReceived), Double(bytesTotal))
                }
            }
            self.connection?.submitRequest(request)
        }
    }
    
}
