---
layout: home
title: Telamon
---

<section class="hero">
  <div class="container">
    <div class="hero-badge">Open Source &middot; Local-first &middot; Privacy-safe</div>
    <h1>The harness for agentic software development</h1>
    <p class="hero-subtitle">
      Everything a developer needs to get the best out of LLMs and coding agents &mdash;
      installed once, shared across every project.
      All tools run locally. No data leaves your machine.
    </p>
    <div class="hero-install">
      <span class="prompt">$</span> curl -fsSL https://raw.githubusercontent.com/hgraca/telamon/main/install.sh | bash<br>
      <span class="prompt">$</span> telamon init path/to/your-project<br>
      <span class="prompt">$</span> cd path/to/your-project && opencode
    </div>
    <div class="hero-actions">
      <a href="{{ '/developer-workflow' | relative_url }}" class="btn btn-primary">Read the docs</a>
      <a href="https://github.com/hgraca/telamon" class="btn btn-secondary" target="_blank" rel="noopener">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/></svg>
        View on GitHub
      </a>
    </div>
  </div>
</section>

<section class="section">
  <div class="container">
    <div class="section-header">
      <h2>Why Telamon?</h2>
      <p>Your coding agent forgets everything between sessions.<br>Telamon fixes that.</p>
    </div>
    <div class="feature-grid">
      <div class="feature-card">
        <div class="feature-icon">&#x1f9e0;</div>
        <h3>Persistent Agent Memory</h3>
        <p>Decisions, bugs, and patterns survive across sessions and projects. Your agent never starts from scratch.</p>
      </div>
      <div class="feature-card">
        <div class="feature-icon">&#x1f50d;</div>
        <h3>Codebase Understanding</h3>
        <p>Semantic code search and a structural knowledge graph let the agent find code by meaning, not just keywords.</p>
      </div>
      <div class="feature-card">
        <div class="feature-icon">&#x1f4d6;</div>
        <h3>Curated Knowledge Vault</h3>
        <p>Human-readable notes that survive model resets &mdash; goals, decisions, patterns, gotchas.</p>
      </div>
      <div class="feature-card">
        <div class="feature-icon">&#x1f504;</div>
        <h3>Session Recall</h3>
        <p>Searchable history of every past agent conversation. Context flows from one session to the next.</p>
      </div>
      <div class="feature-card">
        <div class="feature-icon">&#x1f916;</div>
        <h3>Multi-Agent System</h3>
        <p>Two agents: <strong>Telamon</strong>, an autonomous orchestrator that delegates to 10 specialized sub-agents, and <strong>Companion</strong>, a pair programmer that works alongside you. Slash commands trigger structured workflows.</p>
      </div>
      <div class="feature-card">
        <div class="feature-icon">&#x26a1;</div>
        <h3>Token Efficiency</h3>
        <p>Automatic output compression and caveman mode cut token usage by up to 75%. Less cost, faster responses.</p>
      </div>
    </div>
  </div>
</section>

<section class="section section-alt">
  <div class="container">
    <div class="section-header">
      <h2>What you get</h2>
    </div>
    <ul class="highlight-list">
      <li>
        <span class="check">&#x2713;</span>
        <span><strong>Install once, use everywhere</strong> &mdash; one <code>curl</code> installs the entire stack. Init any project in seconds.</span>
      </li>
      <li>
        <span class="check">&#x2713;</span>
        <span><strong>100% local</strong> &mdash; Postgres, Ollama, Obsidian, Docker. No cloud dependencies, no data exfiltration.</span>
      </li>
      <li>
        <span class="check">&#x2713;</span>
        <span><strong>Works with any coding agent</strong> &mdash; built for <a href="https://opencode.ai">opencode</a>, compatible with any MCP-capable agent.</span>
      </li>
      <li>
        <span class="check">&#x2713;</span>
        <span><strong>Automatic knowledge capture</strong> &mdash; learnings are promoted to memory before context is compacted. No manual intervention.</span>
      </li>
      <li>
        <span class="check">&#x2713;</span>
        <span><strong>Rich MCP integrations</strong> &mdash; GitHub, browser DevTools, Playwright, AST search, library docs, web search.</span>
      </li>
      <li>
        <span class="check">&#x2713;</span>
        <span><strong>Extensible with modules</strong> &mdash; add third-party commands, agents, skills, scripts, and plugins from any git repo. One command wires them into every project.</span>
      </li>
      <li>
        <span class="check">&#x2713;</span>
        <span><strong>Optional observability</strong> &mdash; opt-in Langfuse for token tracking and Graphiti + Neo4j for temporal knowledge graphs.</span>
      </li>
    </ul>
  </div>
</section>

<section class="section">
  <div class="container">
    <div class="section-header">
      <h2>Get started in 3 steps</h2>
      <p>Linux (Ubuntu/Debian/Mint) and macOS (Apple Silicon + Intel) supported.</p>
    </div>
    <div class="install-steps">
      <div class="install-step">
        <span class="step-number">1</span>
        <div>
          <h3>Install</h3>
          <p>One command installs everything &mdash; Docker, Node.js, Python, opencode, Obsidian, all memory tools, and the global <code>telamon</code> CLI.</p>
          <code>curl -fsSL https://raw.githubusercontent.com/hgraca/telamon/main/install.sh | bash</code>
        </div>
      </div>
      <div class="install-step">
        <span class="step-number">2</span>
        <div>
          <h3>Initialise a project</h3>
          <p>Wire up memory, knowledge graph, and vault for your project. Run once per project, from anywhere.</p>
          <code>telamon init path/to/your-project</code>
        </div>
      </div>
      <div class="install-step">
        <span class="step-number">3</span>
        <div>
          <h3>Start working</h3>
          <p>Open your project in opencode. Telamon is already there.</p>
          <code>cd path/to/your-project && opencode</code>
        </div>
      </div>
    </div>
    <div class="hero-actions" style="margin-top: 2.5rem;">
      <a href="{{ '/developer-workflow' | relative_url }}" class="btn btn-primary">Full developer workflow</a>
      <a href="{{ '/configuration' | relative_url }}" class="btn btn-secondary">Configuration guide</a>
    </div>
  </div>
</section>

<section class="section section-alt">
  <div class="container">
    <div class="section-header">
      <h2>Tools under the hood</h2>
      <p>Every tool runs locally. Telamon installs, configures, and manages them all.</p>
    </div>
    <div class="feature-grid">
      <div class="feature-card">
        <h3>Graphify</h3>
        <p>Structural knowledge graph auto-built from your codebase. Updated every 30 minutes.</p>
      </div>
      <div class="feature-card">
        <h3>Codebase Index</h3>
        <p>Semantic code search &mdash; find functions, classes, and patterns by describing what they do.</p>
      </div>
      <div class="feature-card">
        <h3>Obsidian + QMD</h3>
        <p>Curated knowledge vault with semantic search. Goals, decisions, patterns in human-readable notes.</p>
      </div>
      <div class="feature-card">
        <h3>RTK + Caveman</h3>
        <p>Automatic output compression and ultra-terse communication mode. Saves up to 75% of tokens.</p>
      </div>
    </div>
    <div class="hero-actions" style="margin-top: 2.5rem;">
      <a href="{{ '/tools' | relative_url }}" class="btn btn-secondary">See all tools &rarr;</a>
    </div>
  </div>
</section>
