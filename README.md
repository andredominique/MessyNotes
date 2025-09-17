# 📝 Messy Notes

Messy Notes is a lightweight macOS app for quick, spontaneous note-taking that organizes your messy thoughts into structured categories in real-time. It’s built in **SwiftUI** with GPT integration.

---

## ✨ Features

- **Distraction-free editor**: Type freely in a clean, plain-text editor.
- **Live organization pane**: Side panel that sorts your words into:
  - Ideas
  - Decisions
  - Questions
  - Actions
- **Lenses**: On-demand perspectives
  - Summary
  - Client Email
  - Creative Direction
- **Save & history**:
  - Keep only the outputs you want
  - Tag and filter saved notes
  - Restore previous notes easily
- **Export options**:
  - Copy to clipboard
  - Export as Markdown, DOCX, or PDF
  - (Optional) Send to Apple Notes or Notion

---

## 🧠 AI Integration

- Uses GPT via API to classify text into structured JSON:
  ```json
  {
    "ideas": [],
    "decisions": [],
    "questions": [],
    "actions": [],
    "summary": ""
  }
  ```
- Only sends text *diffs* to keep calls efficient.
- Updates occur every 5–7 seconds or on manual refresh (⌘L).
- User edits (dragging cards between categories) are respected.

---

## 🗂 Data Model

```swift
struct Note: Identifiable, Codable {
    var id: UUID
    var rawText: String
    var structured: StructuredNote
    var tags: [String]
    var dateCreated: Date
    var dateModified: Date
}

struct StructuredNote: Codable {
    var ideas: [String]
    var decisions: [String]
    var questions: [String]
    var actions: [String]
    var summary: String?
}
```

---

## 🖥 UI Layout

- **Split view**:
  - Left: Text editor
  - Right: Organizer pane (cards under categories + lens buttons)
- **History view (⌘Y)**:
  - List of saved notes
  - Search and filter by tags
  - Open to restore note + structure

---

## ⚙️ Tech Stack

- Language: **Swift 5**
- Framework: **SwiftUI + Combine**
- Storage: CoreData or JSON in Application Support directory
- AI: OpenAI GPT API (pluggable)
- Export: SwiftMarkdown, PDFKit

---

## 🚀 Example Workflow

1. User types:  
   *“Client wants video shoot at F23, 9–2pm, with breakout sessions. Ask about vendor stands. Vox pops after panel.”*  
2. Organizer pane updates:  
   - Ideas: “Vox pops after panel”  
   - Decisions: “Video shoot at F23, 9–2pm”  
   - Questions: “Will they have vendor stands?”  
   - Actions: —  
3. User hits **Summary lens** →  
   *“USYD event: panel + breakout sessions, video shoot, confirm vendor stands, include vox pops.”*  
4. Press **Keep** → saved with tags “USYD, video shoot”.  
5. Export to Markdown and paste into project doc.

---

## 🧭 Guiding Principle

Messy Notes is designed to **support typing first**. Writing helps learning and memory. AI only provides structure and clarity — it never replaces the act of taking notes.
