import os
import subprocess
import tkinter as tk

class FakeUpdateApp:
    def __init__(self, root, script_dir):
        self.root = root
        self.script_dir = script_dir
        self.audio_proc = None
        self.lock_proc = None

        # 1. ANZEIGE ÖFFNEN (Vollbild, im Vordergrund)
        self.root.attributes("-fullscreen", True)
        self.root.attributes("-topmost", True)
        self.root.configure(bg="#0067B8")  # Windows-Update-Blau
        
        self.create_widgets()
        self.start_background_tasks()

        # Überwachen, ob das Sperr-Skript beendet wurde (Tastenkombination gedrückt)
        self.check_lock_status()

    def create_widgets(self):
        self.frame = tk.Frame(self.root, bg="#0067B8")
        self.frame.place(relx=0.5, rely=0.5, anchor=tk.CENTER)

        tk.Label(self.frame, text="Updates werden verarbeitet", font=("Segoe UI", 28), fg="white", bg="#0067B8").pack(pady=10)
        
        self.lbl_prozent = tk.Label(self.frame, text="0 %", font=("Segoe UI", 64), fg="white", bg="#0067B8")
        self.lbl_prozent.pack(pady=10)

        self.lbl_text = tk.Label(self.frame, text="Schalten Sie den PC nicht aus.", font=("Segoe UI", 20), fg="white", bg="#0067B8")
        self.lbl_text.pack(pady=10)

        tk.Label(self.frame, text="Dies kann einige Zeit dauern.", font=("Segoe UI", 14), fg="#E1FFFF", bg="#0067B8").pack(pady=5)

    def start_background_tasks(self):
        audio_path = os.path.join(self.script_dir, "ImperialMarch.ps1")
        lock_path = os.path.join(self.script_dir, "InputLock.ps1")

        # SCHRITT 1: Audio im Hintergrund starten
        if os.path.exists(audio_path):
            try:
                self.audio_proc = subprocess.Popen([
                    "powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", 
                    "-WindowStyle", "Hidden", "-File", audio_path, "-Wiederholungen", "0"
                ])
            except Exception as e:
                print(f"Audio Fehler: {e}")

        # SCHRITT 2: Tastatur- und Maussperre (.ps1) starten
        if os.path.exists(lock_path):
            try:
                self.lock_proc = subprocess.Popen([
                    "powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", 
                    "-WindowStyle", "Hidden", "-File", lock_path
                ])
            except Exception as e:
                print(f"Sperr-Skript Fehler: {e}")

        # Fortschrittsanzeige starten
        self.current_pct = 0
        self.update_progress()

    def update_progress(self):
        if self.current_pct < 99:
            self.current_pct += 1
            self.lbl_prozent.config(text=f"{self.current_pct} %")
            self.root.after(1000, self.update_progress)
        else:
            self.lbl_text.config(text="Neustart wird vorbereitet...")

    def check_lock_status(self):
        # Prüfen, ob das Sperr-Skript beendet wurde (weil der Nutzer die Tastenkombi gedrückt hat)
        if self.lock_proc and self.lock_proc.poll() is not None:
            self.trigger_exit()
            return
        
        # Alle 100ms erneut prüfen
        self.root.after(100, self.check_lock_status)

    def trigger_exit(self):
        # REIHENFOLGE BEIM BEENDEN:
        
        # 1. Musik-Prozess hart beenden
        if self.audio_proc:
            try:
                self.audio_proc.terminate()
                self.audio_proc.wait(timeout=1)
            except:
                pass
        
        try:
            subprocess.run([
                "powershell.exe", "-Command", 
                "Get-Process powershell -ErrorAction SilentlyContinue | Where-Object {$_.CommandLine -like '*ImperialMarch.ps1*'} | Stop-Process -Force -ErrorAction SilentlyContinue"
            ], capture_output=True)
        except:
            pass

        # 2. Anzeige schließen
        self.root.destroy()

if __name__ == "__main__":
    root = tk.Tk()
    root.title("Windows Update")

    script_dir = os.path.dirname(os.path.abspath(__file__))
    app = FakeUpdateApp(root, script_dir)
    root.mainloop()