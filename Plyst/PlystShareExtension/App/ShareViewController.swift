//
//  ShareViewController.swift
//  PlystShareExtension
//
//  Created by opfic on 10/1/26.
//

import OSLog
import UIKit

@MainActor
final class ShareViewController: UIViewController {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "opfic.Plyst.ShareExtension",
        category: String(describing: ShareViewController.self)
    )

    private lazy var statusView = ShareStatusView(
        frame: .zero,
        send: { [weak self] in self?.handle($0) }
    )

    override func loadView() {
        view = statusView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        do {
            // 이번 단계는 App Group 컨테이너 확인까지만 수행합니다. 저장소는 열지 않습니다.
            _ = try ClipAppGroupDirectory()
            statusView.setStatus(.saving)
        } catch {
            Self.logger.error("공유 저장 경로 확인 실패: \(String(describing: type(of: error)), privacy: .public)")
            statusView.setStatus(.failed)
        }
    }

    private func handle(_ action: ShareStatusViewAction) {
        switch action {
        case .cancel:
            extensionContext?.cancelRequest(withError: CocoaError(.userCancelled))
        case .done:
            extensionContext?.completeRequest(returningItems: nil)
        }
    }
}
