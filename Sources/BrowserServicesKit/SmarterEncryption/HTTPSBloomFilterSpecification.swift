//
//  HTTPSBloomFilterSpecification.swift
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

public struct HTTPSBloomFilterSpecification: Equatable, Decodable, Sendable {
   
    public let bitCount: Int
    public let errorRate: Double
    public let totalEntries: Int
    public let sha256: String
    
    public init(bitCount: Int, errorRate: Double, totalEntries: Int, sha256: String) {
        self.bitCount = bitCount
        self.errorRate = errorRate
        self.totalEntries = totalEntries
        self.sha256 = sha256
    }

    static func copy(storedSpecification specification: HTTPSStoredBloomFilterSpecification?) -> HTTPSBloomFilterSpecification? {
        guard let specification = specification,
              let sha256 = specification.sha256 else { return nil }
        return HTTPSBloomFilterSpecification(bitCount: Int(specification.bitCount),
                                             errorRate: specification.errorRate,
                                             totalEntries: Int(specification.totalEntries),
                                             sha256: sha256)
    }

}
