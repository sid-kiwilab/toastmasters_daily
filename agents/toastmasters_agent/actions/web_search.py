"""
Web search action: DuckDuckGo search + scrape, summarize with OpenAI.
Uses curl_chrome110 in Docker when available; falls back to requests.
"""
import subprocess
import os
import urllib.parse
import concurrent.futures
import requests
from bs4 import BeautifulSoup

import logging
logger = logging.getLogger("toastmasters_agent.web_search")

_USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
)
_DDG_SEARCH_URL = "https://html.duckduckgo.com/html/"


def _count_tokens(text):
    return len(text) // 4


def _truncate_text(text, max_tokens=3000):
    tokens = _count_tokens(text)
    if tokens <= max_tokens:
        return text, tokens
    max_chars = max_tokens * 4
    truncated = text[:max_chars] + "... [truncated]"
    return truncated, _count_tokens(truncated)


def _unwrap_ddg_url(href: str) -> str:
    """Resolve DuckDuckGo redirect links to the destination URL."""
    if not href:
        return ""
    url = href.strip()
    if url.startswith("//"):
        url = "https:" + url
    if "duckduckgo.com/l/" in url and "uddg=" in url:
        try:
            parsed = urllib.parse.urlparse(url)
            qs = urllib.parse.parse_qs(parsed.query)
            if "uddg" in qs:
                return urllib.parse.unquote(qs["uddg"][0])
        except Exception:
            pass
    return url


def _is_good_result(url: str, title: str, link) -> bool:
    if not url or not title:
        return False
    if not url.startswith(("http://", "https://")):
        return False
    lower = url.lower()
    if "duckduckgo.com" in lower:
        return False
    classes = link.get("class") or []
    class_str = " ".join(classes).lower()
    if "ad" in class_str or "sponsor" in class_str:
        return False
    if "advertisement" in title.lower():
        return False
    return True


def _extract_results(html_content: str) -> list[dict]:
    soup = BeautifulSoup(html_content, "html.parser")
    results = []
    seen = set()
    selectors = [
        ".result__a",
        ".result__title a",
        "a.result__a",
        "h2 a",
        ".web-result a[href]",
        "a[data-testid='result-title-a']",
    ]
    for selector in selectors:
        for link in soup.select(selector):
            url = _unwrap_ddg_url(link.get("href", ""))
            title = link.get_text(strip=True)
            if not _is_good_result(url, title, link):
                continue
            norm = url.rstrip("/")
            if norm in seen:
                continue
            seen.add(norm)
            results.append({"title": title, "url": url})
    return results


def _fetch_html(url: str) -> str | None:
    """Fetch a URL; prefer curl_chrome110 in Docker, fall back to requests."""
    curl_command = [
        "curl_chrome110",
        url,
        "-L",
        "-H", f"User-Agent: {_USER_AGENT}",
        "-H", "Accept: text/html,application/xhtml+xml",
        "-H", "Accept-Language: en-US,en;q=0.9",
        "--compressed",
        "--max-time", "30",
        "--connect-timeout", "10",
    ]
    try:
        result = subprocess.run(
            curl_command,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="ignore",
            timeout=35,
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout
    except (FileNotFoundError, subprocess.TimeoutExpired) as e:
        logger.info("curl_chrome110 unavailable or timed out (%s); using requests", e)
    except Exception as e:
        logger.warning("curl_chrome110 error: %s; using requests", e)

    try:
        resp = requests.get(
            url,
            headers={"User-Agent": _USER_AGENT, "Accept-Language": "en-US,en;q=0.9"},
            timeout=20,
        )
        resp.raise_for_status()
        return resp.text
    except Exception as e:
        logger.error("requests fetch failed for %s: %s", url[:80], e)
        return None


def _fetch_html_requests_only(url: str) -> str | None:
    try:
        resp = requests.get(
            url,
            headers={"User-Agent": _USER_AGENT, "Accept-Language": "en-US,en;q=0.9"},
            timeout=20,
        )
        resp.raise_for_status()
        return resp.text
    except Exception as e:
        logger.warning("requests fetch failed for %s: %s", url[:80], e)
        return None


def _search_duckduckgo(query):
    try:
        logger.info("Searching DuckDuckGo for: %s", query[:80])
        encoded_query = urllib.parse.quote(query)
        search_url = f"{_DDG_SEARCH_URL}?q={encoded_query}"
        for label, fetch in (("curl", _fetch_html), ("requests", _fetch_html_requests_only)):
            html_content = fetch(search_url)
            if not html_content:
                continue
            results = _extract_results(html_content)
            if results:
                logger.info("Found %d search results via %s", len(results), label)
                return {"results": results[:10]}
        logger.info("Found 0 search results")
        return {"results": []}
    except Exception as e:
        logger.error("Error searching DuckDuckGo: %s", e)
        return {"error": str(e)}


def _scrape_url(url):
    try:
        if not url or not isinstance(url, str):
            return {"url": url, "content": "", "error": "Invalid URL"}
        url = url.strip()
        if not url.startswith(("http://", "https://")):
            return {"url": url, "content": "", "error": "URL must start with http:// or https://"}
        html = _fetch_html(url)
        if not html:
            return {"url": url, "content": "", "error": "Scraping failed"}
        soup = BeautifulSoup(html, "html.parser")
        for tag in soup(["script", "style", "nav", "footer", "header"]):
            tag.decompose()
        text_content = soup.get_text()
        lines = (line.strip() for line in text_content.splitlines())
        chunks = (phrase.strip() for line in lines for phrase in line.split("  "))
        text_content = " ".join(c for c in chunks if c)
        truncated_content, _ = _truncate_text(text_content, max_tokens=2000)
        return {"url": url, "content": truncated_content, "token_count": _count_tokens(truncated_content)}
    except Exception as e:
        logger.error("Error scraping %s: %s", url, e)
        return {"url": url, "content": "", "error": str(e)}


def _scrape_urls_parallel(urls):
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
        futures = {executor.submit(_scrape_url, u): u for u in urls}
        return [f.result() for f in concurrent.futures.as_completed(futures)]


def _generate_response_with_openai(query, scraped_content, club_list=False):
    """Summarize scraped content with OpenAI."""
    key = os.getenv("OPENAI_API_KEY", "").strip()
    if not key:
        return {"error": "OPENAI_API_KEY not set"}
    content_summary = ""
    for i, result in enumerate(scraped_content, 1):
        if result.get("content"):
            content_summary += f"\n\nSource {i} ({result['url']}):\n{result['content']}\n"
    if club_list:
        prompt = f"""From the search results, list Toastmasters clubs for: "{query}"

Search Results:{content_summary}

Write a short list (up to 5 clubs). For each: club name, location/area, and official website or toastmasters.org link if available. Keep it concise. Do not invent Toastmasters Daily guest-join or meeting URLs. If none found, say so."""
        system = "You list official Toastmasters clubs from search results. Be concise."
        max_tokens = 500
    else:
        prompt = f"""Based on the following search results, provide a comprehensive and accurate answer to the query: "{query}"

Search Results:{content_summary}

Please provide a well-structured response that:
1. Directly answers the query
2. Uses information from the search results
3. Cites sources when appropriate
4. Is informative and helpful

Answer:"""
        system = "You are a helpful assistant that provides accurate information based on search results."
        max_tokens = 1000
    try:
        resp = requests.post(
            "https://api.openai.com/v1/chat/completions",
            headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
            json={
                "model": "gpt-4o-mini",
                "messages": [
                    {"role": "system", "content": system},
                    {"role": "user", "content": prompt},
                ],
                "max_tokens": max_tokens,
                "temperature": 0.7,
            },
            timeout=60,
        )
        data = resp.json()
        if resp.status_code != 200:
            return {"error": data.get("error", {}).get("message", "OpenAI API error")}
        return {"response": data["choices"][0]["message"]["content"]}
    except Exception as e:
        logger.error("OpenAI summarization error: %s", e)
        return {"error": str(e)}


def _is_retry_eligible(query: str) -> bool:
    q = (query or "").lower()
    if not q:
        return False
    club_near = "club" in q and ("near" in q or "nearest" in q or "closest" in q or "find" in q or "meet" in q)
    when_meet = "when" in q and ("meet" in q or "meeting" in q) and "toastmaster" in q
    return bool(club_near or when_meet)


def _is_no_good_result(response: str) -> bool:
    if not (response or response.strip()):
        return True
    r = response.strip().lower()
    if r.startswith("search failed:") or r.startswith("no search results") or r.startswith("no valid urls"):
        return True
    if r.startswith("could not scrape") or r.startswith("summarization failed:"):
        return True
    if "no response" in r or "no results" in r or "no clubs" in r or "couldn't find" in r:
        return True
    return False


def _run_once(query: str, club_list: bool = False) -> str:
    search_result = _search_duckduckgo(query)
    if "error" in search_result:
        return f"Search failed: {search_result['error']}"
    results = search_result.get("results", [])
    if not results:
        return "No search results found."
    urls = []
    seen = set()
    for r in results[:10]:
        url = (r.get("url") or "").strip()
        if url.startswith(("http://", "https://")):
            norm = url.rstrip("/")
            if norm not in seen:
                urls.append(url)
                seen.add(norm)
    if not urls:
        return "No valid URLs to scrape."
    scraped = _scrape_urls_parallel(urls[:4])
    successful = [s for s in scraped if s.get("content") and not s.get("error")]
    if not successful:
        titles = [f"- {r.get('title', '')}: {r.get('url', '')}" for r in results[:5]]
        if club_list and titles:
            return "Official clubs from search (pages could not be scraped):\n" + "\n".join(titles)
        return "Could not scrape any content from the results."
    ai_result = _generate_response_with_openai(query, successful, club_list=club_list)
    if "error" in ai_result:
        return f"Summarization failed: {ai_result['error']}"
    return ai_result.get("response", "No response.")


def run(query: str, club_list: bool = False) -> str:
    """
    Run web search: DuckDuckGo search -> scrape top 4 URLs -> summarize with OpenAI.
    club_list=True asks for a short official-club list (no Toastmasters Daily join URLs).
    """
    query = (query or "").strip()
    if not query:
        return "Error: empty query."
    out = _run_once(query, club_list=club_list)
    if _is_retry_eligible(query) and _is_no_good_result(out):
        logger.info("Retry once for query: %s", query[:60])
        out = _run_once(query, club_list=club_list)
    return out
