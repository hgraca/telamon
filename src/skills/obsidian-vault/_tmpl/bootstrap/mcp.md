# MCP Servers

## Tool Selection

- **ast-grep**: Search or transform code using AST patterns
- **chrome-devtools-mcp**: Inspect or debug a browser via Chrome DevTools
- **context7**: Look up library or framework documentation
- **git**: Run git operations
- **github**: Interact with GitHub repositories, pull requests, issues, and code reviews
- **grep**: Search code across public GitHub repositories
- **playwright**: Interact with a browser or test web pages
- **exa**: Search the web
- **laravel-boost**: Run Laravel Artisan commands, manage migrations, scaffold Laravel components

## Laravel Boost

Laravel Boost is an MCP server with tools designed specifically for Laravel applications.

### Documentation Search

- Use the `search-docs` tool before trying other approaches for Laravel or ecosystem packages
- It automatically passes installed packages and versions, returning version-specific docs
- Pass an array of packages to filter when you know which packages you need
- Use multiple, broad, simple queries: `['rate limiting', 'routing rate limiting', 'routing']`
- Do not add package names to queries — package info is already included

#### Search Syntax

- Simple words with auto-stemming: `authentication` finds 'authenticate' and 'auth'
- Multiple words (AND): `rate limit`
- Quoted phrases (exact): `"infinite scroll"`
- Mixed: `middleware "rate limit"`
- Multiple queries: `queries=["authentication", "middleware"]`

### Other Boost Tools

- `database-query`: Read-only database queries
- `database-schema`: Inspect table structure before writing migrations or models
- `browser-logs`: Read recent browser logs, errors, and exceptions
- `get-absolute-url`: Get correct scheme, domain/IP, and port for project URLs — use when sharing URLs with the user

### Artisan via CLI

- Run Artisan commands directly: `php artisan route:list`, `php artisan tinker --execute "..."`
- Debug PHP code: `php artisan tinker --execute "your code here"`
- Read config: read config files directly or `php artisan config:show [key]`
- Inspect routes: `php artisan route:list`
- Check env vars: read the `.env` file directly (agent debugging only — does not override the architecture rule against `.env` references in production code)

### Frontend Bundling

- If frontend changes are not reflected in UI, the user may need to run `yarn run build`, `yarn run dev`, or `composer run dev`
- "Illuminate\Foundation\ViteException" error: run `yarn run build` or ask the user to run `yarn run dev` / `composer run dev`
