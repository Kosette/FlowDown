//
//  SettingContent+General.swift
//  FlowDown
//
//  Created by 秋星桥 on 1/24/25.
//

import AlertController
import ConfigurableKit
import Digger
import MarkdownView
import Storage
import UIKit

extension SettingController.SettingContent {
    class GeneralController: StackScrollController {
        init() {
            super.init(nibName: nil, bundle: nil)
            title = String(localized: "General")
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError()
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .background
        }

        let autoCollapse = ConfigurableObject(
            icon: "arrow.down.right.and.arrow.up.left",
            title: "Collapse Reasoning Content",
            explain: "Enable this to automatically collapse reasoning content after the reasoning is completed. This is useful for keeping the chat interface clean and focused on the final response.",
            key: ModelManager.shared.collapseReasoningSectionWhenCompleteKey,
            defaultValue: false,
            annotation: .boolean
        )
        .createView()

        override func setupContentViews() {
            super.setupContentViews()

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionHeaderView().with(
                    header: "Display"
                )
            ) { $0.bottom /= 2 }
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(BrandingLabel.configurableObject.createView())
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(UIUserInterfaceStyle.configurableObject.createView())
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(MarkdownTheme.configurableObject.createView())
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionFooterView().with(
                    footer: "The above setting only adjusts the text size in conversations. To change the font size globally, please go to the system settings, as this app follows the system’s font size preferences."
                )
            ) { $0.top /= 2 }
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionHeaderView().with(
                    header: "Chat"
                )
            ) { $0.bottom /= 2 }
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(autoCollapse)
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionFooterView().with(
                    footer: "The above setting will take effect at conversation page."
                )
            ) { $0.top /= 2 }
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionHeaderView().with(
                    header: "Editor"
                )
            ) { $0.bottom /= 2 }
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(EditorBehavior.useConfirmationOnSendConfigurableObject.createView())
            stackView.addArrangedSubview(SeparatorView())
            stackView.addArrangedSubviewWithMargin(EditorBehavior.pasteAsFileConfigurableObject.createView())
            stackView.addArrangedSubview(SeparatorView())
            stackView.addArrangedSubviewWithMargin(EditorBehavior.compressImageConfigurableObject.createView())
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionFooterView().with(
                    footer: "Regardless of whether image compression is enabled, the EXIF information of the image will be removed. This will delete information such as the shooting date and location."
                )
            ) { $0.top /= 2 }
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionHeaderView().with(
                    header: "Model Selector"
                )
            ) { $0.bottom /= 2 }
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(ChatView.editorModelNameStyle.createView())
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(ChatView.editorApplyModelToDefault.createView())
            stackView.addArrangedSubview(SeparatorView())

            stackView.addArrangedSubviewWithMargin(
                ConfigurableSectionFooterView().with(
                    footer: "If this switch is turned off, the newly selected model in the conversation will not be used for new conversations."
                )
            ) { $0.top /= 2 }
            stackView.addArrangedSubview(SeparatorView())
        }
    }
}
