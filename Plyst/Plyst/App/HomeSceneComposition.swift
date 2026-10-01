//
//  HomeSceneComposition.swift
//  Plyst
//
//  Created by opfic on 9/30/26.
//

import OSLog
import UIKit

@MainActor
final class HomeSceneComposition {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "opfic.Plyst",
        category: String(describing: HomeSceneComposition.self)
    )

    private let storage: SQLiteClipStorageService
    private let images: ClipImageService
    private let clipboard: ClipClipboardService
    private let photos: ClipPhotoLibraryService

    init() throws {
        var directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        directory.appendPathComponent("Plyst", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)

        let storage = try SQLiteClipStorageService(databaseURL: directory.appendingPathComponent("clips.sqlite"))
        let files = try ClipImageFileStore(rootURL: directory.appendingPathComponent("images", isDirectory: true))
        let images = ClipImageService(storage: storage, files: files)
        let clipboard = ClipClipboardService(storage: storage, images: images)
        self.storage = storage
        self.images = images
        self.clipboard = clipboard
        photos = ClipPhotoLibraryService(storage: storage, images: images)
    }

    func makeRootViewController() -> UIViewController {
        // 상세 화면은 같은 저장소와 서비스 인스턴스를 공유합니다.
        let makeDetail: @MainActor (Clip) -> UIViewController = { [storage, clipboard, images, photos] clip in
            switch clip.content {
            case .text:
                TextDetailViewController(
                    reactor: TextDetailReactor(
                        clip: clip,
                        storage: storage,
                        clipboard: clipboard
                    ),
                    makeTextDetailView: { TextDetailView(frame: .zero, send: $0) }
                )
            case .image:
                ImageDetailViewController(
                    reactor: ImageDetailReactor(
                        clip: clip,
                        storage: storage,
                        clipboard: clipboard,
                        images: images,
                        photos: photos
                    ),
                    makeImageDetailView: { ImageDetailView(frame: .zero, send: $0) }
                )
            }
        }
        let reactor = HomeReactor(
            storage: storage,
            clipboard: clipboard,
            images: images
        )
        // 검색 화면은 같은 저장소와 서비스 인스턴스를 공유합니다. 클로저는 Composition이 아니라 서비스만 캡처합니다.
        let controller = HomeViewController(
            reactor: reactor,
            makeHomeView: { HomeView(frame: .zero, send: $0) },
            makeSearchViewController: { [storage, clipboard, images, makeDetail] in
                SearchViewController(
                    reactor: SearchReactor(
                        storage: storage,
                        history: storage,
                        clipboard: clipboard,
                        images: images
                    ),
                    makeSearchView: { SearchView(frame: .zero, send: $0) },
                    makeDetailViewController: makeDetail
                )
            },
            makeDetailViewController: makeDetail
        )
        let navigation = UINavigationController(rootViewController: controller)
        navigation.setNavigationBarHidden(true, animated: false)
        return navigation
    }

    func startPendingCleanupRecovery() {
        Task { [images] in
            do {
                let pending = try await images.recoverPendingCleanup()
                if !pending.isEmpty {
                    Self.logger.warning("이미지 정리 보류: \(pending.count, privacy: .public)개")
                }
            } catch {
                Self.logger.error("이미지 정리 재시도 실패: \(String(describing: type(of: error)), privacy: .public)")
            }
        }
    }
}
