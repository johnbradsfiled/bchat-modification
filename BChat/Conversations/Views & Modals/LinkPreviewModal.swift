
final class LinkPreviewModal : Modal {
    private let onLinkPreviewsEnabled: () -> Void

    // MARK: Lifecycle
    init(onLinkPreviewsEnabled: @escaping () -> Void) {
        self.onLinkPreviewsEnabled = onLinkPreviewsEnabled
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        preconditionFailure("Use init(onLinkPreviewsEnabled:) instead.")
    }

    override init(nibName: String?, bundle: Bundle?) {
        preconditionFailure("Use init(onLinkPreviewsEnabled:) instead.")
    }

    override func populateContentView() {
        // Title
        let titleLabel = UILabel()
        titleLabel.textColor = Colors.text
        titleLabel.font = Fonts.boldOpenSans(ofSize: Values.mediumFontSize)
        titleLabel.text = NSLocalizedString("modal_link_previews_title", comment: "")
        titleLabel.textAlignment = .center
        // Message
        let messageLabel = UILabel()
        messageLabel.textColor = Colors.text
        messageLabel.font = Fonts.OpenSans(ofSize: Values.smallFontSize)
        let message = NSLocalizedString("modal_link_previews_explanation", comment: "")
        messageLabel.text = message
        messageLabel.numberOfLines = 0
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.textAlignment = .center
        // Enable button
        let enableButton = UIButton()
        enableButton.set(.height, to: Values.mediumButtonHeight)
        enableButton.layer.cornerRadius = Modal.buttonCornerRadius
        enableButton.backgroundColor = Colors.buttonBackground
        enableButton.titleLabel!.font = Fonts.OpenSans(ofSize: Values.smallFontSize)
        enableButton.setTitleColor(Colors.text, for: UIControl.State.normal)
        enableButton.setTitle(NSLocalizedString("modal_link_previews_button_title", comment: ""), for: UIControl.State.normal)
        enableButton.addTarget(self, action: #selector(enable), for: UIControl.Event.touchUpInside)
        // Button stack view
        let buttonStackView = UIStackView(arrangedSubviews: [ cancelButton, enableButton ])
        buttonStackView.axis = .horizontal
        buttonStackView.spacing = Values.mediumSpacing
        buttonStackView.distribution = .fillEqually
        // Content stack view
        let contentStackView = UIStackView(arrangedSubviews: [ titleLabel, messageLabel ])
        contentStackView.axis = .vertical
        contentStackView.spacing = Values.largeSpacing
        // Main stack view
        let spacing = Values.largeSpacing - Values.smallFontSize / 2
        let mainStackView = UIStackView(arrangedSubviews: [ contentStackView, buttonStackView ])
        mainStackView.axis = .vertical
        mainStackView.spacing = spacing
        contentView.addSubview(mainStackView)
        mainStackView.pin(.leading, to: .leading, of: contentView, withInset: Values.largeSpacing)
        mainStackView.pin(.top, to: .top, of: contentView, withInset: Values.largeSpacing)
        contentView.pin(.trailing, to: .trailing, of: mainStackView, withInset: Values.largeSpacing)
        contentView.pin(.bottom, to: .bottom, of: mainStackView, withInset: spacing)
    }

    // MARK: Interaction
    @objc private func enable() {
        SSKPreferences.areLinkPreviewsEnabled = true
        presentingViewController?.dismiss(animated: true, completion: nil)
        onLinkPreviewsEnabled()
    }
}
