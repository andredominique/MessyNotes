//
//  ContentView.swift
//  Messy Notes
//
//  Created by andre&dominique on 17/9/2025.
//

import SwiftUI

import Combine


struct Note: Identifiable, Codable {
    var id: UUID = UUID()
    var rawText: String = ""
    var structured: StructuredNote = StructuredNote()
    var tags: [String] = []
    var dateCreated: Date = Date()
    var dateModified: Date = Date()
}

struct StructuredNote: Codable {
    var ideas: [String] = []
    var decisions: [String] = []
    var questions: [String] = []
    var actions: [String] = []
    var summary: String? = nil
}


struct ContentView: View {
    @State private var note = Note()
    @State private var savedNotes: [Note] = [] {
        didSet {
            saveNotesToDisk()
        }
    }
    @State private var selectedLens: String? = nil
    @State private var newTag: String = ""
    @State private var searchTag: String = ""
    @State private var selectedHistoryNote: Note? = nil

    @State private var cancellable: AnyCancellable? = nil
    @State private var isLoadingAI: Bool = false
    @State private var lastRawText: String = ""

    // Replace with your actual OpenAI API key
    let openAIKey = "YOUR_OPENAI_API_KEY"

    let lenses = ["Summary", "Client Email", "Creative Direction"]

    var body: some View {
        NavigationSplitView {
            // History view
            VStack {
                HStack {
                    TextField("Search tags...", text: $searchTag)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Clear") { searchTag = "" }
                }
                .padding(.horizontal)
                List(savedNotes.filter { searchTag.isEmpty || $0.tags.contains(searchTag) }) { note in
                    Button(action: { selectedHistoryNote = note }) {
                        VStack(alignment: .leading) {
                            Text(note.rawText)
                                .lineLimit(1)
                            Text(note.tags.joined(separator: ", "))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                if let selected = selectedHistoryNote {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Restore Note")
                            .font(.headline)
                        Text(selected.rawText)
                            .font(.body)
                        Text("Tags: \(selected.tags.joined(separator: ", "))")
                            .font(.caption)
                        Button("Restore") {
                            note = selected
                            selectedHistoryNote = nil
                        }
                        Button("Dismiss") {
                            selectedHistoryNote = nil
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("History")
        } detail: {
            HSplitView {
                // Editor
                VStack(alignment: .leading, spacing: 12) {
                    Text("Editor")
                        .font(.headline)
                    TextEditor(text: $note.rawText)
                        .border(Color.gray.opacity(0.2))
                        .frame(minHeight: 200)
                    if isLoadingAI {
                        ProgressView("Organizing with AI...")
                    }
                    HStack {
                        TextField("Add tag", text: $newTag)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button("Tag") {
                            let tag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !tag.isEmpty && !note.tags.contains(tag) {
                                note.tags.append(tag)
                                newTag = ""
                            }
                        }
                        Button("Keep") {
                            note.dateModified = Date()
                            savedNotes.append(note)
                            note = Note()
                        }
                        Button("Refresh AI") {
                            classifyTextWithAI()
                        }
                    }
                }
                .frame(minWidth: 300)

                // Organizer pane
                VStack(alignment: .leading, spacing: 12) {
                    Text("Organizer")
                        .font(.headline)
                    ForEach([("Ideas", note.structured.ideas),
                             ("Decisions", note.structured.decisions),
                             ("Questions", note.structured.questions),
                             ("Actions", note.structured.actions)], id: \ .0) { category, items in
                        Section(header: Text(category).font(.subheadline)) {
                            ForEach(items, id: \ .self) { item in
                                Text(item)
                                    .padding(4)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                    }
                    Divider()
                    Text("Lenses")
                        .font(.subheadline)
                    HStack {
                        ForEach(lenses, id: \ .self) { lens in
                            Button(lens) {
                                selectedLens = lens
                                // Future: trigger lens transformation
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    if let lens = selectedLens {
                        Text("Lens: \(lens)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Divider()
                    Text("Summary: \(note.structured.summary ?? "")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Divider()
                    Text("Export")
                        .font(.subheadline)
                    HStack {
                        Button("Markdown") { exportMarkdown(note) }
                        Button("DOCX") { /* TODO: Implement DOCX export */ }
                        Button("PDF") { /* TODO: Implement PDF export */ }
                        Button("Clipboard") { copyToClipboard(note) }
                    }
                }
                .frame(minWidth: 300)
            }
            .padding()
        }
    }

    // Call this function to classify text using GPT
    func classifyTextWithAI() {
        guard !note.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isLoadingAI = true
        let prompt = "Classify the following text into ideas, decisions, questions, actions, and summary as JSON: \n\(note.rawText)"
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 512
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        cancellable = URLSession.shared.dataTaskPublisher(for: request)
            .map { $0.data }
            .decode(type: OpenAIResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                isLoadingAI = false
                if case .failure(let error) = completion {
                    print("AI error: \(error)")
                }
            }, receiveValue: { response in
                if let jsonString = response.choices.first?.message.content,
                   let jsonData = jsonString.data(using: .utf8),
                   let structured = try? JSONDecoder().decode(StructuredNote.self, from: jsonData) {
                    note.structured = structured
                }
            })
    }

    // Poll for changes every 6 seconds
    func startAIPolling() {
        Timer.scheduledTimer(withTimeInterval: 6.0, repeats: true) { _ in
            if note.rawText != lastRawText {
                lastRawText = note.rawText
                classifyTextWithAI()
            }
        }
    }

    // MARK: - Export Functions

    func exportMarkdown(_ note: Note) {
        let md = markdownString(for: note)
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["md"]
        panel.nameFieldStringValue = "MessyNote.md"
        if panel.runModal() == .OK, let url = panel.url {
            try? md.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    func markdownString(for note: Note) -> String {
        var md = "# Messy Note\n\n"
        md += "**Created:** \(note.dateCreated)\n\n"
        md += "**Tags:** \(note.tags.joined(separator: ", "))\n\n"
        md += "## Raw Text\n\(note.rawText)\n\n"
        md += "## Organizer\n"
        md += "- **Ideas:** \n  " + note.structured.ideas.joined(separator: "\n  ") + "\n"
        md += "- **Decisions:** \n  " + note.structured.decisions.joined(separator: "\n  ") + "\n"
        md += "- **Questions:** \n  " + note.structured.questions.joined(separator: "\n  ") + "\n"
        md += "- **Actions:** \n  " + note.structured.actions.joined(separator: "\n  ") + "\n"
        md += "## Summary\n\(note.structured.summary ?? "")\n"
        return md
    }

    func copyToClipboard(_ note: Note) {
        let md = markdownString(for: note)
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(md, forType: .string)
        #endif
    }

    // OpenAI API response structs
    struct OpenAIResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String
            }
            let message: Message
        }
        let choices: [Choice]
    }

    // Start polling when view appears
    init() {
        loadNotesFromDisk()
        startAIPolling()
    }

    // MARK: - Persistence
    func notesFileURL() -> URL {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MessyNotes", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("notes.json")
    }

    func saveNotesToDisk() {
        let url = notesFileURL()
        if let data = try? JSONEncoder().encode(savedNotes) {
            try? data.write(to: url)
        }
    }

    func loadNotesFromDisk() {
        let url = notesFileURL()
        if let data = try? Data(contentsOf: url),
           let notes = try? JSONDecoder().decode([Note].self, from: data) {
            savedNotes = notes
        }
    }
}

#Preview {
    ContentView()
}
