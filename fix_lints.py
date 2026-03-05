import os
import re

def fix_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    original = content

    # 1. withOpacity(x) -> withValues(alpha: x) 
    #   (Note: in Flutter 3.27+ withOpacity is deprecated in favor of withValues)
    content = re.sub(r'\.withOpacity\(([^)]+)\)', r'.withValues(alpha: \1)', content)

    # 2. Add curly braces to if statements without them (e.g. if (x) return;)
    # Specifically in pdf_import_screen.dart:229 and 230: 
    # "if (v == true) _selected.add(e.id); else _selected.remove(e.id);"
    content = re.sub(r'if \(v == true\) _selected\.add\(e\.id\);', r'if (v == true) { _selected.add(e.id); }', content)
    content = re.sub(r'else _selected\.remove\(e\.id\);', r'else { _selected.remove(e.id); }', content)

    if content != original:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Fixed {path}")

for root, _, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            fix_file(os.path.join(root, file))

print("Done with auto-fixes")
