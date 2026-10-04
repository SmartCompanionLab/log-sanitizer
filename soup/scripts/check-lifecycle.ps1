# ==========================================
# SOUP Dependency Lifecycle Report
# ==========================================

$dependencyFile = "target/runtime-dependencies.txt"
$mappingFile    = "soup/config/lifecycle-mapping.csv"
$reportFile     = "target/soup-lifecycle-report.csv"

# ------------------------------------------
# Validate mapping
# ------------------------------------------

if (-not (Test-Path $mappingFile)) {
    Write-Error "Mapping file not found: $mappingFile"
    exit 1
}

# ------------------------------------------
# Create target directory
# ------------------------------------------

if (-not (Test-Path "target")) {
    New-Item -ItemType Directory "target" | Out-Null
}

# ------------------------------------------
# Generate Maven runtime dependency tree
# ------------------------------------------

Write-Host "Generating Maven runtime dependency tree..."

# Only scope is runtime, as we want to check the dependencies that are actually used at runtime, not those that are only needed for testing or compilation.
mvn dependency:tree `
    "-Dscope=runtime" `
    "-DoutputFile=$dependencyFile"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Maven dependency tree generation failed."
    exit 1
}

Write-Host "Dependency tree generated: $dependencyFile"
Write-Host ""

# ------------------------------------------
# Load lifecycle mapping
# ------------------------------------------

$mapping = Import-Csv $mappingFile
$today = Get-Date
$results = @()

# ------------------------------------------
# Parse Maven dependencies
# ------------------------------------------

$dependencies = Get-Content $dependencyFile |
    ForEach-Object {

        if ($_ -match '([a-zA-Z0-9_.-]+):([a-zA-Z0-9_.-]+):jar:([^:]+):') {

            [PSCustomObject]@{
                GroupId    = $matches[1]
                ArtifactId = $matches[2]
                Version    = $matches[3]
            }
        }
    } |
    Sort-Object GroupId, ArtifactId, Version -Unique

# ------------------------------------------
# Check each dependency
# ------------------------------------------

foreach ($dependency in $dependencies) {

    $component = "$($dependency.GroupId):$($dependency.ArtifactId)"
    $version   = $dependency.Version

    Write-Host "Checking $component $version ..."

    $product     = ""
    $releaseDate = ""
    $latest      = ""
    $support     = ""
    $eol         = ""
    $status      = "REVIEW"
    $reason      = ""

    # --------------------------------------
    # Find lifecycle mapping
    # --------------------------------------

    $map = $mapping | Where-Object {

        (
            $_.groupId -eq $dependency.GroupId -and
            $_.artifactId -eq $dependency.ArtifactId
        ) -or
        (
            $_.groupId.EndsWith(".*") -and
            $dependency.GroupId -like $_.groupId.Replace(".*", "*") -and
            (
                $_.artifactId -eq "*" -or
                $_.artifactId -eq $dependency.ArtifactId
            )
        )

    } | Select-Object -First 1

    if (-not $map) {

        $reason = "No lifecycle mapping"

    }
    else {

        $product = $map.lifecycleProduct

        if ([string]::IsNullOrWhiteSpace($product)) {

            $reason = "Lifecycle product not mapped"

        }
        else {

            # ----------------------------------
            # Query lifecycle API
            # ----------------------------------

            try {

                $data = Invoke-RestMethod `
                    "https://endoflife.date/api/$product.json" `
                    -ErrorAction Stop

                # Maven version -> lifecycle cycle
                $cycle = ($version -split '\.')[0]

                $record = $data |
                    Where-Object {
                        "$($_.cycle)" -eq "$cycle"
                    } |
                    Select-Object -First 1

                if (-not $record) {

                    $reason = "Lifecycle cycle not found"

                }
                else {

                    $releaseDate = $record.releaseDate
                    $latest      = $record.latest
                    $support     = $record.support
                    $eol         = $record.eol

                    # ----------------------------------
                    # Evaluate lifecycle
                    # ----------------------------------

                    if (
                        $record.eol -ne $false -and
                        $record.eol -and
                        $today -gt [datetime]$record.eol
                    ) {

                        $status = "FAIL"
                        $reason = "EOL reached"

                    }
                    elseif (
                        $record.support -and
                        $today -gt [datetime]$record.support
                    ) {

                        $status = "REVIEW"
                        $reason = "Standard support ended"

                    }
                    elseif ($record.eol -eq $false) {

                        $status = "PASS"
                        $reason = "No EOL date"

                    }
                    else {

                        $status = "PASS"
                        $reason = "Standard support active"
                    }
                }
            }
            catch {

                $reason = "Lifecycle API/product unavailable"
            }
        }
    }

    $results += [PSCustomObject]@{
        Component  = $component
        Version    = $version
        Product    = $product
        Release    = $releaseDate
        Latest     = $latest
        Support    = $support
        EOL        = $eol
        Status     = $status
        Reason     = $reason
    }
}

# ------------------------------------------
# Display report
# ------------------------------------------

Write-Host ""
Write-Host "========== SOUP LIFECYCLE REPORT =========="
Write-Host ""

$results | Format-Table -AutoSize

# ------------------------------------------
# Export CSV
# ------------------------------------------

$results | Export-Csv $reportFile -NoTypeInformation

Write-Host ""
Write-Host "Report generated: $reportFile"

# ------------------------------------------
# Release Gate
# ------------------------------------------

$failCount = @($results | Where-Object { $_.Status -eq "FAIL" }).Count

$reviewCount = @($results | Where-Object { $_.Status -eq "REVIEW" }).Count

Write-Host ""
Write-Host "Release Gate Summary:"
Write-Host "FAIL   : $failCount"
Write-Host "REVIEW : $reviewCount"

if ($failCount -gt 0) {
    Write-Error "SOUP lifecycle gate FAILED - EOL dependency detected."
    exit 1
}

Write-Host "SOUP lifecycle gate PASSED."
exit 0