
Add-Type -AssemblyName PresentationFramework

# Modern WPF XAML for login window
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="FuOnline Tool" Height="400" Width="500" WindowStartupLocation="CenterScreen"
        Background="#222222" AllowsTransparency="True" WindowStyle="None" Opacity="0.92">
    <Border CornerRadius="24" Background="#222222" Padding="0" BorderBrush="#444" BorderThickness="2">
        <Grid Margin="30">
            <Grid.RowDefinitions>
                <RowDefinition Height="40"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="120"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <!-- Custom window buttons -->
            <StackPanel Orientation="Horizontal" Grid.Row="0" Grid.ColumnSpan="2" HorizontalAlignment="Right" VerticalAlignment="Top" Margin="0,0,0,0">
                <Button x:Name="MinBtn" Content="_" Width="28" Height="28" Margin="0,0,2,0" Background="#333" Foreground="#fff" BorderBrush="#555" BorderThickness="0" FontSize="16" Cursor="Hand">
                    <Button.Template>
                        <ControlTemplate TargetType="Button">
                            <Border CornerRadius="14" Background="{TemplateBinding Background}" >
                                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                        </ControlTemplate>
                    </Button.Template>
                </Button>
                <Button x:Name="RestoreBtn" Content="❐" Width="28" Height="28" Margin="0,0,2,0" Background="#333" Foreground="#fff" BorderBrush="#555" BorderThickness="0" FontSize="15" Cursor="Hand">
                    <Button.Template>
                        <ControlTemplate TargetType="Button">
                            <Border CornerRadius="14" Background="{TemplateBinding Background}" >
                                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                        </ControlTemplate>
                    </Button.Template>
                </Button>
                <Button x:Name="CloseBtn" Content="✕" Width="28" Height="28" Background="#e81123" Foreground="#fff" BorderBrush="#555" BorderThickness="0" FontSize="15" Cursor="Hand">
                    <Button.Template>
                        <ControlTemplate TargetType="Button">
                            <Border CornerRadius="14" Background="{TemplateBinding Background}" >
                                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                        </ControlTemplate>
                    </Button.Template>
                </Button>
            </StackPanel>

            <TextBlock Text="FuOnline Tool" Foreground="#fff" FontSize="28" FontWeight="Bold" Grid.Row="1" Grid.ColumnSpan="2" HorizontalAlignment="Center" Margin="0,0,0,16"/>

            <TextBlock Text="Username:" Foreground="#fff" FontSize="16" Grid.Row="2" Grid.Column="0" VerticalAlignment="Center" Margin="0,0,8,0"/>
            <TextBox x:Name="UsernameBox" Grid.Row="2" Grid.Column="1" Margin="0,0,0,8" FontSize="16" Height="32" Padding="8,4,8,4" Background="#333" Foreground="#fff" BorderBrush="#555" BorderThickness="1" VerticalContentAlignment="Center"/>

            <TextBlock Text="Password:" Foreground="#fff" FontSize="16" Grid.Row="3" Grid.Column="0" VerticalAlignment="Center" Margin="0,0,8,0"/>
            <PasswordBox x:Name="PasswordBox" Grid.Row="3" Grid.Column="1" Margin="0,0,0,8" FontSize="16" Height="32" Padding="8,4,8,4" Background="#333" Foreground="#fff" BorderBrush="#555" BorderThickness="1" VerticalContentAlignment="Center"/>

            <Button Content="Login" Grid.Row="4" Grid.Column="1" Margin="0,8,0,0" Width="120" Height="38" FontSize="16" FontWeight="SemiBold" Background="#0078D7" Foreground="#fff" BorderBrush="#0078D7" BorderThickness="0" x:Name="LoginBtn" HorizontalAlignment="Left" Cursor="Hand"/>

            <TextBlock Text="Auto download source, updates, and more features available after login." Foreground="#bbb" FontSize="14" Grid.Row="5" Grid.ColumnSpan="2" TextWrapping="Wrap" Margin="0,24,0,0" HorizontalAlignment="Center"/>
        </Grid>
    </Border>
</Window>
"@

# Convert XAML string to a MemoryStream
$bytes = [System.Text.Encoding]::UTF8.GetBytes($xaml)
$stream = New-Object System.IO.MemoryStream(,$bytes)

# Load XAML
$window = [Windows.Markup.XamlReader]::Load($stream)

# Get controls
$usernameBox = $window.FindName("UsernameBox")
$passwordBox = $window.FindName("PasswordBox")
$loginBtn = $window.FindName("LoginBtn")
$minBtn = $window.FindName("MinBtn")
$restoreBtn = $window.FindName("RestoreBtn")
$closeBtn = $window.FindName("CloseBtn")

# Add event handler for login button
$loginBtn.Add_Click({
    $username = $usernameBox.Text
    $password = $passwordBox.Password
    if ($username -and $password) {
        [System.Windows.MessageBox]::Show("Login successful!","FuOnline Tool")
        $window.Close()
    } else {
        [System.Windows.MessageBox]::Show("Please enter username and password.","FuOnline Tool")
    }
})

# Add event handlers for window buttons
$minBtn.Add_Click({
    $window.WindowState = [System.Windows.WindowState]::Minimized
})
$restoreBtn.Add_Click({
    if ($window.WindowState -eq [System.Windows.WindowState]::Maximized) {
        $window.WindowState = [System.Windows.WindowState]::Normal
    } else {
        $window.WindowState = [System.Windows.WindowState]::Maximized
    }
})
$closeBtn.Add_Click({
    $window.Close()
})

# Enable window dragging by mouse
$null = $window.Add_MouseLeftButtonDown({
    $window.DragMove()
})

# Show window
$window.Topmost = $true
$window.ShowDialog() | Out-Null
