//
//  MarkdownPreviewView.swift
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

import SwiftUI
import Combine
import StringUtils
import Textual

struct MarkdownPreviewView: View {

    private struct ContentIdentity: Hashable {

        let markdown: String
        let baseURL: URL?
    }


    @State var model: MarkdownPreviewModel

    @State private var contentHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0


    var body: some View {

        let verticalPadding: CGFloat = 32

        ScrollView {
            StructuredText(markdown: self.model.markdown, baseURL: self.model.baseURL)
                .id(ContentIdentity(markdown: self.model.markdown, baseURL: self.model.baseURL))  // Reparse source and base URL changes.
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self, of: \.size.height) { height in
                    // Textual's table layout can grow after its initial scroll-view measurement.
                    self.contentHeight = height
                }
                .textual.structuredTextStyle(.gitHub)
                .textual.textSelection(.enabled)
                .textual.imageAttachmentLoader(MarkdownPreviewAttachmentLoader(baseURL: self.model.baseURL))
                .textual.overflowMode(.wrap)
                .padding()
                .frame(maxWidth: 800, alignment: .leading)
                .frame(maxWidth: .infinity, minHeight: max(self.viewportHeight, self.contentHeight + verticalPadding), alignment: .topLeading)
        }
        .onGeometryChange(for: CGFloat.self, of: \.size.height) { height in
            self.viewportHeight = height
        }
        .background(Color(nsColor: .textBackgroundColor))
        .accessibilityLabel(String(localized: "Markdown Preview", table: "Document", comment: "accessibility label"))
    }
}


struct MarkdownPreviewAttachmentLoader: AttachmentLoader {

    let baseURL: URL?

    private let loader: any AttachmentLoader = .image()


    func attachment(for url: URL, text: String, environment: ColorEnvironmentValues) async throws -> AnyAttachment {

        let imageURL = try await self.resolvedURL(for: url)
        let attachment = try await self.loader.attachment(for: imageURL, text: text, environment: environment)

        return AnyAttachment(attachment as any Textual.Attachment)
    }


    /// Resolves an image URL and requests user-approved access when the sandbox requires it.
    func resolvedURL(for url: URL) async throws -> URL {

        let imageURL = (URL(string: url.absoluteString, relativeTo: self.baseURL) ?? url).absoluteURL
        guard imageURL.isFileURL, (try? imageURL.isReadable) != true else { return imageURL }

        return try await Self.grantAccess(to: imageURL)
    }


    /// Returns an image URL based on the user-approved containing directory.
    @MainActor private static func grantAccess(to imageURL: URL) throws -> URL {

        var directoryURL = imageURL.deletingLastPathComponent()
        try directoryURL.grantAccess(isDirectory: true)

        return directoryURL.appending(component: imageURL.lastPathComponent)
    }
}


@MainActor @Observable final class MarkdownPreviewModel {

    // MARK: Public Properties

    private(set) var markdown: String
    private(set) var baseURL: URL?


    // MARK: Private Properties

    private let document: TextDocument
    @ObservationIgnored private var isSuspended = false
    @ObservationIgnored private lazy var updateDebouncer = Debouncer(delay: .seconds(0.3)) { [weak self] in self?.update() }
    @ObservationIgnored private var textEditingObserver: AnyCancellable?
    @ObservationIgnored private var fileURLObserver: AnyCancellable?


    // MARK: Lifecycle

    init(document: TextDocument) {

        self.document = document
        self.markdown = document.textStorage.string.immutable
        self.baseURL = document.fileURL?.deletingLastPathComponent()

        self.fileURLObserver = document.publisher(for: \.fileURL)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] fileURL in
                self?.baseURL = fileURL?.deletingLastPathComponent()
            }

        self.textEditingObserver = NotificationCenter.default.publisher(for: NSTextStorage.didProcessEditingNotification, object: document.textStorage)
            .map { $0.object as! NSTextStorage }
            .filter { $0.editedMask.contains(.editedCharacters) }
            .sink { [weak self] _ in
                guard let self, !self.isSuspended else { return }

                self.updateDebouncer.schedule()
            }
    }


    isolated deinit {
        self.updateDebouncer.cancel()
    }


    // MARK: Public Methods

    /// Stops updating the content while the preview is hidden.
    func suspend() {

        self.isSuspended = true
        self.updateDebouncer.cancel()
    }


    /// Resumes observing edits and displays the current content.
    func resume() {

        self.isSuspended = false
        self.update()
    }


    // MARK: Private Methods

    /// Takes an immutable copy of the document text for rendering.
    private func update() {

        self.markdown = self.document.textStorage.string.immutable
        self.baseURL = self.document.fileURL?.deletingLastPathComponent()
    }
}


// MARK: - Preview

#Preview {

    MarkdownPreviewView(model: MarkdownPreviewModel(document: TextDocument()))
}
