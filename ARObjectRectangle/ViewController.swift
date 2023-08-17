//
//  ViewController.swift
//  ARObjectRectangle
//
//  Created by raykim on 2023/08/17.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {

    @IBOutlet var sceneView: ARSCNView!
    var boundingBoxView: UIView?
    var labelView: UILabel?

    lazy var yoloRequest: VNCoreMLRequest = {
        do {
            let model = try yolov8s().model
            let vnModel = try VNCoreMLModel(for: model)
            self.yoloRequest = VNCoreMLRequest(model: vnModel)
            self.yoloRequest.imageCropAndScaleOption = .scaleFit
            return self.yoloRequest
        } catch let error {
            fatalError("mlmodel error.")
        }
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.delegate = self
        sceneView.showsStatistics = true
        sceneView.debugOptions = .showBoundingBoxes
        sceneView.session.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let pixelBuffer = frame.capturedImage
        var ciImage = CIImage(cvPixelBuffer: pixelBuffer, options: [:])
        ciImage = ciImage.oriented(.right)
        let aspect =  sceneView.bounds.width / sceneView.bounds.height
        let estimateWidth = ciImage.extent.height * aspect
        let cropped = ciImage.cropped(to: CGRect(
            x: ciImage.extent.width / 2 - estimateWidth / 2,
            y: 0,
            width: estimateWidth,
            height: ciImage.extent.height
        ))
        let handler = VNImageRequestHandler(ciImage: cropped, options: [:])
        do {
            try handler.perform([yoloRequest])
            guard let result = yoloRequest.results?.first as? VNRecognizedObjectObservation else { return }
            drawBoundingBox(on: result)
        } catch let error {
            print(error)
        }
    }
    
    func drawBoundingBox(on observation: VNRecognizedObjectObservation) {
       DispatchQueue.main.async {
           let screenSize = self.sceneView.bounds.size
           let boundingBox = observation.boundingBox
           let origin = CGPoint(x: boundingBox.minX * screenSize.width, y: (1 - boundingBox.maxY) * screenSize.height)
           let size = CGSize(width: boundingBox.width * screenSize.width, height: boundingBox.height * screenSize.height)
           
           if self.boundingBoxView == nil {
               self.boundingBoxView = UIView()
               self.boundingBoxView?.backgroundColor = UIColor.red.withAlphaComponent(0.3)
               self.boundingBoxView?.layer.borderColor = UIColor.red.cgColor
               self.boundingBoxView?.layer.borderWidth = 2
               self.view.addSubview(self.boundingBoxView!)
           }
           self.boundingBoxView?.frame = CGRect(origin: origin, size: size)
           
           if self.labelView == nil {
               self.labelView = UILabel()
               self.labelView?.textColor = UIColor.red
               self.labelView?.backgroundColor = UIColor.white.withAlphaComponent(0.6)
               self.view.addSubview(self.labelView!)
           }
           self.labelView?.text = observation.labels.first?.identifier ?? ""
           self.labelView?.sizeToFit()
           self.labelView?.center = CGPoint(x: origin.x, y: origin.y - (self.labelView?.frame.height ?? 0) / 2)
       }
   }
}
