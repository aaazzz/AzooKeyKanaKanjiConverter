//
//  JapaneseNumberConversionTests.swift
//  KanaKanjiConverterModuleTests
//
//  Created by ensan on 2023/04/18.
//  Copyright © 2023 ensan. All rights reserved.
//

@testable import KanaKanjiConverterModule
import XCTest

final class JapaneseNumberConversionTests: XCTestCase {
    func testJapaneseNumberConversion() throws {
        let dicdataStore = DicdataStore(dictionaryURL: URL(fileURLWithPath: ""))
        do {
            let result = dicdataStore.getJapaneseNumberDicdata(head: "イチマン")
            XCTAssertEqual(result.count, 2)
            XCTAssertTrue(result.contains(where: {$0.word == "一万"}))
            XCTAssertTrue(result.contains(where: {$0.word == "10000"}))
        }
        do {
            let result = dicdataStore.getJapaneseNumberDicdata(head: "ニオクロクセンヨンヒャクマンキュウ")
            XCTAssertEqual(result.count, 2)
            XCTAssertTrue(result.contains(where: {$0.word == "二億六千四百万九"}))
            XCTAssertTrue(result.contains(where: {$0.word == "264000009"}))
        }
        do {
            XCTAssertEqual(dicdataStore.getJapaneseNumberDicdata(head: "マルマン").count, 0)
            XCTAssertEqual(dicdataStore.getJapaneseNumberDicdata(head: "アマン").count, 0)
            XCTAssertEqual(dicdataStore.getJapaneseNumberDicdata(head: "イチリン").count, 0)
            XCTAssertEqual(dicdataStore.getJapaneseNumberDicdata(head: "ニムリョウタイスウサンガイ").count, 0)
        }
    }

    /// 位の語だけの読み（ヒャク・ジュウ・セン）も数になる。マン・オクは単独では数にしない。
    func testUnitOnlyReadings() throws {
        let dicdataStore = DicdataStore(dictionaryURL: URL(fileURLWithPath: ""))
        let expected: [(String, String, String)] = [
            ("ヒャク", "百", "100"),
            ("ジュウ", "十", "10"),
            ("セン", "千", "1000"),
            ("ヒャクマン", "百万", "1000000"),
            ("センマン", "千万", "10000000"),
            ("ジュウオク", "十億", "1000000000"),
        ]
        for (head, kanji, roman) in expected {
            let result = dicdataStore.getJapaneseNumberDicdata(head: head)
            XCTAssertEqual(result.count, 2, head)
            XCTAssertTrue(result.contains(where: {$0.word == kanji}), head)
            XCTAssertTrue(result.contains(where: {$0.word == roman}), head)
            XCTAssertTrue(result.allSatisfy({$0.ruby == head}), head)
        }
        XCTAssertEqual(dicdataStore.getJapaneseNumberDicdata(head: "マン").count, 0)
        XCTAssertEqual(dicdataStore.getJapaneseNumberDicdata(head: "オク").count, 0)
        XCTAssertEqual(dicdataStore.getJapaneseNumberDicdata(head: "マンオク").count, 0)
    }

    /// 助数詞の前の促音形「ヒャッ」（ひゃっこ・ろっぴゃっぽん）を読む。
    func testGeminatedHyaku() throws {
        let dicdataStore = DicdataStore(dictionaryURL: URL(fileURLWithPath: ""))
        let expected: [(String, String, String)] = [
            ("ヒャッ", "百", "100"),
            ("サンビャッ", "三百", "300"),
            ("ロッピャッ", "六百", "600"),
            ("ハッピャッ", "八百", "800"),
            ("センニヒャッ", "千二百", "1200"),
        ]
        for (head, kanji, roman) in expected {
            let result = dicdataStore.getJapaneseNumberDicdata(head: head)
            XCTAssertEqual(result.count, 2, head)
            XCTAssertTrue(result.contains(where: {$0.word == kanji}), head)
            XCTAssertTrue(result.contains(where: {$0.word == roman}), head)
        }
        XCTAssertEqual(dicdataStore.getJapaneseNumberDicdata(head: "ヒャン").count, 0)
    }
}
