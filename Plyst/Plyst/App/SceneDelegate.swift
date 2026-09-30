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
