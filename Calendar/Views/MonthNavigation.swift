import SwiftUI

struct MonthNavigation: View {
    @ObservedObject var state: CalendarState
    var compact = false
    @State private var choosingYear = false
    @State private var choosingMonth = false

    var body: some View {
        HStack(spacing: compact ? 8 : 20) {
            selectorButton(
                title: "\(String(state.year))年",
                width: compact ? 94 : 140,
                identifier: compact ? "menuYearPicker" : "yearPicker",
                isPresented: $choosingYear
            ) { yearPicker }
            selectorButton(
                title: "\(state.month)月",
                width: compact ? 58 : 120,
                identifier: compact ? "menuMonthPicker" : "monthPicker",
                isPresented: $choosingMonth
            ) { monthPicker }
            Spacer(minLength: 0)
            IconButton(symbol: "chevron.left", label: "上个月") { state.changeMonth(-1) }
                .disabled(!state.canGoBack)
            IconButton(symbol: "chevron.right", label: "下个月") { state.changeMonth(1) }
                .disabled(!state.canGoForward)
            Button("今天") { state.goToday() }
                .buttonStyle(.plain)
                .lineLimit(1)
                .frame(width: compact ? 58 : 106, height: compact ? 34 : 44)
                .background(Design.background, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Design.line, lineWidth: 1))
                .accessibilityIdentifier("todayButton")
        }
        .font(.system(size: compact ? 15 : 20))
        .foregroundStyle(Design.ink)
        .controlSize(.large)
    }

    private var yearPicker: some View {
        ScrollViewReader { reader in
            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(72), spacing: 6), count: 3),
                    spacing: 6
                ) {
                    ForEach(1901...2100, id: \.self) { year in
                        optionButton("\(String(year))年", selected: year == state.year, identifier: "yearOption-\(year)") {
                            state.setMonth(year: year, month: state.month)
                            choosingYear = false
                        }
                        .id(year)
                    }
                }
                .padding(10)
            }
            .frame(width: 254, height: 292)
            .onAppear { reader.scrollTo(state.year, anchor: .center) }
        }
    }

    private var monthPicker: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(68), spacing: 8), count: 3),
            spacing: 8
        ) {
            ForEach(1...12, id: \.self) { month in
                optionButton("\(month)月", selected: month == state.month, identifier: "monthOption-\(month)") {
                    state.setMonth(year: state.year, month: month)
                    choosingMonth = false
                }
            }
        }
        .padding(14)
        .frame(width: 256)
    }

    private func selectorButton<Content: View>(
        title: String,
        width: CGFloat,
        identifier: String,
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        Button {
            if identifier.contains("Year") || identifier == "yearPicker" { choosingMonth = false }
            else { choosingYear = false }
            isPresented.wrappedValue.toggle()
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.system(size: compact ? 10 : 13, weight: .medium))
            }
            .padding(.horizontal, compact ? 9 : 12)
            .frame(width: width, height: compact ? 34 : 44)
            .background(Design.background, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Design.line, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .popover(isPresented: isPresented, arrowEdge: .bottom, content: content)
    }

    private func optionButton(
        _ title: String,
        selected: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: selected ? .semibold : .regular))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(selected ? Color.white : Design.ink)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(selected ? Design.selection : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
    }
}
