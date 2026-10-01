//
//  ShareViewController.swift
//  PlystShareExtension
//
//  Created by opfic on 10/1/26.
//

import OSLog
import ReactorKit
import RxSwift
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
    /// 저장 완료를 보여 준 뒤 요청을 종료하기까지의 시간입니다.
    private static let completionDelay = Duration.seconds(2)

    private var reactor: ShareReactor?
    private var task: Task<Void, Never>?
    private var finishTask: Task<Void, Never>?
    private var didFinish = false

    deinit {
        task?.cancel()
        finishTask?.cancel()
    }

    override func loadView() {
        view = statusView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        prepare()
    }

    /// 시스템이 principal class를 직접 생성하므로 저장소를 열 수 없는 경우를 고려해 viewDidLoad에서 조립합니다.
    private func prepare() {
        do {
            let directory = try ClipAppGroupDirectory()
            let storage = try SQLiteClipStorageService(
                databaseURL: directory.containerURL.appendingPathComponent("ShareInbox.sqlite")
            )
            let files = try ClipImageFileStore(
                rootURL: directory.containerURL.appendingPathComponent("ShareInboxImages", isDirectory: true)
            )
            let images = ClipImageService(storage: storage, files: files)
            let item = ClipShareItem(item: extensionContext?.inputItems.first as? NSExtensionItem)
            bind(ShareReactor(item: item, service: ClipShareService(storage: storage, images: images)))
        } catch {
            Self.logger.error("공유 저장소 준비 실패: \(String(describing: type(of: error)), privacy: .public)")
            statusView.setStatus(.failed)
        }
    }

    private func bind(_ reactor: ShareReactor) {
        task?.cancel()
        self.reactor = reactor
        // 값을 기다리는 동안에는 Reactor나 ViewController가 아니라 스트림만 캡처합니다.
        let values = reactor.state.values
        task = Task { [weak self] in
            do {
                for try await state in values {
                    guard !Task.isCancelled else { return }
                    self?.render(state.status)
                }
            } catch is CancellationError {
                // 관찰 취소는 화면 생명주기의 정상적인 일부입니다.
            } catch {
                Self.logger.error("상태 구독 실패: \(String(describing: type(of: error)), privacy: .public)")
            }
        }
        reactor.action.onNext(.save)
    }

    private func render(_ status: ShareStatus) {
        statusView.setStatus(status)
        guard status == .completed, !didFinish else { return }
        didFinish = true
        finishTask = Task { [weak self] in
            try? await Task.sleep(for: Self.completionDelay)
            guard !Task.isCancelled else { return }
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
    }

    private func handle(_ action: ShareStatusViewAction) {
        switch action {
        case .cancel:
            // 진행 중인 저장을 먼저 중단한 뒤 요청을 종료합니다.
            reactor?.action.onNext(.cancel)
            extensionContext?.cancelRequest(withError: CocoaError(.userCancelled))
        case .retry:
            if let reactor {
                reactor.action.onNext(.save)
            } else {
                prepare()
            }
        }
    }
}
