# PeopleTools Patching Demo

These scripts were used for the demonstration of patching an ELM Image 14 PI from 8.55.09 to 8.55.13.

## Scripts

`.\patching\applyPTPatch.ps1 85513` is what we used to apply the patch.

The `applyPTPatch.ps1` script takes 4 arguments

* PatchLevel (Required)
* Database (Optional - Default `Yes`)
* Bootstrap (Optional - Default `Yes`)
* Puppet (Optional - Default `Yes`)

The script assumes the PeopleTools Patch DPK Files is mounted to `c:\ptxxxxx`, but you can modify that to point to any location where the PeopleTools Patch DPK is downloaded.

