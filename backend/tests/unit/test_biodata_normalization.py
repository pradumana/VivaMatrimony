"""
Unit tests for biodata data normalization functions.
Tests null handling, text normalization, array cleaning, and privacy filters.
"""
import pytest
from app.services.biodata_service import (
    _normalize_text,
    _normalize_array,
    _normalize_education,
    _normalize_family,
    _normalize_lifestyle,
    _filter_employment,
    _format_location,
    _format_enum,
)


class TestNormalizeText:
    """Test _normalize_text function."""
    
    def test_null_input(self):
        assert _normalize_text(None) is None
    
    def test_empty_string(self):
        assert _normalize_text("") is None
    
    def test_whitespace_only(self):
        assert _normalize_text("   ") is None
    
    def test_leading_trailing_whitespace(self):
        assert _normalize_text("  Hello  ") == "Hello"
    
    def test_normal_text(self):
        assert _normalize_text("Praduman Sharma") == "Praduman Sharma"
    
    def test_multiline_text(self):
        result = _normalize_text("  Line 1\n  Line 2  ")
        assert result == "Line 1\n  Line 2"


class TestNormalizeArray:
    """Test _normalize_array function."""
    
    def test_null_input(self):
        assert _normalize_array(None) is None
    
    def test_empty_array(self):
        assert _normalize_array([]) is None
    
    def test_array_with_empty_strings(self):
        assert _normalize_array(["", "  ", ""]) is None
    
    def test_array_with_mixed_content(self):
        result = _normalize_array(["Reading", "  ", "Cooking", "", "Travel"])
        assert result == ["Reading", "Cooking", "Travel"]
    
    def test_array_with_whitespace(self):
        result = _normalize_array(["  Reading  ", "Cooking"])
        assert result == ["Reading", "Cooking"]
    
    def test_array_all_valid(self):
        result = _normalize_array(["Reading", "Cooking", "Photography"])
        assert result == ["Reading", "Cooking", "Photography"]


class TestNormalizeEducation:
    """Test _normalize_education function."""
    
    def test_null_input(self):
        assert _normalize_education(None) is None
    
    def test_empty_dict(self):
        assert _normalize_education({}) is None
    
    def test_all_null_fields(self):
        education = {
            "highest_qualification": None,
            "degree": None,
            "field_of_study": None,
            "college_university": None,
            "additional_qualifications": None,
        }
        assert _normalize_education(education) is None
    
    def test_all_empty_strings(self):
        education = {
            "highest_qualification": "",
            "degree": "  ",
            "field_of_study": "",
        }
        assert _normalize_education(education) is None
    
    def test_partial_data(self):
        education = {
            "degree": "B.Tech",
            "field_of_study": "Aerospace Engineering",
            "college_university": None,
        }
        result = _normalize_education(education)
        assert result is not None
        assert result["degree"] == "B.Tech"
        assert result["field_of_study"] == "Aerospace Engineering"
    
    def test_whitespace_trimming(self):
        education = {
            "degree": "  B.Tech  ",
            "college_university": "  Amity University  ",
        }
        result = _normalize_education(education)
        assert result["degree"] == "B.Tech"
        assert result["college_university"] == "Amity University"


class TestFilterEmployment:
    """Test _filter_employment function with privacy settings."""
    
    def test_null_input(self):
        assert _filter_employment(None) is None
    
    def test_empty_dict(self):
        assert _filter_employment({}) is None
    
    def test_show_company_false(self):
        employment = {
            "profession": "Software Engineer",
            "company": "TechCorp",
            "show_company": False,
        }
        result = _filter_employment(employment)
        assert result["profession"] == "Software Engineer"
        assert result["company"] is None
    
    def test_show_company_true(self):
        employment = {
            "profession": "Software Engineer",
            "company": "TechCorp",
            "show_company": True,
        }
        result = _filter_employment(employment)
        assert result["company"] == "TechCorp"
    
    def test_show_income_false(self):
        employment = {
            "profession": "Engineer",
            "income_min_lpa": 10,
            "income_max_lpa": 15,
            "show_income": False,
        }
        result = _filter_employment(employment)
        assert result["profession"] == "Engineer"
        assert result["income_min_lpa"] is None
        assert result["income_max_lpa"] is None
    
    def test_show_income_true(self):
        employment = {
            "profession": "Engineer",
            "income_min_lpa": 10,
            "income_max_lpa": 15,
            "show_income": True,
        }
        result = _filter_employment(employment)
        assert result["income_min_lpa"] == 10
        assert result["income_max_lpa"] == 15
    
    def test_normalize_text_fields(self):
        employment = {
            "profession": "  Software Engineer  ",
            "job_title": "  Senior Developer  ",
            "show_company": True,
        }
        result = _filter_employment(employment)
        assert result["profession"] == "Software Engineer"
        assert result["job_title"] == "Senior Developer"


class TestNormalizeFamily:
    """Test _normalize_family function with privacy settings."""
    
    def test_null_input(self):
        assert _normalize_family(None) is None
    
    def test_show_parents_info_false(self):
        family = {
            "father_name": "John Sharma",
            "father_occupation": "Businessman",
            "mother_name": "Jane Sharma",
            "mother_occupation": "Teacher",
            "show_parents_info": False,
            "brothers_count": 1,
        }
        result = _normalize_family(family)
        assert result["father_name"] is None
        assert result["father_occupation"] is None
        assert result["mother_name"] is None
        assert result["mother_occupation"] is None
        assert result["brothers_count"] == 1  # Siblings not affected
    
    def test_show_parents_info_true(self):
        family = {
            "father_name": "John Sharma",
            "mother_name": "Jane Sharma",
            "show_parents_info": True,
        }
        result = _normalize_family(family)
        assert result["father_name"] == "John Sharma"
        assert result["mother_name"] == "Jane Sharma"
    
    def test_normalize_non_parent_fields(self):
        family = {
            "show_parents_info": False,
            "family_location": "  Delhi  ",
            "additional_info": "  Close-knit family  ",
        }
        result = _normalize_family(family)
        assert result["family_location"] == "Delhi"
        assert result["additional_info"] == "Close-knit family"
    
    def test_siblings_only(self):
        family = {
            "brothers_count": 2,
            "sisters_count": 1,
            "brothers_married": 1,
            "sisters_married": 0,
        }
        result = _normalize_family(family)
        assert result is not None
        assert result["brothers_count"] == 2
        assert result["sisters_count"] == 1


class TestNormalizeLifestyle:
    """Test _normalize_lifestyle function."""
    
    def test_null_input(self):
        assert _normalize_lifestyle(None) is None
    
    def test_normalize_hobbies_array(self):
        lifestyle = {
            "hobbies": ["Reading", "  ", "Cooking", ""],
        }
        result = _normalize_lifestyle(lifestyle)
        assert result["hobbies"] == ["Reading", "Cooking"]
    
    def test_empty_hobbies_array(self):
        lifestyle = {
            "hobbies": ["", "  "],
            "diet": "Vegetarian",
        }
        result = _normalize_lifestyle(lifestyle)
        assert result["hobbies"] is None
        assert result["diet"] == "Vegetarian"
    
    def test_normalize_text_fields(self):
        lifestyle = {
            "fitness": "  Regular gym  ",
            "other_info": "  Enjoys outdoor activities  ",
        }
        result = _normalize_lifestyle(lifestyle)
        assert result["fitness"] == "Regular gym"
        assert result["other_info"] == "Enjoys outdoor activities"
    
    def test_all_empty(self):
        lifestyle = {
            "diet": None,
            "hobbies": [],
            "fitness": "",
        }
        assert _normalize_lifestyle(lifestyle) is None


class TestFormatLocation:
    """Test _format_location function."""
    
    def test_null_input(self):
        assert _format_location(None) is None
    
    def test_empty_dict(self):
        assert _format_location({}) is None
    
    def test_all_fields(self):
        location = {
            "city": "Delhi",
            "district": "Central Delhi",
            "state": "Delhi",
            "country": "India",
        }
        assert _format_location(location) == "Delhi, Central Delhi, Delhi, India"
    
    def test_partial_fields(self):
        location = {
            "city": "Mumbai",
            "state": "Maharashtra",
        }
        assert _format_location(location) == "Mumbai, Maharashtra"
    
    def test_single_field(self):
        location = {"city": "Bangalore"}
        assert _format_location(location) == "Bangalore"
    
    def test_none_values(self):
        location = {
            "city": "Delhi",
            "district": None,
            "state": "Delhi",
        }
        assert _format_location(location) == "Delhi, Delhi"


class TestFormatEnum:
    """Test _format_enum function."""
    
    def test_empty_string(self):
        assert _format_enum("") == ""
    
    def test_underscore_to_space(self):
        assert _format_enum("never_married") == "Never Married"
    
    def test_multiple_underscores(self):
        assert _format_enum("awaiting_divorce") == "Awaiting Divorce"
    
    def test_already_formatted(self):
        assert _format_enum("Married") == "Married"
    
    def test_lowercase(self):
        assert _format_enum("single") == "Single"


class TestEdgeCases:
    """Test edge cases and stress scenarios."""
    
    def test_very_long_text(self):
        long_text = "A" * 5000
        result = _normalize_text(long_text)
        assert result == long_text
    
    def test_unicode_text(self):
        text = "संदीप शर्मा"
        result = _normalize_text(text)
        assert result == "संदीप शर्मा"
    
    def test_special_characters(self):
        text = "Company & Co. Pvt. Ltd."
        result = _normalize_text(text)
        assert result == "Company & Co. Pvt. Ltd."
    
    def test_large_hobbies_array(self):
        hobbies = [f"Hobby_{i}" for i in range(50)]
        lifestyle = {"hobbies": hobbies}
        result = _normalize_lifestyle(lifestyle)
        assert len(result["hobbies"]) == 50
    
    def test_mixed_none_and_empty_in_array(self):
        mixed = ["Valid", None, "", "  ", "Another Valid"]
        result = _normalize_array(mixed)
        assert result == ["Valid", "Another Valid"]
