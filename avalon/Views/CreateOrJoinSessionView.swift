//
//  CreateOrJoinSessionView.swift
//  avalon
//
//  Created by James Williams on 10/05/2020.
//  Copyright © 2020 James Williams. All rights reserved.
//

import SwiftUI

struct CreateOrJoinSessionView: View {
	@ObservedObject var sessionService: SessionService
	@State var joinCode: String = ""
	var body: some View {
		VStack(alignment: .center, spacing: 10) {
			Button(action: { self.sessionService.new() }) {
				Spacer()
				Text("Start a new recording")
				Spacer()
			}
			.padding()
			.background(Color.blue.opacity(0.2))
			.cornerRadius(5)
			Text("OR")
				.font(.subheadline)
				.bold()
				.foregroundColor(.blue)
			VStack(alignment: .leading, spacing: 5) {
				TextField("Code", text: $joinCode)
				.padding()
				.background(Color.gray.opacity(0.1))
				.cornerRadius(5)
				Button(action: { self.sessionService.join(code: self.joinCode) }) {
					Spacer()
					Text("Join a recording")
					Spacer()
				}
				.padding()
				.background(Color.blue.opacity(0.2))
				.cornerRadius(5)
			}
		}
		.frame(maxWidth: 300)
	}
}

struct CreateOrJoinSessionView_Previews: PreviewProvider {
    static var previews: some View {
        CreateOrJoinSessionView(sessionService: SessionService())
    }
}
