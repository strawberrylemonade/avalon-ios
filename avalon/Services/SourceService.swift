//
//  SourceService.swift
//  avalon
//
//  Created by James Williams on 07/05/2020.
//  Copyright © 2020 James Williams. All rights reserved.
//

import Foundation
import AVFoundation
import Photos

class SourceService: ObservableObject {
	
	@Published var sources: [Source] = []
	var captureSession: AVCaptureSession?
	var output: AVCaptureMovieFileOutput?
	
	let rawSources: [SourceType] = [.Camera, .Microphone]
	let localOrigin: Origin = Origin(type: .Local, name: "This iPhone")
	
	init() {
		self.sources = rawSources.map { rawSource in
			let permission = PermissionService.getPermissionStatus(for: rawSource)
			return Source(id: UUID().uuidString.lowercased(), type: rawSource, name: rawSource.toName(), permissionStatus: permission, status: .Disabled, origin: self.localOrigin)
		}
	}
	
	func requestPermission(for source: Source) {
		PermissionService.requestPermission(for: source.type) { permissionStatus in
			DispatchQueue.main.async {
				self.mutate(source: source) { s in
					var m = s
					m.permissionStatus = permissionStatus
					return m
				}
			}
		}
	}
	
	func enable(source: Source) {
		mutate(source: source) { s in
			var m = s
			m.status = SourceStatus.Enabled
			return m
		}
	}
	
	func disable(source: Source) {
		mutate(source: source) { s in
			var m = s
			m.status = SourceStatus.Disabled
			return m
		}
	}
	
	func mutate(source: Source, cb: @escaping (Source) -> Source) {
		self.sources = self.sources.map { s -> Source in
			if (s.id != source.id) {
				return s
			}
			
			return cb(s)
		}
	}
	
}
