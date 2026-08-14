//
//  CategoryDraft.swift
//  Lootrack
//
//  Created by Alessandro Esposito on 14/08/2026.
//


struct CategoryDraft {
    var name = ""
    var type: TransactionType = .expense

    init() {}

    init(category: Category) {
        name = category.name
        type = category.type
    }
}