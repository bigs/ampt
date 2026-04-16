//
//  ShaderLibraryView.swift
//  ampt
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct ShaderLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Shader.dateCreated) private var shaders: [Shader]
    let compilationState: ShaderCompilationState

    @State private var selectedShaderID: PersistentIdentifier?
    @State private var fileWatcher = ShaderFileWatcher()
    @State private var editingShaderID: PersistentIdentifier?

    private var selectedShader: Shader? {
        guard let id = selectedShaderID else { return nil }
        return shaders.first { $0.persistentModelID == id }
    }

    var body: some View {
        NavigationSplitView {
            shaderList
        } detail: {
            if let shader = selectedShader {
                shaderDetail(shader)
            } else {
                ContentUnavailableView("No Shader Selected", systemImage: "waveform")
            }
        }
        .navigationTitle("Shader Library")
        .toolbar {
            ToolbarItem {
                Button("Choose Editor", systemImage: "app.dashed") {
                    pickEditor()
                }
            }
            ToolbarItem {
                Button("New Shader", systemImage: "plus") {
                    newShader()
                }
            }
        }
    }

    // MARK: - Shader List

    private var shaderList: some View {
        List(selection: $selectedShaderID) {
            ForEach(shaders) { shader in
                HStack {
                    Image(systemName: shader.isActive ? "circle.fill" : "circle")
                        .foregroundStyle(shader.isActive ? .green : .secondary)
                        .font(.caption)
                    Text(shader.title)
                        .lineLimit(1)
                }
                .tag(shader.persistentModelID)
                .contextMenu {
                    Button("Activate") { activateShader(shader) }
                    Divider()
                    Button("Delete", role: .destructive) { deleteShader(shader) }
                }
            }
        }
    }

    // MARK: - Shader Detail

    private func shaderDetail(_ shader: Shader) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            TextField("Title", text: Binding(
                get: { shader.title },
                set: { shader.title = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .font(.headline)

            // Source editor
            TextEditor(text: Binding(
                get: { shader.source },
                set: { shader.source = $0 }
            ))
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(.background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Compilation error
            if let error = compilationState.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(3)
                    .textSelection(.enabled)
            }

            // Actions
            HStack {
                if !shader.isActive {
                    Button("Activate") { activateShader(shader) }
                } else {
                    Text("Active")
                        .foregroundStyle(.green)
                        .font(.callout.weight(.medium))
                }

                Spacer()

                if fileWatcher.isWatching && editingShaderID == shader.persistentModelID {
                    Button("Done Editing") {
                        fileWatcher.stopWatching()
                        editingShaderID = nil
                    }
                } else {
                    Button("Open in Editor") {
                        openInExternalEditor(shader)
                    }
                    .disabled(preferredEditorURL == nil && !canPickEditor)
                }

                Button("Delete", role: .destructive) { deleteShader(shader) }
                    .disabled(shaders.count <= 1)
            }
        }
        .padding()
    }

    // MARK: - Actions

    private func activateShader(_ shader: Shader) {
        for s in shaders { s.isActive = false }
        shader.isActive = true
    }

    private func newShader() {
        let shader = Shader(title: "New Shader", source: Shader.newShaderTemplate)
        modelContext.insert(shader)
        selectedShaderID = shader.persistentModelID
    }

    private func deleteShader(_ shader: Shader) {
        guard shaders.count > 1 else { return }
        let wasActive = shader.isActive
        if editingShaderID == shader.persistentModelID {
            fileWatcher.stopWatching()
            editingShaderID = nil
        }
        modelContext.delete(shader)
        if wasActive, let first = shaders.first(where: { $0.persistentModelID != shader.persistentModelID }) {
            first.isActive = true
        }
        selectedShaderID = nil
    }

    // MARK: - External Editor

    private var canPickEditor: Bool { true }

    private var preferredEditorURL: URL? {
        UserDefaults.standard.url(forKey: "preferredShaderEditor")
    }

    private func pickEditor() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            UserDefaults.standard.set(url, forKey: "preferredShaderEditor")
        }
    }

    private func openInExternalEditor(_ shader: Shader) {
        guard let editorURL = preferredEditorURL else {
            pickEditor()
            guard preferredEditorURL != nil else { return }
            openInExternalEditor(shader)
            return
        }

        // Write source to temp file
        let tempDir = NSTemporaryDirectory()
        let fileName = "ampt-shader-\(shader.title.replacingOccurrences(of: " ", with: "-")).metal"
        let filePath = (tempDir as NSString).appendingPathComponent(fileName)

        do {
            try shader.source.write(toFile: filePath, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to write temp shader file: \(error)")
            return
        }

        // Open in editor
        let fileURL = URL(fileURLWithPath: filePath)
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([fileURL], withApplicationAt: editorURL, configuration: config)

        // Watch for changes
        editingShaderID = shader.persistentModelID
        fileWatcher.watch(fileAt: filePath) { newSource in
            shader.source = newSource
        }
    }
}
