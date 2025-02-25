//
//  GPCRequestFactory.swift
//  DuckDuckGo
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

public struct GPCRequestFactory {
    
    public init() { }
    
    public struct Constants {
        public static let secGPCHeader = "Sec-GPC"
    }

    private func gpcHeadersEnabled(config: PrivacyConfiguration) -> [String] {
        let settings = config.settings(for: .gpc)

        guard let enabledSites = settings["gpcHeaderEnabledSites"] as? [String] else {
            return []
        }

        return enabledSites
    }

    public func isGPCEnabled(url: URL,
                             config: PrivacyConfiguration) -> Bool {
        let enabledSites = gpcHeadersEnabled(config: config)

        if enabledSites.contains(where: { gpcHost in url.isPart(ofDomain: gpcHost) }) {
            // Check if url is on exception list
            // Since headers are only enabled for a small numbers of sites
            // perform this check here for efficiency
            return config.isFeature(.gpc, enabledForDomain: url.host)
        }

        return false
    }

    
    public func requestForGPC(basedOn incomingRequest: URLRequest,
                       config: PrivacyConfiguration,
                       gpcEnabled: Bool) -> URLRequest? {
        
        func removingHeader(fromRequest incomingRequest: URLRequest) -> URLRequest? {
            var request = incomingRequest
            if let headers = request.allHTTPHeaderFields, headers.firstIndex(where: { $0.key == Constants.secGPCHeader }) != nil {
                request.setValue(nil, forHTTPHeaderField: Constants.secGPCHeader)
                return request
            }
            
            return nil
        }
        
        /*
         For now, the GPC header is only applied to sites known to be honoring GPC (nytimes.com, washingtonpost.com),
         while the DOM signal is available to all websites.
         This is done to avoid an issue with back navigation when adding the header (e.g. with 't.co').
         */
        guard let url = incomingRequest.url, isGPCEnabled(url: url, config: config) else {
            // Remove GPC header if its still there (or nil)
            return removingHeader(fromRequest: incomingRequest)
        }
        
        // Add GPC header if needed
        if config.isEnabled(featureKey: .gpc) && gpcEnabled {
            var request = incomingRequest
            if let headers = request.allHTTPHeaderFields,
               headers.firstIndex(where: { $0.key == Constants.secGPCHeader }) == nil {
                request.addValue("1", forHTTPHeaderField: Constants.secGPCHeader)
                return request
            }
        } else {
            // Check if GPC header is still there and remove it
            return removingHeader(fromRequest: incomingRequest)
        }
        
        return nil
    }
}
