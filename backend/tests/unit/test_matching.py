"""Unit tests for matching/compatibility scoring functions."""
import pytest
from app.services.matching_service import (
    _score_age, _score_location, _score_education,
    _score_profession, _score_lifestyle, _score_family, _score_message,
)


class TestAgeScoring:
    def test_exact_match(self):
        score = _score_age(25, 30, 27, 25, 35, 28)
        assert score > 0.7

    def test_outside_range(self):
        score = _score_age(25, 30, 40, None, None, 28)
        assert score < 0.5

    def test_no_preference(self):
        score = _score_age(None, None, 30, None, None, 28)
        assert score >= 0.4  # Neutral

    def test_boundary_match(self):
        score = _score_age(25, 30, 32, None, None, 28)
        # Slightly outside range but within 2 years
        assert score > 0.2

    def test_unknown_age(self):
        score = _score_age(25, 30, None, None, None, 28)
        assert score == 0.5  # Neutral for unknown


class TestLocationScoring:
    def test_city_match(self):
        score = _score_location([], ["Delhi"], "Delhi", "Delhi")
        assert score == 1.0

    def test_state_match(self):
        score = _score_location(["Maharashtra"], [], "Maharashtra", "Mumbai")
        assert score == 0.8

    def test_no_match(self):
        score = _score_location(["Gujarat"], ["Surat"], "UP", "Agra")
        assert score == 0.3

    def test_no_preference(self):
        score = _score_location([], [], "UP", "Agra")
        assert score == 0.7


class TestEducationScoring:
    def test_sufficient_education(self):
        score = _score_education("bachelor", "Master's in Computer Science")
        assert score == 1.0

    def test_exact_level(self):
        score = _score_education("master", "Master of Business Administration")
        assert score == 1.0

    def test_below_required(self):
        score = _score_education("master", "High School")
        assert score < 0.5

    def test_no_preference(self):
        score = _score_education(None, "Some degree")
        assert score == 0.7


class TestLifestyleScoring:
    def test_diet_match(self):
        score = _score_lifestyle(["vegetarian"], None, None, "vegetarian", None, None)
        assert score == 1.0

    def test_diet_no_match(self):
        score = _score_lifestyle(["vegetarian"], None, None, "non_vegetarian", None, None)
        assert score < 0.5

    def test_no_preference(self):
        score = _score_lifestyle([], None, None, "vegetarian", None, None)
        assert score == 0.7

    def test_smoking_match(self):
        score = _score_lifestyle([], "never", None, None, "never", None)
        assert score == 1.0


class TestFamilyScoring:
    def test_type_match(self):
        score = _score_family(["nuclear"], [], "nuclear", None)
        assert score >= 0.8

    def test_type_no_match(self):
        score = _score_family(["nuclear"], [], "joint", None)
        assert score < 0.6

    def test_no_preference(self):
        score = _score_family([], [], "nuclear", "moderate")
        assert score == 0.7


class TestScoreMessages:
    def test_high_score_message(self):
        msg = _score_message(90)
        assert "highly" in msg.lower() or "compatible" in msg.lower()

    def test_medium_score_message(self):
        msg = _score_message(65)
        assert msg

    def test_low_score_message(self):
        msg = _score_message(30)
        assert msg  # Always returns something

    def test_no_implication_of_perfection(self):
        # Per spec: NEVER claim "perfect for each other"
        msg = _score_message(99)
        assert "perfect" not in msg.lower()
