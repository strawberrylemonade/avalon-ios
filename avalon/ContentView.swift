//
//  ContentView.swift
//  avalon
//
//  Created by James Williams on 07/05/2020.
//  Copyright © 2020 James Williams. All rights reserved.
//

import SwiftUI

struct ContentView: View {
	@ObservedObject var sessionService = SessionService()
	@ObservedObject var sourceService = SourceService()


	var body: some View {
		
		if sessionService.session == nil {
			return AnyView(CreateOrJoinSessionView(sessionService: sessionService))
		}
		
		if sessionService.session?.status == SessionStatus.Idle {
			return AnyView(ConfigureSessionView(sourceService: sourceService, sessionService: sessionService))
		}
		
		if (sessionService.session?.status == SessionStatus.Ready || sessionService.session?.status == SessionStatus.Recording) {
			return AnyView(RecordingView(sessionService: sessionService))
		}
		
		if (sessionService.session?.status == SessionStatus.Stopped) {
			return AnyView(UploadAndCompleteSessionView(sessionService: sessionService, conductorService: sessionService.conductorService))
		}
		
		return AnyView(ActivityIndicator(isAnimating: true))
	}
}

struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		ContentView()
			.previewLayout(.fixed(width: 896, height: 414))
	}
}
