### **Applying EC2 User Data Changes Without Recreating the Instance**

By default, AWS EC2 **user data** runs only during the **first boot** of an instance. However, you can **re-run user data manually** or use **AWS Systems Manager (SSM)** to apply changes dynamically.

---

## **1. Methods to Re-Run or Apply User Data Changes**
### **Method 1: Manually Re-Run User Data on an Existing Instance**
If your user data script is already on the instance, you can manually execute it.

#### **For Windows EC2 Instances**
1. Open **PowerShell** as Administrator.
2. Run the following command:
   ```powershell
   C:\ProgramData\Amazon\EC2-Windows\Launch\Scripts\InitializeInstance.ps1 -Schedule
   ```

3. Alternatively, execute the batch file directly:
   ```cmd
   C:\ProgramData\Amazon\EC2-Windows\Launch\Scripts\UserScript.cmd
   ```

This will force Windows to execute the user data script again.

---

#### **For Linux EC2 Instances**
User data scripts are usually stored at:
```bash
/var/lib/cloud/instance/scripts/
```
To re-run the script manually:
```bash
sudo cloud-init init
sudo cloud-init modules --mode=config
sudo cloud-init modules --mode=final
```
Or directly execute:
```bash
sudo bash /var/lib/cloud/instance/user-data.txt
```

If user data execution is disabled after the first boot, you can modify the cloud-init config:

```bash
sudo vi /etc/cloud/cloud.cfg
```
Change this line:
```yaml
cloud_final_modules:
  - [scripts-user, once-per-instance]
```
To:
```yaml
cloud_final_modules:
  - [scripts-user, always]
```
This makes user data execute every time the instance boots.

---

### **Method 2: Use AWS Systems Manager (SSM) to Execute New Commands**
If your instance has **SSM Agent installed and configured**, you can use AWS Systems Manager to run new scripts **remotely**.

#### **Run a Script via SSM Console**
1. Go to **AWS Systems Manager > Run Command**.
2. Click **Run a Command**.
3. Choose **AWS-RunShellScript** for Linux or **AWS-RunPowerShellScript** for Windows.
4. Enter your new user data script in the command box.
5. Select the EC2 instance and run the command.

#### **Run Script via AWS CLI**
For **Linux**:
```sh
aws ssm send-command --document-name "AWS-RunShellScript" --targets "Key=instanceIds,Values=i-xxxxxxxxxxxxx" --parameters 'commands=["bash /var/lib/cloud/instance/user-data.txt"]'
```

For **Windows**:
```sh
aws ssm send-command --document-name "AWS-RunPowerShellScript" --targets "Key=instanceIds,Values=i-xxxxxxxxxxxxx" --parameters 'commands=["C:\ProgramData\Amazon\EC2-Windows\Launch\Scripts\InitializeInstance.ps1 -Schedule"]'
```

---

### **Method 3: Restart the Instance to Trigger User Data Execution**
In **some cases**, rebooting the instance may **re-run user data** if cloud-init is configured to allow it.

#### **Rebooting the Instance via CLI**
```sh
aws ec2 reboot-instances --instance-ids i-xxxxxxxxxxxxx
```
or using PowerShell on Windows:
```powershell
Restart-Computer -Force
```

##### **Will Rebooting Help?**
✅ **YES, if**:
- The user data script is configured to re-run on boot (see cloud-init changes above).
- The script modifies system settings or installs software that applies on reboot.

❌ **NO, if**:
- The script was designed to run **only once per instance** (default behavior).
- Cloud-init or AWS Launch services do not allow re-execution on boot.

---

### **Final Recommendation**
| **Scenario** | **Solution** |
|-------------|-------------|
| Need to apply new changes **without reboot** | Use **SSM Run Command** |
| Need to apply user data script again **manually** | Run it from `/var/lib/cloud/instance/user-data.txt` or `C:\ProgramData\Amazon\EC2-Windows\Launch\Scripts\UserScript.cmd` |
| Need user data to run **on every boot** | Modify `/etc/cloud/cloud.cfg` (Linux) |
| Willing to reboot the instance | Try `aws ec2 reboot-instances`, but ensure cloud-init is configured properly |

---

Would you like **Terraform code to automate this via SSM**, or do you need help modifying **CloudFormation scripts** to make user data persist? 🚀
