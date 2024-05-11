# HOW TO CREATE A NEW MODULE
## Document goal
The is document will instruct on how you should proceed with module creation.
Modules are managed as microsoft intend it.

## Module structure
A module is composed of three distincts elements:
1. A folder
2. A module file
3. One or more script/module file.

The folder is at the top of the hierarchy and must be placed in .\Modules:
```
|
+-+-> MODULES
  +-+-> MyModule
    +---> myModule.psd1
    +---> myModule.psm1
```
When the script starts, it will automatically load every manifest file (.psd1) to import related module file (.psm1) or script (.ps1).

## Create your module
### Step 1: Choosing a name
All modules should reflect the nature of the functions they will offers. The name should always be prefixed by 'Module-'.
Example:
> You will create a module that will deal with User accounts.
> You will name your module: Module-UserManagement

### Step 2: Create folder
Once youe module name ha been fixed, proceed with the folder creation within the .\Modules directory. 
The folder must be named as your module (i.e. *Module-UserManagement* as per previous example).

### Step 3: Create a manifest file
Fireup PowerShell and move to your new folder. Then, run the following command to generate your manifest (remplace *module-userManagement* by your script name):
```
New-ModuleManifest  -Path ./Module-UserManagement.psd1 `
                    -ModuleVersion '1.0.0.0' `
                    -Author $env:username `
                    -RootModule Module-UserManagement.psm1 `
                    -NestedModules Module-UserManagement.psm1 `
                    -Guid (New-Guid).Guid
```
*RootModule* and *NestedModule* are requested for the manifest to load properly the functions within your module file.

### Step 4: Create your module file
To let the module be able to load your functions, create a new file name as your folder with the extension '.psm1' (*module-userManagement.psm1* in our example), then add your function to it.

## Tips
### Test the validity of a manifest file
Just run the below command against your .psd1 file to test it (adapt following your need):
```
test-moduleManifest .\Modules\MyModule\myModule.psd1
```
### Load your module file
To load your module and test if it works, run the below commands:
```
import-module .\Modules\MyModule -verbose
Get-Command -Module MyModule
Get-Module
```
You should get on screen the list of functions within your module and the module manifest version number (1.0.0.0 by default).