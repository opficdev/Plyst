//
//  SceneDelegate.swift
//  Plyst
//
//  Created by opfic on 9/28/26.
//

import OSLog
import UIKit

@MainActor
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "opfic.Plyst",
        category: String(describing: SceneDelegate.self)
    )

    var window: UIWindow?
    private var composition: HomeSceneComposition?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        self.window = window
        configureRoot(in: window)
        window.makeKeyAndVisible()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        composition?.importSharedClips()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        window = nil
        composition = nil
    }

    private func configureRoot(in window: UIWindow) {
        do {
            let composition = try HomeSceneComposition()
            let root = composition.makeRootViewController()
            self.composition = composition
            window.rootViewController = root
            composition.startPendingCleanupRecovery()
            // 시작 실패 후 다시 시도해 성공하면 Scene이 이미 활성 상태라 sceneDidBecomeActive가 오지 않습니다.
            composition.importSharedClips()
        } catch {
            Self.logger.error("기록 화면 초기화 실패: \(String(describing: type(of: error)), privacy: .public)")
            composition = nil
            window.rootViewController = StartupFailureViewController { [weak self] in
                guard let self, let window = self.window else { return }
                self.configureRoot(in: window)
            }
        }
    }
}
