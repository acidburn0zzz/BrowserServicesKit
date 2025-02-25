//
//  RemoteMessageModel.swift
//  DuckDuckGo
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

public struct RemoteMessageModel: Equatable, Codable {

    public let id: String
    public var content: RemoteMessageModelType?
    public let matchingRules: [Int]
    public let exclusionRules: [Int]

    public init(id: String, content: RemoteMessageModelType?, matchingRules: [Int], exclusionRules: [Int]) {
        self.id = id
        self.content = content
        self.matchingRules = matchingRules
        self.exclusionRules = exclusionRules
    }

    public static func == (lhs: RemoteMessageModel, rhs: RemoteMessageModel) -> Bool {
        if lhs.id != rhs.id {
            return false
        }
        if lhs.content != rhs.content {
            return false
        }
        if lhs.matchingRules != rhs.matchingRules {
            return false
        }
        if lhs.exclusionRules != rhs.exclusionRules {
            return false
        }
        return true
    }

    mutating func localizeContent(translation: RemoteMessageResponse.JsonContentTranslation) {
        guard let content = content else {
            return
        }

        switch content {
        case .small(let titleText, let descriptionText):
            self.content = .small(titleText: translation.titleText ?? titleText,
                                  descriptionText: translation.descriptionText ?? descriptionText)
        case .medium(let titleText, let descriptionText, let placeholder):
            self.content = .medium(titleText: translation.titleText ?? titleText,
                                   descriptionText: translation.descriptionText ?? descriptionText,
                                   placeholder: placeholder)
        case .bigSingleAction(let titleText, let descriptionText, let placeholder, let primaryActionText, let primaryAction):
            self.content = .bigSingleAction(titleText: translation.titleText ?? titleText,
                                            descriptionText: translation.descriptionText ?? descriptionText,
                                            placeholder: placeholder,
                                            primaryActionText: translation.primaryActionText ?? primaryActionText,
                                            primaryAction: primaryAction)
        case .bigTwoAction(let titleText, let descriptionText, let placeholder, let primaryActionText, let primaryAction,
                           let secondaryActionText, let secondaryAction):
            self.content = .bigTwoAction(titleText: translation.titleText ?? titleText,
                                         descriptionText: translation.descriptionText ?? descriptionText,
                                         placeholder: placeholder,
                                         primaryActionText: translation.primaryActionText ?? primaryActionText,
                                         primaryAction: primaryAction,
                                         secondaryActionText: translation.secondaryActionText ?? secondaryActionText,
                                         secondaryAction: secondaryAction)
        }
    }
}

public enum RemoteMessageModelType: Codable, Equatable {
    case small(titleText: String, descriptionText: String)
    case medium(titleText: String, descriptionText: String, placeholder: RemotePlaceholder)
    case bigSingleAction(titleText: String, descriptionText: String, placeholder: RemotePlaceholder,
                         primaryActionText: String, primaryAction: RemoteAction)
    case bigTwoAction(titleText: String, descriptionText: String, placeholder: RemotePlaceholder,
                      primaryActionText: String, primaryAction: RemoteAction, secondaryActionText: String,
                      secondaryAction: RemoteAction)

    public static func == (lhs: RemoteMessageModelType, rhs: RemoteMessageModelType) -> Bool {
        switch (lhs, rhs) {
        case (.small(let lhsTitleText, let lhsDescriptionText), .small(let rhsTitleText, let rhsDescriptionText)):
            return lhsTitleText == rhsTitleText && lhsDescriptionText == rhsDescriptionText
        case (.medium(let lhsTitleText, let lhsDescriptionText, let lhsPlaceholder),
              .medium(let rhsTitleText, let rhsDescriptionText, let rhsPlaceholder)):
            return lhsTitleText == rhsTitleText && lhsDescriptionText == rhsDescriptionText && lhsPlaceholder == rhsPlaceholder
        case (.bigSingleAction(let lhsTitleText, let lhsDescriptionText, let lhsPlaceholder, let lhsPrimaryActionText, let lhsPrimaryAction),
              .bigSingleAction(let rhsTitleText, let rhsDescriptionText, let rhsPlaceholder, let rhsPrimaryActionText, let rhsPrimaryAction)):
            return lhsTitleText == rhsTitleText && lhsDescriptionText == rhsDescriptionText && lhsPlaceholder == rhsPlaceholder &&
                   lhsPrimaryActionText == rhsPrimaryActionText && lhsPrimaryAction == rhsPrimaryAction
        case (.bigTwoAction(let lhsTitleText, let lhsDescriptionText, let lhsPlaceholder, let lhsPrimaryActionText, let lhsPrimaryAction,
                            let lhsSecondaryActionText, let lhsSecondaryAction), .bigTwoAction(let rhsTitleText, let rhsDescriptionText,
                                                                                               let rhsPlaceholder, let rhsPrimaryActionText,
                                                                                               let rhsPrimaryAction, let rhsSecondaryActionText,
                                                                                               let rhsSecondaryAction)):
            return lhsTitleText == rhsTitleText && lhsDescriptionText == rhsDescriptionText && lhsPlaceholder == rhsPlaceholder &&
                   lhsPrimaryActionText == rhsPrimaryActionText && lhsPrimaryAction == rhsPrimaryAction &&
                   lhsSecondaryActionText == rhsSecondaryActionText && lhsSecondaryAction == rhsSecondaryAction
        default:
            return false
        }
    }
}

public enum RemoteAction: Codable, Equatable {
    case url(value: String)
    case appStore
    case dismiss
}

public enum RemotePlaceholder: String, Codable {
    case announce = "RemoteMessageAnnouncement"
    case ddgAnnounce = "RemoteMessageDDGAnnouncement"
    case criticalUpdate = "RemoteMessageCriticalAppUpdate"
    case appUpdate = "RemoteMessageAppUpdate"
    case macComputer = "RemoteMessageMacComputer"
}
