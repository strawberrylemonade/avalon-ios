//
//  Source.swift
//  avalon
//
//  Created by James Williams on 07/05/2020.
//  Copyright © 2020 James Williams. All rights reserved.
//

import Foundation
import AVFoundation
import SwiftUI

enum SourceType: String, Codable {
	case Camera = "Camera"
	case Microphone = "Microphone"
	case Screen = "Screen"
	
	func toMediaType() -> AVMediaType? {
		switch self {
		case .Camera:
			return .video
		case .Microphone:
			return .audio
		case .Screen:
			return nil
		}
	}
	
	func toName() -> String {
		switch self {
		case .Camera:
			return "Camera"
		case .Microphone:
			return "Microphone"
		case .Screen:
		  return "Screen share"
		}
	}
	
	func toImage() -> Image {
		switch self {
		case .Camera:
			return Image(systemName: "video.fill")
		case .Microphone:
			return Image(systemName: "mic.fill")
		case .Screen:
		  return Image(systemName: "rectangle.on.rectangle")
		}
	}
}

enum SourcePermissionStatus: String, Codable {
	case Idle = "Idle"
	case Pending = "Pending"
	case Allowed = "Allowed"
	case Denied = "Denied"
}

enum SourceOrigin: String, Codable {
	case Local = "Local"
	case Remote = "Remote"
}

struct Origin: Codable {
	var type: SourceOrigin
	var name: String
}

enum SourceStatus: String, Codable {
	case Enabled = "Enabled"
	case Disabled = "Disabled"
}

struct Source: Identifiable, Codable {
	var id: String
	var type: SourceType
	var name: String
	var permissionStatus: SourcePermissionStatus?
	var status: SourceStatus
	var origin: Origin
	var updatedAt: Date?
	var createdAt: Date?
	var sessionId: String?
}

