import AppKit
import Carbon.HIToolbox
import ServiceManagement

// MARK: - Hotkey globale (Carbon: non richiede permessi di Accessibilità)

final class HotKey {
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void

    init(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        self.action = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let me = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { me.action() }
            return noErr
        }, 1, &spec, selfPtr, &handler)
        let id = EventHotKeyID(signature: OSType(0x434C5052), id: 1) // 'CLPR'
        RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &ref)
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        if let handler { RemoveEventHandler(handler) }
    }
}

// MARK: - Stampa

enum ClipboardPrinter {
    /// Testo della clipboard: preferisce RTF (mantiene la formattazione), poi testo semplice.
    static func clipboardContent() -> NSAttributedString? {
        let pb = NSPasteboard.general
        // Tabelle copiate da web, Numbers, Excel, Fogli: arrivano come testo separato da tab
        if let text = pb.string(forType: .string), let rows = parseTable(text) {
            return makeTable(rows)
        }
        if let rtf = pb.data(forType: .rtf),
           let attr = NSAttributedString(rtf: rtf, documentAttributes: nil),
           !attr.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return attr
        }
        if let text = pb.string(forType: .string),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return NSAttributedString(string: text, attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.black,
            ])
        }
        return nil
    }

    /// pdfURL != nil: salva in PDF senza dialogo (per verifiche: ClipPrint --pdf out.pdf)
    static func printClipboard(pdfURL: URL? = nil) {
        guard let content = clipboardContent() else {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "Nessun testo negli appunti"
            alert.informativeText = "Copia del testo e riprova."
            alert.runModal()
            return
        }

        let info = NSPrintInfo.shared.copy() as! NSPrintInfo
        info.paperName = NSPrinter.PaperName("A4")
        info.paperSize = NSSize(width: 595.28, height: 841.89) // A4 in punti
        let margin: CGFloat = 56 // ~2 cm
        info.topMargin = margin
        info.bottomMargin = margin
        info.leftMargin = margin
        info.rightMargin = margin
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        info.isHorizontallyCentered = false
        info.isVerticallyCentered = false

        let width = info.paperSize.width - info.leftMargin - info.rightMargin
        // TextKit 1: TextKit 2 non supporta NSTextTable
        let textView = NSTextView(usingTextLayoutManager: false)
        textView.frame = NSRect(x: 0, y: 0, width: width, height: 1)
        textView.isEditable = false
        textView.drawsBackground = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textStorage?.setAttributedString(forPrinting(content))
        textView.isVerticallyResizable = true
        textView.sizeToFit()

        NSApp.activate(ignoringOtherApps: true)
        let op = NSPrintOperation(view: textView, printInfo: info)
        op.jobTitle = "Appunti"
        if let pdfURL {
            op.printInfo.jobDisposition = .save
            op.printInfo.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = pdfURL
            op.showsPrintPanel = false
            op.showsProgressPanel = false
            op.run()
            return
        }
        op.showsPrintPanel = true
        op.showsProgressPanel = true
        op.printPanel.options.insert([.showsCopies, .showsPageRange, .showsPreview, .showsPaperSize, .showsOrientation])
        op.run()
    }

    /// Riconosce testo tabellare: almeno 2 righe, tutte con lo stesso numero (≥2) di colonne separate da tab.
    static func parseTable(_ text: String) -> [[String]]? {
        let lines = text
            .components(separatedBy: "\n")
            .map { $0.hasSuffix("\r") ? String($0.dropLast()) : $0 }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard lines.count >= 2 else { return nil }
        let rows = lines.map { $0.components(separatedBy: "\t").map { $0.trimmingCharacters(in: .whitespaces) } }
        let cols = rows[0].count
        guard cols >= 2, rows.allSatisfy({ $0.count == cols }) else { return nil }
        return rows
    }

    /// Costruisce una tabella vera (NSTextTable) con bordi; la prima riga è l'intestazione.
    static func makeTable(_ rows: [[String]]) -> NSAttributedString {
        let cols = rows[0].count
        let table = NSTextTable()
        table.numberOfColumns = cols
        table.layoutAlgorithm = .fixedLayoutAlgorithm
        table.collapsesBorders = true
        table.setContentWidth(100, type: .percentageValueType)

        // Larghezza colonne proporzionale al contenuto (con minimo e massimo)
        // (abbastanza larghe da non spezzare la parola più lunga della colonna)
        let weights: [CGFloat] = (0..<cols).map { c in
            let longest = rows.map { $0[c].count }.max() ?? 0
            let longestWord = rows.flatMap { $0[c].split(separator: " ") }.map(\.count).max() ?? 0
            return CGFloat(max(min(longest, 45), longestWord + 3, 4))
        }
        let total = weights.reduce(0, +)

        let border = NSColor(white: 0.55, alpha: 1)
        let headerBg = NSColor(white: 0.9, alpha: 1)
        let body = NSFont.systemFont(ofSize: 10.5)
        let bold = NSFont.boldSystemFont(ofSize: 10.5)

        let result = NSMutableAttributedString()
        for (r, row) in rows.enumerated() {
            for (c, cell) in row.enumerated() {
                let block = NSTextTableBlock(table: table, startingRow: r, rowSpan: 1, startingColumn: c, columnSpan: 1)
                block.setValue(weights[c] / total * 100, type: .percentageValueType, for: .width)
                block.setWidth(0.5, type: .absoluteValueType, for: .border)
                block.setBorderColor(border)
                block.setWidth(5, type: .absoluteValueType, for: .padding)
                block.verticalAlignment = .topAlignment
                if r == 0 { block.backgroundColor = headerBg }

                let para = NSMutableParagraphStyle()
                para.textBlocks = [block]
                result.append(NSAttributedString(string: cell + "\n", attributes: [
                    .font: r == 0 ? bold : body,
                    .paragraphStyle: para,
                ]))
            }
        }
        return result
    }

    /// Forza testo nero e niente sfondo (evita testo bianco copiato da app in dark mode).
    private static func forPrinting(_ s: NSAttributedString) -> NSAttributedString {
        let m = NSMutableAttributedString(attributedString: s)
        let all = NSRange(location: 0, length: m.length)
        m.removeAttribute(.backgroundColor, range: all)
        m.addAttribute(.foregroundColor, value: NSColor.black, range: all)
        return m
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var hotKey: HotKey?
    private let previewItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Avvia al login", action: #selector(toggleLogin), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "printer", accessibilityDescription: "ClipPrint")

        let menu = NSMenu()
        menu.delegate = self
        let printItem = NSMenuItem(title: "Stampa appunti…", action: #selector(printNow), keyEquivalent: "p")
        printItem.keyEquivalentModifierMask = [.control, .option, .command]
        printItem.target = self
        menu.addItem(printItem)
        previewItem.isEnabled = false
        menu.addItem(previewItem)
        menu.addItem(.separator())
        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Esci", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        // ⌃⌥⌘P
        hotKey = HotKey(keyCode: UInt32(kVK_ANSI_P),
                        modifiers: UInt32(controlKey | optionKey | cmdKey)) { ClipboardPrinter.printClipboard() }
    }

    func menuWillOpen(_ menu: NSMenu) {
        if let text = ClipboardPrinter.clipboardContent()?.string {
            let oneLine = text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
            previewItem.title = "“" + (oneLine.count > 40 ? String(oneLine.prefix(40)) + "…" : oneLine) + "”"
        } else {
            previewItem.title = "Appunti vuoti"
        }
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func printNow() {
        // Lascia chiudere il menu prima di aprire il pannello di stampa
        DispatchQueue.main.async { ClipboardPrinter.printClipboard() }
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }
}

if let i = CommandLine.arguments.firstIndex(of: "--pdf"), i + 1 < CommandLine.arguments.count {
    _ = NSApplication.shared
    ClipboardPrinter.printClipboard(pdfURL: URL(fileURLWithPath: CommandLine.arguments[i + 1]))
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
