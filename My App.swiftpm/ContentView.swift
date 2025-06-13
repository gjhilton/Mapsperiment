import SwiftUI
import SceneKit
import CoreImage

struct Place: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let description: String
}

struct ContentView: View {
    let places = [
        Place(name: "Mountain", description: "A beautiful mountain landscape with scenic views and hiking trails."),
        Place(name: "Lake", description: "A calm and peaceful lake surrounded by forests."),
        Place(name: "Desert", description: "A hot, dry desert with dunes and cacti."),
        Place(name: "City", description: "A bustling city filled with skyscrapers and energy.")
    ]
    
    @State private var selectedPlace: Place?
    @State private var resetCameraTrigger = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                MenuSceneView(
                    places: places,
                    onPlaceSelected: { selectedPlace = $0 },
                    resetCameraTrigger: $resetCameraTrigger
                )
                .ignoresSafeArea()
                
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            resetCameraTrigger.toggle()
                        } label: {
                            Image(systemName: "location.north.line.fill")
                                .padding()
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .padding()
                    }
                    Spacer()
                    Text("Tap a location to learn more")
                        .padding()
                        .background(.thinMaterial)
                        .cornerRadius(12)
                        .padding(.bottom, 40)
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { selectedPlace != nil },
                set: { if !$0 { selectedPlace = nil } }
            )) {
                if let place = selectedPlace {
                    DetailView(place: place)
                }
            }
        }
    }
}

struct DetailView: View {
    let place: Place
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(place.name)
                    .font(.largeTitle)
                    .bold()
                
                Text(place.description)
            }
            .padding()
        }
        .navigationTitle(place.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MenuSceneView: UIViewRepresentable {
    let places: [Place]
    var onPlaceSelected: (Place) -> Void
    @Binding var resetCameraTrigger: Bool
    
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        let scene = SCNScene()
        sceneView.scene = scene
        sceneView.allowsCameraControl = true
        sceneView.backgroundColor = UIColor.systemBackground
        
        // Camera
        let cameraNode = SCNNode()
        cameraNode.name = "camera"
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 5, 15)
        scene.rootNode.addChildNode(cameraNode)
        
        // Directional light (strong, shadow casting)
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .directional
        lightNode.light?.intensity = 2500
        lightNode.light?.castsShadow = true
        lightNode.light?.shadowMode = .deferred
        lightNode.light?.shadowSampleCount = 32
        lightNode.light?.shadowRadius = 5
        lightNode.position = SCNVector3(0, 10, 10)
        lightNode.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 4, 0)
        scene.rootNode.addChildNode(lightNode)
        
        // Ambient light (soft fill)
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = UIColor(white: 0.3, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLight)
        
        // Spotlight for drama (from above)
        let spotlightNode = SCNNode()
        spotlightNode.light = SCNLight()
        spotlightNode.light?.type = .spot
        spotlightNode.light?.color = UIColor.white
        spotlightNode.light?.intensity = 1500
        spotlightNode.light?.castsShadow = true
        spotlightNode.position = SCNVector3(0, 10, 0)
        spotlightNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        scene.rootNode.addChildNode(spotlightNode)
        
        // Folded map with parchment material
        let foldedMap = makeFoldedMap(width: 10, depth: 10, segments: 40)
        scene.rootNode.addChildNode(foldedMap)
        
        // Dot positions
        let positions: [SCNVector3] = [
            SCNVector3(-3, 0, -3),
            SCNVector3(3, 0, -3),
            SCNVector3(-3, 0, 3),
            SCNVector3(3, 0, 3)
        ]
        
        for (index, place) in places.enumerated() {
            let pos = positions[index]
            let y = mapY(at: pos.x, z: pos.z)
            
            // Dot: low cylinder 0.2 height, radius 0.6
            let dotGeometry = SCNCylinder(radius: 0.6, height: 0.2)
            dotGeometry.firstMaterial?.diffuse.contents = UIColor.systemRed
            
            let dot = SCNNode(geometry: dotGeometry)
            dot.name = place.name
            dot.position = SCNVector3(pos.x, y + Float(dotGeometry.height / 2), pos.z) // sits ON map
            scene.rootNode.addChildNode(dot)
            
            // Label setup
            
            // Text geometry - black, script font, no extrusion depth (flat)
            let fontName = "SnellRoundhand-Bold"
            let font = UIFont(name: fontName, size: 1.2) ?? UIFont.systemFont(ofSize: 1.2, weight: .bold)
            let textGeometry = SCNText(string: place.name, extrusionDepth: 0)
            textGeometry.font = font
            textGeometry.firstMaterial?.diffuse.contents = UIColor.black
            textGeometry.firstMaterial?.isDoubleSided = true
            textGeometry.firstMaterial?.readsFromDepthBuffer = true
            textGeometry.flatness = 0.1
            
            let textNode = SCNNode(geometry: textGeometry)
            textNode.scale = SCNVector3(0.4, 0.4, 0.4)
            textNode.castsShadow = false
            
            // Center text by bounding box
            let (minVec, maxVec) = textGeometry.boundingBox
            let textWidth = maxVec.x - minVec.x
            let textHeight = maxVec.y - minVec.y
            textNode.position = SCNVector3(-textWidth * 0.4 / 2 - minVec.x * 0.4, -textHeight * 0.4 / 2 - minVec.y * 0.4, 0.01)
            
            // Background rectangle behind text
            let padding: Float = 0.1
            let bgWidth = CGFloat(textWidth) * 0.4 + CGFloat(padding * 2)
            let bgHeight = CGFloat(textHeight) * 0.4 + CGFloat(padding * 2)
            let bgGeometry = SCNPlane(width: bgWidth, height: bgHeight)
            bgGeometry.cornerRadius = bgHeight * 0.2
            bgGeometry.firstMaterial?.diffuse.contents = UIColor.white
            bgGeometry.firstMaterial?.lightingModel = .constant
            bgGeometry.firstMaterial?.readsFromDepthBuffer = true
            
            let bgNode = SCNNode(geometry: bgGeometry)
            bgNode.position = SCNVector3(0, 0, 0)
            bgNode.castsShadow = false
            
            // Group label nodes
            let labelNode = SCNNode()
            labelNode.addChildNode(bgNode)
            labelNode.addChildNode(textNode)
            labelNode.position = SCNVector3(pos.x, y + 0.5 + Float(dotGeometry.height / 2), pos.z)
            
            // Billboard so label faces user on Y-axis only
            let billboardConstraint = SCNBillboardConstraint()
            billboardConstraint.freeAxes = [.Y]
            labelNode.constraints = [billboardConstraint]
            
            scene.rootNode.addChildNode(labelNode)
        }
        
        // Tap gesture
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        sceneView.addGestureRecognizer(tap)
        
        context.coordinator.sceneView = sceneView
        context.coordinator.places = places
        
        return sceneView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        if resetCameraTrigger {
            if let cam = uiView.scene?.rootNode.childNode(withName: "camera", recursively: true) {
                let move = SCNAction.move(to: SCNVector3(0, 5, 15), duration: 1.0)
                let rotate = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 1.0, usesShortestUnitArc: true)
                let group = SCNAction.group([move, rotate])
                cam.runAction(group)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPlaceSelected: onPlaceSelected)
    }
    
    func mapY(at x: Float, z: Float) -> Float {
        let width: Float = 10.0
        let xf = (x / width) + 0.5
        let freq: Float = 4.0
        let amp: Float = 0.2
        return sin(xf * .pi * freq) * amp
    }
    
    func makeFoldedMap(width: CGFloat, depth: CGFloat, segments: Int) -> SCNNode {
        var vertices: [SCNVector3] = []
        var indices: [UInt32] = []
        
        for z in 0...segments {
            for x in 0...segments {
                let xf = CGFloat(x) / CGFloat(segments)
                let zf = CGFloat(z) / CGFloat(segments)
                
                let posX = (xf - 0.5) * width
                let posZ = (zf - 0.5) * depth
                let y = sin(xf * .pi * 4.0) * 0.2
                
                vertices.append(SCNVector3(Float(posX), Float(y), Float(posZ)))
            }
        }
        
        for z in 0..<segments {
            for x in 0..<segments {
                let topLeft = UInt32(z * (segments + 1) + x)
                let topRight = topLeft + 1
                let bottomLeft = topLeft + UInt32(segments + 1)
                let bottomRight = bottomLeft + 1
                
                indices.append(contentsOf: [topLeft, bottomLeft, topRight])
                indices.append(contentsOf: [topRight, bottomLeft, bottomRight])
            }
        }
        
        let vertexSource = SCNGeometrySource(vertices: vertices)
        let indexData = Data(bytes: indices, count: indices.count * MemoryLayout<UInt32>.size)
        let element = SCNGeometryElement(data: indexData,
                                         primitiveType: .triangles,
                                         primitiveCount: indices.count / 3,
                                         bytesPerIndex: MemoryLayout<UInt32>.size)
        
        let geometry = SCNGeometry(sources: [vertexSource], elements: [element])
        geometry.firstMaterial = makeParchmentMaterial()
        
        return SCNNode(geometry: geometry)
    }
    
    func makeParchmentMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        let parchmentColor = UIColor(red: 0.95, green: 0.91, blue: 0.78, alpha: 1.0)
        
        // Noise texture overlay
        let noiseFilter = CIFilter(name: "CIRandomGenerator")!
        let colorFilter = CIFilter(name: "CIConstantColorGenerator", parameters: [kCIInputColorKey: CIColor(color: parchmentColor)])!
        
        let compositorFilter = CIFilter(name: "CISourceOverCompositing")!
        compositorFilter.setValue(colorFilter.outputImage, forKey: kCIInputBackgroundImageKey)
        compositorFilter.setValue(noiseFilter.outputImage, forKey: kCIInputImageKey)
        
        let context = CIContext()
        let outputImage = compositorFilter.outputImage!.cropped(to: CGRect(x: 0, y: 0, width: 256, height: 256))
        let cgImage = context.createCGImage(outputImage, from: outputImage.extent)!
        
        material.diffuse.contents = UIImage(cgImage: cgImage)
        material.isDoubleSided = true
        return material
    }
    
    class Coordinator: NSObject {
        weak var sceneView: SCNView?
        let onPlaceSelected: (Place) -> Void
        var places: [Place] = []
        
        init(onPlaceSelected: @escaping (Place) -> Void) {
            self.onPlaceSelected = onPlaceSelected
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let sceneView = sceneView else { return }
            let location = gesture.location(in: sceneView)
            let hitResults = sceneView.hitTest(location, options: [SCNHitTestOption.boundingBoxOnly: false])
            for result in hitResults {
                if let name = result.node.name {
                    if let place = places.first(where: { $0.name == name }) {
                        onPlaceSelected(place)
                        break
                    }
                }
            }
        }
    }
}
