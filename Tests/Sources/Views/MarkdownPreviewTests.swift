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
import Observation
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


    @Test func previewModelObservesBaseURLChanges() async {

        let document = TextDocument()
        let model = MarkdownPreviewModel(document: document)
        let directoryURL = URL(filePath: "/tmp/MarkdownPreviewTests", directoryHint: .isDirectory)

        await confirmation("The model publishes file URL changes to SwiftUI.") { confirmation in
            withObservationTracking {
                _ = model.baseURL
            } onChange: {
                confirmation()
            }

            document.fileURL = directoryURL.appending(component: "note.md")
            try? await Task.sleep(for: .milliseconds(100))
        }

        #expect(model.baseURL == directoryURL)
    }


    @Test func previewImageLoaderResolvesRelativeFileURL() async throws {

        let directoryURL = FileManager.default.temporaryDirectory.appending(component: UUID().uuidString, directoryHint: .isDirectory)
        let assetsURL = directoryURL.appending(component: "assets", directoryHint: .isDirectory)
        let imageURL = assetsURL.appending(component: "image.png")
        try FileManager.default.createDirectory(at: assetsURL, withIntermediateDirectories: true)
        try Data().write(to: imageURL)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let loader = MarkdownPreviewAttachmentLoader(baseURL: directoryURL)
        let resolvedURL = try await loader.resolvedURL(for: URL(string: "assets/image.png")!)

        #expect(resolvedURL == imageURL)
    }


    @Test func previewImageLoaderLeavesRemoteURLUnchanged() async throws {

        let remoteURL = try #require(URL(string: "https://example.com/image.png"))
        let loader = MarkdownPreviewAttachmentLoader(baseURL: URL(filePath: "/tmp"))

        #expect(try await loader.resolvedURL(for: remoteURL) == remoteURL)
    }


    @Test func previewToggleAndValidation() throws {

        let viewController = ContentViewController(document: TextDocument())
        _ = viewController.view

        let menuItem = NSMenuItem(title: "Preview Markdown", action: #selector(ContentViewController.toggleMarkdownPreview(_:)), keyEquivalent: "")
        #expect(viewController.validateUserInterfaceItem(menuItem))
        #expect(menuItem.state == .off)
        #expect(viewController.splitView.subviews.count == 1)

        viewController.toggleMarkdownPreview(nil)
        #expect(viewController.showsMarkdownPreview)
        #expect(viewController.validateUserInterfaceItem(menuItem))
        #expect(menuItem.state == .on)
        #expect(viewController.splitView.subviews.count == 2)

        viewController.toggleMarkdownPreview(nil)
        #expect(!viewController.showsMarkdownPreview)
        #expect(viewController.splitView.subviews.count == 1)
        #expect(viewController.validateUserInterfaceItem(menuItem))
        #expect(menuItem.state == .off)
    }


    @Test func previewToggleBeforeViewLoad() throws {

        let viewController = ContentViewController(document: TextDocument())
        let menuItem = NSMenuItem(title: "Preview Markdown", action: #selector(ContentViewController.toggleMarkdownPreview(_:)), keyEquivalent: "")

        viewController.toggleMarkdownPreview(nil)
        #expect(!viewController.isViewLoaded)
        _ = viewController.view

        #expect(viewController.showsMarkdownPreview)
        #expect(viewController.validateUserInterfaceItem(menuItem))
        #expect(menuItem.state == .on)
        #expect(viewController.splitView.subviews.count == 2)
    }


    @Test func previewUnavailableBeforeViewLoad() throws {

        let viewController = ContentViewController(document: nil)
        let menuItem = NSMenuItem(title: "Preview Markdown", action: #selector(ContentViewController.toggleMarkdownPreview(_:)), keyEquivalent: "")

        viewController.toggleMarkdownPreview(nil)
        _ = viewController.view

        #expect(!viewController.showsMarkdownPreview)
        #expect(!viewController.validateUserInterfaceItem(menuItem))
        #expect(menuItem.state == .off)
        #expect(viewController.splitView.subviews.count == 1)
    }


    @Test func previewIsUnavailableWithoutTextDocument() {

        let viewController = ContentViewController(document: nil)
        _ = viewController.view

        let menuItem = NSMenuItem(title: "Preview Markdown", action: #selector(ContentViewController.toggleMarkdownPreview(_:)), keyEquivalent: "")
        #expect(!viewController.validateUserInterfaceItem(menuItem))

        viewController.toggleMarkdownPreview(nil)
        #expect(!viewController.showsMarkdownPreview)
        #expect(menuItem.state == .off)
        #expect(viewController.splitView.subviews.count == 1)
    }


    @Test func previewRetainsUserSelectedWidth() async throws {

        let viewController = ContentViewController(document: TextDocument())
        _ = viewController.view
        let window = NSWindow(contentViewController: viewController)
        window.setContentSize(NSSize(width: 1_000, height: 720))
        window.makeKeyAndOrderFront(nil)
        window.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        viewController.splitView.layoutSubtreeIfNeeded()
        #expect(window.contentLayoutRect.width == 1_000)
        #expect(viewController.splitView.bounds.width == 1_000)
        defer { window.close() }

        viewController.toggleMarkdownPreview(nil)
        viewController.view.layoutSubtreeIfNeeded()
        viewController.splitView.layoutSubtreeIfNeeded()
        viewController.splitView.setPosition(600, ofDividerAt: 0)
        viewController.view.layoutSubtreeIfNeeded()
        let previewView = viewController.splitView.subviews[1]
        let editorView = viewController.splitView.subviews[0]
        #expect(previewView.frame.width > 200)
        let previewWidth = previewView.frame.width
        let editorWidth = editorView.frame.width

        for _ in 0..<3 {
            viewController.toggleMarkdownPreview(nil)
            viewController.view.layoutSubtreeIfNeeded()
            viewController.splitView.layoutSubtreeIfNeeded()
            #expect(viewController.splitView.subviews.count == 1)

            viewController.toggleMarkdownPreview(nil)
            viewController.view.layoutSubtreeIfNeeded()
            viewController.splitView.layoutSubtreeIfNeeded()
            let didRestoreWidth = await Task.waitFor { abs(previewView.frame.width - previewWidth) < 0.5 }

            #expect(didRestoreWidth, "Restored preview width: \(previewView.frame.width), expected: \(previewWidth)")
            #expect(abs(editorView.frame.width - editorWidth) < 0.5)
        }
    }


    @Test func documentReplacementBeforeViewLoadDoesNotLoadViews() throws {

        let viewController = ContentViewController(document: nil)
        #expect(!viewController.isViewLoaded)

        let document = TextDocument()
        viewController.document = document

        #expect(!viewController.isViewLoaded)
        #expect(viewController.hostedViewController.viewIfLoaded == nil)

        _ = viewController.view
        let documentViewController = try #require(viewController.hostedViewController as? DocumentViewController)
        #expect(documentViewController.document === document)
        #expect(viewController.splitView.subviews.count == 1)
        #expect(viewController.splitView.subviews[0] === documentViewController.view)
    }


    @Test func openingDocumentReplacesNoDocumentView() {

        let viewController = ContentViewController(document: nil)
        _ = viewController.view
        #expect(viewController.splitView.subviews.count == 1)

        let document = TextDocument()
        viewController.document = document

        let documentViewController = viewController.hostedViewController as? DocumentViewController
        #expect(documentViewController?.document === document)
        #expect(viewController.splitView.subviews.count == 1)
        #expect(viewController.splitView.subviews[0] === documentViewController?.view)

        viewController.toggleMarkdownPreview(nil)
        #expect(viewController.showsMarkdownPreview)
        #expect(viewController.splitView.subviews.count == 2)
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
        #expect(viewController.splitView.subviews.count == 1)
        #expect(viewController.splitView.subviews[0] === documentViewController?.view)

        viewController.toggleMarkdownPreview(nil)
        #expect(viewController.showsMarkdownPreview)
        #expect(viewController.splitView.subviews.count == 2)
    }
}
