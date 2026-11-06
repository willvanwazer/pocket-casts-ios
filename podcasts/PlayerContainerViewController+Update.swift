import Foundation
import PocketCastsDataModel
import PocketCastsUtils
import UIKit

extension PlayerContainerViewController {
    func updateColors() {
        view.backgroundColor = PlayerColorHelper.playerBackgroundColor01()
        #if !APPCLIP
        updateArtworkBackground()
        if #available(iOS 27.1, *) {
            updateLargeScreenColors()
        }
        #endif
    }

    @objc func update() {
        guard PlaybackManager.shared.currentEpisode != nil else {
            closeNowPlaying()

            return
        }

        updateColors()
        updateAvailableTabs()
    }

    private func updateAvailableTabs() {
        #if !APPCLIP
        if #available(iOS 27.1, *), usesLargeScreenLayout {
            updateLargeScreenTabs(force: false)
            return
        }

        guard let playingEpisode = PlaybackManager.shared.currentEpisode else { return }

        // Update the colors when the episode changes
        tabsView.themeDidChange()

        let shouldShowNotes = (playingEpisode is Episode)
        let shouldShowChapters = PlaybackManager.shared.chapterCount() > 0
        let shouldShowTranscript = isTranscriptAvailable(for: playingEpisode)

        // check to see if the visible views are already configured correctly
        if shouldShowNotes == showingNotes,
            shouldShowChapters == showingChapters,
            shouldShowTranscript == showingTranscript {
            return
        }

        let selectedTab = tabsView.tabs[safe: tabsView.currentTab] ?? .nowPlaying
        showNotesItem.removeFromParent()
        showNotesItem.view.removeFromSuperview()
        showingNotes = false

        chaptersItem.removeFromParent()
        chaptersItem.view.removeFromSuperview()
        showingChapters = false

        if transcriptsItem.parent != nil {
            transcriptsItem.willBeRemovedFromPlayer()
            transcriptsItem.willMove(toParent: nil)
            transcriptsItem.view.removeFromSuperview()
            transcriptsItem.removeFromParent()
        }
        showingTranscript = false

        // Uploaded files can have no secondary pages. Keep the content width closed
        // at Now Playing even after removing the previous episode's tabs.
        finalScrollViewConstraint?.isActive = false
        finalScrollViewConstraint = nowPlayingItem.view.trailingAnchor.constraint(equalTo: mainScrollView.trailingAnchor)
        finalScrollViewConstraint?.isActive = true
        tabsView.tabs = [.nowPlaying]

        var previousTab: PlayerItemViewController = nowPlayingItem

        if shouldShowTranscript {
            showingTranscript = true
            tabsView.tabs += [.transcript]
            addTab(transcriptsItem, previousTab: &previousTab)
        }

        if shouldShowNotes {
            showingNotes = true
            tabsView.tabs += [.showNotes]

            addTab(showNotesItem, previousTab: &previousTab)
        }

        if shouldShowChapters {
            showingChapters = true
            tabsView.tabs += [.chapters]

            addTab(chaptersItem, previousTab: &previousTab)
        }

        tabsView.currentTab = tabsView.tabs.firstIndex(of: selectedTab) ?? 0
        view.layoutIfNeeded()
        let offset = CGFloat(tabsView.currentTab) * mainScrollView.bounds.width
        mainScrollView.setContentOffset(CGPoint(x: offset, y: 0), animated: false)
        #endif
    }

    private func addTab(_ tab: PlayerItemViewController, previousTab: inout PlayerItemViewController) {
        guard addTab(tab, after: previousTab) else { return }

        previousTab = tab
    }

    @discardableResult
    func addTab(_ tab: PlayerItemViewController, after afterTab: PlayerItemViewController? = nil) -> Bool {
        guard let tabView = tab.view else { return false }

        tab.willBeAddedToPlayer()
        mainScrollView.addSubview(tabView)
        addChild(tab)

        let previousAnchor = afterTab?.view.map { $0.trailingAnchor } ?? mainScrollView.leadingAnchor

        finalScrollViewConstraint?.isActive = false
        let finalConstraint = tab.view.trailingAnchor.constraint(equalTo: mainScrollView.trailingAnchor)
        NSLayoutConstraint.activate([
            tabView.leadingAnchor.constraint(equalTo: previousAnchor),
            tabView.topAnchor.constraint(equalTo: mainScrollView.topAnchor),
            tabView.bottomAnchor.constraint(equalTo: mainScrollView.bottomAnchor),
            tabView.widthAnchor.constraint(equalTo: mainScrollView.widthAnchor),
            tabView.heightAnchor.constraint(equalTo: mainScrollView.heightAnchor),
            finalConstraint
        ])

        finalScrollViewConstraint = finalConstraint
        tab.didMove(toParent: self)
        return true
    }
}
