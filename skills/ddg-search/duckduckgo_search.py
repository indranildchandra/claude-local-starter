from ddgs import DDGS
import sys


def ddg_search(query: str) -> str:
    """Search the web using DuckDuckGo and return a formatted summary of results.

    Use this tool whenever you need current information, specific facts,
    venue details, event listings, opening hours, or anything that benefits
    from a live web search.

    Args:
        query: The search query string.

    Returns:
        Formatted string with title, URL, and body text (capped at 500 chars) for each result.
        Returns an error message if the search fails.
    """
    try:
        results = DDGS().text(query, max_results=10)
        if not results:
            return f"No results found for: {query}"

        lines = [f"Search results for: {query}\n"]
        for i, r in enumerate(results, 1):
            lines.append(f"{i}. {r.get('title', 'No title')}")
            lines.append(f"   URL: {r.get('href', '')}")
            lines.append(f"   {r.get('body', '')[:500]}")
            lines.append("")
        return "\n".join(lines)
    except Exception as e:
        return f"Search failed: {e}"


if __name__ == "__main__":
    query = " ".join(sys.argv[1:])
    if not query:
        print("Usage: python3 duckduckgo_search.py <query>")
        sys.exit(1)
    print(ddg_search(query))
