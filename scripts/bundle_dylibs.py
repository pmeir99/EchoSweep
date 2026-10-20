#!/usr/bin/env python3
"""Bundle non-system Mach-O dependencies exactly once, then rewrite install names."""
import os
import pathlib
import shutil
import subprocess
import sys

binary = pathlib.Path(sys.argv[1]).resolve()
frameworks = pathlib.Path(sys.argv[2]).resolve()
frameworks.mkdir(parents=True, exist_ok=True)
brew = pathlib.Path("/opt/homebrew")
seen = {binary}
queue = [binary]
copied = {}
edges = []
MAX_LIBS = 100

def dependencies(path):
    output = subprocess.check_output(["otool", "-L", str(path)], text=True)
    return [line.strip().split(" (compatibility version")[0] for line in output.splitlines()[1:] if " (compatibility version" in line]

def resolve(dep, owner):
    if dep.startswith("/usr/lib/") or dep.startswith("/System/"):
        return None
    if dep.startswith("@loader_path/"):
        path = (owner.parent / dep[len("@loader_path/"):]).resolve()
    elif dep.startswith("@executable_path/"):
        path = (binary.parent / dep[len("@executable_path/"):]).resolve()
    elif dep.startswith("@rpath/"):
        name = dep[len("@rpath/"):]
        candidates = list(brew.glob("opt/*/lib/" + name)) + list(brew.glob("lib/" + name))
        path = next((p.resolve() for p in candidates if p.exists()), None)
    else:
        path = pathlib.Path(dep).resolve()
    if path is None or not path.exists():
        raise RuntimeError(f"Unresolved dependency {dep} referenced by {owner}")
    return path

while queue:
    owner = queue.pop(0)
    for dep in dependencies(owner):
        source = resolve(dep, owner)
        if source is None:
            continue
        if source not in copied:
            if len(copied) >= MAX_LIBS:
                raise RuntimeError("Dependency limit reached (possible recursion)")
            dest = frameworks / source.name
            if dest.exists():
                raise RuntimeError(f"Duplicate library basename: {source}")
            shutil.copy2(source, dest)
            os.chmod(dest, 0o755)
            copied[source] = dest
            queue.append(dest)
        edges.append((owner, dep, copied[source]))

for owner, dep, dest in edges:
    target = ("@loader_path/" if owner != binary else "@loader_path/../../Frameworks/") + dest.name
    subprocess.check_call(["install_name_tool", "-change", dep, target, str(owner)])
for dest in copied.values():
    subprocess.check_call(["install_name_tool", "-id", "@rpath/" + dest.name, str(dest)])
print(f"Bundled {len(copied)} unique dynamic libraries")
