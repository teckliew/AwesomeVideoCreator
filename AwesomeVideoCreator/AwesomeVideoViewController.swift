//
//  AwesomeVideoViewController.swift
//  AwesomeVideoCreator
//
//  Created by Barrett Breshears on 11/15/15.
//  Copyright © 2015 Sledgedev. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation
import AssetsLibrary
import MobileCoreServices

class AwesomeVideoViewController: UIViewController, AVCaptureFileOutputRecordingDelegate, UICollectionViewDelegate, UICollectionViewDataSource, AVPlayerViewControllerDelegate {

    @IBOutlet var switchCameraBtn:UIButton?
    @IBOutlet var flashLightBtn:UIButton?
    @IBOutlet var doneBtn:UIButton!
    @IBOutlet var closeBtn:UIButton!
    @IBOutlet var videoPreviewView:UIView!
    @IBOutlet var clipsScrollView:UIScrollView!
    @IBOutlet var recordBtn:UIButton!
    @IBOutlet var timeLabel:UILabel!
    @IBOutlet var trashButton:UIButton!
    @IBOutlet var clipsCollectionView:UICollectionView!
    @IBOutlet var videoPlayerView:UIView!
    
    var videoPlayer:AVPlayerViewController?
    var avPlayerLayer:AVPlayerLayer?
    var thumbnails = [UIImage]()
    var draggableThumbnail:DraggableThumbnail?
    var selectedIndexPath:NSIndexPath?
    var selectedPlayingVideo:Int = 0
    var captureSession:AVCaptureSession?
    var audioCapture:AVCaptureDevice?
    var backCameraVideoCapture:AVCaptureDevice?
    var frontCameraVideoCapture:AVCaptureDevice?
    var previewLayer:AVCaptureVideoPreviewLayer?
    var frontCamera:Bool = false
    var flash:Bool = false
    var recordingInProgress = false
    var output:AVCaptureMovieFileOutput!
    var videoClips:[NSURL] = [NSURL]()
    var videoThumbnail:[Thumbnail] = [Thumbnail]()
    var animating:Bool = false
    var time:Int = 0
    var loadedLibraryAsset = false
    
    var timer:NSTimer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        captureSession = AVCaptureSession()
        clipsCollectionView.canCancelContentTouches = false
        clipsCollectionView.exclusiveTouch = false
        
        // clipsScrollView.canCancelContentTouches = false
        // clipsScrollView.exclusiveTouch = false
        let devices = AVCaptureDevice.devices()
        for device in devices {
            
            if device.hasMediaType(AVMediaTypeAudio){
                audioCapture = device as? AVCaptureDevice
            }else if device.hasMediaType(AVMediaTypeVideo){
                if device.position == AVCaptureDevicePosition.Back{
                    backCameraVideoCapture = device as? AVCaptureDevice
                }else{
                    frontCameraVideoCapture = device as? AVCaptureDevice
                }
                
            }
            
        }
        
        // if audio capture did no get set no media type available :( return from the method
        if audioCapture == nil{
            return
        }
         beginSession()
    }
    
    func beginSession(){
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewView.clipsToBounds = true
        previewLayer?.frame = self.view.bounds
        self.videoPreviewView.layer.addSublayer(previewLayer!)
        
        captureSession?.startRunning()

        
        // start by adding audio capture
        do{
            try captureSession?.addInput(AVCaptureDeviceInput(device: audioCapture!))
        }catch{
            print(error)
            return
        }
        
        do{
            try captureSession?.addInput(AVCaptureDeviceInput(device: backCameraVideoCapture!))
        }catch{
            print(error)
            return
        }
			
				//long press for thumbnails
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(AwesomeVideoViewController.handleLongGesture(_:)))
        longPressGesture.minimumPressDuration = 0.1
        clipsCollectionView.addGestureRecognizer(longPressGesture)
        
        //video output for recording
				output = AVCaptureMovieFileOutput()
        let maxDuration = CMTimeMakeWithSeconds(60, 30)
        output.maxRecordedDuration = maxDuration
        captureSession?.addOutput(output)
        //let connection = output.connectionWithMediaType(AVMediaTypeVideo)
        //connection.videoOrientation = AVCaptureVideoOrientation.Portrait
        //captureSession?.sessionPreset = AVCaptureSessionPreset1280x720
        //captureSession?.commitConfiguration()
        
        videoPreviewView.bringSubviewToFront(self.trashButton)
        videoPreviewView.bringSubviewToFront(self.timeLabel)
        
        self.viewStyling()
    }
    
    func viewStyling(){
        
        self.videoPlayerView.hidden = true
        self.trashButton.hidden = true
        let image = UIImage(named: "record")?.imageWithRenderingMode(UIImageRenderingMode.AlwaysTemplate)
        recordBtn.setImage(image, forState: UIControlState.Normal)
        recordBtn.imageView?.contentMode = UIViewContentMode.ScaleAspectFit
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func swapCamera(){
        
        
        for var i in 0..<captureSession!.inputs.count {
            
            let input = captureSession!.inputs[i] as! AVCaptureDeviceInput
            let device = input.device as AVCaptureDevice
					
            if device.hasMediaType(AVMediaTypeVideo){
                captureSession?.removeInput(input)
            }
            
            
        }
        
        if frontCamera {
            try! captureSession?.addInput(AVCaptureDeviceInput(device: backCameraVideoCapture!))
						flashLightBtn?.hidden = false
        }else{
            try! captureSession?.addInput(AVCaptureDeviceInput(device: frontCameraVideoCapture!))
						flashLightBtn?.hidden = true
        }
        
        frontCamera = !frontCamera
        
        
    }
    
    @IBAction func toggleFlashlight(){
			if !frontCamera {
				let device = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
				if (device.hasTorch) {
					do {
						try device.lockForConfiguration()
						if (device.torchMode == AVCaptureTorchMode.On) {
							device.torchMode = AVCaptureTorchMode.Off
						} else {
							do {
								try device.setTorchModeOnWithLevel(1.0)
							} catch {
								print(error)
							}
						}
						device.unlockForConfiguration()
					} catch {
						print(error)
					}
				}
			}
    }
	
	
    @IBAction func recordVideo(){
			
        if recordingInProgress {
            self.stopTimer()
            output.stopRecording()
            
            recordBtn.tintColor = UIColor.blackColor()
            
        }else{
            
            recordBtn.tintColor = UIColor.redColor()
            let formatter = NSDateFormatter()
            formatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"
            let date = NSDate()
            let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as NSString
            let outputPath = "\(documentsPath)/\(formatter.stringFromDate(date)).mp4"
            let outputURL = NSURL(fileURLWithPath: outputPath)
            output.startRecordingToOutputFileURL(outputURL, recordingDelegate: self)
            self.startTimer()
        }
        
        recordingInProgress = !recordingInProgress
        
    }
    
    @IBAction func doneBtnClicked(){
        self.mergeVideoClips()
    }
    
		@IBAction func addClip(sender: AnyObject) {
				self.addClipFromLibrary()
		}
	
    // MARK: AVCaptureFileOutputRecordingDelegate methods
    func captureOutput(captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAtURL outputFileURL: NSURL!, fromConnections connections: [AnyObject]!, error: NSError!) {
        
        cropVideo(outputFileURL, fromLibrary: false)
        // getThumbnail(outputFileURL)
        
    }
    
    func captureOutput(captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAtURL fileURL: NSURL!, fromConnections connections: [AnyObject]!) {
    }
    
	
    func cropVideo(outputFileURL:NSURL, fromLibrary:Bool) {
		
        let videoAsset: AVAsset = AVAsset(URL: outputFileURL) as AVAsset
        let clipVideoTrack = videoAsset.tracksWithMediaType(AVMediaTypeVideo).first! as AVAssetTrack
        let composition = AVMutableComposition()
        composition.addMutableTrackWithMediaType(AVMediaTypeVideo, preferredTrackID: CMPersistentTrackID())
        let videoComposition = AVMutableVideoComposition()
        let instruction = AVMutableVideoCompositionInstruction()
        // rotate to portrait
        let transformer:AVMutableVideoCompositionLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: clipVideoTrack)
        var t1:CGAffineTransform
        var t2:CGAffineTransform
        
        instruction.timeRange = CMTimeRangeMake(kCMTimeZero, CMTimeMakeWithSeconds(180, 30))
        
        if fromLibrary {
            
            
            //cropping based on orientation of video clip
            if clipVideoTrack.naturalSize.height > clipVideoTrack.naturalSize.width {
                //portrait videos
                videoComposition.renderSize = CGSizeMake(clipVideoTrack.naturalSize.width, clipVideoTrack.naturalSize.width)
                t1 = CGAffineTransformMakeTranslation(0, -(clipVideoTrack.naturalSize.height/4));
            } else {
                //landscape videos
                videoComposition.renderSize = CGSizeMake(clipVideoTrack.naturalSize.height, clipVideoTrack.naturalSize.height)
                t1 = CGAffineTransformMakeTranslation(-(clipVideoTrack.naturalSize.width/4), 0);
            }
            
            t2 = CGAffineTransformRotate(t1, 0);
            
        } else {
            //recorded straight from the camera - default settings
            videoComposition.renderSize = CGSizeMake(720, 720)
            t1 = CGAffineTransformMakeTranslation(720, 0);
            t2 = CGAffineTransformRotate(t1, CGFloat(M_PI_2));

        }
        
        videoComposition.frameDuration = CMTimeMake(1, 30)
        
        transformer.setTransform(t2, atTime: kCMTimeZero)
        instruction.layerInstructions = [transformer]
        videoComposition.instructions = [instruction]
        
        
        
        let formatter = NSDateFormatter()
        formatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"
        let date = NSDate()
        let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as NSString
        let outputPath = "\(documentsPath)/\(formatter.stringFromDate(date)).mp4"
        let outputURL = NSURL(fileURLWithPath: outputPath)
        let exporter = AVAssetExportSession(asset: videoAsset, presetName: AVAssetExportPresetHighestQuality)!
        exporter.videoComposition = videoComposition
        exporter.outputURL = outputURL
        exporter.outputFileType = AVFileTypeQuickTimeMovie
        
        exporter.exportAsynchronouslyWithCompletionHandler({ () -> Void in
            dispatch_async(dispatch_get_main_queue(), {
                self.handleExportCompletion(exporter)
            })
        })
    }
    
    func handleExportCompletion(session: AVAssetExportSession) {
        let library = ALAssetsLibrary()
        let thumbnail =  self.getThumbnail(session.outputURL!)
        videoClips.append(session.outputURL!)
        
        thumbnails.append(thumbnail)
        self.clipsCollectionView.reloadData()
        let indexPath = NSIndexPath(forItem: thumbnails.count - 1, inSection: 0)
        self.clipsCollectionView.scrollToItemAtIndexPath(indexPath, atScrollPosition: UICollectionViewScrollPosition.Right, animated: true)
        /*
        if library.videoAtPathIsCompatibleWithSavedPhotosAlbum(session.outputURL) {
            var completionBlock: ALAssetsLibraryWriteVideoCompletionBlock
            
            completionBlock = { assetUrl, error in
                if error != nil {
                    print("error writing to disk")
                } else {
                    
                }
            }
            
            library.writeVideoAtPathToSavedPhotosAlbum(session.outputURL, completionBlock: completionBlock)
        }
        
        let player = AVPlayer(URL: session.outputURL!)
        let playerController = AVPlayerViewController()
        playerController.player = player
        self.presentViewController(playerController, animated: true) {
            player.play()
        }

        */
        

    }

    
    func getThumbnail(outputFileURL:NSURL) -> UIImage {
        
        let clip = AVURLAsset(URL: outputFileURL)
        let imgGenerator = AVAssetImageGenerator(asset: clip)
        let cgImage = try! imgGenerator.copyCGImageAtTime(
            CMTimeMake(1, 1), actualTime: nil)
        let uiImage = UIImage(CGImage: cgImage)
        return uiImage
        
    }
    
    // hide status bar
    override func prefersStatusBarHidden() -> Bool {
        return true;
    }
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.Portrait
    }
    
    // MARK: - CollectionView stuff
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("ThumbnailCell", forIndexPath: indexPath) as! ThumbnailCollectionViewCell
        cell.thumbnailImageView.image = thumbnails[indexPath.row]
        cell.exclusiveTouch = false
        return cell
        
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return thumbnails.count
    }
    
    func collectionView(collectionView: UICollectionView, moveItemAtIndexPath sourceIndexPath: NSIndexPath, toIndexPath destinationIndexPath: NSIndexPath) {
        self.selectedIndexPath = destinationIndexPath
        
        let url = videoClips[sourceIndexPath.row]
        let thumbnail = thumbnails[sourceIndexPath.row]
        
        videoClips.removeAtIndex(sourceIndexPath.row)
        videoClips.insert(url, atIndex: destinationIndexPath.row)
        thumbnails.removeAtIndex(sourceIndexPath.row)
        thumbnails.insert(thumbnail, atIndex: destinationIndexPath.row)
        
        
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        self.selectedPlayingVideo = indexPath.row;
        self.addVideoPlayer(self.videoClips[indexPath.row])
    }
    
    func addVideoPlayer(url:NSURL){
        
        
        let playerItem = AVPlayerItem(URL: url)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(AwesomeVideoViewController.itemDidFinishPlaying(_:)), name:AVPlayerItemDidPlayToEndTimeNotification, object: playerItem)
        videoPlayerView.hidden = false
        videoPlayer = AVPlayerViewController() //
        videoPlayer?.delegate = self
        videoPlayer?.player = AVPlayer(playerItem: playerItem)
        avPlayerLayer = AVPlayerLayer(player: videoPlayer!.player)
        avPlayerLayer!.frame = videoPlayerView!.frame
        videoPlayerView!.layer.addSublayer(avPlayerLayer!)
        videoPlayer!.player!.play()
    

    }
    
    
    func itemDidFinishPlaying(notification:NSNotification){
        print("finished")
        self.selectedPlayingVideo += 1
        if selectedPlayingVideo < self.videoClips.count {
            self.addVideoPlayer(self.videoClips[self.selectedPlayingVideo])
				} else {
					videoPlayerView.hidden = true
			}
    }
    
    
    func handleLongGesture(gesture: UILongPressGestureRecognizer){
        switch(gesture.state) {
            
        case UIGestureRecognizerState.Began:
            if let selectedIndexPath = self.clipsCollectionView.indexPathForItemAtPoint(gesture.locationInView(self.clipsCollectionView)){
                self.selectedIndexPath = selectedIndexPath
                clipsCollectionView.beginInteractiveMovementForItemAtIndexPath(selectedIndexPath)

            }else {
                break
            }
                    case UIGestureRecognizerState.Changed:
            let touchPoint = gesture.locationInView(self.view)
            let hitView = self.view.hitTest(touchPoint, withEvent: nil)
            if (hitView == self.trashButton){
                self.trashButton.tintColor = UIColor.redColor()
            }else if (hitView == self.videoPreviewView){
                self.trashButton.hidden = false
                self.trashButton.tintColor = UIColor.blackColor()
            }else{
                self.trashButton.hidden = true
                self.trashButton.tintColor = UIColor.blackColor()
            }

            clipsCollectionView.updateInteractiveMovementTargetPosition(gesture.locationInView(gesture.view!))
        case UIGestureRecognizerState.Ended:
            let touchPoint = gesture.locationInView(self.view)
            let hitView = self.view.hitTest(touchPoint, withEvent: nil)
            if (hitView == self.trashButton){
                let cell = clipsCollectionView.cellForItemAtIndexPath(self.selectedIndexPath!)
                cell?.removeFromSuperview()
                let avAsset = AVURLAsset(URL: self.videoClips[self.selectedIndexPath!.row])
                let duration = CMTimeGetSeconds(avAsset.duration)
                self.time -= Int(duration)
                self.updateTimeLabel()
                self.thumbnails.removeAtIndex(self.selectedIndexPath!.row)
                self.videoClips.removeAtIndex(self.selectedIndexPath!.row)
                self.clipsCollectionView.reloadData()
                
            }
            
            self.trashButton.hidden = true
            self.trashButton.tintColor = UIColor.blackColor()

            clipsCollectionView.endInteractiveMovement()
        default:
            clipsCollectionView.cancelInteractiveMovement()
        }
    }
    
    
    func startTimer(){
        if timer == nil {
         timer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector:#selector(AwesomeVideoViewController.addTime), userInfo: nil, repeats: true)
        }
    }
    
    func stopTimer(){
        if timer != nil {
            timer?.invalidate()
            timer = nil
        }
    }
	
    func addTime(){
        self.time += 1
        self.updateTimeLabel()
    }
    
    func updateTimeLabel(){
        self.timeLabel.text = "\(time)"
    }
    

    func mergeVideoClips(){
        
        let composition = AVMutableComposition()
        
        let videoTrack = composition.addMutableTrackWithMediaType(AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        let audioTrack = composition.addMutableTrackWithMediaType(AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        var mergeTime:Double = 0.000
        for video in self.videoClips {
            let asset = AVAsset(URL: video)
            let videoAssetTrack = asset.tracksWithMediaType(AVMediaTypeVideo)[0] 
            let audioAssetTrack = asset.tracksWithMediaType(AVMediaTypeAudio)[0]
            let atTime = CMTime(seconds: mergeTime, preferredTimescale:600)
            do{
                try videoTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration) , ofTrack: videoAssetTrack, atTime: atTime)
                
                try audioTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration) , ofTrack: audioAssetTrack, atTime: atTime)
                
            }catch{
                print("something bad happend I don't want to talk about it")
            }
            mergeTime +=  asset.duration.seconds
            
        }
        
        
        
        let directory = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as String
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateStyle = .LongStyle
        dateFormatter.timeStyle = .ShortStyle
        let date = dateFormatter.stringFromDate(NSDate())
        let savePath = "\(directory)/mergedVideo-\(date).mp4"
        let url = NSURL(fileURLWithPath: savePath)
        
        let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)
        exporter?.outputURL = url
        exporter?.shouldOptimizeForNetworkUse = true
        exporter?.outputFileType = AVFileTypeMPEG4
        
        
        exporter?.exportAsynchronouslyWithCompletionHandler({ () -> Void in
            
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.finalExportCompletion(exporter!)
            })
            
        })
       
        
    }
    
    func finalExportCompletion(session: AVAssetExportSession) {
        let library = ALAssetsLibrary()
        if library.videoAtPathIsCompatibleWithSavedPhotosAlbum(session.outputURL) {
        var completionBlock: ALAssetsLibraryWriteVideoCompletionBlock
        
        completionBlock = { assetUrl, error in
        if error != nil {
        print("error writing to disk")
        } else {
        
        }
        }
        
        library.writeVideoAtPathToSavedPhotosAlbum(session.outputURL, completionBlock: completionBlock)
        }
        
        let player = AVPlayer(URL: session.outputURL!)
        let playerController = AVPlayerViewController()
        playerController.player = player
        self.presentViewController(playerController, animated: true) {
        player.play()
        }
        
        
        
    }
	
	func addClipFromLibrary() {
		print("addClip")
		if savedPhotosAvailable() {
			startMediaBrowserFromViewController(self, usingDelegate: self)
			loadedLibraryAsset = true
		}
	}
	
	func savedPhotosAvailable() -> Bool {
		if UIImagePickerController.isSourceTypeAvailable(.SavedPhotosAlbum) == false {
			let alert = UIAlertController(title: "Not Available", message: "No Saved Album found", preferredStyle: .Alert)
			alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Cancel, handler: nil))
			presentViewController(alert, animated: true, completion: nil)
			return false
		}
		return true
	}
	
	func startMediaBrowserFromViewController(viewController: UIViewController!, usingDelegate delegate : protocol<UINavigationControllerDelegate, UIImagePickerControllerDelegate>!) -> Bool {
		
		if UIImagePickerController.isSourceTypeAvailable(.SavedPhotosAlbum) == false {
			return false
		}
		
		let mediaUI = UIImagePickerController()
		mediaUI.sourceType = .SavedPhotosAlbum
		mediaUI.mediaTypes = [kUTTypeMovie as NSString as String]
		mediaUI.allowsEditing = true
		mediaUI.delegate = delegate
		presentViewController(mediaUI, animated: true, completion: nil)
		return true
	}

	
}

extension Int {
    var degreesToRadians : CGFloat {
        return CGFloat(self) * CGFloat(M_PI) / 180.0
    }
}

extension AwesomeVideoViewController: UINavigationControllerDelegate {
	
}

extension AwesomeVideoViewController: UIImagePickerControllerDelegate {
	func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
		let mediaType = info[UIImagePickerControllerMediaType] as! NSString
		dismissViewControllerAnimated(true, completion: nil)
		
		if mediaType == kUTTypeMovie {
			let avAsset = AVAsset(URL:info[UIImagePickerControllerMediaURL] as! NSURL)
			var messageTitle = ""
            var message = ""
			var videoPath:NSURL
			var videoDuration:Float64
			
			videoPath = avAsset.valueForKey("URL") as! NSURL
			//check for video length
			videoDuration = CMTimeGetSeconds(avAsset.duration)
            if videoDuration < 60 {
                self.cropVideo(videoPath, fromLibrary: true)
                messageTitle = "Asset Loaded"
                message = "Video loaded from library"
            } else {
                messageTitle = "Video Too Long"
                message = "Video must be under 60 seconds"
            }
            let alert = UIAlertController(title: messageTitle, message: message, preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Cancel, handler: nil))
            presentViewController(alert, animated: true, completion: nil)
		}
	}
}
