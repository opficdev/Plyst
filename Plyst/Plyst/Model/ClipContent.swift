//
//  ClipContent.swift
//  Plyst
//
//  Created by opfic on 9/28/26.
//

import Foundation

enum ClipContent: Equatable, Sendable {

    /// URL을 포함한 원본 문자열을 정규화하지 않고 저장합니다.
    case text(String)
    case image(ClipImageMetadata)

    /// 이미지의 메타데이터만 검증합니다. 이미지 디코딩과 파일 존재 여부 검사는 이미지 파일 서비스의 책임입니다.
    var isValid: Bool {
        switch self {
        case .text(let text):
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .image(let image):
            return image.isValid
        }
    }
}
