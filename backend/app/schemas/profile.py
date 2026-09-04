"""Profile-related schemas."""
from datetime import date
from typing import List, Optional
from uuid import UUID
from pydantic import BaseModel, field_validator, model_validator
from enum import Enum


class GenderEnum(str, Enum):
    male = "male"
    female = "female"
    other = "other"


class MaritalStatusEnum(str, Enum):
    never_married = "never_married"
    divorced = "divorced"
    widowed = "widowed"
    separated = "separated"


class DietEnum(str, Enum):
    vegetarian = "vegetarian"
    non_vegetarian = "non_vegetarian"
    eggetarian = "eggetarian"
    vegan = "vegan"
    jain = "jain"
    other = "other"


class FamilyTypeEnum(str, Enum):
    nuclear = "nuclear"
    joint = "joint"
    extended = "extended"


class FamilyValuesEnum(str, Enum):
    traditional = "traditional"
    moderate = "moderate"
    liberal = "liberal"


class EmploymentTypeEnum(str, Enum):
    salaried = "salaried"
    self_employed = "self_employed"
    business = "business"
    government = "government"
    not_working = "not_working"
    student = "student"
    other = "other"


class PreferenceImportanceEnum(str, Enum):
    must_have = "must_have"
    preferred = "preferred"
    doesnt_matter = "doesnt_matter"


# ---------------------------------------------------------------------------
# Profile
# ---------------------------------------------------------------------------

class ProfileCreateRequest(BaseModel):
    full_name: str
    gender: GenderEnum
    date_of_birth: date
    height_cm: Optional[int] = None
    marital_status: MaritalStatusEnum = MaritalStatusEnum.never_married
    have_children: bool = False
    children_count: int = 0
    mother_tongue: Optional[str] = None
    languages_known: Optional[List[str]] = None
    religion: Optional[str] = None
    caste: Optional[str] = None
    sub_caste: Optional[str] = None
    about_me: Optional[str] = None

    @field_validator("full_name")
    @classmethod
    def validate_name(cls, v: str) -> str:
        v = v.strip()
        if len(v) < 2:
            raise ValueError("Name must be at least 2 characters")
        if len(v) > 255:
            raise ValueError("Name too long")
        return v

    @field_validator("date_of_birth")
    @classmethod
    def validate_dob(cls, v: date) -> date:
        from datetime import date as d, timedelta
        today = d.today()
        min_age_date = today.replace(year=today.year - 18)
        if v > min_age_date:
            raise ValueError("Must be at least 18 years old")
        max_age_date = today.replace(year=today.year - 80)
        if v < max_age_date:
            raise ValueError("Invalid date of birth")
        return v

    @field_validator("height_cm")
    @classmethod
    def validate_height(cls, v: Optional[int]) -> Optional[int]:
        if v is not None and not (100 <= v <= 250):
            raise ValueError("Height must be between 100cm and 250cm")
        return v

    @field_validator("about_me")
    @classmethod
    def validate_about(cls, v: Optional[str]) -> Optional[str]:
        if v and len(v) > 2000:
            raise ValueError("About me must be under 2000 characters")
        return v


class ProfileUpdateRequest(ProfileCreateRequest):
    full_name: Optional[str] = None
    gender: Optional[GenderEnum] = None
    date_of_birth: Optional[date] = None


class ProfileResponse(BaseModel):
    id: UUID
    user_id: UUID
    full_name: str
    gender: str
    date_of_birth: date
    age: int
    height_cm: Optional[int]
    height_display: Optional[str]  # e.g. "5'7\""
    marital_status: str
    have_children: bool
    children_count: int
    mother_tongue: Optional[str]
    languages_known: Optional[List[str]]
    religion: Optional[str]
    caste: Optional[str]
    sub_caste: Optional[str]
    about_me: Optional[str]
    profile_visibility: str
    photo_visibility: str
    completion_percentage: int
    is_verified: bool

    class Config:
        from_attributes = True


# ---------------------------------------------------------------------------
# Location
# ---------------------------------------------------------------------------

class LocationRequest(BaseModel):
    country: str = "India"
    state: Optional[str] = None
    district: Optional[str] = None
    city: Optional[str] = None

    @field_validator("country", "state", "district", "city")
    @classmethod
    def clean_str(cls, v: Optional[str]) -> Optional[str]:
        return v.strip() if v else v


class LocationResponse(BaseModel):
    country: str
    state: Optional[str]
    district: Optional[str]
    city: Optional[str]


# ---------------------------------------------------------------------------
# Education
# ---------------------------------------------------------------------------

class EducationRequest(BaseModel):
    highest_qualification: Optional[str] = None
    degree: Optional[str] = None
    field_of_study: Optional[str] = None
    college_university: Optional[str] = None
    graduation_year: Optional[int] = None
    additional_qualifications: Optional[str] = None

    @field_validator("graduation_year")
    @classmethod
    def validate_year(cls, v: Optional[int]) -> Optional[int]:
        if v is not None:
            from datetime import date
            current_year = date.today().year
            if not (1960 <= v <= current_year + 6):
                raise ValueError(f"Graduation year must be between 1960 and {current_year + 6}")
        return v


class EducationResponse(BaseModel):
    highest_qualification: Optional[str]
    degree: Optional[str]
    field_of_study: Optional[str]
    college_university: Optional[str]
    graduation_year: Optional[int]
    additional_qualifications: Optional[str]


# ---------------------------------------------------------------------------
# Employment
# ---------------------------------------------------------------------------

class EmploymentRequest(BaseModel):
    profession: Optional[str] = None
    job_title: Optional[str] = None
    company: Optional[str] = None
    industry: Optional[str] = None
    employment_type: Optional[EmploymentTypeEnum] = None
    work_location: Optional[str] = None
    income_min_lpa: Optional[float] = None
    income_max_lpa: Optional[float] = None
    show_company: bool = True
    show_income: bool = False

    @model_validator(mode="after")
    def validate_income_range(self) -> "EmploymentRequest":
        if self.income_min_lpa is not None and self.income_max_lpa is not None:
            if self.income_min_lpa > self.income_max_lpa:
                raise ValueError("Minimum income cannot exceed maximum income")
        return self


class EmploymentResponse(BaseModel):
    profession: Optional[str]
    job_title: Optional[str]
    company: Optional[str]      # None if show_company=False for others
    industry: Optional[str]
    employment_type: Optional[str]
    work_location: Optional[str]
    income_min_lpa: Optional[float]   # None if show_income=False for others
    income_max_lpa: Optional[float]
    show_company: bool
    show_income: bool


# ---------------------------------------------------------------------------
# Family Details
# ---------------------------------------------------------------------------

class FamilyDetailsRequest(BaseModel):
    father_name: Optional[str] = None
    father_occupation: Optional[str] = None
    father_is_alive: bool = True
    mother_name: Optional[str] = None
    mother_occupation: Optional[str] = None
    mother_is_alive: bool = True
    brothers_count: int = 0
    brothers_married: int = 0
    sisters_count: int = 0
    sisters_married: int = 0
    family_type: Optional[FamilyTypeEnum] = None
    family_values: Optional[FamilyValuesEnum] = None
    family_location: Optional[str] = None
    additional_info: Optional[str] = None
    show_parents_info: bool = True

    @model_validator(mode="after")
    def validate_siblings(self) -> "FamilyDetailsRequest":
        if self.brothers_married > self.brothers_count:
            raise ValueError("Married brothers cannot exceed total brothers")
        if self.sisters_married > self.sisters_count:
            raise ValueError("Married sisters cannot exceed total sisters")
        return self


class FamilyDetailsResponse(BaseModel):
    father_name: Optional[str]
    father_occupation: Optional[str]
    father_is_alive: bool
    mother_name: Optional[str]
    mother_occupation: Optional[str]
    mother_is_alive: bool
    brothers_count: int
    brothers_married: int
    sisters_count: int
    sisters_married: int
    family_type: Optional[str]
    family_values: Optional[str]
    family_location: Optional[str]
    additional_info: Optional[str]


# ---------------------------------------------------------------------------
# Lifestyle
# ---------------------------------------------------------------------------

class LifestyleRequest(BaseModel):
    diet: Optional[DietEnum] = None
    smoking: Optional[str] = None
    drinking: Optional[str] = None
    fitness: Optional[str] = None
    hobbies: Optional[List[str]] = None
    interests: Optional[List[str]] = None
    travel: Optional[str] = None
    pets: bool = False
    pet_types: Optional[List[str]] = None
    other_info: Optional[str] = None

    @field_validator("hobbies", "interests", "pet_types")
    @classmethod
    def validate_list(cls, v: Optional[List[str]]) -> Optional[List[str]]:
        if v and len(v) > 20:
            raise ValueError("Too many items in list")
        return v


class LifestyleResponse(BaseModel):
    diet: Optional[str]
    smoking: Optional[str]
    drinking: Optional[str]
    fitness: Optional[str]
    hobbies: Optional[List[str]]
    interests: Optional[List[str]]
    travel: Optional[str]
    pets: bool
    pet_types: Optional[List[str]]
    other_info: Optional[str]


# ---------------------------------------------------------------------------
# Partner Preferences
# ---------------------------------------------------------------------------

class PartnerPreferencesRequest(BaseModel):
    min_age: Optional[int] = None
    max_age: Optional[int] = None
    age_importance: PreferenceImportanceEnum = PreferenceImportanceEnum.preferred
    min_height_cm: Optional[int] = None
    max_height_cm: Optional[int] = None
    height_importance: PreferenceImportanceEnum = PreferenceImportanceEnum.doesnt_matter
    preferred_countries: Optional[List[str]] = None
    preferred_states: Optional[List[str]] = None
    preferred_cities: Optional[List[str]] = None
    location_importance: PreferenceImportanceEnum = PreferenceImportanceEnum.preferred
    preferred_native_states: Optional[List[str]] = None
    preferred_native_districts: Optional[List[str]] = None
    native_place_importance: PreferenceImportanceEnum = PreferenceImportanceEnum.preferred
    min_education: Optional[str] = None
    preferred_fields: Optional[List[str]] = None
    education_importance: PreferenceImportanceEnum = PreferenceImportanceEnum.preferred
    preferred_professions: Optional[List[str]] = None
    min_income_lpa: Optional[float] = None
    income_importance: PreferenceImportanceEnum = PreferenceImportanceEnum.doesnt_matter
    preferred_marital_status: Optional[List[MaritalStatusEnum]] = None
    preferred_mother_tongues: Optional[List[str]] = None
    preferred_religions: Optional[List[str]] = None
    preferred_castes: Optional[List[str]] = None
    preferred_diet: Optional[List[DietEnum]] = None
    smoking_preference: Optional[str] = None
    drinking_preference: Optional[str] = None
    lifestyle_importance: PreferenceImportanceEnum = PreferenceImportanceEnum.preferred
    preferred_family_types: Optional[List[FamilyTypeEnum]] = None
    preferred_family_values: Optional[List[FamilyValuesEnum]] = None
    open_to_relocation: bool = True
    want_children: Optional[bool] = None
    other_expectations: Optional[str] = None

    @model_validator(mode="after")
    def validate_age_range(self) -> "PartnerPreferencesRequest":
        if self.min_age and self.max_age:
            if self.min_age > self.max_age:
                raise ValueError("Minimum age cannot exceed maximum age")
            if self.min_age < 18:
                raise ValueError("Minimum age must be at least 18")
        return self


class PartnerPreferencesResponse(PartnerPreferencesRequest):
    pass


# ---------------------------------------------------------------------------
# Full profile (aggregated view)
# ---------------------------------------------------------------------------

class FullProfileResponse(BaseModel):
    profile: ProfileResponse
    member_id: Optional[str] = None
    current_location: Optional[LocationResponse]
    native_place: Optional[LocationResponse]
    education: Optional[EducationResponse]
    employment: Optional[EmploymentResponse]
    family: Optional[FamilyDetailsResponse]
    lifestyle: Optional[LifestyleResponse]
    primary_photo_url: Optional[str]
    photo_count: int
    compatibility_score: Optional[int] = None


# ---------------------------------------------------------------------------
# Photo
# ---------------------------------------------------------------------------

class PhotoResponse(BaseModel):
    id: UUID
    url: str
    thumbnail_url: Optional[str]
    is_primary: bool
    display_order: int
    file_size_bytes: int
    created_at: str
