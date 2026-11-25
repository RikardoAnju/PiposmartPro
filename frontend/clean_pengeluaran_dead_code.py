import os
import re

path = 'lib/screens/report/pengeluaran/laporan_pengeluaran_screen.dart'
with open(path, 'r') as f:
    content = f.read()

# _CalendarPopup is around line 754 and ends at the bottom of the file (around 1118)
# We can just remove everything from `class _CalendarPopup extends StatefulWidget` to the end of the file.
# Since it's the last thing in the file, we can easily slice it.

split_str = "class _CalendarPopup extends StatefulWidget {"
if split_str in content:
    content = content.split(split_str)[0]
    with open(path, 'w') as f:
        f.write(content)
    print("Removed dead code from laporan_pengeluaran_screen.dart")
else:
    print("Could not find _CalendarPopup in laporan_pengeluaran_screen.dart")
