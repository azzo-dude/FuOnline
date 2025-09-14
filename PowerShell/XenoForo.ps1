class XenoForo {
    hidden static $session = [Microsoft.PowerShell.Commands.WebRequestSession]::new()

    static [bool] loadConfigJson([string]$path) {

        return $true
    }

    static [bool] login([string]$username, [System.Security.SecureString]$password, [string]$url) {
        try {
            $PlainTextPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR(
                [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
            )
            $loginPage = Invoke-WebRequest -Uri $url -WebSession ([XenoForo]::session)

            $tokenMatch = [regex]::Match($loginPage.RawContent, 'name="_xfToken" value="([^"]+)"')
            if (-not $tokenMatch.Success) {
                Write-Error "Could not find _xfToken on the login page."
                return $false
            }
            $xfToken = $tokenMatch.Groups[1].Value

            $credentials = @{
                login    = $username
                password = $PlainTextPassword
                _xfToken = $xfToken
            }

            $loginActionUrl = "$url/login"

            $response = Invoke-WebRequest -Uri $loginActionUrl -Method Post -Body $credentials -WebSession ([XenoForo]::session)

            if ($response.RawContent -match $username) {
                Write-Host "Login successful!" -ForegroundColor Green
                return $true
            } else {
                Write-Warning "Login may have failed. Check credentials or site structure."
                return $false
            }
        } catch {
            Write-Error "Login failed: $_"
            return $false
        }
    }
}
