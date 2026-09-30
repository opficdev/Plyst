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
    private var pinnedClips = [Clip]()
    private var renderedNow: Date?
    private var renderedFilter: HomeFilter?
    private var presentedFeedbackID: UUID?
    private var feedbackTask: Task<Void, Never>?
    private let makeSearchViewController: @MainActor () -> UIViewController

    /// 상단 고정 항목이 있으면 section 0을 그 전용으로 두어 시간순 구간이 없어도 표시되게 한다.
    private var pinnedRowSectionCount: Int { pinnedClips.isEmpty ? 0 : 1 }

    init(
        reactor: HomeReactor,
        makeSearchViewController: @escaping @MainActor () -> UIViewController
    ) {
        self.makeSearchViewController = makeSearchViewController
        super.init(reactor: reactor)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

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
        let content = state.content
        let contentChanged = sections != content.sections || pinnedClips != content.pinnedClips
        if contentChanged || renderedNow != state.now {
            sections = content.sections
            pinnedClips = content.pinnedClips
            renderedNow = state.now
            homeView.reloadContent()
        }
        if contentChanged { timeline.update(clips: state.clips) }

        if renderedFilter != state.filter {
            let isFilterSwitch = renderedFilter != nil
            renderedFilter = state.filter
            homeView.setSelectedFilter(state.filter)
            if isFilterSwitch { homeView.scrollToTop() }
        }

        switch state.loadPhase {
        case .initial:
            homeView.hideEmptyState()
        case .loaded:
            if state.clips.isEmpty {
                homeView.showEmptyState(title: HomeFilter.all.emptyTitle, message: HomeFilter.all.emptyMessage)
            } else if content.isEmpty {
                homeView.showEmptyState(title: state.filter.emptyTitle, message: state.filter.emptyMessage)
            } else {
                homeView.hideEmptyState()
            }
        case .failed:
            if state.clips.isEmpty {
                homeView.showEmptyState(
                    title: "기록을 불러오지 못했습니다",
                    message: "앱을 다시 열어 기록을 확인해 주세요"
                )
            } else {
                homeView.hideEmptyState()
            }
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
        for view in collectionView.visibleSupplementaryViews(ofKind: HomeGridLayout.pinnedRowKind) {
            guard let row = view as? HomePinnedRowView else { continue }
            configurePinnedRow(row, state: state)
        }
    }

    private func configurePinnedRow(
        _ row: HomePinnedRowView,
        state: HomeReactor.State
    ) {
        row.configure(
            clips: pinnedClips,
            now: state.now,
            key: { [weak self] clip in self?.pinnedRowThumbnailKey(for: clip) },
            thumbnail: { [weak self] key in self?.thumbnail(for: key, state: state) }
        )
        requestPinnedRowThumbnails(row, state: state)
    }

    /// 썸네일 보관 개수보다 고정 이미지가 많아도 요청과 제거가 반복되지 않도록 보이는 카드만 요청한다.
    private func requestPinnedRowThumbnails(
        _ row: HomePinnedRowView,
        state: HomeReactor.State
    ) {
        for clip in row.visibleClips() {
            guard let key = pinnedRowThumbnailKey(for: clip), state.thumbnails[key] == nil else { continue }
            reactor.action.onNext(.thumbnailRequested(key))
        }
    }

    private func pinnedRowThumbnailKey(for clip: Clip) -> HomeThumbnailKey? {
        guard case .image(let image) = clip.content else { return nil }
        let pixels = max(1, Int(ceil(HomePinnedClipView.thumbnailDimension * traitCollection.displayScale)))
        return HomeThumbnailKey(
            clipID: clip.id,
            fileID: image.fileID,
            maximumPixelDimension: pixels
        )
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

    private func clip(at indexPath: IndexPath) -> Clip {
        sections[indexPath.section - pinnedRowSectionCount].clips[indexPath.item]
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

    func homeViewDidRequestSearch(_ view: HomeView) {
        navigationController?.pushViewController(makeSearchViewController(), animated: true)
    }

    func homeView(
        _ view: HomeView,
        didSelectFilter filter: HomeFilter
    ) {
        reactor.action.onNext(.selectFilter(filter))
    }
}

extension HomeViewController: HomePinnedRowViewDelegate {
    func homePinnedRowViewDidScroll(_ view: HomePinnedRowView) {
        requestPinnedRowThumbnails(view, state: reactor.currentState)
    }
}

extension HomeViewController: UICollectionViewDataSource, UICollectionViewDelegate, HomeGridLayoutDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        homeView.updateScrollPosition(scrollView.contentOffset.y)
    }

    func scrollViewDidEndDragging(
        _ scrollView: UIScrollView,
        willDecelerate decelerate: Bool
    ) {
        guard !decelerate else { return }
        homeView.snapHeader()
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        homeView.snapHeader()
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        pinnedRowSectionCount + sections.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        guard pinnedRowSectionCount <= section else { return 0 }
        return sections[section - pinnedRowSectionCount].clips.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let clip = clip(at: indexPath)
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
        switch kind {
        case HomeGridLayout.pinnedRowKind:
            guard let row = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: HomePinnedRowView.reuseIdentifier,
                for: indexPath
            ) as? HomePinnedRowView else { preconditionFailure("HomePinnedRowView registration mismatch") }
            row.delegate = self
            configurePinnedRow(row, state: reactor.currentState)
            return row

        default:
            guard let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: HomeSectionHeaderView.reuseIdentifier,
                for: indexPath
            ) as? HomeSectionHeaderView else { preconditionFailure("HomeSectionHeaderView registration mismatch") }
            header.configure(title: sections[indexPath.section - pinnedRowSectionCount].kind.title)
            return header
        }
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
        willDisplaySupplementaryView view: UICollectionReusableView,
        forElementKind elementKind: String,
        at indexPath: IndexPath
    ) {
        guard let row = view as? HomePinnedRowView else { return }
        requestPinnedRowThumbnails(row, state: reactor.currentState)
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
        let clip = clip(at: indexPath)
        switch clip.content {
        case .text:
            return HomeTextCell.height(for: clip, width: width)
        case .image:
            return HomeImageCell.height(for: clip, width: width)
        }
    }

    func homeLayoutHeightForPinnedRow(_ layout: HomeGridLayout) -> CGFloat {
        pinnedClips.isEmpty ? 0 : HomePinnedRowView.height
    }
}
