# Phase 10: creates the Knowledge article "How an order moves through Keyburn" (record type
# Policy_FAQ) with docfiles/order_workflow_diagram.png attached as a File, embeds that File in the
# body, and publishes it. OCC_ExplainOrderWorkflow finds the diagram through this article's File
# link at question time, so the File link is what matters; the embedded <img> is for human readers.
#
# The body text deliberately does NOT state what the diagram shows (draft expiry, when an order can
# be cancelled): those facts must come from the image, not from text retrieval.
#
# Run from sfdx-project/:  powershell -File scripts\create_order_workflow_article.ps1
# Not re-runnable over a published article: to change the diagram, edit the article as a draft in
# the UI and upload a new version of the File instead.

param([string]$TargetOrg = 'devorg')
$ErrorActionPreference = 'Stop'

$UrlName = 'how-an-order-moves-through-keyburn'
$png = Join-Path $PSScriptRoot '..\..\docfiles\order_workflow_diagram.png'
if (-not (Test-Path $png)) { throw "Diagram not found: $png - run docfiles\make_order_workflow_diagram.ps1 first." }

# sf api request rest handles auth and token refresh; the token from `sf org display` gave a 401.
# Bodies go through stdin (--body -): a file path passed to --body is sent as literal text.
$base = '/services/data/v67.0'
function Query([string]$soql) { (sf api request rest "$base/query?q=$([uri]::EscapeDataString($soql))" --target-org $TargetOrg | ConvertFrom-Json).records }
function Send([string]$method, [string]$path, $obj) {
    $out = ($obj | ConvertTo-Json -Compress) | sf api request rest "$base$path" --method $method --body - --target-org $TargetOrg | Out-String
    if ($LASTEXITCODE -ne 0) { throw "$method $path failed: $out" }
    if ($out.Trim()) { $out | ConvertFrom-Json }
}
function Post([string]$path, $obj) { Send 'POST' $path $obj }
function Patch([string]$path, $obj) { Send 'PATCH' $path $obj | Out-Null }

$existing = Query "SELECT Id, PublishStatus FROM Knowledge__kav WHERE UrlName = '$UrlName' AND Language = 'en_US'"
if ($existing) { Write-Output "Article already exists ($($existing[0].Id), $($existing[0].PublishStatus)) - nothing to do."; return }

$rt = (Query "SELECT Id FROM RecordType WHERE SobjectType = 'Knowledge__kav' AND DeveloperName = 'Policy_FAQ'")[0].Id

$kav = Post '/sobjects/Knowledge__kav' @{
    Title        = 'How an order moves through Keyburn'
    UrlName      = $UrlName
    Summary      = 'The stages a Keyburn order goes through, from Draft to Delivered, shown as a diagram.'
    RecordTypeId = $rt
    Language     = 'en_US'
}
Write-Output "Draft article: $($kav.id)"

# FirstPublishLocationId links the File to the article version in the same insert.
$cv = Post '/sobjects/ContentVersion' @{
    Title                  = 'Keyburn order workflow diagram'
    PathOnClient           = 'order_workflow_diagram.png'
    VersionData            = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path $png)))
    FirstPublishLocationId = $kav.id
}
Write-Output "File version: $($cv.id)"

$body = '<p>The diagram below shows each stage a Keyburn order passes through, from Draft to Delivered. ' +
        'Ask our assistant to explain any step.</p>' +
        "<p><img src=`"/sfc/servlet.shepherd/version/download/$($cv.id)`" alt=`"Keyburn order workflow diagram`"></img></p>"
Patch "/sobjects/Knowledge__kav/$($kav.id)" @{ Article_Body__c = $body }

# The agent user can read the article but does NOT inherit access to its File through the article
# link (UserRecordAccess: HasReadAccess=false on the ContentDocument), and the prompt template then
# fails to resolve the image ("[Provide:{LATEST PUBLISHED VERSION ID}]"). Share this one File
# read-only (Viewer) with the agent running user - targeted, no OWD change.
$agentUser = (Query "SELECT Id FROM User WHERE Username = '__AGENT_USERNAME__'")[0].Id
$docId = (Query "SELECT ContentDocumentId FROM ContentVersion WHERE Id = '$($cv.id)'")[0].ContentDocumentId
Post '/sobjects/ContentDocumentLink' @{ ContentDocumentId = $docId; LinkedEntityId = $agentUser; ShareType = 'V' } | Out-Null
Write-Output "File $docId shared read-only with the agent user"

$ka = (Query "SELECT KnowledgeArticleId FROM Knowledge__kav WHERE Id = '$($kav.id)'")[0].KnowledgeArticleId
$apex = "KbManagement.PublishingService.publishArticle('$ka', true);"
$tmp = Join-Path $env:TEMP 'publish_order_workflow.apex'
[IO.File]::WriteAllText($tmp, $apex, (New-Object Text.UTF8Encoding($false)))
sf apex run --file $tmp --target-org $TargetOrg | Out-Null
Remove-Item $tmp

$final = Query "SELECT Id, PublishStatus FROM Knowledge__kav WHERE UrlName = '$UrlName' AND Language = 'en_US'"
Write-Output "Published: $($final[0].Id) ($($final[0].PublishStatus)). Wait for Data Library re-indexing before testing."
