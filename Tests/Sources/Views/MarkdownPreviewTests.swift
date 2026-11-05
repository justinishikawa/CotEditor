//
//  MarkdownPreviewTests.swift
//
//  CotEditor
//  https://coteditor.com
//
//  Created by CotEditor Project on 2026-11-05.
//
//  ---------------------------------------------------------------------------
//
//  © 2026 CotEditor Project
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import AppKit
import Testing
import StringUtils
@testable import CotEditor

@MainActor struct MarkdownPreviewTests {

    @Test func previewModelUpdatesAndSuspends() async throws {

        let document = TextDocument()
        let model = MarkdownPreviewModel(document: document)

        document.textStorage.replaceCharacters(in: document.textStorage.range, with: "# Initial heading")
        model.resume()
        #expect(model.markdown == "# Initial heading")

        model.suspend()
        document.textStorage.replaceCharacters(in: document.textStorage.range, with: "## Hidden heading")
        try await Task.sleep(for: .milliseconds(400))
        #expect(model.markdown == "# Initial heading")

        model.resume()
        #expect(model.markdown == "## Hidden heading")

        document.textStorage.replaceCharacters(in: document.textStorage.range, with: "### Current heading")
        let didUpdate = await Task.waitFor { model.markdown == "### Current heading" }
        #expect(didUpdate, "Text edits must update the visible preview.")

        model.suspend()
    }


    @Test func previewToggleAndValidation() throws {

        let viewController = ContentViewController(document: TextDocument())
        _ = viewController.view

        let menuItem = NSMenuItem(title: "Preview Markdown", action: #selector(ContentViewController.toggleMarkdownPreview(_:)), keyEquivalent: "")
        #expect(viewController.validateUserInterfaceItem(menuItem))
        #expect(menuItem.state == .off)
        #expect(viewController.splitViewItems.count == 1)

        viewController.toggleMarkdownPreview(nil)
        #expect(viewController.showsMarkdownPreview)
        #expect(viewController.validateUserInterfaceItem(menuItem))
        #expect(menuItem.state == .on)
        #expect(viewController.splitViewItems.count == 2)
        #expect(viewController.splitViewItems[1].minimumThickness == 200)

        viewController.toggleMarkdownPreview(nil)
        #expect(!viewController.showsMarkdownPreview)
        #expect(viewController.splitViewItems.count == 1)
        #expect(viewController.validateUserInterfaceItem(menuItem))
        #expect(menuItem.state == .off)
    }


    @Test func previewIsUnavailableWithoutTextDocument() {

        let viewController = ContentViewController(document: nil)
        _ = viewController.view

        let menuItem = NSMenuItem(title: "Preview Markdown", action: #selector(ContentViewController.toggleMarkdownPreview(_:)), keyEquivalent: "")
        #expect(!viewController.validateUserInterfaceItem(menuItem))

        viewController.toggleMarkdownPreview(nil)
        #expect(!viewController.showsMarkdownPreview)
        #expect(menuItem.state == .off)
        #expect(viewController.splitViewItems.count == 1)
    }


    @Test func previewFollowsSelectedTextDocument() {

        let firstDocument = TextDocument()
        let secondDocument = TextDocument()
        let viewController = ContentViewController(document: firstDocument)
        _ = viewController.view

        viewController.toggleMarkdownPreview(nil)
        viewController.document = secondDocument

        let documentViewController = viewController.hostedViewController as? DocumentViewController
        #expect(viewController.document === secondDocument)
        #expect(documentViewController?.document === secondDocument)
        #expect(!viewController.showsMarkdownPreview)
        #expect(viewController.splitViewItems.count == 1)
        #expect(viewController.splitViewItems[0].viewController === documentViewController)

        viewController.toggleMarkdownPreview(nil)
        #expect(viewController.showsMarkdownPreview)
        #expect(viewController.splitViewItems.count == 2)
    }
}
