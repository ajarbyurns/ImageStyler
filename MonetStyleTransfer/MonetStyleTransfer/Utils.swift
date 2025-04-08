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
    @Published var transformedImage: UIImage? = nil
    
    init() {
        if let model = try? VNCoreMLModel(for: fast_neural_style_transfer_starry_night().model) {
            self.coreMLRequest = VNCoreMLRequest(model: model, completionHandler: { request, error in
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
                        }
                        return
                    }
                    
                    // Create a UIImage from the CGImage
                    let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
                    DispatchQueue.main.async { [weak self] in
                        print("Process Image")
                        self?.transformedImage = image
                    }
                } else {
                    DispatchQueue.main.async { [weak self] in
                        print("Error in Request Results")
                        self?.transformedImage = nil
                    }
                }
            })
        } else {
            print("No Model")
        }
    }
    
    func predict(image: UIImage){
        let ciimage = CIImage(image: image)
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
        let handler = VNImageRequestHandler(ciImage: ciimage ,options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            let arr = [coreMLRequest]
            do {
                try handler.perform(arr)
            } catch {
                print("Error performing request: \(error)")
                DispatchQueue.main.async { [weak self] in
                    self?.transformedImage = nil
                }
            }
        }
    }
}
