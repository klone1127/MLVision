//
//  ViewController.swift
//  MLVision
//
//  Created by jgrm on 2017/6/16.
//  Copyright © 2017年 klone1127. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    var resultLabel: UILabel?
    var cameraView: UIView?
    private var requests = [VNRequest]()
    private lazy var cameraLayer: AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
    
    // captureSession
    private lazy var captureSession: AVCaptureSession = {
        let session = AVCaptureSession()
        session.sessionPreset = AVCaptureSession.Preset.photo
        guard
            let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: backCamera)
        else  { return session}
        session.addInput(input)
        return session
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.loadCameraView()
        self.loadCameraLayer()
        self.loadResultLabel()
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "MLVisionQueue"))
        self.captureSession.addOutput(videoOutput)
        self.captureSession.startRunning()
        self.setupVision()
    }
    
    func loadCameraView() {
        self.cameraView = UIView(frame: self.view.bounds)
        self.view.addSubview(self.cameraView!)
    }
    
    func loadCameraLayer() {
        self.cameraLayer.frame = (self.cameraView?.frame)!
        self.cameraLayer.videoGravity = .resizeAspectFill
        self.cameraView?.layer.addSublayer(self.cameraLayer)
    }
    
    func loadResultLabel() {
        let h: CGFloat = 150.0
        let w: CGFloat = UIScreen.main.bounds.size.width
        let y: CGFloat = UIScreen.main.bounds.size.height - h
        self.resultLabel = UILabel(frame: CGRect(x: 0, y: y, width: w, height: h))
        self.resultLabel?.numberOfLines = 0
        self.resultLabel?.font = UIFont.systemFont(ofSize: 15.0)
        self.resultLabel?.textColor = .white
        self.resultLabel?.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        self.view.insertSubview(self.resultLabel!, aboveSubview: self.cameraView!)
    }
    
    func setupVision() {
        guard let visionModel = try? VNCoreMLModel(for: Inceptionv3().model) else {
            fatalError("无法加载模型")
        }
        let classificationRequest = VNCoreMLRequest(model: visionModel, completionHandler: handleClassifications)
        classificationRequest.imageCropAndScaleOption = VNImageCropAndScaleOptionCenterCrop
        self.requests = [classificationRequest]
    }
    
    func handleClassifications(request: VNRequest, error: Error?) {
        print("\(String(describing: request.results))")
        guard let results = request.results else {
            print("no result: \(String(describing: error))")
            return
        }
        
        let classifications = results[0...2]
            .flatMap({ $0 as? VNClassificationObservation })
            .filter({ $0.confidence > 0.3 })
            .map({ $0.identifier })
        
        DispatchQueue.main.async {
            self.resultLabel?.text = classifications.joined(separator: "\n")
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        var requestOptions:[VNImageOption: Any] = [:]
        if let cameraIntrinsicData = CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil) {
            requestOptions = [.cameraIntrinsics:cameraIntrinsicData]
        }
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: 1, options: requestOptions)
        do {
            try imageRequestHandler.perform(self.requests)
        } catch {
            print(error)
        }
    }
    
}

