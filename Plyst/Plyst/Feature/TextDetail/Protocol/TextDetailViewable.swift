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

    /// 입력 중인 칸은 대입하지 않고 사용자의 입력을 그대로 둡니다. 입력 중이 아닐 때만 값이 다르면 대입합니다.
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
