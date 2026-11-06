import Combine
import UIKit

class HeadphoneSettingsViewController: PCTableViewController {
    private var allSections: [TableSection] = [
        .init(rows: [.previousAction, .nextAction], footer: L10n.settingsHeadphoneControlsFooter)
    ]

    private var visibleSections: [TableSection] = []
    private var cancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = L10n.settingsHeadphoneControls
        Analytics.track(.settingsHeadphoneControlsShown)
    }

    override var customCellTypes: [ReusableTableCell.Type] {
        [SwitchCell.self, DisclosureCell.self]
    }

    override func reloadData() {
        visibleSections = allSections.filter(\.visible)

        super.reloadData()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let section = visibleSections[indexPath.section]
        let row = section.rows[indexPath.row]

        let actions: [HeadphoneControlAction] = [.skipForward, .nextChapter, .skipBack, .previousChapter]

        switch row {
        case .nextAction:
            showPicker(L10n.settingsNextAction, actions, currentValue: Settings.headphonesNextAction) { [weak self] in
                self?.headphoneOptionChanged(to: $0, for: row)
            }
        case .previousAction:
            showPicker(L10n.settingsPreviousAction, actions, currentValue: Settings.headphonesPreviousAction) { [weak self] in
                self?.headphoneOptionChanged(to: $0, for: row)
            }
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = visibleSections[indexPath.section]
        let row = section.rows[indexPath.row]

        switch row {
        case .previousAction:
            let cell = tableView.dequeueReusableCell(DisclosureCell.self, for: indexPath)
            cell.cellLabel.text = L10n.settingsPreviousAction
            cell.setImage(imageName: "settings_headphone_controls_skip_back")
            cell.cellSecondaryLabel.text = Settings.headphonesPreviousAction.displayableTitle

            return cell
        case .nextAction:
            let cell = tableView.dequeueReusableCell(DisclosureCell.self, for: indexPath)
            cell.cellLabel.text = L10n.settingsNextAction
            cell.setImage(imageName: "settings_headphone_controls_skip_forward")
            cell.cellSecondaryLabel.text = Settings.headphonesNextAction.displayableTitle
            return cell
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        visibleSections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        visibleSections[section].rows.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        visibleSections[section].footer
    }

    // MARK: - Headphone Option

    private func headphoneOptionChanged(to selection: HeadphoneControlAction, for row: TableSection.Row) {
        // Store the setting action as a closure to be able to finish setting the value after the purchase
        let action = { [weak self] in
            switch row {
            case .previousAction:
                Settings.trackValueChanged(.settingsHeadphoneControlsPreviousChanged, value: selection)
                Settings.headphonesPreviousAction = selection

            case .nextAction:
                Settings.trackValueChanged(.settingsHeadphoneControlsNextChanged, value: selection)
                Settings.headphonesNextAction = selection
            }

            self?.reloadData()
        }

        // Show the upsell if needed
        selection.isUnlocked ? action() : showUpsell(for: selection, unlocked: action)
    }

    private func showUpsell(for selection: HeadphoneControlAction, unlocked: @escaping () -> Void) {
        guard let feature = selection.paidFeature else { return }

        // If the feature is unlocked, then finish updating the setting they were trying to change to
        // This will only fire once, and only if the feature is unlocked.
        feature.objectWillChange
            .receive(on: DispatchQueue.main)
            .first(where: { feature.isUnlocked })
            .sink { unlocked() }
            .store(in: &cancellables)

        feature.presentUpgradeController(from: self, source: .headphoneSettings)
    }

    // MARK: - Data Struct

    private struct TableSection {
        /// The visible rows in the section
        var rows: [Row] {
            allRows.filter(\.visible)
        }

        /// Whether the section should be visible or not
        var visible: Bool {
            !rows.isEmpty
        }

        private let allRows: [Row]

        /// The footer text to display
        let footer: String

        init(rows: [Row], footer: String) {
            self.allRows = rows
            self.footer = footer
        }

        enum Row {
            case previousAction, nextAction

            var visible: Bool { true }
        }
    }
}

// MARK: - Private: Options Picker

private extension HeadphoneSettingsViewController {
    private func showPicker(_ title: String, _ options: [HeadphoneControlAction], currentValue: HeadphoneControlAction, onChange: @escaping ((HeadphoneControlAction) -> Void)) {
        let picker = OptionsPicker(title: title)
        picker.addActions(options.map { option in
            OptionAction(label: option.displayableTitle, icon: option.iconName, tintIcon: false, selected: currentValue == option) {
                onChange(option)
            }
        })
        picker.present(from: self)
    }
}

// MARK: - Helper extension to get the title and image for each option

private extension HeadphoneControlAction {
    var displayableTitle: String {
        switch self {
        case .skipBack:
            return L10n.skipBack
        case .skipForward:
            return L10n.skipForward
        case .previousChapter:
            return L10n.siriShortcutPreviousChapter.localizedCapitalized
        case .nextChapter:
            return L10n.siriShortcutNextChapter.localizedCapitalized
        }
    }

    var iconName: String? {
        isUnlocked ? nil : "plusGold24"
    }
}
