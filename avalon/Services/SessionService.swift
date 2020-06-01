//
//  SessionService.swift
//  avalon
//
//  Created by James Williams on 07/05/2020.
//  Copyright © 2020 James Williams. All rights reserved.
//

import Foundation
import AVFoundation
import Promises
import SocketIO
import Alamofire
import UIKit

enum SessionStatus: String, Codable {
	case Idle = "Idle"
	case Ready = "Ready"
	case Loading = "Loading"
	case Recording = "Recording"
	case Stopped = "Stopped"
}

enum RecordingMode: String, Codable {
	case PiP = "PiP"
	case Facecam = "Facecam"
	case Screen = "Screen"
	
	func toQualityPreset() -> AVCaptureSession.Preset {
		switch self {
		case .PiP:
			return .medium
		case .Facecam:
			return .hd1280x720
		case .Screen:
			return .low
		}
	}
}

struct RecordingLayout: Codable {
	var pipPosition: CameraPosition
	var recordingMode: RecordingMode
}

struct Session: Codable {
	var id: UUID
	var code: String
	var status: SessionStatus
	var sources: [Source]
	var layout: RecordingLayout
	var createdAt: Date?
	var updatedAt: Date?
}

struct CommunicationError: Error {}

enum SessionConnectionStatus: String {
	case Connected = "Connected"
	case Disconnected = "Disconnected"
	case Connecting = "Connecting"
	case Failed = "Failed"
}

struct StartRecordingEvent: Codable {
	var type: String = "start"
	var targetTime: Date
}

class SessionService: NSObject, ObservableObject {
	
	static let BASE_URL = "https://jameswilliams.eu.ngrok.io/api"
	
	@Published var session: Session?
	@Published var connectionStatus: SessionConnectionStatus = .Disconnected
	
	@Published var conductorService: ConductorService = ConductorService()
	
	private let manager: SocketManager
	
	override init() {
		manager = SocketManager(socketURL: URL(string: "\(SessionService.BASE_URL)")!, config: [.log(true), .compress])
		super.init()
		conductorService.delegate = self
	}
	
	func new() {
		let socket = manager.defaultSocket
		createSession()
			.then { session in
				self.session = session
				print(session)
				self.handleConnectionStatus(socket: socket)
				socket.onAny(self.handleUpdate)
				socket.connect()
			}
			.catch { error in
				print(error.localizedDescription)
			}
	}
	
	func join(code: String) {
		let socket = manager.defaultSocket
		getSessionByCode(code: code)
			.then { session in
				self.session = session
				print(session)
				self.handleConnectionStatus(socket: socket)
				socket.onAny(self.handleUpdate)
				socket.connect()
			}
			.catch { error in
				print(error.localizedDescription)
			}
	}
	
	func handleConnectionStatus(socket: SocketIOClient) {
		socket.on(clientEvent: .connect) {_,_ in
			self.connectionStatus = .Connected

			guard let sessionId = self.session?.id.uuidString.lowercased() else { return }
			socket.emit("subscribeToUpdates", ["sessionId": sessionId])
		}
		
		socket.on(clientEvent: .disconnect) {_,_ in
			self.connectionStatus = .Disconnected
		}
		
		socket.on(clientEvent: .reconnect) {_,_ in
			self.connectionStatus = .Connected
		}
		
		socket.on(clientEvent: .reconnectAttempt) {_,_ in
			self.connectionStatus = .Connecting
		}
		
		socket.on(clientEvent: .error) {data,_ in
			self.connectionStatus = .Failed
			print(data)
		}
	}
	
	func handleUpdate(update: SocketAnyEvent) {
		switch update.event {
		case "sessionUpdated":
			sessionUpdated(with: update.items)
		case "sourceAdded":
			sourceAdded(with: update.items)
		case "startRecording":
			guard let recordingMode = session?.layout.recordingMode else { return }
			conductorService.start(with: recordingMode)
			session?.status = .Recording
		case "stopRecording":
			conductorService.stop()
			session?.status = .Stopped
		default:
			print("Unhandled event happened here.")
		}
	}
	
	func prepare() {
		guard let sources: [Source] = session?.sources, sources.count > 0 else { return }
		conductorService.prepare(sources: sources)
		session?.status = .Ready
	}
	
	func sessionUpdated(with data: [Any]?) {
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .formatted(DateFormatter.iso8601Full)

		guard let data = data?.first else { print("Cannot find data"); return }
		let session = try? decoder.decode(Session.self, from: JSONSerialization.data(withJSONObject: data))
		if let session = session {
			self.session = session
		}
	}
	
	func switchRecordingModes(to mode: RecordingMode) {
		session?.layout.recordingMode = mode
		conductorService.switchRecordingModes(to: mode)
		if (session?.status == .Recording) {
			conductorService.start(with: mode)
		}
	}
	
	func sourceAdded(with data: [Any]?) {
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .formatted(DateFormatter.iso8601Full)

		guard let data = data?.first else { print("Cannot find data"); return }
		print(data)
		let source = try? decoder.decode(Source.self, from: JSONSerialization.data(withJSONObject: data))
		if var source = source {
			source.origin.type = .Remote
			self.session?.sources.append(source)
		}
	}
		
	func createSession() -> Promise<Session> {
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .formatted(DateFormatter.iso8601Full)
		
		return Promise<Session> { resolve, reject in
			AF.request("\(SessionService.BASE_URL)/session", method: .post)
				.responseDecodable(of: Session.self, decoder: decoder) { response in
					switch response.result {
					case .success(let session):
						resolve(session)
					case let .failure(error):
						reject(error)
					}
				}
			.response { response in
				switch response.result {
				case .success(let session):
					print(String(bytes: session!, encoding: .ascii))
				case let .failure(error):
					print(error)
				}
			}
		}
	}
	
	func getSessionByCode(code: String) -> Promise<Session> {
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .formatted(DateFormatter.iso8601Full)

		return Promise<Session> { resolve, reject in
			AF.request("\(SessionService.BASE_URL)/session?code=\(code)", method: .get)
			.responseDecodable(of: Session.self, decoder: decoder) { response in
				switch response.result {
				case .success(let session):
					resolve(session)
				case let .failure(error):
					reject(error)
				}
			}
		}
	}
	
	func add(source: Source) -> Promise<Any?> {
		return Promise<Any?> { resolve, reject in
			var source = source
			source.status = .Enabled
			guard let sessionId = self.session?.id.uuidString.lowercased() else { reject(CommunicationError()); return }

			AF.request("\(SessionService.BASE_URL)/session/\(sessionId)/sources", method: .post, parameters: source, encoder: JSONParameterEncoder.default)
			.response { response in
				switch response.result {
				case .success:
					resolve(nil)
				case let .failure(error):
					reject(error)
				}
			}
		}
	}
	
	func remove(source: Source) -> Promise<Any?> {
		return Promise<Any?> { resolve, reject in
			guard let sessionId = self.session?.id.uuidString.lowercased() else { reject(CommunicationError()); return }

			AF.request("\(SessionService.BASE_URL)/session/\(sessionId)/sources", method: .delete, parameters: ["sessionId": sessionId], encoder: JSONParameterEncoder.default)
			.response { response in
				switch response.result {
				case .success:
					resolve(nil)
				case let .failure(error):
					reject(error)
				}
			}
		}
	}
	
	func askForStart() -> Promise<Any?> {
		return Promise<Any?> { resolve, reject in
			guard let sessionId = self.session?.id.uuidString.lowercased() else { reject(CommunicationError()); return }

			AF.request("\(SessionService.BASE_URL)/session/\(sessionId)/start", method: .post)
			.response { response in
				switch response.result {
				case .success:
					resolve(nil)
				case let .failure(error):
					reject(error)
				}
			}
		}
	}
	
	func askForEnd() -> Promise<Any?> {
		return Promise<Any?> { resolve, reject in
			guard let sessionId = self.session?.id.uuidString.lowercased() else { reject(CommunicationError()); return }

			AF.request("\(SessionService.BASE_URL)/session/\(sessionId)/stop", method: .post)
				.response { response in
					switch response.result {
					case .success:
						resolve(nil)
					case let .failure(error):
						reject(error)
					}
				}
				
		}
	}
	
	struct SignedURLResponse: Codable {
		let url: String
	}
	
	func getSignedUploadURL() -> Promise<SignedURLResponse> {
		return Promise<SignedURLResponse> { resolve, reject in
			AF.request("\(SessionService.BASE_URL)/session/upload", method: .get)
				.responseDecodable(of: SignedURLResponse.self) { response in
					switch response.result {
					case .success(let response):
						resolve(response)
					case let .failure(error):
						reject(error)
					}
				}
		}
	}
	
	func add(media: [Media]) -> Promise<Any?> {
		return Promise<Any?> { resolve, reject in
			guard let sessionId = self.session?.id.uuidString.lowercased() else { reject(CommunicationError()); return }

			AF.request("\(SessionService.BASE_URL)/session/\(sessionId)/media", method: .post, parameters: media, encoder: JSONParameterEncoder.default)
			.response { response in
				switch response.result {
				case .success:
					resolve(nil)
				case let .failure(error):
					reject(error)
				}
			}
		}
	}
}

extension SessionService: ConductorDelegate {
	func allMediaUploaded() {
		add(media: conductorService.medias)
	}
	
}
