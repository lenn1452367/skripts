<#
.SYNOPSIS
    InputLock.ps1 - Sperrt alles, entsperrt sauber bei STRG + ALT + SHIFT + Q
    und gibt die Tasten kontrolliert frei, bevor es sich schließt.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -ReferencedAssemblies 'System.Windows.Forms','System.Drawing' -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace Venice.Blocker
{
    public class GlobalBlocker
    {
        private const int WH_KEYBOARD_LL = 13;
        private const int WH_MOUSE_LL    = 14;
        private const int WM_KEYDOWN     = 0x0100;
        private const int WM_SYSKEYDOWN  = 0x0104;
        private const int WM_LBUTTONDOWN = 0x0201;
        private const int WM_LBUTTONUP   = 0x0202;
        private const int WM_RBUTTONDOWN = 0x0204;
        private const int WM_RBUTTONUP   = 0x0205;
        private const int WM_MBUTTONDOWN = 0x0207;
        private const int WM_MBUTTONUP   = 0x0208;

        private const uint KEYEVENTF_KEYUP = 0x0002;

        private delegate IntPtr HookProc(int nCode, IntPtr wParam, IntPtr lParam);
        private static HookProc _kbProc;
        private static HookProc _msProc;
        private static IntPtr _kbHook = IntPtr.Zero;
        private static IntPtr _msHook = IntPtr.Zero;

        public static volatile bool UnlockRequested = false;

        [DllImport("user32.dll", SetLastError = true)]
        private static extern IntPtr SetWindowsHookEx(int idHook, HookProc lpfn, IntPtr hMod, uint dwThreadId);
        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool UnhookWindowsHookEx(IntPtr hhk);
        [DllImport("user32.dll", SetLastError = true)]
        private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern IntPtr GetModuleHandle(string lpModuleName);
        [DllImport("user32.dll")]
        private static extern short GetAsyncKeyState(int vKey);
        [DllImport("user32.dll")]
        private static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, int dwExtraInfo);

        private static bool IsDown(int vk) { return (GetAsyncKeyState(vk) & 0x8000) != 0; }

        public static void Start()
        {
            _kbProc = KbProc;
            _msProc = MsProc;
            IntPtr mod = GetModuleHandle(null);
            _kbHook = SetWindowsHookEx(WH_KEYBOARD_LL, _kbProc, mod, 0);
            _msHook = SetWindowsHookEx(WH_MOUSE_LL, _msProc, mod, 0);
        }

        public static void ReleaseAndStop()
        {
            // 1. Erst die Hooks entfernen (Tastatur & Maus wieder freigeben)
            if (_kbHook != IntPtr.Zero) { UnhookWindowsHookEx(_kbHook); _kbHook = IntPtr.Zero; }
            if (_msHook != IntPtr.Zero) { UnhookWindowsHookEx(_msHook); _msHook = IntPtr.Zero; }

            // 2. Dann aktiv das Loslassen der Tasten an Windows senden
            keybd_event(0x10, 0, KEYEVENTF_KEYUP, 0); // Shift
            keybd_event(0x11, 0, KEYEVENTF_KEYUP, 0); // Ctrl
            keybd_event(0x12, 0, KEYEVENTF_KEYUP, 0); // Alt
            keybd_event(0x51, 0, KEYEVENTF_KEYUP, 0); // Q
        }

        private static IntPtr KbProc(int nCode, IntPtr wParam, IntPtr lParam)
        {
            if (nCode >= 0)
            {
                int msg = wParam.ToInt32();
                if (msg == WM_KEYDOWN || msg == WM_SYSKEYDOWN)
                {
                    int vk = Marshal.ReadInt32(lParam);
                    bool isShift = (vk == 0x10 || vk == 0xA0 || vk == 0xA1);
                    bool isCtrl  = (vk == 0x11 || vk == 0xA2 || vk == 0xA3);
                    bool isAlt   = (vk == 0x12 || vk == 0xA4 || vk == 0xA5);
                    bool isQ     = (vk == 0x51);

                    if (isShift || isCtrl || isAlt || isQ)
                    {
                        bool shiftDown = IsDown(0xA0) || IsDown(0xA1) || IsDown(0x10);
                        bool ctrlDown  = IsDown(0xA2) || IsDown(0xA3) || IsDown(0x11);
                        bool altDown   = IsDown(0xA4) || IsDown(0xA5) || IsDown(0x12);
                        bool qDown     = IsDown(0x51);

                        if (ctrlDown && altDown && shiftDown && qDown)
                        {
                            UnlockRequested = true;
                        }
                        return CallNextHookEx(_kbHook, nCode, wParam, lParam);
                    }
                }
            }
            return (IntPtr)1; // Blockiert alles
        }

        private static IntPtr MsProc(int nCode, IntPtr wParam, IntPtr lParam)
        {
            if (nCode >= 0)
            {
                int msg = wParam.ToInt32();
                if (msg == WM_LBUTTONDOWN || msg == WM_LBUTTONUP ||
                    msg == WM_RBUTTONDOWN || msg == WM_RBUTTONUP ||
                    msg == WM_MBUTTONDOWN || msg == WM_MBUTTONUP)
                    return (IntPtr)1;
            }
            return CallNextHookEx(_msHook, nCode, wParam, lParam);
        }
    }
}
'@

[Venice.Blocker.GlobalBlocker]::Start()

# Warten, bis die Tastenkombination gedrückt wird
while (-not [Venice.Blocker.GlobalBlocker]::UnlockRequested) {
    Start-Sleep -Milliseconds 50
}

# Ablauf beim Entsperren der Reihe nach:
# 1. Tasten & Maus entsperren und Signale senden
[Venice.Blocker.GlobalBlocker]::ReleaseAndStop()

# 2. Kurze Gedenksekunde, damit Windows die Freigabe verarbeitet
Start-Sleep -Milliseconds 250

# 3. Skript schließt sich nun von selbst und gibt das Signal an Python weiter