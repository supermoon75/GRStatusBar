//
//  GRStatusBar.swift
//  GRStatusBar
//
//  Created by Guilherme Rambo on 27/01/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Cocoa

/// Manages a status bar associated with a particular window
///
/// The status bar is a thin translucent bar displayed on be bottom-left of the window
@objc public class GRStatusBar: NSObject {

    /// The style used for the status bar vibrancy (Light or Dark)
    public var style = GRStatusBarStyle.Light {
        didSet {
            guard backgroundView != nil else { return }
            
            backgroundView.appearance = style.appearance
        }
    }
    
    /// The color to use as the status bar's background (will have opacity reduced to keep translucency)
    public var backgroundColor: NSColor? {
        didSet {
            tintView.backgroundColor = backgroundColor?.colorWithAlphaComponent(LayoutConstants.backgroundColorAlpha)
        }
    }
    
    /// The color for the text (if you want to customize other text properties, use `attributedText`)
    public var textColor: NSColor? = LayoutConstants.defaultTextColor {
        didSet {
            label.textColor = textColor ?? LayoutConstants.defaultTextColor
        }
    }
    
    /// The text to display in the status bar (if you want to customize text properties, set `attributedText` instead)
    ///
    /// *The status bar is automatically shown for `displayTime` seconds when this property is changed, unless It is set to nil*
    public var text: String? {
        didSet {
            guard label != nil else { return }
            
            label.stringValue = text ?? ""
            
            if text != nil {
                show()
            }
        }
    }
    
    /// The attributed text to display in the status bar
    ///
    /// *The status bar is automatically shown for `displayTime` seconds when this property is changed, unless It is set to nil*
    public var attributedText: NSAttributedString? {
        didSet {
            label.attributedStringValue = attributedText ?? NSAttributedString()
            
            if attributedText != nil {
                show()
            }
        }
    }
    
    /// How long the status bar should stay on screen by default
    public var displayTime: Double = 4.0
    
    /// Whether the status bar is currently being displayed or not
    ///
    /// *This is set to `true` when the show animation starts and `false` when the hide animation starts*
    public var isVisible = false
    
    private var window: NSWindow
    
    private var containerView: NSView!
    private var tintView: GRStatusBarBackgroundView!
    private var backgroundView: NSVisualEffectView!
    private var label: NSTextField!
    
    private let windowContentViewObserverContext = UnsafeMutablePointer<Void>()
    init(window: NSWindow) {
        self.window = window

        super.init()
        
        self.window.addObserver(self, forKeyPath: "contentView", options: [.Initial, .New], context: windowContentViewObserverContext)
        
        fixContentViewIfNeeded()
        buildViews()
    }
    
    /// Shows the status bar for the specified duration.
    ///
    /// If no duration is specified, the status bar is shown for the duration specified in `displayTime`.
    /// If the duration specified is `zero`, the status bar is shown until `hide()` is called manually
    public func show(forDuration duration: Double? = nil) {
        bringToFront()
        
        let duration = duration ?? self.displayTime
        
        isVisible = true
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.4
            self.containerView.animator().alphaValue = 1.0
        }) {
            guard duration > 0.0 else { return }
            
            let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(duration * Double(NSEC_PER_SEC)))
            dispatch_after(delayTime, dispatch_get_main_queue()) {
                self.hide()
            }
        }
    }
    
    /// Hides the status bar after the specified delay
    ///
    /// If no delay is specified, the status bar is hidden immediately
    public func hide(afterDelay delay: Double? = 0.0) {
        let hideBlock = {
            self.isVisible = false
            
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.4
                self.containerView.animator().alphaValue = 0.0
            }, completionHandler: nil)
        }
        
        guard let delay = delay else { return hideBlock() }
        
        let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC)))
        dispatch_after(delayTime, dispatch_get_main_queue(), hideBlock)
    }
    
    private func fixContentViewIfNeeded() {
        guard let contentView = window.contentView else { return }
        guard !contentView.wantsLayer else { return }
        
        contentView.wantsLayer = true
        print("[GRStatusBar] WARNING: Window contentView must have wantsLayer = true")
    }

    private func buildViews() {
        let defaultRect = NSMakeRect(0, 0, LayoutConstants.defaultWidth, LayoutConstants.defaultHeight)

        // Container View
        
        containerView = NSView(frame: defaultRect)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addConstraint(NSLayoutConstraint(item: containerView, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: LayoutConstants.defaultHeight))
        
        // Visual Effect View
        
        backgroundView = RoundedVisualEffectView(frame: defaultRect)
        backgroundView.blendingMode = .WithinWindow
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.material = .AppearanceBased
        backgroundView.appearance = style.appearance
        backgroundView.state = .Active
        containerView.addSubview(backgroundView)
        
        // Tint View
        
        tintView = GRStatusBarBackgroundView(frame: defaultRect)
        tintView.backgroundColor = backgroundColor
        tintView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(tintView)
        
        // Label
        
        label = NSTextField(frame: defaultRect)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.stringValue = text ?? ""
        if let attributedText = attributedText {
            label.attributedStringValue = attributedText
        }
        label.editable = false
        label.selectable = false
        label.bezeled = false
        label.bordered = false
        label.drawsBackground = false
        label.font = NSFont.systemFontOfSize(LayoutConstants.defaultFontSize)
        label.textColor = textColor
        label.lineBreakMode = .ByTruncatingMiddle
        label.sizeToFit()
        backgroundView.addSubview(label)
        
        // Configure frames and constraints
        
        containerView.setFrameSize(label.bounds.size)
        backgroundView.setFrameSize(label.bounds.size)
        tintView.setFrameSize(label.bounds.size)

        backgroundView.leadingAnchor.constraintEqualToAnchor(containerView.leadingAnchor).active = true
        backgroundView.trailingAnchor.constraintEqualToAnchor(containerView.trailingAnchor).active = true
        backgroundView.topAnchor.constraintEqualToAnchor(containerView.topAnchor).active = true
        backgroundView.bottomAnchor.constraintEqualToAnchor(containerView.bottomAnchor).active = true
        
        tintView.leadingAnchor.constraintEqualToAnchor(containerView.leadingAnchor).active = true
        tintView.trailingAnchor.constraintEqualToAnchor(containerView.trailingAnchor).active = true
        tintView.topAnchor.constraintEqualToAnchor(containerView.topAnchor).active = true
        tintView.bottomAnchor.constraintEqualToAnchor(containerView.bottomAnchor).active = true
        
        // Constraint from label to visual effect view, LEFT with padding
        let labelLeadingAnchor = label.leadingAnchor.constraintEqualToAnchor(backgroundView.leadingAnchor)
        labelLeadingAnchor.constant = LayoutConstants.padding
        labelLeadingAnchor.active = true
        // Constraint from label to visual effect view, RIGHT with padding
        let labelTrailingAnchor = label.trailingAnchor.constraintEqualToAnchor(backgroundView.trailingAnchor)
        labelTrailingAnchor.constant = -LayoutConstants.padding
        labelTrailingAnchor.active = true
        // Constraint to center label vertically inside visual effect view
        let labelCenterAnchor = label.centerYAnchor.constraintEqualToAnchor(backgroundView.centerYAnchor)
        labelCenterAnchor.constant = LayoutConstants.textYOffset
        labelCenterAnchor.active = true
        
        // Start with the container hidden
        containerView.alphaValue = 0.0
        
        if let contentView = window.contentView {
            // Start with the best style for the contentView's appearance
            style = GRStatusBarStyle(appearance: contentView.appearance)
        }
        
        bringToFront()
    }
    
    private func bringToFront() {
        guard containerView != nil else { return }

        if containerView.superview != nil {
            containerView.removeFromSuperview()
        }
        
        guard let contentView = window.contentView else { return }
        
        contentView.addSubview(containerView)
        
        let leadingConstraint = containerView.leadingAnchor.constraintEqualToAnchor(contentView.leadingAnchor)
        leadingConstraint.constant = LayoutConstants.margin
        leadingConstraint.active = true
        let bottomConstraint = containerView.bottomAnchor.constraintEqualToAnchor(contentView.bottomAnchor)
        bottomConstraint.constant = -LayoutConstants.margin
        bottomConstraint.active = true
    }
    
    override public func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if context == windowContentViewObserverContext {
            bringToFront()
        } else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
    
    deinit {
        window.removeObserver(self, forKeyPath: "contentView", context: windowContentViewObserverContext)
    }

}