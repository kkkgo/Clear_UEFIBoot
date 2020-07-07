#include <iostream>
#include <windows.h>
#include <commctrl.h>
#include <Winbase.h>

bool EnableDebugPrivilege()
{
    HANDLE hToken;
    LUID sedebugnameValue;
    TOKEN_PRIVILEGES tkp;
    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, &hToken))
    {
        return   FALSE;
    }
    if (!LookupPrivilegeValue(NULL, SE_SYSTEM_ENVIRONMENT_NAME, &sedebugnameValue))
    {
        CloseHandle(hToken);
        return false;
    }
    tkp.PrivilegeCount = 1;
    tkp.Privileges[0].Luid = sedebugnameValue;
    tkp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
    if (!AdjustTokenPrivileges(hToken, FALSE, &tkp, sizeof(tkp), NULL, NULL))
    {
        CloseHandle(hToken);
        return false;
    }
    return true;
}

int main(int argc, char* argv[])
{
    FIRMWARE_TYPE fwt;
    GetFirmwareType(&fwt);
    DWORD err_c;
    EnableDebugPrivilege();
    if (fwt == FirmwareTypeUefi)
    {
        SetFirmwareEnvironmentVariableA("BootOrder", "{8BE4DF61-93CA-11D2-AA0D-00E098032B8C}", NULL, 0);
        err_c = GetLastError();
        
        if (err_c == 0)
        {
            std::cout << "All UEFI boot order entry in NVRAM have been cleared.\n";
        }
        else if (err_c == 0xcb)
			{
				std::cout << "There is no UEFI boot order entry found in NVRAM.\nOr this program is not compatible with your system version.\nMaybe you can try to execute in PE environment.\n";
				std::cout << std::hex << "Error: 0x" << err_c <<"\n"<< std::endl;
			}
		else if (err_c == 0x522)
		{
			std::cout << "You need to run this program with administrator rights.\n";
			std::cout << std::hex << "Error: 0x" << err_c << "\n" << std::endl;
		}
		else{
			std::cout << std::hex << "Error: 0x" << err_c << "\n" << std::endl;
		}
    }
    else
    {
        std::cout << "You are using Legacy BIOS.\nError:This program must be run in UEFI mode.";

    }
}
