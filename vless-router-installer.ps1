# VLESS Router - Установщик с графическим интерфейсом для Windows
# Скрипт автоматически находит роутер, устанавливает соединение и открывает веб-интерфейс

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Создание формы
$form = New-Object System.Windows.Forms.Form
$form.Text = "VLESS Router Installer"
$form.Size = New-Object System.Drawing.Size(500, 400)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# Иконка и стиль
$form.BackColor = [System.Drawing.Color]::White
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)

# Заголовок
$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Location = New-Object System.Drawing.Point(20, 20)
$titleLabel.Size = New-Object System.Drawing.Size(460, 30)
$titleLabel.Text = "VLESS Router - Мастер установки"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($titleLabel)

# Описание
$descriptionLabel = New-Object System.Windows.Forms.Label
$descriptionLabel.Location = New-Object System.Drawing.Point(20, 60)
$descriptionLabel.Size = New-Object System.Drawing.Size(460, 40)
$descriptionLabel.Text = "Этот мастер поможет вам установить VLESS Router на ваш маршрутизатор с OpenWrt"
$form.Controls.Add($descriptionLabel)

# Группа настроек подключения
$groupBox = New-Object System.Windows.Forms.GroupBox
$groupBox.Location = New-Object System.Drawing.Point(20, 110)
$groupBox.Size = New-Object System.Drawing.Size(440, 180)
$groupBox.Text = "Настройки подключения к роутеру"
$form.Controls.Add($groupBox)

# IP-адрес роутера
$ipLabel = New-Object System.Windows.Forms.Label
$ipLabel.Location = New-Object System.Drawing.Point(20, 30)
$ipLabel.Size = New-Object System.Drawing.Size(150, 20)
$ipLabel.Text = "IP-адрес роутера:"
$groupBox.Controls.Add($ipLabel)

$ipTextBox = New-Object System.Windows.Forms.TextBox
$ipTextBox.Location = New-Object System.Drawing.Point(180, 30)
$ipTextBox.Size = New-Object System.Drawing.Size(240, 20)
$ipTextBox.Text = "192.168.1.1"
$groupBox.Controls.Add($ipTextBox)

# Порт SSH
$portLabel = New-Object System.Windows.Forms.Label
$portLabel.Location = New-Object System.Drawing.Point(20, 60)
$portLabel.Size = New-Object System.Drawing.Size(150, 20)
$portLabel.Text = "Порт SSH:"
$groupBox.Controls.Add($portLabel)

$portTextBox = New-Object System.Windows.Forms.TextBox
$portTextBox.Location = New-Object System.Drawing.Point(180, 60)
$portTextBox.Size = New-Object System.Drawing.Size(240, 20)
$portTextBox.Text = "22"
$groupBox.Controls.Add($portTextBox)

# Имя пользователя
$userLabel = New-Object System.Windows.Forms.Label
$userLabel.Location = New-Object System.Drawing.Point(20, 90)
$userLabel.Size = New-Object System.Drawing.Size(150, 20)
$userLabel.Text = "Имя пользователя:"
$groupBox.Controls.Add($userLabel)

$userTextBox = New-Object System.Windows.Forms.TextBox
$userTextBox.Location = New-Object System.Drawing.Point(180, 90)
$userTextBox.Size = New-Object System.Drawing.Size(240, 20)
$userTextBox.Text = "root"
$groupBox.Controls.Add($userTextBox)

# Пароль
$passwordLabel = New-Object System.Windows.Forms.Label
$passwordLabel.Location = New-Object System.Drawing.Point(20, 120)
$passwordLabel.Size = New-Object System.Drawing.Size(150, 20)
$passwordLabel.Text = "Пароль:"
$groupBox.Controls.Add($passwordLabel)

$passwordTextBox = New-Object System.Windows.Forms.TextBox
$passwordTextBox.Location = New-Object System.Drawing.Point(180, 120)
$passwordTextBox.Size = New-Object System.Drawing.Size(240, 20)
$passwordTextBox.PasswordChar = "*"
$groupBox.Controls.Add($passwordTextBox)

# Статус
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(20, 300)
$statusLabel.Size = New-Object System.Drawing.Size(460, 20)
$statusLabel.Text = "Готов к установке"
$form.Controls.Add($statusLabel)

# Прогресс-бар
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(20, 325)
$progressBar.Size = New-Object System.Drawing.Size(440, 20)
$progressBar.Minimum = 0
$progressBar.Maximum = 100
$form.Controls.Add($progressBar)

# Кнопка установки
$installButton = New-Object System.Windows.Forms.Button
$installButton.Location = New-Object System.Drawing.Point(320, 355)
$installButton.Size = New-Object System.Drawing.Size(140, 30)
$installButton.Text = "Установить"
$installButton.BackColor = [System.Drawing.Color]::FromArgb(0, 123, 255)
$installButton.ForeColor = [System.Drawing.Color]::White
$installButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$form.Controls.Add($installButton)

# Функция проверки соединения с роутером
function Test-RouterConnection {
    param($ipAddress)
    try {
        $ping = New-Object System.Net.NetworkInformation.Ping
        $result = $ping.Send($ipAddress, 3000)
        return $result.Status -eq "Success"
    }
    catch {
        return $false
    }
}

# Функция установки
function Start-Installation {
    $ipAddress = $ipTextBox.Text
    $port = $portTextBox.Text
    $user = $userTextBox.Text
    $password = $passwordTextBox.Text
    
    $progressBar.Value = 5
    $statusLabel.Text = "Проверка соединения с роутером..."
    
    # Проверка доступности роутера
    if (-not (Test-RouterConnection -ipAddress $ipAddress)) {
        [System.Windows.Forms.MessageBox]::Show("Не удается подключиться к роутеру. Проверьте IP-адрес и соединение.", "Ошибка", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        $progressBar.Value = 0
        $statusLabel.Text = "Ошибка подключения"
        return
    }
    
    $progressBar.Value = 15
    $statusLabel.Text = "Подготовка к установке..."
    
    # Создание временной директории
    $tempDir = [System.IO.Path]::GetTempPath() + [System.Guid]::NewGuid().ToString()
    New-Item -Path $tempDir -ItemType Directory | Out-Null
    
    # Проверка наличия необходимых инструментов
    $hasSsh = $null -ne (Get-Command -Name "ssh" -ErrorAction SilentlyContinue)
    $hasScp = $null -ne (Get-Command -Name "scp" -ErrorAction SilentlyContinue)
    
    if (-not ($hasSsh -and $hasScp)) {
        $gitForWindowsPath = "C:\Program Files\Git\usr\bin"
        $hasSsh = Test-Path "$gitForWindowsPath\ssh.exe"
        $hasScp = Test-Path "$gitForWindowsPath\scp.exe"
        
        if (-not ($hasSsh -and $hasScp)) {
            $result = [System.Windows.Forms.MessageBox]::Show("На вашем компьютере не обнаружены необходимые SSH-инструменты. Хотите установить Git for Windows, который включает эти инструменты?", "Требуются дополнительные компоненты", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
            
            if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
                Start-Process "https://gitforwindows.org/"
                [System.Windows.Forms.MessageBox]::Show("После установки Git for Windows, запустите этот установщик снова.", "Установка прервана", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                $progressBar.Value = 0
                $statusLabel.Text = "Установка прервана - требуется Git for Windows"
                return
            } else {
                $progressBar.Value = 0
                $statusLabel.Text = "Установка прервана"
                return
            }
        }
    }
    
    # Копирование файлов установки
    $progressBar.Value = 30
    $statusLabel.Text = "Копирование файлов на роутер..."
    
    try {
        # Создание директории проекта на роутере
        $psiSshMkdir = New-Object System.Diagnostics.ProcessStartInfo
        $psiSshMkdir.FileName = "ssh"
        $psiSshMkdir.Arguments = "-p $port -o StrictHostKeyChecking=no $user@$ipAddress `"mkdir -p /root/vless-router`""
        $psiSshMkdir.UseShellExecute = $false
        $psiSshMkdir.CreateNoWindow = $true
        
        $processSshMkdir = [System.Diagnostics.Process]::Start($psiSshMkdir)
        $processSshMkdir.WaitForExit()
        
        # Копируем только нужные файлы и директории
        $necessaryItems = @(
            "config", 
            "scripts", 
            "web", 
            "setup_webserver.sh", 
            "vless-router-installer.bat",
            "README.md"
        )
        
        foreach ($item in $necessaryItems) {
            if (Test-Path "$PSScriptRoot\$item") {
                $psiScp = New-Object System.Diagnostics.ProcessStartInfo
                $psiScp.FileName = "scp"
                $psiScp.Arguments = "-r -P $port -o StrictHostKeyChecking=no `"$PSScriptRoot\$item`" $user@$ipAddress:/root/vless-router/"
                $psiScp.UseShellExecute = $false
                $psiScp.CreateNoWindow = $true
                
                $processScp = [System.Diagnostics.Process]::Start($psiScp)
                $processScp.WaitForExit()
                
                if ($processScp.ExitCode -ne 0) {
                    throw "Ошибка при копировании '$item' на роутер."
                }
            }
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Ошибка при копировании файлов: $_", "Ошибка", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        $progressBar.Value = 0
        $statusLabel.Text = "Ошибка установки"
        return
    }
    
    $progressBar.Value = 60
    $statusLabel.Text = "Настройка web-сервера на роутере..."
    
    try {
        # Запуск скрипта инициализации на роутере
        $psiSsh = New-Object System.Diagnostics.ProcessStartInfo
        $psiSsh.FileName = "ssh"
        $psiSsh.Arguments = "-p $port -o StrictHostKeyChecking=no $user@$ipAddress `"cd /root/vless-router && chmod +x ./setup_webserver.sh && ./setup_webserver.sh`""
        $psiSsh.UseShellExecute = $false
        $psiSsh.CreateNoWindow = $true
        
        $processSsh = [System.Diagnostics.Process]::Start($psiSsh)
        $processSsh.WaitForExit()
        
        if ($processSsh.ExitCode -ne 0) {
            throw "Ошибка при настройке web-сервера на роутере."
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Ошибка при настройке web-сервера: $_", "Ошибка", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        $progressBar.Value = 0
        $statusLabel.Text = "Ошибка установки"
        return
    }
    
    $progressBar.Value = 90
    $statusLabel.Text = "Запуск веб-интерфейса..."
    
    # Открытие веб-интерфейса в браузере
    Start-Process "http://$ipAddress:8080/setup.html"
    
    $progressBar.Value = 100
    $statusLabel.Text = "Установка завершена! Откройте веб-интерфейс для завершения настройки."
    
    [System.Windows.Forms.MessageBox]::Show("Установка VLESS Router завершена успешно! Теперь откройте веб-браузер и перейдите по адресу http://$ipAddress:8080/setup.html для завершения настройки.", "Установка завершена", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
}

# Привязка события нажатия кнопки
$installButton.Add_Click({Start-Installation})

# Отображение формы
$form.ShowDialog() 