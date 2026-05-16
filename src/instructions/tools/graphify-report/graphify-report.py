#!/usr/bin/env python3
"""Graphify report tool — reads graph.json and produces Markdown optimized for LLM consumption.

Usage:
  python3 graphify-report.py --graph-path graphify-out/graph.json
  python3 graphify-report.py --graph-path graphify-out/graph.json --words "planning,workflow"
  python3 graphify-report.py --graph-path graphify-out/graph.json --words "memory,skill" --top-n 5

Output: Markdown with summary stats, god nodes table, and optional word deep-dive sections.
"""
import json
import sys
import os
from collections import Counter, defaultdict


def load_graph(path):
    with open(path) as f:
        data = json.load(f)
    nodes = data.get("nodes", [])
    links = data.get("links", [])
    hyperedges = data.get("hyperedges", [])

    node_map = {}
    for n in nodes:
        node_map[n["id"]] = n

    adj = defaultdict(list)
    for e in links:
        src, tgt = e["source"], e["target"]
        adj[src].append((tgt, e))
        adj[tgt].append((src, e))

    return nodes, links, hyperedges, node_map, adj


def compute_stats(nodes, links):
    communities = set()
    confidence_counts = Counter()
    file_type_counts = Counter()

    for n in nodes:
        c = n.get("community")
        if c is not None:
            communities.add(c)
        ft = n.get("file_type", "unknown")
        file_type_counts[ft] += 1

    for e in links:
        conf = e.get("confidence", "UNKNOWN")
        confidence_counts[conf] += 1

    total_edges = len(links)
    confidence_pct = {}
    for k, v in confidence_counts.items():
        confidence_pct[k] = round(v / total_edges * 100, 1) if total_edges else 0

    return {
        "total_nodes": len(nodes),
        "total_edges": total_edges,
        "total_communities": len(communities),
        "confidence_breakdown": dict(confidence_counts),
        "confidence_pct": confidence_pct,
        "file_type_breakdown": dict(file_type_counts),
    }


def find_god_nodes(node_map, adj, top_n=10):
    scored = []
    for nid, ndata in node_map.items():
        degree = len(adj.get(nid, []))
        scored.append((degree, nid, ndata.get("label", nid)))
    scored.sort(reverse=True)
    return [
        {
            "rank": i + 1,
            "label": label,
            "degree": deg,
            "id": nid,
            "source": node_map[nid].get("source_file", ""),
            "file_type": node_map[nid].get("file_type", ""),
            "community": node_map[nid].get("community"),
        }
        for i, (deg, nid, label) in enumerate(scored[:top_n])
    ]


def find_top_file_nodes(node_map, adj, top_n=10):
    """Return top_n file-level nodes (source_location == L1) ranked by degree."""
    file_nodes = []
    for nid, ndata in node_map.items():
        if ndata.get("source_location", "") == "L1":
            degree = len(adj.get(nid, []))
            file_nodes.append(
                {
                    "rank": 0,
                    "label": ndata.get("label", nid),
                    "id": nid,
                    "source": ndata.get("source_file", ""),
                    "file_type": ndata.get("file_type", ""),
                    "community": ndata.get("community"),
                    "degree": degree,
                }
            )
    file_nodes.sort(key=lambda x: x["degree"], reverse=True)
    for i, n in enumerate(file_nodes[:top_n]):
        n["rank"] = i + 1
    return file_nodes[:top_n]


def common_prefix_path(a: str, b: str) -> str:
    """Return the longest common directory-boundary prefix of two paths.

    E.g. common_prefix_path('src/foo/bar', 'src/foo/baz') == 'src/foo'
         common_prefix_path('src/foo', 'src/foo/bar')     == 'src/foo'
    """
    parts_a = a.split("/")
    parts_b = b.split("/")
    common = []
    for pa, pb in zip(parts_a, parts_b):
        if pa == pb:
            common.append(pa)
        else:
            break
    return "/".join(common)


def collapse_folders(folder_degree: dict, folder_node_count: dict, top_n: int,
                     max_collapse_levels: int = 2,
                     min_ancestor_depth: int = 4) -> list:
    """Collapse the top_n folders so that sibling sub-folders sharing a common
    ancestor are merged into that ancestor.

    A merge is triggered only when ALL of the following hold:
      - The common ancestor is shared by the MAJORITY (> half) of the current top_n.
      - The ancestor depth is ≥ min_ancestor_depth (prevents collapsing to shallow
        project roots like 'src' or 'app/Core').
      - The ancestor is within max_collapse_levels of the median member depth
        (prevents collapsing deeply nested folders to a distant root).

    Algorithm (iterative until stable):
      1. Take the current top_n by degree.
      2. For every candidate ancestor prefix shared by ≥ 2 top folders, count
         how many top folders it covers.
      3. If the best candidate passes all guards, merge all sub-path members into
         that ancestor (summing degree and node_count), then repeat.
      4. Stop when no qualifying candidate exists.
    """
    deg = dict(folder_degree)
    cnt = dict(folder_node_count)

    changed = True
    while changed:
        changed = False
        top = sorted(deg.items(), key=lambda x: x[1], reverse=True)[:top_n]
        top_folders = [f for f, _ in top]
        if len(top_folders) < 2:
            break

        # Build map: ancestor prefix → list of top folders it covers
        prefix_members: dict[str, list[str]] = {}
        for i, fa in enumerate(top_folders):
            for fb in top_folders[i + 1:]:
                prefix = common_prefix_path(fa, fb)
                if not prefix or "/" not in prefix:
                    continue
                if prefix == fa == fb:
                    continue
                if prefix not in prefix_members:
                    prefix_members[prefix] = []
                for f in (fa, fb):
                    if f not in prefix_members[prefix]:
                        prefix_members[prefix].append(f)

        if not prefix_members:
            break

        # Pick the prefix covering the most top folders (deepest wins on ties)
        best_prefix, best_members = max(
            prefix_members.items(),
            key=lambda kv: (len(kv[1]), len(kv[0].split("/"))),
        )

        # Guard 1: must cover majority of current top_n
        if len(best_members) <= len(top_folders) / 2:
            break

        # Guard 2: ancestor must be deep enough to be meaningful
        ancestor_depth = len(best_prefix.split("/"))
        if ancestor_depth < min_ancestor_depth:
            break

        # Guard 3: ancestor must be within max_collapse_levels of the median member depth
        member_depths = sorted(len(f.split("/")) for f in best_members)
        median_depth = member_depths[len(member_depths) // 2]
        if median_depth - ancestor_depth > max_collapse_levels:
            break

        # Merge all top folders that are sub-paths of best_prefix
        to_merge = [
            f for f in top_folders
            if f == best_prefix or f.startswith(best_prefix + "/")
        ]
        if len(to_merge) < 2:
            break

        merged_deg = sum(deg.pop(f, 0) for f in to_merge)
        merged_cnt = sum(cnt.pop(f, 0) for f in to_merge)
        merged_deg += deg.pop(best_prefix, 0)
        merged_cnt += cnt.pop(best_prefix, 0)
        deg[best_prefix] = merged_deg
        cnt[best_prefix] = merged_cnt
        changed = True

    ranked = sorted(deg.items(), key=lambda x: x[1], reverse=True)

    # Post-processing: drop any folder that is a sub-path of a higher-ranked
    # folder already in the output. This handles cases where the collapse loop
    # merged the original top-N entries but left behind lower-ranked sub-folders
    # in the full degree map that bubble up after the merge.
    kept: list[str] = []
    result = []
    rank = 1
    for folder, d in ranked:
        dominated = any(
            folder == k or folder.startswith(k.rstrip("/") + "/")
            for k in kept
        )
        if dominated:
            continue
        kept.append(folder)
        result.append({
            "rank": rank,
            "folder": folder,
            "total_degree": d,
            "node_count": cnt.get(folder, 0),
        })
        rank += 1
        if rank > top_n:
            break
    return result


def find_top_folder_nodes(node_map, adj, top_n=10):
    """Aggregate nodes by source directory, rank folders by total degree.

    Sibling sub-folders that dominate the top_n list are collapsed into their
    nearest common ancestor so the result shows meaningfully distinct areas.
    """
    import os

    folder_degree: dict[str, int] = {}
    folder_node_count: dict[str, int] = {}
    for nid, ndata in node_map.items():
        src = ndata.get("source_file", "")
        folder = os.path.dirname(src) if src else ""
        if not folder:
            folder = "."
        degree = len(adj.get(nid, []))
        folder_degree[folder] = folder_degree.get(folder, 0) + degree
        folder_node_count[folder] = folder_node_count.get(folder, 0) + 1

    return collapse_folders(folder_degree, folder_node_count, top_n)


def find_connected_folders(parent, node_map, adj, top_n=3):
    """Return top_n folders most connected to nodes inside parent via graph edges.

    For each node inside parent, walk its adjacency list. For each neighbour
    that lives in a *different* folder, count that cross-folder edge. Rank
    external folders by total cross-edge count, excluding parent itself.
    """
    import os

    prefix = parent.rstrip("/") + "/"
    # Collect node IDs that belong to this folder
    parent_nodes = {
        nid
        for nid, ndata in node_map.items()
        if (os.path.dirname(ndata.get("source_file", "")) or ".") == parent
        or (os.path.dirname(ndata.get("source_file", "")) or ".").startswith(prefix)
    }

    edge_count: dict[str, int] = {}
    for nid in parent_nodes:
        for neighbour, _edge in adj.get(nid, []):
            if neighbour in parent_nodes:
                continue  # same folder — skip
            ndata = node_map.get(neighbour, {})
            folder = os.path.dirname(ndata.get("source_file", "")) or "."
            edge_count[folder] = edge_count.get(folder, 0) + 1

    ranked = sorted(edge_count.items(), key=lambda x: x[1], reverse=True)[:top_n]
    return [
        {"rank": i + 1, "folder": f, "edge_count": c}
        for i, (f, c) in enumerate(ranked)
    ]


def find_folder_nodes_with_children(node_map, adj, top_n=3, children_n=3):
    """Return top_n collapsed folders, each with their top children_n connected folders."""
    top_folders = find_top_folder_nodes(node_map, adj, top_n)
    for entry in top_folders:
        entry["top_connected_folders"] = find_connected_folders(
            entry["folder"], node_map, adj, children_n
        )
    return top_folders


def find_matching_file_nodes(words, node_map, adj, top_n=10):
    """Among word-matched nodes, return top_n file-level nodes (source_location == L1) by degree."""
    terms = [w.lower().strip() for w in words.split(",") if w.strip()]
    matches = []
    for nid, ndata in node_map.items():
        if ndata.get("source_location", "") != "L1":
            continue
        label = ndata.get("label", "").lower()
        src = ndata.get("source_file", "").lower()
        score = sum(1 for t in terms if t in label or t in src)
        if score > 0:
            degree = len(adj.get(nid, []))
            matches.append(
                {
                    "rank": 0,
                    "label": ndata.get("label", nid),
                    "id": nid,
                    "source": ndata.get("source_file", ""),
                    "file_type": ndata.get("file_type", ""),
                    "community": ndata.get("community"),
                    "degree": degree,
                    "score": score,
                }
            )
    matches.sort(key=lambda x: (x["degree"], x["score"]), reverse=True)
    for i, m in enumerate(matches[:top_n]):
        m["rank"] = i + 1
    return matches[:top_n]


def find_matching_folder_nodes(words, node_map, adj, top_n=10):
    """Among word-matched nodes, aggregate by source directory and rank by total degree.

    Sibling sub-folders that dominate the top_n list are collapsed into their
    nearest common ancestor.
    """
    import os

    terms = [w.lower().strip() for w in words.split(",") if w.strip()]
    folder_degree: dict[str, int] = {}
    folder_node_count: dict[str, int] = {}
    for nid, ndata in node_map.items():
        label = ndata.get("label", "").lower()
        src = ndata.get("source_file", "").lower()
        score = sum(1 for t in terms if t in label or t in src)
        if score == 0:
            continue
        folder = os.path.dirname(ndata.get("source_file", "")) or "."
        degree = len(adj.get(nid, []))
        folder_degree[folder] = folder_degree.get(folder, 0) + degree
        folder_node_count[folder] = folder_node_count.get(folder, 0) + 1

    return collapse_folders(folder_degree, folder_node_count, top_n)


def format_stats_md(stats):
    """Format stats section as Markdown."""
    conf_pct = stats["confidence_pct"]
    conf_str = ", ".join(
        f"{k}: {v}%" for k, v in sorted(conf_pct.items())
    )
    ft = stats["file_type_breakdown"]
    ft_str = ", ".join(
        f"{k}: {v}" for k, v in sorted(ft.items())
    )

    lines = [
        "## Graph Summary",
        "",
        f"| Metric | Value |",
        f"|--------|-------|",
        f"| Nodes | {stats['total_nodes']} |",
        f"| Edges | {stats['total_edges']} |",
        f"| Communities | {stats['total_communities']} |",
        f"| Confidence | {conf_str} |",
        f"| File types | {ft_str} |",
        "",
    ]
    return "\n".join(lines)


def format_god_nodes_md(gods):
    """Format god nodes as Markdown table."""
    lines = [
        "## God Nodes (Most Connected)",
        "",
        "| # | Label | Degree | Type | Source |",
        "|---|-------|--------|------|--------|",
    ]
    for g in gods:
        label = g["label"].replace("|", "\\|")
        source = g["source"].replace("|", "\\|")
        lines.append(
            f"| {g['rank']} | {label} | {g['degree']} | {g['file_type']} | `{source}` |"
        )
    lines.append("")
    return "\n".join(lines)


def top_folders_from_file_nodes(file_nodes, top_n=10):
    """Return top_n most common base folder paths from a list of file nodes."""
    import os
    counts: dict[str, int] = {}
    for n in file_nodes:
        folder = os.path.dirname(n.get("source", "")) or "."
        counts[folder] = counts.get(folder, 0) + 1
    ranked = sorted(counts.items(), key=lambda x: x[1], reverse=True)[:top_n]
    return [{"rank": i + 1, "folder": f, "file_count": c} for i, (f, c) in enumerate(ranked)]


def format_top_file_nodes_md(file_nodes, title="Most Connected File Nodes", folder_top_n=10):
    """Format top file nodes as Markdown table, followed by top folder summary."""
    lines = [
        f"## {title}",
        "",
        "| # | Label | Degree | Type | Source |",
        "|---|-------|--------|------|--------|",
    ]
    for n in file_nodes:
        label = n["label"].replace("|", "\\|")
        source = n["source"].replace("|", "\\|")
        lines.append(
            f"| {n['rank']} | {label} | {n['degree']} | {n['file_type']} | `{source}` |"
        )
    lines.append("")

    # Append top folders derived from this file list
    top_folders = top_folders_from_file_nodes(file_nodes, top_n=folder_top_n)
    if top_folders:
        lines += [
            "### Top Folders",
            "",
            "| # | Folder | Files |",
            "|---|--------|-------|",
        ]
        for f in top_folders:
            folder = f["folder"].replace("|", "\\|")
            lines.append(f"| {f['rank']} | `{folder}` | {f['file_count']} |")
        lines.append("")

    return "\n".join(lines)

def format_top_folder_nodes_md(folder_nodes, title="Most Connected Folder Nodes"):
    """Format top folder nodes as Markdown.

    If entries contain 'top_connected_folders', renders a two-level view: each
    top folder as a sub-heading with its most-connected peer folders in a table.
    Otherwise renders a flat table.
    """
    has_children = any("top_connected_folders" in n for n in folder_nodes)

    if not has_children:
        lines = [
            f"## {title}",
            "",
            "| # | Folder | Total Degree | Node Count |",
            "|---|--------|--------------|------------|",
        ]
        for n in folder_nodes:
            folder = n["folder"].replace("|", "\\|")
            lines.append(
                f"| {n['rank']} | `{folder}` | {n['total_degree']} | {n['node_count']} |"
            )
        lines.append("")
        return "\n".join(lines)

    lines = [f"## {title}", ""]
    for n in folder_nodes:
        folder = n["folder"]
        lines += [
            f"### {n['rank']}. `{folder}`",
            "",
            f"Total degree: **{n['total_degree']}** | Nodes: **{n['node_count']}**",
            "",
        ]
        connected = n.get("top_connected_folders", [])
        if connected:
            lines += [
                "| # | Connected Folder | Cross-edges |",
                "|---|-----------------|-------------|",
            ]
            for s in connected:
                sub = s["folder"].replace("|", "\\|")
                lines.append(
                    f"| {s['rank']} | `{sub}` | {s['edge_count']} |"
                )
            lines.append("")
        else:
            lines += ["_No connected folders found._", ""]
    return "\n".join(lines)


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Graphify report tool")
    parser.add_argument(
        "--graph-path",
        default="graphify-out/graph.json",
        help="Path to graph.json",
    )
    parser.add_argument(
        "--words",
        default="",
        help="Comma-separated words to filter/dive into",
    )
    parser.add_argument(
        "--top-n",
        type=int,
        default=10,
        help="Number of top god nodes to show",
    )
    parser.add_argument(
        "--format",
        choices=["markdown", "json"],
        default="markdown",
        help="Output format (default: markdown)",
    )
    args = parser.parse_args()

    graph_path = args.graph_path
    if not os.path.exists(graph_path):
        alt = os.path.join(os.getcwd(), graph_path)
        if os.path.exists(alt):
            graph_path = alt
        else:
            msg = f"graph.json not found at {args.graph_path} or {alt}"
            if args.format == "json":
                print(json.dumps({"status": "error", "code": "GRAPH_NOT_FOUND", "message": msg}))
            else:
                print(f"❌ {msg}")
            sys.exit(1)

    nodes, links, hyperedges, node_map, adj = load_graph(graph_path)
    stats = compute_stats(nodes, links)
    gods = find_god_nodes(node_map, adj, args.top_n)

    if args.words:
        top_file_nodes = find_matching_file_nodes(args.words, node_map, adj, 100)
        top_folder_nodes = find_matching_folder_nodes(args.words, node_map, adj, 3)
    else:
        top_file_nodes = find_top_file_nodes(node_map, adj, 100)
        top_folder_nodes = find_top_folder_nodes(node_map, adj, 3)

    # Enrich top 3 folders with their top 3 cross-edge connected folders
    for entry in top_folder_nodes[:3]:
        entry["top_connected_folders"] = find_connected_folders(
            entry["folder"], node_map, adj, top_n=3
        )

    if args.format == "json":
        result = {
            "status": "ok",
            "graph_path": graph_path,
            "stats": stats,
            "god_nodes": gods,
            "top_file_nodes": top_file_nodes,
            "top_folder_nodes": top_folder_nodes,
        }
        print(json.dumps(result, indent=2))
    else:
        # Markdown output
        file_title = (
            f"Most Connected File Nodes matching `{args.words}`"
            if args.words
            else "Most Connected File Nodes"
        )
        folder_title = (
            f"Most Connected Folder Nodes matching `{args.words}`"
            if args.words
            else "Most Connected Folder Nodes"
        )
        parts = [
            f"# Graphify Report",
            f"",
            f"`{graph_path}`",
            f"",
            format_stats_md(stats),
            format_god_nodes_md(gods),
            format_top_folder_nodes_md(top_folder_nodes, title=folder_title),
            format_top_file_nodes_md(top_file_nodes, title=file_title),
        ]
        print("\n".join(parts))


if __name__ == "__main__":
    main()