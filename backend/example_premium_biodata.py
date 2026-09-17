"""
Example script to render the premium wedding biodata template to PDF using WeasyPrint.

Installation:
    pip install jinja2 weasyprint

Usage:
    python example_premium_biodata.py
"""

from jinja2 import Environment, FileSystemLoader
from weasyprint import HTML
import os

# Sample profile data
profile_data = {
    "name": "Priya Sharma",
    "photo_url": "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=400&h=500&fit=crop",
    "age": "28",
    "date_of_birth": "15th March 1996",
    "height": "5'5\"",
    "weight": "55 kg",
    "blood_group": "B+",
    "marital_status": "Never Married",
    "religion": "Hindu",
    "caste": "Brahmin",
    "sub_caste": "Saryupari",
    "gotra": "Kashyap",
    "manglik": "No",
    "native_place": "Varanasi, Uttar Pradesh",
    "current_city": "Bangalore, Karnataka",
    
    "highest_qualification": "Master of Computer Applications (MCA)",
    "university": "Delhi University",
    "additional_education": "AWS Certified Solutions Architect",
    
    "occupation": "Senior Software Engineer",
    "company": "Tech Mahindra",
    "annual_income": "₹18 LPA",
    "work_mode": "Hybrid (3 days office)",
    "career_focus": "Moving towards cloud architecture and team leadership",
    
    "father": "Mr. Rajesh Sharma (Retired IAS Officer)",
    "mother": "Mrs. Sunita Sharma (Homemaker)",
    "siblings": "1 Elder Brother (Married, Software Engineer)",
    "family_type": "Nuclear Family",
    "family_values": "Traditional with modern outlook",
    
    "hobbies": "Reading, Classical Dance (Kathak), Yoga, Traveling",
    "diet": "Vegetarian",
    "smoking": "No",
    "drinking": "Occasionally (Social)",
    "languages": "Hindi, English, Kannada",
    
    "partner_age": "28-33 Years",
    "partner_height": "5'8\" and above",
    "partner_education": "Graduate or higher in any field",
    "partner_profession": "Well-settled professional (Engineer/Doctor/Business)",
    "partner_location": "Open to Bangalore, Mumbai, Delhi NCR or abroad",
    "partner_values": "Family-oriented, respectful, believes in mutual growth",
    
    "photo_quote": "Grateful for the journey, excited for the life ahead.",
    "about_partner": "Looking for a life partner to share a journey of love, respect, growth and happiness."
}

def render_biodata_pdf(profile, output_filename="biodata_premium.pdf"):
    """
    Render the premium wedding biodata template to PDF.
    
    Args:
        profile (dict): Profile data dictionary
        output_filename (str): Output PDF filename
    """
    # Setup Jinja2 environment
    template_dir = os.path.join(os.path.dirname(__file__), "app", "utils", "templates")
    env = Environment(loader=FileSystemLoader(template_dir))
    
    # Load template
    template = env.get_template("biodata_premium_wedding.html")
    
    # Render HTML with profile data
    html_content = template.render(profile=profile)
    
    # Convert to PDF using WeasyPrint
    HTML(string=html_content).write_pdf(output_filename)
    
    print(f"✓ PDF generated successfully: {output_filename}")
    print(f"  Profile: {profile['name']}")
    print(f"  Size: {os.path.getsize(output_filename) / 1024:.1f} KB")

if __name__ == "__main__":
    # Generate PDF
    render_biodata_pdf(profile_data)
    
    # Also save HTML for preview
    template_dir = os.path.join(os.path.dirname(__file__), "app", "utils", "templates")
    env = Environment(loader=FileSystemLoader(template_dir))
    template = env.get_template("biodata_premium_wedding.html")
    html_content = template.render(profile=profile_data)
    
    with open("biodata_premium_preview.html", "w", encoding="utf-8") as f:
        f.write(html_content)
    print("✓ HTML preview saved: biodata_premium_preview.html")
