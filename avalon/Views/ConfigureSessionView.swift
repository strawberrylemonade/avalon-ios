//
//  ConfigureSessionView.swift
//  avalon
//
//  Created by James Williams on 10/05/2020.
//  Copyright © 2020 James Williams. All rights reserved.
//

import SwiftUI

struct ConfigureSessionView: View {
	@ObservedObject var sourceService: SourceService
	@ObservedObject var sessionService: SessionService

	var body: some View {
			HStack {
				VStack {
					Header(sessionCode: sessionService.session?.code)
					SourceList(sourceService: sourceService, sessionService: sessionService)
				}

				Sidebar(sourceService: sourceService, sessionService: sessionService)
			}
	}
}

struct ConfigureSessionView_Previews: PreviewProvider {
	static var previews: some View {
		ConfigureSessionView(sourceService: SourceService(), sessionService: SessionService())
	}
}

struct ActivityIndicator: UIViewRepresentable {

    typealias UIView = UIActivityIndicatorView
    var isAnimating: Bool
		var configuration = { (indicator: UIView) in }

    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIView { UIView() }
    func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<Self>) {
        isAnimating ? uiView.startAnimating() : uiView.stopAnimating()
        configuration(uiView)
    }
}

extension View where Self == ActivityIndicator {
    func configure(_ configuration: @escaping (Self.UIView)->Void) -> Self {
        Self.init(isAnimating: self.isAnimating, configuration: configuration)
    }
}

enum CameraPosition: String, CaseIterable, Codable {
	case TopLeft = "TopLeft"
	case BottomLeft = "BottomLeft"
	case TopRight = "TopRight"
	case BottomRight = "BottomRight"
}

struct Sidebar: View {
	@ObservedObject var sourceService: SourceService
	@ObservedObject var sessionService: SessionService
	@State var cameraPosition: CameraPosition = .TopLeft
	
	var body: some View {
		VStack {
			VStack(alignment: .leading, spacing: 15) {
				VStack(alignment: .leading, spacing: 5) {
					Text("Camera position")
						.font(.subheadline)
					HStack {
						ForEach(CameraPosition.allCases, id: \.self) { (position: CameraPosition) in
							Button(action: { self.cameraPosition = position }) {
								Image(position.rawValue)
									.opacity(self.cameraPosition == position ? 1 : 0.3)
							}
							.buttonStyle(PlainButtonStyle())
						}
					}
				}
				
				VStack(alignment: .leading, spacing: 5) {
					Text("Sync status")
						.font(.subheadline)
					
					HStack {
						Text("Avalon Server")
						Text(sessionService.connectionStatus.rawValue)
					}
					.font(.subheadline)
				}
				Spacer()
			}
			
			Button(action: { self.sessionService.prepare() }) {
				Text("Ready")
				.foregroundColor(.blue)
			}
			.padding()
			.background(Color.blue.opacity(0.2))
			.cornerRadius(5)

		}
		.padding()
	}
}

struct Header: View {
	var sessionCode: String?
	var body: some View {
		HStack {
			VStack(alignment: .leading) {
				Text("Project Avalon")
					.font(.title)
					.fontWeight(.bold)
				Text("Remote, cross-device recording")
					.font(.subheadline)
			}
			Spacer()
			VStack(alignment: .trailing) {
				Text("Connection code")
					.font(.subheadline)
				if (sessionCode != nil) {
					Text(sessionCode!)
					.font(.title)
					.fontWeight(.bold)
				} else {
					ActivityIndicator(isAnimating: true)
				}
			}
			.foregroundColor(.blue)
		}
		.padding()
	}
}

func filterForRemoteSources(allSources: [Source]?, localSources:[Source]?) -> [Source] {
	if allSources == nil || localSources == nil { return [] }
	return allSources!.filter { source in
		return localSources!.first(where: {
			$0.id == source.id
		}) == nil
	}
}

struct SourceList: View {
	@ObservedObject var sourceService: SourceService
	@ObservedObject var sessionService: SessionService
	
	var body: some View {
		ScrollView {
			VStack {
				ForEach(sourceService.sources) { source in
					SourceView(source: source, sourceService: self.sourceService, sessionService: self.sessionService)
				}
				ForEach(filterForRemoteSources(allSources: sessionService.session?.sources, localSources: sourceService.sources)) { source in
					SourceView(source: source, sourceService: self.sourceService, sessionService: self.sessionService)
				}
				Spacer()
			}
			.padding()
		}
	}
}


struct SourceView: View {
	var source: Source
	var sourceService: SourceService
	var sessionService: SessionService
	
	var body: some View {
		HStack(spacing: 10) {
			HStack {
				source.type.toImage()
				Spacer()
				if (source.origin.type == SourceOrigin.Remote) {
					HStack(spacing: 5) {
						Text("\(source.name) from")
						Text("\(source.origin.name)")
						.bold()
					}
				}
								
				if source.origin.type == SourceOrigin.Local {
					if source.status == SourceStatus.Disabled {
						if source.permissionStatus == SourcePermissionStatus.Idle {
							Text("No \(source.name.lowercased()) access")
						}

						if source.permissionStatus == SourcePermissionStatus.Allowed {
							Text("Access to \(source.name.lowercased()) granted")
						}

						if source.permissionStatus == SourcePermissionStatus.Denied {
							Text("Denied \(source.name.lowercased()) access")
						}
					} else {
						Text("\(source.name) active")
					}
				}
				
				Spacer()
			}
			.font(.subheadline)
			.padding()
			.foregroundColor(source.status == SourceStatus.Enabled ? .blue : .primary)
			.background(Color.init(.systemGray6))
			.cornerRadius(5)
			
			if (source.origin.type == SourceOrigin.Local) {
				if source.permissionStatus == SourcePermissionStatus.Idle {
					Button(action: { self.sourceService.requestPermission(for: self.source) }) {
						Text("Allow")
					}
					.padding()
					.background(Color.blue.opacity(0.2))
					.cornerRadius(5)
				}
				
				if source.permissionStatus == SourcePermissionStatus.Pending {
					Button(action: {  }) {
						ActivityIndicator(isAnimating: true)
					}
					.padding()
					.background(Color.blue.opacity(0.2))
					.cornerRadius(5)
				}
				
				if source.permissionStatus == SourcePermissionStatus.Allowed {
					
					if source.status == .Enabled {
						Button(action: {
							self.sourceService.disable(source: self.source)
							self.sessionService.remove(source: self.source)
						}) {
							Text("Disable")
						}
						.padding()
						.background(Color.blue.opacity(0.2))
						.cornerRadius(5)
					} else {
						Button(action: {
							self.sourceService.enable(source: self.source)
							self.sessionService.add(source: self.source)
						}) {
							Text("Enable")
						}
						.padding()
						.background(Color.blue.opacity(0.2))
						.cornerRadius(5)
					}
				}
				
			}
		}
	}
}

