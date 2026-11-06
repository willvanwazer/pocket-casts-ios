import PocketCastsDataModel

extension HeadphoneControlAction: Unlockable {
    var paidFeature: PaidFeature? { nil }
}

extension PlayerAction: Unlockable {
    var paidFeature: PaidFeature? { nil }
}
