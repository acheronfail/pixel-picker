//
//  SequenceViewController.swift
//  Apptivator
//

let SEQUENCE_DETAIL_NO_SHORTCUT = "There must be at least one shortcut in a sequence."
let SEQUENCE_DETAIL_TEXT = """
To use a seqeunce, press the first shortcut (and release it), then press the next, and so on, until \
you activate the application.
"""

enum UIStates {
    case Okay
    case NoShortcuts
    case ConflictingShortcuts
}

class SequenceViewController: NSViewController {
    // View animation lifecycle hooks.
    var beforeAdded: (() -> Void)?
    var afterAdded: (() -> Void)?
    var beforeRemoved: (() -> Void)?
    var afterRemoved: (() -> Void)?

    var referenceView: NSView!
    var defaultTextColor: NSColor!

    var list: [(MASShortcutView, NSKeyValueObservation)] = []
    var listAsSequence: [MASShortcutView] {
        // Filter out any nil values.
        get { return list.compactMap({ $0.0.shortcutValue != nil ? $0.0 : nil }) }
    }
    var entry: ApplicationEntry! {
        // Copy the entry's sequence.
        didSet {
            list = entry.sequence.map({
                newShortcut(withKeyCode: $0.shortcutValue.keyCode, modifierFlags: $0.shortcutValue.modifierFlags)
            })
            list.append(newShortcut(withKeyCode: nil, modifierFlags: nil))
        }
    }

    @IBOutlet weak var titleTextField: NSTextField!
    @IBOutlet weak var detailTextField: NSTextField!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var saveButton: NSButton!
    
    @IBAction func closeButtonClick(_ sender: Any) { slideOutAndRemove() }
    @IBAction func saveButtonClick(_ sender: Any) {
        let sequence = listAsSequence

        // This is a sanity check: the save button should never be enabled without a valid sequence.
        assert(sequence.count > 0, "sequence.count must be > 0.")

        if ApplicationState.shared.checkForConflictingSequence(sequence, excluding: self.entry) == nil {
            entry.sequence = sequence
            slideOutAndRemove()
        } else {
            assertionFailure("Tried to save with a conflicting sequence.")
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self

        imageView.image = entry.icon

        titleTextField.stringValue = entry.name
        detailTextField.stringValue = SEQUENCE_DETAIL_TEXT
        defaultTextColor = detailTextField.textColor

        updateList(self)
    }

    // This should be the only way to create shortcuts to add to the editable list. Each shortcut is
    // paired with its recordingWatcher, so that we don't accidentally fire any other shortcuts when
    // the user is configuring these shortcuts.
    func newShortcut(withKeyCode keyCode: UInt?, modifierFlags: UInt?) -> (MASShortcutView, NSKeyValueObservation) {
        let view = MASShortcutView()
        if keyCode != nil && modifierFlags != nil {
            view.shortcutValue = MASShortcut(keyCode: keyCode!, modifierFlags: modifierFlags!)
        }
        view.shortcutValueChange = updateList
        let watcher = view.observe(\.isRecording, changeHandler: ApplicationState.shared.onRecordingChange)
        return (view, watcher)
    }

    // Whenever a shortcut's value changes, update the list.
    func updateList(_ sender: Any?) {
        // Remove nil entries from list (except last).
        for (i, _) in list.enumerated().reversed() {
            if list.count > 1 && list[i].0.shortcutValue == nil {
                let _ = list.remove(at: i)
            }
        }

        // Ensure there's always one more shortcut at the end of the list.
        if list.last?.0.shortcutValue != nil && list.count < ApplicationState.shared.defaults.integer(forKey: "maxShortcutsInSequence") {
            list.append(newShortcut(withKeyCode: nil, modifierFlags: nil))
        }

        // Check for any conflicting entries.
        let sequence = listAsSequence
        if sequence.count == 0 {
            updateUIWith(reason: .NoShortcuts, nil)
        } else {
            if let conflictingEntry = ApplicationState.shared.checkForConflictingSequence(sequence, excluding: entry) {
                updateUIWith(reason: .ConflictingShortcuts, conflictingEntry)
            } else {
                updateUIWith(reason: .Okay, nil)
            }
        }

        tableView.reloadData()
    }

    // Update the view with information regarding a conflicting entry. Entries' sequences conflict
    // when you cannot fully type sequence A without first calling sequence B (this makes it
    // impossible to call sequence A, and is therefore forbidden).
    func updateUIWith(reason: UIStates, _ conflictingEntry: ApplicationEntry?) {
        switch reason {
        case .ConflictingShortcuts:
            assert(conflictingEntry != nil, "conflictingEntry must be != nil")
            saveButton.isEnabled = false
            detailTextField.textColor = .red

            let boldAttribute = [NSAttributedStringKey.font: NSFont.boldSystemFont(ofSize: 11)]
            let attrString = NSMutableAttributedString(string: "Current sequence conflicts with:\n")
            attrString.append(NSAttributedString(string: conflictingEntry!.name, attributes: boldAttribute))
            attrString.append(NSAttributedString(string: ", which has the sequence:\n"))
            attrString.append(NSAttributedString(string: conflictingEntry!.shortcutString!, attributes: boldAttribute))
            detailTextField.attributedStringValue = attrString
        case .NoShortcuts:
            saveButton.isEnabled = false
            detailTextField.textColor = .red
            detailTextField.stringValue = SEQUENCE_DETAIL_NO_SHORTCUT
        case .Okay:
            saveButton.isEnabled = true
            detailTextField.textColor = defaultTextColor
            detailTextField.stringValue = SEQUENCE_DETAIL_TEXT
        }
    }

    // Animate entering the view, making it the size of `referenceView` and sliding over the top
    // of it.
    func slideInAndAdd(to referringView: NSView) {
        beforeAdded?()
        referenceView = referringView
        self.view.alphaValue = 0.0
        self.view.frame.size = referenceView.frame.size
        self.view.frame.origin = CGPoint(x: referenceView.frame.maxX, y: referenceView.frame.minY)
        referenceView.superview!.addSubview(self.view)
        runAnimation({ _ in
            self.view.animator().frame.origin = referenceView.frame.origin
            self.view.animator().alphaValue = 1.0
        }, done: {
            self.afterAdded?()
        })
    }

    func slideOutAndRemove() {
        beforeRemoved?()
        let destination = CGPoint(x: referenceView.frame.maxX, y: referenceView.frame.minY)
        runAnimation({ _ in
            self.view.animator().frame.origin = destination
            self.view.animator().alphaValue = 0.0
        }, done: {
            self.view.removeFromSuperview()
            self.afterRemoved?()
        })
    }
}

extension SequenceViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        return list[row].0
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return false
    }
}

extension SequenceViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return list.count
    }
}
