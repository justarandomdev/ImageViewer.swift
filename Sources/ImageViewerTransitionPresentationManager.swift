//
//  ImageViewerTransitionPresentationManager.swift
//  ImageViewer.swift
//
//  Created by Michael Henry Pantaleon on 2020/08/19.
//

import Foundation
import UIKit

protocol ImageViewerTransitionViewControllerConvertible {
    
    // The source view
    var sourceView: UIImageView? { get }
    
    // The final view
    var targetView: UIImageView? { get }
}

final class ImageViewerTransitionPresentationAnimator:NSObject {
    
    let isPresenting: Bool
    
    init(isPresenting: Bool) {
        self.isPresenting = isPresenting
        super.init()
    }
}

private extension CGSize {
    func aspectFit(in boundingSize: CGSize) -> CGSize {
        let resultSize: CGSize
        let widthRatio = boundingSize.width / width
        let heightRatio = boundingSize.height / height

        if heightRatio < widthRatio {
            resultSize = CGSize(width: boundingSize.height / height * width, height: boundingSize.height)
        } else if widthRatio < heightRatio {
            resultSize = CGSize(width: boundingSize.width, height: boundingSize.width / width * height)
        } else {
            resultSize = boundingSize
        }

        return resultSize
    }
}

// MARK: - UIViewControllerAnimatedTransitioning
extension ImageViewerTransitionPresentationAnimator: UIViewControllerAnimatedTransitioning {

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?)
        -> TimeInterval {
            return 0.3
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let key: UITransitionContextViewControllerKey = isPresenting ? .to : .from
        guard let controller = transitionContext.viewController(forKey: key)
            else { return }
        
        let animationDuration = transitionDuration(using: transitionContext)
        
        if isPresenting {
            presentAnimation(
                transitionView: transitionContext.containerView,
                controller: controller,
                duration: animationDuration) { finished in
                    transitionContext.completeTransition(finished)
            }
             
        } else {
            dismissAnimation(
                transitionView: transitionContext.containerView,
                controller: controller,
                duration: animationDuration) { finished in
                    transitionContext.completeTransition(finished)
            }
        }
    }
    
    private func createDummyImageView(frame: CGRect, image:UIImage? = nil, isPresenting: Bool, originalCornerRadius: CGFloat)
        -> UIImageView {
            let dummyImageView:UIImageView = UIImageView(frame: frame)
            dummyImageView.clipsToBounds = true
            dummyImageView.contentMode = .scaleAspectFit
            dummyImageView.alpha = 1.0
            dummyImageView.image = image
            dummyImageView.layer.cornerRadius = isPresenting ? originalCornerRadius : 0
            dummyImageView.layer.masksToBounds = true
            return dummyImageView
    }
    
    private func presentAnimation(
        transitionView:UIView,
        controller: UIViewController,
        duration: TimeInterval,
        completed: @escaping((Bool) -> Void)) {

        guard
            let transitionVC = controller as? ImageViewerTransitionViewControllerConvertible,
            let sourceView = transitionVC.sourceView
        else { return }
    
        sourceView.alpha = 0.0
        controller.view.alpha = 0.0
        
        transitionView.addSubview(controller.view)
        transitionVC.targetView?.alpha = 0.0
        
        let originalCornerRadius = sourceView.layer.cornerRadius
        let dummyImageView = createDummyImageView(
            frame: sourceView.frameRelativeToWindow(),
            image: sourceView.image,
            isPresenting: isPresenting,
            originalCornerRadius: originalCornerRadius)
        transitionView.addSubview(dummyImageView)

        let targetFrame: CGRect
        if let image = sourceView.image {
            let screenBounds = UIScreen.main.bounds
            let finalSize = image.size.aspectFit(in: screenBounds.size)
            targetFrame = CGRect(origin: CGPoint(x: abs(screenBounds.width-finalSize.width)/2.0,
                                                 y: abs(screenBounds.height-finalSize.height)/2.0),
                                 size: finalSize)
        } else {
            targetFrame = UIScreen.main.bounds
        }
        UIView.animate(withDuration: duration, animations: {
            dummyImageView.frame = targetFrame
            dummyImageView.layer.cornerRadius = 0
            controller.view.alpha = 1.0
        }) { finished in
            transitionVC.targetView?.alpha = 1.0
            dummyImageView.removeFromSuperview()
            completed(finished)
        }
    }
    
    private func dismissAnimation(
        transitionView:UIView,
        controller: UIViewController,
        duration:TimeInterval,
        completed: @escaping((Bool) -> Void)) {
        
        guard
            let transitionVC = controller as? ImageViewerTransitionViewControllerConvertible
        else { return }
  
        let sourceView = transitionVC.sourceView
        let targetView = transitionVC.targetView

        let originalCornerRadius = sourceView?.layer.cornerRadius ?? 0.0
        let dummyImageView = createDummyImageView(
            frame: targetView?.frameRelativeToWindow() ?? UIScreen.main.bounds,
            image: targetView?.image,
            isPresenting: isPresenting,
            originalCornerRadius: originalCornerRadius)
        transitionView.addSubview(dummyImageView)
        targetView?.isHidden = true
      
        controller.view.alpha = 1.0
        UIView.animate(withDuration: duration, animations: {
            if let sourceView = sourceView {
                // return to original position
                dummyImageView.frame = sourceView.frameRelativeToWindow()
                dummyImageView.layer.cornerRadius = originalCornerRadius
            } else {
                // just disappear
                dummyImageView.alpha = 0.0
            }
            controller.view.alpha = 0.0
        }) { finished in
            sourceView?.alpha = 1.0
            controller.view.removeFromSuperview()
            completed(finished)
        }
    }
}

final class ImageViewerTransitionPresentationController: UIPresentationController {
    
    override var frameOfPresentedViewInContainerView: CGRect {
        var frame: CGRect = .zero
        frame.size = size(forChildContentContainer: presentedViewController,
                          withParentContainerSize: containerView!.bounds.size)
        return frame
    }
    
    override func containerViewWillLayoutSubviews() {
        presentedView?.frame = frameOfPresentedViewInContainerView
    }
}

final class ImageViewerTransitionPresentationManager: NSObject {
    
}

// MARK: - UIViewControllerTransitioningDelegate
extension ImageViewerTransitionPresentationManager: UIViewControllerTransitioningDelegate {
    func presentationController(
        forPresented presented: UIViewController,
        presenting: UIViewController?,
        source: UIViewController
    ) -> UIPresentationController? {
        let presentationController = ImageViewerTransitionPresentationController(
            presentedViewController: presented,
            presenting: presenting)
        return presentationController
    }
    
    func animationController(
        forPresented presented: UIViewController,
        presenting: UIViewController,
        source: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
 
        return ImageViewerTransitionPresentationAnimator(isPresenting: true)
    }
    
    func animationController(
        forDismissed dismissed: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        return ImageViewerTransitionPresentationAnimator(isPresenting: false)
    }
}

// MARK: - UIAdaptivePresentationControllerDelegate
extension ImageViewerTransitionPresentationManager: UIAdaptivePresentationControllerDelegate {
    
    func adaptivePresentationStyle(
        for controller: UIPresentationController,
        traitCollection: UITraitCollection
    ) -> UIModalPresentationStyle {
        return .none
    }
    
    func presentationController(
        _ controller: UIPresentationController,
        viewControllerForAdaptivePresentationStyle style: UIModalPresentationStyle
    ) -> UIViewController? {
        return nil
    }
}
