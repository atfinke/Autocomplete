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

    @IBOutlet var textView: ArrowTextView!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var freakingAppKit: NSScrollView!

    var suggestions = [Suggestion]()
    var words = [String]()


    override func viewDidLoad() {
        super.viewDidLoad()

        textView.delegate = self

        tableView.delegate = self
        tableView.dataSource = self

        textView.isAutomaticTextCompletionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false

        words = try! String(contentsOfFile: Bundle.main.path(forResource: "20k", ofType: "txt")!).components(separatedBy: "\n")

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

        let bla = (textView.string as NSString).range(of: " ", options: .backwards)

        guard bla.location != NSNotFound, let rect = boundingRectForCharacterRange(range: bla) else {
            return
        }

        guard let lastWord = textView.string.components(separatedBy: " ").last, lastWord.count > 2 else {
            freakingAppKit.isHidden = true
            return
        }

        let lower = lastWord.lowercased()

        var isLow = true

        if let char = lastWord.first,
            let scala = UnicodeScalar(String(describing: char)),
            CharacterSet.uppercaseLetters.contains(scala) {
            isLow = false
        }

        let c = NSColor(calibratedRed: 250.0/255.0, green: 240.0/255.0, blue: 200.0/255.0, alpha: 1.0)
        DispatchQueue.global().async {
            let filteredWords = Array(self.words.filter({ $0.starts(with: lower) }).sorted(by: { (lhs, rhs) -> Bool in
                return lhs.count < rhs.count
            }))

            var newSuggestions = [Suggestion]()

            for word in filteredWords {
                if let def =  DCSCopyTextDefinition(nil, word as CFString, CFRangeMake(0, word.count))?.takeRetainedValue() {
                    let bri = (def as NSString)
                    if bri.range(of: "▶").location != NSNotFound {
                        let aaa = bri.substring(from: bri.range(of: "▶").location + 1) as NSString
                        if aaa.range(of: " ").location != NSNotFound {
                            let ex = aaa.substring(to: aaa.range(of: " ").location)
                            let str = (isLow ? word : word.capitalized)

                            let string = NSMutableAttributedString(string: str)
                            string.beginEditing()
                            string.addAttribute(NSAttributedStringKey.backgroundColor, value: c, range: NSRange(location: 0, length: lower.count))
                            string.addAttribute(NSAttributedStringKey.underlineStyle, value: 1, range: NSRange(location: 0, length: lower.count))
                            string.addAttribute(NSAttributedStringKey.underlineColor, value: NSColor.orange, range: NSRange(location: 0, length: lower.count))
                            string.endEditing()

                            let a = Suggestion(actual: word, display: string, partOfSpeech: ex)
                            newSuggestions.append(a)

                            if newSuggestions.count >= 8 {
                                break
                            }
                        }
                    }
                }


            }

            DispatchQueue.main.async {
                let height: CGFloat = 19.5 * CGFloat(newSuggestions.count)
                self.freakingAppKit.frame = NSRect(x: rect.origin.x - 60, y: self.textView.frame.height - rect.origin.y - height - rect.height - 5, width: 220, height: height)

                self.suggestions = newSuggestions
                self.tableView.reloadData()
                self.tableView.selectRowIndexes(IndexSet(integersIn: 0...0), byExtendingSelection: false)

                self.freakingAppKit.isHidden = false
            }
        }
    }

    func boundingRectForCharacterRange(range: NSRange) -> CGRect? {
        let layoutManager = textView.layoutManager!
        let textContainer = textView.textContainer!

        var glyphRange = NSRange()
        layoutManager.characterRange(forGlyphRange: range, actualGlyphRange: &glyphRange)
        return layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
    }

}
