//
//  DraggableThumbnail.swift
//  AwesomeVideoCreator
//
//  Created by Barrett Breshears on 11/22/15.
//  Copyright © 2015 Sledgedev. All rights reserved.
//

import UIKit

protocol DraggableThumbnailDelegate{
    func finishedDragging()
    func thumbnailDestroyed()
}

class DraggableThumbnail: UIImageView {

    var delegate:DraggableThumbnailDelegate!
    var originalFrame:CGRect!
    
    // Only override drawRect: if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func drawRect(rect: CGRect) {
        // Drawing code
    }

    /*
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        delegate.finishedDragging()
        self.animateToPreviousThumbnail()
    }
    
  
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        
        let touch:UITouch = touches.first!
        self.center = touch.locationInView(self.superview)
        
    }
   */
    
    func animateToPreviousThumbnail(){
        UIView.animateWithDuration(0.3, animations: { () -> Void in
            self.frame = self.originalFrame
            }) { (success) -> Void in
                self.delegate.thumbnailDestroyed()
                self.removeFromSuperview()
        }
    }

}
