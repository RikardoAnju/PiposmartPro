import os
import re

path = 'lib/screens/report/omset/laporan_omset_screen.dart'
with open(path, 'r') as f:
    content = f.read()

split_str = "class _CalendarPopup extends StatefulWidget {"
if split_str in content:
    content = content.split(split_str)[0]
    with open(path, 'w') as f:
        f.write(content)
    print("Removed dead code from laporan_omset_screen.dart")
else:
    print("Could not find _CalendarPopup in laporan_omset_screen.dart")
