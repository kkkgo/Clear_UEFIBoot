[CmdletBinding()]
param(
  [Parameter(Mandatory=$True)] [String] $GUID = "", 
  [Parameter(Mandatory=$True)] [String] $Variable = ""
)

Process
{
  Add-Type -Language CSharp -TypeDefinition @'
    using System;
    using System.ComponentModel;
    using System.Diagnostics;
    using System.Runtime.CompilerServices;
    using System.Runtime.InteropServices;

    public class UEFINative
    {
        static IntPtr tokenHandle = IntPtr.Zero;

        public static String GetVariable(string name, string guid)
        {
            const int MAX_SIZE = 8192;
            IntPtr buffer = Marshal.AllocHGlobal(MAX_SIZE);

            EnablePriv();
            UInt32 size = GetFirmwareEnvironmentVariableA(name, guid, buffer, MAX_SIZE);
            if (size == 0)
            {
                throw new Win32Exception();
            }
            DisablePriv();
            String result = Marshal.PtrToStringAnsi(buffer);
            Marshal.FreeHGlobal(buffer);
            return result;
        }

        private static void EnablePriv()
        {
            // get process token
            if (!OpenProcessToken(Process.GetCurrentProcess().Handle,
                TOKEN_QUERY | TOKEN_ADJUST_PRIVILEGES,
                out tokenHandle))
            {
                throw new Win32Exception(Marshal.GetLastWin32Error(),
                    "Failed to open process token handle");
            }

            // lookup the shutdown privilege
            TOKEN_PRIVILEGES tokenPrivs = new TOKEN_PRIVILEGES();
            tokenPrivs.PrivilegeCount = 1;
            tokenPrivs.Privileges = new LUID_AND_ATTRIBUTES[1];
            tokenPrivs.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;

            if (!LookupPrivilegeValue(null,
                SE_SYSTEM_ENVIRONMENT_NAME,
                out tokenPrivs.Privileges[0].Luid))
            {
                throw new Win32Exception(Marshal.GetLastWin32Error(),
                    "Failed to open lookup shutdown privilege");
            }

            // add the shutdown privilege to the process token
            if (!AdjustTokenPrivileges(tokenHandle,
                false,
                ref tokenPrivs,
                0,
                IntPtr.Zero,
                IntPtr.Zero))
            {
                throw new Win32Exception(Marshal.GetLastWin32Error(),
                    "Failed to adjust process token privileges");
            }
        }

        private static void DisablePriv()
        {
            // close the process token
            if (tokenHandle != IntPtr.Zero)
            {
                CloseHandle(tokenHandle);
            }

        }

        [StructLayout(LayoutKind.Sequential)]
        private struct LUID
        {
            public uint LowPart;
            public int HighPart;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct LUID_AND_ATTRIBUTES
        {
            public LUID Luid;
            public UInt32 Attributes;
        }

        private struct TOKEN_PRIVILEGES
        {
            public UInt32 PrivilegeCount;
            [MarshalAs(UnmanagedType.ByValArray, SizeConst = 1)]
            public LUID_AND_ATTRIBUTES[] Privileges;
        }

        private const UInt32 TOKEN_QUERY = 0x0008;
        private const UInt32 TOKEN_ADJUST_PRIVILEGES = 0x0020;
        private const UInt32 SE_PRIVILEGE_ENABLED = 0x00000002;
        private const string SE_SYSTEM_ENVIRONMENT_NAME = "SeSystemEnvironmentPrivilege";

        [DllImport("advapi32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool OpenProcessToken(IntPtr ProcessHandle,
            UInt32 DesiredAccess,
            out IntPtr TokenHandle);

        [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool LookupPrivilegeValue(string lpSystemName,
            string lpName,
            out LUID lpLuid);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool CloseHandle(IntPtr hObject);

        [DllImport("advapi32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool AdjustTokenPrivileges(IntPtr TokenHandle,
            [MarshalAs(UnmanagedType.Bool)]bool DisableAllPrivileges,
            ref TOKEN_PRIVILEGES NewState,
            UInt32 Zero,
            IntPtr Null1,
            IntPtr Null2);

        [DllImport("kernel32.dll", SetLastError = true)]
        static extern UInt32 GetFirmwareEnvironmentVariableA(string lpName, string lpGuid, IntPtr pBuffer, UInt32 nSize);
    }
'@

  [UEFINative]::GetVariable($Variable, $GUID)
}
