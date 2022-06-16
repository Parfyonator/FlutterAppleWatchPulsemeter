//
//  WatchViewModel.swift
//  watch Extension
//
//  Created by Amorn Apichattanakul on 17/4/21.
//

import Foundation
import WatchConnectivity
import HealthKit
import UIKit

class WatchViewModel: NSObject, ObservableObject, HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        
    }
    
    var session: WCSession
    var workout: HKWorkoutSession?
    let healthStore = HKHealthStore()
    var heartRateUnit: HKUnit = HKUnit(from: "count/min") // HKUnit.countUnit().unitDivided(by: HKUnit.minuteUnit())
    @Published var counter = 0
    @Published var heartReate: Double = 0.0 // HKQuantityType // = (HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifier.heartRate) ?? 0)
    
    // Add more cases if you have more receive method
    enum WatchReceiveMethod: String {
        case sendCounterToNative
    }
    
    // Add more cases if you have more sending method
    enum WatchSendMethod: String {
        case sendCounterToFlutter
    }
    
    init(session: WCSession = .default) {
//        let workoutConfig = HKWorkoutConfiguration()
//        workoutConfig.activityType = .coreTraining
//        workoutConfig.locationType = .indoor
        
        self.session = session
//        self.healthStore = HKHealthStore()
//        self.workout = try HKWorkoutSession(
//            healthStore: self.healthStore,
//            configuration: workoutConfig
//        )
        super.init()
        self.session.delegate = self
//        self.workout.delegate = self
        startWorkout()
        session.activate()
        
        let heartRateSampleType = HKSampleType.quantityType(forIdentifier: .heartRate) // HKObjectType.quantityType(forIdentifier: .heartRate)!
        if #available(watchOSApplicationExtension 8.0, *) {
            self.healthStore.enableBackgroundDelivery(for: heartRateSampleType!, frequency: .immediate, withCompletion: { (success: Bool, error: Error?) in
                debugPrint("enableBackgroundDeliveryForType handler called for \(heartRateSampleType) - success: \(success), error: \(error)")
                //            HKHealthStore().execute(anchorQuery)
                self.observerHeartRateSamples()
            })
        } else {
            // Fallback on earlier versions
        }
//        observerHeartRateSamples()
    }
    
    private func startWorkout() {
        let workoutConfiguration = HKWorkoutConfiguration()
        workoutConfiguration.activityType = .coreTraining
        workoutConfiguration.locationType = .indoor
    
        do {
            workout = try HKWorkoutSession(
                healthStore: self.healthStore,
                configuration: workoutConfiguration
            )
            workout?.delegate = self
            workout?.startActivity(with: Date())
//            healthStore.start(workout!)
        } catch {
            print("Failed to start workout:", error)
        }
    }
    
    func endWorkout() {
        workout?.stopActivity(with: Date())
        workout?.end()
    }
    
    func sendDataMessage(for method: WatchSendMethod, data: [String: Any] = [:]) {
        sendMessage(for: method.rawValue, data: data)
    }
    
    func updateHeartRate(heartRateValue: Double) { // HKQuantityType
        self.heartReate = heartRateValue
    }
    
    func observerHeartRateSamples() {
        let heartRateSampleType = HKObjectType.quantityType(forIdentifier: .heartRate)
        
//        if let observerQuery = observerQuery {
//            healthStore.stop(observerQuery)
//        }
        
        let observerQuery = HKObserverQuery(sampleType: heartRateSampleType!, predicate: nil) { (_, _, error) in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                return
            }
            
            self.fetchLatestHeartRateSample { (sample) in
                guard let sample = sample else {
                    return
                }
                
                DispatchQueue.main.async {
                    let heartRate = sample.quantity.doubleValue(for: self.heartRateUnit)
                    print("Heart Rate Sample: \(heartRate)")
                    self.updateHeartRate(heartRateValue: heartRate)
                    self.sendDataMessage(for: .sendCounterToFlutter, data: ["counter": self.heartReate])
                }
            }
        }
        
        healthStore.execute(observerQuery)
    }

    func fetchLatestHeartRateSample(completionHandler: @escaping (_ sample: HKQuantitySample?) -> Void) {
        guard let sampleType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate) else {
            completionHandler(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: Date.distantPast, end: Date(), options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: sampleType,
                                  predicate: predicate,
                                  limit: Int(HKObjectQueryNoLimit),
                                  sortDescriptors: [sortDescriptor]) { (_, results, error) in
                                    if let error = error {
                                        print("Error: \(error.localizedDescription)")
                                        return
                                    }
                                    
                                    completionHandler(results?[0] as? HKQuantitySample)
        }
        
        healthStore.execute(query)
    }
}

extension WatchViewModel: WCSessionDelegate {
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
    }
    
    // Receive message From AppDelegate.swift that send from iOS devices
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            guard let method = message["method"] as? String, let enumMethod = WatchReceiveMethod(rawValue: method) else {
                return
            }
            
            switch enumMethod {
            case .sendCounterToNative:
                self.counter = (message["data"] as? Int) ?? 0
            }
        }
    }
    
    func sendMessage(for method: String, data: [String: Any] = [:]) {
        guard session.isReachable else {
            return
        }
        let messageData: [String: Any] = ["method": method, "data": data]
        session.sendMessage(messageData, replyHandler: nil, errorHandler: nil)
    }
    
}

