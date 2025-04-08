//
//  Utils.swift
//  MonetStyleTransfer
//
//  Created by Barry Juans on 07/04/25.
//

import CoreML
import UIKit
import CoreGraphics
import Accelerate
import Vision

class MachineModel: ObservableObject {
    
    var coreMLRequest: VNCoreMLRequest? = nil
    let model: VNCoreMLModel?
    @Published var transformedImage: UIImage? = nil
    
    init() {
        model = try? VNCoreMLModel(for: fast_neural_style_transfer_starry_night().model)
    }
    
    func createRequest() -> VNCoreMLRequest? {
        if let model {
            let request = VNCoreMLRequest(model: model, completionHandler: { [weak self] request, error in
                guard let self else {
                    return
                }
                if let result = request.results?.first as? VNPixelBufferObservation {
                    print("Getting Image")
                    let pixelBuffer = result.pixelBuffer
                            
                    // Create a CIImage from the pixel buffer
                    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                    
                    // Create a CIContext to render the CIImage
                    let ciContext = CIContext(options: nil)
                    
                    // Render the CIImage to a CGImage
                    guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
                        DispatchQueue.main.async { [weak self] in
                            self?.transformedImage = nil
                            self?.coreMLRequest = nil
                        }
                        return
                    }
                    
                    // Create a UIImage from the CGImage
                    let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
                    DispatchQueue.main.async { [weak self] in
                        print("Process Image")
                        self?.transformedImage = image
                        self?.coreMLRequest = nil
                    }
                } else {
                    DispatchQueue.main.async { [weak self] in
                        print("Error in Request Results")
                        self?.transformedImage = nil
                        self?.coreMLRequest = nil
                    }
                }
            })
            
            return request
        } else {
            return nil
        }
    }
    
    func predict(image: UIImage){
        let ciimage = CIImage(image: image)
        if coreMLRequest == nil {
            coreMLRequest = createRequest()
        }
        guard let ciimage else {
            print("Nil ciimage")
            self.transformedImage = nil
            return
        }
        guard let coreMLRequest = self.coreMLRequest else {
            print("Nil coreMLReq")
            self.transformedImage = nil
            return
        }
        var handler: VNImageRequestHandler? = VNImageRequestHandler(ciImage: ciimage ,options: [:])
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else {
                return
            }
            let arr = [coreMLRequest]
            do {
                try handler?.perform(arr)
                handler = nil
            } catch {
                print("Error performing request: \(error)")
                DispatchQueue.main.async { [weak self] in
                    self?.transformedImage = nil
                }
            }
        }
    }
}
