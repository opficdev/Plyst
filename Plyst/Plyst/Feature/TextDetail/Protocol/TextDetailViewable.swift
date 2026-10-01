//
//  TextDetailViewable.swift
//  Plyst
//
//  Created by opfic on 10/1/26.
//

import UIKit

@MainActor
protocol TextDetailViewable: UIView {
    func setContent(
        meta: String,
        text: String
    )

    /// 사용자가 입력 중인 값과 같으면 대입하지 않아 커서 위치를 유지합니다.
    func setDraft(
        name: String,
        memo: String,
        isPinned: Bool
    )

    func setDates(
        saved: String,
        lastUsed: String
    )

    func setSaveEnabled(_ isEnabled: Bool)
    func setBusy(_ isBusy: Bool)
    func focusName()

    /// 피드백 토스트를 이 앵커 아래에 배치합니다.
    var feedbackTopAnchor: NSLayoutYAxisAnchor { get }
}
