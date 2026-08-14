//
//  CategoryListView.swift
//  Lootrack
//
//  Created by Alessandro Esposito on 14/08/2026.
//


import SwiftUI
import SwiftData

struct CategoryListView: View {
    @State private var showingAddCategory = false
    @State private var editingCategory: Category?

    @Query(
        filter: #Predicate<Category> { category in
            category.deletedAt == nil
        },
        sort: \Category.name
    )
    private var categories: [Category]

    var body: some View {
        List {
            ForEach(categories) { category in
                HStack {
                    Text(category.name)

                    Spacer()

                    Text(category.type == .expense ? "Expense" : "Income")
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    editingCategory = category
                }
                .swipeActions {
                    Button(
                        "Delete",
                        systemImage: "trash",
                        role: .destructive
                    ) {
                        category.deletedAt = .now
                        category.updatedAt = .now
                    }
                }
            }
        }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add", systemImage: "plus") {
                    showingAddCategory = true
                }
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            AddCategoryView()
        }
    }
}