//
//  JapaneseCounter.swift
//  KanaKanjiConverterModule
//
//  数＋助数詞を 1 語として候補にする（さんびき → 3匹・三匹、ろっぴき → 6匹・六匹、3びき → 3匹）。
//
//  辞書には「一匹」「三匹」のような決まった組はあるが、「匹＝ピキ・ビキ」のような音の変わった助数詞は
//  単独では入っていないことが多い。そのため数の節点（getJapaneseNumberDicdata）と助数詞がつながらず、
//  「6匹」「100匹」「3軒」「3足」は候補に出なかった。また「3階」「3台」は作れても、点数で負けて上位に残らなかった。
//
//  ここでは読みを「数の部分」と「助数詞の部分」に分け、音便の規則（促音化・半濁音化・連濁）で作った
//  標準の読みと完全に一致したときだけ、数＋助数詞の 1 語を足す。読みで打った場合は、音が変わる形
//  （ロッピキ・サンビキ・ヨジ）に限る。変わらない形は lattice が既存の節点で組める。規則は Hizikey の学習データ用の
//  imeranker/data/numerals.py と同じもので、テストの期待値はそちらから生成している。
//

import Foundation

private enum CounterTail: Hashable {
    /// 1〜9 の一の位で終わる
    case digit(Int)
    case ten, hundred, thousand, man, oku, cho
}

private struct CounterSpec {
    let surface: String
    /// 数のあとの助数詞の読み（カタカナ）
    let reading: String
    /// この尾で終わる数は促音化する（イチ→イッ、ロク→ロッ…）
    let geminate: Set<CounterTail>
    /// 促音のあとの助数詞の読み（ホン → ポン）。nil なら reading のまま
    let afterGeminate: String?
    /// 「ん」で終わる数のあとの助数詞の読み（3本 → ボン）
    let afterN: [CounterTail: String]
    /// 一の位の数字の読みの置き換え（4時 → ヨ）
    let digitOverride: [Int: String]
    /// 別の語になるので作らない数（1人 → ヒトリ、2人 → フタリ）
    var excluded: Set<Int> = []
}

private enum CounterTable {
    static let k: Set<CounterTail> = [.digit(1), .digit(6), .digit(8), .ten, .hundred]
    static let st: Set<CounterTail> = [.digit(1), .digit(8), .ten]
    static let h: Set<CounterTail> = [.digit(1), .digit(6), .digit(8), .ten, .hundred]
    static let nTails: [CounterTail] = [.digit(3), .thousand, .man, .oku, .cho]
    static let yo: [Int: String] = [4: "ヨ"]
    static let ji: [Int: String] = [4: "ヨ", 7: "シチ", 9: "ク"]
    static let gatsu: [Int: String] = [4: "シ", 7: "シチ", 9: "ク"]

    static func hRow(_ surface: String, _ base: String, _ p: String, _ voiced: String, _ tails: [CounterTail] = [.digit(3)]) -> CounterSpec {
        CounterSpec(surface: surface, reading: base, geminate: h, afterGeminate: p,
                    afterN: Dictionary(uniqueKeysWithValues: tails.map { ($0, voiced) }), digitOverride: [:])
    }
    static func row(_ surface: String, _ base: String, _ geminate: Set<CounterTail> = [], afterN: [CounterTail: String] = [:],
                    digitOverride: [Int: String] = [:]) -> CounterSpec {
        CounterSpec(surface: surface, reading: base, geminate: geminate, afterGeminate: nil, afterN: afterN, digitOverride: digitOverride)
    }

    /// 1 つの読みに 1 つの表記（か月・ヶ月などの書き分けは代表 1 つ）。辞書で済んでいる読み（1人→ヒトリ、日付）は扱わない。
    static let specs: [CounterSpec] = [
        // は行: 促音のあとは ぱ行、「ん」のあとは ば行（分は ぷん）
        hRow("本", "ホン", "ポン", "ボン", nTails),
        hRow("匹", "ヒキ", "ピキ", "ビキ", nTails),
        hRow("杯", "ハイ", "パイ", "バイ", nTails),
        hRow("分", "フン", "プン", "プン", [.digit(3), .digit(4)] + Array(nTails.dropFirst())),
        hRow("発", "ハツ", "パツ", "パツ"),
        hRow("泊", "ハク", "パク", "パク"),
        hRow("歩", "ホ", "ポ", "ポ"),
        hRow("編", "ヘン", "ペン", "ペン"),
        hRow("票", "ヒョウ", "ピョウ", "ビョウ"),
        // か行: 1・6・8・10・100 のあとで促音化
        row("個", "コ", k),
        row("回", "カイ", k),
        row("回目", "カイメ", k),
        row("階", "カイ", k, afterN: [.digit(3): "ガイ"]),
        row("件", "ケン", k),
        row("軒", "ケン", k, afterN: [.digit(3): "ゲン"]),
        row("曲", "キョク", k),
        row("巻", "カン", k),
        row("期", "キ", k),
        row("基", "キ", k),
        row("校", "コウ", k),
        row("区", "ク", k),
        row("戸", "コ", k),
        row("項", "コウ", k),
        row("か月", "カゲツ", k),
        row("か国", "カコク", k),
        row("か所", "カショ", k),
        row("回戦", "カイセン", k),
        row("階建て", "カイダテ", k, afterN: [.digit(3): "ガイダテ"]),
        // さ行・た行: 1・8・10 のあとだけ促音化（6歳 ロクサイ、100点 ヒャクテン）
        row("歳", "サイ", st),
        row("冊", "サツ", st),
        row("点", "テン", st),
        row("通", "ツウ", st),
        row("頭", "トウ", st),
        row("着", "チャク", st),
        row("週", "シュウ", st),
        row("週間", "シュウカン", st),
        row("周年", "シュウネン", st),
        row("社", "シャ", st),
        row("種類", "シュルイ", st),
        row("章", "ショウ", st),
        row("勝", "ショウ", st),
        row("足", "ソク", st, afterN: [.digit(3): "ゾク"]),
        row("隻", "セキ", st),
        row("席", "セキ", st),
        row("世紀", "セイキ", st),
        row("試合", "シアイ", st),
        row("丁目", "チョウメ", st),
        // 数のほうの読みだけが変わる、または何も変わらない
        row("円", "エン", digitOverride: yo),
        row("年", "ネン", digitOverride: yo),
        row("年間", "ネンカン", digitOverride: yo),
        row("年目", "ネンメ", digitOverride: yo),
        row("月", "ガツ", digitOverride: gatsu),
        row("時", "ジ", digitOverride: ji),
        row("時間", "ジカン", digitOverride: ji),
        CounterSpec(surface: "人", reading: "ニン", geminate: [], afterGeminate: nil, afterN: [:], digitOverride: yo, excluded: [1, 2]),
        row("割", "ワリ", digitOverride: yo),
        row("枚", "マイ"),
        row("台", "ダイ"),
        row("名", "メイ"),
        row("倍", "バイ"),
        row("度", "ド"),
        row("位", "イ"),
        row("号", "ゴウ"),
        row("番", "バン"),
        row("番目", "バンメ"),
        row("秒", "ビョウ"),
        row("部", "ブ"),
        row("話", "ワ"),
        row("両", "リョウ"),
        row("組", "クミ"),
        row("段", "ダン"),
        row("代", "ダイ"),
        row("面", "メン"),
        row("線", "セン"),
    ]

    /// 助数詞側の読み（どの形でも）→ その読みを取りうる助数詞
    static let bySpokenForm: [String: [CounterSpec]] = {
        var map: [String: [CounterSpec]] = [:]
        for spec in specs {
            var forms: Set<String> = [spec.reading]
            if let p = spec.afterGeminate { forms.insert(p) }
            forms.formUnion(spec.afterN.values)
            for form in forms {
                map[form, default: []].append(spec)
            }
        }
        return map
    }()
    static let maxSpokenLength = bySpokenForm.keys.map(\.count).max() ?? 0
}

private enum CounterReading {
    static let digits = ["ゼロ", "イチ", "ニ", "サン", "ヨン", "ゴ", "ロク", "ナナ", "ハチ", "キュウ"]
    static let kanjiDigits: [Character] = ["〇", "一", "二", "三", "四", "五", "六", "七", "八", "九"]

    /// 1〜9999 の読みと、その数が何で終わるか
    static func group(_ g: Int) -> (String, CounterTail) {
        let th = g / 1000, h = g / 100 % 10, t = g / 10 % 10, o = g % 10
        var s = ""
        if th > 0 { s += [1: "セン", 3: "サンゼン", 8: "ハッセン"][th] ?? digits[th] + "セン" }
        if h > 0 { s += [1: "ヒャク", 3: "サンビャク", 6: "ロッピャク", 8: "ハッピャク"][h] ?? digits[h] + "ヒャク" }
        if t > 0 { s += t == 1 ? "ジュウ" : digits[t] + "ジュウ" }
        if o > 0 { s += digits[o] }
        let tail: CounterTail = o > 0 ? .digit(o) : (t > 0 ? .ten : (h > 0 ? .hundred : .thousand))
        return (s, tail)
    }

    /// 数の読み（カタカナ）と、その数が何で終わるか。0 と 1 兆以上は扱わない。
    static func number(_ n: Int) -> (String, CounterTail)? {
        guard 0 < n, n < 10_000_000_000_000_000 else { return nil }
        let units: [(Int, String, CounterTail)] = [(1_000_000_000_000, "チョウ", .cho), (100_000_000, "オク", .oku), (10_000, "マン", .man)]
        var rest = n, s = "", tail: CounterTail?
        for (value, reading, unitTail) in units where rest >= value {
            let g = rest / value
            rest %= value
            s += (g == 1 ? "イチ" : group(g).0) + reading
            tail = unitTail
        }
        if rest > 0 {
            let (r, t) = group(rest)
            s += r
            tail = t
        }
        return tail.map { (s, $0) }
    }

    /// 一の位の数字の読みが置き換わるか（4時 ヨジ、7時 シチジ、9月 クガツ）
    static func overridesDigit(_ n: Int, _ spec: CounterSpec) -> Bool {
        guard let (_, tail) = number(n), case .digit(let d) = tail else { return false }
        return spec.digitOverride[d] != nil
    }

    static func geminate(_ reading: String) -> String {
        for (plain, small) in [("イチ", "イッ"), ("ロク", "ロッ"), ("ハチ", "ハッ"), ("ジュウ", "ジュッ"), ("ャク", "ャッ")] where reading.hasSuffix(plain) {
            return String(reading.dropLast(plain.count)) + small
        }
        return reading
    }

    /// 数＋助数詞の標準の読みと、数のあとの助数詞の読み（数字で打つときの形: 3びき）
    static func counted(_ n: Int, _ spec: CounterSpec) -> (full: String, spokenCounter: String)? {
        guard !spec.excluded.contains(n), let (reading, tail) = number(n) else { return nil }
        if spec.geminate.contains(tail) {
            let counter = spec.afterGeminate ?? spec.reading
            return (geminate(reading) + counter, counter)
        }
        if let counter = spec.afterN[tail] {
            return (reading + counter, counter)
        }
        if case .digit(let d) = tail, let replacement = spec.digitOverride[d] {
            return (String(reading.dropLast(digits[d].count)) + replacement + spec.reading, spec.reading)
        }
        return (reading + spec.reading, spec.reading)
    }
}

extension DicdataStore {
    /// 読み全体が「数＋助数詞」の標準の読みと一致するときの 1 語（数字形・漢数字形）。
    /// 数字で打った読み（3ビキ）は数字形だけを返す。
    func getJapaneseCounterDicdata(head: String) -> [DicdataElement] {
        let chars = Array(head)
        guard chars.count >= 2 else { return [] }
        var result: [DicdataElement] = []
        for length in 1...min(CounterTable.maxSpokenLength, chars.count - 1) {
            let suffix = String(chars[(chars.count - length)...])
            guard let specs = CounterTable.bySpokenForm[suffix] else { continue }
            let prefix = String(chars[..<(chars.count - length)])
            if prefix.allSatisfy({ $0.isASCII && $0.isNumber }) {
                // 数字で打った: 3ビキ → 3匹
                guard prefix.count <= 12, prefix.first != "0" || prefix.count == 1, let n = Int(prefix) else { continue }
                for spec in specs where CounterReading.counted(n, spec)?.spokenCounter == suffix {
                    result.append(DicdataElement(word: prefix + spec.surface, ruby: head, lcid: CIDData.固有名詞.cid, rcid: CIDData.固有名詞.cid, mid: 17, value: -11))
                }
                continue
            }
            // 読みで打った: サンビキ → 3匹・三匹。数の部分は getJapaneseNumberDicdata で読む。
            // 4時（ヨジ）のように一の位の読みが変わる助数詞は、ヨ を ヨン に戻してから読む。
            for spec in specs {
                var prefixes = [prefix]
                for (d, replacement) in spec.digitOverride where prefix.hasSuffix(replacement) {
                    prefixes.append(String(prefix.dropLast(replacement.count)) + CounterReading.digits[d])
                }
                for p in prefixes {
                    let number = getJapaneseNumberDicdata(head: p)
                    guard number.count == 2, let n = Int(number[1].word),
                          CounterReading.counted(n, spec)?.full == head else { continue }
                    // 音が変わる形だけを作る（ロッピキ・サンビキ・ヨジ）。変わらない形（ニクミ → 2組）は
                    // 数の節点と辞書の助数詞で lattice が組めるので、足すと「憎み」「仙台」などを押しのけるだけ。
                    let geminated = p.hasSuffix("ッ")
                    let changed = geminated || suffix != spec.reading || CounterReading.overridesDigit(n, spec)
                    // 位の語だけの数（セン・ヒャク・ジュウ）は、促音形のときだけ（ヒャッピキ・ジュッポン）。
                    // セン＋ダイ → 1000台 は「仙台」「先代」とぶつかる。
                    let unitOnly = [10, 100, 1000, 10_000, 100_000_000, 1_000_000_000_000].contains(n) && !p.hasPrefix("イ")
                    guard changed, !unitOnly || geminated else { break }
                    result.append(DicdataElement(word: number[1].word + spec.surface, ruby: head, lcid: CIDData.固有名詞.cid, rcid: CIDData.固有名詞.cid, mid: 17, value: -11))
                    result.append(DicdataElement(word: number[0].word + spec.surface, ruby: head, lcid: CIDData.数.cid, rcid: 1300, mid: 17, value: -12.5))
                    break
                }
            }
        }
        return result
    }
}
