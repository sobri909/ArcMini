//
//  ThinkingListBox.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 21/6/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI

struct ThinkingListBox: View {
     var body: some View {
        ZStack {
            HStack {
                Rectangle().fill(Color("brandTertiaryDark")).frame(width: 3).cornerRadius(1.5)
                Spacer().frame(width: 34)
                VStack(alignment: .leading) {
                    Text("Thinking...").font(.system(size: 14, weight: .medium))
                }
                Spacer()
            }
            .frame(height: 44)
            .padding([.leading], 102)
            .padding([.trailing], 20)
            .background(Color("background"))
        }
    }
}
