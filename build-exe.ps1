$ErrorActionPreference = "Stop"

$Root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$ScriptPath = Join-Path $Root "Install-NVCPL.ps1"
$DllPath = Join-Path $Root "nvcpluir.dll"
$OutputPath = Join-Path $Root "Install-NVCPL.exe"

if (-not (Test-Path $ScriptPath)) { throw "Install-NVCPL.ps1 was not found." }
if (-not (Test-Path $DllPath)) { throw "nvcpluir.dll was not found." }

$CompilerCandidates = @(
    "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe",
    "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\csc.exe",
    "$env:WINDIR\Microsoft.NET\Framework64\v3.5\csc.exe",
    "$env:WINDIR\Microsoft.NET\Framework\v3.5\csc.exe"
)
$Compiler = $CompilerCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $Compiler) { throw "csc.exe was not found in the .NET Framework folders." }

$BuildRoot = Join-Path ([IO.Path]::GetTempPath()) "Install-NVCPL-exe-build-$PID"
$LauncherPath = Join-Path $BuildRoot "InstallNvcplLauncher.cs"
$ManifestPath = Join-Path $BuildRoot "InstallNvcplLauncher.exe.manifest"
New-Item $BuildRoot -ItemType Directory -Force | Out-Null

try {
    @'
using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;

internal static class Program
{
    private const string ScriptResource = "Install-NVCPL.ps1";
    private const string DllResource = "nvcpluir.dll";

    private static int Main()
    {
        string extractionRoot = Path.Combine(Path.GetTempPath(), "Install-NVCPL-" + Guid.NewGuid().ToString("N"));

        try
        {
            Directory.CreateDirectory(extractionRoot);

            string scriptPath = Path.Combine(extractionRoot, ScriptResource);
            string dllPath = Path.Combine(extractionRoot, DllResource);
            ExtractResource(ScriptResource, scriptPath);
            ExtractResource(DllResource, dllPath);

            string powerShellPath = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.System),
                @"WindowsPowerShell\v1.0\powershell.exe");

            ProcessStartInfo startInfo = new ProcessStartInfo
            {
                FileName = powerShellPath,
                Arguments = "-NoProfile -ExecutionPolicy Bypass -File \"" + scriptPath + "\"",
                UseShellExecute = false,
                WorkingDirectory = extractionRoot
            };

            using (Process process = Process.Start(startInfo))
            {
                process.WaitForExit();
                return process.ExitCode;
            }
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine("Failed to launch Install-NVCPL: " + ex.Message);
            Console.Error.WriteLine("Press Enter to exit.");
            Console.ReadLine();
            return 1;
        }
        finally
        {
            TryDeleteDirectory(extractionRoot);
        }
    }

    private static void ExtractResource(string resourceName, string outputPath)
    {
        Assembly assembly = Assembly.GetExecutingAssembly();
        using (Stream input = assembly.GetManifestResourceStream(resourceName))
        {
            if (input == null)
            {
                throw new InvalidOperationException("Missing embedded resource: " + resourceName);
            }

            using (FileStream output = File.Create(outputPath))
            {
                input.CopyTo(output);
            }
        }
    }

    private static void TryDeleteDirectory(string directory)
    {
        try
        {
            if (Directory.Exists(directory))
            {
                Directory.Delete(directory, true);
            }
        }
        catch
        {
            // Best effort cleanup only.
        }
    }
}
'@ | Set-Content -Path $LauncherPath -Encoding UTF8

    @'
<?xml version="1.0" encoding="utf-8"?>
<assembly manifestVersion="1.0" xmlns="urn:schemas-microsoft-com:asm.v1">
  <trustInfo xmlns="urn:schemas-microsoft-com:asm.v2">
    <security>
      <requestedPrivileges xmlns="urn:schemas-microsoft-com:asm.v3">
        <requestedExecutionLevel level="requireAdministrator" uiAccess="false" />
      </requestedPrivileges>
    </security>
  </trustInfo>
</assembly>
'@ | Set-Content -Path $ManifestPath -Encoding UTF8

    & $Compiler `
        /nologo `
        /optimize+ `
        /target:exe `
        /platform:anycpu `
        "/out:$OutputPath" `
        "/win32manifest:$ManifestPath" `
        "/resource:$ScriptPath,Install-NVCPL.ps1" `
        "/resource:$DllPath,nvcpluir.dll" `
        $LauncherPath

    if ($LASTEXITCODE -ne 0) { throw "csc.exe failed with exit code $LASTEXITCODE." }

    $Output = Get-Item $OutputPath
    Write-Output "Built $($Output.FullName)"
    Write-Output "Size: $($Output.Length) bytes"
}
finally {
    Remove-Item $BuildRoot -Recurse -Force -ErrorAction SilentlyContinue
}
