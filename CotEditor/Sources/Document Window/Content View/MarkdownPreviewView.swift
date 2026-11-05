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

    @State var model: MarkdownPreviewModel


    var body: some View {

        ScrollView {
            StructuredText(markdown: self.model.markdown, baseURL: self.model.baseURL)
                .textual.structuredTextStyle(.gitHub)
                .textual.textSelection(.enabled)
                .textual.imageAttachmentLoader(.image(relativeTo: self.model.baseURL))
                .textual.overflowMode(.wrap)
                .padding()
                .frame(maxWidth: 800)
                .frame(maxWidth: .infinity)
                .containerRelativeFrame(.vertical, alignment: .top)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .accessibilityLabel(String(localized: "Markdown Preview", table: "Document", comment: "accessibility label"))
    }
}


@MainActor @Observable final class MarkdownPreviewModel {

    // MARK: Public Properties

    private(set) var markdown: String
    var baseURL: URL?  { self.document.fileURL?.deletingLastPathComponent() }


    // MARK: Private Properties

    private let document: TextDocument
    @ObservationIgnored private var isSuspended = false
    @ObservationIgnored private lazy var updateDebouncer = Debouncer(delay: .seconds(0.3)) { [weak self] in self?.update() }
    @ObservationIgnored private var textEditingObserver: AnyCancellable?


    // MARK: Lifecycle

    init(document: TextDocument) {

        self.document = document
        self.markdown = document.textStorage.string.immutable

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
    }
}


// MARK: - Preview

#Preview {

    MarkdownPreviewView(model: MarkdownPreviewModel(document: TextDocument()))
}
