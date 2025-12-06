//
//  main.swift
//  FlowDown
//
//  Created by 秋星桥 on 2024/12/31.
//

@_exported import Foundation
@_exported import Logger
@_exported import SnapKit
@_exported import SwifterSwift
@_exported import UIKit

import Storage

#if !DEBUG
    fclose(stdout)
    fclose(stderr)

    Security.removeDebugger()
    guard Security.validateAppSignature() else {
        Security.crashOut()
    }
#endif

#if (os(macOS) || targetEnvironment(macCatalyst)) && ENABLE_SANDBOX_CHECK
    do {
        // make sure sandbox is enabled otherwise panic the app
        let sandboxTestDir = URL(fileURLWithPath: "/tmp/sandbox.test.\(UUID().uuidString)")
        FileManager.default.createFile(atPath: sandboxTestDir.path, contents: nil, attributes: nil)
        if FileManager.default.fileExists(atPath: sandboxTestDir.path) {
            fatalError("This app should not run outside of sandbox which may cause trouble.")
        }
    }
#endif

let logger = Logger.app
_ = LogStore.shared

let disposableResourcesDir = FileManager.default
    .temporaryDirectory
    .appendingPathComponent("DisposableResources")

AppEnvironment.bootstrap(.live())

import ConfigurableKit
import MLX

#if DEBUG
    logger.infoFile("Running in DEBUG mode")
    ConfigurableKit.storage = UserDefaultKeyValueStorage(suite: .standard, prefix: "in-house.")
#endif

#if targetEnvironment(simulator) || arch(x86_64)
    ConfigurableKit.set(value: false, forKey: MLX.GPU.isSupportedKey)
    assert(!MLX.GPU.isSupported)
#else
    ConfigurableKit.set(value: true, forKey: MLX.GPU.isSupportedKey)
    assert(MLX.GPU.isSupported)
#endif

_ = ModelManager.shared
_ = ModelToolsManager.shared
_ = ConversationManager.shared
_ = MCPService.shared

Task.detached(priority: .background) {
    try? FileManager.default.removeItem(at: disposableResourcesDir)
}

#if os(macOS) || targetEnvironment(macCatalyst)
    _ = UpdateManager.shared
    FLDCatalystHelper.shared.install()
#endif

_ = ChatSelection.shared

_ = UIApplicationMain(
    CommandLine.argc,
    CommandLine.unsafeArgv,
    nil,
    NSStringFromClass(AppDelegate.self),
)
