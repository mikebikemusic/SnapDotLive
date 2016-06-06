//
//  ViewController.swift
//  SnapDotLive
//
//  Created by Mike on 6/5/16.
//  Copyright © 2016 Orologics. All rights reserved.
//

import UIKit
import GPUImage
import AVFoundation
import Photos


class ViewController: UIViewController {
    @IBOutlet weak var renderView: RenderView!
    @IBOutlet weak var unsharpMaskSlider: UISlider!
    @IBOutlet weak var contrastSlider: UISlider!
    @IBOutlet weak var brightnessSlider: UISlider!

    var camera:Camera!
    var unsharpMask:UnsharpMask!
    var filterMode:BasicOperation!
    var brightnessFilter: BrightnessAdjustment!
    var fullColorFilter: BrightnessAdjustment!
    var contrastFilter: ContrastAdjustment!
    var greyscaleFilter: Luminance!
    var isRecording = false
    var movieOutput:MovieOutput? = nil
    
    var fullColor = true
    private let tmpDir = NSURL(fileURLWithPath: NSTemporaryDirectory())
    private let videoOutputURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).URLByAppendingPathComponent("MediaCache/OutputVideo.mov")

    override func viewDidLoad() {
        super.viewDidLoad()
        
        renderView.orientation = .Portrait
        do {
            camera = try Camera(sessionPreset:AVCaptureSessionPreset640x480)
            camera.runBenchmark = false
            
            unsharpMask = UnsharpMask()
            brightnessFilter = BrightnessAdjustment()
            brightnessFilter.brightness = 0.0
            contrastFilter = ContrastAdjustment()
            camera --> unsharpMask --> brightnessFilter --> contrastFilter --> renderView
            
            greyscaleFilter = Luminance()

            camera.startCapture()
        } catch {
            fatalError("Could not initialize rendering pipeline: \(error)")
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    
    @IBAction func capture(sender: AnyObject) {
        if (!isRecording) {
            do {
                self.isRecording = true
                let documentsDir = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain:.UserDomainMask, appropriateForURL:nil, create:true)
                let fileURL = NSURL(string:"test.mp4", relativeToURL:documentsDir)!
                do {
                    try NSFileManager.defaultManager().removeItemAtURL(fileURL)
                } catch {
                }
                movieOutput = try MovieOutput(URL:fileURL, size:Size(width:480, height:640), liveVideo:true)
                camera.audioEncodingTarget = movieOutput
                contrastFilter --> movieOutput!
                movieOutput!.startRecording()
                (sender as! UIBarButtonItem).title = "Stop"
            } catch {
                fatalError("Couldn't initialize movie, error: \(error)")
            }
        } else {
            movieOutput?.finishRecording{
                do {
                    let documentsDir = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain:.UserDomainMask, appropriateForURL:nil, create:true)
                    let fileURL = NSURL(string:"test.mp4", relativeToURL:documentsDir)!
                    PHPhotoLibrary.requestAuthorization({(status:PHAuthorizationStatus) in
                        switch status{
                        case .Authorized:
                            PHPhotoLibrary.sharedPhotoLibrary().performChanges({
                                if #available(iOS 9.0, *) {
                                    let options = PHAssetResourceCreationOptions()
                                    options.shouldMoveFile = true
                                    let changeRequest = PHAssetCreationRequest.creationRequestForAsset()
                                    changeRequest.addResourceWithType(.Video, fileURL: fileURL, options: options)
                                } else {
                                    PHAssetChangeRequest.creationRequestForAssetFromVideoAtFileURL(fileURL)
                                }
                                }, completionHandler: {success, err in
                                    if !success {
                                        print("Could not save movie to photo library: \(err)")
                                    }
                                    dispatch_async(dispatch_get_main_queue()) {
                                        (sender as! UIBarButtonItem).title = "Record"
                                    }
                                    self.isRecording = false
                                    self.camera.audioEncodingTarget = nil
                                    self.movieOutput = nil
                            })
                            break
                        case .Denied:
                            dispatch_async(dispatch_get_main_queue(), {
                                print("Denied")
                            })
                            break
                        default:
                            dispatch_async(dispatch_get_main_queue(), {
                                print("Default")
                            })
                            break
                        }
                    })
                    if PHPhotoLibrary.authorizationStatus() == .Authorized {
                    }
                } catch {
                    print("Couldn't initialize movie, error: \(error)")
                }
            }
        }
    }
    
    @IBAction func colorMode(sender: AnyObject) {
        fullColor = !fullColor
        unsharpMask.removeAllTargets()
        if fullColor {
            greyscaleFilter.removeAllTargets()
            unsharpMask --> brightnessFilter
            (sender as! UIBarButtonItem).title = "Full Color"
        } else {
            unsharpMask --> greyscaleFilter --> brightnessFilter
            (sender as! UIBarButtonItem).title = "Greyscale"
        }
    }
    
    @IBAction func unsharpMaskChanged(sender: AnyObject) {
        unsharpMask.intensity = unsharpMaskSlider.value
    }
    
    @IBAction func sharpButtonPressed(sender: AnyObject) {
        unsharpMaskSlider.value = 1.0
        unsharpMask.intensity = unsharpMaskSlider.value
    }
    
    @IBAction func contrastChanged(sender: AnyObject) {
        contrastFilter.contrast = contrastSlider.value
    }
    
    @IBAction func contrastButtonPressed(sender: AnyObject) {
        contrastSlider.value = 1.0
        contrastFilter.contrast = contrastSlider.value
    }
    
    @IBAction func brightnessChanged(sender: AnyObject) {
        brightnessFilter.brightness = brightnessSlider.value
    }
    
    @IBAction func brightnessButtonPressed(sender: AnyObject) {
        brightnessSlider.value = 0.0
        brightnessFilter.brightness = brightnessSlider.value
    }
    

}

