//
//  ClipboardReader.swift
//  Plyst
//
//  Created by opfic on 9/29/26.
//

enum ClipboardReadResult: Equatable, Sendable {
    case text(String)
    case empty
    case unsupported
    /// 지원 형식의 값을 얻지 못했거나 읽는 동안 내용이 변경되었습니다. 권한 거절 여부를 확정하지 않습니다.
    case accessFailed
}

/// 명시적인 호출에서만 클립보드를 읽고 UIKit 객체 대신 값 타입을 반환합니다.
protocol ClipboardReader: Sendable {
    @MainActor
    func read() throws -> ClipboardReadResult
}
