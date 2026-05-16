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


def find_top_folder_nodes(node_map, adj, top_n=10):
    """Aggregate nodes by source directory, rank folders by total degree."""
    import os

    folder_degree = {}
    folder_node_count = {}
    for nid, ndata in node_map.items():
        src = ndata.get("source_file", "")
        folder = os.path.dirname(src) if src else ""
        if not folder:
            folder = "."
        degree = len(adj.get(nid, []))
        folder_degree[folder] = folder_degree.get(folder, 0) + degree
        folder_node_count[folder] = folder_node_count.get(folder, 0) + 1

    ranked = sorted(folder_degree.items(), key=lambda x: x[1], reverse=True)
    return [
        {
            "rank": i + 1,
            "folder": folder,
            "total_degree": deg,
            "node_count": folder_node_count[folder],
        }
        for i, (folder, deg) in enumerate(ranked[:top_n])
    ]


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
    """Among word-matched nodes, aggregate by source directory and rank by total degree."""
    import os

    terms = [w.lower().strip() for w in words.split(",") if w.strip()]
    folder_degree = {}
    folder_node_count = {}
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

    ranked = sorted(folder_degree.items(), key=lambda x: x[1], reverse=True)
    return [
        {
            "rank": i + 1,
            "folder": folder,
            "total_degree": deg,
            "node_count": folder_node_count[folder],
        }
        for i, (folder, deg) in enumerate(ranked[:top_n])
    ]


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


def format_top_file_nodes_md(file_nodes, title="Most Connected File Nodes"):
    """Format top file nodes as Markdown table."""
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
    return "\n".join(lines)


def format_top_folder_nodes_md(folder_nodes, title="Most Connected Folder Nodes"):
    """Format top folder nodes as Markdown table."""
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
        top_file_nodes = find_matching_file_nodes(args.words, node_map, adj, args.top_n)
        top_folder_nodes = find_matching_folder_nodes(args.words, node_map, adj, args.top_n)
    else:
        top_file_nodes = find_top_file_nodes(node_map, adj, args.top_n)
        top_folder_nodes = find_top_folder_nodes(node_map, adj, args.top_n)

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
            format_top_file_nodes_md(top_file_nodes, title=file_title),
            format_top_folder_nodes_md(top_folder_nodes, title=folder_title),
        ]
        print("\n".join(parts))


if __name__ == "__main__":
    main()