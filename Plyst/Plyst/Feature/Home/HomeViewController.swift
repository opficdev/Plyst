//
//  HomeViewController.swift
//  Plyst
//
//  Created by opfic on 9/30/26.
//

import ReactorKit
import RxSwift
import UIKit

@MainActor
final class HomeViewController: ReactorViewController<HomeReactor> {
    private lazy var homeView = HomeView(frame: .zero)
    private var collectionView: UICollectionView { homeView.collectionView }
    private let thumbnailCache = NSCache<NSString, UIImage>()
    private lazy var timeline = HomeTimelineScheduler { [weak self] now in
        self?.reactor.action.onNext(.timeChanged(now))
    }

    private var sections = [HomeSection]()
    private var renderedNow: Date?
    private var presentedFeedbackID: UUID?
    private var feedbackTask: Task<Void, Never>?

    override func loadView() {
        homeView.delegate = self
        homeView.collectionView.dataSource = self
        homeView.collectionView.delegate = self
        homeView.layout.delegate = self
        view = homeView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        thumbnailCache.countLimit = 48
        navigationController?.setNavigationBarHidden(true, animated: false)
        reactor.action.onNext(.viewDidLoad)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        timeline.appear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timeline.disappear()
    }

    deinit {
        feedbackTask?.cancel()
    }

    override func render(state: HomeReactor.State) {
        let sections = state.sections
        let sectionsChanged = self.sections != sections
        if sectionsChanged || renderedNow != state.now {
            self.sections = sections
            renderedNow = state.now
            homeView.reloadContent()
        }
        if sectionsChanged { timeline.update(clips: state.clips) }

        switch state.loadPhase {
        case .initial:
            homeView.hideEmptyState()
        case .loaded:
            homeView.showEmptyState(
                title: "아직 저장된 내용이 없습니다",
                message: "텍스트나 이미지를 복사한 뒤 현재 클립보드 저장을 눌러보세요"
            )
            if !state.clips.isEmpty { homeView.hideEmptyState() }
        case .failed:
            homeView.showEmptyState(
                title: "기록을 불러오지 못했습니다",
                message: "앱을 다시 열어 기록을 확인해 주세요"
            )
            if !state.clips.isEmpty { homeView.hideEmptyState() }
        }

        homeView.setSaving(state.isSaving)
        updateVisibleThumbnails(state: state)
        showFeedback(state.feedback)
    }

    private func showFeedback(_ feedback: HomeReactor.Feedback?) {
        guard let feedback else {
            homeView.hideFeedback()
            presentedFeedbackID = nil
            return
        }
        guard presentedFeedbackID != feedback.id else { return }
        presentedFeedbackID = feedback.id
        homeView.showFeedback(
            message: feedback.message,
            isSuccess: feedback.isSuccess
        )
        feedbackTask?.cancel()
        feedbackTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.reactor.action.onNext(.dismissFeedback(feedback.id))
        }
    }

    private func updateVisibleThumbnails(state: HomeReactor.State) {
        for cell in collectionView.visibleCells {
            guard let cell = cell as? HomeImageCell,
                  let key = cell.representedKey,
                  let data = state.thumbnails[key] else { continue }
            let cacheKey = "\(key.fileID.uuidString)-\(key.maximumPixelDimension)" as NSString
            let image = thumbnailCache.object(forKey: cacheKey) ?? UIImage(data: data)
            if let image {
                thumbnailCache.setObject(image, forKey: cacheKey)
                cell.setThumbnail(image)
            }
        }
    }

    private func thumbnail(
        for key: HomeThumbnailKey,
        state: HomeReactor.State
    ) -> UIImage? {
        let cacheKey = "\(key.fileID.uuidString)-\(key.maximumPixelDimension)" as NSString
        if let image = thumbnailCache.object(forKey: cacheKey) { return image }
        guard let data = state.thumbnails[key], let image = UIImage(data: data) else { return nil }
        thumbnailCache.setObject(image, forKey: cacheKey)
        return image
    }

    private func thumbnailKey(
        for clip: Clip,
        width: CGFloat
    ) -> HomeThumbnailKey? {
        guard case .image(let image) = clip.content else { return nil }
        let pixels = max(1, Int(ceil((width - 12) * traitCollection.displayScale)))
        return HomeThumbnailKey(clipID: clip.id, fileID: image.fileID, maximumPixelDimension: pixels)
    }
}

extension HomeViewController: HomeViewDelegate {
    func homeViewDidRequestSave(_ view: HomeView) {
        reactor.action.onNext(.saveCurrentClipboard)
    }
}

extension HomeViewController: UICollectionViewDataSource, UICollectionViewDelegate, HomeGridLayoutDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        homeView.updateScrollPosition(scrollView.contentOffset.y)
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        sections.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        sections[section].clips.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let clip = sections[indexPath.section].clips[indexPath.item]
        switch clip.content {
        case .text:
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: HomeTextCell.reuseIdentifier,
                for: indexPath
            ) as? HomeTextCell else { preconditionFailure("HomeTextCell registration mismatch") }
            cell.configure(with: clip, now: reactor.currentState.now)
            return cell
        case .image:
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: HomeImageCell.reuseIdentifier,
                for: indexPath
            ) as? HomeImageCell else { preconditionFailure("HomeImageCell registration mismatch") }
            let width = max(1, (collectionView.bounds.width - 42) / 2)
            if let key = thumbnailKey(for: clip, width: width) {
                cell.configure(
                    with: clip,
                    now: reactor.currentState.now,
                    key: key,
                    thumbnail: thumbnail(for: key, state: reactor.currentState)
                )
            }
            return cell
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        guard let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: HomeSectionHeaderView.reuseIdentifier,
            for: indexPath
        ) as? HomeSectionHeaderView else { preconditionFailure("HomeSectionHeaderView registration mismatch") }
        header.configure(title: sections[indexPath.section].kind.title)
        return header
    }

    func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        guard let cell = cell as? HomeImageCell,
              let key = cell.representedKey,
              reactor.currentState.thumbnails[key] == nil else { return }
        reactor.action.onNext(.thumbnailRequested(key))
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didEndDisplaying cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        guard let cell = cell as? HomeImageCell,
              let key = cell.representedKey else { return }
        Task { @MainActor [weak self] in
            guard let self,
                  !self.collectionView.visibleCells.contains(where: { ($0 as? HomeImageCell)?.representedKey == key }) else { return }
            self.reactor.action.onNext(.thumbnailCancelled(key))
        }
    }

    func homeLayout(
        _ layout: HomeGridLayout,
        heightForItemAt indexPath: IndexPath,
        width: CGFloat
    ) -> CGFloat {
        let clip = sections[indexPath.section].clips[indexPath.item]
        switch clip.content {
        case .text:
            return HomeTextCell.height(for: clip, width: width)
        case .image:
            return HomeImageCell.height(for: clip, width: width)
        }
    }
}
