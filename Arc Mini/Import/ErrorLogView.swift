//
//  ErrorLogView.swift
//  Arc
//
//  Created by Matt Greenfield on 23/6/21.
//  Copyright © 2021 Big Paua. All rights reserved.
//

import SwiftUI

struct ErrorLogView: View {
    
    @Environment(\.presentationMode) var presentationMode
    @State var fontSize: CGFloat = 8

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer().overlay(
                    HStack {
                        fontSizeButton
                        Spacer()
                    }
                )
                Text("ERRORS LOG").font(.custom("Silka-Black", size: 14)).kerning(2).foregroundColor(.black)
                Spacer().overlay(
                    HStack(spacing: 0) {
                        Spacer()
                        shareButton
                        closeButton
                    }
                )
            }
            .padding([.leading, .trailing], 12)
            .frame(height: 64)
            Rectangle().fill(Color(0xE2E2E2)).frame(height: .onePixel)
            
            ScrollView {
                Text(ArcImporter.highlander.makeErrorsLog())
                    .font(.system(size: self.fontSize, weight: .regular, design: .monospaced))
            }
        }
    }
    
    var fontSizeButton: some View {
        Button {
            if self.fontSize < 12 {
                self.fontSize += 1
            } else {
                self.fontSize = 8
            }
        } label: {
            Image(systemName: "textformat.size")
        }
        .frame(width: 44, height: 64)
    }

    var shareButton: some View {
        Button {
            // TODO
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .frame(width: 44, height: 64)
    }

    var closeButton: some View {
        Button {
            presentationMode.wrappedValue.dismiss()
        } label: {
            Image(systemName: "xmark")
        }
        .frame(width: 44, height: 64)
    }
    
}
