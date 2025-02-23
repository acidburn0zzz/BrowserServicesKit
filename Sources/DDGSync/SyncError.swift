//
//  SyncError.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation

public enum SyncError: Error, Equatable {

    case noToken

    case failedToCreateAccountKeys(_ message: String)
    case accountNotFound
    case accountAlreadyExists
    case invalidRecoveryKey

    case noFeaturesSpecified
    case noResponseBody
    case unexpectedStatusCode(Int)
    case unexpectedResponseBody
    case unableToEncodeRequestBody(_ message: String)
    case unableToDecodeResponse(_ message: String)
    case invalidDataInResponse(_ message: String)
    case accountRemoved

    case failedToEncryptValue(_ message: String)
    case failedToDecryptValue(_ message: String)
    case failedToPrepareForConnect(_ message: String)
    case failedToOpenSealedBox(_ message: String)
    case failedToSealData(_ message: String)

    case failedToWriteSecureStore(status: OSStatus)
    case failedToReadSecureStore(status: OSStatus)
    case failedToRemoveSecureStore(status: OSStatus)
    
}
