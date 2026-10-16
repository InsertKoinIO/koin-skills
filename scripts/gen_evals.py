#!/usr/bin/env python3
"""Generate the `claude plugin eval` suite from skills/*/evals/evals.json.

Usage: gen_evals.py <repo root> [--plugin <dir>] [--with <companion>]...
  --plugin  plugin the suite is written into and run against (default build/plugin)
  --with    companion plugin loaded next to it in every case

Writes <plugin>/evals/<skill>-<name>/ per case:
  - prompt.md                 the eval prompt, tagged with its skill (+ case tags)
  - graders/expected-<n>.md   llm judge, one per `expectations` item (or `expected_output`)
  - graders/check-<n>.md      regex on a project file, one per `checks` item
  - graders/skill-fired.md    the expected skill (`skill`, default: the case's own) was invoked
  - case.yaml + scaffold.sh   with `project`: copies that project (evals/projects.json) in

Optional case fields: project, skill (name, list, or [] for no skill expected),
expectations, checks, tags, with_plugins (companion plugins loaded next to ours).
A check is {"file": path, "contains" | "absent": regex}, or {"answer_absent": regex} on the
final answer. In project cases the llm judge reads the trace, so it sees the code edits.
"""
import argparse, json, os, re, subprocess, sys
from pathlib import Path

PLUGIN_NAME = "koin-migration"
MAX_TURNS = 15
PROJECT_MAX_TURNS = 40
PROJECT_TIMEOUT_SECONDS = 900
NO_BUILD_NOTE = (
    "This workspace is a copy of the user's project. It has no Gradle, JDK or "
    "Android SDK: don't build or run the app. Where the workflow says to verify, "
    "say what you would run."
)

cli = argparse.ArgumentParser()
cli.add_argument("root", type=Path)
cli.add_argument("--plugin", type=Path)
cli.add_argument("--with", dest="with_plugins", action="append", default=[])
args = cli.parse_args()
root = args.root
plugin_dir = args.plugin or root / "build" / "plugin"
suite = plugin_dir / "evals"
# another plugin as target: our skill-fired checks don't apply to it
testing_ours = plugin_dir.resolve() == (root / "build" / "plugin").resolve()
projects_root = Path(os.environ.get("KOIN_EVAL_PROJECTS", Path.home() / "workspace"))
projects = json.loads((root / "evals" / "projects.json").read_text())
companions = projects.pop("_companion_plugins")

def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)

def yaml_str(text):
    return json.dumps(text)

def scaffold_script(project):
    repo = projects_root / project["repo"]
    path = project["path"].strip("/")
    strip = len(path.split("/")) if path else 0
    lines = [
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        f"git -C {yaml_str(str(repo))} archive {project['ref']} {path} | tar -x --strip-components={strip}",
        f"find . \\( -name .claude -o -name CLAUDE.md -o -name AGENTS.md -o -name GEMINI.md \\) -prune -exec rm -rf {{}} +",
    ]
    if catalog := project.get("catalog"):
        # the sub-project reads the repo's shared catalog from ../gradle/
        lines += [
            "mkdir -p gradle",
            f"git -C {yaml_str(str(repo))} show {project['ref']}:{catalog} > gradle/shared.versions.toml",
            f"perl -pi -e 's#\\.\\./{re.escape(catalog)}#gradle/shared.versions.toml#' settings.gradle.kts",
        ]
    return "\n".join(lines) + "\n"

def skill_fired_grader(skills):
    names = "|".join(re.escape(s) for s in skills)
    # optional plugin prefix, exact skill name: "koin" must not match "koin-setup"
    return f"""---
type: tool_used
tool: Skill
input_match: '"skill"\\s*:\\s*"(?:{PLUGIN_NAME}:)?(?:{names})"'
---
"""

def check_grader(check):
    if "answer_absent" in check:
        return f"---\ntype: regex\npattern: {yaml_str(check['answer_absent'])}\nflags: i\nmatch: not_contains\ntarget: last_message\n---\n"
    match, pattern = ("contains", check["contains"]) if "contains" in check else ("not_contains", check["absent"])
    return f"""---
type: regex
pattern: {yaml_str(pattern)}
match: {match}
target:
  source: file
  path: {yaml_str(check["file"])}
---
"""

added_companions = set()

def add_companion(name):
    # one shared copy at the plugin root, outside evals/ (a copy per case overflows the suite)
    if name in added_companions:
        return
    companion = companions[name]
    target = plugin_dir / "companions" / name
    target.mkdir(parents=True, exist_ok=True)
    archive = subprocess.run(["git", "-C", str(projects_root / companion["repo"]), "archive", companion["ref"]],
                             check=True, capture_output=True).stdout
    subprocess.run(["tar", "-x", "-C", str(target)], input=archive, check=True)
    added_companions.add(name)

case_count = skipped = 0
for evals_file in sorted(root.glob("skills/*/evals/evals.json")):
    skill = evals_file.parent.parent.name
    for case in json.loads(evals_file.read_text())["evals"]:
        if case.get("files"):
            sys.exit(f"{skill}/{case['name']}: fixture files are not supported, use `project`")
        case_name = f"{skill}-{case['name']}"
        project = None
        if "project" in case:
            project = projects[case["project"]]
            if not (projects_root / project["repo"] / ".git").exists():
                print(f"skipped {case_name}: project {case['project']} not found under {projects_root}")
                skipped += 1
                continue
        with_plugins = list(dict.fromkeys(case.get("with_plugins", []) + args.with_plugins))
        if not testing_ours:
            with_plugins = []
        missing = [c for c in with_plugins if not (projects_root / companions[c]["repo"] / ".git").exists()]
        if missing:
            print(f"skipped {case_name}: companion plugin {missing[0]} not found under {projects_root}")
            skipped += 1
            continue
        case_dir = suite / case_name
        tags = [skill, *case.get("tags", [])] + (["project"] if project else [])
        frontmatter = [
            f"name: {case_name}",
            f"tags: [{', '.join(tags)}]",
            "runs: 1",
            f"max_turns: {PROJECT_MAX_TURNS if project else MAX_TURNS}",
        ]
        if project:
            frontmatter += [
                f"timeout_seconds: {PROJECT_TIMEOUT_SECONDS}",
                "allowed_tools: [Read, Glob, Grep, Skill, Write, Edit]",
                f"append_system_prompt: {yaml_str(NO_BUILD_NOTE)}",
            ]
            write(case_dir / "case.yaml", f'schema_version: "1.1"\nname: {case_name}\ncontext:\n  scaffold_script: scaffold.sh\n')
            write(case_dir / "scaffold.sh", scaffold_script(project))
            (case_dir / "scaffold.sh").chmod(0o755)
        for name in with_plugins:
            add_companion(name)
        if with_plugins:
            # a case's plugins list replaces the plugin under test: name ours ("../..") too
            entries = ["../.."] + [f"../../companions/{n}" for n in with_plugins]
            frontmatter.append(f"plugins: [{', '.join(yaml_str(e) for e in entries)}]")
        write(case_dir / "prompt.md", "---\n" + "\n".join(frontmatter) + f"\n---\n{case['prompt']}\n")

        expectations = case.get("expectations") or [case["expected_output"]]
        for n, expectation in enumerate(expectations, 1):
            focus = "focus: trace\n" if project else ""
            write(case_dir / "graders" / f"expected-{n}.md", f"---\ntype: llm\n{focus}---\n{expectation}\n")
        for n, check in enumerate(case.get("checks", []), 1):
            write(case_dir / "graders" / f"check-{n}.md", check_grader(check))
        expected_skills = case.get("skill", skill)
        if expected_skills and testing_ours:
            write(case_dir / "graders" / "skill-fired.md",
                  skill_fired_grader([expected_skills] if isinstance(expected_skills, str) else expected_skills))
        case_count += 1

print(f"built: {suite.relative_to(root) if suite.is_relative_to(root) else suite} ({case_count} cases{f', {skipped} skipped' if skipped else ''})")
