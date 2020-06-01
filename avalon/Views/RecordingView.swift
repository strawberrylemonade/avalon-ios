//
//  RecordingView.swift
//  avalon
//
//  Created by James Williams on 10/05/2020.
//  Copyright © 2020 James Williams. All rights reserved.
//

import SwiftUI

struct RecordingView: View {
	@ObservedObject var sessionService: SessionService
	var body: some View {
		ZStack {
			PreviewView(sessionService: sessionService)
				.edgesIgnoringSafeArea(.all)
			HStack {
				Spacer()
				
				VStack {
					VStack {
						Button(action: { self.sessionService.switchRecordingModes(to: .Facecam) }) {
							Image("Headcam")
						}
						.buttonStyle(PlainButtonStyle())
						
						Button(action: { self.sessionService.switchRecordingModes(to: .PiP) }) {
							Image("PIP")
						}
						.buttonStyle(PlainButtonStyle())
						
						Button(action: { self.sessionService.switchRecordingModes(to: .Screen) }) {
							Image("Screen")
						}
						.buttonStyle(PlainButtonStyle())
					}
					.padding()
					
					Spacer()
					if sessionService.session?.status == SessionStatus.Recording {
						Button(action: { self.sessionService.askForEnd() }) {
							Text("Stop")
							.foregroundColor(.white)
						}
						.padding()
						.background(Color.red)
						.cornerRadius(5)
					}
					
					if sessionService.session?.status == SessionStatus.Ready {
						Button(action: { self.sessionService.askForStart() }) {
							Text("Start")
							.foregroundColor(.white)
						}
						.padding()
						.background(Color.red)
						.cornerRadius(5)
					}
				}
				.frame(maxWidth: 120)
			}
		}
	}
}

struct RecordingView_Previews: PreviewProvider {
	static var previews: some View {
		RecordingView(sessionService: SessionService())
			.previewLayout(.fixed(width: 896, height: 414))
			.background(Color.black)
	}
}
