import BChatMessagingKit

final class BlockedModal: Modal {
    private let publicKey: String
    
    // MARK: Lifecycle
    init(publicKey: String) {
        self.publicKey = publicKey
        super.init(nibName: nil, bundle: nil)
    }
    
    override init(nibName: String?, bundle: Bundle?) {
        preconditionFailure("Use init(publicKey:) instead.")
    }
    
    required init?(coder: NSCoder) {
        preconditionFailure("Use init(publicKey:) instead.")
    }
    
    override func populateContentView() {
        // Name
        let name = Storage.shared.getContact(with: publicKey)?.displayName(for: .regular) ?? publicKey
        // Title
        let titleLabel = UILabel()
        titleLabel.textColor = Colors.text
        titleLabel.font = Fonts.boldOpenSans(ofSize: Values.mediumFontSize)
        titleLabel.text = String(format: NSLocalizedString("modal_blocked_title", comment: ""), name)
        titleLabel.textAlignment = .center
        // Message
        let messageLabel = UILabel()
        messageLabel.textColor = Colors.text
        messageLabel.font = Fonts.OpenSans(ofSize: Values.smallFontSize)
        let message = String(format: NSLocalizedString("modal_blocked_explanation", comment: ""), name)
        let attributedMessage = NSMutableAttributedString(string: message)
        attributedMessage.addAttributes([ .font : Fonts.boldOpenSans(ofSize: Values.smallFontSize) ], range: (message as NSString).range(of: name))
        messageLabel.attributedText = attributedMessage
        messageLabel.numberOfLines = 0
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.textAlignment = .center
        // Unblock button
        let unblockButton = UIButton()
        unblockButton.set(.height, to: Values.mediumButtonHeight)
        unblockButton.layer.cornerRadius = Modal.buttonCornerRadius
        if isDarkMode {
            unblockButton.backgroundColor = Colors.bchatJoinOpenGpBackgroundGreen
            unblockButton.setTitleColor(UIColor.white, for: UIControl.State.normal)
        }else{
            unblockButton.backgroundColor = Colors.bchatJoinOpenGpBackgroundGreen
            unblockButton.setTitleColor(UIColor.white, for: UIControl.State.normal)
        }
        unblockButton.titleLabel!.font = Fonts.OpenSans(ofSize: Values.smallFontSize)
        unblockButton.setTitle(NSLocalizedString("modal_blocked_button_title", comment: ""), for: UIControl.State.normal)
        unblockButton.addTarget(self, action: #selector(unblock), for: UIControl.Event.touchUpInside)
        // Button stack view
        let buttonStackView = UIStackView(arrangedSubviews: [ cancelButton, unblockButton ])
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
    @objc private func unblock() {
//        let publicKey: String = self.publicKey
//
//        Storage.shared.write(
//            with: { transaction in
//                guard let transaction = transaction as? YapDatabaseReadWriteTransaction, let contact: Contact = Storage.shared.getContact(with: publicKey, using: transaction) else {
//                    return
//                }
//
//                contact.isBlocked = false
//                Storage.shared.setContact(contact, using: transaction as Any)
//            },
//            completion: {
//                MessageSender.syncConfiguration(forceSyncNow: true).retainUntilComplete()
//            }
//        )
//
//        presentingViewController?.dismiss(animated: true, completion: nil)
        
        if let contact: Contact = Storage.shared.getContact(with: publicKey) {
            Storage.shared.write(
                with: { transaction in
                    guard let transaction = transaction as? YapDatabaseReadWriteTransaction else { return }
                    contact.isBlocked = false
                    Storage.shared.setContact(contact, using: transaction)
                },
                completion: {
                    MessageSender.syncConfiguration(forceSyncNow: true).retainUntilComplete()
                }
            )
            presentingViewController?.dismiss(animated: true, completion: nil)
        }
    }
}
