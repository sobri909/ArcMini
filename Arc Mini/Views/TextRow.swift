//
//  TextRow.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 16/12/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI

struct TextRow: View {
    var left: Text
    var right: Text
    var leftFont: Font = .system(size: 17, weight: .regular)
    var rightFont: Font = .system(size: 15, weight: .semibold)
    
    var body: some View {
        HStack {
            left.font(leftFont)
            Spacer()
            right.font(rightFont)
                .foregroundColor(Color(UIColor.arcGray1))
        }.frame(height: 44)
    }
}

struct TextRow_Previews: PreviewProvider {
    static var previews: some View {
        TextRow(left: Text("Left text"), right: Text("Right text"))
            .border(Color.green, width: 1)
            .padding(20)
    }
}
