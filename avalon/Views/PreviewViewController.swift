//
//  PreviewViewController.swift
//  avalon
//
//  Created by James Williams on 10/05/2020.
//  Copyright © 2020 James Williams. All rights reserved.
//

import UIKit
import SwiftUI

struct PreviewView: UIViewRepresentable {
	var sessionService: SessionService
		
	public func makeUIView(context: Context) -> UIView {
		let view = UIView(frame: CGRect(x:0, y:0, width: UIScreen.main.bounds.size.width, height: UIScreen.main.bounds.size.height))
		sessionService.conductorService.preview(view: view)
		return view
	}
	
	func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<PreviewView>) {
	}
}
