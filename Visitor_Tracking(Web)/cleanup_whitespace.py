import re

with open('src/components/DashboardPage.vue', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Clean up trailing spaces and fix problematic lines
cleaned_lines = []
for line in lines:
    # Remove trailing whitespace but preserve the newline
    line = line.rstrip() + '\n' if line.endswith('\n') else line.rstrip()
    cleaned_lines.append(line)

# Write back
with open('src/components/DashboardPage.vue', 'w', encoding='utf-8') as f:
    f.writelines(cleaned_lines)

print('Cleaned all trailing whitespace')
