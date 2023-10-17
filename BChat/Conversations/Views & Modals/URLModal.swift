
final class URLModal : Modal {
    private let url: URL
    
    // MARK: Lifecycle
    init(url: URL) {
        self.url = url
        super.init(nibName: nil, bundle: nil)
    }
    
    override init(nibName: String?, bundle: Bundle?) {
        preconditionFailure("Use init(url:) instead.")
    }
    
    required init?(coder: NSCoder) {
        preconditionFailure("Use init(url:) instead.")
    }
    
    override func populateContentView() {
        // Title
        let titleLabel = UILabel()
        titleLabel.textColor = Colors.text
        titleLabel.font = Fonts.boldOpenSans(ofSize: Values.mediumFontSize)
        titleLabel.text = NSLocalizedString("modal_open_url_title", comment: "")
        titleLabel.textAlignment = .center
        // Message
        let messageLabel = UILabel()
        messageLabel.textColor = Colors.text
        messageLabel.font = Fonts.OpenSans(ofSize: Values.smallFontSize)
        let message = String(format: NSLocalizedString("modal_open_url_explanation", comment: ""), url.absoluteString)
        let attributedMessage = NSMutableAttributedString(string: message)
        attributedMessage.addAttributes([ .font : Fonts.boldOpenSans(ofSize: Values.smallFontSize) ], range: (message as NSString).range(of: url.absoluteString))
        messageLabel.attributedText = attributedMessage
        messageLabel.numberOfLines = 0
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.textAlignment = .center
        // Open button
        let openButton = UIButton()
        openButton.set(.height, to: Values.mediumButtonHeight)
        openButton.layer.cornerRadius = Modal.buttonCornerRadius
        openButton.backgroundColor = Colors.buttonBackground
        openButton.titleLabel!.font = Fonts.OpenSans(ofSize: Values.smallFontSize)
        openButton.setTitleColor(Colors.text, for: UIControl.State.normal)
        openButton.setTitle(NSLocalizedString("modal_open_url_button_title", comment: ""), for: UIControl.State.normal)
        openButton.addTarget(self, action: #selector(openURL), for: UIControl.Event.touchUpInside)
        // Button stack view
        let buttonStackView = UIStackView(arrangedSubviews: [ cancelButton, openButton ])
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
    @objc private func openURL() {
        let url = self.url
        presentingViewController?.dismiss(animated: true, completion: {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        })
    }
}
