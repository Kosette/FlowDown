//
//  AppEnvironment.swift
//  FlowDown
//
//  Created by OpenAI Code Assistant on 2/17/25.
//

import Foundation
import Storage

/// Centralizes core services so they can be swapped (for previews/tests) without touching global singletons.
enum AppEnvironment {
    struct Container {
        let storage: Storage
        let syncEngine: SyncEngine
    }

    private static var containerStack: [Container] = []

    static var current: Container {
        guard let container = containerStack.last else {
            fatalError("Call AppEnvironment.bootstrap(_) before accessing dependencies.")
        }
        return container
    }

    @discardableResult
    static func bootstrap(_ container: Container) -> Container {
        containerStack = [container]
        apply(container)
        return container
    }

    static func push(_ container: Container) {
        containerStack.append(container)
        apply(container)
    }

    static func pop() {
        guard containerStack.count > 1 else {
            assertionFailure("Attempted to pop the root AppEnvironment container.")
            return
        }
        _ = containerStack.popLast()
        if let container = containerStack.last {
            apply(container)
        }
    }

    private static func apply(_ container: Container) {
        Storage.setSyncEngine(container.syncEngine)
    }
}

extension AppEnvironment.Container {
    static func live() -> AppEnvironment.Container {
        let storage: Storage
        do {
            storage = try Storage.db()
        } catch {
            fatalError(error.localizedDescription)
        }

        let syncEngine = SyncEngine(
            storage: storage,
            containerIdentifier: CloudKitConfig.containerIdentifier,
            mode: .live,
            automaticallySync: true,
        )
        return .init(storage: storage, syncEngine: syncEngine)
    }
}

// Convenience accessors to keep existing call sites small.
var sdb: Storage { AppEnvironment.current.storage }
var syncEngine: SyncEngine { AppEnvironment.current.syncEngine }
