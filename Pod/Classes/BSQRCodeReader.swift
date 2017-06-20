//
//  BSQRCodeReader.swift
//  v1.0.0
//  This plugin is created to read QR Code inside your app.
//  BSQRCodeReader is inherited from UIView so you can use your own page design and
//  include this reader to be part of your layout.
//
//  Created by Bobby Stenly Irawan (iceman.bsi@gmail.com) on 4/12/16.
//  for more information please visit https://github.com/icemanbsi/BSQRCodeReader
//

import Foundation
import UIKit
import AVFoundation

public protocol BSQRCodeReaderDelegate {
    func didFailWithError(_ error: NSError)
    func didCaptureQRCodeWithContent(_ content: String) -> Bool
    func beforeStartScanning(_ reader: BSQRCodeReader)
    func afterStopScanning(_ reader: BSQRCodeReader)
}

public extension BSQRCodeReaderDelegate {
    func didFailWithError(_ error: NSError) { }
    func didCaptureQRCodeWithContent(_ content: String) -> Bool { return true }
    func beforeStartScanning(_ reader: BSQRCodeReader) { }
    func afterStopScanning(_ reader: BSQRCodeReader) { }
}

open class BSQRCodeReader: UIView, AVCaptureMetadataOutputObjectsDelegate {
    
    // -- public attributes
    open var delegate: BSQRCodeReaderDelegate?
    open var scanSize = 200
    
    // -- public attributes
    var captureSession: AVCaptureSession = AVCaptureSession()
    var captureDevice: AVCaptureDevice? = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
    var deviceInput: AVCaptureDeviceInput?
    var metadataOutput: AVCaptureMetadataOutput = AVCaptureMetadataOutput()
    var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    var qrCodeFrameView:UIView?
    var scanRec:CGRect?
    
    required public override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
    }
    
    fileprivate func setup(){
        let preset = AVCaptureSessionPresetHigh
        if self.captureSession.canSetSessionPreset(preset) {
            self.captureSession.sessionPreset = preset
        }
        self.videoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
        self.videoPreviewLayer.frame = self.bounds
        
        do {
            self.deviceInput = try AVCaptureDeviceInput(device: self.captureDevice)
        } catch let error as NSError {
            if let delegate = self.delegate {
                delegate.didFailWithError(error)
            }
            return
        }
        
        if let captureInput = self.deviceInput {
            self.captureSession.addInput(captureInput)
        }
        
        self.metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        self.captureSession.addOutput(self.metadataOutput)
        
        self.metadataOutput.metadataObjectTypes = self.metadataOutput.availableMetadataObjectTypes
        
        self.videoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        self.layer.addSublayer(self.videoPreviewLayer)
        
        self.updateVideoOrientation(UIApplication.shared.statusBarOrientation)
    }
    
    fileprivate func updateVideoOrientation(_ orientation:UIInterfaceOrientation){
        
        switch orientation {
        case .portrait :
            videoPreviewLayer.connection?.videoOrientation = .portrait
            break
        case .portraitUpsideDown :
            videoPreviewLayer.connection?.videoOrientation = .portraitUpsideDown
            break
        case .landscapeLeft :
            videoPreviewLayer.connection?.videoOrientation = .landscapeLeft
            break
        case .landscapeRight :
            videoPreviewLayer.connection?.videoOrientation = .landscapeRight
            break
        default:
            videoPreviewLayer.connection?.videoOrientation = .portrait
        }
    }
    
    
    open func startScanning() {
        self.captureSession.startRunning()
        
        if scanRec != nil {
            let visibleRect = videoPreviewLayer.metadataOutputRectOfInterest(for: scanRec!)
            metadataOutput.rectOfInterest = visibleRect
        } else {
            print("scanrec not defined, add the addBorders attribute")
        }
        
    }
    
    open func stopScanning() {
        self.captureSession.stopRunning()
    }
    
    open func addBorders() {
        //added border box, the camera will only scan the inside of the box
        let frameSize = self.superview?.frame.size
        let screenWidth = super.superview?.frame.size.width
        let screenHeight = super.superview?.frame.size.height
        let size = self.scanSize
        let xPos = (CGFloat(screenWidth!) / CGFloat(2)) - (CGFloat(size) / CGFloat(2))
        let yPos = (CGFloat(screenHeight!) / CGFloat(2)) - (CGFloat(size) / CGFloat(2))
        self.scanRec = CGRect(x: Int(xPos), y: Int(yPos), width: size, height: size)
        
        let shapeLayer:CAShapeLayer = CAShapeLayer()
        
        shapeLayer.bounds = self.scanRec!
        shapeLayer.position = CGPoint(x: (frameSize?.width)!/2, y: (frameSize?.height)!/2)
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = UIColor.white.cgColor
        shapeLayer.lineWidth = 2
        shapeLayer.lineJoin = kCALineJoinRound
        shapeLayer.lineDashPattern = [6,3]
        shapeLayer.path = UIBezierPath(roundedRect: self.scanRec!, cornerRadius: 5).cgPath
        self.superview?.layer.addSublayer(shapeLayer)
    }
    
    
    // -- MARK : AVCaptureMetadataOutputObjectsDelegate
    open func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [Any]!, from connection: AVCaptureConnection!) {
        
        var detectionString:String?
        
        for metadata in metadataObjects {
            if let metadataObject = metadata as? AVMetadataObject {
                
                if (metadataObject.type == AVMetadataObjectTypeQRCode) {
                    if let machineReadableObject = metadataObject as? AVMetadataMachineReadableCodeObject {
                        detectionString = machineReadableObject.stringValue
                    }
                }
                
                if let qrCodeContent = detectionString {
                    self.stopScanning()
                    if let delegate = self.delegate {
                        if !delegate.didCaptureQRCodeWithContent(qrCodeContent) {
                            self.startScanning()
                        }
                    }
                    return
                }
            }
        }
        
    }
}
