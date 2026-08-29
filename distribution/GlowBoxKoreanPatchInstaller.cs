using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Windows.Forms;
using Microsoft.Win32;

internal static class Program
{
    private const string Version = "1.0.0";
    private static readonly string[] BundleNames = {
        "11ee4a0ca6d5e27a4192b31f12d7b10a.bundle",
        "4acc258f619ac06b664ed91b69b7f2a1.bundle",
        "7bd755be8ba5171f40812b455a8a4ff1.bundle",
        "a83647f242c8e97a23ee6bcd801cb623.bundle",
        "b79bff27dd04232ee4d7bc9d1c2236b8.bundle"
    };
    private static readonly Dictionary<string, string> OriginalHashes = new Dictionary<string, string> {
        { BundleNames[0], "7AE36FD537ACBFFFA9D20A8D1C439982D0C7806696E8468F681AB3ED67E5CEE2" },
        { BundleNames[1], "6DBCE59D4C90FB3D3A6704FC877EFACA77D36A7AAAAACE165945DABF8A07F48D" },
        { BundleNames[2], "6EC3D3DB085064A4D1D97B0B375B475966F90668F3068DEB1EDE8FB192E6B3AE" },
        { BundleNames[3], "4633E027E17F0B4AB44EFEDF717736C78256C5FD4E1846567267BC5A48F3C2E6" },
        { BundleNames[4], "74D5C1A1C6D22E3DB89F227A1B30561A5CA492C9F354A8F743741C12844D5F77" }
    };

    [STAThread]
    private static void Main(string[] args)
    {
        if (args.Length == 2 && (args[0] == "--install" || args[0] == "--restore")) {
            try {
                string root = InstallerForm.ValidateRoot(args[1]);
                if (args[0] == "--install") InstallerForm.Install(root); else InstallerForm.Restore(root);
                Environment.ExitCode = 0;
            } catch { Environment.ExitCode = 1; }
            return;
        }
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new InstallerForm());
    }

    private sealed class InstallerForm : Form
    {
        private readonly TextBox pathBox = new TextBox();
        private readonly Label status = new Label();
        private readonly Button installButton = new Button();
        private readonly Button restoreButton = new Button();

        internal InstallerForm()
        {
            Text = "Glow Box 한국어 패치 v" + Version;
            ClientSize = new Size(620, 245);
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            Font = new Font("Malgun Gothic", 9F);

            var title = new Label { Text = "Glow Box 비공식 한국어 패치", Font = new Font(Font.FontFamily, 16F, FontStyle.Bold), AutoSize = true, Location = new Point(24, 20) };
            var note = new Label { Text = "게임을 종료한 뒤 설치하세요. 원본 파일은 자동으로 백업됩니다.", AutoSize = true, Location = new Point(27, 58) };
            var pathLabel = new Label { Text = "게임 설치 폴더", AutoSize = true, Location = new Point(27, 92) };
            pathBox.Location = new Point(27, 114); pathBox.Size = new Size(475, 25);
            var browse = new Button { Text = "찾아보기", Location = new Point(510, 112), Size = new Size(84, 29) };
            installButton.Text = "한국어 패치 설치"; installButton.Location = new Point(27, 158); installButton.Size = new Size(180, 38);
            restoreButton.Text = "원본 복구"; restoreButton.Location = new Point(217, 158); restoreButton.Size = new Size(130, 38);
            status.Location = new Point(27, 207); status.Size = new Size(565, 25); status.ForeColor = Color.DimGray;
            Controls.AddRange(new Control[] { title, note, pathLabel, pathBox, browse, installButton, restoreButton, status });

            pathBox.Text = FindGamePath() ?? "";
            browse.Click += delegate { Browse(); };
            installButton.Click += delegate { RunAction(true); };
            restoreButton.Click += delegate { RunAction(false); };
        }

        private void Browse()
        {
            using (var dialog = new FolderBrowserDialog()) {
                dialog.Description = "Glow Box가 설치된 GlowMachine 폴더를 선택하세요.";
                if (dialog.ShowDialog(this) == DialogResult.OK) pathBox.Text = dialog.SelectedPath;
            }
        }

        private void RunAction(bool install)
        {
            installButton.Enabled = restoreButton.Enabled = false;
            try {
                if (Process.GetProcessesByName("Glow Box").Length > 0) throw new InvalidOperationException("게임을 먼저 종료하세요.");
                string root = ValidateRoot(pathBox.Text);
                if (install) Install(root); else Restore(root);
                status.Text = install ? "한국어 패치 설치가 완료되었습니다." : "원본 파일 복구가 완료되었습니다.";
                status.ForeColor = Color.DarkGreen;
                MessageBox.Show(this, status.Text, "완료", MessageBoxButtons.OK, MessageBoxIcon.Information);
            } catch (Exception ex) {
                status.Text = ex.Message; status.ForeColor = Color.DarkRed;
                MessageBox.Show(this, ex.Message, "오류", MessageBoxButtons.OK, MessageBoxIcon.Error);
            } finally { installButton.Enabled = restoreButton.Enabled = true; }
        }

        internal static string ValidateRoot(string path)
        {
            if (String.IsNullOrWhiteSpace(path)) throw new DirectoryNotFoundException("게임 설치 폴더를 선택하세요.");
            string root = Path.GetFullPath(path.Trim());
            if (!File.Exists(Path.Combine(root, "Glow Box.exe"))) throw new DirectoryNotFoundException("올바른 GlowMachine 폴더가 아닙니다.");
            return root;
        }

        internal static void Install(string root)
        {
            string target = Path.Combine(root, "Glow Box_Data", "StreamingAssets", "aa", "StandaloneWindows64");
            string backup = Path.Combine(root, "KoreanPatch_Backup");
            Directory.CreateDirectory(backup);
            foreach (string name in BundleNames) {
                string destination = Path.Combine(target, name);
                string backupFile = Path.Combine(backup, name);
                if (!File.Exists(destination)) throw new FileNotFoundException("게임 파일 누락: " + name);
                if (!File.Exists(backupFile)) {
                    if (!String.Equals(Hash(destination), OriginalHashes[name], StringComparison.OrdinalIgnoreCase))
                        throw new InvalidDataException("지원하지 않는 게임 버전 또는 수정된 파일입니다: " + name);
                    File.Copy(destination, backupFile, false);
                }
                string temp = destination + ".tmp";
                using (Stream input = Assembly.GetExecutingAssembly().GetManifestResourceStream("GlowBox.Payload." + name)) {
                    if (input == null) throw new InvalidDataException("내장 패치 파일 누락: " + name);
                    using (FileStream output = File.Create(temp)) input.CopyTo(output);
                }
                File.Copy(temp, destination, true); File.Delete(temp);
            }
            File.WriteAllText(Path.Combine(root, "KoreanPatch.json"), "{\"version\":\"" + Version + "\",\"installedAt\":\"" + DateTime.Now.ToString("o") + "\"}", Encoding.UTF8);
        }

        internal static void Restore(string root)
        {
            string target = Path.Combine(root, "Glow Box_Data", "StreamingAssets", "aa", "StandaloneWindows64");
            string backup = Path.Combine(root, "KoreanPatch_Backup");
            if (!Directory.Exists(backup)) throw new DirectoryNotFoundException("복구용 백업을 찾지 못했습니다.");
            foreach (string name in BundleNames) {
                string source = Path.Combine(backup, name);
                if (!File.Exists(source)) throw new FileNotFoundException("백업 파일 누락: " + name);
                File.Copy(source, Path.Combine(target, name), true);
            }
            string marker = Path.Combine(root, "KoreanPatch.json"); if (File.Exists(marker)) File.Delete(marker);
        }

        private static string Hash(string path)
        {
            using (SHA256 sha = SHA256.Create()) using (FileStream stream = File.OpenRead(path)) {
                return BitConverter.ToString(sha.ComputeHash(stream)).Replace("-", "");
            }
        }

        private static string FindGamePath()
        {
            var candidates = new List<string>();
            AddSteamCandidates(candidates, Registry.CurrentUser.OpenSubKey(@"Software\Valve\Steam"), "SteamPath");
            AddSteamCandidates(candidates, Registry.LocalMachine.OpenSubKey(@"SOFTWARE\WOW6432Node\Valve\Steam"), "InstallPath");
            foreach (string path in candidates) if (File.Exists(Path.Combine(path, "Glow Box.exe"))) return path;
            return null;
        }

        private static void AddSteamCandidates(List<string> candidates, RegistryKey key, string valueName)
        {
            using (key) {
                if (key == null) return;
                string steam = key.GetValue(valueName) as string; if (String.IsNullOrEmpty(steam)) return;
                candidates.Add(Path.Combine(steam, "steamapps", "common", "GlowMachine"));
                string vdf = Path.Combine(steam, "steamapps", "libraryfolders.vdf");
                if (!File.Exists(vdf)) return;
                foreach (Match match in Regex.Matches(File.ReadAllText(vdf), "\\\"path\\\"\\s+\\\"([^\\\"]+)\\\""))
                    candidates.Add(Path.Combine(match.Groups[1].Value.Replace("\\\\", "\\"), "steamapps", "common", "GlowMachine"));
            }
        }
    }
}
