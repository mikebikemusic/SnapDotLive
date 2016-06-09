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
import MobileCoreServices


class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    @IBOutlet weak var renderView: RenderView!
    @IBOutlet weak var unsharpMaskSlider: UISlider!
    @IBOutlet weak var contrastSlider: UISlider!
    @IBOutlet weak var brightnessSlider: UISlider!
    @IBOutlet weak var recordButton: UIBarButtonItem!

    @IBOutlet weak var imageView: UIImageView!
    var camera:Camera!
    private let imagePicker = UIImagePickerController()
    
    let harrisCornerDetector = HarrisCornerDetector()
    let blendFilter = AlphaBlend()
    
    let unsharpMask = UnsharpMask()
    let brightnessFilter = BrightnessAdjustment()
    let contrastFilter = ContrastAdjustment()
    var lastFilter:ImageProcessingOperation?
    let greyscaleFilter = Luminance()
    let greyFilter = Luminance()
    var isRecording = false
    var movieOutput:MovieOutput? = nil
    var picture:PictureInput!
    let rawDataOutput = RawDataOutput()
    let rawDataOutputGrey = RawDataOutput()
    let rawDataInput = RawDataInput()
    let algo = MyAlgo()
    
    var fullColor = true
    var useCamera = false
    var disableCamera = false
    
    private let tmpDir = NSURL(fileURLWithPath: NSTemporaryDirectory())
    private let videoOutputURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).URLByAppendingPathComponent("MediaCache/OutputVideo.mov")
    private var sourceURL = NSURL()
    private var validURL = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
        imagePicker.delegate = self

        renderView.backgroundRenderColor = Color.White
        renderView.fillMode = FillMode.PreserveAspectRatio
        brightnessFilter.brightness = 0.0

        unsharpMask --> brightnessFilter --> contrastFilter  // do not insert any filter between unsharp and brightness without fixing the other references
        lastFilter = contrastFilter
        
        lastFilter! --> renderView
        lastFilter! --> rawDataOutput
        lastFilter! --> rawDataOutputGrey

        rawDataOutputGrey.pixelFormat = .Luminance
//        rawDataInput --> renderView
        
        rawDataOutput.downloadBytes = { pixels, size, pixelFormat, imageOrientation in
            let bytesPerRow = Int(size.width) * 4
            set_rgba_image(Int(size.width), Int(size.height), bytesPerRow, pixels)
//            self.rawDataInput.uploadBytes(pixels, size: size, pixelFormat: pixelFormat, orientation: imageOrientation)
        }
        rawDataOutputGrey.downloadBytes = { pixels, size, pixelFormat, imageOrientation in
            let bytesPerRow = Int(size.width) * 4
            set_grey_image(Int(size.width), Int(size.height), bytesPerRow, pixels)
        }

        if useCamera {
            do {
                camera = try Camera(sessionPreset:AVCaptureSessionPreset640x480)
//                camera.runBenchmark = true
                camera --> unsharpMask
                camera.startCapture()
            } catch {
                fatalError("Could not initialize rendering pipeline: \(error)")
            }
        } else {
            useCamera = true // to enable photo picking button
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    
    @IBAction func capture(sender: AnyObject) {
        if !useCamera {
            return
        }
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
                lastFilter! --> movieOutput!
                movieOutput!.startRecording()
                recordButton.title = "Stop"
            } catch {
                fatalError("Couldn't initialize movie, error: \(error)")
            }
        } else {
            movieOutput?.finishRecording {
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
                                        self.recordButton.title = "Record"
                                    }
                                    self.isRecording = false
                                    self.camera.audioEncodingTarget = nil
                                    self.lastFilter!.removeAllTargets()
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
            (sender as! UIBarButtonItem).title = "Greyscale"
        } else {
            unsharpMask --> greyscaleFilter --> brightnessFilter
            (sender as! UIBarButtonItem).title = "Full Color"
        }
        if validURL {
            picture.processImage()
        }
    }
    
    @IBAction func inputMode(sender: AnyObject) {
        if isRecording {
            capture(recordButton)  // to turn off recording
            return
        }
        if disableCamera {
            return
        }
        useCamera = !useCamera
        if useCamera {
            if validURL {
                picture.removeAllTargets()
                validURL = false
            }
            if camera == nil {
                do {
                    camera = try Camera(sessionPreset:AVCaptureSessionPreset640x480)
//                    camera.runBenchmark = true
                    camera --> unsharpMask
                    camera.startCapture()
                } catch {
                    fatalError("Could not initialize rendering pipeline: \(error)")
                }
            }
            camera --> unsharpMask
            camera.startCapture()
            (sender as! UIBarButtonItem).title = "Photo"
           
        } else {
            if camera != nil {
                camera.stopCapture()
                camera.removeAllTargets()
            }
            imagePicker.sourceType = .PhotoLibrary
            imagePicker.mediaTypes = [kUTTypeImage as String]
            (sender as! UIBarButtonItem).title = "Camera"
            
            presentViewController(imagePicker, animated: true, completion: nil)
        }
    }
    
    @IBAction func unsharpMaskChanged(sender: AnyObject) {
        unsharpMask.intensity = unsharpMaskSlider.value
        if validURL {
            picture.processImage()
        }
    }
    
    @IBAction func sharpButtonPressed(sender: AnyObject) {
        unsharpMaskSlider.value = 1.0
        unsharpMask.intensity = unsharpMaskSlider.value
        if validURL {
            picture.processImage()
        }
    }
    
    @IBAction func contrastChanged(sender: AnyObject) {
        contrastFilter.contrast = contrastSlider.value
        if validURL {
            picture.processImage()
        }
    }
    
    @IBAction func contrastButtonPressed(sender: AnyObject) {
        contrastSlider.value = 1.0
        contrastFilter.contrast = contrastSlider.value
        if validURL {
            picture.processImage()
        }
    }
    
    @IBAction func brightnessChanged(sender: AnyObject) {
        brightnessFilter.brightness = brightnessSlider.value
        if validURL {
            picture.processImage()
        }
    }
    
    @IBAction func brightnessButtonPressed(sender: AnyObject) {
        brightnessSlider.value = 0.0
        brightnessFilter.brightness = brightnessSlider.value
        if validURL {
            picture.processImage()
        }
    }
    
    // MARK: - UIImagePickerControllerDelegate Methods
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        let theImage = info[UIImagePickerControllerOriginalImage] as! UIImage!
//        imageView.image = theImage
        validURL = true
        dismissViewControllerAnimated(true, completion: nil)
        if picture != nil {
            picture.removeAllTargets()
        }
        picture = PictureInput(image: theImage!)
        picture --> unsharpMask
        picture.processImage()
    }
    
    func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        dismissViewControllerAnimated(true, completion: nil)
    }
    

}
