"""Builds keyburn-packaging-damage-guide.pdf for the Phase 13b visual source.

The PDF's text layer deliberately does NOT say what to do for each damage grade. That
instruction exists only as pixels inside the illustration, so the index can only learn it
if Intelligent Context's LLM-based parsing actually reads the image. The s3_visual_* evals
assert those image-only facts. Run: py -3.12 s3-docs/visual/make_damage_guide.py
"""
from pathlib import Path

from fpdf import FPDF
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).parent
PNG = HERE / "damage_grades.png"
PDF = HERE / "keyburn-packaging-damage-guide.pdf"
FONT = "C:/Windows/Fonts/arial.ttf"
FONT_BOLD = "C:/Windows/Fonts/arialbd.ttf"

# (grade, damage, action lines, colour)
GRADES = [
    ("A", "Dented corner", ["Accept the parcel.", "The contents are protected."], (46, 125, 50)),
    ("B", "Crushed side or puncture", ["Accept the parcel, open it", "and check the item. If the item",
                                       "is damaged, report it with a photo."], (239, 108, 0)),
    ("C", "Wet or torn open", ["Refuse the delivery.", "The carrier returns it and",
                               "a replacement ships automatically."], (198, 40, 40)),
]


def box(draw, x, y, grade):
    """Draws a parcel with the damage that defines its grade."""
    brown, dark = (196, 154, 108), (120, 85, 50)
    top = [(x + 40, y + 60), (x + 190, y + 60), (x + 250, y + 20), (x + 100, y + 20)]
    front = [(x + 40, y + 60), (x + 190, y + 60), (x + 190, y + 200), (x + 40, y + 200)]
    side = [(x + 190, y + 60), (x + 250, y + 20), (x + 250, y + 160), (x + 190, y + 200)]
    for poly, shade in ((top, (214, 178, 136)), (front, brown), (side, (170, 128, 86))):
        draw.polygon(poly, fill=shade, outline=dark)
    draw.line([(x + 115, y + 60), (x + 175, y + 20)], fill=dark, width=3)  # tape
    if grade == "A":
        draw.polygon([(x + 40, y + 60), (x + 70, y + 60), (x + 40, y + 92)], fill=(150, 110, 70), outline=dark)
    elif grade == "B":
        draw.line([(x + 60, y + 110), (x + 120, y + 130), (x + 170, y + 105)], fill=dark, width=5)
        draw.ellipse([(x + 95, y + 150), (x + 125, y + 175)], fill=(60, 40, 25))
    else:
        for i in range(5):
            draw.ellipse([(x + 60 + i * 25, y + 160 + (i % 2) * 12), (x + 80 + i * 25, y + 185 + (i % 2) * 12)],
                         fill=(90, 140, 200))
        draw.line([(x + 100, y + 20), (x + 130, y + 45), (x + 110, y + 60)], fill=(255, 255, 255), width=6)
        draw.line([(x + 190, y + 90), (x + 215, y + 120), (x + 200, y + 150)], fill=(255, 255, 255), width=6)


def make_png():
    w, h = 1500, 620
    img = Image.new("RGB", (w, h), "white")
    d = ImageDraw.Draw(img)
    title_f = ImageFont.truetype(FONT_BOLD, 34)
    head_f = ImageFont.truetype(FONT_BOLD, 28)
    label_f = ImageFont.truetype(FONT, 24)
    body_f = ImageFont.truetype(FONT, 23)
    d.text((40, 25), "What to do when your parcel arrives damaged", font=title_f, fill=(33, 33, 33))
    for i, (grade, damage, lines, colour) in enumerate(GRADES):
        x = 40 + i * 490
        d.rounded_rectangle([(x, 90), (x + 460, 590)], radius=18, outline=colour, width=4)
        d.rounded_rectangle([(x, 90), (x + 460, 145)], radius=18, fill=colour)
        d.text((x + 20, 100), f"Grade {grade}", font=head_f, fill="white")
        box(d, x + 95, 160, grade)
        d.text((x + 20, 380), damage, font=label_f, fill=(66, 66, 66))
        d.line([(x + 20, 420), (x + 440, 420)], fill=(200, 200, 200), width=2)
        for j, line in enumerate(lines):
            d.text((x + 20, 440 + j * 34), line, font=body_f, fill=(33, 33, 33))
    img.save(PNG)


def make_pdf():
    pdf = FPDF(orientation="L", unit="mm", format="A4")
    pdf.set_auto_page_break(False)
    pdf.add_page()
    pdf.add_font("Arial", "", FONT)
    pdf.add_font("Arial", "B", FONT_BOLD)
    pdf.set_font("Arial", "B", 18)
    pdf.cell(0, 10, "Keyburn Packaging Damage Guide", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Arial", "", 10)
    pdf.cell(0, 6, "Document owner: Keyburn Logistics. Version 1.1, effective 1 September 2026.",
             new_x="LMARGIN", new_y="NEXT")
    pdf.ln(2)
    pdf.set_font("Arial", "", 11)
    pdf.multi_cell(0, 6, "Carriers sometimes deliver parcels with damaged packaging. Keyburn groups "
                         "packaging damage into three grades, A, B and C. Find the picture that matches "
                         "your parcel: each picture shows the grade and what to do.")
    pdf.ln(3)
    pdf.image(str(PNG), x=10, w=277)
    pdf.output(str(PDF))


if __name__ == "__main__":
    make_png()
    make_pdf()
    print(PDF)
