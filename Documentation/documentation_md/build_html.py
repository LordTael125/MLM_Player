import os
import glob
import markdown

header = """<!doctype html>
<html>
    <head>
        <meta charset="UTF-8" />
        <title>Modern Music Player Handbook</title>
        <style>
            body {
                font-family:
                    "Inter",
                    -apple-system,
                    BlinkMacSystemFont,
                    "Segoe UI",
                    Roboto,
                    sans-serif;
                line-height: 1.6;
                color: #333;
                max-width: 900px;
                margin: 0 auto;
                padding: 40px;
                background: #fff;
            }
            h1,
            h2,
            h3,
            h4 {
                color: #1a1a1a;
                margin-top: 2em;
            }
            h1 {
                font-size: 2.5em;
                border-bottom: 2px solid #eee;
                padding-bottom: 10px;
            }
            h2 {
                font-size: 1.8em;
                border-left: 5px solid #6200ee;
                padding-left: 15px;
            }

            code {
                font-family: "Fira Code", "Consolas", monospace;
                background: #f4f4f4;
                padding: 2px 5px;
                border-radius: 4px;
                font-size: 0.9em;
            }
            pre {
                background: #f8f8f8;
                padding: 15px;
                border-radius: 8px;
                overflow-x: auto;
                border: 1px solid #eee;
            }
            pre code {
                background: none;
                padding: 0;
            }

            /* TABLE STYLING - UNIFORM COLUMN SIZES */
            table {
                width: 100%;
                border-collapse: collapse;
                margin: 20px 0;
                table-layout: fixed; /* Force uniform column distribution */
            }
            th,
            td {
                border: 1px solid #ddd;
                padding: 12px;
                text-align: left;
                word-wrap: break-word; /* Ensure text doesn't break table layout */
            }
            th {
                background-color: #f2f2f2;
                font-weight: bold;
            }
            tr:nth-child(even) {
                background-color: #fafafa;
            }

            /* Special rule for 2-column tables to be 50/50 */
            table tr th:only-child,
            table tr td:only-child {
                width: auto;
            }

            /* Handle specific table patterns discovered in chapters */
            /* Chapter 10, 15 etc often have 2 or 3 columns */

            /* Theme Toggle Button */
            .theme-toggle-btn {
                position: fixed;
                top: 20px;
                left: 20px;
                background: #ffffff;
                color: #333333;
                border: 1px solid #ddd;
                border-radius: 50%;
                width: 48px;
                height: 48px;
                display: flex;
                align-items: center;
                justify-content: center;
                cursor: pointer;
                box-shadow: 0 4px 6px rgba(0,0,0,0.1);
                z-index: 1000;
                transition: all 0.3s ease;
            }
            .theme-toggle-btn:hover {
                transform: scale(1.05);
                box-shadow: 0 6px 8px rgba(0,0,0,0.15);
            }
            body.dark-mode .theme-toggle-btn {
                background: #2a2a2a;
                color: #f8f8f8;
                border-color: #444;
            }

            /* Dark Mode Styles */
            body.dark-mode {
                background: #121212;
                color: #e0e0e0;
            }
            body.dark-mode h1,
            body.dark-mode h2,
            body.dark-mode h3,
            body.dark-mode h4 {
                color: #ffffff;
            }
            body.dark-mode h1 {
                border-bottom: 2px solid #333;
            }
            body.dark-mode code {
                background: #2a2a2a;
                color: #f8f8f8;
            }
            body.dark-mode pre {
                background: #1e1e1e;
                border: 1px solid #333;
            }
            body.dark-mode table th {
                background-color: #333;
            }
            body.dark-mode table td, body.dark-mode table th {
                border: 1px solid #444;
            }
            body.dark-mode tr:nth-child(even) {
                background-color: #1a1a1a;
            }
            body.dark-mode a {
                color: #bb86fc;
            }
            
            @media print {
                .theme-toggle-btn { display: none; }
                body {
                    padding: 0;
                    margin: 1in;
                    font-size: 12pt;
                }
                h1,
                h2,
                h3 {
                    page-break-after: avoid;
                }
                pre,
                blockquote,
                table {
                    page-break-inside: avoid;
                }
                .page-break {
                    page-break-before: always;
                }
            }
        </style>
    </head>
    <body>
        <button class="theme-toggle-btn" onclick="toggleTheme()" title="Toggle Light/Dark Mode">
            <svg id="theme-icon-sun" xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="5"></circle><line x1="12" y1="1" x2="12" y2="3"></line><line x1="12" y1="21" x2="12" y2="23"></line><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"></line><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"></line><line x1="1" y1="12" x2="3" y2="12"></line><line x1="21" y1="12" x2="23" y2="12"></line><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"></line><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"></line></svg>
            <svg id="theme-icon-moon" xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="display:none;"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path></svg>
        </button>
"""

footer = """
        <script>
            function updateIcon(isDark) {
                document.getElementById('theme-icon-sun').style.display = isDark ? 'none' : 'block';
                document.getElementById('theme-icon-moon').style.display = isDark ? 'block' : 'none';
            }

            function toggleTheme() {
                document.body.classList.toggle('dark-mode');
                const isDark = document.body.classList.contains('dark-mode');
                localStorage.setItem('theme', isDark ? 'dark' : 'light');
                updateIcon(isDark);
            }
            
            // Load saved theme on load, or fallback to OS preference
            let isDark = false;
            if (localStorage.getItem('theme') === 'dark') {
                isDark = true;
            } else if (!localStorage.getItem('theme') && window.matchMedia('(prefers-color-scheme: dark)').matches) {
                isDark = true;
            }
            
            if (isDark) {
                document.body.classList.add('dark-mode');
            }
            // Ensure correct icon is shown immediately
            updateIcon(isDark);
        </script>
    </body>
</html>
"""

def main():
    base_dir = "/home/lordtael125/HDD/Work_Files/codes/git-repo/MLM_Player/Documentation/documentation_md"
    os.chdir(base_dir)
    
    import re

    # Read files
    files = ["README.md"] + sorted(glob.glob("[0-2]*.md"))
    
    full_markdown = ""
    for idx, f in enumerate(files):
        with open(f, 'r', encoding='utf-8') as file:
            content = file.read()
            if f != "README.md":
                full_markdown += f'<a id="{f}"></a>\n\n'
            full_markdown += content + "\n\n<div class=\"page-break\"></div>\n\n"
            
    # Convert local markdown links to internal anchor links
    full_markdown = re.sub(r'\]\(([^)]+\.md)\)', r'](#\1)', full_markdown)

    # Also save the concatenated markdown
    with open("ModernMusicPlayer_Handbook_Book.md", "w", encoding='utf-8') as f:
        f.write(full_markdown)
    with open("ModernMusicPlayer_Handbook_Book_Formatted.md", "w", encoding='utf-8') as f:
        f.write(full_markdown)
        
    html_content = markdown.markdown(full_markdown, extensions=['tables', 'fenced_code', 'toc'])
    
    with open("../ModernMusicPlayer_Handbook_Book.html", "w", encoding='utf-8') as f:
        f.write(header + html_content + footer)

if __name__ == "__main__":
    main()
