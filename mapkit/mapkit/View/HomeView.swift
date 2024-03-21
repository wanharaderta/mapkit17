//
//  HomeView.swift
//  mapkit
//
//  Created by Wanhar on 19/03/24.
//

import SwiftUI
import MapKit

struct HomeView: View {
    
    // Map properties
    @State private var cameraPosition: MapCameraPosition = .region(.myRegion)
    @State private var mapSelection: MKMapItem?
    @Namespace private var locationSpace
    @State private var viewingRegion: MKCoordinateRegion?
    // Search
    @State private var searchText = ""
    @State private var showSearch = false
    @State private var searchResult: [MKMapItem] = []
    @State private var showDetails: Bool = false
    @State private var lookAroundScene: MKLookAroundScene?
    
    // Route Properties
    @State private var routeDisplaying: Bool = false
    @State private var route: MKRoute?
    @State private var routeDestination: MKMapItem?
    
    var body: some View {
        NavigationStack {
            Map(position: $cameraPosition, selection: $mapSelection, scope: locationSpace, content: {
                // Map Annotations
                Annotation("Jakarta", coordinate: .myLocation, content: {
                    ZStack {
                        Image(systemName: "house.fill")
                            .font(.title3)
                        Image(systemName: "square")
                            .font(.largeTitle)
                    }
                })
                .annotationTitles(.hidden)
                
                // Display Annotations as Marker
                ForEach(searchResult, id: \.self) { item in
                    if routeDisplaying {
                        if item == routeDestination {
                            let placemark = item.placemark
                            Marker(placemark.name ?? "Place", coordinate: placemark.coordinate)
                                .tint(.blue)
                        }
                    } else {
                        let placemark = item.placemark
                        Marker(placemark.name ?? "Place", coordinate: placemark.coordinate)
                            .tint(.blue)
                    }
                }
                
                // Display Route
                if let route {
                    MapPolyline(route.polyline)
                        .stroke(.blue, lineWidth: 7)
                }
                
                // To current location
                UserAnnotation()
            })
            .onMapCameraChange { ctx in
                viewingRegion = ctx.region
            }
            .overlay(alignment: .bottomTrailing, content: {
                VStack(spacing: 15) {
                    MapCompass(scope: locationSpace)
                    MapUserLocationButton(scope: locationSpace)
                    MapPitchToggle(scope: locationSpace)
                }
                .buttonBorderShape(.circle)
                .padding()
            })
            .mapScope(locationSpace)
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar(routeDisplaying ? .hidden : .visible, for: .navigationBar)
            // search
            .searchable(text: $searchText, isPresented: $showSearch)
            .sheet(isPresented: $showDetails, onDismiss: {
                withAnimation(.snappy) {
                    // Zooming Region
                    if let boundingRect = route?.polyline.boundingMapRect, routeDisplaying {
                        cameraPosition = .rect(boundingRect)
                    }
                }
            }, content: {
                MapDetails()
                    .presentationDetents([.height(300)])
                    .presentationBackgroundInteraction(.enabled(upThrough: .height(300)))
                    .presentationCornerRadius(25)
                    .interactiveDismissDisabled(true)
            })
            .safeAreaInset(edge: .bottom, content: {
                if routeDisplaying {
                    Button("End Route") {
                        // Closing the route
                        withAnimation(.snappy) {
                            routeDisplaying = false
                            showDetails = true
                            mapSelection = routeDestination
                            routeDestination = nil
                            route = nil
                            cameraPosition = .region(.myRegion)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.red.gradient, in: .rect(cornerRadius: 15))
                    .padding()
                    .background(.ultraThinMaterial)
                }
            })
        }
        .onSubmit(of: .search) {
            Task {
                guard !searchText.isEmpty else { return }
                await searchPlaces()
            }
        }
        .onChange(of: showSearch, initial: false) {
            if !showSearch {
                searchResult.removeAll(keepingCapacity: false)
                showDetails = false
                
                // Zooming out to user
                withAnimation(.snappy) {
                    cameraPosition = .region(.myRegion)
                }
            }
        }
        .onChange(of: mapSelection) { oldValue, newValue in
            showDetails = newValue != nil
            fetchLookAroundPreview()
        }
    }
    
    @ViewBuilder
    func MapDetails() -> some View {
        VStack(spacing: 15) {
            ZStack {
                if lookAroundScene == nil {
                    ContentUnavailableView("No Preview Available", image: "eye.slash")
                } else {
                    LookAroundPreview(scene: $lookAroundScene)
                }
            }
            .frame(height: 200)
            .clipShape(.rect(cornerRadius: 15))
            .overlay(alignment: .topTrailing, content: {
                Button(action: {
                    showDetails = false
                    withAnimation(.snappy) {
                        mapSelection = nil
                    }
                }, label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.black)
                        .background(.white, in: .circle)
                })
            })
            
            Button("Get Directions", action: fetchRoute)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.blue.gradient, in: .rect(cornerRadius: 15))
        }
        .padding(15)
    }
    
    // Search places
    func searchPlaces() async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.region = .myRegion
        
        let results = try? await MKLocalSearch(request: request).start()
        searchResult = results?.mapItems ?? []
    }
    
    // Fetch Location Preview
    func fetchLookAroundPreview() {
        if let mapSelection {
            lookAroundScene = nil
            Task {
                let request = MKLookAroundSceneRequest(mapItem: mapSelection)
                lookAroundScene = try? await request.scene
            }
        }
    }
    
    // Fetching Route
    func fetchRoute() {
        if let mapSelection {
            let request = MKDirections.Request()
            request.source = .init(placemark: .init(coordinate: .myLocation))
            request.destination = mapSelection
            
            Task {
                let results = try? await MKDirections(request: request).calculate()
                route = results?.routes.first
                
                routeDestination = mapSelection
                
                withAnimation(.snappy) {
                    routeDisplaying = true
                    showDetails = false
                    
                    if let boundingRect = route?.polyline.boundingMapRect {
                        cameraPosition = .rect(boundingRect)
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

extension CLLocationCoordinate2D {
    static var myLocation: CLLocationCoordinate2D {
        return .init(latitude: 37.3346, longitude: -122.0090)
    }
}

extension MKCoordinateRegion {
    static var myRegion: MKCoordinateRegion {
        return .init(center: .myLocation, latitudinalMeters: 10000, longitudinalMeters: 10000)
    }
}
