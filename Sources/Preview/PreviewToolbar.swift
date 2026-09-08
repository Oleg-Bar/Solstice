import AppKit

final class PreviewToolbar: NSView {
    static let preferredSize = NSSize(width: 190,height: 36)
    var onAddCity: (() -> Void)?
    var onRemoveCity: (() -> Void)?
    private let addButton = NSButton()
    private let removeButton = NSButton()
    private let progress = NSProgressIndicator()
    var isSearching = false {
        didSet {
            addButton.isEnabled = !isSearching
            isSearching ? progress.startAnimation(nil) : progress.stopAnimation(nil)
            progress.isHidden = !isSearching
        }
    }
    var canRemoveCity = false { didSet { removeButton.isEnabled = canRemoveCity } }

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        addButton.title = "Добавить город"
        addButton.font = .systemFont(ofSize: NSFont.systemFontSize(for: .small),weight: .regular)
        addButton.image = NSImage(systemSymbolName: "plus",accessibilityDescription: nil)
        addButton.imagePosition = .imageLeading
        addButton.imageHugsTitle = true
        addButton.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 10,weight: .regular)
        addButton.controlSize = .small
        addButton.isBordered = true
        if #available(macOS 26.0, *) {
            addButton.bezelStyle = .glass
        } else {
            addButton.bezelStyle = .accessoryBarAction
        }
        addButton.contentTintColor = .secondaryLabelColor
        addButton.target = self; addButton.action = #selector(addCity)

        removeButton.image = NSImage(systemSymbolName: "minus",accessibilityDescription: "Удалить город")
        removeButton.imagePosition = .imageOnly
        removeButton.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 10,weight: .regular)
        removeButton.controlSize = .small
        removeButton.isBordered = true
        removeButton.bezelStyle = .accessoryBarAction
        removeButton.contentTintColor = .tertiaryLabelColor
        removeButton.toolTip = "Удалить добавленный город"
        removeButton.isEnabled = false
        removeButton.target = self; removeButton.action = #selector(removeCity)

        progress.style = .spinning; progress.controlSize = .small; progress.isHidden = true
        let stack = NSStackView(views: [addButton,removeButton,progress])
        stack.orientation = .horizontal; stack.alignment = .centerY; stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false; addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor,constant: 13),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor,constant: -13),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    required init?(coder: NSCoder) { nil }
    @objc private func addCity() { onAddCity?() }
    @objc private func removeCity() { onRemoveCity?() }
}
