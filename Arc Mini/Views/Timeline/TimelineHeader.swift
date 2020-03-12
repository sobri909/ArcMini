//
//  TimelineHeader.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 10/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI

struct TimelineHeader: View {
    var body: some View {
        HStack {
            Text("TIMELINE")
                .font(.custom("Rubik-Medium", size: 12))
                .foregroundColor(.arcSelected)
                .kerning(1)
            Spacer()
        }
        .padding([.leading, .trailing], 20)
        .frame(height: 55)
        .background(Color.white)
    }
}

struct TimelineHeader_Previews: PreviewProvider {
    static var previews: some View {
        TimelineHeader()
    }
}
