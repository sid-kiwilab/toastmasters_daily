"""
Web search action: DuckDuckGo search + scrape with curl_chrome110 (avoids blockers).
Same logic as actions/web_search/ app, exposed as a single run() for the LangGraph agent.
"""
import subprocess
import os
import urllib.parse
import concurrent.futures
import requests
from bs4 import BeautifulSoup

import logging
logger = logging.getLogger("toastmasters_agent.web_search")


def _count_tokens(text):
    return len(text) // 4


def _truncate_text(text, max_tokens=3000):
    tokens = _count_tokens(text)
    if tokens <= max_tokens:
        return text, tokens
    max_chars = max_tokens * 4
    truncated = text[:max_chars] + "... [truncated]"
    return truncated, _count_tokens(truncated)


def _search_duckduckgo(query):
    """Search DuckDuckGo using curl_chrome110 (avoids blockers)."""
    try:
        logger.info("Searching DuckDuckGo for: %s", query[:80])
        encoded_query = urllib.parse.quote(query)
        curl_command = [
            "curl_chrome110",
            f"https://duckduckgo.com/html/?q={encoded_query}",
            "-L",
            "-H", "Accept: application/json, text/plain, */*",
            "-H", "Accept-Language: en-US,en;q=0.9,en;q=0.8",
            "-H", "Accept-Encoding: gzip, deflate, br",
            "-H", "Cache-Control: no-cache",
            "-H", "Pragma: no-cache",
            "-H", "Sec-Ch-Ua: \"Google Chrome\";v=\"110\", \"Chromium\";v=\"110\", \"Not_A Brand\";v=\"24\"",
            "-H", "Sec-Ch-Ua-Mobile: ?0",
            "-H", "Sec-Ch-Ua-Platform: \"Windows\"",
            "-H", "Sec-Fetch-Dest: empty",
            "-H", "Sec-Fetch-Mode: cors",
            "-H", "Sec-Fetch-Site: same-origin",
            "-H", "Upgrade-Insecure-Requests: 1",
            "-H", "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36",
            "-H", "X-Requested-With: XMLHttpRequest",
            "--compressed",
            "--max-time", "30",
            "--connect-timeout", "10",
        ]
        result = subprocess.run(curl_command, capture_output=True, text=True, encoding="utf-8", errors="ignore")
        if result.returncode != 0:
            logger.error("DuckDuckGo search failed: %s", result.stderr)
            return {"error": "Search failed"}
        html_content = result.stdout
        soup = BeautifulSoup(html_content, "html.parser")
        results = []
        # Same selectors as web_search folder (avoiding ads)
        selectors = [
            ".result__a",
            ".result__title a",
            "h2 a[href^='http']",
            "a[href^='http']",
            ".result a[href^='http']",
            ".web-result a[href^='http']",
            "a[data-testid='result-title-a']",
            ".result__snippet a[href^='http']",
            "a[href*='http']",
            "a",
            ".result",
            ".web-result",
            "[data-testid*='result']",
        ]
        for selector in selectors:
            elements = soup.select(selector)
            if selector in ["a", "a[href*='http']", "a[href^='http']"]:
                for link in elements:
                    url = link.get("href", "")
                    title = link.get_text().strip()
                    if url.startswith("//duckduckgo.com/l/?uddg="):
                        try:
                            parsed = urllib.parse.urlparse(url)
                            qs = urllib.parse.parse_qs(parsed.query)
                            if "uddg" in qs:
                                url = urllib.parse.unquote(qs["uddg"][0])
                        except Exception:
                            pass
                    if (
                        url.startswith("http")
                        and title
                        and "duckduckgo.com" not in url
                        and "ad" not in link.get("class", [])
                        and "sponsor" not in link.get("class", [])
                        and "advertisement" not in title.lower()
                    ):
                        results.append({"title": title, "url": url})
        logger.info("Found %d search results", len(results))
        return {"results": results[:10]}
    except Exception as e:
        logger.error("Error searching DuckDuckGo: %s", e)
        return {"error": str(e)}


def _scrape_url(url):
    """Scrape a single URL using curl_chrome110."""
    try:
        if not url or not isinstance(url, str):
            return {"url": url, "content": "", "error": "Invalid URL"}
        url = url.strip()
        if not url.startswith(("http://", "https://")):
            return {"url": url, "content": "", "error": "URL must start with http:// or https://"}
        curl_command = [
            "curl_chrome110",
            url,
            "-H", "Accept: application/json, text/plain, */*",
            "-H", "Accept-Language: en-US,en;q=0.9,en;q=0.8",
            "-H", "Accept-Encoding: gzip, deflate, br",
            "-H", "Cache-Control: no-cache",
            "-H", "Pragma: no-cache",
            "-H", "Sec-Ch-Ua: \"Google Chrome\";v=\"110\", \"Chromium\";v=\"110\", \"Not_A Brand\";v=\"24\"",
            "-H", "Sec-Ch-Ua-Mobile: ?0",
            "-H", "Sec-Ch-Ua-Platform: \"Windows\"",
            "-H", "Sec-Fetch-Dest: empty",
            "-H", "Sec-Fetch-Mode: cors",
            "-H", "Sec-Fetch-Site: same-origin",
            "-H", "Upgrade-Insecure-Requests: 1",
            "-H", "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36",
            "-H", "X-Requested-With: XMLHttpRequest",
            "--compressed",
            "--max-time", "30",
            "--connect-timeout", "10",
        ]
        result = subprocess.run(curl_command, capture_output=True, text=True, encoding="utf-8", errors="ignore")
        if result.returncode != 0:
            return {"url": url, "content": "", "error": result.stderr or "Scraping failed"}
        soup = BeautifulSoup(result.stdout, "html.parser")
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


def _generate_response_with_openai(query, scraped_content):
    """Summarize scraped content with OpenAI."""
    key = os.getenv("OPENAI_API_KEY", "").strip()
    if not key:
        return {"error": "OPENAI_API_KEY not set"}
    content_summary = ""
    for i, result in enumerate(scraped_content, 1):
        if result.get("content"):
            content_summary += f"\n\nSource {i} ({result['url']}):\n{result['content']}\n"
    prompt = f"""Based on the following search results, provide a comprehensive and accurate answer to the query: "{query}"

Search Results:{content_summary}

Please provide a well-structured response that:
1. Directly answers the query
2. Uses information from the search results
3. Cites sources when appropriate
4. Is informative and helpful

Answer:"""
    try:
        resp = requests.post(
            "https://api.openai.com/v1/chat/completions",
            headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
            json={
                "model": "gpt-4o-mini",
                "messages": [
                    {"role": "system", "content": "You are a helpful assistant that provides accurate information based on search results."},
                    {"role": "user", "content": prompt},
                ],
                "max_tokens": 1000,
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
    """Only retry for: find club near me, or when does Toastmasters meet."""
    q = (query or "").lower()
    if not q:
        return False
    club_near = "club" in q and ("near" in q or "nearest" in q or "closest" in q or "find" in q or "meet" in q)
    when_meet = "when" in q and ("meet" in q or "meeting" in q) and "toastmaster" in q
    return bool(club_near or when_meet)


def _is_no_good_result(response: str) -> bool:
    """True if the response indicates no/failed results (retry once allowed)."""
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


def _run_once(query: str) -> str:
    """Single pass: search -> scrape -> summarize. Returns answer or error string."""
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
        return "Could not scrape any content from the results."
    ai_result = _generate_response_with_openai(query, successful)
    if "error" in ai_result:
        return f"Summarization failed: {ai_result['error']}"
    return ai_result.get("response", "No response.")


def run(query: str) -> str:
    """
    Run web search: DuckDuckGo search -> scrape top 4 URLs with curl_chrome110 -> summarize with OpenAI.
    For "club near me" and "when does Toastmasters meet" queries, retry once if the first result is no good.
    """
    query = (query or "").strip()
    if not query:
        return "Error: empty query."
    out = _run_once(query)
    if _is_retry_eligible(query) and _is_no_good_result(out):
        logger.info("Retry once for query: %s", query[:60])
        out = _run_once(query)
    return out
