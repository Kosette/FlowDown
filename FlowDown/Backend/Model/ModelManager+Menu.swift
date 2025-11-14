//
//  ModelManager+Menu.swift
//  FlowDown
//
//  Created by 秋星桥 on 2/3/25.
//

import AlertController
import ChatClientKit
import ConfigurableKit
import Foundation
import Storage
import UIKit

extension ModelManager {
    private func openModelManagementPage(controller: UIViewController?) {
        guard let controller else { return }
        if let nav = controller.navigationController {
            let controller = SettingController.SettingContent.ModelController()
            nav.pushViewController(controller, animated: true)
        } else {
            let setting = SettingController()
            SettingController.setNextEntryPage(.modelManagement)
            controller.present(setting, animated: true)
        }
    }

    func buildModelSelectionMenu(
        currentSelection: ModelIdentifier? = nil,
        requiresCapabilities: Set<ModelCapabilities> = [],
        allowSelectionWithNone: Bool = false,
        onCompletion: @escaping (ModelIdentifier) -> Void,
        includeQuickActions: Bool = true
    ) -> [UIMenuElement] {
        let localModels = ModelManager.shared.localModels.value.filter {
            !$0.model_identifier.isEmpty
        }.filter { requiresCapabilities.isSubset(of: $0.capabilities) }
        let cloudModels = ModelManager.shared.cloudModels.value.filter {
            !$0.model_identifier.isEmpty
        }.filter { requiresCapabilities.isSubset(of: $0.capabilities) }

        var appleIntelligenceAvailable = false
        if #available(iOS 26.0, macCatalyst 26.0, *),
           AppleIntelligenceModel.shared.isAvailable,
           requiresCapabilities.isSubset(of: modelCapabilities(
               identifier: AppleIntelligenceModel.shared.modelIdentifier
           ))
        {
            appleIntelligenceAvailable = true
        }

        if localModels.isEmpty, cloudModels.isEmpty, !appleIntelligenceAvailable {
            return []
        }

        var localBuildSections: [String: [(String, LocalModel)]] = [:]
        for item in localModels {
            localBuildSections[item.scopeIdentifier, default: []]
                .append((item.modelDisplayName, item))
        }
        var cloudBuildSections: [String: [(String, CloudModel)]] = [:]
        for item in cloudModels {
            cloudBuildSections[item.auxiliaryIdentifier, default: []]
                .append((item.modelDisplayName, item))
        }

        var localMenuChildren: [UIMenuElement] = []
        var localMenuChildrenOptions: UIMenu.Options = []
        if localModels.count < 4 { localMenuChildrenOptions.insert(.displayInline) }
        var cloudMenuChildren: [UIMenuElement] = []
        var cloudMenuChildrenOptions: UIMenu.Options = []
        if cloudModels.count < 4 { cloudMenuChildrenOptions.insert(.displayInline) }

        for key in localBuildSections.keys.sorted() {
            let items = localBuildSections[key] ?? []
            guard !items.isEmpty else { continue }
            let key = key.isEmpty ? String(localized: "Ungrouped") : key
            localMenuChildren.append(UIMenu(
                title: key,
                options: localMenuChildrenOptions,
                children: items.map { item in
                    UIAction(title: item.0, state: item.1.id == currentSelection ? .on : .off) { _ in
                        onCompletion(item.1.id)
                    }
                }
            ))
        }

        for key in cloudBuildSections.keys.sorted() {
            let items = cloudBuildSections[key] ?? []
            guard !items.isEmpty else { continue }
            let key = key.isEmpty ? String(localized: "Ungrouped") : key
            cloudMenuChildren.append(UIMenu(
                title: key,
                options: cloudMenuChildrenOptions,
                children: items.map { item in
                    UIAction(title: item.0, state: item.1.id == currentSelection ? .on : .off) { _ in
                        onCompletion(item.1.id)
                    }
                }
            ))
        }

        var finalChildren: [UIMenuElement] = []
        var finalOptions: UIMenu.Options = []
        if localMenuChildren.isEmpty || cloudMenuChildren.isEmpty || localMenuChildren.count + cloudMenuChildren.count < 10 {
            finalOptions.insert(.displayInline)
        }

        var leadingElements: [UIMenuElement] = []

        let totalSections = localBuildSections.count + cloudBuildSections.count
        let shouldShowRelatedModels = totalSections > 2

        if shouldShowRelatedModels, let currentSelection, !currentSelection.isEmpty {
            var relatedEntries: [(title: String, identifier: ModelIdentifier)] = []

            if let match = localModels.first(where: { $0.id == currentSelection }) {
                let groupKey = match.scopeIdentifier
                let peers = localBuildSections[groupKey] ?? []
                relatedEntries = peers.map { ($0.0, $0.1.id) }
            } else if let match = cloudModels.first(where: { $0.id == currentSelection }) {
                let groupKey = match.auxiliaryIdentifier
                let peers = cloudBuildSections[groupKey] ?? []
                relatedEntries = peers.map { ($0.0, $0.1.id) }
            }

            if relatedEntries.count > 1 {
                relatedEntries.sort { lhs, rhs in
                    if lhs.identifier == currentSelection { return true }
                    if rhs.identifier == currentSelection { return false }
                    return lhs.title < rhs.title
                }

                let relatedActions: [UIAction] = relatedEntries.map { entry in
                    UIAction(
                        title: entry.title,
                        state: entry.identifier == currentSelection ? .on : .off
                    ) { _ in
                        onCompletion(entry.identifier)
                    }
                }
                leadingElements.append(contentsOf: relatedActions)
            }
        }

        if allowSelectionWithNone {
            finalChildren.append(UIAction(
                title: String(localized: "Use None")
            ) { _ in
                onCompletion("")
            })
        }

        if #available(iOS 26.0, macCatalyst 26.0, *) {
            if appleIntelligenceAvailable {
                finalChildren.append(UIAction(
                    title: AppleIntelligenceModel.shared.modelDisplayName,
                    state: currentSelection == AppleIntelligenceModel.shared.modelIdentifier ? .on : .off
                ) { _ in
                    onCompletion(AppleIntelligenceModel.shared.modelIdentifier)
                })
            }
        }

        if !localMenuChildren.isEmpty {
            finalChildren.append(UIMenu(
                title: String(localized: "Local Models"),
                options: finalOptions,
                children: localMenuChildren
            ))
        }
        if !cloudMenuChildren.isEmpty {
            finalChildren.append(UIMenu(
                title: String(localized: "Cloud Models"),
                options: finalOptions,
                children: cloudMenuChildren
            ))
        }

        if !leadingElements.isEmpty {
            finalChildren.insert(contentsOf: leadingElements, at: 0)
        }

        if includeQuickActions {
            let quickMenu = UIMenu(
                title: String(localized: "Quick Actions"),
                image: UIImage(systemName: "bolt"),
                children: [UIDeferredMenuElement.uncached { completion in
                    var quickChildren: [UIMenuElement] = []

                    var auxiliaryElements: [UIMenuElement] = []
                    let alignAction = UIAction(
                        title: String(localized: "Align with chat model"),
                        state: ModelManager.ModelIdentifier.defaultModelForAuxiliaryTaskWillUseCurrentChatModel ? .on : .off
                    ) { _ in
                        ModelManager.ModelIdentifier.defaultModelForAuxiliaryTaskWillUseCurrentChatModel.toggle()
                    }
                    auxiliaryElements.append(alignAction)

                    if let currentSelection, !currentSelection.isEmpty {
                        auxiliaryElements.append(UIAction(
                            title: String(localized: "Use current selection"),
                            image: UIImage(systemName: "link")
                        ) { _ in
                            ModelManager.ModelIdentifier.defaultModelForAuxiliaryTaskWillUseCurrentChatModel = false
                            ModelManager.ModelIdentifier.defaultModelForAuxiliaryTask = currentSelection
                        })
                    }

                    if !ModelManager.ModelIdentifier.defaultModelForAuxiliaryTaskWillUseCurrentChatModel {
                        let selection = ModelManager.shared.buildModelSelectionMenu(
                            currentSelection: ModelManager.ModelIdentifier.storedAuxiliaryTaskModel,
                            requiresCapabilities: [],
                            allowSelectionWithNone: false,
                            onCompletion: { identifier in
                                ModelManager.ModelIdentifier.defaultModelForAuxiliaryTask = identifier
                            },
                            includeQuickActions: false
                        )
                        if !selection.isEmpty {
                            auxiliaryElements.append(UIMenu(
                                title: String(localized: "Choose model"),
                                options: [.displayInline],
                                children: selection
                            ))
                        }
                    }

                    quickChildren.append(UIMenu(
                        title: String(localized: "Auxiliary Model"),
                        children: auxiliaryElements
                    ))

                    var visualElements: [UIMenuElement] = []
                    if let currentSelection,
                       !currentSelection.isEmpty,
                       ModelManager.shared.modelCapabilities(identifier: currentSelection).contains(.visual)
                    {
                        visualElements.append(UIAction(
                            title: String(localized: "Use current selection"),
                            image: UIImage(systemName: "camera.fill")
                        ) { _ in
                            ModelManager.ModelIdentifier.defaultModelForAuxiliaryVisualTask = currentSelection
                        })
                    }

                    let visualSelection = ModelManager.shared.buildModelSelectionMenu(
                        currentSelection: ModelManager.ModelIdentifier.defaultModelForAuxiliaryVisualTask,
                        requiresCapabilities: [.visual],
                        allowSelectionWithNone: true,
                        onCompletion: { identifier in
                            ModelManager.ModelIdentifier.defaultModelForAuxiliaryVisualTask = identifier
                        },
                        includeQuickActions: false
                    )
                    if !visualSelection.isEmpty {
                        visualElements.append(UIMenu(
                            title: String(localized: "Choose model"),
                            options: [.displayInline],
                            children: visualSelection
                        ))
                    }
                    visualElements.append(UIAction(
                        title: String(localized: "Skip visual assistant when possible"),
                        state: ModelManager.shared.defaultModelForAuxiliaryVisualTaskSkipIfPossible ? .on : .off
                    ) { _ in
                        ModelManager.shared.defaultModelForAuxiliaryVisualTaskSkipIfPossible.toggle()
                    })

                    quickChildren.append(UIMenu(
                        title: String(localized: "Visual Auxiliary Model"),
                        children: visualElements
                    ))

                    let temperatureActions = ModelManager.shared.temperaturePresets.map { preset -> UIAction in
                        let currentValue = Double(ModelManager.shared.temperature)
                        let isCurrent = abs(currentValue - preset.value) < 0.0001
                        let action = UIAction(
                            title: preset.title,
                            image: UIImage(systemName: preset.icon),
                            state: isCurrent ? .on : .off
                        ) { _ in
                            ModelManager.shared.temperature = Float(preset.value)
                        }
                        return action
                    }
                    quickChildren.append(UIMenu(
                        title: String(localized: "Temperature"),
                        children: temperatureActions
                    ))

                    completion(quickChildren)
                }]
            )
            finalChildren.append(quickMenu)
        }

        return finalChildren
    }
}
