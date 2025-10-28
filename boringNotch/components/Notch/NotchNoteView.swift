import SwiftUI

// MARK: - Models

struct Note: Identifiable, Codable {
    let id: Int
    var attributedText: Data? // NSAttributedString encoded as Data
    var plainText: String = ""
    
    init(id: Int) {
        self.id = id
    }
}

// MARK: - Note Manager

class NoteManager: ObservableObject {
    @Published var notes: [Note] = []
    @Published var selectedNoteIndex: Int = 0
    
    private let userDefaults = UserDefaults.standard
    private let notesKey = "savedNotes"
    private let selectedIndexKey = "selectedNoteIndex"
    
    init() {
        loadNotes()
    }
    
    var currentNote: Note {
        get {
            guard selectedNoteIndex < notes.count else {
                return notes[0]
            }
            return notes[selectedNoteIndex]
        }
        set {
            if selectedNoteIndex < notes.count {
                notes[selectedNoteIndex] = newValue
                saveNotes()
            }
        }
    }
    
    func selectNote(at index: Int) {
        guard index < notes.count else { return }
        selectedNoteIndex = index
        userDefaults.set(index, forKey: selectedIndexKey)
    }
    
    private func loadNotes() {
        // Initialize with 7 empty notes if none exist
        if let data = userDefaults.data(forKey: notesKey),
           let decoded = try? JSONDecoder().decode([Note].self, from: data) {
            notes = decoded
        } else {
            notes = (0..<7).map { Note(id: $0) }
        }
        
        selectedNoteIndex = userDefaults.integer(forKey: selectedIndexKey)
        if selectedNoteIndex >= notes.count {
            selectedNoteIndex = 0
        }
    }
    
    func saveNotes() {
        if let encoded = try? JSONEncoder().encode(notes) {
            userDefaults.set(encoded, forKey: notesKey)
        }
    }
}

// MARK: - Main View

struct NotchNoteView: View {
    @EnvironmentObject var vm: BoringViewModel
    @StateObject private var noteManager = NoteManager()
    @State private var shouldFocusEditor: Bool = false
    
    let tabColors: [Color] = [
        Color(red: 1.0, green: 0.27, blue: 0.23),      // Red
        Color(red: 1.0, green: 0.58, blue: 0.0),       // Orange
        Color(red: 1.0, green: 0.8, blue: 0.0),        // Yellow
        Color(red: 0.2, green: 0.78, blue: 0.35),      // Green
        Color(red: 0.0, green: 0.48, blue: 1.0),       // Blue
        Color(red: 0.35, green: 0.34, blue: 0.84),     // Indigo
        Color(red: 0.69, green: 0.32, blue: 0.87)      // Purple
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Top bar with tabs and formatting
            HStack(spacing: 8) {
                // Horizontal tab selector
                HStack(spacing: 6) {
                    ForEach(0..<7) { index in
                        NoteTabButton(
                            color: tabColors[index],
                            isSelected: noteManager.selectedNoteIndex == index,
                            hasContent: !noteManager.notes[index].plainText.isEmpty
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                noteManager.selectNote(at: index)
                            }
                        }
                    }
                }
                
                Divider()
                    .frame(height: 16)
                    .background(Color.white.opacity(0.2))
                
                // Compact formatting toolbar
                HStack(spacing: 8) {
                    FormatButton(icon: "bold", size: .compact) {
                        NotificationCenter.default.post(name: .applyFormatting, object: "bold")
                    }
                    
                    FormatButton(icon: "italic", size: .compact) {
                        NotificationCenter.default.post(name: .applyFormatting, object: "italic")
                    }
                    
                    FormatButton(icon: "underline", size: .compact) {
                        NotificationCenter.default.post(name: .applyFormatting, object: "underline")
                    }
                    
                    FormatButton(icon: "strikethrough", size: .compact) {
                        NotificationCenter.default.post(name: .applyFormatting, object: "strikethrough")
                    }
                    
                    FormatButton(icon: "list.bullet", size: .compact) {
                        NotificationCenter.default.post(name: .applyFormatting, object: "bullet")
                    }
                }
                
                Spacer()
                
                // Character count
                Text("\(noteManager.currentNote.plainText.count)")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.2))
            
            // Scrollable text editor with outline
            RichTextEditor(noteManager: noteManager, shouldFocus: $shouldFocusEditor)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(shouldFocusEditor ? 0.3 : 0.1), lineWidth: 1)
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .frame(minWidth: 300)
        .onAppear {
            // Give focus to the text editor when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                shouldFocusEditor = true
            }
        }
    }
}

// MARK: - Tab Button

struct NoteTabButton: View {
    let color: Color
    let isSelected: Bool
    let hasContent: Bool
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: isSelected ? 20 : 16, height: isSelected ? 20 : 16)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isSelected ? 0.5 : 0), lineWidth: 1.5)
                )
                .overlay(
                    Circle()
                        .fill(Color.white.opacity(hasContent && !isSelected ? 0.4 : 0))
                        .frame(width: 6, height: 6)
                )
                .scaleEffect(isHovering ? 1.15 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Format Button

enum FormatButtonSize {
    case compact
    case regular
}

struct FormatButton: View {
    let icon: String
    let size: FormatButtonSize
    let action: () -> Void
    
    @State private var isHovering = false
    
    private var iconSize: CGFloat {
        size == .compact ? 11 : 13
    }
    
    private var frameSize: CGFloat {
        size == .compact ? 20 : 24
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundColor(isHovering ? .white : .gray)
                .frame(width: frameSize, height: frameSize)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Rich Text Editor

struct RichTextEditor: NSViewRepresentable {
    @ObservedObject var noteManager: NoteManager
    @Binding var shouldFocus: Bool
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.usesFindBar = true
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.textColor = .white
        textView.backgroundColor = .clear
        textView.insertionPointColor = .white
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.textContainerInset = NSSize(width: 8, height: 8)
        
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false // optional: always show
        scrollView.verticalScroller?.alphaValue = 0.8

        
        // Configure text container for proper wrapping
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)
        
        DispatchQueue.main.async {
            if let container = textView.textContainer {
                container.containerSize = NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)
                container.widthTracksTextView = true
            }
        }

        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.scrollerInsets = NSEdgeInsets(top: 2, left: 0, bottom: 2, right: 0)

        // Store reference to textView in coordinator
        context.coordinator.textView = textView
        
        // Load saved content
        if let data = noteManager.currentNote.attributedText,
           let attributedString = try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: NSAttributedString.self, from: data) {
            textView.textStorage?.setAttributedString(attributedString)
        } else {
            textView.string = noteManager.currentNote.plainText
        }
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        // Handle focus state
        if shouldFocus {
            DispatchQueue.main.async {
                if let window = textView.window {
                    window.makeFirstResponder(textView)
                }
            }
        }

        
        // Update content when note selection changes
        if context.coordinator.currentNoteIndex != noteManager.selectedNoteIndex {
            context.coordinator.currentNoteIndex = noteManager.selectedNoteIndex
            
            if let data = noteManager.currentNote.attributedText,
               let attributedString = try? NSKeyedUnarchiver.unarchivedObject(
                ofClass: NSAttributedString.self, from: data) {
                textView.textStorage?.setAttributedString(attributedString)
            } else {
                textView.string = noteManager.currentNote.plainText
            }
            
            // Refocus after content change
            if shouldFocus {
                DispatchQueue.main.async {
                    textView.window?.makeFirstResponder(textView)
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(noteManager: noteManager)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var noteManager: NoteManager
        var currentNoteIndex: Int
        weak var textView: NSTextView?
        
        init(noteManager: NoteManager) {
            self.noteManager = noteManager
            self.currentNoteIndex = noteManager.selectedNoteIndex
            super.init()
            
            // Listen for formatting commands
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(applyFormatting(_:)),
                name: .applyFormatting,
                object: nil
            )
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            // Save both attributed and plain text
            if let attributedString = textView.attributedString() as NSAttributedString?,
               let data = try? NSKeyedArchiver.archivedData(
                withRootObject: attributedString, requiringSecureCoding: false) {
                noteManager.currentNote.attributedText = data
            }
            
            noteManager.currentNote.plainText = textView.string
            noteManager.saveNotes()
        }
        
        @objc func applyFormatting(_ notification: Notification) {
            guard let format = notification.object as? String else { return }
            
            // Use the stored textView reference
            guard let textView = self.textView else { return }
            
            let range = textView.selectedRange()
            guard range.length > 0 else {
                // If no selection, insert bullet point at cursor
                if format == "bullet" {
                    insertBulletPoint(in: textView)
                }
                return
            }
            
            let storage = textView.textStorage!
            
            switch format {
            case "bold":
                storage.applyFontTraits(.boldFontMask, range: range)
            case "italic":
                storage.applyFontTraits(.italicFontMask, range: range)
            case "underline":
                let hasUnderline = storage.attribute(.underlineStyle, at: range.location, effectiveRange: nil) != nil
                if hasUnderline {
                    storage.removeAttribute(.underlineStyle, range: range)
                } else {
                    storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                }
            case "strikethrough":
                let hasStrikethrough = storage.attribute(.strikethroughStyle, at: range.location, effectiveRange: nil) != nil
                if hasStrikethrough {
                    storage.removeAttribute(.strikethroughStyle, range: range)
                } else {
                    storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                }
            case "bullet":
                insertBulletPoint(in: textView)
            default:
                break
            }
        }
        
        private func insertBulletPoint(in textView: NSTextView) {
            let range = textView.selectedRange()
            textView.insertText("• ", replacementRange: range)
        }
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let applyFormatting = Notification.Name("applyFormatting")
}
