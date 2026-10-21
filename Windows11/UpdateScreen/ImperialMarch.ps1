<#
.SYNOPSIS
    ImperialMarch.ps1 - Imperial March (Darth Vaders Thema) möglichst originalnah.

.DESCRIPTION
    Synthetisiert das Thema von John Williams in g-Moll mit Original-Tempo (108 BPM),
    originalem Rhythmus (Viertel / punktierte Achtel + Sechzehntel / Halbe), der
    chromatischen Mittelpartie sowie einem blechbläserartigen Klang (Obertöne,
    Oktavverdopplung, Anstoß-/Abklingverhalten, leichter Hall).
    Das Rendern läuft in kompiliertem C#, damit es schnell geht.

.PARAMETER Wiederholungen
    0 = endlos (Standard), n = n Durchläufe

.PARAMETER Tempo
    Geschwindigkeitsfaktor, 1.0 = Originaltempo (108 BPM)

.EXAMPLE
    .\ImperialMarch.ps1
#>

[CmdletBinding()]
param(
    [int]    $Wiederholungen = 0,
    [double] $Tempo          = 1.0
)

$ErrorActionPreference = 'Stop'

Write-Host 'Imperial March läuft - Abbruch mit STRG+C' -ForegroundColor Yellow

# ---------------------------------------------------------------------------
# Notennamen -> Frequenz (gleichstufig, A4 = 440 Hz). 'R' = Pause
# ---------------------------------------------------------------------------
function Get-Freq([string]$Name) {
    if ($Name -eq 'R') { return 0.0 }
    $semi = @{ 'C'=0; 'D'=2; 'E'=4; 'F'=5; 'G'=7; 'A'=9; 'B'=11 }
    $m = [regex]::Match($Name, '^([A-G])(s|b)?(\d)$')
    if (-not $m.Success) { throw "Ungültige Note: $Name" }
    $n = $semi[$m.Groups[1].Value]
    if ($m.Groups[2].Value -eq 's') { $n++ }
    if ($m.Groups[2].Value -eq 'b') { $n-- }
    $midi = 12 * ([int]$m.Groups[3].Value + 1) + $n
    return 440.0 * [Math]::Pow(2.0, ($midi - 69) / 12.0)
}

# Originaltempo laut Notenblatt: 108 BPM -> Viertel = 556 ms -> Sechzehntel = ca. 139 ms
$u = 60000.0 / 108.0 / 4.0 / $Tempo

# Motiv: @( Note , Dauer in Sechzehnteln )   (4/4-Takt = 16 Einheiten)

# Takt 1-4: Hauptthema und Antwort
$thema = @(
    @('G4',4),  @('G4',4),  @('G4',4),  @('Eb4',3), @('Bb4',1),   # Takt 1
    @('G4',4),  @('Eb4',3), @('Bb4',1), @('G4',8),                # Takt 2
    @('D5',4),  @('D5',4),  @('D5',4),  @('Eb5',3), @('Bb4',1),   # Takt 3
    @('Fs4',4), @('Eb4',3), @('Bb4',1), @('G4',8)                 # Takt 4
)

# Takt 5-8 (= 9-12 = 13-14): Mittelteil mit chromatischem Abstieg
$teilB = @(
    @('G5',4),  @('G4',3),  @('G4',1),  @('G5',4),  @('Fs5',3), @('F5',1),                 # Takt 5
    @('E5',1),  @('Eb5',1), @('E5',2),  @('R',2),   @('Ab4',2), @('Db5',4), @('C5',3), @('B4',1),   # Takt 6
    @('Bb4',1), @('A4',1),  @('Bb4',2), @('R',2),   @('Eb4',2), @('Fs4',4), @('Eb4',3), @('G4',1),  # Takt 7
    @('Bb4',4), @('G4',3),  @('Bb4',1), @('D5',8)                                          # Takt 8
)

# Ablauf laut Notenblatt (Wiederholung zurück zum Anfang, 1. und 2. Klammer):
#   Takt 1-4 | Takt 5-8 | Takt 9-12 (= 5-8)  :||  Takt 1-4 | Takt 5-6 | 2. Klammer: Takt 13-14 (= 7-8)
$motiv = $thema + $teilB + $teilB + $thema + $teilB

# ---------------------------------------------------------------------------
# Kompilierter Synthesizer (schnell)
# ---------------------------------------------------------------------------
Add-Type -TypeDefinition @"
using System;
using System.IO;

public static class Synth {
    static readonly double[] Harm = { 1.00, 0.55, 0.45, 0.30, 0.18, 0.10 };

    public static byte[] RenderWav(double[] freq, double[] durMs, double[] gate, int sr, double volume) {
        int total = 0;
        int[] len = new int[freq.Length];
        for (int i = 0; i < freq.Length; i++) { len[i] = (int)(sr * durMs[i] / 1000.0); total += len[i]; }

        int tail = sr; // 1 s Ausklang für Hall
        double[] buf = new double[total + tail];
        int pos = 0;

        for (int n = 0; n < freq.Length; n++) {
            int active = (int)(len[n] * gate[n]);
            double f = freq[n];
            if (f > 0) {
                int atk = (int)(sr * 0.012);
                int dec = (int)(sr * 0.090);
                int rel = Math.Min((int)(sr * 0.040), (int)(active * 0.35));
                // Marcato: kurze, kräftige Noten klingen etwas lauter an
                double peak = durMs[n] < 700 ? 1.0 : 0.95;
                for (int i = 0; i < active; i++) {
                    double t = (double)i / sr;
                    double env;
                    if (i < atk) env = (double)i / atk;
                    else if (i < atk + dec) env = 1.0 - 0.18 * (double)(i - atk) / dec;
                    else env = 0.82 - 0.12 * Math.Min(1.0, (double)(i - atk - dec) / (sr * 1.5));
                    if (i > active - rel) env *= (double)(active - i) / rel;
                    env *= peak;

                    // leichtes Vibrato nur auf langen Noten
                    double vib = 1.0;
                    if (durMs[n] > 800 && t > 0.35)
                        vib = 1.0 + 0.0035 * Math.Sin(2 * Math.PI * 5.2 * t) * Math.Min(1.0, (t - 0.35) / 0.4);

                    double s = 0, s2 = 0;
                    for (int h = 0; h < Harm.Length; h++) {
                        double hf = f * vib * (h + 1);
                        if (hf < sr / 2.0) s += Harm[h] * Math.Sin(2 * Math.PI * hf * t);
                        double lf = f * 0.5 * vib * (h + 1);
                        if (lf < sr / 2.0) s2 += Harm[h] * Math.Sin(2 * Math.PI * lf * t);
                    }
                    buf[pos + i] += env * (s + 0.55 * s2);
                }
            }
            pos += len[n];
        }

        // Einfacher Raumhall (zwei Echos)
        int d1 = (int)(sr * 0.085), d2 = (int)(sr * 0.137);
        double[] outBuf = new double[buf.Length];
        for (int i = 0; i < buf.Length; i++) {
            double v = buf[i];
            if (i >= d1) v += 0.22 * outBuf[i - d1];
            if (i >= d2) v += 0.14 * outBuf[i - d2];
            outBuf[i] = v;
        }

        double max = 1e-9;
        for (int i = 0; i < outBuf.Length; i++) max = Math.Max(max, Math.Abs(outBuf[i]));
        double scale = 32767.0 * volume / max;

        int dataLen = outBuf.Length * 2;
        MemoryStream ms = new MemoryStream(44 + dataLen);
        BinaryWriter bw = new BinaryWriter(ms);
        bw.Write(new char[] { 'R','I','F','F' });
        bw.Write(36 + dataLen);
        bw.Write(new char[] { 'W','A','V','E','f','m','t',' ' });
        bw.Write(16); bw.Write((short)1); bw.Write((short)1);
        bw.Write(sr); bw.Write(sr * 2); bw.Write((short)2); bw.Write((short)16);
        bw.Write(new char[] { 'd','a','t','a' });
        bw.Write(dataLen);
        for (int i = 0; i < outBuf.Length; i++) bw.Write((short)(outBuf[i] * scale));
        bw.Flush();
        return ms.ToArray();
    }
}
"@

function Play-ImperialMarch {
    param(
        [array]$NotenListe,
        [int]$Lautstaerke = 80
    )

    $count = $NotenListe.Length
    $freq  = New-Object double[] $count
    $dur   = New-Object double[] $count
    $gate  = New-Object double[] $count

    for ($n = 0; $n -lt $count; $n++) {
        $freq[$n] = Get-Freq $NotenListe[$n][0]
        $units    = [int]$NotenListe[$n][1]
        $dur[$n]  = $units * $u

        # Artikulation: Tonwiederholung -> deutlich abgesetzt (Marcato),
        # kurze Noten leicht gebunden, lange Noten fast voll gehalten
        $sameNext = ($n -lt $count - 1) -and ($NotenListe[$n+1][0] -eq $NotenListe[$n][0])
        if     ($sameNext)    { $gate[$n] = 0.80 }
        elseif ($units -ge 8) { $gate[$n] = 0.97 }
        else                  { $gate[$n] = 0.93 }
    }

    $wav = [Synth]::RenderWav($freq, $dur, $gate, 44100, $Lautstaerke / 100.0)

    # Dauer aus der WAV-Größe berechnen (44 Byte Header, 16 Bit mono)
    $dauerMs = [int]((($wav.Length - 44) / 2) / 44100.0 * 1000)

    $ms = New-Object System.IO.MemoryStream (,$wav)
    $player = New-Object System.Media.SoundPlayer $ms
    try {
        # Asynchron starten und in kleinen Schritten warten, damit STRG+C sofort greift
        $player.Play()
        $ende = [DateTime]::UtcNow.AddMilliseconds($dauerMs)
        while ([DateTime]::UtcNow -lt $ende) {
            Start-Sleep -Milliseconds 50
        }
    }
    finally {
        # Bei Abbruch sofort verstummen
        $player.Stop()
        $player.Dispose()
        $ms.Dispose()
    }
}

$lauf = 0
while ($true) {
    Play-ImperialMarch -NotenListe $motiv -Lautstaerke 80
    Start-Sleep -Milliseconds 300
    $lauf++
    if ($Wiederholungen -gt 0 -and $lauf -ge $Wiederholungen) { break }
}
