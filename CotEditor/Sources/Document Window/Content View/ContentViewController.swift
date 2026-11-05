//
//  ContentViewController.swift
//
//  CotEditor
//  https://coteditor.com
//
//  Created by 1024jp on 2024-05-04.
//
//  ---------------------------------------------------------------------------
//
//  © 2024-2026 1024jp
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
import SwiftUI

final class ContentViewController: NSViewController, NSSplitViewDelegate, NSUserInterfaceValidations {

    // MARK: Public Properties

    var document: DataDocument?  { didSet { self.updateDocument(from: oldValue) } }

    private(set) var hostedViewController: NSViewController


    // MARK: Private Properties

    let splitView = NSSplitView()

    private var markdownPreviewViewController: NSViewController?

    private var markdownPreviewWidth: CGFloat?


    /// Whether the Markdown preview is visible.
    private(set) var showsMarkdownPreview = false {

        didSet {
            guard self.showsMarkdownPreview != oldValue else { return }

            self.setMarkdownPreviewVisible(self.showsMarkdownPreview)
        }
    }


    // MARK: Lifecycle

    init(document: DataDocument?) {

        self.document = document
        self.hostedViewController = Self.viewController(document: document)

        super.init(nibName: nil, bundle: nil)

        self.addChild(self.hostedViewController)
    }


    @available(*, unavailable)
    required init?(coder: NSCoder) {

        fatalError("init(coder:) has not been implemented")
    }


    override func loadView() {

        let view = NSView()
        view.embedSubview(self.splitView)

        self.view = view
    }


    override func viewDidLoad() {

        super.viewDidLoad()

        self.splitView.isVertical = true
        self.splitView.dividerStyle = .thin
        self.splitView.delegate = self
        self.splitView.addSubview(self.hostedViewController.view)
    }


    override func viewDidLayout() {

        super.viewDidLayout()
        self.restoreMarkdownPreviewWidth()
    }


    func splitView(_ splitView: NSSplitView, shouldAdjustSizeOfSubview view: NSView) -> Bool {

        view == self.hostedViewController.view
    }


    func splitView(_ splitView: NSSplitView, didResizeSubviews notification: Notification) {

        self.restoreMarkdownPreviewWidth()
    }


    /// Restores the user-selected width after the split view lays out its reinserted pane.
    private func restoreMarkdownPreviewWidth() {

        guard
            self.showsMarkdownPreview,
            self.splitView.subviews.count > 1,
            let width = self.markdownPreviewWidth
        else { return }

        // Width restoration must follow the split view's reinserted-pane layout.
        self.markdownPreviewWidth = nil
        let availableWidth = max(0, self.splitView.bounds.width - self.splitView.dividerThickness - 200)
        let previewWidth = min(width, availableWidth)
        self.splitView.setPosition(self.splitView.bounds.width - previewWidth, ofDividerAt: 0)
    }


    func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {

        switch item.action {
            case #selector(toggleMarkdownPreview):
                (item as? NSMenuItem)?.state = self.showsMarkdownPreview ? .on : .off
                return self.document is TextDocument
            default:
                return true
        }
    }


    // MARK: Action Messages

    /// Toggles the Markdown preview pane for the current text document.
    @IBAction func toggleMarkdownPreview(_ sender: Any?) {

        self.showsMarkdownPreview.toggle()
    }


    // MARK: Split View Delegate Methods

    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {

        proposedMinimumPosition + 200
    }


    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {

        proposedMaximumPosition - 200
    }


    // MARK: Private Methods

    /// Creates the preview for the current text document if necessary.
    ///
    /// - Returns: A view controller, or `nil` when the document is not text.
    private func makeMarkdownPreviewViewControllerIfNeeded() -> NSViewController? {

        if let viewController = self.markdownPreviewViewController { return viewController }
        guard let document = self.document as? TextDocument else { return nil }

        let model = MarkdownPreviewModel(document: document)
        let viewController = NSHostingController(rootView: MarkdownPreviewView(model: model))
        viewController.sizingOptions = []
        self.markdownPreviewViewController = viewController

        return viewController
    }


    /// Shows or hides the preview without replacing the document view.
    ///
    /// - Parameter isVisible: Whether the preview should be visible.
    private func setMarkdownPreviewVisible(_ isVisible: Bool) {

        guard self.isViewLoaded else { return }

        let previewViewController = isVisible ? self.makeMarkdownPreviewViewControllerIfNeeded() : self.markdownPreviewViewController
        guard
            let previewViewController,
            let model = (previewViewController as? NSHostingController<MarkdownPreviewView>)?.rootView.model
        else {
            self.showsMarkdownPreview = false
            return
        }

        if isVisible {
            model.resume()
            previewViewController.view.frame.size = NSSize(width: self.markdownPreviewWidth ?? self.splitView.bounds.width / 2, height: self.splitView.bounds.height)
            self.addChild(previewViewController)
            self.splitView.addSubview(previewViewController.view)
        } else {
            model.suspend()
            self.markdownPreviewWidth = previewViewController.view.frame.width
            previewViewController.view.removeFromSuperview()
            previewViewController.removeFromParent()
        }

        self.view.layoutSubtreeIfNeeded()
    }


    /// Updates the hosted view controller when the document changes.
    ///
    /// - Parameter oldDocument: The previous document.
    private func updateDocument(from oldDocument: DataDocument?) {

        guard oldDocument != self.document else { return }

        self.removeMarkdownPreview()
        self.hostedViewController.viewIfLoaded?.removeFromSuperview()
        self.hostedViewController.removeFromParent()

        self.hostedViewController = Self.viewController(document: self.document)
        self.addChild(self.hostedViewController)
        self.splitView.addSubview(self.hostedViewController.view, positioned: .below, relativeTo: nil)
    }


    /// Removes the current document's preview before switching documents.
    private func removeMarkdownPreview() {

        guard
            let previewViewController = self.markdownPreviewViewController,
            let model = (previewViewController as? NSHostingController<MarkdownPreviewView>)?.rootView.model
        else { return }

        model.suspend()
        previewViewController.viewIfLoaded?.removeFromSuperview()
        previewViewController.removeFromParent()
        self.markdownPreviewViewController = nil
        self.markdownPreviewWidth = nil
        self.showsMarkdownPreview = false
    }


    /// Creates a new view controller with the passed-in document.
    ///
    /// - Parameter document: The represented document.
    /// - Returns: A view controller.
    private static func viewController(document: DataDocument?) -> NSViewController {

        switch document {
            case let document as TextDocument:
                DocumentViewController(document: document)
            case let document as PreviewDocument:
                Self.hostingController(rootView: FilePreviewView(item: document))
            case .none:
                Self.hostingController(rootView: NoDocumentView())
            default:
                preconditionFailure()
        }
    }


    /// Creates a hosting controller that doesn’t propagate the SwiftUI content’s ideal size to the split view pane layout.
    ///
    /// - Parameter rootView: The SwiftUI view to host.
    /// - Returns: A hosting controller.
    private static func hostingController(rootView: some View) -> NSViewController {

        let controller = NSHostingController(rootView: rootView)
        controller.sizingOptions = []

        return controller
    }
}


private extension NSView {

    /// Adds a subview constrained to fill the receiver.
    ///
    /// - Parameter subview: The subview to embed.
    func embedSubview(_ subview: NSView) {

        subview.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(subview)

        NSLayoutConstraint.activate([
            subview.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            subview.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            subview.topAnchor.constraint(equalTo: self.topAnchor),
            subview.bottomAnchor.constraint(equalTo: self.bottomAnchor),
        ])
    }
}
