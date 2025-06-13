
import SwiftUI
import SceneKit

// MARK: - Model

struct Place: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let description: String
}

// MARK: - ContentView with Navigation

struct ContentView: View {
    let places = [
        Place(name: "Mountain", description: "A beautiful mountain landscape with scenic views and hiking trails."),
        Place(name: "Lake", description: "A calm and peaceful lake surrounded by forests."),
        Place(name: "Desert", description: "A hot, dry desert with dunes and cacti."),
        Place(name: "City", description: "A bustling city filled with skyscrapers and energy.")
    ]
    
    @State private var selectedPlace: Place?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // SceneKit Map View
                MenuSceneView(places: places) { tappedPlace in
                    selectedPlace = tappedPlace
                }
                .ignoresSafeArea()
                
                // Instruction Overlay
                VStack {
                    Spacer()
                    Text("Tap a location to learn more")
                        .padding()
                        .background(.thinMaterial)
                        .cornerRadius(12)
                        .padding(.bottom, 40)
                }
            }
            .navigationDestination(isPresented: Binding<Bool>(
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

// MARK: - DetailView

struct DetailView: View {
    let place: Place
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(place.name)
                    .font(.largeTitle)
                    .bold()
                
                Text(place.description)
                    .font(.body)
            }
            .padding()
        }
        .navigationTitle(place.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - SceneKit Menu View

struct MenuSceneView: UIViewRepresentable {
    let places: [Place]
    var onPlaceSelected: (Place) -> Void
    
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.scene = SCNScene()
        sceneView.allowsCameraControl = true
        sceneView.backgroundColor = UIColor.systemBackground
        
        let scene = sceneView.scene!
        
        // Camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 15)
        scene.rootNode.addChildNode(cameraNode)
        
        // Map Plane
        let mapNode = SCNNode(geometry: SCNPlane(width: 10, height: 10))
        mapNode.eulerAngles.x = -.pi / 2 // lay flat
        mapNode.geometry?.firstMaterial?.diffuse.contents = UIColor.tertiarySystemFill
        scene.rootNode.addChildNode(mapNode)
        
        // Dots for places
        let positions: [SCNVector3] = [
            SCNVector3(-3, 0.5, -3),
            SCNVector3(3, 0.5, -3),
            SCNVector3(-3, 0.5, 3),
            SCNVector3(3, 0.5, 3)
        ]
        
        for (index, place) in places.enumerated() {
            let dot = SCNNode(geometry: SCNSphere(radius: 0.4))
            dot.geometry?.firstMaterial?.diffuse.contents = UIColor.systemRed
            dot.position = positions[index]
            dot.name = place.name
            scene.rootNode.addChildNode(dot)
        }
        
        // Tap gesture recognizer
        let tapRecognizer = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        sceneView.addGestureRecognizer(tapRecognizer)
        
        context.coordinator.sceneView = sceneView
        context.coordinator.places = places
        
        return sceneView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPlaceSelected: onPlaceSelected)
    }
    
    // MARK: Coordinator to handle taps
    
    class Coordinator: NSObject {
        var onPlaceSelected: (Place) -> Void
        weak var sceneView: SCNView?
        var places: [Place] = []
        
        init(onPlaceSelected: @escaping (Place) -> Void) {
            self.onPlaceSelected = onPlaceSelected
        }
        
        @objc func handleTap(_ gestureRecognizer: UIGestureRecognizer) {
            guard let sceneView = sceneView else { return }
            let location = gestureRecognizer.location(in: sceneView)
            let hitResults = sceneView.hitTest(location, options: nil)
            if let result = hitResults.first,
               let nodeName = result.node.name,
               let tappedPlace = places.first(where: { $0.name == nodeName }) {
                onPlaceSelected(tappedPlace)
            }
        }
    }
}
