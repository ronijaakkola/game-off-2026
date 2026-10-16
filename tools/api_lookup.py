"""Prints the Godot class reference for `check.py api`, which builds the cache it reads.

The cache is the editor's class reference as a JSON list with one dictionary per class
(Godot's DocData::ClassDoc). Descriptions are in Godot's BBCode, turned into plain text here.
Standard library only.
"""

import difflib
import json
import re
import textwrap
from pathlib import Path

SEARCH_LIMIT = 30
ENUM_PREVIEW = 12
BRIEF_LENGTH = 120
COMMAND = "uv run tools/check.py api"
SECTIONS = [
    ("property", "Properties"),
    ("constructor", "Constructors"),
    ("method", "Methods"),
    ("annotation", "Annotations"),
    ("signal", "Signals"),
    ("constant", "Constants"),
]
KEYWORDS = {
    "property": "var",
    "method": "func",
    "signal": "signal",
    "constant": "const",
    "annotation": "",
    "constructor": "",
    "theme": "theme",
    "enum": "enum",
}

CSHARP = re.compile(r"\[csharp[^\]]*\].*?\[/csharp\]", re.DOTALL)
CODEBLOCK = re.compile(r"\[(codeblock|gdscript)(?: [^\]]*)?\]\n?(.*?)\[/\1\]", re.DOTALL)
CODE = re.compile(r"\[code(?: [^\]]*)?\](.*?)\[/code\]", re.DOTALL)
REFERENCE = re.compile(
    r"\[(method|member|signal|constant|enum|annotation|theme_item|param|constructor|operator)"
    r" ([^\]]+)\]"
)
URL = re.compile(r"\[url=([^\]]+)\](.*?)\[/url\]", re.DOTALL)
BRACKETED = re.compile(r"\[([@A-Za-z_][A-Za-z0-9_]*)\]")
STYLE = re.compile(r"\[/?(b|i|u|s|kbd|center|codeblocks|url|color|font)(=[^\]]*)?\]")
PLACEHOLDER = re.compile(r"\x00(\d+)\x00")
SENTENCE_END = re.compile(r"[.!?](?=\s|$)")


class NotFound(Exception):
    pass


def lookup(cache: Path, query: str, search: bool = False, full: bool = False) -> str:
    """Returns the text to print, or raises NotFound with a one-line message."""
    reference = Reference(json.loads(cache.read_text(encoding="utf-8")))
    query = query.strip(". ")
    if search:
        return reference.search(query)
    if query in reference.classes:
        return reference.summary(query, full)
    if "." in query:
        parts = query.split(".")
        return reference.member(parts[0], parts[-1])
    return reference.search(query)


class Reference:
    def __init__(self, classes: list[dict]):
        self.classes = {c["name"]: c for c in classes}

    # --- formatting ---------------------------------------------------------

    def text(self, bbcode: str, links: bool = True) -> str:
        """Godot's documentation BBCode as plain text. Code stays as written, in
        backticks or as an indented block."""
        kept: list[str] = []

        def keep(value: str) -> str:
            kept.append(value)
            return f"\x00{len(kept) - 1}\x00"

        def block(match: re.Match) -> str:
            code = textwrap.dedent(match.group(2).rstrip()).expandtabs(4)
            return keep("\n" + textwrap.indent(code, "    ") + "\n")

        def reference(match: re.Match) -> str:
            kind, name = match.groups()
            return keep(f"`{name}()`" if kind in ("method", "constructor") else f"`{name}`")

        def bracketed(match: re.Match) -> str:
            name = match.group(1)
            if name in self.classes:
                return name
            return {"br": "\n", "lb": "[", "rb": "]"}.get(name, match.group(0))

        result = textwrap.dedent(bbcode).strip()
        result = CSHARP.sub("", result)
        result = CODEBLOCK.sub(block, result)
        result = CODE.sub(lambda m: keep("`" + unescape(m.group(1)) + "`"), result)
        result = REFERENCE.sub(reference, result)
        result = URL.sub(lambda m: f"{m.group(2)} ({m.group(1)})" if links else m.group(2), result)
        result = STYLE.sub("", result)
        result = BRACKETED.sub(bracketed, result)
        result = PLACEHOLDER.sub(lambda m: kept[int(m.group(1))], result)
        return re.sub(r"\n{3,}", "\n\n", result).strip()

    def brief(self, entry: dict, key: str = "description") -> str:
        """The first sentence of a description, on one line."""
        description = entry.get(key, "")
        description = re.split(r"\[codeblocks?\]|\[gdscript", description)[0]
        text = self.text(description, links=False)
        line = next((x for x in text.splitlines() if x.strip()), "")
        for end in SENTENCE_END.finditer(line):
            if not re.search(r"\b(e\.g|i\.e|etc|vs)\.$", line[: end.end()]):
                line = line[: end.end()]
                break
        if len(line) > BRIEF_LENGTH:
            line = line[:BRIEF_LENGTH].rsplit(" ", 1)[0] + "..."
        flags = [f for f in ("deprecated", "experimental") if f in entry]
        return " ".join([f"({f})" for f in flags] + [line]).strip()

    def signature(self, kind: str, entry: dict, prefix: str = "", keyword: bool = False) -> str:
        name = prefix + entry["name"]
        if kind == "property":
            text = f"{name}: {type_of(entry)}" + default(entry)
        elif kind == "theme":
            text = f"{entry.get('data_type', '')} {name}: {entry.get('type', '')}" + default(entry)
        elif kind == "constant":
            text = f"{name} = {entry.get('value', '')}"
        elif kind == "enum":
            text = name + (" (flags)" if entry.get("is_bitfield") else "")
        else:
            qualifiers = entry.get("qualifiers", "").split()
            arguments = [
                f"{a['name']}: {type_of(a)}" + default(a) for a in entry.get("arguments", [])
            ]
            if "vararg" in qualifiers:
                arguments.append("...")
            text = f"{name}({', '.join(arguments)})"
            if kind == "annotation" and not arguments:
                text = name
            if kind == "method":
                returns = entry.get("return_enum") or entry.get("return_type") or "void"
                text += f" -> {returns}"
                if "static" in qualifiers:
                    text = "static " + (f"func {text}" if keyword else text)
                    keyword = False
                extra = [q for q in qualifiers if q not in ("static", "vararg", "const")]
                if extra:
                    text += f" ({' '.join(extra)})"
        word = KEYWORDS[kind]
        return f"{word} {text}" if keyword and word else text

    def line(self, kind: str, entry: dict, prefix: str = "", keyword: bool = False) -> str:
        brief = self.brief(entry)
        signature = self.signature(kind, entry, prefix, keyword)
        return f"{signature}  # {brief}" if brief else signature

    # --- class summary ------------------------------------------------------

    def summary(self, class_name: str, full: bool) -> str:
        entry = self.classes[class_name]
        lines = [" < ".join(self.chain(class_name))]
        lines.append(self.text(entry.get("brief_description", "")))
        if full:
            lines.append(self.text(entry.get("description", "")))
        if "deprecated" in entry:
            lines.append("Deprecated: " + self.text(entry["deprecated"]))
        members = own_members(entry)
        for kind, title in SECTIONS:
            found = [m for k, m in members if k == kind]
            if kind == "constant":
                found = [m for m in found if not m.get("enumeration")]
                lines += self.enums(entry)
            if found:
                lines.append(title)
                lines += ["  " + self.line(kind, m) for m in found]
        lines += self.theme_items(entry)
        parent = entry.get("inherits")
        more = [f"`{COMMAND} {class_name}.<member>` for one member in full"]
        if not full and entry.get("description", "").strip():
            more.append(f"`{COMMAND} {class_name} --full` for the class description")
        if parent:
            more.append(f"`{COMMAND} {parent}` for inherited members")
        lines.append("More: " + ", ".join(more) + ".")
        return "\n".join(line for line in lines if line) + "\n"

    def enums(self, entry: dict) -> list[str]:
        enums: dict[str, list[dict]] = {}
        for constant in entry.get("constants", []):
            if constant.get("enumeration"):
                enums.setdefault(constant["enumeration"], []).append(constant)
        lines = ["Enums"] if enums else []
        for name, values in enums.items():
            names = [v["name"] for v in values[:ENUM_PREVIEW]]
            if len(values) > ENUM_PREVIEW:
                names.append(f"... {len(values)} in all")
            flags = " (flags)" if values[0].get("is_bitfield") else ""
            lines.append(f"  {name}{flags}: {', '.join(names)}")
        return lines

    def theme_items(self, entry: dict) -> list[str]:
        by_type: dict[str, list[str]] = {}
        for item in entry.get("theme_properties", []):
            by_type.setdefault(item.get("data_type", ""), []).append(item["name"])
        lines = ["Theme items"] if by_type else []
        lines += [f"  {data_type}: {', '.join(names)}" for data_type, names in by_type.items()]
        return lines

    def chain(self, class_name: str) -> list[str]:
        chain = [class_name]
        while chain[-1] in self.classes and self.classes[chain[-1]].get("inherits"):
            chain.append(self.classes[chain[-1]]["inherits"])
        return chain

    # --- one member ---------------------------------------------------------

    def member(self, class_name: str, name: str) -> str:
        if class_name not in self.classes:
            close = self.close(class_name, list(self.classes))
            hint = f" Close: {', '.join(close)}." if close else ""
            raise NotFound(f'no class named "{class_name}".{hint}{self.elsewhere(name)}')
        for owner in self.chain(class_name):
            matches = find(self.classes.get(owner, {}), name)
            if matches:
                break
        else:
            chain = [self.classes.get(c, {}) for c in self.chain(class_name)]
            names = {m["name"] for c in chain for _, m in all_members(c)}
            close = self.close(name, sorted(names))
            hint = f" Close: {', '.join(close)}." if close else ""
            raise NotFound(
                f'{class_name} has no member "{name}", inherited ones included.{hint}'
                + self.elsewhere(name)
            )
        notes = []
        if owner != class_name:
            notes.append(f"Inherited from {owner}.")
        for child in self.chain(class_name)[: self.chain(class_name).index(owner)]:
            overrides = [m for k, m in find(self.classes[child], name, True) if k == "property"]
            if overrides:
                value = overrides[0].get("default_value", "")
                notes.append(f"{child} overrides the default: {value}")
                break
        entries = [self.entry(kind, entry, owner) for kind, entry in matches]
        return "\n\n".join(["\n".join(notes)] * bool(notes) + entries) + "\n"

    def entry(self, kind: str, entry: dict, owner: str) -> str:
        if kind == "enum":
            values = entry["values"]
            lines = [self.signature(kind, entry, owner + ".", keyword=True)]
            lines += ["  " + self.line("constant", v) for v in values]
            return "\n".join(lines)
        lines = [self.signature(kind, entry, owner + ".", keyword=True)]
        if kind == "constant" and entry.get("enumeration"):
            lines.append(f"In enum {owner}.{entry['enumeration']}.")
        if kind == "property" and (entry.get("setter") or entry.get("getter")):
            accessors = [f"{a}()" for a in (entry.get("setter"), entry.get("getter")) if a]
            lines.append("Accessors: " + ", ".join(accessors))
        for flag in ("deprecated", "experimental"):
            if flag in entry:
                lines.append(f"{flag.capitalize()}: {self.text(entry[flag]) or 'yes'}")
        description = self.text(entry.get("description", ""))
        lines.append(description or "No description in the class reference.")
        return "\n".join(lines)

    def elsewhere(self, name: str) -> str:
        owners = sorted(c for c, e in self.classes.items() if find(e, name))
        if not owners:
            return ""
        shown = ", ".join(f"{c}.{name}" for c in owners[:8])
        more = f" and {len(owners) - 8} more" if len(owners) > 8 else ""
        return f" Found in {shown}{more}."

    # --- search -------------------------------------------------------------

    def search(self, query: str) -> str:
        needle = query.lower()
        hits: list[tuple[int, str, str, dict]] = []
        for class_name, entry in self.classes.items():
            rank = match_rank(class_name, entry, needle)
            if rank is not None:
                hits.append((rank, class_name, "class", entry))
            for kind, member in all_members(entry):
                rank = match_rank(member["name"], member, needle)
                if rank is not None and kind != "constructor" and not member.get("overridden"):
                    hits.append((rank, f"{class_name}.{member['name']}", kind, member))
        if not hits:
            names = set(self.classes)
            for entry in self.classes.values():
                names.update(m["name"] for _, m in all_members(entry))
            close = self.close(query, sorted(names))
            hint = f" Close: {', '.join(close)}." if close else ""
            raise NotFound(f'no class or member matches "{query}".{hint}')
        hits.sort(key=lambda hit: hit[:2])
        lines = []
        for _, name, kind, entry in hits[:SEARCH_LIMIT]:
            if kind == "class":
                brief = self.brief(entry, "brief_description")
                lines.append(f"class {name}" + (f"  # {brief}" if brief else ""))
            else:
                prefix = name.rsplit(".", 1)[0] + "."
                lines.append(self.line(kind, entry, prefix, keyword=True))
        if len(hits) > SEARCH_LIMIT:
            lines.append(f"... {len(hits) - SEARCH_LIMIT} more. Narrow the search.")
        lines.append(f"More: `{COMMAND} <Class>` or `{COMMAND} <Class>.<member>`.")
        return "\n".join(lines) + "\n"

    def close(self, name: str, candidates: list[str]) -> list[str]:
        by_lower: dict[str, str] = {}
        for candidate in candidates:
            by_lower.setdefault(candidate.lower(), candidate)
        close = difflib.get_close_matches(name.lower(), list(by_lower), n=5, cutoff=0.7)
        return [by_lower[c] for c in close]


def own_members(entry: dict) -> list[tuple[str, dict]]:
    """Members this class declares, without properties that only override a default."""
    return [(k, m) for k, m in all_members(entry) if not m.get("overridden")]


def all_members(entry: dict) -> list[tuple[str, dict]]:
    members = []
    for kind, key in (
        ("property", "properties"),
        ("constructor", "constructors"),
        ("method", "methods"),
        ("annotation", "annotations"),
        ("signal", "signals"),
        ("constant", "constants"),
        ("theme", "theme_properties"),
    ):
        members += [(kind, m) for m in entry.get(key, [])]
    enums: dict[str, dict] = {}
    for constant in entry.get("constants", []):
        if constant.get("enumeration"):
            enum = enums.setdefault(
                constant["enumeration"],
                {"name": constant["enumeration"], "values": [], "is_bitfield": False},
            )
            enum["values"].append(constant)
            enum["is_bitfield"] = constant.get("is_bitfield", False)
    members += [("enum", e) for e in enums.values()]
    return members


def find(entry: dict, name: str, overridden: bool = False) -> list[tuple[str, dict]]:
    """Members called `name`. Annotations match without their @."""
    names = (name, "@" + name)
    return [
        (k, m)
        for k, m in all_members(entry)
        if m["name"] in names and bool(m.get("overridden")) == overridden
    ]


def match_rank(name: str, entry: dict, needle: str) -> int | None:
    """Exact names first, then prefixes, then substrings, then the docs' search keywords."""
    name = name.lower()
    if name == needle or name == "@" + needle:
        return 0
    if name.startswith(needle):
        return 1
    if needle in name:
        return 2
    if needle in entry.get("keywords", "").lower():
        return 3
    return None


def type_of(entry: dict) -> str:
    return entry.get("enumeration") or entry.get("type") or "Variant"


def default(entry: dict) -> str:
    value = entry.get("default_value", "")
    return f" = {value}" if value != "" else ""


def unescape(code: str) -> str:
    return code.replace("[lb]", "[").replace("[rb]", "]")
