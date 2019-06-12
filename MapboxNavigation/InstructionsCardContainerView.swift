import UIKit
import MapboxDirections
import MapboxCoreNavigation

/**
 The `InstructionsCardContainerViewDelegate` protocol defines a method that allows an object to customize presented visual instructions within the instructions container view.
 */

@objc(MBInstructionsCardContainerViewDelegate)
public protocol InstructionsCardContainerViewDelegate: VisualInstructionDelegate {
    /**
     Called when the Primary Label will present a visual instruction.
     
     - parameter primaryLabel: The custom primary label that the instruction will be presented on.
     - parameter instruction: the `VisualInstruction` that will be presented.
     - parameter presented: the formatted string that is provided by the instruction presenter
     - returns: optionally, a customized NSAttributedString that will be presented instead of the default, or if nil, the default behavior will be used.
     */
    @objc(primaryLabel:willPresentVisualInstruction:asAttributedString:)
    optional func primaryLabel(_ primaryLabel: InstructionLabel, willPresent instruction: VisualInstruction, as presented: NSAttributedString) -> NSAttributedString?
    
    /**
     Called when the Secondary Label will present a visual instruction.
     
     - parameter secondaryLabel: The custom secondary label that the instruction will be presented on.
     - parameter instruction: the `VisualInstruction` that will be presented.
     - parameter presented: the formatted string that is provided by the instruction presenter
     - returns: optionally, a customized NSAttributedString that will be presented instead of the default, or if nil, the default behavior will be used.
     */
    @objc(secondaryLabel:willPresentVisualInstruction:asAttributedString:)
    optional func secondaryLabel(_ secondaryLabel: InstructionLabel, willPresent instruction: VisualInstruction, as presented: NSAttributedString) -> NSAttributedString?
}

/// :nodoc:
@objc(MBInstructionsCardContainerView)
public class InstructionsCardContainerView: UIView {
    
    lazy var informationStackView = UIStackView(orientation: .vertical, autoLayout: true)
    
    lazy var instructionsCardView: InstructionsCardView = {
        let cardView: InstructionsCardView = InstructionsCardView()
        cardView.translatesAutoresizingMaskIntoConstraints = true
        return cardView
    }()
    
    lazy var lanesView: LanesView = .forAutoLayout(hidden: true)
    lazy var nextBannerView: NextBannerView = .forAutoLayout(hidden: true)
    
    private var informationChildren: [UIView] {
        return [instructionsCardView] + secondaryChildren
    }
    
    private var secondaryChildren: [UIView] {
        return [lanesView, nextBannerView]
    }
    
    public weak var delegate: InstructionsCardContainerViewDelegate?
    
    private var gradientLayer: CAGradientLayer!
    private (set) var style: InstructionsCardStyle!
    private (set) var step: RouteStep!
    
    required public init(style: InstructionsCardStyle? = DayInstructionsCardStyle()) {
        super.init(frame: .zero)
        self.style = style
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }
    
    public func prepareLayout(for style: InstructionsCardStyle) {
        commonInit()
        instructionsCardView.prepareLayout(for: style)
    }
    
    public func updateBackgroundColor(highlightEnabled: Bool) {
        if highlightEnabled {
            highlightContainerView()
        } else {
            prepareLayout()
        }
    }
    
    func commonInit() {
        addStackConstraints()
        setupInformationStackView()
        prepareLayout()
        
        instructionsCardView.primaryLabel.instructionDelegate = self
        instructionsCardView.secondaryLabel.instructionDelegate = self
    }
    
    private func addStackConstraints() {
        addSubview(informationStackView)
        
        let top = informationStackView.topAnchor.constraint(equalTo: self.topAnchor)
        let leading = informationStackView.leadingAnchor.constraint(equalTo: self.leadingAnchor)
        let trailing = informationStackView.trailingAnchor.constraint(equalTo: self.trailingAnchor)
        let bottom = bottomAnchor.constraint(equalTo: informationStackView.bottomAnchor)
        
        NSLayoutConstraint.activate([top, leading, trailing, bottom])
    }
    
    private func setupInformationStackView() {
        informationStackView.insertArrangedSubview(instructionsCardView, at: 0)
        informationStackView.addArrangedSubviews(secondaryChildren)
    }
    
    private func prepareLayout() {
        instructionsCardView.prepareLayout()
        
        setGradientLayer(for: self)
        setGradientLayer(for: lanesView)
        setGradientLayer(for: nextBannerView)
        
        layer.cornerRadius = style.cornerRadius
        layer.masksToBounds = true
    }
    
    @discardableResult private func setGradientLayer(for view: UIView) -> UIView {
        guard !view.isHidden else { return view }
        
        let backgroundColor = instructionsCardView.style.backgroundColor
        let alphaComponent = InstructionsCardConstants.backgroundColorAlphaComponent
        let colors = [backgroundColor.cgColor, backgroundColor.withAlphaComponent(alphaComponent).cgColor]

        let requiresGradient = (gradientLayer(for: view) == nil)
        
        if requiresGradient {
            let gradientLayer = CAGradientLayer()
            view.layer.insertSublayer(gradientLayer, at: 0)
        }
        
        if let gradientLayer = view.layer.sublayers?.first as? CAGradientLayer {
            gradientLayer.frame = bounds
            gradientLayer.colors = colors
        }
        
        if let nextBannerView = view as? NextBannerView {
            let style = instructionsCardView.style
            nextBannerView.maneuverView.primaryColor = style.nextBannerViewPrimaryColor
            nextBannerView.maneuverView.secondaryColor = style.nextBannerViewSecondaryColor
            nextBannerView.instructionLabel.normalTextColor = style.nextBannerInstructionLabelTextColor
            nextBannerView.instructionLabel.normalFont = style.nextBannerInstructionLabelNormalFont
            nextBannerView.instructionLabel.shieldHeight = style.nextBannerInstructionLabelNormalFont.pointSize
        }
        
        if let lanesView = view as? LanesView, let stackView = lanesView.subviews.first as? UIStackView {
            let style = instructionsCardView.style
            let laneViews: [LaneView] = stackView.subviews.compactMap { $0 as? LaneView }
            laneViews.forEach { laneView in
                guard laneView.isValid else { return }
                laneView.primaryColor = style.lanesViewDefaultColor
                laneView.secondaryColor = style.lanesViewDefaultColor
            }
        }
        
        view.layoutIfNeeded()
        
        return view
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
    }
    
    private func gradientLayer(for view: UIView, with colors:[CGColor]? = nil) -> CAGradientLayer? {
        guard !view.isHidden, let sublayers = view.layer.sublayers,
              let firstLayer = sublayers.first as? CAGradientLayer,
              let layerColors = firstLayer.colors as? [CGColor], layerColors.count == 2 else {
            return nil
        }
        
        if let colors = colors {
            let colorsMatched = layerColors.reduce(false) { $0 || colors.contains($1) }
            return colorsMatched ? firstLayer : nil
        }
        
        return firstLayer
    }
    
    public func updateInstruction(for step: RouteStep, distance: CLLocationDistance, previewEnabled: Bool = false) {
        instructionsCardView.updateDistanceFromCurrentLocation(distance)
        instructionsCardView.step = step
        
        // TODO: Merge Instructions Card, Lanes & Next Banner View Instructions
        guard let instruction = step.instructionsDisplayedAlongStep?.last else { return }
        updateInstruction(instruction, previewEnabled: previewEnabled)
    }
    
    public func updateInstruction(_ instruction: VisualInstructionBanner, previewEnabled: Bool = false) {
        if lanesView.isHidden {
            lanesView.update(for: instruction)
        } else if lanesView.isCurrentlyVisible && instruction.tertiaryInstruction == nil {
            lanesView.hide()
        }
        
        if nextBannerView.isHidden {
            nextBannerView.update(for: instruction)
            nextBannerView.instructionDelegate = self
        } else if nextBannerView.isCurrentlyVisible && instruction.tertiaryInstruction?.text == nil {
            nextBannerView.hide()
        }
        
        if !previewEnabled, let distance = instructionsCardView.distanceFromCurrentLocation {
            let highlightEnabled = distance < InstructionsCardConstants.highlightDistance
            updateBackgroundColor(highlightEnabled: highlightEnabled)
        } else {
            updateBackgroundColor(highlightEnabled: false)
        }
    }
    
    func highlightContainerView() {
        let duration = InstructionsCardConstants.highlightAnimationDuration
        let style = instructionsCardView.style
        let alphaComponent = InstructionsCardConstants.highlightedBackgroundAlphaComponent
        
        let colors = [style.highlightedBackgroundColor.cgColor,
                      style.highlightedBackgroundColor.withAlphaComponent(alphaComponent).cgColor]
        
        let containerGradientLayer = gradientLayer(for: self)
        var lanesViewGradientLayer = gradientLayer(for: lanesView)
        var nextBannerGradientLayer = gradientLayer(for: nextBannerView)
        
        if lanesView.isCurrentlyVisible && lanesViewGradientLayer == nil {
            let view = setGradientLayer(for: lanesView)
            lanesViewGradientLayer = view.layer.sublayers?.first as? CAGradientLayer
        }
        
        if nextBannerView.isCurrentlyVisible && nextBannerGradientLayer == nil {
            let view = setGradientLayer(for: nextBannerView)
            nextBannerGradientLayer = view.layer.sublayers?.first as? CAGradientLayer
        }
        
        UIView.animate(withDuration: duration, animations: {
            if let lanesViewGradientLayer = lanesViewGradientLayer {
                self.highlightLanesView(lanesViewGradientLayer, colors: colors)
            }
            
            if let nextBannerGradientLayer = nextBannerGradientLayer {
                self.hightlightNextBannerView(nextBannerGradientLayer, colors: colors)
            }
            
            if let containerGradientLayer = containerGradientLayer {
                containerGradientLayer.colors = colors
            }
            
            self.highlightInstructionsCardView(colors: colors)
        })
    }
    
    fileprivate func highlightLanesView(_ gradientLayer: CAGradientLayer, colors: [CGColor]) {
        gradientLayer.colors = colors
        guard let stackView = lanesView.subviews.first as? UIStackView  else {
            return
        }
        let style = self.instructionsCardView.style
        let laneViews: [LaneView] = stackView.subviews.compactMap { $0 as? LaneView }
        laneViews.forEach { laneView in
            guard laneView.isValid else { return }
            laneView.primaryColor = style.lanesViewHighlightedColor
            laneView.secondaryColor = style.lanesViewHighlightedColor
        }
    }
    
    fileprivate func hightlightNextBannerView(_ gradientLayer: CAGradientLayer, colors: [CGColor]) {
        gradientLayer.colors = colors
        let style = instructionsCardView.style
        nextBannerView.maneuverView.primaryColor = style.nextBannerInstructionHighlightedColor
        nextBannerView.maneuverView.secondaryColor = style.nextBannerInstructionHighlightedColor
        nextBannerView.instructionLabel.normalTextColor = style.nextBannerInstructionHighlightedColor
    }
    
    fileprivate func highlightInstructionsCardView(colors: [CGColor]) {
        let style = instructionsCardView.style
        instructionsCardView.gradientLayer.colors = colors
        // primary & secondary labels
        instructionsCardView.primaryLabel.normalTextColor = style.primaryLabelHighlightedTextColor
        instructionsCardView.secondaryLabel.normalTextColor = style.secondaryLabelHighlightedTextColor
        // distance label
        instructionsCardView.distanceLabel.unitTextColor = style.distanceLabelHighlightedTextColor
        instructionsCardView.distanceLabel.valueTextColor = style.distanceLabelHighlightedTextColor
        // maneuver view
        instructionsCardView.maneuverView.primaryColor = style.maneuverViewHighlightedColor
        instructionsCardView.maneuverView.secondaryColor = style.maneuverViewHighlightedColor
    }
}

extension InstructionsCardContainerView: InstructionsCardContainerViewDelegate {
    public func label(_ label: InstructionLabel, willPresent instruction: VisualInstruction, as presented: NSAttributedString) -> NSAttributedString? {
        
        if let primaryLabel = label as? PrimaryLabel,
           let presented = delegate?.primaryLabel?(primaryLabel, willPresent: instruction, as: presented) {
            return presented
        } else if let secondaryLabel = label as? SecondaryLabel,
            let presented = delegate?.secondaryLabel?(secondaryLabel, willPresent: instruction, as: presented) {
            return presented
        } else {
            let style = instructionsCardView.style
            let highlighted = instructionsCardView.distanceFromCurrentLocation < InstructionsCardConstants.highlightDistance
            let textColor = highlighted ? style.primaryLabelTextColor : style.primaryLabelHighlightedTextColor
            let attributes = [NSAttributedString.Key.foregroundColor: textColor]
            
            let range = NSRange(location: 0, length: presented.length)
            let mutable = NSMutableAttributedString(attributedString: presented)
            mutable.addAttributes(attributes, range: range)
            
            return mutable
        }
    }
}
