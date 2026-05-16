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


def find_matching_nodes(words, node_map, adj, top_n=10):
    """Find nodes whose label matches any of the given words, returning top_n by degree."""
    terms = [w.lower().strip() for w in words.split(",") if w.strip()]
    matches = []
    for nid, ndata in node_map.items():
        label = ndata.get("label", "").lower()
        score = sum(1 for t in terms if t in label)
        if score > 0:
            neighbors = []
            seen_neighbor_ids = set()
            for neighbor_id, edge in adj.get(nid, []):
                if neighbor_id in seen_neighbor_ids:
                    continue
                seen_neighbor_ids.add(neighbor_id)
                neighbor = node_map.get(neighbor_id, {})
                neighbors.append(
                    {
                        "label": neighbor.get("label", neighbor_id),
                        "relation": edge.get("relation", ""),
                        "confidence": edge.get("confidence", ""),
                        "confidence_score": edge.get("confidence_score"),
                        "source": neighbor.get("source_file", ""),
                        "file_type": neighbor.get("file_type", ""),
                        "community": neighbor.get("community"),
                    }
                )
            neighbors.sort(key=lambda x: (x["relation"], x["label"]))
            matches.append(
                {
                    "label": ndata.get("label", nid),
                    "id": nid,
                    "source": ndata.get("source_file", ""),
                    "file_type": ndata.get("file_type", ""),
                    "community": ndata.get("community"),
                    "degree": len(adj.get(nid, [])),
                    "neighbors": neighbors,
                }
            )
    matches.sort(key=lambda x: x["degree"], reverse=True)
    return matches[:top_n]


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


def format_deep_dive_md(matches, query):
    """Format word-matched nodes (top N by degree) as Markdown sections."""
    lines = [
        f"## Deep Dive: `{query}`",
        "",
        f"**{len(matches)} matching nodes (top by degree)**",
        "",
    ]

    for m in matches:
        label = m["label"]
        source = m["source"]
        ft = m["file_type"]
        degree = m["degree"]
        community = m["community"]

        lines.append(f"### {label}")
        lines.append("")
        lines.append(
            f"`{source}` · {ft} · degree={degree} · community={community}"
        )
        lines.append("")

        if m["neighbors"]:
            lines.append("| Relation | → Neighbor | Confidence | Source |")
            lines.append("|----------|------------|------------|--------|")
            for nb in m["neighbors"]:
                nb_label = nb["label"].replace("|", "\\|")
                nb_source = nb["source"].replace("|", "\\|")
                lines.append(
                    f"| {nb['relation']} | {nb_label} | {nb['confidence']} | `{nb_source}` |"
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

    if args.format == "json":
        result = {
            "status": "ok",
            "graph_path": graph_path,
            "stats": stats,
            "god_nodes": gods,
        }
        if args.words:
            matches = find_matching_nodes(args.words, node_map, adj, args.top_n)
            result["word_matches"] = {
                "query": args.words,
                "total_matches": len(matches),
                "matches": matches,
            }
        print(json.dumps(result, indent=2))
    else:
        # Markdown output
        parts = [
            f"# Graphify Report",
            f"",
            f"`{graph_path}`",
            f"",
            format_stats_md(stats),
            format_god_nodes_md(gods),
        ]
        if args.words:
            matches = find_matching_nodes(args.words, node_map, adj, args.top_n)
            parts.append(format_deep_dive_md(matches, args.words))

        print("\n".join(parts))


if __name__ == "__main__":
    main()