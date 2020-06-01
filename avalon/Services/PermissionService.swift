//
//  PermissionService.swift
//  avalon
//
//  Created by James Williams on 07/05/2020.
//  Copyright © 2020 James Williams. All rights reserved.
//

import Foundation
import AVFoundation

class PermissionService {
	
	
	static func getPermissionStatus(for source: SourceType) -> SourcePermissionStatus {
		guard let mediaType = source.toMediaType() else {
			fatalError("This source does not equate to a media type that can be granted permissions.")
		}
		
		switch AVCaptureDevice.authorizationStatus(for: mediaType) {
			case .notDetermined:
				return .Idle
			case .restricted:
				return .Denied
			case .denied:
				return .Denied
			case .authorized:
				return .Allowed
			@unknown default:
				return .Denied
		}
	}
	
	static func requestPermission(for source: SourceType, cb: @escaping (SourcePermissionStatus) -> Void) {
		guard let mediaType = source.toMediaType() else {
			fatalError("This source does not equate to a media type that can be granted permissions.")
		}
		
		AVCaptureDevice.requestAccess(for: mediaType) { granted in
			cb(granted ? SourcePermissionStatus.Allowed : SourcePermissionStatus.Denied)
		}
	}
}
