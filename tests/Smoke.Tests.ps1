Describe 'PowerShell source smoke tests' {
    $files = @(Get-ChildItem -Path $PSScriptRoot -Recurse -File -Include *.ps1,*.psm1 |
        Where-Object { $_.FullName -notmatch '\\\.git\\' })

    It 'has at least one PowerShell file' {
        if ($files.Count -eq 0) { throw 'No PowerShell files found' }
    }

    It 'parses every PowerShell file without errors' {
        foreach ($file in $files) {
            $tokens = $null
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors) | Out-Null
            if ($errors.Count -gt 0) { throw "Parse errors in $($file.FullName)" }
        }
    }
}