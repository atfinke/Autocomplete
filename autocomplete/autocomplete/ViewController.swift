//
//  ViewController.swift
//  autocomplete
//
//  Created by Andrew Finke on 3/11/18.
//  Copyright © 2018 Andrew Finke. All rights reserved.
//



// ==================
// No one should ever look at this file and think anything below is the right way to do anything.
// ==================

import Cocoa
import CoreServices

class ArrowTextView: NSTextView {
    override func keyDown(with event: NSEvent) {
        super.keyDown(with: event)
        if Int(event.keyCode) == 126 {
            NotificationCenter.default.post(name: Notification.Name("up"), object: nil)
        } else if Int(event.keyCode) == 125 {
            NotificationCenter.default.post(name: Notification.Name("down"), object: nil)
        }
    }
}

struct Suggestion {
    let actual: String
    let display: NSAttributedString
    let partOfSpeech: String
}

class ViewController: NSViewController, NSTextViewDelegate, NSTableViewDataSource, NSTableViewDelegate  {

    // MARK: - Properties

    @IBOutlet var textView: ArrowTextView!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var tableViewScrollView: NSScrollView!

    var suggestions = [Suggestion]()

    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        textView.delegate = self

        tableView.delegate = self
        tableView.dataSource = self

        self.tableViewScrollView.wantsLayer = true
        self.tableViewScrollView.layer!.cornerRadius = 6;

        textView.isAutomaticTextCompletionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false

        NotificationCenter.default.addObserver(forName: Notification.Name("up"), object: nil, queue: nil) { _ in
            let currentIndex = self.tableView.selectedRow
            let newIndex = max(0, currentIndex - 1)
            self.tableView.selectRowIndexes(IndexSet(integersIn: newIndex...newIndex), byExtendingSelection: false)
        }

        NotificationCenter.default.addObserver(forName: Notification.Name("down"), object: nil, queue: nil) { _ in
            let currentIndex = self.tableView.selectedRow
            let newIndex = min(self.suggestions.count - 1, currentIndex + 1)
            self.tableView.selectRowIndexes(IndexSet(integersIn: newIndex...newIndex), byExtendingSelection: false)
        }
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        return suggestions.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: (tableColumn!.identifier), owner: self) as? NSTableCellView
        if tableColumn == tableView.tableColumns[0] {
            cell?.textField?.stringValue = suggestions[row].partOfSpeech
        } else if tableColumn == tableView.tableColumns[1] {
            cell?.textField?.attributedStringValue = suggestions[row].display
        }
        return cell
    }

    // MARK: - NSTextViewDelegate

    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        if replacementString == "\n" {
            var words = textView.string.components(separatedBy: " ")
            words.removeLast()
            textView.string = words.joined(separator: " ") + " " + suggestions[tableView.selectedRow].actual + " "
            textDidChange(Notification(name: .NSAppleEventManagerWillProcessFirstEvent))
            return false
        } else {
            return true
        }
    }

    func textDidChange(_ notification: Notification) {
        let lastSpace = (textView.string as NSString).range(of: " ", options: .backwards)
        guard lastSpace.location != NSNotFound,
            let layoutManager = textView.layoutManager,
            let textContainer = textView.textContainer else {
                return
        }

        var glyphRange = NSRange()
        layoutManager.characterRange(forGlyphRange: lastSpace, actualGlyphRange: &glyphRange)
        let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

        guard let lastWord = textView.string.components(separatedBy: " ").last, lastWord.count > 2 else {
            tableViewScrollView.isHidden = true
            return
        }
        let lower = lastWord.lowercased()

        let backgroundColor = NSColor(calibratedRed: 250.0/255.0,
                                      green: 240.0/255.0,
                                      blue: 200.0/255.0,
                                      alpha: 1.0)

        DispatchQueue.global().async {
            let completions = NSSpellChecker.shared.completions(forPartialWordRange: NSRange(location: lastSpace.location + 1, length: lower.count), in: self.textView.string, language: nil, inSpellDocumentWithTag: 0) ?? []

            var newSuggestions = [Suggestion]()
            for word in completions {

                if let fullDefinition = DCSCopyTextDefinition(nil, word as CFString, CFRangeMake(0, word.count))?.takeRetainedValue() {

                    let definitions = (fullDefinition as String).components(separatedBy: "|")
                    if definitions.count > 2 {
                        let firstDefinitionParts = definitions[2].components(separatedBy: " ")
                        if firstDefinitionParts.count > 1 {
                            let relevantRange = NSRange(location: 0, length: lower.count)

                            let string = NSMutableAttributedString(string: word)
                            string.beginEditing()
                            string.addAttribute(.backgroundColor, value: backgroundColor, range: relevantRange)
                            string.addAttribute(.underlineStyle, value: 1, range: relevantRange)
                            string.addAttribute(.underlineColor, value: NSColor.orange, range: relevantRange)
                            string.endEditing()

                            let suggestion = Suggestion(actual: word,
                                                        display: string,
                                                        partOfSpeech: firstDefinitionParts[1])
                            newSuggestions.append(suggestion)

                            if newSuggestions.count >= 8 {
                                break
                            }
                        }
                    }
                }
            }

            DispatchQueue.main.async {
                let height: CGFloat = 19.5 * CGFloat(newSuggestions.count)
                self.tableViewScrollView.frame = NSRect(x: rect.origin.x - 60, y: self.textView.frame.height - rect.origin.y - height - rect.height - 5, width: 220, height: height)

                self.suggestions = newSuggestions
                self.tableView.reloadData()
                self.tableView.selectRowIndexes(IndexSet(integersIn: 0...0), byExtendingSelection: false)

                self.tableViewScrollView.isHidden = false
            }
        }
    }


}
