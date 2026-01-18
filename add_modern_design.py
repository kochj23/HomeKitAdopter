#!/usr/bin/env python3
"""
Add ModernDesign.swift to HomeKitAdopter Xcode project
"""

import uuid
import re

# Read the project.pbxproj file
project_path = '/Volumes/Data/xcode/HomeKitAdopter/HomeKitAdopter.xcodeproj/project.pbxproj'
with open(project_path, 'r') as f:
    content = f.read()

# Generate unique IDs for the new file
file_ref_id = str(uuid.uuid4().hex[:24].upper())
build_file_id = str(uuid.uuid4().hex[:24].upper())

# File reference entry
file_ref = f"\t\t{file_ref_id} /* ModernDesign.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ModernDesign.swift; sourceTree = \"<group>\"; }};"

# Build file entry
build_file = f"\t\t{build_file_id} /* ModernDesign.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* ModernDesign.swift */; }};"

# Add file reference
file_ref_section = re.search(r'\/\* Begin PBXFileReference section \*\/', content)
if file_ref_section:
    insert_pos = file_ref_section.end()
    content = content[:insert_pos] + '\n' + file_ref + content[insert_pos:]

# Add build file
build_file_section = re.search(r'\/\* Begin PBXBuildFile section \*\/', content)
if build_file_section:
    insert_pos = build_file_section.end()
    content = content[:insert_pos] + '\n' + build_file + content[insert_pos:]

# Find the HomeKitAdopter group and add the file reference
# Look for the group that contains HomeKitAdopterApp.swift
group_pattern = r'(BB0002 \/\* ContentView\.swift \*\/,)'
match = re.search(group_pattern, content)
if match:
    insert_pos = match.end()
    content = content[:insert_pos] + f'\n\t\t\t\t{file_ref_id} /* ModernDesign.swift */,' + content[insert_pos:]

# Find the Sources build phase and add the build file reference
sources_pattern = r'(AA0002 \/\* ContentView\.swift in Sources \*\/,)'
match = re.search(sources_pattern, content)
if match:
    insert_pos = match.end()
    content = content[:insert_pos] + f'\n\t\t\t\t{build_file_id} /* ModernDesign.swift in Sources */,' + content[insert_pos:]

# Write the modified content back
with open(project_path, 'w') as f:
    f.write(content)

print(f"Successfully added ModernDesign.swift to Xcode project")
print(f"File Reference ID: {file_ref_id}")
print(f"Build File ID: {build_file_id}")
