using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.ServiceProcess;
using System.Threading;

internal sealed class RoutePilotHysteriaService : ServiceBase
{
    private const string FixedServiceName = "RoutePilotHysteriaClient";
    private readonly object logLock = new object();
    private volatile bool stopping;
    private Thread worker;
    private Process child;
    private Dictionary<string, string> settings;

    public RoutePilotHysteriaService()
    {
        ServiceName = FixedServiceName;
        CanStop = true;
        CanShutdown = true;
        AutoLog = false;
    }

    private static Dictionary<string, string> LoadSettings()
    {
        string path = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "service.conf");
        if (!File.Exists(path)) throw new FileNotFoundException("Service configuration is missing.", path);

        var result = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (string rawLine in File.ReadAllLines(path))
        {
            string line = rawLine.Trim();
            if (line.Length == 0 || line.StartsWith("#", StringComparison.Ordinal)) continue;
            int separator = line.IndexOf('=');
            if (separator <= 0) throw new InvalidDataException("Invalid service.conf line.");
            result[line.Substring(0, separator).Trim()] = line.Substring(separator + 1).Trim();
        }

        foreach (string required in new[] { "Executable", "Arguments", "WorkingDirectory", "LogPath" })
        {
            if (!result.ContainsKey(required) || String.IsNullOrWhiteSpace(result[required]))
                throw new InvalidDataException("Missing service setting: " + required);
        }
        if (!File.Exists(result["Executable"])) throw new FileNotFoundException("Configured executable is missing.", result["Executable"]);
        return result;
    }

    private int RestartDelayMilliseconds
    {
        get
        {
            int value;
            if (settings.ContainsKey("RestartDelayMilliseconds") && Int32.TryParse(settings["RestartDelayMilliseconds"], out value))
                return Math.Max(1000, Math.Min(value, 60000));
            return 3000;
        }
    }

    private void Log(string message)
    {
        string logPath = settings["LogPath"];
        lock (logLock)
        {
            string directory = Path.GetDirectoryName(logPath);
            if (!String.IsNullOrEmpty(directory)) Directory.CreateDirectory(directory);
            File.AppendAllText(logPath, DateTimeOffset.Now.ToString("o") + " " + message + Environment.NewLine);
        }
    }

    protected override void OnStart(string[] args)
    {
        settings = LoadSettings();
        stopping = false;
        worker = new Thread(Supervise) { IsBackground = true, Name = "RoutePilotSupervisor" };
        worker.Start();
        Log("service started");
    }

    protected override void OnStop()
    {
        stopping = true;
        Process runningChild = child;
        if (runningChild != null)
        {
            try { if (!runningChild.HasExited) runningChild.Kill(); } catch { }
        }
        if (worker != null) worker.Join(10000);
        Log("service stopped");
    }

    protected override void OnShutdown()
    {
        OnStop();
        base.OnShutdown();
    }

    private void Supervise()
    {
        while (!stopping)
        {
            try
            {
                var start = new ProcessStartInfo
                {
                    FileName = settings["Executable"],
                    Arguments = settings["Arguments"],
                    WorkingDirectory = settings["WorkingDirectory"],
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true
                };

                using (var running = new Process { StartInfo = start, EnableRaisingEvents = true })
                {
                    child = running;
                    running.OutputDataReceived += delegate(object sender, DataReceivedEventArgs e) { if (e.Data != null) Log("OUT " + e.Data); };
                    running.ErrorDataReceived += delegate(object sender, DataReceivedEventArgs e) { if (e.Data != null) Log("ERR " + e.Data); };
                    if (!running.Start()) throw new InvalidOperationException("The configured process did not start.");
                    Log("child started pid=" + running.Id);
                    running.BeginOutputReadLine();
                    running.BeginErrorReadLine();

                    while (!stopping && !running.WaitForExit(1000)) { }
                    if (stopping && !running.HasExited)
                    {
                        try { running.Kill(); } catch { }
                        running.WaitForExit(5000);
                    }
                    if (running.HasExited) Log("child exited code=" + running.ExitCode);
                    child = null;
                }
            }
            catch (Exception ex)
            {
                Log("supervisor error=" + ex.GetType().Name + ": " + ex.Message);
                child = null;
            }
            if (!stopping) Thread.Sleep(RestartDelayMilliseconds);
        }
    }

    public static void Main()
    {
        ServiceBase.Run(new RoutePilotHysteriaService());
    }
}
