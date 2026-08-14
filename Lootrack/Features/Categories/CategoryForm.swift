//
//  CategoryForm.swift
//  Lootrack
//
//  Created by Alessandro Esposito on 14/08/2026.
//


import SwiftUI

struct CategoryForm: View {
    @Binding var draft: CategoryDraft

    var body: some View {
        Form {
            Section("Category") {
                TextField("Name", text: $draft.name)

                Picker("Type", selection: $draft.type) {
                    Text("Expense")
                        .tag(TransactionType.expense)

                    Text("Income")
                        .tag(TransactionType.income)
                }
            }
        }
    }
}