//
//  TripsDisplayData.swift
//  SmartReceipts
//
//  Created by Bogdan Evsenev on 11/06/2017.
//  Copyright © 2017 Will Baumann. All rights reserved.
//

import Foundation
import Viperit
import MKDropdownMenu
import RxSwift

fileprivate typealias MenuItem = (title: String, subject: PublishSubject<Void>)

final class TripsDisplayData: DisplayData {
    private let settingsSubject = PublishSubject<Void>()
    private let autoScansSubject = PublishSubject<Void>()
    private(set) var menuDisplayData: TripsMenuDisplayData!
    
    var settingsTap: Observable<Void> { return settingsSubject.asObservable() }
    var autoScansTap: Observable<Void> { return autoScansSubject.asObservable() }
    
    required init() {
        let items: [MenuItem]  = [
            (LocalizedString("menu.item.settings"), settingsSubject),
            (LocalizedString("menu.item.auto.scans"), autoScansSubject)
        ]
        menuDisplayData = TripsMenuDisplayData(items: items)
    }
    
}

// MENU
class TripsMenuDisplayData: NSObject, MKDropdownMenuDelegate, MKDropdownMenuDataSource  {
    private var items = [MenuItem]()
    
    fileprivate init(items: [MenuItem]) {
        self.items = items
    }
    
    func dropdownMenu(_ dropdownMenu: MKDropdownMenu, numberOfRowsInComponent component: Int) -> Int {
        return items.count
    }
    
    func numberOfComponents(in dropdownMenu: MKDropdownMenu) -> Int {
        return 1
    }
    
    func dropdownMenu(_ dropdownMenu: MKDropdownMenu, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        return NSAttributedString(string: items[row].title, attributes: [
            NSFontAttributeName: UIFont.systemFont(ofSize: 16, weight: UIFontWeightMedium),
            NSForegroundColorAttributeName: AppTheme.primaryColor
        ])
    }
    
    func dropdownMenu(_ dropdownMenu: MKDropdownMenu, didSelectRow row: Int, inComponent component: Int) {
        items[row].subject.onNext()
        dropdownMenu.closeAllComponents(animated: true)
    }
}
