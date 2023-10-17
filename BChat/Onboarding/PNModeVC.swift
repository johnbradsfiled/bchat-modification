import PromiseKit

final class PNModeVC : BaseVC, OptionViewDelegate {

    private var optionViews: [OptionView] {
        [ apnsOptionView, backgroundPollingOptionView ]
    }

    private var selectedOptionView: OptionView? {
        return optionViews.first { $0.isSelected }
    }

    // MARK: Components
    private lazy var apnsOptionView: OptionView = {
        let explanation = NSLocalizedString("fast_mode_explanation", comment: "")
        let result = OptionView(title: "Fast Mode", explanation: explanation, delegate: self, isRecommended: true)
        result.accessibilityLabel = "Fast mode option"
        return result
    }()
    
    private lazy var backgroundPollingOptionView: OptionView = {
        let explanation = NSLocalizedString("slow_mode_explanation", comment: "")
        let result = OptionView(title: "Slow Mode", explanation: explanation, delegate: self)
        result.accessibilityLabel = "Slow mode option"
        return result
    }()

    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpGradientBackground()
        setUpNavBarStyle()
        setUpNavBarSessionIcon()
        let learnMoreButton = UIBarButtonItem(image: #imageLiteral(resourceName: "ic_info"), style: .plain, target: self, action: #selector(learnMore))
        learnMoreButton.tintColor = Colors.text
        navigationItem.rightBarButtonItem = learnMoreButton
        // Set up title label
        let titleLabel = UILabel()
        titleLabel.textColor = Colors.text
        titleLabel.font = Fonts.boldOpenSans(ofSize: isIPhone5OrSmaller ? Values.largeFontSize : Values.veryLargeFontSize)
        titleLabel.text = NSLocalizedString("vc_pn_mode_title", comment: "")
        titleLabel.numberOfLines = 0
        titleLabel.lineBreakMode = .byWordWrapping
        // Set up spacers
        let topSpacer = UIView.vStretchingSpacer()
        let bottomSpacer = UIView.vStretchingSpacer()
        let registerButtonBottomOffsetSpacer = UIView()
        registerButtonBottomOffsetSpacer.set(.height, to: Values.onboardingButtonBottomOffset)
        // Set up register button
        let registerButton = Button(style: .prominentFilled, size: .large)
        registerButton.setTitle(NSLocalizedString("continue_2", comment: ""), for: UIControl.State.normal)
        registerButton.titleLabel!.font = Fonts.boldOpenSans(ofSize: Values.mediumFontSize)
        registerButton.addTarget(self, action: #selector(register), for: UIControl.Event.touchUpInside)
        // Set up register button container
        let registerButtonContainer = UIView(wrapping: registerButton, withInsets: UIEdgeInsets(top: 0, leading: Values.massiveSpacing, bottom: 0, trailing: Values.massiveSpacing), shouldAdaptForIPadWithWidth: Values.iPadButtonWidth)
        // Set up options stack view
        let optionsStackView = UIStackView(arrangedSubviews: optionViews)
        optionsStackView.axis = .vertical
        optionsStackView.spacing = Values.smallSpacing
        optionsStackView.alignment = .fill
        // Set up top stack view
        let topStackView = UIStackView(arrangedSubviews: [ titleLabel, UIView.spacer(withHeight: isIPhone6OrSmaller ? Values.mediumSpacing : Values.veryLargeSpacing), optionsStackView ])
        topStackView.axis = .vertical
        topStackView.alignment = .fill
        // Set up top stack view container
        let topStackViewContainer = UIView(wrapping: topStackView, withInsets: UIEdgeInsets(top: 0, leading: Values.veryLargeSpacing, bottom: 0, trailing: Values.veryLargeSpacing))
        // Set up main stack view
        let mainStackView = UIStackView(arrangedSubviews: [ topSpacer, topStackViewContainer, bottomSpacer, registerButtonContainer, registerButtonBottomOffsetSpacer ])
        mainStackView.axis = .vertical
        mainStackView.alignment = .fill
        view.addSubview(mainStackView)
        mainStackView.pin(to: view)
        topSpacer.heightAnchor.constraint(equalTo: bottomSpacer.heightAnchor, multiplier: 1).isActive = true
        // Preselect APNs mode
        optionViews[0].isSelected = true
    }

    // MARK: Interaction
    @objc private func learnMore() {
        let urlAsString = ""
        let url = URL(string: urlAsString)!
        UIApplication.shared.open(url)
    }

    func optionViewDidActivate(_ optionView: OptionView) {
        optionViews.filter { $0 != optionView }.forEach { $0.isSelected = false }
    }

    @objc private func register() {
        guard selectedOptionView != nil else {
            let title = NSLocalizedString("vc_pn_mode_no_option_picked_modal_title", comment: "")
            let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("BUTTON_OK", comment: ""), style: .default, handler: nil))
            return presentAlert(alert)
        }
        UserDefaults.standard[.isUsingFullAPNs] = (selectedOptionView == apnsOptionView)
        TSAccountManager.sharedInstance().didRegister()
        let homeVC = HomeVC()
        navigationController!.setViewControllers([ homeVC ], animated: true)
        let syncTokensJob = SyncPushTokensJob(accountManager: AppEnvironment.shared.accountManager, preferences: Environment.shared.preferences)
        syncTokensJob.uploadOnlyIfStale = false
        let _: Promise<Void> = syncTokensJob.run()
    }
}
