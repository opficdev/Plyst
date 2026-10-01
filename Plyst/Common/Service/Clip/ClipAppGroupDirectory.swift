//
//  ClipAppGroupDirectory.swift
//  Plyst
//
//  Created by opfic on 10/1/26.
//

import Foundation

/// 본 앱과 Share Extension이 함께 쓰는 App Group 컨테이너의 위치입니다.
/// 컨테이너를 찾지 못하면 `CocoaError(.fileNoSuchFile)`을 던집니다.
struct ClipAppGroupDirectory: Sendable {
    private static let appGroupIdentifier = "group.opfic.Plyst"

    let containerURL: URL

    init() throws {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier) else {
            throw CocoaError(.fileNoSuchFile)
        }
        self.containerURL = containerURL
    }
}
