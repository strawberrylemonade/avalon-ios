//
//  ConductorService.swift
//  avalon
//
//  Created by James Williams on 13/05/2020.
//  Copyright © 2020 James Williams. All rights reserved.
//

import Foundation
import Promises
import Alamofire
import AVFoundation
import UIKit

enum MediaState: String, Codable {
	case Idle = "Idle"
	case Recording = "Recording"
	case Uploading = "Uploading"
	case Uploaded = "Uploaded"
	case Failed = "Failed"
}

struct Media: Codable, Identifiable {
	var id: UUID
	var uploadedUrl: URL?
	var localPath: URL
	var mode: RecordingMode
	var state: MediaState
	var progress: Double = 0
	
	var startTime: Int?
	var endTime: Int?
	var duration: Int?
}

protocol ConductorDelegate {
	func allMediaUploaded() -> Void
}

class ConductorService: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {
	@Published var medias: [Media] = []
	
	private var captureSession: AVCaptureSession?
	private var output: AVCaptureMovieFileOutput?
	private var globalStartTime: Int?
	
	var delegate: ConductorDelegate?
	
	func uploadMedia(media: Media) {
		AF.upload(media.localPath, to: "https://avalonvideo.s3.eu-west-2.amazonaws.com/videos/\(media.id.uuidString).mp4", method: .put)
		.uploadProgress { progress in
			self.mutate(media: media) { media in
				var m = media
				m.progress = progress.fractionCompleted
				return m
			}
		}
		.response { response in
			switch response.result {
			case .success(_):
				self.mutate(media: media) { media in
					var m = media
					m.uploadedUrl = URL(string: "https://avalonvideo.s3.eu-west-2.amazonaws.com/videos/\(media.id.uuidString).mp4")
					m.state = .Uploaded
					return m
				}
				self.isAllMediaUploaded()
			case let .failure(error):
				self.mutate(media: media) { media in
					var m = media
					m.state = .Failed
					return m
				}
				print(error)
			}
		}
	}
	
	func isAllMediaUploaded() {
		if medias.reduce(true, { isUploaded, media in
			if !isUploaded { return isUploaded }
			return media.state == .Uploaded
		}) {
			delegate?.allMediaUploaded()
		}
	}
	
	func prepare(sources: [Source]) {
		captureSession = AVCaptureSession()
		captureSession?.sessionPreset = .medium
		output = AVCaptureMovieFileOutput()
		
		sources.forEach { source in
			// Create the capture session.
			
			if (source.status == .Disabled) {
				return
			}
			
			// Find the default audio device.
			guard let captureSession = captureSession, let mediaType = source.type.toMediaType() else { return }
			guard let device = getCaptureDeviceForMedia(mediaType: mediaType) else { return }
			
			do {
				// Wrap the audio device in a capture device input.
				let input = try AVCaptureDeviceInput(device: device)
				
				// If the input can be added, add it to the session.
				if captureSession.canAddInput(input) {
					captureSession.addInput(input)
				}
								
			} catch {
				// Configuration failed. Handle error.
				print(error.localizedDescription)
			}
			
		}
		
		guard let captureSession = captureSession, let output = output else { return }

		if captureSession.canAddOutput(output) {
			captureSession.addOutput(output)
			let connection = output.connection(with: .video)
			connection?.videoOrientation = transformOrientation(orientation: UIApplication.shared.windows.first!.windowScene!.interfaceOrientation)
			output.setOutputSettings([AVVideoCodecKey: AVVideoCodecType.h264], for: connection!)
		}
		
		captureSession.startRunning()
	}
	
	func transformOrientation(orientation: UIInterfaceOrientation) -> AVCaptureVideoOrientation {
			switch orientation {
			case .landscapeLeft:
				return .landscapeLeft
			case .landscapeRight:
				return .landscapeRight
			case .portraitUpsideDown:
				return .portraitUpsideDown
			default:
				return .portrait
			}
	}
	
	func mutate(by url: URL, cb: @escaping (Media) -> Media) {
		self.medias = self.medias.map { m -> Media in
			if (m.localPath != url) {
				return m
			}
			
			return cb(m)
		}
	}
	
	func mutate(media: Media, cb: @escaping (Media) -> Media) {
		self.medias = self.medias.map { m -> Media in
			if (m.id != media.id) {
				return m
			}
			
			return cb(m)
		}
	}
	
	func switchRecordingModes(to mode: RecordingMode) {
		changeResolution(to: mode.toQualityPreset())
	}
	
	func changeResolution(to preset: AVCaptureSession.Preset) {
		captureSession?.sessionPreset = preset
	}
	
	func preview(view: UIView) {
    guard let captureSession = self.captureSession, captureSession.isRunning else { return }
		
		let preview = AVCaptureVideoPreviewLayer(session: captureSession)
		preview.videoGravity = AVLayerVideoGravity.resizeAspectFill
    preview.connection?.videoOrientation = transformOrientation(orientation: UIApplication.shared.windows.first!.windowScene!.interfaceOrientation)
    
    view.layer.insertSublayer(preview, at: 0)
    preview.frame = view.frame
	}
	
	func start(with mode: RecordingMode) {
		guard let output = output else { return }
		
		if globalStartTime == nil {
			globalStartTime = getCurrentMilliseconds()
		}

		let id = UUID()
		let path = NSTemporaryDirectory().appending(id.uuidString).appending(".mp4")
		let url = URL(fileURLWithPath: path)
				
		let media = Media(id: id, localPath: url, mode: mode, state: .Idle)
		medias.append(media)
		
		output.startRecording(to: url, recordingDelegate: self)
	}
	
	func stop() {
		captureSession?.stopRunning()
	}
	
	func getCaptureDeviceForMedia(mediaType: AVMediaType) -> AVCaptureDevice? {
		switch mediaType {
		case .audio:
			return AVCaptureDevice.default(for: .audio)
		case .video:
			let cap = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
			return cap
		default:
			return nil
		}
	}

	func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
		print("Recording has started.")
		mutate(by: fileURL) { media in
			var m = media
			m.startTime = self.getCurrentMilliseconds() - self.globalStartTime!
			m.state = .Recording
			return m
		}
	}
	
	func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
		mutate(by: outputFileURL) { media in
			var m = media
			m.endTime = self.getCurrentMilliseconds() - self.globalStartTime!
			m.duration = m.endTime! - m.startTime!
			m.state = .Uploading
			return m
		}
		
		guard let media = medias.first(where: { $0.localPath == outputFileURL }) else { print("Media not found?"); return }
		uploadMedia(media: media)
	}
	
	func getCurrentMilliseconds() -> Int {
		let n = Int(CACurrentMediaTime() * 1000)
		print(n)
		return n
	}
}
