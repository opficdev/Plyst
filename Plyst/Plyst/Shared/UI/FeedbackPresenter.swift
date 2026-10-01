//
//  FeedbackPresenter.swift
//  Plyst
//
//  Created by opfic on 10/1/26.
//

import UIKit

/// 화면에 피드백 토스트를 붙이고 한 번만 표시한 뒤 일정 시간이 지나면 닫도록 알립니다.
/// 같은 식별자의 피드백이 다시 전달돼도 토스트를 다시 띄우지 않습니다.
/// 토스트는 host 위에 가장 나중에 추가하므로 다른 서브뷰보다 앞에 표시됩니다.
@MainActor
final class FeedbackPresenter {
    private let toast: ToastView
    private let successColor: UIColor
    private let failureColor: UIColor
    private let duration: Duration
    private let dismiss: @MainActor (UUID) -> Void
    private var presentedID: UUID?
    private var task: Task<Void, Never>?

    /// topAnchor에서 topInset만큼 아래에 가로 중앙으로 배치합니다.
    init(
        host: UIView,
        topAnchor: NSLayoutYAxisAnchor,
        topInset: CGFloat,
        duration: Duration = .seconds(2),
        textColor: UIColor = UIColor(resource: .homeBottomText),
        successColor: UIColor = UIColor(resource: .homeFeedbackSuccess),
        failureColor: UIColor = UIColor(resource: .homeFeedbackFailure),
        dismiss: @escaping @MainActor (UUID) -> Void
    ) {
        toast = ToastView(textColor: textColor)
        self.successColor = successColor
        self.failureColor = failureColor
        self.duration = duration
        self.dismiss = dismiss

        host.addSubview(toast)
        toast.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: host.centerXAnchor),
            toast.topAnchor.constraint(equalTo: topAnchor, constant: topInset),
            toast.leadingAnchor.constraint(greaterThanOrEqualTo: host.leadingAnchor, constant: 20),
            toast.trailingAnchor.constraint(lessThanOrEqualTo: host.trailingAnchor, constant: -20)
        ])
    }

    deinit {
        task?.cancel()
    }

    /// feedback이 nil이면 토스트를 숨깁니다.
    func update(_ feedback: (any FeedbackPresentable)?) {
        guard let feedback else {
            toast.hide()
            presentedID = nil
            return
        }
        guard presentedID != feedback.id else { return }
        presentedID = feedback.id
        toast.show(
            message: feedback.message,
            backgroundColor: feedback.isSuccess ? successColor : failureColor
        )
        task?.cancel()
        task = Task { [duration, dismiss] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            dismiss(feedback.id)
        }
    }
}
