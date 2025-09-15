param (
    [parameter(mandatory=$false, helpMessage="Specify the state mode (Debug or Release). Default is Debug.")]
    [ValidateSet("Debug", "Release")]
    [string]$stateMode = "Debug"
)

enum stateMode {
    Debug
    Release
}

class MainProgram {
    static main($stateMode) {
        if ($stateMode -eq "Debug") {
            Write-Host "Running in Debug mode"
            # Add Debug mode specific logic here
        } elseif ($stateMode -eq "Release") {
            Write-Host "Running in Release mode"
            # Add Release mode specific logic here
        } else {
            Write-Host "Invalid state mode. Please use 'Debug' or 'Release'."
        }
    }
}

[MainProgram]::main($stateMode)