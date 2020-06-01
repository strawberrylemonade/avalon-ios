//
//  UploadAndCompleteSessionView.swift
//  avalon
//
//  Created by James Williams on 10/05/2020.
//  Copyright © 2020 James Williams. All rights reserved.
//

import SwiftUI

struct UploadAndCompleteSessionView: View {
	@ObservedObject var sessionService: SessionService
	@ObservedObject var conductorService: ConductorService
    var body: some View {
			VStack {
				ForEach(conductorService.medias) { (media: Media) in
					Text(media.id.uuidString)
					Text(media.state.rawValue)
					Text("\(media.progress)")
					Text(media.mode.rawValue)
				}
			}
    }
}

struct UploadAndCompleteSessionView_Previews: PreviewProvider {
    static var previews: some View {
			let ss = SessionService()
			return UploadAndCompleteSessionView(sessionService: ss, conductorService: ss.conductorService)
    }
}
