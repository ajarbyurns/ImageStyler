//
//  CameraView.swift
//  MonetStyleTransfer
//
//  Created by Barry Juans on 07/04/25.
//

import SwiftUI
import AVFoundation

class UIImageWrapper: ObservableObject {
    @Published var image: UIImage?
}

struct CameraView: View {
    @StateObject private var imageWrapper = UIImageWrapper()
    @State private var isCameraAvailableAndAuthorized = false

    var body: some View {
        VStack {
            if isCameraAvailableAndAuthorized {
                if imageWrapper.image == nil {
                    CameraPreview()
                        .edgesIgnoringSafeArea(.all)
                } else {
                    ImageDetailView()
                }
            } else {
                Text("Camera is not available or authorized")
            }
        }
        .onAppear {
            checkCameraAvailabilityAndAuthorization()
        }
        .environmentObject(imageWrapper)
    }
    
    func checkCameraAvailabilityAndAuthorization() {
        let cameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)
        var cameraAuthorized = false
        
        if cameraAvailable {
            print("Camera is available")
            
            // Check camera authorization
            let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
            
            switch authorizationStatus {
            case .authorized:
                self.isCameraAvailableAndAuthorized = true
            case .denied:
                self.isCameraAvailableAndAuthorized = false
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    if granted {
                        cameraAuthorized = true
                    } else {
                        cameraAuthorized = false
                    }
                    self.isCameraAvailableAndAuthorized = cameraAvailable && cameraAuthorized
                }
            case .restricted:
                self.isCameraAvailableAndAuthorized = false
            @unknown default:
                self.isCameraAvailableAndAuthorized = false
                print("Unknown camera authorization status")
            }
        }
    }
}

struct CameraPreview: View {
    @EnvironmentObject var imageWrapper: UIImageWrapper
    @State private var captureSession: AVCaptureSession?
    @State private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    @State private var isCapturing = false
    @State private var photoCaptureDelegate: PhotoCaptureDelegate?

    var body: some View {
        ZStack {
            if let videoPreviewLayer = videoPreviewLayer {
                VideoPreviewLayerView(videoPreviewLayer: videoPreviewLayer)
                    .edgesIgnoringSafeArea(.all)
                if isCapturing {
                    ActivityIndicator()
                }
            }

            VStack {
                Spacer()
                Button(action: {
                    self.takePhoto()
                }) {
                    Text("Take Photo")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
                .disabled(isCapturing)
            }
            .background(.clear)
        }
        .onAppear {
            self.setupCamera()
        }
        .onDisappear {
            self.teardownCamera()
        }
    }

    func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo

        guard let backCamera = AVCaptureDevice.default(for: .video) else {
            return
        }
        
        guard let captureSession else {
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            captureSession.addInput(input)
        } catch {
            print("Error setting up camera input: \(error)")
            return
        }

        let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer.videoGravity = .resizeAspectFill
        self.videoPreviewLayer = videoPreviewLayer

        DispatchQueue.global().async {
            captureSession.startRunning()
        }
    }

    func teardownCamera() {
        captureSession?.stopRunning()
        videoPreviewLayer?.removeFromSuperlayer()
        videoPreviewLayer = nil
        captureSession = nil
    }

    func takePhoto() {
        guard let captureSession = captureSession else {
            return
        }
        
        isCapturing = true

        let photoOutput = AVCapturePhotoOutput()
        captureSession.addOutput(photoOutput)

        let photoSettings = AVCapturePhotoSettings()
        photoSettings.photoQualityPrioritization = .balanced

        photoCaptureDelegate = PhotoCaptureDelegate { image in
            captureSession.stopRunning()
            DispatchQueue.main.async {
                self.isCapturing = false
                self.imageWrapper.image = image
                self.photoCaptureDelegate = nil
            }
        }

        photoOutput.capturePhoto(with: photoSettings, delegate: photoCaptureDelegate!)
    }
}

struct VideoPreviewLayerView: UIViewRepresentable {
    let videoPreviewLayer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        videoPreviewLayer.frame = view.bounds
        videoPreviewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(videoPreviewLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        videoPreviewLayer.frame = UIScreen.main.bounds
    }
}

class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    let callback: (UIImage) -> Void

    init(callback: @escaping (UIImage) -> Void) {
        self.callback = callback
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
            return
        }

        if let imageData = photo.fileDataRepresentation() {
            if let image = UIImage(data: imageData) {
                callback(image)
            }
        }
    }
}

struct ImageDetailView: View {
    @EnvironmentObject var imageWrapper: UIImageWrapper
    @StateObject var model: MachineModel = MachineModel()

    var body: some View {
        VStack {
            GeometryReader { geo in
                if let _ = imageWrapper.image {
                    if let transformedImage = model.transformedImage {
                        Image(uiImage: transformedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geo.size.width, height: geo.size.height)
                    } else {
                        ActivityIndicator()
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                } else {
                    Text("No Image Available")
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    self.imageWrapper.image = nil
                } label: {
                    HStack {
                        Text("Retake Photo")
                    }
                }
            }
        }
        .onAppear() {
            transformImage()
        }
    }
    
    func transformImage() {
        if let img = imageWrapper.image {
            model.predict(image: img)
        } else {
            self.imageWrapper.image = nil
        }
    }
}

struct ActivityIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.2)
            .stroke(Color.blue, lineWidth: 5)
            .frame(width: 50, height: 50)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false))
            .onAppear {
                self.isAnimating = true
            }
    }
}
