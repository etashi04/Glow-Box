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
    private const string Version = "__PATCH_VERSION__";
    private const string GameBuild = "__GAME_BUILD__";
    __BUNDLE_CONFIGURATION__

    [STAThread]
    private static void Main(string[] args)
    {
        if (args.Length == 2 && (args[0] == "--install" || args[0] == "--restore")) {
            try {
                string root = InstallerForm.ValidateRoot(args[1]);
                if (args[0] == "--install") InstallerForm.Install(root); else InstallerForm.Restore(root);
                Environment.ExitCode = 0;
            } catch (Exception ex) {
                try { File.WriteAllText(Path.Combine(args[1], "KoreanPatch_CLI_Error.txt"), ex.ToString(), Encoding.UTF8); } catch { }
                Environment.ExitCode = 1;
            }
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
            var note = new Label { Text = "지원 게임: " + GameBuild + " · 원본 파일은 자동 백업됩니다.", AutoSize = true, Location = new Point(27, 58) };
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
            string staging = Path.Combine(Path.GetTempPath(), "GlowBoxPatch_" + Guid.NewGuid().ToString("N"));
            string rollback = Path.Combine(staging, "rollback");

            // Validate every file before changing the game directory.
            foreach (string name in BundleNames) {
                string destination = Path.Combine(target, name);
                string backupFile = Path.Combine(backup, name);
                if (!File.Exists(destination)) throw new FileNotFoundException("게임 파일 누락: " + name);
                string currentHash = Hash(destination);
                if (File.Exists(backupFile)) {
                    if (!SameHash(Hash(backupFile), OriginalHashes[name]))
                        throw new InvalidDataException("기존 백업이 손상되었거나 다른 게임 버전입니다: " + name);
                    if (!SameHash(currentHash, OriginalHashes[name]) && !SameHash(currentHash, PatchedHashes[name]))
                        throw new InvalidDataException("패치 후 게임이 업데이트되었거나 파일이 수정되었습니다: " + name);
                } else if (!SameHash(currentHash, OriginalHashes[name])) {
                    throw new InvalidDataException("지원하지 않는 게임 버전 또는 수정된 파일입니다: " + name);
                }
            }

            Directory.CreateDirectory(backup);
            Directory.CreateDirectory(rollback);
            try {
                foreach (string name in BundleNames) {
                    string destination = Path.Combine(target, name);
                    string backupFile = Path.Combine(backup, name);
                    if (!File.Exists(backupFile)) File.Copy(destination, backupFile, false);
                    File.Copy(destination, Path.Combine(rollback, name), true);
                    string staged = Path.Combine(staging, name);
                    WritePayload(name, staged);
                    if (!SameHash(Hash(staged), PatchedHashes[name])) throw new InvalidDataException("내장 패치 파일 검증 실패: " + name);
                }
                foreach (string name in BundleNames) File.Copy(Path.Combine(staging, name), Path.Combine(target, name), true);
            } catch {
                foreach (string name in BundleNames) {
                    string saved = Path.Combine(rollback, name);
                    if (File.Exists(saved)) File.Copy(saved, Path.Combine(target, name), true);
                }
                throw;
            } finally {
                if (Directory.Exists(staging)) Directory.Delete(staging, true);
            }
            File.WriteAllText(Path.Combine(root, "KoreanPatch.json"), "{\"version\":\"" + Version + "\",\"installedAt\":\"" + DateTime.Now.ToString("o") + "\"}", Encoding.UTF8);
        }

        private static void WritePayload(string name, string destination)
        {
                using (Stream input = Assembly.GetExecutingAssembly().GetManifestResourceStream("GlowBox.Payload." + name)) {
                    if (input == null) throw new InvalidDataException("내장 패치 파일 누락: " + name);
                using (FileStream output = File.Create(destination)) input.CopyTo(output);
                }
        }

        internal static void Restore(string root)
        {
            string target = Path.Combine(root, "Glow Box_Data", "StreamingAssets", "aa", "StandaloneWindows64");
            string backup = Path.Combine(root, "KoreanPatch_Backup");
            if (!Directory.Exists(backup)) throw new DirectoryNotFoundException("복구용 백업을 찾지 못했습니다.");
            foreach (string name in BundleNames) {
                string source = Path.Combine(backup, name);
                if (!File.Exists(source)) throw new FileNotFoundException("백업 파일 누락: " + name);
                if (!SameHash(Hash(source), OriginalHashes[name])) throw new InvalidDataException("복구용 백업이 손상되었거나 다른 게임 버전입니다: " + name);
            }
            string rollback = Path.Combine(Path.GetTempPath(), "GlowBoxRestore_" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(rollback);
            try {
                foreach (string name in BundleNames) File.Copy(Path.Combine(target, name), Path.Combine(rollback, name), true);
                foreach (string name in BundleNames) File.Copy(Path.Combine(backup, name), Path.Combine(target, name), true);
            } catch {
                foreach (string name in BundleNames) {
                    string saved = Path.Combine(rollback, name);
                    if (File.Exists(saved)) File.Copy(saved, Path.Combine(target, name), true);
                }
                throw;
            } finally { if (Directory.Exists(rollback)) Directory.Delete(rollback, true); }
            string marker = Path.Combine(root, "KoreanPatch.json"); if (File.Exists(marker)) File.Delete(marker);
        }

        private static bool SameHash(string left, string right)
        {
            return String.Equals(left, right, StringComparison.OrdinalIgnoreCase);
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
