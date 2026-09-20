import SwiftUI

struct MonthNavigation: View {
    @ObservedObject var state: CalendarState
    var compact = false
    @State private var choosingYear = false
    @State private var choosingMonth = false

    var body: some View {
        HStack(spacing: compact ? 8 : 20) {
            if compact {
                Menu {
                    ForEach(1...12, id: \.self) { month in
                        Button("\(month)月") { state.setMonth(year: state.year, month: month) }
                    }
                } label: {
                    Text("\(String(state.year))年 \(state.month)月").font(.system(size: 18, weight: .medium))
                }.menuStyle(.borderlessButton).fixedSize()
            } else {
                Button { choosingYear.toggle() } label: { selectorLabel("\(String(state.year))年", width: 140) }
                    .buttonStyle(.plain).accessibilityIdentifier("yearPicker")
                    .popover(isPresented: $choosingYear) {
                        ScrollViewReader { reader in
                            ScrollView {
                                LazyVStack(spacing: 4) {
                                    ForEach(1901...2100, id: \.self) { year in
                                        Button("\(String(year))年") {
                                            state.setMonth(year: year, month: state.month); choosingYear = false
                                        }.buttonStyle(.plain).padding(8)
                                            .foregroundStyle(year == state.year ? Design.red : Design.ink).id(year)
                                    }
                                }.frame(maxWidth: .infinity)
                            }.frame(width: 150, height: 280)
                                .onAppear { reader.scrollTo(state.year, anchor: .center) }
                        }.padding(8)
                    }
                Button { choosingMonth.toggle() } label: { selectorLabel("\(state.month)月", width: 120) }
                    .buttonStyle(.plain).accessibilityIdentifier("monthPicker")
                    .popover(isPresented: $choosingMonth) {
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(58)), count: 3), spacing: 12) {
                            ForEach(1...12, id: \.self) { month in
                                Button("\(month)月") {
                                    state.setMonth(year: state.year, month: month); choosingMonth = false
                                }.buttonStyle(.plain).padding(10)
                                    .foregroundStyle(month == state.month ? Design.red : Design.ink)
                            }
                        }.padding(16)
                    }
            }
            Spacer(minLength: 0)
            IconButton(symbol: "chevron.left", label: "上个月") { state.changeMonth(-1) }.disabled(!state.canGoBack)
            IconButton(symbol: "chevron.right", label: "下个月") { state.changeMonth(1) }.disabled(!state.canGoForward)
            Button("今天") { state.goToday() }
                .buttonStyle(.plain).frame(width: compact ? 68 : 106, height: compact ? 34 : 44)
                .background(Design.background, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Design.line, lineWidth: 1))
                .accessibilityIdentifier("todayButton")
        }
        .font(.system(size: compact ? 16 : 20))
        .foregroundStyle(Design.ink)
        .controlSize(.large)
    }
    private func selectorLabel(_ title: String, width: CGFloat) -> some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: "chevron.down").font(.system(size: 13))
        }.padding(.horizontal, 12).frame(width: width, height: 44)
            .background(Design.background, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Design.line, lineWidth: 1))
    }
}
