import SwiftUI
import AppKit

// MARK: - Clipboard Item Model
struct ClipboardItem: Identifiable, Equatable {
    let id = UUID()
    let content: ClipboardContent
    let timestamp: Date
    let preview: String
    
    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
    }
}

enum ClipboardContent: Equatable {
    case text(String)
    case image(NSImage)
    case url(URL)
    case file(URL)
    
    var icon: String {
        switch self {
        case .text: return "doc.text"
        case .image: return "photo"
        case .url: return "link"
        case .file: return "doc"
        }
    }
}

// MARK: - Clipboard Manager
class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()
    
    @Published var items: [ClipboardItem] = []
    @Published var isMonitoring = false
    
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let maxItems = 20
    
    private init() {
        lastChangeCount = NSPasteboard.general.changeCount
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    func stopMonitoring() {
        isMonitoring = false
        timer?.invalidate()
        timer = nil
    }
    
    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        
        if let content = extractContent(from: pasteboard) {
            let newItem = ClipboardItem(
                content: content,
                timestamp: Date(),
                preview: generatePreview(for: content)
            )
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.items.insert(newItem, at: 0)
                
                if self.items.count > self.maxItems {
                    self.items = Array(self.items.prefix(self.maxItems))
                }
            }
        }
    }
    
    private func extractContent(from pasteboard: NSPasteboard) -> ClipboardContent? {
        // Check for image first
        if let image = pasteboard.readObjects(forClasses: [NSImage.self])?.first as? NSImage {
            return .image(image)
        }
        
        // Check for URL
        if let url = pasteboard.readObjects(forClasses: [NSURL.self])?.first as? URL {
            if url.isFileURL {
                return .file(url)
            } else {
                return .url(url)
            }
        }
        
        // Check for text
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            return .text(string)
        }
        
        return nil
    }
    
    private func generatePreview(for content: ClipboardContent) -> String {
        switch content {
        case .text(let string):
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return String(trimmed.prefix(100))
        case .image:
            return "Image"
        case .url(let url):
            return url.absoluteString
        case .file(let url):
            return url.lastPathComponent
        }
    }
    
    func copyItem(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        switch item.content {
        case .text(let string):
            pasteboard.setString(string, forType: .string)
        case .image(let image):
            pasteboard.writeObjects([image])
        case .url(let url), .file(let url):
            pasteboard.writeObjects([url as NSURL])
        }
    }
    
    func deleteItem(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
    }
    
    func clearHistory() {
        items.removeAll()
    }
}
struct NotchClipView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var clipboardManager = ClipboardManager.shared
    
    var body: some View {
        HStack {
            panel
        }
        .onAppear {
            clipboardManager.startMonitoring()
        }
        .onDisappear {
            clipboardManager.stopMonitoring()
        }
    }
    
    var panel: some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(style: StrokeStyle(lineWidth: 4, dash: [10]))
            .foregroundStyle(.white.opacity(0.1))
            .overlay {
                content
                    .padding()
            }
            .animation(vm.animation, value: clipboardManager.items.count)
    }
    
    var content: some View {
        Group {
            if clipboardManager.items.isEmpty {
                emptyState
            } else {
                clipboardList
            }
        }
    }
    
    var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.on.clipboard")
                .symbolVariant(.fill)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white, .gray)
                .imageScale(.large)
            
            Text("No clipboard history")
                .foregroundStyle(.gray)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.medium)
        }
    }
    
    var clipboardList: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(clipboardManager.items) { item in
                        ClipboardItemRow(item: item)
                    }
                }
                .padding(.top, 8)
            }
            .scrollIndicators(.never)
        }
    }
    
    var header: some View {
        HStack {
            Text("Clipboard History")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)
            
            Spacer()
            
            Text("\(clipboardManager.items.count)")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.gray)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.white.opacity(0.1))
                .clipShape(Capsule())
            
            Button(action: {
                clipboardManager.clearHistory()
            }) {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
                    .imageScale(.small)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.bottom, 8)
    }
}

struct ClipboardItemRow: View {
    let item: ClipboardItem
    @ObservedObject var clipboardManager = ClipboardManager.shared
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            icon
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.preview)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                
                Text(timeAgo(from: item.timestamp))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.gray)
            }
            
            Spacer()
            
            if isHovering {
                HStack(spacing: 8) {
                    Button(action: {
                        clipboardManager.copyItem(item)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .foregroundStyle(.white)
                            .imageScale(.small)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        withAnimation {
                            clipboardManager.deleteItem(item)
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .imageScale(.small)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? .white.opacity(0.1) : .clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            clipboardManager.copyItem(item)
        }
    }
    
    var icon: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.1))
                .frame(width: 40, height: 40)
            
            Group {
                if case .image(let nsImage) = item.content {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                } else {
                    Image(systemName: item.content.icon)
                        .foregroundStyle(.white)
                        .imageScale(.medium)
                }
            }
        }
    }
    
    func timeAgo(from date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        
        if seconds < 60 {
            return "Just now"
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            return "\(minutes)m ago"
        } else if seconds < 86400 {
            let hours = Int(seconds / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(seconds / 86400)
            return "\(days)d ago"
        }
    }
}

// MARK: - Preview
struct NotchClipView_Previews: PreviewProvider {
    static var previews: some View {
        NotchClipView()
            .environmentObject(BoringViewModel())
            .frame(width: 400, height: 300)
            .background(.black)
    }
}
