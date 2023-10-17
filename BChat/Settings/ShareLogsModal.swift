import SignalUtilitiesKit

final class ShareLogsModal : Modal {
    
    // MARK: Lifecycle
    init() {
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
        titleLabel.text = NSLocalizedString("modal_share_logs_title", comment: "")
        titleLabel.textAlignment = .center
        // Message
        let messageLabel = UILabel()
        messageLabel.textColor = Colors.text.withAlphaComponent(Values.mediumOpacity)
        messageLabel.font = Fonts.OpenSans(ofSize: Values.smallFontSize)
        messageLabel.text = NSLocalizedString("modal_share_logs_explanation", comment: "")
        messageLabel.numberOfLines = 0
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.textAlignment = .center
        // Open button
        let shareButton = UIButton()
        shareButton.set(.height, to: Values.mediumButtonHeight)
        shareButton.layer.cornerRadius = Modal.buttonCornerRadius
        shareButton.backgroundColor = Colors.buttonBackground
        shareButton.titleLabel!.font = Fonts.OpenSans(ofSize: Values.smallFontSize)
        shareButton.setTitleColor(Colors.text, for: UIControl.State.normal)
        shareButton.setTitle(NSLocalizedString("share", comment: ""), for: UIControl.State.normal)
        shareButton.addTarget(self, action: #selector(shareLogs), for: UIControl.Event.touchUpInside)
        // Button stack view
        let buttonStackView = UIStackView(arrangedSubviews: [ cancelButton, shareButton ])
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
    @objc private func shareLogs() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        OWSLogger.info("[Version] iOS \(UIDevice.current.systemVersion) \(version)")
        DDLog.flushLog()
        let logFilePaths = AppEnvironment.shared.fileLogger.logFileManager.sortedLogFilePaths
        if let latestLogFilePath = logFilePaths.first {
            let latestLogFileURL = URL(fileURLWithPath: latestLogFilePath)
            self.dismiss(animated: true, completion: {
                if let vc = CurrentAppContext().frontmostViewController() {
                    let shareVC = UIActivityViewController(activityItems: [ latestLogFileURL ], applicationActivities: nil)
                    if UIDevice.current.isIPad {
                        shareVC.excludedActivityTypes = []
                        shareVC.popoverPresentationController?.permittedArrowDirections = []
                        shareVC.popoverPresentationController?.sourceView = vc.view
                        shareVC.popoverPresentationController?.sourceRect = vc.view.bounds
                    }
                    vc.present(shareVC, animated: true, completion: nil)
                }
            })
        }
    }
}
