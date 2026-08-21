param(
    [string]$OutputPath = (Join-Path (Join-Path (Split-Path $PSScriptRoot -Parent) 'deployment') 'Cross-Platform-AI-Activity.workbook')
)

$RogueDomains = "dynamic(['chatgpt.com','openai.com','openai.azure.com','oaiusercontent.com','oaistatic.com','claude.ai','claude.com','anthropic.com','gemini.google.com','aistudio.google.com','notebooklm.google.com','generativelanguage.googleapis.com','aiplatform.googleapis.com','ai.google.dev','deepmind.google','labs.google','perplexity.ai','deepseek.com','mistral.ai','huggingface.co','api.cohere.com','cohere.com','groq.com','together.xyz','openrouter.ai','replicate.com','api.ai21.com','router.requesty.ai','ark.cn-beijing.volces.com','api.sambanova.ai','api.fireworks.ai','api.asksage.ai','poe.com','character.ai','meta.ai','grok.com','x.ai','you.com','jasper.ai','copy.ai','runwayml.com','cursor.com','cursor.sh','codeium.com','windsurf.com','tabnine.com','replit.com','v0.dev','lovable.dev','bolt.new','grammarly.com','otter.ai','fireflies.ai','read.ai','githubcopilot.com','api.githubcopilot.com','api.enterprise.githubcopilot.com','copilot-proxy.githubusercontent.com','copilotstudio.microsoft.com','securitycopilot.microsoft.com','designer.microsoft.com','lex-runtime','polly.','deepgram.com','elevenlabs.io','gamma.app','meshy.ai','venice.ai','cline.bot','freeconvert.com','kiro.dev'])"
$ApprovedDomains = "dynamic(['copilot.microsoft.com','m365.cloud.microsoft','m365copilot.com','copilot.cloud.microsoft'])"
# Process classification lists are baked into every generated query at build time. The AgentProcesses list inside individual queries below is a separate copy. Tune all copies together, then rebuild, or the tabs will disagree.
$BrowserProcesses = "dynamic(['chrome.exe','msedge.exe','firefox.exe','brave.exe','opera.exe','vivaldi.exe','chrome','firefox','brave','opera','vivaldi','safari','Google Chrome','Microsoft Edge'])"
$ScriptProcesses = "dynamic(['python.exe','python3.exe','python','python3','powershell.exe','pwsh.exe','pwsh','curl.exe','curl','wget.exe','wget','node.exe','node','cmd.exe','wscript.exe','cscript.exe','bash','sh','zsh','jupyter.exe','jupyter-notebook.exe','rscript.exe','go.exe'])"
$LocalAIProcesses = "dynamic(['ollama.exe','ollama','lmstudio.exe','lmstudio','jan.exe','jan','gpt4all.exe','gpt4all','msty.exe','msty','anythingllm.exe','anythingllm','open-webui','chatgpt.exe','claude.exe','claude','cursor.exe','cursor','windsurf.exe','windsurf','aider.exe','aider','openclaw.exe','openclaw','opencode.exe','opencode','codex.exe','codex'])"
$AIServiceExpression = "case(RemoteUrl contains 'chatgpt' or RemoteUrl contains 'openai' or RemoteUrl contains 'oaistatic' or RemoteUrl contains 'oaiusercontent', 'OpenAI and ChatGPT', RemoteUrl contains 'claude' or RemoteUrl contains 'anthropic', 'Claude', RemoteUrl contains 'gemini' or RemoteUrl contains 'aistudio' or RemoteUrl contains 'notebooklm' or RemoteUrl contains 'ai.google.dev' or RemoteUrl contains 'deepmind.google' or RemoteUrl contains 'labs.google', 'Google AI', RemoteUrl contains 'perplexity', 'Perplexity', RemoteUrl contains 'deepseek', 'DeepSeek', RemoteUrl contains 'mistral', 'Mistral', RemoteUrl contains 'huggingface', 'Hugging Face', RemoteUrl contains 'cohere', 'Cohere', RemoteUrl contains 'groq', 'Groq', RemoteUrl contains 'openrouter', 'OpenRouter', RemoteUrl contains 'replicate', 'Replicate', RemoteUrl contains 'githubcopilot' or RemoteUrl contains 'copilot-proxy', 'GitHub Copilot', RemoteUrl contains 'cursor', 'Cursor', RemoteUrl contains 'windsurf' or RemoteUrl contains 'codeium', 'Windsurf and Codeium', RemoteUrl contains 'tabnine', 'Tabnine', RemoteUrl contains 'copilot.microsoft' or RemoteUrl contains 'm365.cloud.microsoft' or RemoteUrl contains 'm365copilot' or RemoteUrl contains 'copilot.cloud.microsoft', 'M365 Copilot', RemoteUrl contains 'copilotstudio.microsoft', 'Microsoft Copilot Studio', RemoteUrl contains 'securitycopilot.microsoft', 'Microsoft Security Copilot', RemoteUrl contains 'designer.microsoft', 'Microsoft Designer', RemoteUrl contains 'lex-runtime', 'Amazon Lex', RemoteUrl contains 'polly.', 'Amazon Polly', RemoteUrl contains 'deepgram', 'Deepgram', RemoteUrl contains 'elevenlabs', 'ElevenLabs', RemoteUrl contains 'gamma.app', 'Gamma', RemoteUrl contains 'meshy.ai', 'Meshy', RemoteUrl contains 'venice.ai', 'Venice AI', RemoteUrl contains 'cline.bot', 'Cline', RemoteUrl contains 'freeconvert', 'FreeConvert', RemoteUrl contains 'kiro.dev', 'Kiro', RemoteUrl contains 'meta.ai', 'Meta AI', RemoteUrl contains 'grok' or RemoteUrl contains 'x.ai', 'Grok', RemoteUrl contains 'poe.com', 'Poe', RemoteUrl contains 'character.ai', 'Character AI', RemoteUrl contains 'replit', 'Replit', RemoteUrl contains 'v0.dev', 'Vercel v0', RemoteUrl contains 'lovable', 'Lovable', RemoteUrl contains 'bolt.new', 'Bolt', RemoteUrl)"

$AICatalogRepository = 'https://github.com/v2fly/domain-list-community'
$AICatalogDataUrl = 'https://raw.githubusercontent.com/v2fly/domain-list-community/master/data'
$AICatalogCachePath = Join-Path $PSScriptRoot 'AI-Domain-Catalog.json'
$AICatalogRoots = @('category-ai-!cn', 'category-ai-cn')
$AICatalogSupplements = @(
    [pscustomobject]@{ Domain = 'api.githubcopilot.com'; Provider = 'GitHub Copilot MCP' },
    [pscustomobject]@{ Domain = 'api.enterprise.githubcopilot.com'; Provider = 'GitHub Copilot Enterprise API' },
    [pscustomobject]@{ Domain = 'mcp.atlassian.com'; Provider = 'Atlassian MCP' }
)

function ConvertTo-KqlLiteral {
    param([string]$Value)
    "'$(($Value ?? '') -replace "'", "''")'"
}

function ConvertTo-ProviderName {
    param([string]$Value)
    $name = (Get-Culture).TextInfo.ToTitleCase(($Value -replace '-!cn$', '' -replace '[-_]', ' '))
    $name = $name -replace '\bAi\b', 'AI'
    $name = $name -replace '\bOpenai\b', 'OpenAI'
    $name = $name -replace '\bGithub\b', 'GitHub'
    $name = $name -replace '\bXai\b', 'xAI'
    $name
}

function Get-ReferencedAICatalog {
    $visited = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $domains = [ordered]@{}
    $pending = [System.Collections.Generic.Queue[string]]::new()
    foreach ($root in $AICatalogRoots) {
        $pending.Enqueue($root)
    }

    while ($pending.Count -gt 0) {
        $ListName = $pending.Dequeue()
        if (-not $visited.Add($ListName)) { continue }
        $content = (Invoke-WebRequest -Uri "$AICatalogDataUrl/$ListName" -UseBasicParsing).Content
        foreach ($rawLine in $content -split "`r?`n") {
            $line = (($rawLine -split '#', 2)[0]).Trim()
            if (-not $line) { continue }

            if ($line -match '^include:([^\s]+)') {
                $pending.Enqueue($Matches[1])
                continue
            }

            if ($line -match '^(keyword|regexp):') { continue }
            $rule = ($line -replace '\s+[@&].*$', '')
            $domain = ($rule -replace '^(domain|full):', '').Trim().ToLowerInvariant()
            if ($domain -notmatch '^[a-z0-9.-]+\.[a-z]{2,}$') { continue }

            if (-not $domains.Contains($domain)) {
                $providerKey = if ($ListName -like 'category-ai-*') { ($domain -split '\.')[0] } else { $ListName }
                $domains[$domain] = ConvertTo-ProviderName $providerKey
            }
        }
    }

    @($domains.GetEnumerator() | ForEach-Object {
        [pscustomobject]@{ Domain = $_.Key; Provider = $_.Value }
    } | Sort-Object Domain)
}

try {
    $AICatalog = @(Get-ReferencedAICatalog)
    if ($AICatalog.Count -lt 100) {
        throw "The remote AI domain catalog returned only $($AICatalog.Count) entries."
    }
}
catch {
    if (-not (Test-Path $AICatalogCachePath)) {
        throw "Unable to retrieve the referenced AI domain catalog and no local cache exists. $($_.Exception.Message)"
    }
    $AICatalog = @((Get-Content $AICatalogCachePath -Raw | ConvertFrom-Json).Entries)
    if ($AICatalog.Count -lt 100) {
        throw "Unable to retrieve a complete AI domain catalog and the local cache contains only $($AICatalog.Count) entries. $($_.Exception.Message)"
    }
}

foreach ($supplement in $AICatalogSupplements) {
    if ($supplement.Domain -notin $AICatalog.Domain) {
        $AICatalog += $supplement
    }
}
$AICatalog = @($AICatalog | Sort-Object Domain -Unique)

[ordered]@{
    Source = $AICatalogRepository
    License = 'MIT'
    RetrievedUtc = [DateTime]::UtcNow.ToString('o')
    Roots = $AICatalogRoots
    Supplements = $AICatalogSupplements
    Entries = $AICatalog
} | ConvertTo-Json -Depth 5 | Set-Content -Path $AICatalogCachePath -Encoding utf8

if ($AICatalog.Count -eq 0) {
    throw 'The referenced AI domain catalog did not contain any usable domain rules.'
}

$ApprovedDomainValues = @('copilot.microsoft.com', 'm365.cloud.microsoft', 'm365copilot.com', 'copilot.cloud.microsoft')
$ApprovedDomains = "dynamic([$((@($ApprovedDomainValues | ForEach-Object { ConvertTo-KqlLiteral $_ })) -join ',')])"
$RogueDomainValues = @($AICatalog.Domain | Where-Object { $_ -notin $ApprovedDomainValues } | Sort-Object -Unique)
$RogueDomains = "dynamic([$((@($RogueDomainValues | ForEach-Object { ConvertTo-KqlLiteral $_ })) -join ',')])"

$NormalizedRemoteHostExpression = "tolower(tostring(parse_url(iff(RemoteUrl has '://', RemoteUrl, strcat('https://', RemoteUrl))).Host))"
$AIServiceExpression = "iff(RemoteUrl has_any ($ApprovedDomains), 'M365 Copilot', $NormalizedRemoteHostExpression)"

function New-TextItem {
    param([string]$Name, [string]$Text, [string]$Style = 'info')
    [ordered]@{
        type = 1
        content = [ordered]@{ version = 'NotebookText/1.0'; json = $Text; style = $Style }
        name = $Name
    }
}

function New-QueryItem {
    param(
        [string]$Name,
        [string]$Title,
        [string]$Query,
        [string]$Visualization = 'table',
        [string]$Width = '100',
        [string]$Height = '280',
        [int]$Size = 0,
        [switch]$Grid,
        [switch]$Tiles,
        [object]$ChartSettings
    )
    # Host scoped matching. Keep the indexed RemoteUrl prefilter for speed, then verify the parsed host so a domain string sitting in a URL path or query does not create a false match.
    $AIHostExpression = "tolower(tostring(parse_url(iff(RemoteUrl has '://', RemoteUrl, strcat('https://', RemoteUrl))).Host))"
    $Query = $Query -replace [regex]::Escape("| where isnotempty(RemoteUrl) and (RemoteUrl has_any (RogueDomains) or RemoteUrl has_any (ApprovedDomains))"), "| where isnotempty(RemoteUrl) and (RemoteUrl has_any (RogueDomains) or RemoteUrl has_any (ApprovedDomains))`n| extend AIHost=$AIHostExpression`n| where AIHost has_any (RogueDomains) or AIHost has_any (ApprovedDomains)"
    $Query = $Query -replace [regex]::Escape("| where isnotempty(RemoteUrl) and RemoteUrl has_any (RogueDomains)"), "| where isnotempty(RemoteUrl) and RemoteUrl has_any (RogueDomains)`n| extend AIHost=$AIHostExpression`n| where AIHost has_any (RogueDomains)"
    $Query = $Query -replace [regex]::Escape("| where isnotempty(RemoteUrl) and RemoteUrl has_any (ApprovedDomains)"), "| where isnotempty(RemoteUrl) and RemoteUrl has_any (ApprovedDomains)`n| extend AIHost=$AIHostExpression`n| where AIHost has_any (ApprovedDomains)"
    $content = [ordered]@{
        version = 'KqlItem/1.0'
        query = $Query.Trim()
        size = $Size
        title = $Title
        timeContextFromParameter = 'TimeRange'
        queryType = 0
        resourceType = 'microsoft.operationalinsights/workspaces'
        visualization = $Visualization
    }
    if ($ChartSettings) {
        $content.chartSettings = $ChartSettings
    }
    if ($Grid) {
        $content.maxItemsCount = 10000
        $content.gridSettings = [ordered]@{ filter = $true; rowLimit = 10000 }
        $content.showExportToExcel = $true
    }
    if ($Tiles) {
        $content.tileSettings = [ordered]@{
            showBorder = $true
            titleContent = [ordered]@{ columnMatch = 'label' }
            leftContent = [ordered]@{
                columnMatch = 'value'
                formatter = 12
                formatOptions = [ordered]@{ palette = 'auto' }
                numberFormat = [ordered]@{ unit = 17; options = [ordered]@{ style = 'decimal'; maximumFractionDigits = 0 } }
            }
            subtitleContent = [ordered]@{ columnMatch = 'subtitle'; formatter = 1 }
        }
    }
    [ordered]@{ type = 3; content = $content; customWidth = $Width; name = $Name }
}

function New-Group {
    param([string]$Name, [string]$TabValue, [object[]]$Items)
    [ordered]@{
        type = 12
        content = [ordered]@{ version = 'NotebookGroup/1.0'; groupType = 'editable'; items = $Items }
        conditionalVisibility = [ordered]@{ parameterName = 'Tab'; comparison = 'isEqualTo'; value = $TabValue }
        name = $Name
    }
}

$OverviewKpis = @"
let RogueDomains = $RogueDomains;
let ApprovedDomains = $ApprovedDomains;
let ScriptProcesses = $ScriptProcesses;
let LocalAIProcesses = $LocalAIProcesses;
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
let Rogue = DeviceNetworkEvents
| where isnotempty(RemoteUrl) and RemoteUrl has_any (RogueDomains)
| where not(RemoteUrl has_any (ApprovedDomains))
| extend Account = coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| extend AIService = $AIServiceExpression;
let Approved = DeviceNetworkEvents
| where isnotempty(RemoteUrl) and RemoteUrl has_any (ApprovedDomains)
| extend Account = coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter;
let LocalEvidence = union
    (DeviceProcessEvents
    | where FileName in~ (LocalAIProcesses)
    | extend Account = coalesce(AccountUpn, AccountName)
    | where DeviceFilter == '' or DeviceName contains DeviceFilter
    | where AccountFilter == '' or Account contains AccountFilter
    | project DeviceId),
    (DeviceFileEvents
    | where tolower(FileName) endswith '.gguf' or tolower(FileName) endswith '.ggml' or tolower(FileName) endswith '.safetensors'
    | extend Account = coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
    | where DeviceFilter == '' or DeviceName contains DeviceFilter
    | where AccountFilter == '' or Account contains AccountFilter
    | project DeviceId);
union
    (Rogue | summarize value=dcountif(Account, isnotempty(Account)) | extend label='Unauthorized users', subtitle='Distinct accounts using nonapproved AI'),
    (Rogue | summarize value=dcount(DeviceId) | extend label='Affected devices', subtitle='MDE devices with unauthorized AI access'),
    (Rogue | summarize value=dcount(AIService) | extend label='Unauthorized services', subtitle='Distinct nonapproved AI providers'),
    (Rogue | where InitiatingProcessFileName in~ (ScriptProcesses) | summarize value=dcountif(Account, isnotempty(Account)) | extend label='Scripted API users', subtitle='Accounts using automation against AI endpoints'),
    (LocalEvidence | summarize value=dcount(DeviceId) | extend label='Local AI devices', subtitle='Devices with local AI process or model evidence'),
    (Approved | summarize value=dcountif(Account, isnotempty(Account)) | extend label='Approved Copilot users', subtitle='Observed M365 Copilot accounts, excluded from rogue totals')
| project label, value, subtitle
"@

$OverviewTrend = @"
let RogueDomains = $RogueDomains;
let ApprovedDomains = $ApprovedDomains;
let AIDomains = array_concat(RogueDomains, ApprovedDomains);
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
DeviceNetworkEvents
| where isnotempty(RemoteUrl) and RemoteUrl has_any (AIDomains)
| extend AIHost = tolower(tostring(parse_url(iff(RemoteUrl has '://', RemoteUrl, strcat('https://', RemoteUrl))).Host))
| where AIHost has_any (AIDomains)
| extend Account = coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| extend IsApproved = AIHost has_any (ApprovedDomains)
| summarize UnauthorizedAIConnections=countif(not(IsApproved)), ApprovedM365CopilotConnections=countif(IsApproved) by bin(TimeGenerated, 1d)
| project TimeGenerated, ['Unauthorized AI']=UnauthorizedAIConnections, ['Approved M365 Copilot']=ApprovedM365CopilotConnections
| order by TimeGenerated asc
"@

$OverviewServices = @"
let RogueDomains = $RogueDomains;
let ApprovedDomains = $ApprovedDomains;
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
DeviceNetworkEvents
| where isnotempty(RemoteUrl) and RemoteUrl has_any (RogueDomains)
| where not(RemoteUrl has_any (ApprovedDomains))
| extend Account = coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| extend AIService = $AIServiceExpression
| summarize Events=count() by AIService
| top 5 by Events desc
| project AIService, Events
"@

$UnauthorizedDetail = @"
let RogueDomains = $RogueDomains;
let ApprovedDomains = $ApprovedDomains;
let BrowserProcesses = $BrowserProcesses;
let ScriptProcesses = $ScriptProcesses;
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
DeviceNetworkEvents
| where isnotempty(RemoteUrl) and RemoteUrl has_any (RogueDomains)
| where not(RemoteUrl has_any (ApprovedDomains))
| extend Account = coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| extend AIService = $AIServiceExpression
| extend AccessMethod = case(InitiatingProcessFileName in~ (ScriptProcesses), 'Script or API', InitiatingProcessFileName in~ (BrowserProcesses), 'Browser', 'Desktop or other application')
| summarize Events=count(), FirstSeen=min(TimeGenerated), LastSeen=max(TimeGenerated), Domains=make_set(RemoteUrl, 10), Actions=make_set(ActionType, 10) by AIService, DeviceName, DeviceId, Account, InitiatingProcessFileName, AccessMethod
| extend RiskScore = case(AccessMethod == 'Script or API' and Events > 50, 90, AccessMethod == 'Script or API', 75, AccessMethod == 'Desktop or other application', 65, Events > 100, 60, 40)
| extend RiskLevel = case(RiskScore >= 85, 'Critical', RiskScore >= 70, 'High', RiskScore >= 50, 'Medium', 'Low')
| extend RecommendedAction = case(AccessMethod == 'Script or API', 'Validate business need, identify API credentials, and contain unauthorized automation', AccessMethod == 'Desktop or other application', 'Verify installation approval and remove unauthorized software', 'Confirm business purpose and coach or restrict the account')
| project LastSeen, RiskLevel, RiskScore, RecommendedAction, AIService, AccessMethod, Account, DeviceName, InitiatingProcessFileName, Events, FirstSeen, Domains, Actions
| top 10000 by RiskScore desc
"@

$TopUsers = @"
let RogueDomains = $RogueDomains;
let ApprovedDomains = $ApprovedDomains;
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
DeviceNetworkEvents
| where isnotempty(RemoteUrl) and RemoteUrl has_any (RogueDomains)
| where not(RemoteUrl has_any (ApprovedDomains))
| extend Account = coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| extend AIService = $AIServiceExpression
| summarize Events=count() by Account
| where isnotempty(Account)
| top 5 by Events desc
| project Account, Events
"@

$ExposureIndicators = @"
let CorrelationWindow = 10m;
let RogueDomains = $RogueDomains;
let ApprovedDomains = $ApprovedDomains;
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
let SensitiveExtensions = dynamic(['.csv','.xlsx','.xls','.mdb','.accdb','.sqlite','.sql','.pdf','.docx','.doc','.env','.config','.json','.yaml','.yml','.xml','.ini','.py','.ps1','.sh','.js','.ts','.pem','.key','.pfx','.p12','.cer','.bak','.backup','.dump']);
let SensitivePaths = dynamic(['confidential','sensitive','pii','private','secret','password','credential','finance','employee','payroll','ssn','personal','operations','infrastructure','controlled','cui','fouo']);
let Files = DeviceFileEvents
| where ActionType in ('FileCreated','FileModified','FileCreatedAggregatedReport','FileModifiedAggregatedReport')
| extend Extension = extract(@'\.[^.]+$', 0, tolower(FileName))
| where Extension in (SensitiveExtensions) or FolderPath has_any (SensitivePaths)
| extend Account = coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
| where isnotempty(Account)
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| extend FileActivityTime=TimeGenerated
| extend CorrelationBucket=pack_array(bin(FileActivityTime, CorrelationWindow), bin(FileActivityTime, CorrelationWindow) + CorrelationWindow)
| mv-expand CorrelationBucket to typeof(datetime)
| project FileActivityTime, CorrelationBucket, DeviceId, DeviceName, Account, FileName, FolderPath, Extension, FileAction=ActionType, FileProcess=InitiatingProcessFileName;
let RogueConnections = DeviceNetworkEvents
| where isnotempty(RemoteUrl) and RemoteUrl has_any (RogueDomains)
| where not(RemoteUrl has_any (ApprovedDomains))
| extend Account = coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
| where isnotempty(Account)
| extend AIService = $AIServiceExpression
| extend AIConnectionTime=TimeGenerated, CorrelationBucket=bin(TimeGenerated, CorrelationWindow)
| project AIConnectionTime, CorrelationBucket, DeviceId, Account, AIService, RemoteUrl, AIProcess=InitiatingProcessFileName;
Files
| join kind=inner hint.strategy=shuffle RogueConnections on DeviceId, Account, CorrelationBucket
| where AIConnectionTime between (FileActivityTime .. FileActivityTime + CorrelationWindow)
| extend MinutesUntilAI = datetime_diff('minute', AIConnectionTime, FileActivityTime)
| extend RiskScore = case(Extension in ('.pfx','.p12','.pem','.key','.env','.sql','.dump'), 85, FolderPath has_any ('secret','credential','payroll','ssn','cui','fouo'), 80, MinutesUntilAI <= 2, 70, 60)
| extend RiskLevel = case(RiskScore >= 85, 'Critical', RiskScore >= 70, 'High', 'Medium')
| extend EvidenceStatement = strcat('Sensitive file activity preceded ', AIService, ' access by ', tostring(MinutesUntilAI), ' minute(s). This is an exposure indicator, not proof of upload.')
| extend RecommendedAction = case(RiskScore >= 85, 'Preserve evidence, contact the user, inspect file and browser activity, and assess containment', RiskScore >= 70, 'Validate the file purpose and review surrounding process and network activity', 'Review the user and device timeline for legitimate business context')
| project AIConnectionTime, RiskLevel, RiskScore, RecommendedAction, Account, DeviceName, AIService, AIProcess, FileName, FolderPath, FileAction, FileProcess, MinutesUntilAI, EvidenceStatement
| top 10000 by RiskScore desc
"@

$ExposureSummary = @"
let CorrelationWindow = 10m;
let RogueDomains = $RogueDomains;
let ApprovedDomains = $ApprovedDomains;
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
let Files = DeviceFileEvents
| where ActionType in ('FileCreated','FileModified','FileCreatedAggregatedReport','FileModifiedAggregatedReport')
| extend Extension = extract(@'\.[^.]+$', 0, tolower(FileName))
| where Extension in ('.csv','.xlsx','.xls','.sql','.pdf','.docx','.env','.json','.yaml','.yml','.py','.ps1','.pem','.key','.pfx','.p12','.dump') or FolderPath has_any ('confidential','sensitive','pii','secret','credential','finance','payroll','ssn','cui','fouo')
| extend Account = coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
| where isnotempty(Account)
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| project FileActivityTime=TimeGenerated, DeviceId, Account, Extension;
let RogueConnections = DeviceNetworkEvents
| where isnotempty(RemoteUrl) and RemoteUrl has_any (RogueDomains)
| where not(RemoteUrl has_any (ApprovedDomains))
| extend Account = coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
| where isnotempty(Account)
| extend AIService = $AIServiceExpression
| project AIConnectionTime=TimeGenerated, DeviceId, Account, AIService;
Files
| join kind=inner RogueConnections on DeviceId, Account
| where AIConnectionTime between (FileActivityTime .. FileActivityTime + CorrelationWindow)
| summarize Indicators=count() by AIService
| top 5 by Indicators desc
| project AIService, Indicators
"@

$AutomationDetail = @"
let RogueDomains = $RogueDomains;
let ApprovedDomains = $ApprovedDomains;
let ScriptProcesses = $ScriptProcesses;
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
let Connections = DeviceNetworkEvents
| where isnotempty(RemoteUrl) and RemoteUrl has_any (RogueDomains)
| where not(RemoteUrl has_any (ApprovedDomains))
| where InitiatingProcessFileName in~ (ScriptProcesses)
| extend Account = coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| extend AIService = $AIServiceExpression
| project TimeGenerated, DeviceId, DeviceName, Account, Process=InitiatingProcessFileName, AIService, RemoteUrl;
let ProcessContext = DeviceProcessEvents
| where FileName in~ (ScriptProcesses)
| where ProcessCommandLine has_any ('openai','anthropic','gemini','langchain','llamaindex','transformers','huggingface','api_key','OPENAI_API_KEY','cohere','mistral','ollama','gpt','claude','llm')
| extend Account = coalesce(AccountUpn, AccountName)
| summarize CommandLines=make_set(ProcessCommandLine, 5), ParentProcesses=make_set(InitiatingProcessFileName, 5) by DeviceId, Account, Process=FileName;
Connections
| summarize APICalls=count(), FirstCall=min(TimeGenerated), LastCall=max(TimeGenerated), Endpoints=make_set(RemoteUrl, 10), Services=make_set(AIService, 10) by DeviceId, DeviceName, Account, Process
| join kind=leftouter ProcessContext on DeviceId, Account, Process
| extend RiskScore = case(APICalls > 500, 95, APICalls > 50, 85, APICalls > 10, 70, 60)
| extend RiskLevel = case(RiskScore >= 90, 'Critical', RiskScore >= 80, 'High', RiskScore >= 70, 'Medium', 'Low')
| extend RecommendedAction = case(RiskScore >= 90, 'Disable exposed credentials, stop the process, and isolate if activity is unapproved', RiskScore >= 80, 'Identify the script owner, API key source, and data handled', 'Validate business purpose and move access to an approved service')
| project LastCall, RiskLevel, RiskScore, RecommendedAction, Account, DeviceName, Process, APICalls, Services, FirstCall, Endpoints, CommandLines, ParentProcesses
| top 10000 by RiskScore desc
"@

$AutomationTrend = @"
let RogueDomains = $RogueDomains;
let ApprovedDomains = $ApprovedDomains;
let ScriptProcesses = $ScriptProcesses;
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
DeviceNetworkEvents
| where isnotempty(RemoteUrl) and RemoteUrl has_any (RogueDomains)
| where not(RemoteUrl has_any (ApprovedDomains))
| where InitiatingProcessFileName in~ (ScriptProcesses)
| extend Account = coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| summarize APICalls=count(), Users=dcountif(Account, isnotempty(Account)) by bin(TimeGenerated, 1d), InitiatingProcessFileName
| order by TimeGenerated asc
"@

$LocalEvidence = @"
let LocalAIProcesses = $LocalAIProcesses;
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
let Downloads = DeviceFileEvents
| where ActionType in ('FileCreated','FileModified')
| where FileName has_any ('ChatGPT','Claude','ollama','LM Studio','LMStudio','gpt4all','GPT4All','Perplexity','Cursor','Windsurf','Codeium','Tabnine','Msty','AnythingLLM','Jan')
| where tolower(FileName) endswith '.exe' or tolower(FileName) endswith '.msi' or tolower(FileName) endswith '.msix' or tolower(FileName) endswith '.pkg' or tolower(FileName) endswith '.dmg' or tolower(FileName) endswith '.zip' or tolower(FileName) endswith '.crx' or tolower(FileName) endswith '.xpi'
| extend Account = coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
| project TimeGenerated, DeviceName, DeviceId, Account, EvidenceType='AI installer or extension', Artifact=FileName, Detail=FolderPath, FileSize, InitiatingProcessFileName;
let Models = DeviceFileEvents
| where ActionType in ('FileCreated','FileModified')
| where tolower(FileName) endswith '.gguf' or tolower(FileName) endswith '.ggml' or tolower(FileName) endswith '.safetensors' or (tolower(FileName) endswith '.bin' and FileSize > 500000000)
| extend Account = coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
| project TimeGenerated, DeviceName, DeviceId, Account, EvidenceType='Local model file', Artifact=FileName, Detail=FolderPath, FileSize, InitiatingProcessFileName;
let Executions = DeviceProcessEvents
| where FileName in~ (LocalAIProcesses)
| where not(FileName startswith 'Microsoft.Copilot')
| extend Account = coalesce(AccountUpn, AccountName)
| project TimeGenerated, DeviceName, DeviceId, Account, EvidenceType='Local AI execution', Artifact=FileName, Detail=ProcessCommandLine, FileSize=long(0), InitiatingProcessFileName;
union Downloads, Models, Executions
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| extend RiskScore = case(EvidenceType == 'Local model file', 85, EvidenceType == 'Local AI execution', 75, 55)
| extend RiskLevel = case(RiskScore >= 85, 'Critical', RiskScore >= 70, 'High', 'Medium')
| extend RecommendedAction = case(EvidenceType == 'Local model file', 'Identify model provenance and owner, inspect nearby data, and remove if unauthorized', EvidenceType == 'Local AI execution', 'Capture process context and validate approved use before containment', 'Verify installer source and remove unauthorized package')
| project TimeGenerated, RiskLevel, RiskScore, RecommendedAction, EvidenceType, Account, DeviceName, Artifact, Detail, FileSize, InitiatingProcessFileName
| top 10000 by RiskScore desc
"@

$LocalSummary = @"
let LocalAIProcesses = $LocalAIProcesses;
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
let Files = DeviceFileEvents
| where ActionType in ('FileCreated','FileModified')
| extend LowerName=tolower(FileName), Account=coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
| where LowerName endswith '.gguf' or LowerName endswith '.ggml' or LowerName endswith '.safetensors' or FileName has_any ('ollama','LM Studio','LMStudio','gpt4all','GPT4All','Cursor','Windsurf','Codeium','Tabnine','Msty','AnythingLLM')
| extend EvidenceType=iff(LowerName endswith '.gguf' or LowerName endswith '.ggml' or LowerName endswith '.safetensors', 'Local model file', 'Installer or package')
| project TimeGenerated, DeviceName, DeviceId, Account, EvidenceType;
let Processes = DeviceProcessEvents
| where FileName in~ (LocalAIProcesses)
| extend Account=coalesce(AccountUpn, AccountName), EvidenceType='Local AI execution'
| project TimeGenerated, DeviceName, DeviceId, Account, EvidenceType;
union Files, Processes
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| summarize Events=count() by EvidenceType
| top 5 by Events desc
| project EvidenceType, Events
"@

$AgentProcesses = @"
let AgentProcesses = dynamic(['claude.exe','claude','cursor.exe','cursor','windsurf.exe','windsurf','aider.exe','aider','openclaw.exe','openclaw','opencode.exe','opencode','codex.exe','codex','cline.exe','continue.exe']);
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
DeviceProcessEvents
| where FileName in~ (AgentProcesses) or ProcessCommandLine has_any (' mcp ','--mcp','mcp.json','modelcontextprotocol','openclaw','opencode','aider','claude-code')
| extend Account=coalesce(AccountUpn, AccountName)
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| extend RecommendedAction='Identify the agent owner, review tool permissions and MCP servers, then stop unauthorized execution'
| project TimeGenerated, RecommendedAction, DeviceName, DeviceId, Account, FileName, ProcessCommandLine, FolderPath, SHA256, InitiatingProcessFileName, InitiatingProcessCommandLine
| top 10000 by TimeGenerated desc
"@

$ContextFiles = @"
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
let FileEvidence = DeviceFileEvents
| where FileName in~ ('AGENTS.md','CLAUDE.md','.cursorrules','.cursorignore','mcp.json','mcp.yaml','mcp.yml','SKILL.md','copilot-instructions.md','settings.json') or FolderPath has_any ('.claude','.cursor','.agents','.continue','.openclaw')
| extend Account=coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
| project TimeGenerated, DeviceName, DeviceId, Account, EvidenceType='Instruction or MCP configuration file', ActionType, Artifact=FileName, Detail=FolderPath, SHA256, InitiatingProcessFileName, InitiatingProcessCommandLine;
let ProcessEvidence = DeviceProcessEvents
| where ProcessCommandLine has_any (' mcp ','--mcp','mcp.json','modelcontextprotocol','openclaw','opencode','aider','claude-code')
| extend Account=coalesce(AccountUpn, AccountName)
| project TimeGenerated, DeviceName, DeviceId, Account, EvidenceType='MCP or agent command', ActionType, Artifact=FileName, Detail=ProcessCommandLine, SHA256, InitiatingProcessFileName, InitiatingProcessCommandLine;
union FileEvidence, ProcessEvidence
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| extend RecommendedAction=iff(EvidenceType == 'MCP or agent command', 'Identify the command owner and review tool permissions, credentials, and configured servers', 'Review instructions, tools, credentials, and server definitions before allowing agent execution')
| project TimeGenerated, RecommendedAction, EvidenceType, DeviceName, DeviceId, Account, ActionType, Artifact, Detail, SHA256, InitiatingProcessFileName, InitiatingProcessCommandLine
| top 10000 by TimeGenerated desc
"@

$PriorityQueue = @"
let RogueDomains = $RogueDomains;
let ApprovedDomains = $ApprovedDomains;
let ScriptProcesses = $ScriptProcesses;
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
let NetworkFindings = DeviceNetworkEvents
| where isnotempty(RemoteUrl) and RemoteUrl has_any (RogueDomains)
| where not(RemoteUrl has_any (ApprovedDomains))
| extend Account=coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName), AIService=$AIServiceExpression
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| summarize Events=count(), FirstSeen=min(TimeGenerated), LastSeen=max(TimeGenerated), Evidence=make_set(RemoteUrl, 8) by DeviceName, DeviceId, Account, AIService, Process=InitiatingProcessFileName
| extend FindingType=iff(Process in~ (ScriptProcesses), 'Scripted AI API access', 'Unauthorized AI access'), RiskScore=iff(Process in~ (ScriptProcesses), iff(Events > 50, 90, 80), iff(Events > 100, 65, 50))
| project LastSeen, FirstSeen, DeviceName, DeviceId, Account, FindingType, RiskScore, Subject=AIService, Process, Events, Evidence;
let ModelFindings = DeviceFileEvents
| where ActionType in ('FileCreated','FileModified')
| where tolower(FileName) endswith '.gguf' or tolower(FileName) endswith '.ggml' or tolower(FileName) endswith '.safetensors'
| extend Account=coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| project LastSeen=TimeGenerated, FirstSeen=TimeGenerated, DeviceName, DeviceId, Account, FindingType='Local AI model file', RiskScore=85, Subject=FileName, Process=InitiatingProcessFileName, Events=1, Evidence=pack_array(FolderPath);
let PersistenceFindings = DeviceRegistryEvents
| where (RegistryKey has 'CurrentVersion' and RegistryKey has 'Run') or RegistryKey has 'Services'
| where RegistryValueData has_any ('ollama','lmstudio','gpt4all','claude','cursor','windsurf','aider','openclaw','opencode','codex')
| extend Account=coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| project LastSeen=TimeGenerated, FirstSeen=TimeGenerated, DeviceName, DeviceId, Account, FindingType='AI persistence', RiskScore=90, Subject=RegistryValueName, Process=InitiatingProcessFileName, Events=1, Evidence=pack_array(RegistryKey, RegistryValueData);
union NetworkFindings, ModelFindings, PersistenceFindings
| extend RiskLevel=case(RiskScore >= 90, 'Critical', RiskScore >= 75, 'High', RiskScore >= 50, 'Medium', 'Low')
| extend RecommendedAction=case(FindingType == 'AI persistence', 'Remove persistence, preserve artifacts, and inspect the full process tree', FindingType == 'Local AI model file', 'Identify owner and model source, inspect adjacent data, and remove if unauthorized', FindingType == 'Scripted AI API access', 'Identify credentials and data scope, then stop unauthorized automation', 'Confirm business purpose and apply access controls or user coaching')
| project LastSeen, RiskLevel, RiskScore, RecommendedAction, FindingType, Subject, Account, DeviceName, Process, Events, FirstSeen, Evidence
| top 10000 by RiskScore desc
"@

$RelatedAlerts = @"
let RogueDomains = $RogueDomains;
let ApprovedDomains = $ApprovedDomains;
let LocalAIProcesses = $LocalAIProcesses;
let DeviceFilter = '{DeviceFilter}';
let AIDevices = union
    (DeviceNetworkEvents | where isnotempty(RemoteUrl) and RemoteUrl has_any (RogueDomains) | where not(RemoteUrl has_any (ApprovedDomains)) | project DeviceId),
    (DeviceProcessEvents | where FileName in~ (LocalAIProcesses) | project DeviceId)
| where isnotempty(DeviceId)
| distinct DeviceId;
AlertEvidence
| where EntityType =~ 'Machine' and isnotempty(DeviceId)
| join kind=inner AIDevices on DeviceId
| join kind=inner (AlertInfo | project AlertId, AlertTimestamp=TimeGenerated, Title, Severity, Category, ServiceSource, DetectionSource, AttackTechniques) on AlertId
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| extend Association='Same device has unauthorized or local AI evidence. This association does not prove the alert was caused by AI activity.'
| extend RecommendedAction='Open the alert, compare its timeline with AI evidence, and escalate only when the activity is related'
| project AlertTimestamp, Severity, RecommendedAction, Title, DeviceName, DeviceId, AlertId, Category, ServiceSource, DetectionSource, AttackTechniques, Association
| top 10000 by AlertTimestamp desc
"@

$UnauthorizedDevices = @"
let RogueDomains = $RogueDomains;
let ApprovedDomains = $ApprovedDomains;
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
DeviceNetworkEvents
| where isnotempty(RemoteUrl) and RemoteUrl has_any (RogueDomains)
| where not(RemoteUrl has_any (ApprovedDomains))
| extend Account=coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName), AIService=$AIServiceExpression
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| summarize Events=count() by DeviceName
| top 5 by Events desc
| project DeviceName, Events
"@

$UnauthorizedMethods = @"
let RogueDomains = $RogueDomains;
let ApprovedDomains = $ApprovedDomains;
let BrowserProcesses = $BrowserProcesses;
let ScriptProcesses = $ScriptProcesses;
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
DeviceNetworkEvents
| where isnotempty(RemoteUrl) and RemoteUrl has_any (RogueDomains)
| where not(RemoteUrl has_any (ApprovedDomains))
| extend Account=coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| extend AccessMethod=case(InitiatingProcessFileName in~ (ScriptProcesses), 'Script or API', InitiatingProcessFileName in~ (BrowserProcesses), 'Browser', 'Desktop or other')
| summarize Events=count() by AccessMethod
| top 5 by Events desc
| project AccessMethod, Events
"@

$ExposureRiskSummary = @"
let CorrelationWindow = 10m;
let RogueDomains = $RogueDomains;
let ApprovedDomains = $ApprovedDomains;
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
let Files = DeviceFileEvents
| where ActionType in ('FileCreated','FileModified','FileCreatedAggregatedReport','FileModifiedAggregatedReport')
| extend Extension=extract(@'\.[^.]+$', 0, tolower(FileName)), Account=coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
| where Extension in ('.csv','.xlsx','.xls','.sql','.pdf','.docx','.env','.json','.yaml','.yml','.py','.ps1','.pem','.key','.pfx','.p12','.dump') or FolderPath has_any ('confidential','sensitive','pii','secret','credential','finance','payroll','ssn','cui','fouo')
| where isnotempty(Account)
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| project FileActivityTime=TimeGenerated, DeviceId, DeviceName, Account, Extension, FolderPath;
let Connections = DeviceNetworkEvents
| where isnotempty(RemoteUrl) and RemoteUrl has_any (RogueDomains)
| where not(RemoteUrl has_any (ApprovedDomains))
| extend Account=coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
| where isnotempty(Account)
| project AIConnectionTime=TimeGenerated, DeviceId, Account;
Files
| join kind=inner Connections on DeviceId, Account
| where AIConnectionTime between (FileActivityTime .. FileActivityTime + CorrelationWindow)
| extend MinutesUntilAI=datetime_diff('minute', AIConnectionTime, FileActivityTime)
| extend RiskScore=case(Extension in ('.pfx','.p12','.pem','.key','.env','.sql','.dump'), 85, FolderPath has_any ('secret','credential','payroll','ssn','cui','fouo'), 80, MinutesUntilAI <= 2, 70, 60)
| extend RiskLevel=case(RiskScore >= 85, 'Critical', RiskScore >= 70, 'High', 'Medium')
| summarize Indicators=count() by RiskLevel
| top 5 by Indicators desc
| project RiskLevel, Indicators
"@

$AutomationProcesses = @"
let RogueDomains = $RogueDomains;
let ApprovedDomains = $ApprovedDomains;
let ScriptProcesses = $ScriptProcesses;
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
DeviceNetworkEvents
| where isnotempty(RemoteUrl) and RemoteUrl has_any (RogueDomains)
| where not(RemoteUrl has_any (ApprovedDomains))
| where InitiatingProcessFileName in~ (ScriptProcesses)
| extend Account=coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| summarize APICalls=count() by Process=InitiatingProcessFileName
| top 5 by APICalls desc
| project Process, APICalls
"@

$LocalDevices = @"
let LocalAIProcesses = $LocalAIProcesses;
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
let Files = DeviceFileEvents
| where ActionType in ('FileCreated','FileModified')
| extend LowerName=tolower(FileName), Account=coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
| where LowerName endswith '.gguf' or LowerName endswith '.ggml' or LowerName endswith '.safetensors' or FileName has_any ('ollama','LM Studio','LMStudio','gpt4all','GPT4All','Cursor','Windsurf','Codeium','Tabnine','Msty','AnythingLLM')
| extend EvidenceType=iff(LowerName endswith '.gguf' or LowerName endswith '.ggml' or LowerName endswith '.safetensors', 'Model file', 'Installer or package')
| project TimeGenerated, DeviceName, DeviceId, Account, EvidenceType;
let Processes = DeviceProcessEvents
| where FileName in~ (LocalAIProcesses)
| extend Account=coalesce(AccountUpn, AccountName), EvidenceType='Execution'
| project TimeGenerated, DeviceName, DeviceId, Account, EvidenceType;
union Files, Processes
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| summarize Events=count() by DeviceName
| top 5 by Events desc
| project DeviceName, Events
"@

$LocalTrend = @"
let LocalAIProcesses = $LocalAIProcesses;
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
let Files = DeviceFileEvents
| where ActionType in ('FileCreated','FileModified')
| extend LowerName=tolower(FileName), Account=coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
| where LowerName endswith '.gguf' or LowerName endswith '.ggml' or LowerName endswith '.safetensors' or FileName has_any ('ollama','LM Studio','LMStudio','gpt4all','GPT4All','Cursor','Windsurf','Codeium','Tabnine','Msty','AnythingLLM')
| extend EvidenceType=iff(LowerName endswith '.gguf' or LowerName endswith '.ggml' or LowerName endswith '.safetensors', 'Model file', 'Installer or package')
| project TimeGenerated, DeviceName, Account, EvidenceType;
let Processes = DeviceProcessEvents
| where FileName in~ (LocalAIProcesses)
| extend Account=coalesce(AccountUpn, AccountName), EvidenceType='Execution'
| project TimeGenerated, DeviceName, Account, EvidenceType;
union Files, Processes
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| summarize Events=count() by bin(TimeGenerated, 1d), EvidenceType
| order by TimeGenerated asc
"@

$AgentScope = @"
let AgentProcesses = dynamic(['claude.exe','claude','cursor.exe','cursor','windsurf.exe','windsurf','aider.exe','aider','openclaw.exe','openclaw','opencode.exe','opencode','codex.exe','codex','cline.exe','continue.exe']);
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
let Processes = DeviceProcessEvents
| where FileName in~ (AgentProcesses) or ProcessCommandLine has_any (' mcp ','--mcp','mcp.json','modelcontextprotocol','openclaw','opencode','aider','claude-code')
| extend Account=coalesce(AccountUpn, AccountName), EvidenceType='Agent execution'
| project TimeGenerated, DeviceName, DeviceId, Account, EvidenceType;
let Files = DeviceFileEvents
| where FileName in~ ('AGENTS.md','CLAUDE.md','.cursorrules','.cursorignore','mcp.json','mcp.yaml','mcp.yml','SKILL.md','copilot-instructions.md','settings.json') or FolderPath has_any ('.claude','.cursor','.agents','.continue','.openclaw')
| extend Account=coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName), EvidenceType='Agent configuration'
| project TimeGenerated, DeviceName, DeviceId, Account, EvidenceType;
union Processes, Files
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| summarize Events=count(), Devices=dcount(DeviceId), Users=dcountif(Account, isnotempty(Account)), LastSeen=max(TimeGenerated) by EvidenceType
| top 10000 by Events desc
"@

$RelatedAlertSummary = @"
let RogueDomains = $RogueDomains;
let ApprovedDomains = $ApprovedDomains;
let LocalAIProcesses = $LocalAIProcesses;
let DeviceFilter = '{DeviceFilter}';
let AIDevices = union
    (DeviceNetworkEvents | where isnotempty(RemoteUrl) and RemoteUrl has_any (RogueDomains) | where not(RemoteUrl has_any (ApprovedDomains)) | project DeviceId),
    (DeviceProcessEvents | where FileName in~ (LocalAIProcesses) | project DeviceId)
| where isnotempty(DeviceId)
| distinct DeviceId;
AlertEvidence
| where EntityType =~ 'Machine' and isnotempty(DeviceId)
| join kind=inner AIDevices on DeviceId
| join kind=inner (AlertInfo | project AlertId, Severity, AlertTimestamp=TimeGenerated) on AlertId
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| summarize Alerts=dcount(AlertId) by Severity
| top 5 by Alerts desc
| project Severity, Alerts
"@

$NativeInvestigationSignals = @"
let RogueDomains = $RogueDomains;
let ApprovedDomains = $ApprovedDomains;
let ScriptProcesses = $ScriptProcesses;
let LocalAIProcesses = $LocalAIProcesses;
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
union
    (DeviceNetworkEvents
    | where isnotempty(RemoteUrl) and RemoteUrl has_any (RogueDomains)
    | where not(RemoteUrl has_any (ApprovedDomains))
    | extend Account=coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
    | where DeviceFilter == '' or DeviceName contains DeviceFilter
    | where AccountFilter == '' or Account contains AccountFilter
    | summarize value=count()
    | extend label='Unauthorized AI connections', subtitle='Native DeviceNetworkEvents evidence'),
    (DeviceNetworkEvents
    | where isnotempty(RemoteUrl) and RemoteUrl has_any (RogueDomains)
    | where not(RemoteUrl has_any (ApprovedDomains)) and InitiatingProcessFileName in~ (ScriptProcesses)
    | extend Account=coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
    | where DeviceFilter == '' or DeviceName contains DeviceFilter
    | where AccountFilter == '' or Account contains AccountFilter
    | summarize value=count()
    | extend label='Scripted AI connections', subtitle='Potential API automation'),
    (DeviceProcessEvents
    | where FileName in~ (LocalAIProcesses) or ProcessCommandLine has_any (' mcp ','--mcp','mcp.json','modelcontextprotocol')
    | extend Account=coalesce(AccountUpn, AccountName)
    | where DeviceFilter == '' or DeviceName contains DeviceFilter
    | where AccountFilter == '' or Account contains AccountFilter
    | summarize value=count()
    | extend label='Local agent executions', subtitle='Native process evidence'),
    (DeviceFileEvents
    | extend LowerName=tolower(FileName), Account=coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
    | where LowerName endswith '.gguf' or LowerName endswith '.ggml' or LowerName endswith '.safetensors' or FileName in~ ('AGENTS.md','CLAUDE.md','mcp.json','mcp.yaml','mcp.yml','SKILL.md')
    | where DeviceFilter == '' or DeviceName contains DeviceFilter
    | where AccountFilter == '' or Account contains AccountFilter
    | summarize value=count()
    | extend label='Model and configuration files', subtitle='Native file evidence')
| project label, value, subtitle
"@

$ApprovedCopilotDetail = @"
let ApprovedDomains = $ApprovedDomains;
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
DeviceNetworkEvents
| where isnotempty(RemoteUrl) and RemoteUrl has_any (ApprovedDomains)
| extend Account=coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| summarize Events=count(), FirstSeen=min(TimeGenerated), LastSeen=max(TimeGenerated), Domains=make_set(RemoteUrl, 10), Actions=make_set(ActionType, 10) by DeviceName, DeviceId, Account, InitiatingProcessFileName
| extend GovernanceStatus='Approved M365 Copilot', RecommendedAction='Confirm expected business use and retain as the approved usage baseline'
| project LastSeen, GovernanceStatus, RecommendedAction, Account, DeviceName, DeviceId, InitiatingProcessFileName, Events, FirstSeen, Domains, Actions
| top 10000 by LastSeen desc
"@

$ProviderDomainInventory = @"
let RogueDomains = $RogueDomains;
let ApprovedDomains = $ApprovedDomains;
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
DeviceNetworkEvents
| where isnotempty(RemoteUrl) and RemoteUrl has_any (RogueDomains)
| where not(RemoteUrl has_any (ApprovedDomains))
| extend Account=coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| extend NormalizedHost=iff(RemoteUrl has '://', tostring(parse_url(RemoteUrl).Host), RemoteUrl)
| extend NormalizedHost=iff(NormalizedHost contains '/', tostring(split(NormalizedHost, '/')[0]), NormalizedHost)
| extend NormalizedHost=iff(NormalizedHost contains ':', tostring(split(NormalizedHost, ':')[0]), NormalizedHost)
| extend AIService=$AIServiceExpression
| summarize Events=count(), Users=dcountif(Account, isnotempty(Account)), Devices=dcount(DeviceId), FirstSeen=min(TimeGenerated), LastSeen=max(TimeGenerated), Processes=make_set(InitiatingProcessFileName, 10) by AIService, NormalizedHost
| extend RecommendedAction='Validate the provider, users, devices, and business purpose, then restrict unapproved access'
| project LastSeen, RecommendedAction, AIService, NormalizedHost, Users, Devices, Events, FirstSeen, Processes
| top 10000 by LastSeen desc
"@

$AgentToolInventory = @"
let AgentProcesses = dynamic(['claude.exe','claude','cursor.exe','cursor','windsurf.exe','windsurf','aider.exe','aider','openclaw.exe','openclaw','opencode.exe','opencode','codex.exe','codex','cline.exe','continue.exe']);
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
DeviceProcessEvents
| where FileName in~ (AgentProcesses) or ProcessCommandLine has_any (' mcp ','--mcp','mcp.json','modelcontextprotocol','openclaw','opencode','aider','claude-code')
| extend Account=coalesce(AccountUpn, AccountName)
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| extend ToolSignal=case(ProcessCommandLine has_any (' mcp ','--mcp','mcp.json','modelcontextprotocol'), 'MCP invocation', FileName)
| summarize Executions=count(), Users=dcountif(Account, isnotempty(Account)), Devices=dcount(DeviceId), FirstSeen=min(TimeGenerated), LastSeen=max(TimeGenerated), Commands=make_set(ProcessCommandLine, 5) by ToolSignal, FileName
| extend Observation=case(Executions <= 3, 'Rare in selected period', Devices == 1, 'Single device in selected period', 'Established in selected period')
| extend RecommendedAction=case(Observation == 'Rare in selected period', 'Determine whether this is a newly introduced agent or MCP tool and validate ownership', Observation == 'Single device in selected period', 'Validate the device owner, tool source, permissions, and configured servers', 'Review established use for approval and expected scope')
| project LastSeen, Observation, RecommendedAction, ToolSignal, FileName, Users, Devices, Executions, FirstSeen, Commands
| top 10000 by LastSeen desc
"@

$ExposureRankingBase = @"
let CorrelationWindow = 10m;
let RogueDomains = $RogueDomains;
let ApprovedDomains = $ApprovedDomains;
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
let Files = DeviceFileEvents
| where ActionType in ('FileCreated','FileModified','FileCreatedAggregatedReport','FileModifiedAggregatedReport')
| extend Extension=extract(@'\.[^.]+$', 0, tolower(FileName)), Account=coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
| where Extension in ('.csv','.xlsx','.xls','.sql','.pdf','.docx','.env','.json','.yaml','.yml','.py','.ps1','.pem','.key','.pfx','.p12','.dump') or FolderPath has_any ('confidential','sensitive','pii','secret','credential','finance','payroll','ssn','cui','fouo')
| where isnotempty(Account)
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| project FileActivityTime=TimeGenerated, DeviceId, DeviceName, Account;
let Connections = DeviceNetworkEvents
| where isnotempty(RemoteUrl) and RemoteUrl has_any (RogueDomains)
| where not(RemoteUrl has_any (ApprovedDomains))
| extend Account=coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
| where isnotempty(Account)
| project AIConnectionTime=TimeGenerated, DeviceId, Account;
Files
| join kind=inner Connections on DeviceId, Account
| where AIConnectionTime between (FileActivityTime .. FileActivityTime + CorrelationWindow)
"@

$ExposureTopAccounts = @"
$ExposureRankingBase
| summarize Indicators=count() by Account
| top 5 by Indicators desc
| project Account, Indicators
"@

$ExposureTopDevices = @"
$ExposureRankingBase
| summarize Indicators=count() by DeviceName
| top 5 by Indicators desc
| project DeviceName, Indicators
"@

$AutomationTopAccounts = @"
let RogueDomains = $RogueDomains;
let ApprovedDomains = $ApprovedDomains;
let ScriptProcesses = $ScriptProcesses;
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
DeviceNetworkEvents
| where isnotempty(RemoteUrl) and RemoteUrl has_any (RogueDomains)
| where not(RemoteUrl has_any (ApprovedDomains)) and InitiatingProcessFileName in~ (ScriptProcesses)
| extend Account=coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| where isnotempty(Account)
| summarize APICalls=count() by Account
| top 5 by APICalls desc
| project Account, APICalls
"@

$AutomationTopDevices = @"
let RogueDomains = $RogueDomains;
let ApprovedDomains = $ApprovedDomains;
let ScriptProcesses = $ScriptProcesses;
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
DeviceNetworkEvents
| where isnotempty(RemoteUrl) and RemoteUrl has_any (RogueDomains)
| where not(RemoteUrl has_any (ApprovedDomains)) and InitiatingProcessFileName in~ (ScriptProcesses)
| extend Account=coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| summarize APICalls=count() by DeviceName
| top 5 by APICalls desc
| project DeviceName, APICalls
"@

$LocalTopAccounts = @"
let LocalAIProcesses = $LocalAIProcesses;
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
let Files = DeviceFileEvents
| where ActionType in ('FileCreated','FileModified')
| extend LowerName=tolower(FileName), Account=coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
| where LowerName endswith '.gguf' or LowerName endswith '.ggml' or LowerName endswith '.safetensors' or FileName has_any ('ollama','LM Studio','LMStudio','gpt4all','GPT4All','Cursor','Windsurf','Codeium','Tabnine','Msty','AnythingLLM')
| project TimeGenerated, DeviceName, Account;
let Processes = DeviceProcessEvents
| where FileName in~ (LocalAIProcesses)
| extend Account=coalesce(AccountUpn, AccountName)
| project TimeGenerated, DeviceName, Account;
union Files, Processes
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| where isnotempty(Account)
| summarize Events=count() by Account
| top 5 by Events desc
| project Account, Events
"@

$AgentRankingBase = @"
let AgentProcesses = dynamic(['claude.exe','claude','cursor.exe','cursor','windsurf.exe','windsurf','aider.exe','aider','openclaw.exe','openclaw','opencode.exe','opencode','codex.exe','codex','cline.exe','continue.exe']);
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
DeviceProcessEvents
| where FileName in~ (AgentProcesses) or ProcessCommandLine has_any (' mcp ','--mcp','mcp.json','modelcontextprotocol','openclaw','opencode','aider','claude-code')
| extend Account=coalesce(AccountUpn, AccountName)
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| extend ToolSignal=case(ProcessCommandLine has_any (' mcp ','--mcp','mcp.json','modelcontextprotocol'), 'MCP invocation', FileName)
"@

$AgentTopTools = @"
$AgentRankingBase
| summarize Executions=count() by ToolSignal
| top 5 by Executions desc
| project ToolSignal, Executions
"@

$AgentTopAccounts = @"
$AgentRankingBase
| where isnotempty(Account)
| summarize Executions=count() by Account
| top 5 by Executions desc
| project Account, Executions
"@

$AgentTopDevices = @"
$AgentRankingBase
| summarize Executions=count() by DeviceName
| top 5 by Executions desc
| project DeviceName, Executions
"@

$RelatedAlertDevices = @"
let RogueDomains = $RogueDomains;
let ApprovedDomains = $ApprovedDomains;
let LocalAIProcesses = $LocalAIProcesses;
let DeviceFilter = '{DeviceFilter}';
let AIDevices = union
    (DeviceNetworkEvents | where isnotempty(RemoteUrl) and RemoteUrl has_any (RogueDomains) | where not(RemoteUrl has_any (ApprovedDomains)) | project DeviceId),
    (DeviceProcessEvents | where FileName in~ (LocalAIProcesses) | project DeviceId)
| where isnotempty(DeviceId)
| distinct DeviceId;
AlertEvidence
| where EntityType =~ 'Machine' and isnotempty(DeviceId)
| join kind=inner AIDevices on DeviceId
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| summarize Alerts=dcount(AlertId) by DeviceName
| top 5 by Alerts desc
| project DeviceName, Alerts
"@

$AIWebTopServices = @"
let RogueDomains = $RogueDomains;
let ApprovedDomains = $ApprovedDomains;
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
DeviceNetworkEvents
| where isnotempty(RemoteUrl) and (RemoteUrl has_any (RogueDomains) or RemoteUrl has_any (ApprovedDomains))
| extend Account=coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName), AIService=$AIServiceExpression
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| summarize DistinctUsers=dcountif(Account, isnotempty(Account)) by AIService
| where DistinctUsers > 0
| top 5 by DistinctUsers desc
| project AIService, DistinctUsers
"@

$AIWebTopAccounts = @"
let RogueDomains = $RogueDomains;
let ApprovedDomains = $ApprovedDomains;
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
DeviceNetworkEvents
| where isnotempty(RemoteUrl) and (RemoteUrl has_any (RogueDomains) or RemoteUrl has_any (ApprovedDomains))
| extend Account=coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| where isnotempty(Account)
| summarize Events=count() by Account
| top 5 by Events desc
| project Account, Events
"@

$AIWebTopDevices = @"
let RogueDomains = $RogueDomains;
let ApprovedDomains = $ApprovedDomains;
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
DeviceNetworkEvents
| where isnotempty(RemoteUrl) and (RemoteUrl has_any (RogueDomains) or RemoteUrl has_any (ApprovedDomains))
| extend Account=coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| summarize Events=count() by DeviceName
| top 5 by Events desc
| project DeviceName, Events
"@

$AIWebTopProcesses = @"
let RogueDomains = $RogueDomains;
let ApprovedDomains = $ApprovedDomains;
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
DeviceNetworkEvents
| where isnotempty(RemoteUrl) and (RemoteUrl has_any (RogueDomains) or RemoteUrl has_any (ApprovedDomains))
| extend Account=coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| summarize Events=count() by Process=InitiatingProcessFileName
| top 5 by Events desc
| project Process, Events
"@

$AIWebScope = @"
let RogueDomains = $RogueDomains;
let ApprovedDomains = $ApprovedDomains;
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
let Activity = DeviceNetworkEvents
| where isnotempty(RemoteUrl) and (RemoteUrl has_any (RogueDomains) or RemoteUrl has_any (ApprovedDomains))
| extend Account=coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName), AIService=$AIServiceExpression
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter;
union
    (Activity | summarize value=dcount(AIService) | extend label='Observed AI applications', subtitle='Applications seen in endpoint network telemetry'),
    (Activity | where not(RemoteUrl has_any (ApprovedDomains)) | summarize value=dcount(AIService) | extend label='Unauthorized applications', subtitle='Observed applications outside the approved M365 Copilot domains'),
    (Activity | summarize value=count() | extend label='Activity events', subtitle='Network events, not traffic bytes or transactions'),
    (Activity | summarize value=dcountif(Account, isnotempty(Account)) | extend label='Users', subtitle='Distinct observed accounts'),
    (Activity | summarize value=dcount(DeviceId) | extend label='Devices', subtitle='Distinct MDE device identifiers'),
    (Activity | summarize value=dcountif(RemoteIP, isnotempty(RemoteIP)) | extend label='IP addresses', subtitle='Distinct remote IP addresses')
| project label, value, subtitle
"@

$AIWebApplicationInventory = @"
let RogueDomains = $RogueDomains;
let ApprovedDomains = $ApprovedDomains;
let BrowserProcesses = $BrowserProcesses;
let ScriptProcesses = $ScriptProcesses;
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
DeviceNetworkEvents
| where isnotempty(RemoteUrl) and (RemoteUrl has_any (RogueDomains) or RemoteUrl has_any (ApprovedDomains))
| extend Account=coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName), AIService=$AIServiceExpression
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| extend GovernanceStatus=iff(RemoteUrl has_any (ApprovedDomains), 'Approved M365 Copilot', 'Unauthorized AI')
| extend AccessMethod=case(InitiatingProcessFileName in~ (ScriptProcesses), 'Script or API', InitiatingProcessFileName in~ (BrowserProcesses), 'Browser', 'Desktop or other application')
| extend NormalizedHost=iff(RemoteUrl has '://', tostring(parse_url(RemoteUrl).Host), RemoteUrl)
| extend NormalizedHost=iff(NormalizedHost contains '/', tostring(split(NormalizedHost, '/')[0]), NormalizedHost)
| extend NormalizedHost=iff(NormalizedHost contains ':', tostring(split(NormalizedHost, ':')[0]), NormalizedHost)
| summarize ActivityEvents=count(), Users=dcountif(Account, isnotempty(Account)), IPAddresses=dcountif(RemoteIP, isnotempty(RemoteIP)), Devices=dcount(DeviceId), FirstSeen=min(TimeGenerated), LastSeen=max(TimeGenerated), Domains=make_set(NormalizedHost, 25), Processes=make_set(InitiatingProcessFileName, 15), AccessMethods=make_set(AccessMethod, 5) by GovernanceStatus, AIService
| extend PolicyPriority=case(GovernanceStatus == 'Approved M365 Copilot', 'Baseline', AccessMethods has 'Script or API', 'High', Users >= 10 or Devices >= 10, 'High', Users >= 3 or Devices >= 3, 'Medium', 'Review')
| extend RecommendedAction=case(GovernanceStatus == 'Approved M365 Copilot', 'Retain as the approved application baseline', PolicyPriority == 'High', 'Identify owners and data scope, review credentials or automation, and restrict unauthorized access', 'Validate business purpose, ownership, and application approval status')
| project LastSeen, PolicyPriority, GovernanceStatus, RecommendedAction, AIService, ActivityEvents, Users, IPAddresses, Devices, FirstSeen, AccessMethods, Processes, Domains
| top 10000 by LastSeen desc
"@

$OverviewApplicationSummary = @"
let RogueDomains = $RogueDomains;
let ApprovedDomains = $ApprovedDomains;
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
DeviceNetworkEvents
| where isnotempty(RemoteUrl) and (RemoteUrl has_any (RogueDomains) or RemoteUrl has_any (ApprovedDomains))
| extend Account=coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName), AIService=$AIServiceExpression
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| summarize ActivityEvents=count(), Users=dcountif(Account, isnotempty(Account)), IPAddresses=dcountif(RemoteIP, isnotempty(RemoteIP)), Devices=dcount(DeviceId) by AIService
| where Users > 0
| top 100 by Users desc
| project AIService, Users, Devices, ActivityEvents, IPAddresses
| top 10000 by Users desc
"@

$AIWebAccessDetail = @"
let RogueDomains = $RogueDomains;
let ApprovedDomains = $ApprovedDomains;
let BrowserProcesses = $BrowserProcesses;
let ScriptProcesses = $ScriptProcesses;
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
DeviceNetworkEvents
| where isnotempty(RemoteUrl) and (RemoteUrl has_any (RogueDomains) or RemoteUrl has_any (ApprovedDomains))
| extend Account=coalesce(InitiatingProcessAccountUpn, InitiatingProcessAccountName)
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| extend AIService=$AIServiceExpression
| extend GovernanceStatus=iff(RemoteUrl has_any (ApprovedDomains), 'Approved M365 Copilot', 'Unauthorized AI')
| extend AccessMethod=case(InitiatingProcessFileName in~ (ScriptProcesses), 'Script or API', InitiatingProcessFileName in~ (BrowserProcesses), 'Browser', 'Desktop or other application')
| extend NormalizedHost=iff(RemoteUrl has '://', tostring(parse_url(RemoteUrl).Host), RemoteUrl)
| extend NormalizedHost=iff(NormalizedHost contains '/', tostring(split(NormalizedHost, '/')[0]), NormalizedHost)
| extend NormalizedHost=iff(NormalizedHost contains ':', tostring(split(NormalizedHost, ':')[0]), NormalizedHost)
| summarize Events=count(), FirstSeen=min(TimeGenerated), LastSeen=max(TimeGenerated), RemoteIPs=make_set(RemoteIP, 25), Actions=make_set(ActionType, 10) by GovernanceStatus, AIService, NormalizedHost, AccessMethod, Account, DeviceName, DeviceId, Process=InitiatingProcessFileName
| extend RecommendedAction=case(GovernanceStatus == 'Approved M365 Copilot', 'Retain as approved usage baseline', AccessMethod == 'Script or API', 'Identify script owner and credentials, validate data scope, and stop unauthorized automation', 'Validate business purpose and restrict or remove unauthorized AI access')
| project LastSeen, GovernanceStatus, RecommendedAction, AIService, NormalizedHost, AccessMethod, Account, DeviceName, DeviceId, Process, Events, FirstSeen, RemoteIPs, Actions
| top 10000 by LastSeen desc
"@

$AICloudInteractionDetail = @"
let RogueDomains = $RogueDomains;
let ApprovedDomains = $ApprovedDomains;
let DeviceFilter = '{DeviceFilter}';
let AccountFilter = '{AccountFilter}';
CloudAppEvents
| extend Raw=todynamic(RawEventData)
| extend TargetDomain=tostring(Raw.TargetDomain), TargetUrl=tostring(Raw.TargetUrl), DeviceName=tostring(Raw.DeviceName), DeviceId=tostring(Raw.MDATPDeviceId), RawAccount=tostring(Raw.UserId), Process=tostring(Raw.Application), AppIdentity=tostring(Raw.AppIdentity)
| extend Account=coalesce(RawAccount, AccountId)
| where ActionType in~ ('AIAppInteraction','CopilotInteraction') or TargetDomain has_any (RogueDomains) or TargetDomain has_any (ApprovedDomains)
| where DeviceFilter == '' or DeviceName contains DeviceFilter
| where AccountFilter == '' or Account contains AccountFilter
| extend GovernanceStatus=case(ActionType =~ 'CopilotInteraction' or AppIdentity has 'M365Copilot' or TargetDomain has_any (ApprovedDomains), 'Approved M365 Copilot', 'Unauthorized AI')
| extend EvidenceType=case(ActionType =~ 'PastedToBrowser', 'Content pasted to browser', ActionType =~ 'AIAppInteraction', 'AI application interaction', ActionType =~ 'CopilotInteraction', 'M365 Copilot interaction', ActionType)
| extend PolicyName=tostring(Raw.PolicyMatchInfo.PolicyName), RuleName=tostring(Raw.PolicyMatchInfo.RuleName), SensitiveInfoTypes=array_length(Raw.SensitiveInfoTypeData)
| extend RecommendedAction=case(GovernanceStatus == 'Approved M365 Copilot', 'Retain as approved audit evidence and review accessed resources when present', ActionType =~ 'PastedToBrowser', 'Review the user and device timeline, target site, policy result, and nearby file activity', 'Validate the application, user, device, and business purpose')
| project TimeGenerated, GovernanceStatus, EvidenceType, RecommendedAction, Account, AccountDisplayName, DeviceName, DeviceId, Process, TargetDomain, TargetUrl, Application, AppIdentity, PolicyName, RuleName, SensitiveInfoTypes
| top 10000 by TimeGenerated desc
"@

$Parameters = [ordered]@{
    type = 9
    content = [ordered]@{
        version = 'KqlParameterItem/1.0'
        parameters = @(
            [ordered]@{
                id = 'time-range'
                version = 'KqlParameterItem/1.0'
                name = 'TimeRange'
                label = 'Time Range'
                type = 4
                isRequired = $true
                isGlobal = $true
                typeSettings = [ordered]@{
                    selectableValues = @(
                        [ordered]@{ durationMs = 3600000 },
                        [ordered]@{ durationMs = 86400000 },
                        [ordered]@{ durationMs = 604800000 },
                        [ordered]@{ durationMs = 2592000000 },
                        [ordered]@{ durationMs = 7776000000 }
                    )
                    allowCustom = $true
                }
                value = [ordered]@{ durationMs = 604800000 }
            },
            [ordered]@{ id='device-filter'; version='KqlParameterItem/1.0'; name='DeviceFilter'; label='Device Name (MDE DeviceName)'; type=1; isRequired=$false; isGlobal=$true; value='' },
            [ordered]@{ id='account-filter'; version='KqlParameterItem/1.0'; name='AccountFilter'; label='Account (UPN or AccountName)'; type=1; isRequired=$false; isGlobal=$true; value='' },
            [ordered]@{ id='tab-selector'; version='KqlParameterItem/1.0'; name='Tab'; type=1; isRequired=$false; isHiddenWhenLocked=$true; value='Overview' }
        )
        style = 'pills'
        queryType = 0
        resourceType = 'microsoft.operationalinsights/workspaces'
    }
    name = 'global-parameters'
}

$TabDefinitions = @(
    [ordered]@{ Label='AI Activity Overview'; Value='Overview' },
    [ordered]@{ Label='Unauthorized AI'; Value='Unauthorized' },
    [ordered]@{ Label='Sensitive File and AI Correlation'; Value='Exposure' },
    [ordered]@{ Label='Automation and API'; Value='Automation' },
    [ordered]@{ Label='Local AI'; Value='LocalAI' },
    [ordered]@{ Label='Agents and MCP'; Value='AgentsMCP' },
    [ordered]@{ Label='AI Findings and Device Alerts'; Value='Investigation' },
    [ordered]@{ Label='AI Application Discovery'; Value='WebTracking' }
)

$TabNavigation = [ordered]@{
    type = 11
    content = [ordered]@{
        version = 'LinkItem/1.0'
        style = 'tabs'
        links = @($TabDefinitions | ForEach-Object {
            [ordered]@{ id="tab-$($_.Value.ToLower())"; cellValue='Tab'; linkTarget='parameter'; linkLabel=$_.Label; subTarget=$_.Value; style='link' }
        })
    }
    name = 'tab-navigation'
}

$Groups = @(
    (New-Group -Name 'group-overview' -TabValue 'Overview' -Items @(
        (New-TextItem -Name 'overview-header' -Text "## AI Activity Overview | Broadest view of AI activity for the period. The results grid is a service level rollup, one row per AI service. For approval posture use the Primary AI Application Governance Inventory on AI Application Discovery, and for row level user, device, host, and process detail use AI Application Users, Devices, Domains on the same tab." -Style 'info'),
        (New-QueryItem -Name 'overview-top-applications' -Title 'Top 5 AI Applications by Distinct Users' -Query $AIWebTopServices -Visualization 'barchart' -Width '55' -Size 2),
        (New-QueryItem -Name 'overview-application-summary' -Title 'Top 100 AI Application Results: Users, Devices, Events, and IP Addresses' -Query $OverviewApplicationSummary -Grid -Width '45' -Size 2),
        (New-QueryItem -Name 'overview-trend' -Title 'Daily Unauthorized AI Events Compared with Approved M365 Copilot Events' -Query $OverviewTrend -Visualization 'areachart' -Width '65' -Height '60' -ChartSettings ([ordered]@{ seriesLabelSettings = @([ordered]@{ seriesName = 'Unauthorized AI'; color = 'redBright' }, [ordered]@{ seriesName = 'Approved M365 Copilot'; color = 'greenBright' }) })),
        (New-QueryItem -Name 'overview-methods' -Title 'Unauthorized AI Events by Access Method' -Query $UnauthorizedMethods -Visualization 'barchart' -Width '35' -Height '60')
    )),
    (New-Group -Name 'group-unauthorized' -TabValue 'Unauthorized' -Items @(
        (New-TextItem -Name 'unauthorized-header' -Text "## Unauthorized AI Access | Direct endpoint connections to nonapproved AI services. Rankings count network events. The records below identify the account, device, service, domain, process, and response action. The governance inventory on this tab lists nonapproved providers only. Approved M365 Copilot posture lives on AI Application Discovery." -Style 'info'),
        (New-QueryItem -Name 'unauthorized-top-users' -Title 'Top 5 Accounts by Unauthorized AI Network Events' -Query $TopUsers -Visualization 'barchart' -Width '34' -Height '55'),
        (New-QueryItem -Name 'unauthorized-devices' -Title 'Top 5 Devices by Unauthorized AI Network Events' -Query $UnauthorizedDevices -Visualization 'barchart' -Width '33' -Height '55'),
        (New-QueryItem -Name 'unauthorized-services' -Title 'Top 5 Nonapproved AI Services by Network Events' -Query $OverviewServices -Visualization 'barchart' -Width '33' -Height '55'),
        (New-QueryItem -Name 'unauthorized-detail' -Title 'Unauthorized AI Access Records by Account, Device, Service, and Process' -Query $UnauthorizedDetail -Grid -Width '100' -Height '110'),
        (New-QueryItem -Name 'provider-domain-inventory' -Title 'Nonapproved Provider and Domain Governance Inventory' -Query $ProviderDomainInventory -Grid -Width '100' -Height '90')
    )),
    (New-Group -Name 'group-exposure' -TabValue 'Exposure' -Items @(
        (New-TextItem -Name 'exposure-header' -Text "## Sensitive File and AI Correlation | File creation or modification followed by unauthorized AI access from the same account and device within 10 minutes. This is a review lead, not proof of file upload." -Style 'info'),
        (New-QueryItem -Name 'exposure-risk-summary' -Title 'Correlated Sensitive File Indicators by Risk Level' -Query $ExposureRiskSummary -Visualization 'barchart' -Width '25' -Height '55'),
        (New-QueryItem -Name 'exposure-summary' -Title 'Top 5 AI Services after Sensitive File Activity' -Query $ExposureSummary -Visualization 'barchart' -Width '25' -Height '55'),
        (New-QueryItem -Name 'exposure-top-accounts' -Title 'Top 5 Accounts with File to AI Correlations' -Query $ExposureTopAccounts -Visualization 'barchart' -Width '25' -Height '55'),
        (New-QueryItem -Name 'exposure-top-devices' -Title 'Top 5 Devices with File to AI Correlations' -Query $ExposureTopDevices -Visualization 'barchart' -Width '25' -Height '55'),
        (New-QueryItem -Name 'exposure-detail' -Title 'Sensitive File and Subsequent AI Access Evidence' -Query $ExposureIndicators -Grid -Width '100' -Height '115')
    )),
    (New-Group -Name 'group-automation' -TabValue 'Automation' -Items @(
        (New-TextItem -Name 'automation-header' -Text "## Scripted AI and API Access | Unauthorized AI connections initiated by command shells, scripting runtimes, command line clients, or developer tools. Review the owner, command context, credentials, and data scope." -Style 'info'),
        (New-QueryItem -Name 'automation-processes' -Title 'Top 5 Script and Command Processes Calling AI Services' -Query $AutomationProcesses -Visualization 'barchart' -Width '34' -Height '55'),
        (New-QueryItem -Name 'automation-top-accounts' -Title 'Top 5 Accounts Running Scripted AI Access' -Query $AutomationTopAccounts -Visualization 'barchart' -Width '33' -Height '55'),
        (New-QueryItem -Name 'automation-top-devices' -Title 'Top 5 Devices Running Scripted AI Access' -Query $AutomationTopDevices -Visualization 'barchart' -Width '33' -Height '55'),
        (New-QueryItem -Name 'automation-detail' -Title 'Script Owner, Process, AI Service, Command Context, and Response' -Query $AutomationDetail -Grid -Width '100' -Height '115')
    )),
    (New-Group -Name 'group-local-ai' -TabValue 'LocalAI' -Items @(
        (New-TextItem -Name 'local-header' -Text "## Local AI Software and Models | Endpoint evidence for local AI executables, installers, packages, and model files. This tab does not count browser access to hosted AI services." -Style 'info'),
        (New-QueryItem -Name 'local-summary' -Title 'Local AI Evidence by Execution, Installer, or Model File' -Query $LocalSummary -Visualization 'piechart' -Width '34' -Height '55' -Size 2),
        (New-QueryItem -Name 'local-devices' -Title 'Top 5 Devices with Local AI Artifacts or Execution' -Query $LocalDevices -Visualization 'barchart' -Width '33' -Height '55' -Size 2),
        (New-QueryItem -Name 'local-top-accounts' -Title 'Top 5 Accounts Creating or Running Local AI' -Query $LocalTopAccounts -Visualization 'barchart' -Width '33' -Height '55' -Size 2),
        (New-QueryItem -Name 'local-detail' -Title 'Local AI Tool, Model, Installer, Owner, and Response Evidence' -Query $LocalEvidence -Grid -Width '100' -Height '115')
    )),
    (New-Group -Name 'group-agents-mcp' -TabValue 'AgentsMCP' -Items @(
        (New-TextItem -Name 'agents-header' -Text "## Agent and MCP Execution | Process commands and configuration evidence for coding agents, autonomous tools, and Model Context Protocol use. Review ownership, tool permissions, credentials, instructions, and configured servers." -Style 'info'),
        (New-QueryItem -Name 'agent-top-tools' -Title 'Top 5 Detected Agent Tools and MCP Invocations' -Query $AgentTopTools -Visualization 'barchart' -Width '34' -Height '55'),
        (New-QueryItem -Name 'agent-top-accounts' -Title 'Top 5 Accounts Running Agents or MCP Commands' -Query $AgentTopAccounts -Visualization 'barchart' -Width '33' -Height '55'),
        (New-QueryItem -Name 'agent-top-devices' -Title 'Top 5 Devices Running Agents or MCP Commands' -Query $AgentTopDevices -Visualization 'barchart' -Width '33' -Height '55'),
        (New-QueryItem -Name 'agent-tool-inventory' -Title 'Agent Tool Ownership, First Seen, Last Seen, and Commands' -Query $AgentToolInventory -Grid -Width '100' -Height '90'),
        (New-QueryItem -Name 'agent-processes' -Title 'Agent Executable and MCP Command Evidence' -Query $AgentProcesses -Grid -Width '50' -Height '105'),
        (New-QueryItem -Name 'agent-context-files' -Title 'Agent Instructions, MCP Configuration, and Command Evidence' -Query $ContextFiles -Grid -Width '50' -Height '105')
    )),
    (New-Group -Name 'group-investigation' -TabValue 'Investigation' -Items @(
        (New-TextItem -Name 'investigation-header' -Text "## AI Findings and Existing Device Alerts | The alerts here are existing Microsoft Defender alerts on devices that also have AI evidence. They are not AI alerts, and this workbook does not claim AI caused them. Use the timeline and association statement to decide whether they are related." -Style 'info'),
        (New-QueryItem -Name 'priority-queue' -Title 'Prioritized AI Findings Requiring Analyst Review' -Query $PriorityQueue -Grid -Width '100' -Height '110'),
        (New-QueryItem -Name 'related-alert-summary' -Title 'Existing Defender Alerts by Severity on Devices with AI Evidence' -Query $RelatedAlertSummary -Visualization 'barchart' -Width '50' -Height '55'),
        (New-QueryItem -Name 'related-alert-devices' -Title 'Top 5 AI Evidence Devices by Existing Defender Alert Count' -Query $RelatedAlertDevices -Visualization 'barchart' -Width '50' -Height '55'),
        (New-QueryItem -Name 'related-alerts' -Title 'Existing Defender Alerts on AI Evidence Devices, Correlation Only' -Query $RelatedAlerts -Grid -Width '100' -Height '105')
    )),
    (New-Group -Name 'group-web-tracking' -TabValue 'WebTracking' -Items @(
        (New-TextItem -Name 'web-tracking-header' -Text "## AI Application Discovery | Application inventory modeled on the tenant discovery views. M365 Copilot is the only approved AI service. The Primary AI Application Governance Inventory is the approval and posture view, one row per service and governance status with a policy priority. AI Application Users, Devices, Domains is the row level view, one row per user, device, host, and process. Cloud Discovery traffic, upload, transaction, and catalog metrics exist in the Defender portal but are not exposed by the current Log Analytics tables. Browser paste evidence does not prove upload." -Style 'info'),
        (New-QueryItem -Name 'web-application-inventory' -Title 'Primary AI Application Governance Inventory: Approval, Activity, Users, IP Addresses, Devices, and Action' -Query $AIWebApplicationInventory -Grid -Width '100'),
        (New-QueryItem -Name 'web-top-accounts' -Title 'Top 5 Accounts across Approved and Nonapproved AI Events' -Query $AIWebTopAccounts -Visualization 'barchart' -Width '34' -Height '55'),
        (New-QueryItem -Name 'web-top-devices' -Title 'Top 5 Devices across Approved and Nonapproved AI Events' -Query $AIWebTopDevices -Visualization 'barchart' -Width '33' -Height '55'),
        (New-QueryItem -Name 'web-top-processes' -Title 'Top 5 Browsers, Scripts, and Applications Reaching AI Services' -Query $AIWebTopProcesses -Visualization 'barchart' -Width '33' -Height '55'),
        (New-QueryItem -Name 'web-access-detail' -Title 'AI Application Users, Devices, Domains, IP Addresses, Processes, and Approval Status' -Query $AIWebAccessDetail -Grid -Width '100' -Height '110'),
        (New-QueryItem -Name 'web-cloud-interactions' -Title 'Corroborating Browser Paste and M365 Copilot Audit Evidence' -Query $AICloudInteractionDetail -Grid -Width '100' -Height '90')
    ))
)

$Workbook = [ordered]@{
    version = 'Notebook/1.0'
    items = @(
        (New-TextItem -Name 'workbook-header' -Text "# AI Activity and Exposure Investigation Workbook`n`nPrioritized evidence and response actions across MDE onboarded Windows, macOS, and Linux devices. AI apps ranked by users, with devices, endpoint events, and remote IPs. M365 Copilot approved. Domains from the MIT licensed v2fly community list: https://github.com/v2fly/domain-list-community" -Style 'info'),
        $Parameters,
        $TabNavigation
    ) + $Groups
    styleSettings = [ordered]@{ showBorder = $true }
    '$schema' = 'https://github.com/Microsoft/Application-Insights-Workbooks/blob/master/schema/workbook.json'
}

$Json = $Workbook | ConvertTo-Json -Depth 100
[System.IO.File]::WriteAllText($OutputPath, $Json, [System.Text.UTF8Encoding]::new($false))
Write-Output $OutputPath

# Regenerate the ARM deployment template so azuredeploy.json always embeds the current workbook.
$ArmTemplate = [ordered]@{
    '$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
    contentVersion = '1.0.0.0'
    parameters = [ordered]@{
        workspaceName = [ordered]@{ type = 'string'; defaultValue = 'SOC-Central'; metadata = [ordered]@{ description = 'Log Analytics workspace name' } }
        workbookDisplayName = [ordered]@{ type = 'string'; defaultValue = 'AI Activity and Exposure Investigation Workbook'; metadata = [ordered]@{ description = 'Workbook display name' } }
        workbookId = [ordered]@{ type = 'string'; defaultValue = '[newGuid()]'; metadata = [ordered]@{ description = 'Workbook resource ID. Must be a GUID. Leave the default to create a new workbook instance.' } }
    }
    variables = [ordered]@{}
    resources = @(
        [ordered]@{
            type = 'Microsoft.Insights/workbooks'
            apiVersion = '2023-06-01'
            name = "[parameters('workbookId')]"
            location = '[resourceGroup().location]'
            kind = 'shared'
            properties = [ordered]@{
                displayName = "[parameters('workbookDisplayName')]"
                sourceId = "[concat('/subscriptions/', subscription().subscriptionId, '/resourceGroups/', resourceGroup().name, '/providers/Microsoft.OperationalInsights/workspaces/', parameters('workspaceName'))]"
                category = 'sentinel'
                serializedData = $Json
            }
        }
    )
    outputs = [ordered]@{
        workbookResourceId = [ordered]@{ type = 'string'; value = "[resourceId('Microsoft.Insights/workbooks', parameters('workbookId'))]" }
    }
}
$ArmPath = Join-Path (Split-Path $OutputPath -Parent) 'azuredeploy.json'
$ArmJson = $ArmTemplate | ConvertTo-Json -Depth 100
[System.IO.File]::WriteAllText($ArmPath, $ArmJson, [System.Text.UTF8Encoding]::new($false))
Write-Output $ArmPath