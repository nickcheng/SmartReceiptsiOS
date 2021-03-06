//
//  TripsPresenter.swift
//  SmartReceipts
//
//  Created by Bogdan Evsenev on 11/06/2017.
//  Copyright © 2017 Will Baumann. All rights reserved.
//

import Foundation
import Viperit
import RxSwift
import UserNotifications

class TripsPresenter: Presenter {
    
    let tripDetailsSubject = PublishSubject<WBTrip>()
    let tripEditSubject = PublishSubject<WBTrip>()
    let tripDeleteSubject = PublishSubject<WBTrip>()
    
    private let bag = DisposeBag()
    
    override func viewHasLoaded() {
        interactor.configureSubscribers()
        executeFor(iPhone: {}, iPad: { router.openNoTrips() })
        
        interactor.lastOpenedTrip
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { trip in
                self.router.openDetails(trip: trip)
            }).disposed(by: bag)
        
        view.addButton.rx.tap
            .subscribe(onNext: {
                self.router.openAddTrip()
            }).disposed(by: bag)
        
        view.settingsTap
            .subscribe(onNext: {
                self.router.openSettings()
            }).disposed(by: bag)
        
        view.autoScansTap
            .filter({ AuthService.shared.isLoggedIn })
            .subscribe(onNext: {
                self.router.openAutoScans()
            }).disposed(by: bag)
        
        view.autoScansTap
            .filter({ !AuthService.shared.isLoggedIn })
            .subscribe(onNext: {
                let authModule = self.router.openAuth()
                _ = authModule.successAuth
                    .map({ authModule.close() })
                    .delay(VIEW_CONTROLLER_TRANSITION_DELAY, scheduler: MainScheduler.instance)
                    .flatMap({ _ -> Observable<UNAuthorizationStatus> in
                        PushNotificationService.shared.authorizationStatus()
                    }).flatMap({ status -> Observable<Void> in
                        let text = LocalizedString("push.request.alert.text")
                        return status == .notDetermined ? UIAlertController.showInfo(text: text) : Observable<Void>.just()
                    }).subscribe(onNext: { [unowned self] in
                        _ = PushNotificationService.shared.requestAuthorization().subscribe()
                        self.router.openAutoScans()
                    })
            }).disposed(by: bag)
        
        view.backupTap
            .subscribe(onNext: {
                self.router.openBackup()
            }).disposed(by: bag)
        
        view.debugButton.rx.tap
            .subscribe(onNext: {
                self.router.openDebug()
            }).disposed(by: bag)
        
        tripDetailsSubject
            .do(onNext: { [unowned self] trip in
                self.interactor.markLastOpened(trip: trip)
            }).subscribe(onNext: { trip in
                self.router.openDetails(trip: trip)
            }).disposed(by: bag)
        
        tripEditSubject
            .subscribe(onNext: { trip in
                self.router.openEdit(trip: trip)
            }).disposed(by: bag)
        
    }
    
    func presentSettings() {
        router.openSettings()
    }
    
    func presentAddTrip() {
        router.openAddTrip()
    }
    
    func fetchedModelAdapter() -> FetchedModelAdapter? {
        return interactor.fetchedModelAdapter()
    }
}


// MARK: - VIPER COMPONENTS API (Auto-generated code)
private extension TripsPresenter {
    var view: TripsViewInterface {
        return _view as! TripsViewInterface
    }
    var interactor: TripsInteractor {
        return _interactor as! TripsInteractor
    }
    var router: TripsRouter {
        return _router as! TripsRouter
    }
}
