"""
Standalone script to render premium biodata template.
Works independently without the full app structure.

Installation:
    pip install jinja2 weasyprint

Usage:
    python render_premium_biodata_standalone.py
"""

from jinja2 import Template
from weasyprint import HTML
import json
import os

def load_template(template_path):
    """Load the HTML template file."""
    with open(template_path, 'r', encoding='utf-8') as f:
        return f.read()

def load_profile_data(json_path):
    """Load profile data from JSON file."""
    with open(json_path, 'r', encoding='utf-8') as f:
        return json.load(f)

def render_biodata(template_content, profile_data, output_pdf="biodata_premium.pdf", output_html="biodata_premium_preview.html"):
    """
    Render biodata template to PDF and HTML preview.
    
    Args:
        template_content (str): Jinja2 template HTML content
        profile_data (dict): Profile data dictionary
        output_pdf (str): Output PDF filename
        output_html (str): Output HTML preview filename
    """
    # Create Jinja2 template
    template = Template(template_content)
    
    # Render with profile data
    html_content = template.render(profile=profile_data)
    
    # Save HTML preview
    with open(output_html, 'w', encoding='utf-8') as f:
        f.write(html_content)
    print(f"✓ HTML preview saved: {output_html}")
    
    # Generate PDF
    HTML(string=html_content).write_pdf(output_pdf)
    print(f"✓ PDF generated: {output_pdf}")
    print(f"  Profile: {profile_data.get('name', 'Unknown')}")
    print(f"  Size: {os.path.getsize(output_pdf) / 1024:.1f} KB")

def main():
    """Main execution function."""
    # File paths
    template_path = "app/utils/templates/biodata_premium_wedding.html"
    json_path = "example_profile_data.json"
    
    # Check if files exist
    if not os.path.exists(template_path):
        print(f"❌ Template file not found: {template_path}")
        print("   Make sure you're running this from the backend/ directory")
        return
    
    if not os.path.exists(json_path):
        print(f"❌ Profile data file not found: {json_path}")
        return
    
    # Load template and data
    print("Loading template and profile data...")
    template_content = load_template(template_path)
    profile_data = load_profile_data(json_path)
    
    # Render biodata
    print("Rendering biodata...")
    render_biodata(template_content, profile_data)
    
    print("\n✓ Done! Open biodata_premium_preview.html in your browser to preview.")

if __name__ == "__main__":
    main()
