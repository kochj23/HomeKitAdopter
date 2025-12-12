#!/usr/bin/swift
//
//  HomeKitQuery.swift
//  Query HomeKit accessories on this Mac
//

import Foundation
import HomeKit

class HomeKitQuery: NSObject, HMHomeManagerDelegate {
    let homeManager = HMHomeManager()
    var hasLoaded = false

    override init() {
        super.init()
        homeManager.delegate = self
    }

    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        hasLoaded = true
        printHomeKitData()
        exit(0)
    }

    func printHomeKitData() {
        print("\n=== HomeKit Homes ===")
        print("Total Homes: \(homeManager.homes.count)")

        for home in homeManager.homes {
            print("\n--- Home: \(home.name) ---")
            print("UUID: \(home.uniqueIdentifier)")
            print("Accessories: \(home.accessories.count)")

            for accessory in home.accessories {
                print("\n  • \(accessory.name)")
                print("    UUID: \(accessory.uniqueIdentifier)")
                print("    Model: \(accessory.model ?? "Unknown")")
                print("    Manufacturer: \(accessory.manufacturer ?? "Unknown")")
                print("    Category: \(accessory.category.categoryType)")
                print("    Room: \(accessory.room?.name ?? "No Room")")
                print("    Reachable: \(accessory.isReachable)")
            }
        }

        print("\n=== Total Accessories: \(homeManager.homes.flatMap { $0.accessories }.count) ===\n")
    }

    func run() {
        print("Querying HomeKit...")
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 5.0))

        if !hasLoaded {
            print("HomeKit data not loaded after 5 seconds. You may need to grant Home access.")
            exit(1)
        }
    }
}

let query = HomeKitQuery()
query.run()
