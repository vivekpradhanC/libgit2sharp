<#
.SYNOPSIS
    TBD
.PARAMETER commitSha
    TBD
#>

Param(
    [Parameter(Mandatory=$true)]
    [string]$commitSha
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Run-Command([scriptblock]$Command) {
    $output = ""

    $exitCode = 0
    $global:lastexitcode = 0

    & $Command

    if ($LastExitCode -ne 0) {
        $exitCode = $LastExitCode
    } elseif (!$?) {
        $exitCode = 1
    } else {
        return
    }

    $error = "``$Command`` failed"

    if ($output) {
        Write-Host -ForegroundColor "Red" $output
        $error += ". See output above."
    }

    Throw $error
}

function Clean-OutputFolder($folder) {

    If (Test-Path $folder) {
        Write-Host -ForegroundColor "Green" "Dropping `"$folder`" folder..."

        Run-Command { & Remove-Item -Recurse -Force "$folder" }

        Write-Host "Done."
    }
}

#################


$root = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
$projectPath = Join-Path $root "..\LibGit2Sharp"

Remove-Item (Join-Path $projectPath "*.nupkg")

Clean-OutputFolder (Join-Path $projectPath "bin\")
Clean-OutputFolder (Join-Path $projectPath "obj\")
Clean-OutputFolder (Join-Path $projectPath "..\Build\")

# The nuspec file needs to be next to the csproj, so copy it there during the pack operation
Copy-Item (Join-Path $root "LibGit2Sharp.nuspec") $projectPath

Push-Location $projectPath

try {
  $FrameworkVersion = "v4.0.30319"
  $FrameworkDir = "$($env:SystemRoot)\Microsoft.NET\Framework"

  If (Test-Path "$($env:SystemRoot)\Microsoft.NET\Framework64") {
    $FrameworkDir = "$($env:SystemRoot)\Microsoft.NET\Framework64"
  }

  Run-Command { & "$(Join-Path $projectPath "..\Lib\NuGet\Nuget.exe")" Restore "$(Join-Path $projectPath "..\LibGit2Sharp.sln")" }
  Run-Command { & "$($FrameworkDir)\$($FrameworkVersion)\msbuild.exe" "$projectPath\..\CI\build.msbuild" /property:CommitSha=$commitSha /target:Build }
  Run-Command { & "$(Join-Path $projectPath "..\Lib\NuGet\Nuget.exe")"  Pack -Symbols "$(Join-Path $projectPath "LibGit2Sharp.csproj")" -Prop Configuration=Release }

}
finally {
  Pop-Location
  Remove-Item (Join-Path $projectPath "LibGit2Sharp.nuspec")
}
