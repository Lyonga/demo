resource "aws_ssm_document" "install_syxsense_windows" {
  name          = "InstallSyxsenseWindowsFromS3"
  document_type = "Command"

  content = <<EOF
{
  "schemaVersion": "2.2",
  "description": "Install Syxsense Agent on Windows from S3",
  "mainSteps": [
    {
      "action": "aws:runPowerShellScript",
      "name": "installSyxsenseAgent",
      "inputs": {
        "runCommand": [
          "aws s3 cp s3://{{ s3_bucket_name }}/ResponderSetup.msi C:\\Syxsense\\ResponderSetup.msi",
          "Start-Process msiexec.exe -ArgumentList '/i', 'C:\\Syxsense\\ResponderSetup.msi', '/qn' -Wait",
          "Remove-Item -Path 'C:\\Syxsense\\ResponderSetup.msi'"
        ]
      }
    }
  ]
}
EOF
}



resource "aws_ssm_document" "install_syxsense_linux" {
  name          = "InstallSyxsenseLinuxFromS3"
  document_type = "Command"

  content = <<EOF
{
  "schemaVersion": "2.2",
  "description": "Install Syxsense Agent on RPM-based Linux from S3",
  "mainSteps": [
    {
      "action": "aws:runShellScript",
      "name": "installSyxsenseAgent",
      "inputs": {
        "runCommand": [
          "aws s3 cp s3://{{ s3_bucket_name }}/syxsenseresponder.latest.linux-x64.rpm /tmp/syxsenseresponder.rpm",
          "sudo yum install -y /tmp/syxsenseresponder.rpm",
          "sudo /usr/local/bin/SyxsenseResponder --instanceName={{ syxsense_instance_name }}",
          "rm -f /tmp/syxsenseresponder.rpm"
        ]
      }
    }
  ]
}
EOF
}


resource "aws_ssm_association" "syxsense_linux_association" {
  name       = aws_ssm_document.install_syxsense_linux.name
  targets = [
    {
      key    = "InstanceIds",
      values = [aws_instance.linux_instance.id]
    }
  ]
}

resource "aws_ssm_association" "syxsense_windows_association" {
  name       = aws_ssm_document.install_syxsense_windows.name
  targets = [
    {
      key    = "InstanceIds",
      values = [aws_instance.windows_instance.id]
    }
  ]
}
