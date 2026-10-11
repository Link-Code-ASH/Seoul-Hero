"""Contact sheet from final raster assets, without editing the source art."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
FONT_DIR = ROOT.parents[3] / 'godot' / 'assets' / 'ui' / 'fonts'

def main():
    font = ImageFont.truetype(str(FONT_DIR / 'Paperlogy-6SemiBold.ttf'), 18)
    small = ImageFont.truetype(str(FONT_DIR / 'Paperlogy-4Regular.ttf'), 14)
    sheet = Image.new('RGBA', (1328, 1218), '#FBF6EC')
    draw = ImageDraw.Draw(sheet)
    draw.text((24, 16), '협회 운영 UI · 배경과 공통 유리 소재', font=font, fill='#24395C')
    backgrounds = [('settings', '설정 · 장비 제어실'), ('archive', '자료집 · 기록 보관실'),
                   ('association', '협회 · 업무 접수처'), ('gate', '출동 · 작전 준비실')]
    for i, (name, label) in enumerate(backgrounds):
        x, y = 24 + (i % 2) * 652, 54 + (i // 2) * 314
        image = Image.open(ROOT / 'assets' / f'bg_{name}.png').convert('RGBA')
        image.thumbnail((628, 283), Image.Resampling.LANCZOS)
        sheet.alpha_composite(image, (x, y))
        draw.text((x, y + 286), label, font=small, fill='#24395C')
    materials = [('glass_panel', '본문 유리판 · 512×384', (24, 710), (384, 288)),
                 ('glass_header', '헤더 소재 · 1024×128', (446, 710), (838, 105)),
                 ('glass_button', '밝은 버튼 · 512×160', (446, 854), (400, 125)),
                 ('glass_button_navy', '남색 행동 버튼 · 512×160', (872, 854), (400, 125)),
                 ('glass_row', '목록·정보 행 · 512×112', (446, 1025), (838, 154))]
    for name, label, position, size in materials:
        image = Image.open(ROOT / 'assets' / f'{name}.png').convert('RGBA')
        image.thumbnail(size, Image.Resampling.LANCZOS)
        sheet.alpha_composite(image, position)
        draw.text((position[0], position[1] + image.height + 7), label, font=small, fill='#24395C')
    sheet.convert('RGB').save(ROOT / 'contact_sheet.png')
    print(ROOT / 'contact_sheet.png')

if __name__ == '__main__':
    main()
