import SwiftUI

struct AuspiceRow: View {
    let title: String
    let items: [String]
    var compact = false
    @State private var expanded = false
    var body: some View {
        Button { expanded.toggle() } label: {
        HStack(alignment: .top, spacing: compact ? 12 : 18) {
            Text(title).font(.system(size: compact ? 16 : 18, weight: .medium))
                .foregroundStyle(.white).frame(width: compact ? 28 : 32, height: compact ? 28 : 32)
                .background(title == "宜" ? Design.green : Design.selection, in: RoundedRectangle(cornerRadius: 8))
            Text(items.isEmpty ? "无" : items.joined(separator: " "))
                .font(.system(size: compact ? 13 : 16)).lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
                .lineLimit(1)
        }.foregroundStyle(Design.ink)
        }.buttonStyle(.plain).help("查看全部\(title)：\(items.joined(separator: "、"))")
            .accessibilityLabel("查看全部\(title)").accessibilityIdentifier("auspice-\(title)")
            .popover(isPresented: $expanded) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("今日\(title)").font(.headline)
                    Text(items.isEmpty ? "无" : items.joined(separator: " · "))
                        .font(.system(size: 16)).lineSpacing(8).fixedSize(horizontal: false, vertical: true)
                }.padding(22).frame(width: 310).foregroundStyle(Design.ink).background(Design.background)
            }
    }
}

struct AlmanacDetail: View {
    let day: AlmanacDay
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("\(String(day.civil.year))年\(day.civil.month)月\(day.civil.day)日  \(day.weekday)")
                    .font(.system(size: 21, weight: .medium)).padding(.top, 30)
                    .accessibilityIdentifier("detailDate")
                Text("\(day.civil.day)")
                    .font(.system(size: 112, weight: .medium, design: .serif))
                    .foregroundStyle(Design.red).padding(.top, 17)
                Text(day.lunarTitle).font(Design.lunarFont(34)).foregroundStyle(Design.red).padding(.top, -5)
                    .accessibilityIdentifier("lunarTitle")
                Text("\(day.lunar.yearInGanZhi)年 · \(day.lunar.yearShengXiao)")
                    .font(.system(size: 19)).padding(.top, 3).padding(.bottom, 26)
                Hairline()
                VStack(spacing: 14) {
                    AuspiceRow(title: "宜", items: day.lunar.dayYi)
                    AuspiceRow(title: "忌", items: day.lunar.dayJi)
                }.padding(.vertical, 23)
                Hairline()
                detailRow("干支", "\(day.lunar.yearInGanZhi)年 \(day.lunar.monthInGanZhi)月 \(day.lunar.dayInGanZhi)日")
                detailRow("冲煞", "\(day.lunar.dayChongDesc)  煞\(day.lunar.daySha)")
                detailRow("五行", day.lunar.dayNaYin)
                detailRow("彭祖百忌", "\(day.lunar.pengZuGan)\n\(day.lunar.pengZuZhi)")
                detailRow("吉神宜趋", day.lunar.dayJiShen.joined(separator: " "))
                detailRow("凶神宜忌", day.lunar.dayXiongSha.joined(separator: " "))
                detailRow("胎神占方", day.lunar.dayPositionTai)
                detailRow("吉神方位", "喜神 \(day.lunar.dayPositionXiDesc) · 福神 \(day.lunar.dayPositionFuDesc)\n财神 \(day.lunar.dayPositionCaiDesc)")
                if !day.festivals.isEmpty { detailRow("节日", day.festivals.joined(separator: "、")) }
                if !day.lunar.jieQi.isEmpty { detailRow("节气", day.lunar.jieQi) }
                Text("黄历内容源自传统民俗").font(.system(size: 11)).foregroundStyle(Design.secondary)
                    .padding(.vertical, 16)
            }.padding(.horizontal, 27)
        }.scrollIndicators(.hidden).foregroundStyle(Design.ink).background(Design.background)
    }
    private func detailRow(_ label: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 13) {
                Text(label).frame(width: 76, alignment: .leading)
                Text(value.isEmpty ? "无" : value).frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }.font(.system(size: 16)).lineSpacing(5).padding(.vertical, 16)
            Hairline()
        }
    }
}
