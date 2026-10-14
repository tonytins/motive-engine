/// The weighted contribution of one motive to an interaction's score.
public struct MotiveOpportunityContribution: Equatable, Sendable {
    /// The motive represented by this contribution.
    public let motiveType: MotiveType

    /// The current motive value.
    public let motiveLevel: Double

    /// Current need urgency in the range `0...1`.
    public let urgency: Double

    /// The sum of advertised benefit rates for this motive.
    public let advertisedStrengthPerSecond: Double

    /// The advertised strength weighted by current urgency.
    public let score: Double
}

/// An interaction offer ranked against one motive snapshot.
public struct ScoredInteractionOffer: Equatable, Sendable {
    /// The eligible offer being scored.
    public let offer: InteractionOffer

    /// The sum of all weighted motive contributions.
    public let score: Double

    /// Per-motive values that explain the total score.
    public let contributions: [MotiveOpportunityContribution]
}

/// A deterministic ranking of eligible interaction offers.
public struct AutonomyRanking: Equatable, Sendable {
    /// Candidates ordered by descending score, then item and interaction IDs.
    public let rankedOffers: [ScoredInteractionOffer]

    /// The highest-ranked offer when its score is positive.
    ///
    /// Returns `nil` when there are no candidates or none has a positive
    /// score.
    public var selectedOffer: ScoredInteractionOffer? {
        guard let bestOffer = rankedOffers.first, bestOffer.score > 0 else {
            return nil
        }
        return bestOffer
    }
}

/// An error encountered while scoring an interaction offer.
public enum AutonomyScoringError: Error, Equatable, Sendable {
    /// The offer's advertised benefits produce a score outside finite range.
    case nonFiniteScore(
        itemInstanceID: ItemInstanceID,
        interactionDefinitionID: InteractionDefinitionID
    )
}

/// Pure motive-weighted ranking over offers already found eligible.
public enum AutonomyScoringSystem {
    /// Scores and ranks eligible offers without changing simulation state.
    ///
    /// Each motive's urgency is `(100 - level) / 100`. An offer's score is
    /// the sum of its advertised benefit rates multiplied by their motive
    /// urgency. Negative benefits lower the score. Offers are ordered by
    /// descending score, then by item-instance ID, item-definition ID, and
    /// interaction ID.
    ///
    /// A positive score is considered useful. `AutonomyRanking.selectedOffer`
    /// is `nil` when no offer has a positive score. The input must contain
    /// only offers that have already passed eligibility checks.
    ///
    /// - Throws: `AutonomyScoringError.nonFiniteScore` if aggregating the
    ///   advertised benefits exceeds finite `Double` range.
    public static func rank(
        _ eligibleOffers: [InteractionOffer],
        for motives: MotiveLevels
    ) throws -> AutonomyRanking {
        let scoredOffers = try eligibleOffers.map {
            try score($0, for: motives)
        }
        let rankedOffers = scoredOffers.sorted { left, right in
            if left.score != right.score {
                return left.score > right.score
            }
            if left.offer.itemInstanceID.rawValue != right.offer.itemInstanceID.rawValue {
                return left.offer.itemInstanceID.rawValue < right.offer.itemInstanceID.rawValue
            }
            if left.offer.itemDefinitionID.rawValue != right.offer.itemDefinitionID.rawValue {
                return left.offer.itemDefinitionID.rawValue
                    < right.offer.itemDefinitionID.rawValue
            }
            return left.offer.interactionDefinitionID.rawValue
                < right.offer.interactionDefinitionID.rawValue
        }

        return AutonomyRanking(rankedOffers: rankedOffers)
    }

    private static func score(
        _ offer: InteractionOffer,
        for motives: MotiveLevels
    ) throws -> ScoredInteractionOffer {
        var advertisedStrengths: [MotiveType: Double] = [:]
        for benefit in offer.advertisedBenefits {
            let strength = advertisedStrengths[benefit.motiveType, default: 0]
                + benefit.expectedStrengthPerSecond
            guard strength.isFinite else {
                throw nonFiniteScore(for: offer)
            }
            advertisedStrengths[benefit.motiveType] = strength
        }

        var totalScore = 0.0
        var contributions: [MotiveOpportunityContribution] = []
        for motiveType in MotiveType.allCases {
            guard let advertisedStrength = advertisedStrengths[motiveType] else {
                continue
            }
            let motiveLevel = motives.level(for: motiveType)
            let urgency = (MotiveLevels.maximumValue - motiveLevel)
                / MotiveLevels.maximumValue
            let contributionScore = advertisedStrength * urgency
            totalScore += contributionScore
            guard contributionScore.isFinite, totalScore.isFinite else {
                throw nonFiniteScore(for: offer)
            }

            contributions.append(
                MotiveOpportunityContribution(
                    motiveType: motiveType,
                    motiveLevel: motiveLevel,
                    urgency: urgency,
                    advertisedStrengthPerSecond: advertisedStrength,
                    score: contributionScore
                )
            )
        }

        return ScoredInteractionOffer(
            offer: offer,
            score: totalScore,
            contributions: contributions
        )
    }

    private static func nonFiniteScore(
        for offer: InteractionOffer
    ) -> AutonomyScoringError {
        .nonFiniteScore(
            itemInstanceID: offer.itemInstanceID,
            interactionDefinitionID: offer.interactionDefinitionID
        )
    }
}
