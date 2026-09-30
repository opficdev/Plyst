//
//  HomeCardFormat.swift
//  Plyst
//
//  Created by opfic on 9/30/26.
//

import UIKit

enum HomeCardFormat {
    static func time(
        for date: Date,
        now: Date
    ) -> String {
        let age = now.timeIntervalSince(date)
        if 0 <= age, age < 60 { return "지금" }
        if 0 <= age, age < 5 * 60 { return "\(Int(age / 60))분 전" }
        if Calendar.current.isDate(date, inSameDayAs: now)
            || Calendar.current.isDate(date, inSameDayAs: Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now) {
            return DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
        }
        return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
    }

    static func height(
        for text: String,
        font: UIFont,
        width: CGFloat,
        lines: Int
    ) -> CGFloat {
        let bounds = (text as NSString).boundingRect(
            with: CGSize(width: max(1, width), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return min(ceil(font.lineHeight * CGFloat(lines)), max(ceil(font.lineHeight), ceil(bounds.height)))
    }
}
