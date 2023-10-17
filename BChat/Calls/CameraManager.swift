import Foundation
import AVFoundation
import BChatUtilitiesKit

@objc
protocol CameraManagerDelegate : AnyObject {
    
    func handleVideoOutputCaptured(sampleBuffer: CMSampleBuffer)
}

final class CameraManager : NSObject {
    private let captureSession = AVCaptureSession()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let videoDataOutputQueue
        = DispatchQueue(label: "CameraManager.videoDataOutputQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    private let audioDataOutput = AVCaptureAudioDataOutput()
    private var isCapturing = false
    weak var delegate: CameraManagerDelegate?
    
    private var videoCaptureDevice: AVCaptureDevice?
    private var videoInput: AVCaptureDeviceInput?
    
    func prepare() {
        print("[Calls] Preparing camera.")
        addNewVideoIO(position: .front)
    }
    
    private func addNewVideoIO(position: AVCaptureDevice.Position) {
        if let videoCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
            let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice), captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
            self.videoCaptureDevice = videoCaptureDevice
            self.videoInput = videoInput
        }
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
            videoDataOutput.videoSettings = [ kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32BGRA) ]
            videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
            guard let connection = videoDataOutput.connection(with: AVMediaType.video) else { return }
            connection.videoOrientation = .portrait
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = (position == .front)
        } else {
            SNLog("Couldn't add video data output to capture bchat.")
        }
    }
    
    func start() {
        guard !isCapturing else { return }
        print("[Calls] Starting camera.")
        isCapturing = true
        captureSession.startRunning()
    }
    
    func stop() {
        guard isCapturing else { return }
        print("[Calls] Stopping camera.")
        isCapturing = false
        captureSession.stopRunning()
    }
    
    func switchCamera() {
        guard let videoCaptureDevice = videoCaptureDevice, let videoInput = videoInput else { return }
        stop()
        if videoCaptureDevice.position == .front {
            captureSession.removeInput(videoInput)
            captureSession.removeOutput(videoDataOutput)
            addNewVideoIO(position: .back)
        } else {
            captureSession.removeInput(videoInput)
            captureSession.removeOutput(videoDataOutput)
            addNewVideoIO(position: .front)
        }
        start()
    }
}

extension CameraManager : AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard connection == videoDataOutput.connection(with: .video) else { return }
        delegate?.handleVideoOutputCaptured(sampleBuffer: sampleBuffer)
    }
    
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        print("[Calls] Frame dropped.")
    }
}
