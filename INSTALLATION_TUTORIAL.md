# BRLN-OS Installation Tutorial

## Complete Step-by-Step Guide to Install BRLN-OS on a USB Drive

This guide will walk you through installing BRLN-OS on a USB pendrive and accessing it via SSH.

---

## Prerequisites

- A USB pendrive with at least **8GB** of storage
- A computer to create the bootable USB
- Access to the target machine where BRLN-OS will run
- Internet connection

---

## Step 1: Download Ubuntu 24.04 LTS

1. Visit the official Canonical website: [https://ubuntu.com/download/server](https://ubuntu.com/download/server)
2. Download **Ubuntu 24.04 LTS Server** (ISO file)
3. Save the ISO file to your computer

---

## Step 2: Download and Install Balena Etcher

1. Visit the Balena Etcher website: [https://www.balena.io/etcher/](https://www.balena.io/etcher/)
2. Download Balena Etcher for your operating system:
   - **Windows**: Download the Windows installer
   - **macOS**: Download the macOS .dmg file
   - **Linux**: Download the AppImage or use package manager
3. Install Balena Etcher on your computer

---

## Step 3: Flash Ubuntu 24.04 to USB Pendrive

1. **Insert your USB pendrive** (minimum 8GB) into your computer
   - ⚠️ **Warning**: All data on the USB will be erased!

2. **Open Balena Etcher**

3. **Flash from file**:
   - Click "Flash from file"
   - Select the Ubuntu 24.04 LTS ISO you downloaded

4. **Select target**:
   - Click "Select target"
   - Choose your USB pendrive from the list
   - Double-check that you selected the correct drive!

5. **Flash!**:
   - Click "Flash!" to start the process
   - Wait for the flashing process to complete (this may take 5-15 minutes)
   - Balena Etcher will verify the flash automatically

6. **Eject the USB safely** when the process is complete

---

## Step 4: Boot from USB and Install Ubuntu

1. **Insert the USB pendrive** into the target machine where you want to install BRLN-OS

2. **Boot from USB**:
   - Restart the computer
   - Press the boot menu key (usually F12, F2, ESC, or DEL depending on your system)
   - Select the USB drive from the boot menu

3. **Install Ubuntu Server**:
   - Follow the Ubuntu installation wizard
   - Configure your language, keyboard layout, and network settings
   - **Create a user account** (remember your username and password!)
   - Select "Install OpenSSH server" when prompted (important for remote access)
   - Complete the installation
   - Reboot when prompted (remove the USB when instructed)

---

## Step 5: Connect via SSH

After Ubuntu boots up on your machine:

1. **Find the IP address** of your Ubuntu machine:
   - On the Ubuntu machine, login and run:
     ```bash
     ip addr show
     ```
   - Look for your IP address (usually starts with 192.168.x.x or 10.0.x.x)

2. **Connect from another computer** using SSH:
   ```bash
   ssh username@YOUR_IP_ADDRESS
   ```
   - Replace `username` with your Ubuntu username
   - Replace `YOUR_IP_ADDRESS` with the IP you found
   - Enter your password when prompted

---

## Step 6: Install BRLN-OS

Once connected via SSH, run the following single command:

```bash
git clone https://github.com/pagcoinbr/brln-os.git && cd brln-os && bash brunel.sh
```

This command will:
1. Clone the BRLN-OS repository from GitHub
2. Navigate into the brln-os directory
3. Run the main installation script (brunel.sh)

---

## Step 7: Follow the Installation Instructions

The `brunel.sh` script will guide you through the installation process:

1. **Main Menu**: You'll see a menu with various options
2. **Follow the prompts**: The script will ask questions and guide you through setup
3. **Configure services**: Choose which Bitcoin/Lightning services to install
4. **Wait for completion**: The installation process may take some time

Key things the installer will do:
- Install Bitcoin Core
- Install Lightning Network Daemon (LND)
- Set up the web interface
- Configure system services
- Set up your wallet

---

## Step 8: Access the Web Interface

After installation is complete:

1. **Find your BRLN-OS IP address** (if you haven't already)
2. **Open a web browser** on any device on the same network
3. **Navigate to**: `http://YOUR_IP_ADDRESS`
4. You'll be greeted by the BRLN-OS interface!

---

## Initial Setup Wizard

When you first access the web interface, BRLN-OS will check your system status:

### Scenario 1: Fresh Installation (No /data/lnd and lnd not in system)
- You'll be taken to the **interactive terminal setup**
- Follow the `menu.sh` prompts to configure your system
- Create your first wallet and configure services

### Scenario 2: LND Directory Exists (/data/lnd) but No Wallet Configured
- You'll be taken to the **wallet creation interface**
- Create or import a wallet
- Configure your Lightning Network node

### Scenario 3: Everything Configured
- You'll be taken directly to the **main dashboard**
- Your system is ready to use!

---

## Troubleshooting

### USB Won't Boot
- Check BIOS/UEFI settings and ensure USB boot is enabled
- Try a different USB port
- Verify the ISO was flashed correctly

### Can't Connect via SSH
- Verify OpenSSH server was installed during Ubuntu setup
- Check firewall settings: `sudo ufw status`
- Verify the IP address is correct

### Installation Fails
- Check internet connection
- Ensure you have enough disk space
- Check system requirements
- Review log files in the brln-os directory

---

## System Requirements

- **Processor**: 2 GHz dual-core or better
- **RAM**: Minimum 4GB, recommended 8GB+
- **Storage**: Minimum 500GB SSD (for Bitcoin blockchain)
- **Network**: Stable internet connection

---

## Next Steps

After successful installation:

1. **Configure your wallet** - Create or import your Bitcoin wallet
2. **Sync the blockchain** - Bitcoin Core will begin syncing (this takes time!)
3. **Set up Lightning** - Configure your Lightning Network node
4. **Explore the interface** - Familiarize yourself with BRLN-OS features
5. **Secure your node** - Enable firewall, change default passwords, back up your keys

---

## Support

For help and support:

- **GitHub Issues**: [https://github.com/pagcoinbr/brln-os/issues](https://github.com/pagcoinbr/brln-os/issues)
- **Documentation**: Check the README.md in the repository
- **Community**: Join the BRLN-OS community

---

## Security Reminders

⚠️ **Important Security Tips**:

1. **Back up your wallet seeds** - Write them down and store safely
2. **Use strong passwords** - Especially for wallet encryption
3. **Keep your system updated** - Run updates regularly
4. **Secure SSH access** - Consider using SSH keys instead of passwords
5. **Enable firewall** - Protect your node from unauthorized access

---

## Conclusion

Congratulations! You've successfully installed BRLN-OS. You now have your own Bitcoin and Lightning Network node running on Ubuntu 24.04 LTS.

Remember: BRLN-OS is powerful software for running a full Bitcoin node. Take time to understand each feature and always prioritize security.

**Welcome to the Bitcoin Network! ₿**

---

*Last updated: December 2025*
*BRLN-OS - Bitcoin for the People*
