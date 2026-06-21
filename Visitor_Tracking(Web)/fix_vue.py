import re

with open('src/components/DashboardPage.vue', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the a-table section by replacing multi-line attributes with single line
content = re.sub(
    r'<a-table\s+:data-source="recentLogs"\s+:columns="logColumns"\s+:pagination="\{\s*pageSize:\s*3\s*\}"\s+row-key="id"\s+size="middle"\s*/>',
    '<a-table :data-source="recentLogs" :columns="logColumns" :pagination="{ pageSize: 3 }" row-key="id" size="middle" />',
    content,
    flags=re.DOTALL
)

with open('src/components/DashboardPage.vue', 'w', encoding='utf-8') as f:
    f.write(content)

print('Fixed DashboardPage.vue')
