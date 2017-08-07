//
//  CalendarViewModel.swift
//  Pods
//
//  Created by Bryan Oltman on 8/4/17.
//  Copyright © 2017 Blue Apron. All rights reserved.
//

import Foundation
import SwiftDate

enum DateError: Error {
    case Generic(String)
    case InvalidDateOrdering
}

public protocol Dated {
    var date: Date? { get set }
}

class CalendarViewModel {
    let startDate: Date
    let endDate: Date
    let monthInfos: [MonthInfo]
    let showLeadingWeeks: Bool
    let showTrailingWeeks: Bool
    fileprivate let daysPerWeek = Calendar.gregorian.weekdaySymbols.count

    static func numberOfSectionsNeededFor(startDate: Date, endDate: Date) -> Int {
        let monthSpan = endDate.month - startDate.month
        let yearSpan = endDate.year - startDate.year
        return yearSpan * 12 + monthSpan + 1
    }

    static func makeMonthInfos(startDate: Date, endDate: Date) throws -> [MonthInfo] {
        let monthStartDate = startDate.beginningOfMonth
        let sections = (0..<(numberOfSectionsNeededFor(startDate: startDate, endDate: endDate)))
        return try sections.map { try MonthInfo(forMonthContaining: monthStartDate + $0.months) }
    }

    init(startDate: Date, endDate: Date, showLeadingWeeks: Bool = true, showTrailingWeeks: Bool = true) throws {
        if startDate > endDate && !startDate.isInSameDayOf(date: endDate) {
            throw DateError.InvalidDateOrdering
        }

        self.startDate = startDate
        self.endDate = endDate
        self.showLeadingWeeks = showLeadingWeeks
        self.showTrailingWeeks = showTrailingWeeks
        self.monthInfos = try CalendarViewModel.makeMonthInfos(startDate: startDate, endDate: endDate)
    }

    func date(at indexPath: IndexPath) -> Date? {
        let dates = self.dates(in: indexPath.section)
        if !(0..<dates.count).contains(indexPath.item) {
            return nil
        }
        return dates[indexPath.item]
    }

    func indexPath(from date: Date) -> IndexPath {
        let section = CalendarViewModel.numberOfSectionsNeededFor(startDate: startDate, endDate: date) - 1
        let zeroIndexDate = firstDisplayDate(for: section, showLeadingWeeks: showLeadingWeeks)
        let intervalDiff = date - zeroIndexDate
        return IndexPath(item: intervalDiff.in(.day) ?? 0, section: section)
    }

    func firstDisplayDate(for section: Int, showLeadingWeeks: Bool) -> Date {
        // returns the date that indexPath.item == 0 should map to,
        // usually (but not always) before the start of the month if leading weeks are being shown
        let monthInfo = monthInfos[section]
        let isFirstMonth = section == 0
        return (!showLeadingWeeks && isFirstMonth) ? startDate.beginningOfWeek : monthInfo.startDate.beginningOfWeek
    }

    func dates(in section: Int) -> [Date?] {
        let monthInfo = monthInfos[section]
        var firstDisplayIndex = monthInfo.firstDayWeekdayIndex
        var lastDisplayIndex = firstDisplayIndex + (monthInfo.numberOfDaysInMonth - 1)
        let zeroIndexDate = firstDisplayDate(for: section, showLeadingWeeks: showLeadingWeeks)
        let isFirstMonth = section == 0
        // If we're in our first month, don't show weeks leading up to but not including startDate
        if !showLeadingWeeks && isFirstMonth {
            // Find out which calendar row our start date is in
            let row = ceil(Double(firstDisplayIndex + startDate.day) / Double(daysPerWeek))

            // Subtract that many days from both indexes - those weeks won't be displayed
            let indexDiff = Int(row - 1) * daysPerWeek
            firstDisplayIndex -= indexDiff
            lastDisplayIndex -= indexDiff
        }

        let isLastMonth = section == monthInfos.count - 1
        if !showTrailingWeeks && isLastMonth {
            // Determine whether the last day to display will change by trimming trailing weeks
            let dayDifference = (monthInfo.endDate - endDate.endOfWeek).in(.day) ?? 0
            lastDisplayIndex -= (dayDifference - 1)
        }

        let requiredRows = ceil(Double(lastDisplayIndex) / Double(daysPerWeek))
        let requiredItems = Int(requiredRows) * daysPerWeek

        // We display full rows for every week we display, even if the current month starts or ends before the week.
        // Return nil for empty day cells
        return (0..<requiredItems).map { index in
            if index < max(firstDisplayIndex, 0) || index > lastDisplayIndex {
                return nil
            }

            return zeroIndexDate + index.days
        }
    }
}
