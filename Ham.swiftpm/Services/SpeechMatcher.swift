//
//  SpeechMatcher.swift
//  Ham
//
//  Created by 길지훈 on 2/27/26.
//

import CoreGraphics

/// Token-based speech matching engine.
///
/// Compares recognized text against script tokens in sequential order.
/// Used by OnboardingViewModel, ActionViewModel, and ScriptIntroView.
///
/// HOW MATCHING WORKS:
///   1. Split the script line into word tokens
///   2. Split recognized text into words (lowercased, letters only)
///   3. Walk both arrays forward — each token consumes a recognized word
///   4. Short words (<=2 chars) auto-skip if not found
///   5. Longer words use fuzzy matching (prefix 60% OR letter overlap 75%)
///
/// HOW TO TUNE:
///   - `minFuzzyLength` (3): words shorter than this require exact match
///   - `prefixThreshold` (0.6): minimum prefix overlap ratio for fuzzy match
///   - `overlapThreshold` (0.75): minimum letter set overlap for fuzzy match
///   - `maxAutoSkip` (2): max consecutive short-word skips before stopping
enum SpeechMatcher {

    static func tokenize(_ line: String) -> [String] {
        line.components(separatedBy: " ").filter { !$0.isEmpty }
    }

    /// Returns the number of sequentially matched tokens.
    static func matchTokens(recognized: String, tokens: [String]) -> Int {
        let recWords = recognized.lowercased()
            .components(separatedBy: .whitespaces)
            .map { $0.filter { $0.isLetter } }
            .filter { !$0.isEmpty }

        var recIdx = 0
        var matched = 0
        var consecutiveSkips = 0

        for token in tokens {
            let target = token.lowercased().filter { $0.isLetter }
            guard !target.isEmpty else { matched += 1; continue }

            var found = false
            for i in recIdx..<recWords.count {
                if recWords[i] == target ||
                   (target.count >= 3 && wordIsSimilar(recWords[i], target)) {
                    recIdx = i + 1
                    found = true
                    consecutiveSkips = 0
                    break
                }
            }

            if found {
                matched += 1
            } else if target.count <= 2 {
                matched += 1
                consecutiveSkips += 1
                if consecutiveSkips > 2 { break }
            } else {
                break
            }
        }

        return matched
    }

    /// Character-position-based fill progress.
    /// Maps matched token count to the actual character position in the original text,
    /// so the fill aligns with word boundaries instead of cutting through words.
    static func fillProgress(matched: Int, in text: String) -> CGFloat {
        guard matched > 0, !text.isEmpty else { return 0 }

        let words = text.split(separator: " ", omittingEmptySubsequences: true)
        guard matched < words.count else { return 1.0 }

        let lastWord = words[matched - 1]
        let endOffset = text.distance(from: text.startIndex, to: lastWord.endIndex)
        return CGFloat(endOffset) / CGFloat(text.count)
    }

    /// Fuzzy match: prefix overlap >= 60% OR character set overlap >= 75%.
    static func wordIsSimilar(_ rec: String, _ target: String) -> Bool {
        guard rec.count >= 2, target.count >= 2 else { return false }
        let shorter = min(rec.count, target.count)
        let prefix = zip(rec, target).prefix(while: { $0 == $1 }).count
        if Float(prefix) / Float(shorter) >= 0.6 { return true }
        let setA = Set(rec)
        let setB = Set(target)
        let overlap = Float(setA.intersection(setB).count) / Float(min(setA.count, setB.count))
        return overlap >= 0.75
    }
}
