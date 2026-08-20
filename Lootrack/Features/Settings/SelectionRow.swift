//
//  SelectionRow.swift
//  Lootrack
//
//  Created by Alessandro Esposito on 20/08/2026.
//

import SwiftUI

struct SelectionRow: View {
    let title: String
    let selected: Bool

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.primary)

            Spacer()

            if selected {
                Image(systemName: "checkmark")
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)
            }
        }
    }
}
