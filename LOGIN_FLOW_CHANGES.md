# Login Flow Changes - BRLN-OS

## Overview
This document describes the changes made to the BRLN-OS login flow to provide a more intelligent initial setup experience based on the system's LND installation status.

## Changes Made

### 1. Installation Tutorial (`INSTALLATION_TUTORIAL.md`)
Created a comprehensive step-by-step installation guide that covers:
- Downloading Ubuntu 24.04 LTS from canonical website
- Downloading and installing Balena Etcher
- Flashing Ubuntu to a USB pendrive (minimum 8GB)
- Booting from USB and installing Ubuntu
- Connecting via SSH
- Installing BRLN-OS with the command: `git clone https://github.com/pagcoinbr/brln-os.git && cd brln-os && bash brunel.sh`
- Following the setup instructions
- Initial setup wizard scenarios

### 2. Modified Login Logic (`main.html`)
Updated the main application entry point to check system status and redirect appropriately:

#### New Logic Flow:
1. **Check LND Installation Status** - Determine if LND is installed
2. **Check Wallet Configuration** - Determine if a wallet is configured
3. **Route Based on Status**:

**Scenario A: Fresh Installation**
- **Condition**: No `/data/lnd` directory AND `lnd` not in system path
- **Action**: Redirect to terminal web running `menu.sh` for initial system setup
- **URL**: `/terminal/?cmd=cd%20/root/brln-os%20%26%26%20bash%20scripts/menu.sh`

**Scenario B: LND Installed, No Wallet**
- **Condition**: `/data/lnd` exists OR `lnd` in system path BUT no wallet configured
- **Action**: Redirect to wallet creation page
- **URL**: `pages/components/wallet/wallet.html`

**Scenario C: Wallet Configured**
- **Condition**: Wallet exists in the system
- **Action**: Load the main dashboard
- **URL**: `pages/home/index.html`

#### New Functions Added:

```javascript
async checkLNDInstalled()
```
- Queries the API endpoint `/api/v1/system/check-lnd-installation`
- Returns object with:
  - `hasLNDDirectory`: boolean - `/data/lnd` directory exists
  - `lndInSystemPath`: boolean - `lnd` command available in PATH
  - `lndInstalled`: boolean - overall installation status

```javascript
redirectToTerminalMenu()
```
- Redirects to terminal running `menu.sh`
- Shows notification about initial setup
- Uses URL parameter to automatically run the command

### 3. New API Endpoint (`api/v1/app.py`)
Added a new endpoint to check LND installation status:

**Endpoint**: `GET /api/v1/system/check-lnd-installation`

**Response**:
```json
{
  "status": "success",
  "has_lnd_directory": false,
  "lnd_in_system_path": false,
  "lnd_installed": false
}
```

**Implementation**:
- Checks if `/data/lnd` directory exists
- Checks if `lnd` command is available via `which lnd`
- Returns comprehensive status information

## Benefits

1. **Smarter Onboarding**: The system now automatically detects the installation state and guides users appropriately
2. **Better UX**: Users are not confused about what to do first - the system tells them
3. **Terminal Integration**: Fresh installations go directly to the interactive terminal setup
4. **Wallet Focus**: Systems with LND but no wallet go straight to wallet creation
5. **Seamless Flow**: Configured systems load the dashboard immediately

## Testing Scenarios

### Test 1: Fresh Installation
1. No `/data/lnd` directory
2. `lnd` not in system path
3. Expected: Redirect to terminal running `menu.sh`

### Test 2: LND Installed via Scripts
1. `/data/lnd` directory exists
2. No wallet configured
3. Expected: Redirect to wallet creation page

### Test 3: Fully Configured System
1. LND installed
2. Wallet configured
3. Expected: Load main dashboard

## Files Modified

1. `/root/brln-os/main.html`
   - Modified `performWalletCheck()` function
   - Added `checkLNDInstalled()` function
   - Added `redirectToTerminalMenu()` function

2. `/root/brln-os/api/v1/app.py`
   - Added `/api/v1/system/check-lnd-installation` endpoint

3. `/root/brln-os/INSTALLATION_TUTORIAL.md` (NEW)
   - Comprehensive installation guide

4. `/root/brln-os/LOGIN_FLOW_CHANGES.md` (THIS FILE)
   - Documentation of changes

## Backward Compatibility

All changes are backward compatible:
- Existing wallet configurations continue to work
- Bypass mechanisms (session storage flags) are preserved
- Error handling ensures graceful degradation
- API returns sensible defaults on error

## Security Considerations

- No sensitive information is exposed in the installation check
- Terminal access is only provided for initial setup
- Wallet password protection remains unchanged
- All existing security measures are preserved

## Future Enhancements

Potential improvements for future versions:
1. Add more granular setup stages (Bitcoin Core, LND, Services)
2. Implement a visual progress indicator for setup
3. Add ability to skip terminal and use GUI setup
4. Provide setup wizard with multiple installation profiles
5. Add system requirements check before installation

## Support

For issues or questions:
- Check the installation tutorial: `INSTALLATION_TUTORIAL.md`
- Review the main README: `README.md`
- Open an issue on GitHub: https://github.com/pagcoinbr/brln-os/issues

---

**Last Updated**: December 29, 2025
**Version**: 1.0
**Author**: BRLN-OS Development Team
