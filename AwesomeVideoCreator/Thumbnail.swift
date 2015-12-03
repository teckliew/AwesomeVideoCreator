//
//  Thumbnail.swift
//  AwesomeVideoCreator
//
//  Created by Barrett Breshears on 11/21/15.
//  Copyright © 2015 Sledgedev. All rights reserved.
//

import UIKit

protocol ThumbnailDelegate {
    func thumbnailTouchesMoved(thumbnail:Thumbnail, touches: Set<UITouch>, withEvent event: UIEvent?);
    func thumbnailTouchesEnded(thumbnail:Thumbnail, touches: Set<UITouch>, withEvent event: UIEvent?);
}

class Thumbnail: UIImageView, DraggableThumbnailDelegate {

    var delegate:ThumbnailDelegate!
    var originalFrame:CGRect!
    /*
    // Only override drawRect: if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func drawRect(rect: CGRect) {
        // Drawing code
    }
    */
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        // self.hidden = true
        // self.originalFrame = self.frame
        delegate.thumbnailTouchesMoved(self, touches: touches, withEvent:event)
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        
        delegate.thumbnailTouchesEnded(self, touches: touches, withEvent: event)
        self.animateToPreviousThumbnail()
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
               
        let touch:UITouch = touches.first!
        self.center = touch.locationInView(self.superview)
        delegate.thumbnailTouchesMoved(self, touches: touches, withEvent: event)
        
    }
    
    func animateToPreviousThumbnail(){
        UIView.animateWithDuration(0.3, animations: { () -> Void in
            self.frame = self.originalFrame
            }) { (success) -> Void in
        }
    }

    
    func finishedDragging() {
    }
    
    func thumbnailDestroyed() {
        self.hidden = false
    }

}
